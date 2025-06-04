-- hz_charselect_ui/client/cl_charselect_ui.lua

local isNuiVisible = false
local nuiFocusCounter = 0
local currentCharacters = {}
local currentMaxSlots = 3
local contextCharId = nil
local charSelectCam = nil -- Variable to store our camera handle
local playerWasFrozen = false -- Track original freeze state
local playerWasInvisible = false -- Track original invisibility state

-- =============================================================================
-- Camera & Scene Management
-- =============================================================================

local function CreateCharacterSelectionScene()
    if charSelectCam then return end -- Don't create if already exists

    print('[hz_charselect_ui] Creating character selection scene...')
    local playerPed = PlayerPedId()

    -- Freeze player
    playerWasFrozen = IsEntityPositionFrozen(playerPed) -- Store original state
    FreezeEntityPosition(playerPed, true)

    -- Make player invisible
    playerWasInvisible = not IsEntityVisible(playerPed) -- Store original state
    SetEntityVisible(playerPed, false, false)

    -- Hide HUD and Minimap
    DisplayHud(false)
    DisplayRadar(false)

    -- Example Camera Position (Overlooking Maze Bank Tower) - Adjust as desired
    local camPos = vector3(280.0, -780.0, 45.0) -- Adjust height/distance as needed
    local camLookAt = vector3(182.9, -789.3, 31.8) -- Look towards Legion center

    charSelectCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(charSelectCam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(charSelectCam, camLookAt.x, camLookAt.y, camLookAt.z)
    SetCamActive(charSelectCam, true)
    RenderScriptCams(true, false, 0, true, false)

    -- Add blur effect (optional)
    -- SetTimecycleModifier("scanline_cam_cheap") -- Example modifier
    -- SetTimecycleModifierStrength(0.6)

    print('[hz_charselect_ui] Character selection scene created.')
end

local function DestroyCharacterSelectionScene()
    if not charSelectCam then return end -- Don't destroy if it doesn't exist

    print('[hz_charselect_ui] Destroying character selection scene...')
    local playerPed = PlayerPedId()

    RenderScriptCams(false, false, 0, true, false)
    SetCamActive(charSelectCam, false)
    DestroyCam(charSelectCam, true)
    charSelectCam = nil

    -- Clear blur effect (if used)
    -- ClearTimecycleModifier()

    -- Restore player visibility and freeze state IF they haven't just spawned
    -- (Spawning logic will handle visibility/freeze separately)
    if IsEntityVisible(playerPed) == false and not playerWasInvisible then
        -- SetEntityVisible(playerPed, true, false) -- Let spawn logic handle this
    end
    if IsEntityPositionFrozen(playerPed) == true and not playerWasFrozen then
         -- FreezeEntityPosition(playerPed, false) -- Let spawn logic handle this
    end

    -- Show HUD and Minimap (only if not being hidden by something else)
    DisplayHud(true)
    DisplayRadar(true)

     print('[hz_charselect_ui] Character selection scene destroyed.')
end


-- =============================================================================
-- NUI Visibility & Focus Management (Modified)
-- =============================================================================

local function SetNuiDisplay(show, data)
    isNuiVisible = show

    -- Send message FIRST
    if show and data then
         SendNUIMessage(data)
    else
         SendNUIMessage({ action = 'hideUI' })
    end

    -- Manage focus AFTER sending message
    SetNuiFocus(show, show)

    -- Manage scene creation/destruction
    if show then
        CreateCharacterSelectionScene()
    else
        DestroyCharacterSelectionScene()
    end

    -- Manage focus counter
    if show then
        nuiFocusCounter = nuiFocusCounter + 1
    else
        nuiFocusCounter = math.max(0, nuiFocusCounter - 1)
    end

    -- Ensure focus is set correctly based on counter (redundant check, but safe)
    if nuiFocusCounter > 0 then
        if not IsNuiFocused() then SetNuiFocus(true, true) end
    else
        if IsNuiFocused() then SetNuiFocus(false, false) end
    end
end

-- =============================================================================
-- Server -> Client Event Handlers (Mostly unchanged, scene handling is in SetNuiDisplay)
-- =============================================================================

RegisterNetEvent('hz:showCharacterUI', function(characters, maxSlots)
    -- (Logic remains the same, just calls SetNuiDisplay which now handles scene)
    if not isNuiVisible then
        print('[hz_charselect_ui] Received showCharacterUI event')
        currentCharacters = characters or {}
        currentMaxSlots = maxSlots or 3
        SetNuiDisplay(true, {
            action = 'showUI',
            characters = currentCharacters,
            maxSlots = currentMaxSlots
        })
        DoScreenFadeIn(500)
    else
        print('[hz_charselect_ui] Warning: Received showCharacterUI while already visible.')
        SendNUIMessage({
            action = 'showUI',
            characters = characters or currentCharacters,
            maxSlots = maxSlots or currentMaxSlots
        })
    end
end)

RegisterNetEvent('hz:hideCharacterUI', function()
     -- (Logic remains the same, just calls SetNuiDisplay which now handles scene)
     if isNuiVisible then
        print('[hz_charselect_ui] Received hideCharacterUI event')
        SetNuiDisplay(false)
     end
end)

RegisterNetEvent('hz:triggerAppearanceEditor', function(gender, charid)
    print(('[hz_charselect_ui] Received triggerAppearanceEditor for gender %s, charid %s'):format(gender, charid))
    -- IMPORTANT: Destroy the selection scene *before* starting appearance editor
    DestroyCharacterSelectionScene()
    -- NUI focus should already be false from SetNuiDisplay(false) above

    contextCharId = charid
    local modelHash = (tonumber(gender) == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
    print(('[hz_charselect_ui] Setting player model to %s...'):format(modelHash))
    Citizen.Await(exports['fivem-appearance']:setPlayerModel(modelHash))
    Wait(1000)
    print('[hz_charselect_ui] Model set. Starting player customization...')
    exports['fivem-appearance']:startPlayerCustomization(function(appearance)
        print('[hz_charselect_ui] fivem-appearance customization callback triggered.')
        -- Make ped visible again *after* editor closes, before potentially showing char screen
        local playerPed = PlayerPedId()
        if not playerWasInvisible then SetEntityVisible(playerPed, true, false) end

        if appearance then
            print(('[hz_charselect_ui] Appearance saved for context charid %s. Sending to server.'):format(contextCharId))
            local skinJson = json.encode(appearance)
            TriggerServerEvent('hz:server:saveSkin', skinJson, contextCharId)
            contextCharId = nil
        else
            print('[hz_charselect_ui] Appearance editing cancelled.')
            contextCharId = nil
            TriggerServerEvent('hz:server:requestCharacterList') -- Ask server to reshow UI
        end
    end)
end)

RegisterNetEvent('hz:spawnSelectedCharacter', function(charData)
    print(('[hz_charselect_ui] Received spawnSelectedCharacter for charid %s'):format(charData.charid))

    -- Ensure NUI is hidden and focus is released, and scene destroyed
    if isNuiVisible then
        SetNuiDisplay(false) -- This will also call DestroyCharacterSelectionScene
    else
        DestroyCharacterSelectionScene() -- Ensure scene is destroyed even if UI wasn't 'visible'
        SetNuiFocus(false, false)
    end

    ShutdownLoadingScreenNui()
    DoScreenFadeOut(0) -- Ensure screen isn't faded out

    local playerPed = PlayerPedId()
    local appearanceTable = nil

    -- Decode skin JSON safely
    if charData.skin and type(charData.skin) == 'string' then
        local success, decoded = pcall(json.decode, charData.skin)
        if success and decoded then appearanceTable = decoded
        else print('[hz_charselect_ui] Warning: Failed to decode skin JSON.') end
    else print('[hz_charselect_ui] Warning: Skin data missing or not a string.') end

    -- Apply Skin
    if appearanceTable then
        print('[hz_charselect_ui] Applying saved appearance data...')
        exports['fivem-appearance']:setPlayerAppearance(appearanceTable)
         -- Ensure ped is visible AFTER applying appearance
        SetEntityVisible(playerPed, true, false)
        Wait(500)
    else
        print('[hz_charselect_ui] No valid appearance data to apply. Setting model and making visible.')
        local modelHash = (tonumber(charData.gender) == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
        Citizen.Await(exports['fivem-appearance']:setPlayerModel(modelHash))
         -- Ensure ped is visible
        SetEntityVisible(playerPed, true, false)
        Wait(500) -- Give model time
    end

    -- Set Position and State
    local position = charData.position
    local spawnPosVec = nil
    if type(position) == 'table' and position.x then
        spawnPosVec = vector3(position.x, position.y, position.z)
    else
        print('[hz_charselect_ui] Warning: Invalid saved position data, using default spawn.')
        local defaultPos = Config.Spawns.Default -- Assuming Config is loaded or accessible
        spawnPosVec = vector3(defaultPos.x, defaultPos.y, defaultPos.z)
    end

    RequestCollisionAtCoord(spawnPosVec.x, spawnPosVec.y, spawnPosVec.z) -- Request collision before setting coords
    local attempts = 0
    while not HasCollisionLoadedAroundEntity(playerPed) and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
    end
    if attempts >= 50 then print("[hz_charselect_ui] Warning: Collision loading timed out.") end

    SetEntityCoords(playerPed, spawnPosVec.x, spawnPosVec.y, spawnPosVec.z, false, false, false, true)
    SetEntityHeading(playerPed, tonumber(charData.position.heading) or 0.0)

    -- Revive player if needed
    if charData.is_dead and charData.is_dead ~= 0 then
         SetEntityHealth(playerPed, 150)
         print('[hz_charselect_ui] Character was marked dead, attempting basic revive.')
    else
         SetEntityHealth(playerPed, charData.health or 200)
    end
    SetPedArmour(playerPed, charData.armour or 0)

    -- FreezeEntityPosition(playerPed, true) -- Freezing might feel abrupt here
    DoScreenFadeIn(1500) -- Longer fade-in now that ped is visible
    print('[hz_charselect_ui] Player spawn finalized.')
    -- Wait(1000)
    -- FreezeEntityPosition(playerPed, false)

    TriggerEvent('hz:playerSpawned', charData)
end)

-- Handle Errors from Server (Unchanged)
RegisterNetEvent('hz:characterSelectError', function(message)
    -- ... (same as before) ...
    print(('[hz_charselect_ui] Received characterSelectError: %s'):format(message)); SendNUIMessage({ action = 'setStatus', message = message or "Error"}); if not isNuiVisible then TriggerServerEvent('hz:server:requestCharacterList') end
end)
RegisterNetEvent('hz:characterCreateError', function(message)
    -- ... (same as before) ...
    print(('[hz_charselect_ui] Received characterCreateError: %s'):format(message)); SendNUIMessage({ action = 'setStatus', message = message or "Error"}); if not isNuiVisible then TriggerServerEvent('hz:server:requestCharacterList') end
end)

-- =============================================================================
-- NUI -> Client -> Server Communication Handlers (Unchanged)
-- =============================================================================
RegisterNUICallback('selectCharacter', function(data, cb)
    -- ... (same as before) ...
    local charid = data.charid and tonumber(data.charid); if charid then TriggerServerEvent('hz:server:selectCharacter', charid); cb({ success = true }) else cb({ success = false, message = "Invalid ID" }) end
end)
RegisterNUICallback('submitCharacterInfo', function(data, cb)
    -- ... (same as before) ...
    local charInfo = data; if not charInfo or not charInfo.slot or not charInfo.firstname or not charInfo.lastname then cb({ success = false, message = "Missing info"}) return end; TriggerServerEvent('hz:server:createCharacterAttempt', charInfo); cb({ success = true })
end)
RegisterNUICallback('closeCharacterUI', function(data, cb)
    -- ... (same as before) ...
    print('[hz_charselect_ui] NUI requested close.'); SetNuiDisplay(false); cb({ success = true }); -- TriggerServerEvent('hz:server:characterSelectClosed')
end)

-- =============================================================================
-- Resource Start / Stop (Unchanged)
-- =============================================================================
AddEventHandler('onClientResourceStart', function(resourceName) if resourceName == GetCurrentResourceName() then print('[hz_charselect_ui] Client script started.'); SetNuiDisplay(false) end end)
AddEventHandler('onClientResourceStop', function(resourceName) if resourceName == GetCurrentResourceName() then print('[hz_charselect_ui] Client script stopped.'); if isNuiVisible then SetNuiDisplay(false) end end end)

print('[hz_charselect_ui] Client script loaded.')