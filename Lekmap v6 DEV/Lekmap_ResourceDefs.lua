------------------------------------------------------------------------------
--  FILE:     Lekmap_ResourceDefs.lua
--  AUTHOR:   EnormousApplePie
--  PURPOSE:  Centralized, pre-defined resource data for Lekmap.
--            Every known resource is statically defined here with its
--            placement rules (class, valid terrains, features, hills/flatlands).
--            At runtime, Initialize() cross-references these definitions
--            against GameInfo.Resources() to build the active resource set.
--            Resources not present in the game are automatically disabled.
------------------------------------------------------------------------------
--  Requires: Lekmap_Constants.lua (for IMPACT_LAYER, DENSITY, REGION_TYPE)
------------------------------------------------------------------------------
--luacheck: globals Lekmap_ResourceDefs
--luacheck: globals GameInfo Lekmap_Constants
--luacheck: ignore table

Lekmap_ResourceDefs = {}

------------------------------------------------------------------------------
-- RESOURCE CLASSES
-- Class-level properties shared by all resources of a given type.
-- Impact layer and default spacing live here, not on individual resources.
--
-- NOTE: Numeric literals are used for impact_layer values instead of
-- Lekmap_Constants.IMPACT_LAYER because this table is defined at module load
-- time, before Lekmap_Constants is guaranteed to be initialized.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.RESOURCE_CLASSES = {
    strategic = {
        impact_layer    = 1,  -- IMPACT_LAYER.STRATEGIC
        default_spacing = { min = 1, max = 3 },
    },
    luxury = {
        impact_layer    = 2,  -- IMPACT_LAYER.LUXURY
        default_spacing = { min = 3, max = 5 },
    },
    bonus = {
        impact_layer    = 3,  -- IMPACT_LAYER.BONUS
        default_spacing = { min = 1, max = 2 },
    },
}

