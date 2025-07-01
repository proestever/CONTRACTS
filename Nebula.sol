/*
    _   ____________  __  ____    ___ 
   / | / / ____/ __ )/ / / / /   /   |
  /  |/ / __/ / __  / / / / /   / /| |
 / /|  / /___/ /_/ / /_/ / /___/ ___ |
/_/ |_/_____/_____/\____/_____/_/  |_|
                                      
' SPDX-License-Identifier: MIT
' BY ✷ GIGA ✷ t.me/giga_doge
' Fork of PulseX Farms

*/
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./RewardToken.sol";

// Nebula staking contract for star token farming
contract Nebula is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Info of each user
    struct UserInfo {
        uint256 amount; // Staked LP tokens
        uint256 rewardDebt; // Reward debt
    }

    // Info of each pool
    struct PoolInfo {
        IERC20 lpToken; // LP token contract
        uint256 allocPoint; // Allocation points for this pool
        uint256 lastRewardTime; // Last time rewards were calculated
        uint256 accstarPerShare; // Accumulated star per share, times 1e12
        bool paused; // Pool pause status
    }

    RewardToken public star; // Reward token
    uint256 public starPerSecond; // star tokens created per second
    uint256 public constant MAX_star_PER_SECOND = 1e18; // Max 1 star per second
    uint256 public constant MIN_star_PER_SECOND = 1e15; // Min 0.001 star per second
    uint256 public constant MAX_ALLOC_POINT = 4000; // Max allocation points
    uint256 public immutable startTime; // When star mining starts

    PoolInfo[] public poolInfo; // Array of pool info
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // User info per pool
    uint256 public totalAllocPoint; // Sum of all allocation points

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event PoolAdded(uint256 indexed pid, address lpToken, uint256 allocPoint);
    event PoolUpdated(uint256 indexed pid, uint256 allocPoint);
    event starPerSecondUpdated(uint256 oldRate, uint256 newRate);
    event PoolPaused(uint256 indexed pid, bool paused);

    constructor(
        RewardToken _star,
        uint256 _starPerSecond,
        uint256 _startTime
    ) Ownable(msg.sender) {
        require(_starPerSecond <= MAX_star_PER_SECOND, "star per second too high");
        require(_starPerSecond >= MIN_star_PER_SECOND, "star per second too low");
        require(_startTime >= block.timestamp, "Start time in past");

        star = _star;
        starPerSecond = _starPerSecond;
        startTime = _startTime;
    }

    /// @notice Returns the number of pools
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /// @notice Updates star per second, with bounds checking
    /// @param _starPerSecond New star per second rate
    function setstarPerSecond(uint256 _starPerSecond) external onlyOwner {
        require(_starPerSecond <= MAX_star_PER_SECOND, "star per second too high");
        require(_starPerSecond >= MIN_star_PER_SECOND, "star per second too low");

        massUpdatePools();
        emit starPerSecondUpdated(starPerSecond, _starPerSecond);
        starPerSecond = _starPerSecond;
    }

    /// @notice Checks for duplicate LP tokens
    /// @param _lpToken LP token to check
    function checkForDuplicate(IERC20 _lpToken) internal view {
        for (uint256 pid = 0; pid < poolInfo.length; pid++) {
            require(poolInfo[pid].lpToken != _lpToken, "Duplicate pool");
        }
    }

    /// @notice Adds a new LP pool
    /// @param _allocPoint Allocation points for the pool
    /// @param _lpToken LP token contract
    function add(uint256 _allocPoint, IERC20 _lpToken) external onlyOwner {
        require(_allocPoint <= MAX_ALLOC_POINT, "Alloc points too high");
        checkForDuplicate(_lpToken);

        massUpdatePools();

        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint += _allocPoint;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardTime: lastRewardTime,
            accstarPerShare: 0,
            paused: false
        }));

        emit PoolAdded(poolInfo.length - 1, address(_lpToken), _allocPoint);
    }

    /// @notice Updates a pool's allocation points
    /// @param _pid Pool ID
    /// @param _allocPoint New allocation points
    function set(uint256 _pid, uint256 _allocPoint) external onlyOwner {
        require(_pid < poolInfo.length, "Invalid pool ID");
        require(_allocPoint <= MAX_ALLOC_POINT, "Alloc points too high");
        require(totalAllocPoint >= poolInfo[_pid].allocPoint - _allocPoint, "Total alloc underflow");

        massUpdatePools();

        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;

        emit PoolUpdated(_pid, _allocPoint);
    }

    /// @notice Pauses or unpauses a pool
    /// @param _pid Pool ID
    /// @param _paused Pause status
    function setPoolPaused(uint256 _pid, bool _paused) external onlyOwner {
        require(_pid < poolInfo.length, "Invalid pool ID");
        poolInfo[_pid].paused = _paused;
        emit PoolPaused(_pid, _paused);
    }

    /// @notice Calculates reward multiplier between two timestamps
    /// @param _from Start time
    /// @param _to End time
    /// @return Multiplier
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        _from = _from > startTime ? _from : startTime;
        if (_to < startTime) return 0;
        return _to - _from;
    }

    /// @notice Views pending star for a user
    /// @param _pid Pool ID
    /// @param _user User address
    /// @return Pending star
    function pendingstar(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accstarPerShare = pool.accstarPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.timestamp > pool.lastRewardTime && lpSupply != 0 && !pool.paused) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 starReward = multiplier * starPerSecond * pool.allocPoint / totalAllocPoint;
            accstarPerShare += starReward * 1e12 / lpSupply;
        }
        return user.amount * accstarPerShare / 1e12 - user.rewardDebt;
    }

    /// @notice Updates all pools
    function massUpdatePools() public {
        for (uint256 pid = 0; pid < poolInfo.length; pid++) {
            updatePool(pid);
        }
    }

    /// @notice Updates a specific pool
    /// @param _pid Pool ID
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime || pool.paused) return;

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 starReward = multiplier * starPerSecond * pool.allocPoint / totalAllocPoint;

        star.mint(address(this), starReward);
        pool.accstarPerShare += starReward * 1e12 / lpSupply;
        pool.lastRewardTime = block.timestamp;
    }

    /// @notice Deposits LP tokens to a pool
    /// @param _pid Pool ID
    /// @param _amount Amount to deposit
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_pid < poolInfo.length, "Invalid pool ID");
        PoolInfo storage pool = poolInfo[_pid];
        require(!pool.paused, "Pool is paused");
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        uint256 pending = user.amount * pool.accstarPerShare / 1e12 - user.rewardDebt;

        user.amount += _amount;
        user.rewardDebt = user.amount * pool.accstarPerShare / 1e12;

        if (pending > 0) {
            safestarTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _pid, _amount);
    }

    /// @notice Withdraws LP tokens from a pool
    /// @param _pid Pool ID
    /// @param _amount Amount to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_pid < poolInfo.length, "Invalid pool ID");
        PoolInfo storage pool = poolInfo[_pid];
        require(!pool.paused, "Pool is paused");
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "Insufficient balance");

        updatePool(_pid);

        uint256 pending = user.amount * pool.accstarPerShare / 1e12 - user.rewardDebt;

        user.amount -= _amount;
        user.rewardDebt = user.amount * pool.accstarPerShare / 1e12;

        if (pending > 0) {
            safestarTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @notice Emergency withdraw without rewards
    /// @param _pid Pool ID
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        require(_pid < poolInfo.length, "Invalid pool ID");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;

        user.amount = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    /// @notice Safely transfers star tokens
    /// @param _to Recipient address
    /// @param _amount Amount to transfer
    function safestarTransfer(address _to, uint256 _amount) internal {
        uint256 starBal = star.balanceOf(address(this));
        if (_amount > starBal) {
            star.transfer(_to, starBal);
        } else {
            star.transfer(_to, _amount);
        }
    }
}