STATS = 'dNmk7_vhghAG06yFnRjm0IrFKPQFhqlF0pU7Bk3RmkM'
Handlers.add('request-update-stats', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    -- Send mint requests to token contract
    Send({
      Target = STATS,
      Action = 'Update-Stats',
      Data = 'Run Cron'
    })
  end)
