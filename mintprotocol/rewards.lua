-- Single-Sided Staking Contract - Rewards Module
-- Handles token emissions and reward distribution to stakers

local config = require('mintprotocol.config')
local state = require('mintprotocol.state')
local utils = require('mintprotocol.utils')
local security = require('mintprotocol.security')
local bint = require('.bint')(256)
local json = require('json')

local rewards = {}

-- Constants for emission calculations
-- 5M tokens with 8 decimal places
rewards.EMISSION_RATE_PER_MONTH = 0.0285                            -- 1.425% monthly rate
rewards.PERIODS_PER_MONTH = 8640                                    -- number of 5-minute periods in a month (30 days * 24 hours * 60 minutes / 5)
rewards.SCALING_FACTORS = {
  PRECISION = bint(10 ^ 16),                                        -- For high-precision calculations
  PERCENTAGE = bint(10 ^ 8),                                        -- For percentage calculations
  DISPLAY = bint(10 ^ 6)                                            -- For display formatting
}
rewards.PRECISION_FACTOR = rewards.SCALING_FACTORS.PRECISION        -- for calculating emissions with high precision
rewards.CRON_CALLER = '8hN_JEoeuEuObMPchK9FjhcvQ_8MjMM1p55D21TJ1XY' -- authorized caller for periodic rewards
rewards.MINT_POLICY = 'KBOfQGUj-K1GNwfx1CeMSZxxcj5p837d-_6hTmkWF0k' -- mint.policy contract
rewards.REWARD_TOKEN = config.MINT_TOKEN                            -- Use the configured MINT token
rewards.DENOMINATION = config.TOKEN_DECIMALS
                             [config.MINT_TOKEN]                    -- Use the configured MINT token decimals
rewards.TOTAL_SUPPLY = bint(5000000) * bint(10 ^ rewards.DENOMINATION)
rewards.MINT_BURN_RATE_WEEKLY = 0.0025                              -- 0.25% weekly burn rate from mint.policy
rewards.CAP_PERCENTAGE = 0.45                                       -- Cap at 45% of weekly burn (safely under 50%)
rewards.MINT_TOKEN_SUPPLY = rewards.MINT_TOKEN_SUPPLY or
  '0'                                                               -- Initialize with zero, will be updated

rewards.TREASURY = 'ugh5LqeSZBKFJ0P_Q5wMpKNusG0jlATrihpcTxh5TKo'
-- Initialize state variables if they don't exist
CurrentRewards = CurrentRewards or '0'         -- tracks current supply of reward tokens
LastRewardTimestamp = LastRewardTimestamp or 0 -- tracks last time rewards were distributed
TokenWeights = TokenWeights or {}              -- weights for each stakeable token


-- Default token weights if not already set
for token, weight in pairs(config.AllowedTokenWeights) do
  TokenWeights[token] = weight
end

-- Handler patterns for rewards operations
rewards.patterns = {
  -- Pattern for requesting token rewards distribution
  requestRewards = function(msg)
    return msg.Tags.Action == 'Request-Rewards'
  end,


  -- Pattern for getting reward statistics
  getRewardStats = function(msg)
    return msg.Tags.Action == 'Get-Reward-Stats'
  end,

  -- Pattern for getting stake ownership percentage
  getStakeOwnership = function(msg)
    return msg.Tags.Action == 'Get-Stake-Ownership'
  end,

  -- Pattern for getting unique stakers count
  getUniqueStakers = function(msg)
    return msg.Tags.Action == 'Get-Unique-Stakers'
  end,

  -- Pattern for getting token stakes breakdown
  getTokenStakes = function(msg)
    return msg.Tags.Action == 'Get-Token-Stakes'
  end,

  -- Pattern for updating mint supply
  updateMintSupply = function(msg)
    return msg.Tags.Action == 'Update-MINT-Supply'
  end,

  -- Pattern for updating mint supply
  distributeRewardsResponse = function(msg)
    return msg.Tags.Action == 'Distribute-Rewards-Response'
  end,
}

