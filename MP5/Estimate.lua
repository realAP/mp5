-- MP5 / Estimate.lua
-- Das aktuelle Mana selbst mitrechnen, wenn der Client es nicht herausgibt.
--
-- Der Client verraet nicht, wie viel Mana man hat - aber alles, was den Wert
-- veraendert:
--
--   Maximalmana            UnitPowerMax            lesbar
--   Regeneration           GetManaRegen            lesbar (beide Stufen)
--   gewirkte Zauber        UNIT_SPELLCAST_SUCCEEDED + GetSpellPowerCost
--
-- Daraus laesst sich der Wert fortschreiben: Kosten abziehen, Regeneration
-- dazurechnen, bei 0 und Maximalmana abschneiden.
--
-- Die Rechnung ist absichtlich eine UNTERGRENZE
-- ---------------------------------------------
-- Jeder Fehler wird so gelegt, dass das Modell zu wenig Mana annimmt, nie
-- zu viel: ein Trank, Aderlass oder Innervieren bringt Mana, das das Modell
-- nicht kennt; Clearcasting spart Kosten, die es trotzdem abzieht. Die
-- Stueckzahl in der Anzeige ist damit das, was sicher geht - sie verspricht
-- nie mehr, als da ist.
--
-- Zwei Dinge korrigieren die Drift wieder nach oben:
--
--   1. Der Volltank-Anker. Mana kann nur bis zum Maximum steigen. Ist seit
--      dem letzten Zauber so viel Regeneration aufgelaufen, dass selbst von
--      0 aus das Maximum erreicht waere, dann ist der Wert mit Sicherheit
--      das Maximum - egal wie falsch das Modell vorher lag.
--
--   2. Die Stille. Das Mana-Ereignis (UNIT_POWER_UPDATE) feuert, wenn sich
--      der Wert aendert - das ist kein geschuetzter Wert, sondern nur ein
--      Signal. Solange Mana fehlt, tickt die Regeneration alle 2 Sekunden
--      und das Ereignis kommt. Bleibt es bei laufender Regeneration mehrere
--      Sekunden still, kann nur ein Grund dahinterstecken: der Tank ist
--      voll. Damit ist der Wert schon wenige Sekunden nach dem Vollwerden
--      exakt, statt erst nach einer ganzen Tankfuellung.
--
--   3. Die Bezahlbarkeits-Schranken. Das Spiel beantwortet "reicht mein Mana
--      fuer diesen Zauber?" selbst, ohne den Wert herauszugeben. Ein Zauber,
--      der gerade geht, kostet hoechstens so viel wie das vorhandene Mana;
--      einer, der mangels Mana nicht geht, kostet mehr. Mehrere Zauber mit
--      verschiedenen Kosten klammern den Wert damit von beiden Seiten ein.
--
-- Nur wenn der Anker greift, ist der Wert exakt. Sonst ist er geschaetzt und
-- die Anzeige stellt eine Tilde davor.

local ADDON, ns = ...

ns.Estimate = {}
local Est = ns.Estimate

local GetTime      = GetTime
local UnitPowerMax = UnitPowerMax or function(u) return UnitManaMax(u) end
local MANA         = Enum and Enum.PowerType and Enum.PowerType.Mana or 0

-- Jeder Wert vom Client laeuft durch diese Sperre: im Kampf schuetzt dieser
-- Client auch das Maximalmana und die Regeneration, und ein geschuetzter
-- Wert faerbt alles ab, was aus ihm entsteht.
local plain = ns.plain or function(v) return type(v) == "number" and v or nil end

local function maxMana()
    local ok, v = pcall(UnitPowerMax, "player", MANA)
    return ok and plain(v) or nil
end

-- Sicherheitszuschlag fuer den Volltank-Anker. Die Regeneration wird aus
-- GetManaRegen() gelesen; liegt die Funktion zu hoch, waere der Anker zu
-- frueh gesetzt. Es muss also mehr aufgelaufen sein als ein voller Tank.
local ANCHOR_MARGIN = 1.25

-- Das Modell, ohne Spiel-API (deshalb einzeln testbar) --------------------

local Model = {}
Model.__index = Model

