local json = require('json')
local NABProcess = 'OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'
local TrustedCron = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

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

AllowedTokensNames = AllowedTokensNames or {
  ['lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM'] = 'Botega LP qAR/AGENT',
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'qAR',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'wAR',
  ['4Aq_6sBUyEo6AlKRq6JLT9dDfYG5ThfznA_cXjwsJpM'] = 'Fren Points',
  ['NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg'] = 'Botega LP qAR/NAB',
  ['9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4'] = 'Botega LP wAR/NAB',
  ['bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8'] = 'Botega LP wUSDC/NAB',
  ['BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q'] = 'Permaswap LP NAB/wAR',
  ['230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M'] = 'Permaswap LP qAR/NAB',
  ['SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'] = 'MINT'
}

TokenWeights = TokenWeights or {
  ['lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM'] = '0',
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = '2600',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = '2600',
  ['4Aq_6sBUyEo6AlKRq6JLT9dDfYG5ThfznA_cXjwsJpM'] = '0',
  ['NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg'] = '36000',
  ['9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4'] = '36000',
  ['bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8'] = '10000',
  ['BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q'] = '180',
  ['230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M'] = '36000',
  ['SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'] = '260'
}

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
-- Handler to register a new token
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
      -- Validate the response
      if not reply.Name then
        msg.reply({
          Action = 'Register-Token-Result',
          Success = false,
          Error = 'Failed to get token information',
          Data = json.encode({
            address = tokenAddress
          })
        })
        return
      end

      -- Register the new token
      AllowedTokens[tokenAddress] = tokenAddress
      AllowedTokensNames[tokenAddress] = reply.Name
      TokenWeights[tokenAddress] = '0'

      msg.reply({
        Action = 'Register-Token-Result',
        Success = true,
        Data = json.encode({
          address = tokenAddress,
          name = reply.Name,
          weight = '0'
        })
      })
    end)
  end
)
