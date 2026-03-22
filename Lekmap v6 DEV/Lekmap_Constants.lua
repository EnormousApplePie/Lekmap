------------------------------------------------------------------------------
--  FILE:     Lekmap_Constants.lua
--  AUTHOR:   EnormousApplePie
--  PURPOSE:  Named constants used across all Lekmap modules.
--            All constants live under the Lekmap_Constants module table so
--            that consumer modules can alias them locally inside functions
--            (avoiding nil-at-load-time issues with bare globals).
------------------------------------------------------------------------------
--luacheck: globals Lekmap_Constants

Lekmap_Constants = {}

------------------------------------------------------------------------------
-- IMPACT LAYERS
-- Used by the resource impact/ripple system to prevent clustering.
-- Each layer tracks placement data independently.
-- Marble uses LUXURY, sea oil uses STRATEGIC -- unique spacing is
-- handled via per-resource properties, not dedicated layers.
-- PLAYER_SPAWN reserves space around starting locations.
------------------------------------------------------------------------------
Lekmap_Constants.IMPACT_LAYER = {
    STRATEGIC       = 1,
    LUXURY          = 2,
    BONUS           = 3,
    CITY_STATE      = 4,
    NATURAL_WONDER  = 5,
    PLAYER_SPAWN    = 6,
}

------------------------------------------------------------------------------
-- RESOURCE DENSITY LEVELS
-- Maps to the user-facing "Resources" dropdown (options 1-10).
------------------------------------------------------------------------------
Lekmap_Constants.DENSITY = {
    NEAR_NOTHING = 1,
    SPARSE       = 2,
    MEDIOCRE     = 3,
    BELOW_NORMAL = 4,
    NORMAL       = 5,
    ABOVE_NORMAL = 6,
    PLENTY       = 7,
    ABUNDANT     = 8,
    RICH         = 9,
    MAXIMUM      = 10,
}

------------------------------------------------------------------------------
-- REGION TYPES
-- Classification of map regions by dominant terrain.
-- Used for luxury assignment, start bias, and terrain measurement.
-- Must match the region classification logic in Lekmap_Regions.
------------------------------------------------------------------------------
Lekmap_Constants.REGION_TYPE = {
    TUNDRA   = 1,
    JUNGLE   = 2,
    FOREST   = 3,
    DESERT   = 4,
    HILLS    = 5,
    PLAINS   = 6,
    GRASS    = 7,
    HYBRID   = 8,
    WETLANDS = 9,
}

------------------------------------------------------------------------------
-- DIRECTION LIST
-- All six hex directions in a table for iteration.
-- Values are engine constants (0-5) that never change; defined here as
-- literals because DirectionTypes is not available at file-load time.
------------------------------------------------------------------------------
Lekmap_Constants.DIRECTION_LIST = {
    0,  -- DIRECTION_NORTHEAST
    1,  -- DIRECTION_EAST
    2,  -- DIRECTION_SOUTHEAST
    3,  -- DIRECTION_SOUTHWEST
    4,  -- DIRECTION_WEST
    5,  -- DIRECTION_NORTHWEST
}