------------------------------------------------------------------------------
-- RESOURCE DEFINITIONS
-- Every resource the script knows about, with its placement data.
-- Keys match the auto-stripped RESOURCE_ prefix (e.g. "IRON" from
-- RESOURCE_IRON). Data sourced from CIV5Units.xml and NewLuxuries XML.
--
-- Fields:
--   class               "strategic" | "luxury" | "bonus"
--   terrains            valid bare terrain types (no feature required)
--   features            valid feature types (resource can appear on these)
--   feature_terrains    terrain types valid UNDER a feature (optional)
--   hills               can appear on PLOT_HILLS
--   flatlands           can appear on PLOT_LAND
--   force_valid_feature (optional) list of features that can be forced onto a
--                       bare feature_terrains plot AFTER placement.  When set,
--                       the plot is accepted even without a feature if its
--                       terrain matches feature_terrains.  The system then
--                       picks the best feature based on adjacent tiles and
--                       region type.  Only forest / jungle should be listed.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.RESOURCE_DEFS = {

    -- ==========================================================================
    -- STRATEGIC RESOURCES
    -- ==========================================================================
    IRON = {
        class            = "strategic",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_SNOW" },
        features         = {},
        hills            = true,
        flatlands        = true,
    },
    HORSE = {
        class            = "strategic",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_TUNDRA" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    COAL = {
        class            = "strategic",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_TUNDRA", "TERRAIN_HILL" },
        features         = { "FEATURE_FOREST", "FEATURE_JUNGLE" },
        feature_terrains = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_TUNDRA" },
        hills            = true,
        flatlands        = true,
    },
    OIL = {
        class            = "strategic",
        terrains         = { "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_SNOW", "TERRAIN_COAST" },
        features         = { "FEATURE_JUNGLE", "FEATURE_MARSH" },
        feature_terrains = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        hills            = false,
        flatlands        = true,
    },
    ALUMINUM = {
        class            = "strategic",
        terrains         = { "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_GRASS", "TERRAIN_HILL" },
        features         = { "FEATURE_FOREST", "FEATURE_JUNGLE" },
        hills            = true,
        flatlands        = false,
    },
    URANIUM = {
        class            = "strategic",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_SNOW" },
        features         = { "FEATURE_JUNGLE", "FEATURE_FOREST", "FEATURE_MARSH" },
        feature_terrains = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_SNOW" },
        hills            = false,
        flatlands        = true,
    },

    -- ==========================================================================
    -- BONUS RESOURCES
    -- ==========================================================================
    WHEAT = {
        class            = "bonus",
        terrains         = { "TERRAIN_PLAINS" },
        features         = { "FEATURE_FLOOD_PLAINS" },
        feature_terrains = { "TERRAIN_DESERT" },
        hills            = false,
        flatlands        = true,
    },
    COW = {
        class            = "bonus",
        terrains         = { "TERRAIN_GRASS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    SHEEP = {
        class            = "bonus",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_HILL" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    DEER = {
        class            = "bonus",
        terrains         = { "TERRAIN_TUNDRA" },
        features         = { "FEATURE_FOREST" },
        feature_terrains = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_TUNDRA", "TERRAIN_SNOW" },
        hills            = true,
        flatlands        = true,
    },
    BANANA = {
        class            = "bonus",
        terrains         = {},
        features         = { "FEATURE_JUNGLE" },
        feature_terrains = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        hills            = false,
        flatlands        = true,
    },
    FISH = {
        class            = "bonus",
        terrains         = { "TERRAIN_COAST" },
        features         = {},
        hills            = false,
        flatlands        = false,
    },
    STONE = {
        class            = "bonus",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_SNOW" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    BISON = {
        class            = "bonus",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    -- ==========================================================================
    -- BONUS RESOURCES  -  Lekmod
    -- ==========================================================================
    HARDWOOD = {
        class            = "bonus",
        terrains         = {},
        features         = { "FEATURE_JUNGLE", "FEATURE_FOREST" },
        feature_terrains = { "TERRAIN_PLAINS", "TERRAIN_GRASS", "TERRAIN_TUNDRA" },
        hills            = false,
        flatlands        = true,
    },
    MAIZE = {
        class            = "bonus",
        terrains         = { "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    -- ==========================================================================
    -- LUXURY RESOURCES  -  Vanilla
    -- ==========================================================================
    WHALE = {
        class            = "luxury",
        terrains         = { "TERRAIN_COAST" },
        features         = {},
        hills            = false,
        flatlands        = false,
    },
    PEARLS = {
        class            = "luxury",
        terrains         = { "TERRAIN_COAST" },
        features         = {},
        hills            = false,
        flatlands        = false,
    },
    GOLD = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_HILL" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    SILVER = {
        class            = "luxury",
        terrains         = { "TERRAIN_TUNDRA", "TERRAIN_DESERT", "TERRAIN_HILL" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    GEMS = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_HILL" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    MARBLE = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    IVORY = {
        class            = "luxury",
        terrains         = { "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    FUR = {
        class               = "luxury",
        terrains            = {},
        features            = { "FEATURE_FOREST" },
        feature_terrains    = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_TUNDRA", "TERRAIN_SNOW" },
        force_valid_feature = { "FEATURE_FOREST" },
        hills               = false,
        flatlands           = true,
    },
    DYE = {
        class               = "luxury",
        terrains            = {},
        features            = { "FEATURE_JUNGLE", "FEATURE_FOREST" },
        feature_terrains    = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_TUNDRA" },
        force_valid_feature = { "FEATURE_FOREST", "FEATURE_JUNGLE" },
        hills               = true,
        flatlands           = true,
    },
    SILK = {
        class               = "luxury",
        terrains            = {},
        features            = { "FEATURE_FOREST" },
        feature_terrains    = { "TERRAIN_PLAINS", "TERRAIN_GRASS" },
        force_valid_feature = { "FEATURE_FOREST" },
        hills               = true,
        flatlands           = true,
    },
    SPICES = {
        class               = "luxury",
        terrains            = {},
        features            = { "FEATURE_JUNGLE", "FEATURE_FOREST" },
        feature_terrains    = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        force_valid_feature = { "FEATURE_FOREST", "FEATURE_JUNGLE" },
        hills               = true,
        flatlands           = true,
    },
    SUGAR = {
        class               = "luxury",
        terrains            = {},
        features            = { "FEATURE_FOREST", "FEATURE_MARSH" },
        feature_terrains    = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT" },
        force_valid_feature = { "FEATURE_FOREST" },
        hills               = true,
        flatlands           = true,
    },
    COTTON = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    WINE = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    INCENSE = {
        class            = "luxury",
        terrains         = { "TERRAIN_PLAINS", "TERRAIN_DESERT" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },

    -- ==========================================================================
    -- LUXURY RESOURCES  -  Expansion
    -- ==========================================================================
    COPPER = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_SNOW", "TERRAIN_HILL" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    SALT = {
        class            = "luxury",
        terrains         = { "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    CRAB = {
        class            = "luxury",
        terrains         = { "TERRAIN_COAST" },
        features         = {},
        hills            = false,
        flatlands        = false,
    },
    TRUFFLES = {
        class               = "luxury",
        terrains            = {},
        features            = { "FEATURE_FOREST", "FEATURE_MARSH", "FEATURE_JUNGLE" },
        feature_terrains    = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        force_valid_feature = { "FEATURE_FOREST", "FEATURE_JUNGLE" },
        hills               = false,
        flatlands           = true,
    },
    CITRUS = {
        class               = "luxury",
        terrains            = {},
        features            = { "FEATURE_FOREST", "FEATURE_JUNGLE" },
        feature_terrains    = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        force_valid_feature = { "FEATURE_FOREST", "FEATURE_JUNGLE" },
        hills               = false,
        flatlands           = true,
    },
    COCOA = {
        class               = "luxury",
        terrains            = {},
        features            = { "FEATURE_JUNGLE", "FEATURE_FOREST" },
        feature_terrains    = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        force_valid_feature = { "FEATURE_JUNGLE", "FEATURE_FOREST" },
        hills               = false,
        flatlands           = true,
    },

    -- ==========================================================================
    -- LUXURY RESOURCES  -  Lekmod
    -- ==========================================================================
    COFFEE = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    TEA = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    TOBACCO = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    AMBER = {
        class            = "luxury",
        terrains         = { "TERRAIN_TUNDRA", "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_HILL" },
        features         = {},
        hills            = true,
        flatlands        = true,
    },
    JADE = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_HILL" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    OLIVE = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    PERFUME = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    CORAL = {
        class            = "luxury",
        terrains         = { "TERRAIN_COAST" },
        features         = {},
        hills            = false,
        flatlands        = false,
    },
    LAPIS = {
        class            = "luxury",
        terrains         = { "TERRAIN_GRASS", "TERRAIN_PLAINS", "TERRAIN_DESERT", "TERRAIN_TUNDRA", "TERRAIN_HILL" },
        features         = {},
        hills            = true,
        flatlands        = false,
    },
    OBSIDIAN = {
        class            = "luxury",
        terrains         = { "TERRAIN_PLAINS", "TERRAIN_TUNDRA" },
        features         = {},
        hills            = false,
        flatlands        = true,
    },
    COCONUT = {
        class            = "luxury",
        terrains         = {},
        features         = { "FEATURE_JUNGLE", "FEATURE_FOREST" },
        feature_terrains = { "TERRAIN_PLAINS", "TERRAIN_GRASS" },
        hills            = false,
        flatlands        = true,
    },
    RUBBER = {
        class            = "luxury",
        terrains         = {},
        features         = { "FEATURE_JUNGLE", "FEATURE_FOREST" },
        feature_terrains = { "TERRAIN_PLAINS", "TERRAIN_GRASS" },
        hills            = false,
        flatlands        = true,
    },
}

------------------------------------------------------------------------------
-- RUNTIME CROSS-REFERENCE
-- Scans GameInfo.Resources() and matches against RESOURCE_DEFS.
-- Produces the active resource set: only resources present in the game
-- database AND defined above are enabled.
--
-- Usage:
--   local active = Lekmap_ResourceDefs.Initialize()
--   active.IRON.id         -- the game's numeric resource ID
--   active.IRON.def        -- reference to RESOURCE_DEFS.IRON
--   active.IRON.classInfo  -- reference to RESOURCE_CLASSES.strategic
------------------------------------------------------------------------------
function Lekmap_ResourceDefs.Initialize()
    local active = {}
    for resource_data in GameInfo.Resources() do
        local short_key = resource_data.Type:sub(10) -- strips "RESOURCE_"
        local resource_def = Lekmap_ResourceDefs.RESOURCE_DEFS[short_key]
        if resource_def and not Lekmap_ResourceDefs.IsExcludedResource(resource_data.Type) then
            active[short_key] = {
                id        = resource_data.ID,
                key       = short_key,
                def       = resource_def,
                classInfo = Lekmap_ResourceDefs.RESOURCE_CLASSES[resource_def.class],
            }
        end
    end
    Lekmap_ResourceDefs.active = active
    return active
end

--- Returns the numeric ID for a resource key, or nil if not active.
function Lekmap_ResourceDefs.GetID(key)
    local entry = Lekmap_ResourceDefs.active and Lekmap_ResourceDefs.active[key]
    if entry then return entry.id end
    return nil
end

--- Returns the short key for a resource engine ID, or nil if not active.
function Lekmap_ResourceDefs.GetKey(resource_id)
    if not Lekmap_ResourceDefs.active then return nil end
    for key, entry in pairs(Lekmap_ResourceDefs.active) do
        if entry.id == resource_id then return key end
    end
    return nil
end

--- Returns true if a resource key is active (present in the game).
function Lekmap_ResourceDefs.IsActive(key)
    return Lekmap_ResourceDefs.active ~= nil
       and Lekmap_ResourceDefs.active[key] ~= nil
end

------------------------------------------------------------------------------
-- EXCLUDED RESOURCES
-- Resources that should never be placed by the map script.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.EXCLUDED_RESOURCES = {
    "RESOURCE_ARTIFACTS",
    "RESOURCE_HIDDEN_ARTIFACTS",
    "RESOURCE_SLAVES",
}

function Lekmap_ResourceDefs.IsExcludedResource(resource_type)
    for _, excluded in ipairs(Lekmap_ResourceDefs.EXCLUDED_RESOURCES) do
        if excluded == resource_type then
            return true
        end
    end
    return false
end

------------------------------------------------------------------------------
-- DENSITY MULTIPLIERS
-- Controls how frequently bonus resources appear based on the user's
-- resource density setting. Higher multiplier = fewer resources.
--
-- NOTE: Numeric key literals are used instead of Lekmap_Constants.DENSITY
-- because this table is defined at module load time, before Lekmap_Constants
-- is guaranteed to be initialized.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.DENSITY_MULTIPLIERS = {
    [1]  = 1.00,  -- DENSITY.NEAR_NOTHING
    [2]  = 0.90,  -- DENSITY.SPARSE
    [3]  = 0.80,  -- DENSITY.MEDIOCRE
    [4]  = 0.75,  -- DENSITY.BELOW_NORMAL
    [5]  = 0.65,  -- DENSITY.NORMAL
    [6]  = 0.55,  -- DENSITY.ABOVE_NORMAL
    [7]  = 0.45,  -- DENSITY.PLENTY
    [8]  = 0.35,  -- DENSITY.ABUNDANT
    [9]  = 0.25,  -- DENSITY.RICH
    [10] = 0.15,  -- DENSITY.MAXIMUM
}

------------------------------------------------------------------------------
-- STRATEGIC RESOURCE AMOUNTS
-- Quantity per tile for major and small deposits, keyed by density level.
--
-- NOTE: Numeric key literals are used instead of Lekmap_Constants.DENSITY
-- because these tables are defined at module load time, before
-- Lekmap_Constants is guaranteed to be initialized.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.STRATEGIC_AMOUNTS_MAJOR = {
    default = { URANIUM = 2, HORSE = 4, OIL = 7, IRON = 6, COAL = 7, ALUMINUM = 8 },
    [1]  = { URANIUM = 2, HORSE = 2, OIL = 5, IRON = 4, COAL = 5, ALUMINUM = 6 },  -- NEAR_NOTHING
    [2]  = { URANIUM = 2, HORSE = 2, OIL = 5, IRON = 4, COAL = 5, ALUMINUM = 6 },  -- SPARSE
    [3]  = { URANIUM = 2, HORSE = 3, OIL = 6, IRON = 5, COAL = 6, ALUMINUM = 7 },  -- MEDIOCRE
    [7]  = { URANIUM = 2, HORSE = 5, OIL = 8, IRON = 7, COAL = 8, ALUMINUM = 9 },  -- PLENTY
    [8]  = { URANIUM = 2, HORSE = 6, OIL = 9, IRON = 8, COAL = 9, ALUMINUM = 10 }, -- ABUNDANT
    [9]  = { URANIUM = 2, HORSE = 6, OIL = 9, IRON = 8, COAL = 9, ALUMINUM = 10 }, -- RICH
    [10] = { URANIUM = 2, HORSE = 6, OIL = 9, IRON = 8, COAL = 9, ALUMINUM = 10 }, -- MAXIMUM
}

Lekmap_ResourceDefs.STRATEGIC_AMOUNTS_SMALL = {
    default = { URANIUM = 2, HORSE = 2, OIL = 4, IRON = 2, COAL = 3, ALUMINUM = 3 },
    [1]  = { URANIUM = 1, HORSE = 1, OIL = 2, IRON = 1, COAL = 2, ALUMINUM = 2 },  -- NEAR_NOTHING
    [2]  = { URANIUM = 1, HORSE = 1, OIL = 2, IRON = 1, COAL = 2, ALUMINUM = 2 },  -- SPARSE
    [3]  = { URANIUM = 1, HORSE = 1, OIL = 2, IRON = 1, COAL = 2, ALUMINUM = 2 },  -- MEDIOCRE
    [7]  = { URANIUM = 2, HORSE = 3, OIL = 3, IRON = 3, COAL = 3, ALUMINUM = 3 },  -- PLENTY
    [8]  = { URANIUM = 2, HORSE = 3, OIL = 3, IRON = 3, COAL = 3, ALUMINUM = 3 },  -- ABUNDANT
    [9]  = { URANIUM = 2, HORSE = 3, OIL = 3, IRON = 3, COAL = 3, ALUMINUM = 3 },  -- RICH
    [10] = { URANIUM = 2, HORSE = 3, OIL = 3, IRON = 3, COAL = 3, ALUMINUM = 3 },  -- MAXIMUM
}

function Lekmap_ResourceDefs.GetMajorStrategicAmounts(density)
    return Lekmap_ResourceDefs.STRATEGIC_AMOUNTS_MAJOR[density]
        or Lekmap_ResourceDefs.STRATEGIC_AMOUNTS_MAJOR.default
end

function Lekmap_ResourceDefs.GetSmallStrategicAmounts(density)
    return Lekmap_ResourceDefs.STRATEGIC_AMOUNTS_SMALL[density]
        or Lekmap_ResourceDefs.STRATEGIC_AMOUNTS_SMALL.default
end

------------------------------------------------------------------------------
-- STRATEGIC PLACEMENT RULES
-- Each entry describes one ProcessResourceList call for strategic resources.
--
-- NOTE: Numeric literals are used for impact_layer instead of
-- Lekmap_Constants.IMPACT_LAYER because this table is defined at module load
-- time, before Lekmap_Constants is guaranteed to be initialized.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.STRATEGIC_PLACEMENT_RULES = {
    {
        terrain_list = "marsh_list",
        frequency    = 7,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "OIL",     amount_key = "major", weight = 65, radius_min = 1, radius_max = 4 },
            { resource = "URANIUM", amount_key = "major", weight = 35, radius_min = 1, radius_max = 4 },
        },
    },
    {
        terrain_list = "tundra_flat_no_feature",
        frequency    = 16,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "OIL",      amount_key = "major", weight = 55, radius_min = 1, radius_max = 5 },
            { resource = "ALUMINUM", amount_key = "major", weight = 15, radius_min = 1, radius_max = 2 },
            { resource = "IRON",     amount_key = "major", weight = 35, radius_min = 1, radius_max = 2 },
        },
    },
    {
        terrain_list = "snow_flat_list",
        frequency    = 15,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "OIL",      amount_key = "major", weight = 65, radius_min = 1, radius_max = 5 },
            { resource = "ALUMINUM", amount_key = "major", weight = 15, radius_min = 1, radius_max = 2 },
            { resource = "IRON",     amount_key = "major", weight = 20, radius_min = 1, radius_max = 2 },
        },
    },
    {
        terrain_list = "desert_flat_no_feature",
        frequency    = 11,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "OIL",  amount_key = "major", weight = 70, radius_min = 1, radius_max = 2 },
            { resource = "IRON", amount_key = "major", weight = 30, radius_min = 1, radius_max = 2 },
        },
    },
    {
        terrain_list = "hills_list",
        frequency    = 22,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "IRON",     amount_key = "major", weight = 26, radius_min = 1, radius_max = 3 },
            { resource = "COAL",     amount_key = "major", weight = 35, radius_min = 1, radius_max = 3 },
            { resource = "ALUMINUM", amount_key = "major", weight = 39, radius_min = 1, radius_max = 3 },
        },
    },
    {
        terrain_list = "jungle_flat_list",
        frequency    = 33,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "COAL",    amount_key = "major", weight = 30, radius_min = 1, radius_max = 2 },
            { resource = "URANIUM", amount_key = "major", weight = 70, radius_min = 1, radius_max = 2 },
        },
    },
    {
        terrain_list = "forest_flat_list",
        frequency    = 39,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "COAL",    amount_key = "major", weight = 25, radius_min = 1, radius_max = 2 },
            { resource = "OIL",     amount_key = "major", weight = 25, radius_min = 1, radius_max = 5 },
            { resource = "URANIUM", amount_key = "major", weight = 50, radius_min = 10, radius_max = 0 },
        },
    },
    {
        terrain_list = "dry_grass_flat_no_feature",
        frequency    = 10,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "HORSE", amount_key = "major", weight = 100, radius_min = 1, radius_max = 5 },
        },
    },
    {
        terrain_list = "plains_flat_no_feature",
        frequency    = 10,
        impact_layer = 1,  -- IMPACT_LAYER.STRATEGIC
        resources    = {
            { resource = "HORSE", amount_key = "major", weight = 100, radius_min = 1, radius_max = 5 },
        },
    },
}

