local json = require('json')
local bint = require('.bint')(256)

-- The token contract that will be used for transfers
local TOKEN_CONTRACT = 'SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0'

--NOTE AIRDROP DATA is integers only (take care of the denomination)
local airdropData = {
  ['V4XAxkILMSopedTbzS9aG7PUBESljte11vebh45Ccyo'] = '55000000000',
  ['kyKvqAVtJH_DNGItB-sHh340xrwqZN3AWYp06pkU3hk'] = '55000000000',
  ['p-5qokt5zCED2mhVlpls_FNMs_Dvbf2E5CKCkHoO2pE'] = '55000000000',
  ['9YcwODxcwVKMLM2_PtrMuTMOACbv3iq0vU4-z0Na9rg'] = '55000000000',
  ['ZEJr2SQX0HRCagAZFMR1wSAFiFLsjIRFDqy0LTZIpBM'] = '55000000000',
  ['3-y5Td8hzGjPjOvkfCaLv4_kt334HZepIJUhr8o_qwc'] = '55000000000',
  ['XC6zWTdCbqw61EFDuCiOnb-vktZiVhzsgbazuW-laxA'] = '55000000000',
  ['waswj7EEzSHq52LEi4_euE3LBB-T3qZvHI9qmUIkg4c'] = '55000000000',
  ['pQV-MRGDsyi39lCkOSfz3IeWgEZ9mfxZhYqmI5GqAQE'] = '55000000000',
  ['MutMHd24HmwBFqqCQ4sF5UDj-6Rn6ETMFQ1_bb7Rmtc'] = '55000000000',
  ['5-NafxrUmiL9cAMRdPIJs83QrNPOfwU-5DOcR7I-J_Y'] = '55000000000',
  ['PAKVfzNyODAEMsVBRtCWYibThVPr7OLv-R-h5AA6eGM'] = '55000000000',
  ['jsj4RhU2OEpyenNTxdZdr7n9i25ct11CBP5BMZc8Ovs'] = '55000000000',
  ['KgsegjwDjIkQ7na0oXTLrHUzxC7ppcDH7hzuVzoH7sE'] = '55000000000',
  ['Lz-bry6sG9p9EGcotPOt7JeKjDhe-P91RVddc03McCA'] = '55000000000',
  ['PKLNYHbnlcnYkFATv5k3IyZCFgC0aVSX6Ay1CYCsiTw'] = '55000000000',
  ['0cQJ5Hd4oCaL57CWP-Pqe5_e0D4_ZDWuxKBgR9ke1SI'] = '55000000000',
  ['R0dcdDCD5ETuKf1N6FIHAOq6qHHK_3YvBzvZfiZ1xa0'] = '55000000000',
  ['WXkrmgVl4TxARXf-DyEcVWLnvZRToGXda4SGHlhvu2I'] = '55000000000',
  ['dUqCbSIdkxxSuIhq8ohcQMwI-oq-CPX1Ey6qUnam0jc'] = '55000000000',
  ['3dTBoAtr9RA0DhNihHvcbInbsMO9nKscXyXarQ82uEM'] = '55000000000',
  ['8KJ4bsDsE8lWSCWlIBC9FF1t7l-21zQoU9ZIcofRek0'] = '55000000000',
  ['4wTrDqno0Wak1Y_qz_GURN7YtHEMhYWwTaN9KJ0eoxE'] = '55000000000',
  ['rZFGt-lp4CqKCzZ1pluR5PqLBw5-tgellSJHjcae1Lc'] = '55000000000',
  ['YMMU4U8YGp7T8bBwB97OYK5AXs_2LzaLaI4O-i69Fbc'] = '55000000000',
  ['ul1DUSv7nJ7m5bqXfYS_JK-AwrsNNY3mVzXykuQ9ASQ'] = '55000000000',
  ['Y6OiqyTH-KogzEyG3eO44UXvrifjmYbbs-14mJQLqto'] = '55000000000',
  ['WWRshZYp-kQqbfTWsE3JyPDWJ4tX58hRZ2NOYEYlpok'] = '55000000000',
  ['IuyxtOajv7t6COlbrPmRLLxkW1Z5NCAol-hn30xefaA'] = '55000000000',
  ['ty5YtynhdixPERscueTiOl1KA4Y69HNrAaJ2H_2sBh8'] = '55000000000',
  ['n6iggmgLb5kaIPxEQNCPnzer9qG9e0U7fgcAOfF55zk'] = '55000000000',
  ['EInZjXtQ5-ivzBr2EOxyxXcumQCNPPu6e85a6FtQk7Y'] = '55000000000',
  ['SZO5P5L0Eq1zErSk2O3Zxbt8Oamcj7bCaexunDissEg'] = '55000000000',
  ['NG_ugGn1fwmO9r_bWVxcmdTL0d9BozaBHsW_7iv-Wkw'] = '55000000000',
  ['pm-gkC607yGg5L-ip8ZPApfntJhUg6K8rqfxyL-x32M'] = '55000000000',
  ['O94QpUJ4oZ8gXlAJMV_xcigO9VyD3Kgf_wI7hTo6SGM'] = '55000000000',
  ['atkI1E32mchuz_nl9kgcDntECH0BOuHJ1FBgCvlcH5E'] = '55000000000',
  ['KlJUM2TsHgUI1Ih-OsorF-UpxND21amAEltukFvotTo'] = '55000000000',
  ['nH0c-gDj_Q01Y7NOgJ5SD8RkTpAMLeWCt-O5a6K0Cv0'] = '55000000000',
  ['hIWyqevBhAbRw02-yBKvHRW731e6__jL2e4mWY65baw'] = '55000000000',
  ['KdhznWri1ouFfYr2ZsQwonFJFOwe_P6QQkJpOQmBaHM'] = '55000000000',
  ['7pZ31pDkI4TBa4FLNTicgj5WSjVhbXbRUgVLrBlRV9M'] = '55000000000',
  ['S0htFhYW3M-oXc_Thb94MQhPBVBFmI4LSxeFgLiVDQE'] = '55000000000',
  ['E-sf_jW398agCto6qOVaxe1vKF46_bO9a1MGFERxkbc'] = '55000000000',
  ['PEnx-heEuwsuDtJW3CFDIhgO30zYeJyeCPm7TUNovLI'] = '55000000000',
  ['_qG9k0ZXzEkxseihL2uq02ZgQaqwtiKjcYiyyVA45uA'] = '55000000000',
  ['ePxTeygYHCMaflPAPUh34plQMxRvcJwEKcZ4t5X4_04'] = '55000000000',
  ['YlprxxUDtRCP2Ewfn5qEOQ0j1w_qLc9R6V6TnZ9HNSU'] = '55000000000',
  ['Ya-QT0DI-LyYQCwyAryJiHnTO99iKR5Tw7SxJ9RtNkI'] = '55000000000',
  ['M9DBgQmRZXWu7YRR4kmd1CJPFhFTwjP7G3DQBWJVYhs'] = '55000000000',
  ['Va9PVPy3MxAvQfPVWr0mc5X93uqkAwifoEf4IXODrVM'] = '55000000000',
  ['4IvQcfhZV2wKQcTlkxKG0mdoUUGoOweDy5zLG8WnJGg'] = '55000000000',
  ['eaHYC1BDClNB6jN9QCRVEjSyQ9OEZKmLSqS9fhfd4lw'] = '55000000000',
  ['Vrw7RTsqc8uHsLxfSvn4UI6HyM7gypnkiHjcjG8Mhew'] = '55000000000',
  ['LYVsmlFESEHL1m2nW0VRLIw9bc7EtJnVjCzgpIOu_2A'] = '55000000000',
  ['8pQIvX_ZSZy7BCfKN6aGcj8U3tnML-aTamRz8-E82EE'] = '55000000000',
  ['owtIzn4iCZe2Gzh2qY5hybs5DIo_qKV0KKyL9Y3o-44'] = '55000000000',
  ['3jlxOwsP38RL6jFhlljndDXj8xndZc-KzVd1P99AtCk'] = '55000000000',
  ['1yI5WyBmavLgqMxBqtMYC2D4wnslYeg1xI2F03xhSpc'] = '55000000000',
  ['SJppYWZeJpEGQ5s7oQrHCI9RbS7yCYxGxamd6VPUMjk'] = '55000000000',
  ['4bEAeTXOqZJpoNndlBBm5D-vGKnnnqHiJIAYq5SfYzk'] = '55000000000',
  ['ScEtph9-vfY7lgqlUWwUwOmm99ySeZGQhOX0MFAyFEs'] = '55000000000',
  ['ec-TRJdOlLN3DC7GzybRyjZKqa7L7YE6DyZXcLLyHuU'] = '55000000000',
  ['ebdMi9ECe0EB4TBBuFH7VF0-d9AjLE9hyTw5HMMZfcA'] = '55000000000',
  ['Hq0haLNws78n6LdILJkTKPIKnJ1EyLPnf1wZK3STaZA'] = '55000000000',
  ['qD5VLaMYyIHlT6vH59TgYIs6g3EFlVjlPqljo6kqVxk'] = '55000000000',
  ['n8Rr5t13j6jtDRsjTPe41GIVxG6eg1VCQOSj6vSdLWM'] = '55000000000',
  ['rH69dRyuzKqkMnV9F0ywIA8JrU33oHl3c7ANqVgUEcc'] = '55000000000',
  ['Mp-Jk-qtNr3XwA_o-n237JkxJupffJhCWtfe42UX3Qs'] = '55000000000',
  ['tHgWgF13yNHJGdaNidiaqkcLFCE-lpSuxz_3lUxKRHI'] = '55000000000',
  ['bNO3z9QeMHGr6KS1R-uJ100U4jHQjTeoePwbr7MAyMA'] = '55000000000',
  ['Bn0kIG1KVfWa_OpuVy-5OhhUXr_LefMcT2QVyKvjImI'] = '55000000000',
  ['IO_UeHQVpcRi636sRYP5GH7xFzekqsKB0PAATD5Gies'] = '55000000000',
  ['1WIZT9EL15vN4CoE9bEOHs0wlNR7VPS5h8EBxJOKEJE'] = '55000000000',
  ['e8KzxfVKibmgE8Odz5H0PP3ONPavc2Jt8WE7kX3_YcQ'] = '55000000000',
  ['kc6JoLCTm6egZvBTbhdaEcLVB6wZZFtbRbrpleeKvEg'] = '55000000000',
  ['K7VQkU6YWkzTXFM3ocAnVJGpg9olFIRyFYdhfzquNF4'] = '55000000000',
  ['27bLe7eelGad6QxrfMovyNdxovQRTYJ_Qmic0_TsffQ'] = '55000000000',
  ['NObz9Xt-7yBnn-11Uo7VuVt7nxEcmxvAZAq1pbIF_38'] = '55000000000',
  ['ME3UsUZ8oVTfwPj59-V7BhcSSrzX-1fhIBnNhtKRFWE'] = '55000000000',
  ['LXxeW7s2Z7ISWqSSDiz_QOOr7cLyYQup0nOYyVYk0jU'] = '55000000000',
  ['N90q65iT59dCo01-gtZRUlLMX0w6_ylFHv2uHaSUFNk'] = '55000000000',
  ['_s0OHX6K7XAA1lKuZkNp6rrm-wHpWY6da4swILL69a8'] = '55000000000',
  ['0xbvOzY0vgX0uj1HgOSw3lvD3POnOF38d9Ij9lZ7Eq8'] = '55000000000',
  ['4KcyhEoC96h9WQIorGog8QJvfzPBPjcMOAgpRqQQKL8'] = '55000000000',
  ['JbNSwhrtcxrpy9NbzMBUYoQChFbRd0BsASf--yebQ5Y'] = '55000000000',
  ['RTNoP5CkbQqjVEuuC9p08WnIsa1nKJH2lYvxOZj5MSU'] = '55000000000',
  ['3wIO-CawjYirR6N4bIgqNm-rA4TmYObJK0VUoLhxzZQ'] = '55000000000',
  ['BaNVhZoSVna0uE_wqV1_wnaO7dwEO9Br1f6Ccc5N_lM'] = '55000000000',
  ['CPkTc_4pEBXQ4jT4Npjc373tGDbb2U7zf-OGz9IPz2A'] = '55000000000',
  ['j36ZMY1DPYMZk-O7qHeUTAGK8DYpFBKKMf_5XA-XCEU'] = '55000000000',
  ['JYpttGaAMYSlNQuIT36shT03y4hNekbluy1aWGKbDi8'] = '55000000000',
  ['pYh2YVJdqptUwOS4KGHeFYNKZrYUOVNCGrcAJ8XXCtw'] = '55000000000',
  ['XezqlWDceGXTTcdtS7B0J__UqDWhYKXo1xVftEywuSE'] = '55000000000',
  ['mb7ZAIdT8Qvj93-998D0CB6NGjB7W1K1swWyu9T3eCg'] = '55000000000',
  ['oys9hS8ku0nGf6juKCj4XaDbs-WjoJM9JkbCwg05k0g'] = '55000000000',
  ['yEW0-7QtnJJJtOUOtyboU5H9gR0Q02pIQMiENhz5BOs'] = '55000000000',
  ['BfJCvBjP2MzWgo9ZaK_m2MUU0hcwGwhasirxtXRhckM'] = '55000000000',
  ['1wdb2k0RYBTisTdRvCLNpnReLgfq2H0XFjNhgxRmZo0'] = '55000000000',
  ['twC5ykYK68fbfCjT9qWYpZX3_ev6XsQ0kCtnIhsItfo'] = '55000000000',
  ['eSRbMNB_wkZiiVeu2Axw5OC9AnRV-zU-vj_WDPbX-JY'] = '55000000000',
  ['_izWq_r55uJyHnWi-GZJUnU6BZBf3UHBnwWt26ReLzM'] = '55000000000',
  ['iQuZaChdbWyqpuUUodkMuwOunuqldCAsh4Nbq6txQCk'] = '55000000000',
  ['4i_qBK2YUgFELXGcDhpq-zQyZOKxOcHiRVVnj3_OWBg'] = '55000000000',
  ['DZbalw2LOY5I1gQfYwv73RTuv-8igiu3KZUkSc3bEH0'] = '55000000000',
  ['35H1BWdkxUF6qPS9o8CJjx4Tk_dONvAbwy7RceHcBdc'] = '55000000000',
  ['Zwh1vYmwfbESP9-rXVXiNS8Ix0MEsUw5GSiObwkVEDE'] = '55000000000',
  ['z7bBs7YKX86ZOVznLAvP9sfgwRnrjgy5HqlLzLISKww'] = '55000000000',
  ['qGjMngUJsOOVVlYBdU2ZugwUIq6ELURSJ_2L2pmqCEU'] = '55000000000',
  ['ZbbJIHw5aTw_tRk53Ky8bwKrQ3CJvKPv7PtEN1lTCAA'] = '55000000000',
  ['WvGQmZYSYU77gv8qFPZIQsPnzkmsjaRoQ8S1x8fTh4M'] = '55000000000',
  ['r9p1UKv3uzfH8KEYABgKXJFvgdS2oFgdxdt8rIFDw7o'] = '55000000000',
  ['pWobDn83FZmTX-eVbRZkKGXXrF936gKNsKuW2zR0y8o'] = '55000000000',
  ['-RlCrWmyn9OaJ86tsr5qhmFRc0h5ovT5xjKQwySGZy0'] = '55000000000',
  ['aeCoT9AtnlJJFMZKDH4RT3lk_K30Y_h5UHVAbfFLYR8'] = '55000000000',
  ['vO-uObAX-AniXMUqrJuQ50M8USnRoEp1PQQbAQBJ-kg'] = '55000000000',
  ['27vY67xnvkJbrCh9_ebFZqqO7R-5DcbUDD8p565uVLI'] = '55000000000',
  ['JZNmYFKqDPOG59qr03wP4lGhyrQQQyGXDslXb7qgWqI'] = '55000000000',
  ['92xDPClNW3M7pKULx0upJ2EUI1pBiOzYY_K2imUd_Bs'] = '55000000000',
  ['imBDcFoKtFqzNk5adStZQsnxo5yHuLFcgDBTeYZai34'] = '55000000000',
  ['dCuh9nEInM0vrdGCjVC2bFngVYL-vqqakciXSQotR34'] = '55000000000',
  ['XwO2tGSO_NLvTaUHycLAeTb-wbO0s1T6eKsLkxGeZkA'] = '55000000000',
  ['SiIO6u2gow2AXXNNe9ZltI2AnOF75ywKW8GtVzvr3V0'] = '55000000000',
  ['1y10SpE-VbBEfT8tIgk2qKrljQ8crnzsPTQwaKQ5VxY'] = '55000000000',
  ['96tpY09SKzG8ksBvNsSOW0mc3I3y2rH4PeJai5Mlds0'] = '55000000000',
  ['i--ddrLayaMYzC3GYVEBLBJdc06fuG6Su2463jJS6Rs'] = '55000000000',
  ['dDBv2vd6GJmi47ma4jOV37IfuvvxsXihuyLvm2e6gsE'] = '55000000000',
  ['9U_MDLfzf-sdww7d7ydaApDiQz3nyHJ4kTS2-9K4AGA'] = '55000000000',
  ['A_9Hc-3xbzxGVjuotO14_2eqtW7QKMoSIHyAQBb6SVs'] = '55000000000',
  ['fr24DFR_Lg6Ff5ue0NFLOqtUH1gGrrPGkKRKxbeuSK8'] = '55000000000',
  ['bC2rCZdlm_oA7M75H7_G4yyL1u92884CP_HVZBMos_8'] = '55000000000',
  ['HPYLYDh7G-PiQFfeHJ61Dn86HMRwP62t4DPf2Yl8RJA'] = '55000000000',
  ['8LrfiR9mKCsoNNM6cyOJNpQAZXFLUSUKCK4zy4vo2lg'] = '55000000000',
  ['bTMpUcWbZ5veIo8vRFbLug3dFW0YIxJichZ_Epr5K5g'] = '55000000000'
}


