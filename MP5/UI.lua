-- MP5 / UI.lua
-- Entwurf 3, von oben nach unten:
--
--     12 / 47          beide Stufen, mittig, die gueltige hell
--   [=========  ]      Balken der 5-Sekunden-Regel
--       3.2s           Restzeit UNTER dem Balken (auf dunklem Grund lesbar)
--   [#] [#] [#] [#]    Zauber-Icons mit "so oft reicht das Mana noch"
--
-- Der OnUpdate laeuft ausschliesslich waehrend der 5 Sekunden nach einem
-- Zauber und schaltet sich danach selbst wieder ab.

local ADDON, ns = ...
local Core   = ns.Core
local Spells = ns.Spells

local UPDATE_THROTTLE = 0.1
local UnitPower = UnitPower or function(u) return UnitMana(u) end

-- SetColorTexture gibt es erst ab 8.0; davor nahm SetTexture die Farbe.
local function solid(tex, r, g, b, a)
    if tex.SetColorTexture then tex:SetColorTexture(r, g, b, a)
    else tex:SetTexture(r, g, b, a) end
end
local MAX_SPELLS      = 5
local INFINITY        = "\226\136\158"     -- ∞

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

local bar = CreateFrame("StatusBar", nil, frame)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetMinMaxValues(0, 5)

local barBG = bar:CreateTexture(nil, "BACKGROUND")
barBG:SetAllPoints()
solid(barBG, 0, 0, 0, 0.6)

-- Die Restzeit steht unter dem Balken, nicht darin: auf dem goldenen
-- Balken war die Zahl nicht zu lesen.
local countdown = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

-- Farben der beiden Stufen. Der gerade wirksame Wert wird hell dargestellt,
-- der andere gedimmt - so ist auf einen Blick klar, welche Stufe gilt.
local C_FSR  = { 0.95, 0.72, 0.22 }   -- innerhalb der 5-Sekunden-Regel (gold)
local C_FULL = { 0.56, 0.76, 1.00 }   -- ausserhalb (manablau)
local C_DIM  = { 0.45, 0.43, 0.38 }   -- inaktive Stufe
local C_ZERO = { 0.60, 0.60, 0.60 }

-- Ampel fuer die Zauber-Zahlen.
local C_MANY = { 0.45, 0.90, 0.45 }
local C_SOME = { 1.00, 0.82, 0.20 }
local C_FEW  = { 1.00, 0.35, 0.35 }

local function color(fs, c, isZero)
    if isZero then c = C_ZERO end
    fs:SetTextColor(c[1], c[2], c[3])
end

-- Beide Stufen stehen in EINER Fontstring, eingefaerbt ueber Farbcodes.
-- Dadurch laesst sich die Zeile als Ganzes exakt mittig setzen.
local function hex(c)
    -- Ganzzahlen erzwingen: %x bricht auf manchen Lua-Builds bei
    -- Fliesskommazahlen ab, und zwar bei jedem Neuzeichnen.
    return string.format("|cff%02x%02x%02x",
        math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

-- Zauber-Felder -----------------------------------------------------------

local slots = {}

local function createSlot(i)
    local b = CreateFrame("Frame", nil, frame)
    b:EnableMouse(true)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- Rand des Icons wegschneiden

    b.border = b:CreateTexture(nil, "BORDER")
    b.border:SetPoint("TOPLEFT", -1, 1)
    b.border:SetPoint("BOTTOMRIGHT", 1, -1)
    solid(b.border, 0, 0, 0, 1)

    -- Umrandete Schrift, damit die Zahl auf jedem Icon lesbar bleibt.
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetShadowColor(0, 0, 0, 1)
    b.count:SetShadowOffset(1, -1)

    b:SetScript("OnEnter", function(self)
        if not ns.db.tooltip or not self.info then return end
        local info, casts = self.info, self.casts
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(info.name .. (info.rank and (" (" .. info.rank .. ")") or ""))
        GameTooltip:AddDoubleLine("Kosten", (info.cost or "?") .. " Mana", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Zauberzeit",
            string.format("%.1fs", math.max(info.castTime or 0, 1.5)), 1, 1, 1, 1, 1, 1)
        if casts == math.huge then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Traegt sich selbst - die Regeneration waehrend", 0.3, 0.9, 0.3)
            GameTooltip:AddLine("der Zauberzeit deckt die Kosten.", 0.3, 0.9, 0.3)
        elseif casts then
            local secs = Spells.TimeLeft(casts, info.castTime)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Reicht noch fuer", casts .. "x", 1, 1, 1, 1, 0.82, 0.2)
            GameTooltip:AddDoubleLine("Das sind", string.format("%.0f Sekunden", secs),
                1, 1, 1, 1, 0.82, 0.2)
        end
        GameTooltip:AddLine(" ")
        local src = Core:ManaSource()
        if src == "prozent" then
            GameTooltip:AddLine("Mana aus dem Prozentwert der Standardleiste", 1, 0.82, 0.2)
            GameTooltip:AddLine("umgerechnet - die Zahl ist daher gerundet (~).", 1, 0.82, 0.2)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Genauer wird es mit numerischem Statustext:", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("Interface > Statustext > Zahlen.", 0.6, 0.6, 0.6)
        elseif src == "text" then
            GameTooltip:AddLine("Mana aus dem Text der Standardleiste gelesen,", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("weil der Client den Wert selbst schuetzt.", 0.6, 0.6, 0.6)
        elseif not Core:ManaReadable() then
            if self.affordable ~= nil then
                GameTooltip:AddLine(self.affordable
                    and "Mana reicht fuer diesen Zauber."
                    or  "Mana reicht nicht - Icon ist grau.",
                    self.affordable and 0.3 or 1,
                    self.affordable and 0.9 or 0.4,
                    self.affordable and 0.3 or 0.4)
                GameTooltip:AddLine(" ")
            end
            GameTooltip:AddLine("Eine Stueckzahl ist nicht moeglich: dieser", 1, 0.6, 0.33)
            GameTooltip:AddLine("Client gibt das aktuelle Mana nicht heraus.", 1, 0.6, 0.33)
        else
            GameTooltip:AddLine("Bei Dauercasten, mit der Regeneration", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("innerhalb der 5-Sekunden-Regel.", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    slots[i] = b
    return b
end

for i = 1, MAX_SPELLS do createSlot(i) end

-- Darstellung -------------------------------------------------------------

local function fmt(v)
    if not v then return "?" end
    local db = ns.db
    if db.decimals > 0 then
        return string.format("%." .. db.decimals .. "f", v)
    end
    return tostring(math.floor(v + 0.5))
end

local function fmtCasts(n)
    if not n then return "?" end
    if n == math.huge then return INFINITY end
    if n > 99 then return "99+" end
    return tostring(n)
end

local shown = nil        -- aktuell dargestellter Wert (fuer die Animation)
local animating = false

-- Welche Zauber sind eingetragen und bekannt? Wird nur bei Aenderungen
-- neu aufgeloest, nicht in jedem Frame.
local resolved = {}

function ns.ResolveSpells()
    local db = ns.db
    if not db then return end         -- SPELLS_CHANGED feuert vor ADDON_LOADED
    for i = 1, MAX_SPELLS do
        local name = db.spells and db.spells[i]
        resolved[i] = name and Spells:Lookup(name) or nil
    end
    ns.ApplyLayout()
end

local function updateSpells()
    local db = ns.db
    if not db then return end
    local mana, approx = Core:GetMana()       -- nil, wenn kein Weg funktioniert
    local mp5  = Core:GetMP5(true)            -- beim Durchcasten gilt die FSR-Stufe
    local mps  = mp5 and (mp5 / 5) or nil

    for i = 1, MAX_SPELLS do
        local b, info = slots[i], resolved[i]
        if not db.showSpells or not info then
            b:Hide()
        else
            b:Show()
            b.info = info
            b.icon:SetTexture(info.icon)

            local casts = Spells.CastsLeft(mana, info.cost, info.castTime, mps)
            b.casts = casts

            if casts then
                -- Stammt das Mana aus einem Prozentwert, ist die Zahl
                -- gerundet. Das zeigt die Tilde an, statt es zu verschweigen.
                local prefix = (approx and casts ~= math.huge) and "~" or ""
                b.count:SetText(prefix .. fmtCasts(casts))
                pcall(b.icon.SetDesaturated, b.icon, false)
                if casts == math.huge then
                    color(b.count, C_MANY)
                elseif casts <= 3 then
                    color(b.count, C_FEW)
                elseif casts <= 10 then
                    color(b.count, C_SOME)
                else
                    color(b.count, C_MANY)
                end
            else
                -- Ohne lesbares Mana laesst sich keine Stueckzahl rechnen.
                -- Das Spiel beantwortet aber, ob der Zauber bezahlbar ist:
                -- nicht bezahlbar -> Icon grau. Das ist die Grenze statt
                -- der Zahl, und es kommt ohne den Manawert aus.
                local ok = Spells:Affordable(info)
                b.affordable = ok
                if ok == nil then
                    b.count:SetText("?")
                    color(b.count, C_ZERO)
                    pcall(b.icon.SetDesaturated, b.icon, false)
                else
                    b.count:SetText("")
                    pcall(b.icon.SetDesaturated, b.icon, ok == false)
                end
            end
        end
    end
end

local function Redraw()
    local db = ns.db
    if not db then return end     -- Events koennen vor ADDON_LOADED feuern
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
        -- Beide Stufen nebeneinander, mittig ueber dem Balken: links der
        -- Wert waehrend der 5-Sekunden-Regel, rechts der danach.
        local left  = inFSR and shown or fsrVal
        local right = inFSR and fullVal or shown
        local cl = inFSR and C_FSR or C_DIM
        local cr = inFSR and C_DIM or C_FULL
        if left and left <= 0 then cl = C_ZERO end
        if right and right <= 0 then cr = C_ZERO end
        value:SetText(hex(cl) .. fmt(left) .. "|r " .. hex(C_DIM) .. "/|r "
                      .. hex(cr) .. fmt(right) .. "|r")
    else
        local c = inFSR and C_FSR or C_FULL
        if cur and cur <= 0 then c = C_ZERO end
        value:SetText(hex(c) .. fmt(shown) .. "|r")
    end

    local rest = Core:FSRRemaining()

    if db.bar == "off" then
        bar:Hide()
    else
        bar:Show()
        -- "fill": der Balken fuellt sich ueber die 5 Sekunden auf, voll heisst
        -- also immer dasselbe - volle Regeneration. "drain": er laeuft leer,
        -- dann heisst voll zweierlei und nur die Farbe trennt die Faelle.
        if db.barDir == "drain" then
            bar:SetValue(rest > 0 and rest or 5)
        else
            bar:SetValue(5 - rest)
        end
        if rest > 0 then
            bar:SetStatusBarColor(0.88, 0.65, 0.16)
        else
            bar:SetStatusBarColor(0.22, 0.42, 0.78)
        end
    end

    if db.showCountdown then
        countdown:SetText(rest > 0 and string.format("%.1fs", rest) or "")
        color(countdown, C_FSR)
        countdown:Show()
    else
        countdown:Hide()
    end

    updateSpells()
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
    countdown:SetFont(font, fs * 0.68, flags)

    local pad   = 4
    local rowH  = fs + 4
    local barH  = db.bar == "full" and (fs * 0.72) or 4

    -- Wie viele Zauber-Felder sind tatsaechlich belegt?
    local used = 0
    for i = 1, MAX_SPELLS do
        if db.showSpells and resolved[i] then used = used + 1 end
    end
    local iconSize = db.iconSize
    local iconGap  = 3

    local h = pad * 2 + rowH
    if db.bar ~= "off"    then h = h + barH + 3 end
    if db.showCountdown   then h = h + fs * 0.68 + 2 end
    if used > 0           then h = h + iconSize + 5 end

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

    -- Beschriftung ist standardmaessig aus; der Wert erklaert sich selbst.
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 2, -pad)
    label:SetText(db.showLabel and "MANA / 5" or "")

    -- Werte mittig ueber dem Balken.
    value:ClearAllPoints()
    value:SetPoint("TOP", frame, "TOP", 0, -pad)

    local y = -(pad + rowH)

    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 2, y)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(pad + 2), y)
    bar:SetHeight(barH)
    if db.bar ~= "off" then y = y - barH - 3 end

    countdown:ClearAllPoints()
    countdown:SetPoint("TOP", frame, "TOP", 0, y - 1)
    if db.showCountdown then y = y - fs * 0.68 - 2 end

    -- Zauber-Felder mittig in einer Reihe.
    local totalW = used * iconSize + math.max(0, used - 1) * iconGap
    local x = -totalW / 2
    local n = 0
    for i = 1, MAX_SPELLS do
        local b = slots[i]
        b:ClearAllPoints()
        b:SetSize(iconSize, iconSize)
        b.count:SetFont(font, math.max(10, iconSize * 0.46), "OUTLINE")
        b.count:ClearAllPoints()
        if db.countAnchor == "center" then
            b.count:SetPoint("CENTER", b, "CENTER", 0, 0)
        else
            b.count:SetPoint("TOPRIGHT", b, "TOPRIGHT", 1, 1)
        end
        if db.showSpells and resolved[i] then
            b:SetPoint("TOPLEFT", frame, "TOP", x + n * (iconSize + iconGap), y - 3)
            n = n + 1
        end
    end

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
    if not Core:ManaReadable() then
        GameTooltip:AddLine("Dieser Client schuetzt den Manawert.", 1, 0.6, 0.33)
        GameTooltip:AddLine("Messung und Zauber-Zahlen sind daher nicht", 1, 0.6, 0.33)
        GameTooltip:AddLine("moeglich - angezeigt wird nur, was die API liefert.", 1, 0.6, 0.33)
        GameTooltip:AddLine(" ")
    end
    GameTooltip:AddLine("Quelle: " .. (src or "-") .. " / " .. (fsrc or "-"), 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Gemessene Werte stammen aus den echten Mana-Ticks", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("und enthalten alle Buffs, Items und Volksfaehigkeiten.", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("/mp5 fuer Einstellungen", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
