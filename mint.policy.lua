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

-- Constants
local Denomination = 8
local TRUSTED_CRON = 'fzBx5uPGi2e_dBbBvwKlh6BbrTLyVJ1YVGlFS1el0uI'
local MINT_TOKEN = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'
local WEEKLY_BURN_RATE = 0.0025                                         -- 0.25%
local FINAL_SUPPLY = utils.toBalanceValue(21000000 * 10 ^ Denomination) -- 21M tokens with 8 decimal places
local PRECISION_FACTOR = bint(10 ^ Denomination)                        -- For percentage calculations

-- Function to get current supply from token contract
local function getCurrentSupply(callback)
  ao.send({
    Target = MINT_TOKEN,
    Action = 'Total-Supply'
  }).onReply(function(reply)
    if reply.Data then
      callback(reply.Data)
    else
      error('Failed to get total supply from token contract')
    end
  end)
end

--[[
  Update the current supply by reducing it according to the weekly burn rate
  The supply cannot go below FINAL_SUPPLY
]]
Handlers.add('update-supply', Handlers.utils.hasMatchingTag('Action', 'Update-Supply'),
  function(msg)
    assert(TRUSTED_CRON == msg.From or ao.id == msg.From, 'Request is not from the trusted Process!')

    getCurrentSupply(function(currentSupply)
      assert(bint(currentSupply) > bint(FINAL_SUPPLY), 'Current supply must be greater than final supply')

      -- Calculate new supply with burn rate
      -- First convert rate to fixed point number with 8 decimal places
      local burnRateFixed = math.floor((1 - WEEKLY_BURN_RATE) * 10 ^ Denomination)
      local newSupply = utils.multiply(currentSupply, burnRateFixed)
      newSupply = utils.divide(newSupply, tostring(PRECISION_FACTOR))

      -- Check if new supply would be below final supply
      if bint(newSupply) > bint(FINAL_SUPPLY) then
        -- Send rebase request to token contract
        ao.send({
          Target = MINT_TOKEN,
          Action = 'Rebase',
          NewSupply = newSupply
        })
      else
        -- If we would go below final supply, set to final supply
        ao.send({
          Target = MINT_TOKEN,
          Action = 'Rebase',
          NewSupply = FINAL_SUPPLY
        })
      end
    end)
  end)
