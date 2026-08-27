--[[
    NEXUS SCRIPT — полная логика (исправлено)
    Включает: Aimbot, Silent Aim, No Recoil, Auto Shoot, FOV (градусы), Target Part,
              God Mode, Infinite Jump, WalkSpeed, JumpPower, Reset,
              Box ESP, Skeleton ESP, Name ESP, Tracers, Max Distance,
              Anti-AFK, Auto-Farm, Rejoin, Show Keybinds, Notifications, Save/Load Config.
    Все функции выключены по умолчанию.
    Экспортирует глобальную таблицу _G.Nexus.
    Требуется DrawingLib для ESP и уведомлений (с фолбэком на встроенный Drawing).
--]]

-- Загрузка DrawingLib с фолбэком
local Drawing = nil
if not Drawing then
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/DrawingLib/main/Library.lua"))()
    end)
    if success then Drawing = result end
end
if not Drawing and rawget(getgenv(), "Drawing") then
    Drawing = rawget(getgenv(), "Drawing")
end

local Nexus = {
    Settings = {
        -- Combat
        Aimbot = false,
        SilentAim = false,
        AutoShoot = false,
        FOVSize = 90,           -- угол в градусах
        TargetPart = "Head",

        -- Player
        GodMode = false,
        InfiniteJump = false,
        WalkSpeed = 16,
        JumpPower = 50,
        WalkSpeedChanged = false,
        JumpPowerChanged = false,

        -- Visuals
        BoxESP = false,
        SkeletonESP = false,
        NameESP = false,
        Tracers = false,
        MaxDistance = 1000,

        -- Misc
        AntiAFK = false,
        AutoFarm = false,
        ShowKeybinds = true,
        Notifications = true,
    },
}

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

-- ================== УВЕДОМЛЕНИЯ ==================
local Notifications = {}
local function createNotification(text)
    if not Drawing or not Nexus.Settings.Notifications then return end
    local notif = Drawing.new("Text")
    notif.Text = text
    notif.Color = Color3.fromRGB(255, 255, 255)
    notif.Size = 18
    notif.Center = true
    notif.Outline = true
    notif.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 3)
    notif.Visible = true
    table.insert(Notifications, {obj = notif, timer = 0})
end

-- Метатаблица для Settings: при изменении любого поля показываем уведомление
local SettingsMeta = {
    __newindex = function(t, k, v)
        rawset(t, k, v)
        if Nexus.Settings.Notifications then
            createNotification(tostring(k) .. " = " .. tostring(v))
        end
    end
}
setmetatable(Nexus.Settings, SettingsMeta)

-- ================== COMBAT LOGIC ==================

local function getClosestPlayer()
    local closest, shortestAngle = nil, math.rad(Nexus.Settings.FOVSize)
    local cameraDir = Camera.CFrame.LookVector
    local cameraPos = Camera.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local part = player.Character:FindFirstChild(Nexus.Settings.TargetPart) or player.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local dirToTarget = (part.Position - cameraPos).Unit
                local angle = math.acos(math.clamp(cameraDir:Dot(dirToTarget), -1, 1))
                if angle <= shortestAngle then
                    shortestAngle = angle
                    closest = part
                end
            end
        end
    end
    return closest
end

-- Aimbot (плавный) и AutoShoot
local aimSmoothing = 0.3  -- коэффициент сглаживания (0..1)
RunService.RenderStepped:Connect(function()
    if Nexus.Settings.Aimbot and not Nexus.Settings.SilentAim then
        local target = getClosestPlayer()
        if target then
            local camPos = Camera.CFrame.Position
            local targetPos = target.Position
            local desiredDir = (targetPos - camPos).Unit
            local currentDir = Camera.CFrame.LookVector
            local newDir = currentDir:Lerp(desiredDir, aimSmoothing).Unit
            Camera.CFrame = CFrame.new(camPos, camPos + newDir)
        end
    end

    if Nexus.Settings.AutoShoot then
        local target = getClosestPlayer()
        if target then
            -- Используем VirtualUser для клика
            VirtualUser:Button1Down(Vector2.new(0,0), Camera.CFrame)
            task.wait(0.05)
            VirtualUser:Button1Up(Vector2.new(0,0), Camera.CFrame)
        end
    end
end)

