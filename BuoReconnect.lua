local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local currentJobId = game.JobId 

local configFileName = "BuoReconnect_Config.json"
local config = {
    RestartTime = 4,
    RejoinSameServer = true,
    TargetPlayer = "",
    TargetToggle = false
}

if isfile and readfile and isfile(configFileName) then
    pcall(function()
        local saved = HttpService:JSONDecode(readfile(configFileName))
        if type(saved) == "table" then
            for k, v in pairs(saved) do config[k] = v end
        end
    end)
end

if type(config.RestartTime) ~= "number" then config.RestartTime = 4 end
if config.RestartTime > 24 then config.RestartTime = 24 end
if config.RestartTime < 1 then config.RestartTime = 1 end

local function saveConfig()
    if writefile then
        pcall(function() writefile(configFileName, HttpService:JSONEncode(config)) end)
    end
end

saveConfig()

if CoreGui:FindFirstChild("BuoReconLite") then
    CoreGui.BuoReconLite:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BuoReconLite"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Position = UDim2.new(0.6, 0, 0.2, 0)
MainFrame.Size = UDim2.new(0, 220, 0, 230)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.GothamBold
Title.Text = "BuoReconnect"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Parent = MainFrame
TimeLabel.BackgroundTransparency = 1
TimeLabel.Position = UDim2.new(0, 0, 0, 30)
TimeLabel.Size = UDim2.new(1, 0, 0, 25)
TimeLabel.Font = Enum.Font.GothamBold
TimeLabel.Text = "00:00:00"
TimeLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
TimeLabel.TextSize = 18

local HoursFrame = Instance.new("Frame")
HoursFrame.Parent = MainFrame
HoursFrame.BackgroundTransparency = 1
HoursFrame.Position = UDim2.new(0, 10, 0, 65)
HoursFrame.Size = UDim2.new(1, -20, 0, 30)

local BtnMinus = Instance.new("TextButton")
BtnMinus.Parent = HoursFrame
BtnMinus.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
BtnMinus.Position = UDim2.new(0, 0, 0, 0)
BtnMinus.Size = UDim2.new(0, 30, 1, 0)
BtnMinus.Font = Enum.Font.GothamBold
BtnMinus.Text = "-"
BtnMinus.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnMinus.TextSize = 18
Instance.new("UICorner", BtnMinus).CornerRadius = UDim.new(0, 6)

local HoursLabel = Instance.new("TextLabel")
HoursLabel.Parent = HoursFrame
HoursLabel.BackgroundTransparency = 1
HoursLabel.Position = UDim2.new(0, 35, 0, 0)
HoursLabel.Size = UDim2.new(1, -70, 1, 0)
HoursLabel.Font = Enum.Font.GothamSemibold
HoursLabel.Text = "Restart: " .. config.RestartTime .. "h"
HoursLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
HoursLabel.TextSize = 14

local BtnPlus = Instance.new("TextButton")
BtnPlus.Parent = HoursFrame
BtnPlus.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
BtnPlus.Position = UDim2.new(1, -30, 0, 0)
BtnPlus.Size = UDim2.new(0, 30, 1, 0)
BtnPlus.Font = Enum.Font.GothamBold
BtnPlus.Text = "+"
BtnPlus.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnPlus.TextSize = 18
Instance.new("UICorner", BtnPlus).CornerRadius = UDim.new(0, 6)

local function createButton(yPos, text)
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.Size = UDim2.new(1, -20, 0, 30)
    btn.Font = Enum.Font.GothamSemibold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local BtnSameServer = createButton(105, "Same Server: " .. (config.RejoinSameServer and "ON" or "OFF"))

local TargetBox = Instance.new("TextBox")
TargetBox.Parent = MainFrame
TargetBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
TargetBox.Position = UDim2.new(0, 10, 0, 145)
TargetBox.Size = UDim2.new(1, -20, 0, 30)
TargetBox.Font = Enum.Font.Gotham
TargetBox.PlaceholderText = "Target Player Name"
TargetBox.Text = config.TargetPlayer
TargetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetBox.TextSize = 13
Instance.new("UICorner", TargetBox).CornerRadius = UDim.new(0, 6)

local BtnTargetToggle = createButton(185, "Target Auto-Join: " .. (config.TargetToggle and "ON" or "OFF"))
if config.TargetToggle then BtnTargetToggle.TextColor3 = Color3.fromRGB(100, 255, 100) end

local isReconnecting = false
local endTime = os.time() + (config.RestartTime * 3600)
local sameServerAttempts = 0

local function forceRejoin()
    if isReconnecting then return end
    isReconnecting = true
    
    TimeLabel.Text = "RECONNECTING..."
    TimeLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    
    task.spawn(function()
        while true do
            pcall(function() GuiService:ClearError() end)
            
            pcall(function()
                if config.RejoinSameServer and currentJobId and currentJobId ~= "" and sameServerAttempts < 5 then
                    sameServerAttempts = sameServerAttempts + 1
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, currentJobId, player)
                else
                    TeleportService:Teleport(game.PlaceId, player)
                end
            end)
            
            task.wait(10)
        end
    end)
end

task.spawn(function()
    while not isReconnecting do
        task.wait(1)
        local remaining = endTime - os.time()
        if remaining <= 0 then
            forceRejoin()
            break
        end
        
        local h = math.floor(remaining / 3600)
        local m = math.floor((remaining % 3600) / 60)
        local s = remaining % 60
        TimeLabel.Text = string.format("%02d:%02d:%02d", h, m, s)
    end
end)

local function updateRestartTime(newTime)
    if newTime and newTime >= 1 and newTime <= 24 then
        local diff = newTime - config.RestartTime
        config.RestartTime = newTime
        endTime = endTime + (diff * 3600) 
        saveConfig()
        HoursLabel.Text = "Restart: " .. config.RestartTime .. "h"
    end
end

BtnPlus.Activated:Connect(function()
    if config.RestartTime < 24 then updateRestartTime(config.RestartTime + 1) end
end)

BtnMinus.Activated:Connect(function()
    if config.RestartTime > 1 then updateRestartTime(config.RestartTime - 1) end
end)

BtnSameServer.Activated:Connect(function()
    config.RejoinSameServer = not config.RejoinSameServer
    BtnSameServer.Text = "Same Server: " .. (config.RejoinSameServer and "ON" or "OFF")
    saveConfig()
end)

TargetBox.FocusLost:Connect(function()
    config.TargetPlayer = TargetBox.Text
    saveConfig()
end)

BtnTargetToggle.Activated:Connect(function()
    config.TargetToggle = not config.TargetToggle
    BtnTargetToggle.Text = "Target Auto-Join: " .. (config.TargetToggle and "ON" or "OFF")
    BtnTargetToggle.TextColor3 = config.TargetToggle and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
    saveConfig()
end)

Players.PlayerRemoving:Connect(function(removedPlayer)
    if config.TargetToggle and config.TargetPlayer ~= "" and removedPlayer.Name == config.TargetPlayer then
        forceRejoin()
    end
end)

TeleportService.TeleportInitFailed:Connect(forceRejoin)

GuiService.ErrorMessageChanged:Connect(function(errorMessage)
    if errorMessage and errorMessage ~= "" then forceRejoin() end
end)

task.spawn(function()
    pcall(function()
        local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui", 5):WaitForChild("promptOverlay", 5)
        if promptOverlay then
            promptOverlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" then forceRejoin() end
            end)
            if promptOverlay:FindFirstChild("ErrorPrompt") then forceRejoin() end
        end
    end)
end)