-- Safe Minimap Dock
-- WoW 1.12 / Turtle / Octowow
--
-- Architecture:
-- * No minimap scanning
-- * No SetParent() on addon buttons
-- * No event removal
-- * No child manipulation
-- * No texture/scale/frame-level changes
-- * Registered buttons are only anchored to this dock with SetPoint()
--
-- The dock is a POSITION REFERENCE, not a parent.

local SMD = CreateFrame("Frame", "SafeMinimapDockController", UIParent)
local Dock = CreateFrame("Frame", "SafeMinimapDockFrame", UIParent)
local Handle = CreateFrame("Button", "SafeMinimapDockHandle", Dock)

local registered = {}
local originals = {}
local pending = {}
local draggingDock = false
local retryElapsed = 0

-- Hover drawer state.
local hoverElapsed = 0
local hoverShown = true
local savedAlpha = {}
local forceShown = false

-- Short, subtle fade state.
local fadeAlpha = 0
local fadeTarget = 0
local FADE_TIME = 0.14

-- Lua 5.0 compatibility: forward declaration.
-- RegisterFrame() can run before the function body is defined below.
local ApplyVisualState

local BUTTON = 34
local GAP = -2
local COLS = 5
local PAD = 0

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99SafeMinimapDock|r: "..msg)
    end
end

local function EnsureDB()
    if not SafeMinimapDockDB then
        SafeMinimapDockDB = {}
    end
    if not SafeMinimapDockDB.buttons then
        SafeMinimapDockDB.buttons = {}
    end
    if not SafeMinimapDockDB.x then
        SafeMinimapDockDB.x = 300
    end
    if not SafeMinimapDockDB.y then
        SafeMinimapDockDB.y = 300
    end
    if SafeMinimapDockDB.showFrame == nil then
        SafeMinimapDockDB.showFrame = false
    end

    -- false = normal hover-hide mode
    -- true  = stay visible until /mdock hide
    if SafeMinimapDockDB.forceShown == nil then
        SafeMinimapDockDB.forceShown = false
    end
end

local function SaveDock()
    EnsureDB()
    local x, y = Dock:GetCenter()
    if x and y then
        SafeMinimapDockDB.x = x
        SafeMinimapDockDB.y = y
    end
end

local function RestoreDock()
    EnsureDB()
    Dock:ClearAllPoints()
    Dock:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        SafeMinimapDockDB.x or 300,
        SafeMinimapDockDB.y or 300)
end

local function GetName(frame)
    if frame and frame.GetName then
        return frame:GetName()
    end
    return nil
end

local function SaveOriginal(frame)
    local name = GetName(frame)
    if not name or originals[name] then
        return
    end

    local p, rel, rp, x, y = frame:GetPoint(1)

    originals[name] = {
        SetPoint = frame.SetPoint,
        ClearAllPoints = frame.ClearAllPoints,
        point = p,
        relativeTo = rel,
        relativePoint = rp,
        x = x,
        y = y,
        width = frame:GetWidth(),
        height = frame:GetHeight(),
        alpha = frame:GetAlpha(),
    }
end

local function InternalClear(frame)
    local name = GetName(frame)
    local o = name and originals[name]
    if o and o.ClearAllPoints then
        o.ClearAllPoints(frame)
    else
        frame:ClearAllPoints()
    end
end

local function InternalSet(frame, point, relativeTo, relativePoint, x, y)
    local name = GetName(frame)
    local o = name and originals[name]
    if o and o.SetPoint then
        o.SetPoint(frame, point, relativeTo, relativePoint, x, y)
    else
        frame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
end

local function LockPosition(frame)
    local name = GetName(frame)
    if not name then return end

    SaveOriginal(frame)

    -- Prevent the owning addon from snapping the registered icon back to the
    -- minimap. SafeMinimapDock calls the saved original methods directly.
    frame.SetPoint = function() return end
    frame.ClearAllPoints = function() return end
end

local function Layout()
    local count = 0

    for i, name in ipairs(SafeMinimapDockDB.buttons) do
        local frame = registered[name]

        if frame and frame:IsShown() then
            count = count + 1

            local col = math.mod(count - 1, COLS)
            local row = math.floor((count - 1) / COLS)

            -- Every icon is anchored by its CENTER to the exact same grid
            -- centerline. Do not derive the anchor from the icon's own edges:
            -- addon buttons often have different native Width/Height values.
            local x = PAD + (BUTTON / 2) + col * (BUTTON + GAP)
            local y = -(PAD + (BUTTON / 2) + row * (BUTTON + GAP))

            InternalClear(frame)
            InternalSet(frame, "CENTER", Dock, "TOPLEFT", x, y)
        end
    end

    local rows = math.ceil(count / COLS)
    if rows < 1 then rows = 1 end

    local usedCols = count
    if usedCols > COLS then usedCols = COLS end
    if usedCols < 1 then usedCols = 1 end

    Dock:SetWidth(PAD * 2 + usedCols * BUTTON + (usedCols - 1) * GAP)
    Dock:SetHeight(PAD * 2 + rows * BUTTON + (rows - 1) * GAP)
