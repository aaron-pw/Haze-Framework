-- Create the players table
CREATE TABLE IF NOT EXISTS `players` (
  `identifier` VARCHAR(100) NOT NULL,
  `license` VARCHAR(50) DEFAULT NULL,
  `steam` VARCHAR(20) DEFAULT NULL,
  `discord` VARCHAR(30) DEFAULT NULL,
  `xbox` VARCHAR(25) DEFAULT NULL,
  `ip` VARCHAR(45) DEFAULT NULL,
  `name` VARCHAR(50) DEFAULT NULL,
  `first_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `permission_level` INT NOT NULL DEFAULT 0,
  `is_banned` TINYINT(1) NOT NULL DEFAULT 0,
  `ban_reason` TEXT DEFAULT NULL,
  `ban_expires` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`identifier`),
  UNIQUE KEY `license_UNIQUE` (`license`),
  UNIQUE KEY `steam_UNIQUE` (`steam`),
  UNIQUE KEY `discord_UNIQUE` (`discord`),
  UNIQUE KEY `xbox_UNIQUE` (`xbox`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create the characters table
CREATE TABLE IF NOT EXISTS `characters` (
  `charid` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(100) NOT NULL,
  `slot` TINYINT NOT NULL,
  `firstname` VARCHAR(50) NOT NULL DEFAULT 'John',
  `lastname` VARCHAR(50) NOT NULL DEFAULT 'Doe',
  `dateofbirth` DATE DEFAULT NULL,
  `gender` TINYINT NOT NULL DEFAULT 0,
  `nationality` VARCHAR(50) DEFAULT 'Unknown',
  `phone_number` VARCHAR(20) DEFAULT NULL,
  `cash` BIGINT NOT NULL DEFAULT 1000,
  `bank` BIGINT NOT NULL DEFAULT 5000,
  `job` VARCHAR(50) NOT NULL DEFAULT 'unemployed',
  `job_grade` INT NOT NULL DEFAULT 0,
  `position` VARCHAR(255) DEFAULT '{"x": 0.0, "y": 0.0, "z": 0.0, "heading": 0.0}',
  `health` INT NOT NULL DEFAULT 200,
  `armour` INT NOT NULL DEFAULT 0,
  `status` TEXT DEFAULT '{"hunger":100,"thirst":100}',
  `skin` LONGTEXT DEFAULT NULL,
  `inventory` LONGTEXT DEFAULT NULL,
  `is_dead` TINYINT(1) NOT NULL DEFAULT 0,
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`charid`),
  UNIQUE KEY `identifier_slot_UNIQUE` (`identifier`, `slot`), -- Ensure only one char per slot per player
  UNIQUE KEY `phone_number_UNIQUE` (`phone_number`),
  KEY `FK_characters_players` (`identifier`), -- Index for faster joins/lookups
  CONSTRAINT `FK_characters_players` FOREIGN KEY (`identifier`) REFERENCES `players` (`identifier`) ON DELETE CASCADE ON UPDATE CASCADE -- Link to players table
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;