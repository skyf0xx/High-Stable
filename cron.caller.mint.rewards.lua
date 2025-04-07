REWARDS = 'lNtrei6YLQiWS8cyFFHDrOBvRzICQPTvrjZBP8fz-ZI'

local function isCron(msg)
  return msg.Action == 'Cron' and (msg.From == ao.env.Process.Owner or msg.From == ao.id)
end

Handlers.add('reward-stakers', Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function(msg)
    assert(isCron(msg), 'message is not from a trusted process')

    -- Send mint requests to token contract
    Send({
      Target = REWARDS,
      Action = 'Request-Rewards',
      Data = 'Run Cron'
    })
  end)
