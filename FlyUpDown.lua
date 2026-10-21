local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local TITLE = "Fly by BuoByte"
local GUI_NAME = "FlyGui"
local MIN_SPEED = 10
local MAX_SPEED = 300
local DEFAULT_SPEED = 60
local STEP = 10
local FLY_KEY = Enum.KeyCode.F
local HIDE_KEY = Enum.KeyCode.V
local UP_KEY = Enum.KeyCode.Space
local DOWN_KEY = Enum.KeyCode.LeftControl
local HEADER_HEIGHT = 28
local LINE_HEIGHT = 2
local TOP_HEIGHT = HEADER_HEIGHT + LINE_HEIGHT
local WIDTH = 230
local HEIGHT = 216
local DEFAULT_HINT = "F fly  |  V hide  |  Space/Ctrl"

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

if env.FlyGuiCleanup then
    pcall(env.FlyGuiCleanup)
end

local player = Players.LocalPlayer
local speed = DEFAULT_SPEED
local flying = false
local lookSteer = true
local upGui = false
local downGui = false
local upKey = false
local downKey = false
local flyGyro = nil
local flyVelocity = nil
local connections = {}
local statusToken = 0
local dragging = false
local sliding = false
local dragStart = nil
local startPosition = nil

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
    warn("FlyGui: could not mount GUI")
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

local function element(className, properties, parent)
    properties.BackgroundColor3 = properties.BackgroundColor3 or COLOR_ELEMENT
    properties.BorderColor3 = COLOR_BORDER
    properties.BorderSizePixel = 1
    properties.TextColor3 = properties.TextColor3 or COLOR_TEXT
    return create(className, properties, parent)
end

local function isPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local frame = create("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(WIDTH, HEIGHT),
    Position = UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2),
    BackgroundColor3 = COLOR_BG,
    BorderColor3 = COLOR_BORDER,
    BorderSizePixel = 1,
    ClipsDescendants = true,
    Active = true,
}, gui)

local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
    BackgroundColor3 = COLOR_HEADER,
    BorderSizePixel = 0,
}, frame)

create("TextLabel", {
    Size = UDim2.new(1, -64, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1,
    Text = TITLE,
    TextColor3 = COLOR_TEXT,
    Font = Enum.Font.SourceSansBold,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, header)

local collapseButton = create("TextButton", {
    Size = UDim2.new(0, 28, 0, HEADER_HEIGHT),
    Position = UDim2.new(1, -56, 0, 0),
    BackgroundTransparency = 1,
    Text = "-",
    TextColor3 = COLOR_MUTED,
    Font = Enum.Font.SourceSansBold,
    TextSize = 20,
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
    Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
    Position = UDim2.new(0, 0, 0, HEADER_HEIGHT),
    BackgroundColor3 = COLOR_ACCENT,
    BorderSizePixel = 0,
}, frame)

local body = create("Frame", {
    Name = "Body",
    Size = UDim2.new(1, 0, 1, -TOP_HEIGHT),
    Position = UDim2.new(0, 0, 0, TOP_HEIGHT),
    BackgroundTransparency = 1,
}, frame)

create("TextLabel", {
    Size = UDim2.new(0.5, -10, 0, 20),
    Position = UDim2.new(0, 10, 0, 8),
    BackgroundTransparency = 1,
    Text = "Speed",
    TextColor3 = COLOR_MUTED,
    Font = Enum.Font.SourceSans,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
}, body)

local speedValue = create("TextLabel", {
    Size = UDim2.new(0.5, -10, 0, 20),
    Position = UDim2.new(0.5, 0, 0, 8),
    BackgroundTransparency = 1,
    Text = tostring(speed),
    TextColor3 = COLOR_ACCENT,
    Font = Enum.Font.Code,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Right,
}, body)

local sliderHit = create("Frame", {
    Size = UDim2.new(1, -20, 0, 24),
    Position = UDim2.new(0, 10, 0, 30),
    BackgroundTransparency = 1,
    Active = true,
}, body)

local sliderTrack = create("Frame", {
    Size = UDim2.new(1, 0, 0, 4),
    Position = UDim2.new(0, 0, 0.5, -2),
    BackgroundColor3 = COLOR_ELEMENT,
    BorderSizePixel = 0,
}, sliderHit)

local sliderFill = create("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = COLOR_ACCENT,
    BorderSizePixel = 0,
}, sliderTrack)

local sliderKnob = create("Frame", {
    Size = UDim2.new(0, 8, 0, 16),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = COLOR_TEXT,
    BorderSizePixel = 0,
}, sliderTrack)

local minusButton = element("TextButton", {
    Size = UDim2.new(0, 32, 0, 28),
    Position = UDim2.new(0, 10, 0, 58),
    Text = "-",
    Font = Enum.Font.SourceSansBold,
    TextSize = 20,
}, body)

local textBox = element("TextBox", {
    Size = UDim2.new(1, -96, 0, 28),
    Position = UDim2.new(0, 48, 0, 58),
    Text = tostring(speed),
    PlaceholderText = MIN_SPEED .. "-" .. MAX_SPEED,
    PlaceholderColor3 = COLOR_MUTED,
    Font = Enum.Font.Code,
    TextSize = 16,
    ClearTextOnFocus = false,
}, body)

local plusButton = element("TextButton", {
    Size = UDim2.new(0, 32, 0, 28),
    Position = UDim2.new(1, -42, 0, 58),
    Text = "+",
    Font = Enum.Font.SourceSansBold,
    TextSize = 20,
}, body)

local upButton = element("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 28),
    Position = UDim2.new(0, 10, 0, 92),
    Text = "Up",
    Font = Enum.Font.SourceSansBold,
    TextSize = 17,
}, body)

