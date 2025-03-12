-- Single-Sided Staking Contract - Impermanent Loss Module
-- Handles impermanent loss calculations and compensation

local config = require('mintprotocol.config')
local utils = require('mintprotocol.utils')
local security = require('mintprotocol.security')
local state = require('mintprotocol.state')

local impermanent_loss = {}

-- Check if impermanent loss occurred by comparing initial and withdrawn token amounts
function impermanent_loss.hasOccurred(withdrawnAmount, initialAmount)
  return utils.math.isLessThan(withdrawnAmount, initialAmount)
end

-- Calculate the token deficit (raw IL amount)
function impermanent_loss.calculateTokenDeficit(initialAmount, withdrawnAmount)
  return utils.math.subtract(initialAmount, withdrawnAmount)
end

-- Calculate the MINT token amount needed to compensate for impermanent loss
-- Calculate compensation amount based on staking duration and other factors
function impermanent_loss.calculateCompensationAmount(ilAmount, finalPriceRatio, initialStakeDate)
  -- Calculate staking duration in days
  local stakingDurationSeconds = (os.time() - initialStakeDate) / 1000
  local stakingDurationDays = stakingDurationSeconds / (24 * 60 * 60)

  -- Calculate coverage percentage based on vesting
  local vestingRatio = math.min(stakingDurationDays / config.IL_MAX_VESTING_DAYS, 1)
  local coveragePercentage = utils.math.multiply(
    tostring(vestingRatio * 100), -- Convert to percentage
    config.IL_MAX_COVERAGE_PERCENTAGE
  )
  coveragePercentage = utils.math.divide(coveragePercentage, config.IL_COVERAGE_DIVISOR)

  -- Calculate compensation: IL_X * Coverage% * R_final
  local mintCompensation = utils.math.multiply(ilAmount, finalPriceRatio)
  mintCompensation = utils.math.multiply(mintCompensation, coveragePercentage)
  mintCompensation = utils.math.divide(mintCompensation, config.IL_COVERAGE_DIVISOR)

  -- Apply compensation cap
  if utils.math.isGreaterThan(mintCompensation, config.IL_MAX_COMP_PER_USER) then
    return config.IL_MAX_COMP_PER_USER
  end

  return mintCompensation, coveragePercentage
end

