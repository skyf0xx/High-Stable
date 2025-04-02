-- Single-Sided Staking Contract - Operations Module
-- Handles tracking, cleanup, and management of pending operations

local config = require('mintprotocol.config')
local state = require('mintprotocol.state')
local utils = require('mintprotocol.utils')
local security = require('mintprotocol.security')

local operations = {}

-- Handler patterns
operations.patterns = {
  -- Pattern for cleanup operation
  cleanup = function(msg)
    return msg.Tags.Action == 'Cleanup'
  end
}

-- Clean up stale pending operations (older than the configured timeout)
operations.cleanStaleOperations = function()
  local now = os.time()
  local pendingOperations = state.getPendingOperations()
  local staleIds = {}

  -- Identify stale operations
  for id, op in pairs(pendingOperations) do
    if op.timestamp and (now - op.timestamp) > config.OPERATION_TIMEOUT then
      table.insert(staleIds, id)
    end
  end

  -- Remove stale operations
  for _, id in ipairs(staleIds) do
    state.removePendingOperation(id)
  end

  return #staleIds
end

-- Create a new operation
operations.createOperation = function(type, token, sender, amount, amm, additionalFields)
  local opId = utils.operationId(sender, token, type)

  local operation = {
    id = opId,
    type = type,
    token = token,
    sender = sender,
    amount = amount,
    amm = amm,
    status = 'pending',
    timestamp = os.time()
  }

  -- Merge any additional fields provided
  if additionalFields then
    for k, v in pairs(additionalFields) do
      operation[k] = v
    end
  end

  state.setPendingOperation(opId, operation)
  return opId, operation
end

-- Update operation status
operations.updateStatus = function(id, status)
  return state.updatePendingOperation(id, { status = status })
end

-- Complete an operation
operations.complete = function(id)
  return state.completePendingOperation(id)
end

-- Fail an operation with a reason
operations.fail = function(id, reason)
  return state.failPendingOperation(id, reason)
end

-- Get operation details
operations.get = function(id)
  return state.getPendingOperation(id)
end

-- Check if operation exists
operations.exists = function(id)
  return state.getPendingOperation(id) ~= nil
end

-- Check if operation is in specific state
operations.isInState = function(id, expectedState)
  local operation = state.getPendingOperation(id)
  return operation and operation.status == expectedState
end

-- Check if operation has timed out
operations.hasTimedOut = function(id)
  local operation = state.getPendingOperation(id)
  if not operation or not operation.timestamp then
    return false
  end

  return (os.time() - operation.timestamp) > config.OPERATION_TIMEOUT
end

-- Count operations by status
operations.countByStatus = function(status)
  local count = 0
  local pendingOperations = state.getPendingOperations()

  for _, op in pairs(pendingOperations) do
    if op.status == status then
      count = count + 1
    end
  end

  return count
end

operations.cleanStaleLocks = function()
  local now = os.time()
  local staleLockTimeout = 600 -- 10 minutes in seconds
  local unlockedTokens = {}

  -- Check each locked token
  for token, lockInfo in pairs(StakingLocks or {}) do
    if (now - lockInfo.lockedAt) > staleLockTimeout then
      -- This is a stale lock that needs to be cleaned up
      state.unlockTokenForStaking(token)
      table.insert(unlockedTokens, token)

      utils.logEvent('StaleLockRemoved', {
        token = token,
        tokenName = config.AllowedTokensNames[token],
        lockedBy = lockInfo.lockedBy,
        lockedAt = lockInfo.lockedAt,
        duration = now - lockInfo.lockedAt,
        operationId = lockInfo.operationId,
        clientOperationId = lockInfo.clientOperationId
      })
    end
  end

  return unlockedTokens
end

-- Handler implementations
operations.handlers = {
  -- Handler for cleanup operation
  cleanup = function(msg)
    security.assertIsAuthorized(msg.From)

    local startCount = state.countPendingOperations()
    local removedCount = operations.cleanStaleOperations()

    -- Also clean up stale locks
    local unlockedTokens = operations.cleanStaleLocks()
    local unlockedCount = #unlockedTokens

    local endCount = state.countPendingOperations()

    utils.logEvent('CleanupCompleted', {
      caller = msg.From,
      operationsBeforeCleanup = startCount,
      operationsAfterCleanup = endCount,
      operationsRemoved = removedCount,
      locksRemoved = unlockedCount
    })

    msg.reply({
      Action = 'Cleanup-Complete',
      ['Operations-Removed'] = tostring(removedCount),
      ['Locks-Removed'] = tostring(unlockedCount),
      ['Timestamp'] = tostring(os.time())
    })
  end
}

return operations
