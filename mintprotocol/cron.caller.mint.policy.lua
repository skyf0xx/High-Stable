POLICY = 'KBOfQGUj-K1GNwfx1CeMSZxxcj5p837d-_6hTmkWF0k'

local function isCron(msg)
  return msg.Action == 'Cron' and (msg.From == ao.env.Process.Owner or msg.From == ao.id)
end

Handlers.add('update-supply', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    assert(isCron(msg), 'message is not from a trusted process')

    -- Send mint requests to token contract
    Send({
      Target = POLICY,
      Action = 'Update-Supply',
      Data = 'Run Cron'
    })
  end)
