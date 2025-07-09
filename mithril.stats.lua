local sqlite3 = require('lsqlite3')
local json = require('json')
local ao = require('ao')

-- Constants for interacting with other processes
local STAKE_MINT_PROCESS = 'KbUW8wkZmiEWeUG0-K8ohSO82TfTUdz6Lqu5nxDoQDc'
local TOKEN_OWNER = 'OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'
local PRICE_TARGET = 'bxpz3u2USXv8Ictxb0aso3l8V9UTimaiGp9henzDsl8'

local TOKEN_DENOMINATION = 8
local PRICE_DENOMINATION = 6

local TRUSTED_CRON = 'iAEDZ6Y_wpEcksEzypVYhI01ShQIHCIvwEQ7NA3-2KA'

-- Helper function to convert for calculations and return string
local function convertTokenAmount(amount)
  local value = tonumber(amount) / (10 ^ TOKEN_DENOMINATION)
  return tostring(value)
end

-- Helper function to convert price for calculations and return string
local function convertPriceAmount(amount)
  local value = tonumber(amount) / (10 ^ PRICE_DENOMINATION)
  return tostring(value)
end

-- Helper function to calculate market cap and return string
local function calculateMarketCap(supply, price)
  local supplyValue = tonumber(supply) / (10 ^ TOKEN_DENOMINATION)
  local priceValue = tonumber(price) / (10 ^ PRICE_DENOMINATION)
  return tostring(supplyValue * priceValue)
end

-- Initialize database
DB = DB or sqlite3.open_memory()

-- Initialize database tables
Handlers.once(
  'delegator-dbsetup',
  { Action = 'Delegator-DBSetup' },
  function(msg)
    -- Create token stakes table
    local response = DB:exec [[
    CREATE TABLE IF NOT EXISTS delegator_stats (
        total_ao_earned TEXT NOT NULL,
        total_delegators INTEGER NOT NULL,
        last_updated INTEGER NOT NULL
    );
  ]]

    msg.reply({
      Action = 'Delegator-DBSetup-Complete',
      Data = json.encode({
        ecosystem_response = response,
      })
    })
  end
)

Handlers.once(
  'dbsetup',
  { Action = 'DBSetup' },
  function(msg)
    -- Create ecosystem metrics table
    local ecosystem_response = DB:exec [[
      CREATE TABLE ecosystem_metrics (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER NOT NULL,
          total_supply TEXT NOT NULL,
          price TEXT NOT NULL,
          floor_price TEXT NOT NULL,
          market_cap TEXT NOT NULL,
          unique_stakers INTEGER NOT NULL,
          daily_mint_rate TEXT NOT NULL
      );
      CREATE INDEX idx_ecosystem_timestamp ON ecosystem_metrics(timestamp);
    ]]

    -- Create token stakes table
    local stakes_response = DB:exec [[
      CREATE TABLE token_stakes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER NOT NULL,
          token_address TEXT NOT NULL,
          token_name TEXT NOT NULL,
          total_staked TEXT NOT NULL,
          num_stakers INTEGER NOT NULL
      );
      CREATE INDEX idx_stakes_timestamp ON token_stakes(timestamp);
    ]]

    msg.reply({
      Action = 'DBSetup-Complete',
      Data = json.encode({
        ecosystem_response = ecosystem_response,
        stakes_response = stakes_response
      })
    })
  end
)

-- Truncate tables handler
Handlers.add('reset',
  Handlers.utils.hasMatchingTag('Action', 'Reset'),
  function(msg)
    assert(msg.From == ao.id, 'This needs to be from a trusted process')

    -- Check if specific table is requested
    local success = true
    local error_msg = nil

    local response1 = DB:exec('DELETE FROM ecosystem_metrics')
    local response2 = DB:exec('DELETE FROM token_stakes')

    if response1 ~= sqlite3.OK or response2 ~= sqlite3.OK then
      success = false
      error_msg = 'Failed to truncate tables'
    end

    msg.reply({
      Success = success,
      Error = error_msg,
      Data = json.encode({
        success = success
      })
    })
  end
)

