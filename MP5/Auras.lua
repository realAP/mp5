-- MP5 / Auras.lua
-- Mana, das von Buffs kommt und in GetManaRegen() nicht auftaucht.
--
-- Warum das ueberhaupt noetig ist
-- -------------------------------
-- GetManaRegen() liefert die Regeneration, die aus dem *Attribut* Geist
-- entsteht, plus "Mana pro 5 Sek." von Ausruestung. Segen der Weisheit und
-- die Manaquelle des Schamanen arbeiten anders: sie sind periodische Effekte,
-- die alle paar Sekunden einen Betrag gutschreiben. Fuer die Rechnung des
-- Spiels ist das kein Regenerationswert, also steht er auch in keinem.
--
-- Solo faellt das nicht auf - diese Buffs hat man dort selten. In einer
-- Gruppeninstanz ist es der Unterschied zwischen "stimmt" und "voellig
-- daneben", und zwar aus einem unangenehmen Grund:
--
--   Innerhalb der 5-Sekunden-Regel ist die Regeneration aus Geist 0. Wer
--   durchheilt, bekommt von GetManaRegen() also die Auskunft "es kommt
--   nichts nach" - und das Modell zieht nur noch ab, bis es bei 0 steht.
--   Segen der Weisheit und die Manaquelle ticken aber waehrend der Regel
--   genauso weiter wie davor. Genau dieses Mana fehlt hier.
--
-- Die Buffs selbst sind nicht geschuetzt: welcher Buff auf einem liegt, darf
-- ein Addon lesen, auch im Kampf. Der Betrag pro Rang ist in Classic fest,
-- also steht er in der Tabelle unten.
--
-- Was hier NICHT drinsteht
-- ------------------------
-- Alles, was unregelmaessig kommt: Richturteil der Weisheit (pro Treffer),
-- Traenke, Manasteine, Aderlass, Innervieren. Dafuer gibt es den Knopf
-- "mein Mana ist jetzt voll". Und Trinken braucht es nicht: danach steht man
-- still, und dann greift der Stille-Anker von selbst.
--
-- Die Tabelle ist absichtlich zu niedrig angesetzt, wo es Unsicherheit gibt
-- (Talente wie "Verbesserter Segen der Weisheit" erhoehen den Betrag um bis
-- zu 20 %, davon sieht man von aussen nichts). Zu wenig anzunehmen bleibt
-- die sichere Richtung: die Stueckzahl verspricht dann nie mehr, als da ist.

local ADDON, ns = ...

ns.Auras = {}
local Auras = ns.Auras

local GetTime = GetTime

-- Mana pro 5 Sekunden, nach der Zauber-ID des Buffs.
local KNOWN = {
    -- Segen der Weisheit (Paladin), Rang 1-6
    [19742] = 10, [19850] = 15, [19852] = 20,
    [19853] = 25, [19854] = 30, [25290] = 33,
    -- Grosser Segen der Weisheit
    [25894] = 30, [25918] = 33,
    -- Manaquelle (Schamanen-Totem), Rang 1-4
    [5677]  = 10, [10491] = 15, [10493] = 20, [10496] = 25,
}

-- Namen als Rueckfall, wenn der Client keine Zauber-ID zum Buff liefert.
-- Dann ist der Rang unbekannt, also wird der kleinste Betrag angenommen.
local BY_NAME = {
    ["Segen der Weisheit"]         = 10,
    ["Großer Segen der Weisheit"]  = 30,
    ["Blessing of Wisdom"]         = 10,
    ["Greater Blessing of Wisdom"] = 30,
    ["Manaquelle"]                 = 10,
    ["Mana Spring"]                = 10,
}

ns.AuraTable = KNOWN

-- Buffs lesen ---------------------------------------------------------------
--
-- Drei Wege, je nach Client. Jeder Aufruf durch pcall: ein Client, der eine
-- der Funktionen anders meint, darf die Anzeige nicht mitnehmen.
local function buffAt(i)
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        local ok, d = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
        if ok then
            if not d then return nil end
            return d.name, d.spellId
        end
    end
    if UnitBuff then
        local ok, name, _, _, _, _, _, _, _, _, spellId = pcall(UnitBuff, "player", i)
        if ok then return name, spellId end
    end
    if UnitAura then
        local ok, name, _, _, _, _, _, _, _, _, spellId =
            pcall(UnitAura, "player", i, "HELPFUL")
        if ok then return name, spellId end
    end
    return nil
end

-- Ergebnis kurz puffern: die Anzeige fragt mehrmals pro Sekunde, die Buffs
-- aendern sich in Minuten.
local CACHE_TTL = 0.5
local cached, cachedAt, cachedList = 0, -1, {}

local function scan()
    local total, list = 0, {}
    for i = 1, 40 do
        local name, id = buffAt(i)
        if not name then break end
        local amount = (id and KNOWN[id]) or BY_NAME[name]
        if amount then
            total = total + amount
            list[#list + 1] = { name = name, id = id, mp5 = amount }
        end
    end
    return total, list
end

-- Mana pro 5 Sekunden aus periodischen Buffs.
-- Rueckgabe: Betrag (immer eine Zahl, 0 wenn keiner gefunden), Liste.
--
-- Dieser Betrag gilt in BEIDEN Zustaenden - innerhalb der 5-Sekunden-Regel
-- genauso wie ausserhalb. Das ist der ganze Punkt.
function Auras:ExtraMP5()
    local now = GetTime()
    if now - cachedAt < CACHE_TTL and cachedAt >= 0 then
        return cached, cachedList
    end
    local ok, total, list = pcall(scan)
    if not ok then total, list = 0, {} end
    cached, cachedList, cachedAt = total or 0, list or {}, now
    return cached, cachedList
end

-- Fuer /mp5 why und das Debug-Fenster: "Segen der Weisheit 33, Manaquelle 20"
function Auras:Describe()
    local total, list = Auras:ExtraMP5()
    if total <= 0 then return nil end
    local parts = {}
    for i = 1, #list do
        parts[#parts + 1] = list[i].name .. " " .. tostring(list[i].mp5)
    end
    return table.concat(parts, ", "), total
end

function Auras:Forget()
    cachedAt = -1
end
