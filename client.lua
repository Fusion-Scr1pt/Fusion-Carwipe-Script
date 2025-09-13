--====================================================--
--  fusion-carwipe | CLIENT
--  Vereist: ox_lib (client) + server events uit server.lua
--====================================================--

--[[
Features (client):
- ox_lib notify handler (vw:notify)
- ox_lib context menu via /carwipe (alias /vehiclewipe)
  • Wipe nu (alle voertuigen)  -> roept server aan
  • Plan wipe over 10 minuten  -> roept server aan, met alerts (10,5,2,1 min + 30s countdown)
  • Wipe voor speler (server ID) -> inputDialog, roept server aan
- Event om het huidige voertuig van de speler lokaal te verwijderen
--]]

--=============================
-- ox_lib notify handler
--=============================
RegisterNetEvent('vw:notify', function(data)
    -- data: { title, description, type, duration }
    if not data then return end
    lib.notify({
        title = data.title or 'VehicleWipe',
        description = data.description or '',
        type = data.type or 'inform',   -- 'success' | 'error' | 'inform' | 'warning'
        duration = data.duration or 5000
    })
end)

--=============================
-- Huidig voertuig client-side verwijderen (gebruikt door /wipe player)
--=============================
RegisterNetEvent('vw:client:deleteCurrentVehicle', function()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        -- Zorg dat wij ‘m mogen verwijderen
        SetEntityAsMissionEntity(veh, true, true)
        -- Eerst proberen als “vehicle”
        DeleteVehicle(veh)
        -- Fallback als entity
        if DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
    end
end)

--=============================
-- ox_lib context menu openen
--=============================
local function openCarWipeMenu()
    lib.registerContext({
        id = 'vw_menu',
        title = 'Vehicle Wipe',
        options = {
            {
                title = '🚨 Wipe nu',
                description = 'Verwijder alle voertuigen direct (server-side)',
                icon = 'car-burst',
                onSelect = function()
                    TriggerServerEvent('vw:server:wipeNow')
                end
            },
            {
                title = '🕒 Plan wipe over 10 minuten',
                description = 'Stuurt meldingen op 10, 5, 2, 1 min en telt 30s → 0s af',
                icon = 'hourglass',
                onSelect = function()
                    TriggerServerEvent('vw:server:schedule10')
                end
            },
            {
                title = '👤 Wipe voertuigen van speler',
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

--=============================
-- Commands + (optionele) keybind
--=============================
RegisterCommand('carwipe', openCarWipeMenu, false)
RegisterCommand('vehiclewipe', openCarWipeMenu, false) -- alias

-- Optioneel: keybind (bijv. F6). Pas naar smaak aan of comment uit.
-- Zorg dat de ‘carwipe’ command hierboven geregistreerd is.
-- RegisterKeyMapping('carwipe', 'Open Vehicle Wipe menu', 'keyboard', 'F6')