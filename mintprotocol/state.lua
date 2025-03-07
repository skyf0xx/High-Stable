-- Single-Sided Staking Contract - State Module
-- Manages all state variables and provides accessor functions

local bint = require('.bint')(256)
local config = require('mintprotocol.config')

local state = {}

-- Global state variables - initialized with defaults if not already set
-- These will be exported to global scope for contract storage
IsPaused = IsPaused or false
StakingPositions = StakingPositions or {}
PendingOperations = PendingOperations or {}

-- Initialize state variables
function state.initialize()
  -- Initialize staking positions for allowed tokens
  for token, _ in pairs(config.AllowedTokensNames) do
    StakingPositions[token] = StakingPositions[token] or {}
  end

  -- Log initialization status
  print(config.Colors.GRAY .. '[State] Initialized state management' .. config.Colors.RESET)
end

-- Accessor functions for reading state

-- Check if contract is paused
function state.isPaused()
  return IsPaused
end

-- Get staking positions
function state.getStakingPositions()
  return StakingPositions
end

-- Get pending operations
function state.getPendingOperations()
  return PendingOperations
end

-- Get a specific staking position
function state.getStakingPosition(token, user)
  if not StakingPositions[token] then
    return nil
  end
  return StakingPositions[token][user]
end

-- Get a specific pending operation
function state.getPendingOperation(id)
  return PendingOperations[id]
end

-- Functions to update state

-- Set or update pause state
function state.setPaused(paused)
  IsPaused = paused
end

-- Set or update a staking position
function state.setStakingPosition(token, user, position)
  StakingPositions[token] = StakingPositions[token] or {}
  StakingPositions[token][user] = position
end

-- Initialize a staking position if it doesn't exist
function state.initializeStakingPosition(token, user)
  if not StakingPositions[token] then
    StakingPositions[token] = {}
  end

  if not StakingPositions[token][user] then
    StakingPositions[token][user] = {
      amount = '0',
      lpTokens = '0',
      mintAmount = '0',
      stakedDate = nil,
      initialPriceRatio = nil -- Add field to store initial X/MINT ratio
    }
  end

  return StakingPositions[token][user]
end

-- Clear a staking position
function state.clearStakingPosition(token, user)
  if StakingPositions[token] and StakingPositions[token][user] then
    StakingPositions[token][user] = {
      amount = '0',
      lpTokens = '0',
      mintAmount = '0',
      stakedDate = nil
    }
  end
end

-- Update a staking position
function state.updateStakingPosition(token, user, updates)
  if not StakingPositions[token] or not StakingPositions[token][user] then
    return false
  end

  for key, value in pairs(updates) do
    StakingPositions[token][user][key] = value
  end

  return true
end

-- Set a pending operation
function state.setPendingOperation(id, operation)
  PendingOperations[id] = operation
end

-- Update a pending operation
function state.updatePendingOperation(id, updates)
  if not PendingOperations[id] then
    return false
  end

  for key, value in pairs(updates) do
    PendingOperations[id][key] = value
  end

  return true
end

-- Complete a pending operation
function state.completePendingOperation(id)
  if not PendingOperations[id] then
    return false
  end

  PendingOperations[id].status = 'completed'
  return true
end

-- Fail a pending operation
function state.failPendingOperation(id)
  if not PendingOperations[id] then
    return false
  end

  PendingOperations[id].status = 'failed'
  return true
end

-- Remove a pending operation
function state.removePendingOperation(id)
  PendingOperations[id] = nil
end

-- Count number of pending operations
function state.countPendingOperations()
  local count = 0
  for _ in pairs(PendingOperations) do
    count = count + 1
  end
  return count
end

-- Get all staking positions for a user
function state.getUserStakingPositions(user)
  local positions = {}

  for token, tokenPositions in pairs(StakingPositions) do
    if tokenPositions[user] then
      positions[token] = tokenPositions[user]
    end
  end

  return positions
end

-- Check if a user has any staking positions
function state.hasStakingPositions(user)
  for _, tokenPositions in pairs(StakingPositions) do
    if tokenPositions[user] and bint(tokenPositions[user].amount) > bint.zero() then
      return true
    end
  end

  return false
end

return state
