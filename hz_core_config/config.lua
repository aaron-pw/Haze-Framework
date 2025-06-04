--[[
    hz_core_config/config.lua
    Defines the core configuration settings for the Haze Framework.
    Uses an explicit export function 'GetConfig' to share settings reliably.
]]

print('[HzConfig] Starting config loading...')

-- Use a local table to store configuration specific to this resource
-- This prevents polluting the global _ENV unless necessary.
local HazeConfig = {}

-- Debug flag for enabling/disabling verbose logging across the framework
HazeConfig.Debug = true -- Set to false for production to reduce console spam

-- Database credentials - IMPORTANT:
-- For production, avoid storing plain passwords here. Use environment variables,
-- server convars loaded from a secrets file (added to .gitignore), or another secure method.
-- oxmysql primarily uses the 'mysql_connection_string' convar if set in server.cfg/secrets.cfg.
-- This table is provided mainly for reference or if other parts of the framework need these details.
HazeConfig.Database = {
    host     = 'localhost', -- Database server host (usually localhost)
    user     = 'root',      -- Database user
    password = '',          -- Database password (FILL THIS IN LOCALLY, KEEP OUT OF GIT)
    database = 'haze_framework', -- Name of the database to use
    port     = 3306         -- Default MySQL port
}

HazeConfig.Characters = {
    MaxSlots = 3, -- Default maximum character slots per player
    -- Can add other character-related configs here later
}

HazeConfig.Spawns = {
    -- Default spawn if no character position or choice made
    Default = { x = -269.4, y = -955.3, z = 31.2, heading = 205.8 },
    -- Selectable locations (add more as needed)
    Selectable = {
        { name = "Legion Square",    coords = { x = 182.9, y = -789.3, z = 31.8, heading = 34.7 } },
        { name = "Davis Station",    coords = { x = 136.7, y = -1709.9, z = 29.3, heading = 329.2 } },
        { name = "Sandy Shores Med", coords = { x = 1838.8, y = 3672.9, z = 34.3, heading = 205.0 } },
        { name = "Paleto Bay Sheriff", coords = { x = -448.3, y = 6010.6, z = 31.7, heading = 70.0 } },
    }
}

-- Add other configuration sections as needed
-- Example:
-- HazeConfig.Player = {
--     DefaultCash = 1000,
--     DefaultBank = 5000,
-- }
-- HazeConfig.Vehicles = {
--     MaxGarages = 3,
-- }


-- =============================================================================
--  EXPORT FUNCTION
-- =============================================================================

-- Define the function that will be called by other resources to get the config
local function getConfigFunction()
    -- This function is assigned to the export below.
    -- It simply returns the HazeConfig table.
    -- Consider returning a deep copy if you want to prevent other resources
    -- from accidentally modifying the original table: `return deepcopy(HazeConfig)`
    -- (requires a deepcopy function, ox_lib might provide one or you can implement it).
    -- For now, returning the reference is usually fine.
    print('[HzConfig] GetConfig() called by another resource.') -- Optional debug print
    return HazeConfig
end

-- Explicitly assign the function to the exports table.
-- The key 'GetConfig' MUST match the name in the manifest's 'exports' block
-- AND the name used by other resources (e.g., exports.hz_core_config:GetConfig()).
-- This method proved more reliable during startup than relying solely on the manifest export.
exports('GetConfig', getConfigFunction)

print('[HzConfig] Configuration loaded and GetConfig function exported.')