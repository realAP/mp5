-- Prueft die Anzeige selbst, ohne Spiel.
--
-- Der Trick: die nachgebauten Rahmen beantworten *jeden* Methodenaufruf.
-- Was nicht eigens nachgebaut ist, wird mitgeschrieben und gibt nichts
-- zurueck. Damit laesst sich UI.lua laden und zeichnen, ohne 60 Methoden
-- von Hand nachzubauen - und ein Tippfehler faellt hier auf statt im Spiel.

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (type(got) == "number" and type(want) == "number" and math.abs(got - want) < 0.01)
  if not ok then fails = fails + 1 end
  print(string.format("%-52s %-14s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

-- Rahmen, die alles koennen -------------------------------------------------

local frames = {}

local function newFrame(kind, name, parent)
  local f = { kind = kind, name = name, parent = parent,
              points = {}, scripts = {}, kids = {}, shown = true, alpha = 1 }

  local real = {
    SetPoint      = function(self, ...) self.points[#self.points + 1] = { ... } end,
    ClearAllPoints= function(self) self.points = {} end,
    SetSize       = function(self, w, h) self.w, self.h = w, h end,
    SetWidth      = function(self, w) self.w = w end,
    SetHeight     = function(self, h) self.h = h end,
    GetWidth      = function(self) return self.w or 0 end,
    GetHeight     = function(self) return self.h or 0 end,
    SetScript     = function(self, e, fn) self.scripts[e] = fn end,
    GetScript     = function(self, e) return self.scripts[e] end,
    SetText       = function(self, t) self.text = t end,
    GetText       = function(self) return self.text end,
    SetTexture    = function(self, p) self.texture = p end,
    SetAlpha      = function(self, a) self.alpha = a end,
    GetAlpha      = function(self) return self.alpha end,
    Show          = function(self) self.shown = true end,
    Hide          = function(self) self.shown = false end,
    IsShown       = function(self) return self.shown end,
    SetValue      = function(self, v) self.value = v end,
    GetValue      = function(self) return self.value end,
    GetFont       = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
    GetName       = function(self) return self.name end,
    GetPoint      = function(self) return "CENTER", nil, "CENTER", 0, 0 end,
    CreateTexture = function(self, n, layer)
      local t = newFrame("Texture", n, self)
      t.layer = layer
      self.kids[#self.kids + 1] = t
      return t
    end,
    CreateFontString = function(self, n, layer, template)
      local t = newFrame("FontString", n, self)
      self.kids[#self.kids + 1] = t
      return t
    end,
  }

  -- Alles Uebrige: tut nichts, zaehlt aber mit.
  f.calls = {}
  setmetatable(f, {
    __index = function(t, k)
      if real[k] then return real[k] end
      return function(self, ...)
        t.calls[k] = (t.calls[k] or 0) + 1
      end
    end,
  })
  frames[#frames + 1] = f
  return f
end

_G = _G or {}
UIParent = newFrame("Frame", "UIParent")
CreateFrame = function(kind, name, parent, template)
  local f = newFrame(kind, name, parent)
  if name then _G[name] = f end
  return f
end

GameTooltip = newFrame("Frame", "GameTooltip")
GameTooltip.lines = {}
GameTooltip.AddLine = function(self, text) self.lines[#self.lines + 1] = text end
GameTooltip.AddDoubleLine = function(self, a, b) self.lines[#self.lines + 1] = a .. "|" .. b end
GameTooltip.ClearLines = function(self) self.lines = {} end

-- Spiel-API ------------------------------------------------------------------

local now, protectedMana = 0, true

GetTime      = function() return now end
UnitPower    = function() if protectedMana then error("secret", 0) end return 500 end
UnitPowerMax = function() return 1000 end
GetManaRegen = function() return 10, 2 end
UnitPowerType = function() return 0 end
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
Enum = { PowerType = { Mana = 0 } }
GetSpellPowerCost = function() return { { type = 0, cost = 100 } } end
GetSpellInfo = function(q) return q, nil, "ICON", 1500, nil, nil, 585 end
IsUsableSpell = function() return true end
GetSpellBookItemName = function(i) if i == 1 then return "Blitzheilung", "Rang 1" end end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local ns = { db = {
  point = "CENTER", x = 0, y = 0, locked = false,
  scale = 1, width = 150, fontSize = 16,
  backdrop = "blizzard", bar = "thin", barDir = "fill",
  showLabel = false, showFull = true, showCountdown = true,
  tooltip = true, decimals = 0, animate = false,
  showSpells = true, spells = { "Blitzheilung" }, iconSize = 24,
  countAnchor = "topright", visibility = "always",
  estimate = true, showLogo = false, showResetButton = true,
} }

local marked = 0
ns.MarkManaFull = function() marked = marked + 1 end
ns.UpdateVisibility = function() end

local src = os.getenv("MP5_SRC") or "MP5"
local ok, err = pcall(function()
  assert(loadfile(src .. "/Core.lua"))("MP5", ns)
  assert(loadfile(src .. "/Spells.lua"))("MP5", ns)
  assert(loadfile(src .. "/Estimate.lua"))("MP5", ns)
  assert(loadfile(src .. "/UI.lua"))("MP5", ns)
  assert(loadfile(src .. "/Debug.lua"))("MP5", ns)
end)
check("Anzeige laedt ohne Fehler", ok and "ja" or tostring(err), "ja")

local ok2, err2 = pcall(ns.ResolveSpells)
check("Zauber aufloesen laeuft durch", ok2 and "ja" or tostring(err2), "ja")

local ok3, err3 = pcall(ns.ApplyLayout)
check("Layout laeuft durch", ok3 and "ja" or tostring(err3), "ja")

local ok4, err4 = pcall(ns.Redraw)
check("Zeichnen laeuft durch", ok4 and "ja" or tostring(err4), "ja")

-- Der Rahmen waechst mit den Icons -------------------------------------------

local frame = ns.frame
local before = frame.w
ns.db.iconSize = 48
ns.ApplyLayout()
check("schmaler Rahmen bei kleinen Icons", before, 150)
check("breiter Rahmen bei grossen Icons", frame.w >= 48 + 12, true)
ns.db.iconSize = 24
ns.ApplyLayout()

-- Der Knopf "Mana ist voll" ---------------------------------------------------

local fullBtn
for i = 1, #frames do
  local f = frames[i]
  if f.kind == "Button" and f.scripts["OnClick"] and f.parent == frame then
    fullBtn = f
  end
end
check("Knopf ist angelegt", fullBtn ~= nil, true)

-- Das Symbol muss sagen, was der Klick tut - nicht das Addon-Zeichen sein.
local icon
for i = 1, #frames do
  local t = frames[i]
  if t.kind == "Texture" and t.parent == fullBtn and t.layer == "ARTWORK" then
    icon = t.texture
  end
end
check("Knopf traegt das Nachfuell-Symbol", icon,
      "Interface\\AddOns\\MP5\\Textures\\refill.tga")

-- Mana wird gerechnet (der Client schuetzt es) -> Knopf sichtbar
ns.Redraw()
check("Mana kommt aus dem Modell", ns.Core:ManaSource(), "modell")
check("Knopf ist sichtbar", fullBtn.shown, true)

fullBtn.scripts["OnClick"](fullBtn)
check("Klick meldet volles Mana", marked, 1)

-- Nach dem Anker ist der Wert exakt: der Knopf wird blass, bleibt aber da.
ns.Estimate:MarkFull()
ns.Redraw()
check("exakter Wert -> Knopf blass", fullBtn.alpha < 0.5, true)

-- Abschaltbar
ns.db.showResetButton = false
ns.Redraw()
check("abgeschaltet -> Knopf weg", fullBtn.shown, false)
ns.db.showResetButton = true

-- Gibt der Client das Mana direkt her, gibt es nichts zu bestaetigen.
protectedMana = false
ns.Core:ClearErrors()
local ok5 = pcall(ns.Redraw)
check("Zeichnen mit lesbarem Mana laeuft durch", ok5, true)
protectedMana = true

-- Das Debug-Fenster -----------------------------------------------------------

check("Fenster ist zu", ns.DebugShown(), false)
local okD, errD = pcall(ns.ShowDebug, true)
check("Fenster oeffnet ohne Fehler", okD and "ja" or tostring(errD), "ja")
check("Fenster ist offen", ns.DebugShown(), true)

local okR, errR = pcall(ns.RefreshDebug)
check("Auffrischen laeuft durch", okR and "ja" or tostring(errR), "ja")

-- Der Zustandstext muss die Quelle und den Modellwert nennen.
local shown
for i = 1, #frames do
  local f = frames[i]
  if f.kind == "FontString" and type(f.text) == "string"
     and f.text:find("Quelle", 1, true) then shown = f.text end
end
check("Zustand nennt die Quelle", shown ~= nil and shown:find("modell", 1, true) ~= nil, true)
check("Zustand nennt das Modell", shown ~= nil and shown:find("Modell", 1, true) ~= nil, true)

-- Die Mitschrift: ein gewirkter Zauber muss darin auftauchen.
ns.Estimate:MarkFull()
local entries = ns.Estimate:Log(8)
check("Mitschrift hat Eintraege", #entries > 0, true)
check("juengster Eintrag ist der Anker von Hand",
      entries[1] and entries[1].what, "Anker: von Hand")

ns.ShowDebug(false)
check("Fenster wieder zu", ns.DebugShown(), false)

-- Der Tooltip des Knopfes -----------------------------------------------------

GameTooltip:ClearLines()
fullBtn.scripts["OnEnter"](fullBtn)
check("Tooltip hat eine Ueberschrift", GameTooltip.lines[1], "Mein Mana ist jetzt voll")
local hasHint = false
for i = 1, #GameTooltip.lines do
  if tostring(GameTooltip.lines[i]):find("/mp5 voll", 1, true) then hasHint = true end
end
check("Tooltip nennt den Befehl", hasHint, true)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
