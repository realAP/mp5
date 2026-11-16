-- MP5 / Config.lua
-- Standardwerte, Sichtbarkeit und Slash-Befehle.

local ADDON, ns = ...
local Core = ns.Core

local defaults = {
    -- Position (pro Charakter)
    point = "CENTER", x = 0, y = -120,
    locked = false,

    -- Groesse
    scale = 1.0,
    width = 150,
    fontSize = 16,

    -- Aussehen
    backdrop      = "blizzard",  -- blizzard | thin | off
    bar           = "thin",      -- thin | full | off
    showLabel     = true,
    showFull      = true,        -- zweiter Wert "/ 47" waehrend der 5-Sek-Regel
    showCountdown = true,
    tooltip       = true,
    decimals      = 0,
    animate       = false,

    visibility = "always",       -- always | combat | notfull
}

local function applyDefaults(db)
    for k, v in pairs(defaults) do
        if db[k] == nil then db[k] = v end
    end
    return db
end

-- Sichtbarkeit -------------------------------------------------------------

local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0

function ns.UpdateVisibility()
    local db = ns.db
    if db.hidden or not Core:HasMana() then
        ns.frame:Hide()
        return
    end
    local show = true
    if db.visibility == "combat" then
        show = InCombatLockdown() or UnitAffectingCombat("player")
    elseif db.visibility == "notfull" then
        show = UnitPower("player", MANA) < UnitPowerMax("player", MANA)
    end
    if show then ns.frame:Show() else ns.frame:Hide() end
end

-- Slash --------------------------------------------------------------------

local function msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100MP5|r " .. text)
end

local function usage()
    msg("Befehle:")
    msg("  /mp5 lock | unlock            - Position fixieren")
    msg("  /mp5 scale <0.5-2>            - Groesse")
    msg("  /mp5 font <8-32>              - Schriftgroesse")
    msg("  /mp5 width <80-400>           - Breite")
    msg("  /mp5 bar off|thin|full        - Balken")
    msg("  /mp5 backdrop blizzard|thin|off")
    msg("  /mp5 label|full|countdown|tooltip|animate on|off")
    msg("  /mp5 decimals 0|1")
    msg("  /mp5 show always|combat|notfull")
    msg("  /mp5 hide | /mp5 unhide")
    msg("  /mp5 reset                    - Standardwerte")
end

local toggles = {
    label     = "showLabel",
    full      = "showFull",
    countdown = "showCountdown",
    tooltip   = "tooltip",
    animate   = "animate",
}

SLASH_MP51 = "/mp5"
SlashCmdList["MP5"] = function(input)
    local db = ns.db
    local cmd, arg = input:lower():match("^%s*(%S*)%s*(%S*)")

    if cmd == "lock" then
        db.locked = true; msg("fixiert.")
    elseif cmd == "unlock" then
        db.locked = false; msg("verschiebbar (links ziehen).")
    elseif cmd == "scale" then
        db.scale = math.max(0.5, math.min(2, tonumber(arg) or db.scale))
    elseif cmd == "font" then
        db.fontSize = math.max(8, math.min(32, tonumber(arg) or db.fontSize))
    elseif cmd == "width" then
        db.width = math.max(80, math.min(400, tonumber(arg) or db.width))
    elseif cmd == "bar" then
        if arg == "off" or arg == "thin" or arg == "full" then db.bar = arg
        else msg("bar off|thin|full"); return end
    elseif cmd == "backdrop" then
        if arg == "blizzard" or arg == "thin" or arg == "off" then db.backdrop = arg
        else msg("backdrop blizzard|thin|off"); return end
    elseif toggles[cmd] then
        db[toggles[cmd]] = (arg == "on")
    elseif cmd == "decimals" then
        db.decimals = math.max(0, math.min(1, tonumber(arg) or 0))
    elseif cmd == "show" then
        if arg == "always" or arg == "combat" or arg == "notfull" then
            db.visibility = arg
            db.hidden = false
        else msg("show always|combat|notfull"); return end
    elseif cmd == "hide" then
        db.hidden = true
    elseif cmd == "unhide" then
        db.hidden = false
    elseif cmd == "reset" then
        for k in pairs(db) do db[k] = nil end
        applyDefaults(db)
        msg("zurueckgesetzt.")
    else
        usage(); return
    end

    ns.ApplyLayout()
    ns.UpdateVisibility()
end

-- Start ---------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UNIT_MAXPOWER")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MP5CharDB = applyDefaults(MP5CharDB or {})
        ns.db = MP5CharDB
    elseif event == "PLAYER_LOGIN" then
        ns.ApplyLayout()
        ns.UpdateVisibility()
    else
        ns.UpdateVisibility()
    end
end)

Core:RegisterCallback(function()
    if ns.db and ns.db.visibility == "notfull" then ns.UpdateVisibility() end
end)
