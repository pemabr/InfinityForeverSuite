-- PluginSystemEngine.lua - Third-party plugin system for custom data types
-- Part of InfinityDetails addon suite
-- Allows external addons to register custom metrics and analyzers

local PluginSystemEngine = {}
PluginSystemEngine.enabled = false
PluginSystemEngine.db = nil
PluginSystemEngine.plugins = {}
PluginSystemEngine.hooks = {}

-- Configuration
PluginSystemEngine.config = {
    enabled = true,
    max_plugins = 20,
}

function PluginSystemEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.plugins then
        self.db.plugins = {}
    end
    
    if not self.db.hooks then
        self.db.hooks = {}
    end
    
    self.plugins = self.db.plugins
    self.hooks = self.db.hooks
    self.enabled = true
    
    self:Log("Initialized plugin system engine")
end

function PluginSystemEngine:RegisterPlugin(pluginName, pluginVersion, authorName, callbacks)
    if not pluginName or not callbacks then
        return false
    end
    
    if #self.plugins >= self.config.max_plugins then
        self:Log("Max plugins reached (" .. self.config.max_plugins .. ")")
        return false
    end
    
    -- Validate plugin structure
    if not callbacks.OnLoad or not callbacks.OnUnload then
        self:Log("Plugin missing required callbacks: OnLoad, OnUnload")
        return false
    end
    
    local plugin = {
        name = pluginName,
        version = pluginVersion or "1.0",
        author = authorName or "Unknown",
        registered_at = GetTime(),
        enabled = true,
        callbacks = callbacks,
        hooks = {},
    }
    
    table.insert(self.plugins, plugin)
    
    -- Call OnLoad
    if type(callbacks.OnLoad) == "function" then
        local success = pcall(callbacks.OnLoad)
        if not success then
            self:Log("Plugin OnLoad failed: " .. pluginName)
            table.remove(self.plugins, #self.plugins)
            return false
        end
    end
    
    self:Log("Registered plugin: " .. pluginName .. " v" .. (pluginVersion or "1.0"))
    
    return true
end

function PluginSystemEngine:UnregisterPlugin(pluginName)
    for i, plugin in ipairs(self.plugins) do
        if plugin.name == pluginName then
            if plugin.callbacks.OnUnload and type(plugin.callbacks.OnUnload) == "function" then
                pcall(plugin.callbacks.OnUnload)
            end
            
            table.remove(self.plugins, i)
            self:Log("Unregistered plugin: " .. pluginName)
            
            return true
        end
    end
    
    return false
end

function PluginSystemEngine:GetPlugin(pluginName)
    for _, plugin in ipairs(self.plugins) do
        if plugin.name == pluginName then
            return plugin
        end
    end
    
    return nil
end

function PluginSystemEngine:CallPluginCallback(pluginName, callbackName, ...)
    local plugin = self:GetPlugin(pluginName)
    if not plugin or not plugin.callbacks[callbackName] then
        return false
    end
    
    if type(plugin.callbacks[callbackName]) ~= "function" then
        return false
    end
    
    local success, result = pcall(plugin.callbacks[callbackName], ...)
    
    if not success then
        self:Log("Plugin callback failed: " .. pluginName .. ":" .. callbackName)
        return false
    end
    
    return true, result
end

function PluginSystemEngine:RegisterHook(hookName, callbackFunction)
    if not hookName or not callbackFunction then
        return false
    end
    
    if not self.hooks[hookName] then
        self.hooks[hookName] = {}
    end
    
    table.insert(self.hooks[hookName], {
        callback = callbackFunction,
        registered_at = GetTime(),
    })
    
    return true
end

function PluginSystemEngine:ExecuteHook(hookName, ...)
    if not self.hooks[hookName] then
        return true
    end
    
    for _, hook in ipairs(self.hooks[hookName]) do
        if type(hook.callback) == "function" then
            local success, result = pcall(hook.callback, ...)
            if not success then
                self:Log("Hook execution failed: " .. hookName)
            end
        end
    end
    
    return true
end

function PluginSystemEngine:ValidatePluginData(pluginName, dataTable)
    if not dataTable then
        return false
    end
    
    -- Basic validation - check for required fields
    if not dataTable.id or not dataTable.type then
        return false
    end
    
    return true
end

function PluginSystemEngine:ListPlugins()
    local list = {}
    
    for _, plugin in ipairs(self.plugins) do
        table.insert(list, {
            name = plugin.name,
            version = plugin.version,
            author = plugin.author,
            enabled = plugin.enabled,
            registered_at = plugin.registered_at,
        })
    end
    
    return list
end

function PluginSystemEngine:EnablePlugin(pluginName)
    local plugin = self:GetPlugin(pluginName)
    if not plugin then
        return false
    end
    
    plugin.enabled = true
    self:Log("Enabled plugin: " .. pluginName)
    
    return true
end

function PluginSystemEngine:DisablePlugin(pluginName)
    local plugin = self:GetPlugin(pluginName)
    if not plugin then
        return false
    end
    
    plugin.enabled = false
    self:Log("Disabled plugin: " .. pluginName)
    
    return true
end

function PluginSystemEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_plugins = #self.plugins,
        max_plugins = self.config.max_plugins,
        total_hooks = table.getn(self.hooks),
    }
end

function PluginSystemEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[PluginSystemEngine] " .. message)
    else
        print("[PluginSystemEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_PLUGIN1 = "/plugin"
    SlashCmdList["PLUGIN"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local plugins = PluginSystemEngine:ListPlugins()
            print("Plugins (" .. #plugins .. "/" .. PluginSystemEngine.config.max_plugins .. "):")
            for i, plugin in ipairs(plugins) do
                print("  [" .. i .. "] " .. plugin.name .. " v" .. plugin.version .. " by " .. plugin.author)
                print("       Status: " .. (plugin.enabled and "ENABLED" or "DISABLED"))
            end
        elseif cmd == "info" then
            local pluginName = args
            local plugin = PluginSystemEngine:GetPlugin(pluginName)
            
            if plugin then
                print("Plugin: " .. plugin.name)
                print("  Version: " .. plugin.version)
                print("  Author: " .. plugin.author)
                print("  Status: " .. (plugin.enabled and "ENABLED" or "DISABLED"))
                print("  Registered: " .. date("%Y-%m-%d %H:%M:%S", plugin.registered_at))
            else
                print("Plugin not found: " .. pluginName)
            end
        elseif cmd == "enable" then
            local pluginName = args
            if PluginSystemEngine:EnablePlugin(pluginName) then
                print("Enabled plugin: " .. pluginName)
            else
                print("Plugin not found: " .. pluginName)
            end
        elseif cmd == "disable" then
            local pluginName = args
            if PluginSystemEngine:DisablePlugin(pluginName) then
                print("Disabled plugin: " .. pluginName)
            else
                print("Plugin not found: " .. pluginName)
            end
        elseif cmd == "status" then
            local status = PluginSystemEngine:GetStatus()
            print("Plugin System:")
            print("  Total Plugins: " .. status.total_plugins .. "/" .. status.max_plugins)
            print("  Registered Hooks: " .. status.total_hooks)
        else
            print("Plugin Commands:")
            print("  /plugin list - List all plugins")
            print("  /plugin info <name> - Show plugin info")
            print("  /plugin enable <name> - Enable plugin")
            print("  /plugin disable <name> - Disable plugin")
            print("  /plugin status - Show system status")
        end
    end
end

return PluginSystemEngine
