-- Prueft das Mana-Modell: Kosten abziehen, Regeneration dazu, Anker bei
-- vollem Tank, Schranken aus der Bezahlbarkeit.
--
-- Die zentrale Eigenschaft ist, dass der Wert eine Untergrenze ist: er darf
-- nie ueber dem echten Mana liegen. Der letzte Test laesst eine Simulation
-- mit echtem Mana und Modell nebeneinander laufen und prueft genau das.

local now = 0

GetTime      = function() return now end
UnitPower    = function() error("secret number value", 0) end   -- geschuetzt
UnitPowerMax = function() return 1000 end
GetManaRegen = function() return 0, 0 end
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
assert(loadfile(src .. "/Core.lua"))("MP5", ns)
assert(loadfile(src .. "/Estimate.lua"))("MP5", ns)
local Est = ns.Estimate

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (type(got) == "number" and type(want) == "number" and math.abs(got - want) < 0.01)
  if not ok then fails = fails + 1 end
  print(string.format("%-54s %-12s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

-- Fortschreiben --------------------------------------------------------------

local m = Est.NewModel(1000)
check("Startwert ist 0 (eine Untergrenze ist immer wahr)", (m:Get()), 0)
check("Startwert ist nicht exakt", select(2, m:Get()), false)

m:Advance(0, 10)          -- erster Aufruf setzt nur den Zeitpunkt
check("erster Advance rechnet nichts", (m:Get()), 0)
m:Advance(10, 10)
check("10 Sekunden bei 10/s -> 100", (m:Get()), 100)

m:Spend(40)
check("Zauber fuer 40 abgezogen", (m:Get()), 60)
m:Spend(100)
check("mehr als da ist -> 0, nicht negativ", (m:Get()), 0)

m:Advance(20, 10)
check("Regeneration laeuft weiter", (m:Get()), 100)
m:Advance(1000, 10)
check("abgeschnitten am Maximum", (m:Get()), 1000)

-- Der Volltank-Anker ---------------------------------------------------------

local a = Est.NewModel(1000)
a:Advance(0, 10)
a:Advance(100, 10)        -- 1000 aufgelaufen = genau ein Tank
check("ein Tank aufgelaufen: noch nicht exakt", select(2, a:Get()), false)
a:Advance(130, 10)        -- 1300 = Tank + Sicherheitszuschlag
check("Tank plus Zuschlag: jetzt exakt", select(2, a:Get()), true)
check("und der Wert ist das Maximum", (a:Get()), 1000)

a:Spend(200)
check("nach bekannten Kosten weiter exakt", select(2, a:Get()), true)
check("Wert stimmt", (a:Get()), 800)
a:Spend(nil)
check("unbekannte Kosten: nicht mehr exakt", select(2, a:Get()), false)
check("und es wird nichts geraten", (a:Get()), 800)

-- Der Stille-Anker -----------------------------------------------------------
--
-- Laeuft die Regeneration, kommt bei fehlendem Mana alle 2 Sekunden ein
-- Mana-Ereignis. Bleibt es still, ist der Tank voll.

local q = Est.NewModel(1000)
q:Advance(0, 10)
q:Advance(5, 10)
check("vor dem Anker nur die aufgelaufene Regeneration", (q:Get()), 50)
q:MarkFull()
check("Stille -> Tank ist voll", (q:Get()), 1000)
check("und der Wert ist exakt", select(2, q:Get()), true)
q:Spend(250)
check("ab dem Anker wird exakt weitergerechnet", (q:Get()), 750)
check("und bleibt exakt", select(2, q:Get()), true)

-- Von Hand: "mein Mana ist jetzt voll" ---------------------------------------

local h = Est.NewModel(1000)
h:Advance(0, 10)
h:Advance(3, 10)
check("vor dem Knopf nur ein Teil", (h:Get()), 30)
h:MarkFull()
check("Knopf setzt auf den Anschlag", (h:Get()), 1000)
check("und der Wert gilt als exakt", select(2, h:Get()), true)
h:Advance(13, 10)
check("danach bleibt es am Anschlag", (h:Get()), 1000)

-- Schranken aus der Bezahlbarkeit --------------------------------------------

local b = Est.NewModel(1000)
b:Advance(0, 0)
b:Clamp(300, nil)
check("Zauber fuer 300 geht -> mindestens 300", (b:Get()), 300)
b:Clamp(nil, 200)
check("Zauber fuer 200 geht nicht -> unter 200", (b:Get()), 199)
b:Clamp(nil, 500)
check("schwaechere obere Schranke aendert nichts", (b:Get()), 199)
b:Clamp(100, nil)
check("schwaechere untere Schranke aendert nichts", (b:Get()), 199)

-- Tod und Zonenwechsel -------------------------------------------------------

local c = Est.NewModel(1000)
c:Advance(0, 10)
c:Advance(200, 10)
check("vor dem Tod exakt", select(2, c:Get()), true)
c:Forget()
check("nach dem Tod wieder 0", (c:Get()), 0)
check("und nicht exakt", select(2, c:Get()), false)

-- Stufenaufstieg -------------------------------------------------------------

local d = Est.NewModel(1000)
d:Advance(0, 10)
d:Advance(200, 10)
d:SetMax(1200)
check("neues Maximum uebernommen", d.max, 1200)
check("Anker muss neu entstehen", select(2, d:Get()), false)

-- Das Modell darf nie ueber dem echten Mana liegen ---------------------------
--
-- Simulation: echtes Mana mit Regeneration, Zaubern, einem Manatrank (den
-- das Modell nicht sieht) und Clearcasting (ein Zauber kostet nichts, das
-- Modell zieht trotzdem ab).

math.randomseed(7)
local sim = Est.NewModel(1000)
local real = 1000
local rate = 12
local t = 0
sim:Advance(t, rate)
local overestimates = 0

for step = 1, 3000 do
  t = t + 0.5
  real = math.min(1000, real + rate * 0.5)
  sim:Advance(t, rate)

  local roll = math.random()
  if roll < 0.25 then
    -- normaler Zauber
    local cost = 40 + math.random(0, 200)
    if real >= cost then
      real = real - cost
      sim:Spend(cost)
    end
  elseif roll < 0.28 then
    -- Clearcasting: kostet nichts, das Modell weiss das nicht
    sim:Spend(120)
  elseif roll < 0.30 then
    -- Manatrank: bringt Mana, das das Modell nicht kennt
    real = math.min(1000, real + 300)
  end

  if sim:Get() > real + 0.01 then overestimates = overestimates + 1 end
end

check("Modell lag nie ueber dem echten Mana", overestimates, 0)

-- Nach einer langen Pause muss es wieder zusammenpassen.
t = t + 300
real = 1000
sim:Advance(t, rate)
check("nach langer Pause exakt", select(2, sim:Get()), true)
check("und gleich dem echten Mana", (sim:Get()), real)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
