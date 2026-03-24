------------------------------------------------------------------------------
--  FILE:     Lekmap_Bonus.lua
--  AUTHOR:   EnormousApplePie
--  PURPOSE:  Bonus resource and fish placement for Lekmap.
--            Handles world bonus distribution, start-area bonus ("sexy bonus"),
--            extra bonuses for hills regions, mainland fish, and open-water fish.
------------------------------------------------------------------------------
--  Depends on:
--      Lekmap_Constants.lua      (IMPACT_LAYER, REGION_TYPE)
--      Lekmap_ResourceDefs.lua   (active set, GetID, IsActive)
--      Lekmap_Resources.lua      (ProcessWeightedList, PlaceSpecificNumber,
--                                 GetPlotCache, GetMapDimensions, PlaceOne)
--      Lekmap_Impact.lua         (PlaceImpact, IsImpacted)
--      Lekmap_Regions.lua        (region data, types, terrain counts)
--      Lekmap_Spawns.lua         (GetAllStartPlots)
--      Lekmap_Utilities.lua      (GenerateNextToCoastalLandDataTables, GenerateThreeFromCoastTable)
--      Lekmap_HexUtil.lua        (PlotRingIterator)
--  Engine globals: Map, PlotTypes, TerrainTypes, FeatureTypes
------------------------------------------------------------------------------
--luacheck: globals Lekmap_Bonus Lekmap_ResourceDefs Lekmap_Resources Lekmap_Regions
--luacheck: globals Lekmap_Spawns Lekmap_Impact Lekmap_Utilities Lekmap_HexUtil
--luacheck: globals Lekmap_Constants
--luacheck: globals Map PlotTypes TerrainTypes FeatureTypes

Lekmap_Bonus = {}

------------------------------------------------------------------------------
-- FREQUENCY MULTIPLIER
-- Higher resource setting = more resources = lower frequency divisor.
------------------------------------------------------------------------------
local BONUS_MULTIPLIER = {
    [1]  = 1.00,
    [2]  = 0.90,
    [3]  = 0.80,
    [4]  = 0.75,
    [5]  = 0.65,
    [6]  = 0.55,
    [7]  = 0.45,
    [8]  = 0.35,
    [9]  = 0.25,
    [10] = 0.15,
}

------------------------------------------------------------------------------
-- BONUS ASSOCIATED WITH REGION TYPE (for sexy bonus at start)
-- Maps REGION_TYPE -> resource key placed near starts.
-- numeric literal: Lekmap_Constants not available at load time
------------------------------------------------------------------------------
local START_BONUS_BY_REGION = {
    [1] = "DEER",    -- REGION_TYPE.TUNDRA
    [2] = "BANANA",  -- REGION_TYPE.JUNGLE
    [3] = "DEER",    -- REGION_TYPE.FOREST
    [4] = "WHEAT",   -- REGION_TYPE.DESERT
    [5] = "MAIZE",   -- REGION_TYPE.HILLS
    [6] = "SHEEP",   -- REGION_TYPE.PLAINS
    [7] = "WHEAT",   -- REGION_TYPE.GRASS
    [8] = "COW",     -- REGION_TYPE.HYBRID
    [9] = "COW",     -- REGION_TYPE.WETLANDS
}

------------------------------------------------------------------------------
-- TERRAIN-SPECIFIC PLOT LIST BUILDERS (shared helpers)
------------------------------------------------------------------------------

local function BuildFilteredList(plot_cache, filter_fn)
    local list = {}
    for i, entry in ipairs(plot_cache) do
        if not entry.has_resource and filter_fn(entry) then
            table.insert(list, i)
        end
    end
    -- Shuffle.
    for i = #list, 2, -1 do
        local j = Map.Rand(i, "Shuffle bonus plot list") + 1
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- Filter functions for world bonus placement.
local function IsExtraDeer(entry)
    return entry.feature_type == FeatureTypes.FEATURE_FOREST and entry.is_flat
       and entry.terrain_type == TerrainTypes.TERRAIN_TUNDRA
end

local function IsDesertWheat(entry)
    if entry.terrain_type ~= TerrainTypes.TERRAIN_DESERT then return false end
    if not entry.is_flat then return false end
    if entry.feature_type == FeatureTypes.FEATURE_FLOOD_PLAINS then return true end
    local plot = Map.GetPlot(entry.x, entry.y)
    return plot:IsFreshWater()
end

local function IsTundraFlat(entry)
    return entry.terrain_type == TerrainTypes.TERRAIN_TUNDRA and entry.is_flat
       and entry.feature_type == FeatureTypes.NO_FEATURE
end

