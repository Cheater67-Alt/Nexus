local baseUrl = "https://raw.githubusercontent.com/Cheater67-Alt/Nexus/main/Modules/"

local function loadModule(fileName)
    local rawUrl = baseUrl .. fileName
    local success, result = pcall(function()
        return loadstring(game:HttpGet(rawUrl))()
    end)
    if success then
        print("[Nexus] Успешно загружен: " .. fileName)
        return result
    else
        warn("[Nexus] Ошибка при загрузке " .. fileName .. ": " .. tostring(result))
        return nil
    end
end

-- Загружаем сначала основной скрипт (он создаст _G.Nexus)
local NexusScripts = loadModule("NexusScripts.lua")
-- Даём небольшую паузу, чтобы _G.Nexus точно был установлен
task.wait(0.5)
-- Теперь загружаем UI
local NexusUI = loadModule("NexusUI.lua")
