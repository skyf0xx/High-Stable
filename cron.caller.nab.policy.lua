POLICY = 'iWO6lWYAFWUahdCa3PJKbg_ACagDur3RR1o4mNbMkKE'

local function isCron(msg)
  return msg.Action == 'Cron' and (msg.From == ao.env.Process.Owner or msg.From == ao.id)
end

Handlers.add('update-supply', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    assert(isCron(msg), 'message is not from a trusted process')

    Send({
      Target = POLICY,
      Action = 'Run-Fiscal-Policy',
    })
  end)
