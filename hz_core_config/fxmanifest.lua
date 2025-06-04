fx_version 'cerulean'
game 'gta5'
author 'aaronpw'
description 'Haze Framework - Core Configuration Loader'
version '0.1.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

exports {
    'GetConfig'
}

load_before 'hz_core_database'
load_before 'hz_core_base'