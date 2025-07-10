/*                         

██████╗ ██████╗  █████╗ ██╗    ██████╗  █████╗ ██╗      ██████╗  ██████╗ ███████╗ █████╗ 
██╔══██╗██╔══██╗██╔══██╗██║    ██╔══██╗██╔══██╗██║     ██╔═══██╗██╔═══██╗╚══███╔╝██╔══██╗
██████╔╝██║  ██║███████║██║    ██████╔╝███████║██║     ██║   ██║██║   ██║  ███╔╝ ███████║
██╔═══╝ ██║  ██║██╔══██║██║    ██╔═══╝ ██╔══██║██║     ██║   ██║██║   ██║ ███╔╝  ██╔══██║
██║     ██████╔╝██║  ██║██║    ██║     ██║  ██║███████╗╚██████╔╝╚██████╔╝███████╗██║  ██║
╚═╝     ╚═════╝ ╚═╝  ╚═╝╚═╝    ╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝

by ✸ GIGA ✸ 

SPDX-License-Identifier: MIT

*/

pragma solidity 0.8.21;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _initialTransfer(address to, uint256 amount) internal virtual {
        _balances[to] = amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

interface IDividendDistributor {
    function initialize() external;
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _claimAfter) external;
    function setShare(address shareholder, uint256 amount, bool exclude) external;
    function deposit() external payable;
    function claimDividend(address shareholder) external;
    function getUnpaidEarnings(address shareholder) external view returns (uint256);
    function getPaidDividends(address shareholder) external view returns (uint256);
    function getTotalPaid() external view returns (uint256);
    function getClaimTime(address shareholder) external view returns (uint256);
    function getTotalDividends() external view returns (uint256);
    function getTotalDistributed() external view returns (uint256);
    function countShareholders() external view returns (uint256);
    function migrate(address newDistributor) external;
    function process() external;
}

interface ILotteryDistributor {
    function initialize() external;
    function setLotteryParameters(uint256 _minHolding, uint256 _minPeriod, uint256 _minPot) external;
    function setParticipant(address participant, uint256 amount) external;
    function deposit() external payable;
    function drawWinners() external;
    function getTicketCount(address participant) external view returns (uint256);
    function getLotteryInfo() external view returns (uint256 pot, uint256 lastDraw, uint256 participants);
    function claimPrize(address winner) external;
    function process() external;
    function getNextDrawInfo() external view returns (uint256 nextDrawTimestamp, uint256 hoursUntilDraw, uint256 minutesUntilDraw, bool isReady);
    function getLastRound() external view returns (uint256 pot, uint256 drawTime, address[] memory winners, uint256[] memory prizes);
}

interface ILotteryDistributorExtended {
    function canDraw() external view returns (bool);
    function processWithAutoDraw() external;
    function hasPendingPayments() external view returns (bool);
}

