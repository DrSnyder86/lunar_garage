RegisterNetEvent('lunar_garage:server:giveVehicleKeys', function(netId)
    local source = source

    if not Config.UseKeySystem then return end
    if GetResourceState('qbx_vehiclekeys') ~= 'started' then return end
    if not netId then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    exports.qbx_vehiclekeys:GiveKeys(source, vehicle, false)
end)
