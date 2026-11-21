-- Prueft das Optionen-Panel ohne Spiel: dass es sich fehlerfrei aufbaut,
-- dass Auffrischen alle Bedienelemente erreicht und dass Klicken und
-- Ziehen die richtigen Werte speichern.
--
-- Hintergrund: ein Tippfehler in diesem Panel faellt im Spiel erst auf,
-- wenn man das Menue oeffnet - und dann als Lua-Fehler. Hier faellt er beim
-- Laden auf.

local fails = 0
local function check(name, got, want)
  local ok = (got == want)
    or (type(got) == "number" and type(want) == "number" and math.abs(got - want) < 0.001)
  if not ok then fails = fails + 1 end
  print(string.format("%-50s %-12s erwartet %s", name, tostring(got), tostring(want)),
        ok and "OK" or "FEHLER")
end

-- Ein Rahmen, der alles mitschreibt, was das Panel von ihm will ------------

local frames = {}

local function newFrame(kind, name)
  local f = {
    kind = kind, name = name, points = {}, scripts = {}, children = {},
    checked = false, text = "", value = 0,
  }
  function f:SetPoint(...)        self.points[#self.points + 1] = { ... } end
  function f:ClearAllPoints()     self.points = {} end
  function f:SetWidth(w)          self.width = w end
  function f:SetHeight(h)         self.height = h end
  function f:SetSize(w, h)        self.width, self.height = w, h end
  function f:GetName()            return self.name end
  function f:SetScript(e, fn)     self.scripts[e] = fn end
  function f:GetScript(e)         return self.scripts[e] end
  function f:SetText(t)           self.text = t end
  function f:GetText()            return self.text end
  function f:SetJustifyH()        end
  function f:SetAutoFocus()       end
  function f:ClearFocus()         end
  function f:SetChecked(v)        self.checked = v and true or false end
  function f:GetChecked()         return self.checked end
  function f:SetMinMaxValues(a, b) self.min, self.max = a, b end
  function f:SetValueStep(s)      self.step = s end
  function f:SetObeyStepOnDrag()  end
  function f:SetValue(v)
    self.value = v
    local fn = self.scripts["OnValueChanged"]
    if fn then fn(self, v) end
  end
  function f:GetValue()           return self.value end
  function f:Show()               end
  function f:Hide()               end
  function f:CreateTexture(n, layer)
    local t = newFrame("Texture", n)
    function t:SetTexture(path) self.path = path end
    function t:SetTexCoord() end
    self.children[#self.children + 1] = t
    return t
  end
  function f:CreateFontString(n, layer, template)
    local fs = newFrame("FontString", n)
    self.children[#self.children + 1] = fs
    return fs
  end
  frames[#frames + 1] = f
  return f
end

_G = _G or {}
UIParent = newFrame("Frame", "UIParent")

CreateFrame = function(kind, name, parent, template)
  local f = newFrame(kind, name)
  -- Die Haken-Vorlage bringt ihre Beschriftung als .Text mit.
  if kind == "CheckButton" and template then
    f.Text = newFrame("FontString", nil)
  end
  -- Die Vorlage OptionsSliderTemplate legt drei benannte Beschriftungen an.
  if template == "OptionsSliderTemplate" and name then
    for _, suffix in ipairs({ "Low", "High", "Text" }) do
      _G[name .. suffix] = newFrame("FontString", name .. suffix)
    end
  end
  if name then _G[name] = f end
  return f
end

-- Die Umgebung, die Options.lua aus dem Addon erwartet ---------------------

local applied, resolved = 0, 0

local ns = {
  db = {
    spells = { [1] = "Blitzheilung" },
    showSpells = true, showFull = true, showCountdown = true,
    barDir = "fill", countAnchor = "topright", locked = false, showLogo = false,
    estimate = true,
    width = 150, iconSize = 24, scale = 1.0, fontSize = 16,
  },
  Spells = {
    Lookup = function(_, name)
      if name == "Blitzheilung" then
        return { name = "Blitzheilung", cost = 125, castTime = 1.5 }
      end
      return nil
    end,
  },
  Estimate = { SetEnabled = function(self, v) self.on = v end },
  ApplyLayout    = function() applied = applied + 1 end,
  ResolveSpells  = function() resolved = resolved + 1 end,
}

local src = os.getenv("MP5_SRC") or "MP5"
local ok, err = pcall(function()
  assert(loadfile(src .. "/Options.lua"))("MP5", ns)
end)
check("Panel baut sich ohne Fehler auf", ok and "ja" or tostring(err), "ja")

-- Auffrischen ----------------------------------------------------------------

local ok2, err2 = pcall(ns.OpenOptions)
check("Auffrischen laeuft durch", ok2 and "ja" or tostring(err2), "ja")

-- Jeder Schieber muss eine eindeutige Beschriftung haben, sonst
-- ueberschreiben sich zwei Schieber in derselben Zeile gegenseitig.
local sliders, names = 0, {}
for i = 1, #frames do
  local f = frames[i]
  if f.kind == "Slider" then
    sliders = sliders + 1
    check("Schieber-Name noch nicht belegt: " .. tostring(f.name),
          names[f.name] == nil, true)
    names[f.name] = true
  end
end
check("vier Schieber vorhanden", sliders, 4)

-- Der Schieber zeigt den Wert aus der Datenbank, nicht 0.
local function sliderByLabel(prefix)
  for i = 1, #frames do
    local f = frames[i]
    if f.kind == "Slider" then
      local lbl = _G[f.name .. "Text"]
      if lbl and lbl.text and lbl.text:find(prefix, 1, true) then return f, lbl end
    end
  end
end

local wSlider, wLabel = sliderByLabel("Breite")
check("Breite steht auf dem Wert aus der Datenbank", wSlider and wSlider.value, 150)
check("und die Beschriftung zeigt ihn", wLabel and wLabel.text, "Breite: 150")

local sSlider, sLabel = sliderByLabel("Gesamtgroesse")
check("Gesamtgroesse mit zwei Nachkommastellen", sLabel and sLabel.text,
      "Gesamtgroesse: 1.00")

-- Auffrischen darf nichts speichern ------------------------------------------
--
-- Sonst schreibt schon das Oeffnen des Menues gerundete Werte zurueck.
ns.db.width = 155
ns.OpenOptions()
check("Oeffnen aendert den Wert nicht", ns.db.width, 155)

-- Ziehen speichert -----------------------------------------------------------

wSlider.scripts["OnValueChanged"](wSlider, 237)
check("Ziehen rastet auf die Schrittweite ein", ns.db.width, 240)

sSlider.scripts["OnValueChanged"](sSlider, 1.37)
check("Gesamtgroesse rastet auf 0.05 ein", ns.db.scale, 1.35)

local fSlider = sliderByLabel("Schriftgroesse")
fSlider.scripts["OnValueChanged"](fSlider, 21.4)
check("Schriftgroesse wird ganzzahlig", ns.db.fontSize, 21)

local iSlider = sliderByLabel("Icon-Groesse")
iSlider.scripts["OnValueChanged"](iSlider, 41)
check("Icon-Groesse rastet auf gerade Werte", ns.db.iconSize, 42)

-- Haken setzen ---------------------------------------------------------------

-- Haken werden ueber ihre Beschriftung gesucht, nicht ueber die
-- Reihenfolge: sonst bricht der Test bei jedem neuen Haken.
local boxes, byText = {}, {}
for i = 1, #frames do
  local f = frames[i]
  if f.kind == "CheckButton" then
    boxes[#boxes + 1] = f
    if f.Text and f.Text.text then byText[f.Text.text] = f end
  end
end
check("acht Haken vorhanden", #boxes, 8)
check("jeder Haken hat eine Beschriftung", #boxes, (function()
  local n = 0
  for _ in pairs(byText) do n = n + 1 end
  return n
end)())

local function click(text, state)
  local b = byText[text]
  if not b then return "Haken nicht gefunden: " .. text end
  b:SetChecked(state)
  b.scripts["OnClick"](b)
  return nil
end

check("Position fixieren wird gespeichert",
      click("Position fixieren", true) or ns.db.locked, true)
check("Zeichen in der Anzeige wird gespeichert",
      click("Zeichen in der Anzeige", true) or ns.db.showLogo, true)
check("Mitrechnen laesst sich abschalten",
      click("Mana mitrechnen (geschuetzter Wert)", false) or ns.db.estimate, false)
check("und wird an das Modell weitergegeben", ns.Estimate.on, false)

-- Das Zeichen oben im Panel
local logoTex
for i = 1, #frames do
  if frames[i].kind == "Texture" and frames[i].path then logoTex = frames[i] end
end
check("Zeichen im Panel vorhanden",
      logoTex and logoTex.path, "Interface\\AddOns\\MP5\\Textures\\logo.tga")

-- Nichts darf unter den Rand des Fensters rutschen ---------------------------
--
-- Das Optionen-Fenster schneidet ab; alles muss oberhalb von 580 liegen.
local deepest = 0
for i = 1, #frames do
  for _, p in ipairs(frames[i].points) do
    for k = 1, #p do
      local v = p[k]
      if type(v) == "number" and v < 0 and -v > deepest then deepest = -v end
    end
  end
end
print(string.format("%-50s %-12s", "tiefster Punkt im Panel", deepest))
check("alles innerhalb des Fensters (unter 580)", deepest < 580, true)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
