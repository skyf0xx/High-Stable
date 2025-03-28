-- return a string of 'true' or 'false'
Handlers.add('check-maintenance',
  Handlers.utils.hasMatchingTag('Action', 'Check-Maintenance'),
  function(msg)
    msg.reply({
      Data = 'true'
    })
  end
)