end

local function RegisterFrame(frame)
    local name = GetName(frame)
    if not name then
        Print("That frame has no global name.")
        return false
    end

    EnsureDB()

    if not registered[name] then
        LockPosition(frame)

        -- Standard Vanilla minimap buttons are visually ~32x32. Normalizing
        -- only the outer clickable frame dimensions makes mixed addon icons
        -- share the same true centerline. Scale and child artwork are untouched.
        frame:SetWidth(32)
        frame:SetHeight(32)

        savedAlpha[name] = frame:GetAlpha()
        registered[name] = frame
        frame:SetAlpha((savedAlpha[name] or 1) * fadeAlpha)
        ApplyVisualState()
    end

    local found = false
    for i, v in ipairs(SafeMinimapDockDB.buttons) do
        if v == name then
            found = true
            break
        end
    end

    if not found then
        table.insert(SafeMinimapDockDB.buttons, name)
    end

    Layout()
    return true
end

local function RegisterMouseFrame()
    local frame = GetMouseFocus()
    local name = GetName(frame)

    if not frame or not name then
        Print("Hover the minimap button itself, then type /mdock add.")
        return
    end

    if RegisterFrame(frame) then
        Print("Docked "..name)
    end
end

local function RestoreRegistered()
    EnsureDB()

    for i, name in ipairs(SafeMinimapDockDB.buttons) do
        local frame = getglobal(name)
        if frame then
            RegisterFrame(frame)
            pending[name] = nil
        else
            pending[name] = true
        end
    end

    Layout()
end

local function UndockMouseFrame()
    local frame = GetMouseFocus()
    local name = GetName(frame)

    if not name then
        Print("Hover a docked icon first.")
        return
    end

    local o = originals[name]

    if o then
        -- Restore original methods first.
        frame.SetPoint = o.SetPoint
        frame.ClearAllPoints = o.ClearAllPoints

        -- Restore original anchor if available.
        if o.ClearAllPoints then
            o.ClearAllPoints(frame)
        end

        if o.point and o.SetPoint then
            o.SetPoint(frame, o.point, o.relativeTo, o.relativePoint, o.x, o.y)
        end

        if o.width and o.height then
            frame:SetWidth(o.width)
            frame:SetHeight(o.height)
        end

        if o.alpha then
            frame:SetAlpha(o.alpha)
        end
    end

    savedAlpha[name] = nil
    registered[name] = nil
    originals[name] = nil
    pending[name] = nil

    for i = table.getn(SafeMinimapDockDB.buttons), 1, -1 do
        if SafeMinimapDockDB.buttons[i] == name then
            table.remove(SafeMinimapDockDB.buttons, i)
        end
    end

    Layout()
    Print("Undocked "..name)
end

------------------------------------------------------------
-- Dock visual
------------------------------------------------------------

Dock:SetFrameStrata("MEDIUM")
Dock:SetWidth(200)
Dock:SetHeight(80)

local bg = Dock:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(Dock)
bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
bg:SetVertexColor(0,0,0)
bg:SetAlpha(0.35)

Handle:SetWidth(70)
Handle:SetHeight(18)
Handle:SetPoint("BOTTOMLEFT", Dock, "TOPLEFT", 0, 2)
Handle:SetMovable(1)
Handle:EnableMouse(1)
Handle:RegisterForDrag("LeftButton")

local hbg = Handle:CreateTexture(nil, "BACKGROUND")
hbg:SetAllPoints(Handle)
hbg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
hbg:SetVertexColor(0,0,0)
hbg:SetAlpha(0.8)

local ht = Handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ht:SetPoint("CENTER", Handle, "CENTER", 0, 0)
ht:SetText("MINIMAP")

ApplyVisualState = function()
    -- Frame chrome remains immediate:
    -- only /mdock show makes background + MINIMAP handle visible.
    if forceShown then
        bg:Show()
        Handle:Show()
    else
        bg:Hide()
        Handle:Hide()
    end

    -- Icons fade toward target instead of snapping.
    if forceShown or hoverShown then
        fadeTarget = 1
    else
        fadeTarget = 0
    end
end

local function SetHoverShown(show)
    hoverShown = show and true or false
    ApplyVisualState()
end

local function CursorInsideDock()
    local left = Dock:GetLeft()
    local right = Dock:GetRight()
    local top = Dock:GetTop()
    local bottom = Dock:GetBottom()

    if not left or not right or not top or not bottom then
        return false
    end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    if not scale or scale == 0 then
        scale = 1
    end

    x = x / scale
    y = y / scale

    -- Small invisible margin makes the hidden dock easy to reveal.
    local margin = 5

    return x >= (left - margin)
       and x <= (right + margin)
       and y >= (bottom - margin)
       and y <= (top + margin)
