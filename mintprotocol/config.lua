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
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'AO Token (AO)',
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = 'Ethereum-Wrapped USDC (USDC)'
}

config.TOKEN_AMM_MAPPINGS = config.TOKEN_AMM_MAPPINGS or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'Ruw6Q5gVgZ-isWhRGW4LVvTu6rMost-J5SKsF4rF-rA', -- MINT/ qAR AMM -
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'UxLqhlBkIITPypglQOOrtcTQddFJU4utYFkwDqFbV7g', -- MINT/ wAR AMM -
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 'Lt0PKHQCFxXkXjJVd5CV2tRIlXe55hs4cQ8_OY9JgsI', -- MINT/ NAB AMM -
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'DMB9l4HSp-9qBvXtxDqDTnZZ3qFNCwJgivwSv0XEgN0', -- MINT/ AO AMM -
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = 'oudDA-JUZi14kbKFIhu4X34qGYHbtZnHdtYWEqbtkO0', -- MINT/ USDC AMM -
}


config.LP_DECIMALS = config.LP_DECIMALS or {
  ['Ruw6Q5gVgZ-isWhRGW4LVvTu6rMost-J5SKsF4rF-rA'] = 12,
  ['cmZi84AA3f717pna0ck-gM93wq1j1exRdNLdt7saG9o'] = 12,
  ['Lt0PKHQCFxXkXjJVd5CV2tRIlXe55hs4cQ8_OY9JgsI'] = 12,
  ['DMB9l4HSp-9qBvXtxDqDTnZZ3qFNCwJgivwSv0XEgN0'] = 12,
  ['oudDA-JUZi14kbKFIhu4X34qGYHbtZnHdtYWEqbtkO0'] = 12,
}


-- Token decimals mapping - defines how many decimal places each token uses
config.TOKEN_DECIMALS = config.TOKEN_DECIMALS or {
  -- MINT token decimal places
  [config.MINT_TOKEN] = 8,

  -- Other tokens decimal places
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 12, -- qAR (12 decimals)
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 12, -- wAR (12 decimals)
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 8,  -- NAB (8 decimals)
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 12, -- AO (12 decimals)
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = 6,  -- USDC (6 decimals)
}


-- Impermanent loss protection parameters
config.IL_MAX_VESTING_DAYS = 30          -- T_max: full vesting period in days
config.IL_MAX_COVERAGE_PERCENTAGE = '50' -- C_max: maximum coverage percentage (50%)
config.IL_COVERAGE_DIVISOR = '100'       -- Divisor for percentage calculations
-- Maximum compensation per user: e.g. 100 MINT tokens (with 8 decimal places)
local MINT_MAX_COMP = 50000
local MINT_DECIMALS = config.TOKEN_DECIMALS[config.MINT_TOKEN] -- Get decimals from config
config.IL_MAX_COMP_PER_USER = tostring(MINT_MAX_COMP * 10 ^ MINT_DECIMALS)



-- Direct access to standard config values
config.OPERATION_TIMEOUT = 3600000 -- 1 hour timeout in miliseconds

-- Staking excess multiplier for MINT tokens
config.EXCESS_MULTIPLIER = '1090' -- 109.0% - to ensure all user tokens are used
config.EXCESS_DIVISOR = '1000'

-- AMM slippage tolerance
config.SLIPPAGE_TOLERANCE = '20'

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
config.updateAllowedTokens = function(tokenAddress, tokenName, ammAddress, decimals, lpDecimals)
  config.AllowedTokensNames[tokenAddress] = tokenName
  config.TOKEN_AMM_MAPPINGS[tokenAddress] = ammAddress
  config.LP_DECIMALS[ammAddress] = lpDecimals
  config.TOKEN_DECIMALS[tokenAddress] = decimals

  return true
end

-- Get decimals for a specific token
config.getDecimalsForToken = function(tokenAddress)
  local decimals = config.TOKEN_DECIMALS[tokenAddress]
  if decimals then
    return decimals
  end
end

config.getDecimalsForLP = function(tokenAddress)
  local decimals = config.LP_DECIMALS[tokenAddress]
  if decimals then
    return decimals
  end
end

return config