contract DividendDistributor is IDividendDistributor, Ownable {
    address public _token;
    IERC20 public immutable reward;
    address public immutable ETH;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    address[] public shareholders;
    mapping(address => uint256) public shareholderIndexes;
    mapping(address => uint256) public shareholderClaims;
    mapping(address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public unclaimed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    uint256 public minPeriod = 30 seconds;
    uint256 public minDistribution = 1;
    uint256 public gas = 800000;
    uint256 public currentIndex;
    
    uint256 public minTokensForDividends = 100000 * 10**9;

    address constant routerAddress = 0x165C3410fC91EF562C50559f7d2289fEbed552d9;
    IDexRouter constant dexRouter = IDexRouter(routerAddress);
    uint256 public slippage = 98;

    bool public initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token);
        _;
    }

    function getTotalDividends() external view override returns (uint256) {
        return totalDividends;
    }

    function getTotalDistributed() external view override returns (uint256) {
        return totalDistributed;
    }

    constructor(address rwd) {
        reward = IERC20(rwd);
        aprv();
        ETH = dexRouter.WPLS();
    }

    function aprv() public {
        reward.approve(routerAddress, type(uint256).max);
    }

    function initialize() external override initialization {
        _token = msg.sender;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _gas) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
        gas = _gas;
    }

    function setShare(address shareholder, uint256 amount, bool exclude) external override onlyToken {
        if (amount > 0 && amount < minTokensForDividends) {
            if (shares[shareholder].amount > 0) {
                removeShareholder(shareholder);
                totalShares = totalShares - shares[shareholder].amount;
                shares[shareholder].amount = 0;
                shares[shareholder].totalExcluded = 0;
                shares[shareholder].totalRealised = 0;
            }
            return;
        }
        
        uint256 currentShare = shares[shareholder].amount;
        if (amount > 0 && currentShare == 0) {
            addShareholder(shareholder);
            shares[shareholder].totalExcluded = getCumulativeDividends(amount);
            shareholderClaims[shareholder] = block.timestamp;
        } else if (amount == 0 && currentShare > 0) {
            removeShareholder(shareholder);
        }

        uint256 unpaid = getUnpaidEarnings(shareholder);
        if (currentShare > 0 && !exclude) {
            if (unpaid > 0) {
                if (shouldDistribute(shareholder, unpaid)) {
                    distributeDividend(shareholder, unpaid);
                } else {
                    unclaimed += unpaid;
                }
            }
        }

        totalShares = (totalShares - currentShare) + amount;

        shares[shareholder].amount = amount;

        shares[shareholder].totalExcluded = getCumulativeDividends(amount);
    }

    function deposit() external payable override {
        uint256 amount;
        if (address(reward) != ETH) {
            address[] memory path = new address[](2);
            path[0] = dexRouter.WPLS();
            path[1] = address(reward);

            uint256 spend = address(this).balance;
            uint256[] memory amountsout = dexRouter.getAmountsOut(spend, path);

            uint256 curBal = reward.balanceOf(address(this));

            dexRouter.swapExactETHForTokens{value: spend}(
                amountsout[1] * slippage / 100,
                path,
                address(this),
                block.timestamp
            );

            amount = reward.balanceOf(address(this)) - curBal;
        } else {
            amount = msg.value;
        }
        totalDividends += amount;
        if (totalShares > 0)
            if (dividendsPerShare == 0)
                dividendsPerShare = (dividendsPerShareAccuracyFactor * totalDividends) / totalShares;
            else
                dividendsPerShare += ((dividendsPerShareAccuracyFactor * amount) / totalShares);
    }

    function extractUnclaimed() external onlyOwner {
        uint256 uncl = unclaimed;
        unclaimed = 0;
        reward.transfer(msg.sender, uncl);
    }

    function extractLostETH() external onlyOwner {
        bool success;
        (success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    function setSlippage(uint256 _slip) external onlyOwner {
        require(_slip <= 100, "Min slippage reached");
        require(_slip >= 50, "Probably too much slippage");
        slippage = _slip;
    }

    function migrate(address newDistributor) external onlyToken {
        DividendDistributor newD = DividendDistributor(newDistributor);
        require(!newD.initialized(), "Already initialized");
        bool success;
        (success, ) = newDistributor.call{value: address(this).balance}("");
        reward.transfer(newDistributor, reward.balanceOf(address(this)));
        require(success, "Transfer failed");
    }

    function shouldDistribute(address shareholder, uint256 unpaidEarnings) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
            && unpaidEarnings > minDistribution;
    }

    function getClaimTime(address shareholder) external view override onlyToken returns (uint256) {
        uint256 scp = shareholderClaims[shareholder] + minPeriod;
        if (scp <= block.timestamp) {
            return 0;
        } else {
            return scp - block.timestamp;
        }
    }

    function distributeDividend(address shareholder, uint256 unpaidEarnings) internal {
        if (shares[shareholder].amount == 0) {
            return;
        }

        if (unpaidEarnings > 0) {
            totalDistributed = totalDistributed + unpaidEarnings;
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised += unpaidEarnings;
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
            if (address(reward) == ETH) {
                bool success;
                (success, ) = shareholder.call{value: unpaidEarnings}("");
            } else
                reward.transfer(shareholder, unpaidEarnings);
        }
    }

    function process() public override {
        uint256 shareholderCount = shareholders.length;

        if (shareholderCount == 0) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }

            uint256 unpaid = getUnpaidEarnings(shareholders[currentIndex]);
            if (shouldDistribute(shareholders[currentIndex], unpaid)) {
                distributeDividend(shareholders[currentIndex], unpaid);
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function claimDividend(address shareholder) external override onlyToken {
        uint256 unpaid = getUnpaidEarnings(shareholder);
        require(shouldDistribute(shareholder, unpaid), "Dividends not available yet");
        distributeDividend(shareholder, unpaid);
    }

    function processClaim(address shareholder) external onlyOwner {
        uint256 unpaid = getUnpaidEarnings(shareholder);
        require(shouldDistribute(shareholder, unpaid), "Dividends not available yet");
        distributeDividend(shareholder, unpaid);
    }

    function getUnpaidEarnings(address shareholder) public view override returns (uint256) {
        if (shares[shareholder].amount == 0) {
            return 0;
        }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if (shareholderTotalDividends <= shareholderTotalExcluded) {
            return 0;
        }

        return shareholderTotalDividends - shareholderTotalExcluded;
    }

    function getPaidDividends(address shareholder) external view override onlyToken returns (uint256) {
        return shares[shareholder].totalRealised;
    }

    function getTotalPaid() external view override onlyToken returns (uint256) {
        return totalDistributed;
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        if (share == 0) {
            return 0;
        }
        return (share * dividendsPerShare) / dividendsPerShareAccuracyFactor;
    }

    function countShareholders() public view returns (uint256) {
        return shareholders.length;
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length - 1];
        shareholderIndexes[shareholders[shareholders.length - 1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}

contract LotteryDistributor is ILotteryDistributor, Ownable {
    address public _token;
    IERC20 public immutable reward;
    address public immutable ETH;
    
    struct Participant {
        uint256 amount;
        uint256 tickets;
        uint256 lastParticipation;
        bool isParticipant;
    }
    
    struct LotteryRound {
        uint256 totalPot;
        uint256 drawTime;
        address[] winners;
        uint256[] prizes;
    }
    
    address[] public participants;
    mapping(address => Participant) public participantInfo;
    mapping(address => uint256) public unclaimedPrizes;
    
    address[] public winnersToProcess;
    uint256 public currentWinnerIndex;
    uint256 public gas = 500000;
    
    uint256 public currentPot;
    uint256 public totalDistributed;
    uint256 public minHolding = 1 * 10**9;
    uint256 public minPeriod = 1 days;
    uint256 public minPot = 1 * 10**18;
    uint256 public lastDrawTime;
    
    uint256 public firstPrizePercent = 65;
    uint256 public secondPrizePercent = 25;
    uint256 public thirdPrizePercent = 10;
    
    uint256 public ticketsPerToken = 1;
    uint256 public ticketDivisor = 1 * 10**9;
    
    bool public pendingPayouts;
    
    LotteryRound[] public lotteryHistory;
    
    function getLotteryRound(uint256 index) external view returns (
        uint256 totalPot,
        uint256 drawTime,
        address[] memory winners,
        uint256[] memory prizes
    ) {
        require(index < lotteryHistory.length, "Invalid index");
        LotteryRound memory round = lotteryHistory[index];
        return (round.totalPot, round.drawTime, round.winners, round.prizes);
    }
    
    address constant routerAddress = 0x165C3410fC91EF562C50559f7d2289fEbed552d9;
    IDexRouter constant dexRouter = IDexRouter(routerAddress);
    uint256 public slippage = 98;
    
    bool public initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }
    
    modifier onlyToken() {
        require(msg.sender == _token);
        _;
    }
    
    modifier onlyAuthorized() {
        require(
            msg.sender == _token || 
            msg.sender == owner() || 
            msg.sender == address(this),
            "Unauthorized"
        );
        _;
    }
    
    event LotteryDrawn(uint256 pot, address[] winners, uint256[] prizes);
    event PrizeClaimed(address winner, uint256 amount);
    event ParticipantUpdated(address participant, uint256 tickets);
    
    constructor(address rwd) {
        reward = IERC20(rwd);
        aprv();
        ETH = dexRouter.WPLS();
        lastDrawTime = block.timestamp;
    }
    
    function aprv() public {
        reward.approve(routerAddress, type(uint256).max);
    }
    
    function initialize() external override initialization {
        _token = msg.sender;
    }
    
    function setLotteryParameters(
        uint256 _minHolding, 
        uint256 _minPeriod, 
        uint256 _minPot
    ) external override onlyToken {
        minHolding = _minHolding;
        minPeriod = _minPeriod;
        minPot = _minPot;
    }
    
    function setGas(uint256 _gas) external onlyToken {
        gas = _gas;
    }
    
    function setPrizeDistribution(
        uint256 _first, 
        uint256 _second, 
        uint256 _third
    ) external onlyOwner {
        require(_first + _second + _third == 100, "Must equal 100%");
        firstPrizePercent = _first;
        secondPrizePercent = _second;
        thirdPrizePercent = _third;
    }
    
    function setTicketParameters(
        uint256 _ticketsPerToken,
        uint256 _ticketDivisor
    ) external onlyOwner {
        ticketsPerToken = _ticketsPerToken;
        ticketDivisor = _ticketDivisor;
    }
    
    function setSlippage(uint256 _slip) external onlyOwner {
        require(_slip <= 100, "Min slippage reached");
        require(_slip >= 50, "Probably too much slippage");
        slippage = _slip;
    }
    
    function setParticipant(address participant, uint256 amount) external override onlyToken {
        if (amount < minHolding) {
            if (participantInfo[participant].isParticipant) {
                removeParticipant(participant);
            }
            return;
        }
        
        uint256 newTickets = (amount * ticketsPerToken) / ticketDivisor;
        
        if (!participantInfo[participant].isParticipant && newTickets > 0) {
            participants.push(participant);
            participantInfo[participant].isParticipant = true;
        }
        
        participantInfo[participant].amount = amount;
        participantInfo[participant].tickets = newTickets;
        participantInfo[participant].lastParticipation = block.timestamp;
        
        emit ParticipantUpdated(participant, newTickets);
    }
    
    function removeParticipant(address participant) internal {
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == participant) {
                participants[i] = participants[participants.length - 1];
                participants.pop();
                break;
            }
        }
        delete participantInfo[participant];
    }
    
    function deposit() external payable override {
        uint256 amount;
        if (address(reward) != ETH) {
            address[] memory path = new address[](2);
            path[0] = dexRouter.WPLS();
            path[1] = address(reward);

            uint256 spend = address(this).balance;
            uint256[] memory amountsout = dexRouter.getAmountsOut(spend, path);

            uint256 curBal = reward.balanceOf(address(this));

            dexRouter.swapExactETHForTokens{value: spend}(
                amountsout[1] * slippage / 100,
                path,
                address(this),
                block.timestamp
            );

            amount = reward.balanceOf(address(this)) - curBal;
        } else {
            amount = msg.value;
        }
        currentPot += amount;
    }
    
    function canDraw() public view returns (bool) {
        return block.timestamp >= lastDrawTime + minPeriod && 
               currentPot >= minPot && 
               participants.length >= 3;
    }
    
    function getNextDrawInfo() external view returns (
        uint256 nextDrawTimestamp,
        uint256 hoursUntilDraw,
        uint256 minutesUntilDraw,
        bool isReady
    ) {
        nextDrawTimestamp = lastDrawTime + minPeriod;
        
        if (block.timestamp >= nextDrawTimestamp) {
            isReady = true;
            hoursUntilDraw = 0;
            minutesUntilDraw = 0;
        } else {
            isReady = false;
            uint256 timeLeft = nextDrawTimestamp - block.timestamp;
            hoursUntilDraw = timeLeft / 3600;
            minutesUntilDraw = (timeLeft % 3600) / 60;
        }
    }
    
    function processWithAutoDraw() external {
        if (canDraw()) {
            try this.drawWinners() {} catch {}
        }
        
        processAllPendingPayments();
    }
    
    function drawWinners() external override onlyAuthorized {
        require(block.timestamp >= lastDrawTime + minPeriod, "Too soon");
        require(currentPot >= minPot, "Pot too small");
        require(participants.length >= 3, "Not enough participants");
        
        uint256 pot = currentPot;
        currentPot = 0;
        lastDrawTime = block.timestamp;
        
        uint256 totalTickets = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            totalTickets += participantInfo[participants[i]].tickets;
        }
        
        require(totalTickets > 0, "No tickets");
        
        address[] memory winners = new address[](3);
        uint256[] memory prizes = new uint256[](3);
        
        prizes[0] = (pot * firstPrizePercent) / 100;
        prizes[1] = (pot * secondPrizePercent) / 100;
        prizes[2] = (pot * thirdPrizePercent) / 100;
        
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, participants.length)));
        
        for (uint256 i = 0; i < 3; i++) {
            uint256 winningTicket = (seed % totalTickets) + 1;
            uint256 currentTicket = 0;
            
            for (uint256 j = 0; j < participants.length; j++) {
                currentTicket += participantInfo[participants[j]].tickets;
                if (currentTicket >= winningTicket) {
                    winners[i] = participants[j];
                    unclaimedPrizes[winners[i]] += prizes[i];
                    winnersToProcess.push(winners[i]);
                    break;
                }
            }
            
            seed = uint256(keccak256(abi.encodePacked(seed, i)));
        }
        
        totalDistributed += pot;
        
        lotteryHistory.push(LotteryRound({
            totalPot: pot,
            drawTime: block.timestamp,
            winners: winners,
            prizes: prizes
        }));
        
        emit LotteryDrawn(pot, winners, prizes);
        
        pendingPayouts = true;
        
        processAllPendingPayments();
    }
    
    function processAllPendingPayments() internal {
        uint256 processed = 0;
        uint256 maxToProcess = winnersToProcess.length;
        
        while (winnersToProcess.length > 0 && processed < 10 && processed < maxToProcess) {
            address winner = winnersToProcess[0];
            uint256 prize = unclaimedPrizes[winner];
            
            if (prize > 0) {
                unclaimedPrizes[winner] = 0;
                
                bool success;
                if (address(reward) == ETH) {
                    (success, ) = winner.call{value: prize}("");
                } else {
                    try reward.transfer(winner, prize) returns (bool s) {
                        success = s;
                    } catch {
                        success = false;
                    }
                }
                
                if (success) {
                    emit PrizeClaimed(winner, prize);
                } else {
                    unclaimedPrizes[winner] = prize;
                }
            }
            
            winnersToProcess[0] = winnersToProcess[winnersToProcess.length - 1];
            winnersToProcess.pop();
            
            processed++;
        }
        
        if (winnersToProcess.length == 0) {
            pendingPayouts = false;
        }
    }
    
    function process() public override {
        if (pendingPayouts) {
            processAllPendingPayments();
            return;
        }
        
        uint256 winnerCount = winnersToProcess.length;
        
        if (winnerCount == 0) {
            return;
        }
        
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        
        while (gasUsed < gas && iterations < winnerCount && iterations < 5) {
            if (currentWinnerIndex >= winnersToProcess.length) {
                currentWinnerIndex = 0;
            }
            
            address winner = winnersToProcess[currentWinnerIndex];
            uint256 prize = unclaimedPrizes[winner];
            
            if (prize > 0) {
                unclaimedPrizes[winner] = 0;
                
                bool success;
                if (address(reward) == ETH) {
                    (success, ) = winner.call{value: prize}("");
                } else {
                    try reward.transfer(winner, prize) returns (bool s) {
                        success = s;
                    } catch {
                        success = false;
                    }
                }
                
                if (success) {
                    emit PrizeClaimed(winner, prize);
                    removeWinner(currentWinnerIndex);
                    if (currentWinnerIndex > 0) currentWinnerIndex--;
                } else {
                    unclaimedPrizes[winner] = prize;
                    currentWinnerIndex++;
                }
            } else {
                removeWinner(currentWinnerIndex);
                if (currentWinnerIndex > 0) currentWinnerIndex--;
            }
            
            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            iterations++;
        }
    }
    
    function hasPendingPayments() external view returns (bool) {
        return winnersToProcess.length > 0 || pendingPayouts;
    }
    
    function removeWinner(uint256 index) internal {
        if (index >= winnersToProcess.length) return;
        winnersToProcess[index] = winnersToProcess[winnersToProcess.length - 1];
        winnersToProcess.pop();
    }
    
    function emergencyDraw() external onlyOwner {
        require(currentPot > 0, "No pot");
        require(participants.length >= 3, "Not enough participants");
        
        lastDrawTime = 0;
        
        this.drawWinners();
    }
    
    function getParticipantDetails(uint256 startIndex, uint256 count) external view returns (
        address[] memory addresses,
        uint256[] memory amounts,
        uint256[] memory tickets,
        uint256[] memory lastParticipations
    ) {
        uint256 endIndex = startIndex + count;
        if (endIndex > participants.length) {
            endIndex = participants.length;
        }
        
        uint256 actualCount = endIndex - startIndex;
        addresses = new address[](actualCount);
        amounts = new uint256[](actualCount);
        tickets = new uint256[](actualCount);
        lastParticipations = new uint256[](actualCount);
        
        for (uint256 i = 0; i < actualCount; i++) {
            address participant = participants[startIndex + i];
            addresses[i] = participant;
            amounts[i] = participantInfo[participant].amount;
            tickets[i] = participantInfo[participant].tickets;
            lastParticipations[i] = participantInfo[participant].lastParticipation;
        }
    }
    
    function claimPrize(address winner) external override {
        uint256 prize = unclaimedPrizes[winner];
        require(prize > 0, "No prize");
        
        unclaimedPrizes[winner] = 0;
        
        if (address(reward) == ETH) {
            (bool success, ) = winner.call{value: prize}("");
            require(success, "Transfer failed");
        } else {
            reward.transfer(winner, prize);
        }
        
        emit PrizeClaimed(winner, prize);
    }
    
    function manualClaim() external {
        uint256 prize = unclaimedPrizes[msg.sender];
        require(prize > 0, "No prize");
        
        unclaimedPrizes[msg.sender] = 0;
        
        if (address(reward) == ETH) {
            (bool success, ) = msg.sender.call{value: prize}("");
            require(success, "Transfer failed");
        } else {
            reward.transfer(msg.sender, prize);
        }
        
        emit PrizeClaimed(msg.sender, prize);
    }
    
    function getTicketCount(address participant) external view override returns (uint256) {
        return participantInfo[participant].tickets;
    }
    
    function getLotteryInfo() external view override returns (
        uint256 pot, 
        uint256 lastDraw, 
        uint256 participantCount
    ) {
        return (currentPot, lastDrawTime, participants.length);
    }
    
    function getTotalTickets() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            total += participantInfo[participants[i]].tickets;
        }
        return total;
    }
    
    function getLastRound() external view override returns (
        uint256 pot,
        uint256 drawTime,
        address[] memory winners,
        uint256[] memory prizes
    ) {
        if (lotteryHistory.length == 0) return (0, 0, new address[](0), new uint256[](0));
        
        LotteryRound memory last = lotteryHistory[lotteryHistory.length - 1];
        return (last.totalPot, last.drawTime, last.winners, last.prizes);
    }
    
    function getLotteryHistoryCount() external view returns (uint256) {
        return lotteryHistory.length;
    }
    
    function extractLostTokens() external onlyOwner {
        uint256 balance = reward.balanceOf(address(this));
        uint256 totalOwed = currentPot;
        
        for (uint256 i = 0; i < winnersToProcess.length; i++) {
            totalOwed += unclaimedPrizes[winnersToProcess[i]];
        }
        
        uint256 available = balance > totalOwed ? balance - totalOwed : 0;
        if (available > 0) {
            reward.transfer(msg.sender, available);
        }
    }
    
    function extractLostETH() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}

