local bint = require('.bint')(256)
local json = require('json')

-- Constants
local MINT_TOKEN = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'

-- State variables
-- Pause mechanism for emergency scenarios
IsPaused = IsPaused or false

-- AllowedTokensNames - tokens accepted for staking
AllowedTokensNames = AllowedTokensNames or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'Q Arweave (qAR)',
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'Wrapped AR (wAR)',
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 'Number Always Bigger (NAB)',
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'AO (AO Token)',
}

-- Token-to-AMM mappings
TOKEN_AMM_MAPPINGS = TOKEN_AMM_MAPPINGS or {
  ['NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8'] = 'VBx1jKKKkr7t4RkJg8axqZY2eNpDZSOxVhcGwF5tWAA', -- qAR AMM
  ['xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'] = 'pX0L5GY09W-EL1zcjrGPYVy-B3iu5HWF53S2_GY0ViI', -- wAR AMM
  ['OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'] = 'AzxYcLUMPJvjz9LPJ-A-6yzwW9ScQYl8TLVL-84y2PE', -- NAB AMM
  ['0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc'] = 'a98-hjIuPJeK89RwZ3jMkoN2iOuQkTkKrMWi4O3DRIY', -- AO AMM
}

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

-- Track staking positions
-- StakingPositions[token][user] = { amount = "100", lpTokens = "50" }
StakingPositions = StakingPositions or {}

-- Initialize staking positions for allowed tokens
for token, _ in pairs(AllowedTokensNames) do
  StakingPositions[token] = StakingPositions[token] or {}
end

-- Pending operations tracking with timestamps for timeouts
-- PendingOperations[operationId] = { type, token, sender, amount, amm, status, timestamp }
PendingOperations = PendingOperations or {}

-- Security helper functions

-- Check if contract is paused
local function assertNotPaused()
  assert(not IsPaused, 'Contract is paused for maintenance or emergency')
end

-- Check if caller is the owner
local function assertIsAuthorized(caller)
  assert(caller == ao.id, 'Caller is not the contract owner')
end

-- Check if a token is allowed
local function isTokenAllowed(token)
  return AllowedTokensNames[token] ~= nil
end

-- Verify token is allowed and assert
local function assertTokenAllowed(token)
  assert(isTokenAllowed(token), 'Token is not supported for staking: ' .. token)
end

-- Check if caller is a valid token contract
local function assertIsAllowedToken(caller)
  assert(isTokenAllowed(caller), 'Sender is not an allowed token contract')
end

-- Get the AMM address for a token
local function getAmmForToken(token)
  local amm = TOKEN_AMM_MAPPINGS[token]
  assert(amm, 'No AMM configured for token: ' .. token)
  return amm
end

-- Assert AMM is valid
local function assertIsValidAmm(address, expectedAmm)
  assert(address == expectedAmm,
    'Unauthorized: message not from expected AMM or factory')
end

-- Generate operation ID
local function operationId(sender, token, type)
  return token .. '-' .. type .. sender .. '-' .. os.time()
end

-- Get user's token from a pair
local function getUsersToken(tokenA, tokenB)
  if (MINT_TOKEN == tokenA) then
    return tokenB
  else
    return tokenA
  end
end

-- Clean up stale pending operations (older than 1 hour)
local function cleanStaleOperations()
  local now = os.time()
  local staleIds = {}

  for id, op in pairs(PendingOperations) do
    if op.timestamp and (now - op.timestamp) > 3600 then -- 1 hour timeout
      table.insert(staleIds, id)
    end
  end

  for _, id in ipairs(staleIds) do
    PendingOperations[id] = nil
  end
end

-- Admin function to pause/unpause contract
Handlers.add('set-pause-state', Handlers.utils.hasMatchingTag('Action', 'Set-Pause-State'),
  function(msg)
    assertIsAuthorized(msg.From)

    local shouldPause = (msg.Tags['Pause'] == 'true')
    IsPaused = shouldPause

    msg.reply({
      Action = 'Pause-State-Updated',
      ['Is-Paused'] = tostring(IsPaused)
    })
  end)

