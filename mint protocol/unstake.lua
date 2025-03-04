-- Single-Sided Staking Contract - Unstake Module
-- Handles all unstaking-related operations

local config = require('config')
local state = require('state')
local utils = require('utils')
local security = require('security')
local impermanent_loss = require('impermanent_loss') -- Add this import
local operations = require('operations')

local unstake = {}

-- Handler patterns for unstaking operations
unstake.patterns = {
  -- Pattern for initial unstake request

  unstake = function(msg)
    security.assertNotPaused()

    local token = msg.Tags['Token']
    local sender = msg.From

    -- Validate token and staking position
    security.assertTokenAllowed(token)
    security.assertStakingPositionExists(token, sender)
    security.assertStakingPositionHasTokens(token, sender)

    -- Get the corresponding AMM for this token
    local amm = security.getAmmForToken(token)

    local position = state.getStakingPosition(token, sender)



    -- Store the position values before clearing
    local positionAmount = position and position.amount or '0'
    local positionLpTokens = position and position.lpTokens or '0'
    local positionMintAmount = position and position.mintAmount or '0'

    -- Clear staking position (checks-effects-interactions pattern)
    state.clearStakingPosition(token, sender)

    local additionalFields = {
      lpTokens = positionLpTokens,
      mintAmount = positionMintAmount
    }
    local opId, operation = operations.createOperation('unstake', token, sender, positionAmount, amm, additionalFields)

    -- Log unstake initiated
    utils.logEvent('UnstakeInitiated', {
      sender = sender,
      token = token,
      tokenName = config.AllowedTokensNames[token],
      amount = position and position.amount or '0',
      lpTokens = position and position.lpTokens or '0',
      operationId = opId
    })

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
      TokenName = config.AllowedTokensNames[token],
      Amount = positionAmount,
      ['Operation-Id'] = opId
    })
  end,

  -- Pattern for AMM burn confirmation
  burnConfirmation = function(msg)
    return msg.Tags.Action == 'Burn-Confirmation'
  end
}

-- Helper function to validate burn operation
local function validateBurnOperation(msg)
  security.assertNotPaused()

  local operationId = msg.Tags['X-Operation-Id']
  local operation = security.verifyOperation(operationId, 'unstake', 'pending')
  security.assertIsValidAmm(msg.From, operation.amm)

  return operation
end

-- Helper function to extract token amounts from burn confirmation
local function extractTokenAmounts(msg, operation)
  local usersToken = utils.getUsersToken(msg.Tags['Token-A'], msg.Tags['Token-B'])

  return {
    withdrawnUserToken = msg.Tags['Withdrawn-' .. usersToken],
    withdrawnMintToken = msg.Tags['Withdrawn-' .. config.MINT_TOKEN],
    initialUserTokenAmount = operation.amount,
    initialMintTokenAmount = operation.mintAmount,
    burnedLpTokens = msg.Tags['Burned-Pool-Tokens'],
    usersToken = usersToken
  }
end

-- REMOVED: handleImpermanentLoss function is now replaced with the call to impermanent_loss.processCompensation

