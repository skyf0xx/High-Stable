-- Single-Sided Staking Contract - Configuration Module
-- Contains all constants and configuration settings

local config = {}

-- Token constants
config.MINT_TOKEN = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'
config.MINT_TESTNET_TOKEN = '7-N7TurGPjbG6tsVijXskYk-OwBbEpGH9o6h9y1dLXY' --'_8pubNOSHLFNaSMHtCNIhFW68XUuLmwiH6ALHtNDzlQ'

-- Initialize configuration state from existing globals or use defaults
config.AllowedTokensNames = config.AllowedTokensNames or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'Q Arweave (qAR)',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'Wrapped AR (wAR)',
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 'Number Always Bigger (NAB)',
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'AO Token (AO)',
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = 'Ethereum-Wrapped USDC (USDC)',
  ['U09Pg31Wlasc8ox5uTDm9sjFQT8XKcCR2Ru5lmFMe2A'] = 'Test Tube Token (TTT)',
  ['XQhUXernOkcwzrNq5U1KlAhHsqLnT3kA4ccAxfQR7XM'] = 'MATRIX (MATRIX)',
  ['s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE'] = 'ArcAO (GAME)',
}




-- Token weights for rewards
config.AllowedTokenWeights = config.AllowedTokenWeights or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = '9000000',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = '9000000',
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = '10000',
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = '20000000',
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = '2000000',
  ['U09Pg31Wlasc8ox5uTDm9sjFQT8XKcCR2Ru5lmFMe2A'] = '0',
  ['XQhUXernOkcwzrNq5U1KlAhHsqLnT3kA4ccAxfQR7XM'] = '1',
  ['s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE'] = '2000000',
}

-- Mapping from staked token to the MINT token it should use
config.STAKED_TOKEN_TO_MINT_TOKEN = config.STAKED_TOKEN_TO_MINT_TOKEN or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = config.MINT_TOKEN,         -- qAR uses main MINT
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = config.MINT_TOKEN,         -- wAR uses main MINT
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = config.MINT_TOKEN,         -- NAB uses main MINT
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = config.MINT_TOKEN,         -- AO uses main MINT
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = config.MINT_TOKEN,         -- USDC uses main MINT
  ['U09Pg31Wlasc8ox5uTDm9sjFQT8XKcCR2Ru5lmFMe2A'] = config.MINT_TESTNET_TOKEN, -- Test Tube Token uses testnet MINT
  ['XQhUXernOkcwzrNq5U1KlAhHsqLnT3kA4ccAxfQR7XM'] = config.MINT_TESTNET_TOKEN, -- MATRIX Token uses testnet MINT
  ['s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE'] = config.MINT_TOKEN,         -- GAME Token uses main MINT
}

config.TOKEN_AMM_MAPPINGS = config.TOKEN_AMM_MAPPINGS or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'WjLpu62JJqXQIjXPBmCkoyWNvTJs4muOKcxdAieEmAY', -- MINT/ qAR AMM -
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'UxLqhlBkIITPypglQOOrtcTQddFJU4utYFkwDqFbV7g', -- MINT/ wAR AMM -
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 'Lt0PKHQCFxXkXjJVd5CV2tRIlXe55hs4cQ8_OY9JgsI', -- MINT/ NAB AMM -
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'mqJsHpuJLk77PB0pVCv47KqT3U_xY_ZHQQwHvzUAsWY', -- MINT/ AO AMM -
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = 'eKECsvAaDph0x7g8-mmrqp4skJEjBTCnykkft-HmikY', -- MINT/ USDC AMM -
  ['U09Pg31Wlasc8ox5uTDm9sjFQT8XKcCR2Ru5lmFMe2A'] = 'HATiF_ca6ENn7aS5bcbkcZb7X5Nq_rhYJ7XE-YLYfuY', -- Test Tube Token/ MINT Test token AMM -
  ['XQhUXernOkcwzrNq5U1KlAhHsqLnT3kA4ccAxfQR7XM'] =
  'pfRs0r3yAXR4Q9SuVMHjJadxyP9GseDRb_mkqCcIyBo',                                                   -- MATRIX/ MINT Test token AMM -
  ['s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE'] =
  'wJerY4pm09KrMm18kO6fSzHJE4cOm6-hUZb_QBadxSA'                                                    -- MINT/ GAME AMM -

}


