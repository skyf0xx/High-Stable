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
rewards.REWARD_TOKEN =
'EYjk_qnq9MOKaHeAlTBm8D0pnjH0nPLPoN6l8WCbynA'                       --config.MINT_TOKEN                            -- Use the configured MINT token
rewards.DENOMINATION = 18                                           --config.TOKEN_DECIMALS[config.MINT_TOKEN]                 -- Use the configured MINT token decimals
rewards.TOTAL_SUPPLY = bint(5000000) * bint(10 ^ rewards.DENOMINATION)
-- Initialize state variables if they don't exist
CurrentSupply = CurrentSupply or '0'           -- tracks current supply of reward tokens
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
  end
}

-- Calculate emission for the current period based on declining curve
local function calculateEmission()
  -- Convert values to bint early to avoid overflow
  local totalSupplyBint = rewards.TOTAL_SUPPLY
  local currentSupplyBint = bint(CurrentSupply)
  local remainingSupply = totalSupplyBint - currentSupplyBint

  -- If no supply remaining, return 0
  if remainingSupply <= bint.zero() then
    return '0'
  end

  -- Calculate the emission rate for a 5-minute period
  -- Convert rate to a fixed-point number with 8 decimal places for precision
  local periodRateFixed = math.floor((rewards.EMISSION_RATE_PER_MONTH / rewards.PERIODS_PER_MONTH) * 10 ^ 8)
  local periodRateBint = bint(periodRateFixed)

  -- Calculate tokens to emit this period
  -- First multiply by rate, then divide by 10^8 to get back to normal scale
  local emission = bint.__idiv(remainingSupply * periodRateBint, bint(10 ^ 8))

  -- Double check we don't exceed remaining supply
  if emission > remainingSupply then
    emission = remainingSupply
  end

  return utils.math.toBalanceValue(emission)
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

-- Calculate total stake weight for all tokens
local function calculateTotalStakeWeight()
  local totalWeight = '0'
  local stakingPositions = state.getStakingPositions()

  for token, tokenPositions in pairs(stakingPositions) do
    local tokenWeight = TokenWeights[token] or '100'

    for _, position in pairs(tokenPositions) do
      if position and utils.math.isPositive(position.amount) then
        local positionWeight = utils.math.multiply(position.amount, tokenWeight)
        totalWeight = utils.math.add(totalWeight, positionWeight)
      end
    end
  end

  return totalWeight
end

