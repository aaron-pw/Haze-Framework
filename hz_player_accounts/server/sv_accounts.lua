--[[
    hz_player_accounts/server/sv_accounts.lua
    Handles database operations related to player accounts and characters.
    Exports functions for use by other resources (e.g., hz_core_base).
    Relies on the global 'MySQL' object provided by @oxmysql/lib/MySQL.lua.
]]

-- Wait for the database connection to be ready before proceeding.
-- Listens for the event triggered by hz_core_database.
local isDbReady = false
AddEventHandler('hz:databaseConnected', function()
    print('[HzAccounts] Database connection confirmed ready.')
    isDbReady = true
end)

-- Helper function to wait until DB is ready (use cautiously to avoid blocking)
local function EnsureDbReady()
    if isDbReady then return true end

    print('[HzAccounts] Waiting for database connection...')
    local timeout = 5000 -- Wait up to 5 seconds
    local waited = 0
    while not isDbReady and waited < timeout do
        Wait(100)
        waited = waited + 100
    end

    if not isDbReady then
        print('^1[HzAccounts] FATAL: Timeout waiting for database connection. DB functions will likely fail.^0')
        return false
    end
    print('[HzAccounts] Database connection confirmed ready (after wait).')
    return true
end


-- =============================================================================
--  Player Account Functions
-- =============================================================================

-- Fetches player account data from the 'players' table.
-- @param identifier string: The primary identifier (e.g., license:)
-- @return table|nil: Player data table or nil if not found/error.
local function GetPlayerAccount(identifier)
    if not EnsureDbReady() or not identifier then return nil end

    -- Use Sync for simplicity during load sequence. Consider Async for frequent calls.
    local result = MySQL.Sync.fetchSingle('SELECT * FROM players WHERE identifier = ?', { identifier })
    return result -- Returns the player row as a table, or nil if not found
end
exports('GetPlayerAccount', GetPlayerAccount) -- Export the function


-- Creates a new player account record in the 'players' table.
-- @param data table: Must contain { identifier, license, steam, discord, xbox, ip, name }
-- @return boolean: True if insert was successful, false otherwise.
local function CreatePlayerAccount(data)
    if not EnsureDbReady() or not data or not data.identifier then return false end

    -- Use pcall for safety as database inserts can fail (e.g., duplicate identifier if logic flawed)
    local success, result = pcall(MySQL.Sync.execute, -- Changed from insert to execute for clarity
        'INSERT INTO players (identifier, license, steam, discord, xbox, ip, name) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            data.identifier or '',
            data.license,       -- Can be nil
            data.steam,         -- Can be nil
            data.discord,       -- Can be nil
            data.xbox,          -- Can be nil
            data.ip,            -- Can be nil
            data.name           -- Can be nil
        }
    )

    if not success then
        print(('[^1[HzAccounts] Error creating player account for %s: %s^0'):format(data.identifier, tostring(result)))
        return false
    end

    -- MySQL.Sync.execute returns the number of affected rows. Should be 1 for successful insert.
    if result == 1 then
        print(('[HzAccounts] Created player account for %s'):format(data.identifier))
        return true
    else
        print(('[^3[HzAccounts] Warning: CreatePlayerAccount query executed but affected rows was %s (expected 1) for %s^0'):format(tostring(result), data.identifier))
        return false
    end
end
exports('CreatePlayerAccount', CreatePlayerAccount) -- Export the function


-- Updates the last_seen timestamp for a player account.
-- @param identifier string: The primary identifier.
-- @return boolean: True if update was successful (1 row affected), false otherwise.
local function UpdatePlayerLastSeen(identifier)
    if not EnsureDbReady() or not identifier then return false end

    local success, result = pcall(MySQL.Sync.execute,
        'UPDATE players SET last_seen = CURRENT_TIMESTAMP WHERE identifier = ?',
        { identifier }
    )

    if not success then
        print(('[^1[HzAccounts] Error updating last_seen for %s: %s^0'):format(identifier, tostring(result)))
        return false
    end

    return result == 1 -- Return true if exactly one row was updated
end
exports('UpdatePlayerLastSeen', UpdatePlayerLastSeen)


-- =============================================================================
--  Character Functions
-- =============================================================================

-- Fetches essential character info for the selection screen.
-- @param identifier string: The player's primary identifier.
-- @return table: An array of character tables {charid, slot, firstname, lastname, job}, empty [] if none/error.
local function GetPlayerCharacters(identifier)
    if not EnsureDbReady() or not identifier then return {} end -- Return empty table on failure

    local result = MySQL.Sync.fetchAll(
        'SELECT charid, slot, firstname, lastname, job FROM characters WHERE identifier = ? ORDER BY slot ASC',
        { identifier }
    )
    return result or {} -- Ensure we return an empty table if query returns nil/false
end
exports('GetPlayerCharacters', GetPlayerCharacters)


-- Fetches all data for a specific character.
-- @param charid number: The character's unique ID.
-- @return table|nil: Character data table or nil if not found/error.
local function GetCharacterData(charid)
    if not EnsureDbReady() or not charid then return nil end

    local result = MySQL.Sync.fetchSingle('SELECT * FROM characters WHERE charid = ?', { charid })
    return result
end
exports('GetCharacterData', GetCharacterData)


