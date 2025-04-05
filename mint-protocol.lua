-- Single-Sided Staking Contract - Main Entry Point
-- This file imports all modules and registers handlers
-- Add this at the beginning of mint-protocol.lua

-- Import all modules
local stake = require('mintprotocol.stake')
local unstake = require('mintprotocol.unstake')
local operations = require('mintprotocol.operations')
local admin = require('mintprotocol.admin')
local rewards = require('mintprotocol.rewards')
local query = require('mintprotocol.query')


-- Admin handlers
Handlers.once('initialize-state', admin.patterns.initState, admin.handlers.initState)
Handlers.add('set-pause-state', admin.patterns.setPauseState, admin.handlers.setPauseState)
Handlers.add('update-allowed-tokens', admin.patterns.updateAllowedTokens, admin.handlers.updateAllowedTokens)
Handlers.add('manual-unlock-token', admin.patterns.manualUnlockToken, admin.handlers.manualUnlockToken)


-- Staking handlers
Handlers.add('stake', stake.patterns.stake, stake.handlers.stake)
Handlers.add('provide-confirmation', stake.patterns.provideConfirmation, stake.handlers.provideConfirmation)

-- Unstaking handlers
Handlers.add('unstake', unstake.patterns.unstake, unstake.handlers.unstake)
Handlers.add('burn-info', unstake.patterns.burnInfo, unstake.handlers.burnInfo)
Handlers.add('token-receipt', unstake.patterns.tokenReceipt, unstake.handlers.tokenReceipt)


-- Rewards handlers
Handlers.add('request-rewards', rewards.patterns.requestRewards, rewards.handlers.requestRewards)
Handlers.add('get-reward-stats', rewards.patterns.getRewardStats, rewards.handlers.getRewardStats)
Handlers.add('get-stake-ownership', rewards.patterns.getStakeOwnership, rewards.handlers.getStakeOwnership)
Handlers.add('get-unique-stakers', rewards.patterns.getUniqueStakers, rewards.handlers.getUniqueStakers)
Handlers.add('get-token-stakes', rewards.patterns.getTokenStakes, rewards.handlers.getTokenStakes)
Handlers.add('update-mint-supply', rewards.patterns.updateMintSupply, rewards.handlers.updateMintSupply)


-- Query handlers
Handlers.add('get-position', query.patterns.getPosition, query.handlers.getPosition)
Handlers.add('get-all-positions', query.patterns.getAllPositions, query.handlers.getAllPositions)
Handlers.add('get-allowed-tokens', query.patterns.getAllowedTokens, query.handlers.getAllowedTokens)
Handlers.add('get-insurance-info', query.patterns.getInsuranceInfo, query.handlers.getInsuranceInfo)
Handlers.add('get-protocol-metrics', query.patterns.getProtocolMetrics, query.handlers.getProtocolMetrics)
Handlers.add('get-positions-for-token', query.patterns.getPositionsForToken, query.handlers.getPositionsForToken)
Handlers.add('get-user-operations', query.patterns.getUserOperations, query.handlers.getUserOperations)
Handlers.add('get-locked-tokens', query.patterns.getLockedTokens, query.handlers.getLockedTokens)



-- Error handlers
Handlers.add('provide-error', stake.patterns.provideError, stake.handlers.provideError)
Handlers.add('refund-unused', stake.patterns.refundUnused, stake.handlers.refundUnused)

-- Maintenance handlers
Handlers.add('cleanup-stale-operations', operations.patterns.cleanup, operations.handlers.cleanup)
