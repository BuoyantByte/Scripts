local env = (getgenv and getgenv()) or _G
if env.BuoReconnectStop then
    pcall(env.BuoReconnectStop)
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do
    task.wait(0.1)
    player = Players.LocalPlayer
end

local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId
local CONFIG_FILE = "BuoReconnect_Config.json"
local SELF_FILE = "BuoReconnect.lua"
local MAX_SAME_TRIES = 20

local IS_PRIVATE = false
pcall(function()
    IS_PRIVATE = game.PrivateServerId ~= nil and game.PrivateServerId ~= ""
end)

local function say(text)
    print("[BuoReconnect] " .. text)
end

local config = {
    RestartTime = 24,
    RejoinSameServer = true,
    AnyServerFallback = true,
    TargetPlayer = "",
    TargetToggle = false,
}

if isfile and readfile then
    pcall(function()
        if isfile(CONFIG_FILE) then
            local saved = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if type(saved) == "table" then
                for k, v in pairs(saved) do
                    if config[k] ~= nil and type(v) == type(config[k]) then
                        config[k] = v
                    end
                end
            end
        end
    end)
end
config.RestartTime = math.clamp(math.floor(config.RestartTime), 1, 24)

local function saveConfig()
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(config))
        end)
    end
end

local alive = true
local connections = {}
local gui

local function track(conn)
    connections[#connections + 1] = conn
    return conn
end

local function stop()
    alive = false
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
    if gui then
        pcall(function() gui:Destroy() end)
    end
    if env.BuoReconnectStop == stop then
        env.BuoReconnectStop = nil
    end
end
env.BuoReconnectStop = stop

local statusLabel, titleLabel
local collapsed = false
local lastStatus = ""

local function setStatus(text)
    lastStatus = text
    if statusLabel then
        statusLabel.Text = text
    end
    if titleLabel and collapsed then
        titleLabel.Text = text
    end
end

local reconnecting = false
local failedFlag = false
local privateBlocked = false
local timerOff = IS_PRIVATE
local suppressUntil = 0
local queued = false

local function isPrivateBlock(text)
    return string.find(string.lower(tostring(text)), "private instance", 1, true) ~= nil
end

local function queueSelf()
    if queued then return end
    queued = true
    local q = queue_on_teleport or queueonteleport
    if q and isfile and isfile(SELF_FILE) then
        pcall(q, 'loadstring(readfile("' .. SELF_FILE .. '"))()')
    end
end

local function rejoin(reason)
    if reconnecting or not alive then return end
    if os.clock() < suppressUntil then return end
    reconnecting = true
    say("rejoin started: " .. tostring(reason))
    queueSelf()

    task.spawn(function()
        task.wait(2)
        local attempt = 0
        local sameFails = 0
        while alive do
            attempt = attempt + 1

            if privateBlocked and reason == "timer" then
                say("private server cannot be rejoined by JobId, timer restart cancelled")
                setStatus("Private: timer off")
                timerOff = true
                suppressUntil = os.clock() + 60
                reconnecting = false
                return
            end

            local useSame = config.RejoinSameServer and JOB_ID ~= ""
            if useSame and (privateBlocked or sameFails >= MAX_SAME_TRIES) then
                if config.AnyServerFallback then
                    useSame = false
                elseif privateBlocked then
                    say("private server cannot be rejoined by JobId and fallback is off, stopping")
                    setStatus("Private: can't rejoin")
                    return
                end
            end

            if useSame then
                setStatus(string.format("Reconnecting... (try %d)", attempt))
                say(string.format("try %d: same server %s", attempt, JOB_ID))
            else
                setStatus(string.format("Try %d (any server)", attempt))
                say(string.format("try %d: any server", attempt))
            end

            failedFlag = false
            local ok, err = pcall(function()
                if useSame then
                    TeleportService:TeleportToPlaceInstance(PLACE_ID, JOB_ID, player)
                else
                    TeleportService:Teleport(PLACE_ID, player)
                end
            end)
            if not ok then
                say("teleport call error: " .. tostring(err))
                failedFlag = true
            end

            local waited = 0
            while alive and waited < 20 and not failedFlag do
                task.wait(1)
                waited = waited + 1
            end

            if useSame then
                sameFails = sameFails + 1
            end
            if failedFlag then
                task.wait(4)
            end
        end
    end)
end

track(TeleportService.TeleportInitFailed:Connect(function(_, result, message)
    failedFlag = true
    local name = tostring(result):match("[^%.]+$") or "?"
    say("teleport failed: " .. name .. " | " .. tostring(message))
    if isPrivateBlock(message) then
        privateBlocked = true
    end
    if reconnecting then
        setStatus("Failed: " .. name)
    end
end))

track(GuiService.ErrorMessageChanged:Connect(function(message)
    if not message or message == "" then return end
    if reconnecting then
        failedFlag = true
        if isPrivateBlock(message) then
            privateBlocked = true
        end
        say("new error while reconnecting: " .. tostring(message))
    else
        rejoin("gui error: " .. tostring(message))
    end
end))

task.spawn(function()
    local ok, overlay = pcall(function()
        return CoreGui:WaitForChild("RobloxPromptGui", 10):WaitForChild("promptOverlay", 10)
    end)
    if not ok or not overlay or not alive then return end

    track(overlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" then
            rejoin("error prompt")
        end
    end))
    if overlay:FindFirstChild("ErrorPrompt") then
        rejoin("error prompt (already open)")
    end
end)

