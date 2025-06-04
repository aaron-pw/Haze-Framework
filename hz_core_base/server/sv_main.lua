--[[
    hz_core_base/server/sv_main.lua
    Core server logic: player connection, hardcap, account loading, character selection/loading, saving.
]]

-- Get config settings (ensure hz_core_config loads first)
local Config = exports.hz_core_config:GetConfig()
local Debug = Config and Config.Debug -- Use debug flag from config
local MaxCharSlots = Config and Config.Characters and Config.Characters.MaxSlots or 3 -- Default 3 if config fails

-- Forward declaration for the spawning function (defined later in the file)
local SpawnPlayerCharacter

-- =============================================================================
--  Player Connecting Handler (Hardcap, Account Check/Creation)
-- =============================================================================
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local tempSrc = source -- Use tempSrc to be clear this is the temporary ID
    local identifiers = GetPlayerIdentifiers(tempSrc)
    local ip = GetPlayerEndpoint(tempSrc)

    -- Start deferrals: Player sees "Connecting..." messages
    deferrals.defer()
    Wait(100) -- Allow FiveM internal processes time

    -- 1. Custom Hardcap Check
    deferrals.update("Checking server capacity...")
    local currentPlayers = #GetPlayers()
    local maxPlayers = GetConvarInt('sv_maxclients', 64) -- Get max clients from convar
    if Debug then print(('[HazeCore] Player Count: %d/%d'):format(currentPlayers, maxPlayers)) end
    if currentPlayers >= maxPlayers then
        -- TODO: Implement priority queue check here
        print(('[HazeCore] Server full. Kicking %s (%s).'):format(playerName, tempSrc))
        deferrals.done("Server is currently full. Please try again later.")
        return
    end
    Wait(200)

    -- 2. Prepare Temporary Player Info
    deferrals.update("Verifying identifiers...")
    local primaryId = GetPrimaryIdentifier(identifiers)
    if not primaryId then
        print(('[^1[HazeCore] Could not determine primary identifier for connecting player %s (%s). Kicking.^0'):format(playerName, tempSrc))
        deferrals.done("Could not verify your identifiers. Please reconnect.")
        return
    end

    -- Create a temporary table to hold data during the connection phase
    local tempPlayerData = {
        tempSource = tempSrc,
        name = playerName,
        identifiers = identifiers,
        identifier = primaryId,
        ip = ip,
        Account = nil -- Account data will be added after fetching/creation
    }
    Wait(100)

    -- 3. Check/Create Player Account
    deferrals.update("Retrieving account information...")
    local accountData = exports.hz_player_accounts:GetPlayerAccount(tempPlayerData.identifier)
    Wait(200) -- Simulate work / allow DB call time

    if accountData then
        -- Account Found
        if Debug then print(('[HazeCore] Found account for %s (%s)'):format(playerName, tempPlayerData.identifier)) end

        -- Check if banned
        if accountData.is_banned then
            local expiry = accountData.ban_expires
            local reason = accountData.ban_reason or "No reason provided."
            local message = "You are banned from this server."
            if expiry then
                message = ("You are banned from this server until %s. Reason: %s"):format(os.date('%Y-%m-%d %H:%M', expiry), reason)
            else -- Permanent
                message = ("You are permanently banned from this server. Reason: %s"):format(reason)
            end
            print(('[HazeCore] Player %s is banned. Kicking.'):format(playerName))
            deferrals.done(message)
            return -- Don't store temporary data if banned
        end

        -- Update last seen (consider async later)
        exports.hz_player_accounts:UpdatePlayerLastSeen(tempPlayerData.identifier)
        -- Add account data to the temporary structure
        tempPlayerData.Account = accountData
        deferrals.update("Account verified.")

    else
        -- Account Not Found - Create New One
        deferrals.update("Creating new account...")
        if Debug then print(('[HazeCore] No account found for %s (%s). Creating new one.'):format(playerName, tempPlayerData.identifier)) end

        local success = exports.hz_player_accounts:CreatePlayerAccount({
            identifier = tempPlayerData.identifier,
            license    = GetIdentifierByType(identifiers, 'license'),
            steam      = GetIdentifierByType(identifiers, 'steam'),
            discord    = GetIdentifierByType(identifiers, 'discord'),
            xbox       = GetIdentifierByType(identifiers, 'live'),
            ip         = tempPlayerData.ip,
            name       = playerName
        })
        Wait(300) -- Simulate creation time

        if success then
            -- Re-fetch the newly created account data to store it
            accountData = exports.hz_player_accounts:GetPlayerAccount(tempPlayerData.identifier)
            if accountData then
                tempPlayerData.Account = accountData -- Add newly created account data
                deferrals.update("Account created successfully.")
                if Debug then print(('[HazeCore] Successfully created account for %s'):format(playerName)) end
            else
                print(('[^1[HazeCore] Failed to re-fetch account after creation for %s. Kicking.^0'):format(playerName))
                deferrals.done("Error verifying your new account. Please try reconnecting.")
                return -- Don't store temporary data if re-fetch failed
            end
        else
            print(('[^1[HazeCore] Failed to create account for %s. Kicking.^0'):format(playerName))
            deferrals.done("There was an error creating your account. Please try reconnecting.")
            return -- Don't store temporary data if creation failed
        end
    end

    -- Store the completed temporary data structure, keyed by temporary source ID.
    -- This data will be picked up by playerJoining using the oldSource ID.
    StoreTemporaryPlayerData(tempSrc, tempPlayerData)
    Wait(0)

    print(('[HazeCore] Player %s (%s) connection sequence complete. Handing off...'):format(playerName, tempSrc))
    Wait(100) -- Small buffer before finishing deferrals
    deferrals.done() -- Allow player connection
