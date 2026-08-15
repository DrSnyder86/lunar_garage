local ROUTING_BUCKET_OFFSET <const> = 1000
local inside = {}

lib.callback.register('lunar_garage:enterInterior', function(source, index, type)
    if not type then
        type = index
        index = nil
    end

    local player = Framework.getPlayerFromId(source)
    
    if not player then return false end
    if index and (not CanEnterLunarGarageInterior or not CanEnterLunarGarageInterior(source, index, type)) then return false end

    local bucketId = ROUTING_BUCKET_OFFSET + source
    inside[source] = true

    SetPlayerRoutingBucket(source, bucketId)
    SetRoutingBucketPopulationEnabled(bucketId, false)

    local vehicles = MySQL.query.await(Queries.getStoredGarage, { player:getIdentifier() })
    return vehicles
end)

RegisterNetEvent('lunar_garage:exitInterior', function()
    local source = source

    if inside[source] then
        SetPlayerRoutingBucket(source, 0)
        inside[source] = false
    end
end)
