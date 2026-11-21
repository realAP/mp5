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

-- Zugriff auf den Manawert ------------------------------------------------
--
-- Manche Clients geben den aktuellen Manawert als "secret value" zurueck:
-- das Spiel darf damit rechnen, Addon-Code nicht. Jede Rechnung damit
-- bricht ab ("attempt to perform arithmetic on a secret number value").
-- Deshalb wird der Zugriff einmal geprueft und, wenn er nicht nutzbar ist,
-- die Messung abgeschaltet - statt bei jedem Mana-Tick zu werfen.

local manaFn = nil          -- nil = noch nicht geprueft, false = kein Zugriff

-- Die Sperre an jeder Grenze zum Client.
--
-- Ein geschuetzter Wert sieht wie eine Zahl aus, bricht aber bei der ersten
-- Rechnung oder dem ersten Vergleich ab - und er faerbt alles ab, was aus
-- ihm entsteht. Im Kampf schuetzt dieser Client mehr Werte als davor
-- (beobachtet an GetManaRegen und UnitPowerMax), weshalb ein einmaliger
-- Test beim Start nicht genuegt: jeder Wert, der von aussen kommt, laeuft
-- hier durch, bevor mit ihm gerechnet wird.
--
-- Rueckgabe: die Zahl, oder nil wenn sie nicht benutzbar ist.
local function plain(v)
    if type(v) ~= "number" then return nil end
    -- Rechnung UND Vergleich pruefen: manche Werte lassen das eine zu und
    -- das andere nicht.
    local ok, fine = pcall(function() return (v + 0) > -1 or true end)
    if not ok or fine ~= true then return nil end
    return v
end

ns.plain = plain

local function usable(v)
    return plain(v) ~= nil
end

-- Maximalmana, oder nil wenn der Client es gerade schuetzt.
local function maxMana()
    local ok, v = pcall(UnitPowerMax, "player", MANA)
    return ok and plain(v) or nil
end

