fx_version 'cerulean'
game 'gta5'
author 'aaronpw'
description 'Haze Framework - Player Account and Character Management'
version '0.1.0'
lua54 'yes'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_accounts.lua'
}

exports {
    'GetPlayerAccount',
    'CreatePlayerAccount',
    'UpdatePlayerLastSeen',
    'GetPlayerCharacters',
    'GetCharacterData',
    'CreateCharacter',
    'UpdateCharacterPosition',
    'UpdateCharacterSkin',
    'DeletePlayerAccount'
}

-- Declare dependencies
dependencies {
    'oxmysql',
    'hz_core_config'
}