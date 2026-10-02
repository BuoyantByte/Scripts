local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

if CoreGui:FindFirstChild("BuoFlyGui") then
    CoreGui.BuoFlyGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BuoFlyGui"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.Position = UDim2.new(0.4, 0, 0.2, 0)
MainFrame.Size = UDim2.new(0, 150, 0, 100)
MainFrame.Active = true
MainFrame.Draggable = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.GothamBold
Title.Text = "BuoFly"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14

local SpeedFrame = Instance.new("Frame")
SpeedFrame.Parent = MainFrame
SpeedFrame.BackgroundTransparency = 1
SpeedFrame.Position = UDim2.new(0, 0, 0, 30)
SpeedFrame.Size = UDim2.new(1, 0, 0, 30)

local BtnMinus = Instance.new("TextButton")
BtnMinus.Parent = SpeedFrame
BtnMinus.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
BtnMinus.Position = UDim2.new(0, 10, 0, 0)
BtnMinus.Size = UDim2.new(0, 30, 0, 30)
BtnMinus.Font = Enum.Font.GothamBold
BtnMinus.Text = "-"
BtnMinus.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnMinus.TextSize = 18
Instance.new("UICorner", BtnMinus).CornerRadius = UDim.new(0, 6)

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Parent = SpeedFrame
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Position = UDim2.new(0, 45, 0, 0)
SpeedLabel.Size = UDim2.new(0, 60, 0, 30)
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.Text = "100" -- Стартовая скорость теперь 100
SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SpeedLabel.TextSize = 16

local BtnPlus = Instance.new("TextButton")
BtnPlus.Parent = SpeedFrame
BtnPlus.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
BtnPlus.Position = UDim2.new(0, 110, 0, 0)
BtnPlus.Size = UDim2.new(0, 30, 0, 30)
BtnPlus.Font = Enum.Font.GothamBold
BtnPlus.Text = "+"
BtnPlus.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnPlus.TextSize = 18
Instance.new("UICorner", BtnPlus).CornerRadius = UDim.new(0, 6)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Parent = MainFrame
ToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
ToggleBtn.Position = UDim2.new(0, 10, 0, 65)
ToggleBtn.Size = UDim2.new(1, -20, 0, 25)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Text = "OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
ToggleBtn.TextSize = 14
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)

local speeds = 150 
local flying = false
local bv, bg, flyLoop

local function getChar() return player.Character end
local function getHrp() local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar(); return c and c:FindFirstChildWhichIsA("Humanoid") end

local function startFly()
    local hrp = getHrp()
    local hum = getHum()
    if not hrp or not hum then return end

    flying = true
    hum.PlatformStand = true

    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 9e4
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp

    flyLoop = RunService.RenderStepped:Connect(function()
        if not flying or not hrp or not hum then return end

        local cam = workspace.CurrentCamera
        local moveDir = hum.MoveDirection

        bg.CFrame = cam.CFrame

        if moveDir.Magnitude > 0 then
            local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
            local flatCamCFrame = CFrame.new(Vector3.zero, flatLook)
            
            local localMove = flatCamCFrame:VectorToObjectSpace(moveDir)
            local flyDir = cam.CFrame:VectorToWorldSpace(localMove)
            
            bv.Velocity = flyDir * speeds
        else
            bv.Velocity = Vector3.zero
        end
    end)
end

local function stopFly()
    flying = false
    if flyLoop then flyLoop:Disconnect(); flyLoop = nil end
    if bv then bv:Destroy(); bv = nil end
    if bg then bg:Destroy(); bg = nil end

    local hum = getHum()
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

ToggleBtn.MouseButton1Down:Connect(function()
    if flying then
        stopFly()
        ToggleBtn.Text = "OFF"
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        startFly()
        ToggleBtn.Text = "ON"
        ToggleBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end)

BtnPlus.MouseButton1Down:Connect(function()
    speeds = speeds + 25 
    SpeedLabel.Text = tostring(speeds)
end)

BtnMinus.MouseButton1Down:Connect(function()
    if speeds > 25 then
        speeds = speeds - 25 
        SpeedLabel.Text = tostring(speeds)
    end
end)

player.CharacterAdded:Connect(function()
    if flying then
        stopFly()
        ToggleBtn.Text = "OFF"
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)