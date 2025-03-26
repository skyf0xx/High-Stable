-- Single-Sided Staking Contract - Stake Module
-- Handles all staking-related operations

local config = require('mintprotocol.config')
local state = require('mintprotocol.state')
local utils = require('mintprotocol.utils')
local security = require('mintprotocol.security')
local operations = require('mintprotocol.operations')


local stake = {}

-- Trim a string number to only the integer part based on the number of decimal places
local function trimToIntegerPart(stringNumber, decimalPlaces)
  -- Convert to string if not already
  stringNumber = tostring(stringNumber)

  -- If the number is shorter than or equal to the decimal places, return zero
  if #stringNumber <= decimalPlaces then
    return '0'
  end

  -- Otherwise, trim the decimal part
  return string.sub(stringNumber, 1, #stringNumber - decimalPlaces)
end

local function fundStake(opId, token, quantity, amm, adjustedMintAmount)
  -- Verify operation exists and is in pending state
  security.verifyOperation(opId, 'stake', 'pending')

  -- Get the appropriate MINT token for this staked token
  local mintToken = config.getMintTokenForStakedToken(token)

  -- Get the operation details
  local operation = operations.get(opId)

  -- Check MINT balance in treasury
  Send({
    Target = mintToken,
    Action = 'Balance',
    Recipient = ao.id -- The contract itself acts as the treasury
  }).onReply(function(balanceReply)
    local mintTreasuryBalance = balanceReply.Balance or '0'

    -- Get the number of decimal places for the MINT token
    local mintDecimals = config.TOKEN_DECIMALS[mintToken]

    -- Trim the balance and adjusted amount to integer parts
    local trimmedBalance = trimToIntegerPart(mintTreasuryBalance, mintDecimals)
    local trimmedAdjustedAmount = trimToIntegerPart(adjustedMintAmount, mintDecimals)

    -- Calculate threshold based on percentage of treasury
    local percentThreshold = '10' -- 10% of treasury
    local percentageBased = utils.math.divide(
      utils.math.multiply(trimmedBalance, percentThreshold),
      '100'
    )

    -- Fixed maximum amount (in MINT)
    local maxAmount = '50000' -- 50,000 MINT tokens
    -- We're working with the integer part now, so no need to adjust for decimals
    local fixedMaxAmount = maxAmount

    -- Use the smaller of the two thresholds
    local threshold = utils.math.isLessThan(percentageBased, fixedMaxAmount)
      and percentageBased
      or fixedMaxAmount

    -- Check if requested amount is below threshold and treasury has sufficient balance
    if utils.math.isLessThan(trimmedAdjustedAmount, threshold) and
      utils.math.isLessThan(trimmedAdjustedAmount, trimmedBalance) then
      -- Proceed with funding the stake

      -- Transfer MINT to the AMM from our treasury
      Send({
        Target = mintToken,
        Action = 'Transfer',
        Recipient = amm,
        Quantity = adjustedMintAmount, -- Use the original full amount for transfer
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
    else
      -- Not enough MINT in treasury, cancel the stake and refund the user
      operations.fail(opId)

      -- Log the failed stake event
      utils.logEvent('StakeFailed', {
        sender = operation.sender,
        token = token,
        tokenName = config.AllowedTokensNames[token],
        mintToken = mintToken,
        amount = quantity,
        error = 'Insufficient MINT balance in treasury',
        requiredAmount = adjustedMintAmount,
        availableAmount = mintTreasuryBalance,
        operationId = opId
      })

      -- Refund the user's tokens
      Send({
        Target = token,
        Action = 'Transfer',
        Recipient = operation.sender,
        Quantity = quantity,
        ['X-Refund-Reason'] = 'Insufficient MINT balance in treasury',
        ['X-Error'] = 'Insufficient MINT balance in treasury',
        ['X-Required-Amount'] = adjustedMintAmount,
        ['X-Available-Amount'] = mintTreasuryBalance,
        ['X-Operation-Id'] = opId
      })
    end
  end)
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
    -- Query AMM for current reserves to calculate MINT amount needed
    Send({
      Target = amm,
      Action = 'Get-Reserves'
    }).onReply(function(reply)
      -- Get the appropriate MINT token for this staked token
      local mintToken = config.getMintTokenForStakedToken(token)

      -- Get reserves for both tokens
      local mintReserve = reply.Tags[mintToken]
      local tokenReserve = reply.Tags[token]


      -- Calculate MINT amount based on current price ratio
      local mintAmount
      if utils.math.isZero(tokenReserve) then
        -- If pool is empty, use a default ratio (1:1)
        mintAmount = quantity
      else
        -- Calculate based on current pool ratio: quantity * (mintReserve / tokenReserve)
        mintAmount = utils.math.divide(
          utils.math.multiply(quantity, mintReserve),
          tokenReserve
        )
      end

      -- Apply excess multiplier to ensure all user tokens are used
      local adjustedMintAmount = utils.calculateAdjustedMintAmount(mintAmount)

      -- Log the calculated amounts
      utils.logEvent('StakingCalculation', {
        token = token,
        mintToken = mintToken,
        quantity = quantity,
        mintAmount = mintAmount,
        adjustedMintAmount = adjustedMintAmount,
        mintReserve = mintReserve,
        tokenReserve = tokenReserve
      })

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

    -- Get the appropriate MINT token for this staked token
    local mintToken = config.getMintTokenForStakedToken(operation.token)

    -- Update staking position with new values
    state.updateStakingPosition(operation.token, operation.sender, {
      amount = utils.math.add(
        state.getStakingPosition(operation.token, operation.sender).amount,
        msg.Tags['Provided-' .. usersToken]),
      lpTokens = utils.math.add(
        state.getStakingPosition(operation.token, operation.sender).lpTokens,
        receivedLP),
      mintAmount = msg.Tags['Provided-' .. mintToken],
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

      -- Get the appropriate MINT token for this staked token
      local mintToken = config.getMintTokenForStakedToken(operation.token)

      -- Determine which reserve corresponds to which token
      local mintReserve, tokenReserve
      if token1 == mintToken then
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
        mintToken = mintToken,
        initialPriceRatio = tokenPerMint,
        sender = operation.sender
      })
    end)

    -- Update pending operation with actual amounts used
    state.updatePendingOperation(operationId, {
      amount = msg.Tags['Provided-' .. usersToken],
      lpTokens = receivedLP,
      mintToken = mintToken,
      status = 'completed'
    })

    -- Log the successful stake event
    utils.logEvent('StakeComplete', {
      sender = operation.sender,
      token = operation.token,
      tokenName = config.AllowedTokensNames[operation.token],
      mintToken = mintToken,
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
      ['LP-Tokens'] = receivedLP,
      ['MINT-Token'] = mintToken
    })
  end,

  -- Handler for AMM providing error during staking process
  provideError = function(msg)
    security.assertNotPaused()

    local operationId = msg.Tags['X-Operation-Id']
    local operation = security.verifyOperation(operationId, 'stake', 'pending')

    -- Get the appropriate MINT token for this staked token
    local mintToken = config.getMintTokenForStakedToken(operation.token)

    if (msg.From == mintToken) then
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
      mintToken = mintToken,
      amount = operation.amount,
      error = msg.Tags['X-Refund-Reason'] or 'Unknown error during liquidity provision',
      operationId = operationId
    })

    -- Determine recipient based on token type
    local recipient = operation.token == mintToken and mintToken or operation.sender

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

    -- If token is any MINT token, allow to stay in our treasury
    if config.isMintToken(token) then
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
