fx_version 'cerulean'
game 'gta5'
author 'Your Name / aaronpw'
description 'Haze Framework - Core Base Logic, Player Handling'
version '0.1.0'
lua54 'yes'

convar_category 'Haze Framework Core' {
    'Core Settings',
    {
        -- Example: Display sv_maxclients setting in txAdmin under this category
        -- { 'Max Players', 'sv_maxclients', 'CV_INT', '64' }
        -- Add other core convars here if needed
    }
}

server_scripts {
    'server/sv_player_data.lua',
    'server/sv_main.lua'
}
client_scripts {
    'client/cl_main.lua'
}

dependencies {
    'ox_lib',
    'hz_core_config',
    'hz_core_database',
    'hz_player_accounts'
}