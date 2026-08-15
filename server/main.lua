-- Used to store vehicles that have been taken out
---@type table<string, number>
local activeVehicles = {}
local propertyGarages = {}

local function normalizeGarageType(vehicleType)
    vehicleType = tostring(vehicleType or 'car'):lower()

    if vehicleType == 'automobile' or vehicleType == 'bike' or vehicleType == 'bicycle' or vehicleType == 'quadbike' then
        return 'car'
    elseif vehicleType == 'plane' or vehicleType == 'heli' or vehicleType == 'helicopter' then
        return 'air'
    elseif vehicleType == 'jetski' then
        return 'boat'
    end

    return vehicleType
end

local function propertyGarageId(name)
    local value = tostring(name or '')

    if propertyGarages[value] then return value end

    value = value:lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')

    if value:sub(1, 9) == 'property_' then
        return value
    end

    return ('property_%s'):format(value)
end

local function coordsToVector4(coords)
    if not coords then return end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)

    if not x or not y or not z then return end

    return vector4(x, y, z, tonumber(coords.w or coords.heading or coords.h) or 0.0)
end

local function vecToTable(coords)
    if not coords then return end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = coords.w or coords.heading or 0.0
    }
end

local function copyKeyholders(keyholders)
    local result = {}

    if type(keyholders) ~= 'table' then return result end

    for _, citizenid in pairs(keyholders) do
        result[#result + 1] = citizenid
    end

    return result
end

local function tableContains(list, value)
    for _, item in pairs(list or {}) do
        if item == value then return true end
    end

    return false
end

local function hasConfiguredJob(player, jobs)
    if not jobs then return true end

    local job = player:getJob()

    if type(jobs) == 'string' then
        return job == jobs
    end

    for _, name in ipairs(jobs) do
        if job == name then return true end
    end

    return false
end

local function getGarage(index)
    if type(index) == 'number' then
        return Config.Garages[index]
    elseif type(index) == 'string' then
        return propertyGarages[index]
    end
end

local function playerCanAccessGarage(player, garage)
    if not garage then return false end
    if not hasConfiguredJob(player, garage.Jobs) then return false end
    if not garage.Property then return true end

    local identifier = player:getIdentifier()

    return garage.Owner == identifier or tableContains(garage.Keyholders, identifier)
end

local function vehicleMatchesOwnershipMode(vehicle, player, society)
    if society then
        return vehicle.job and vehicle.job ~= '' and vehicle.job == player:getJob()
    end

    return not vehicle.job or vehicle.job == ''
end

local function canAccessGarage(source, garage)
    local player = Framework.getPlayerFromId(source)
    if not player then return false end

    return playerCanAccessGarage(player, garage)
end

local function garageCoords(garage)
    return garage.Position or garage.PedPosition or garage.SpawnPosition
end

local function isNearCoords(source, coords)
    if not coords then return false end

    local playerPed = GetPlayerPed(source)
    if not playerPed or playerPed == 0 then return false end

    local playerCoords = GetEntityCoords(playerPed)
    local distance = math.max(Config.MaxDistance or 10.0, 25.0)

    return #(playerCoords - vector3(coords.x, coords.y, coords.z)) <= distance
end

local function isNearGarage(source, garage)
    return isNearCoords(source, garageCoords(garage))
end

local function isNearGarageParking(source, garage)
    if garage.Property and garage.SpawnPosition then
        return isNearCoords(source, garage.SpawnPosition)
    end

    return isNearGarage(source, garage)
end

local function spawnTypeMatchesGarage(spawnType, garage)
    return normalizeGarageType(spawnType) == normalizeGarageType(garage.Type)
end

local function clientGarageData(garage)
    return {
        Label = garage.Label,
        Type = garage.Type,
        Position = vecToTable(garage.Position),
        SpawnPosition = vecToTable(garage.SpawnPosition),
        Interior = garage.Interior,
        Property = true,
        Visible = false
    }
end

local function refreshPropertyGarageForPlayer(source, id)
    local garage = propertyGarages[id]

    if garage and canAccessGarage(source, garage) then
        TriggerClientEvent('lunar_garage:client:registerPropertyGarage', source, id, clientGarageData(garage))
    else
        TriggerClientEvent('lunar_garage:client:removePropertyGarage', source, id)
    end
end

local function refreshPropertyGarage(id)
    for _, playerId in ipairs(GetPlayers()) do
        refreshPropertyGarageForPlayer(tonumber(playerId), id)
    end
end

local function RegisterPropertyGarage(name, data)
    if type(data) ~= 'table' then return false end

    local accessPoint = data.accessPoints and data.accessPoints[1] or data.AccessPoints and data.AccessPoints[1]
    local entryData = data.entryCoords or data.EntryCoords or data.Position or data.position or data.coords or data.Coords
    local spawnData = data.spawnCoords or data.SpawnCoords or data.SpawnPosition or data.spawnPosition or data.coords or data.Coords

    if not entryData and accessPoint then
        entryData = accessPoint.coords or accessPoint.entry or accessPoint.entryCoords
    end

    if not spawnData and accessPoint then
        spawnData = accessPoint.spawn or accessPoint.spawnCoords or accessPoint.coords
    end

    local entryCoords = coordsToVector4(entryData)
    local spawnCoords = coordsToVector4(spawnData)

    if not entryCoords or not spawnCoords then return false end

    local interior = data.interior or data.Interior

    if interior == '' or interior == 'none' or not Config.GarageInteriors[interior] then
        interior = nil
    end

    local id = data.id or data.Id or propertyGarageId(name)

    propertyGarages[id] = {
        Label = data.label or data.Label or tostring(name),
        Type = normalizeGarageType(data.vehicleType or data.VehicleType or data.Type or data.type or 'car'),
        Position = vector3(entryCoords.x, entryCoords.y, entryCoords.z),
        SpawnPosition = spawnCoords,
        Interior = interior,
        Owner = data.owner or data.Owner,
        Keyholders = copyKeyholders(data.keyholders or data.Keyholders),
        Property = true,
        Visible = false
    }

    refreshPropertyGarage(id)

    return id
end

local function RemovePropertyGarage(name)
    local id = propertyGarageId(name)

    propertyGarages[id] = nil
    TriggerClientEvent('lunar_garage:client:removePropertyGarage', -1, id)

    return true
end

exports('RegisterPropertyGarage', RegisterPropertyGarage)
exports('RemovePropertyGarage', RemovePropertyGarage)
exports('RefreshPropertyGarage', refreshPropertyGarage)

function CanEnterLunarGarageInterior(source, index, vehicleType)
    local player = Framework.getPlayerFromId(source)
    if not player then return false end

    local garage = getGarage(index)
    if not garage or not garage.Interior then return false end
    if vehicleType and not spawnTypeMatchesGarage(vehicleType, garage) then return false end
    if not playerCanAccessGarage(player, garage) then return false end

    return isNearGarage(source, garage)
end

lib.callback.register('lunar_garage:getPropertyGarages', function(source)
    local player = Framework.getPlayerFromId(source)
    if not player then return {} end

    local garages = {}

    for id, garage in pairs(propertyGarages) do
        if playerCanAccessGarage(player, garage) then
            garages[id] = clientGarageData(garage)
        end
    end

    return garages
end)


local function giveVehicleKeys(source, vehicle)
    if not Config.UseKeySystem then return end
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if GetResourceState('qbx_vehiclekeys') == 'started' then
        exports.qbx_vehiclekeys:GiveKeys(source, vehicle, false)
        return
    end

    -- qb-vehiclekeys is client/event based in most installs, so leave it to client/cl_edit.lua.
end

local function invalidIndexMessage(kind, source, index)
    print(('[lunar_garage] Invalid %s index from source %s: %s'):format(kind, source or 'unknown', tostring(index)))
    TriggerClientEvent('lunar_garage:showNotification', source, ('Invalid %s location. Check your garage config/client args.'):format(kind), 'error')
end

local function garageStorageName(index, garage)
    if not garage then return end

    if garage.Property then
        return tostring(index)
    end

    return garage.Garage or garage.Name or garage.Label
end

local function setVehicleStored(plate, stored, garageName)
    stored = stored == true and 1 or tonumber(stored) or 0

    if Framework.name == 'qb-core' or Framework.name == 'qbx_core' then
        if garageName then
            return MySQL.update.await('UPDATE player_vehicles SET `stored` = ?, `state` = ?, `garage` = ? WHERE plate = ?', {
                stored,
                stored,
                garageName,
                plate
            })
        end

        return MySQL.update.await('UPDATE player_vehicles SET `stored` = ?, `state` = ? WHERE plate = ?', {
            stored,
            stored,
            plate
        })
    end

    return MySQL.update.await(Queries.setStoredVehicle, { stored, plate })
end


---@async
local function moveOutVehiclesIntoGarages()
    if Framework.name == 'qb-core' or Framework.name == 'qbx_core' then
        MySQL.update.await('UPDATE player_vehicles SET `stored` = 1, `state` = 1 WHERE `stored` = 0 OR `state` = 0')
        return
    end

    MySQL.update.await(Queries.setStoredVehicle:gsub('WHERE plate = ?', 'WHERE `stored` = 0'), { 1 })
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(100)

    if Config.AutoRespawn then
        moveOutVehiclesIntoGarages()
        activeVehicles = {} -- clear cache to prevent desync
    end
end)