interface ILpPair {
    function sync() external;
}

interface IDexRouter {
    function factory() external pure returns (address);
    function WPLS() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
}

interface IDexFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract pdaipalooza is ERC20, Ownable {
    IDexRouter public immutable dexRouter;
    address public lpPair;
    mapping(address => uint256) public walletProtection;
    bool public protectionDisabled = false;

    // Token metadata for block explorers
    string public WEBSITE = "https://pdaipalooza.com";
    string public TELEGRAM = "https://t.me/pDAIPalooza";
    string public LOGO = "https://pdaipalooza.com/assets/pdai%20logo%20copper_1751979128134-CdL69UeK.png";

    uint8 constant _decimals = 9;
    uint256 constant _decimalFactor = 10 ** _decimals;
    address constant DEAD_ADDRESS = 0x0000000000000000000000000000000000000000;

    bool private swapping;
    uint256 public swapTokensAtAmount;
    uint256 public maxSwapTokens;

    IDividendDistributor public distributor;
    ILotteryDistributor public lotteryDistributor;
    address public taxCollector;
    uint256 public rewardSplit = 33;
    uint256 public lotterySplit = 33;
    
    bool public autoProcess = true;
    bool public swapEnabled = true;

    uint256 public tradingActiveTime;
    uint256 public buyFeePercentage = 10;
    uint256 public sellFeePercentage = 10;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public isDividendExempt;
    mapping(address => bool) public isLotteryExempt;
    mapping(address => bool) public pairs;

