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

--[[
     Get most recent candle information for HST
   ]]
--
Handlers.add('get-candles', Handlers.utils.hasMatchingTag('Action', 'Cron'), function(msg)
  ao.send({
    Target = _DEXI,
    Action = 'Get-Candles',
    ['Days'] = '4',
    ['Interval'] = '1d',
    ['AMM'] = _AMM
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