lib.callback.register('lunar_garage:getOwnedVehicles', function(source, index, society)
    local player = Framework.getPlayerFromId(source)
    if not player then return end
    
    local garage = getGarage(index)
    if not garage then
        invalidIndexMessage('garage', source, index)
        return {}
    end

    if not playerCanAccessGarage(player, garage) or not isNearGarage(source, garage) then
        return {}
    end

    if garage.Property and society then
        return {}
    end

    if society then
        local vehicles = MySQL.query.await(Queries.getGarageSociety, {
            player:getJob()
        })

        for _, vehicle in ipairs(vehicles) do
            if vehicle.stored == 1 or vehicle.stored == true then
                vehicle.state = 'in_garage'
            elseif activeVehicles[vehicle.plate] then
                local entity = activeVehicles[vehicle.plate]
                if not DoesEntityExist(entity) then
                    activeVehicles[vehicle.plate] = nil
                    vehicle.state = 'in_impound'
                elseif GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                    DeleteEntity(entity)
                    activeVehicles[vehicle.plate] = nil
                    vehicle.state = 'in_impound'
                else
                    vehicle.state = 'out_garage'
                end
            else
                vehicle.state = 'in_impound'
            end
        end

        return vehicles
    else
        local vehicles = MySQL.query.await(Queries.getGarage, {
            player:getIdentifier()
        })

        for _, vehicle in ipairs(vehicles) do
            if vehicle.stored == 1 or vehicle.stored == true then
                vehicle.state = 'in_garage'
            elseif activeVehicles[vehicle.plate] then
                local entity = activeVehicles[vehicle.plate]
                if not DoesEntityExist(entity) then
                    activeVehicles[vehicle.plate] = nil
                    vehicle.state = 'in_impound'
                elseif not DoesEntityExist(entity) or GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                    DeleteEntity(entity)
                    activeVehicles[vehicle.plate] = nil
                    vehicle.state = 'in_impound'
                else
                    vehicle.state = 'out_garage'
                end
            else
                vehicle.state = 'in_impound'
            end
        end

        return vehicles
    end
end)