    event SetPair(address indexed pair, bool indexed value);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event FeePercentagesUpdated(uint256 buyFee, uint256 sellFee);

    constructor(string memory name, string memory ticker, uint256 supply, address reward) ERC20(name, ticker) {
        address routerAddress = 0x165C3410fC91EF562C50559f7d2289fEbed552d9;
        dexRouter = IDexRouter(routerAddress);
        
        lpPair = IDexFactory(dexRouter.factory()).createPair(address(this), dexRouter.WPLS());
        pairs[lpPair] = true;

        _approve(msg.sender, routerAddress, type(uint256).max);
        _approve(address(this), routerAddress, type(uint256).max);

        uint256 totalSupply = supply * _decimalFactor;

        swapTokensAtAmount = (totalSupply * 1) / 1000000;
        maxSwapTokens = (totalSupply * 20) / 100;

        excludeFromFees(msg.sender, true);
        excludeFromFees(address(this), true);

        isDividendExempt[routerAddress] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD_ADDRESS] = true;
        isDividendExempt[lpPair] = true;
        
        isLotteryExempt[routerAddress] = true;
        isLotteryExempt[address(this)] = true;
        isLotteryExempt[DEAD_ADDRESS] = true;
        isLotteryExempt[lpPair] = true;

        _initialTransfer(msg.sender, totalSupply);
        
