--[[
  This module gets the highest low and acts on the monetary policy for HST
]]
--

---@type number
HighestLow = HighestLow or 0


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
