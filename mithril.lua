local bint = require('.bint')(256)
local ao = require('ao')
local MonetaryPolicyProcess = '_disabled_' --enabled after Transfer lock period
local MINT_PROCESS = 'xxx'
local TRANSFER_LOCK_TIMESTAMP = 1740720000 -- February 28, 2025 00:00:00 UTC

--[[
  This module implements the ao Standard Token Specification.

  Terms:
    Sender: the wallet or Process that sent the Message

  It will first initialize the internal state, and then attach handlers,
    according to the ao Standard Token Spec API:

    - Info(): return the token parameters, like Name, Ticker, Logo, and Denomination

    - Balance(Target?: string): return the token balance of the Target. If Target is not provided, the Sender
        is assumed to be the Target

    - Balances(): return the token balance of all participants

    - Transfer(Target: string, Quantity: number): if the Sender has a sufficient balance, send the specified Quantity
        to the Target. It will also issue a Credit-Notice to the Target and a Debit-Notice to the Sender

    - Mint(Quantity: number): if the Sender matches the Process Owner, then mint the desired Quantity of tokens, adding
        them the Processes' balance
]]
--
local json = require('json')

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
  rebase function to update the supply and gons per token
]]
--
---@param newSupply string
function Rebase(newSupply)
  GonsPerToken = bint.__idiv(bint(TotalGons), bint(newSupply))
  TotalSupply = newSupply
end

--[[
     Initialize State

     ao.id is equal to the Process.Id
   ]]
--
Variant = '0.0.3'

-- token should be idempotent and not change previous state updates
Denomination = Denomination or 8
--total MTH supply (externally displayed balance)
---@type string
TotalSupply = TotalSupply or utils.toBalanceValue(21e6 * 10 ^ Denomination)

--[[
    Internal balance calculation is handled in "gons"
    TotalGons is a multiple of InitialSupply so that GonsPerToken is an integer.
    Use the highest integer value for TotalGons for max granularity.
   ]]
---@type string
TotalGons = TotalGons or utils.toBalanceValue(bint.maxinteger() - (bint.maxinteger() % bint(TotalSupply)))


---@type Bint
GonsPerToken = GonsPerToken or bint.zero()
if (GonsPerToken == bint.zero()) then
  Rebase(TotalSupply)
end


Balances = Balances or { [ao.id] = TotalGons }

Name = Name or 'Number Always Bigger'
Ticker = Ticker or 'NAB'
Logo = Logo or 'LQ4crOHN9qO6JsLNs253AaTch6MgAMbM8PKqBxs4hgI' --TODO: Update Logo

--[[
     Add handlers for each incoming Action defined by the ao Standard Token Specification
   ]]
--

--[[
     Info
   ]]
--
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
  ao.send({
    Target = msg.From,
    Name = Name,
    Ticker = Ticker,
    Logo = Logo,
    Denomination = tostring(Denomination)
  })
end)

--[[
     Balance
   ]]
--
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
  local bal = '0'

  -- If not Recipient is provided, then return the Senders balance
  if (msg.Tags.Recipient and Balances[msg.Tags.Recipient]) then
    bal = Balances[msg.Tags.Recipient]
  elseif msg.Tags.Target and Balances[msg.Tags.Target] then
    bal = Balances[msg.Tags.Target]
  elseif Balances[msg.From] then
    bal = Balances[msg.From]
  end

  local MTHBalance = utils.toBalanceValue(bint.__idiv(bint(bal), GonsPerToken))



  ao.send({
    Target = msg.From,
    Balance = MTHBalance,
    Ticker = Ticker,
    Account = msg.Tags.Recipient or msg.From,
    Data = MTHBalance
  })
end)

--[[
     Balances
   ]]
--
Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'),
  function(msg)
    local MTHBalances = {}

    for i = 1, #Balances do
      local MTHBalance = utils.toBalanceValue(bint.__idiv(bint(Balances[i]), GonsPerToken))
      table.insert(MTHBalances, MTHBalance)
    end

    ao.send({ Target = msg.From, Data = json.encode(MTHBalances) })
  end)

--[[
     Transfer
   ]]
--
Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
  -- Check if current time is after transfer lock period
  assert(
    (os.time() >= TRANSFER_LOCK_TIMESTAMP or msg.From == ao.id),
    'Transfers are locked until February 28, 2025 00:00:00 UTC')

  assert(type(msg.Recipient) == 'string', 'Recipient is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')

  if not Balances[msg.From] then Balances[msg.From] = '0' end
  if not Balances[msg.Recipient] then Balances[msg.Recipient] = '0' end

  -- internal transfer is in gons
  local gonQuantity = utils.toBalanceValue(bint(msg.Quantity) * GonsPerToken)
  if bint(gonQuantity) <= bint(Balances[msg.From]) then
    Balances[msg.From] = utils.subtract(Balances[msg.From], gonQuantity)
    Balances[msg.Recipient] = utils.add(Balances[msg.Recipient], gonQuantity)

    --[[
         Only send the notifications to the Sender and Recipient
         if the Cast tag is not set on the Transfer message
       ]]
    --
    if not msg.Cast then
      -- Debit-Notice message template, that is sent to the Sender of the transfer
      local debitNotice = {
        Target = msg.From,
        Action = 'Debit-Notice',
        Recipient = msg.Recipient,
        Quantity = msg.Quantity,
        Data = Colors.gray ..
          'You transferred ' ..
          Colors.blue .. msg.Quantity .. Colors.gray .. ' to ' .. Colors.green .. msg.Recipient .. Colors.reset
      }
      -- Credit-Notice message template, that is sent to the Recipient of the transfer
      local creditNotice = {
        Target = msg.Recipient,
        Action = 'Credit-Notice',
        Sender = msg.From,
        Quantity = msg.Quantity,
        Data = Colors.gray ..
          'You received ' ..
          Colors.blue .. msg.Quantity .. Colors.gray .. ' from ' .. Colors.green .. msg.From .. Colors.reset
      }

      -- Add forwarded tags to the credit and debit notice messages
      for tagName, tagValue in pairs(msg) do
        -- Tags beginning with "X-" are forwarded
        if string.sub(tagName, 1, 2) == 'X-' then
          debitNotice[tagName] = tagValue
          creditNotice[tagName] = tagValue
        end
      end

      -- Send Debit-Notice and Credit-Notice
      ao.send(debitNotice)
      ao.send(creditNotice)
    end
  else
    ao.send({
      Target = msg.From,
      Action = 'Transfer-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Insufficient Balance!'
    })
  end