-- Creates a new character record.
-- @param data table: Must contain { identifier, slot, firstname, lastname, dateofbirth, gender, nationality }
-- @return number|false: The new character ID (charid) on success, false otherwise.
local function CreateCharacter(data)
    if not EnsureDbReady() or not data or not data.identifier or not data.slot then return false end

    -- Use pcall as inserts can fail (e.g., duplicate slot)
    local success, charid = pcall(MySQL.Sync.insert, -- Using insert to get the new ID
        [[
            INSERT INTO characters
            (identifier, slot, firstname, lastname, dateofbirth, gender, nationality, cash, bank, job, position, status, skin)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]],
        {
            data.identifier,
            data.slot,
            data.firstname   or 'Jane',
            data.lastname    or 'Doe',
            data.dateofbirth or '1990-01-01',
            data.gender      or 0,
            data.nationality or 'American',
            data.cash        or 1000,  -- Default starting cash
            data.bank        or 5000,  -- Default starting bank
            data.job         or 'unemployed', -- Default job
            data.position    or '{"x": 0.0, "y": 0.0, "z": 0.0, "heading": 0.0}', -- Default position (e.g., from config)
            data.status      or '{"hunger":100,"thirst":100}', -- Default status
            data.skin        or '{}'   -- Default empty skin
        }
    )

    if success and charid then
        print(('[HzAccounts] Created character %s for %s in slot %s'):format(charid, data.identifier, data.slot))
        return charid
    else
        print(('[^1[HzAccounts] Error creating character for %s slot %s: %s^0'):format(data.identifier, data.slot, tostring(charid))) -- charid holds error message on pcall failure
        return false
    end
end
exports('CreateCharacter', CreateCharacter)

-- Updates only the position for a character (basic save example).
-- A more comprehensive save function will be needed later.
-- @param charid number: The character's unique ID.
-- @param position string: JSON string of the position data.
-- @return boolean: True if update was successful (1 row affected), false otherwise.
local function UpdateCharacterPosition(charid, position)
    if not EnsureDbReady() or not charid or not position then return false end

    -- Ensure position is a string
    if type(position) ~= 'string' then
        position = json.encode(position) -- Attempt to encode if it's a table
    end

    local success, result = pcall(MySQL.Sync.execute,
        'UPDATE characters SET position = ? WHERE charid = ?',
        { position, charid }
    )

    if not success then
        print(('[^1[HzAccounts] Error updating position for charid %s: %s^0'):format(charid, tostring(result)))
        return false
    end

    -- Optional: Add a debug print if successful
    -- if result == 1 then print(('[HzAccounts] Updated position for charid %s'):format(charid)) end

    return result == 1 -- Return true if exactly one row was updated
end
exports('UpdateCharacterPosition', UpdateCharacterPosition)


-- =============================================================================
--  Character Update/Delete Functions (NEW)
-- =============================================================================

-- Updates the skin data for a character.
-- @param charid number: The character's unique ID.
-- @param skinData string: JSON string of the skin data (from fivem-appearance).
-- @return boolean: True if update was successful (1 row affected), false otherwise.
local function UpdateCharacterSkin(charid, skinData)
    if not EnsureDbReady() or not charid or not skinData then return false end

    -- Ensure skinData is a string (it should be from fivem-appearance)
    if type(skinData) ~= 'string' then
        print(('[^1[HzAccounts] Error: UpdateCharacterSkin received non-string skin data for charid %s.^0'):format(charid))
        skinData = json.encode(skinData) -- Attempt to encode, but likely indicates an upstream issue
    end

    local success, result = pcall(MySQL.Sync.execute,
        'UPDATE characters SET skin = ? WHERE charid = ?',
        { skinData, charid }
    )

    if not success then
        print(('[^1[HzAccounts] Error updating skin for charid %s: %s^0'):format(charid, tostring(result)))
        return false
    end

    if result == 1 then
         print(('[HzAccounts] Updated skin for charid %s.'):format(charid))
         return true
    else
        -- This might happen if charid doesn't exist, which shouldn't occur in normal flow
        print(('[^3[HzAccounts] Warning: UpdateCharacterSkin query executed but affected rows was %s (expected 1) for charid %s.^0'):format(tostring(result), charid))
        return false
    end
end
exports('UpdateCharacterSkin', UpdateCharacterSkin)

-- Deletes a player account and all associated characters (via CASCADE constraint).
-- USE WITH CAUTION! Primarily for the 0-char cleanup scenario.
-- @param identifier string: The primary identifier of the player account to delete.
-- @return boolean: True if delete was successful (1 player row affected), false otherwise.
local function DeletePlayerAccount(identifier)
    if not EnsureDbReady() or not identifier then return false end
    print(('[^3[HzAccounts] WARNING: Attempting to delete player account %s and all associated characters!^0'):format(identifier))

    -- CASCADE constraint on the 'characters' table should handle deleting associated characters.
    local success, result = pcall(MySQL.Sync.execute,
        'DELETE FROM players WHERE identifier = ?',
        { identifier }
    )

    if not success then
        print(('[^1[HzAccounts] Error deleting player account for %s: %s^0'):format(identifier, tostring(result)))
        return false
    end

    if result == 1 then
        print(('[^2[HzAccounts] Successfully deleted player account %s.^0'):format(identifier))
        return true
    else
        -- This implies the player record didn't exist when delete was attempted.
        print(('[^3[HzAccounts] Warning: DeletePlayerAccount query executed but affected rows was %s (expected 1) for %s.^0'):format(tostring(result), identifier))
        return false -- Indicate player wasn't found/deleted
    end
end
exports('DeletePlayerAccount', DeletePlayerAccount)



print('[HzAccounts] Player accounts script loaded.')

-- Initial check to ensure DB is connected when the script loads
EnsureDbReady()