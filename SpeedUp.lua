local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local TITLE = "SpeedUp by BuoByte"
local GUI_NAME = "SpeedUp"
local MIN_SPEED = 20
local MAX_SPEED = 90
local STEP = 5
local TOGGLE_KEY = Enum.KeyCode.V
local HEADER_HEIGHT = 28
local DEFAULT_HINT = "limit " .. MIN_SPEED .. "-" .. MAX_SPEED .. "   |   V to hide"

local COLOR_BG = Color3.fromRGB(24, 24, 24)
local COLOR_HEADER = Color3.fromRGB(16, 16, 16)
local COLOR_ELEMENT = Color3.fromRGB(38, 38, 38)
local COLOR_BORDER = Color3.fromRGB(62, 62, 62)
local COLOR_ACCENT = Color3.fromRGB(125, 75, 200)
local COLOR_ON = Color3.fromRGB(110, 190, 110)
local COLOR_OFF = Color3.fromRGB(205, 85, 85)
local COLOR_TEXT = Color3.fromRGB(225, 225, 225)
local COLOR_MUTED = Color3.fromRGB(125, 125, 125)

local env = (getgenv and getgenv()) or _G

if env.CheaterDebuffCleanup then
    pcall(env.CheaterDebuffCleanup)
end
if env.SpeedUpCleanup then
    pcall(env.SpeedUpCleanup)
end

local player = Players.LocalPlayer
local speed = MIN_SPEED
local enabled = true
local originalSpeed = nil
local humanoid = nil
local humanoidConnection = nil
local connections = {}
local statusToken = 0
local dragging = false
local dragStart = nil
local startPosition = nil
local sliding = false

local function findContainers()
    local list = {}
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then
            table.insert(list, result)
        end
    end
    table.insert(list, CoreGui)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(list, playerGui)
    end
    return list
end

for _, container in ipairs(findContainers()) do
    pcall(function()
        local old = container:FindFirstChild(GUI_NAME)
        if old then
            old:Destroy()
        end
    end)
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mounted = false
for _, container in ipairs(findContainers()) do
    local ok = pcall(function()
        gui.Parent = container
    end)
    if ok and gui.Parent == container then
        mounted = true
        break
    end
end

if not mounted then
    gui:Destroy()
    warn("SpeedUp: could not mount GUI")
    return
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function create(className, properties, parent)
    local instance = Instance.new(className)
    for key, value in pairs(properties) do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end

local function isPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local frame = create("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 230, 0, 182),
    Position = UDim2.new(0.5, -115, 0.5, -91),
    BackgroundColor3 = COLOR_BG,
    BorderColor3 = COLOR_BORDER,
    BorderSizePixel = 1,
    Active = true,
}, gui)

local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
    BackgroundColor3 = COLOR_HEADER,
    BorderSizePixel = 0,
}, frame)

create("TextLabel", {
    Size = UDim2.new(1, -36, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1,
    Text = TITLE,
    TextColor3 = COLOR_TEXT,
    Font = Enum.Font.SourceSansBold,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, header)

local closeButton = create("TextButton", {
    Size = UDim2.new(0, 28, 0, HEADER_HEIGHT),
    Position = UDim2.new(1, -28, 0, 0),
    BackgroundTransparency = 1,
    Text = "x",
    TextColor3 = COLOR_MUTED,
    Font = Enum.Font.SourceSansBold,
    TextSize = 20,
}, header)

create("Frame", {
    Size = UDim2.new(1, 0, 0, 2),
    Position = UDim2.new(0, 0, 0, HEADER_HEIGHT),
    BackgroundColor3 = COLOR_ACCENT,
    BorderSizePixel = 0,
}, frame)

create("TextLabel", {
    Size = UDim2.new(0.5, -10, 0, 20),
    Position = UDim2.new(0, 10, 0, 38),
    BackgroundTransparency = 1,
    Text = "Speed",
    TextColor3 = COLOR_MUTED,
    Font = Enum.Font.SourceSans,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
}, frame)

local speedValue = create("TextLabel", {
    Size = UDim2.new(0.5, -10, 0, 20),
    Position = UDim2.new(0.5, 0, 0, 38),
    BackgroundTransparency = 1,
    Text = tostring(speed),
    TextColor3 = COLOR_ACCENT,
    Font = Enum.Font.Code,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Right,
}, frame)

local sliderHit = create("Frame", {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, 58),
    BackgroundTransparency = 1,
    Active = true,
}, frame)

local track = create("Frame", {
    Size = UDim2.new(1, 0, 0, 4),
    Position = UDim2.new(0, 0, 0.5, -2),
    BackgroundColor3 = COLOR_ELEMENT,
    BorderSizePixel = 0,
}, sliderHit)

local fill = create("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = COLOR_ACCENT,
    BorderSizePixel = 0,
}, track)

