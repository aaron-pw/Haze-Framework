fx_version 'cerulean'
game 'gta5'
author 'aaronpw'
description 'Haze Framework - Character Selection/Creation UI'
version '0.1.0'
lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'css/style.css',
    'js/script.js'
    -- Add image/font files here later if needed
}

client_scripts {
    'client/cl_charselect_ui.lua'
}

dependency 'ox_lib'