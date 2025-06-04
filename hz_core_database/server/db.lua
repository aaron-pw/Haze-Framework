--[[
    hz_core_database/server/db.lua
    Initializes and verifies the database connection using the oxmysql library.
    Relies on oxmysql connecting automatically via the 'mysql_connection_string' convar.
    Uses the MySQL global object provided by @oxmysql/lib/MySQL.lua.
]]
print('[HazeDB] Initialized. Waiting for oxmysql readiness via MySQL.ready.await()...')

local ready = MySQL.ready.await()

-- Check if oxmysql successfully initialized
if not ready then
    print('^1[HazeDB] FATAL ERROR: MySQL.ready.await() did not return true. oxmysql failed to initialize or connect. Check server console for oxmysql errors and verify connection string.^0')
    return
end

print('[HazeDB] oxmysql is ready. Performing simple test query...')

local success, result = pcall(MySQL.Sync.fetchScalar, 'SELECT 1 AS test', {}) -- Use 'AS test' just for clarity

-- Check the results of the test query
if success and result == 1 then
    print('^2[HazeDB] Test query successful (SELECT 1). Database connection confirmed.^0')

    -- Trigger an event that other resources can listen for, signifying the DB is ready.
    -- This is crucial for resources that need to query the DB immediately on start.
    TriggerEvent('hz:databaseConnected')

    -- TODO: You can now safely export database functions from this resource if desired.
    -- Example:
    -- exports('GetUserById', function(userId)
    --     if not userId then return nil end
    --     local p = promise.new()
    --     MySQL.Async.fetchSingle('SELECT * FROM users WHERE id = ?', { userId }, function(user)
    --         p:resolve(user) -- Resolve promise with the user data (or nil)
    --     end)
    --     return Citizen.Await(p) -- Return the awaited result
    -- end)

else
    -- Test query failed.
    if not success then
        print('^1[HazeDB] FATAL ERROR: Test query failed during execution! Error: ' .. tostring(result) .. '^0')
        print('^1[HazeDB] Check database permissions, connection string, and ensure MySQL server is running.^0')
    else
        print('^1[HazeDB] FATAL ERROR: Test query executed but returned an unexpected result: ' .. tostring(result) .. '^0')
    end
end

print('[HazeDB] Database handler script finished initialization.')