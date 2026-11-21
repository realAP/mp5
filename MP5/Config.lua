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
    -- Mana selbst mitrechnen, wenn der Client den Wert nicht herausgibt.
    estimate    = true,

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
        -- Beide Werte koennen geschuetzt sein (im Kampf auch das Maximum);
        -- dann wird angezeigt, statt zu vergleichen und abzubrechen.
        local cur = ns.plain and ns.plain(Core:GetMana()) or Core:GetMana()
        local max = Core.GetMaxMana and Core:GetMaxMana() or nil
        show = (cur == nil) or (max == nil) or (cur < max)
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
    msg("  /mp5 width <80-400>           - Breite (Mindestbreite: die")
    msg("                                  Zauber-Reihe kann breiter sein)")
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
    msg("  /mp5 estimate on|off|reset    - Mana mitrechnen, wenn der Client")
    msg("                                  es nicht herausgibt")
    msg("  /mp5 options                  - Interface-Optionen oeffnen")
    msg("  /mp5 decimals 0|1")
    msg("  /mp5 show always|combat|notfull")
    msg("  /mp5 hide | /mp5 unhide")
    msg("  /mp5 errors [clear]           - mitgeschriebene Fehler")
    msg("  /mp5 probe                    - was dieser Client hergibt")
    msg("  /mp5 why                      - warum steht da keine Zahl?")
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
    if info.rankIgnored then
        msg("|cffffaa33Hinweis:|r Dieser Client kennt keine Raenge, "
            .. "\"" .. info.rankIgnored .. "\" wurde ignoriert.")
    end
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
    elseif cmd == "estimate" then
        if arg == "reset" then
            if ns.Estimate then ns.Estimate:Reset() end
            msg("Modell zurueckgesetzt - es baut sich aus der Regeneration "
                .. "neu auf.")
            return
        elseif arg == "on" or arg == "off" then
            db.estimate = (arg == "on")
            if ns.Estimate then ns.Estimate:SetEnabled(db.estimate) end
            msg(db.estimate
                and "Mana wird mitgerechnet, wenn der Client es schuetzt."
                or  "Mana wird nicht mitgerechnet.")
        else msg("estimate on|off|reset"); return end
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
    elseif cmd == "why" then
        -- Die Stueckzahl braucht vier Werte. Hier steht, welcher fehlt.
        local function str(...)
            if select("#", ...) == 0 then return "-" end
            local v = ...
            if v == nil then return "|cffff5555FEHLT|r" end
            return tostring(v)
        end

        local mana  = Core:GetMana()
        local mp5   = Core:GetMP5(true)
        local mps   = mp5 and (mp5 / 5) or 0
        msg("Warum keine Zahl? Die Rechnung braucht vier Werte:")
        msg("  aktuelles Mana:   " .. str(mana) .. "  (Quelle: "
            .. str(Core:ManaSource()) .. ")")
        if mana == nil then
            msg("  Durchsuchte Stellen der Manaleiste:")
            local cands = Core:ManaBarCandidates()
            if #cands == 0 then
                msg("    |cffff5555keine gefunden|r - Standard-Spielerfenster "
                    .. "nicht vorhanden oder von einem anderen Addon ersetzt?")
            end
            for i = 1, #cands do
                local c = cands[i]
                msg("    " .. c.label .. ": \"" .. tostring(c.text) .. "\""
                    .. (c.value and ("  -> " .. tostring(c.value)) or ""))
            end
        end
        msg("  Regen beim Casten: " .. str(mp5) .. " MP5"
            .. (mp5 and "" or "  -> wird mit 0 gerechnet"))

        -- Das Modell: woraus der Wert gerade besteht.
        if ns.Estimate then
            local ok, s = pcall(ns.Estimate.Status, ns.Estimate)
            if ok and type(s) == "table" then
                local function num(v) return v and tostring(math.floor(v)) or "-" end
                msg("  Modell: " .. (s.enabled and "an" or "aus")
                    .. ", Wert " .. num(s.mana) .. " von " .. num(s.max)
                    .. (s.exact and "  |cff40ff40(exakt: Tank ist voll)|r"
                                 or "  (Untergrenze)"))
                msg("    aufgelaufene Regeneration seit dem letzten Zauber: "
                    .. num(s.credit)
                    .. " (Anker bei " .. num(s.max and s.max * 1.25) .. ")")
                msg("    Mana-Ereignis: " .. (s.events and "kommt an" or
                    "|cffff5555noch keins gesehen|r")
                    .. ", seit " .. num(s.quiet) .. "s still"
                    .. " (Anker ab 3s)")
                msg("    Schranken aus der Bezahlbarkeit: mindestens "
                    .. num(s.lower) .. ", weniger als " .. num(s.upper)
                    .. "  (" .. num(s.ladder) .. " Zauber in der Kostenleiter)")
            end
        end

        local any = false
        for i = 1, MAX_SPELLS do
            local name = db.spells[i]
            if name then
                any = true
                local s2 = ns.Spells:Lookup(name)
                if not s2 then
                    msg("  " .. i .. ") " .. name
                        .. ": |cffff5555Zauber nicht gefunden|r")
                else
                    local casts = ns.Spells.CastsLeft(mana, s2.cost, s2.castTime, mps)
                    msg("  " .. i .. ") " .. s2.name
                        .. "  Kosten " .. str(s2.cost)
                        .. " (" .. str(s2.costFrom) .. ")"
                        .. "  Zeit " .. str(s2.castTime)
                        .. "  ID " .. str(s2.spellID)
                        .. "  -> " .. str(casts))
                end
            end
        end
        if not any then
            msg("  |cffff5555Kein Zauber eingetragen.|r "
                .. "Zum Beispiel: /mp5 spell 1 Blitzheilung")
        end
        return
    elseif cmd == "probe" then
        -- Nimmt auch "gar kein Argument" entgegen, nicht nur nil.
        local function str(...)
            if select("#", ...) == 0 then return "-" end
            local v = ...
            if v == nil then return "-" end
            return tostring(v)
        end
        local ok, p = pcall(ns.Probe)
        if not ok or type(p) ~= "table" then
            msg("|cffff5555Pruefung fehlgeschlagen:|r " .. tostring(p))
            return
        end
        msg("Client-Pruefung:")
        msg("  aktuelles Mana:  " .. str(p.manaCurrent))
        msg("  Maximalmana:     " .. str(p.manaMax))
        msg("  UnitMana:        " .. str(p.manaLegacy))
        msg("  GetManaRegen:    " .. str(p.getManaRegen))
        msg("  davon Cast-Wert: " .. str(p.getManaRegenCast))
        msg("  Spirit:          " .. str(p.spirit))
        msg("  Intellect:       " .. str(p.intellect))
        msg("  Text der Leiste: " .. str(p.manaBarText))
        msg("  Wert der Leiste: " .. str(p.manaBarValue))
        msg("  Statustext-CVar: " .. str(p.statusTextCVar))
        msg("  vergleichbar:    " .. str(p.manaCanCompare))
        msg("  bezahlbar-Test:  " .. str(p.spellAffordable))
        msg("  Mana-Quelle:     " .. str(Core:ManaSource()))
        msg("  Mana daraus:     " .. str(Core:GetMana()))
        msg("  MP5 ausserhalb:  " .. str(Core:GetMP5(false)))
        msg("  MP5 beim Casten: " .. str(Core:GetMP5(true)))
        msg("Vollstaendig in WTF\\Account\\<KONTO>\\SavedVariables\\MP5.lua")
        return
    elseif cmd == "errors" then
        if arg == "clear" then
            MP5Errors = {}
            Core:ClearErrors()
            msg("Fehlerspeicher geleert.")
            return
        end
        local list = MP5Errors
        if type(list) ~= "table" or #list == 0 then
            msg("Keine Fehler mitgeschrieben.")
        else
            msg(#list .. " verschiedene Fehler:")
            for i = 1, #list do
                msg("  " .. i .. ") x" .. (list[i].count or 1) .. "  " .. list[i].msg)
            end
            msg("Vollstaendig mit Stacktrace in:")
            msg("  WTF\\Account\\<KONTO>\\SavedVariables\\MP5.lua")
        end
        return
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

-- Diese Events kennt nicht jeder Client; RegisterEvent bricht dort ab.
for _, e in ipairs({ "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED" }) do
    pcall(f.RegisterEvent, f, e)
end

f:SetScript("OnEvent", ns.safe(function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MP5CharDB = applyDefaults(MP5CharDB or {})
        ns.db = MP5CharDB
    elseif event == "PLAYER_LOGIN" then
        if ns.Estimate then ns.Estimate:SetEnabled(ns.db.estimate) end
        pcall(ns.Probe)            -- einmal aufschreiben, was der Client kann
        ns.ResolveSpells()
        ns.UpdateVisibility()
        if not Core:ManaReadable() then
            msg("|cffff9955Dieser Client schuetzt den aktuellen Manawert|r "
                .. "(\"secret value\"). Addons duerfen damit nicht rechnen.")
            local src = Core:ManaSource()
            if src == "prozent" then
                msg("|cff40ff40Umweg gefunden:|r Mana wird aus dem Prozentwert "
                    .. "der Standardleiste umgerechnet. Die Zauber-Zahlen sind "
                    .. "daher gerundet (~). Mit numerischem Statustext werden "
                    .. "sie genau.")
            elseif src == "text" then
                msg("|cff40ff40Umweg gefunden:|r Mana wird aus dem Text der "
                    .. "Standardleiste gelesen. Die Zauber-Zahlen stimmen.")
            elseif src == "modell" then
                msg("|cff40ff40Umweg gefunden:|r Mana wird mitgerechnet - "
                    .. "Kosten der gewirkten Zauber abziehen, Regeneration "
                    .. "dazu. Die Zahlen sind eine Untergrenze (~) und "
                    .. "werden exakt, sobald der Tank einmal voll war.")
                msg("Stand und Herleitung: |cff88ccff/mp5 why|r, "
                    .. "abschalten mit |cff88ccff/mp5 estimate off|r.")
            end
            msg("Gemessen wird deshalb nicht; die Regenerationszahlen kommen "
                .. "von GetManaRegen(). Die 5-Sekunden-Regel laeuft ueber die "
                .. "Zauber selbst.")
        end
    elseif event == "LEARNED_SPELL_IN_TAB" or event == "SPELLS_CHANGED" then
        -- Neuer Rang gelernt: Kosten und Icon koennen sich geaendert haben.
        ns.ResolveSpells()
    else
        ns.UpdateVisibility()
    end
end))

Core:RegisterCallback(function()
    if ns.db and ns.db.visibility == "notfull" then ns.UpdateVisibility() end
end)