-- Helper function to validate address format
local function isValidAddress(address)
  -- Basic validation - check if it's a string and matches expected length
  return type(address) == 'string' and #address == 43
end

-- Helper function to validate amount
local function isValidAmount(amount)
  -- Check if amount can be converted to bint and is greater than 0
  local success = pcall(function()
    return bint(amount) > bint.zero()
  end)
  return success
end

-- Helper function to count table elements
local function countRecipients(data)
  local count = 0
  for _ in pairs(data) do
    count = count + 1
  end
  return count
end

-- Helper function to calculate total airdrop amount
local function calculateTotalAirdrop()
  local total = bint.zero()

  for _, amount in pairs(airdropData) do
    -- Add each amount to total
    total = total + bint(amount)
  end

  return total
end


-- Helper function to process single airdrop
local function processSingleAirdrop(address, amount)
  -- Validate address and amount
  if not isValidAddress(address) then
    return {
      success = false,
      error = 'Invalid address format',
      address = address
    }
  end

  if not isValidAmount(amount) then
    return {
      success = false,
      error = 'Invalid amount',
      address = address
    }
  end

  -- Send transfer request to token contract
  Send({
    Target = TOKEN_CONTRACT,
    Action = 'Transfer',
    Recipient = address,
    Quantity = tostring(amount),
    ['X-Purpose'] = 'MINT Airdrop for LP Survey'
  })

  return {
    success = true,
    address = address,
    amount = amount
  }