-- Helper function to handle user token profit sharing
local function handleUserTokenProfitSharing(tokenData, operation)
  if utils.math.isLessThan(tokenData.withdrawnUserToken, tokenData.initialUserTokenAmount) or
    utils.math.isEqual(tokenData.withdrawnUserToken, tokenData.initialUserTokenAmount) then
    return {
      userTokenProfit = '0',
      feeShareAmount = '0',
      amountToSendUser = tokenData.withdrawnUserToken
    }
  end

  -- User has made profit
  local userTokenProfit = utils.math.subtract(tokenData.withdrawnUserToken, tokenData.initialUserTokenAmount)

  -- Calculate fee split: 99% to user, 1% to protocol (adjustable ratio)
  local protocolFees = utils.math.divide(
    utils.math.multiply(userTokenProfit, config.PROTOCOL_FEE_PERCENTAGE),
    config.FEE_DIVISOR
  )
  local userShare = utils.math.subtract(userTokenProfit, protocolFees)

  -- Adjust amount to send user
  local amountToSendUser = utils.math.subtract(tokenData.withdrawnUserToken, protocolFees)

  -- Log fee sharing for user token
  utils.logEvent('UserTokenFeeSharing', {
    sender = operation.sender,
    token = operation.token,
    tokenName = config.AllowedTokensNames[operation.token],
    initialAmount = tokenData.initialUserTokenAmount,
    withdrawnAmount = tokenData.withdrawnUserToken,
    profit = userTokenProfit,
    userShare = userShare,
    protocolShare = protocolFees,
    operationId = operation.id
  })

  return {
    userTokenProfit = userTokenProfit,
    feeShareAmount = userShare,
    amountToSendUser = amountToSendUser
  }
end

-- Helper function to handle MINT token profit sharing-- Helper function to handle MINT token profit sharing
local function handleMintTokenProfitSharing(tokenData, operation)
  if utils.math.isLessThan(tokenData.withdrawnMintToken, tokenData.initialMintTokenAmount) or
    utils.math.isEqual(tokenData.withdrawnMintToken, tokenData.initialMintTokenAmount) then
    return '0' -- No profit to share
  end

  local mintTokenProfit = utils.math.subtract(tokenData.withdrawnMintToken, tokenData.initialMintTokenAmount)

  -- Calculate fee split: protocol fee percentage to treasury, rest to user
  local protocolFee = utils.math.divide(
    utils.math.multiply(mintTokenProfit, config.PROTOCOL_FEE_PERCENTAGE),
    config.FEE_DIVISOR
  )
  local userShare = utils.math.subtract(mintTokenProfit, protocolFee)

  -- Send user's share of MINT profits
  Send({
    Target = config.MINT_TOKEN,
    Action = 'Transfer',
    Recipient = operation.sender,
    Quantity = userShare,
    ['X-MINT-Profit-Share'] = 'true',
    ['X-Operation-Id'] = operation.id
  })

  -- Log MINT profit sharing
  utils.logEvent('MintTokenProfitSharing', {
    sender = operation.sender,
    initialMintAmount = tokenData.initialMintTokenAmount,
    withdrawnMintAmount = tokenData.withdrawnMintToken,
    profit = mintTokenProfit,
    userShare = userShare,
    protocolShare = protocolFee,
    operationId = operation.id
  })

  return userShare
end

-- Helper function to send tokens and notify user
local function sendTokensAndNotify(operation, tokenData, results)
  -- Return user's tokens
  Send({
    Target = operation.token,
    Action = 'Transfer',
    Recipient = operation.sender,
    Quantity = results.amountToSendUser,
    ['X-Message'] = 'Unstake-Complete',
    ['X-Token'] = operation.token,
    ['X-TokenName'] = config.AllowedTokensNames[operation.token],
    ['X-Amount'] = results.amountToSendUser,
    ['X-Initial-User-Token-Amount'] = tokenData.initialUserTokenAmount,
    ['X-Withdrawn-User-Token'] = tokenData.withdrawnUserToken,
    ['X-Initial-MINT-Amount'] = tokenData.initialMintTokenAmount,
    ['X-Withdrawn-MINT'] = tokenData.withdrawnMintToken,
    ['X-IL-Compensation'] = results.ilCompensation,
    ['X-User-Token-Profit-Share'] = results.feeShareAmount,
    ['X-MINT-Profit-Share'] = results.mintProfitShare,
    ['X-LP-Tokens-Burned'] = tokenData.burnedLpTokens
  })

  -- Notify user with a separate message
  Send({
    Target = operation.sender,
    Action = 'Unstake-Complete',
    Token = operation.token,
    TokenName = config.AllowedTokensNames[operation.token],
    ['Initial-Amount'] = tokenData.initialUserTokenAmount,
    ['Withdrawn-Amount'] = results.amountToSendUser,
    ['IL-Compensation'] = results.ilCompensation,
    ['Profit-Share'] = results.feeShareAmount,
    ['MINT-Profit-Share'] = results.mintProfitShare,
    ['LP-Tokens-Burned'] = tokenData.burnedLpTokens,
    ['Operation-Id'] = operation.id
  })
