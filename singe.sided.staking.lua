local bint = require('.bint')(256)
local json = require('json')

-- Constants
local MINT_TOKEN = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'
local BOTEGA_AMM = 'VBx1jKKKkr7t4RkJg8axqZY2eNpDZSOxVhcGwF5tWAA'

-- Helper functions
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
  end
}

-- State variables - simplified to just use AllowedTokensNames
AllowedTokensNames = AllowedTokensNames or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'Q Arweave (qAR)',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'Wrapped AR (wAR)',
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 'Number Always Bigger (NAB)',
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'AO (AO Token)',


}

-- Track staking positions
-- StakingPositions[token][user] = { amount = "100", lpTokens = "50" }
StakingPositions = StakingPositions or {}

-- Initialize staking positions for allowed tokens
for token, _ in pairs(AllowedTokensNames) do
  StakingPositions[token] = StakingPositions[token] or {}
end

-- Pending operations tracking
PendingOperations = PendingOperations or {}

-- Check if a token is allowed
local function isTokenAllowed(token)
  return AllowedTokensNames[token] ~= nil
end


local function operationId(sender)
  return ao.id .. '-' .. sender .. '-' .. os.time()
end

-- Handler to stake tokens
Handlers.add('stake', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
  function(msg)
    local token = msg.From
    local quantity = msg.Quantity
    local sender = msg.Sender

    -- Validate token is allowed
    assert(isTokenAllowed(token), 'Token is not supported for staking')
    assert(bint(quantity) > bint.zero(), 'Stake amount must be greater than 0')

    -- Create pending operation
    local operationId = operationId(sender)
    PendingOperations[operationId] = {
      type = 'stake',
      token = token,
      sender = sender,
      amount = quantity,
      status = 'pending'
    }

    -- Request MINT tokens from protocol treasury
    Send({
      Target = MINT_TOKEN,
      Action = 'Transfer',
      Recipient = BOTEGA_AMM,
      Quantity = quantity,
      ['X-Operation-Id'] = operationId
    })

    -- Provide liquidity to AMM
    Send({
      Target = BOTEGA_AMM,
      Action = 'Provide',
      ['Token-A'] = token,
      ['Token-B'] = MINT_TOKEN,
      ['Amount-A'] = quantity,
      ['Amount-B'] = quantity,
      ['X-Operation-Id'] = operationId,
      ['X-Slippage-Tolerance'] = '1.0' -- 1% slippage tolerance
    })

    -- Initialize or update staking position
    if not StakingPositions[token][sender] then
      StakingPositions[token][sender] = {
        amount = '0',
        lpTokens = '0'
      }
    end

    StakingPositions[token][sender].amount = utils.add(StakingPositions[token][sender].amount, quantity)

    -- Send confirmation to user
    Send({
      Target = sender,
      Action = 'Stake-Confirmation',
      Token = token,
      TokenName = AllowedTokensNames[token],
      Amount = quantity,
      ['Operation-Id'] = operationId
    })
  end)

-- Handler for AMM liquidity provision confirmation
Handlers.add('provide-confirmation', Handlers.utils.hasMatchingTag('Action', 'Provide-Confirmation'),
  function(msg)
    local operationId = msg.Tags['X-Operation-Id']
    local operation = PendingOperations[operationId]

    if operation and operation.type == 'stake' then
      -- Update LP token balance
      StakingPositions[operation.token][operation.sender].lpTokens =
        utils.add(StakingPositions[operation.token][operation.sender].lpTokens, msg.Tags['LP-Tokens'])

      -- Mark operation as completed
      operation.status = 'completed'

      -- Notify user
      Send({
        Target = operation.sender,
        Action = 'Stake-Complete',
        Token = operation.token,
        TokenName = AllowedTokensNames[operation.token],
        Amount = operation.amount,
        ['LP-Tokens'] = msg.Tags['LP-Tokens']
      })
    end
  end)

