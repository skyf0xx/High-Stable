# Extensions for VS Code

Lua Language Server by sumneko

Startup:
`aos process-name --wallet .aos.json`

These are the current names for the processes:
mithril.lua --> "Number Always Bigger" (OsK9Vgjxo0ypX_HLz2iJJuh4hp3I80yA9KArsJjIloU)
mithril.policy.lua --> "NAB Policy"
mithril.stake.mint.lua --> "NAB Stake and Mint" (KbUW8wkZmiEWeUG0-K8ohSO82TfTUdz6Lqu5nxDoQDc)
cron.caller.stakers.lua --> "NAB Staking Cron" (4SPnL6WtRmaFEVb1iopgS9IUYX917sfIWjbO5z8zX3k) every 5 minutes
mithril.stats.lua --> "NAB Ecosystem Stats" (dNmk7_vhghAG06yFnRjm0IrFKPQFhqlF0pU7Bk3RmkM) NOTE: Uses WASM 64 sqlite first init is with --module=ghSkge2sIUD_F00ym5sEimC63BDBuBrq4b5OcwxOjiw
cron.caller.stats.lua --> "Cron NAB Ecosystem Stats" (iAEDZ6Y_wpEcksEzypVYhI01ShQIHCIvwEQ7NA3-2KA) every 24 hours
maintenance.lua --> "Maintenance" (SpkZWLmuKAQ3vIK_1ErUndUxA372HxPtB5ncxa2V9VM)
points.lua --> "NAB FRN Points" (4Aq_6sBUyEo6AlKRq6JLT9dDfYG5ThfznA_cXjwsJpM)
