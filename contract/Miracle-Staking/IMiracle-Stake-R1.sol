// SPDX-License-Identifier: UNLICENSED

/* 
*This code is subject to the Copyright License
* Copyright (c) 2023 Sevenlinelabs
* All rights reserved.
*/
pragma solidity ^0.8.17;

// Token
import "@thirdweb-dev/contracts/drop/DropERC1155.sol"; // For my collection of Node
import "@thirdweb-dev/contracts/token/TokenERC20.sol"; // For my ERC-20 Token contract

// Access Control + security
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./module/Miralce-Stake-Core.sol";

contract StakeMiracleR1 is StakeMiracleCore
{
    constructor(address _defaultAdmin, uint256 _stakingsection, DropERC1155 _NodeNFTToken, TokenERC20 _RewardToken, address _DaoAddress, uint256 _rewardPerMin) {
        StakingSection = _stakingsection;
        IStakingSection = _stakingsection - 1;
        
        NodeNftCollection = _NodeNFTToken;
        rewardsToken = _RewardToken;
        DaoAddress = _DaoAddress;
        rewardPerMin = _rewardPerMin;
        
        //Fee Definition
        DaoRoyalty = [10, 15, 20, 25, 30, 35, 40, 45, 50];
        PoolRoyalty = 5;
        AgentRoyalty = 2;

        // Initialize this contract's state.
        PausePool = false;
        PauseClaim = false;
        _owner = _defaultAdmin;
        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    // ===================================================================================
    // User Function 
    // ===================================================================================
    function stake(uint256 _depositAmount, uint256 _poolID) external nonReentrant{
        _stake(msg.sender, _depositAmount, _poolID);
    }

    function withdraw(uint256 _withdrawAmount) external nonReentrant {
        _withdraw(msg.sender, _withdrawAmount);
    }

    function claim() external nonReentrant {
        _claim(msg.sender);
    }

    function claimAgent(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant{
        _claimAgent(_user);
    }

    function calculateRewards() external view returns (uint256 _MyReward, uint256 _DaoReward, uint256 _PoolReward) {
        (_MyReward, _DaoReward, _PoolReward) = _calculateRewards(msg.sender);
    }

    function calculateAgentRewards() external view returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward, uint256 _AgentReward) {
        (_PlayerReward, _DaoReward, _PoolReward, _AgentReward) = _calculateAgentRewards(msg.sender);
    }

    // ===================================================================================
    // Admin Function 
    // ===================================================================================
    function adminStake(address _user, uint256 _depositAmount, uint256 _poolID) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _stake(_user, _depositAmount, _poolID);
    }

    function adminWithdraw(address _user, uint256 _withdrawAmount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _withdraw(_user, _withdrawAmount);
    }

    function calculateRewardsUser(address _user) external view returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward) {
        (_PlayerReward, _DaoReward, _PoolReward) = _calculateRewards(_user);
    }

    function calculateAgentRewardsUser(address _user) external view returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward, uint256 _AgentReward) {
        (_PlayerReward, _DaoReward, _PoolReward, _AgentReward) = _calculateAgentRewards(_user);
    }

    // ===================================================================================
    // Stake pool status 
    // ===================================================================================
    function getStakePlayerCount() external view returns (uint256 _playerCount) {
        return _getStakePlayerCount();
    }

    function getStakePlayers() external view returns (address[] memory _stakeplayers){
        return _getStakePlayers();
    }

    function getStakingPool(uint256 _PoolSeq) external view returns (address _poolAddress) {
        return _getStakingPool(_PoolSeq);
    }

    function getTotalUnClaim() external view returns (uint256 _totalUnClaim) {
        return _getTotalUnClaim();
    }
}