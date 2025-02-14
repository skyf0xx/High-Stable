ALLOWED_TOKENS = 'G3biaSUvclo3cd_1ErpPYt-VoSSazWrKcuBlzeLkTnU'

local function isCron(msg)
  return msg.Action == 'Cron' and (msg.From == ao.env.Process.Owner or msg.From == ao.id)
end

--Updates additional
Handlers.add('allowed-tokens-secondary-actions', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    assert(isCron(msg), 'message is not from a trusted process')

    Send({
      Target = ALLOWED_TOKENS,
      Action = 'Update-LP-Denominations',
      Data = 'Run Cron'
    })

    Send({
      Target = ALLOWED_TOKENS,
      Action = 'Update-LP-Supplies',
      Data = 'Run Cron'
    })
  end)