function Est.NewModel(max)
    return setmetatable({
        max      = max or 0,
        mana     = 0,        -- bewusst 0: eine Untergrenze ist immer wahr
        credit   = 0,        -- aufgelaufene Regeneration seit dem letzten Zauber
        exact    = false,    -- hat der Volltank-Anker schon gegriffen?
        last     = nil,      -- Zeitpunkt des letzten Fortschreibens
    }, Model)
end

function Model:SetMax(max)
    if type(max) ~= "number" or max <= 0 or max == self.max then return end
    self.max = max
    if self.mana > max then self.mana = max end
    -- Beim Stufenaufstieg fuellt das Spiel auf; der Anker muss neu entstehen.
    self.credit, self.exact = 0, false
end

-- Regeneration fuer die Zeit seit dem letzten Aufruf dazurechnen.
-- ratePerSec darf nil sein (unbekannt) - dann wird nichts dazugerechnet,
-- was die Untergrenze nicht verletzt.
function Model:Advance(now, ratePerSec)
    if not self.last then self.last = now return end
    local dt = now - self.last
    self.last = now
    if dt <= 0 then return end
    if not ratePerSec or ratePerSec <= 0 then return end

    local gain = ratePerSec * dt
    self.mana = self.mana + gain
    if self.mana > self.max then self.mana = self.max end

    self.credit = self.credit + gain
    if self.max > 0 and self.credit >= self.max * ANCHOR_MARGIN then
        -- Selbst von 0 aus waere der Tank jetzt voll.
        self.mana, self.exact = self.max, true
    end
end

-- Einen gewirkten Zauber verbuchen. cost = nil heisst "Kosten unbekannt":
-- dann ist der Wert danach nicht mehr exakt, und es wird nichts abgezogen.
function Model:Spend(cost)
    self.credit = 0
    if type(cost) ~= "number" then
        self.exact = false
        return
    end
    self.mana = self.mana - cost
    if self.mana < 0 then self.mana = 0 end
end

-- Der Tank ist mit Sicherheit voll (Anker von aussen).
function Model:MarkFull()
    self.mana  = self.max
    self.exact = true
    self.credit = self.max * ANCHOR_MARGIN
end

-- Mana wurde von aussen gesetzt (Tod, Zonenwechsel): alles vergessen.
function Model:Forget()
    self.mana, self.credit, self.exact = 0, 0, false
end

-- Schranken aus der Bezahlbarkeit. lower = mindestens so viel Mana ist da,
-- upper = weniger als so viel. Beide duerfen nil sein.
function Model:Clamp(lower, upper)
    if lower and lower > self.mana then
        self.mana = lower
        -- Nach oben korrigiert: der Wert war zu niedrig, also stimmte die
        -- Buchfuehrung nicht. Exakt ist er jetzt trotzdem nicht.
        self.exact = false
    end
    if upper and upper <= self.mana then
        self.mana = upper - 1
        if self.mana < 0 then self.mana = 0 end
        self.exact = false
    end
end

-- Rueckgabe: Wert, exakt?
function Model:Get()
    return self.mana, self.exact
end

-- Anbindung an das Spiel ---------------------------------------------------

local model = Est.NewModel(0)
local enabled = true

-- Kosten eines Zaubers anhand seiner ID, gepuffert. Downgeranktes Wirken
-- hat eine eigene ID, der Wert stimmt also pro Rang.
local costCache = {}

local function costOf(spellID)
    if not spellID then return nil end
    local c = costCache[spellID]
    if c ~= nil then
        if c == false then return nil end
        return c
    end

    local fn = GetSpellPowerCost or (C_Spell and C_Spell.GetSpellPowerCost)
    if fn then
        local ok, costs = pcall(fn, spellID)
        if ok and type(costs) == "table" then
            for i = 1, #costs do
                local e = costs[i]
                if e and (e.type == 0 or e.name == "MANA") and e.cost then
                    costCache[spellID] = e.cost
                    return e.cost
                end
            end
            -- Kostentabelle vorhanden, aber kein Mana darin: kostet keins.
            costCache[spellID] = 0
            return 0
        end
    end

    costCache[spellID] = false
    return nil
end

-- Die Kostenleiter fuer die Schranken: bekannte Zauber mit verschiedenen
-- Manakosten, aufsteigend. Wird nur bei Aenderungen am Zauberbuch gebaut.
local ladder = nil
local LADDER_MAX = 12