-- Calculate emission for the current period based on declining curve
local function calculateEmission()
  -- Convert values to bint early to avoid overflow
  local totalSupplyBint = rewards.TOTAL_SUPPLY
  local currentRewardsBint = bint(CurrentRewards)
  local remainingRewards = totalSupplyBint - currentRewardsBint

  -- If no supply remaining, return 0
  if remainingRewards <= bint.zero() then
    return '0'
  end

  -- Calculate the emission rate for a 5-minute period
  -- Convert rate to a fixed-point number with 8 decimal places for precision
  local periodRateFixed = math.floor((rewards.EMISSION_RATE_PER_MONTH / rewards.PERIODS_PER_MONTH) * 10 ^ 8)

  -- Use the multiply function which already handles bint conversion
  local remainingRewardsStr = tostring(remainingRewards)
  local periodRateStr = tostring(periodRateFixed)

  -- Calculate emission with precision maintained
  local scaledEmission = utils.math.multiply(remainingRewardsStr, periodRateStr)

  -- Then divide by precision factor (10^8)
  local emission = utils.math.divide(scaledEmission, '100000000')

  -- Ensure we don't exceed remaining supply
  if utils.math.isGreaterThan(emission, remainingRewardsStr) then
    emission = remainingRewardsStr
  end

  -- Calculate cap based on mint.policy burn rate
  local mintSupply = rewards.MINT_TOKEN_SUPPLY

  if mintSupply ~= '0' then
    -- First multiply by numerator
    local weeklyBurnAmount = utils.math.multiply(mintSupply, tostring(config.MINT_BURN_RATE_WEEKLY_NUM))
    -- Then divide by denominator
    weeklyBurnAmount = utils.math.divide(weeklyBurnAmount, tostring(config.MINT_BURN_RATE_WEEKLY_DEN))

    -- Same for CAP_PERCENTAGE
    local weeklyCap = utils.math.multiply(weeklyBurnAmount, tostring(config.CAP_PERCENTAGE_NUM))
    weeklyCap = utils.math.divide(weeklyCap, tostring(config.CAP_PERCENTAGE_DEN))

    local periodCap = utils.math.divide(weeklyCap, '2016')

    if utils.math.isGreaterThan(emission, periodCap) then
      emission = periodCap
    end
  end

  return emission
end

-- Count total unique stakers across all tokens
local function countUniqueStakers()
  local uniqueStakers = {}
  local stakingPositions = state.getStakingPositions()

  for token, tokenPositions in pairs(stakingPositions) do
    for staker, position in pairs(tokenPositions) do
      if position and utils.math.isPositive(position.amount) then
        uniqueStakers[staker] = true
      end
    end
  end

  local count = 0
  for _ in pairs(uniqueStakers) do
    count = count + 1
  end

  return count
end

-- Get  unique stakers across all tokens
local function uniqueStakersByAddress()
  local seen = {}
  local result = {}
  local stakingPositions = state.getStakingPositions()

  for _, tokenPositions in pairs(stakingPositions) do
    for staker, position in pairs(tokenPositions) do
      if position and utils.math.isPositive(position.amount) and not seen[staker] then
        seen[staker] = true
        table.insert(result, staker)
      end
    end
  end

  return result
end


-- Calculate total stake weight for all tokens
local function calculateTotalStakeWeight()
  local totalWeight = '0'
  local stakingPositions = state.getStakingPositions()




  for token, tokenPositions in pairs(stakingPositions) do
    local tokenWeight = TokenWeights[token] or '100'

    for staker, position in pairs(tokenPositions) do
      if position and utils.math.isPositive(position.amount) then
        local positionWeight


        positionWeight = utils.math.multiply(position.amount, tokenWeight)

        totalWeight = utils.math.add(totalWeight, positionWeight)
      end
    end
  end

  return totalWeight
end

