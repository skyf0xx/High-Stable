STAKER = 'KbUW8wkZmiEWeUG0-K8ohSO82TfTUdz6Lqu5nxDoQDc'

local function isCron(msg)
  return msg.Action == 'Cron' and (msg.From == ao.env.Process.Owner or msg.From == ao.id)
end

Handlers.add('request-token-mints', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    assert(isCron(msg), 'message is not from a trusted process')

    -- Send mint requests to token contract
    Send({
      Target = STAKER,
      Action = 'Request-Token-Mints',
      Data = 'Run Cron'
    })
  end)