-- Admin function to update allowed tokens
Handlers.add('update-allowed-tokens', Handlers.utils.hasMatchingTag('Action', 'Update-Allowed-Tokens'),
  function(msg)
    assertIsAuthorized(msg.From)

    local tokenAddress = msg.Tags['Token-Address']
    local tokenName = msg.Tags['Token-Name']
    local ammAddress = msg.Tags['AMM-Address']

    assert(tokenAddress and tokenName and ammAddress, 'Missing token information')

    -- Update token info
    AllowedTokensNames[tokenAddress] = tokenName
    TOKEN_AMM_MAPPINGS[tokenAddress] = ammAddress
    StakingPositions[tokenAddress] = StakingPositions[tokenAddress] or {}

    msg.reply({
      Action = 'Allowed-Tokens-Updated',
      ['Token-Address'] = tokenAddress,
      ['Token-Name'] = tokenName,
      ['AMM-Address'] = ammAddress
    })
  end)

-- Handler to stake tokens - security improved
Handlers.add('stake', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
  function(msg)
    assertNotPaused()

    local token = msg.From
    local quantity = msg.Quantity
    local sender = msg.Sender

    -- Verify sender is an allowed token contract
    assertIsAllowedToken(token)
    assert(bint(quantity) > bint.zero(), 'Stake amount must be greater than 0')

    -- Get the corresponding AMM for this token
    local amm = getAmmForToken(token)

    -- Create pending operation with timestamp
    local opId = operationId(sender, token, 'stake')
    PendingOperations[opId] = {
      type = 'stake',
      token = token,
      sender = sender,
      amount = quantity,
      amm = amm,
      status = 'pending',
      timestamp = os.time()
    }

    -- Initialize or update staking position
    if not StakingPositions[token][sender] then
      StakingPositions[token][sender] = {
        amount = '0',
        lpTokens = '0'
      }
    end

    Send({
      Target = amm,
      Action = 'Get-Swap-Output',
      Token = token,
      Quantity = quantity,
      Swapper = ao.id
    }).onReply(function(reply)
      local mintAmount = reply.Tags.Output

      -- Apply a small excess (3% more MINT tokens) to ensure all user tokens are used
      local excessMultiplier = '1030' -- 103.0%
      local adjustedMintAmount = utils.divide(utils.multiply(mintAmount, excessMultiplier), '1000')

      -- Request MINT tokens from protocol treasury and transfer to the AMM
      Send({
        Target = MINT_TOKEN,
        Action = 'Transfer',
        Recipient = ao.id,
        Quantity = adjustedMintAmount,
        ['X-Operation-Id'] = opId
      }).onReply(function()
        -- After receiving MINT tokens, transfer them to the AMM as the second token
        Send({
          Target = MINT_TOKEN,
          Action = 'Transfer',
          Recipient = amm,
          Quantity = adjustedMintAmount,
          ['X-Action'] = 'Provide',
          ['X-Slippage-Tolerance'] = '0.5',
          ['X-Operation-Id'] = opId
        })

        -- Transfer the user's token to the AMM
        Send({
          Target = token,
          Action = 'Transfer',
          Recipient = amm,
          Quantity = quantity,
          ['X-Action'] = 'Provide',
          ['X-Slippage-Tolerance'] = '0.5',
          ['X-Operation-Id'] = opId
        })
      end)
    end)
  end)

-- Handler for AMM liquidity provision confirmation - security improved
Handlers.add('provide-confirmation', Handlers.utils.hasMatchingTag('Action', 'Provide-Confirmation'),
  function(msg)
    assertNotPaused()

    local operationId = msg.Tags['X-Operation-Id']
    local operation = PendingOperations[operationId]

    -- Verify operation exists and is of correct type
    assert(operation and operation.type == 'stake', 'Invalid or unknown operation')

    -- Verify the message is from the correct AMM or factory
    assertIsValidAmm(msg.From, operation.amm)

    local receivedLP = msg.Tags['Received-Pool-Tokens']
    local usersToken = getUsersToken(msg.Tags['Token-A'], msg.Tags['Token-B'])

    -- Verify operation is in the correct state
    assert(operation.status == 'pending', 'Operation is not in pending state')

    -- Initialize or update staking position
    StakingPositions[operation.token][operation.sender].amount = utils.add(
      StakingPositions[operation.token][operation.sender].amount,
      msg.Tags['Provided-' .. usersToken])

    -- The AMM sends LP tokens directly to the contract (ao.id)
    -- We need to update the user's virtual balance
    StakingPositions[operation.token][operation.sender].lpTokens =
      utils.add(StakingPositions[operation.token][operation.sender].lpTokens, receivedLP)

    -- Update amount user staked in case they got a refund
    PendingOperations[operationId].amount = msg.Tags['Provided-' .. usersToken]
    PendingOperations[operationId].lpTokens = receivedLP

    -- Mark operation as completed
    PendingOperations[operationId].status = 'completed'

    -- Notify user
    Send({
      Target = operation.sender,
      Action = 'Stake-Complete',
      Token = operation.token,
      TokenName = AllowedTokensNames[operation.token],
      Amount = operation.amount,
      ['LP-Tokens'] = receivedLP
    })
  end)

