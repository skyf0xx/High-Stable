ALLOWED_TOKENS = 'G3biaSUvclo3cd_1ErpPYt-VoSSazWrKcuBlzeLkTnU'
Handlers.add('request-token-mints', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    -- Send mint requests to token contract
    Send({
      Target = ALLOWED_TOKENS,
      Action = 'Update-Token-Weights',
      Data = 'Run Cron'
    })
  end)