-- Silent Aim (хук методов оружия)
local silentAimInstalled = false
local weaponModule = nil
local fireOriginals = {}
local configOriginals = {}

local function findWeaponModule()
    local candidates = {
        {"WeaponsSystem", "Libraries", "BaseWeapon"},
        {"WeaponsSystem", "Libraries", "BaseFirearm"},
        {"WeaponsSystem", "Modules", "BaseWeapon"},
        {"WeaponsSystem", "Shared", "BaseWeapon"},
        {"WeaponSystem", "Libraries", "BaseWeapon"},
        {"Weapons", "BaseWeapon"},
        {"BaseWeapon"},
    }
    for _, path in ipairs(candidates) do
        local node = ReplicatedStorage
        for i = 1, #path do
            node = node and node:FindFirstChild(path[i])
            if not node then break end
        end
        if node and node:IsA("ModuleScript") then
            local ok, mod = pcall(require, node)
            if ok and type(mod) == "table" then
                return mod
            end
        end
    end
    return nil
end

local function installSilentAim()
    if silentAimInstalled then return end
    silentAimInstalled = true

    weaponModule = findWeaponModule()
    if not weaponModule then
        warn("[Nexus] Оружейный модуль не найден, Silent Aim будет недоступен")
        return
    end

    local fireMethods = {"fire", "Fire", "shoot", "Shoot", "FireWeapon", "fireWeapon", "PullTrigger", "Activate"}
    for _, methodName in ipairs(fireMethods) do
        if type(weaponModule[methodName]) == "function" then
            fireOriginals[methodName] = weaponModule[methodName]
            weaponModule[methodName] = function(self, ...)
                local args = table.pack(...)
                if Nexus.Settings.SilentAim then
                    local targetPart = getClosestPlayer()
                    if targetPart then
                        local origin
                        if self and typeof(self.Muzzle) == "Instance" then
                            origin = self.Muzzle.Position
                        elseif typeof(args[1]) == "Vector3" then
                            origin = args[1]
                        else
                            origin = Camera.CFrame.Position
                        end

                        if typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                            args[2] = (targetPart.Position - origin).Unit
                        elseif typeof(args[1]) == "Vector3" then
                            if (args[1] - origin).Magnitude > 10 then
                                args[1] = targetPart.Position
                            else
                                args[1] = (targetPart.Position - origin).Unit
                            end
                        elseif type(args[1]) == "table" then
                            local bulletData = args[1]
                            if typeof(bulletData.origin) == "Vector3" and typeof(bulletData.direction) == "Vector3" then
                                bulletData.direction = (targetPart.Position - bulletData.origin).Unit
                            elseif typeof(bulletData.target) == "Vector3" then
                                bulletData.target = targetPart.Position
                            elseif typeof(bulletData.position) == "Vector3" then
                                bulletData.position = targetPart.Position
                            end
                        end
                    end
                end
                return fireOriginals[methodName](self, table.unpack(args, 1, args.n))
            end
            print("[Nexus] Silent Aim установлен на метод: " .. methodName)
        end
    end

    local configMethods = {"getConfigValue", "GetConfigValue", "getConfig", "GetConfig", "getStat", "GetStat"}
    local zeroConfigs = {
        RecoilMin = 0, RecoilMax = 0, MinSpread = 0, MaxSpread = 0,
        ConeAngle = 0, Spread = 0, Recoil = 0, Inaccuracy = 0,
        BulletSpread = 0, SpreadMin = 0, SpreadMax = 0,
        RecoilX = 0, RecoilY = 0, RecoilZ = 0,
        RecoilHorizontal = 0, RecoilVertical = 0,
        Accuracy = 1,
    }
    for _, methodName in ipairs(configMethods) do
        if type(weaponModule[methodName]) == "function" then
            configOriginals[methodName] = weaponModule[methodName]
            weaponModule[methodName] = function(self, ...)
                local configName = select(1, ...)
                if Nexus.Settings.SilentAim and zeroConfigs[configName] ~= nil then
                    return zeroConfigs[configName]
                end
                return configOriginals[methodName](self, ...)
            end
            print("[Nexus] No Recoil установлен на метод: " .. methodName)
        end
    end
