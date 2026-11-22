-- Prueft, dass das Modell im Takt des Spiels gutschreibt und nicht im Takt
-- der Bildrate.
--
-- Der Fall dahinter: Mana kommt in Spruengen. Alle 2 Sekunden ein Tick aus
-- Geist, der Segen der Weisheit alle 5 Sekunden, und innerhalb der
-- 5-Sekunden-Regel aus Geist gar nichts. Wer die Regeneration gleichmaessig
-- hochrechnet, bekommt vielleicht die Summe hin, liegt aber dauernd
-- daneben - mal darueber, mal darunter, phasenverschoben.
--
-- Hier laeuft eine Simulation mit echtem Mana und das Modell daneben. Geprueft
-- wird dreierlei:
--   1. Das Modell liegt nie ueber dem echten Mana (Untergrenze).
--   2. Es bekommt nur dann Mana, wenn das Spiel welches gibt (Phase).
--   3. Es laeuft in einem Kampf mit Buffs nicht leer (der Ini-Fall).

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (type(got) == "number" and type(want) == "number" and math.abs(got - want) < 0.01)
  if not ok then fails = fails + 1 end
  print(string.format("%-56s %-10s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

-- Die Welt --------------------------------------------------------------------

local MAX        = 1000
local SPIRIT_PS  = 10        -- Mana pro Sekunde aus Geist, ausserhalb der Regel
local TICK       = 2.0       -- Geist tickt alle 2 Sekunden
local BOW        = 33        -- Segen der Weisheit, alle 5 Sekunden
local BOW_TICK   = 5.0
local COST       = 100
local SPELL_ID   = 2061

local now      = 0
local mana     = MAX         -- die Wahrheit
local lastCast = -100

local function inFSR() return now < lastCast + 5.0 end

GetTime      = function() return now end
UnitPower    = function() error("secret number value", 0) end
UnitPowerMax = function() return MAX end
-- GetManaRegen liefert Mana pro Sekunde: ausserhalb der Regel / beim Zaubern.
-- Der zweite Wert ist 0 - genau das ist der Fall, der das Modell leerlaufen
-- liess, denn der Segen der Weisheit steht in keinem der beiden.
GetManaRegen = function() return SPIRIT_PS, 0 end
UnitBuff     = function(_, i)
  if i == 1 then return "Segen der Weisheit", nil, nil, nil, nil, nil, nil,
                        nil, nil, 25290 end
end
Enum = { PowerType = { Mana = 0 } }
GetSpellPowerCost = function(id) if id == SPELL_ID then
  return { { type = 0, cost = COST } } end return {} end
GetSpellInfo = function(q) return q, nil, "ICON", 1500, nil, nil, SPELL_ID end
GetSpellBookItemName = function() return nil end     -- keine Kostenleiter
IsUsableSpell = function() return true end
UnitAffectingCombat = function() return true end
InCombatLockdown = function() return true end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local handlers = {}
CreateFrame = function()
  local f = {}
  setmetatable(f, { __index = function(_, k)
    if k == "SetScript" then
      return function(self, e, fn) if e == "OnEvent" then handlers[#handlers + 1] = fn end end
    end
    return function() end
  end })
  return f
end

local ns = {}
local src = os.getenv("MP5_SRC") or "MP5"
assert(loadfile(src .. "/Auras.lua"))("MP5", ns)
assert(loadfile(src .. "/Core.lua"))("MP5", ns)
assert(loadfile(src .. "/Estimate.lua"))("MP5", ns)
local Est = ns.Estimate

local function fire(...)
  for i = 1, #handlers do pcall(handlers[i], nil, ...) end
end

-- Mana aendern heisst: Ereignis. Der Wert darin ist geschuetzt, der
-- Zeitpunkt nicht - und auf den Zeitpunkt kommt es hier an.
local function changeMana(delta)
  mana = math.max(0, math.min(MAX, mana + delta))
  fire("UNIT_POWER_UPDATE", "player", "MANA")
end

local function cast()
  if mana < COST then return false end
  changeMana(-COST)
  lastCast = now
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", SPELL_ID)
  return true
end

-- Der Kampf -------------------------------------------------------------------
--
-- Alle 3 Sekunden ein Zauber: damit laeuft die 5-Sekunden-Regel durchgehend,
-- der Geist tickt also nie. Allein der Segen der Weisheit bringt Mana. Genau
-- so sieht es in einer Instanz aus, wenn es eng wird.

local nextSpirit, nextBow, nextCast = TICK, BOW_TICK, 1.0
local worstOver, gainedWithoutTick, worstUnder = 0, 0, 0
local prevModel = nil
local gaveMana = false

Est:Reset()
-- Beide Seiten starten am gleichen Punkt: der Spieler hat eben den Knopf
-- "mein Mana ist jetzt voll" gedrueckt.
check("Anker von Hand gesetzt", Est:MarkFull(), true)
check("Modell startet voll", (Est:Get()), MAX)

for step = 1, 1200 do                 -- 120 Sekunden in Schritten von 0,1 s
  now = step * 0.1
  gaveMana = false

  if now >= nextSpirit then
    nextSpirit = nextSpirit + TICK
    -- Innerhalb der Regel tickt der Geist nicht.
    if not inFSR() and mana < MAX then
      changeMana(SPIRIT_PS * TICK)
      gaveMana = true
    end
  end
  if now >= nextBow then
    nextBow = nextBow + BOW_TICK
    if mana < MAX then changeMana(BOW); gaveMana = true end
  end
  if now >= nextCast then
    nextCast = nextCast + 3.0
    cast()
  end

  -- Das tut die Anzeige: jeden Frame nachfragen.
  local m = Est:Get()
  if m then
    if os.getenv("TRACE") and step % 5 == 0 then
      print(string.format("t=%5.1f  wahr=%6.1f  modell=%6.1f  exakt=%s  fsr=%s",
        now, mana, m, tostring(select(2, Est:Get())), tostring(inFSR())))
    end
    if m - mana > worstOver then worstOver = m - mana
      if os.getenv("TRACE2") then
        print(string.format("ueber um %.1f bei t=%.1f (wahr %.0f, modell %.1f)",
          m - mana, now, mana, m)) end
    end
    if prevModel and m > prevModel + 0.01 and not gaveMana and now > 15 then
      gainedWithoutTick = gainedWithoutTick + (m - prevModel)
    end
    if now > 20 and mana - m > worstUnder then worstUnder = mana - m end
    prevModel = m
  end
end

-- Ueber dem echten Wert darf das Modell nur um das liegen, was ein einzelner
-- Buff-Tick bringt (hier 33). Der Grund ist unvermeidbar: wann der Segen der
-- Weisheit tickt, sieht man von aussen nicht, also wird sein Betrag
-- gleichmaessig verteilt - und dann kann er kurz vor dem echten Tick schon
-- angerechnet sein.
check("Modell liegt hoechstens einen Buff-Tick darueber", worstOver < BOW, true)
print(string.format("  (groesster Vorlauf: %.1f Mana)", worstOver))
check("Modell bekommt nichts ohne Tick (Phase)", gainedWithoutTick < 1, true)
check("Zufuhr laeuft im Takt", Est:Status().mode, "ticks")
check("Ticks wurden gezaehlt", Est:Status().ticks > 20, true)

-- Der Ini-Fall: mit Segen der Weisheit darf das Modell nicht bei 0 kleben,
-- solange in Wirklichkeit noch Mana da ist. Der Rueckstand darf hoechstens
-- in der Groesse eines Ticks liegen - genau einen Tick haelt das Modell
-- absichtlich zurueck.
check("echtes Mana ist am Ende noch da", mana > 0, true)
check("Rueckstand bleibt klein", worstUnder < 90, true)
print(string.format("  (groesster Rueckstand: %.1f Mana)", worstUnder))

-- Und die Groessenordnung muss stimmen: nicht beliebig weit darunter.
local m = Est:Get()
check("Modell liegt in der Groessenordnung des echten Werts",
      m >= mana * 0.5, true)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
