local json = require('json')
local bint = require('.bint')(256)
local MINT_PROTOCOL = 'lNtrei6YLQiWS8cyFFHDrOBvRzICQPTvrjZBP8fz-ZI'
local MINT_TOKEN = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'

-- Initialize rewards tracking if it doesn't exist yet
AccumulatedRewards = AccumulatedRewards or {}
TotalDistributedRewards = TotalDistributedRewards or '0'
LastDistributionTime = LastDistributionTime or 0

local utils = {}

-- Math operations using bint
utils.math = {
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

  isGreaterThan = function(a, b)
    return bint(a) > bint(b)
  end,

  isLessThan = function(a, b)
    return bint(a) < bint(b)
  end,

  isZero = function(a)
    return bint(a) == bint.zero()
  end,

  isPositive = function(a)
    return bint(a) > bint.zero()
  end,

  isEqual = function(a, b)
    return bint(a) == bint(b)
  end
}

-- Function to track rewards for an address
local function trackRewards(address, amount)
  -- Initialize rewards for this address if not already existing
  if not AccumulatedRewards[address] then
    AccumulatedRewards[address] = {
      total = '0',
      lastReceived = '0',
      lastDistributionTime = 0,
      distributions = 0
    }
  end

  -- Update rewards tracking
  AccumulatedRewards[address].total = utils.math.add(AccumulatedRewards[address].total, amount)
  AccumulatedRewards[address].lastReceived = amount
  AccumulatedRewards[address].lastDistributionTime = os.time()
  AccumulatedRewards[address].distributions = AccumulatedRewards[address].distributions + 1

  -- Update global tracking
  TotalDistributedRewards = utils.math.add(TotalDistributedRewards, amount)
  LastDistributionTime = os.time()
end

--[[
     Distribute Rewards
   ]]
--
Handlers.add('distributeRewards', Handlers.utils.hasMatchingTag('Action', 'Distribute-Rewards'), function(msg)
  local allocations = json.decode(msg.Data)
  assert(msg.From == MINT_PROTOCOL, 'Message not from trusted process!')
  assert(type(allocations) == 'table', 'Rewards must be a valid array')

  local currentTime = os.time()
  local totalDistributed = '0'

  for staker, amount in pairs(allocations) do
    -- Only include non-zero allocations
    if utils.math.isPositive(amount) then
      -- Track rewards for this address
      trackRewards(staker, amount)
      totalDistributed = utils.math.add(totalDistributed, amount)

      -- Send reward token to staker
      Send({
        Target = MINT_TOKEN,
        Action = 'Transfer',
        Recipient = staker,
        Quantity = amount,
        Cast = 'true',
        ['X-Reward-Type'] = 'Staking-Reward',
        ['X-Distribution-Time'] = tostring(currentTime)
      })
    end
  end

  msg.reply({
    Action = 'Distribute-Rewards-Response',
    Data = 'Rewards Distributed',
    ['Total-Distributed'] = totalDistributed,
    ['Distribution-Time'] = tostring(currentTime),
    ['Grand-Total-Distributed'] = TotalDistributedRewards
  })
end)

--[[
     Get Accumulated Rewards
   ]]
--
Handlers.add('getAccumulatedRewards', Handlers.utils.hasMatchingTag('Action', 'Get-Accumulated-Rewards'), function(msg)
  local address = msg.Tags.Address or msg.From
  local includeAll = msg.Tags['Include-All'] == 'true'

  local result = {}

  if includeAll then
    -- Return rewards for all addresses
    for addr, rewards in pairs(AccumulatedRewards) do
      result[addr] = rewards
    end
  else
    -- Return rewards for a specific address
    if AccumulatedRewards[address] then
      result = AccumulatedRewards[address]
    else
      result = {
        total = '0',
        lastReceived = '0',
        lastDistributionTime = 0,
        distributions = 0
      }
    end
  end

  -- Add summary data
  local summary = {
    totalAddresses = 0,
    totalDistributed = TotalDistributedRewards,
    lastDistributionTime = LastDistributionTime
  }

  -- Count total addresses that have received rewards
  for _ in pairs(AccumulatedRewards) do
    summary.totalAddresses = summary.totalAddresses + 1
  end

  msg.reply({
    Action = 'Accumulated-Rewards',
    Address = includeAll and 'all' or address,
    Data = json.encode(result),
    Summary = json.encode(summary),
    ['Total-Received'] = includeAll and TotalDistributedRewards or
    (AccumulatedRewards[address] and AccumulatedRewards[address].total or '0'),
    ['Last-Distribution-Time'] = tostring(LastDistributionTime),
    ['Total-Addresses'] = tostring(summary.totalAddresses)
  })
end)

--[[
     Get Rewards Distribution Summary
   ]]
--
Handlers.add('getRewardsSummary', Handlers.utils.hasMatchingTag('Action', 'Get-Rewards-Summary'), function(msg)
  -- Calculate summary statistics
  local summary = {
    totalDistributed = TotalDistributedRewards,
    totalRecipients = 0,
    lastDistributionTime = LastDistributionTime,
    topRecipients = {}
  }

  -- Create an array for sorting
  local addressList = {}
  for addr, rewards in pairs(AccumulatedRewards) do
    summary.totalRecipients = summary.totalRecipients + 1
    table.insert(addressList, {
      address = addr,
      total = rewards.total,
      distributions = rewards.distributions
    })
  end

  -- Sort by total rewards (descending)
  table.sort(addressList, function(a, b)
    return utils.math.isGreaterThan(a.total, b.total)
  end)

  -- Take top 10 recipients
  for i = 1, math.min(10, #addressList) do
    table.insert(summary.topRecipients, addressList[i])
  end

  msg.reply({
    Action = 'Rewards-Summary',
    Data = json.encode(summary),
    ['Total-Distributed'] = TotalDistributedRewards,
    ['Total-Recipients'] = tostring(summary.totalRecipients),
    ['Last-Distribution-Time'] = tostring(LastDistributionTime)
  })
end)
