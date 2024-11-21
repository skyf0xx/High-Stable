local bint = require('.bint')(256)
local ao = require('ao')
local json = require('json')

local _DEXIExchange = 'jao0bfwk99iME8aK_TJLjm8H0bwaHzNuVbKRE1jArRo'
local _AMMPool = '2bKo3vwB1Mo5TItmxuUQzZ11JgKauU_n2IZO1G13AIk'
local _MithrilProcess = '4CaeyAuNb7kRLiJBv6ij4uYmb5cHiu6r8lUUa9L7jxs'

--[[
  This module gets the highest low and acts on the monetary policy for MTH
]]
--

---@type number
HighestLow = HighestLow or 0

---@type number
CurrentSupply = CurrentSupply or 0

---@type number
DaysToCorrect = DaysToCorrect or 7; -- number of days to distribute correction over

--[[
     Add handlers to manaage monetary policy
   ]]
--


--[[
     Get most recent candle information for MTH
   ]]
--
Handlers.add('cron', Handlers.utils.hasMatchingTag('Action', 'Cron'), function(msg)
  ao.send({
    Target = _DEXIExchange,
    Action = 'Get-Candles',
    ['Days'] = '4',
    ['Interval'] = '1d',
    ['AMM'] = _AMMPool
  })
end)


--[[
     Process Candles to get the highest low
   ]]
--
Handlers.add('process-candles',
  Handlers.utils.hasMatchingTag('App-Name', 'Dexi') and Handlers.utils.hasMatchingTag('Payload', 'Candles'),
  function(msg)
    assert(msg.From == _DEXIExchange, 'Message originator is not trusted')
    assert(msg.Tags['AMM'] == _AMMPool, 'This AMM is not monitored')

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
      Target = _DEXIExchange,
      Action = 'Get-Stats',
      ['AMM'] = _AMMPool
    })
  end)


--[[
     Process the current stats (price)
   ]]
--
Handlers.add('process-stats',
  Handlers.utils.hasMatchingTag('App-Name', 'Dexi') and Handlers.utils.hasMatchingTag('Payload', 'Stats'),
  function(msg)
    assert(msg.From == _DEXIExchange, 'Message originator is not trusted')
    assert(msg.Tags['AMM'] == _AMMPool, 'This AMM is not monitored')

    local price = tonumber(msg.Tags['Latest-Price'])

    assert(price ~= nil, 'Invalid price: ' .. tostring(price))
    assert(price > 0, 'Price must be greater than zero')

    if (price < HighestLow) then
      UpdatePolicy(price)
    end
  end
)


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

--[[
     Update the monetary policy (current supply)
   ]]
--

---@param currentPrice number
function UpdatePolicy(currentPrice)
  local percentDelta = (HighestLow - currentPrice) / HighestLow
  local dailyCorrection = percentDelta / DaysToCorrect

  local newSupply = bint(math.floor((CurrentSupply * (1 - dailyCorrection))))
  if (newSupply > 0) then
    CurrentSupply = newSupply
    ao.send({
      Target = _MithrilProcess,
      Action = 'Rebase',
      ['NewSupply'] = tostring(newSupply)
    })
  end
end
