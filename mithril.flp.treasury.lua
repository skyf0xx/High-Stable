local bint = require('.bint')(256)

local utils = {
  add = function(a, b)
    return tostring(bint(a) + bint(b))
  end,
  subtract = function(a, b)
    return tostring(bint(a) - bint(b))
  end,
  toBalanceValue = function(a)
    return tostring(bint(a))
  end,
  toNumber = function(a)
    return tonumber(a)
  end
}

Denomination = Denomination or 8
TotalSupply = 14000000
TotalSupplyDenominated = utils.toBalanceValue(TotalSupply * 10 ^ Denomination)
NABProcess = 'OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU'
FLP_CONTRACT = 'X0HxJGSBzney-YLDzAtjt9Pc-c6N_1sf_MlqO0ezoeI'


Handlers.add('self-register-FLP',
  Handlers.utils.hasMatchingTag('Action', 'Self-Register-FLP'),
  function(msg)
    assert(msg.From == ao.id, 'Caller is not authorised')
    print('registering')
    -- Send this message to the Factory Oracle to create your FLP
    Send({
      Target = 'It-_AKlEfARBmJdbJew1nG9_hIaZt0t20wQc28mFGBE',
      Action = 'Create-FLP',

      -- Basic FLP Info
      Name = 'Number Always Bigger (NAB)',
      ['Short-Description'] = 'The ultimate deflationary experiment.',
      ['Long-Description'] =
      'NAB is the first deflationary Meme-Fi token on AO that uses *100%* of its earnings to buy back and burn itself. This creates relentless upward pressure — in bull *and* bear markets.',

      -- Token Configuration
      ['Token-Process'] = NABProcess,
      ['Token-Supply'] = TotalSupplyDenominated,
      ['Decay-Factor'] = '0.99976104',

      -- Timing
      ['Starts-At-Timestamp'] = tostring(math.max(os.time() + (24 * 60 * 60 * 5 * 1000))), -- 5 days from now

      -- Addresses
      Treasury = ao.id,
      Deployer = ao.id,

      -- Technical Settings
      ['Are-Batch-Transfers-Possible'] = 'true',

      -- Social Media
      ['Twitter-Handle'] = 'AlwaysBigger',
      ['Website-URL'] = 'https://number-always-bigger.ar.io/',
    })
  end
)


Handlers.add('supply-flp-contract',
  Handlers.utils.hasMatchingTag('Action', 'Supply-FLP-Contract'),
  function(msg)
    assert(msg.From == ao.id, 'Caller is not authorised')
    Send({
      Target = NABProcess,
      Action = 'Transfer',
      ['X-Action'] = 'Initialize-FLP',
      Recipient = FLP_CONTRACT,
      Quantity = TotalSupplyDenominated,
    }).onReply(function(reply)
      print('FLP contract supplied with initial supply')
    end)
  end
)
