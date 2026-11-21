-- MP5 / Debug.lua
-- Ein Fenster, das zeigt, was das Addon ueber das Mana denkt.
--
-- Zweck: auf diesem Client wird das Mana gerechnet, nicht gelesen. Ob die
-- Rechnung stimmt, sieht man nur im Vergleich mit der Manaleiste des
-- Spiels - also Seite an Seite, ueber die Zeit, mit der Mitschrift dessen,
-- was das Modell zuletzt getan hat.
--
-- Oben der Zustand, unten die letzten Ereignisse. Verschiebbar, und es
-- laeuft nur, solange es sichtbar ist.

local ADDON, ns = ...

local GetTime      = GetTime
local UnitPowerMax = UnitPowerMax or function(u) return UnitManaMax(u) end
local MANA         = Enum and Enum.PowerType and Enum.PowerType.Mana or 0

local LINES    = 8        -- Zeilen fuer die Mitschrift
local INTERVAL = 0.25     -- Auffrischen, solange das Fenster offen ist

local f = CreateFrame("Frame", "MP5DebugFrame", UIParent)
f:SetSize(320, 250)
f:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)
f:Hide()

if f.SetBackdrop then
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
end

local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOPLEFT", 12, -10)
title:SetText("MP5 - was das Addon denkt")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
if close.SetPoint then close:SetPoint("TOPRIGHT", 2, 2) end
close:SetScript("OnClick", function() ns.ShowDebug(false) end)

local state = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
state:SetPoint("TOPLEFT", 12, -32)
state:SetWidth(296)
state:SetJustifyH("LEFT")

local logTitle = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
logTitle:SetPoint("TOPLEFT", 12, -132)
logTitle:SetText("Zuletzt passiert")

local lines = {}
for i = 1, LINES do
    local fs = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 12, -150 - (i - 1) * 12)
    fs:SetWidth(296)
    fs:SetJustifyH("LEFT")
    lines[i] = fs
end

local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hint:SetPoint("BOTTOMLEFT", 12, 10)
hint:SetWidth(296)
hint:SetJustifyH("LEFT")
hint:SetText("Vergleiche mit deiner Manaleiste. Weicht es ab: /mp5 voll")

-- Zeilen bauen --------------------------------------------------------------

local function num(v, digits)
    if type(v) ~= "number" then return "-" end
    if digits then return string.format("%." .. digits .. "f", v) end
    return tostring(math.floor(v + 0.5))
end

local function gold(t)   return "|cffffd100" .. t .. "|r" end
local function green(t)  return "|cff40ff40" .. t .. "|r" end
local function red(t)    return "|cffff5555" .. t .. "|r" end
local function dim(t)    return "|cff808080" .. t .. "|r" end

local function stateText()
    local Core, Est = ns.Core, ns.Estimate
    local out = {}

    local mana, approx, src = Core:GetMana()
    local max = Core.GetMaxMana and Core:GetMaxMana()

    out[#out + 1] = "Mana: " .. (mana and gold(num(mana)) or red("unbekannt"))
        .. (max and (" / " .. num(max)) or "")
        .. (mana and max and max > 0
            and dim(string.format("  (%d%%)", math.floor(mana / max * 100))) or "")

    out[#out + 1] = "Quelle: " .. (src and gold(src) or red("keine"))
        .. (approx and dim("  gerundet/Untergrenze") or green("  genau"))

    local s = Est and Est:Status()
    if s then
        out[#out + 1] = "Modell: " .. (s.enabled and "an" or red("aus"))
            .. "  Wert " .. num(s.mana)
            .. (s.exact and green("  exakt") or gold("  Untergrenze"))
        out[#out + 1] = dim("Regeneration: ") .. num(s.rate, 1) .. "/s"
            .. dim("   aufgelaufen: ") .. num(s.credit)
            .. dim(" von ") .. num(s.max and s.max * 1.25)
        out[#out + 1] = dim("Mana-Ereignis: ")
            .. (s.events and ("still seit " .. num(s.quiet, 1) .. "s") or red("nie gesehen"))
        out[#out + 1] = dim("Schranken: ") .. "mind. " .. num(s.lower)
            .. ", unter " .. num(s.upper)
            .. dim("  (" .. tostring(s.ladder) .. " Zauber)")
    end

    local fsr = Core:InFSR()
    out[#out + 1] = dim("5-Sek-Regel: ")
        .. (fsr and gold(num(Core:FSRRemaining(), 1) .. "s") or "aus")
        .. dim("   MP5: ") .. num((Core:GetMP5(true)))
        .. " / " .. num((Core:GetMP5(false)))

    return table.concat(out, "\n")
end

local function logText(i, e, now)
    if not e then return "" end
    local age = now - (e.t or now)
    return dim(string.format("%5.1fs  ", age))
        .. e.what .. dim("  " .. tostring(e.detail or ""))
end

local function refresh()
    local ok, text = pcall(stateText)
    state:SetText(ok and text or ("|cffff5555" .. tostring(text) .. "|r"))

    local entries = (ns.Estimate and ns.Estimate:Log(LINES)) or {}
    local now = GetTime()
    for i = 1, LINES do
        lines[i]:SetText(logText(i, entries[i], now))
    end
end

ns.RefreshDebug = refresh

-- Laufen nur, solange sichtbar ----------------------------------------------

local elapsed = 0
f:SetScript("OnUpdate", ns.safe(function(_, e)
    elapsed = elapsed + e
    if elapsed < INTERVAL then return end
    elapsed = 0
    refresh()
end))

function ns.ShowDebug(show)
    if show == nil then show = not f:IsShown() end
    if show then
        refresh()
        f:Show()
    else
        f:Hide()
    end
    if ns.db then ns.db.debug = show and true or false end
    return show
end

function ns.DebugShown()
    return f:IsShown()
end

ns.debugFrame = f