local function buildLadder()
    ladder = {}
    local getName = GetSpellBookItemName
        or (C_SpellBook and C_SpellBook.GetSpellBookItemName)
    local getInfo = GetSpellBookItemInfo
        or (C_SpellBook and C_SpellBook.GetSpellBookItemInfo)
    if not getName then return end

    local book = BOOKTYPE_SPELL or "spell"
    local seen, items = {}, {}
    for i = 1, 512 do
        local ok, n, rank = pcall(getName, i, book)
        if not ok or not n then break end

        local id
        if getInfo then
            local ok2, a, b = pcall(getInfo, i, book)
            if ok2 then
                if type(a) == "table" then id = a.spellID
                else id = tonumber(b) end
            end
        end
        if not id then
            local query = (rank and rank ~= "") and (n .. "(" .. rank .. ")") or n
            local info = ns.Spells and ns.Spells:Lookup(query)
            id = info and info.spellID
        end

        local cost = id and costOf(id)
        if cost and cost > 0 and not seen[cost] then
            seen[cost] = true
            items[#items + 1] = { cost = cost, id = id, name = n, rank = rank }
        end
    end

    table.sort(items, function(a, b) return a.cost < b.cost end)

    -- Auf LADDER_MAX Stufen ausduennen, gleichmaessig verteilt: zwoelf
    -- Abfragen pro Aktualisierung sind genug, um den Wert einzuklammern.
    if #items <= LADDER_MAX then
        ladder = items
    else
        local step = #items / LADDER_MAX
        for k = 1, LADDER_MAX do
            ladder[k] = items[math.floor((k - 0.5) * step) + 1]
        end
    end
end

-- Rueckgabe: true = bezahlbar, false = Mana reicht nicht, nil = unklar
-- (Abklingzeit, Gestalt, Reichweite - daraus folgt nichts ueber das Mana).
local function affordable(entry)
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable, noPower = pcall(C_Spell.IsSpellUsable, entry.id or entry.name)
        if ok and usable ~= nil then
            if usable then return true end
            if noPower then return false end
            return nil
        end
    end
    if IsUsableSpell then
        local query = (entry.rank and entry.rank ~= "")
            and (entry.name .. "(" .. entry.rank .. ")") or entry.name
        local ok, usable, noMana = pcall(IsUsableSpell, query)
        if ok and usable ~= nil then
            if usable then return true end
            if noMana then return false end
            return nil
        end
    end
    return nil
end

-- Untere und obere Schranke aus der Kostenleiter.
local function bounds()
    if not ladder then buildLadder() end
    local lower, upper
    for i = 1, #ladder do
        local e = ladder[i]
        local a = affordable(e)
        if a == true then
            if not lower or e.cost > lower then lower = e.cost end
        elseif a == false then
            if not upper or e.cost < upper then upper = e.cost end
        end
    end
    -- Widerspruch (z.B. durch einen Buff zwischen zwei Abfragen): die
    -- untere Schranke ist die verlaesslichere, sie kommt aus einem "geht".
    if lower and upper and upper <= lower then upper = nil end
    return lower, upper
end

local lastBounds = 0
local BOUNDS_INTERVAL = 0.4

-- Der Stille-Anker ---------------------------------------------------------
--
-- lastEvent  = wann sich das Mana zuletzt geaendert hat (Ereignis, kein Wert)
-- sawEvents  = feuert dieser Client das Ereignis ueberhaupt? Ohne diesen
--              Nachweis wuerde Stille nichts bedeuten.
-- quietFrom  = ab wann die Stille zaehlt: nach einem Zauber erst ab dem Ende
--              der 5-Sekunden-Regel, denn innerhalb der Regel kann die
--              Regeneration 0 sein und dann ist Stille normal.
local lastEvent = 0
local sawEvents = false
local quietFrom = 0
local FSR_DURATION = 5.0
local QUIET       = 3.0        -- Regeneration tickt alle 2s, mit Luft nach oben

local function regenPerSec()
    local Core = ns.Core
    if not Core then return nil end
    local mp5 = plain(Core:GetMP5(Core:InFSR()))
    return mp5 and mp5 / 5 or nil
end

-- Ist die Regeneration laufend, aber trotzdem still? Dann ist der Tank voll.
local function quietMeansFull(now)
    if not sawEvents then return false end
    local rate = regenPerSec()
    if not rate or rate <= 0 then return false end
    local since = now - (lastEvent > quietFrom and lastEvent or quietFrom)
    return since >= QUIET
end

local function refresh(now)
    model:SetMax(maxMana())
    model:Advance(now, regenPerSec())
    if quietMeansFull(now) then model:MarkFull() end
    if now - lastBounds >= BOUNDS_INTERVAL then
        lastBounds = now
        local lo, hi = bounds()
        model:Clamp(lo, hi)
    end
end

-- Aktuelles Mana aus dem Modell. Rueckgabe: Wert, exakt?
function Est:Get()
    if not enabled then return nil end
    -- Ohne Maximalmana kann das Modell nichts rechnen. Im Kampf kann der
    -- Wert verschwinden; dann bleibt der zuletzt bekannte stehen.
    if (model.max or 0) <= 0 and not maxMana() then return nil end
    refresh(GetTime())
    local v, exact = model:Get()
    return plain(v), exact
end

function Est:Enabled()  return enabled end
function Est:SetEnabled(v)
    enabled = v and true or false
    if enabled then model:Forget() end
end

function Est:Reset()
    model:Forget()
    ladder = nil
    lastEvent, quietFrom = GetTime(), GetTime()
end

-- Fuer /mp5 why: der Zustand des Modells im Klartext.
function Est:Status()
    if not ladder then buildLadder() end
    local lo, hi = bounds()
    local mana, exact = model:Get()
    return {
        enabled = enabled,
        mana    = mana,
        exact   = exact,
        credit  = model.credit,
        max     = model.max,
        rate    = regenPerSec(),
        lower   = lo,
        upper   = hi,
        ladder  = #ladder,
        -- Der Stille-Anker
        events  = sawEvents,
        quiet   = GetTime() - (lastEvent > quietFrom and lastEvent or quietFrom),
    }
end

-- Events -------------------------------------------------------------------

local f = CreateFrame("Frame")
local function reg(event, unitOnly)
    if unitOnly and f.RegisterUnitEvent then
        if pcall(f.RegisterUnitEvent, f, event, "player") then return end
    end
    pcall(f.RegisterEvent, f, event)
end

reg("UNIT_SPELLCAST_SUCCEEDED", true)
reg("UNIT_MAXPOWER", true)
reg("UNIT_POWER_UPDATE", true)
reg("UNIT_MANA", true)             -- aeltere Clients
reg("PLAYER_ENTERING_WORLD")
reg("PLAYER_DEAD")
reg("PLAYER_ALIVE")
reg("PLAYER_UNGHOST")
reg("SPELLS_CHANGED")
reg("LEARNED_SPELL_IN_TAB")

f:SetScript("OnEvent", (ns.safe or function(fn) return fn end)(function(_, event, unit, a2, a3)
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MANA" then
        if unit ~= "player" then return end
        if a2 and a2 ~= "MANA" then return end
        -- Nur das Signal wird benutzt, nicht der Wert: dass sich etwas
        -- geaendert hat, ist nicht geschuetzt.
        lastEvent = GetTime()
        sawEvents = true
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end
        local now = GetTime()
        quietFrom = now + FSR_DURATION
        model:SetMax(maxMana())
        model:Advance(now, regenPerSec())
        -- Die Signatur ist je nach Client (unit, castGUID, spellID) oder
        -- (unit, spellName, rank); die ID ist das, was eine Zahl ist.
        local id = tonumber(a3) or tonumber(a2)
        model:Spend(costOf(id))
    elseif event == "UNIT_MAXPOWER" then
        if unit ~= "player" then return end
        model:SetMax(maxMana())
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        ladder = nil
        costCache = {}
    else
        -- Tod, Auferstehung, Zonenwechsel: das Spiel setzt das Mana selbst.
        model:Forget()
        model:SetMax(maxMana())
        -- Die Stille erst ab jetzt zaehlen, sonst wuerde der Ladebildschirm
        -- als "voll" durchgehen.
        lastEvent, quietFrom = GetTime(), GetTime()
    end
end))
