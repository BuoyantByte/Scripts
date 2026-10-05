local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local currentJobId = game.JobId 

local configFileName = "BuoReconnect_Config.json"
local config = {
    RestartTime = 24,
    RejoinSameServer = true,
    TargetPlayer = "",
    TargetToggle = false
}

if isfile and readfile and isfile(configFileName) then
    pcall(function()
        local saved = HttpService:JSONDecode(readfile(configFileName))
        if type(saved) == "table" then
            for k, v in pairs(saved) do
                config[k] = v
            end
        end
    end)
end

local function saveConfig()
    if writefile then
        pcall(function()
            writefile(configFileName, HttpService:JSONEncode(config))
        end)
    end
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "BuoReconnect",
    Icon = 0,
    LoadingTitle = "BuoReconnect",
    LoadingSubtitle = "by BuoyantByte",
    ShowText = "BuoReconnect",
    Theme = "Amethyst",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = false,
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
    KeySystem = false
})

task.spawn(function()
    local parent = (gethui and gethui()) or CoreGui
    local rayfieldGui = parent:WaitForChild("Rayfield", 5)
    if rayfieldGui then
        local main = rayfieldGui:WaitForChild("Main", 5)
        if main then
            main.Size = UDim2.new(0, 400, 0, 260)
            main.ClipsDescendants = true
            
            task.wait(0.3)
            
            for _, obj in ipairs(rayfieldGui:GetDescendants()) do
                if obj:IsA("GuiObject") then
                    if obj ~= main and not obj:IsDescendantOf(main) then
                        if obj:IsA("Frame") or obj:IsA("CanvasGroup") then
                            obj.BackgroundTransparency = 1
                        elseif obj:IsA("ImageLabel") then
                            obj.ImageTransparency = 1
                            obj.BackgroundTransparency = 1
                        end
                    end
                    if obj.Name:lower():find("shadow") or obj.Name:lower():find("glow") then
                        obj.Visible = false
                    end
                end
            end
        end
    end
end)

local home = Window:CreateTab("Home", 127099021069839)
local alt  = Window:CreateTab("Alt", 95949997618327)

local isReconnecting = false

local function forceRejoin()
    if isReconnecting then return end
    isReconnecting = true
    
    print("[Auto-Reconnect] Connection lost! Starting continuous reconnect loop...")
    
    task.spawn(function()
        while true do
            print("[Auto-Reconnect] Attempting to reconnect...")
            
            -- Попытка прожать кнопку в стандартном UI ошибки Роблокса
            pcall(function()
                local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
                if promptOverlay then
                    local errorPrompt = promptOverlay:FindFirstChild("ErrorPrompt")
                    if errorPrompt then
                        local buttonArea = errorPrompt:FindFirstChild("ButtonArea")
                        if buttonArea then
                            for _, btn in ipairs(buttonArea:GetChildren()) do
                                if btn:IsA("GuiButton") and btn.Visible then
                                    if getconnections then
                                        for _, conn in pairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
                                        for _, conn in pairs(getconnections(btn.Activated)) do conn:Fire() end
                                    elseif firesignal then
                                        firesignal(btn.MouseButton1Click)
                                        firesignal(btn.Activated)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            
            -- Телепорт с учетом настроек сервера
            pcall(function()
                if config.RejoinSameServer and currentJobId and currentJobId ~= "" then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, currentJobId, player)
                else
                    TeleportService:Teleport(game.PlaceId, player)
                end
            end)
            
            task.wait(4)
        end
    end)
end

TeleportService.TeleportInitFailed:Connect(function()
    print("[Auto-Reconnect] Teleport initialization failed. Retrying...")
    forceRejoin()
end)

local ToggleSameServer = home:CreateToggle({
    Name = "Rejoin Current Server (VIP/Private)",
    CurrentValue = config.RejoinSameServer,
    Flag = "ToggleSameServer",
    Callback = function(Value)
        config.RejoinSameServer = Value
        saveConfig()
    end,
})

local reconnectTime = 0
local endTime = 0
local timerRunning = false
local previousSliderValue = config.RestartTime