end)


-- =============================================================================
--  Player Joining Handler (Finalize Data, Character Selection Trigger)
-- =============================================================================
AddEventHandler('playerJoining', function(oldSource)
    -- oldSource is the temporary ID used during playerConnecting
    local src = source -- This is the NEW, final server ID for the player

    print(('[HazeCore] Player joining with final source %s (previous temp source %s)'):format(src, oldSource))

    -- Move data from temporary storage (ConnectingPlayers) to the main Players table
    -- using the final source ID 'src'. This function is defined in sv_player_data.lua.
    local player = FinalizePlayerData(src, oldSource)

    -- Check if the data was successfully transferred
    if not player then
        -- FinalizePlayerData already printed an error if tempData was missing
        print(('[^1[HazeCore] Kicking player %s due to missing temporary data during join.^0'):format(src))
        DropPlayer(src, "Session data lost during connection. Please reconnect.")
        return
    end

    -- Now 'player' refers to Players[src] which contains the Account data fetched during connecting
    print(('[HazeCore] Player %s (%s) finalized. Account ID: %s'):format(player.name, src, player.identifier))

    -- Fetch character list for this player
    local characters = exports.hz_player_accounts:GetPlayerCharacters(player.identifier)

    -- Handle 0-Character Scenario (First Join)
    if #characters == 0 then
        print(('[HazeCore] Player %s has account but 0 characters. Proceeding directly to creation.'):format(player.identifier))
        -- Instead of deleting and kicking, send an empty list to the UI.
        -- The UI logic (JS) should ideally handle showing only "Create" options
        -- when the character list is empty.
        TriggerClientEvent('hz:showCharacterUI', src, {}, MaxCharSlots) -- Send empty table {}
        -- Player will now see the UI and should only be able to click "Create"
        return -- Stop further processing in this block
    end

    -- Send character list and max slots to the client UI
    print(('[HazeCore] Sending character data to player %s'):format(src))
    TriggerClientEvent('hz:showCharacterUI', src, characters, MaxCharSlots)
    -- Player is now in character selection NUI and further action depends on client events
end)


-- =============================================================================
--  Character Selection/Creation Event Handlers (from Client NUI)
-- =============================================================================