track(Players.PlayerRemoving:Connect(function(removed)
    if removed == player or not config.TargetToggle or config.TargetPlayer == "" then
        return
    end
    local target = config.TargetPlayer:lower()
    if removed.Name:lower() == target or removed.DisplayName:lower() == target then
        rejoin("target player left")
    end
end))

local endTime = os.time() + config.RestartTime * 3600

local function formatTime(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h >= 1 then
        return string.format("%dh %dm", h, m)
    elseif m >= 1 then
        return string.format("%dm", m)
    end
    return string.format("%ds", sec)
end

local function refreshStatus()
    if reconnecting or timerOff then return end
    setStatus("Time left: " .. formatTime(math.max(0, endTime - os.time())))
end

local function buildUI()
    local ACCENT = Color3.fromRGB(139, 92, 246)
    local BG = Color3.fromRGB(24, 22, 34)
    local ROW = Color3.fromRGB(44, 40, 62)
    local WHITE = Color3.fromRGB(240, 240, 245)
    local MUTED = Color3.fromRGB(170, 165, 190)
    local FONT = Enum.Font.GothamMedium
    local FULL_H = 238
    local TITLE_H = 28

    local function new(class, props, parent)
        local obj = Instance.new(class)
        for k, v in pairs(props) do
            obj[k] = v
        end
        obj.Parent = parent
        return obj
    end

    local function round(obj, radius)
        new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, obj)
    end

    gui = new("ScreenGui", {
        Name = "BuoReconnectLite",
        ResetOnSpawn = false,
        DisplayOrder = 999,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    local main = new("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(230, FULL_H),
        Position = UDim2.new(0, 12, 0.5, -FULL_H / 2),
        BackgroundColor3 = BG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
    }, gui)
    round(main, 8)

    local title = new("Frame", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, TITLE_H),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
    }, main)
    round(title, 8)

    titleLabel = new("TextLabel", {
        Size = UDim2.new(1, -36, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = "BuoReconnect",
        TextColor3 = WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, title)

    local collapseBtn = new("TextButton", {
        Size = UDim2.fromOffset(28, TITLE_H),
        Position = UDim2.new(1, -28, 0, 0),
        BackgroundTransparency = 1,
        Text = "-",
        TextColor3 = WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
    }, title)

    local body = new("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -TITLE_H),
        Position = UDim2.fromOffset(0, TITLE_H),
        BackgroundTransparency = 1,
    }, main)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, body)
    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)

    local order = 0
    local function nextOrder()
        order = order + 1
        return order
    end

    local function makeToggle(label, key)
        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = ROW,
            TextColor3 = WHITE,
            Font = FONT,
            TextSize = 13,
            LayoutOrder = nextOrder(),
        }, body)
        round(btn)

        local function refresh()
            local on = config[key]
            btn.Text = label .. ": " .. (on and "ON" or "OFF")
            btn.BackgroundColor3 = on and ACCENT or ROW
        end
        refresh()

        track(btn.Activated:Connect(function()
            config[key] = not config[key]
            refresh()
            saveConfig()
        end))
    end

    makeToggle("Same server", "RejoinSameServer")
    makeToggle("Fallback: any server", "AnyServerFallback")

    local hoursRow = new("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
    }, body)

    local function makeStepper(text, xPos)
        local b = new("TextButton", {
            Size = UDim2.fromOffset(36, 28),
            Position = xPos,
            BackgroundColor3 = ROW,
            Text = text,
            TextColor3 = WHITE,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
        }, hoursRow)
        round(b)
        return b
    end

    local minusBtn = makeStepper("-", UDim2.fromOffset(0, 0))
    local plusBtn = makeStepper("+", UDim2.new(1, -36, 0, 0))
    local hoursLabel = new("TextLabel", {
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.fromOffset(40, 0),
        BackgroundTransparency = 1,
        TextColor3 = WHITE,
        Font = FONT,
        TextSize = 13,
    }, hoursRow)

    local function updateHoursLabel()
        hoursLabel.Text = "Restart every " .. config.RestartTime .. " h"
    end
    updateHoursLabel()

    local function setHours(h)
        h = math.clamp(h, 1, 24)
        if h == config.RestartTime then return end

        local now = os.time()
        local remaining = math.max(0, endTime - now)
        endTime = now + math.max(5, remaining + (h - config.RestartTime) * 3600)

        config.RestartTime = h
        updateHoursLabel()
        saveConfig()
        refreshStatus()
    end

    track(minusBtn.Activated:Connect(function() setHours(config.RestartTime - 1) end))
    track(plusBtn.Activated:Connect(function() setHours(config.RestartTime + 1) end))

    statusLabel = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "Time left: ...",
        TextColor3 = MUTED,
        Font = FONT,
        TextSize = 13,
        LayoutOrder = nextOrder(),
    }, body)

    makeToggle("Target player", "TargetToggle")

    local targetBox = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = ROW,
        Text = config.TargetPlayer,
        PlaceholderText = "Target player name",
        PlaceholderColor3 = MUTED,
        TextColor3 = WHITE,
        Font = FONT,
        TextSize = 13,
        ClearTextOnFocus = false,
        LayoutOrder = nextOrder(),
    }, body)
    round(targetBox)

    track(targetBox.FocusLost:Connect(function()
        config.TargetPlayer = (targetBox.Text:gsub("^%s*(.-)%s*$", "%1"))
        saveConfig()
    end))

    track(collapseBtn.Activated:Connect(function()
        collapsed = not collapsed
        body.Visible = not collapsed
        main.Size = UDim2.fromOffset(230, collapsed and TITLE_H or FULL_H)
        collapseBtn.Text = collapsed and "+" or "-"
        titleLabel.Text = collapsed and lastStatus or "BuoReconnect"
    end))

    local dragging = false
    local dragStart = nil
    local startPos = nil

    track(title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    c:Disconnect()
                end
            end)
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.K then
            gui.Enabled = not gui.Enabled
        end
    end))

    local mounted = false
    if gethui then
        mounted = pcall(function() gui.Parent = gethui() end) and gui.Parent ~= nil
    end
    if not mounted then
        mounted = pcall(function() gui.Parent = CoreGui end) and gui.Parent ~= nil
    end
    if not mounted then
        gui.Parent = player:WaitForChild("PlayerGui")
    end
end

local okUI, errUI = pcall(buildUI)
if not okUI then
    say("UI error: " .. tostring(errUI))
    if gui then
        pcall(function() gui:Destroy() end)
        gui = nil
    end
end

task.spawn(function()
    if timerOff then
        setStatus("Private: timer off")
        return
    end
    while alive and not timerOff do
        local remaining = endTime - os.time()
        if remaining <= 0 then
            rejoin("timer")
            break
        end
        refreshStatus()
        task.wait(remaining > 120 and 15 or 1)
    end
end)

say("started, restart every " .. config.RestartTime .. " h, private " .. tostring(IS_PRIVATE) .. ", jobId " .. tostring(JOB_ID))
