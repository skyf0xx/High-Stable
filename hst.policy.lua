local ao = require('ao')
local json = require('json')

local _DEXI = 'jao0bfwk99iME8aK_TJLjm8H0bwaHzNuVbKRE1jArRo'
local _AMM = '2bKo3vwB1Mo5TItmxuUQzZ11JgKauU_n2IZO1G13AIk'

--[[
  This module gets the highest low and acts on the monetary policy for HST
]]
--

---@type number
HighestLow = HighestLow or 0

---@type number
CurrentSupply = CurrentSupply or 0


--[[
     Add handlers to manaage monetary policy
   ]]
--


--[[
     Get most recent candle information for HST
   ]]
--
Handlers.add('cron', Handlers.utils.hasMatchingTag('Action', 'Cron'), function(msg)
  ao.send({
    Target = _DEXI,
    Action = 'Get-Candles',
    ['Days'] = '4',
    ['Interval'] = '1d',
    ['AMM'] = _AMM
  })
end)


--[[
     Process Candles to get the highest low
   ]]
--
Handlers.add('process-candles',
  Handlers.utils.hasMatchingTag('App-Name', 'Dexi') and Handlers.utils.hasMatchingTag('Payload', 'Candles'),
  function(msg)
    assert(msg.From == _DEXI, 'Message originator is not trusted')
    assert(msg.Tags['AMM'] == _AMM, 'This AMM is not monitored')

    local candles = json.decode(msg.Data)

    -- Ensure that the input data structure is correct
    assert(type(candles) == 'table', 'Input must be a table')
    assert(#candles >= 3, 'Candles must have at least 3 elements')
    for _, element in ipairs(candles) do
      assert(type(element) == 'table', 'Each element must be a table')
      assert(element.low ~= nil, "Each element must have a 'low' key")
    end

    UpdateHighestLow(candles)

    -- Get the current price
    ao.send({
      Target = _DEXI,
      Action = 'Get-Stats',
      ['AMM'] = _AMM
    })
  end)
--[[
  Get policy info
]]
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
  ao.send({
    Target = msg.From,
    HighestLow = tostring(HighestLow),
    CurrentSupply = tostring(CurrentSupply)
  })
end)


--[[
  Get the highest low from the daily candles
]]
--
function UpdateHighestLow(dailyCandles)
  -- Loop through each daily candle starting from the second to the second-last
  for i = 2, #dailyCandles - 1 do
    local prevLow = dailyCandles[i - 1].low
    local curLow = dailyCandles[i].low
    local nextLow = dailyCandles[i + 1].low

    -- Check for a V-shape formation (current low is lower than both the previous and next lows)
    if curLow < prevLow and curLow < nextLow then
      -- Update the highest low if the current low is higher
      if curLow > HighestLow then
        HighestLow = curLow
      end
    end
  end
end
