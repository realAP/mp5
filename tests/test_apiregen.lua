-- Prueft, dass beide Stufen aus GetManaRegen() gelesen werden, wenn der
-- Client zwei verschiedene Werte liefert - der Fall auf Clients, die den
-- Manawert schuetzen und auf denen nicht gemessen werden kann.

local now = 0
local handler
local regenBase, regenCasting = 10, 2.4    -- Mana pro Sekunde

GetTime      = function() return now end
UnitPower    = function() error("secret number value", 0) end   -- geschuetzt
UnitPowerMax = function() return 1435 end
GetManaRegen = function() return regenBase, regenCasting end
Enum = { PowerType = { Mana = 0 } }
CreateFrame = function()
  return {
    RegisterUnitEvent = function() end,
    RegisterEvent = function() end,
    SetScript = function(_, _, fn) handler = fn end,
  }
end

local ns = {}
assert(loadfile((os.getenv("MP5_SRC") or "MP5") .. "/Core.lua"))("MP5", ns)
local Core = ns.Core

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (type(got) == "number" and type(want) == "number" and math.abs(got - want) < 0.001)
  if not ok then fails = fails + 1 end
  print(string.format("%-50s %-10s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

local function at(t) now = t end

at(0)
check("Manawert ist nicht lesbar", Core:ManaReadable(), false)

-- Beide Stufen kommen aus den zwei Rueckgaben, unabhaengig vom Zustand
check("ausserhalb der Regel: 10/s -> 50", (Core:GetMP5(false)), 50)
check("innerhalb der Regel:  2.4/s -> 12", (Core:GetMP5(true)), 12)
check("Quelle ist die API", select(2, Core:GetMP5(false)), "api")

-- Der Timer laeuft ueber das Cast-Event, nicht ueber das Mana
at(10)
handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 585)
check("Zauber startet die Regel", Core:InFSR() and 1 or 0, 1)
check("aktueller Wert ist jetzt der Cast-Wert", (Core:GetCurrent()), 12)
at(15.1)
check("nach Ablauf wieder der volle Wert", (Core:GetCurrent()), 50)

-- Liefert der Client zweimal denselben Wert, ist nur der aktuelle
-- Zustand bekannt - dann darf die andere Stufe nicht geraten werden.
regenCasting = regenBase
at(20)
check("gleiche Rueckgaben: aktueller Zustand bekannt", (Core:GetMP5(false)), 50)
check("gleiche Rueckgaben: andere Stufe unbekannt", (Core:GetMP5(true)), nil)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
