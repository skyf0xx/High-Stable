local json = require('json')
local bint = require('.bint')(256)
local MINT_PROTOCOL = 'lNtrei6YLQiWS8cyFFHDrOBvRzICQPTvrjZBP8fz-ZI'
local MINT_TOKEN = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'

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
--[[
     Distribute Rewards
   ]]
--
Handlers.add('distributeRewards', Handlers.utils.hasMatchingTag('Action', 'Distribute-Rewards'), function(msg)
  local allocations = json.decode(msg.Data)
  assert(msg.From == MINT_PROTOCOL, 'Message not from trusted process!')
  assert(type(allocations) == 'table', 'Rewards must be a valid array')

  local currentTime = os.time()

  for staker, amount in pairs(allocations) do
    -- Only include non-zero allocations
    if utils.math.isPositive(amount) then
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
  })
end)