local function pickManaFn()
    local tries = {}
    if UnitPower then
        tries[#tries + 1] = function() return UnitPower("player", MANA) end
    end
    if UnitMana then
        tries[#tries + 1] = function() return UnitMana("player") end
    end
    for i = 1, #tries do
        local ok, v = pcall(tries[i])
        if ok and v ~= nil and usable(v) then return tries[i] end
    end
    return false
end

-- Letzter Ausweg, wenn der Wert geschuetzt ist: die Standard-Manaleiste.
-- Ein Text ist keine geschuetzte Zahl, und ein StatusBar-Wert auch nicht.
--
-- Die Fontstring heisst nicht auf jedem Client PlayerFrameManaBarText,
-- deshalb werden die Regionen der Leiste durchsucht statt Namen geraten.

local function parseManaText(t)
    if type(t) ~= "string" or t == "" then return nil end

    -- "1234 / 1435" - Tausenderpunkte entfernen, der Trenner ist kein Komma
    local a = t:match("^%s*([%d%.,%s]-%d)%s*/")
    if a then
        local n = tonumber((a:gsub("[%.,%s]", "")))
        if n then return n, false end
    end

    -- "47%" oder "47,5%" - hier ist das Komma ein Dezimaltrenner
    local pct = t:match("([%d]+[%.,]?%d*)%s*%%")
    if pct then
        local v = tonumber((pct:gsub(",", ".")))
        local max = maxMana()
        if v and max and max > 0 then
            return max * v / 100, true
        end
    end

    -- nur eine Zahl
    local n = t:match("^%s*([%d%.,%s]-%d)%s*$")
    if n then
        local v = tonumber((n:gsub("[%.,%s]", "")))
        if v then return v, false end
    end

    return nil
end

-- Alle Fontstrings, die den Manawert tragen koennten.
local function barCandidates()
    local out = {}
    local function add(label, fs)
        if fs and fs.GetText then out[#out + 1] = { label = label, fs = fs } end
    end

    add("PlayerFrameManaBarText", PlayerFrameManaBarText)

    local bar = PlayerFrameManaBar
    if bar then
        add("ManaBar.TextString", bar.TextString)
        if bar.GetRegions then
            local ok, regions = pcall(function() return { bar:GetRegions() } end)
            if ok and type(regions) == "table" then
                for i = 1, #regions do
                    add("ManaBar-Region " .. i, regions[i])
                end
            end
        end
    end

    -- Manche Clients haengen den Text ans Spielerfenster, nicht an die Leiste.
    if PlayerFrame and PlayerFrame.GetRegions then
        local ok, regions = pcall(function() return { PlayerFrame:GetRegions() } end)
        if ok and type(regions) == "table" then
            for i = 1, #regions do
                add("PlayerFrame-Region " .. i, regions[i])
            end
        end
    end

    return out
end

-- Fuer /mp5 why: was liefert jeder Kandidat?
function Core:ManaBarCandidates()
    local out, c = {}, barCandidates()
    for i = 1, #c do
        local ok, t = pcall(c[i].fs.GetText, c[i].fs)
        local v = ok and parseManaText(t) or nil
        out[#out + 1] = {
            label = c[i].label,
            text  = ok and tostring(t) or "FEHLER",
            value = v,
        }
    end
    return out
end

local function indirectMana()
    -- Der Wert der Leiste selbst. Der Vergleich muss mit im pcall stehen:
    -- auf einem geschuetzten Wert bricht schon ">" ab.
    local bar = PlayerFrameManaBar
    if bar and bar.GetValue then
        local ok, v = pcall(function()
            local x = bar:GetValue()
            if type(x) == "number" and x > 0 then return x end
        end)
        if ok and type(v) == "number" then return v, false, "leistenwert" end
    end

    local c = barCandidates()
    for i = 1, #c do
        local ok, t = pcall(c[i].fs.GetText, c[i].fs)
        if ok then
            local v, approx = parseManaText(t)
            if v then return v, approx, approx and "prozent" or "text" end
        end
    end

    return nil
end

local function readMana()
    if manaFn == nil then manaFn = pickManaFn() end
    if manaFn then
        local ok, v = pcall(manaFn)
        -- Auch hier durch die Sperre: ein Client, der den Wert ausserhalb
        -- des Kampfes herausgibt, kann ihn im Kampf schuetzen.
        if ok then
            local n = plain(v)
            if n then return n, false, "api" end
        end
    end
    -- Geschuetzt: ueber die Standardleiste versuchen.
    local ok, v, approx, src = pcall(indirectMana)
    if ok and type(v) == "number" then
        return v, approx and true or false, src
    end
    return nil
end

-- Ist der Wert direkt aus der API lesbar? (false heisst nicht, dass es
-- gar nicht geht - der Leistentext kann trotzdem greifen.)
function Core:ManaReadable()
    if manaFn == nil then manaFn = pickManaFn() end
    return manaFn and true or false
end

-- Kommt ueberhaupt ein Wert zustande, egal auf welchem Weg?
function Core:ManaAvailable()
    return (readMana() ~= nil)
end

-- Aktuelles Mana, oder nil wenn kein Weg zum Wert fuehrt.
-- Rueckgabe: Wert, gerundet?, Quelle ("api" | "text" | "prozent" | "modell")
--
-- Das Modell steht bewusst erst am Ende: es rechnet den Wert nur nach
-- (Kosten abziehen, Regeneration dazu) und ist eine Untergrenze, solange
-- der Volltank-Anker nicht gegriffen hat. Ein direkt gelesener Wert ist
-- immer besser. Die Messung der Mana-Ticks benutzt das Modell nicht -
-- sie wuerde sonst die eigene Annahme als Tick messen.
function Core:GetMana()
    local v, approx, src = readMana()
    if v then return v, approx, src end

    local Est = ns.Estimate
    if Est then
        local ok, m, exact = pcall(Est.Get, Est)
        if ok and type(m) == "number" then
            return m, not exact, "modell"
        end
    end
    return nil
end

-- Woher kommt das aktuelle Mana gerade? nil = nirgendwo.
-- Bewusst ueber eine Zuweisung statt select(3, ...): kommt kein Wert
-- zustande, gibt select gar nichts zurueck - und ein tostring() ohne
-- Argument bricht ab ("bad argument #1 to 'tostring'").
function Core:ManaSource()
    local _, _, src = Core:GetMana()
    return src
end

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

-- Ein Fehler in der Anzeige darf nicht bei jedem Mana-Tick erneut
-- hochkommen. Jede Fehlermeldung wird genau einmal ausgegeben; danach
-- laeuft das Addon weiter, ohne den Chat zuzumuellen.
local reported = {}
local MAX_ERRORS = 60

-- Fehler werden zusaetzlich in die SavedVariables geschrieben. Die Datei
-- WTF\Account\<KONTO>\SavedVariables\MP5.lua ist reiner Text und laesst
-- sich weitergeben, ohne irgendetwas abzutippen.
local function store(err)
    if type(MP5Errors) ~= "table" then MP5Errors = {} end
    local e = tostring(err)
    for i = 1, #MP5Errors do
        if MP5Errors[i].msg == e then
            MP5Errors[i].count = (MP5Errors[i].count or 1) + 1
            return
        end
    end
    if #MP5Errors >= MAX_ERRORS then return end
    MP5Errors[#MP5Errors + 1] = {
        msg     = e,
        count   = 1,
        when    = date and date("%Y-%m-%d %H:%M:%S") or nil,
        build   = GetBuildInfo and tostring(GetBuildInfo()) or nil,
        version = GetAddOnMetadata and GetAddOnMetadata("MP5", "Version") or nil,
        stack   = debugstack and debugstack(3, 6, 0) or nil,
    }
end

local function report(err)
    pcall(store, err)
    if reported[err] then return end
    reported[err] = true
    local out = DEFAULT_CHAT_FRAME
    if out then
        out:AddMessage("|cffffd100MP5|r |cffff5555Fehler:|r " .. tostring(err))
        out:AddMessage("|cffffd100MP5|r Mitgeschrieben. Weitere Meldungen "
            .. "derselben Art bleiben stumm. |cff88ccff/mp5 errors|r")
    end
end

-- Fuer Event-Handler: faengt alles ab und schreibt es mit.
function ns.safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then report(err) end
    end
end

ns.report = report

local function fire()
    for i = 1, #Core.callbacks do
        local ok, err = pcall(Core.callbacks[i])
        if not ok then report(err) end
    end
end

-- Damit sich ein Fehler nach einem Fix wieder melden kann.
function Core:ClearErrors()
    reported = {}
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

-- Kostet dieser Zauber Mana? Nur dann startet die 5-Sekunden-Regel.
-- Die Signatur von UNIT_SPELLCAST_SUCCEEDED ist je nach Client
-- (unit, castGUID, spellID) oder (unit, spellName, rank).
local function spellCostsMana(a2, a3)
    local id = tonumber(a3) or tonumber(a2)
    if id and GetSpellPowerCost then
        local ok, costs = pcall(GetSpellPowerCost, id)
        if ok and type(costs) == "table" then
            for i = 1, #costs do
                local c = costs[i]
                if c and (c.type == 0 or c.name == "MANA") then
                    return (c.cost or 0) > 0
                end
            end
            return false          -- Kostentabelle da, aber kein Mana darin
        end
    end
    return true                   -- unbekannt: lieber ausloesen als verpassen
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
    local cur  = readMana()
    if not cur then return end        -- Client schuetzt den Wert: nicht messbar
    local max  = maxMana()
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
    if max and cur >= max then
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

-- GetManaRegen() liefert Mana pro Sekunde, und zwar zwei Werte:
--   1. ausserhalb der 5-Sekunden-Regel (inkl. Geist)
--   2. waehrend des Zauberns (nur MP5-Effekte)
-- Nicht jeder Client fuellt den zweiten Wert sinnvoll; manche geben zweimal
-- den Wert des gerade aktiven Zustands zurueck. Deshalb wird er nur dann
-- fuer beide Stufen benutzt, wenn er sich vom ersten unterscheidet.
-- Der zuletzt benutzbare API-Wert je Stufe, und ob die letzte Abfrage an
-- einem geschuetzten Wert gescheitert ist.
local lastApi = {}
local tainted = false

local function apiMP5(inFSR)
    tainted = false
    if not GetManaRegen then return nil end
    local ok, b, c = pcall(GetManaRegen)
    if not ok then return nil end
    -- Im Kampf schuetzt dieser Client auch diese Rueckgaben. Dann lieber
    -- keine Zahl als eine, die bei der naechsten Rechnung abbricht.
    local base, casting = plain(b), plain(c)
    if not base then
        -- Es KAM etwas, es war nur nicht benutzbar. Das ist der Kampf-Fall
        -- und unterscheidet sich von "diese Stufe ist unbekannt": hier darf
        -- der zuletzt gelesene Wert weiterhin gelten.
        tainted = (b ~= nil)
        return nil
    end

    if casting and casting ~= base then
        return (inFSR and casting or base) * 5
    end

    -- Nur der aktuelle Zustand ist bekannt.
    if inFSR == (GetTime() < fsrEnd) then return base * 5 end
    return nil
end

-- Mana aus periodischen Buffs (Segen der Weisheit, Manaquelle). Diese
-- Betraege stehen in GetManaRegen() NICHT drin, in einem gemessenen Tick
-- dagegen schon - sonst wuerde hier doppelt gezaehlt.
local function auraMP5()
    local A = ns.Auras
    if not A then return 0 end
    -- Abschaltbar: sollte ein Client diese Buffs doch in GetManaRegen()
    -- fuehren, wuerde hier doppelt gezaehlt. Dann /mp5 buffs off.
    if ns.db and ns.db.auraRegen == false then return 0 end
    local ok, extra = pcall(A.ExtraMP5, A)
    return (ok and type(extra) == "number") and extra or 0
end

-- Wert fuer einen Zustand. inFSR = true  -> nur MP5-Effekte
--                          inFSR = false -> inkl. Geist
-- Rueckgabe: Wert, Quelle ("gemessen" | "api" | nil)
function Core:GetMP5(inFSR)
    local now = GetTime()
    local m = measured[inFSR]
    if m and (now - m.t) < MEASURE_TTL then
        return plain(m.mp5), "gemessen"
    end

    local v = plain(apiMP5(inFSR))
    if v then
        lastApi[inFSR] = v
        return v + auraMP5(), "api"
    end

    -- Geschuetzt (im Kampf): der zuletzt gelesene Wert ist die beste
    -- Auskunft, die es gibt - besser als ein "?" fuer die Dauer des Kampfes.
    -- Nur bei echter Taint, nicht wenn die Stufe nie bekannt war.
    if tainted and lastApi[inFSR] then
        return lastApi[inFSR] + auraMP5(), "zuletzt"
    end

    if m then return plain(m.mp5), "gemessen" end

    -- Gar keine Auskunft vom Client, aber ein Buff, der sicher tickt: dann
    -- ist dieser Betrag die ganze Wahrheit, die wir haben - und besser als
    -- "nichts kommt nach", denn damit laeuft das Modell leer.
    local extra = auraMP5()
    if extra > 0 then return extra, "buffs" end
    return nil, nil
end

-- Nur der Anteil aus Buffs, fuer die Auskunft.
function Core:GetAuraMP5()
    return auraMP5()
end

-- Der gerade wirksame Wert.
function Core:GetCurrent()
    return Core:GetMP5(GetTime() < fsrEnd)
end

-- Der Wert nach Ablauf der 5-Sekunden-Regel.
function Core:GetFull()
    return Core:GetMP5(false)
end

-- Maximalmana nach aussen, oder nil wenn der Client es gerade schuetzt.
function Core:GetMaxMana()
    return maxMana()
end

function Core:HasMana()
    local max = maxMana()
    -- Schuetzt der Client den Wert gerade (im Kampf), ist das kein Grund,
    -- die Anzeige zu verstecken: wer Mana hat, hat es weiterhin.
    if not max then return true end
    return max > 0
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

-- Der Start der Regel wird normalerweise am sinkenden Mana erkannt.
-- Schuetzt der Client den Manawert, geht das nicht - dann dient der
-- erfolgreiche Zauber selbst als Ausloeser. Schadet auch sonst nicht:
-- startFSR setzt das Ende neu, egal wie oft es aufgerufen wird.
reg("UNIT_SPELLCAST_SUCCEEDED")
reg("UNIT_POWER_UPDATE")
reg("UNIT_MANA")                  -- aeltere Clients
reg("UNIT_MAXPOWER")
reg("UNIT_AURA")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

local auraThrottle = 0

f:SetScript("OnEvent", ns.safe(function(_, event, unit, powerType, arg3)
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MANA" then
        if unit ~= "player" then return end
        if powerType and powerType ~= "MANA" then return end
        onManaChanged()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end
        if spellCostsMana(powerType, arg3) then startFSR() end
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
        lastMana = readMana() or 0
        pending = nil
        fire()
    end
end))
