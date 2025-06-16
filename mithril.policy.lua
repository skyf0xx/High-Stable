local bint = require('.bint')(256)
local ao = require('ao')
local json = require('json')

local _DEXIExchange = 'Meb6GwY5I9QN77F0c5Ku2GpCFxtYyG1mfJus2GWYtII'
local _AMMPool = 'NX9PKbLVIyka3KPZghnEekw9FB2dfzbzVabpY-ZN1Dg'
local TOKEN_OWNER = 'OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'
local TRUSTED_CRON = 'IZ5T94KbaukoYifGf1NpSr9-CHTZRsfBlP6-7L8f7wU'

--[[
  This module implements an automated monetary policy system for the MTH token
  that dynamically adjusts token supply based on price movements and technical analysis.
]]

-- State Variables
---@type number
HighestLow = HighestLow or 0

---@type number
CurrentSupply = CurrentSupply or 0

---@type number
DaysToCorrect = DaysToCorrect or 7 -- number of days to distribute correction over

-- Price validation state
LastValidPrice = LastValidPrice or 0
LastPriceTimestamp = LastPriceTimestamp or 0

-- Statistics
TotalRebases = TotalRebases or 0
LastRebaseTimestamp = LastRebaseTimestamp or 0

--[[
  Validate price for extreme movements and basic sanity checks
]]
function ValidatePrice(price, timestamp)
  -- Basic sanity checks
  if price <= 0 then
    print('Invalid price: ' .. tostring(price))
    return false
  end

  -- Check for extreme movements (>90% change from last valid price)
  if LastValidPrice > 0 then
    local change = math.abs(price - LastValidPrice) / LastValidPrice
    if change > 0.9 then
      print(string.format('Extreme price change detected: %.2f%%, ignoring', change * 100))
      return false
    end
  end

  LastValidPrice = price
  LastPriceTimestamp = timestamp
  return true
end

