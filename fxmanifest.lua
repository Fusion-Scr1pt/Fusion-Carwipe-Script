server_script '@ElectronAC/src/include/server.lua'
client_script '@ElectronAC/src/include/client.lua'
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
    '@es_extended/imports.lua', -- ESX Legacy
    'server.lua'
}

client_scripts {
    'client.lua'
}