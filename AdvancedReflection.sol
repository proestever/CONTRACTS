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
    address public liquidityPool;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromRewards;
    mapping(address => bool) public isBlacklisted;
    mapping(address => uint256) private holderBalances;
    address[] private holders;

    event FeesUpdated(uint256 buyFee, uint256 sellFee, uint256 buyBurn, uint256 sellBurn);
    event RewardDistributed(uint256 amount);
    event ExcludeFromFee(address indexed account, bool isExcluded);
    event ExcludeFromRewards(address indexed account, bool isExcluded);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event TradingEnabled(bool enabled);
    event LiquidityPoolSet(address pool);
    event TokensWithdrawn(address token, address to, uint256 amount);
    event ETHWithdrawn(address to, uint256 amount);
    event SlippageUpdated(uint256 slippagePercent);
    event DevSplitUpdated(uint256 splitPercent);

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
        isExcludedFromFee[msg.sender] = true;
        isExcludedFromRewards[address(this)] = true;
        tradingEnabled = false;
        swapSlippagePercent = 50; // Default 1% slippage
        devSplitPercent = 10; // Default no dev split
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

    // 4. Set liquidity pool
    function setLiquidityPool(address _liquidityPool) external onlyOwner {
        liquidityPool = _liquidityPool;
        isExcludedFromFee[_liquidityPool] = true;
        isExcludedFromRewards[_liquidityPool] = true;
        emit LiquidityPoolSet(_liquidityPool);
    }

    // 5. Exclude from rewards
    function setExcludeFromRewards(address account, bool excluded) external onlyOwner {
        isExcludedFromRewards[account] = excluded;
        emit ExcludeFromRewards(account, excluded);
    }

    // 6. Set fees and burn percentages
    function setFees(
        uint256 _buyFeePercent,
        uint256 _sellFeePercent,
        uint256 _buyBurnPercent,
        uint256 _sellBurnPercent
    ) external onlyOwner {
        require(_buyFeePercent + _buyBurnPercent <= 20, "Buy fees too high");
        require(_sellFeePercent + _sellBurnPercent <= 20, "Sell fees too high");
        buyFeePercent = _buyFeePercent;
        sellFeePercent = _sellFeePercent;
        buyBurnPercent = _buyBurnPercent;
        sellBurnPercent = _sellBurnPercent;
        emit FeesUpdated(_buyFeePercent, _sellFeePercent, _buyBurnPercent, _sellBurnPercent);
    }

    // 7. Set slippage
    function setSwapSlippage(uint256 _slippagePercent) external onlyOwner {
        require(_slippagePercent <= 5, "Slippage too high");
        swapSlippagePercent = _slippagePercent;
        emit SlippageUpdated(_slippagePercent);
    }

    // 8. Set dev split
    function setDevSplit(uint256 _splitPercent) external onlyOwner {
        require(_splitPercent <= 100, "Invalid split percentage");
        devSplitPercent = _splitPercent;
        emit DevSplitUpdated(_splitPercent);
    }

    // Override transfer function
    function _update(address from, address to, uint256 amount) internal override {
        require(!isBlacklisted[from] && !isBlacklisted[to], "Blacklisted address");
        require(tradingEnabled || from == owner() || to == owner(), "Trading not enabled");

        uint256 transferAmount = amount;

        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            bool isBuy = from == liquidityPool || from == owner();
            uint256 feePercent = isBuy ? buyFeePercent : sellFeePercent;
            uint256 burnPercent = isBuy ? buyBurnPercent : sellBurnPercent;

            uint256 feeAmount = amount * feePercent / 100;
            uint256 burnAmount = amount * burnPercent / 100;

            if (feeAmount > 0) {
                uint256 devShare = feeAmount * devSplitPercent / 100;
                uint256 rewardShare = feeAmount - devShare;

                if (devShare > 0) {
                    super._update(from, owner(), devShare);
                }
                if (rewardShare > 0) {
                    super._update(from, address(this), rewardShare);
                }
                transferAmount -= feeAmount;
            }

            if (burnAmount > 0) {
                super._update(from, address(0), burnAmount);
                transferAmount -= burnAmount;
            }

            distributeRewards();
        }

        super._update(from, to, transferAmount);

        // Update holder balances
        updateHolder(from);
        updateHolder(to);
    }

    // Distribute collected fees as rewards to holders
    function distributeRewards() internal {
        uint256 rewardBalance = balanceOf(address(this));
        if (rewardBalance == 0 || holders.length == 0) return;

        uint256 totalSupplyForRewards = totalSupply() - balanceOf(address(0)) - balanceOf(address(this));
        for (uint256 i = 0; i < holders.length; i++) {
            if (isExcludedFromRewards[holders[i]]) {
                totalSupplyForRewards -= balanceOf(holders[i]);
            }
        }
        if (totalSupplyForRewards == 0) return;

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            if (!isExcludedFromRewards[holder]) {
                uint256 holderBalance = balanceOf(holder);
                if (holderBalance > 0) {
                    uint256 rewardShare = rewardBalance * holderBalance / totalSupplyForRewards;
                    if (rewardShare > 0) {
                        super._update(address(this), holder, rewardShare);
                    }
                }
            }
        }

        emit RewardDistributed(rewardBalance);
    }

    // Update holder list
    function updateHolder(address account) internal {
        if (isExcludedFromRewards[account]) return;

        if (balanceOf(account) > 0 && holderBalances[account] == 0) {
            holders.push(account);
            holderBalances[account] = balanceOf(account);
        } else if (balanceOf(account) == 0 && holderBalances[account] > 0) {
            removeHolder(account);
            holderBalances[account] = 0;
        } else {
            holderBalances[account] = balanceOf(account);
        }
    }

    // Remove holder from the holder list
    function removeHolder(address account) internal {
        uint256 length = holders.length;
        for (uint256 i = 0; i < length; i++) {
            if (holders[i] == account) {
                holders[i] = holders[length - 1];
                holders.pop();
                break;
            }
        }
    }

    // Receive ETH
    receive() external payable {}
}