-- Calculate individual staker allocations based on their stake weight
local function calculateStakerAllocations(totalEmission)
  local allocations = {}
  local totalStakeWeight = calculateTotalStakeWeight()

  -- If no stakes, return empty allocations
  if utils.math.isZero(totalStakeWeight) then
    return allocations
  end

  -- Track rounding errors to distribute later
  local totalAllocated = '0'
  local stakingPositions = state.getStakingPositions()

  -- Calculate individual allocations with higher precision
  for token, tokenPositions in pairs(stakingPositions) do
    local tokenWeight = TokenWeights[token] or '100'

    for staker, position in pairs(tokenPositions) do
      if position and utils.math.isPositive(position.amount) then
        local stakerWeight = utils.math.multiply(position.amount, tokenWeight)

        -- Calculate allocation with higher precision
        -- First multiply by emission and precision factor before division
        local weightedEmission = utils.math.multiply(totalEmission, stakerWeight)
        local precisionWeightedEmission = utils.math.multiply(weightedEmission, tostring(rewards.PRECISION_FACTOR))
        local allocation = utils.math.divide(precisionWeightedEmission, totalStakeWeight)

        -- Remove precision factor
        allocation = utils.math.divide(allocation, tostring(rewards.PRECISION_FACTOR))

        -- Track total allocated
        totalAllocated = utils.math.add(totalAllocated, allocation)

        -- Store allocation
        if utils.math.isPositive(allocation) then
          if not allocations[staker] then
            allocations[staker] = '0'
          end
          allocations[staker] = utils.math.add(allocations[staker], allocation)
        end
      end
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
        -- Calculate weight
        local weight = utils.math.multiply(position.amount, tokenWeight)
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

    -- Prepare reward distributions
    local distributions = {}
    for staker, amount in pairs(allocations) do
      -- Only include non-zero allocations
      if utils.math.isPositive(amount) then
        table.insert(distributions, {
          address = staker,
          amount = amount
        })


        -- Send reward token to staker
        Send({
          Target = rewards.REWARD_TOKEN,
          Action = 'Transfer',
          Recipient = staker,
          Quantity = amount,
          ['X-Reward-Type'] = 'Staking-Reward',
          ['X-Distribution-Time'] = tostring(currentTime)
        })
      end
    end

    -- Update state
    CurrentSupply = utils.math.add(CurrentSupply, newTokens)
    LastRewardTimestamp = currentTime

    -- Log the distribution
    utils.logEvent('RewardsDistributed', {
      timestamp = currentTime,
      totalAmount = newTokens,
      recipients = #distributions,
      remainingSupply = utils.math.subtract(rewards.TOTAL_SUPPLY, CurrentSupply)
    })

    -- Reply with distribution summary
    msg.reply({
      Action = 'Rewards-Distribution',
      Status = 'Success',
      ['Total-Amount'] = newTokens,
      ['Recipients'] = tostring(#distributions),
      ['Timestamp'] = tostring(currentTime),
      ['Remaining-Supply'] = utils.math.subtract(rewards.TOTAL_SUPPLY, CurrentSupply)
    })
  end,



  -- Handler for getting reward statistics
  getRewardStats = function(msg)
    local totalSupplyBint = rewards.TOTAL_SUPPLY
    local currentSupplyBint = bint(CurrentSupply)
    local remainingSupply = totalSupplyBint - currentSupplyBint

    -- Calculate daily emission rate
    local dailyEmission = '0'
    if remainingSupply > bint.zero() then
      local periodRateFixed = math.floor((rewards.EMISSION_RATE_PER_MONTH / rewards.PERIODS_PER_MONTH) * 10 ^ 8)
      local periodRateBint = bint(periodRateFixed)
      dailyEmission = utils.math.toBalanceValue(
        bint.__idiv(remainingSupply * periodRateBint * bint(288), bint(10 ^ 8))
      )
    end

    -- Prepare statistics
    local stats = {
      totalSupply = utils.math.toBalanceValue(totalSupplyBint),
      currentSupply = utils.math.toBalanceValue(currentSupplyBint),
      remainingSupply = utils.math.toBalanceValue(remainingSupply),
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
      ['Current-Supply'] = utils.math.toBalanceValue(currentSupplyBint),
      ['Remaining-Supply'] = utils.math.toBalanceValue(remainingSupply),
      ['Daily-Emission'] = dailyEmission,
      ['Last-Distribution'] = tostring(LastRewardTimestamp),
      ['Unique-Stakers'] = tostring(stats.uniqueStakers)
    })
  end,

  -- Handler for getting stake ownership percentage
  getStakeOwnership = function(msg)
    -- Input validation
    local staker = msg.Tags.Staker
    assert(type(staker) == 'string', 'Staker address is required!')

    -- Get ownership data
    local ownershipData = calculateStakeOwnership(staker)
    local totalWeight = ownershipData.totalWeight
    local stakerWeight = ownershipData.stakerWeight

    -- Handle case where there are no stakes
    if utils.math.isZero(totalWeight) then
      msg.reply({
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

    -- Calculate ownership percentage with 6 decimal places of precisionse
    local scaledStakerWeight = utils.math.multiply(stakerWeight, '100')
    scaledStakerWeight = utils.math.multiply(scaledStakerWeight, tostring(rewards.PRECISION_FACTOR))
    local ownershipPercentageBint = utils.math.divide(scaledStakerWeight, totalWeight)

    -- Convert to string with proper decimal places
    local percentageValue = utils.math.divide(ownershipPercentageBint, tostring(rewards.PRECISION_FACTOR))
    local ownershipPercentageStr = string.format('%.6f', tonumber(percentageValue))

    -- Reply with ownership details
    msg.reply({
      Action = 'Stake-Ownership',
      Staker = staker,
      ['Ownership-Percentage'] = ownershipPercentageStr,
      Data = json.encode({
        percentage = ownershipPercentageStr,
        stakerWeight = stakerWeight,
        totalWeight = totalWeight
      })
    })
  end,

  -- Handler for getting unique stakers count
  getUniqueStakers = function(msg)
    local uniqueCount = countUniqueStakers()

    msg.reply({
      Action = 'Unique-Stakers',
      Count = tostring(uniqueCount),
      Data = tostring(uniqueCount)
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
  end
}

return rewards
