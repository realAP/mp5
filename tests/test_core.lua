-- Minimal-Stub der WoW-API, um die Messlogik in Core.lua zu pruefen.
local now, mana, maxMana = 0, 1000, 5000
local handler

GetTime       = function() return now end
UnitPower     = function() return mana end
UnitPowerMax  = function() return maxMana end
GetManaRegen  = function() return 3 end      -- 15 MP5
Enum = { PowerType = { Mana = 0 } }
CreateFrame = function()
  return {
    RegisterUnitEvent = function() end,
    RegisterEvent = function() end,
    SetScript = function(self, _, fn) handler = fn end,
  }
end

local ns = {}
assert(loadfile((os.getenv("MP5_SRC") or "MP5") .. "/Core.lua"))("MP5", ns)
local Core = ns.Core

local function at(t) now = t end
local function power(delta) mana = mana + delta; handler(nil, "UNIT_POWER_UPDATE", "player", "MANA") end

local fails = 0
local function check(name, got, want)
  local ok = math.abs((got or -999) - want) < 0.001
  if not ok then fails = fails + 1 end
  print(string.format("%-46s %-8s erwartet %s", name, tostring(got), tostring(want)), ok and "OK" or "FEHLER")
end

at(0); handler(nil, "PLAYER_ENTERING_WORLD")

-- Regen ausserhalb der 5-Sek-Regel: +40 alle 2s  ->  100 MP5
at(2); power(40)
at(4); power(40)
check("ausserhalb FSR gemessen", (Core:GetMP5(false)), 100)

-- Zauber bei t=5 -> FSR bis t=10
at(5); power(-200)
check("in FSR?", Core:InFSR() and 1 or 0, 1)
check("Restzeit", Core:FSRRemaining(), 5)

-- Ticks in der FSR: nur Buff-Anteil, +10 alle 2s -> 25 MP5
at(6); power(10)
at(8); power(10)
check("innerhalb FSR gemessen", (Core:GetMP5(true)), 25)
check("aktueller Wert (in FSR)", (Core:GetCurrent()), 25)
check("voller Wert weiter bekannt", (Core:GetFull()), 100)

-- Trank mitten drin darf die Messung nicht verfaelschen
at(9); power(1500)
check("Trank ignoriert", (Core:GetMP5(true)), 25)

-- Nach Ablauf der FSR wieder voller Wert
at(11)
check("nach FSR wieder voll", (Core:GetCurrent()), 100)

-- Null-Regeneration muss als 0 ankommen
at(20); power(-100)      -- neue FSR bis 25
at(21); power(0)
at(22); power(0)
mana = mana - 0
at(21.5)
check("Messwert bleibt ueber die FSR hinaus gueltig", (Core:GetMP5(true)), 25)

-- Am Manamaximum wird nicht gemessen (Tick waere abgeschnitten)
mana = maxMana
at(30); power(0)
at(32); power(0)
print(fails == 0 and "\nAlle Tests bestanden." or ("\n" .. fails .. " Test(s) fehlgeschlagen."))
os.exit(fails == 0 and 0 or 1)