local knob = create("Frame", {
    Size = UDim2.new(0, 8, 0, 16),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = COLOR_TEXT,
    BorderSizePixel = 0,
}, track)

local minusButton = create("TextButton", {
    Size = UDim2.new(0, 32, 0, 28),
    Position = UDim2.new(0, 10, 0, 90),
    BackgroundColor3 = COLOR_ELEMENT,
    BorderColor3 = COLOR_BORDER,
    BorderSizePixel = 1,
    Text = "-",
    TextColor3 = COLOR_TEXT,
    Font = Enum.Font.SourceSansBold,
    TextSize = 20,
}, frame)

local textBox = create("TextBox", {
    Size = UDim2.new(1, -96, 0, 28),
    Position = UDim2.new(0, 48, 0, 90),
    BackgroundColor3 = COLOR_ELEMENT,
    BorderColor3 = COLOR_BORDER,
    BorderSizePixel = 1,
    Text = tostring(speed),
    PlaceholderText = MIN_SPEED .. "-" .. MAX_SPEED,
    PlaceholderColor3 = COLOR_MUTED,
    TextColor3 = COLOR_TEXT,
    Font = Enum.Font.Code,
    TextSize = 16,
    ClearTextOnFocus = false,
}, frame)

local plusButton = create("TextButton", {
    Size = UDim2.new(0, 32, 0, 28),
    Position = UDim2.new(1, -42, 0, 90),
    BackgroundColor3 = COLOR_ELEMENT,
    BorderColor3 = COLOR_BORDER,
    BorderSizePixel = 1,
    Text = "+",
    TextColor3 = COLOR_TEXT,
    Font = Enum.Font.SourceSansBold,
    TextSize = 20,
}, frame)

local toggleButton = create("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 28),
    Position = UDim2.new(0, 10, 0, 124),
    BackgroundColor3 = COLOR_ELEMENT,
    BorderColor3 = COLOR_BORDER,
    BorderSizePixel = 1,
    Text = "ON",
    TextColor3 = COLOR_ON,
    Font = Enum.Font.SourceSansBold,
    TextSize = 17,
}, frame)

local resetButton = create("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 28),
    Position = UDim2.new(0.5, 5, 0, 124),
    BackgroundColor3 = COLOR_ELEMENT,
    BorderColor3 = COLOR_BORDER,
    BorderSizePixel = 1,
    Text = "Reset " .. MIN_SPEED,
    TextColor3 = COLOR_TEXT,
    Font = Enum.Font.SourceSansBold,
    TextSize = 17,
}, frame)

local hint = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18),
    Position = UDim2.new(0, 10, 0, 158),
    BackgroundTransparency = 1,
    Text = DEFAULT_HINT,
    TextColor3 = COLOR_MUTED,
    Font = Enum.Font.SourceSans,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, frame)

local openButton = create("TextButton", {
    Size = UDim2.new(0, 62, 0, 30),
    Position = UDim2.new(0, 8, 0.4, 0),
    BackgroundColor3 = COLOR_HEADER,
    BorderColor3 = COLOR_ACCENT,
    BorderSizePixel = 1,
    Text = "SpeedUp",
    TextColor3 = COLOR_ACCENT,
    Font = Enum.Font.SourceSansBold,
    TextSize = 16,
}, gui)

local function sanitize(value)
    if type(value) ~= "number" or value ~= value then
        return nil
    end
    return math.clamp(math.floor(value + 0.5), MIN_SPEED, MAX_SPEED)
end

local function applySpeed()
    if not enabled then
        return
    end
    local current = humanoid
    if current and current.Parent and current.WalkSpeed ~= speed then
        current.WalkSpeed = speed
    end
end