end

Handle:SetScript("OnDragStart", function()
    draggingDock = true
    Dock:StartMoving()
end)

Handle:SetScript("OnDragStop", function()
    if draggingDock then
        Dock:StopMovingOrSizing()
        draggingDock = false
        SaveDock()
        Layout()
    end
end)

Dock:SetMovable(1)

------------------------------------------------------------
-- Startup
------------------------------------------------------------

SMD:RegisterEvent("VARIABLES_LOADED")
SMD:RegisterEvent("PLAYER_ENTERING_WORLD")

SMD:SetScript("OnEvent", function()
    EnsureDB()
    RestoreDock()
    RestoreRegistered()

    forceShown = SafeMinimapDockDB.forceShown and true or false

    -- Start icons hidden unless the dock is forced visible.
    hoverShown = false
    fadeAlpha = forceShown and 1 or 0
    fadeTarget = fadeAlpha
    ApplyVisualState()

    -- Apply starting alpha immediately once, then all later changes are faded.
    for name, frame in pairs(registered) do
        if frame then
            frame:SetAlpha((savedAlpha[name] or 1) * fadeAlpha)
        end
    end
end)

local function UpdateFade(elapsed)
    if fadeAlpha == fadeTarget then
        return
    end

    local step = elapsed / FADE_TIME

    if fadeTarget > fadeAlpha then
        fadeAlpha = fadeAlpha + step
        if fadeAlpha > fadeTarget then
            fadeAlpha = fadeTarget
        end
    else
        fadeAlpha = fadeAlpha - step
        if fadeAlpha < fadeTarget then
            fadeAlpha = fadeTarget
        end
    end

    for name, frame in pairs(registered) do
        if frame then
            local base = savedAlpha[name]
            if base == nil then
                base = 1
            end
            frame:SetAlpha(base * fadeAlpha)
        end
    end
end

SMD:SetScript("OnUpdate", function()
    UpdateFade(arg1)

    -- Hover detection only checks the dock's own saved rectangle.
    -- It does not scan minimap frames or discover icons.
    hoverElapsed = hoverElapsed + arg1
    if hoverElapsed >= 0.06 then
        hoverElapsed = 0

        if forceShown then
            -- /mdock show: frame chrome + icons stay visible.
            hoverShown = true
            ApplyVisualState()
        elseif CursorInsideDock() then
            -- Hover reveals icons only; frame chrome stays hidden.
            SetHoverShown(true)
        else
            if not draggingDock then
                SetHoverShown(false)
            end
        end
    end

    -- Existing delayed lookup for previously registered frame NAMES only.
    retryElapsed = retryElapsed + arg1
    if retryElapsed < 0.25 then
        return
    end
    retryElapsed = 0

    local changed = false

    for name in pairs(pending) do
        local frame = getglobal(name)
        if frame then
            RegisterFrame(frame)
            pending[name] = nil
            changed = true
        end
    end

    if changed then
        Layout()

        -- Newly restored icons must respect the current hover state.
        if not hoverShown then
            SetHoverShown(true)
            SetHoverShown(false)
        end
    end
end)

------------------------------------------------------------
-- Commands
------------------------------------------------------------

SLASH_SAFEMINIMAPDOCK1 = "/mdock"

SlashCmdList["SAFEMINIMAPDOCK"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "add" or msg == "" then
        RegisterMouseFrame()
        return
    end

    if msg == "remove" then
        UndockMouseFrame()
        return
    end

    if msg == "list" then
        EnsureDB()
        Print("Docked icons:")
        for i, name in ipairs(SafeMinimapDockDB.buttons) do
            Print(" "..i..". "..name)
        end
        return
    end

    if msg == "show" then
        EnsureDB()
        forceShown = true
        SafeMinimapDockDB.forceShown = true
        hoverShown = true
        ApplyVisualState()
        Print("Dock frame + icons locked visible. Use /mdock hide to restore icon-only hover mode.")
        return
    end

    if msg == "hide" then
        EnsureDB()
        forceShown = false
        SafeMinimapDockDB.forceShown = false
        hoverShown = CursorInsideDock() and true or false
        ApplyVisualState()
        Print("Icon-only hover mode restored.")
        return
    end

    if msg == "reset" then
        EnsureDB()
        SafeMinimapDockDB.x = 300
        SafeMinimapDockDB.y = 300
        RestoreDock()
        Layout()
        Print("Dock position reset.")
        return
    end

    Print("/mdock add - dock hovered icon")
    Print("/mdock remove - undock hovered icon")
    Print("/mdock list - list docked icons")
    Print("/mdock show - keep dock visible")
    Print("/mdock hide - restore hover-hide")
    Print("/mdock reset - reset dock position")
end
