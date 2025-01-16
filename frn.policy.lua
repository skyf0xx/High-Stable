local bint = require('.bint')(256)
local ao = require('ao')

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
    return tostring(bint(a) // bint(b))
  end,
  toBalanceValue = function(a)
    return tostring(bint(a))
  end,
  toNumber = function(a)
    return tonumber(a)
  end
}


local Denomination = 8
local StartingSupply = utils.toBalanceValue(37500000 * 10 ^ Denomination)
CurrentSupply = CurrentSupply or StartingSupply

-- Constants
local TOKEN_OWNER = 'to_update'
local WEEKLY_BURN_RATE = 0.0025                                         -- 0.25%
local FINAL_SUPPLY = utils.toBalanceValue(21000000 * 10 ^ Denomination) -- 21M tokens with 8 decimal places
local PRECISION_FACTOR = bint(10 ^ Denomination)                        -- For percentage calculations

--[[
  Update the current supply by reducing it according to the weekly burn rate
  The supply cannot go below FINAL_SUPPLY
]]
Handlers.add('update-supply', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    assert(bint(CurrentSupply) > bint(FINAL_SUPPLY), 'Current supply must be greater than final supply')

    -- Calculate new supply with burn rate
    -- First convert rate to fixed point number with 8 decimal places
    local burnRateFixed = math.floor((1 - WEEKLY_BURN_RATE) * 10 ^ Denomination)
    local newSupply = utils.multiply(CurrentSupply, burnRateFixed)
    newSupply = math.floor(utils.divide(newSupply, tostring(PRECISION_FACTOR)))

    -- Check if new supply would be below final supply
    if bint(newSupply) > bint(FINAL_SUPPLY) then
      CurrentSupply = newSupply
    else
      CurrentSupply = FINAL_SUPPLY
    end

    ao.send({
      Target = TOKEN_OWNER,
      Action = 'Rebase',
      NewSupply = newSupply
    })
  end)