        taxCollector = msg.sender;

        DividendDistributor dist = new DividendDistributor(reward);
        setDistributor(address(dist), false);
        
        LotteryDistributor lottery = new LotteryDistributor(reward);
        setLotteryDistributor(address(lottery), false);
    }

    receive() external payable {}

    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function updateSwapTokens(uint256 atAmount, uint256 maxAmount) external onlyOwner {
        require(maxAmount <= (totalSupply() * 1) / 100, "Max swap cannot be higher than 1% supply.");
        swapTokensAtAmount = atAmount;
        maxSwapTokens = maxAmount;
    }

    function setTaxCollector(address wallet) external onlyOwner {
        taxCollector = wallet;
    }

    function toggleSwap() external onlyOwner {
        swapEnabled = !swapEnabled;
    }

    function toggleProcess() external onlyOwner {
        autoProcess = !autoProcess;
    }

    function setPair(address pair, bool value) external {
        require(pair != lpPair, "The pair cannot be removed from pairs");
        require(msg.sender == owner() || msg.sender == taxCollector, "Unauthorised");
        pairs[pair] = value;
        setDividendExempt(pair, true);
        setLotteryExempt(pair, true);
        emit SetPair(pair, value);
    }

    function getFees() public view returns (uint256 buyFee, uint256 sellFee) {
        return (buyFeePercentage, sellFeePercentage);
    }

    function setBuyFeePercentage(uint256 _buyFee) external onlyOwner {
        require(_buyFee <= 25, "Buy fee cannot exceed 25%");
        buyFeePercentage = _buyFee;
        emit FeePercentagesUpdated(_buyFee, sellFeePercentage);
    }

    function setSellFeePercentage(uint256 _sellFee) external onlyOwner {
        require(_sellFee <= 25, "Sell fee cannot exceed 25%");
        sellFeePercentage = _sellFee;
        emit FeePercentagesUpdated(buyFeePercentage, _sellFee);
    }

    function setSplits(uint256 _rewardSplit, uint256 _lotterySplit) external onlyOwner {
        require(_rewardSplit + _lotterySplit <= 100, "Total cannot exceed 100%");
        rewardSplit = _rewardSplit;
        lotterySplit = _lotterySplit;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setDividendExempt(address holder, bool exempt) public onlyOwner {
        isDividendExempt[holder] = exempt;
        if (exempt) {
            distributor.setShare(holder, 0, true);
        } else {
            distributor.setShare(holder, balanceOf(holder), false);
        }
    }

    function setLotteryExempt(address holder, bool exempt) public onlyOwner {
        isLotteryExempt[holder] = exempt;
        if (exempt) {
            lotteryDistributor.setParticipant(holder, 0);
        } else {
            lotteryDistributor.setParticipant(holder, balanceOf(holder));
        }
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (tradingActiveTime == 0) {
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading not yet active");
            super._transfer(from, to, amount);
        } else {
            uint256 fees = 0;
            if (!_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
                if (pairs[from]) {
                    fees = (amount * buyFeePercentage) / 100;
                } else if (pairs[to]) {
                    fees = (amount * sellFeePercentage) / 100;
                }

                if (fees > 0) {
                    super._transfer(from, address(this), fees);
                }

                if (swapEnabled && !swapping && pairs[to]) {
                    swapping = true;
                    swapBack(amount);
                    swapping = false;
                }

                amount -= fees;
            }

            super._transfer(from, to, amount);

            if (autoProcess) {
                try distributor.process() {} catch {}
                
                bool lotteryDrawn = false;
                
                try ILotteryDistributorExtended(address(lotteryDistributor)).canDraw() returns (bool canDraw) {
                    if (canDraw) {
                        try lotteryDistributor.drawWinners() {
                            lotteryDrawn = true;
                        } catch {}
                    }
                } catch {}
                
                try lotteryDistributor.process() {} catch {}
                
                if (lotteryDrawn) {
                    try lotteryDistributor.process() {} catch {}
                    try lotteryDistributor.process() {} catch {}
                }
            }
        }

        _beforeTokenTransfer(from, to);

        if (!isDividendExempt[from]) {
            try distributor.setShare(from, balanceOf(from), false) {} catch {}
        }
        if (!isDividendExempt[to]) {
            try distributor.setShare(to, balanceOf(to), false) {} catch {}
        }
        
        if (!isLotteryExempt[from]) {
            try lotteryDistributor.setParticipant(from, balanceOf(from)) {} catch {}
        }
        if (!isLotteryExempt[to]) {
            try lotteryDistributor.setParticipant(to, balanceOf(to)) {} catch {}
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WPLS();
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function swapBack(uint256 amount) private {
        uint256 amountToSwap = balanceOf(address(this));
        if (amountToSwap < swapTokensAtAmount) return;
        if (amountToSwap > maxSwapTokens) amountToSwap = maxSwapTokens;
        if (amountToSwap > amount) amountToSwap = amount;
        if (amountToSwap == 0) return;

        uint256 ethBalance = address(this).balance;
        swapTokensForEth(amountToSwap);
        uint256 generated = address(this).balance - ethBalance;

        if (generated > 0) {
            uint256 rewardAmount = (rewardSplit * generated) / 100;
            uint256 lotteryAmount = (lotterySplit * generated) / 100;
            
            if (rewardAmount > 0)
                try distributor.deposit{value: rewardAmount}() {} catch {}
            
            if (lotteryAmount > 0)
                try lotteryDistributor.deposit{value: lotteryAmount}() {} catch {}
            
            if (address(this).balance > 0 && taxCollector != address(0)) {
                bool success;
                (success, ) = taxCollector.call{value: address(this).balance}("");
            }
        }
    }

    function withdrawTax() external {
        require(msg.sender == owner() || msg.sender == taxCollector, "Unauthorised");
        bool success;
        (success, ) = address(msg.sender).call{value: address(this).balance}("");
    }

    function launch() external onlyOwner {
        require(tradingActiveTime == 0);
        tradingActiveTime = block.number;
    }

    function setDistributor(address _distributor, bool migrate) public onlyOwner {
        if (migrate)
            distributor.migrate(_distributor);
        distributor = IDividendDistributor(_distributor);
        distributor.initialize();
    }

    function setLotteryDistributor(address _lottery, bool /*migrate*/) public onlyOwner {
        lotteryDistributor = ILotteryDistributor(_lottery);
        lotteryDistributor.initialize();
    }

    function claimDistributor(address _distributor) external onlyOwner {
        Ownable(_distributor).transferOwnership(msg.sender);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _claimAfter) external onlyOwner {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution, _claimAfter);
    }

    function setLotteryParameters(uint256 _minHolding, uint256 _minPeriod, uint256 _minPot) external onlyOwner {
        lotteryDistributor.setLotteryParameters(_minHolding, _minPeriod, _minPot);
    }

    function manualDeposit() payable external {
        distributor.deposit{value: msg.value}();
    }

    function getPoolStatistics() external view returns (uint256 totalRewards, uint256 totalRewardsPaid, uint256 rewardHolders) {
        totalRewards = distributor.getTotalDividends();
        totalRewardsPaid = distributor.getTotalDistributed();
        rewardHolders = distributor.countShareholders();
    }

    function myStatistics(address wallet) external view returns (uint256 reward, uint256 rewardClaimed) {
        reward = distributor.getUnpaidEarnings(wallet);
        rewardClaimed = distributor.getPaidDividends(wallet);
    }

    function checkClaimTime(address wallet) external view returns (uint256) {
        return distributor.getClaimTime(wallet);
    }

    function claim() external {
        distributor.claimDividend(msg.sender);
    }

    function drawLottery() external {
        lotteryDistributor.drawWinners();
    }

    function claimLotteryPrize() external {
        lotteryDistributor.claimPrize(msg.sender);
    }

    function getLotteryInfo() external view returns (uint256 pot, uint256 lastDraw, uint256 participants) {
        return lotteryDistributor.getLotteryInfo();
    }

    function getMyTickets() external view returns (uint256) {
        return lotteryDistributor.getTicketCount(msg.sender);
    }

    // Check if lottery is ready to draw
    function isLotteryReady() external view returns (bool) {
        return ILotteryDistributorExtended(address(lotteryDistributor)).canDraw();
    }

    // Manual trigger for lottery with auto-draw
    function processLotteryWithDraw() external {
        require(autoProcess || msg.sender == owner(), "Auto process disabled");
        ILotteryDistributorExtended(address(lotteryDistributor)).processWithAutoDraw();
    }

    // Force lottery draw (owner only) - useful for testing
    function forceLotteryDraw() external onlyOwner {
        lotteryDistributor.drawWinners();
    }

    // Check if lottery has pending payments
    function lotteryHasPendingPayments() external view returns (bool) {
        try ILotteryDistributorExtended(address(lotteryDistributor)).hasPendingPayments() returns (bool pending) {
            return pending;
        } catch {
            return false;
        }
    }

    // Force process all pending lottery payments (owner only)
    function forceProcessLotteryPayments() external onlyOwner {
        for (uint256 i = 0; i < 10; i++) {
            try lotteryDistributor.process() {} catch {
                break;
            }
        }
    }

    // Process lottery payments with custom iterations
    function processLotteryPayments(uint256 iterations) external {
        require(msg.sender == owner() || autoProcess, "Not authorized");
        
        for (uint256 i = 0; i < iterations; i++) {
            try lotteryDistributor.process() {
            } catch {
                break;
            }
        }
    }

    // Emergency function to process specific winner (owner only)
    function emergencyPayWinner(address winner) external onlyOwner {
        lotteryDistributor.claimPrize(winner);
    }

    // NEW FUNCTION: Get time left until next lottery draw
    function getLotteryTimeLeft() external view returns (
        uint256 hoursLeft,
        uint256 minutesLeft,
        uint256 secondsLeft,
        bool isReady
    ) {
        (uint256 nextDrawTimestamp, uint256 hoursUntilDraw, uint256 minutesUntilDraw, bool ready) = lotteryDistributor.getNextDrawInfo();
        
        if (ready) {
            return (0, 0, 0, true);
        }
        
        uint256 timeLeft = nextDrawTimestamp - block.timestamp;
        hoursLeft = hoursUntilDraw;
        minutesLeft = minutesUntilDraw;
        secondsLeft = (timeLeft % 3600) % 60;
        isReady = false;
    }

    // NEW FUNCTION: Get last 3 lottery winners and their prizes
    function getLastLotteryWinners() external view returns (
        address[] memory winners,
        uint256[] memory prizes,
        uint256 potSize,
        uint256 drawTime
    ) {
        (uint256 pot, uint256 time, address[] memory winnerAddresses, uint256[] memory prizeAmounts) = lotteryDistributor.getLastRound();
        return (winnerAddresses, prizeAmounts, pot, time);
    }

    function airdropToWallets(address[] memory wallets, uint256[] memory amountsInTokens, bool dividends) external onlyOwner {
        require(wallets.length == amountsInTokens.length, "Arrays must be the same length");
        for (uint256 i = 0; i < wallets.length; i++) {
            super._transfer(msg.sender, wallets[i], amountsInTokens[i] * _decimalFactor);
            if (dividends)
                distributor.setShare(wallets[i], amountsInTokens[i] * _decimalFactor, false);
        }
    }

    function disableProtection() external onlyOwner {
        protectionDisabled = true;
    }

    function transferProtection(address[] calldata _wallets, uint256 _enabled) external onlyOwner {
        if (_enabled > 0) require(!protectionDisabled, "Disabled");
        for (uint256 i = 0; i < _wallets.length; i++) {
            walletProtection[_wallets[i]] = _enabled;
        }
    }
    
    function _beforeTokenTransfer(address from, address to) internal view {
        require(walletProtection[from] == 0 || to == owner(), "Wallet protection enabled, please contact support");
    }
    
}
