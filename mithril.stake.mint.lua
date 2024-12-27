Variant = '0.0.1'
local bint = require('.bint')(256)
local tableUtils = require('.utils')
local json = require('json')

local function countTableElements(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

-- Constants
CRON_CALLER = 'MlOkQg3_PSmUJOUTqxQdmzopMBjn0phrvEOHsdyuevQ'
TOKEN_OWNER = 'OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'
TOTAL_SUPPLY = 21000000 * 10 ^ 8  -- 21M tokens with 8 decimal places
EMISSION_RATE_PER_MONTH = 0.01425 -- 1.425% monthly rate
PERIODS_PER_MONTH = 8760          -- number of 5-minute periods in a month (43800/5)
PRECISION_FACTOR = bint(10 ^ 16)  -- calculating emissions

local PRE_MINT = 5050

-- State variables
CurrentSupply = CurrentSupply or PRE_MINT
LastMintTimestamp = LastMintTimestamp or 0

-- caution - allowedtokens should be append only
local allowedTokens = {
  agent_qar_lp = 'lmaw9BhyycEIyxWhr0kF_tTcfoSoduDX8fChpHn2eQM',
  qar = 'NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8',
  war = 'xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10',
  frp = 'NgPF445swQfqq0cuM1nNQaVzg05sq8eX5L4YxS-6oDo',
  qar_nab_lp = 'NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg',
  war_nab_lp = '9eM72ObMJM6o3WHi6nTldwhHsCXSKgzz1hv-FpURZB4',
  wusdc_nab_lp = 'bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8',
  nab_war_ps_lp = 'BGBUvr5dVJrgmmuPN6G56OIuNSHUWO2y7bZyPlAjK8Q',
  qar_nab_ps_lp = '230cSNf7AWy6VsBTftbTXW76xR5H1Ki42nT2xM2fA6M',
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
}

-- weight forumula for lp: 2*(1/ total lp tokens per 1AR)
local tokenWeights = {
  agent_qar_lp = '1',
  qar = '2600',
  war = '2600',
  frp = '260',
  qar_nab_lp = '36000',
  war_nab_lp = '36000',
  wusdc_nab_lp = '10000',
  nab_war_ps_lp = '180',
  qar_nab_ps_lp = '36000',
}


--[[
  Initialize the staker table. stakers[token][user] = balance
]]
---@return table<string, table>
function UpdateAllowedTokens()
  local stakers = Stakers
  for _, token in pairs(allowedTokens) do
    if not stakers[token] then stakers[token] = {} end
  end
  return stakers
end

Stakers = Stakers or UpdateAllowedTokens()
StakersBackup = StakersBackup or Stakers --used before calling UpdateAllowedTokens just for safety

--[[
  utils helper functions to remove the bint complexity.
]]
--
local utils = {
  add = function(a, b)
    return tostring(bint(a) + bint(b))
  end,
  subtract = function(a, b)
    return tostring(bint(a) - bint(b))
  end,
  multiply = function(a, b)
    return tostring(bint(a) * bint(b))
  end,
  divide = function(a, b)
    return tostring(bint.__idiv(bint(a), bint(b)))
  end,
  toBalanceValue = function(a)
    return tostring(bint(a))
  end,
  toNumber = function(a)
    return tonumber(a)
  end
}


--[[
     Get the name of the token
   ]]
--
---@param address string
---@return string
function TokenName(address)
  for token, addr in pairs(allowedTokens) do
    if addr == address then
      return token
    end
  end

  return ''
end

--[[
     Handler to update allowed tokens.
     Update allowedTokens arrays then call this handler
   ]]
--
Handlers.add('update-allowed-tokens', Handlers.utils.hasMatchingTag('Action', 'Update-Allowed-Tokens'),
  function(msg)
    Stakers = UpdateAllowedTokens()
    Send({
      Target = msg.From,
      Data = 'Allowed tokens: ' .. json.encode(allowedTokens)
    })
  end)


--[[
     Handler for staking. To stake, simply send tokens to this address.
   ]]
--
Handlers.add('stake', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
  function(msg)
    -- credit notice is sent by the token process to the staking contract
    local token = msg.From
    local quantity = msg.Quantity
    local stakeable = tableUtils.includes(token, tableUtils.values(allowedTokens))
    local sender = msg.Sender
    local tokenName = TokenName(token)

    --don't bother to refund unstakeable tokens - to prevent being drained through spurious fees
    assert(stakeable, 'Token: ' .. token .. ' is not stakable and was ignored!')
    assert(bint(0) < bint(quantity), 'Quantity must be greater than zero!')

    if not Stakers[token][sender] then Stakers[token][sender] = '0' end

    Stakers[token][sender] = utils.add(Stakers[token][sender], quantity)

    Send({
      Target = sender,
      Data = Colors.gray ..
        'You have staked a total of ' ..
        Colors.blue .. Stakers[token][sender] .. Colors.reset .. ' ' .. tokenName
    })
  end)



--[[
     Handler to unstake
   ]]
--

Handlers.add('unstake', Handlers.utils.hasMatchingTag('Action', 'Unstake'),
  function(msg)
    local from = msg.From
    local token = msg.Tags['Token']
    local stakeable = tableUtils.includes(token, tableUtils.values(allowedTokens))
    local quantity = Stakers[token][from] or '0'
    local tokenName = TokenName(token)

    assert(stakeable, 'Token: ' .. token .. ' is not stakable and was ignored!')
    assert(bint(0) < bint(quantity), 'You need to have more than zero staked tokens!')

    Stakers[token][from] = nil

    --send the staked tokens back to the user
    Send({
      Target = token,
      Action = 'Transfer',
      Recipient = from,
      Quantity = quantity,
      ['X-Message'] = 'Mithril Unstake',
      ['X-Staked-Balance-Remaining-' .. tokenName] = '0'
    })

    Send({
      Target = from,
      Data = Colors.gray ..
        'Successfully unstaked ' ..
        Colors.blue .. quantity .. Colors.reset .. ' ' .. tokenName
    })
  end)


--[[
     Handler to get staked balances for a specific staker
   ]]
--
Handlers.add('get-staked-balances', Handlers.utils.hasMatchingTag('Action', 'Get-Staked-Balances'),
  function(msg)
    local staker = msg.Tags['Staker']
    assert(type(staker) == 'string', 'Staker address is required!')

    -- Initialize result array to store balances
    local balances = {}

    -- Loop through allowedTokensNames to maintain consistent order
    for token, name in pairs(allowedTokensNames) do
      local tokenAddress = allowedTokens[token]
      local amount = '0' -- Default to '0' for unstaked tokens

      -- If there's a staked balance for this token, use it
      if Stakers[tokenAddress] and Stakers[tokenAddress][staker] then
        amount = Stakers[tokenAddress][staker]
      end

      -- Add entry to balances array with token address included
      table.insert(balances, {
        name = name,
        address = tokenAddress,
        amount = amount
      })
    end

    -- Send response with balances array
    Send({
      Target = msg.From,
      Action = 'Staked-Balances',
      Staker = staker,
      Data = json.encode(balances),
      Weights = json.encode(tokenWeights)
    })
  end)


--[[
     Handler to get list of allowed tokens
   ]]
--
Handlers.add('get-allowed-tokens', Handlers.utils.hasMatchingTag('Action', 'Get-Allowed-Tokens'),
  function(msg)
    Send({
      Target = msg.From,
      Action = 'Allowed-Tokens',
      Data = json.encode({ allowedTokens, allowedTokensNames })
    })
  end)


--[[
  Calculate emission for a 5-minute period
  Returns the number of tokens to mint in this period
]]

local function calculateEmission()
  -- Convert all values to bint early to avoid overflow
  local totalSupplyBint = bint(TOTAL_SUPPLY)
  local currentSupplyBint = bint(CurrentSupply)
  local remainingSupply = totalSupplyBint - currentSupplyBint

  -- If no supply remaining, return 0
  if remainingSupply <= bint.zero() then
    return '0'
  end

  -- Calculate the emission rate for a 5-minute period
  -- Convert rate to a fixed-point number with 8 decimal places for precision
  local periodRateFixed = math.floor((EMISSION_RATE_PER_MONTH / PERIODS_PER_MONTH) * 10 ^ 8)
  local periodRateBint = bint(periodRateFixed)

  -- Calculate tokens to emit this period
  -- First multiply by rate, then divide by 10^8 to get back to normal scale
  local emission = bint.__idiv(remainingSupply * periodRateBint, bint(10 ^ 8))

  -- Double check we don't exceed remaining supply
  if emission > remainingSupply then
    emission = remainingSupply
  end

  return utils.toBalanceValue(emission)
end


--[[
  Calculate individual staker allocations based on their stake weight
]]
local function calculateStakerAllocations(totalEmission)
  local allocations = {}
  local totalStakeWeight = bint.zero()
  local emissionBint = bint(totalEmission)

  -- First pass: calculate total weighted stake
  for token, stakersMap in pairs(Stakers) do
    local tokenName = TokenName(token)
    if tokenName and tokenWeights[tokenName] then
      local tokenWeight = bint(tokenWeights[tokenName])
      for _, amount in pairs(stakersMap) do
        totalStakeWeight = totalStakeWeight + (bint(amount) * tokenWeight)
      end
    end
  end

  -- If no stakes, return empty allocations
  if totalStakeWeight == bint.zero() then
    return allocations
  end


  -- Track rounding errors to distribute later
  local totalAllocated = bint.zero()

  -- Second pass: calculate individual allocations with higher precision
  for token, stakersMap in pairs(Stakers) do
    local tokenName = TokenName(token)
    if tokenName and tokenWeights[tokenName] then
      local tokenWeight = bint(tokenWeights[tokenName])
      for staker, amount in pairs(stakersMap) do
        local stakerWeight = bint(amount) * tokenWeight

        -- Calculate allocation with higher precision
        -- First multiply by emission and precision factor before division
        local allocation = bint.__idiv(
          (emissionBint * stakerWeight * PRECISION_FACTOR),
          (totalStakeWeight)
        )

        -- Remove precision factor
        allocation = bint.__idiv(allocation, PRECISION_FACTOR)

        -- Track total allocated
        totalAllocated = totalAllocated + allocation

        -- Store allocation
        if allocation > bint.zero() then
          if not allocations[staker] then
            allocations[staker] = '0'
          end
          allocations[staker] = utils.toBalanceValue(bint(allocations[staker]) + allocation)
        end
      end
    end
  end

  -- Distribute any remaining dust from rounding (if any)
  local remainingEmission = emissionBint - totalAllocated
  if remainingEmission > bint.zero() then
    -- Find the staker with the highest stake to give them the dust
    local highestStaker = nil
    local highestStake = bint.zero()

    for token, stakersMap in pairs(Stakers) do
      local tokenName = TokenName(token)
      if tokenName and tokenWeights[tokenName] then
        local tokenWeight = bint(tokenWeights[tokenName])
        for staker, amount in pairs(stakersMap) do
          local stakerWeight = bint(amount) * tokenWeight
          if stakerWeight > highestStake then
            highestStake = stakerWeight
            highestStaker = staker
          end
        end
      end
    end

    -- Add remaining dust to highest staker's allocation
    if highestStaker then
      if not allocations[highestStaker] then
        allocations[highestStaker] = '0'
      end
      allocations[highestStaker] = utils.toBalanceValue(
        bint(allocations[highestStaker]) + remainingEmission
      )
    end
  end

  return allocations
end


--[[
  Handler to request token mints
  Called every 5 minutes by a cron job oracle
]]
Handlers.add('request-token-mints', Handlers.utils.hasMatchingTag('Action', 'Request-Token-Mints'),
  function(msg)
    assert(CRON_CALLER == msg.From, 'Request is not from the trusted Cron!')

    -- Ensure sufficient time has passed since last mint
    local currentTime = os.time()
    assert(currentTime >= LastMintTimestamp + 300, 'Too soon for next mint') -- 300 seconds = 5 minutes

    -- Calculate new tokens to mint this period
    local newTokens = calculateEmission()

    -- If no tokens to mint, exit early
    if newTokens == '0' then
      return
    end

    -- Calculate allocation for each staker
    local allocations = calculateStakerAllocations(newTokens)

    -- Prepare mint requests
    local mints = {}
    for staker, amount in pairs(allocations) do
      -- Only include non-zero allocations
      if bint(amount) > bint.zero() then
        table.insert(mints, {
          address = staker,
          amount = amount
        })
      end
    end

    -- Update state
    CurrentSupply = utils.add(CurrentSupply, newTokens)
    LastMintTimestamp = currentTime

    -- Send mint requests to token contract only if there are valid mints
    if #mints > 0 then
      Send({
        Target = TOKEN_OWNER,
        Action = 'Mint-From-Stake',
        Data = json.encode(mints)
      })
    end
  end)


--[[
     Handler to get stake ownership percentage for a specific address
     This considers the weighted value of all staked tokens
   ]]
--
Handlers.add('get-stake-ownership', Handlers.utils.hasMatchingTag('Action', 'Get-Stake-Ownership'),
  function(msg)
    -- Input validation with clear error message
    local staker = msg.Tags['Staker']
    assert(type(staker) == 'string', 'Staker address is required!')

    -- Initialize weights with bint
    local totalStakeWeight = bint.zero()
    local stakerWeight = bint.zero()

    -- Calculate total weighted stake across all tokens
    for tokenAddress, stakersMap in pairs(Stakers) do
      -- Get token name for weight lookup
      local tokenName = TokenName(tokenAddress)
      -- Ensure we have a valid token weight
      if tokenName and tokenWeights[tokenName] then
        local tokenWeight = bint(tokenWeights[tokenName])

        -- Calculate weights for all stakers
        for addr, amount in pairs(stakersMap) do
          -- Convert amount to bint and calculate weight
          local weight = bint(amount) * tokenWeight
          totalStakeWeight = totalStakeWeight + weight

          -- Calculate this staker's weight if it matches
          if addr == staker then
            stakerWeight = stakerWeight + weight
          end
        end
      end
    end

    -- Handle case where there are no stakes
    if totalStakeWeight == bint.zero() then
      Send({
        Target = msg.From,
        Action = 'Stake-Ownership',
        Staker = staker,
        ['Ownership-Percentage'] = '0.000000',
        Data = json.encode({
          percentage = '0.000000',
          stakerWeight = '0',
          totalWeight = '0'
        })
      })
      return
    end

    -- Calculate ownership percentage with 6 decimal places of precision
    -- Multiply by 10^8 before division to maintain precision, then format result
    local scaledStakerWeight = bint(utils.toBalanceValue(stakerWeight)) * bint(100 * PRECISION_FACTOR)
    local ownershipPercentageBint = bint.__idiv(scaledStakerWeight, bint(utils.toBalanceValue(totalStakeWeight)))

    -- Convert to string with proper decimal places
    local ownershipPercentageStr = string.format('%.6f',
      tonumber(utils.toBalanceValue(ownershipPercentageBint)) / PRECISION_FACTOR)

    -- Send response with ownership details
    Send({
      Target = msg.From,
      Action = 'Stake-Ownership',
      Staker = staker,
      ['Ownership-Percentage'] = ownershipPercentageStr,
      Data = json.encode({
        percentage = ownershipPercentageStr,
        stakerWeight = utils.toBalanceValue(stakerWeight),
        totalWeight = utils.toBalanceValue(totalStakeWeight)
      })
    })
  end
)

-- Get number of unique stakers across all tokens
Handlers.add('get-unique-stakers',
  Handlers.utils.hasMatchingTag('Action', 'Get-Unique-Stakers'),
  function(msg)
    local uniqueStakers = {}
    for token, stakersMap in pairs(Stakers) do
      for staker, balance in pairs(stakersMap) do
        -- Only count stakers with positive balance
        if bint(balance) > bint.zero() then
          uniqueStakers[staker] = true
        end
      end
    end

    msg.reply({
      Action = 'Unique-Stakers',
      Data = tostring(countTableElements(uniqueStakers))
    })
  end
)

-- Get current minting rate in tokens per day
Handlers.add('get-minting-rate',
  Handlers.utils.hasMatchingTag('Action', 'Get-Minting-Rate'),
  function(msg)
    -- Get remaining supply
    local totalSupplyBint = bint(TOTAL_SUPPLY)
    local currentSupplyBint = bint(CurrentSupply)
    local remainingSupply = totalSupplyBint - currentSupplyBint

    -- If no supply remaining, return 0
    if remainingSupply <= bint.zero() then
      msg.reply({
        Action = 'Minting-Rate',
        Data = '0'
      })
      return
    end

    -- Calculate the emission rate for one day
    -- EMISSION_RATE_PER_MONTH is 0.01425 (1.425%)
    -- There are 288 5-minute periods in a day (24 * 60 / 5)
    local periodRateFixed = math.floor((EMISSION_RATE_PER_MONTH / PERIODS_PER_MONTH) * 10 ^ 8)
    local periodRateBint = bint(periodRateFixed)

    -- Calculate daily emission: remainingSupply * (periodRate * 288)
    local dailyRate = bint.__idiv(remainingSupply * periodRateBint * bint(288), bint(10 ^ 8))

    msg.reply({
      Action = 'Minting-Rate',
      Data = utils.toBalanceValue(dailyRate)
    })
  end
)

-- Get token staking breakdown
Handlers.add('get-token-stakes',
  Handlers.utils.hasMatchingTag('Action', 'Get-Token-Stakes'),
  function(msg)
    local tokenStats = {}

    for token, stakersMap in pairs(Stakers) do
      local totalStaked = '0'
      for _, amount in pairs(stakersMap) do
        totalStaked = utils.add(totalStaked, amount)
      end

      table.insert(tokenStats, {
        address = token,
        name = allowedTokensNames[TokenName(token)],
        total_staked = totalStaked,
        num_stakers = countTableElements(stakersMap)
      })
    end

    msg.reply({
      Action = 'Token-Stakes',
      Data = json.encode(tokenStats)
    })
  end
)
