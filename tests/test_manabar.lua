-- Prueft, dass das aktuelle Mana aus dem Text der Standard-Manaleiste
-- gelesen wird, wenn der Client den Wert selbst schuetzt.

local now = 0
local barText = nil

GetTime      = function() return now end
UnitPower    = function() error("secret number value", 0) end   -- geschuetzt
UnitPowerMax = function() return 1435 end
GetManaRegen = function() return 10, 2.4 end
Enum = { PowerType = { Mana = 0 } }
CreateFrame = function()
  return {
    RegisterUnitEvent = function() end,
    RegisterEvent = function() end,
    SetScript = function() end,
  }
end
PlayerFrameManaBarText = { GetText = function() return barText end }

local ns = {}
assert(loadfile((os.getenv("MP5_SRC") or "MP5") .. "/Core.lua"))("MP5", ns)
local Core = ns.Core

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (type(got) == "number" and type(want) == "number" and math.abs(got - want) < 0.01)
  if not ok then fails = fails + 1 end
  print(string.format("%-46s %-12s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

check("direkter Zugriff ist geschuetzt", Core:ManaReadable(), false)

-- "1234 / 1435"
barText = "1234 / 1435"
local v, approx, src = Core:GetMana()
check("Zahlen: Wert", v, 1234)
check("Zahlen: nicht gerundet", approx, false)
check("Zahlen: Quelle", src, "text")

-- Mit Tausenderpunkt, wie im deutschen Client
barText = "1.234 / 1.435"
check("Tausenderpunkt", (Core:GetMana()), 1234)

-- Prozent: mit dem lesbaren Maximalmana umrechnen
barText = "47%"
v, approx, src = Core:GetMana()
check("Prozent: 47% von 1435", v, 674.45)
check("Prozent: als gerundet markiert", approx, true)
check("Prozent: Quelle", src, "prozent")

barText = "47,5%"
check("Prozent mit Komma", (Core:GetMana()), 681.625)

-- Beides gleichzeitig: die Zahlen gewinnen, sie sind genauer
barText = "1234 / 1435 (86%)"
v, approx = Core:GetMana()
check("Zahlen und Prozent: Zahlen gewinnen", v, 1234)
check("  und gelten als genau", approx, false)

-- Nur eine Zahl
barText = "1234"
check("einzelne Zahl", (Core:GetMana()), 1234)

-- Nichts zu holen
barText = ""
check("leerer Text", (Core:GetMana()), nil)
barText = nil
check("kein Text", (Core:GetMana()), nil)
check("dann auch keine Quelle", Core:ManaSource(), nil)
check("und nichts verfuegbar", Core:ManaAvailable(), false)

-- Mit Text ist wieder etwas verfuegbar, auch wenn die API schweigt
barText = "900 / 1435"
check("mit Text wieder verfuegbar", Core:ManaAvailable(), true)

-- ManaSource muss genau EINEN Wert liefern. Gab readMana nichts her,
-- lieferte select(3, ...) gar nichts - und tostring() ohne Argument
-- bricht ab ("bad argument #1 to 'tostring'").
barText = nil
check("ManaSource liefert genau einen Wert", select("#", Core:ManaSource()), 1)
check("  und tostring darauf geht", tostring(Core:ManaSource()), "nil")
barText = "900 / 1435"
check("mit Text ebenfalls genau einer", select("#", Core:ManaSource()), 1)

-- Die Zauber-Rechnung bekommt damit wieder eine Zahl
local spells = {}
assert(loadfile((os.getenv("MP5_SRC") or "MP5") .. "/Spells.lua"))("MP5", spells)
local casts = spells.Spells.CastsLeft(Core:GetMana(), 155, 1.5, 2.4)
check("Stueckzahl wieder berechenbar", casts, 5)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
