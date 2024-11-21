Variant = '0.0.1'
local bint = require('.bint')(256)
local tableUtils = require('.utils')
local json = require('json')

-- Constants
TOKEN_MINT_PROCESS = 'xxxx'
TOTAL_SUPPLY = 21000000 * 10 ^ 8  -- 21M tokens with 8 decimal places
EMISSION_RATE_PER_MONTH = 0.01425 -- 1.425% monthly rate
PERIODS_PER_MONTH = 8760          -- number of 5-minute periods in a month (43800/5)

-- State variables
CurrentSupply = CurrentSupply or 0
LastMintTimestamp = LastMintTimestamp or 0

-- caution - allowedtokens should be append only
local allowedTokens = { stETH = 'xxxx', stSOL = 'yyy' }
local tokenWeights = { stETH = '1', stSOL = '1' }


--[[
  Initialize the staker table. stakers[token][user] = balance
]]
---@return table<string, table>
function UpdateAllowedTokens()
  local stakers = {}
  for _, token in pairs(allowedTokens) do
    if not stakers[token] then stakers[token] = {} end
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
     Update allowedTokens array then call this handler
   ]]
--
Handlers.add('update-allowed-tokens', Handlers.utils.hasMatchingTag('Action', 'Update-Allowed-Tokens'),
  function(msg)
    Stakers = UpdateAllowedTokens()
    ao.send({
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


--[[
     Handler to get staked balances for a specific staker
   ]]
--
Handlers.add('get-staked-balances', Handlers.utils.hasMatchingTag('Action', 'Get-Staked-Balances'),
  function(msg)
    local staker = msg.Tags['Staker']
    assert(type(staker) == 'string', 'Staker address is required!')

    -- Initialize result table to store balances
    local balances = {}

    -- Loop through each token in Stakers
    for token, stakersMap in pairs(Stakers) do
      -- Get the balance for this staker, or '0' if they haven't staked
      balances[TokenName(token)] = stakersMap[staker] or '0'
    end

    -- Send response with balances
    ao.send({
      Target = msg.From,
      Action = 'Staked-Balances',
      Staker = staker,
      Data = json.encode(balances)
    })
  end)


--[[
     Handler to get list of allowed tokens
   ]]
--
Handlers.add('get-allowed-tokens', Handlers.utils.hasMatchingTag('Action', 'Get-Allowed-Tokens'),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = 'Allowed-Tokens',
      Data = json.encode(allowedTokens)
    })
  end)


--[[
  Calculate emission for a 5-minute period
  Returns the number of tokens to mint in this period
]]
local function calculateEmission()
  local remainingSupply = TOTAL_SUPPLY - CurrentSupply

  -- Calculate the emission rate for a 5-minute period
  -- Monthly rate is EMISSION_RATE_PER_MONTH, divided by periods per month
  local periodRate = EMISSION_RATE_PER_MONTH / PERIODS_PER_MONTH

  -- Calculate tokens to emit this period
  local emission = math.floor(remainingSupply * periodRate)

  return emission
end

--[[
  Calculate individual staker allocations based on their stake weight
]]
local function calculateStakerAllocations(totalEmission)
  local allocations = {}
  local totalStakeWeight = bint.zero()

  -- Calculate total weighted stake across all tokens
  for token, stakersMap in pairs(Stakers) do
    local tokenWeight = bint(tokenWeights[token])
    for staker, amount in pairs(stakersMap) do
      totalStakeWeight = totalStakeWeight + (bint(amount) * tokenWeight)
    end
  end

  -- If no stakes, return empty allocations
  if totalStakeWeight == bint.zero() then
    return allocations
  end

  -- Calculate each staker's allocation
  for token, stakersMap in pairs(Stakers) do
    local tokenWeight = bint(tokenWeights[token])
    for staker, amount in pairs(stakersMap) do
      local stakerWeight = bint(amount) * tokenWeight
      local allocation = utils.multiply(totalEmission, utils.divide(stakerWeight, totalStakeWeight))

      if not allocations[staker] then
        allocations[staker] = '0'
      end
      allocations[staker] = utils.add(allocations[staker], allocation)
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
    -- Ensure sufficient time has passed since last mint
    local currentTime = os.time()
    assert(currentTime >= LastMintTimestamp + 300, 'Too soon for next mint') -- 300 seconds = 5 minutes

    -- Calculate new tokens to mint this period
    local newTokens = calculateEmission()

    -- Calculate allocation for each staker
    local allocations = calculateStakerAllocations(newTokens)

    -- Prepare mint requests
    local mints = {}
    for staker, amount in pairs(allocations) do
      table.insert(mints, {
        address = staker,
        amount = amount
      })
    end

    -- Update state
    CurrentSupply = utils.add(CurrentSupply, newTokens)
    LastMintTimestamp = currentTime

    -- Send mint requests to token contract
    ao.send({
      Target = TOKEN_MINT_PROCESS,
      Action = 'Mint-From-Stake',
      Data = json.encode(mints)
    })
  end)