lib.callback.register('lunar_garage:getImpoundedVehicles', function(source, index, society)
    local player = Framework.getPlayerFromId(source)
    if not player then return end
    
    local impound = Config.Impounds[index]
    if not impound then
        invalidIndexMessage('impound', source, index)
        return {}
    end

    if not playerCanAccessGarage(player, impound) or not isNearGarage(source, impound) then
        return {}
    end

    if society then
        local vehicles = MySQL.query.await(Queries.getImpoundSociety, {
            player:getJob()
        })

        local filtered = {}

        for _, vehicle in ipairs(vehicles) do
            local entity = activeVehicles[vehicle.plate]

            if not entity then
                table.insert(filtered, vehicle)
            elseif not DoesEntityExist(entity) then
                activeVehicles[vehicle.plate] = nil
                table.insert(filtered, vehicle)
            elseif GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                DeleteEntity(entity)
                activeVehicles[vehicle.plate] = nil
                table.insert(filtered, vehicle)
            end
        end

        return filtered
    else
        local vehicles = MySQL.query.await(Queries.getImpound, {
            player:getIdentifier()
        })

        local filtered = {}

        for _, vehicle in ipairs(vehicles) do
            local entity = activeVehicles[vehicle.plate]

            if not entity then
                table.insert(filtered, vehicle)
            elseif not DoesEntityExist(entity) then
                activeVehicles[vehicle.plate] = nil
                table.insert(filtered, vehicle)
            elseif GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                DeleteEntity(entity)
                activeVehicles[vehicle.plate] = nil
                table.insert(filtered, vehicle)
            end
        end

        return filtered
    end
end)

