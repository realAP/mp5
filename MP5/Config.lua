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
    barDir        = "fill",      -- fill (fuellt sich hoch) | drain (laeuft leer)
    showLabel     = false,       -- "MANA / 5" - der Wert erklaert sich selbst
    showFull      = true,        -- beide Stufen "12 / 47"
    showCountdown = true,        -- Restzeit unter dem Balken
    tooltip       = true,
    decimals      = 0,
    animate       = false,

    -- Zauber-Leiste
    showSpells  = true,
    spells      = {},            -- bis zu 5 Namen, z.B. "Blitzheilung"
    iconSize    = 24,
    countAnchor = "topright",    -- topright | center

    visibility = "always",       -- always | combat | notfull
}

local MAX_SPELLS = 5

local function applyDefaults(db)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            -- Tabellen kopieren, sonst teilen sich alle Charaktere eine.
            if type(v) == "table" then
                local t = {}
                for i, x in pairs(v) do t[i] = x end
                db[k] = t
            else
                db[k] = v
            end
        end
    end
    if type(db.spells) ~= "table" then db.spells = {} end
    return db
end

-- Sichtbarkeit -------------------------------------------------------------

local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local UnitPower    = UnitPower    or function(u) return UnitMana(u) end
local UnitPowerMax = UnitPowerMax or function(u) return UnitManaMax(u) end

function ns.UpdateVisibility()
    local db = ns.db
    if not db or not ns.frame then return end
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
    msg("  /mp5 bardir fill|drain        - Balken fuellt sich / laeuft leer")
    msg("  /mp5 backdrop blizzard|thin|off")
    msg("  /mp5 label|full|countdown|tooltip|animate on|off")
    msg("  /mp5 spells on|off            - Zauber-Leiste")
    msg("  /mp5 spell <1-5> <Zauber>     - z.B. /mp5 spell 1 Blitzheilung")
    msg("  /mp5 spell <1-5> clear        - Platz leeren")
    msg("  /mp5 spell list               - belegte Plaetze zeigen")
    msg("  /mp5 icon <16-48>             - Groesse der Zauber-Icons")
    msg("  /mp5 count topright|center    - wo die Zahl auf dem Icon sitzt")
    msg("  /mp5 options                  - Interface-Optionen oeffnen")
    msg("  /mp5 decimals 0|1")
    msg("  /mp5 show always|combat|notfull")
    msg("  /mp5 hide | /mp5 unhide")
    msg("  /mp5 reset                    - Standardwerte")
end

local toggles = {
    spells    = "showSpells",
    label     = "showLabel",
    full      = "showFull",
    countdown = "showCountdown",
    tooltip   = "tooltip",
    animate   = "animate",
}

-- Zaubernamen duerfen Leerzeichen und Grossbuchstaben haben, deshalb wird
-- der Rest der Eingabe hier unveraendert gelesen.
local function spellCommand(db, raw)
    local idx, rest = raw:match("^%s*(%d)%s*(.*)$")
    if not idx then
        if raw:lower():match("^%s*list") then
            msg("Zauber-Plaetze:")
            for i = 1, MAX_SPELLS do
                msg("  " .. i .. ": " .. (db.spells[i] or "|cff808080frei|r"))
            end
        else
            msg("/mp5 spell <1-5> <Zaubername>  |  /mp5 spell <1-5> clear  |  /mp5 spell list")
        end
        return false
    end

    idx = tonumber(idx)
    if idx < 1 or idx > MAX_SPELLS then
        msg("Platz 1 bis " .. MAX_SPELLS .. ".")
        return false
    end

    rest = rest:gsub("^%s+", ""):gsub("%s+$", "")
    if rest == "" or rest:lower() == "clear" or rest:lower() == "leer" then
        db.spells[idx] = nil
        msg("Platz " .. idx .. " geleert.")
        return true
    end

    local info = ns.Spells:Lookup(rest)
    if not info then
        msg("|cffff5555Unbekannter Zauber:|r " .. rest)
        msg("Genau wie im Makro schreiben, Rang optional: Blitzheilung(Rang 5)")
        return false
    end

    db.spells[idx] = rest
    msg("Platz " .. idx .. ": " .. info.name
        .. (info.rank and (" (" .. info.rank .. ")") or "")
        .. " - " .. (info.cost or "?") .. " Mana, "
        .. string.format("%.1fs", math.max(info.castTime or 0, 1.5)))
    return true
end

SLASH_MP51 = "/mp5"
SlashCmdList["MP5"] = function(input)
    local db = ns.db
    local cmd, arg = input:lower():match("^%s*(%S*)%s*(%S*)")

    -- Zuerst die Befehle, die den Originaltext brauchen.
    if cmd == "spell" then
        local raw = input:match("^%s*%S+%s*(.*)$") or ""
        spellCommand(db, raw)
        ns.ResolveSpells()
        ns.UpdateVisibility()
        return
    end

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
    elseif cmd == "bardir" then
        if arg == "fill" or arg == "drain" then
            db.barDir = arg
            msg(arg == "fill" and "Balken fuellt sich bis zur vollen Regeneration."
                               or "Balken laeuft die 5 Sekunden leer.")
        else msg("bardir fill|drain"); return end
    elseif cmd == "backdrop" then
        if arg == "blizzard" or arg == "thin" or arg == "off" then db.backdrop = arg
        else msg("backdrop blizzard|thin|off"); return end
    elseif toggles[cmd] then
        db[toggles[cmd]] = (arg == "on")
    elseif cmd == "icon" then
        db.iconSize = math.max(16, math.min(48, tonumber(arg) or db.iconSize))
    elseif cmd == "count" then
        if arg == "topright" or arg == "center" then db.countAnchor = arg
        else msg("count topright|center"); return end
    elseif cmd == "options" then
        ns.OpenOptions()
        return
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
        ns.ResolveSpells()
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
f:RegisterEvent("LEARNED_SPELL_IN_TAB")
f:RegisterEvent("SPELLS_CHANGED")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MP5CharDB = applyDefaults(MP5CharDB or {})
        ns.db = MP5CharDB
    elseif event == "PLAYER_LOGIN" then
        ns.ResolveSpells()
        ns.UpdateVisibility()
    elseif event == "LEARNED_SPELL_IN_TAB" or event == "SPELLS_CHANGED" then
        -- Neuer Rang gelernt: Kosten und Icon koennen sich geaendert haben.
        ns.ResolveSpells()
    else
        ns.UpdateVisibility()
    end
end)

Core:RegisterCallback(function()
    if ns.db and ns.db.visibility == "notfull" then ns.UpdateVisibility() end
end)