local function IsBananaJungle(entry)
    return entry.feature_type == FeatureTypes.FEATURE_JUNGLE and not entry.is_mountain and not entry.is_water
end

local function IsPlainsFlat(entry)
    return entry.terrain_type == TerrainTypes.TERRAIN_PLAINS and entry.is_flat
       and entry.feature_type == FeatureTypes.NO_FEATURE
end

local function IsGrassFlat(entry)
    return entry.terrain_type == TerrainTypes.TERRAIN_GRASS and entry.is_flat
       and entry.feature_type == FeatureTypes.NO_FEATURE
end

local function IsDryGrassFlat(entry)
    return entry.terrain_type == TerrainTypes.TERRAIN_GRASS and entry.is_flat
       and entry.feature_type == FeatureTypes.NO_FEATURE
end

local function IsHillsOpen(entry)
    return entry.is_hill and entry.feature_type == FeatureTypes.NO_FEATURE
end

local function IsDesertFlat(entry)
    return entry.terrain_type == TerrainTypes.TERRAIN_DESERT and entry.is_flat
       and entry.feature_type == FeatureTypes.NO_FEATURE
end

local function IsForestFlatNotTundra(entry)
    return entry.feature_type == FeatureTypes.FEATURE_FOREST and entry.is_flat
       and entry.terrain_type ~= TerrainTypes.TERRAIN_TUNDRA
end

local function IsHillsCovered(entry)
    return entry.is_hill and (entry.feature_type == FeatureTypes.FEATURE_FOREST or entry.feature_type == FeatureTypes.FEATURE_JUNGLE)
end

local function IsFlatCovered(entry)
    return entry.is_flat and (entry.feature_type == FeatureTypes.FEATURE_FOREST or entry.feature_type == FeatureTypes.FEATURE_JUNGLE)
end

local function IsTundraFlatForest(entry)
    return entry.terrain_type == TerrainTypes.TERRAIN_TUNDRA and entry.is_flat
       and entry.feature_type == FeatureTypes.FEATURE_FOREST
end

local function IsCoast(entry)
    return entry.is_coast
end

------------------------------------------------------------------------------
-- WORLD BONUS PLACEMENT
-- Places bonuses across the map with terrain-specific frequencies.
------------------------------------------------------------------------------

--- World bonus placement rules: { filter_fn, frequency_multiplier, resource_key, min_radius, max_radius }
local function GetWorldBonusRules()
    return {
        { IsExtraDeer,           6,  "DEER",     1, 2 },
        { IsDesertWheat,         6,  "WHEAT",    1, 2 },
        { IsTundraFlat,          8,  "DEER",     1, 2 },
        { IsBananaJungle,        10, "BANANA",   1, 2 },
        { IsPlainsFlat,          30, "WHEAT",    1, 3 },
        { IsPlainsFlat,          15, "BISON",    2, 3 },
        { IsPlainsFlat,          22, "COW",      2, 3 },
        { IsGrassFlat,           22, "COW",      2, 3 },
        { IsDryGrassFlat,        20, "STONE",    1, 1 },
        { IsDryGrassFlat,        20, "BISON",    1, 1 },
        { IsHillsOpen,           20, "SHEEP",    1, 1 },
        { IsTundraFlat,          10, "STONE",    1, 2 },
        { IsDesertFlat,          16, "STONE",    1, 2 },
        { IsForestFlatNotTundra, 22, "DEER",     3, 4 },
        { IsHillsCovered,        22, "HARDWOOD", 1, 2 },
        { IsFlatCovered,         22, "HARDWOOD", 1, 2 },
        { IsTundraFlatForest,    22, "HARDWOOD", 1, 2 },
        { IsPlainsFlat,          35, "MAIZE",    1, 2 },
    }
end

function Lekmap_Bonus.PlaceWorldBonus(resource_setting)
    local IMPACT_LAYER = Lekmap_Constants.IMPACT_LAYER
    local multiplier = BONUS_MULTIPLIER[resource_setting] or 0.65
    local plot_cache = Lekmap_Resources.GetPlotCache()
    local layer = IMPACT_LAYER.BONUS
    local rules = GetWorldBonusRules()

    for _, rule in ipairs(rules) do
        local filter_fn       = rule[1]
        local base_frequency  = rule[2]
        local resource_key    = rule[3]
        local min_radius      = rule[4]
        local max_radius      = rule[5]

        local resource_id = Lekmap_ResourceDefs.GetID(resource_key)
        if resource_id then
            local plot_list = BuildFilteredList(plot_cache, filter_fn)
            if #plot_list > 0 then
                local entries = { { resource_id, 1, 100, min_radius, max_radius } }
                Lekmap_Resources.ProcessWeightedList(
                    math.ceil(base_frequency * multiplier), layer, plot_list, entries)
            end
        end
    end
