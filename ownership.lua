--
Handlers.add('ping', Handlers.utils.hasMatchingTag('Action', 'Ping'),
  function(msg)
    print('Ping from ' .. msg.From)
    print(Owner)
    msg.reply({ Data = 'Pong' })
  end)
