-- MP5 / Options.lua
-- Panel in den Interface-Optionen: die fuenf Zauber-Plaetze und das
-- Aussehen der Leiste. Alles hier ist auch ueber /mp5 erreichbar.

local ADDON, ns = ...

local MAX_SPELLS = 5

local panel = CreateFrame("Frame", "MP5OptionsPanel")
panel.name = "MP5"

local rows = {}

-- Bausteine ---------------------------------------------------------------

local function title(parent, text, size, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK",
        size == "big" and "GameFontNormalLarge" or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function note(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width or 560)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

-- Je nach Client heisst die Vorlage anders; die erste, die existiert, gewinnt.
local function build(kind, parent, templates)
    for i = 1, #templates do
        local ok, f = pcall(CreateFrame, kind, nil, parent, templates[i])
        if ok and f then return f end
    end
    return CreateFrame(kind, nil, parent)
end

local function checkbox(parent, text, x, y, get, set)
    local cb = build("CheckButton", parent,
        { "InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate" })
    cb:SetPoint("TOPLEFT", x, y)
    local label = cb.Text or _G[(cb:GetName() or "") .. "Text"]
    if label then label:SetText(text) end
    cb.refresh = function() cb:SetChecked(get()) end
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ns.ResolveSpells()
    end)
    return cb
end

-- Ein Schieber. "show" formatiert den Wert ueber dem Schieber; ohne Angabe
-- wird ganzzahlig gerundet. Der Name muss eindeutig sein, weil die Vorlage
-- ihre Beschriftungen ueber globale Namen findet - deshalb gehen x und y
-- hinein und nicht nur y (zwei Schieber in einer Zeile haben dasselbe y).
local function slider(parent, text, x, y, min, max, step, get, set, show)
    local id = "MP5Slider" .. math.abs(x) .. "_" .. math.abs(y)
    local s = CreateFrame("Slider", id, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(190)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then pcall(s.SetObeyStepOnDrag, s, true) end

    local fmt = show or function(v) return tostring(math.floor(v + 0.5)) end
    local name = s:GetName()
    if _G[name .. "Low"]  then _G[name .. "Low"]:SetText(fmt(min)) end
    if _G[name .. "High"] then _G[name .. "High"]:SetText(fmt(max)) end
    local lbl = _G[name .. "Text"]

    local function label(v) if lbl then lbl:SetText(text .. ": " .. fmt(v)) end end

    -- Beim Auffrischen darf das Setzen des Wertes nicht wieder speichern,
    -- sonst schreibt das Oeffnen des Menues den gerundeten Wert zurueck.
    local quiet = false
    s.refresh = function()
        quiet = true
        local v = get()
        s:SetValue(v)
        label(v)
        quiet = false
    end
    s:SetScript("OnValueChanged", function(_, v)
        -- Auf ein Vielfaches der Schrittweite legen, damit der Wert nicht
        -- mit Nachkommastellen aus dem Ziehen stehen bleibt.
        v = math.floor(v / step + 0.5) * step
        label(v)
        if quiet then return end
        set(v)
        ns.ApplyLayout()
    end)
    return s
end

-- Aufbau -------------------------------------------------------------------

title(panel, "MP5", "big", 16, -16)
note(panel, "Zeigt die gemessene Mana-Regeneration pro 5 Sekunden und, darunter, "
          .. "wie oft das Mana fuer einen Zauber noch reicht.", 16, -40)

title(panel, "Zauber-Leiste", nil, 16, -80)
note(panel, "Bis zu fuenf Zauber. Genau so schreiben wie im Makro; ein Rang ist "
          .. "optional, ohne Rang gilt der hoechste gelernte. "
          .. "Beispiele: Blitzheilung  |  Erneuern(Rang 4)  |  Machtwort: Schild",
     16, -102, 560)

local spellsOn = checkbox(panel, "Zauber-Leiste anzeigen", 14, -146,
    function() return ns.db.showSpells end,
    function(v) ns.db.showSpells = v end)

-- Fuenf Eingabefelder, jeweils mit Rueckmeldung dahinter.
for i = 1, MAX_SPELLS do
    local y = -180 - (i - 1) * 28

    local lbl = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 20, y - 6)
    lbl:SetText(i .. ".")

    local box = CreateFrame("EditBox", "MP5SpellBox" .. i, panel, "InputBoxTemplate")
    box:SetPoint("TOPLEFT", 40, y)
    box:SetSize(190, 20)
    box:SetAutoFocus(false)

    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    info:SetPoint("LEFT", box, "RIGHT", 12, 0)
    info:SetWidth(320)
    info:SetJustifyH("LEFT")

    local function describe()
        local text = box:GetText()
        if not text or text == "" then
            info:SetText("|cff808080frei|r")
            return
        end
        local s = ns.Spells:Lookup(text)
        if not s then
            info:SetText("|cffff5555nicht gefunden|r")
            return
        end
        local text = string.format("|cff40ff40%s|r  %s Mana, %.1fs",
            s.name .. (s.rank and (" (" .. s.rank .. ")") or ""),
            tostring(s.cost or "?"),
            math.max(s.castTime or 0, 1.5))
        if s.rankIgnored then
            text = text .. "  |cffffaa33(Rang ignoriert)|r"
        end
        info:SetText(text)
    end

    local function commit()
        local text = box:GetText()
        text = text and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
        ns.db.spells[i] = (text ~= "" and text) or nil
        describe()
        ns.ResolveSpells()
    end

    box:SetScript("OnEnterPressed", function(self) commit(); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", commit)
    box:SetScript("OnTextChanged", describe)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(ns.db.spells[i] or "")
        self:ClearFocus()
    end)

    rows[i] = { box = box, describe = describe }