--[[
  V-shape pattern detection for identifying support levels
]]
function UpdateHighestLow(dailyCandles)
  -- Require minimum 5 days for better pattern detection
  if #dailyCandles < 5 then
    print('Insufficient candle data for analysis: ' .. #dailyCandles .. ' days')
    return
  end

  -- Loop through candles with 2-day context window on each side
  for i = 3, #dailyCandles - 2 do
    local curLow = dailyCandles[i].low
    local prevLow = dailyCandles[i - 1].low
    local nextLow = dailyCandles[i + 1].low
    local prev2Low = dailyCandles[i - 2].low
    local next2Low = dailyCandles[i + 2].low

    -- V-shape: current must be lowest among 5-day window
    if curLow < prevLow and curLow < nextLow and
      curLow < prev2Low and curLow < next2Low then
      -- Require minimum depth to avoid noise (2% minimum dip)
      local avgSurrounding = (prevLow + nextLow) / 2
      local depthPercent = (avgSurrounding - curLow) / avgSurrounding

      if depthPercent >= 0.02 and curLow > HighestLow then
        HighestLow = curLow
        print(string.format('New support level found: %.6f at index %d (%.2f%% dip)',
          curLow, i, depthPercent * 100))
        break -- Found a new higher low, exit early
      end
    end
  end
end

--[[
  Execute policy by adjusting token supply
]]
function UpdatePolicy(currentPrice)
  local percentDelta = (HighestLow - currentPrice) / HighestLow
  local dailyCorrection = percentDelta / DaysToCorrect
  -- Cap daily correction at .5%
  dailyCorrection = math.min(dailyCorrection, 0.005)
  local newSupply = CurrentSupply * bint(math.floor((1 - dailyCorrection) * 10 ^ 6)) / bint(10 ^ 6)

  -- Minimum supply change threshold (0.01%)
  local changeThreshold = CurrentSupply / bint(10000)
  local supplyChange = CurrentSupply - newSupply

  if supplyChange < changeThreshold then
    print('Supply change below threshold, skipping rebase')
    return
  end

  print(string.format('Executing rebase: %.6f -> %.6f (%.4f%% reduction)',
    tonumber(tostring(CurrentSupply)) / 1e6,
    tonumber(tostring(newSupply)) / 1e6,
    (1 - tonumber(tostring(newSupply)) / tonumber(tostring(CurrentSupply))) * 100))

  --[[ Send({
    Target = TOKEN_OWNER,
    Action = 'Rebase',
    NewSupply = tostring(newSupply)
  }).onReply(function(rebaseReply)
    CurrentSupply = newSupply
    TotalRebases = TotalRebases + 1
    LastRebaseTimestamp = rebaseReply.Timestamp or os.time() * 1000
    print('Rebase completed successfully')
  end) ]] --
end

--[[
  HANDLERS
]]

--[[
  Cron handler - starts the policy cycle by requesting current supply
]]
Handlers.add('cron', Handlers.utils.hasMatchingTag('Action', 'Run-Fiscal-Policy'), function(msg)
  print('Policy cron triggered - requesting current supply')

  assert(msg.From == ao.id or msg.From == TRUSTED_CRON, 'Message originator is not trusted')
  Send({
    Target = TOKEN_OWNER,
    Action = 'Total-Supply'
  }).onReply(function(supplyReply)
    CurrentSupply = bint(supplyReply.Data)
    print('Current supply updated: ' .. tostring(CurrentSupply))

    ao.send({
      Target = _DEXIExchange,
      Action = 'Get-Candles',
      ['Days'] = '4',
      ['Interval'] = '1d',
      ['AMM'] = _AMMPool
    })
  end)
end)


--[[
  Process candle data to update highest low support level
]]
Handlers.add('process-candles',
  Handlers.utils.hasMatchingTag('App-Name', 'Dexi') and Handlers.utils.hasMatchingTag('Payload', 'Candles'),
  function(msg)
    assert(msg.From == _DEXIExchange, 'Message originator is not trusted')
    assert(msg.Tags['AMM'] == _AMMPool, 'This AMM is not monitored')

    local candles = json.decode(msg.Data)

    -- Validate candle data structure
    assert(type(candles) == 'table', 'Input must be a table')
    assert(#candles >= 3, 'Candles must have at least 3 elements')
    for _, element in ipairs(candles) do
      assert(type(element) == 'table', 'Each element must be a table')
      assert(element.low ~= nil, "Each element must have a 'low' key")
      assert(type(element.low) == 'number', "Element 'low' must be a number")
    end

    print('Processing ' .. #candles .. ' candles for support level analysis')
    UpdateHighestLow(candles)

    ao.send({
      Target = _DEXIExchange,
      Action = 'Get-Stats',
      ['AMM'] = _AMMPool
    })
  end)

--[[
  Process current price and make policy decisions
]]
Handlers.add('process-stats',
  Handlers.utils.hasMatchingTag('App-Name', 'Dexi') and Handlers.utils.hasMatchingTag('Payload', 'Stats'),
  function(msg)
    assert(msg.From == _DEXIExchange, 'Message originator is not trusted')
    assert(msg.Tags['AMM'] == _AMMPool, 'This AMM is not monitored')

    local price = tonumber(msg.Tags['Latest-Price'])
    assert(price ~= nil, 'Invalid price: ' .. tostring(price))
    assert(price > 0, 'Price must be greater than zero')
    assert(ValidatePrice(price, msg.Timestamp), 'Price is not considered valid')



    print(string.format('Current price: %.6f, Support level: %.6f', price, HighestLow))

    -- Execute policy if price is below support level
    if price < HighestLow and HighestLow > 0 then
      print('Price below support level - executing policy')
      UpdatePolicy(price)
    else
      print('Price above support level - no action needed')
    end
  end
)

--[[
  Info handler
]]
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
  msg.reply({
    Target = msg.From,
    Action = 'Policy-Info',
    Data = json.encode({
      highest_low = HighestLow,
      current_supply = tostring(CurrentSupply),
      days_to_correct = DaysToCorrect,
      last_valid_price = LastValidPrice,
      last_price_timestamp = LastPriceTimestamp,
      total_rebases = TotalRebases,
      last_rebase_timestamp = LastRebaseTimestamp,
      amm_pool = _AMMPool,
    })
  })
end)
