-- Single-Sided Staking Contract - Admin Module
-- Handles administrative functions such as pause/unpause and token management

local config = require('mintprotocol.config')
local state = require('mintprotocol.state')
local utils = require('mintprotocol.utils')
local security = require('mintprotocol.security')

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

return admin
