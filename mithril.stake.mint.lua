Variant = '0.0.1'
local bint = require('.bint')(256)
local tableUtils = require('.utils')
local allowedTokens = { stETH = 'xxxx', stSOL = 'yyy' }


--[[
  Initialize the staker table. stakers[token][user] = balance
]]
---@return table<string, table>
function UpdateAllowedTokens()
  local stakers = {}
  for _, token in pairs(allowedTokens) do
    stakers[token] = {}
  end
  return stakers
end

Stakers = Stakers or UpdateAllowedTokens()


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

Handlers.add('stake', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
  function(msg)
    -- credit notice is sent by the token process to the staking contract
    local token = msg.From
    local quantity = msg.Quantity
    local stakeable = tableUtils.includes(token, tableUtils.values(allowedTokens))
    local sender = msg.Sender
    local tokenName = TokenName(token)

    --don't bother to refund unstakeable tokens - to prevent being drained through spurious fees
    assert(type(stakeable) == true, 'Token: ' .. token .. ' is not stakable and was ignored!')
    assert(bint(0) < bint(quantity), 'Quantity must be greater than zero!')

    if not Stakers[token][sender] then Stakers[token][sender] = '0' end

    Stakers[token][sender] = utils.add(Stakers[token][sender], quantity)

    ao.send({
      Target = sender,
      Data = Colors.gray ..
        'You have staked a total of ' ..
        Colors.blue .. Stakers[token][sender] .. Colors.reset .. ' ' .. tokenName
    })
  end)



Handlers.add('unstake', Handlers.utils.hasMatchingTag('Action', 'Unstake'),
  function(msg)
    local from = msg.From
    local token = msg.Tags['Token']
    local stakeable = tableUtils.includes(token, tableUtils.values(allowedTokens))
    local quantity = Stakers[token][from] or '0'
    local tokenName = TokenName(token)

    assert(type(stakeable) == true, 'Token: ' .. token .. ' is not stakable and was ignored!')
    assert(bint(0) < bint(quantity), 'You need to have more than zero staked tokens!')

    Stakers[token][from] = nil

    --send the staked tokens back to the user
    ao.send({
      Target = token,
      Action = 'Transfer',
      Recipient = from,
      Quantity = quantity,
      ['X-Message'] = 'Mithril Unstake',
      ['X-Staked-Balance-Remaining-' .. tokenName] = '0'
    })

    ao.send({
      Target = from,
      Data = Colors.gray ..
        'Successfully unstaked ' ..
        Colors.blue .. quantity .. Colors.reset .. ' ' .. tokenName
    })
  end)



