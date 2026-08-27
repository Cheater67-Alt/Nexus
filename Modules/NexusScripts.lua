--[[
    NEXUS SCRIPT — вся логика (Aimbot, Silent Aim, No Recoil, WalkSpeed/JumpPower, ESP, Anti-AFK)
    Экспортирует глобальную таблицу _G.Nexus.
    Все функции выключены по умолчанию.
    Требуется DrawingLib для ESP (загружается автоматически).
--]]

-- Загружаем DrawingLib (если не удалось, ESP не будет работать, но остальное останется)
local DrawingLibSuccess, Drawing = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/DrawingLib/main/Library.lua"))()
end)
if not DrawingLibSuccess then
    warn("[Nexus] Не удалось загрузить DrawingLib. ESP будет отключён.")
    Drawing = nil
end

local Nexus = {
    Settings = {
        -- Combat
        Aimbot = false,
        SilentAim = false,
        AutoShoot = false,
        FOVSize = 200,
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
    }
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

-- ================== COMBAT LOGIC ==================

local function getClosestPlayer()
    local closest, shortestDistance = nil, Nexus.Settings.FOVSize
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local part = player.Character:FindFirstChild(Nexus.Settings.TargetPart) or player.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < shortestDistance then
                        closest = part
                        shortestDistance = dist
                    end
                end
            end
        end
    end
    return closest
end

-- Aimbot и AutoShoot
RunService.RenderStepped:Connect(function()
    if Nexus.Settings.Aimbot or Nexus.Settings.AutoShoot then
        local target = getClosestPlayer()
        if target then
            if Nexus.Settings.Aimbot then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
            end
            if Nexus.Settings.AutoShoot then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    tool:Activate()
                end
            end
        end
    end
end)

-- Silent Aim (установка хуков)
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

RunService.Stepped:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Nexus.Settings.WalkSpeedChanged then
            hum.WalkSpeed = Nexus.Settings.WalkSpeed
        end
        if Nexus.Settings.JumpPowerChanged then
            hum.JumpPower = Nexus.Settings.JumpPower
        end
    end
end)

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
-- Блок ESP будет работать только если DrawingLib успешно загружена
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
        ESP_Storage[player] = {Box = box, Name = name, Tracer = tracer}
    end

    for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
    Players.PlayerAdded:Connect(createESP)

    RunService.RenderStepped:Connect(function()
        for player, objs in pairs(ESP_Storage) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local hrp = player.Character.HumanoidRootPart
                local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                if onScreen and dist <= Nexus.Settings.MaxDistance then
                    if Nexus.Settings.NameESP then
                        objs.Name.Position = Vector2.new(pos.X, pos.Y - 40)
                        objs.Name.Text = player.Name .. " [" .. math.floor(dist) .. "m]"
                        objs.Name.Visible = true
                    else
                        objs.Name.Visible = false
                    end
                    if Nexus.Settings.BoxESP then
                        local size = (Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0)).Y - Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 4, 0)).Y)
                        objs.Box.Size = Vector2.new(size / 1.5, size)
                        objs.Box.Position = Vector2.new(pos.X - objs.Box.Size.X / 2, pos.Y - objs.Box.Size.Y / 2)
                        objs.Box.Visible = true
                    else
                        objs.Box.Visible = false
                    end
                    if Nexus.Settings.Tracers then
                        objs.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        objs.Tracer.To = Vector2.new(pos.X, pos.Y)
                        objs.Tracer.Visible = true
                    else
                        objs.Tracer.Visible = false
                    end
                else
                    objs.Name.Visible = false
                    objs.Box.Visible = false
                    objs.Tracer.Visible = false
                end
            else
                objs.Name.Visible = false
                objs.Box.Visible = false
                objs.Tracer.Visible = false
            end
        end
    end)
end

-- ================== MISC ==================

LocalPlayer.Idled:Connect(function()
    if Nexus.Settings.AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

function Nexus.RejoinServer()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

_G.Nexus = Nexus
print("Nexus script loaded. Ready.")
