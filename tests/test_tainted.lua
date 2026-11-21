-- Prueft den Kampf-Fall dieses Clients: ausserhalb des Kampfes sind
-- Maximalmana und GetManaRegen lesbar, IM KAMPF sind sie geschuetzt.
--
-- Ein geschuetzter Wert sieht wie eine Zahl aus (type() sagt "number"),
-- bricht aber bei jeder Rechnung und jedem Vergleich ab. Hier wird genau
-- so ein Wert nachgebaut: keine Stelle im Addon darf mit ihm rechnen, und
-- nichts darf einen Fehler werfen - es muss einfach keine Zahl herauskommen.

local realType = type

-- Der geschuetzte Wert: jede Rechnung und jeder Vergleich bricht ab.
local function boom() error("attempt to perform arithmetic on a secret number value", 0) end
local SECRET = setmetatable({}, {
    __add = boom, __sub = boom, __mul = boom, __div = boom,
    __lt  = boom, __le  = boom, __unm = boom,
})

-- Der Client behauptet, es sei eine Zahl.
type = function(v)
    if v == SECRET then return "number" end
    return realType(v)
end

local inCombat = false
local now = 0

GetTime      = function() return now end
UnitPower    = function() error("secret number value", 0) end
UnitPowerMax = function() if inCombat then return SECRET end return 1000 end
GetManaRegen = function()
    if inCombat then return SECRET, SECRET end
    return 10, 2
end
Enum = { PowerType = { Mana = 0 } }
CreateFrame = function()
  return {
    RegisterUnitEvent = function() end,
    RegisterEvent = function() end,
    SetScript = function() end,
  }
end

local ns = {}
local src = os.getenv("MP5_SRC") or "MP5"
assert(loadfile(src .. "/Auras.lua"))("MP5", ns)
assert(loadfile(src .. "/Core.lua"))("MP5", ns)
assert(loadfile(src .. "/Spells.lua"))("MP5", ns)
assert(loadfile(src .. "/Estimate.lua"))("MP5", ns)
local Core, Spells = ns.Core, ns.Spells

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (realType(got) == "number" and realType(want) == "number"
        and math.abs(got - want) < 0.01)
  if not ok then fails = fails + 1 end
  print(string.format("%-52s %-12s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

-- Ruft fn auf und meldet, ob es ohne Fehler durchlief.
local function safe(fn, ...)
  local ok, a, b = pcall(fn, ...)
  if not ok then return "FEHLER: " .. tostring(a) end
  return a, b
end

-- Die Sperre selbst -----------------------------------------------------------

check("geschuetzter Wert wird erkannt", ns.plain(SECRET), nil)
check("echte Zahl geht durch", ns.plain(42), 42)
check("nil bleibt nil", ns.plain(nil), nil)

-- Ausserhalb des Kampfes ------------------------------------------------------

check("ausserhalb: MP5 ausserhalb der Regel", safe(Core.GetMP5, Core, false), 50)
check("ausserhalb: MP5 beim Casten", safe(Core.GetMP5, Core, true), 10)
check("ausserhalb: Maximalmana", safe(Core.GetMaxMana, Core), 1000)
check("ausserhalb: hat Mana", safe(Core.HasMana, Core), true)

-- Im Kampf --------------------------------------------------------------------

inCombat = true

-- Der zuletzt gelesene Wert gilt weiter: im Kampf ist er die beste
-- Auskunft, die es gibt, und besser als ein "?" fuer den ganzen Kampf.
check("im Kampf: letzter bekannter MP5-Wert gilt weiter",
      safe(Core.GetMP5, Core, false), 50)
check("im Kampf: Quelle sagt das auch",
      select(2, safe(Core.GetMP5, Core, false)), "zuletzt")
check("im Kampf: ebenso fuer die Cast-Stufe", safe(Core.GetMP5, Core, true), 10)
check("im Kampf: Maximalmana ist geschuetzt", safe(Core.GetMaxMana, Core), nil)
check("im Kampf: Anzeige bleibt trotzdem erlaubt", safe(Core.HasMana, Core), true)
check("im Kampf: Mana wird nicht direkt gelesen",
      select(3, safe(Core.GetMana, Core)) ~= "api", true)

-- Das Modell laeuft im Kampf weiter --------------------------------------------
--
-- Maximalmana und Regeneration sind im Kampf geschuetzt, aber beide waren
-- vorher bekannt. Das Modell rechnet mit dem letzten Stand weiter, statt
-- auszusetzen - genau dann braucht man die Zahl ja.

inCombat = false
now = 100
check("ausserhalb: Modell startet bei 0", safe(ns.Estimate.Get, ns.Estimate), 0)

inCombat = true
now = 110
check("im Kampf: Modell rechnet weiter (10/s mal 10s)",
      safe(ns.Estimate.Get, ns.Estimate), 100)
now = 120
ns.Estimate:Get()
check("und weiter", safe(ns.Estimate.Get, ns.Estimate), 200)

-- Die Stueckzahl --------------------------------------------------------------
--
-- Egal welcher der vier Werte geschuetzt ist: keine Zahl, kein Fehler.

check("Stueckzahl mit geschuetztem Mana",
      safe(Spells.CastsLeft, SECRET, 100, 1.5, 2), nil)
check("Stueckzahl mit geschuetzten Kosten",
      safe(Spells.CastsLeft, 1000, SECRET, 1.5, 2), nil)
check("Stueckzahl mit geschuetzter Zauberzeit",
      safe(Spells.CastsLeft, 1000, 100, SECRET, 2), nil)
check("Stueckzahl mit geschuetzter Regeneration",
      safe(Spells.CastsLeft, 1000, 100, 1.5, SECRET), nil)
check("Stueckzahl mit lauter echten Zahlen",
      safe(Spells.CastsLeft, 1000, 100, 1.5, 2), 10)

-- Und nach dem Kampf muss es wieder gehen -------------------------------------

inCombat = false
check("nach dem Kampf wieder eine Zahl", safe(Core.GetMP5, Core, false), 50)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
