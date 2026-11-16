-- Prueft die Zauber-Rechnung aus Spells.lua gegen eine Simulation.
-- Braucht keine Spiel-API: die Rechnung ist bewusst davon getrennt.

CreateFrame = function() return {} end

local ns = {}
assert(loadfile((os.getenv("MP5_SRC") or "MP5") .. "/Spells.lua"))("MP5", ns)
local Spells = ns.Spells

local fails = 0
local function check(name, got, want)
    local ok = (got == want) or (type(got) == "number" and type(want) == "number"
                                 and math.abs(got - want) < 0.001)
    if not ok then fails = fails + 1 end
    print(string.format("%-52s %-10s erwartet %s", name, tostring(got), tostring(want)),
          ok and "OK" or "FEHLER")
end

local GCD = 1.5

-- Simulation: zahlen, dann waehrend der Zauberzeit regenerieren.
local function simulate(mana, cost, castTime, mps, limit)
    local t = castTime > GCD and castTime or GCD
    local n = 0
    while mana >= cost do
        mana = mana - cost + mps * t
        n = n + 1
        if n > (limit or 100000) then return math.huge end
    end
    return n
end

-- Beispiel aus dem Entwurf: 5000 Mana, Blitzheilung 155, 1.5s, 12 MP5 --------
local casts = Spells.CastsLeft(5000, 155, 1.5, 12 / 5)
check("Blitzheilung: 5000 Mana, 155 Kosten, 12 MP5", casts, 33)
check("  stimmt mit der Simulation ueberein", casts, simulate(5000, 155, 1.5, 12 / 5))

-- Ohne jede Regeneration ist es einfach Mana / Kosten ------------------------
check("ohne Regeneration", Spells.CastsLeft(1000, 100, 2.5, 0), 10)

-- Zauber traegt sich selbst --------------------------------------------------
check("Nettokosten 0  -> unbegrenzt", Spells.CastsLeft(1000, 15, 1.5, 10), math.huge)
check("Nettokosten < 0 -> unbegrenzt", Spells.CastsLeft(1000, 10, 3.0, 10), math.huge)

-- Nicht genug Mana fuer einen einzigen Zauber --------------------------------
check("Mana < Kosten", Spells.CastsLeft(50, 155, 1.5, 2.4), 0)
check("Mana == Kosten", Spells.CastsLeft(155, 155, 1.5, 2.4), 1)

-- Sofortzauber rechnen mit dem globalen Cooldown, nicht mit 0 Sekunden -------
local instant = Spells.CastsLeft(1000, 100, 0, 10)      -- 10 MP/s * 1.5s = 15
check("Sofortzauber nutzt den GCD", instant, simulate(1000, 100, 0, 10))
check("  und ist damit mehr als Mana/Kosten", instant > 10, true)

-- Laengere Zauberzeit bringt mehr Regeneration pro Zauber -------------------
local kurz = Spells.CastsLeft(3000, 200, 1.5, 20)
local lang = Spells.CastsLeft(3000, 200, 3.0, 20)
check("laengerer Zauber -> mehr Wirkungen", lang > kurz, true)
check("  (Simulation kurz)", kurz, simulate(3000, 200, 1.5, 20))
check("  (Simulation lang)", lang, simulate(3000, 200, 3.0, 20))

-- Gegen die Simulation ueber viele zufaellige Faelle ------------------------
math.randomseed(20261116)
local mismatch = 0
for _ = 1, 500 do
    local mana = math.random(100, 12000)
    local cost = math.random(20, 600)
    local ct   = math.random(0, 40) / 10
    local mps  = math.random(0, 200) / 10
    local got  = Spells.CastsLeft(mana, cost, ct, mps)
    local want = simulate(mana, cost, ct, mps, 50000)
    if got ~= want then mismatch = mismatch + 1 end
end
check("500 Zufallsfaelle gegen die Simulation", mismatch, 0)

-- Restzeit -------------------------------------------------------------------
check("Restzeit bei 10 Zaubern a 2s", Spells.TimeLeft(10, 2.0), 20)
check("Restzeit nutzt den GCD", Spells.TimeLeft(10, 0), 15)

print("")
if fails == 0 then
    print("Alle Tests bestanden.")
else
    print(fails .. " Test(s) fehlgeschlagen.")
    os.exit(1)
end
