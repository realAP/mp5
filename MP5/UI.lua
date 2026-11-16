-- MP5 / UI.lua
-- Anzeige im klassischen Blizzard-Stil. Frei verschiebbar, skalierbar.
-- Der OnUpdate laeuft ausschliesslich waehrend der 5 Sekunden nach einem
-- Zauber und schaltet sich danach selbst wieder ab.

local ADDON, ns = ...
local Core = ns.Core

local UPDATE_THROTTLE = 0.1

local frame = CreateFrame("Frame", "MP5Frame", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:Hide()

ns.frame = frame

local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
local value = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
local extra = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")

local bar = CreateFrame("StatusBar", nil, frame)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetMinMaxValues(0, 5)

local barBG = bar:CreateTexture(nil, "BACKGROUND")
barBG:SetAllPoints()
barBG:SetColorTexture(0, 0, 0, 0.6)

local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
barText:SetPoint("CENTER")

-- Darstellung -------------------------------------------------------------

local function fmt(v)
    if not v then return "?" end
    local db = ns.db
    if db.decimals > 0 then
        return string.format("%." .. db.decimals .. "f", v)
    end
    return tostring(math.floor(v + 0.5))
end

local shown = nil        -- aktuell dargestellter Wert (fuer die Animation)
local animating = false

-- Farben der beiden Stufen. Der gerade wirksame Wert wird hell dargestellt,
-- der andere gedimmt - so ist auf einen Blick klar, welche Stufe gilt.
local C_FSR  = { 0.95, 0.72, 0.22 }   -- innerhalb der 5-Sekunden-Regel (gold)
local C_FULL = { 0.56, 0.76, 1.00 }   -- ausserhalb (manablau)
local C_DIM  = { 0.45, 0.43, 0.38 }   -- inaktive Stufe
local C_ZERO = { 0.60, 0.60, 0.60 }

local function color(fs, c, isZero)
    if isZero then c = C_ZERO end
    fs:SetTextColor(c[1], c[2], c[3])
end

local function Redraw()
    local db = ns.db
    local inFSR = Core:InFSR()
    local fsrVal  = Core:GetMP5(true)    -- Stufe 1: waehrend des Castens
    local fullVal = Core:GetMP5(false)   -- Stufe 2: nach der 5-Sekunden-Regel
    local cur = inFSR and fsrVal or fullVal

    -- Optionales weiches Hochzaehlen. Standardmaessig aus: ohne Animation
    -- springt der Wert sofort und es laeuft kein zusaetzlicher OnUpdate.
    animating = false
    if db.animate and cur and shown then
        local diff = cur - shown
        if math.abs(diff) > 0.1 then
            shown = shown + diff * 0.25
            animating = true
        else
            shown = cur
        end
    else
        shown = cur
    end

    if db.showFull then
        -- Beide Stufen dauerhaft nebeneinander: links der Wert waehrend der
        -- 5-Sekunden-Regel, rechts der Wert danach. Hell = gilt gerade.
        local left  = inFSR and shown or fsrVal
        local right = inFSR and fullVal or shown
        extra:SetText(fmt(left) .. " /")
        value:SetText(fmt(right))
        color(extra, inFSR and C_FSR or C_DIM, left and left <= 0)
        color(value, inFSR and C_DIM or C_FULL, right and right <= 0)
        extra:Show()
    else
        -- Nur die gerade wirksame Stufe.
        extra:Hide()
        value:SetText(fmt(shown))
        color(value, inFSR and C_FSR or C_FULL, cur and cur <= 0)
    end

    if db.bar == "off" then
        bar:Hide()
    else
        bar:Show()
        local rest = Core:FSRRemaining()
        bar:SetValue(rest)
        if rest > 0 then
            bar:SetStatusBarColor(0.88, 0.65, 0.16)
        else
            bar:SetStatusBarColor(0.22, 0.42, 0.78)
            bar:SetValue(5)
        end
        if db.showCountdown then
            barText:SetText(rest > 0 and string.format("%.1fs", rest) or "")
        else
            barText:SetText("")
        end
    end
end

ns.Redraw = Redraw

-- OnUpdate nur solange die 5-Sekunden-Regel laeuft -------------------------

local elapsed = 0
local function OnUpdate(_, e)
    elapsed = elapsed + e
    if elapsed < UPDATE_THROTTLE then return end
    elapsed = 0
    Redraw()
    if not Core:InFSR() and not animating then
        frame:SetScript("OnUpdate", nil)   -- Leerlauf: keine Berechnung mehr
    end
end

local function OnChanged()
    Redraw()
    if (Core:InFSR() or animating) and not frame:GetScript("OnUpdate") then
        elapsed = 0
        frame:SetScript("OnUpdate", OnUpdate)
    end
end

Core:RegisterCallback(OnChanged)

-- Layout ------------------------------------------------------------------

function ns.ApplyLayout()
    local db = ns.db
    local font, _, flags = value:GetFont()
    local fs = db.fontSize

    label:SetFont(font, fs * 0.72, flags)
    value:SetFont(font, fs, flags)
    extra:SetFont(font, fs * 0.82, flags)
    barText:SetFont(font, fs * 0.55, flags)

    local pad = 4
    -- Ein Balken mit Zeitanzeige braucht Hoehe fuer die Schrift; ohne
    -- Countdown bleibt der duenne Balken ein 3-Pixel-Strich.
    local barH
    if db.bar == "full" then
        barH = fs * 0.72
    elseif db.showCountdown then
        barH = math.max(9, fs * 0.58)
    else
        barH = 3
    end
    local rowH = fs + 4
    local h = rowH + (db.bar ~= "off" and (barH + 3) or 0) + pad * 2
    frame:SetSize(db.width, h)
    frame:SetScale(db.scale)

    if db.backdrop ~= "off" and frame.SetBackdrop then
        if db.backdrop == "blizzard" then
            frame:SetBackdrop({
                bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            frame:SetBackdropColor(0, 0, 0, 0.85)
        else
            frame:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            frame:SetBackdropColor(0, 0, 0, 0.55)
            frame:SetBackdropBorderColor(0, 0, 0, 0.9)
        end
    elseif frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end

    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 2, -pad)
    label:SetText(db.showLabel and "MANA / 5" or "")

    value:ClearAllPoints()
    value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(pad + 2), -pad + 1)

    extra:ClearAllPoints()
    extra:SetPoint("RIGHT", value, "LEFT", -4, -1)

    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad + 2, pad)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(pad + 2), pad)
    bar:SetHeight(barH)

    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    frame:EnableMouse(not db.locked)
    Redraw()