local function restartTimerFromNow()
    if reconnectTime > 0 then
        endTime = os.time() + reconnectTime
        timerRunning = true
    else
        timerRunning = false
    end
end

local function adjustTimer(newValue)
    local now = os.time()
    if timerRunning and endTime > now then
        local remainingSeconds = endTime - now
        local difference = (newValue - previousSliderValue) * 3600
        local newRemainingSeconds = math.max(0, remainingSeconds + difference)
        
        endTime = now + newRemainingSeconds
        reconnectTime = newValue * 3600
    else
        reconnectTime = newValue * 3600
        restartTimerFromNow()
    end
    previousSliderValue = newValue
    
    config.RestartTime = newValue
    saveConfig()
end

local Slider = home:CreateSlider({
    Name = "Restart Time",
    Range = {1, 24},
    Increment = 1,
    Suffix = "Hours",
    CurrentValue = config.RestartTime,
    Flag = "RestartTimeSlider",
    Callback = function(Value)
        adjustTimer(Value)
    end,
})

local timeleft = home:CreateButton({
    Name = "Time left: Starting...",
    Callback = function()
        if timerRunning then
            local remaining = endTime - os.time()
            if remaining > 0 then
                local h = math.floor(remaining / 3600)
                local m = math.floor((remaining % 3600) / 60)
                local s = remaining % 60
                print(string.format("[Info] Exact time: %dh %dm %ds", h, m, s))
            end
        end
    end,
})

task.spawn(function()
    while true do
        task.wait(1)
        if timerRunning and reconnectTime > 0 then
            local now = os.time()
            local remaining = endTime - now
            if remaining > 0 then
                local hours = math.floor(remaining / 3600)
                local minutes = math.floor((remaining % 3600) / 60)
                local seconds = remaining % 60
                
                if hours >= 1 then
                    timeleft:Set(string.format("Time left: %dh %dm", hours, minutes))
                elseif minutes > 0 then
                    timeleft:Set(string.format("Time left: %dm", minutes))
                else
                    timeleft:Set(string.format("Time left: %ds", seconds))
                end
            else
                timeleft:Set("Time left: Restarting...")
                forceRejoin()
                break
            end
        else
            timeleft:Set("Time left: Inactive")
        end
    end
end)

previousSliderValue = config.RestartTime
reconnectTime = config.RestartTime * 3600
restartTimerFromNow()

local DropdownTargetPlayer = alt:CreateDropdown({
    Name = "TargetPlayer",
    Options = {},
    CurrentOption = {config.TargetPlayer},
    MultipleOptions = false,
    Flag = "PlayerInServer",
    Callback = function(Options)
        config.TargetPlayer = Options[1] or ""
        saveConfig()
    end,
})

local ToggleTargetPlayer = alt:CreateToggle({
    Name = "Target Player",
    CurrentValue = config.TargetToggle,
    Flag = "ToggleRestartAlt",
    Callback = function(Value)
        config.TargetToggle = Value
        saveConfig()
    end,
})

local function updatePlayers()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end
    if config.TargetPlayer ~= "" and not table.find(names, config.TargetPlayer) then
        table.insert(names, 1, config.TargetPlayer)
    end
    DropdownTargetPlayer:Refresh(names, true)
end

updatePlayers()
Players.PlayerAdded:Connect(updatePlayers)
Players.PlayerRemoving:Connect(function(removedPlayer)
    updatePlayers()
    if config.TargetToggle and removedPlayer.Name == config.TargetPlayer then
        forceRejoin()
    end
end)

GuiService.ErrorMessageChanged:Connect(function(errorMessage)
    if errorMessage and errorMessage ~= "" then
        print("[Auto-Reconnect] GUI error detected:", errorMessage)
        forceRejoin()
    end
end)

task.spawn(function()
    pcall(function()
        local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui", 5):WaitForChild("promptOverlay", 5)
        if promptOverlay then
            promptOverlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" then
                    print("[Auto-Reconnect] ErrorPrompt window found in CoreGui!")
                    forceRejoin()
                end
            end)
            
            if promptOverlay:FindFirstChild("ErrorPrompt") then
                forceRejoin()
            end
        end
    end)
end)