-- Handler for unstaking
Handlers.add('unstake', Handlers.utils.hasMatchingTag('Action', 'Unstake'),
  function(msg)
    local token = msg.Tags['Token']
    local sender = msg.From

    -- Validate token and staking position
    assert(isTokenAllowed(token), 'Token is not supported for staking')
    assert(StakingPositions[token][sender], 'No staking position found')
    assert(bint(StakingPositions[token][sender].amount) > bint.zero(), 'No tokens staked')

    local position = StakingPositions[token][sender]
    local operationId = operationId(sender)

    -- Create pending operation
    PendingOperations[operationId] = {
      type = 'unstake',
      token = token,
      sender = sender,
      amount = position.amount,
      lpTokens = position.lpTokens,
      status = 'pending'
    }

    -- Remove liquidity from AMM
    Send({
      Target = BOTEGA_AMM,
      Action = 'Remove',
      ['LP-Tokens'] = position.lpTokens,
      ['X-Operation-Id'] = operationId,
      ['X-Slippage-Tolerance'] = '1.0'
    })

    -- Clear staking position
    StakingPositions[token][sender] = {
      amount = '0',
      lpTokens = '0'
    }

    -- Send confirmation to user
    Send({
      Target = sender,
      Action = 'Unstake-Started',
      Token = token,
      TokenName = AllowedTokensNames[token],
      Amount = position.amount,
      ['Operation-Id'] = operationId
    })
  end)

-- Handler for AMM remove liquidity confirmation
Handlers.add('remove-confirmation', Handlers.utils.hasMatchingTag('Action', 'Remove-Confirmation'),
  function(msg)
    local operationId = msg.Tags['X-Operation-Id']
    local operation = PendingOperations[operationId]

    if operation and operation.type == 'unstake' then
      -- Return original token to user
      Send({
        Target = operation.token,
        Action = 'Transfer',
        Recipient = operation.sender,
        Quantity = operation.amount
      })

      -- Handle any accrued fees
      if msg.Tags['Fees'] then
        Send({
          Target = operation.sender,
          Action = 'Fee-Distribution',
          Amount = msg.Tags['Fees']
        })
      end

      -- Mark operation as completed
      operation.status = 'completed'

      -- Notify user
      Send({
        Target = operation.sender,
        Action = 'Unstake-Complete',
        Token = operation.token,
        TokenName = AllowedTokensNames[operation.token],
        Amount = operation.amount,
        Fees = msg.Tags['Fees'] or '0'
      })
    end
  end)

-- Handler to get staking position
Handlers.add('get-position', Handlers.utils.hasMatchingTag('Action', 'Get-Position'),
  function(msg)
    local token = msg.Tags['Token']
    local user = msg.Tags['User'] or msg.From

    assert(isTokenAllowed(token), 'Token is not supported for staking')

    local position = StakingPositions[token][user] or {
      amount = '0',
      lpTokens = '0'
    }

    msg.reply({
      Action = 'Position-Info',
      Token = token,
      ['Token-Name'] = AllowedTokensNames[token],
      Amount = position.amount,
      ['LP-Tokens'] = position.lpTokens
    })
  end)

-- Handler to get all positions for a user
Handlers.add('get-all-positions', Handlers.utils.hasMatchingTag('Action', 'Get-All-Positions'),
  function(msg)
    local user = msg.Tags['User'] or msg.From
    local positions = {}

    for token, tokenName in pairs(AllowedTokensNames) do
      if StakingPositions[token] and StakingPositions[token][user] then
        positions[token] = {
          name = tokenName,
          amount = StakingPositions[token][user].amount,
          lpTokens = StakingPositions[token][user].lpTokens
        }
      end
    end

    msg.reply({
      Action = 'All-Positions',
      Data = json.encode(positions)
    })
  end)

-- Handler to get list of allowed tokens
Handlers.add('get-allowed-tokens', Handlers.utils.hasMatchingTag('Action', 'Get-Allowed-Tokens'),
  function(msg)
    local allowedTokens = {}

    for token, name in pairs(AllowedTokensNames) do
      table.insert(allowedTokens, {
        address = token,
        name = name
      })
    end

    msg.reply({
      Action = 'Allowed-Tokens',
      Data = json.encode(allowedTokens)
    })
  end)
