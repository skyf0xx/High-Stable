-- Single-Sided Staking Contract - Configuration Module
-- Contains all constants and configuration settings

local config = {}

-- Token constants
config.MINT_TOKEN = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'

-- Initialize configuration state from existing globals or use defaults
config.AllowedTokensNames = config.AllowedTokensNames or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'Q Arweave (qAR)',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'Wrapped AR (wAR)',
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 'Number Always Bigger (NAB)',
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'AO (AO Token)',
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = 'USDC (Ethereum-Wrapped USDC)'
}

config.TOKEN_AMM_MAPPINGS = config.TOKEN_AMM_MAPPINGS or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'VBx1jKKKkr7t4RkJg8axqZY2eNpDZSOxVhcGwF5tWAA', -- MINT/ qAR AMM
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'pX0L5GY09W-EL1zcjrGPYVy-B3iu5HWF53S2_GY0ViI', -- MINT/ wAR AMM
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 'AzxYcLUMPJvjz9LPJ-A-6yzwW9ScQYl8TLVL-84y2PE', -- MINT/ NAB AMM
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'a98-hjIuPJeK89RwZ3jMkoN2iOuQkTkKrMWi4O3DRIY', -- MINT/ AO AMM
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = 'a98-hjIuPJeK89RwZ3jMkoN2iOuQkTkKrMWi4O3DRIY', -- MINT/ USDC AMM
}


-- Reference global state for allowed tokens configuration
-- This ensures the config module always reflects current state
config.getAllowedTokensNames = function()
  return config.AllowedTokensNames or {}
end

config.getTokenAmmMappings = function()
  return config.TOKEN_AMM_MAPPINGS or {}
end

-- Direct access to standard config values
config.OPERATION_TIMEOUT = 3600000 -- 1 hour timeout in miliseconds

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


-- Functions to update config values (for use by admin module)
config.updateAllowedTokens = function(tokenAddress, tokenName, ammAddress)
  -- Update global state
  config.AllowedTokensNames = config.AllowedTokensNames or {}
  config.TOKEN_AMM_MAPPINGS = config.TOKEN_AMM_MAPPINGS or {}

  config.AllowedTokensNames[tokenAddress] = tokenName
  config.TOKEN_AMM_MAPPINGS[tokenAddress] = ammAddress

  return true
end

return config