local function refreshUi()
    local alpha = (speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
    speedValue.Text = tostring(speed)
    fill.Size = UDim2.new(alpha, 0, 1, 0)
    knob.Position = UDim2.new(alpha, 0, 0.5, 0)
    fill.BackgroundColor3 = enabled and COLOR_ACCENT or COLOR_MUTED
    speedValue.TextColor3 = enabled and COLOR_ACCENT or COLOR_MUTED
    toggleButton.Text = enabled and "ON" or "OFF"
    toggleButton.TextColor3 = enabled and COLOR_ON or COLOR_OFF
    if not textBox:IsFocused() then
        textBox.Text = tostring(speed)
    end
end

local function showStatus(text)
    statusToken = statusToken + 1
    local token = statusToken
    hint.Text = text
    task.delay(1.5, function()
        if statusToken == token and hint.Parent then
            hint.Text = DEFAULT_HINT
        end
    end)
end

local function setSpeed(value)
    local clean = sanitize(value)
    if not clean then
        return false
    end
    speed = clean
    applySpeed()
    refreshUi()
    return true
end

local function setEnabled(state)
    enabled = state
    if enabled then
        applySpeed()
    elseif humanoid and humanoid.Parent and originalSpeed then
        humanoid.WalkSpeed = originalSpeed
    end
    refreshUi()
end

local function updateFromPosition(x)
    local width = track.AbsoluteSize.X
    if width <= 0 then
        return
    end
    local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
    setSpeed(MIN_SPEED + alpha * (MAX_SPEED - MIN_SPEED))
end

local function onCharacter(character)
    task.spawn(function()
        local found = character:WaitForChild("Humanoid", 10)
        if not found then
            return
        end
        if humanoidConnection then
            humanoidConnection:Disconnect()
        end
        humanoid = found
        originalSpeed = found.WalkSpeed
        humanoidConnection = found:GetPropertyChangedSignal("WalkSpeed"):Connect(applySpeed)
        applySpeed()
    end)
end

local function cleanup()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    connections = {}
    if humanoidConnection then
        humanoidConnection:Disconnect()
        humanoidConnection = nil
    end
    if humanoid and humanoid.Parent and originalSpeed then
        pcall(function()
            humanoid.WalkSpeed = originalSpeed
        end)
    end
    gui:Destroy()
    env.SpeedUpCleanup = nil
end

env.SpeedUpCleanup = cleanup

connect(header.InputBegan, function(input)
    if isPointer(input) then
        dragging = true
        dragStart = input.Position
        startPosition = frame.AbsolutePosition
    end
end)

connect(sliderHit.InputBegan, function(input)
    if isPointer(input) then
        sliding = true
        updateFromPosition(input.Position.X)
    end
end)

connect(UserInputService.InputChanged, function(input)
    local moving = input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    if not moving then
        return
    end
    if dragging and dragStart and startPosition then
        local delta = input.Position - dragStart
        local viewport = gui.AbsoluteSize
        local x = math.clamp(startPosition.X + delta.X, 0, math.max(viewport.X - frame.AbsoluteSize.X, 0))
        local y = math.clamp(startPosition.Y + delta.Y, 0, math.max(viewport.Y - HEADER_HEIGHT, 0))
        frame.Position = UDim2.fromOffset(x, y)
    end
    if sliding then
        updateFromPosition(input.Position.X)
    end
end)

connect(UserInputService.InputEnded, function(input)
    if isPointer(input) then
        dragging = false
        sliding = false
    end
end)

connect(textBox.FocusLost, function()
    local value = tonumber(textBox.Text)
    if value then
        if value < MIN_SPEED or value > MAX_SPEED then
            showStatus("clamped to " .. sanitize(value))
        end
        setSpeed(value)
    else
        showStatus("enter a number " .. MIN_SPEED .. "-" .. MAX_SPEED)
    end
    textBox.Text = tostring(speed)
end)

connect(minusButton.Activated, function()
    setSpeed(speed - STEP)
end)

connect(plusButton.Activated, function()
    setSpeed(speed + STEP)
end)

connect(toggleButton.Activated, function()
    setEnabled(not enabled)
end)

connect(resetButton.Activated, function()
    setSpeed(MIN_SPEED)
end)

connect(closeButton.Activated, cleanup)

connect(openButton.Activated, function()
    frame.Visible = not frame.Visible
end)

connect(UserInputService.InputBegan, function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == TOGGLE_KEY then
        frame.Visible = not frame.Visible
    end
end)

connect(RunService.Heartbeat, applySpeed)
connect(player.CharacterAdded, onCharacter)

if player.Character then
    onCharacter(player.Character)
end

refreshUi()