-- Process impermanent loss compensation for an unstaking operation
-- Process impermanent loss compensation for an unstaking operation
function impermanent_loss.processCompensation(tokenData, operation)
  -- Get position to retrieve initial price ratio and stake date
  local position = state.getStakingPosition(operation.token, operation.sender) or {}
  local initialPriceRatio = position.initialPriceRatio
  local initialStakeDate = position.stakedDate or operation.timestamp

  -- If no impermanent loss detected through the simple method, check using standard formula
  local simpleIL = impermanent_loss.hasOccurred(tokenData.withdrawnUserToken, tokenData.initialUserTokenAmount)

  -- If no IL detected through simple method and no initial price ratio, return early
  if not simpleIL and not initialPriceRatio then
    return '0'
  end -- Fixed: Changed closing bracket to 'end'

  -- Get the AMM for the token
  local amm = security.getAmmForToken(operation.token)

  -- Query AMM for current price ratio (final ratio)
  Send({
    Target = amm,
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

    -- Calculate current token/MINT ratio
    local finalPriceRatio = utils.math.divide(tokenReserve, mintReserve)

    -- Calculate IL amount
    local ilAmount

    -- If we have initial price ratio, use standard IL formula
    if initialPriceRatio then
      ilAmount = impermanent_loss.calculateStandardIL(
        tokenData.initialUserTokenAmount,
        initialPriceRatio,
        finalPriceRatio
      )
    else
      -- Backward compatibility: use simple token deficit method
      ilAmount = impermanent_loss.calculateTokenDeficit(
        tokenData.initialUserTokenAmount,
        tokenData.withdrawnUserToken
      )
    end -- Fixed: Changed closing bracket to 'end'

    -- If no IL detected, return
    if utils.math.isZero(ilAmount) then
      return
    end -- Fixed: Changed closing bracket to 'end'

    -- Calculate compensation amount and coverage percentage
    local mintCompensation, coveragePercentage = impermanent_loss.calculateCompensationAmount(
      ilAmount,
      finalPriceRatio,
      initialStakeDate
    )

    -- Send compensation to the user
    Send({
      Target = config.MINT_TOKEN,
      Action = 'Transfer',
      Recipient = operation.sender,
      Quantity = mintCompensation,
      ['X-IL-Compensation'] = 'true',
      ['X-Token-Deficit'] = ilAmount,
      ['X-Deficit-Insurance-For-Token'] = config.AllowedTokensNames[operation.token],
      ['X-Operation-Id'] = operation.id,
      ['X-Coverage-Percentage'] = coveragePercentage,
      ['X-Staking-Duration-Days'] = tostring(math.floor((os.time() - initialStakeDate) / (24 * 60 * 60))),
      ['X-Initial-Price-Ratio'] = initialPriceRatio or 'N/A',
      ['X-Final-Price-Ratio'] = finalPriceRatio
    })

    -- Record metrics and log the compensation
    impermanent_loss.recordMetrics(operation.token, ilAmount, mintCompensation)

    utils.logEvent('ILCompensation', {
      formula = 'Enhanced IL Formula Applied',
      sender = operation.sender,
      token = operation.token,
      tokenName = config.AllowedTokensNames[operation.token],
      initialAmount = tokenData.initialUserTokenAmount,
      withdrawnAmount = tokenData.withdrawnUserToken,
      ilAmount = ilAmount,
      mintCompensation = mintCompensation,
      coveragePercentage = coveragePercentage,
      stakingDurationDays = math.floor((os.time() - initialStakeDate) / (24 * 60 * 60)),
      initialPriceRatio = initialPriceRatio or 'Not available',
      finalPriceRatio = finalPriceRatio,
      operationId = operation.id
    })
  end)

  -- Return token deficit for immediate reference
  -- Actual compensation happens asynchronously
  return impermanent_loss.calculateTokenDeficit(
    tokenData.initialUserTokenAmount,
    tokenData.withdrawnUserToken
  )
end

-- Calculate estimated IL for a position without processing compensation
function impermanent_loss.estimateIL(token, lpAmount, initialUserAmount, initialMintAmount)
  local amm = security.getAmmForToken(token)

  -- Create a promise-like structure for async response
  local estimationResult = {
    pending = true,
    completed = false,
    result = nil
  }

  -- Query AMM for simulated burn result without executing
  Send({
    Target = amm,
    Action = 'Simulate-Burn',
    Quantity = lpAmount,
    ['X-Simulation-Only'] = 'true'
  }).onReply(function(reply)
    -- Extract the simulated withdrawn amounts
    local simulatedWithdrawnUserToken = reply.Tags['Simulated-Withdrawn-' .. token]
    local simulatedWithdrawnMintToken = reply.Tags['Simulated-Withdrawn-' .. config.MINT_TOKEN]

    -- Calculate potential token deficit (impermanent loss)
    local tokenDeficit = '0'
    local hasIL = false

    if simulatedWithdrawnUserToken and initialUserAmount then
      if utils.math.isLessThan(simulatedWithdrawnUserToken, initialUserAmount) then
        tokenDeficit = utils.math.subtract(initialUserAmount, simulatedWithdrawnUserToken)
        hasIL = true
      end
    end

    -- Calculate estimated MINT compensation
    local estimatedCompensation = '0'

    if hasIL and utils.math.isPositive(tokenDeficit) then
      -- Query for MINT equivalent of the token deficit
      Send({
        Target = amm,
        Action = 'Get-Swap-Output',
        Token = token,
        Quantity = tokenDeficit,
        ['X-Simulation-Only'] = 'true'
      }).onReply(function(swapReply)
        local mintEquivalent = swapReply.Tags.Output
        estimatedCompensation = impermanent_loss.calculateCompensationAmount(mintEquivalent)

        -- Complete the estimation result
        estimationResult.result = {
          estimated = true,
          tokenDeficit = tokenDeficit,
          estimatedCompensation = estimatedCompensation,
          hasIL = hasIL,
          simulatedWithdrawnUserToken = simulatedWithdrawnUserToken,
          simulatedWithdrawnMintToken = simulatedWithdrawnMintToken,
          initialUserAmount = initialUserAmount,
          initialMintAmount = initialMintAmount
        }

        estimationResult.completed = true
        estimationResult.pending = false
      end)
    else
      -- No IL expected, complete the estimation result
      estimationResult.result = {
        estimated = true,
        tokenDeficit = '0',
        estimatedCompensation = '0',
        hasIL = false,
        simulatedWithdrawnUserToken = simulatedWithdrawnUserToken,
        simulatedWithdrawnMintToken = simulatedWithdrawnMintToken,
        initialUserAmount = initialUserAmount,
        initialMintAmount = initialMintAmount
      }

      estimationResult.completed = true
      estimationResult.pending = false
    end
  end)

  return estimationResult
end

-- Extract current price ratio from liquidity pool
function impermanent_loss.getCurrentPriceRatio(token)
  local amm = security.getAmmForToken(token)

  -- Create a promise-like structure for async response
  local ratioResult = {
    pending = true,
    completed = false,
    result = nil
  }

  -- Query AMM for current reserves
  Send({
    Target = amm,
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

    -- Calculate price ratios
    local tokenPerMint = utils.math.divide(tokenReserve, mintReserve)
    local mintPerToken = utils.math.divide(mintReserve, tokenReserve)

    -- Complete the ratio result
    ratioResult.result = {
      tokenPerMint = tokenPerMint,
      mintPerToken = mintPerToken,
      tokenReserve = tokenReserve,
      mintReserve = mintReserve,
      timestamp = os.time()
    }

    ratioResult.completed = true
    ratioResult.pending = false

    -- Log the price ratio for monitoring
    utils.logEvent('PriceRatioQueried', {
      token = token,
      tokenName = config.AllowedTokensNames[token],
      tokenPerMint = tokenPerMint,
      mintPerToken = mintPerToken
    })
  end)

  return ratioResult
end

-- Track historical IL metrics
function impermanent_loss.recordMetrics(token, ilAmount, compensationAmount)
  -- Initialize metrics storage if needed
  ILMetrics = ILMetrics or {}
  ILMetrics[token] = ILMetrics[token] or {
    totalIL = '0',
    totalCompensation = '0',
    occurrences = 0,
    lastUpdated = 0,
    history = {}
  }

  -- Update metrics
  ILMetrics[token].totalIL = utils.math.add(ILMetrics[token].totalIL, ilAmount)
  ILMetrics[token].totalCompensation = utils.math.add(ILMetrics[token].totalCompensation, compensationAmount)
  ILMetrics[token].occurrences = ILMetrics[token].occurrences + 1
  ILMetrics[token].lastUpdated = os.time()

  -- Add to history (keep last 100 entries)
  table.insert(ILMetrics[token].history, {
    timestamp = os.time(),
    ilAmount = ilAmount,
    compensationAmount = compensationAmount
  })

  -- Trim history if needed
  if #ILMetrics[token].history > 100 then
    table.remove(ILMetrics[token].history, 1)
  end

  -- Log event
  utils.logEvent('ILMetricsUpdated', {
    token = token,
    tokenName = config.AllowedTokensNames[token],
    totalIL = ILMetrics[token].totalIL,
    totalCompensation = ILMetrics[token].totalCompensation,
    occurrences = ILMetrics[token].occurrences
  })

  return ILMetrics[token]
end

-- Get IL metrics for analysis
function impermanent_loss.getMetrics(token)
  if not token then
    -- Return metrics for all tokens
    local allMetrics = {}
    for tokenAddr, metrics in pairs(ILMetrics or {}) do
      allMetrics[tokenAddr] = {
        tokenName = config.AllowedTokensNames[tokenAddr],
        totalIL = metrics.totalIL,
        totalCompensation = metrics.totalCompensation,
        occurrences = metrics.occurrences,
        lastUpdated = metrics.lastUpdated
      }
    end
    return allMetrics
  else
    -- Return metrics for specific token
    return ILMetrics and ILMetrics[token] or {
      totalIL = '0',
      totalCompensation = '0',
      occurrences = 0,
      lastUpdated = 0,
      history = {}
    }
  end
end

-- Calculate the effective IL rate for a specific token
function impermanent_loss.calculateILRate(token)
  local metrics = impermanent_loss.getMetrics(token)

  -- Get total staked amount for this token
  local totalStaked = utils.math.toBalanceValue('0')
  local stakingPositions = state.getStakingPositions()

  if stakingPositions[token] then
    for _, position in pairs(stakingPositions[token]) do
      if position and position.amount then
        totalStaked = utils.math.add(totalStaked, position.amount)
      end
    end
  end

  -- If no tokens staked or no IL occurrences, return zero rate
  if utils.math.isZero(totalStaked) or metrics.occurrences == 0 then
    return '0'
  end

  -- Calculate IL as percentage of total staked
  local ilRate = utils.math.divide(
    utils.math.multiply(metrics.totalIL, '10000'),
    totalStaked
  )

  return ilRate -- IL rate in basis points (e.g., 100 = 1%)
end

-- Get IL history for a token
function impermanent_loss.getILHistory(token)
  if not ILMetrics or not ILMetrics[token] then
    return {}
  end

  return ILMetrics[token].history
end

-- Calculate impermanent loss using the standard IL formula:
-- IL_X = max(Deposited_X * (1 - sqrt(R_final / R_initial)), 0)
-- Calculate impermanent loss using the standard IL formula:
-- IL_X = max(Deposited_X * (1 - sqrt(R_final / R_initial)), 0)
function impermanent_loss.calculateStandardIL(initialAmount, initialRatio, finalRatio)
  -- Handle case where initial ratio is zero or not available
  if utils.math.isZero(initialRatio) then
    return '0'
  end

  -- Calculate price ratio change
  local ratioChange = utils.math.divide(finalRatio, initialRatio)

  -- Calculate square root of ratio change
  local ratioChangeNum = tonumber(ratioChange)
  if not ratioChangeNum or ratioChangeNum < 0 then
    utils.logEvent('ILCalculationError', {
      error = 'Invalid ratio change value for square root',
      initialRatio = initialRatio,
      finalRatio = finalRatio,
      ratioChange = ratioChange
    })
    return '0' -- Return no IL if we can't calculate it properly
  end

  local sqrtRatioChange = math.sqrt(ratioChangeNum)

  -- Calculate IL factor: (1 - sqrt(R_final / R_initial))
  local ilFactor = 1 - sqrtRatioChange

  -- If IL factor is negative or zero, there's no impermanent loss
  if ilFactor <= 0 then
    return '0'
  end

  -- Calculate IL amount with precision (multiply by 1000, then divide)
  local ilAmount = utils.math.multiply(initialAmount, tostring(ilFactor * 1000))
  ilAmount = utils.math.divide(ilAmount, '1000')

  return ilAmount
end

return impermanent_loss