-- Calculate individual staker allocations based on their stake weight
local function calculateStakerAllocations(totalEmission)
  local allocations = {}
  local minnows = {} -- Track stakers with small weights
  local totalStakeWeight = calculateTotalStakeWeight()

  -- If no stakes, return empty allocations
  if utils.math.isZero(totalStakeWeight) then
    return allocations
  end

  -- Reserve 10% for minnows
  local minnowsReserve = utils.math.divide(utils.math.multiply(totalEmission, '10'), '100')
  local whalesEmission = utils.math.subtract(totalEmission, minnowsReserve)

  -- Track rounding errors to distribute later
  local totalAllocated = '0'
  local stakingPositions = state.getStakingPositions()

  -- Calculate individual allocations with higher precision for whales
  for token, tokenPositions in pairs(stakingPositions) do
    local tokenWeight = TokenWeights[token] or '100'

    for staker, position in pairs(tokenPositions) do
      if position and utils.math.isPositive(position.amount) then
        local stakerWeight = utils.math.multiply(position.amount, tokenWeight)

        -- Calculate allocation with higher precision
        -- First multiply by emission and precision factor before division
        local weightedEmission = utils.math.multiply(whalesEmission, stakerWeight)
        local precisionWeightedEmission = utils.math.multiply(weightedEmission, tostring(rewards.PRECISION_FACTOR))
        local allocation = utils.math.divide(precisionWeightedEmission, totalStakeWeight)

        -- Remove precision factor
        allocation = utils.math.divide(allocation, tostring(rewards.PRECISION_FACTOR))

        -- Track total allocated
        totalAllocated = utils.math.add(totalAllocated, allocation)

        -- Store allocation for regular stakers
        if utils.math.isPositive(allocation) then
          if not allocations[staker] then
            allocations[staker] = '0'
          end
          allocations[staker] = utils.math.add(allocations[staker], allocation)
        elseif utils.math.isPositive(stakerWeight) then
          -- This is a minnow (weight too small to get an allocation)
          table.insert(minnows, {
            staker = staker,
            weight = stakerWeight
          })
        end
      end
    end
  end

  -- Sort minnows by weight from highest to lowest
  table.sort(minnows, function(a, b)
    return utils.math.isGreaterThan(a.weight, b.weight)
  end)

  -- Distribute minnow reserve equally, prioritizing by weight
  if #minnows > 0 then
    -- Calculate minnow share but ensure it's at least 1
    local minnowShare = utils.math.divide(minnowsReserve, tostring(#minnows))
    if utils.math.isLessThan(minnowShare, '1') then
      minnowShare = '1'
    end

    -- Keep track of remaining reserve
    local remainingReserve = minnowsReserve

    -- Distribute to minnows until reserve is exhausted
    for _, minnow in ipairs(minnows) do
      -- Check if we still have enough in the reserve
      if utils.math.isGreaterThanOrEqual(remainingReserve, minnowShare) then
        if not allocations[minnow.staker] then
          allocations[minnow.staker] = '0'
        end
        allocations[minnow.staker] = utils.math.add(allocations[minnow.staker], minnowShare)
        totalAllocated = utils.math.add(totalAllocated, minnowShare)
        remainingReserve = utils.math.subtract(remainingReserve, minnowShare)
      else
        -- We've run out of the reserve, so break the loop
        break
      end
    end

    -- If there's any leftover in the reserve, distribute proportionally to whales
    if utils.math.isPositive(remainingReserve) and utils.math.isPositive(totalAllocated) then
      for staker, allocation in pairs(allocations) do
        local share = utils.math.divide(
          utils.math.multiply(allocation, remainingReserve),
          totalAllocated
        )
        allocations[staker] = utils.math.add(allocations[staker], share)
      end
    end
  else
    -- If no minnows, add the reserved amount back to the total allocated
    -- and distribute proportionally to existing stakers
    for staker, allocation in pairs(allocations) do
      local share = utils.math.divide(
        utils.math.multiply(allocation, minnowsReserve),
        totalAllocated
      )
      allocations[staker] = utils.math.add(allocations[staker], share)
    end
  end

  return allocations
end

-- Calculate ownership percentage for a specific staker
local function calculateStakeOwnership(staker)
  local totalStakeWeight = '0'
  local stakerWeight = '0'
  local stakingPositions = state.getStakingPositions()




  -- Calculate total weighted stake across all tokens
  for token, tokenPositions in pairs(stakingPositions) do
    local tokenWeight = TokenWeights[token] or '100'

    -- Calculate weights for all stakers
    for addr, position in pairs(tokenPositions) do
      if position and utils.math.isPositive(position.amount) then
        local weight

        weight = utils.math.multiply(position.amount, tokenWeight)

        totalStakeWeight = utils.math.add(totalStakeWeight, weight)

        -- Calculate this staker's weight if it matches
        if addr == staker then
          stakerWeight = utils.math.add(stakerWeight, weight)
        end
      end
    end
  end

  -- Return data
  return {
    totalWeight = totalStakeWeight,
    stakerWeight = stakerWeight
  }
end




-- Handler implementations for rewards operations
rewards.handlers = {
  -- Handler for requesting token rewards distribution
  requestRewards = function(msg)
    security.assertNotPaused()

    -- Verify caller is authorized
    assert(msg.From == rewards.CRON_CALLER or msg.From == ao.id,
      'Request is not from the trusted Cron or contract owner!')

    local currentTime = os.time()
    assert(currentTime >= LastRewardTimestamp + 300000, 'Too soon for next reward distribution')

    -- Calculate new tokens to mint this period
    local newTokens = calculateEmission()

    -- If no tokens to distribute, exit early
    if newTokens == '0' then
      msg.reply({
        Action = 'Rewards-Distribution',
        Status = 'No-Tokens',
        Message = 'No tokens available for distribution'
      })
      return
    end

    -- Calculate allocation for each staker
    local allocations = calculateStakerAllocations(newTokens)
    Send({
      Target = rewards.TREASURY,
      Action = 'Distribute-Rewards',
      Data = json.encode(allocations),
    })

    -- Update state
    CurrentRewards = utils.math.add(CurrentRewards, newTokens)
    LastRewardTimestamp = currentTime


    -- Reply with distribution summary
    msg.reply({
      Action = 'Rewards-Distribution',
      Status = 'Success',
      ['Total-Amount'] = newTokens,
      ['Timestamp'] = tostring(currentTime),
      ['Remaining-Supply'] = utils.math.subtract(rewards.TOTAL_SUPPLY, CurrentRewards)
    })
  end,



  -- Handler for getting reward statistics
  getRewardStats = function(msg)
    local totalSupplyBint = rewards.TOTAL_SUPPLY
    local currentRewardsBint = bint(CurrentRewards)
    local remainingRewards = totalSupplyBint - currentRewardsBint

    -- Calculate daily emission rate
    local dailyEmission = '0'
    if remainingRewards > bint.zero() then
      local periodRateFixed = math.floor((rewards.EMISSION_RATE_PER_MONTH / rewards.PERIODS_PER_MONTH) * 10 ^ 8)
      local periodRateBint = bint(periodRateFixed)
      dailyEmission = utils.math.toBalanceValue(
        bint.__idiv(remainingRewards * periodRateBint * bint(288), bint(10 ^ 8))
      )
    end

    -- Prepare statistics
    local stats = {
      totalSupply = utils.math.toBalanceValue(totalSupplyBint),
      currentRewards = utils.math.toBalanceValue(currentRewardsBint),
      remainingRewards = utils.math.toBalanceValue(remainingRewards),
      dailyEmissionRate = dailyEmission,
      lastDistribution = LastRewardTimestamp,
      uniqueStakers = countUniqueStakers(),
      tokenWeights = TokenWeights
    }

    -- Reply with statistics
    msg.reply({
      Action = 'Reward-Stats',
      Data = json.encode(stats),
      ['Total-Supply'] = utils.math.toBalanceValue(totalSupplyBint),
      ['Current-Supply'] = utils.math.toBalanceValue(currentRewardsBint),
      ['Remaining-Supply'] = utils.math.toBalanceValue(remainingRewards),
      ['Daily-Emission'] = dailyEmission,
      ['Last-Distribution'] = tostring(LastRewardTimestamp),
      ['Unique-Stakers'] = tostring(stats.uniqueStakers)
    })
  end,

  -- Handler for getting stake ownership percentage
  -- Handler for getting stake ownership percentage
  getStakeOwnership = function(msg)
    -- Input validation
    local staker = msg.Tags.Staker
    assert(type(staker) == 'string', 'Staker address is required!')

    -- Get ownership data
    local ownershipData = calculateStakeOwnership(staker)
    local totalWeight = ownershipData.totalWeight
    local stakerWeight = ownershipData.stakerWeight

    -- Gather token weights info with names
    local tokenWeightsInfo = {}
    for tokenAddr, weight in pairs(TokenWeights) do
      table.insert(tokenWeightsInfo, {
        address = tokenAddr,
        name = config.AllowedTokensNames[tokenAddr] or 'Unknown Token',
        weight = weight
      })
    end

    -- Handle case where there are no stakes
    if utils.math.isZero(totalWeight) then
      msg.reply({
        Action = 'Stake-Ownership',
        Staker = staker,
        ['Ownership-Percentage'] = '0.000000',
        Data = json.encode({
          percentage = '0.000000',
          stakerWeight = '0',
          totalWeight = '0',
          tokenWeights = tokenWeightsInfo
        })
      })
      return
    end

    -- Calculate ownership percentage with 6 decimal places of precision
    local scaledStakerWeight = utils.math.multiply(stakerWeight, '100000000') -- Scale up for percentage calculation
    local ownershipPercentage = utils.math.divide(scaledStakerWeight, totalWeight)

    -- Format to 6 decimal places
    local ownershipPercentageStr = string.format('%.6f', tonumber(ownershipPercentage) / 1000000)

    -- Reply with ownership details
    msg.reply({
      Action = 'Stake-Ownership',
      Staker = staker,
      ['Ownership-Percentage'] = ownershipPercentageStr,
      Data = json.encode({
        percentage = ownershipPercentageStr,
        stakerWeight = stakerWeight,
        totalWeight = totalWeight,
        tokenWeights = tokenWeightsInfo
      })
    })
  end,

  -- Handler for getting unique stakers count
  getUniqueStakers = function(msg)
    local uniqueCount = countUniqueStakers()
    local stakers = uniqueStakersByAddress()

    msg.reply({
      Action = 'Unique-Stakers',
      Count = tostring(uniqueCount),
      Data = tostring(uniqueCount),
      Stakers = json.encode(stakers)
    })
  end,

  -- Handler for getting token stakes breakdown
  getTokenStakes = function(msg)
    local tokenStats = {}
    local stakingPositions = state.getStakingPositions()

    for token, tokenPositions in pairs(stakingPositions) do
      local totalStaked = '0'
      local stakerCount = 0

      for _, position in pairs(tokenPositions) do
        if position and utils.math.isPositive(position.amount) then
          totalStaked = utils.math.add(totalStaked, position.amount)
          stakerCount = stakerCount + 1
        end
      end

      table.insert(tokenStats, {
        address = token,
        name = config.AllowedTokensNames[token],
        totalStaked = totalStaked,
        stakerCount = stakerCount,
        weight = TokenWeights[token] or '100'
      })
    end

    msg.reply({
      Action = 'Token-Stakes',
      Data = json.encode(tokenStats)
    })
  end,

  -- Handler for updating the MINT token supply
  updateMintSupply = function(msg)
    -- Verify caller is authorized
    assert(msg.From == rewards.MINT_POLICY or msg.From == ao.id,
      'Request is not from the trusted Cron or contract owner!')

    local totalSupplyValue = msg.Data
    assert(totalSupplyValue ~= nil, 'Total-Supply value is required')

    utils.logEvent('MintSupplyUpdated', {
      previousValue = rewards.MINT_TOKEN_SUPPLY,
      newValue = totalSupplyValue,
      updatedBy = msg.From,
      timestamp = os.time()
    })

    msg.reply({
      Action = 'MINT-Supply-Updated',
      Status = 'Success',
      ['Previous-Supply'] = rewards.MINT_TOKEN_SUPPLY,
      ['New-Supply'] = totalSupplyValue,
      ['Timestamp'] = tostring(os.time())
    })

    rewards.MINT_TOKEN_SUPPLY = totalSupplyValue
  end,

  distributeRewardsResponse = function(msg)
    -- empty handler to prevent message from going to cli
  end
}





return rewards
