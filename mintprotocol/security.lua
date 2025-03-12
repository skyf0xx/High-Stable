-- Single-Sided Staking Contract - Security Module
-- Contains security checks and validation functions

local config = require('mintprotocol.config')
local state = require('mintprotocol.state')
local bint = require('.bint')(256)

local security = {}

-- Check if contract is paused
security.assertNotPaused = function()
  assert(not state.isPaused(), 'Contract is paused for maintenance or emergency')
end

-- Check if caller is the owner
security.assertIsAuthorized = function(caller)
  assert(caller == ao.id, 'Caller is not the contract owner')
end

-- Check if a token is allowed
security.isTokenAllowed = function(token)
  return config.AllowedTokensNames[token] ~= nil
end

-- Verify token is allowed and assert
security.assertTokenAllowed = function(token)
  assert(security.isTokenAllowed(token), 'Token is not supported for staking: ' .. token)
end

-- Check if caller is a valid token contract
security.assertIsAllowedTokenProcess = function(caller)
  assert(security.isTokenAllowed(caller), 'Sender is not an allowed token contract')
end

-- Get the AMM address for a token
security.getAmmForToken = function(token)
  local amm = config.TOKEN_AMM_MAPPINGS[token]
  assert(amm ~= nil, 'No AMM configured for token: ' .. token)
  return amm
end

-- Assert AMM is valid
security.assertIsValidAmm = function(address, expectedAmm)
  assert(address == expectedAmm or address == '3XBGLrygs11K63F_7mldWz4veNx6Llg6hI2yZs8LKHo',
    'Unauthorized: message not from expected AMM. Got: ' .. address .. ', expected: ' .. expectedAmm)
end

-- Operation status checking helper
security.verifyOperation = function(opId, expectedType, expectedStatus)
  local operations = state.getPendingOperations()
  local operation = operations[opId]
  assert(operation ~= nil, 'Operation not found: ' .. opId)
  assert(operation.type == expectedType,
    'Invalid operation type. Expected: ' .. expectedType .. ', got: ' .. operation.type)
  assert(operation.status == expectedStatus,
    'Operation in wrong state. Expected: ' .. expectedStatus .. ', got: ' .. operation.status)
  return operation
end

-- Validate token quantity is positive
security.assertPositiveQuantity = function(quantity)
  assert(bint(quantity) > bint.zero(), 'Amount must be greater than 0')
end

-- Validate staking position exists
security.assertStakingPositionExists = function(token, user)
  local position = state.getStakingPosition(token, user)
  assert(position ~= nil, 'No staking position found for this token')
end

-- Validate staking position has tokens
security.assertStakingPositionHasTokens = function(token, user)
  local position = state.getStakingPosition(token, user)
  assert(position ~= nil, 'No staking position found for this token')
  assert(bint(position.amount) > bint.zero(), 'No tokens staked in this position')
end

-- Validate operation timestamp is not too old
security.assertOperationNotTimedOut = function(operation)
  assert(operation.timestamp ~= nil, 'Operation has no timestamp')
  local elapsed = os.time() - operation.timestamp
  assert(elapsed <= config.OPERATION_TIMEOUT, 'Operation timed out (elapsed: ' .. elapsed .. 's)')
end

-- Validate message has all required tags
security.validateRequiredTags = function(msg, requiredTags)
  for _, tag in ipairs(requiredTags) do
    assert(msg.Tags[tag] ~= nil, 'Missing required tag: ' .. tag)
  end
end

-- Validate user has permissions for operation
security.assertUserCanAccessPosition = function(requestedUser, caller)
  -- Users can only access their own positions unless they're the contract owner
  if requestedUser ~= caller then
    security.assertIsAuthorized(caller)
  end
end

-- Check if an operation is ready for completion
security.isOperationReadyForCompletion = function(operation)
  return operation.status == 'pending' and not security.isOperationTimedOut(operation)
end

-- Check if an operation has timed out
security.isOperationTimedOut = function(operation)
  if not operation or not operation.timestamp then
    return false
  end

  return (os.time() - operation.timestamp) > config.OPERATION_TIMEOUT
end

-- Validate the integrity of a staking operation
security.validateStakingOperation = function(token, sender, quantity)
  security.assertNotPaused()
  security.assertTokenAllowed(token)
  security.assertPositiveQuantity(quantity)
  -- Additional validations can be added as needed
end

-- Validate the integrity of an unstaking operation
security.validateUnstakingOperation = function(token, sender)
  security.assertNotPaused()
  security.assertTokenAllowed(token)
  security.assertStakingPositionExists(token, sender)
  security.assertStakingPositionHasTokens(token, sender)
  -- Additional validations can be added as needed
end

-- Validate a burn confirmation message from AMM
security.validateBurnConfirmation = function(msg, operation)
  security.assertNotPaused()
  security.assertIsValidAmm(msg.From, operation.amm)

  -- Validate required tags for burn confirmation
  local requiredTags = {
    'Burned-Pool-Tokens',
    'Token-A',
    'Token-B'
  }
  security.validateRequiredTags(msg, requiredTags)

  return true
end

-- Log unauthorized access attempts
security.logSecurityEvent = function(eventType, details)
  local utils = require('utils')
  utils.logEvent('SecurityEvent', {
    type = eventType,
    details = details,
    timestamp = os.time()
  })
end

return security