lib.callback.register('lunar_garage:takeOutVehicle', function(source, index, plate, type, society)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local garage = getGarage(index)
    if not garage then
        invalidIndexMessage('garage', source, index)
        return
    end

    if not playerCanAccessGarage(player, garage) or not isNearGarage(source, garage) or not spawnTypeMatchesGarage(type, garage) then
        return
    end

    if garage.Property and society then
        return
    end

    local vehicle = MySQL.single.await(Queries.getStoredVehicle, {
        player:getIdentifier(), player:getJob(), plate, 1
    })

    if vehicle then
        if not vehicleMatchesOwnershipMode(vehicle, player, society) then
            return
        end

        local coords = garage.SpawnPosition
        local props = json.decode(vehicle.mods or vehicle.vehicle)
        local entity = Utils.createVehicle(props.model, coords, type)

        if entity == 0 then return end

        setVehicleStored(plate, 0)

        while NetworkGetEntityOwner(entity) == -1 do Wait(0) end

        local netId, owner = NetworkGetNetworkIdFromEntity(entity), NetworkGetEntityOwner(entity)
        
        TriggerClientEvent('lunar_garage:setVehicleProperties', owner, netId, props)

        activeVehicles[plate] = entity
        giveVehicleKeys(source, entity)

        return netId
    end
end)

lib.callback.register('lunar_garage:saveVehicle', function(source, props, netId, index, type)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local garage = getGarage(index)
    if not garage then
        invalidIndexMessage('garage', source, index)
        return false
    end

    if not playerCanAccessGarage(player, garage) or not isNearGarageParking(source, garage) or not spawnTypeMatchesGarage(type, garage) then
        return false
    end

    local vehicle = MySQL.single.await(Queries.getOwnedVehicle, {
        player:getIdentifier(), player:getJob(), props.plate
    })
    
    if vehicle then
        if garage.Property and vehicle.job and vehicle.job ~= '' then
            return false
        end

        local oldProps = json.decode(vehicle.mods or vehicle.vehicle)

        if props.model ~= oldProps.model then
            return false
        end

        setVehicleStored(props.plate, 1, garageStorageName(index, garage))
        MySQL.update.await(Queries.setVehicleProps, { json.encode(props), props.plate })

        SetTimeout(500, function()
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
        end)

        activeVehicles[props.plate] = nil;

        return true
    end
    
    return false
end)

lib.callback.register('lunar_garage:retrieveVehicle', function(source, index, plate, type, society)
    if activeVehicles[plate] then return end

    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local impound = Config.Impounds[index]
    if not impound then
        invalidIndexMessage('impound', source, index)
        return false
    end

    if not playerCanAccessGarage(player, impound) or not isNearGarage(source, impound) or not spawnTypeMatchesGarage(type, impound) then
        return false
    end

    local vehicle = MySQL.single.await(Queries.getOwnedVehicle, {
        player:getIdentifier(), player:getJob(), plate
    })

    if vehicle then
        if not vehicleMatchesOwnershipMode(vehicle, player, society) then
            return false
        end

        if player:getAccountMoney('money') < Config.ImpoundPrice then return false end

        player:removeAccountMoney('money', Config.ImpoundPrice)

        local coords = impound.SpawnPosition
        local props = json.decode(vehicle.mods or vehicle.vehicle)
        local entity = Utils.createVehicle(props.model, coords, type)

        if entity == 0 then return end

        setVehicleStored(plate, 0)

        while NetworkGetEntityOwner(entity) == -1 do Wait(0) end

        local netId, owner = NetworkGetNetworkIdFromEntity(entity), NetworkGetEntityOwner(entity)
        
        TriggerClientEvent('lunar_garage:setVehicleProperties', owner, netId, props)

        activeVehicles[props.plate] = entity
        giveVehicleKeys(source, entity)

        return true, netId
    end

    return false
end)

lib.callback.register('lunar_garage:getVehicleCoords', function(source, plate)
    local entity = activeVehicles[plate]

    if not entity then return end

    return GetEntityCoords(entity)
end)