local downButton = element("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 28),
    Position = UDim2.new(0.5, 5, 0, 92),
    Text = "Down",
    Font = Enum.Font.SourceSansBold,
    TextSize = 17,
}, body)

local flyButton = element("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 28),
    Position = UDim2.new(0, 10, 0, 126),
    Text = "Fly: OFF",
    TextColor3 = COLOR_OFF,
    Font = Enum.Font.SourceSansBold,
    TextSize = 17,
}, body)

local lookButton = element("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 28),
    Position = UDim2.new(0.5, 5, 0, 126),
    Text = "Look: ON",
    TextColor3 = COLOR_ON,
    Font = Enum.Font.SourceSansBold,
    TextSize = 17,
}, body)

local hint = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18),
    Position = UDim2.new(0, 10, 0, 160),
    BackgroundTransparency = 1,
    Text = DEFAULT_HINT,
    TextColor3 = COLOR_MUTED,
    Font = Enum.Font.SourceSans,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, body)

local function refreshUi()
    local alpha = (speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
    speedValue.Text = tostring(speed)
    sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
    sliderKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
    if not textBox:IsFocused() then
        textBox.Text = tostring(speed)
    end
    flyButton.Text = flying and "Fly: ON" or "Fly: OFF"
    flyButton.TextColor3 = flying and COLOR_ON or COLOR_OFF
    lookButton.Text = lookSteer and "Look: ON" or "Look: OFF"
    lookButton.TextColor3 = lookSteer and COLOR_ON or COLOR_OFF
    upButton.BackgroundColor3 = (flying and (upGui or upKey)) and COLOR_ACCENT or COLOR_ELEMENT
    downButton.BackgroundColor3 = (flying and (downGui or downKey)) and COLOR_ACCENT or COLOR_ELEMENT
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

local function sanitize(value)
    if type(value) ~= "number" or value ~= value then
        return nil
    end
    return math.clamp(math.floor(value + 0.5), MIN_SPEED, MAX_SPEED)
end

local function setSpeed(value)
    local clean = sanitize(value)
    if not clean then
        return false
    end
    speed = clean
    refreshUi()
    return true
end

local function updateFromPosition(x)
    local width = sliderTrack.AbsoluteSize.X
    if width <= 0 then
        return
    end
    local alpha = math.clamp((x - sliderTrack.AbsolutePosition.X) / width, 0, 1)
    setSpeed(MIN_SPEED + alpha * (MAX_SPEED - MIN_SPEED))
end

local function getParts()
    local character = player.Character
    if not character then
        return nil, nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") or (humanoid and humanoid.RootPart)
    return humanoid, root
end

local function destroyMovers()
    if flyGyro then
        pcall(function()
            flyGyro:Destroy()
        end)
        flyGyro = nil
    end
    if flyVelocity then
        pcall(function()
            flyVelocity:Destroy()
        end)
        flyVelocity = nil
    end
end

local function ensureMovers(root)
    if not flyGyro or flyGyro.Parent ~= root then
        if flyGyro then
            pcall(function()
                flyGyro:Destroy()
            end)
        end
        flyGyro = Instance.new("BodyGyro")
        flyGyro.Name = "FlyGyro"
        flyGyro.P = 90000
        flyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyGyro.CFrame = root.CFrame
        flyGyro.Parent = root
    end
    if not flyVelocity or flyVelocity.Parent ~= root then
        if flyVelocity then
            pcall(function()
                flyVelocity:Destroy()
            end)
        end
        flyVelocity = Instance.new("BodyVelocity")
        flyVelocity.Name = "FlyVelocity"
        flyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyVelocity.Parent = root
    end
end

local function setFlying(state)
    if state == flying then
        return
    end
    local humanoid, root = getParts()
    if state then
        if not humanoid or not root or humanoid.Health <= 0 then
            showStatus("no character")
            return
        end
        flying = true
        ensureMovers(root)
        humanoid.PlatformStand = true
    else
        flying = false
        destroyMovers()
        if humanoid then
            humanoid.PlatformStand = false
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
        end
    end
    refreshUi()
end

local function bindHold(button, setHeld)
    connect(button.InputBegan, function(input)
        if isPointer(input) then
            setHeld(true)
            refreshUi()
            local release
            release = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    setHeld(false)
                    refreshUi()
                    release:Disconnect()
                end
            end)
        end
    end)