end

-- Handler implementations for unstaking operations
unstake.handlers = {
  -- Handler for initial unstake request
  unstake = function(msg)
    security.assertNotPaused()

    local token = msg.Tags['Token']
    local sender = msg.From

    -- Validate token and staking position
    security.assertTokenAllowed(token)
    security.assertStakingPositionExists(token, sender)
    security.assertStakingPositionHasTokens(token, sender)

    -- Get the corresponding AMM for this token
    local amm = security.getAmmForToken(token)

    local position = state.getStakingPosition(token, sender)
    local opId = utils.operationId(sender, token, 'unstake')

    -- Log unstake initiated
    utils.logEvent('UnstakeInitiated', {
      sender = sender,
      token = token,
      tokenName = config.AllowedTokensNames[token],
      amount = position and position.amount or '0',
      lpTokens = position and position.lpTokens or '0',
      operationId = opId
    })

    -- Store the position values before clearing
    local positionAmount = position and position.amount or '0'
    local positionLpTokens = position and position.lpTokens or '0'
    local positionMintAmount = position and position.mintAmount or '0'

    -- Clear staking position (checks-effects-interactions pattern)
    state.clearStakingPosition(token, sender)

    -- Create pending operation
    state.setPendingOperation(opId, {
      id = opId,
      type = 'unstake',
      token = token,
      sender = sender,
      amount = positionAmount,
      lpTokens = positionLpTokens,
      mintAmount = positionMintAmount,
      amm = amm,
      status = 'pending',
      timestamp = os.time()
    })

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
      TokenName = config.AllowedTokensNames[token],
      Amount = positionAmount,
      ['Operation-Id'] = opId
    })
  end,

  -- Handler for AMM burn confirmation
  -- Handler for AMM burn confirmation
  burnConfirmation = function(msg)
    -- Step 1: Validate the operation
    local operation = validateBurnOperation(msg)

    -- Step 2: Extract token amounts
    local tokenData = extractTokenAmounts(msg, operation)

    -- Step 3: Mark operation as completed (checks-effects-interactions)
    state.completePendingOperation(msg.Tags['X-Operation-Id'])

    -- Step 4: Process impermanent loss and profit sharing
    -- Use the impermanent_loss module to handle IL compensation
    local ilCompensation = impermanent_loss.processCompensation(tokenData, operation)

    local userTokenResults = handleUserTokenProfitSharing(tokenData, operation)

    local mintProfitShare = handleMintTokenProfitSharing(tokenData, operation)

    -- Step 5: Send tokens and notify user
    local results = {
      amountToSendUser = userTokenResults.amountToSendUser,
      ilCompensation = ilCompensation,
      feeShareAmount = userTokenResults.feeShareAmount,
      mintProfitShare = mintProfitShare
    }

    sendTokensAndNotify(operation, tokenData, results)

    -- Log unstake completed
    utils.logEvent('UnstakeComplete', {
      sender = operation.sender,
      token = operation.token,
      tokenName = config.AllowedTokensNames[operation.token],
      initialAmount = tokenData.initialUserTokenAmount,
      withdrawnAmount = tokenData.withdrawnUserToken,
      lpTokensBurned = tokenData.burnedLpTokens,
      ilCompensation = ilCompensation,
      userTokenProfit = userTokenResults.userTokenProfit,
      mintProfitShare = mintProfitShare,
      operationId = operation.id
    })
  end
}

return unstake
