-- ALE load check — delete this file after confirming scripts load.
PrintInfo("[CHECK] ALE is loading Lua scripts. check.lua OK.")
print("[CHECK] ALE is loading Lua scripts. check.lua OK.")

-- mod-ale does not export event constants as globals; use raw numbers.
-- PLAYER_EVENT_ON_LOGIN = 3
RegisterPlayerEvent(3, function(event, player)
    PrintInfo("[CHECK] LOGIN HOOK event=" .. tostring(event) .. " player=" .. tostring(player))
    player:SendBroadcastMessage("[CHECK] ALE is working. Login hook fired.")
end)
