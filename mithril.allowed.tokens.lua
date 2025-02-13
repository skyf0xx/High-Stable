local json = require('json')
local bint = require('.bint')(256)
local NAB_PROCESS = 'OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'
local STAKE_MINT_PROCESS = 'KbUW8wkZmiEWeUG0-K8ohSO82TfTUdz6Lqu5nxDoQDc'
local TRUSTED_CRON = 'pn2IDtbofqxWXyj9W6eXtdp4C7JZ1oJaM81l12ygqYc'

-- Define the token configurations
-- caution - allowedtokens should be append only
-- Beow was the initial list of allowed tokens, before they became dynamic
AllowedTokens = AllowedTokens or {
  ['lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM'] = 'lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM',
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10',
  ['4Aq_6sBUyEo6AlKRq6JLT9dDfYG5ThfznA_cXjwsJpM'] = '4Aq_6sBUyEo6AlKRq6JLT9dDfYG5ThfznA_cXjwsJpM',
  ['NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg'] = 'NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg',
  ['9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4'] = '9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4',
  ['bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8'] = 'bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8',
  ['BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q'] = 'BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q',
  ['230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M'] = '230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M',
  ['SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'] = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'
}

LPTokens = LPTokens or {
  'lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM',
  'NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg',
  '9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4',
  'bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8',
  'BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q',
  '230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M',
}

AllowedTokensNames = AllowedTokensNames or {
  ['lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM'] = 'Botega LP qAR/AGENT',
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'Q Arweave',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'Wrapped AR',
  ['4Aq_6sBUyEo6AlKRq6JLT9dDfYG5ThfznA_cXjwsJpM'] = 'NAB FRN Points',
  ['NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg'] = 'Botega LP qAR/NAB',
  ['9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4'] = 'Botega LP wAR/NAB',
  ['bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8'] = 'Botega LP wUSDC/NAB',
  ['BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q'] = 'NAB-wAR-30',
  ['230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M'] = 'qAR-NAB-30',
  ['SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'] = 'MINT'
}


TokenWeights = TokenWeights or {
  ['lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM'] = '0',
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = '100',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = '100',
  ['4Aq_6sBUyEo6AlKRq6JLT9dDfYG5ThfznA_cXjwsJpM'] = '0',
  ['NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg'] = '0',
  ['9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4'] = '0',
  ['bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8'] = '0',
  ['BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q'] = '0',
  ['230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M'] = '0',
  ['SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'] = '30'
}

-- New state variables for LP token information
AllowedLPTokensDenomination = AllowedLPTokensDenomination or {}
AllowedLPTokensTotalSupply = AllowedLPTokensTotalSupply or {}

AllowedTokensMultiplier = {
  -- Double weight for NAB AO/ AR pairs where there are whales (Or favored partners)
  ['zYzUzy0ooaHj4eeFkBa3WdQE2CR7-nJ3WQteUnm6wMA'] = 10, --NAB / AO Botega
  ['9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4'] = 10, --WAR/ NAB Botega
  ['NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg'] = 10, --QAR/ NAB Botega
  ['VRJW7p3SOJ927_mbuRzkYizYZxNLug6BOACxgXvvjFQ'] = 10, --NAB/ AO Permaswap
  ['BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q'] = 10, --WAR/ NAB Permaswap
  ['230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M'] = 10, --QAR/ NAB Permaswap
}

-- Handler to update LP token denominations
Handlers.add('update-lp-denominations',
  Handlers.utils.hasMatchingTag('Action', 'Update-LP-Denominations'),
  function(msg)
    assert(TRUSTED_CRON == msg.From or ao.id == msg.From, 'Request is not from the trusted Process!')

    local function updateDenomination(tokenAddress)
      Send({
        Target = tokenAddress,
        Action = 'Info'
      }).onReply(function(reply)
        if reply.Tags.Denomination then
          AllowedLPTokensDenomination[tokenAddress] = reply.Tags.Denomination
        end
      end)
    end

    -- Update denomination for each LP token
    for _, tokenAddress in ipairs(LPTokens) do
      updateDenomination(tokenAddress)
    end

    msg.reply({
      Action = 'LP-Denominations-Updated',
      Data = 'Updated LP token denominations'
    })
  end
)

local function cleanSupplyString(supply)
  if type(supply) ~= 'string' then
    return '0'
  end

  -- First remove all quotes and whitespace
  local cleaned = string.gsub(supply, '["\' ]', '')

  -- Then let bint handle the numeric conversion
  local success, result = pcall(function() return tostring(bint(cleaned)) end)
  return success and result or '0'
end

