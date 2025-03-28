-- Single-Sided Staking Contract - Query Module
-- Handles all read-only query operations for retrieving contract state

local config = require('mintprotocol.config')
local state = require('mintprotocol.state')
local utils = require('mintprotocol.utils')
local security = require('mintprotocol.security')
local json = require('json')
local impermanent_loss = require('mintprotocol.impermanent_loss')

local query = {}

-- Handler patterns for query operations
query.patterns = {
  -- Pattern for getting a specific staking position
  getPosition = function(msg)
    return msg.Tags.Action == 'Get-Position'
  end,

  -- Pattern for getting all positions for a user
  getAllPositions = function(msg)
    return msg.Tags.Action == 'Get-All-Positions'
  end,

  -- Pattern for getting allowed tokens list
  getAllowedTokens = function(msg)
    return msg.Tags.Action == 'Get-Allowed-Tokens'
  end,

  getInsuranceInfo = function(msg)
    return msg.Tags.Action == 'Get-Insurance-Info'
  end,

  getProtocolMetrics = function(msg)
    return msg.Tags.Action == 'Get-Protocol-Metrics'
  end,

  getPositionsForToken = function(msg)
    return msg.Tags.Action == 'Get-Positions-For-Token'
  end,

}

-- Handler implementations for query operations
query.handlers = {
  -- Handler for getting a specific staking position
  getPosition = function(msg)
    local token = msg.Tags['Token']
    local user = msg.Tags['User'] or msg.From

    -- Validate token is allowed
    security.assertTokenAllowed(token)

    -- Get the corresponding AMM for this token
    local amm = security.getAmmForToken(token)

    -- Get the appropriate MINT token for this staked token
    local mintToken = config.getMintTokenForStakedToken(token)

    -- Get position or return default values if it doesn't exist
    local position = state.getStakingPosition(token, user) or {
      amount = '0',
      lpTokens = '0',
      mintAmount = '0'
    }

    -- Calculate time staked if available
    local timeStaked = ''
    if position.stakedDate then
      local elapsedMilliSeconds = utils.timeElapsedSince(position.stakedDate)
      timeStaked = utils.formatDuration(elapsedMilliSeconds)
    end

    -- Format amounts for better readability
    local formattedAmount = utils.formatTokenQuantity(position.amount, token, false)
    local formattedLpTokens = utils.formatTokenQuantity(position.lpTokens, amm, true)
    local formattedMintAmount = utils.formatTokenQuantity(position.mintAmount, mintToken, false)

    -- Reply with position information
    msg.reply({
      Action = 'Position-Info',
      Token = token,
      ['Token-Name'] = config.AllowedTokensNames[token],
      Amount = position.amount,
      ['Formatted-Amount'] = formattedAmount,
      ['LP-Tokens'] = position.lpTokens,
      ['Formatted-LP-Tokens'] = formattedLpTokens,
      ['MINT-Amount'] = position.mintAmount,
      ['Formatted-MINT-Amount'] = formattedMintAmount,
      ['Time-Staked'] = timeStaked,
      ['AMM'] = amm,
      ['MINT-Token'] = mintToken -- Add which MINT token is used for this position
    })
  end,

  -- Handler for getting all positions for a user
  getAllPositions = function(msg)
    local user = msg.Tags['User'] or msg.From
    local positions = {}

    -- Gather all staking positions for the user across all tokens
    for token, tokenName in pairs(config.AllowedTokensNames) do
      local amm = security.getAmmForToken(token)
      local position = state.getStakingPosition(token, user)

      -- Get the appropriate MINT token for this staked token
      local mintToken = config.getMintTokenForStakedToken(token)

      if position and utils.math.isPositive(position.amount) then
        -- Calculate time staked if available
        local timeStaked = ''
        if position.stakedDate then
          local elapsedSeconds = utils.timeElapsedSince(position.stakedDate)
          timeStaked = utils.formatDuration(elapsedSeconds)
        end

        -- Format amounts for better readability
        local formattedAmount = utils.formatTokenQuantity(position.amount, token, false)
        local formattedLpTokens = utils.formatTokenQuantity(position.lpTokens, amm, true)
        local formattedMintAmount = utils.formatTokenQuantity(position.mintAmount, mintToken, false)


        -- Add position to results
        positions[token] = {
          name = tokenName,
          amount = position.amount,
          formattedAmount = formattedAmount,
          lpTokens = position.lpTokens,
          formattedLpTokens = formattedLpTokens,
          mintAmount = position.mintAmount,
          formattedMintAmount = formattedMintAmount,
          timeStaked = timeStaked,
          amm = amm,
          mintToken = mintToken -- Add which MINT token is used for this position
        }
      end
    end

    -- Reply with all positions
    msg.reply({
      Action = 'All-Positions',
      User = user,
      Data = json.encode(positions),
      ['Positions-Count'] = tostring(#positions or 0)
    })
  end,

  -- Handler for getting allowed tokens list
  getAllowedTokens = function(msg)
    local allowedTokens = {}

    -- Gather information about all allowed tokens
    for token, name in pairs(config.AllowedTokensNames) do
      local mintToken = config.getMintTokenForStakedToken(token)

      table.insert(allowedTokens, {
        address = token,
        name = name,
        amm = config.TOKEN_AMM_MAPPINGS[token],
        decimals = config.getDecimalsForToken(token),
        mintToken = mintToken -- Add which MINT token is used for this token
      })
    end

    -- Reply with allowed tokens information
    msg.reply({
      Action = 'Allowed-Tokens',
      Data = json.encode(allowedTokens),
      Count = tostring(#allowedTokens)
    })
  end,

  getInsuranceInfo = function(msg)
    -- Calculate human-readable MINT maximum compensation
    local mintDecimals = config.TOKEN_DECIMALS[config.MINT_TOKEN] or 8
    local maxCompHuman = tonumber(config.IL_MAX_COMP_PER_USER) / (10 ^ mintDecimals)

    -- Basic insurance info response
    local responseData = {
      version = config.VERSION,
      maxVestingDays = config.IL_MAX_VESTING_DAYS,
      maxCoveragePercentage = config.IL_MAX_COVERAGE_PERCENTAGE .. '%',
      maxCompensationPerUser = maxCompHuman .. ' MINT',
      protocolFeePercentage = config.PROTOCOL_FEE_PERCENTAGE .. '%',
      rebasingBurnRate = '0.25% weekly for MINT token',
      allowedTokens = {},
      mintTokens = {
        main = config.MINT_TOKEN,
        testnet = config.MINT_TESTNET_TOKEN
      }
    }

    -- Add coverage explanation
    responseData.coverageExplanation = {
      formula = 'MINT_comp = min(IL_X * Coverage% * R_final, COMP_CAP)',
      coverageFormula = 'Coverage% = min(t / T_max, 1) * C_max',
      ilFormula = 'IL_X = max(Deposited_X * (1 - sqrt(R_final / R_initial)), 0)',
      explanation = string.format(
        'Coverage increases linearly from 0%% on day 0 to %s%% after %d days. The compensation in MINT tokens equals the impermanent loss amount multiplied by the coverage percentage and the current token/MINT price ratio, up to a maximum of %s MINT per user.',
        config.IL_MAX_COVERAGE_PERCENTAGE,
        config.IL_MAX_VESTING_DAYS,
        maxCompHuman
      )
    }

    -- Add coverage examples
    responseData.coverageExamples = {
      ['Day 1'] = string.format('%.2f%%', (1 / config.IL_MAX_VESTING_DAYS) * tonumber(config.IL_MAX_COVERAGE_PERCENTAGE)),
      ['Day 7'] = string.format('%.2f%%', (7 / config.IL_MAX_VESTING_DAYS) * tonumber(config.IL_MAX_COVERAGE_PERCENTAGE)),
      ['Day 15'] = string.format('%.2f%%',
        (15 / config.IL_MAX_VESTING_DAYS) * tonumber(config.IL_MAX_COVERAGE_PERCENTAGE)),
      ['Day 30+'] = config.IL_MAX_COVERAGE_PERCENTAGE .. '% (maximum)'
    }

    -- Add practical example
    responseData.practicalExample = {
      scenario = 'User stakes 100 tokens when the price is 1 MINT = 2 tokens (0.5 tokens per MINT)',
      priceChange = 'Price changes to 1 MINT = 1 token (1 token per MINT)',
      ilAmount = 'Impermanent loss = 29.3 tokens',
      stakingDuration = 'User has staked for 15 days (15/' .. config.IL_MAX_VESTING_DAYS .. ' = 50% of vesting)',
      coverage = 'Coverage = 50% of ' ..
        config.IL_MAX_COVERAGE_PERCENTAGE .. '% = ' .. (tonumber(config.IL_MAX_COVERAGE_PERCENTAGE) / 2) .. '%',
      compensation = string.format('Compensation = 29.3 tokens × %d%% × 1 token/MINT = %.2f MINT',
        tonumber(config.IL_MAX_COVERAGE_PERCENTAGE) / 2, 29.3 * (tonumber(config.IL_MAX_COVERAGE_PERCENTAGE) / 100 / 2) *
        1)
    }

    -- Add testnet explanation
    responseData.testnetExplanation = {
      description = 'The protocol supports both main MINT token and testnet MINT token',
      usage = 'When staking Test Tube Token, the protocol uses testnet MINT token for all operations',
      tokens = {
        ['Test Tube Token'] = config.MINT_TESTNET_TOKEN,
        ['All other tokens'] = config.MINT_TOKEN
      }
    }

    -- Add all supported tokens
    for tokenAddr, tokenName in pairs(config.AllowedTokensNames) do
      local mintToken = config.getMintTokenForStakedToken(tokenAddr)

      responseData.allowedTokens[tokenAddr] = {
        name = tokenName,
        amm = config.TOKEN_AMM_MAPPINGS[tokenAddr],
        decimals = config.getDecimalsForToken(tokenAddr),
        mintToken = mintToken -- Add which MINT token is used for this token
      }
    end

    -- Count number of tokens (fix for table.getn issue)
    local tokenCount = 0
    for _, _ in pairs(responseData.allowedTokens) do
      tokenCount = tokenCount + 1
    end

    -- Safe JSON encoding with pcall for general info
    local success, encodedData = pcall(json.encode, responseData)
    if not success then
      msg.reply({
        Action = 'Insurance-Info-Error',
        Error = 'JSON encoding error'
      })
      return
    end

    -- Reply with general insurance info for all tokens
    msg.reply({
      Action = 'Insurance-Info',
      Data = encodedData,
      ['Max-Vesting-Days'] = tostring(config.IL_MAX_VESTING_DAYS),
      ['Max-Coverage-Percentage'] = config.IL_MAX_COVERAGE_PERCENTAGE .. '%',
      ['Max-Compensation'] = maxCompHuman .. ' MINT',
      ['Supported-Tokens'] = tostring(tokenCount),
      ['MINT-Token'] = config.MINT_TOKEN,
      ['MINT-Testnet-Token'] = config.MINT_TESTNET_TOKEN
    })
  end
  ,

  getProtocolMetrics = function(msg)
    local metrics = {
      contractVersion = config.VERSION,
      isPaused = state.isPaused(),
      timestamp = os.time(),
      totalSupportedTokens = 0,
      totalActiveUsers = 0,
      totalStakingPositions = 0,
      totalPendingOperations = state.countPendingOperations(),
      tokenMetrics = {},
      impermanentLossMetrics = {},
      mintTokens = {
        main = config.MINT_TOKEN,
        testnet = config.MINT_TESTNET_TOKEN
      }
    }

    -- Track unique users across all tokens
    local uniqueUsers = {}

    -- Collect token-specific metrics
    for token, tokenName in pairs(config.AllowedTokensNames) do
      metrics.totalSupportedTokens = metrics.totalSupportedTokens + 1

      -- Get the appropriate MINT token for this staked token
      local mintToken = config.getMintTokenForStakedToken(token)

      -- Initialize token metrics
      local tokenMetric = {
        address = token,
        name = tokenName,
        totalStaked = '0',
        activePositions = 0,
        activeUsers = 0,
        amm = config.TOKEN_AMM_MAPPINGS[token],
        decimals = config.getDecimalsForToken(token),
        mintToken = mintToken -- Add which MINT token is used for this token
      }

      -- Get all staking positions for this token
      local stakingPositions = state.getStakingPositions()
      if stakingPositions[token] then
        for user, position in pairs(stakingPositions[token]) do
          if position and utils.math.isPositive(position.amount) then
            -- Count active positions
            tokenMetric.activePositions = tokenMetric.activePositions + 1

            -- Track unique users
            if not uniqueUsers[user] then
              uniqueUsers[user] = true
              metrics.totalActiveUsers = metrics.totalActiveUsers + 1
            end

            -- Count active users per token
            tokenMetric.activeUsers = tokenMetric.activeUsers + 1

            -- Sum total staked amount
            tokenMetric.totalStaked = utils.math.add(tokenMetric.totalStaked, position.amount)
          end
        end
      end

      -- Calculate human-readable total staked with proper decimal places
      tokenMetric.formattedTotalStaked = utils.formatTokenQuantity(tokenMetric.totalStaked, token, false)

      -- Store token metrics
      metrics.tokenMetrics[token] = tokenMetric

      -- Add total staking positions
      metrics.totalStakingPositions = metrics.totalStakingPositions + tokenMetric.activePositions
    end


    metrics.impermanentLossMetrics = impermanent_loss.getMetrics()

    -- If we have IL metrics, calculate some additional stats
    if metrics.impermanentLossMetrics then
      metrics.totalILOccurrences = 0
      metrics.totalILCompensationAmount = '0'
      metrics.totalILCompensationByMintToken = {
        [config.MINT_TOKEN] = '0',
        [config.MINT_TESTNET_TOKEN] = '0'
      }

      for tokenAddr, tokenMetrics in pairs(metrics.impermanentLossMetrics) do
        if tokenMetrics.occurrences then
          metrics.totalILOccurrences = metrics.totalILOccurrences + tokenMetrics.occurrences
        end

        if tokenMetrics.totalCompensation then
          metrics.totalILCompensationAmount = utils.math.add(
            metrics.totalILCompensationAmount,
            tokenMetrics.totalCompensation
          )

          -- Add to the appropriate MINT token total
          local mintToken = config.getMintTokenForStakedToken(tokenAddr)
          metrics.totalILCompensationByMintToken[mintToken] = utils.math.add(
            metrics.totalILCompensationByMintToken[mintToken],
            tokenMetrics.totalCompensation
          )
        end
      end

      -- Format total IL compensation to be human-readable (for both tokens)
      metrics.formattedTotalILCompensation = utils.formatTokenQuantity(
        metrics.totalILCompensationAmount,
        config.MINT_TOKEN,
        false
      )

      metrics.formattedTotalILCompensationByMintToken = {
        [config.MINT_TOKEN] = utils.formatTokenQuantity(
          metrics.totalILCompensationByMintToken[config.MINT_TOKEN],
          config.MINT_TOKEN,
          false
        ),
        [config.MINT_TESTNET_TOKEN] = utils.formatTokenQuantity(
          metrics.totalILCompensationByMintToken[config.MINT_TESTNET_TOKEN],
          config.MINT_TESTNET_TOKEN,
          false
        )
      }
    end

    -- Add protocol settings
    metrics.protocolSettings = {
      maxVestingDays = config.IL_MAX_VESTING_DAYS,
      maxCoveragePercentage = config.IL_MAX_COVERAGE_PERCENTAGE .. '%',
      slippageTolerance = config.SLIPPAGE_TOLERANCE .. '%',
      protocolFeePercentage = config.PROTOCOL_FEE_PERCENTAGE .. '%',
      userSharePercentage = config.USER_SHARE_PERCENTAGE .. '%'
    }

    -- Create JSON response
    local responseData
    local success, encodedData = pcall(json.encode, metrics)
    if success then
      responseData = encodedData
    else
      responseData = json.encode({
        error = 'Failed to encode full metrics',
        basic = {
          totalStakingPositions = metrics.totalStakingPositions,
          totalActiveUsers = metrics.totalActiveUsers,
          totalSupportedTokens = metrics.totalSupportedTokens
        }
      })
    end

    -- Reply with metrics information directly without treasury balance
    msg.reply({
      Action = 'Protocol-Metrics',
      Data = responseData,
      ['Total-Tokens'] = tostring(metrics.totalSupportedTokens),
      ['Total-Users'] = tostring(metrics.totalActiveUsers),
      ['Total-Positions'] = tostring(metrics.totalStakingPositions),
      ['Contract-Version'] = config.VERSION,
      ['Timestamp'] = tostring(metrics.timestamp),
      ['MINT-Token'] = config.MINT_TOKEN,
      ['MINT-Testnet-Token'] = config.MINT_TESTNET_TOKEN
    })
  end,

  getPositionsForToken = function(msg)
    local token = msg.Tags['Token']

    -- Validate token is allowed
    security.assertTokenAllowed(token)

    -- Get the corresponding AMM for this token
    local amm = security.getAmmForToken(token)

    -- Get the appropriate MINT token for this staked token
    local mintToken = config.getMintTokenForStakedToken(token)

    -- Get all staking positions for this token
    local positions = {}
    local stakingPositions = state.getStakingPositions()
    local tokenTotal = '0'

    if stakingPositions[token] then
      for user, position in pairs(stakingPositions[token]) do
        -- Only include positions with positive amounts
        if position and utils.math.isPositive(position.amount) then
          -- Format amounts for better readability
          local formattedAmount = utils.formatTokenQuantity(position.amount, token, false)
          local formattedLpTokens = utils.formatTokenQuantity(position.lpTokens, amm, true)
          local formattedMintAmount = utils.formatTokenQuantity(position.mintAmount, mintToken, false)

          -- Calculate time staked if available
          local timeStaked = ''
          if position.stakedDate then
            local elapsedSeconds = utils.timeElapsedSince(position.stakedDate)
            timeStaked = utils.formatDuration(elapsedSeconds * 1000) -- Convert to milliseconds
          end

          -- Add position to results
          positions[user] = {
            amount = position.amount,
            formattedAmount = formattedAmount,
            lpTokens = position.lpTokens,
            formattedLpTokens = formattedLpTokens,
            mintAmount = position.mintAmount,
            formattedMintAmount = formattedMintAmount,
            timeStaked = timeStaked
          }

          -- Add to total
          tokenTotal = utils.math.add(tokenTotal, position.amount)
        end
      end
    end

    -- Count users with positions
    local userCount = 0
    for _ in pairs(positions) do
      userCount = userCount + 1
    end

    -- Format the total
    local formattedTotal = utils.formatTokenQuantity(tokenTotal, token, false)

    -- Reply with all positions for this token
    msg.reply({
      Action = 'Positions-For-Token',
      Token = token,
      ['Token-Name'] = config.AllowedTokensNames[token],
      Data = json.encode(positions),
      ['User-Count'] = tostring(userCount),
      ['Total-Staked'] = tokenTotal,
      ['Formatted-Total-Staked'] = formattedTotal,
      ['AMM'] = amm,
      ['MINT-Token'] = mintToken
    })
  end
}

-- Additional query functions that aren't exposed as handlers

-- Get detailed statistics about the contract
function query.getContractStats()
  local stats = {
    version = config.VERSION,
    isPaused = state.isPaused(),
    tokensSupported = 0,
    activeStakingPositions = 0,
    pendingOperations = 0,
    totalStakedByToken = {},
    mintTokens = {
      main = config.MINT_TOKEN,
      testnet = config.MINT_TESTNET_TOKEN
    }
  }

  -- Count supported tokens
  for token, _ in pairs(config.AllowedTokensNames) do
    stats.tokensSupported = stats.tokensSupported + 1
    stats.totalStakedByToken[token] = '0'
  end

  -- Count active staking positions and total staked amounts
  local stakingPositions = state.getStakingPositions()
  for token, users in pairs(stakingPositions) do
    for _, position in pairs(users) do
      if position and utils.math.isPositive(position.amount) then
        stats.activeStakingPositions = stats.activeStakingPositions + 1
        stats.totalStakedByToken[token] = utils.math.add(
          stats.totalStakedByToken[token] or '0',
          position.amount
        )
      end
    end
  end

  -- Count pending operations
  stats.pendingOperations = state.countPendingOperations()

  return stats
end

-- Get token information by address
function query.getTokenInfo(tokenAddress)
  if not security.isTokenAllowed(tokenAddress) then
    return nil
  end

  local mintToken = config.getMintTokenForStakedToken(tokenAddress)

  return {
    address = tokenAddress,
    name = config.AllowedTokensNames[tokenAddress],
    amm = config.TOKEN_AMM_MAPPINGS[tokenAddress],
    decimals = config.getDecimalsForToken(tokenAddress),
    mintToken = mintToken -- Add which MINT token is used for this token
  }
end

-- Get all staking positions for a token
function query.getTokenStakingPositions(token)
  if not security.isTokenAllowed(token) then
    return nil
  end

  local positions = {}
  local stakingPositions = state.getStakingPositions()

  if stakingPositions[token] then
    for user, position in pairs(stakingPositions[token]) do
      if utils.math.isPositive(position.amount) then
        positions[user] = position
      end
    end
  end

  return positions
end

-- Get total staked amount for a token
function query.getTotalStakedForToken(token)
  if not security.isTokenAllowed(token) then
    return '0'
  end

  local total = '0'
  local stakingPositions = state.getStakingPositions()

  if stakingPositions[token] then
    for _, position in pairs(stakingPositions[token]) do
      if position and position.amount then
        total = utils.math.add(total, position.amount)
      end
    end
  end

  return total
end

-- Get pending operations by type
function query.getPendingOperationsByType(operationType)
  local results = {}
  local operations = state.getPendingOperations()

  for id, operation in pairs(operations) do
    if operation.type == operationType and operation.status == 'pending' then
      results[id] = operation
    end
  end

  return results
end

return query
