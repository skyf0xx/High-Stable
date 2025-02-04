local json = require('json')

-- Define the token configurations
-- caution - allowedtokens should be append only

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
