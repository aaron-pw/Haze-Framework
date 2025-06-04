-- Client entry point, can add event handlers here later
print('[HazeCore] Base client script loaded.')

-- Example: Greet player once spawned
AddEventHandler('playerSpawned', function()
    -- Use ox_lib notification later: lib.notify({ title = 'Haze Framework', description = 'Welcome!', type = 'inform' })
    print('[HazeCore] Player has spawned.')
    -- Maybe TriggerServerEvent('hz:playerSpawned') later if needed
end)