end

title(panel, "Groesse", nil, 16, -326)

local COL1, COL2 = 20, 290

local widthSlider = slider(panel, "Breite", COL1, -358, 80, 400, 10,
    function() return ns.db.width end,
    function(v) ns.db.width = v end)

local iconSlider = slider(panel, "Icon-Groesse", COL2, -358, 16, 48, 2,
    function() return ns.db.iconSize end,
    function(v) ns.db.iconSize = v end)

local scaleSlider = slider(panel, "Gesamtgroesse", COL1, -402, 0.5, 2, 0.05,
    function() return ns.db.scale end,
    function(v) ns.db.scale = v end,
    function(v) return string.format("%.2f", v) end)

local fontSlider = slider(panel, "Schriftgroesse", COL2, -402, 8, 32, 1,
    function() return ns.db.fontSize end,
    function(v) ns.db.fontSize = v end)

note(panel, "Die Breite ist eine Mindestbreite - braucht die Zauber-Reihe mehr "
          .. "Platz, waechst der Rahmen mit.", 20, -434, 540)

-- Ab hier zweispaltig: das Optionen-Fenster schneidet alles ab, was tiefer
-- als etwa 580 Punkte liegt.
title(panel, "Darstellung", nil, 16, -450)

local barFill = checkbox(panel, "Balken fuellt sich auf (sonst leer)", 14, -474,
    function() return ns.db.barDir ~= "drain" end,
    function(v) ns.db.barDir = v and "fill" or "drain" end)

local countCenter = checkbox(panel, "Zahl mittig auf dem Icon", COL2 - 6, -474,
    function() return ns.db.countAnchor == "center" end,
    function(v) ns.db.countAnchor = v and "center" or "topright" end)

local countdownOn = checkbox(panel, "Restzeit unter dem Balken", 14, -498,
    function() return ns.db.showCountdown end,
    function(v) ns.db.showCountdown = v end)

local fullOn = checkbox(panel, "Beide Stufen zeigen", COL2 - 6, -498,
    function() return ns.db.showFull end,
    function(v) ns.db.showFull = v end)

local lockedOn = checkbox(panel, "Position fixieren", 14, -522,
    function() return ns.db.locked end,
    function(v) ns.db.locked = v end)

local estimateOn = checkbox(panel, "Mana mitrechnen (geschuetzter Wert)", COL2 - 6, -522,
    function() return ns.db.estimate end,
    function(v)
        ns.db.estimate = v
        if ns.Estimate then ns.Estimate:SetEnabled(v) end
    end)

note(panel, "Mitrechnen: Kosten der Zauber abziehen, Regeneration dazu - fuer "
          .. "Clients, die das Mana nicht herausgeben. Dann Untergrenze (~), "
          .. "exakt sobald der Tank voll war.  |cff808080Alles auch ueber "
          .. "/mp5, Herleitung mit /mp5 why|r", 20, -546, 560)

-- Oeffnen und Auffrischen --------------------------------------------------

local function refresh()
    if not ns.db then return end
    for i = 1, MAX_SPELLS do
        rows[i].box:SetText(ns.db.spells[i] or "")
        rows[i].describe()
    end
    spellsOn.refresh()
    barFill.refresh()
    countCenter.refresh()
    countdownOn.refresh()
    fullOn.refresh()
    lockedOn.refresh()
    estimateOn.refresh()
    iconSlider.refresh()
    widthSlider.refresh()
    scaleSlider.refresh()
    fontSlider.refresh()
end

panel.refresh = refresh          -- neue Settings-API
panel.OnRefresh = refresh
panel.okay = function() end
panel.cancel = function() end

local category

if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, "MP5")
    category.ID = "MP5"
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

function ns.OpenOptions()
    refresh()
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(category.ID or category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Aelterer Client: der erste Aufruf landet gelegentlich daneben.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
