ESX = exports["es_extended"]:getSharedObject()

local STAFF_GROUPS = { mod = true, admin = true, superadmin = true }

local OWNED_TABLE       = 'owned_vehicles'
local OWNED_OWNER_FIELD = 'owner'
local OWNED_PLATE_FIELD = 'plate'

local SCHEDULE_MINUTES  = 10
local scheduled         = false

local function isStaff(xPlayer)
    if not xPlayer then return false end
    local g = xPlayer.getGroup and xPlayer.getGroup() or nil
    return g and STAFF_GROUPS[g] == true
end

local function normalizePlate(str)
    if not str then return '' end
    return (str:gsub('%s+','')):upper()
end

local function notifyPlayer(src, msg, typ, dur)
    TriggerClientEvent('vw:notify', src, {
        title = 'VehicleWipe',
        description = msg,
        type = typ or 'inform',
        duration = dur or 5000
    })
end

local function notifyAll(msg, typ, dur)
    TriggerClientEvent('vw:notify', -1, {
        title = 'VehicleWipe',
        description = msg,
        type = typ or 'inform',
        duration = dur or 5000
    })
end

local function fetchOwnedPlates(identifier)
    local rows
    if MySQL and MySQL.query and MySQL.query.await then
        rows = MySQL.query.await(
            ('SELECT %s FROM %s WHERE %s = ?'):format(OWNED_PLATE_FIELD, OWNED_TABLE, OWNED_OWNER_FIELD),
            { identifier }
        )
    elseif exports and exports.oxmysql and exports.oxmysql.executeSync then
        rows = exports.oxmysql:executeSync(
            ('SELECT %s FROM %s WHERE %s = ?'):format(OWNED_PLATE_FIELD, OWNED_TABLE, OWNED_OWNER_FIELD),
            { identifier }
        )
    else
        print('[fusion-carwipe] oxmysql niet gevonden. Voeg @oxmysql/lib/MySQL.lua toe.')
        return {}
    end

    local set = {}
    if rows then
        for _, r in ipairs(rows) do
            local p = r[OWNED_PLATE_FIELD]
            if p then set[normalizePlate(p)] = true end
        end
    end
    return set
end

local function forceDeleteVehServer(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    DeleteEntity(veh)
    Wait(0)
    if not DoesEntityExist(veh) then return true end
    if netId and netId ~= 0 then
        TriggerClientEvent('vw:client:forceDeleteNetVeh', -1, netId)
        Wait(150)
        if DoesEntityExist(veh) then
            DeleteEntity(veh)
            Wait(0)
        end
    end
    return not DoesEntityExist(veh)
end

local function collectOccupiedVehiclesSet()
    local occupied = {}
    for _, pid in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 and DoesEntityExist(veh) then
                occupied[veh] = true
            end
        end
    end
    return occupied
end

local function wipeAllVehicles()
    local occupied = collectOccupiedVehiclesSet()
    local removed = 0
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and not occupied[veh] then
            if forceDeleteVehServer(veh) then
                removed = removed + 1
            end
        end
    end
    return removed
end

local function wipeVehiclesOfPlayer(targetId)
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return 0 end

    local platesOwned = fetchOwnedPlates(xTarget.identifier)
    TriggerClientEvent('vw:client:deleteCurrentVehicle', targetId)

    local removed = 0
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local plate = normalizePlate(GetVehicleNumberPlateText(veh))
            if plate ~= '' and platesOwned[plate] then
                if forceDeleteVehServer(veh) then
                    removed = removed + 1
                end
            end
        end
    end
    return removed
end

RegisterCommand('carwipe', function(source)
    local src = source
    if src == 0 then
        print('[fusion-carwipe] /carwipe kan niet via console.')
        return
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isStaff(xPlayer) then
        notifyPlayer(src, 'Geen permissie (minimaal mod vereist).', 'error')
        return
    end
    TriggerClientEvent('vw:client:openCarwipeMenu', src)
end, false)

RegisterCommand('vehiclewipe', function(source)
    ExecuteCommand('carwipe')
end, false)

RegisterNetEvent('vw:server:wipeNow', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isStaff(xPlayer) then
        notifyPlayer(src, 'Geen permissie.', 'error'); return
    end

    notifyAll('🚨 Vehicle wipe gestart...', 'warning')
    local count = wipeAllVehicles()
    notifyAll(('Vehicle wipe klaar: %d voertuig(en) verwijderd.'):format(count), 'success')
    print(('[VehicleWipe NOW] %d vehicles removed by %s'):format(count, xPlayer.getName()))
end)

RegisterNetEvent('vw:server:schedule10', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isStaff(xPlayer) then
        notifyPlayer(src, '❌ Geen permissie.', 'error'); return
    end
    if scheduled then
        notifyPlayer(src, 'Er staat al een wipe gepland.', 'warning'); return
    end
    scheduled = true
    local who = xPlayer.getName()

    notifyAll(('🕒 Vehicle wipe gepland over %d minuten.'):format(SCHEDULE_MINUTES), 'inform')

    SetTimeout((SCHEDULE_MINUTES - 5) * 60 * 1000, function() if scheduled then notifyAll('⏳ Wipe over 5 min.', 'warning') end end)
    SetTimeout((SCHEDULE_MINUTES - 2) * 60 * 1000, function() if scheduled then notifyAll('⏳ Wipe over 2 min.', 'warning') end end)
    SetTimeout((SCHEDULE_MINUTES - 1) * 60 * 1000, function() if scheduled then notifyAll('⏳ Wipe over 1 min.', 'warning') end end)

    SetTimeout((SCHEDULE_MINUTES * 60 - 30) * 1000, function()
        if not scheduled then return end
        local sec = 30
        local function tick()
            if not scheduled then return end
            if sec <= 0 then
                notifyAll('🚨 Vehicle wipe gestart...', 'warning')
                local count = wipeAllVehicles()
                notifyAll(('Geplande wipe klaar: %d voertuig(en) verwijderd.'):format(count), 'success')
                print(('[VehicleWipe RUN] %d vehicles removed (scheduled by %s)'):format(count, who))
                scheduled = false
                return
            end
            notifyAll(('⏱️ Wipe in %ds...'):format(sec), 'warning', 1100)
            sec = sec - 1
            SetTimeout(1000, tick)
        end
        tick()
    end)
end)

RegisterNetEvent('vw:server:wipePlayer', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isStaff(xPlayer) then
        notifyPlayer(src, 'Geen permissie.', 'error'); return
    end

    targetId = tonumber(targetId or 0)
    if not targetId or not GetPlayerName(targetId) then
        notifyPlayer(src, 'Ongeldige server ID.', 'error'); return
    end

    local removed = wipeVehiclesOfPlayer(targetId)
    local tName = GetPlayerName(targetId) or ('ID ' .. targetId)
    notifyPlayer(src, ('%d voertuig(en) van %s verwijderd.'):format(removed, tName), 'success')
    print(('[VehicleWipe PLAYER] %d vehicles removed for %s (%d) by %s'):format(
        removed, tName, targetId, xPlayer.getName()))
end)