end

task.spawn(installSilentAim)

-- ================== PLAYER LOGIC ==================

-- God Mode, WalkSpeed, JumpPower
RunService.Stepped:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Nexus.Settings.WalkSpeedChanged then
            hum.WalkSpeed = Nexus.Settings.WalkSpeed
        end
        if Nexus.Settings.JumpPowerChanged then
            hum.JumpPower = Nexus.Settings.JumpPower
        end
        if Nexus.Settings.GodMode then
            hum.Health = hum.MaxHealth
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if Nexus.Settings.InfiniteJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

function Nexus.ResetCharacter()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0
    end
end

-- ================== VISUALS (ESP) ==================
if Drawing then
    local ESP_Storage = {}

    local function createESP(player)
        if player == LocalPlayer then return end
        local box = Drawing.new("Square")
        box.Visible = false
        box.Color = Color3.fromRGB(0, 255, 136)
        box.Thickness = 1
        box.Filled = false

        local name = Drawing.new("Text")
        name.Visible = false
        name.Color = Color3.fromRGB(255, 255, 255)
        name.Size = 14
        name.Center = true
        name.Outline = true

        local tracer = Drawing.new("Line")
        tracer.Visible = false
        tracer.Color = Color3.fromRGB(0, 255, 136)
        tracer.Thickness = 1

        -- Скелет: линии между частями тела
        local skeletonLines = {}
        local bonePairs = {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},
        }
        for _ = 1, #bonePairs do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Color = Color3.fromRGB(255, 255, 255)
            line.Thickness = 1
            table.insert(skeletonLines, line)
        end

        ESP_Storage[player] = {
            Box = box,
            Name = name,
            Tracer = tracer,
            SkeletonLines = skeletonLines,
            BonePairs = bonePairs,
        }
    end

    for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
    Players.PlayerAdded:Connect(createESP)

    RunService.RenderStepped:Connect(function()
        for player, objs in pairs(ESP_Storage) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                if onScreen and dist <= Nexus.Settings.MaxDistance then
                    -- Name ESP
                    if Nexus.Settings.NameESP then
                        objs.Name.Position = Vector2.new(pos.X, pos.Y - 40)
                        objs.Name.Text = player.Name .. " [" .. math.floor(dist) .. "m]"
                        objs.Name.Visible = true
                    else
                        objs.Name.Visible = false
                    end

                    -- Box ESP
                    if Nexus.Settings.BoxESP then
                        local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                        local bottom = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 4, 0))
                        if top and bottom then
                            local size = top.Y - bottom.Y
                            objs.Box.Size = Vector2.new(size / 1.5, size)
                            objs.Box.Position = Vector2.new(pos.X - objs.Box.Size.X / 2, pos.Y - objs.Box.Size.Y / 2)
                            objs.Box.Visible = true
                        else
                            objs.Box.Visible = false
                        end
                    else
                        objs.Box.Visible = false
                    end

                    -- Tracers
                    if Nexus.Settings.Tracers then
                        objs.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        objs.Tracer.To = Vector2.new(pos.X, pos.Y)
                        objs.Tracer.Visible = true
                    else
                        objs.Tracer.Visible = false
                    end

                    -- Skeleton ESP
                    if Nexus.Settings.SkeletonESP then
                        for i, line in ipairs(objs.SkeletonLines) do
                            local bonePair = objs.BonePairs[i]
                            local part1 = char:FindFirstChild(bonePair[1])
                            local part2 = char:FindFirstChild(bonePair[2])
                            if part1 and part2 then
                                local p1, on1 = Camera:WorldToViewportPoint(part1.Position)
                                local p2, on2 = Camera:WorldToViewportPoint(part2.Position)
                                if on1 and on2 then
                                    line.From = Vector2.new(p1.X, p1.Y)
                                    line.To = Vector2.new(p2.X, p2.Y)
                                    line.Visible = true
                                else
                                    line.Visible = false
                                end
                            else
                                line.Visible = false
                            end
                        end
                    else
                        for _, line in ipairs(objs.SkeletonLines) do
                            line.Visible = false
                        end
                    end
                else
                    objs.Name.Visible = false
                    objs.Box.Visible = false
                    objs.Tracer.Visible = false
                    for _, line in ipairs(objs.SkeletonLines) do
                        line.Visible = false
                    end
                end
            else
                objs.Name.Visible = false
                objs.Box.Visible = false
                objs.Tracer.Visible = false
                for _, line in ipairs(objs.SkeletonLines) do
                    line.Visible = false
                end
            end
        end
    end)
