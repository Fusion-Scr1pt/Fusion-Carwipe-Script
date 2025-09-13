local scheduled = false
local scheduleTimer = nil
local SCHEDULE_MINUTES = 10

-- ===== Helpers =====
local function isStaff(xPlayer)
    if not xPlayer then return false end
    local g = xPlayer.getGroup()
    return g == 'mod' or g == 'admin' or g == 'superadmin'
end

local function notifyPlayer(target, msg, ntype, dur)
    TriggerClientEvent('vw:notify', target, {
        title = 'VehicleWipe',
        description = msg,
        type = ntype or 'inform',
        duration = dur or 5000
    })
end

local function notifyAll(msg, ntype, dur)
    TriggerClientEvent('vw:notify', -1, {
        title = 'VehicleWipe',
        description = msg,
        type = ntype or 'inform',
        duration = dur or 6000
    })
end

-- 🔥 Verwijder ALLE voertuigen (zonder inzittenden-check)
local function wipeAllVehicles()
    local removed = 0
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            DeleteEntity(veh)
            removed = removed + 1
        end
    end
    return removed
end

-- 🔥 Verwijder voertuigen “van” 1 speler:
--  - forceer client om z'n huidige voertuig te verwijderen (als die erin zit)
--  - verwijder server-side alle vehicles waarvoor hij de network owner is
local function wipeVehiclesOfPlayer(targetId)
    -- Laat de client z'n eigen huidige voertuig weggooien
    TriggerClientEvent('vw:client:deleteCurrentVehicle', targetId)

    local removed = 0
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local owner = NetworkGetEntityOwner(veh)
            if owner == targetId then
                DeleteEntity(veh)
                removed = removed + 1
            end
        end
    end
    return removed
end

-- ===== Server Events (ESX permissie) =====
RegisterNetEvent('vw:server:wipeNow', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isStaff(xPlayer) then
        notifyPlayer(src, '❌ Geen permissie (minimaal mod vereist).', 'error')
        return
    end

    notifyAll('🚨 Vehicle wipe gestart (alle voertuigen)...', 'warning')
    local count = wipeAllVehicles()
    notifyAll(('✅ Vehicle wipe klaar. Verwijderd: %d voertuig(en).'):format(count), 'success')
    print(('[VehicleWipe NOW] %d vehicles removed by %s'):format(count, xPlayer.getName()))
end)

RegisterNetEvent('vw:server:wipePlayer', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isStaff(xPlayer) then
        notifyPlayer(src, '❌ Geen permissie (minimaal mod vereist).', 'error')
        return
    end

    targetId = tonumber(targetId or 0)
    if not targetId or not GetPlayerName(targetId) then
        notifyPlayer(src, '❌ Ongeldige server ID.', 'error')
        return
    end

    local removed = wipeVehiclesOfPlayer(targetId)
    local tName = GetPlayerName(targetId) or ('ID ' .. targetId)
    notifyPlayer(src, ('✅ Klaar: %d voertuig(en) verwijderd voor %s.'):format(removed, tName), 'success')
    print(('[VehicleWipe PLAYER] %d vehicles removed for %s (%d) by %s'):format(
        removed, tName, targetId, xPlayer.getName()))
end)

-- Geplande wipe: notify op 10m (nu), 5m, 2m, 1m en dan 30s → 0s aftellen
RegisterNetEvent('vw:server:schedule10', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isStaff(xPlayer) then
        notifyPlayer(src, '❌ Geen permissie (minimaal mod vereist).', 'error')
        return
    end

    if scheduled then
        notifyPlayer(src, '⚠️ Er staat al een wipe gepland.', 'warning')
        return
    end

    scheduled = true
    local who = xPlayer.getName()
    notifyAll(('🕒 Vehicle wipe gepland over %d minuten.'):format(SCHEDULE_MINUTES), 'inform', 8000)
    print(('[VehicleWipe PLAN] scheduled by %s'):format(who))

    -- 5 minuten resterend
    SetTimeout((SCHEDULE_MINUTES - 5) * 60 * 1000, function()
        if not scheduled then return end
        notifyAll('⏳ Nog 5 minuten tot vehicle wipe.', 'warning')
    end)

    -- 2 minuten resterend
    SetTimeout((SCHEDULE_MINUTES - 2) * 60 * 1000, function()
        if not scheduled then return end
        notifyAll('⏳ Nog 2 minuten tot vehicle wipe.', 'warning')
    end)

    -- 1 minuut resterend
    SetTimeout((SCHEDULE_MINUTES - 1) * 60 * 1000, function()
        if not scheduled then return end
        notifyAll('⏳ Nog 1 minuut tot vehicle wipe.', 'warning')
    end)

    -- 30 seconden aftellen
    SetTimeout((SCHEDULE_MINUTES * 60 - 30) * 1000, function()
        if not scheduled then return end
        local seconds = 30
        local function tick()
            if not scheduled then return end
            if seconds <= 0 then
                notifyAll('🚨 Vehicle wipe gestart (alle voertuigen)...', 'warning')
                local count = wipeAllVehicles()
                notifyAll(('✅ Geplande wipe klaar. Verwijderd: %d voertuig(en).'):format(count), 'success')
                print(('[VehicleWipe RUN] %d vehicles removed (scheduled by %s)'):format(count, who))
                scheduled = false
                scheduleTimer = nil
                return
            else
                notifyAll(('⏱️ Vehicle wipe in %ds...'):format(seconds), 'warning', 1200)
                seconds = seconds - 1
                scheduleTimer = SetTimeout(1000, tick)
            end
        end
        tick()
    end)
end)