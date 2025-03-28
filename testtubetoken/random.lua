--------------------------------------------------------------------------------
-- RandomModule
-- Interacts with RandAO Protocol to:
--   • Retrieve and update configuration from DNS
--   • Send token transfers to request random values
--   • Receive and process random responses
--   • Manage provider list record random request status
--------------------------------------------------------------------------------
local function RandomModule(json)
  -- Create a table to hold module functions and data
  local self         = {}

  ----------------------------------------------------------------------------
  -- Default State Variables
  --   RandAODNS      : Points to the DNS record that provides random config
  --   PaymentToken   : Token to pay the Random Process with
  --   RandomCost     : Cost (token quantity) per random request
  --   RandomProcess  : Transaction ID / Process that fulfills random requests
  --   Providers      : JSON-encoded list of provider IDs for round-robin usage
  ----------------------------------------------------------------------------
  self.RandAODNS     = 'byaUfQzuojukjWPIQd9-qpGPrO9Nrlqqfib4879LyCE'
  self.PaymentToken  = '5ZR9uegKoEhE9fJMbs-MvWLIztMNCVxgpzfeBVE3vqI'
  self.RandomCost    = '100'
  self.RandomProcess = 'XAYnAxAEFhVRwhUyFKZmkeTiazIZClQIELLw6h44Ngc'
  self.Providers     =
  '{\"provider_ids\":[\"XUo8jZtUDBFLtp5okR12oLrqIZ4ewNlTpqnqmriihJE\",\"c8Iq4yunDnsJWGSz_wYwQU--O9qeODKHiRdUkQkW2p8\",\"Sr3HVH0Nh6iZzbORLpoQFOEvmsuKjXsHswSWH760KAk\"]}'

  ----------------------------------------------------------------------------
  -- initialize()
  -- Sets up a handler to listen for the "Records-Notice" action.
  -- Upon receiving new config data, it updates the module state via setConfig().
  -- Finally, it calls updateConfig() to request the current configuration from DNS.
  ----------------------------------------------------------------------------
  function self.initialize()
    print('Initializing Random Module')
    Handlers.add(
      'Records-Notice',
      Handlers.utils.hasMatchingTag('Action', 'Records-Notice'),
      function(msg)
        print('entered records')
        print(json.encode(msg.Data))
        local decodedData   = json.decode(msg.Data)

        local randomProcess = decodedData.randomprocess.transactionId
        local rngToken      = decodedData.rngtoken.transactionId

        self.setConfig(rngToken, self.RandomCost, randomProcess)
        print('RNG Token: ' .. rngToken)
        print('RNG Process: ' .. randomProcess)
      end
    )
    self.updateConfig()
  end

  ----------------------------------------------------------------------------
  -- updateConfig()
  -- Sends a request to retrieve new configuration records from the RandAODNS.
  ----------------------------------------------------------------------------
  function self.updateConfig()
    return ao.send({
      Target = self.RandAODNS,
      Action = 'Records'
    })
  end

  ----------------------------------------------------------------------------
  -- setConfig(paymentToken, randomCost, randomProcess)
  -- Dynamically updates the module's state with new configuration details.
  --
  -- Arguments:
  --   paymentToken  : The token used to pay for random generation
  --   randomCost    : The cost (in tokens) of a single random request
  --   randomProcess : The Process ID responsible for generating random values
  ----------------------------------------------------------------------------
  function self.setConfig(paymentToken, randomCost, randomProcess)
    self.PaymentToken = paymentToken
    self.RandomCost = randomCost
    self.RandomProcess = randomProcess
  end

  ----------------------------------------------------------------------------
  -- setProviderList(providerList)
  -- Updates the module's Providers field to use for random requests.
  --
  -- Arguments:
  --   providerList  : A list of provider ID strings
  ----------------------------------------------------------------------------
  function self.setProviderList(providerList)
    local providers = { provider_ids = providerList }
    self.Providers = json.encode(providers)
  end

  ----------------------------------------------------------------------------
  -- showConfig()
  -- Simple utility to log the current configuration values for debugging.
  ----------------------------------------------------------------------------
  function self.showConfig()
    print('PaymentToken: ' .. self.PaymentToken)
    print('RandomCost: ' .. self.RandomCost)
    print('RandomProcess: ' .. self.RandomProcess)
  end

  ----------------------------------------------------------------------------
  -- isRandomProcess(processId)
  -- Checks if the given process ID matches the configured RandomProcess.
  --
  -- Arguments:
  --   processId : The ID of the process to verify
  --
  -- Returns:
  --   Boolean indicating whether processId is the active RandomProcess
  ----------------------------------------------------------------------------
  function self.isRandomProcess(processId)
    return processId == self.RandomProcess
  end

  ----------------------------------------------------------------------------
  -- generateUUID()
  -- Creates a universally unique identifier (UUID) in the form of a string.
  -- Used as a callback ID when requesting random values.
  --
  -- Returns:
  --   A randomly generated UUID (string)
  ----------------------------------------------------------------------------
  function self.generateUUID()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

    return string.gsub(template, '[xy]', function(c)
      local v = (c == 'x') and random(0, 15) or random(8, 11)
      return string.format('%x', v)
    end)
  end

  ----------------------------------------------------------------------------
  -- requestRandom(callbackId)
  -- Sends a token transfer to the configured RandomProcess to request entropy,
  -- paying the specified RandomCost. Expects to receive a random response
  -- matching callbackId via a subsequent message.
  --
  -- Arguments:
  --   callbackId : Unique identifier for tracking the random request
  --
  -- Returns:
  --   The result of ao.send (typically a receipt or reference)
  ----------------------------------------------------------------------------
  function self.requestRandom(callbackId)
    local send = ao.send({
      Target = self.PaymentToken,
      Action = 'Transfer',
      Recipient = self.RandomProcess,
      Quantity = self.RandomCost,
      ['X-CallbackId'] = callbackId
    })
    return send
  end

  ----------------------------------------------------------------------------
  -- requestRandomFromProviders(callbackId)
  -- Similar to requestRandom(), but uses an explicit list of providers.
  -- This instructs the RandomProcess to only utilize specified providers
  -- for entropy generation.
  --
  -- Arguments:
  --   callbackId : Unique identifier for tracking the random request
  --
  -- Returns:
  --   The result of ao.send (receipt or reference)
  ----------------------------------------------------------------------------
  function self.requestRandomFromProviders(callbackId)
    local send = ao.send({
      Target = self.PaymentToken,
      Action = 'Transfer',
      Recipient = self.RandomProcess,
      Quantity = self.RandomCost,
      ['X-Providers'] = self.Providers,
      ['X-CallbackId'] = callbackId
    })
    return send
  end

  ----------------------------------------------------------------------------
  -- processRandomResponse(from, data)
  -- Validates the source process of the random response and extracts the
  -- callbackId and entropy from the data payload.
  --
  -- Arguments:
  --   from : The process ID from which this message arrived
  --   data : Table containing "callbackId" and "entropy"
  --
  -- Returns:
  --   callbackId (string), entropy (number)
  ----------------------------------------------------------------------------
  function self.processRandomResponse(from, data)
    assert(self.isRandomProcess(from), 'Failure: message is not from RandomProcess')

    local callbackId = data['callbackId']
    local entropy    = tonumber(data['entropy'])
    return callbackId, entropy
  end

  ----------------------------------------------------------------------------
  -- viewRandomStatus(callbackId)
  -- Queries the RandomProcess to check the status of a random request
  -- identified by callbackId, and prints the result.
  --
  -- Arguments:
  --   callbackId : Unique identifier of the random request to check
  --
  -- Returns:
  --   The status data returned by the random process
  ----------------------------------------------------------------------------
  function self.viewRandomStatus(callbackId)
    -- utilizies the receive functionality to await for a response to the query
    local results = ao.send({
      Target = self.RandomProcess,
      Action = 'Get-Random-Request-Via-Callback-Id',
      Data = callbackId
    }).receive().Data
    print('Results: ' .. tostring(results))
    return results
  end

  -- Return the table so the module can be used
  return self
end

return RandomModule
