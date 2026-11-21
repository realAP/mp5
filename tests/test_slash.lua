-- Prueft die Chatbefehle. Bisher waren sie der einzige ungetestete Weg ins
-- Addon - und genau dort steckte der Fehler, dass "/mp5 debug" das Fenster
-- nie geoeffnet hat ("x and nil or y" kann kein nil ergeben).
--
-- Geprueft wird, was ein Befehl in der Datenbank anrichtet, nicht wie die
-- Meldung lautet.

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (type(got) == "number" and type(want) == "number" and math.abs(got - want) < 0.01)
  if not ok then fails = fails + 1 end
  print(string.format("%-52s %-14s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

-- Rahmen, die jeden Aufruf annehmen ------------------------------------------

local frames = {}
local function newFrame(kind, name, parent)
  local f = { kind = kind, name = name, parent = parent,
              points = {}, scripts = {}, shown = true, alpha = 1 }
  local real = {
    SetScript = function(self, e, fn) self.scripts[e] = fn end,
    GetScript = function(self, e) return self.scripts[e] end,
    SetPoint  = function(self, ...) self.points[#self.points + 1] = { ... } end,
    ClearAllPoints = function(self) self.points = {} end,
    SetSize   = function(self, w, h) self.w, self.h = w, h end,
    SetWidth  = function(self, w) self.w = w end,
    SetText   = function(self, t) self.text = t end,
    GetText   = function(self) return self.text end,
    SetTexture= function(self, p) self.texture = p end,
    SetAlpha  = function(self, a) self.alpha = a end,
    Show      = function(self) self.shown = true end,
    Hide      = function(self) self.shown = false end,
    IsShown   = function(self) return self.shown end,
    GetFont   = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
    GetName   = function(self) return self.name end,
    GetPoint  = function(self) return "CENTER", nil, "CENTER", 0, 0 end,
    SetValue  = function(self, v) self.value = v end,
    CreateTexture = function(self, n, layer)
      local t = newFrame("Texture", n, self); t.layer = layer; return t
    end,
    CreateFontString = function(self, n) return newFrame("FontString", n, self) end,
  }
  setmetatable(f, { __index = function(t, k)
    if real[k] then return real[k] end
    return function() end
  end })
  frames[#frames + 1] = f
  return f
end

_G = _G or {}
UIParent = newFrame("Frame", "UIParent")
CreateFrame = function(kind, name, parent, template)
  local f = newFrame(kind, name, parent)
  -- Die Haken-Vorlage bringt ihre Beschriftung mit; ohne diesen Eintrag
  -- liefert der Auffang-Index eine Funktion statt nichts.
  if kind == "CheckButton" then rawset(f, "Text", newFrame("FontString", nil, f)) end
  if name then _G[name] = f end
  return f
end

GameTooltip = newFrame("Frame", "GameTooltip")

-- Spiel-API -------------------------------------------------------------------

local now = 0
GetTime      = function() return now end
UnitPower    = function() error("secret", 0) end     -- Mana ist geschuetzt
UnitPowerMax = function() return 1000 end
GetManaRegen = function() return 10, 2 end
Enum = { PowerType = { Mana = 0 } }
GetSpellPowerCost = function() return { { type = 0, cost = 100 } } end
GetSpellInfo = function(q) return q, nil, "ICON", 1500, nil, nil, 585 end
IsUsableSpell = function() return true end
GetSpellBookItemName = function(i) if i == 1 then return "Blitzheilung", "Rang 1" end end
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
SlashCmdList = {}

local said = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) said[#said + 1] = t end }

local ns = {}
local src = os.getenv("MP5_SRC") or "MP5"
local ok, err = pcall(function()
  for _, file in ipairs({ "Core", "Spells", "Estimate", "Probe", "UI", "Debug",
                          "Config", "Options" }) do
    assert(loadfile(src .. "/" .. file .. ".lua"))("MP5", ns)
  end
end)
check("alle Dateien laden", ok and "ja" or tostring(err), "ja")

-- ADDON_LOADED nachstellen, damit ns.db existiert
MP5CharDB = {}
local cfgFrame
for i = 1, #frames do
  local f = frames[i]
  if f.scripts["OnEvent"] and f.kind == "Frame" then cfgFrame = f end
end
for i = 1, #frames do
  local f = frames[i]
  if f.scripts["OnEvent"] then
    pcall(f.scripts["OnEvent"], f, "ADDON_LOADED", "MP5")
  end
end
check("Datenbank angelegt", type(ns.db), "table")

local slash = SlashCmdList["MP5"]
check("Slash-Befehl eingetragen", type(slash), "function")

local function run(cmd)
  said = {}
  local ok2, err2 = pcall(slash, cmd)
  if not ok2 then return "FEHLER: " .. tostring(err2) end
  return nil
end

-- Das Debug-Fenster ------------------------------------------------------------

check("Fenster ist am Anfang zu", ns.DebugShown(), false)
check("/mp5 debug laeuft", run("debug"), nil)
check("/mp5 debug oeffnet das Fenster", ns.DebugShown(), true)
check("/mp5 debug schliesst wieder", run("debug") or ns.DebugShown(), false)
check("/mp5 debug on oeffnet", run("debug on") or ns.DebugShown(), true)
check("/mp5 debug on bleibt offen", run("debug on") or ns.DebugShown(), true)
check("/mp5 debug off schliesst", run("debug off") or ns.DebugShown(), false)
check("Zustand wird gemerkt", ns.db.debug, false)

-- Werte setzen ------------------------------------------------------------------

check("/mp5 width setzt die Breite", run("width 240") or ns.db.width, 240)
check("/mp5 width begrenzt nach oben", run("width 900") or ns.db.width, 400)
check("/mp5 scale setzt die Groesse", run("scale 1.4") or ns.db.scale, 1.4)
check("/mp5 icon setzt die Icon-Groesse", run("icon 40") or ns.db.iconSize, 40)

check("/mp5 logo on", run("logo on") or ns.db.showLogo, true)
check("/mp5 logo off", run("logo off") or ns.db.showLogo, false)
check("/mp5 button off", run("button off") or ns.db.showResetButton, false)
check("/mp5 button on", run("button on") or ns.db.showResetButton, true)

check("/mp5 bar nimmt gueltige Werte", run("bar full") or ns.db.bar, "full")
check("/mp5 bar lehnt Unsinn ab", run("bar quatsch") or ns.db.bar, "full")

-- Das Mana-Modell ----------------------------------------------------------------

check("/mp5 estimate off", run("estimate off") or ns.db.estimate, false)
check("/mp5 estimate on", run("estimate on") or ns.db.estimate, true)

now = 10
check("/mp5 voll laeuft", run("voll"), nil)
check("/mp5 voll setzt den Anker", select(2, ns.Estimate:Get()), true)
check("danach steht das Mana am Anschlag", math.floor((ns.Estimate:Get())), 1000)

check("/mp5 estimate reset laeuft", run("estimate reset"), nil)
check("Reset vergisst den Anker", select(2, ns.Estimate:Get()), false)

-- Auskunft --------------------------------------------------------------------

check("/mp5 why laeuft durch", run("why"), nil)
check("/mp5 why sagt etwas", #said > 0, true)
check("/mp5 probe laeuft durch", run("probe"), nil)
check("/mp5 errors laeuft durch", run("errors"), nil)
check("/mp5 ohne Befehl zeigt die Hilfe", run("") or (#said > 5), true)
check("/mp5 unbekannt zeigt die Hilfe", run("gibtsnicht") or (#said > 5), true)

-- Zuruecksetzen -------------------------------------------------------------------

check("/mp5 reset laeuft", run("reset"), nil)
check("Reset stellt die Breite wieder her", ns.db.width, 150)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
