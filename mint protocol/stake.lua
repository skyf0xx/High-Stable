-- Single-Sided Staking Contract - Stake Module
-- Handles all staking-related operations

local config = require('config')
local state = require('state')
local utils = require('utils')
local security = require('security')

local stake = {}

-- Handler patterns for staking operations
stake.patterns = {
  -- Pattern for initial stake request
  stake = function(msg)
    return msg.Tags.Action == 'Credit-Notice' and msg.Tags['X-User-Request'] == 'Stake'
  end,

  -- Pattern for funding a stake with MINT tokens
  fundStake = function(msg)
    return msg.Tags.Action == 'Credit-Notice' and
      msg.Tags['X-User-Request'] == 'Fund-Stake' and
      msg.From == config.MINT_TOKEN
  end,

  -- Pattern for AMM providing confirmation of liquidity provision
  provideConfirmation = function(msg)
    return msg.Tags.Action == 'Provide-Confirmation'
  end,

  -- Pattern for AMM providing error during staking process
  provideError = function(msg)
    return msg.Tags.Action == 'Provide-Error'
  end,

  -- Pattern for handling unused tokens (refunds)
  refundUnused = function(msg)
    return msg.Tags.Action == 'Credit-Notice' and
      msg.Tags['X-User-Request'] ~= 'Stake' and
      msg.Tags['X-User-Request'] ~= 'Fund-Stake'
  end
}

