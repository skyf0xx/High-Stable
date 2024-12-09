STAKER = 'KbUW8wkZmiEWeUG0-K8ohSO82TfTUdz6Lqu5nxDoQDc'
Handlers.add('request-token-mints', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    -- Send mint requests to token contract
    Send({
      Target = STAKER,
      Action = 'Request-Token-Mints',
      Data = 'Run Cron'
    })
  end)
