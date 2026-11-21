-- Prueft das Mana aus periodischen Buffs (Segen der Weisheit, Manaquelle).
--
-- Der Fall, der dahintersteckt: in einer Gruppeninstanz heilt man durch,
-- und innerhalb der 5-Sekunden-Regel meldet GetManaRegen() 0. Ohne die
-- Buffs zieht das Modell dann nur noch ab und steht nach einer Minute bei
-- 0, obwohl in Wirklichkeit staendig Mana nachkommt.

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (type(got) == "number" and type(want) == "number" and math.abs(got - want) < 0.01)
  if not ok then fails = fails + 1 end
  print(string.format("%-54s %-12s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

-- Spiel-API -------------------------------------------------------------------

local now = 0
GetTime = function() return now end
CreateFrame = function()
  local f = {}
  setmetatable(f, { __index = function() return function() end end })
  return f
end

-- Die Buffs, die gerade auf dem Spieler liegen: { name, spellId }
local buffs = {}
UnitBuff = function(unit, i)
  local b = buffs[i]
  if not b then return nil end
  return b[1], nil, nil, nil, nil, nil, nil, nil, nil, b[2]
end

local regenBase, regenCasting = 10, 0   -- Mana pro Sekunde
GetManaRegen = function() return regenBase, regenCasting end
UnitPowerMax = function() return 1000 end
UnitPower    = function() error("secret", 0) end
Enum = { PowerType = { Mana = 0 } }
GetSpellPowerCost = function() return { { type = 0, cost = 100 } } end
GetSpellInfo = function(q) return q, nil, "ICON", 1500, nil, nil, 585 end
IsUsableSpell = function() return true end
GetSpellBookItemName = function() return nil end
UnitAffectingCombat = function() return false end
InCombatLockdown = function() return false end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local ns = {}
local src = os.getenv("MP5_SRC") or "MP5"
assert(loadfile(src .. "/Auras.lua"))("MP5", ns)
assert(loadfile(src .. "/Core.lua"))("MP5", ns)
assert(loadfile(src .. "/Estimate.lua"))("MP5", ns)

local Auras, Core, Est = ns.Auras, ns.Core, ns.Estimate

-- Erkennung -------------------------------------------------------------------

check("ohne Buffs kommt nichts dazu", (Auras:ExtraMP5()), 0)
check("ohne Buffs keine Beschreibung", Auras:Describe(), nil)

buffs = { { "Segen der Weisheit", 25290 } }      -- Rang 6
Auras:Forget()
check("Segen der Weisheit Rang 6", (Auras:ExtraMP5()), 33)

buffs[2] = { "Manaquelle", 10496 }               -- Rang 4
Auras:Forget()
check("dazu die Manaquelle", (Auras:ExtraMP5()), 33 + 25)
local what, total = Auras:Describe()
check("Beschreibung nennt beide", what, "Segen der Weisheit 33, Manaquelle 25")
check("Beschreibung nennt die Summe", total, 58)

-- Unbekannter Rang: der Name traegt, mit dem kleinsten Betrag.
buffs = { { "Segen der Weisheit", 999999 } }
Auras:Forget()
check("unbekannter Rang faellt auf den Namen zurueck", (Auras:ExtraMP5()), 10)

-- Buffs, die kein Mana geben, zaehlen nicht mit.
buffs = { { "Macht", 25291 }, { "Seelenstein", 20765 } }
Auras:Forget()
check("fremde Buffs zaehlen nicht", (Auras:ExtraMP5()), 0)

-- Der Puffer haelt kurz, aendert das Ergebnis aber nicht dauerhaft.
buffs = { { "Segen der Weisheit", 25290 } }
check("gepuffert: noch der alte Wert", (Auras:ExtraMP5()), 0)
now = now + 1
check("nach dem Puffer der neue Wert", (Auras:ExtraMP5()), 33)

-- Core zaehlt sie zur API-Auskunft dazu ---------------------------------------

-- Ausserhalb der 5-Sekunden-Regel: 10/s = 50 MP5, plus 33 aus dem Segen.
local v, source = Core:GetMP5(false)
check("Quelle ist die API", source, "api")
check("MP5 enthaelt den Segen", v, 50 + 33)

-- Das ist der eigentliche Fall: im Kampf meldet die API 0, der Segen tickt
-- trotzdem weiter.
regenCasting = 0
local vf, sf = Core:GetMP5(true)
check("waehrend des Zauberns bleibt der Segen", vf, 33)
check("auch dort eine Quelle", sf ~= nil, true)

-- Gibt der Client gar nichts her, ist der Buff die ganze Auskunft.
GetManaRegen = nil
assert(loadfile(src .. "/Core.lua"))("MP5", ns)
Core = ns.Core
local vb, sb = Core:GetMP5(true)
check("ohne API tragen allein die Buffs", vb, 33)
check("Quelle heisst buffs", sb, "buffs")

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
