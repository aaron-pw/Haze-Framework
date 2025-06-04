fx_version 'cerulean'
game 'gta5'
author 'aaronpw'
description 'Haze Framework - Database Handling'
version '0.1.0'
lua54 'yes'

server_scripts {
    -- CRITICAL: Include the oxmysql Lua library file. This file provides the
    -- global 'MySQL' object (MySQL.Sync, MySQL.Async, MySQL.ready) which acts
    -- as the compatibility bridge to the core oxmysql resource (which runs JS).
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua'
}

dependencies {
    'oxmysql',
    'hz_core_config'
}