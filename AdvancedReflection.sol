// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardToken is ERC20, Ownable {
    IERC20 public rewardToken;
    
    uint256 public buyFeePercent;
    uint256 public sellFeePercent;
    uint256 public buyBurnPercent;
    uint256 public sellBurnPercent;
    uint256 public devSplitPercent;
    uint256 public swapSlippagePercent;
    bool public tradingEnabled;
    
    // Improved pair tracking
    mapping(address => bool) public isPair;
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromRewards;
    mapping(address => bool) public isBlacklisted;
    
    // Improved holder tracking
    mapping(address => bool) private isHolder;
    address[] private holders;
    mapping(address => uint256) private holderIndexes;
    
    // Track rewards
    uint256 private constant MAGNITUDE = 2**128;
    uint256 private magnifiedRewardPerShare;
    mapping(address => int256) private magnifiedRewardCorrections;
    mapping(address => uint256) private withdrawnRewards;
    uint256 public totalRewardsDistributed;
    
    // Min holding for rewards (to prevent dust accounts)
    uint256 public minHoldingForRewards = 1000 * 10**18; // 1000 tokens default
    
    // events
    event FeesUpdated(uint256 buyFee, uint256 sellFee, uint256 buyBurn, uint256 sellBurn);
    event RewardDistributed(uint256 amount);
    event ExcludeFromFee(address indexed account, bool isExcluded);
    event ExcludeFromRewards(address indexed account, bool isExcluded);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event TradingEnabled(bool enabled);
    event PairUpdated(address indexed pair, bool isPair);
    event TokensWithdrawn(address token, address to, uint256 amount);
    event ETHWithdrawn(address to, uint256 amount);
    event SlippageUpdated(uint256 slippagePercent);
    event DevSplitUpdated(uint256 splitPercent);
    event MinHoldingUpdated(uint256 minHolding);
    event Debug(string message, address addr, uint256 value, bool flag);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _rewardTokenAddress,
        uint256 _buyFeePercent,
        uint256 _sellFeePercent,
        uint256 _buyBurnPercent,
        uint256 _sellBurnPercent
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        _mint(msg.sender, _initialSupply * 10 ** decimals());
        rewardToken = IERC20(_rewardTokenAddress);
        buyFeePercent = _buyFeePercent;
        sellFeePercent = _sellFeePercent;
        buyBurnPercent = _buyBurnPercent;
        sellBurnPercent = _sellBurnPercent;
        
        // Exclude owner and contract from fees
        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[address(this)] = true;
        
        // Exclude contract and zero address from rewards
        isExcludedFromRewards[address(this)] = true;
        isExcludedFromRewards[address(0)] = true;
        
        tradingEnabled = false;
        swapSlippagePercent = 50; // Default 0.5% slippage
        devSplitPercent = 10; // Default 10% to dev
    }

    // 1. Withdraw stuck tokens/ETH
    function withdrawStuckTokens(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(this), "Cannot withdraw native token");
        IERC20(token).transfer(to, amount);
        emit TokensWithdrawn(token, to, amount);
    }

    function withdrawStuckETH(address payable to) external onlyOwner {
        uint256 amount = address(this).balance;
        to.transfer(amount);
        emit ETHWithdrawn(to, amount);
    }

    // 2. Blacklist feature
    function setBlacklist(address account, bool blacklisted) external onlyOwner {
        isBlacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }

    // 3. Launch button
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled(true);
    }

    // 4. Set pair (can be called by owner or automatically detected)
    function setPair(address pair, bool value) public onlyOwner {
        require(pair != address(0), "Invalid pair");
        isPair[pair] = value;
        isExcludedFromRewards[pair] = value;
        emit PairUpdated(pair, value);
    }

    // 5. Exclude from rewards
    function setExcludeFromRewards(address account, bool excluded) external onlyOwner {
        require(account != address(0), "Zero address");
        isExcludedFromRewards[account] = excluded;
        
        if(excluded) {
            _removeHolder(account);
        } else {
            _addHolder(account);
        }
        
        emit ExcludeFromRewards(account, excluded);
    }

    // 6. Exclude from fees
    function setExcludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
        emit ExcludeFromFee(account, excluded);
    }

    // 7. Set fees and burn percentages
    function setFees(
        uint256 _buyFeePercent,
        uint256 _sellFeePercent,
        uint256 _buyBurnPercent,
        uint256 _sellBurnPercent
    ) external onlyOwner {
        require(_buyFeePercent + _buyBurnPercent <= 25, "Buy fees too high");
        require(_sellFeePercent + _sellBurnPercent <= 25, "Sell fees too high");
        buyFeePercent = _buyFeePercent;
        sellFeePercent = _sellFeePercent;
        buyBurnPercent = _buyBurnPercent;
        sellBurnPercent = _sellBurnPercent;
        emit FeesUpdated(_buyFeePercent, _sellFeePercent, _buyBurnPercent, _sellBurnPercent);
    }

    // 8. Set slippage
    function setSwapSlippage(uint256 _slippagePercent) external onlyOwner {
        require(_slippagePercent <= 500, "Slippage too high"); // Max 5%
        swapSlippagePercent = _slippagePercent;
        emit SlippageUpdated(_slippagePercent);
    }

    // 9. Set dev split
    function setDevSplit(uint256 _splitPercent) external onlyOwner {
        require(_splitPercent <= 50, "Dev split too high"); // Max 50%
        devSplitPercent = _splitPercent;
        emit DevSplitUpdated(_splitPercent);
    }

    // 10. Set min holding for rewards
    function setMinHoldingForRewards(uint256 _minHolding) external onlyOwner {
        minHoldingForRewards = _minHolding;
        emit MinHoldingUpdated(_minHolding);
    }

    // Get claimable rewards for an account
    function getClaimableRewards(address account) public view returns (uint256) {
        if(isExcludedFromRewards[account]) return 0;
        
        int256 accumulatedReward = int256(magnifiedRewardPerShare * balanceOf(account) / MAGNITUDE);
        return uint256(accumulatedReward - magnifiedRewardCorrections[account]) - withdrawnRewards[account];
    }

    // Override transfer function
    function _update(address from, address to, uint256 amount) internal override {
        require(!isBlacklisted[from] && !isBlacklisted[to], "Blacklisted address");
        
        // Allow owner transfers before trading enabled
        require(tradingEnabled || from == owner() || to == owner() || from == address(0), "Trading not enabled");

        // Auto-detect liquidity pairs
        if(from != address(0) && to != address(0)) {
            // Check if this might be a new pair (has code and receiving first tokens)
            if(_isPotentialPair(to) && balanceOf(to) == 0 && amount > 0) {
                isPair[to] = true;
                isExcludedFromRewards[to] = true;
                emit PairUpdated(to, true);
            }
        }

        uint256 transferAmount = amount;
        
        // Handle fees if not excluded
        if (!isExcludedFromFee[from] && !isExcludedFromFee[to] && from != address(0) && to != address(0)) {
            // Determine if buy or sell
            bool isSell = isPair[to];
            bool isBuy = isPair[from];
            
            emit Debug("Transfer type", from, amount, isBuy || isSell);
            
            if(isBuy || isSell) {
                uint256 feePercent = isBuy ? buyFeePercent : sellFeePercent;
                uint256 burnPercent = isBuy ? buyBurnPercent : sellBurnPercent;

                uint256 feeAmount = (amount * feePercent) / 1000; // Using 1000 for 0.1% precision
                uint256 burnAmount = (amount * burnPercent) / 1000;

                if (feeAmount > 0) {
                    uint256 devShare = (feeAmount * devSplitPercent) / 100;
                    uint256 rewardShare = feeAmount - devShare;

                    if (devShare > 0) {
                        super._update(from, owner(), devShare);
                    }
                    if (rewardShare > 0) {
                        super._update(from, address(this), rewardShare);
                        _distributeRewards(rewardShare);
                    }
                    transferAmount -= feeAmount;
                    
                    emit Debug("Fee taken", from, feeAmount, true);
                }

                if (burnAmount > 0) {
                    super._update(from, address(0), burnAmount);
                    transferAmount -= burnAmount;
                }
            }
        }

        // Update reward corrections before balance change
        if(from != address(0) && !isExcludedFromRewards[from]) {
            magnifiedRewardCorrections[from] += int256(magnifiedRewardPerShare * amount / MAGNITUDE);
        }
        if(to != address(0) && !isExcludedFromRewards[to]) {
            magnifiedRewardCorrections[to] -= int256(magnifiedRewardPerShare * amount / MAGNITUDE);
        }

        super._update(from, to, transferAmount);

        // Update holder list after transfer
        _updateHolderList(from);
        _updateHolderList(to);
    }

    // Distribute rewards by increasing magnified reward per share
    function _distributeRewards(uint256 rewardAmount) internal {
        if(rewardAmount == 0) return;
        
        uint256 totalSupplyForRewards = _getTotalSupplyForRewards();
        if(totalSupplyForRewards == 0) return;
        
        magnifiedRewardPerShare += (rewardAmount * MAGNITUDE) / totalSupplyForRewards;
        totalRewardsDistributed += rewardAmount;
        
        emit RewardDistributed(rewardAmount);
    }

    // Get total supply eligible for rewards
    function _getTotalSupplyForRewards() internal view returns (uint256) {
        uint256 total = totalSupply();
        
        // Subtract excluded balances
        if(isExcludedFromRewards[address(0)]) total -= balanceOf(address(0));
        if(isExcludedFromRewards[address(this)]) total -= balanceOf(address(this));
        
        // Subtract other excluded addresses
        for(uint256 i = 0; i < holders.length; i++) {
            if(isExcludedFromRewards[holders[i]]) {
                total -= balanceOf(holders[i]);
            }
        }
        
        return total;
    }

    // Update holder list
    function _updateHolderList(address account) internal {
        if(account == address(0)) return;
        
        uint256 balance = balanceOf(account);
        bool meetsMinimum = balance >= minHoldingForRewards;
        bool isCurrentHolder = isHolder[account];
        
        if(meetsMinimum && !isCurrentHolder && !isExcludedFromRewards[account]) {
            _addHolder(account);
        } else if((!meetsMinimum || balance == 0) && isCurrentHolder) {
            _removeHolder(account);
        }
    }

    // Add holder
    function _addHolder(address account) internal {
        if(!isHolder[account]) {
            holders.push(account);
            holderIndexes[account] = holders.length - 1;
            isHolder[account] = true;
        }
    }

    // Remove holder
    function _removeHolder(address account) internal {
        if(isHolder[account]) {
            uint256 index = holderIndexes[account];
            uint256 lastIndex = holders.length - 1;
            
            if(index != lastIndex) {
                address lastHolder = holders[lastIndex];
                holders[index] = lastHolder;
                holderIndexes[lastHolder] = index;
            }
            
            holders.pop();
            delete holderIndexes[account];
            isHolder[account] = false;
        }
    }

    // Check if address might be a pair
    function _isPotentialPair(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    // Get holder count
    function getHolderCount() external view returns (uint256) {
        return holders.length;
    }

    // Get holders list (paginated to prevent gas issues)
    function getHolders(uint256 offset, uint256 limit) external view returns (address[] memory) {
        require(offset < holders.length, "Offset too high");
        
        uint256 end = offset + limit;
        if(end > holders.length) {
            end = holders.length;
        }
        
        address[] memory result = new address[](end - offset);
        for(uint256 i = offset; i < end; i++) {
            result[i - offset] = holders[i];
        }
        
        return result;
    }

    // Manually claim rewards (optional - rewards are automatic)
    function claimRewards() external {
        require(!isExcludedFromRewards[msg.sender], "Excluded from rewards");
        
        uint256 claimable = getClaimableRewards(msg.sender);
        if(claimable > 0) {
            withdrawnRewards[msg.sender] += claimable;
            super._update(address(this), msg.sender, claimable);
        }
    }

    // Receive ETH
    receive() external payable {}
}