end

-- ================== SHOW KEYBINDS ==================
if Drawing then
    local keybindsText = Drawing.new("Text")
    keybindsText.Visible = false
    keybindsText.Color = Color3.fromRGB(255, 255, 255)
    keybindsText.Size = 14
    keybindsText.Position = Vector2.new(10, 10)
    keybindsText.Outline = true
    keybindsText.Text = ""

    RunService.RenderStepped:Connect(function()
        if Nexus.Settings.ShowKeybinds then
            local active = {}
            if Nexus.Settings.Aimbot then table.insert(active, "Aimbot") end
            if Nexus.Settings.SilentAim then table.insert(active, "Silent Aim") end
            if Nexus.Settings.AutoShoot then table.insert(active, "Auto Shoot") end
            if Nexus.Settings.GodMode then table.insert(active, "God Mode") end
            if Nexus.Settings.InfiniteJump then table.insert(active, "Infinite Jump") end
            if Nexus.Settings.AutoFarm then table.insert(active, "Auto Farm") end
            if #active > 0 then
                keybindsText.Text = "Активные: " .. table.concat(active, ", ")
                keybindsText.Visible = true
            else
                keybindsText.Visible = false
            end
        else
            keybindsText.Visible = false
        end
    end)
end

-- ================== AUTO-FARM ==================
local lastFarmAction = 0
RunService.Heartbeat:Connect(function()
    if Nexus.Settings.AutoFarm then
        local now = os.clock()
        if now - lastFarmAction > 0.5 then
            lastFarmAction = now
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool then
                tool:Activate()
            end
            VirtualUser:Button1Down(Vector2.new(0,0), Camera.CFrame)
            task.wait(0.1)
            VirtualUser:Button1Up(Vector2.new(0,0), Camera.CFrame)
        end
    end
end)

-- ================== MISC ==================

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if Nexus.Settings.AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- Rejoin Server
function Nexus.RejoinServer()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- Save / Load Config
function Nexus.SaveConfig()
    local success, err = pcall(function()
        writefile("NexusConfig.json", HttpService:JSONEncode(Nexus.Settings))
    end)
    if success then
        print("[Nexus] Конфигурация сохранена.")
        createNotification("Конфигурация сохранена")
    else
        warn("[Nexus] Не удалось сохранить конфигурацию: " .. tostring(err))
        createNotification("Ошибка сохранения")
    end
end

function Nexus.LoadConfig()
    local success, content = pcall(function()
        return readfile("NexusConfig.json")
    end)
    if success and content then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                Nexus.Settings[k] = v
            end
            print("[Nexus] Конфигурация загружена.")
            createNotification("Конфигурация загружена")
        else
            warn("[Nexus] Ошибка разбора конфигурации.")
        end
    else
        warn("[Nexus] Файл конфигурации не найден.")
        createNotification("Конфиг не найден")
    end
end

-- Экспорт глобальной таблицы
_G.Nexus = Nexus

print("Nexus script loaded. Ready.")