-- Triggered when player selects an existing character in the NUI
RegisterNetEvent('hz:server:selectCharacter', function(charid)
    local src = source -- This is the final player ID
    local player = GetPlayerData(src) -- Use final ID to get player data

    if not player or not player.Account then
        print(('[^1[HazeCore] Error selecting character: Player data not found for source %s.^0'):format(src))
        TriggerClientEvent('hz:characterSelectError', src, "Error retrieving your account data.")
        return
    end

    print(('[HazeCore] Player %s (%s) attempting to select charid %s'):format(player.name, src, charid))

    -- Verify the character belongs to this player
    local charData = exports.hz_player_accounts:GetCharacterData(charid)

    if not charData then
        print(('[^1[HazeCore] Error selecting character: Charid %s not found in database.^0'):format(charid))
        TriggerClientEvent('hz:characterSelectError', src, "Character data not found.")
        return
    end

    if charData.identifier ~= player.identifier then
        print(('[^1[HazeCore] SECURITY WARNING: Player %s (%s) attempted to select character %s belonging to %s! Kicking.^0'):format(player.name, player.identifier, charid, charData.identifier))
        DropPlayer(src, "Character selection mismatch. Security violation.")
        return
    end

    -- Character is valid and belongs to player
    print(('[HazeCore] Character %s selected for player %s (%s). Spawning...'):format(charid, player.name, src))

    -- Decode JSON fields stored as text in DB before storing in player table / sending to client
    charData.position = json.decode(charData.position or '{}') -- Decode position JSON
    charData.status = json.decode(charData.status or '{}')     -- Decode status JSON
    -- Skin (charData.skin) is usually kept as JSON string for fivem-appearance

    -- Store the selected character data in the player's runtime data table
    UpdatePlayerData(src, { Character = charData, isLoaded = false }) -- Set isLoaded=false until fully spawned

    -- Spawn the player using the helper function
    SpawnPlayerCharacter(src, charData)
end)


-- Triggered when player submits info for a new character from NUI
RegisterNetEvent('hz:server:createCharacterAttempt', function(charInfo)
    local src = source -- Final player ID
    local player = GetPlayerData(src) -- Use final ID

    if not player or not player.Account then
        print(('[^1[HazeCore] Error creating character: Player data not found for source %s.^0'):format(src))
        TriggerClientEvent('hz:characterCreateError', src, "Error retrieving your account data.")
        return
    end

    print(('[HazeCore] Player %s (%s) attempting to create character in slot %s'):format(player.name, src, charInfo.slot))

    -- ** Server-Side Validation **
    -- 1. Check slot number validity
    if not charInfo.slot or charInfo.slot < 1 or charInfo.slot > MaxCharSlots then
        TriggerClientEvent('hz:characterCreateError', src, "Invalid character slot selected.")
        return
    end

    -- 2. Check if slot is already taken
    local existingChars = exports.hz_player_accounts:GetPlayerCharacters(player.identifier)
    for _, char in ipairs(existingChars) do
        if char.slot == charInfo.slot then
            TriggerClientEvent('hz:characterCreateError', src, "That character slot is already in use.")
            return
        end
    end

    -- 3. Validate names, DOB, etc. (Add more robust checks as needed)
    if not charInfo.firstname or #charInfo.firstname < 2 or string.find(charInfo.firstname, "[^%a%s%-]") then
        TriggerClientEvent('hz:characterCreateError', src, "Invalid first name (min 2 letters, hyphens, spaces allowed).")
        return
    end
    if not charInfo.lastname or #charInfo.lastname < 2 or string.find(charInfo.lastname, "[^%a%s%-]") then
        TriggerClientEvent('hz:characterCreateError', src, "Invalid last name (min 2 letters, hyphens, spaces allowed).")
        return
    end
    -- TODO: Add proper DOB validation (e.g., check age range)

    -- Validation passed, attempt to create in DB
    -- Prepare data for the CreateCharacter export
    local createData = {
        identifier = player.identifier,
        slot = charInfo.slot,
        firstname = charInfo.firstname,
        lastname = charInfo.lastname,
        dateofbirth = charInfo.dateofbirth,
        gender = charInfo.gender,
        nationality = charInfo.nationality,
        -- Using defaults defined in hz_player_accounts:CreateCharacter for cash, bank, job, pos, status, skin
    }

    local newCharId = exports.hz_player_accounts:CreateCharacter(createData)

    if newCharId then
        print(('[HazeCore] Character record %s created for %s. Triggering appearance editor.'):format(newCharId, player.identifier))
        -- Store the temporary charid, maybe? To ensure skin save context is correct?
        UpdatePlayerData(src, { creatingCharId = newCharId }) -- Store temporarily

        -- Trigger the appearance editor on the client
        -- Pass gender preference and the new charid for context
        TriggerClientEvent('hz:triggerAppearanceEditor', src, tonumber(charInfo.gender), newCharId)

    else
        print(('[^1[HazeCore] Failed to create character record for %s in DB.^0'):format(player.identifier))
        TriggerClientEvent('hz:characterCreateError', src, "Failed to save character information. Please try again.")
    end
end)