-- Handler for refunding unused tokens - security improved
Handlers.add('refund-unused', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
  function(msg)
    assertNotPaused()

    local operationId = msg.Tags['X-Operation-Id']
    local operation = PendingOperations[operationId]
    local token = msg.From
    local quantity = msg.Quantity

    -- Verify the quantity is valid
    assert(bint(quantity) > bint.zero(), 'Refund amount must be greater than 0')

    if (token == MINT_TOKEN) then -- refund our treasury
      Send({
        Target = token,
        Action = 'Transfer',
        Recipient = MINT_TOKEN,
        Quantity = quantity
      })
      return
    end

    if (operation ~= nil) then
      -- Verify operation status
      assert(operation.status == 'pending' or operation.status == 'completed',
        'Operation is in an invalid state for refunds')

      -- Get the AMM for this token
      local amm = getAmmForToken(operation.token)

      -- Verify the message is from a valid source
      assert(msg.From == amm or msg.From == operation.token,
        'Unauthorized: refund not from recognized source')

      -- Refund the user
      Send({
        Target = token,
        Action = 'Transfer',
        Recipient = operation.sender,
        Quantity = quantity,
        TokenName = AllowedTokensNames[operation.token],
      })
    end
  end)

-- Handler for unstaking - security improved
Handlers.add('unstake', Handlers.utils.hasMatchingTag('Action', 'Unstake'),
  function(msg)
    assertNotPaused()

    local token = msg.Tags['Token']
    local sender = msg.From

    -- Validate token and staking position
    assertTokenAllowed(token)
    assert(StakingPositions[token][sender], 'No staking position found')
    assert(bint(StakingPositions[token][sender].amount) > bint.zero(), 'No tokens staked')

    -- Get the corresponding AMM for this token
    local amm = getAmmForToken(token)

    local position = StakingPositions[token][sender]
    local opId = operationId(sender, token, 'unstake')

    -- Update state before external calls (checks-effects-interactions pattern)
    -- Store the position values before clearing
    local positionAmount = position.amount
    local positionLpTokens = position.lpTokens

    -- Clear staking position
    StakingPositions[token][sender] = {
      amount = '0',
      lpTokens = '0'
    }

    -- Create pending operation
    PendingOperations[opId] = {
      id = opId,
      type = 'unstake',
      token = token,
      sender = sender,
      amount = positionAmount,
      lpTokens = positionLpTokens,
      amm = amm,
      status = 'pending',
      timestamp = os.time()
    }

    -- Remove liquidity from AMM by burning LP tokens
    Send({
      Target = amm,
      Action = 'Burn',
      Quantity = positionLpTokens,
      ['X-Operation-Id'] = opId,
    })

    -- Send confirmation to user
    Send({
      Target = sender,
      Action = 'Unstake-Started',
      Token = token,
      TokenName = AllowedTokensNames[token],
      Amount = positionAmount,
      ['Operation-Id'] = opId
    })
  end)