end

bindHold(upButton, function(state)
    upGui = state
end)

bindHold(downButton, function(state)
    downGui = state
end)

connect(RunService.Heartbeat, function()
    if not flying then
        return
    end
    local humanoid, root = getParts()
    if not humanoid or not root or humanoid.Health <= 0 then
        setFlying(false)
        return
    end
    ensureMovers(root)
    local camera = workspace.CurrentCamera
    local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    local hasFlat = flat.Magnitude > 0.001
    if hasFlat then
        flat = flat.Unit
    end
    local move = humanoid.MoveDirection
    local direction = move
    if lookSteer and hasFlat and move.Magnitude > 0 then
        local rightVector = Vector3.new(-flat.Z, 0, flat.X)
        direction = look * move:Dot(flat) + rightVector * move:Dot(rightVector)
    end
    local vertical = ((upGui or upKey) and 1 or 0) - ((downGui or downKey) and 1 or 0)
    direction = direction + Vector3.new(0, vertical, 0)
    if direction.Magnitude > 1 then
        direction = direction.Unit
    end
    flyVelocity.Velocity = direction * speed
    if hasFlat then
        flyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
    end
end)

connect(player.CharacterAdded, function()
    flying = false
    destroyMovers()
    refreshUi()
end)

local function cleanup()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    connections = {}
    destroyMovers()
    if flying then
        flying = false
        local humanoid = getParts()
        if humanoid then
            pcall(function()
                humanoid.PlatformStand = false
            end)
        end
    end
    gui:Destroy()
    env.FlyGuiCleanup = nil
end

env.FlyGuiCleanup = cleanup

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
    elseif input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == UP_KEY then
            upKey = false
        elseif input.KeyCode == DOWN_KEY then
            downKey = false
        end
        refreshUi()
    end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    if UserInputService:GetFocusedTextBox() then
        return
    end
    local key = input.KeyCode
    if key == UP_KEY then
        upKey = true
        refreshUi()
    elseif key == DOWN_KEY then
        downKey = true
        refreshUi()
    elseif not processed and key == FLY_KEY then
        setFlying(not flying)
    elseif not processed and key == HIDE_KEY then
        frame.Visible = not frame.Visible
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

connect(flyButton.Activated, function()
    setFlying(not flying)
end)

connect(lookButton.Activated, function()
    lookSteer = not lookSteer
    refreshUi()
end)

local collapsed = false
connect(collapseButton.Activated, function()
    collapsed = not collapsed
    body.Visible = not collapsed
    frame.Size = UDim2.fromOffset(WIDTH, collapsed and TOP_HEIGHT or HEIGHT)
    collapseButton.Text = collapsed and "+" or "-"
end)

connect(closeButton.Activated, cleanup)

refreshUi()
