local json = require('json')
local bint = require('.bint')(256)
local NAB_PROCESS = 'OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'
local NAB_DENOMINATION = 8
local STAKE_MINT_PROCESS = 'KbUW8wkZmiEWeUG0-K8ohSO82TfTUdz6Lqu5nxDoQDc'
local TRUSTED_CRON = 'pn2IDtbofqxWXyj9W6eXtdp4C7JZ1oJaM81l12ygqYc'
local TRUSTED_SECONDARY_CRON = 'BNGGjJMLRKou_dimjmodfEeEL77CZCdRmT3Rc3yyZss'

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
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = '400',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = '300',
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

-- Constants
local BENCHMARK_POOL = 'NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg' -- NAB/qAR pool
local BENCHMARK_WEIGHT = 300
local MIN_WEIGHT = 50
local MAX_WEIGHT = 5000

-- Strategic pool multipliers
local STRATEGIC_MULTIPLIERS = {
  -- NAB/AO pairs
  ['zYzUzy0ooaHj4eeFkBa3WdQE2CR7-nJ3WQteUnm6wMA'] = 2.0, -- NAB/AO Botega
  ['VRJW7p3SOJ927_mbuRzkYizYZxNLug6BOACxgXvvjFQ'] = 2.0, -- NAB/AO Permaswap

  -- WAR/NAB pairs
  ['9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4'] = 1.5, -- WAR/NAB Botega
  ['BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q'] = 1.5, -- WAR/NAB Permaswap

  -- QAR/NAB pairs
  ['NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg'] = 1.5, -- QAR/NAB Botega
  ['230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M'] = 1.5, -- QAR/NAB Permaswap

  -- NAB/ MINT pairs
  ['Lt0PKHQCFxXkXjJVd5CV2tRIlXe55hs4cQ8_OY9JgsI'] = 8, -- QAR/NAB Botega
  ['2wN5sF25smQorJncgUdg85C3jwBzDTOH-iBxDwvfBvs'] = 15 -- QAR/NAB Permaswap
}

-- Handler to update LP token denominations
Handlers.add('update-lp-denominations',
  Handlers.utils.hasMatchingTag('Action', 'Update-LP-Denominations'),
  function(msg)
    assert(TRUSTED_SECONDARY_CRON == msg.From or ao.id == msg.From, 'Request is not from the trusted Process!')

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
    assert(TRUSTED_SECONDARY_CRON == msg.From or ao.id == msg.From, 'Request is not from the trusted Process!')

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




-- Helper function to convert denomination
local function convertFromDenomination(amount, denomination)
  return tonumber(amount) / (10 ^ tonumber(denomination))
end

-- Helper function to calculate NAB to LP ratio
local function calculateRatio(nabBalance, lpSupply, lpDenomination)
  local adjustedLPSupply = convertFromDenomination(lpSupply, lpDenomination)
  local adjustedNABBAlance = convertFromDenomination(nabBalance, NAB_DENOMINATION)
  if adjustedLPSupply <= 0 then return 0 end
  return adjustedNABBAlance / adjustedLPSupply
end

local function updateTokenWeights()
  -- Get NAB balances for all LP tokens in one go
  Send({
    Target = NAB_PROCESS,
    Action = 'Balances-From-Many',
    Data = json.encode(LPTokens)
  }).onReply(function(reply)
    local balances = json.decode(reply.Data)

    -- First calculate benchmark coefficient
    local benchmarkCoefficient = nil
    local benchmarkNABBalance = tonumber(balances[BENCHMARK_POOL])

    if benchmarkNABBalance and benchmarkNABBalance > 0 then
      local lpDenomination = AllowedLPTokensDenomination[BENCHMARK_POOL]
      local lpSupply = AllowedLPTokensTotalSupply[BENCHMARK_POOL]

      if lpSupply then
        local benchmarkRatio = calculateRatio(benchmarkNABBalance, lpSupply, lpDenomination)
        if benchmarkRatio > 0 then
          benchmarkCoefficient = 1 / benchmarkRatio
        end
      end
    end

    -- Only proceed if we have a valid benchmark
    if benchmarkCoefficient then
      -- Calculate weights for each pool
      for tokenAddress, nabBalance in pairs(balances) do
        local lpDenomination = AllowedLPTokensDenomination[tokenAddress]
        local lpSupply = AllowedLPTokensTotalSupply[tokenAddress]

        if lpSupply then
          local nabAmount = tonumber(nabBalance)
          if nabAmount and nabAmount > 0 then
            -- Calculate pool's NAB/LP ratio
            local poolRatio = calculateRatio(nabAmount, lpSupply, lpDenomination)

            -- Calculate base weight using benchmark formula
            local weight = math.floor(poolRatio * benchmarkCoefficient * BENCHMARK_WEIGHT)

            -- Apply strategic multiplier if exists
            if STRATEGIC_MULTIPLIERS[tokenAddress] then
              weight = math.floor(weight * STRATEGIC_MULTIPLIERS[tokenAddress])
            end

            -- Apply weight bounds
            weight = math.max(MIN_WEIGHT, math.min(MAX_WEIGHT, weight))

            -- Update weight in state
            TokenWeights[tokenAddress] = tostring(weight)
          else
            TokenWeights[tokenAddress] = tostring(MIN_WEIGHT)
          end
        end
      end

      -- Update stake mint process with new weights
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
      local denomination = reply.Tags['Denomination']

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
      assert(type(denomination) == 'string' and denomination ~= '', 'Token info missing required Denomination tag')

      -- Register the new token
      AllowedTokens[tokenAddress] = tokenAddress
      AllowedTokensNames[tokenAddress] = tokenName
      TokenWeights[tokenAddress] = '0'
      table.insert(LPTokens, tokenAddress)
      AllowedLPTokensDenomination[tokenAddress] = denomination

      -- Get and store the total supply
      Send({
        Target = tokenAddress,
        Action = 'Total-Supply'
      }).onReply(function(supplyReply)
        if supplyReply.Data then
          AllowedLPTokensTotalSupply[tokenAddress] = cleanSupplyString(supplyReply.Data)
        end

        -- Update token weights after all data is collected
        updateTokenWeights()

        msg.reply({
          Action = 'Register-Token-Result',
          Success = true,
          Data = json.encode({
            address = tokenAddress,
            name = tokenName,
            denomination = denomination,
            totalSupply = AllowedLPTokensTotalSupply[tokenAddress]
          })
        })
      end)
    end)
  end
)
