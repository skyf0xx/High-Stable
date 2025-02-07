STATS = 'dNmk7_vhghAG06yFnRjm0IrFKPQFhqlF0pU7Bk3RmkM'

local function isCron(msg)
  return msg.Action == 'Cron' and (msg.From == ao.env.Process.Owner or msg.From == ao.id)
end


Handlers.add('request-update-stats', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    assert(isCron(msg), 'message is not from a trusted process')
    -- Send mint requests to token contract
    Send({
      Target = STATS,
      Action = 'Update-Stats',
      Data = 'Run Cron'
    })
  end)