-- Triggered from client after fivem-appearance saves skin data
RegisterNetEvent('hz:server:saveSkin', function(skinData, contextCharId)
    local src = source -- Final player ID
    local player = GetPlayerData(src) -- Use final ID

    if not player or not player.Account then
        print(('[^1[HazeCore] Error saving skin: Player data not found for source %s.^0'):format(src))
        return
    end

    -- Validate contextCharId (could use player.creatingCharId or verify it belongs to player)
    if not contextCharId then
        print(('[^1[HazeCore] Error saving skin: No character context ID provided for player %s.^0'):format(src))
        -- Optionally try player.creatingCharId if available? Risky.
        return
    end

    -- Optional: Verify contextCharId matches player.creatingCharId if you stored it
    -- if player.creatingCharId ~= contextCharId then
    --    print(('[^1[HazeCore] Error saving skin: Context char ID mismatch for player %s.^0'):format(src))
    --    return
    -- end

    print(('[HazeCore] Received skin data for charid %s from player %s (%s)'):format(contextCharId, player.name, src))

    -- Save the skin data to the database
    local saved = exports.hz_player_accounts:UpdateCharacterSkin(contextCharId, skinData)

    if saved then
        -- Skin saved, now fetch the full character data (including the new skin) and spawn
        local charData = exports.hz_player_accounts:GetCharacterData(contextCharId)
        if charData and charData.identifier == player.identifier then -- Verify ownership again
            print(('[HazeCore] Skin saved for charid %s. Spawning character...'):format(contextCharId))
            -- Decode JSON fields for runtime use
            charData.position = json.decode(charData.position or '{}')
            charData.status = json.decode(charData.status or '{}')

            -- Update player table with the final character data and clear temp marker
            UpdatePlayerData(src, { Character = charData, isLoaded = false, creatingCharId = nil })
            -- Spawn the player
            SpawnPlayerCharacter(src, charData)
        else
            print(('[^1[HazeCore] Error saving skin: Failed to fetch/verify character data after save for charid %s.^0'):format(contextCharId))
            DropPlayer(src, "Error finalizing character creation.")
        end
    else
        print(('[^1[HazeCore] Error saving skin: Failed to update database for charid %s.^0'):format(contextCharId))
        DropPlayer(src, "Error saving appearance data.")
    end
end)


-- Added handler for when appearance editor is cancelled or player requests list refresh
RegisterNetEvent('hz:server:requestCharacterList', function()
    local src = source -- Final player ID
    local player = GetPlayerData(src) -- Use final ID

    if not player or not player.Account then
        print(('[^1[HazeCore] Error handling requestCharacterList: Player data not found for source %s.^0'):format(src))
        DropPlayer(src, "Session error. Please reconnect.")
        return
    end

    print(('[HazeCore] Player %s (%s) requested character list again.'):format(player.name, src))

    -- Re-fetch character list
    local characters = exports.hz_player_accounts:GetPlayerCharacters(player.identifier)

    -- Send character list and max slots back to the client UI
    TriggerClientEvent('hz:showCharacterUI', src, characters, MaxCharSlots)
end)