-- Helper function to insert ecosystem metrics
local function insertEcosystemMetrics(metrics)
  local stmt = DB:prepare([[
    INSERT INTO ecosystem_metrics (
      timestamp, total_supply, price, floor_price,
      market_cap, unique_stakers, daily_mint_rate
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
  ]])

  stmt:bind_values(
    metrics.timestamp,
    metrics.total_supply,
    metrics.price,
    metrics.floor_price,
    metrics.market_cap,
    metrics.unique_stakers,
    metrics.daily_mint_rate
  )

  stmt:step()
  stmt:finalize()
end

-- Helper function to insert token stakes
local function insertTokenStakes(stakes)
  local stmt = DB:prepare([[
    INSERT INTO token_stakes (
      timestamp, token_address, token_name,
      total_staked, num_stakers
    ) VALUES (?, ?, ?, ?, ?)
  ]])

  for _, stake in ipairs(stakes) do
    stmt:bind_values(
      stake.timestamp,
      stake.address,
      stake.name,
      stake.total_staked,
      stake.num_stakers
    )
    stmt:step()
    stmt:reset()
  end

  stmt:finalize()
end

-- Collect all statistics
local function collectStatistics()
  local timestamp = os.time()
  local metrics = {
    timestamp = timestamp,
    floor_price = '0' -- Initialize with default value
  }
  -- Get total supply
  Send({
    Target = TOKEN_OWNER,
    Action = 'Total-Supply'
  }).onReply(function(totalSupplyReply)
    metrics.total_supply = convertTokenAmount(totalSupplyReply.Data)

    -- After getting supply, get price
    Send({
      Target = PRICE_TARGET,
      Action = 'Get-Price',
      Token = TOKEN_OWNER,
      Quantity = tostring(100000000) -- 1.0 tokens
    }).onReply(function(priceReply)
      metrics.price = convertPriceAmount(priceReply.Tags.Price)
      -- Calculate market cap using raw values
      metrics.market_cap = calculateMarketCap(totalSupplyReply.Data, priceReply.Tags.Price)

      -- After getting price, get unique stakers
      Send({
        Target = STAKE_MINT_PROCESS,
        Action = 'Get-Unique-Stakers'
      }).onReply(function(stakersReply)
        metrics.unique_stakers = tonumber(stakersReply.Data)

        -- After getting stakers, get daily mint rate
        Send({
          Target = STAKE_MINT_PROCESS,
          Action = 'Get-Minting-Rate'
        }).onReply(function(mintRateReply)
          metrics.daily_mint_rate = convertTokenAmount(mintRateReply.Data)

          -- After getting all metrics, insert them
          insertEcosystemMetrics(metrics)

          -- Finally, get token stakes
          Send({
            Target = STAKE_MINT_PROCESS,
            Action = 'Get-Token-Stakes'
          }).onReply(function(stakesReply)
            local stakes = json.decode(stakesReply.Data)
            -- Add timestamp to each stake record
            for _, stake in ipairs(stakes) do
              stake.timestamp = timestamp
            end
            -- Insert stakes into database

            insertTokenStakes(stakes)
          end)
        end)
      end)
    end)
  end)
end

-- Cron handler to collect statistics
Handlers.add('cron',
  Handlers.utils.hasMatchingTag('Action', 'Update-Stats'),
  function(msg)
    assert(msg.From == ao.id or msg.From == TRUSTED_CRON, 'This needs to be from a trusted process')
    collectStatistics()
  end
)

-- Get Latest Stats handler
Handlers.add('get-latest-stats',
  Handlers.utils.hasMatchingTag('Action', 'Get-Latest-Stats'),
  function(msg)
    local results = {}
    for row in DB:nrows([[
      SELECT * FROM ecosystem_metrics
      ORDER BY timestamp DESC LIMIT 1
    ]]) do
      results = row
    end

    msg.reply({
      Action = 'Latest-Stats',
      Data = json.encode(results)
    })
  end
)

-- Get Historical Stats handler
Handlers.add('get-historical-stats',
  Handlers.utils.hasMatchingTag('Action', 'Get-Historical-Stats'),
  function(msg)
    local from_time = msg.Tags.From or (os.time() - 86400000) -- Default to last 24 hours
    local to_time = msg.Tags.To or os.time()

    local results = {}
    local stmt = DB:prepare([[
      SELECT * FROM ecosystem_metrics
      WHERE timestamp BETWEEN ? AND ?
      ORDER BY timestamp ASC
    ]])

    stmt:bind_values(from_time, to_time)

    for row in stmt:nrows() do
      table.insert(results, row)
    end

    stmt:finalize()

    msg.reply({
      Action = 'Historical-Stats',
      Data = json.encode(results)
    })
  end
)

-- Get Token Breakdown handler
Handlers.add('get-token-breakdown',
  Handlers.utils.hasMatchingTag('Action', 'Get-Token-Breakdown'),
  function(msg)
    local results = {}
    for row in DB:nrows([[
      SELECT * FROM token_stakes
      WHERE timestamp = (
        SELECT MAX(timestamp) FROM token_stakes
      )
    ]]) do
      table.insert(results, row)
    end

    msg.reply({
      Action = 'Token-Breakdown',
      Data = json.encode(results)
    })
  end
)