end

-- Verschieben --------------------------------------------------------------

frame:SetScript("OnDragStart", function(self)
    if not ns.db.locked then self:StartMoving() end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    ns.db.point, ns.db.x, ns.db.y = point, x, y
end)

-- Tooltip: Aufschluesselung (Entwurf 5) ------------------------------------

frame:SetScript("OnEnter", function(self)
    if not ns.db.tooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Mana-Regeneration")

    local fsrVal, src   = Core:GetMP5(true)
    local fullVal, fsrc = Core:GetMP5(false)
    local inFSR = Core:InFSR()

    GameTooltip:AddDoubleLine("Waehrend des Zauberns (5-Sek-Regel)",
        fmt(fsrVal) .. " / 5 Sek.", 1, 1, 1, 0.95, 0.72, 0.22)
    GameTooltip:AddDoubleLine("Danach (inkl. Geist)",
        fmt(fullVal) .. " / 5 Sek.", 1, 1, 1, 0.56, 0.76, 1)
    if inFSR then
        GameTooltip:AddDoubleLine("5-Sekunden-Regel",
            string.format("noch %.1fs", Core:FSRRemaining()), 1, 1, 1, 1, 0.82, 0.2)
    else
        GameTooltip:AddLine("Volle Regeneration aktiv", 0.3, 0.9, 0.3)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Quelle: " .. (src or "-") .. " / " .. (fsrc or "-"), 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Gemessene Werte stammen aus den echten Mana-Ticks", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("und enthalten alle Buffs, Items und Volksfaehigkeiten.", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("/mp5 fuer Einstellungen", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