end

-- Handler to get total airdrop amount
Handlers.add('get-airdrop-total',
  Handlers.utils.hasMatchingTag('Action', 'Get-Airdrop-Total'),
  function(msg)
    -- Only owner can request totals
    assert(msg.From == ao.id, 'Only owner can request airdrop totals')

    local total = calculateTotalAirdrop()
    local recipients = countRecipients(airdropData)
    local denomination = 8
    msg.reply({
      Action = 'Airdrop-Total',
      Data = tostring(total),
      Details = json.encode({
        totalAmount = tostring(total),
        totalNormalized = tostring(total / 10 ^ denomination),
        recipientCount = recipients
      })
    })
  end
)

-- Handler for airdrop execution
Handlers.add('execute-airdrop',
  Handlers.utils.hasMatchingTag('Action', 'Execute-Airdrop'),
  function(msg)
    -- Only owner can execute airdrops
    assert(msg.From == ao.id, 'Only owner can execute airdrops')

    -- Parse the airdrop data

    assert(type(airdropData) == 'table', 'Invalid airdrop data format')

    -- Generate unique airdrop ID for tracking purposes
    local airdropId = os.time() .. '-' .. msg.From

    -- Process each airdrop
    local results = {
      successful = {},
      failed = {}
    }

    for address, amount in pairs(airdropData) do
      local result = processSingleAirdrop(address, amount)
      if result.success then
        table.insert(results.successful, result)
      else
        table.insert(results.failed, result)
      end
    end

    -- Send response with results
    msg.reply({
      Action = 'Airdrop-Results',
      ['Airdrop-ID'] = airdropId,
      Data = json.encode({
        airdropId = airdropId,
        totalProcessed = #results.successful + #results.failed,
        successful = #results.successful,
        failed = #results.failed,
        results = results
      })
    })
  end
)
