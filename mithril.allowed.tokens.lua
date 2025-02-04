local json = require('json')

-- Define the token configurations
-- caution - allowedtokens should be append only
local allowedTokens = {
  agent_qar_lp = 'lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM',
  qar = 'NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8',
  war = 'xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10',
  frp = '4Aq_6sBUyEo6AlKRq6JLT9dDfYG5ThfznA_cXjwsJpM',
  qar_nab_lp = 'NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg',
  war_nab_lp = '9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4',
  wusdc_nab_lp = 'bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8',
  nab_war_ps_lp = 'BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q',
  qar_nab_ps_lp = '230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M',
  mint = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0',
}


local allowedTokensNames = {
  agent_qar_lp = 'Botega LP qAR/AGENT',
  qar = 'qAR',
  war = 'wAR',
  frp = 'Fren Points',
  qar_nab_lp = 'Botega LP qAR/NAB',
  war_nab_lp = 'Botega LP wAR/NAB',
  wusdc_nab_lp = 'Botega LP wUSDC/NAB',
  nab_war_ps_lp = 'Permaswap LP NAB/wAR',
  qar_nab_ps_lp = 'Permaswap LP qAR/NAB',
  mint = 'MINT'

}

-- weight forumula for lp: 2*(1/ total lp tokens per 1AR)
local tokenWeights = {
  agent_qar_lp = '0', --discontinued
  qar = '2600',
  war = '2600',
  frp = '0', --discontinued
  qar_nab_lp = '36000',
  war_nab_lp = '36000',
  wusdc_nab_lp = '10000',
  nab_war_ps_lp = '180',
  qar_nab_ps_lp = '36000',
  mint = '260'
}

-- Handler to get all token configurations
Handlers.add('get-token-configs',
  Handlers.utils.hasMatchingTag('Action', 'Get-Token-Configs'),
  function(msg)
    msg.reply({
      Action = 'Token-Configs',
      Data = json.encode({
        allowedTokens = allowedTokens,
        allowedTokensNames = allowedTokensNames,
        tokenWeights = tokenWeights
      })
    })
  end
)