-- =============================================================================
--  Player Spawning Function
-- =============================================================================

-- Spawns the player with their selected character data
SpawnPlayerCharacter = function(src, charData)
    local player = GetPlayerData(src) -- Use final ID
    if not player or not charData then
        print(('[^1[HazeCore] SpawnPlayerCharacter failed: Missing player or charData for source %s.^0'):format(src))
        DropPlayer(src, "Failed to load character data for spawning.")
        return
    end

    -- Update player state - Mark as fully loaded *before* sending spawn trigger
    UpdatePlayerData(src, { isLoaded = true })

    -- Hide character selection UI on the client
    TriggerClientEvent('hz:hideCharacterUI', src)

    -- Tell client to handle the actual spawning (apply skin, set pos, health, etc.)
    print(('[HazeCore] Triggering client spawn for %s (%s) with charid %s'):format(player.name, src, charData.charid))
    TriggerClientEvent('hz:spawnSelectedCharacter', src, charData)

    -- Trigger a server-side event that other resources can listen for
    -- (e.g., inventory, status loops, job managers might need this)
    TriggerEvent('hz:playerCharacterLoaded', src, charData)
end


-- =============================================================================
--  Player Dropping Handler (Saving Data)
-- =============================================================================
AddEventHandler('playerDropped', function(reason)
    local src = source -- This is the final player ID
    local player = GetPlayerData(src) -- Use final ID to get data

    if player then
        print(('[HazeCore] Player %s (%s - %s) disconnected. Reason: %s'):format(player.name, src, player.identifier, reason))

        -- Check if character data was loaded and save it
        if player.isLoaded and player.Character then
            local charid = player.Character.charid
            local ped = GetPlayerPed(src) -- This might be 0 if player disconnected abruptly

            if ped and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                local health = GetEntityHealth(ped)
                local armour = GetPedArmour(ped)
                -- TODO: Get current status (hunger/thirst) from player table if updated during gameplay
                -- local currentStatusJson = json.encode(player.Character.status or {}) -- Needs live updates

                local positionData = {
                    x = tonumber(string.format("%.2f", coords.x)),
                    y = tonumber(string.format("%.2f", coords.y)),
                    z = tonumber(string.format("%.2f", coords.z)),
                    heading = tonumber(string.format("%.2f", heading))
                }
                local positionJson = json.encode(positionData)

                -- TODO: Implement a single 'UpdateCharacterData' function in hz_player_accounts
                --       that takes a table of fields to update (pos, health, armour, status, etc.)
                -- For now, save position separately.
                print(('[HazeCore] Saving position for charid %s: %s'):format(charid, positionJson))
                local savedPos = exports.hz_player_accounts:UpdateCharacterPosition(charid, positionJson)
                if not savedPos then
                    print(('[^1[HazeCore] Failed to save position for charid %s on disconnect.^0'):format(charid))
                end
                -- Add separate calls to save health, armour, etc. until UpdateCharacterData is made
                -- exports.hz_player_accounts:UpdateCharacterHealth(charid, health) -- Example, needs export
                -- exports.hz_player_accounts:UpdateCharacterArmour(charid, armour) -- Example, needs export

            else
                 print(('[^3[HazeCore] Could not get player ped for saving charid %s on disconnect (Ped: %s). Saving only non-ped data if possible.^0'):format(charid, tostring(ped)))
                 -- Still attempt to save non-ped data if applicable (e.g., inventory if stored in player table)
            end
        else
            print(('[HazeCore] No character data loaded for %s, skipping character save.'):format(player.name))
        end

        -- Finally, remove the player's data from the active Players table using the final source ID
        RemovePlayerData(src)
    else
        -- This can happen if player disconnects during connection phase or if data was already cleaned up
        print(('[HazeCore] Player %s disconnected (data not found in Players table). Reason: %s'):format(src, reason))
    end
end)


-- Initial message indicating the script loaded
print('^2[HazeCore] Base server script loaded (sv_main.lua). Player handlers active.^0')