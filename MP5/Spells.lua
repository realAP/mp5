-- MP5 / Spells.lua
-- "Wie oft kann ich diesen Zauber noch am Stueck wirken?"
--
-- Die Rechnung
-- ------------
-- Waehrend man durchcastet, laeuft die 5-Sekunden-Regel permanent weiter.
-- Es gilt also die *innerhalb*-Regeneration (nur MP5-Effekte, kein Geist).
--
--   M = aktuelles Mana
--   c = Manakosten pro Zauber
--   t = Dauer eines Zaubers (mindestens globaler Cooldown)
--   r = Mana pro Sekunde waehrend des Castens  (= MP5 innerhalb / 5)
--
-- Vor dem k-ten Zauber hat man M + r*t*(k-1) Mana und muss c bezahlen:
--
--   M + r*t*(k-1) >= c*k
--   M - c         >= (k-1) * (c - r*t)
--   k             <= 1 + (M - c) / (c - r*t)
--
-- "c - r*t" sind die *Nettokosten* eines Zaubers: was er kostet, abzueglich
-- dessen, was waehrend seiner Zauberzeit zurueckkommt. Ist dieser Wert <= 0,
-- finanziert sich der Zauber selbst und man kann ihn unbegrenzt wirken.

local ADDON, ns = ...

ns.Spells = {}
local Spells = ns.Spells

local GCD = 1.5      -- kuerzer als der globale Cooldown geht kein Zauber

-- Sperre gegen geschuetzte Werte. Im Kampf gibt dieser Client auch Kosten
-- und Zauberzeit als "secret value" zurueck; damit zu rechnen bricht ab.
-- Core legt die Funktion an, fuer die Tests genuegt der Typ-Test.
local function plain(v)
    if ns.plain then return ns.plain(v) end
    return type(v) == "number" and v or nil
end

-- Reine Rechnung, ohne Spiel-API (deshalb einzeln testbar) ----------------

-- Rueckgabe: Anzahl ganzer Zauber, oder math.huge wenn der Zauber sich
-- selbst traegt. Nil, wenn eine Angabe fehlt.
function Spells.CastsLeft(mana, cost, castTime, manaPerSec)
    mana, cost = plain(mana), plain(cost)
    castTime, manaPerSec = plain(castTime), plain(manaPerSec)
    if not (mana and cost and castTime and manaPerSec) then return nil end
    if cost <= 0 then return math.huge end
    if mana < cost then return 0 end

    local t = castTime
    if t < GCD then t = GCD end

    local net = cost - manaPerSec * t          -- Nettokosten pro Zauber
    if net <= 0 then return math.huge end

    return math.floor(1 + (mana - cost) / net)
end

-- Wie lange reicht das Mana bei Dauercasten? (fuer den Tooltip)
function Spells.TimeLeft(casts, castTime)
    if not casts or casts == math.huge then return math.huge end
    local t = castTime and castTime > GCD and castTime or GCD
    return casts * t
end

-- Anbindung an die Spiel-API ----------------------------------------------

local GetSpellInfo      = GetSpellInfo
local GetSpellPowerCost = GetSpellPowerCost

-- Manakosten. GetSpellPowerCost beruecksichtigt Talente und Buffs und ist
-- der verlaessliche Weg; aelteren Clients fehlt die Funktion, dort wird die
-- Zauberbeschreibung ausgelesen.
local scanner