-- Handler for AMM burn/remove liquidity confirmation - security improved
Handlers.add('burn-confirmation', Handlers.utils.hasMatchingTag('Action', 'Burn-Confirmation'),
  function(msg)
    assertNotPaused()

    local operationId = msg.Tags['X-Operation-Id']
    local operation = PendingOperations[operationId]

    -- Verify operation exists and is of correct type
    assert(operation and operation.type == 'unstake', 'Invalid or unknown operation')

    -- Verify the message is from the correct AMM or factory
    assertIsValidAmm(msg.From, operation.amm)

    -- Verify operation is in the correct state
    assert(operation.status == 'pending', 'Operation is not in pending state')

    local usersToken = getUsersToken(msg.Tags['Token-A'], msg.Tags['Token-B'])

    -- The user should receive their original token back
    local withdrawnAmount = msg.Tags['Withdrawn-' .. usersToken]

    -- Verify withdrawal amount is positive
    assert(bint(withdrawnAmount) > bint.zero(), 'Withdrawn amount must be greater than 0')

    -- Mark operation as completed first (checks-effects-interactions)
    PendingOperations[operationId].status = 'completed'

    -- Return original token to user
    Send({
      Target = operation.token,
      Action = 'Transfer',
      Recipient = operation.sender,
      Quantity = withdrawnAmount
    })

    -- Notify user
    Send({
      Target = operation.sender,
      Action = 'Unstake-Complete',
      Token = operation.token,
      TokenName = AllowedTokensNames[operation.token],
      Amount = withdrawnAmount,
      ['MINT-Amount'] = msg.Tags['Withdrawn-' .. MINT_TOKEN],
      ['LP-Tokens-Burned'] = msg.Tags['Burned-Pool-Tokens']
    })
  end)

-- Handler to get staking position
Handlers.add('get-position', Handlers.utils.hasMatchingTag('Action', 'Get-Position'),
  function(msg)
    local token = msg.Tags['Token']
    local user = msg.Tags['User'] or msg.From

    assertTokenAllowed(token)

    -- Get the corresponding AMM for this token
    local amm = getAmmForToken(token)

    local position = StakingPositions[token][user] or {
      amount = '0',
      lpTokens = '0'
    }

    msg.reply({
      Action = 'Position-Info',
      Token = token,
      ['Token-Name'] = AllowedTokensNames[token],
      Amount = position.amount,
      ['LP-Tokens'] = position.lpTokens,
      ['AMM'] = amm
    })
  end)

-- Handler to get all positions for a user
Handlers.add('get-all-positions', Handlers.utils.hasMatchingTag('Action', 'Get-All-Positions'),
  function(msg)
    local user = msg.Tags['User'] or msg.From
    local positions = {}
    local amm = ''

    for token, tokenName in pairs(AllowedTokensNames) do
      amm = getAmmForToken(token)
      if StakingPositions[token] and StakingPositions[token][user] then
        positions[token] = {
          name = tokenName,
          amount = StakingPositions[token][user].amount,
          lpTokens = StakingPositions[token][user].lpTokens,
          amm = amm
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
        name = name,
        amm = TOKEN_AMM_MAPPINGS[token]
      })
    end

    msg.reply({
      Action = 'Allowed-Tokens',
      Data = json.encode(allowedTokens)
    })
  end)

-- Handler for AMM liquidity provision errors - security improved
Handlers.add('provide-error', Handlers.utils.hasMatchingTag('Action', 'Provide-Error'),
  function(msg)
    assertNotPaused()

    local operationId = msg.Tags['X-Operation-Id']
    local operation = PendingOperations[operationId]

    -- Verify operation exists and is of correct type
    assert(operation and operation.type == 'stake', 'Invalid or unknown operation')

    -- Verify the message is from the correct AMM or factory
    assertIsValidAmm(msg.From, operation.amm)

    -- Verify operation is in the correct state
    assert(operation.status == 'pending', 'Operation is not in pending state')

    -- Mark operation as failed first (checks-effects-interactions)
    PendingOperations[operationId].status = 'failed'

    -- Return the user's tokens
    Send({
      Target = operation.token,
      Action = 'Transfer',
      Recipient = operation.sender,
      Quantity = operation.amount
    })

    -- Notify user
    Send({
      Target = operation.sender,
      Action = 'Stake-Failed',
      Token = operation.token,
      TokenName = AllowedTokensNames[operation.token],
      Amount = operation.amount,
      Error = msg.Tags['Result'] or 'Unknown error during liquidity provision'
    })
  end)

-- Run cleanup periodically (e.g., attach to a frequently called handler)
Handlers.add('cleanup-stale-operations', Handlers.utils.hasMatchingTag('Action', 'Cleanup'),
  function(msg)
    assertIsAuthorized(msg.From)
    cleanStaleOperations()

    msg.reply({
      Action = 'Cleanup-Complete',
      ['Timestamp'] = tostring(os.time())
    })
  end)
