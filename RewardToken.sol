// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

// RewardToken for staking rewards
contract RewardToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    constructor() ERC20("RewardToken", "RWD") ERC20Permit("RewardToken") Ownable(msg.sender) {
        // Initial mint to deployer for liquidity or other purposes
        _mint(msg.sender, 1_000_000 * 10**18); // 1M tokens
    }

    /// @notice Mints new tokens, only callable by owner (MasterChef)
    /// @param _to Recipient address
    /// @param _amount Amount to mint
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}