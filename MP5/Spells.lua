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

-- Reine Rechnung, ohne Spiel-API (deshalb einzeln testbar) ----------------

-- Rueckgabe: Anzahl ganzer Zauber, oder math.huge wenn der Zauber sich
-- selbst traegt. Nil, wenn eine Angabe fehlt.
function Spells.CastsLeft(mana, cost, castTime, manaPerSec)
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

local function manaCost(spellID)
    if GetSpellPowerCost and spellID then
        local costs = GetSpellPowerCost(spellID)
        if type(costs) == "table" then
            for i = 1, #costs do
                local c = costs[i]
                -- 0 = Mana
                if c and (c.type == 0 or c.name == "MANA") and c.cost then
                    return c.cost
                end
            end
        end
    end
    return tooltipCost(spellID)
end

-- Angaben zu einem Zauber. "name" darf auch einen Rang tragen, genau wie
-- im Makro:  "Blitzheilung"  oder  "Blitzheilung(Rang 5)".
-- Ohne Rangangabe nimmt das Spiel automatisch den hoechsten gelernten Rang.
-- Rueckgabe: Tabelle oder nil, wenn der Zauber nicht bekannt ist.
function Spells:Lookup(name)
    if not name or name == "" then return nil end
    if not GetSpellInfo then return nil end

    local spellName, rank, icon, castTime, _, _, spellID = GetSpellInfo(name)
    if not spellName then return nil end

    return {
        name     = spellName,
        rank     = (rank ~= "" and rank) or nil,
        icon     = icon,
        castTime = (castTime or 0) / 1000,     -- ms -> Sekunden
        cost     = manaCost(spellID),
        spellID  = spellID,
        query    = name,
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
