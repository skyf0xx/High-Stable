-- Single-Sided Staking Contract - Configuration Module
-- Contains all constants and configuration settings

local config = {}

-- Token constants
config.MINT_TOKEN = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'

-- Reference global state for allowed tokens configuration
-- This ensures the config module always reflects current state
config.getAllowedTokensNames = function()
  return AllowedTokensNames or {}
end

config.getTokenAmmMappings = function()
  return TOKEN_AMM_MAPPINGS or {}
end

-- Direct access to standard config values
config.OPERATION_TIMEOUT = 3600 -- 1 hour timeout in seconds

-- Staking excess multiplier for MINT tokens
config.EXCESS_MULTIPLIER = '1090' -- 109.0% - to ensure all user tokens are used
config.EXCESS_DIVISOR = '1000'

-- AMM slippage tolerance
config.SLIPPAGE_TOLERANCE = '0.5' -- 0.5% slippage tolerance for AMM operations

-- Impermanent loss protection settings
config.IL_COMPENSATION_MARGIN = '110' -- 110% (10% safety margin for IL compensation)
config.IL_COMPENSATION_DIVISOR = '100'

-- Fee sharing settings
config.PROTOCOL_FEE_PERCENTAGE = '1' -- 1% protocol fee
config.USER_SHARE_PERCENTAGE = '99'  -- 99% user share
config.FEE_DIVISOR = '100'

-- Contract version
config.VERSION = '1.0.0'

-- Colors for logging
config.Colors = {
  BLUE = Colors.blue,
  GRAY = Colors.gray,
  GREEN = Colors.green,
  RED = Colors.red,
  RESET = Colors.reset
}

-- Alias for backwards compatibility and simpler code
-- (Allows other modules to directly access these without using getter functions)
setmetatable(config, {
  __index = function(t, k)
    if k == 'AllowedTokensNames' then
      return config.getAllowedTokensNames()
    elseif k == 'TOKEN_AMM_MAPPINGS' then
      return config.getTokenAmmMappings()
    end
    return rawget(t, k)
  end
})

-- Functions to update config values (for use by admin module)
config.updateAllowedTokens = function(tokenAddress, tokenName, ammAddress)
  -- Update global state
  AllowedTokensNames = AllowedTokensNames or {}
  TOKEN_AMM_MAPPINGS = TOKEN_AMM_MAPPINGS or {}

  AllowedTokensNames[tokenAddress] = tokenName
  TOKEN_AMM_MAPPINGS[tokenAddress] = ammAddress

  return true
end

return config