end

------------------------------------------------------------------------------
-- SEXY BONUS AT CIV STARTS
-- Places a region-appropriate bonus in ring 2 around each start.
------------------------------------------------------------------------------

function Lekmap_Bonus.PlaceAtCivStarts()
    local num_regions = Lekmap_Regions.GetRegionCount()
    local start_plots = Lekmap_Spawns.GetAllStartPlots()
    if not start_plots then return end

    for region_index = 1, num_regions do
        local start_plot = start_plots[region_index]
        if start_plot and start_plot.x and start_plot.y then
            local region_type = Lekmap_Regions.GetRegionType(region_index)
            local bonus_key = START_BONUS_BY_REGION[region_type] or "WHEAT"

            local resource_id = Lekmap_ResourceDefs.GetID(bonus_key)
            if resource_id then
                local plot_list = Lekmap_Resources.GeneratePlotList(bonus_key, { x = start_plot.x, y = start_plot.y, radius = 2 })
                Lekmap_Resources.PlaceSpecificNumber(resource_id, 1, 1, 1.0, -1, 0, 0, plot_list)
            end
        end
    end
end

------------------------------------------------------------------------------
-- EXTRA BONUSES FOR HILLS REGIONS
-- Hills regions are low on food; add extra food bonuses proportional to
-- how infertile the region is.
------------------------------------------------------------------------------

function Lekmap_Bonus.PlaceExtraForHillsRegions()
    local IMPACT_LAYER = Lekmap_Constants.IMPACT_LAYER
    local REGION_TYPE = Lekmap_Constants.REGION_TYPE
    local num_regions = Lekmap_Regions.GetRegionCount()
    local map_width, map_height = Lekmap_Resources.GetMapDimensions()
    local plot_cache = Lekmap_Resources.GetPlotCache()
    local layer = IMPACT_LAYER.BONUS

    for region_index = 1, num_regions do
        local region_type = Lekmap_Regions.GetRegionType(region_index)
        if region_type == REGION_TYPE.HILLS then
            local region = Lekmap_Regions.GetRegion(region_index)
            local counts = Lekmap_Regions.GetTerrainCounts(region_index)
            if region and counts then
                local area_plots      = counts.areaPlots or 1
                local hills_count     = counts.hills or 0
                local peaks_count     = counts.peaks or 0
                local flatlands_count = counts.flatlands or 0
                local grass_count     = counts.grass or 0
                local plains_count    = counts.plains or 0

                local hills_ratio = (hills_count + peaks_count) / area_plots
                local farm_ratio  = (grass_count + plains_count) / area_plots
                local infertility_factor = 1 + math.max(0, hills_ratio - farm_ratio)

                -- Generate terrain-specific plot lists within the region.
                local dry_hills, flat_plains, flat_grass, flat_tundra, jungles, forests = {}, {}, {}, {}, {}, {}
                local west_x  = region.westX
                local south_y = region.southY
                local width   = region.width
                local height  = region.height

                for rel_y = 0, height - 1 do
                    for rel_x = 0, width - 1 do
                        local plot_x = (rel_x + west_x) % map_width
                        local plot_y = (rel_y + south_y) % map_height
                        local idx = plot_y * map_width + plot_x + 1
                        local entry = plot_cache[idx]
                        if entry and not entry.has_resource and not entry.is_water and not entry.is_mountain then
                            local feature_type = entry.feature_type
                            local terrain_type = entry.terrain_type
                            if feature_type == FeatureTypes.FEATURE_JUNGLE then
                                table.insert(jungles, idx)
                            elseif feature_type == FeatureTypes.FEATURE_FOREST then
                                table.insert(forests, idx)
                            elseif feature_type == FeatureTypes.FEATURE_FLOOD_PLAINS then
                                table.insert(flat_plains, idx)
                            elseif feature_type == FeatureTypes.NO_FEATURE then
                                if entry.is_hill then
                                    if (terrain_type == TerrainTypes.TERRAIN_GRASS or terrain_type == TerrainTypes.TERRAIN_PLAINS or terrain_type == TerrainTypes.TERRAIN_TUNDRA) then
                                        local plot = Map.GetPlot(plot_x, plot_y)
                                        if not plot:IsFreshWater() then
                                            table.insert(dry_hills, idx)
                                        end
                                    end
                                elseif entry.is_flat then
                                    if terrain_type == TerrainTypes.TERRAIN_PLAINS then
                                        table.insert(flat_plains, idx)
                                    elseif terrain_type == TerrainTypes.TERRAIN_DESERT then
                                        local plot = Map.GetPlot(plot_x, plot_y)
                                        if plot:IsFreshWater() then
                                            table.insert(flat_plains, idx)
                                        end
                                    elseif terrain_type == TerrainTypes.TERRAIN_GRASS then
                                        table.insert(flat_grass, idx)
                                    elseif terrain_type == TerrainTypes.TERRAIN_TUNDRA then
                                        table.insert(flat_tundra, idx)
                                    end
                                end
                            end
                        end
                    end
                end

                -- Place bonuses with infertility-adjusted frequencies.
                local function PlaceExtra(plot_list, key, frequency, min_radius, max_radius)
                    if #plot_list == 0 then return end
                    local resource_id = Lekmap_ResourceDefs.GetID(key)
                    if not resource_id then return end
                    local entries = { { resource_id, 1, 100, min_radius, max_radius } }
                    Lekmap_Resources.ProcessWeightedList(
                        math.ceil(frequency / infertility_factor), layer, plot_list, entries)
                end

                PlaceExtra(dry_hills,   "SHEEP",    9,  1, 1)
                PlaceExtra(jungles,     "BANANA",   14, 1, 2)
                PlaceExtra(flat_tundra, "DEER",     14, 0, 1)
                PlaceExtra(flat_tundra, "HARDWOOD", 14, 0, 1)
                PlaceExtra(flat_plains, "WHEAT",    18, 0, 2)
                PlaceExtra(flat_plains, "MAIZE",    18, 0, 2)
                PlaceExtra(flat_grass,  "COW",      20, 1, 2)
                PlaceExtra(forests,     "DEER",     24, 1, 2)
                PlaceExtra(forests,     "HARDWOOD", 24, 1, 2)
            end
        end
    end
