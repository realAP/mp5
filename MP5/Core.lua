-- MP5 / Core.lua
-- Ermittelt die tatsaechliche Mana-Regeneration pro 5 Sekunden.
--
-- Zwei Quellen, bewusst in dieser Reihenfolge:
--   1. GEMESSEN  - die echten Mana-Ticks werden mitgezaehlt. Das ist per
--                  Definition exakt und enthaelt automatisch alles:
--                  Geist, Segen der Weisheit, Nahrung, Items, Volksfaehigkeiten.
--   2. API       - GetManaRegen() als Sofortwert, solange noch nichts
--                  gemessen wurde. In Classic liefert die Funktion immer den
--                  Wert des *aktuellen* Zustands (innerhalb/ausserhalb der
--                  5-Sekunden-Regel) und ist bei Buffs nicht verlaesslich,
--                  daher nur Ueberbrueckung.

local ADDON, ns = ...

ns.Core = {}
local Core = ns.Core

local GetTime             = GetTime
-- Aeltere Clients kennen nur UnitMana/UnitManaMax.
local UnitPower           = UnitPower    or function(u) return UnitMana(u) end
local UnitPowerMax        = UnitPowerMax or function(u) return UnitManaMax(u) end
local GetManaRegen        = GetManaRegen
local MANA                = Enum and Enum.PowerType and Enum.PowerType.Mana or 0

-- Mana tickt in Classic alle 2 Sekunden.
local TICK_INTERVAL  = 2.0
local TICK_TOLERANCE = 0.35      -- akzeptierter Abstand zweier Ticks
local FSR_DURATION   = 5.0       -- Dauer der 5-Sekunden-Regel
local MEASURE_TTL    = 180       -- Messwerte so lange als gueltig ansehen (Sek.)

-- Zustand -----------------------------------------------------------------
local lastMana   = 0
local fsrEnd     = 0             -- Zeitpunkt, an dem die 5-Sek-Regel endet
local fsrStart   = 0
local pending    = nil           -- letzter beobachteter Zuwachs {delta, t}

-- Messwerte getrennt fuer "innerhalb" und "ausserhalb" der 5-Sek-Regel.
local measured = {
    [true]  = nil,               -- {mp5 = x, t = Zeitpunkt}
    [false] = nil,
}

Core.callbacks = {}

local function fire()
    for i = 1, #Core.callbacks do
        Core.callbacks[i]()
    end
end

function Core:RegisterCallback(fn)
    Core.callbacks[#Core.callbacks + 1] = fn
end

-- 5-Sekunden-Regel --------------------------------------------------------

function Core:InFSR()
    return GetTime() < fsrEnd
end

function Core:FSRRemaining()
    local rest = fsrEnd - GetTime()
    return rest > 0 and rest or 0
end

local function startFSR()
    local now = GetTime()
    if not (now < fsrEnd) then
        fsrStart = now           -- nur bei echtem Neustart merken
    end
    fsrEnd = now + FSR_DURATION
    fire()
end

-- Messung -----------------------------------------------------------------

-- Ein Zuwachs gilt nur dann als regulaerer Regenerations-Tick, wenn zwei
-- gleich grosse Zuwaechse im Abstand von ~2 Sekunden auftreten. Traenke,
-- Evokation, Aderlass usw. fallen damit heraus.
local function onManaChanged()
    local now  = GetTime()
    local cur  = UnitPower("player", MANA)
    local max  = UnitPowerMax("player", MANA)
    local delta = cur - lastMana
    lastMana = cur

    if delta < 0 then
        -- Mana ausgegeben -> 5-Sekunden-Regel laeuft los.
        pending = nil
        startFSR()
        return
    end

    if delta <= 0 then return end

    -- Am Manamaximum wird der Tick abgeschnitten, der Wert waere zu klein.
    if cur >= max then
        pending = nil
        return
    end

    if pending then
        local gap = now - pending.t
        local sameSize = math.abs(delta - pending.delta) <= math.max(1, delta * 0.05)
        if sameSize and math.abs(gap - TICK_INTERVAL) <= TICK_TOLERANCE then
            -- Zustand muss waehrend des gesamten Intervalls derselbe gewesen sein.
            local inFSR = now < fsrEnd
            local stable = (not inFSR) and (pending.t > fsrEnd) or (inFSR and fsrStart <= pending.t)
            if stable then
                measured[inFSR] = { mp5 = delta * (5 / TICK_INTERVAL), t = now }
                fire()
            end
        end
    end

    pending = { delta = delta, t = now }
end

-- Abfrage ------------------------------------------------------------------

local function apiMP5()
    if not GetManaRegen then return nil end
    local base = GetManaRegen()
    if not base then return nil end
    return base * 5
end

-- Wert fuer einen Zustand. inFSR = true  -> nur MP5-Effekte
--                          inFSR = false -> inkl. Geist
-- Rueckgabe: Wert, Quelle ("gemessen" | "api" | nil)
function Core:GetMP5(inFSR)
    local now = GetTime()
    local m = measured[inFSR]
    if m and (now - m.t) < MEASURE_TTL then
        return m.mp5, "gemessen"
    end

    -- Die API kennt nur den aktuellen Zustand.
    if inFSR == (now < fsrEnd) then
        local v = apiMP5()
        if v then return v, "api" end
    end

    if m then return m.mp5, "gemessen" end
    return nil, nil
end

-- Der gerade wirksame Wert.
function Core:GetCurrent()
    return Core:GetMP5(GetTime() < fsrEnd)
end

-- Der Wert nach Ablauf der 5-Sekunden-Regel.
function Core:GetFull()
    return Core:GetMP5(false)
end

function Core:HasMana()
    return UnitPowerMax("player", MANA) > 0
end

-- Events -------------------------------------------------------------------

local f = CreateFrame("Frame")
local function reg(event)
    if f.RegisterUnitEvent then
        local ok = pcall(f.RegisterUnitEvent, f, event, "player")
        if ok then return end
    end
    pcall(f.RegisterEvent, f, event)
end

reg("UNIT_POWER_UPDATE")
reg("UNIT_MANA")                  -- aeltere Clients
reg("UNIT_MAXPOWER")
reg("UNIT_AURA")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

local auraThrottle = 0

f:SetScript("OnEvent", function(_, event, unit, powerType)
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MANA" then
        if unit ~= "player" then return end
        if powerType and powerType ~= "MANA" then return end
        onManaChanged()
    elseif event == "UNIT_AURA" then
        if unit ~= "player" then return end
        -- Buffs koennen die Regeneration aendern. Messwerte werden nicht
        -- verworfen (UNIT_AURA feuert im Kampf staendig, das wuerde jede
        -- Messung zerstoeren) - sie werden vom naechsten Tick ueberschrieben,
        -- also spaetestens nach 2 Sekunden.
        local now = GetTime()
        if now - auraThrottle < 0.25 then return end
        auraThrottle = now
        fire()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        measured[true], measured[false] = nil, nil
        pending = nil
        fire()
    else
        lastMana = UnitPower("player", MANA)
        pending = nil
        fire()
    end
end)
