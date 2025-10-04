RegisterNetEvent('vw:notify', function(data)
    if not data then return end
    lib.notify({
        title = data.title or 'VehicleWipe',
        description = data.description or '',
        type = data.type or 'inform',
        duration = data.duration or 5000
    })
end)

RegisterNetEvent('vw:client:deleteCurrentVehicle', function()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        if DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
    end
end)

local function openCarWipeMenu()
    lib.registerContext({
        id = 'vw_menu',
        title = 'Vehicle Wipe',
        options = {
            {
                title = 'Wipe nu',
                description = 'Verwijder alle voertuigen direct (server-side)',
                icon = 'car-burst',
                onSelect = function()
                    TriggerServerEvent('vw:server:wipeNow')
                end
            },
            {
                title = 'Plan wipe over 10 minuten',
                description = 'Alerts op 10, 5, 2, 1 min en 30s → 0',
                icon = 'hourglass',
                onSelect = function()
                    TriggerServerEvent('vw:server:schedule10')
                end
            },
            {
                title = 'Wipe voertuigen van speler',
                description = 'Voer een server ID in',
                icon = 'user-slash',
                onSelect = function()
                    local input = lib.inputDialog('Wipe voertuigen van speler', {
                        { type = 'number', label = 'Server ID', required = true, min = 1 }
                    })
                    if input and input[1] then
                        TriggerServerEvent('vw:server:wipePlayer', tonumber(input[1]))
                    end
                end
            }
        }
    })
    lib.showContext('vw_menu')
end

RegisterCommand('carwipe', openCarWipeMenu, false)
RegisterCommand('vehiclewipe', openCarWipeMenu, false)
