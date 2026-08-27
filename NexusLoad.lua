local baseUrl = "https://raw.githubusercontent.com/Cheater67-Alt/Nexus/main/Modules/"

-- Функция для безопасной загрузки модуля
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

-- Загружаем модули
local NexusUI = loadModule("NexusUI.lua")
local NexusScripts = loadModule("NexusScripts.lua")
