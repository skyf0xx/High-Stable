# Extensions for VS Code

Lua Language Server by sumneko

Startup:
`aos process-name --wallet .aos.json`

These are the current names for the processes:
NAB
mithril.lua --> "Number Always Bigger" (OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU)
mithril.policy.lua --> "NAB Policy Handler" (iWO6lWYAFWUahdCa3PJKbg_ACagDur3RR1o4mNbMkKE)
mithril.stake.mint.lua --> "NAB Stake and Mint" (KbUW8wkZmiEWeUG0-K8ohSO82TfTUdz6Lqu5nxDoQDc)
mithril.allowed.tokens.lua --> "NAB Allowed Tokens" (G3biaSUvclo3cd_1ErpPYt-VoSSazWrKcuBlzeLkTnU)
mithril.stats.lua --> "NAB Ecosystem Stats" (dNmk7_vhghAG06yFnRjm0IrFKPQFhqlF0pU7Bk3RmkM) NOTE: Uses WASM 64 sqlite first init is with --module=ghSkge2sIUD_F00ym5sEimC63BDBuBrq4b5OcwxOjiw
mithril.flp.treasury.lua --> "NAB Fair-Launch Treasury" (NSX-Z920BtJ5J_Cjrj90DJ6yuaMbAznGIVaSOcWzyyA)

CRONS
cron.caller.stakers.lua --> "NAB Staking Reward Cron" (h7nm30_3nDfMrN5TRdEC80ZIUzQl-fIWWxobwews4WE) every 5 minutes
cron.caller.stats.lua --> "Cron NAB Ecosystem Stats" (iAEDZ6Y_wpEcksEzypVYhI01ShQIHCIvwEQ7NA3-2KA) every 24 hours
cron.caller.allowed.tokens.lua --> "Cron NAB Allowed Tokens" (pn2IDtbofqxWXyj9W6eXtdp4C7JZ1oJaM81l12ygqYc) every 24 hours
cron.caller.allowed.tokens.secondary.lua --> "Cron NAB Allowed Tokens Secondary Data" (BNGGjJMLRKou_dimjmodfEeEL77CZCdRmT3Rc3yyZss) every 25 hours
cron.caller.mint.policy.lua --> "Cron MINT Policy" (fzBx5uPGi2e_dBbBvwKlh6BbrTLyVJ1YVGlFS1el0uI)
cron.caller.mint.rewards.lua --> "Cron MINT Protocol Rewards" (8hN_JEoeuEuObMPchK9FjhcvQ_8MjMM1p55D21TJ1XY)
cron.caller.nab.policy.lua --> "NAB Policy" (IZ5T94KbaukoYifGf1NpSr9-CHTZRsfBlP6-7L8f7wU)

MINT
mint.lua --> "MINT" (SWQx44W-1iMwGFBSHlC3lStCq3Z7O2WZrx9quLeZOu0)
mint.policy.lua --> "MINT Policy" (KBOfQGUj-K1GNwfx1CeMSZxxcj5p837d-_6hTmkWF0k)
mint-protocol.lua --> "MINT Protocol" (lNtrei6YLQiWS8cyFFHDrOBvRzICQPTvrjZBP8fz-ZI)
rewards.treasury.lua --> "MINT Protocol Rewards Treasury" (ugh5LqeSZBKFJ0P_Q5wMpKNusG0jlATrihpcTxh5TKo)

OPERATIONS
maintenance.lua --> "Maintenance" (SpkZWLmuKAQ3vIK_1ErUndUxA372HxPtB5ncxa2V9VM)
mint-protocol.maintenance.lua  "MINT Protocol Maintenance" (ZT37FSfc486FCWTrO8dQ6E24iX0IhRlTy88OvsO-NM4)

airdrop.lua --> "NAB Airdropper" ( WWPYXeDnKggZ1At-AYMaoKmay8e7P2jot_lkL8aZVeE)

TEST TUBE
test.tube.token.lua --> "Test Tube Token" (U09Pg31Wlasc8ox5uTDm9sjFQT8XKcCR2Ru5lmFMe2A)


Note: if a process doesn't start through its alias, you can just use its address
