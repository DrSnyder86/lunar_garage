-- Lunar Garage Qbox compatibility columns
-- Run this only if your player_vehicles table does not already have these columns.

ALTER TABLE `player_vehicles`
    ADD COLUMN IF NOT EXISTS `job` VARCHAR(50) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `type` VARCHAR(20) NOT NULL DEFAULT 'car',
    ADD COLUMN IF NOT EXISTS `stored` TINYINT(1) NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS `state` INT(11) NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS `idx_player_vehicles_citizenid_type_stored`
    ON `player_vehicles` (`citizenid`, `type`, `stored`);

CREATE INDEX IF NOT EXISTS `idx_player_vehicles_job_type_stored`
    ON `player_vehicles` (`job`, `type`, `stored`);

CREATE INDEX IF NOT EXISTS `idx_player_vehicles_plate`
    ON `player_vehicles` (`plate`);