config.LP_DECIMALS = config.LP_DECIMALS or {
  ['WjLpu62JJqXQIjXPBmCkoyWNvTJs4muOKcxdAieEmAY'] = 12,
  ['UxLqhlBkIITPypglQOOrtcTQddFJU4utYFkwDqFbV7g'] = 12,
  ['Lt0PKHQCFxXkXjJVd5CV2tRIlXe55hs4cQ8_OY9JgsI'] = 12,
  ['mqJsHpuJLk77PB0pVCv47KqT3U_xY_ZHQQwHvzUAsWY'] = 12,
  ['eKECsvAaDph0x7g8-mmrqp4skJEjBTCnykkft-HmikY'] = 12,
  ['HATiF_ca6ENn7aS5bcbkcZb7X5Nq_rhYJ7XE-YLYfuY'] = 12,
  ['pfRs0r3yAXR4Q9SuVMHjJadxyP9GseDRb_mkqCcIyBo'] = 12,
  ['wJerY4pm09KrMm18kO6fSzHJE4cOm6-hUZb_QBadxSA'] = 12,
}


-- Token decimals mapping - defines how many decimal places each token uses
config.TOKEN_DECIMALS = config.TOKEN_DECIMALS or {
  -- MINT token decimal places
  [config.MINT_TOKEN] = 8,
  [config.MINT_TESTNET_TOKEN] = 18,

  -- Other tokens decimal places
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 12, -- qAR (12 decimals)
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 12, -- wAR (12 decimals)
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 8,  -- NAB (8 decimals)
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 12, -- AO (12 decimals)
  ['7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ'] = 6,  -- USDC (6 decimals)
  ['U09Pg31Wlasc8ox5uTDm9sjFQT8XKcCR2Ru5lmFMe2A'] = 12, -- Test Tube Token (12 decimals)
  ['XQhUXernOkcwzrNq5U1KlAhHsqLnT3kA4ccAxfQR7XM'] = 18, -- MATRIX Token (18 decimals)
  ['s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE'] = 18, -- GAME Token (18 decimals)

}

-- Impermanent loss protection parameters
config.IL_MAX_VESTING_DAYS = 30          -- T_max: full vesting period in days
config.IL_MAX_COVERAGE_PERCENTAGE = '50' -- C_max: maximum coverage percentage (50%)
config.IL_COVERAGE_DIVISOR = '100'       -- Divisor for percentage calculations
-- Maximum compensation per user: e.g. 100 MINT tokens (with 8 decimal places)
local MINT_MAX_COMP = 50000
local MINT_DECIMALS = config.TOKEN_DECIMALS[config.MINT_TOKEN] -- Get decimals from config
config.IL_MAX_COMP_PER_USER = tostring(MINT_MAX_COMP * 10 ^ MINT_DECIMALS)



config.MINT_BURN_RATE_WEEKLY_NUM = 25    -- Numerator
config.MINT_BURN_RATE_WEEKLY_DEN = 10000 -- Denominator (0.0025 = 25/10000)

config.CAP_PERCENTAGE_NUM = 45           -- Numerator
config.CAP_PERCENTAGE_DEN = 100          -- Denominator (0.45 = 45/100)




-- Direct access to standard config values
config.OPERATION_TIMEOUT = 3600000 -- 1 hour timeout in miliseconds

-- Staking excess multiplier for MINT tokens
config.EXCESS_MULTIPLIER = '1090' -- 109.0% - to ensure all user tokens are used
config.EXCESS_DIVISOR = '1000'

-- AMM slippage tolerance
config.SLIPPAGE_TOLERANCE = '99'

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
config.updateAllowedTokens = function(tokenAddress, tokenName, ammAddress, decimals, lpDecimals, weight)
  config.AllowedTokensNames[tokenAddress] = tokenName
  config.TOKEN_AMM_MAPPINGS[tokenAddress] = ammAddress
  config.LP_DECIMALS[ammAddress] = lpDecimals
  config.TOKEN_DECIMALS[tokenAddress] = decimals
  config.AllowedTokenWeights[tokenAddress] = weight
  -- Set default MINT token for this staked token (can be overridden)
  if tokenAddress == 'U09Pg31Wlasc8ox5uTDm9sjFQT8XKcCR2Ru5lmFMe2A'
    or tokenAddress == 'XQhUXernOkcwzrNq5U1KlAhHsqLnT3kA4ccAxfQR7XM'
  then
    config.STAKED_TOKEN_TO_MINT_TOKEN[tokenAddress] = config.MINT_TESTNET_TOKEN
  else
    config.STAKED_TOKEN_TO_MINT_TOKEN[tokenAddress] = config.MINT_TOKEN
  end

  return true
end

-- Get the appropriate MINT token to use for a given staked token
config.getMintTokenForStakedToken = function(stakedToken)
  return config.STAKED_TOKEN_TO_MINT_TOKEN[stakedToken] or config.MINT_TOKEN
end

-- Check if a token is a MINT token (either mainnet or testnet)
config.isMintToken = function(token)
  return token == config.MINT_TOKEN or token == config.MINT_TESTNET_TOKEN
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