-- Handler to update LP token total supplies
Handlers.add('update-lp-supplies',
  Handlers.utils.hasMatchingTag('Action', 'Update-LP-Supplies'),
  function(msg)
    assert(TRUSTED_CRON == msg.From or ao.id == msg.From, 'Request is not from the trusted Process!')

    local function updateSupply(tokenAddress)
      Send({
        Target = tokenAddress,
        Action = 'Total-Supply'
      }).onReply(function(reply)
        if reply.Data then
          AllowedLPTokensTotalSupply[tokenAddress] = cleanSupplyString(reply.Data)
        end
      end)
    end

    -- Update total supply for each LP token
    for _, tokenAddress in ipairs(LPTokens) do
      updateSupply(tokenAddress)
    end

    msg.reply({
      Action = 'LP-Supplies-Updated',
      Data = 'Updated LP token total supplies'
    })
  end
)


local function updateTokenWeights()
  local maxLPWeight = 7500
  local minLPWeight = 50

  Send({
    Target = NAB_PROCESS,
    Action = 'Balances-From-Many',
    Data = json.encode(LPTokens)
  }).onReply(function(reply)
    local balances = json.decode(reply.Data)

    -- Reset weights
    for _, tokenAddress in ipairs(LPTokens) do
      TokenWeights[tokenAddress] = '0'
    end

    -- Calculate adjusted balances using supply and denomination
    local adjustedBalances = {}
    local totalAdjustedBalance = 0

    for tokenAddress, balance in pairs(balances) do
      local denomination = tonumber(AllowedLPTokensDenomination[tokenAddress])
      local totalSupply = AllowedLPTokensTotalSupply[tokenAddress]

      if denomination and totalSupply then
        local nabBalance = tonumber(balance)
        local denominatedSupply = tonumber(totalSupply) / (10 ^ denomination)

        if denominatedSupply > 0 and nabBalance > 0 then
          -- Calculate adjusted balance: (NAB balance)^2 / total supply
          local adjustedBalance = (nabBalance * nabBalance) / denominatedSupply
          adjustedBalances[tokenAddress] = adjustedBalance
          totalAdjustedBalance = totalAdjustedBalance + adjustedBalance
        end
      end
    end

    -- Calculate weights if we have any adjusted balances
    if totalAdjustedBalance > 0 then
      for tokenAddress, adjustedBalance in pairs(adjustedBalances) do
        local weight = math.floor((adjustedBalance / totalAdjustedBalance) * maxLPWeight)
        weight = math.max(minLPWeight, weight)

        -- Apply multiplier after minLPWeight check if one exists for this token
        if AllowedTokensMultiplier[tokenAddress] then
          weight = math.floor(weight * AllowedTokensMultiplier[tokenAddress])
        end

        TokenWeights[tokenAddress] = tostring(weight)
      end

      Send({
        Target = STAKE_MINT_PROCESS,
        Action = 'Refresh-Token-Configs'
      })
    end
  end)
end


-- Handler to get all token configurations
Handlers.add('get-token-configs',
  Handlers.utils.hasMatchingTag('Action', 'Get-Token-Configs'),
  function(msg)
    msg.reply({
      Action = 'Token-Configs',
      Data = json.encode({
        allowedTokens = AllowedTokens,
        allowedTokensNames = AllowedTokensNames,
        tokenWeights = TokenWeights
      })
    })
  end
)

-- Handler to update token weights (called by cron once a day)
Handlers.add('update-token-weights',
  Handlers.utils.hasMatchingTag('Action', 'Update-Token-Weights'),
  function(msg)
    assert(TRUSTED_CRON == msg.From or ao.id == msg.From, 'Request is not from the trusted Process!')

    updateTokenWeights()

    msg.reply({
      Action = 'Token-Weights-Updated',
      Data = 'Updated the token weights'
    })
  end
)

-- Handler to register a new LP token
Handlers.add('register-token',
  Handlers.utils.hasMatchingTag('Action', 'Register-Token'),
  function(msg)
    -- Input validation
    local tokenAddress = msg.Tags['Token-Address']
    assert(type(tokenAddress) == 'string', 'Token address is required!')
    if (AllowedTokens[tokenAddress]) then
      msg.reply({
        Action = 'Register-Token-Result',
        Success = true,
      })
      return
    end
    assert(not AllowedTokens[tokenAddress], 'Token is already registered!')

    -- Get token information from the token's process
    Send({
      Target = tokenAddress,
      Action = 'Info'
    }).onReply(function(reply)
      -- Extract name directly
      local tokenName = reply.Tags['Name']

      -- Check for NAB process in any tag value
      local hasNABProcess = false
      for _, value in pairs(reply.Tags) do
        if value == NAB_PROCESS then
          hasNABProcess = true
          break
        end
      end

      -- Validate the response
      assert(type(tokenName) == 'string' and tokenName ~= '', 'Token info missing required Name tag')
      assert(hasNABProcess, 'Token must have NAB as one of its paired tokens')

      -- Register the new token
      AllowedTokens[tokenAddress] = tokenAddress
      AllowedTokensNames[tokenAddress] = tokenName
      TokenWeights[tokenAddress] = '0'
      table.insert(LPTokens, tokenAddress)

      updateTokenWeights()
    end)
  end
)
