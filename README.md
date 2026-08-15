# lunar_garage - Qbox Integration Build

This copy of `lunar_garage` has been adjusted to work with Qbox/QBX resources, `qbx_properties`, and the included `qr-vehicleshop` build.

## What Was Changed

- Added Qbox/QBX compatibility paths for `player_vehicles`.
- Added support for `state`, `stored`, `type`, `job`, and `garage` vehicle columns.
- Synced `stored` and `state` whenever vehicles are taken out, parked, retrieved from impound, or auto-returned on restart.
- Added vehicle type normalization so QB/Qbox values such as `automobile`, `bike`, `boat`, `plane`, and `heli` map correctly to Lunar garage types.
- Fixed air and boat garage filtering so those vehicles do not get mixed into car garages.
- Added dynamic property garage registration exports for `qbx_properties`.
- Added property garage access validation for owners and keyholders.
- Added property garage interior support.
- Split property garage behavior into two points:
  - Entry point: open the garage menu or enter the garage interior on foot.
  - Spawn/parking point: spawn vehicles and park vehicles.
- Added configurable property interaction distances:
  - `Config.PropertyGarageDistance`
  - `Config.PropertyGarageParkingDistance`
- Added `Config.AutoRespawn` support for Qbox `state` and `stored`.
- Hardened the vehicle contract registration so it waits for `Config.Contract` and `Framework` before registering the item.

## Exports Used By qbx_properties

`qbx_properties` uses these exports when `lunar_garage` is started:

```lua
exports.lunar_garage:RegisterPropertyGarage(name, data)
exports.lunar_garage:RemovePropertyGarage(name)
exports.lunar_garage:RefreshPropertyGarage(name)
```

The dynamic property garage data supports this shape:

```lua
{
    id = 'property_example',
    label = 'Example Property',
    vehicleType = 'car',
    entryCoords = vec4(0.0, 0.0, 0.0, 0.0),
    spawnCoords = vec4(0.0, 0.0, 0.0, 0.0),
    interior = 'large',
    owner = 'citizenid',
    keyholders = {}
}
```

Old single-coordinate property garages are still normalized for backwards compatibility.

## Database

For Qbox, `player_vehicles` needs these compatibility columns:

- `job`
- `type`
- `stored`
- `state`

Use one of these SQL files:

- `sql/qbox_lunar_garage.sql` for Lunar garage compatibility only.
- `../Qr_vehicleshop/qr-vehicleshop/qbox_lunar_vehicle_columns.sql` if you are also using the included QR vehicle shop. That file is a superset and includes finance columns too.

If old rows have mismatched `stored` and `state` values, run:

```sql
sql/repair_qbox_vehicle_storage_state.sql
```

That repair returns out vehicles to a garaged state, matching `Config.AutoRespawn = true`.

## Important Config

```lua
Config.AutoRespawn = true
Config.PropertyGarageDistance = 3.0
Config.PropertyGarageParkingDistance = 3.0
```

For the included vehicle shop defaults, make sure these Lunar garage names exist:

- `pillboxgarage`
- `lsymcboathouse`
- `airporthangar`

## Start Order

Recommended order:

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure lunar_garage
ensure qbx_properties
ensure qr-vehicleshop
```

If you use bob74_ipl interiors through `qbx_properties`, start `bob74_ipl` before `qbx_properties`.
