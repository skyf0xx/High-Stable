local json = require('json')
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

-- Helper function to update token weights based on NAB balances
local function updateTokenWeights()
  local maxLPWeight = 200

  -- Only get balances for LP tokens
  Send({
    Target = NAB_PROCESS,
    Action = 'Balances-From-Many',
    Data = json.encode(LPTokens)
  }).onReply(function(reply)
    local balances = json.decode(reply.Data)

    for _, tokenAddress in ipairs(LPTokens) do
      TokenWeights[tokenAddress] = '0'
    end

    local totalBalance = 0
    for _, balance in pairs(balances) do
      totalBalance = totalBalance + tonumber(balance)
    end

    if totalBalance > 0 then
      for tokenAddress, balance in pairs(balances) do
        local balanceNum = tonumber(balance)
        if balanceNum > 0 then
          -- Calculate proportional weight: (balance/totalBalance) * maxLPWeight
          local weight = math.floor((balanceNum / totalBalance) * maxLPWeight)
          TokenWeights[tokenAddress] = tostring(weight)
        end
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
    assert(not AllowedTokens[tokenAddress], 'Token is already registered!')

    -- Get token information from the token's process
    Send({
      Target = tokenAddress,
      Action = 'Info'
    }).onReply(function(reply)
      -- Extract name from tags
      local tokenName
      local hasNABProcess = false

      for _, tag in pairs(reply.Tags) do
        if tag.name == 'Name' then
          tokenName = tag.value
        end
        if tag.value == NAB_PROCESS then
          hasNABProcess = true
        end
      end

      -- Validate the response
      assert(tokenName, 'Token info missing required Name tag')
      assert(hasNABProcess, 'Token must reference NAB process in tags')

      -- Register the new token
      AllowedTokens[tokenAddress] = tokenAddress
      AllowedTokensNames[tokenAddress] = tokenName
      TokenWeights[tokenAddress] = '0'
      table.insert(LPTokens, tokenAddress)

      updateTokenWeights()

      msg.reply({
        Action = 'Register-Token-Result',
        Success = true,
        Data = json.encode({
          address = tokenAddress,
          name = tokenName,
          weight = '0'
        })
      })
    end)
  end
)
