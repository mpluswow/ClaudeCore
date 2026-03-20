-- =============================================================================
-- DFP_AH.lua  v1.0.0
-- Dreamforge Auction House — client module
--
-- Registers the /ah slash command used by DforgePanel's AH button.
-- Sends ".ah" to the server which spawns a temporary faction-correct
-- auctioneer and opens the AH window from anywhere.
--
-- Requires: dfp-ah-server.lua loaded by the worldserver.
-- =============================================================================

SLASH_DFPAH1 = "/ah"
SlashCmdList["DFPAH"] = function()
    SendChatMessage(".ah", "SAY", nil, nil)
end
