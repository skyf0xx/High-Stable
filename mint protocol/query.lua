-- Single-Sided Staking Contract - Query Module
-- Handles all read-only query operations for retrieving contract state

local config = require('config')
local state = require('state')
local utils = require('utils')
local security = require('security')
local json = require('json')

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
  end
}

-- Handler implementations for query operations
query.handlers = {
  -- Handler for getting a specific staking position
  getPosition = function(msg)
    local token = msg.Tags['Token']
    local user = msg.Tags['User'] or msg.From

    -- Validate token is allowed
    security.assertTokenAllowed(token)

    -- Verify user has permission to access the requested position
    security.assertUserCanAccessPosition(user, msg.From)

    -- Get the corresponding AMM for this token
    local amm = security.getAmmForToken(token)

    -- Get position or return default values if it doesn't exist
    local position = state.getStakingPosition(token, user) or {
      amount = '0',
      lpTokens = '0',
      mintAmount = '0'
    }

    -- Calculate time staked if available
    local timeStaked = ''
    if position.stakedDate then
      local elapsedSeconds = utils.timeElapsedSince(position.stakedDate)
      timeStaked = utils.formatDuration(elapsedSeconds)
    end

    -- Format amounts for better readability
    local formattedAmount = utils.formatTokenQuantity(position.amount)
    local formattedLpTokens = utils.formatTokenQuantity(position.lpTokens)

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
      ['Time-Staked'] = timeStaked,
      ['AMM'] = amm
    })
  end,

  -- Handler for getting all positions for a user
  getAllPositions = function(msg)
    local user = msg.Tags['User'] or msg.From

    -- Verify user has permission to access the requested positions
    security.assertUserCanAccessPosition(user, msg.From)

    local positions = {}

    -- Gather all staking positions for the user across all tokens
    for token, tokenName in pairs(config.AllowedTokensNames) do
      local amm = security.getAmmForToken(token)
      local position = state.getStakingPosition(token, user)

      if position and utils.math.isPositive(position.amount) then
        -- Calculate time staked if available
        local timeStaked = ''
        if position.stakedDate then
          local elapsedSeconds = utils.timeElapsedSince(position.stakedDate)
          timeStaked = utils.formatDuration(elapsedSeconds)
        end

        -- Format amounts for better readability
        local formattedAmount = utils.formatTokenQuantity(position.amount)
        local formattedLpTokens = utils.formatTokenQuantity(position.lpTokens)

        -- Add position to results
        positions[token] = {
          name = tokenName,
          amount = position.amount,
          formattedAmount = formattedAmount,
          lpTokens = position.lpTokens,
          formattedLpTokens = formattedLpTokens,
          mintAmount = position.mintAmount,
          timeStaked = timeStaked,
          amm = amm
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
      table.insert(allowedTokens, {
        address = token,
        name = name,
        amm = config.TOKEN_AMM_MAPPINGS[token]
      })
    end

    -- Reply with allowed tokens information
    msg.reply({
      Action = 'Allowed-Tokens',
      Data = json.encode(allowedTokens),
      Count = tostring(#allowedTokens)
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
    totalStakedByToken = {}
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

  return {
    address = tokenAddress,
    name = config.AllowedTokensNames[tokenAddress],
    amm = config.TOKEN_AMM_MAPPINGS[tokenAddress]
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