local function tooltipCost(spellID)
    if not spellID then return nil end
    if not scanner then
        scanner = CreateFrame("GameTooltip", "MP5ScanTooltip", nil, "GameTooltipTemplate")
        scanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    scanner:ClearLines()
    local ok = pcall(scanner.SetSpellByID, scanner, spellID)
    if not ok then return nil end
    for i = 2, scanner:NumLines() do
        local line = _G["MP5ScanTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            -- "40 Mana", "Kosten: 40 Mana", "40 mana"
            local n = text:match("(%d+)%s+[Mm]ana")
            if n then return tonumber(n) end
        end
    end
    return nil
end

-- Position eines Zaubers im Zauberbuch, fuer die Tooltip-Abfrage ohne ID.
local function bookIndex(name)
    local getName = GetSpellBookItemName
        or (C_SpellBook and C_SpellBook.GetSpellBookItemName)
    if not (getName and name) then return nil end
    local book = BOOKTYPE_SPELL or "spell"
    for i = 1, 1024 do
        local ok, n = pcall(getName, i, book)
        if not ok or not n then return nil end
        if n == name then return i, book end
    end
    return nil
end

-- Kosten aus der Zauberbeschreibung, wahlweise ueber die ID oder, wenn
-- es keine gibt, ueber die Position im Zauberbuch.
local function tooltipCostByBook(name)
    local idx, book = bookIndex(name)
    if not idx then return nil end
    if not scanner then
        scanner = CreateFrame("GameTooltip", "MP5ScanTooltip", nil, "GameTooltipTemplate")
        scanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    scanner:ClearLines()
    if not scanner.SetSpellBookItem then return nil end
    if not pcall(scanner.SetSpellBookItem, scanner, idx, book) then return nil end
    for i = 2, scanner:NumLines() do
        local line = _G["MP5ScanTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            local n = text:match("(%d+)%s+[Mm]ana")
            if n then return tonumber(n) end
        end
    end
    return nil
end

-- Rueckgabe: Kosten, Weg ("api" | "tooltip" | "zauberbuch") oder nil
local function manaCost(spellID, name)
    local fn = GetSpellPowerCost
        or (C_Spell and C_Spell.GetSpellPowerCost)
    if fn and spellID then
        local ok, costs = pcall(fn, spellID)
        if not ok then costs = nil end
        if type(costs) == "table" then
            for i = 1, #costs do
                local c = costs[i]
                -- 0 = Mana
                if c and (c.type == 0 or c.name == "MANA") then
                    local v = plain(c.cost)
                    if v then return v, "api" end
                end
            end
        end
    end

    local v = tooltipCost(spellID)
    if v then return v, "tooltip" end

    v = tooltipCostByBook(name)
    if v then return v, "zauberbuch" end

    return nil, nil
end

-- Angaben zu einem Zauber. "name" darf auch einen Rang tragen, genau wie
-- im Makro:  "Blitzheilung"  oder  "Blitzheilung(Rang 5)".
-- Ohne Rangangabe nimmt das Spiel automatisch den hoechsten gelernten Rang.
-- Rueckgabe: Tabelle oder nil, wenn der Zauber nicht bekannt ist.
-- Es gibt zwei Formen der Zauber-Abfrage:
--   alt:  GetSpellInfo(name) -> name, rank, icon, castTime(ms), ..., spellID
--   neu:  C_Spell.GetSpellInfo(name) -> Tabelle, ohne Rang (die gibt es dort
--         nicht mehr), mit castTime in Millisekunden
-- Beide werden probiert, damit das Addon auf alten wie neuen Clients laeuft.
local function rawLookup(query)
    if GetSpellInfo then
        local ok, a, b, c, d, _, _, g = pcall(GetSpellInfo, query)
        if ok and type(a) == "string" then
            return { name = a, rank = b, icon = c, castTime = d, spellID = g }
        end
        -- Neuere Clients geben hier bereits eine Tabelle zurueck.
        if ok and type(a) == "table" and a.name then
            return { name = a.name, icon = a.iconID, castTime = a.castTime,
                     spellID = a.spellID }
        end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, query)
        if ok and type(info) == "table" and info.name then
            return { name = info.name, icon = info.iconID, castTime = info.castTime,
                     spellID = info.spellID }
        end
    end
    return nil
end

function Spells:Lookup(name)
    if not name or name == "" then return nil end

    local info = rawLookup(name)

    -- Raenge gibt es auf neueren Clients nicht mehr. Schlaegt die Abfrage
    -- mit Rangangabe fehl, wird sie ohne wiederholt - sonst meldet das
    -- Addon "nicht gefunden" fuer einen Zauber, den es sehr wohl gibt.
    local strippedRank
    if not info then
        local bare = name:match("^(.-)%s*%b()%s*$")
        if bare and bare ~= "" and bare ~= name then
            info = rawLookup(bare)
            if info then strippedRank = name:match("%((.-)%)") end
        end
    end

    if not info then return nil end

    local cost, costFrom = manaCost(info.spellID, info.name)

    return {
        name      = info.name,
        rank      = (info.rank and info.rank ~= "" and info.rank) or nil,
        icon      = info.icon,
        castTime  = (plain(info.castTime) or 0) / 1000,   -- ms -> Sekunden
        cost      = cost,
        costFrom  = costFrom,
        spellID   = info.spellID,
        query     = name,
        -- Der Client kennt keine Raenge: die Angabe wurde ignoriert.
        rankIgnored = strippedRank,
    }
end

-- Alle gelernten Raenge eines Zaubers, fuer die Rangauswahl in den
-- Interface-Optionen. Rueckgabe: Liste von { rank, query, cost, castTime }.
function Spells:Ranks(name)
    local out = {}
    if not name or name == "" then return out end

    if not (GetSpellInfo and GetSpellBookItemName) then return out end
    local wanted = GetSpellInfo(name)
    if not wanted then return out end

    local book = BOOKTYPE_SPELL or "spell"
    local i = 1
    while true do
        local n, rank = GetSpellBookItemName(i, book)
        if not n then break end
        if n == wanted then
            local query = (rank and rank ~= "") and (n .. "(" .. rank .. ")") or n
            local info = Spells:Lookup(query)
            if info then
                out[#out + 1] = {
                    rank     = rank,
                    query    = query,
                    cost     = info.cost,
                    castTime = info.castTime,
                }
            end
        end
        i = i + 1
    end
    return out
end

-- Ersatz, wenn das aktuelle Mana nicht lesbar ist ---------------------------
--
-- Das Spiel beantwortet die Frage "reicht mein Mana fuer diesen Zauber?"
-- selbst, ohne den Wert herauszugeben. Das ergibt keine Stueckzahl, aber
-- immerhin die Grenze: ab wann geht dieser Zauber nicht mehr.
--
-- Rueckgabe: true = bezahlbar, false = zu wenig Mana, nil = nicht feststellbar
function Spells:Affordable(info)
    if not info then return nil end

    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable, noPower = pcall(C_Spell.IsSpellUsable,
            info.spellID or info.name)
        if ok and usable ~= nil then
            if noPower then return false end
            return usable and true or false
        end
    end

    if IsUsableSpell then
        local ok, usable, noMana = pcall(IsUsableSpell, info.query or info.name)
        if ok and usable ~= nil then
            if noMana then return false end
            return usable and true or false
        end
    end

    return nil
end

