-- MP5 / Probe.lua
-- Schreibt einmal beim Einloggen auf, was dieser Client hergibt.
-- Ergebnis landet in MP5Probe, also in
--   WTF\Account\<KONTO>\SavedVariables\MP5.lua
-- und laesst sich als Datei weitergeben, ohne etwas abzutippen.

local ADDON, ns = ...

local function try(fn)
    local ok, a, b = pcall(fn)
    if not ok then return "FEHLER: " .. tostring(a) end
    if a == nil then return "nil" end
    return a, b
end

-- Ist ein Wert fuer Addon-Code rechenbar, oder geschuetzt?
local function kind(v)
    if v == nil then return "nil" end
    local ok = pcall(function() return v + 0 end)
    if not ok then return "GESCHUETZT (secret value)" end
    return "lesbar: " .. tostring(v)
end

function ns.Probe()
    local p = {}

    p.build = { try(function() return GetBuildInfo() end) }
    p.class = { try(function() return select(2, UnitClass("player")) end) }
    p.level = { try(function() return UnitLevel("player") end) }

    -- Der geschuetzte Wert und sein Maximum
    p.manaCurrent = kind(select(1, try(function() return UnitPower("player", 0) end)))
    p.manaMax     = kind(select(1, try(function() return UnitPowerMax("player", 0) end)))
    p.manaLegacy  = kind(select(1, try(function() return UnitMana and UnitMana("player") end)))

    -- Der direkte Weg zur Regeneration
    p.getManaRegen = kind(select(1, try(function()
        return GetManaRegen and (select(1, GetManaRegen()))
    end)))
    p.getManaRegenCast = kind(select(1, try(function()
        return GetManaRegen and (select(2, GetManaRegen()))
    end)))

    -- Die Bausteine fuer eine Formel
    p.spirit    = kind(select(1, try(function() return select(2, UnitStat("player", 5)) end)))
    p.intellect = kind(select(1, try(function() return select(2, UnitStat("player", 4)) end)))

    -- Der Umweg ueber den Text der Standard-Manaleiste
    p.manaBarText = select(1, try(function()
        return PlayerFrameManaBarText and PlayerFrameManaBarText:GetText()
    end))

    -- Zweiter Versuch fuer das aktuelle Mana: der Wert der Standardleiste.
    -- Ein StatusBar-Wert ist eine gewoehnliche Zahl, kein geschuetzter Wert.
    p.manaBarValue = kind(select(1, try(function()
        return PlayerFrameManaBar and PlayerFrameManaBar:GetValue()
    end)))
    p.manaBarExists = (PlayerFrameManaBar ~= nil) and "ja" or "nein"

    -- Zauber-API: welche Form existiert, und was liefert eine Abfrage?
    p.spellApi = {
        GetSpellInfo          = (GetSpellInfo ~= nil) and "ja" or "nein",
        C_Spell               = (C_Spell ~= nil) and "ja" or "nein",
        C_Spell_GetSpellInfo  = (C_Spell and C_Spell.GetSpellInfo) and "ja" or "nein",
        GetSpellPowerCost     = (GetSpellPowerCost ~= nil) and "ja" or "nein",
        C_Spell_GetSpellPowerCost =
            (C_Spell and C_Spell.GetSpellPowerCost) and "ja" or "nein",
        GetSpellBookItemName  = (GetSpellBookItemName ~= nil) and "ja" or "nein",
        C_SpellBook           = (C_SpellBook ~= nil) and "ja" or "nein",
    }

    -- Eine echte Abfrage mit dem ersten Zauber aus dem Zauberbuch.
    local first = select(1, try(function()
        if GetSpellBookItemName then return (GetSpellBookItemName(1, "spell")) end
        if C_SpellBook and C_SpellBook.GetSpellBookItemName then
            return (C_SpellBook.GetSpellBookItemName(1, 0))
        end
    end))
    p.spellBookFirst = tostring(first)
    if type(first) == "string" then
        local hit = ns.Spells and ns.Spells:Lookup(first)
        p.spellLookup = hit
            and (hit.name .. " | Kosten " .. tostring(hit.cost)
                 .. " | Zeit " .. tostring(hit.castTime))
            or "nicht gefunden"
        p.spellAffordable = tostring(hit and ns.Spells:Affordable(hit))
        local ranked = ns.Spells and ns.Spells:Lookup(first .. "(Rang 1)")
        p.spellLookupWithRank = ranked
            and (ranked.name .. (ranked.rankIgnored and " (Rang ignoriert)" or ""))
            or "nicht gefunden"
    end

    -- Darf man einen geschuetzten Wert wenigstens VERGLEICHEN? Wenn ja,
    -- liesse sich das aktuelle Mana eingrenzen, ohne es zu lesen.
    p.manaCanCompare = select(1, try(function()
        local v = UnitPower("player", 0)
        local ok = pcall(function() return v > 0 end)
        return ok and "ja" or "nein"
    end))

    -- Der Text der Manaleiste ist nur gefuellt, wenn die Statustexte
    -- eingeschaltet sind. Deshalb hier auch die Einstellung selbst.
    p.statusTextCVar = select(1, try(function()
        return GetCVar and (GetCVar("statusText") or GetCVar("statusTextDisplay"))
    end))
    p.manaBarTextAgain = select(1, try(function()
        return PlayerFrameManaBarText and PlayerFrameManaBarText:GetText()
    end))

    -- Ersatzweg: beantwortet das Spiel, ob ein Zauber bezahlbar ist?
    p.isUsableSpell = (IsUsableSpell ~= nil) and "ja" or "nein"
    p.isSpellUsable = (C_Spell and C_Spell.IsSpellUsable) and "ja" or "nein"

    -- Welche Funktionen existieren ueberhaupt?
    local names = {
        "UnitPower", "UnitPowerMax", "UnitMana", "UnitManaMax", "GetManaRegen",
        "GetSpellInfo", "GetSpellPowerCost", "GetSpellBookItemName", "UnitStat",
        "GetInventoryItemLink", "C_Timer", "Settings", "InterfaceOptions_AddCategory",
    }
    p.exists = {}
    for i = 1, #names do
        p.exists[names[i]] = (_G[names[i]] ~= nil) and "ja" or "nein"
    end

    MP5Probe = p
    return p
end
