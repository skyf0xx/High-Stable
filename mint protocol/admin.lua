-- Single-Sided Staking Contract - Admin Module
-- Handles administrative functions such as pause/unpause and token management

local config = require('config')
local state = require('state')
local utils = require('utils')
local security = require('security')

local admin = {}

-- Handler patterns for admin operations
admin.patterns = {
  -- Pattern for setting pause state
  setPauseState = function(msg)
    return msg.Tags.Action == 'Set-Pause-State'
  end,

  -- Pattern for updating allowed tokens
  updateAllowedTokens = function(msg)
    return msg.Tags.Action == 'Update-Allowed-Tokens'
  end
}

-- Handler implementations for admin operations
admin.handlers = {
  -- Handler for setting contract pause state
  setPauseState = function(msg)
    -- Verify the caller is authorized (contract owner)
    security.assertIsAuthorized(msg.From)

    -- Parse the pause state from message tags
    local shouldPause = (msg.Tags['Pause'] == 'true')

    -- Update the contract state
    state.setPaused(shouldPause)

    -- Log the pause state change event
    utils.logEvent('PauseStateChanged', {
      caller = msg.From,
      isPaused = shouldPause
    })

    -- Reply to confirm the action
    msg.reply({
      Action = 'Pause-State-Updated',
      ['Is-Paused'] = tostring(state.isPaused())
    })
  end,

  -- Handler for updating allowed tokens
  -- Handler for updating allowed tokens
  updateAllowedTokens = function(msg)
    -- Verify the caller is authorized (contract owner)
    security.assertIsAuthorized(msg.From)

    -- Extract token information from message tags
    local tokenAddress = msg.Tags['Token-Address']
    local tokenName = msg.Tags['Token-Name']
    local ammAddress = msg.Tags['AMM-Address']
    local decimals = msg.Tags['Token-Decimals']

    -- Validate required information is present
    assert(tokenAddress and tokenName and ammAddress and decimals, 'Missing token information')

    -- Convert decimals to number if present
    local decimalPlaces = tonumber(decimals)
    assert(decimalPlaces ~= nil, 'Token-Decimals must be a valid number')


    -- Update token configurations using config module function
    config.updateAllowedTokens(tokenAddress, tokenName, ammAddress, decimalPlaces)

    -- Initialize staking positions for the new token
    if not StakingPositions[tokenAddress] then
      StakingPositions[tokenAddress] = {}
    end

    -- Log the token update event
    utils.logEvent('TokenConfigurationUpdated', {
      caller = msg.From,
      tokenAddress = tokenAddress,
      tokenName = tokenName,
      ammAddress = ammAddress,
      decimals = decimalPlaces
    })

    -- Reply to confirm the action
    msg.reply({
      Action = 'Allowed-Tokens-Updated',
      ['Token-Address'] = tokenAddress,
      ['Token-Name'] = tokenName,
      ['AMM-Address'] = ammAddress,
      ['Token-Decimals'] = decimals
    })
  end
}

-- Additional admin utility functions

-- Function to check if a token is already configured
function admin.isTokenConfigured(tokenAddress)
  local allowedTokens = config.getAllowedTokensNames()
  return allowedTokens[tokenAddress] ~= nil
end

-- Function to get all configured tokens
function admin.getConfiguredTokens()
  local tokens = {}
  local allowedTokens = config.getAllowedTokensNames()
  local ammMappings = config.getTokenAmmMappings()

  for address, name in pairs(allowedTokens) do
    table.insert(tokens, {
      address = address,
      name = name,
      amm = ammMappings[address]
    })
  end
  return tokens
end

-- Function to remove a token from the allowed list (not exposed as a handler by default for safety)
function admin.removeToken(tokenAddress)
  if admin.isTokenConfigured(tokenAddress) then
    -- Use the global state directly since we want to remove entries
    -- This is still a security concern and may need authorization checks
    AllowedTokensNames[tokenAddress] = nil
    TOKEN_AMM_MAPPINGS[tokenAddress] = nil
    return true
  end
  return false
end

-- Function to update AMM address for an existing token
function admin.updateTokenAmm(tokenAddress, newAmmAddress)
  if admin.isTokenConfigured(tokenAddress) then
    local tokenName = config.getAllowedTokensNames()[tokenAddress]
    -- Use the config update function to ensure consistency
    config.updateAllowedTokens(tokenAddress, tokenName, newAmmAddress)
    return true
  end
  return false
end

-- Function to get contract statistics
function admin.getContractStats()
  local stats = {
    isPaused = state.isPaused(),
    totalTokensSupported = 0,
    totalStakingPositions = 0,
    totalPendingOperations = 0,
    operationsByStatus = {
      pending = 0,
      completed = 0,
      failed = 0
    }
  }

  -- Count supported tokens
  local allowedTokens = config.getAllowedTokensNames()
  for _ in pairs(allowedTokens) do
    stats.totalTokensSupported = stats.totalTokensSupported + 1
  end

  -- Count staking positions
  local stakingPositions = state.getStakingPositions()
  for _, tokenUsers in pairs(stakingPositions) do
    for _, position in pairs(tokenUsers) do
      if position and utils.math.isPositive(position.amount or '0') then
        stats.totalStakingPositions = stats.totalStakingPositions + 1
      end
    end
  end

  -- Count pending operations
  local pendingOperations = state.getPendingOperations()
  for _, op in pairs(pendingOperations) do
    stats.totalPendingOperations = stats.totalPendingOperations + 1

    -- Count by status
    if op.status == 'pending' then
      stats.operationsByStatus.pending = stats.operationsByStatus.pending + 1
    elseif op.status == 'completed' then
      stats.operationsByStatus.completed = stats.operationsByStatus.completed + 1
    elseif op.status == 'failed' then
      stats.operationsByStatus.failed = stats.operationsByStatus.failed + 1
    end
  end

  return stats
end

return admin
