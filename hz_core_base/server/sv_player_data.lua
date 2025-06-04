--[[
    hz_core_base/server/sv_player_data.lua
    Manages server-side player data tables.
]]

-- Table for players who have fully joined (keyed by final server ID)
Players = {} -- << DEFINED GLOBALLY WITHIN RESOURCE SCOPE

-- Table to temporarily hold data for players during the connecting phase (keyed by temporary source ID)
ConnectingPlayers = {} -- << DEFINED GLOBALLY WITHIN RESOURCE SCOPE


-- Helper function to get keys of a table (for debugging)
function getKeys(tbl)
    local keys = {}
    if type(tbl) == 'table' then
        for k, _ in pairs(tbl) do
            table.insert(keys, tostring(k)) -- Convert key to string for printing
        end
    end
    return keys
end


-- Function called from playerConnecting to store temporary data.
function StoreTemporaryPlayerData(tempSrc, data)
    -- Ensure tempSrc is a number before using as key, just in case
    local numericTempSrc = tonumber(tempSrc)
    if not numericTempSrc then
        print(('[^1[HazeCore] StoreTemporaryPlayerData: Invalid tempSrc "%s", cannot store data.^0'):format(tostring(tempSrc)))
        return
    end

    ConnectingPlayers[numericTempSrc] = data
    print(('[HazeCore] Stored temporary data for connecting player %s'):format(numericTempSrc))
    -- DEBUG: Print table content AFTER storing using json.encode
    print(('[HazeCore] ConnectingPlayers table AFTER store for %s: %s'):format(numericTempSrc, json.encode(ConnectingPlayers)))
end


-- Function called from playerJoining to finalize player data.
-- Moves data from ConnectingPlayers to Players table using the final source ID.
-- @param finalSrc number: The final server ID.
-- @param tempSrc number: The temporary source ID provided by playerJoining event.
-- @return table|nil: The finalized player data object in the Players table, or nil on failure.
function FinalizePlayerData(finalSrc, tempSrc)
    -- DEBUG: Print table content BEFORE lookup using json.encode
    print(('[HazeCore] ConnectingPlayers table BEFORE lookup for tempSrc %s (type: %s) (finalSrc %s): %s'):format(tempSrc, type(tempSrc), finalSrc, json.encode(ConnectingPlayers)))

    -- Ensure tempSrc is treated as a number for lookup
    local numericTempSrc = tonumber(tempSrc)
    if not numericTempSrc then
         print(('[^1[HazeCore] Error finalizing player data: tempSrc "%s" could not be converted to a number.^0'):format(tostring(tempSrc)))
         return nil
    end

    -- Attempt lookup using the numeric key
    local tempData = ConnectingPlayers[numericTempSrc]

    -- Check if data was found using the numeric key
    if not tempData then
        -- If still nil, print the explicit numeric key lookup attempt and list available keys
        print(('[^1[HazeCore] Error finalizing player data: No temporary data found using NUMERIC key %s (original tempSrc: %s). Table keys: %s^0'):format(numericTempSrc, tempSrc, json.encode(getKeys(ConnectingPlayers))))
        return nil
    end

    -- Data found, create the entry in the main Players table
    Players[finalSrc] = {
        source      = finalSrc, -- Use final ID
        name        = tempData.name,
        identifiers = tempData.identifiers,
        identifier  = tempData.identifier,
        ip          = tempData.ip,
        isAdmin     = false, -- Placeholder
        isLoaded    = false, -- Character not loaded yet
        Account     = tempData.Account, -- The account data fetched during connecting
        Character   = nil -- Character data added later
    }
    print(('[HazeCore] Finalized player data for %s (%s) using tempSrc %s.'):format(Players[finalSrc].name, finalSrc, tempSrc))

    -- Clean up temporary data using the numeric key
    ConnectingPlayers[numericTempSrc] = nil

    -- DEBUG: Print table content AFTER cleanup using json.encode
    print(('[HazeCore] ConnectingPlayers table AFTER cleanup for %s: %s'):format(numericTempSrc, json.encode(ConnectingPlayers)))
    return Players[finalSrc]
end


-- Function to retrieve data for a joined player.
function GetPlayerData(src)
    return Players[tonumber(src)] -- Ensure lookup uses number
end


-- Function to remove player data on disconnect (uses final ID).
function RemovePlayerData(src)
    local numericSrc = tonumber(src)
    if not numericSrc then return end -- Ignore if src isn't valid number

    if Players[numericSrc] then
        print(('[HazeCore] Removing player data for %s (%s)'):format(Players[numericSrc].name or 'Unknown', numericSrc))
        Players[numericSrc] = nil
    else
         print(('[^3[HazeCore] RemovePlayerData: Did not find player data for src %s.^0'):format(numericSrc))
    end
end


-- Function to update specific fields for a joined player.
function UpdatePlayerData(src, data)
    local numericSrc = tonumber(src)
    if not numericSrc then return false end -- Ignore if src isn't valid number

    if Players[numericSrc] and data then
        for key, value in pairs(data) do
            Players[numericSrc][key] = value
        end
        return true
    end
    return false
end


-- Helper function to determine the primary identifier (e.g., license)
function GetPrimaryIdentifier(identifiers)
    if not identifiers or type(identifiers) ~= 'table' then return nil end
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, 8) == 'license:' then
            return identifier
        end
    end
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, 6) == 'steam:' then
            return identifier
        end
    end
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, 8) == 'discord:' then
            return identifier
        end
    end
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, 5) == 'live:' then -- xbox
            return identifier
        end
    end
    -- Fallback to the first identifier if none of the preferred types are found
    return identifiers[1]
end


-- Helper to get a specific identifier type
function GetIdentifierByType(identifiers, idType) -- idType e.g., 'license', 'steam'
    if not identifiers or not idType then return nil end
    local prefix = idType .. ':'
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, #prefix) == prefix then
            return identifier
        end
    end
    return nil
end

print('[HazeCore] Player data management script loaded (sv_player_data.lua).')