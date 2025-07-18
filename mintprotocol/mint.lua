local bint = require('.bint')(256)
local MonetaryPolicyProcess = 'KBOfQGUj-K1GNwfx1CeMSZxxcj5p837d-_6hTmkWF0k'
local MINT_PROTOCOL_PROCESS = 'lNtrei6YLQiWS8cyFFHDrOBvRzICQPTvrjZBP8fz-ZI'


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
TotalSupply = TotalSupply or utils.toBalanceValue(77000000 * 10 ^ Denomination)



--[[
    Internal balance calculation is handled in "gons"
    TotalGons is a multiple of InitialSupply so that GonsPerToken is an integer.
    Use the highest integer value for TotalGons for max granularity.
   ]]

TOTAL_THEORETICAL_SUPPLY = TOTAL_THEORETICAL_SUPPLY or
  utils.toBalanceValue(bint(77000000) * bint(10) ^ Denomination) -- 77M tokens with 8 decimal places
---@type string
TotalGons = TotalGons or utils.toBalanceValue(bint(TOTAL_THEORETICAL_SUPPLY) * bint(10 ^ 18))

---@type Bint
GonsPerToken = GonsPerToken or bint.zero()
if (GonsPerToken == bint.zero()) then
  Rebase(TotalSupply)
end


Balances = Balances or { [ao.id] = TotalGons }

Name = Name or 'MINT'
Ticker = Ticker or 'MINT'
Logo = Logo or 'P9EWU8qgkvM95Y-HTp8U36i9_2ZzKx3kWtJduCEIKgk'

--[[
     Add handlers for each incoming Action defined by the ao Standard Token Specification
   ]]
--

--[[
     Info
   ]]
--
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
  msg.reply({
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



  msg.reply({
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

    for address, balance in pairs(Balances) do
      local MTHBalance = utils.toBalanceValue(bint.__idiv(bint(balance), GonsPerToken))
      -- Store both address and balance
      MTHBalances[address] = MTHBalance
    end

    msg.reply({ Data = json.encode(MTHBalances) })
  end)

--[[
     Transfer
   ]]
--
Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
  -- Check if current time is after transfer lock period


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
      msg.reply(debitNotice)
      Send(creditNotice)
    end
  else
    msg.reply({
      Action = 'Transfer-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Insufficient Balance!'
    })
  end
end)



--[[
     Total Supply
   ]]
--
Handlers.add('totalSupply', Handlers.utils.hasMatchingTag('Action', 'Total-Supply'), function(msg)
  assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')

  msg.reply({
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

  msg.reply({
    Data = Colors.gray .. 'Successfully burned ' .. Colors.blue .. msg.Quantity .. Colors.reset
  })
end)


--[[
    Mint
   ]]
--
Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg)
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint(0) < bint(msg.Quantity), 'Quantity must be greater than zero!')
  assert(msg.From == ao.id or msg.From == MINT_PROTOCOL_PROCESS,
    'Only authorized processes can mint new ' .. Ticker .. ' tokens!')
  local recipient = msg.From
  if not Balances[recipient] then Balances[recipient] = '0' end

  -- Convert the token quantity to gons before adding to balance
  local gonQuantity = utils.toBalanceValue(bint(msg.Quantity) * GonsPerToken)

  -- Add gons to the token pool, according to Quantity
  Balances[recipient] = utils.add(Balances[recipient], gonQuantity)
  TotalSupply = utils.add(TotalSupply, msg.Quantity)

  if msg.reply then
    msg.reply({
      Data = Colors.gray .. 'Successfully minted ' .. Colors.blue .. msg.Quantity .. Colors.reset
    })
  else
    Send({
      Target = recipient,
      Data = Colors.gray .. 'Successfully minted ' .. Colors.blue .. msg.Quantity .. Colors.reset
    })
  end
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

    msg.reply({
      Action = 'Rebase',
      Data = Colors.gray ..
        'Total supply has been rebased to ' ..
        Colors.blue .. msg.NewSupply .. Colors.reset
    })
  end)


--[[
  Supply Reduction Handler
  Reduces total supply from ~18.1B to ~50M tokens
]] --
BackupBalances = {}

--[[
  Supply Reduction Handler
  Reduces total supply from ~18.1B to ~50M tokens
]] --
Handlers.add('reduce-supply', Handlers.utils.hasMatchingTag('Action', 'Reduce-Supply'),
  function(msg)
    assert(msg.From == ao.id, 'Only the process owner can reduce supply!')

    for address, balanceGon in pairs(Balances) do
      BackupBalances[address] = balanceGon
    end

    -- Calculate reduction factor: ~18.1B to ~50M
    local currentSupply = TotalSupply
    local targetSupply = '5000000000000000' -- 50M tokens with 8 decimals
    local reductionFactor = bint.__idiv(bint(currentSupply), bint(targetSupply))

    -- Minimum balance threshold (1 full token = 10^8)
    local minBalanceGon = utils.toBalanceValue(bint(10 ^ Denomination) * GonsPerToken)

    local newTotalSupply = '0'

    -- Process each balance
    for address, balanceGon in pairs(Balances) do
      -- Convert gons to display tokens
      local currentTokens = bint.__idiv(bint(balanceGon), GonsPerToken)

      -- Reduce by factor
      local newTokens = bint.__idiv(currentTokens, reductionFactor)

      -- Convert to gons for comparison
      local newBalanceGon = utils.toBalanceValue(bint(newTokens) * GonsPerToken)

      -- Apply minimum balance rule
      if bint(newBalanceGon) < bint(minBalanceGon) and bint(newBalanceGon) > bint.zero() then
        newBalanceGon = minBalanceGon                       -- Set to 1 full token in gons
        newTokens = utils.toBalanceValue(10 ^ Denomination) -- Update tokens too
      end
      Balances[address] = newBalanceGon

      -- Add to new total supply
      newTotalSupply = utils.add(newTotalSupply, utils.toBalanceValue(newTokens))
    end

    -- Update total supply
    TotalSupply = newTotalSupply

    msg.reply({
      Action = 'Supply-Reduced',
      Data = Colors.gray .. 'Supply reduced from ' .. Colors.blue .. currentSupply ..
        Colors.gray .. ' to ' .. Colors.blue .. TotalSupply .. Colors.reset,
      BackupCreated = 'true',
      ReductionFactor = tostring(reductionFactor)
    })
  end)
