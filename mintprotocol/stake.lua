-- Single-Sided Staking Contract - Stake Module
-- Handles all staking-related operations

local config = require('mintprotocol.config')
local state = require('mintprotocol.state')
local utils = require('mintprotocol.utils')
local security = require('mintprotocol.security')
local operations = require('mintprotocol.operations')


local stake = {}

local function fundStake(opId, token, quantity, amm, adjustedMintAmount)
  -- Verify operation exists and is in pending state
  security.verifyOperation(opId, 'stake', 'pending')

  -- Transfer MINT to the AMM from our treasury
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
end

-- Handler patterns for staking operations
stake.patterns = {
  -- Pattern for initial stake request
  stake = function(msg)
    return msg.Tags.Action == 'Credit-Notice' and msg.Tags['X-User-Request'] == 'Stake'
  end,



  -- Pattern for AMM providing confirmation of liquidity provision
  provideConfirmation = function(msg)
    return msg.Tags.Action == 'Provide-Confirmation'
  end,

  -- Pattern for AMM providing error during staking process
  provideError = function(msg)
    return msg.Tags.Action == 'Credit-Notice' and
      msg.Tags['X-Refund-Reason'] ~= nil
  end,

  -- Pattern for handling unused tokens (refunds)
  refundUnused = function(msg)
    if config.LP_DECIMALS[msg.From] ~= nil then
      return false --this is LP being sent to us so we keep it
    end

    return msg.Tags.Action == 'Credit-Notice' and
      msg.Tags['X-User-Request'] ~= 'Stake' and
      msg.Tags['X-User-Request'] ~= 'Fund-Stake' and
      msg.Tags['X-Reason'] ~= 'Treasury-Fund' and
      msg.Tags['X-Refund-Reason'] == nil and
      msg.Tags['X-Action'] ~= 'Burn-LP-Output' --not from a burn (unstake) refund
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

    local opId, operation = operations.createOperation('stake', token, sender, quantity, amm)

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

      fundStake(opId, token, quantity, amm, adjustedMintAmount)
    end)
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
      mintAmount = msg.Tags['Provided-' .. config.MINT_TOKEN],
      stakedDate = os.time()
    })

    -- Record initial price ratio by querying AMM
    Send({
      Target = operation.amm,
      Action = 'Get-Reserves'
    }).onReply(function(reply)
      local reserve1 = reply.Tags['Reserve-1']
      local reserve2 = reply.Tags['Reserve-2']
      local token1 = reply.Tags['Token-1']
      local token2 = reply.Tags['Token-2']

      -- Determine which reserve corresponds to which token
      local mintReserve, tokenReserve
      if token1 == config.MINT_TOKEN then
        mintReserve = reserve1
        tokenReserve = reserve2
      else
        mintReserve = reserve2
        tokenReserve = reserve1
      end

      -- Calculate token/MINT price ratio
      local tokenPerMint = utils.math.divide(tokenReserve, mintReserve)

      -- Update staking position with initial price ratio
      state.updateStakingPosition(operation.token, operation.sender, {
        initialPriceRatio = tokenPerMint
      })

      utils.logEvent('InitialPriceRatioRecorded', {
        token = operation.token,
        tokenName = config.AllowedTokensNames[operation.token],
        initialPriceRatio = tokenPerMint,
        sender = operation.sender
      })
    end)

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

    if (msg.From == config.MINT_TOKEN) then
      return -- we are being refunded our own token
    end
    -- Verify we're getting refunded a legal token
    security.assertTokenAllowed(msg.From)

    -- Mark operation as failed (checks-effects-interactions pattern)
    operations.fail(operationId)

    -- Log the failed stake event
    utils.logEvent('StakeFailed', {
      sender = operation.sender,
      token = operation.token,
      tokenName = config.AllowedTokensNames[operation.token],
      amount = operation.amount,
      error = msg.Tags['X-Refund-Reason'] or 'Unknown error during liquidity provision',
      operationId = operationId
    })

    -- Determine recipient based on token type
    local recipient = operation.token == config.MINT_TOKEN and config.MINT_TOKEN or operation.sender

    -- Return the tokens
    Send({
      Target = operation.token,
      Action = 'Transfer',
      Recipient = recipient, --either the user or the treasury
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

    -- If token is MINT allow to stay in our treasury
    if token == config.MINT_TOKEN then
      return
    end

    -- For other tokens, verify operation exists
    local operation = operations.get(operationId)
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