end

------------------------------------------------------------------------------
-- FISH PLACEMENT
-- Two modes: mainland coast (near the main landmass) and open water.
------------------------------------------------------------------------------

--- Build mainland coast WATER lists for fish placement.
--- Inner = ocean tiles directly adjacent to the biggest landmass.
--- Second = coast tiles one ring beyond inner.
--- Outer = coast tiles one ring beyond second.
local function BuildMainlandCoastLists()
    local map_width, map_height = Lekmap_Resources.GetMapDimensions()

    -- These return WATER plots at increasing distances from the mainland.
    local inner_coast, second_coast = Lekmap_Utilities.GenerateMainlandExpandedCoastData()
    local outer_coast = Lekmap_Utilities.GenerateThreeFromMainlandCoast(inner_coast, second_coast)

    local inner_list   = {}
    local second_list  = {}
    local outer_list   = {}
    local combined_list = {}
    local mainland_coast_lookup = {}

    for y = 0, map_height - 1 do
        for x = 0, map_width - 1 do
            local i = map_width * y + x + 1
            if inner_coast[i] == true then
                table.insert(inner_list, i)
                table.insert(combined_list, i)
                mainland_coast_lookup[i] = true
            elseif second_coast[i] == true then
                table.insert(second_list, i)
                table.insert(combined_list, i)
                mainland_coast_lookup[i] = true
            elseif outer_coast[i] == true then
                table.insert(outer_list, i)
                table.insert(combined_list, i)
                mainland_coast_lookup[i] = true
            end
        end
    end

    -- Shuffle each list.
    local function Shuffle(list)
        for i = #list, 2, -1 do
            local j = Map.Rand(i, "Shuffle coast list") + 1
            list[i], list[j] = list[j], list[i]
        end
    end
    Shuffle(inner_list)
    Shuffle(second_list)
    Shuffle(outer_list)
    Shuffle(combined_list)

    return inner_list, second_list, outer_list, combined_list, mainland_coast_lookup
end