-- Handler implementations for staking operations
stake.handlers = {
  -- Handler for initial stake request
  stake = function(msg)
    security.assertNotPaused()

    local token = msg.From
    local quantity = msg.Quantity
    local sender = msg.Sender

    -- Verify sender is an allowed token contract
    security.assertIsAllowedTokenProcess(token)
    security.assertPositiveQuantity(quantity)

    -- Get the corresponding AMM for this token
    local amm = security.getAmmForToken(token)

    -- Create pending operation with timestamp
    local opId = utils.operationId(sender, token, 'stake')
    state.setPendingOperation(opId, {
      type = 'stake',
      token = token,
      sender = sender,
      amount = quantity,
      amm = amm,
      status = 'pending',
      timestamp = os.time()
    })

    -- Log stake initiated
    utils.logEvent('StakeInitiated', {
      sender = sender,
      token = token,
      tokenName = config.AllowedTokensNames[token],
      amount = quantity,
      operationId = opId
    })

    -- Initialize staking position if it doesn't exist
    state.initializeStakingPosition(token, sender)

    -- Query AMM for swap output to determine MINT amount needed
    Send({
      Target = amm,
      Action = 'Get-Swap-Output',
      Token = token,
      Quantity = quantity,
      Swapper = ao.id
    }).onReply(function(reply)
      local mintAmount = reply.Tags.Output

      -- Apply excess multiplier to ensure all user tokens are used
      local adjustedMintAmount = utils.calculateAdjustedMintAmount(mintAmount)

      -- Request MINT tokens from protocol treasury and transfer to the AMM
      Send({
        Target = config.MINT_TOKEN,
        Action = 'Transfer',
        Recipient = ao.id,
        Quantity = adjustedMintAmount,
        ['X-Operation-Id'] = opId,
        ['X-User-Request'] = 'Fund-Stake',
        ['X-Token'] = token,
        ['X-Amount'] = quantity,
        ['X-AMM'] = amm,
        ['X-Adjusted-Mint-Amount'] = adjustedMintAmount
      })
    end)
  end,

  -- Handler for funding a stake with MINT tokens
  fundStake = function(msg)
    security.assertNotPaused()

    local opId = msg.Tags['X-Operation-Id']
    local token = msg.Tags['X-Token']
    local quantity = msg.Tags['X-Amount']
    local amm = msg.Tags['X-AMM']
    local adjustedMintAmount = msg.Tags['X-Adjusted-Mint-Amount']

    -- Verify operation exists and is in pending state
    security.verifyOperation(opId, 'stake', 'pending')

    -- After receiving MINT tokens, transfer them to the AMM as the second token
    Send({
      Target = config.MINT_TOKEN,
      Action = 'Transfer',
      Recipient = amm,
      Quantity = adjustedMintAmount,
      ['X-Action'] = 'Provide',
      ['X-Slippage-Tolerance'] = config.SLIPPAGE_TOLERANCE,
      ['X-Operation-Id'] = opId
    })

    -- Transfer the user's token to the AMM
    Send({
      Target = token,
      Action = 'Transfer',
      Recipient = amm,
      Quantity = quantity,
      ['X-Action'] = 'Provide',
      ['X-Slippage-Tolerance'] = config.SLIPPAGE_TOLERANCE,
      ['X-Operation-Id'] = opId
    })
  end,

  -- Handler for AMM providing confirmation of liquidity provision
  provideConfirmation = function(msg)
    security.assertNotPaused()

    local operationId = msg.Tags['X-Operation-Id']
    local operation = security.verifyOperation(operationId, 'stake', 'pending')

    -- Verify the message is from the correct AMM
    security.assertIsValidAmm(msg.From, operation.amm)

    local receivedLP = msg.Tags['Received-Pool-Tokens']
    local usersToken = utils.getUsersToken(msg.Tags['Token-A'], msg.Tags['Token-B'])

    -- Update staking position with new values
    state.updateStakingPosition(operation.token, operation.sender, {
      amount = utils.math.add(
        state.getStakingPosition(operation.token, operation.sender).amount,
        msg.Tags['Provided-' .. usersToken]),
      lpTokens = utils.math.add(
        state.getStakingPosition(operation.token, operation.sender).lpTokens,
        receivedLP),
      mintAmount = msg.Tags['Provided-' .. config.MINT_TOKEN], -- Track MINT contribution
      stakedDate = os.time()
    })

    -- Update pending operation with actual amounts used
    state.updatePendingOperation(operationId, {
      amount = msg.Tags['Provided-' .. usersToken],
      lpTokens = receivedLP,
      status = 'completed'
    })

    -- Log the successful stake event
    utils.logEvent('StakeComplete', {
      sender = operation.sender,
      token = operation.token,
      tokenName = config.AllowedTokensNames[operation.token],
      amount = msg.Tags['Provided-' .. usersToken],
      lpTokens = receivedLP,
      operationId = operationId
    })

    -- Notify user of successful stake
    Send({
      Target = operation.sender,
      Action = 'Stake-Complete',
      Token = operation.token,
      TokenName = config.AllowedTokensNames[operation.token],
      Amount = msg.Tags['Provided-' .. usersToken],
      ['LP-Tokens'] = receivedLP
    })
  end,

  -- Handler for AMM providing error during staking process
  provideError = function(msg)
    security.assertNotPaused()

    local operationId = msg.Tags['X-Operation-Id']
    local operation = security.verifyOperation(operationId, 'stake', 'pending')

    -- Verify the message is from the correct AMM
    security.assertIsValidAmm(msg.From, operation.amm)

    -- Mark operation as failed (checks-effects-interactions pattern)
    state.failPendingOperation(operationId)

    -- Log the failed stake event
    utils.logEvent('StakeFailed', {
      sender = operation.sender,
      token = operation.token,
      tokenName = config.AllowedTokensNames[operation.token],
      amount = operation.amount,
      error = msg.Tags['X-Refund-Reason'] or 'Unknown error during liquidity provision',
      operationId = operationId
    })

    -- Return the user's tokens
    Send({
      Target = operation.token,
      Action = 'Transfer',
      Recipient = operation.sender,
      Quantity = operation.amount,
      ['X-Refund-Reason'] = msg.Tags['X-Refund-Reason'] or 'Unknown error during liquidity provision'
    })
  end,

  -- Handler for handling unused tokens (refunds)
  refundUnused = function(msg)
    security.assertNotPaused()

    local operationId = msg.Tags['X-Operation-Id']
    local token = msg.From
    local quantity = msg.Quantity

    -- Verify the quantity is valid
    security.assertPositiveQuantity(quantity)

    -- If token is MINT, refund to treasury
    if token == config.MINT_TOKEN then
      Send({
        Target = token,
        Action = 'Transfer',
        Recipient = config.MINT_TOKEN,
        Quantity = quantity,
        ['X-Operation-Id'] = operationId,
        ['X-reason'] = 'Refund excess'
      })
      return
    end

    -- For other tokens, verify operation exists
    local operation = state.getPendingOperation(operationId)
    assert(operation ~= nil, 'This credit does not belong to anyone')
    assert(operation.status == 'pending' or operation.status == 'completed',
      'Operation is in an invalid state for refunds')

    -- Get the AMM for this token
    local amm = security.getAmmForToken(operation.token)

    -- Verify the message is from a valid source
    assert(msg.From == amm or msg.From == operation.token,
      'Unauthorized: refund not from recognized source')

    -- Refund the user
    Send({
      Target = token,
      Action = 'Transfer',
      Recipient = operation.sender,
      Quantity = quantity,
      ['X-Operation-Id'] = operationId,
      ['X-reason'] = 'Refund excess'
    })

    -- Log refund event
    utils.logEvent('RefundProcessed', {
      sender = operation.sender,
      token = token,
      amount = quantity,
      operationId = operationId
    })
  end
}

return stake
