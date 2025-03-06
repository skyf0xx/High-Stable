-- Single-Sided Staking Contract - Main Entry Point
-- This file imports all modules and registers handlers

-- Import all modules
local state = require('state')
local stake = require('stake')
local unstake = require('unstake')
local operations = require('operations')
local admin = require('admin')
local query = require('query')

-- Initialize contract state
state.initialize()

-- Register all handlers
local function registerHandlers()
  -- Admin handlers
  Handlers.add('set-pause-state', admin.patterns.setPauseState, admin.handlers.setPauseState)
  Handlers.add('update-allowed-tokens', admin.patterns.updateAllowedTokens, admin.handlers.updateAllowedTokens)

  -- Staking handlers
  Handlers.add('stake', stake.patterns.stake, stake.handlers.stake)
  Handlers.add('fund-stake', stake.patterns.fundStake, stake.handlers.fundStake)
  Handlers.add('provide-confirmation', stake.patterns.provideConfirmation, stake.handlers.provideConfirmation)

  -- Unstaking handlers
  Handlers.add('unstake', unstake.patterns.unstake, unstake.handlers.unstake)
  Handlers.add('burn-confirmation', unstake.patterns.burnConfirmation, unstake.handlers.burnConfirmation)

  -- Query handlers
  Handlers.add('get-position', query.patterns.getPosition, query.handlers.getPosition)
  Handlers.add('get-all-positions', query.patterns.getAllPositions, query.handlers.getAllPositions)
  Handlers.add('get-allowed-tokens', query.patterns.getAllowedTokens, query.handlers.getAllowedTokens)
  Handlers.add('get-insurance-info', query.patterns.getInsuranceInfo, query.handlers.getInsuranceInfo)
  Handlers.add('get-protocol-metrics', query.patterns.getProtocolMetrics, query.handlers.getProtocolMetrics)


  -- Error handlers
  Handlers.add('provide-error', stake.patterns.provideError, stake.handlers.provideError)
  Handlers.add('refund-unused', stake.patterns.refundUnused, stake.handlers.refundUnused)

  -- Maintenance handlers
  Handlers.add('cleanup-stale-operations', operations.patterns.cleanup, operations.handlers.cleanup)
end

-- Log contract initialization
print(Colors.blue .. 'Single-Sided Staking Contract Initialized' .. Colors.reset)

-- Register all handlers
registerHandlers()