end)


--[[
    Standard Mint
   ]]
--
Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg)
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint(0) < bint(msg.Quantity), 'Quantity must be greater than zero!')

  if not Balances[ao.id] then Balances[ao.id] = '0' end

  if msg.From == ao.id then
    -- Add tokens to the token pool, according to Quantity
    Balances[msg.From] = utils.add(Balances[msg.From], msg.Quantity)
    TotalSupply = utils.add(TotalSupply, msg.Quantity)
    ao.send({
      Target = msg.From,
      Data = Colors.gray .. 'Successfully minted ' .. Colors.blue .. msg.Quantity .. Colors.reset
    })
  else
    ao.send({
      Target = msg.From,
      Action = 'Mint-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Only the Process Id can mint new ' .. Ticker .. ' tokens!'
    })
  end
end)


--[[
    Mint from Stake
   ]]
--
Handlers.add('mint-from-stake', Handlers.utils.hasMatchingTag('Action', 'Mint-From-Stake'), function(msg)
  assert(MINT_PROCESS == msg.From, 'Request is not from the trusted Mint Process!')

  -- Parse the JSON data containing mint requests
  local mintRequests = json.decode(msg.Data)
  assert(type(mintRequests) == 'table', 'Mint requests must be a valid array')

  -- Track total minted amount to update supply
  local totalMinted = '0'

  -- Process each mint request
  for _, request in ipairs(mintRequests) do
    local address = request.address
    local amount = request.amount

    assert(type(address) == 'string', 'Mint request address must be a string')
    assert(type(amount) == 'string', 'Mint request amount must be a string')
    assert(bint(0) < bint(amount), 'Mint amount must be greater than zero')

    -- Initialize balance if needed
    if not Balances[address] then
      Balances[address] = '0'
    end

    -- Convert MTH amount to gons for internal accounting
    local gonAmount = utils.toBalanceValue(bint(amount) * GonsPerToken)

    -- Update balance
    Balances[address] = utils.add(Balances[address], gonAmount)

    -- Add to total minted
    totalMinted = utils.add(totalMinted, amount)
    --[[ commented out for now (gas implications)
    -- Send credit notice to recipient
    ao.send({
      Target = address,
      Action = 'Credit-Notice',
      Sender = ao.id,
      Quantity = amount,
      Data = Colors.gray ..
        'You received ' ..
        Colors.blue .. amount .. Colors.gray .. ' MTH from staking rewards' .. Colors.reset
    })
     ]]
  end

  -- Update total supply
  TotalSupply = utils.add(TotalSupply, totalMinted)
end)

--[[
     Total Supply
   ]]
--
Handlers.add('totalSupply', Handlers.utils.hasMatchingTag('Action', 'Total-Supply'), function(msg)
  assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')

  ao.send({
    Target = msg.From,
    Action = 'Total-Supply',
    Data = TotalSupply,
    Ticker = Ticker
  })
end)

--[[
 Burn
]]
--
Handlers.add('burn', Handlers.utils.hasMatchingTag('Action', 'Burn'), function(msg)
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint(msg.Quantity) <= bint(Balances[msg.From]), 'Quantity must be less than or equal to the current balance!')

  local gonQuantity = utils.toBalanceValue(bint(msg.Quantity) * GonsPerToken)

  Balances[msg.From] = utils.subtract(Balances[msg.From], gonQuantity)
  TotalSupply = utils.subtract(TotalSupply, msg.Quantity)

  ao.send({
    Target = msg.From,
    Data = Colors.gray .. 'Successfully burned ' .. Colors.blue .. msg.Quantity .. Colors.reset
  })
end)
--[[
     Monetary Policy Handlers
   ]]

--[[
     Handler for Rebasing the total supply
   ]]
--

Handlers.add('rebase', Handlers.utils.hasMatchingTag('Action', 'Rebase'),
  function(msg)
    assert(MonetaryPolicyProcess == msg.From, 'Request is not from the trusted Monetary Policy Process!')

    Rebase(msg.NewSupply)

    ao.send({
      Target = msg.From,
      Action = 'Rebase',
      Data = Colors.gray ..
        'Total supply has been rebased to ' ..
        Colors.blue .. msg.NewSupply .. Colors.reset
    })
  end)