------------------------------------------------------------------------------
-- MINIMUM STRATEGIC GUARANTEES
------------------------------------------------------------------------------
Lekmap_ResourceDefs.MINIMUM_STRATEGIC_GUARANTEES = {
    { resource = "IRON",     min_absolute = 8,   min_per_civ = 4, fallback_lists = { "hills_list", "land_list" } },
    { resource = "HORSE",    min_absolute = nil,  min_per_civ = 4, fallback_lists = { "plains_flat_no_feature", "dry_grass_flat_no_feature" } },
    { resource = "COAL",     min_absolute = 8,   min_per_civ = 4, fallback_lists = { "hills_list", "land_list" } },
    { resource = "OIL",      min_absolute = nil,  min_per_civ = 4, fallback_lists = { "land_list" } },
    { resource = "ALUMINUM", min_absolute = nil,  min_per_civ = 4, fallback_lists = { "hills_list" } },
    { resource = "URANIUM",  min_absolute = nil,  min_per_civ = 5, fallback_lists = { "land_list" }, use_while_loop = true },
}

------------------------------------------------------------------------------
-- BONUS PLACEMENT RULES
-- Resources not present in the game are automatically skipped at runtime.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.BONUS_PLACEMENT_RULES = {
    { terrain_list = "extra_deer_list",                frequency = 6,  resources = { { resource = "DEER",     quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "desert_wheat_list",              frequency = 6,  resources = { { resource = "WHEAT",    quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "tundra_flat_no_feature",         frequency = 8,  resources = { { resource = "DEER",     quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "banana_list",                    frequency = 10, resources = { { resource = "BANANA",   quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "plains_flat_no_feature",         frequency = 30, resources = { { resource = "WHEAT",    quantity = 1, weight = 100, radius_min = 1, radius_max = 3 } } },
    { terrain_list = "plains_flat_no_feature",         frequency = 15, resources = { { resource = "BISON",    quantity = 1, weight = 100, radius_min = 2, radius_max = 3 } } },
    { terrain_list = "plains_flat_no_feature",         frequency = 22, resources = { { resource = "COW",      quantity = 1, weight = 100, radius_min = 2, radius_max = 3 } } },
    { terrain_list = "grass_flat_no_feature",          frequency = 22, resources = { { resource = "COW",      quantity = 1, weight = 100, radius_min = 2, radius_max = 3 } } },
    { terrain_list = "dry_grass_flat_no_feature",      frequency = 20, resources = { { resource = "STONE",    quantity = 1, weight = 100, radius_min = 1, radius_max = 1 } } },
    { terrain_list = "dry_grass_flat_no_feature",      frequency = 20, resources = { { resource = "BISON",    quantity = 1, weight = 100, radius_min = 1, radius_max = 1 } } },
    { terrain_list = "hills_open_list",                frequency = 20, resources = { { resource = "SHEEP",    quantity = 1, weight = 100, radius_min = 1, radius_max = 1 } } },
    { terrain_list = "tundra_flat_no_feature",         frequency = 10, resources = { { resource = "STONE",    quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "desert_flat_no_feature",         frequency = 16, resources = { { resource = "STONE",    quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "forest_flat_that_are_not_tundra", frequency = 22, resources = { { resource = "DEER",    quantity = 1, weight = 100, radius_min = 3, radius_max = 4 } } },
    { terrain_list = "hills_covered_list",             frequency = 22, resources = { { resource = "HARDWOOD", quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "flat_covered",                   frequency = 22, resources = { { resource = "HARDWOOD", quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "tundra_flat_forest",             frequency = 22, resources = { { resource = "HARDWOOD", quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
    { terrain_list = "plains_flat_no_feature",         frequency = 35, resources = { { resource = "MAIZE",    quantity = 1, weight = 100, radius_min = 1, radius_max = 2 } } },
}

------------------------------------------------------------------------------
-- LUXURY REGION WEIGHTS
-- Unified table -- includes all resources from vanilla, expansions, and
-- lekmod. Resources not present in the game are filtered by
-- ResolveWeightTable() at runtime.
--
-- NOTE: Numeric key literals are used instead of Lekmap_Constants.REGION_TYPE
-- because this table is defined at module load time, before Lekmap_Constants
-- is guaranteed to be initialized.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.LUXURY_REGION_WEIGHTS = {
    [1] = { -- REGION_TYPE.TUNDRA
        { "FUR", 40 }, { "MARBLE", 10 }, { "SILVER", 40 }, { "AMBER", 40 },
        { "SALT", 40 }, { "GOLD", 10 }, { "COPPER", 10 }, { "GEMS", 10 },
        { "JADE", 10 }, { "LAPIS", 10 }, { "WHALE", 10 }, { "CRAB", 10 },
        { "PEARLS", 10 }, { "OBSIDIAN", 10 }, { "CORAL", 10 },
    },
    [2] = { -- REGION_TYPE.JUNGLE
        { "CITRUS", 40 }, { "COCOA", 40 }, { "SPICES", 40 }, { "SUGAR", 40 },
        { "OBSIDIAN", 40 }, { "COCONUT", 40 }, { "RUBBER", 40 }, { "TRUFFLES", 40 },
        { "SILK", 10 }, { "DYE", 10 }, { "FUR", 10 }, { "WHALE", 10 },
        { "CRAB", 10 }, { "PEARLS", 10 }, { "CORAL", 10 },
    },
    [3] = { -- REGION_TYPE.FOREST
        { "TRUFFLES", 40 }, { "MARBLE", 5 }, { "SILK", 10 }, { "DYE", 10 },
        { "FUR", 40 }, { "COCONUT", 10 }, { "RUBBER", 10 }, { "CITRUS", 10 },
        { "COCOA", 10 }, { "SPICES", 10 }, { "SUGAR", 10 }, { "WHALE", 10 },
        { "CRAB", 10 }, { "PEARLS", 10 }, { "CORAL", 10 },
    },
    [4] = { -- REGION_TYPE.DESERT
        { "INCENSE", 40 }, { "MARBLE", 5 }, { "SALT", 40 }, { "GOLD", 40 },
        { "LAPIS", 40 }, { "OBSIDIAN", 10 }, { "COPPER", 10 }, { "SILVER", 10 },
        { "AMBER", 10 }, { "GEMS", 10 }, { "JADE", 10 }, { "WHALE", 10 },
        { "CRAB", 10 }, { "PEARLS", 10 }, { "CORAL", 10 },
    },
    [5] = { -- REGION_TYPE.HILLS
        { "GOLD", 30 }, { "MARBLE", 15 }, { "SILVER", 30 }, { "COPPER", 30 },
        { "GEMS", 30 }, { "SALT", 30 }, { "JADE", 30 }, { "AMBER", 30 },
        { "LAPIS", 30 }, { "OBSIDIAN", 30 }, { "WHALE", 10 }, { "CRAB", 10 },
        { "PEARLS", 10 }, { "CORAL", 10 },
    },
    [6] = { -- REGION_TYPE.PLAINS
        { "INCENSE", 40 }, { "MARBLE", 10 }, { "IVORY", 40 }, { "WINE", 40 },
        { "OLIVE", 40 }, { "COFFEE", 40 }, { "TOBACCO", 10 }, { "TEA", 10 },
        { "PERFUME", 40 }, { "COTTON", 10 }, { "WHALE", 10 }, { "CRAB", 10 },
        { "PEARLS", 10 }, { "CORAL", 10 },
    },
    [7] = { -- REGION_TYPE.GRASS
        { "TOBACCO", 40 }, { "MARBLE", 10 }, { "TEA", 40 }, { "COTTON", 40 },
        { "PERFUME", 25 }, { "IVORY", 10 }, { "WINE", 10 }, { "OLIVE", 25 },
        { "COFFEE", 25 }, { "WHALE", 10 }, { "CRAB", 10 }, { "PEARLS", 10 },
        { "CORAL", 10 },
    },
    [8] = { -- REGION_TYPE.HYBRID
        { "GOLD", 30 }, { "MARBLE", 15 }, { "SILVER", 30 }, { "COPPER", 30 },
        { "GEMS", 30 }, { "SALT", 30 }, { "JADE", 30 }, { "AMBER", 30 },
        { "LAPIS", 30 }, { "OBSIDIAN", 30 }, { "COFFEE", 5 }, { "COCONUT", 5 },
        { "RUBBER", 5 }, { "TOBACCO", 5 }, { "TEA", 5 }, { "PERFUME", 5 },
        { "COTTON", 5 }, { "IVORY", 5 }, { "WINE", 5 }, { "OLIVE", 5 },
        { "INCENSE", 5 }, { "TRUFFLES", 5 }, { "SILK", 5 }, { "DYE", 5 },
        { "FUR", 5 }, { "CITRUS", 5 }, { "COCOA", 5 }, { "SPICES", 5 },
        { "SUGAR", 5 }, { "WHALE", 20 }, { "CRAB", 20 }, { "PEARLS", 20 },
        { "CORAL", 20 },
    },
    [9] = { -- REGION_TYPE.WETLANDS
        { "TOBACCO", 40 }, { "TEA", 40 }, { "PERFUME", 20 }, { "COTTON", 30 },
        { "OLIVE", 20 }, { "SILVER", 20 }, { "SUGAR", 20 }, { "COPPER", 20 },
        { "CORAL", 20 }, { "CRAB", 25 }, { "PEARLS", 25 }, { "COCONUT", 30 },
        { "RUBBER", 5 }, { "WHALE", 25 }, { "COCOA", 10 }, { "TRUFFLES", 5 },
        { "SPICES", 5 }, { "GEMS", 20 },
    },
}

------------------------------------------------------------------------------
-- LUXURY FALLBACK WEIGHTS
------------------------------------------------------------------------------
Lekmap_ResourceDefs.LUXURY_FALLBACK_WEIGHTS = {
    { "GOLD", 10 }, { "SILVER", 10 }, { "COPPER", 10 }, { "GEMS", 10 },
    { "MARBLE", 5 }, { "SALT", 10 }, { "JADE", 10 }, { "AMBER", 10 },
    { "LAPIS", 10 }, { "OBSIDIAN", 10 }, { "COFFEE", 5 }, { "TOBACCO", 5 },
    { "TEA", 5 }, { "PERFUME", 5 }, { "COTTON", 5 }, { "IVORY", 5 },
    { "WINE", 5 }, { "OLIVE", 5 }, { "INCENSE", 5 }, { "TRUFFLES", 5 },
    { "SILK", 5 }, { "DYE", 5 }, { "FUR", 5 }, { "CITRUS", 5 },
    { "COCOA", 5 }, { "SPICES", 5 }, { "SUGAR", 5 }, { "WHALE", 30 },
    { "CRAB", 30 }, { "PEARLS", 30 }, { "COCONUT", 5 }, { "RUBBER", 5 },
    { "CORAL", 30 },
}

------------------------------------------------------------------------------
-- LUXURY CITY STATE WEIGHTS
------------------------------------------------------------------------------
Lekmap_ResourceDefs.LUXURY_CITY_STATE_WEIGHTS = {
    { "GOLD", 5 }, { "OBSIDIAN", 5 }, { "MARBLE", 5 }, { "SILVER", 5 },
    { "COPPER", 5 }, { "GEMS", 5 }, { "SALT", 5 }, { "JADE", 5 },
    { "AMBER", 5 }, { "LAPIS", 5 }, { "COFFEE", 5 }, { "TOBACCO", 5 },
    { "TEA", 5 }, { "PERFUME", 5 }, { "COTTON", 5 }, { "IVORY", 5 },
    { "WINE", 5 }, { "OLIVE", 5 }, { "INCENSE", 5 }, { "TRUFFLES", 5 },
    { "SILK", 5 }, { "DYE", 5 }, { "FUR", 5 }, { "CITRUS", 5 },
    { "COCOA", 5 }, { "SPICES", 5 }, { "SUGAR", 5 }, { "COCONUT", 5 },
    { "RUBBER", 5 }, { "WHALE", 30 }, { "CRAB", 30 }, { "PEARLS", 30 },
    { "CORAL", 30 },
}

------------------------------------------------------------------------------
-- RESOURCE PREFERENCES
-- Terrain/feature placement preferences for strategic resources.
-- Higher preference value = less likely to spawn on that terrain/feature.
------------------------------------------------------------------------------
Lekmap_ResourceDefs.RESOURCE_PREFERENCES = {
    { resource = "URANIUM",  feature = "FEATURE_FOREST",  preference = 60 },
    { resource = "URANIUM",  feature = "FEATURE_JUNGLE",  preference = 140 },
    { resource = "URANIUM",  feature = "FEATURE_MARSH",   preference = 20 },

    { resource = "OIL",      terrain = "TERRAIN_DESERT",  preference = 28 },
    { resource = "OIL",      terrain = "TERRAIN_SNOW",    preference = 45 },
    { resource = "OIL",      terrain = "TERRAIN_TUNDRA",  preference = 50 },
    { resource = "OIL",      feature = "FEATURE_MARSH",   preference = 15 },
    { resource = "OIL",      feature = "FEATURE_FOREST",  preference = 140 },

    { resource = "ALUMINUM", terrain = "TERRAIN_SNOW",    preference = 70 },
    { resource = "ALUMINUM", terrain = "TERRAIN_TUNDRA",  preference = 80 },
    { resource = "ALUMINUM", terrain = "TERRAIN_HILL",    preference = 50 },

    { resource = "IRON",     terrain = "TERRAIN_TUNDRA",  preference = 50 },
    { resource = "IRON",     terrain = "TERRAIN_SNOW",    preference = 75 },
    { resource = "IRON",     terrain = "TERRAIN_HILL",    preference = 88 },
    { resource = "IRON",     terrain = "TERRAIN_DESERT",  preference = 35 },

    { resource = "COAL",     feature = "FEATURE_FOREST",  preference = 200 },
    { resource = "COAL",     feature = "FEATURE_JUNGLE",  preference = 72 },
    { resource = "COAL",     terrain = "TERRAIN_HILL",    preference = 60 },

    { resource = "HORSE",    terrain = "TERRAIN_GRASS",   preference = 17 },
    { resource = "HORSE",    terrain = "TERRAIN_PLAINS",  preference = 17 },
}

------------------------------------------------------------------------------
-- HELPER: Resolve weight tables from string keys to resource IDs.
-- Uses the active resource set. Any key not active is silently skipped.
------------------------------------------------------------------------------
function Lekmap_ResourceDefs.ResolveWeightTable(weight_table)
    local resolved = {}
    local active = Lekmap_ResourceDefs.active
    if not active then return resolved end
    for _, entry in ipairs(weight_table) do
        local key    = entry[1]
        local weight = entry[2]
        local resource_entry = active[key]
        if resource_entry then
            table.insert(resolved, { resource_entry.id, weight })
        end
    end
    return resolved
end
