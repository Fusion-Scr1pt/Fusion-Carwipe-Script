fx_version 'cerulean'
game 'gta5'

author 'Fusion Scripts'
description 'Carwipe Script'

dependency 'es_extended'
dependency 'ox_lib'

shared_scripts {
    '@ox_lib/init.lua'
}

server_scripts {
    '@es_extended/imports.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}