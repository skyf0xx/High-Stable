ALLOWED_TOKENS = 'G3biaSUvclo3cd_1ErpPYt-VoSSazWrKcuBlzeLkTnU'

local function isCron(msg)
  return msg.Action == 'Cron' and (msg.From == ao.env.Process.Owner or msg.From == ao.id)
end

Handlers.add('request-token-mints', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    assert(isCron(msg), 'message is not from a trusted process')

    -- Send mint requests to token contract
    Send({
      Target = ALLOWED_TOKENS,
      Action = 'Update-Token-Weights',
      Data = 'Run Cron'
    })
  end)