------------------------------------------------------------------------------
--- Place fish on a coast plot list with frequency-based spacing.
--  This is a direct placement function (not using ProcessWeightedList)
--  because fish have their own impact layer behavior (BONUS layer).
--
--  @param frequency       how many coast plots per fish
--  @param plot_list       shuffled array of 1-based plot indices
--  @param skip_mainland   optional lookup table of mainland coast indices to skip
------------------------------------------------------------------------------
function Lekmap_Bonus.PlaceFishOnList(frequency, plot_list, skip_mainland)
    if not plot_list or #plot_list == 0 then return end
    local IMPACT_LAYER = Lekmap_Constants.IMPACT_LAYER

    local fish_id = Lekmap_ResourceDefs.GetID("FISH")
    if not fish_id then return end

    local plot_cache = Lekmap_Resources.GetPlotCache()
    local num_to_place = math.ceil(#plot_list / frequency)
    local layer = IMPACT_LAYER.BONUS
    local current_index = 1

    for _ = 1, num_to_place do
        if current_index > #plot_list then break end
        for idx = current_index, #plot_list do
            current_index = idx + 1
            local plot_index = plot_list[idx]

            -- If skip_mainland is set, skip plots that are part of the mainland coast.
            if skip_mainland and skip_mainland[plot_index] then
                -- Skip this one; only place on non-mainland coast.
            elseif not Lekmap_Impact.IsImpacted(layer, plot_cache[plot_index].x, plot_cache[plot_index].y) then
                local plot_x = plot_cache[plot_index].x
                local plot_y = plot_cache[plot_index].y
                local plot = Map.GetPlot(plot_x, plot_y)
                local feature_type = plot:GetFeatureType()

                -- Must be actual coast water; reject lakes and ice.
                if plot:IsWater() and not plot:IsLake() and feature_type ~= FeatureTypes.FEATURE_ICE then
                    if plot:GetResourceType(-1) == -1 then
                        local fish_radius = Map.Rand(2, "Fish radius") + 1
                        plot:SetResourceType(fish_id, 1)
                        Lekmap_Impact.PlaceImpact(layer, plot_x, plot_y, fish_radius)
                        if plot_cache[plot_index] then plot_cache[plot_index].has_resource = true end
                        break
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------------
--- Place fish near the mainland with layered frequency (inner/second/outer).
--  Uses the _lek_coastal_refish mode: inner coast is dense, outer is sparse.
------------------------------------------------------------------------------
function Lekmap_Bonus.PlaceFishMainland(resource_setting)
    local multiplier = BONUS_MULTIPLIER[resource_setting] or 0.65

    local inner_list, second_list, outer_list, _, _ = BuildMainlandCoastLists()

    print("Lekmap_Bonus: Fish mainland - inner=" .. #inner_list .. ", second=" .. #second_list .. ", outer=" .. #outer_list)

    -- Inner coast: dense fish (frequency 3).
    Lekmap_Bonus.PlaceFishOnList(math.ceil(3 * multiplier), inner_list, nil)

    -- Second ring: medium fish (frequency 8).
    Lekmap_Bonus.PlaceFishOnList(math.ceil(8 * multiplier), second_list, nil)

    -- Outer ring: sparse fish (frequency 15).
    Lekmap_Bonus.PlaceFishOnList(math.ceil(15 * multiplier), outer_list, nil)
end

------------------------------------------------------------------------------
--- Place fish in open water (non-mainland coast).
--  These fish go on all coast tiles that are NOT part of the mainland coast.
------------------------------------------------------------------------------
function Lekmap_Bonus.PlaceFishOpenWater(resource_setting)
    local multiplier = BONUS_MULTIPLIER[resource_setting] or 0.65
    local plot_cache = Lekmap_Resources.GetPlotCache()

    -- Build a full coast list.
    local all_coast = BuildFilteredList(plot_cache, IsCoast)

    -- Build mainland lookup to skip.
    local _, _, _, _, mainland_lookup = BuildMainlandCoastLists()

    -- Open water fish: frequency 16 (sparser).
    Lekmap_Bonus.PlaceFishOnList(math.ceil(16 * multiplier), all_coast, mainland_lookup)
end

------------------------------------------------------------------------------
-- ORCHESTRATOR
------------------------------------------------------------------------------

function Lekmap_Bonus.PlaceAll(args)
    args = args or {}
    local resource_setting = Lekmap_Resources.GetResourceSetting()

    print("Lekmap_Bonus: Beginning bonus placement.")

    -- Step 1: Fish on mainland coast.
    print("Lekmap_Bonus: Placing mainland fish.")
    Lekmap_Bonus.PlaceFishMainland(resource_setting)

    -- Step 2: Fish on open water.
    print("Lekmap_Bonus: Placing open water fish.")
    Lekmap_Bonus.PlaceFishOpenWater(resource_setting)

    -- Step 3: Sexy bonus at starts.
    print("Lekmap_Bonus: Placing start bonuses.")
    Lekmap_Bonus.PlaceAtCivStarts()

    -- Step 4: Extra bonuses for hills regions.
    print("Lekmap_Bonus: Placing extra bonuses for hills regions.")
    Lekmap_Bonus.PlaceExtraForHillsRegions()

    -- Step 5: World bonuses.
    print("Lekmap_Bonus: Placing world bonuses.")
    Lekmap_Bonus.PlaceWorldBonus(resource_setting)

    print("Lekmap_Bonus: Bonus placement complete.")
end
