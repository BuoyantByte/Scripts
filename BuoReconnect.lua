local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "BuoReconnect",
    Icon = 0,
    LoadingTitle = "BuoReconnect",
    LoadingSubtitle = "by BuoyantByte",
    ShowText = "BuoReconnect",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

local home = Window:CreateTab("Home", 127099021069839)
local alt  = Window:CreateTab("Alt", 95949997618327)

local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local GuiService      = game:GetService("GuiService")
local CoreGui         = game:GetService("CoreGui")

local player = Players.LocalPlayer

local targetPlayerName = nil
local isTargetEnabled  = false

local function rejoinSelf(forceStandard)
    if not forceStandard and #game.JobId > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    else
        TeleportService:Teleport(game.PlaceId, player)
    end
end

local reconnectTime = 0
local endTime = 0
local timerRunning = false
local previousSliderValue = 5

local function restartTimerFromNow()
    if reconnectTime > 0 then
        endTime = os.time() + reconnectTime
        timerRunning = true
        local hours = reconnectTime / 3600
        print("=== TIMER START (FRESH) ===")
        print("[Timer] Started for " .. hours .. " hours")
        print("[Timer] End time:", endTime)
        print("============================")
    else
        timerRunning = false
        print("[Timer] Stopped")
    end
end

local function adjustTimer(newValue)
    print("\n=== ADJUST TIMER ===")
    print("[Timer] Old:", previousSliderValue, "hours | New:", newValue, "hours")
    
    local now = os.time()
    
    if timerRunning and endTime > now then
        local remainingSeconds = endTime - now
        local difference = (newValue - previousSliderValue) * 3600
        local newRemainingSeconds = math.max(0, remainingSeconds + difference)
        
        endTime = now + newRemainingSeconds
        reconnectTime = newValue * 3600
        
        local hours = math.floor(newRemainingSeconds / 3600)
        local minutes = math.floor((newRemainingSeconds % 3600) / 60)
        
        print("[Timer] ADJUSTED! Time left:", hours .. "h " .. minutes .. "m")
        print("[Timer] New end time:", endTime)
    else
        print("[Timer] Timer not active, starting fresh")
        reconnectTime = newValue * 3600
        restartTimerFromNow()
    end
    
    previousSliderValue = newValue
    print("====================\n")
end

local Slider = home:CreateSlider({
    Name = "Restart Time",
    Range = {1, 24},
    Increment = 1,
    Suffix = "Hours",
    CurrentValue = 5,
    Flag = "RestartTimeSlider",
    Callback = function(Value)
        print("\n>>> SLIDER: " .. Value .. " hours <<<")
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
        else
            print("[Info] Timer inactive")
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
                
                if remaining % 60 == 0 then
                    print(string.format("[Timer] %dh %dm left", hours, minutes))
                end
            else
                timeleft:Set("Time left: Restarting...")
                print("[Timer] Time's up! Reconnecting...")
                rejoinSelf()
                break
            end
        else
            timeleft:Set("Time left: Inactive")
        end
    end
end)

print("\n=== INITIAL START ===")
previousSliderValue = Slider.CurrentValue or 5
reconnectTime = (Slider.CurrentValue or 5) * 3600
restartTimerFromNow()
print("=====================\n")

local DropdownTargetPlayer = alt:CreateDropdown({
    Name = "TargetPlayer",
    Options = {},
    CurrentOption = {""},
    MultipleOptions = false,
    Flag = "PlayerInServer",
    Callback = function(Options)
        targetPlayerName = Options[1]
    end,
})

local ToggleTargetPlayer = alt:CreateToggle({
    Name = "Target Player",
    CurrentValue = false,
    Flag = "ToggleRestartAlt",
    Callback = function(Value)
        isTargetEnabled = Value
    end,
})

local function updatePlayers()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end
    DropdownTargetPlayer:Refresh(names, true)
end

updatePlayers()
Players.PlayerAdded:Connect(updatePlayers)
Players.PlayerRemoving:Connect(function(removedPlayer)
    updatePlayers()
    if isTargetEnabled and removedPlayer.Name == targetPlayerName then
        task.spawn(function()
            rejoinSelf()
        end)
    end
end)

local function onErrorMessageChanged(errorMessage)
    if errorMessage and errorMessage ~= "" then
        print("[Auto-Reconnect] Error:", errorMessage)
        if player then
            task.wait(0.5)
            if string.find(errorMessage, "773") or string.find(errorMessage, "unsuccessful") then
                print("[Auto-Reconnect] JobId invalid (Error 773). Reconnecting normally...")
                rejoinSelf(true)
            else
                rejoinSelf(false)
            end
        end
    end
end

GuiService.ErrorMessageChanged:Connect(onErrorMessageChanged)

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
            if promptOverlay then
                local errorPrompt = promptOverlay:FindFirstChild("ErrorPrompt")
                if errorPrompt then
                    local buttonArea = errorPrompt:FindFirstChild("ButtonArea")
                    if buttonArea then
                        local reconnectBtn = buttonArea:FindFirstChild("ConfirmButton") or buttonArea:FindFirstChild("Button")
                        if reconnectBtn and reconnectBtn.Visible then
                            print("[Auto-Clicker] Found Reconnect button! Auto-clicking...")
                            
                            if getconnections then
                                for _, conn in pairs(getconnections(reconnectBtn.MouseButton1Click)) do
                                    conn:Fire()
                                end
                                for _, conn in pairs(getconnections(reconnectBtn.Activated)) do
                                    conn:Fire()
                                end
                            elseif firesignal then
                                firesignal(reconnectBtn.MouseButton1Click)
                                firesignal(reconnectBtn.Activated)
                            end
                        end
                    end
                end
            end
        end)
    end
end)
