------------------------------------------------------------------------------
--  FILE:     Lekmap_Resources.lua
--  AUTHOR:   EnormousApplePie
--  PURPOSE:  Core resource placement mechanics for Lekmap.
--            Provides data-driven plot list generation (from Lekmap_ResourceDefs),
--            weighted and specific-count placement functions, resource tracking,
--            and the main orchestrator that calls all sub-modules.
------------------------------------------------------------------------------
--  Depends on:
--      Lekmap_Constants.lua      (IMPACT_LAYER)
--      Lekmap_ResourceDefs.lua   (RESOURCE_DEFS, RESOURCE_CLASSES, active set)
--      Lekmap_Impact.lua         (GetValue, IsImpacted, PlaceImpact)
--      Lekmap_Regions.lua        (region data)
--      Lekmap_Spawns.lua         (start plot data)
--      Lekmap_HexUtil.lua        (PlotRingIterator)
--      Lekmap_Luxuries.lua       (luxury placement, loaded separately)
--      Lekmap_Strategics.lua     (strategic placement, loaded separately)
--      Lekmap_Bonus.lua          (start bonuses + world/sea scatter; loaded in MapGenerator)
--  Engine globals: Map, PlotTypes, TerrainTypes, FeatureTypes, GameInfo,
--                  ResourceUsageTypes, Game
------------------------------------------------------------------------------
--luacheck: globals Lekmap_Resources Lekmap_ResourceDefs Lekmap_Impact Lekmap_Regions
--luacheck: globals Lekmap_Spawns Lekmap_HexUtil Lekmap_Luxuries Lekmap_Strategics Lekmap_Bonus include
--luacheck: globals Lekmap_Constants
--luacheck: globals Map PlotTypes TerrainTypes FeatureTypes GameInfo ResourceUsageTypes Game

Lekmap_Resources = {}

------------------------------------------------------------------------------
-- PRIVATE STATE
------------------------------------------------------------------------------
local map_width, map_height = 0, 0

--- Per-plot cached data from BuildWorldPlotCache.
--- Each entry: { plot_type, terrain_type, feature_type, is_hill, is_flat, is_water, is_coast,
---               adjacent_to_land, is_lake, has_resource, is_mountain, x, y }
local plot_cache = {}

--- Collision data: plots occupied by player starts, CS starts, or natural wonders.
local collision_data = {}

--- Tracks how many of each resource ID have been placed.
local amounts_placed = {}

--- Total luxury instances placed (for cap enforcement).
local total_lux_placed = 0

--- Barren plot counter (mountains, ice, deep ocean, etc.).
local barren_plots = 0

--- Resource setting (density 1-10, from map options).
local resource_setting = 5

------------------------------------------------------------------------------
-- NAMED CONSTANTS
------------------------------------------------------------------------------
local TERRAIN_LOOKUP = {}  -- populated at init: TERRAIN_LOOKUP["TERRAIN_GRASS"] = TerrainTypes.TERRAIN_GRASS
local FEATURE_LOOKUP = {}  -- populated at init: FEATURE_LOOKUP["FEATURE_FOREST"] = FeatureTypes.FEATURE_FOREST

------------------------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------------------------

--- Build lookup tables that map string names to engine enum values.
local function BuildEnumLookups()
    -- Terrain names to IDs.
    for row in GameInfo.Terrains() do
        TERRAIN_LOOKUP[row.Type] = row.ID
    end
    -- Feature names to IDs.
    for row in GameInfo.Features() do
        FEATURE_LOOKUP[row.Type] = row.ID
    end
end

------------------------------------------------------------------------------
--- Build a per-plot cache of terrain, feature, and plot type data.
--  This is called once, and individual GeneratePlotList calls filter this
--  cache rather than re-querying every plot from the engine.
------------------------------------------------------------------------------
function Lekmap_Resources.BuildWorldPlotCache()
    map_width, map_height = Map.GetGridSize()
    plot_cache = {}
    barren_plots = 0

    for y = 0, map_height - 1 do
        for x = 0, map_width - 1 do
            local i = y * map_width + x + 1
            local plot = Map.GetPlot(x, y)
            local plot_type    = plot:GetPlotType()
            local terrain_type = plot:GetTerrainType()
            local feature_type = plot:GetFeatureType()

            plot_cache[i] = {
                x               = x,
                y               = y,
                plot_type       = plot_type,
                terrain_type    = terrain_type,
                feature_type    = feature_type,
                is_hill         = (plot_type == PlotTypes.PLOT_HILLS),
                is_flat         = (plot_type == PlotTypes.PLOT_LAND),
                is_water        = (plot_type == PlotTypes.PLOT_OCEAN),
                is_mountain     = (plot_type == PlotTypes.PLOT_MOUNTAIN),
                is_coast        = (terrain_type == TerrainTypes.TERRAIN_COAST and plot_type == PlotTypes.PLOT_OCEAN),
                is_lake         = plot:IsLake(),
                adjacent_to_land = plot:IsAdjacentToLand(),
                has_resource    = (plot:GetResourceType(-1) ~= -1),
            }

            if plot_type == PlotTypes.PLOT_MOUNTAIN then
                barren_plots = barren_plots + 1
            elseif plot_type == PlotTypes.PLOT_OCEAN then
                if feature_type == FeatureTypes.FEATURE_ICE or plot:IsLake() then
                    barren_plots = barren_plots + 1
                elseif terrain_type ~= TerrainTypes.TERRAIN_COAST then
                    barren_plots = barren_plots + 1 -- deep ocean
                end
            end
        end
    end

    print("Lekmap_Resources: World plot cache built. " .. (map_width * map_height) .. " plots, " .. barren_plots .. " barren.")
end

------------------------------------------------------------------------------
-- PLOT VALIDATION
------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- Check whether a cached plot entry matches a resource definition.
--
--  @param entry    plot cache entry (from plot_cache)
--  @param def      resource definition (from RESOURCE_DEFS)
--  @return true if the resource can legally be placed on this plot
------------------------------------------------------------------------------
function Lekmap_Resources.IsValidPlotForResource(entry, def)
    -- Must not already have a resource.
    if entry.has_resource then return false end

    -- Must not be a collision plot (start, CS, NW).
    if collision_data[entry.y * map_width + entry.x + 1] then return false end

    -- Must not be mountain.
    if entry.is_mountain then return false end

    -- Shallow coast water (before hill/flat). Same idea as land + empty def.features: only
    -- NO_FEATURE tiles qualify — atolls, ice, etc. are features and are not listed on FISH etc.
    if entry.is_water then
        if entry.is_lake then return false end
        if not entry.is_coast then return false end
        if entry.feature_type ~= FeatureTypes.NO_FEATURE then return false end
        for _, t in ipairs(def.terrains) do
            if TERRAIN_LOOKUP[t] == TerrainTypes.TERRAIN_COAST then
                return true
            end
        end
        return false
    end

    -- Land: hills/flatlands eligibility.
    if entry.is_hill and not def.hills then return false end
    if entry.is_flat and not def.flatlands then return false end

    -- Land plot with a feature.
    if entry.feature_type ~= FeatureTypes.NO_FEATURE then
        -- Check if feature is in the allowed features list.
        local feature_allowed = false
        for _, f in ipairs(def.features) do
            if FEATURE_LOOKUP[f] == entry.feature_type then
                feature_allowed = true
                break
            end
        end
        if not feature_allowed then return false end

        -- If feature_terrains is specified, the terrain under the feature must match.
        if def.feature_terrains then
            local terrain_under_ok = false
            for _, t in ipairs(def.feature_terrains) do
                if TERRAIN_LOOKUP[t] == entry.terrain_type then
                    terrain_under_ok = true
                    break
                end
            end
            if not terrain_under_ok then return false end
        end
        return true
    end

    -- Land plot with no feature: terrain must be in the terrains list.
    for _, t in ipairs(def.terrains) do
        if TERRAIN_LOOKUP[t] == entry.terrain_type then
            return true
        end
    end

    -- force_valid_feature: accept bare terrain if it matches feature_terrains
    -- and the resource has a feature that can be forced after placement.
    if def.force_valid_feature and def.feature_terrains then
        for _, t in ipairs(def.feature_terrains) do
            if TERRAIN_LOOKUP[t] == entry.terrain_type then
                return true
            end
        end
    end

    return false
end

------------------------------------------------------------------------------
-- SINGLE-PLOT CACHE + START BONUS PLACEMENT (relax hill/flat/mountain & features;
-- never changes grass/plains/desert/tundra/snow or water class; never strips
-- flood plains or oasis.)
------------------------------------------------------------------------------

local function EnsureMapSize()
    if map_width == 0 or map_height == 0 then
        map_width, map_height = Map.GetGridSize()
    end
end

--- Refresh one plot_cache cell from the live map (after terrain/feature edits).
function Lekmap_Resources.RefreshPlotCacheAt(x, y)
    EnsureMapSize()
    local plot = Map.GetPlot(x, y)
    if not plot then return end
    local i = y * map_width + x + 1
    local plot_type    = plot:GetPlotType()
    local terrain_type = plot:GetTerrainType()
    local feature_type = plot:GetFeatureType()

    plot_cache[i] = {
        x               = x,
        y               = y,
        plot_type       = plot_type,
        terrain_type    = terrain_type,
        feature_type    = feature_type,
        is_hill         = (plot_type == PlotTypes.PLOT_HILLS),
        is_flat         = (plot_type == PlotTypes.PLOT_LAND),
        is_water        = (plot_type == PlotTypes.PLOT_OCEAN),
        is_mountain     = (plot_type == PlotTypes.PLOT_MOUNTAIN),
        is_coast        = (terrain_type == TerrainTypes.TERRAIN_COAST and plot_type == PlotTypes.PLOT_OCEAN),
        is_lake         = plot:IsLake(),
        adjacent_to_land = plot:IsAdjacentToLand(),
        has_resource    = (plot:GetResourceType(-1) ~= -1),
    }
end

--- Shuffled 1-based plot_cache indices for one hex ring around (cx, cy).
function Lekmap_Resources.GetShuffledRingPlotIndices(cx, cy, ring)
    EnsureMapSize()
    local center = Map.GetPlot(cx, cy)
    if not center or ring < 1 then return {} end
    local list = {}
    for ring_plot in Lekmap_HexUtil.PlotRingIterator(center, ring) do
        local rx = ring_plot:GetX()
        local ry = ring_plot:GetY()
        table.insert(list, ry * map_width + rx + 1)
    end
    for i = #list, 2, -1 do
        local j = Map.Rand(i, "Lekmap ring shuffle") + 1
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function PlotAllowsFloodPlainsForDef(def)
    for _, f in ipairs(def.features or {}) do
        if FEATURE_LOOKUP[f] == FeatureTypes.FEATURE_FLOOD_PLAINS then
            return true
        end
    end
    return false
end

--- Adjust hill/flat/mountain and clear blocking features (not flood plains / oasis).
-- Never calls SetTerrainType (biome grass/plains/desert/tundra/snow unchanged).
-- @return true if the map was modified
local function TryRelaxPlotForStartBonus(plot, def)
    if not plot or plot:GetPlotType() == PlotTypes.PLOT_OCEAN then
        return false
    end
    if plot:GetResourceType(-1) ~= -1 then
        return false
    end

    local changed = false
    local ft = plot:GetFeatureType()

    if ft == FeatureTypes.FEATURE_FLOOD_PLAINS and not PlotAllowsFloodPlainsForDef(def) then
        return false
    end
    if ft == FeatureTypes.FEATURE_OASIS then
        return false
    end

    local pt = plot:GetPlotType()

    if pt == PlotTypes.PLOT_MOUNTAIN then
        if def.hills then
            plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true)
            changed = true
        elseif def.flatlands then
            plot:SetPlotType(PlotTypes.PLOT_LAND, false, true)
            changed = true
        else
            return false
        end
        pt = plot:GetPlotType()
    end

    if pt == PlotTypes.PLOT_HILLS and def.flatlands and not def.hills then
        plot:SetPlotType(PlotTypes.PLOT_LAND, false, true)
        changed = true
        pt = PlotTypes.PLOT_LAND
    elseif pt == PlotTypes.PLOT_LAND and def.hills and not def.flatlands then
        plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true)
        changed = true
        pt = PlotTypes.PLOT_HILLS
    end

    ft = plot:GetFeatureType()
    if ft ~= FeatureTypes.NO_FEATURE
        and ft ~= FeatureTypes.FEATURE_FLOOD_PLAINS
        and ft ~= FeatureTypes.FEATURE_OASIS
    then
        plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1)
        changed = true
    end

    return changed
end

------------------------------------------------------------------------------
--- Try to place one start-area bonus at (x,y): valid plot first, else one relax pass.
--  Uses bonus impact spacing.  Applies ForceFeatureAfterPlacement when needed.
--  @param region_index  optional region # for feature forcing heuristics
--  @return              true if placed
------------------------------------------------------------------------------
function Lekmap_Resources.TryPlaceStartBonusAtPlot(resource_key, x, y, region_index)
    local active = Lekmap_ResourceDefs.active and Lekmap_ResourceDefs.active[resource_key]
    if not active then return false end
    local def = active.def

    local plot = Map.GetPlot(x, y)
    if not plot or plot:GetResourceType(-1) ~= -1 then return false end
    if Lekmap_Resources.IsCollision(x, y) then return false end

    EnsureMapSize()
    Lekmap_Resources.RefreshPlotCacheAt(x, y)
    local idx = y * map_width + x + 1
    local entry = plot_cache[idx]
    if not entry then return false end

    local function attempt_place()
        if not Lekmap_Resources.IsValidPlotForResource(entry, def) then
            return false
        end
        if not Lekmap_Resources.PlaceOne(x, y, resource_key, 1) then
            return false
        end
        Lekmap_Resources.ForceFeatureAfterPlacement(resource_key, x, y, region_index)
        return true
    end

    if attempt_place() then
        return true
    end

    if TryRelaxPlotForStartBonus(plot, def) then
        Lekmap_Resources.RefreshPlotCacheAt(x, y)
        entry = plot_cache[idx]
        if attempt_place() then
            return true
        end
    end

    return false
end

------------------------------------------------------------------------------
-- FORCE-FEATURE LOGIC
-- When a resource with force_valid_feature is placed on a bare-terrain plot,
-- determine the best feature to add based on context.
------------------------------------------------------------------------------

--- Choose which feature to force based on adjacent tiles and region type.
--  @param x, y             plot coordinates
--  @param candidates       list of feature name strings (e.g. {"FEATURE_FOREST","FEATURE_JUNGLE"})
--  @param region_index     optional region number (for fallback region-type heuristic)
--  @return feature_id      engine feature ID to set, or nil
local function ChooseForceFeature(x, y, candidates, region_index)
    if #candidates == 0 then return nil end
    if #candidates == 1 then return FEATURE_LOOKUP[candidates[1]] end

    -- Count adjacent features that match any of the candidates.
    local counts = {}
    for _, f_name in ipairs(candidates) do
        counts[f_name] = 0
    end

    local center_plot = Map.GetPlot(x, y)
    if center_plot then
        for adj_plot in Lekmap_HexUtil.PlotRingIterator(center_plot, 1) do
            local adj_feature = adj_plot:GetFeatureType()
            for _, f_name in ipairs(candidates) do
                if FEATURE_LOOKUP[f_name] == adj_feature then
                    counts[f_name] = counts[f_name] + 1
                end
            end
        end
    end

    -- Pick the candidate with the highest adjacent count.
    local best_name = candidates[1]
    local best_count = counts[best_name] or 0
    for _, f_name in ipairs(candidates) do
        if (counts[f_name] or 0) > best_count then
            best_count = counts[f_name]
            best_name  = f_name
        end
    end

    -- Tie-break with region type if adjacent counts are equal.
    if best_count == 0 and region_index then
        local REGION_TYPE = Lekmap_Constants.REGION_TYPE
        local region = Lekmap_Regions.GetRegion(region_index)
        local rtype = region and region.regionType
        if rtype then
            -- Jungle-like regions prefer jungle; otherwise prefer forest.
            local prefer_jungle = (rtype == REGION_TYPE.JUNGLE or rtype == REGION_TYPE.WETLANDS)
            for _, f_name in ipairs(candidates) do
                if prefer_jungle and f_name == "FEATURE_JUNGLE" then
                    best_name = f_name
                    break
                elseif not prefer_jungle and f_name == "FEATURE_FOREST" then
                    best_name = f_name
                    break
                end
            end
        end
    end

    return FEATURE_LOOKUP[best_name]
end

--- After placing a resource on a bare plot, force the appropriate feature if
--  the resource definition has force_valid_feature defined.
--  @param resource_key   short key (e.g. "DYE")
--  @param x, y           plot coordinates
--  @param region_index   optional region number for context-aware picking
function Lekmap_Resources.ForceFeatureAfterPlacement(resource_key, x, y, region_index)
    local active_resource = Lekmap_ResourceDefs.active and Lekmap_ResourceDefs.active[resource_key]
    if not active_resource then return end
    local def = active_resource.def
    if not def.force_valid_feature then return end

    local plot = Map.GetPlot(x, y)
    if not plot then return end

    -- Only force if the plot currently has no feature.
    if plot:GetFeatureType() ~= FeatureTypes.NO_FEATURE then return end

    local feature_id = ChooseForceFeature(x, y, def.force_valid_feature, region_index)
    if feature_id then
        plot:SetFeatureType(feature_id, -1)
        -- Update the plot cache.
        local idx = y * map_width + x + 1
        if plot_cache[idx] then
            plot_cache[idx].feature_type = feature_id
        end
        print(string.format("Lekmap_Resources: Forced feature %d on (%d,%d) for %s", feature_id, x, y, resource_key))
    end
end

------------------------------------------------------------------------------
-- PLOT LIST GENERATION
------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- Generate a shuffled list of valid plot indices for a resource.
--
--  @param resource_key  short key (e.g. "IRON", "GOLD")
--  @param scope         "world" for entire map, or { x, y, radius } for near-plot
--  @return              shuffled array of 1-based plot indices
------------------------------------------------------------------------------
function Lekmap_Resources.GeneratePlotList(resource_key, scope)
    local active_resource = Lekmap_ResourceDefs.active and Lekmap_ResourceDefs.active[resource_key]
    if not active_resource then return {} end
    local def = active_resource.def

    local candidates = {}

    if scope == "world" then
        -- Scan entire world plot cache.
        for i, entry in ipairs(plot_cache) do
            if Lekmap_Resources.IsValidPlotForResource(entry, def) then
                table.insert(candidates, i)
            end
        end
    elseif type(scope) == "table" and scope.x and scope.y and scope.radius then
        -- Near-plot: scan rings around (x, y) up to radius.
        local center_plot = Map.GetPlot(scope.x, scope.y)
        if center_plot then
            for ring = 1, scope.radius do
                for ring_plot in Lekmap_HexUtil.PlotRingIterator(center_plot, ring) do
                    local rx = ring_plot:GetX()
                    local ry = ring_plot:GetY()
                    local idx = ry * map_width + rx + 1
                    local entry = plot_cache[idx]
                    if entry and Lekmap_Resources.IsValidPlotForResource(entry, def) then
                        table.insert(candidates, idx)
                    end
                end
            end
        end
    end

    -- Shuffle (Fisher-Yates).
    for i = #candidates, 2, -1 do
        local j = Map.Rand(i, "Shuffle plot list") + 1
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    return candidates
end

------------------------------------------------------------------------------
--- Generate plot lists for a resource scoped to a region rectangle.
--
--  @param resource_key   short key
--  @param region_index   1-based region number
--  @return               shuffled array of 1-based plot indices within the region
------------------------------------------------------------------------------
function Lekmap_Resources.GeneratePlotListInRegion(resource_key, region_index)
    local active_resource = Lekmap_ResourceDefs.active and Lekmap_ResourceDefs.active[resource_key]
    if not active_resource then return {} end
    local def = active_resource.def

    local region = Lekmap_Regions.GetRegion(region_index)
    if not region then return {} end

    local west_x  = region.westX
    local south_y = region.southY
    local width   = region.width
    local height  = region.height

    local candidates = {}

    for ry = 0, height - 1 do
        for rx = 0, width - 1 do
            local px = (rx + west_x) % map_width
            local py = (ry + south_y) % map_height
            local idx = py * map_width + px + 1
            local entry = plot_cache[idx]
            if entry and Lekmap_Resources.IsValidPlotForResource(entry, def) then
                table.insert(candidates, idx)
            end
        end
    end

    -- Shuffle.
    for i = #candidates, 2, -1 do
        local j = Map.Rand(i, "Shuffle region plot list") + 1
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    return candidates
end

------------------------------------------------------------------------------
-- CORE PLACEMENT FUNCTIONS
------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- Place a single resource at a specific plot and apply impact.
--
--  @param x              plot X
--  @param y              plot Y
--  @param resource_key   short key (e.g. "IRON")
--  @param quantity        resource quantity (0 for unquantified)
--  @return               true if placed successfully
------------------------------------------------------------------------------
function Lekmap_Resources.PlaceOne(x, y, resource_key, quantity)
    local active_resource = Lekmap_ResourceDefs.active and Lekmap_ResourceDefs.active[resource_key]
    if not active_resource then return false end

    local plot = Map.GetPlot(x, y)
    if plot == nil then return false end
    if plot:GetResourceType(-1) ~= -1 then return false end

    plot:SetResourceType(active_resource.id, quantity or 0)

    -- Jungle/forest etc. when RESOURCE_DEFS sets force_valid_feature (matches PlaceSpecificNumber / scatter).
    Lekmap_Resources.ForceFeatureAfterPlacement(resource_key, x, y, nil)

    -- Update tracking.
    amounts_placed[active_resource.id] = (amounts_placed[active_resource.id] or 0) + (quantity > 0 and quantity or 1)
    if active_resource.def.class == "luxury" then
        total_lux_placed = total_lux_placed + 1
    end

    -- Apply impact.
    local class_info = active_resource.classInfo
    local spacing    = class_info.default_spacing
    local min_radius = spacing.min
    local max_radius = spacing.max
    local radius     = min_radius
    if max_radius > min_radius then
        radius = min_radius + Map.Rand(max_radius - min_radius + 1, "Resource impact radius")
    end
    Lekmap_Impact.PlaceImpact(class_info.impact_layer, x, y, radius)

    -- Mark plot cache as having a resource.
    local idx = y * map_width + x + 1
    if plot_cache[idx] then
        plot_cache[idx].has_resource = true
    end

    return true
end

------------------------------------------------------------------------------
--- Place one bonus scatter instance at a cached plot index (world / regional scatter).
--  Updates amounts_placed, BONUS impact, plot_cache.has_resource, optional feature force.
--
--  @param plot_index            1-based index into plot_cache
--  @param resource_key          e.g. "WHEAT"
--  @param min_radius            BONUS impact min ripple radius
--  @param max_radius            BONUS impact max ripple radius
--  @param options               optional { ignore_bonus_impact = bool }
--  @return                      true if placed
------------------------------------------------------------------------------
function Lekmap_Resources.PlaceScatterBonusAtPlotIndex(plot_index, resource_key, min_radius, max_radius, options)
    options = options or {}
    local active = Lekmap_ResourceDefs.active and Lekmap_ResourceDefs.active[resource_key]
    if not active then
        return false
    end
    local entry = plot_cache[plot_index]
    if not entry or entry.has_resource then
        return false
    end
    local x, y = entry.x, entry.y
    if Lekmap_Resources.IsCollision(x, y) then
        return false
    end
    local IMPACT_LAYER = Lekmap_Constants.IMPACT_LAYER
    if not options.ignore_bonus_impact and Lekmap_Impact.IsImpacted(IMPACT_LAYER.BONUS, x, y) then
        return false
    end
    local plot = Map.GetPlot(x, y)
    if not plot or plot:GetResourceType(-1) ~= -1 then
        return false
    end

    plot:SetResourceType(active.id, 1)
    amounts_placed[active.id] = (amounts_placed[active.id] or 0) + 1
    if Game.GetResourceUsageType(active.id) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY then
        total_lux_placed = total_lux_placed + 1
    end

    local radius_add = 0
    if max_radius > min_radius then
        radius_add = Map.Rand(max_radius - min_radius + 1, "Scatter bonus impact radius")
    end
    Lekmap_Impact.PlaceImpact(IMPACT_LAYER.BONUS, x, y, min_radius + radius_add)
    Lekmap_Resources.ForceFeatureAfterPlacement(resource_key, x, y, nil)
    if plot_cache[plot_index] then
        plot_cache[plot_index].has_resource = true
    end
    return true
end

------------------------------------------------------------------------------
--- Place resources from a weighted entry list onto a plot list.
--  Rewrite of the original ProcessResourceList.
--
--  Entries format: array of { id, quantity, weight, min_radius, max_radius }
--  Divides plot list length by frequency to determine how many to place.
--
--  @param frequency        divider: num_plots / frequency = num_to_place
--  @param layer            Lekmap_Constants.IMPACT_LAYER constant
--  @param plot_list        shuffled array of plot indices
--  @param entries          array of resource entry tables
--  @return                 number of resources placed
------------------------------------------------------------------------------
function Lekmap_Resources.ProcessWeightedList(frequency, layer, plot_list, entries)
    if plot_list == nil or #plot_list == 0 then return 0 end
    if entries == nil or #entries == 0 then return 0 end

    local num_to_place = math.ceil(#plot_list / frequency)
    local num_placed   = 0

    -- Build cumulative weight thresholds.
    local total_weight = 0
    for _, e in ipairs(entries) do
        total_weight = total_weight + e[3]
    end
    if total_weight <= 0 then return 0 end

    local thresholds = {}
    local accumulated = 0
    for i, e in ipairs(entries) do
        accumulated = accumulated + e[3]
        thresholds[i] = accumulated * 10000 / total_weight
    end

    -- Pass 1: seek unimpacted plots.
    local current_idx = 1
    local pass_one_complete = false

    for _ = 1, num_to_place do
        -- Roll for resource type.
        local roll = Map.Rand(10000, "Choose resource type")
        local chosen_entry = 1
        for i, t in ipairs(thresholds) do
            if roll < t then
                chosen_entry = i
                break
            end
        end

        local entry = entries[chosen_entry]
        local resource_id       = entry[1]
        local resource_quantity = entry[2]
        local min_radius        = entry[4]
        local max_radius        = entry[5]
        local placed            = false

        if not pass_one_complete then
            -- Walk sequentially through unvisited plots, looking for impact == 0.
            for idx = current_idx, #plot_list do
                current_idx = idx + 1
                if idx == #plot_list then
                    pass_one_complete = true
                end

                local plot_index = plot_list[idx]
                if not Lekmap_Impact.IsImpacted(layer, plot_cache[plot_index].x, plot_cache[plot_index].y) then
                    local px = plot_cache[plot_index].x
                    local py = plot_cache[plot_index].y
                    local resource_plot = Map.GetPlot(px, py)
                    if resource_plot:GetResourceType(-1) == -1 then
                        local radius_add = 0
                        if max_radius > min_radius then
                            radius_add = Map.Rand(max_radius - min_radius + 1, "Resource radius")
                        end
                        resource_plot:SetResourceType(resource_id, resource_quantity)
                        Lekmap_Impact.PlaceImpact(layer, px, py, min_radius + radius_add)

                        amounts_placed[resource_id] = (amounts_placed[resource_id] or 0) + resource_quantity
                        if Game.GetResourceUsageType(resource_id) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY then
                            total_lux_placed = total_lux_placed + 1
                        end
                        -- Force feature if needed.
                        local rkey = Lekmap_ResourceDefs.GetKey(resource_id)
                        if rkey then
                            Lekmap_Resources.ForceFeatureAfterPlacement(rkey, px, py, nil)
                        end
                        if plot_cache[plot_index] then plot_cache[plot_index].has_resource = true end
                        placed = true
                        num_placed = num_placed + 1
                        break
                    end
                end
            end
        end

        -- Pass 2: fallback -- find plot with lowest impact value.
        if not placed and pass_one_complete then
            local lowest_impact  = 98
            local best_plot_index = nil
            for _, plot_index in ipairs(plot_list) do
                local px = plot_cache[plot_index].x
                local py = plot_cache[plot_index].y
                local val = Lekmap_Impact.GetValue(layer, px, py)
                if val < lowest_impact then
                    local resource_plot = Map.GetPlot(px, py)
                    if resource_plot:GetResourceType(-1) == -1 then
                        lowest_impact   = val
                        best_plot_index = plot_index
                    end
                end
            end
            if best_plot_index then
                local px = plot_cache[best_plot_index].x
                local py = plot_cache[best_plot_index].y
                local resource_plot = Map.GetPlot(px, py)
                local radius_add = 0
                if max_radius > min_radius then
                    radius_add = Map.Rand(max_radius - min_radius + 1, "Resource radius")
                end
                resource_plot:SetResourceType(resource_id, resource_quantity)
                Lekmap_Impact.PlaceImpact(layer, px, py, min_radius + radius_add)
                amounts_placed[resource_id] = (amounts_placed[resource_id] or 0) + resource_quantity
                -- Force feature if needed.
                local rkey2 = Lekmap_ResourceDefs.GetKey(resource_id)
                if rkey2 then
                    Lekmap_Resources.ForceFeatureAfterPlacement(rkey2, px, py, nil)
                end
                if plot_cache[best_plot_index] then plot_cache[best_plot_index].has_resource = true end
                num_placed = num_placed + 1
            end
        end
    end

    return num_placed
end

------------------------------------------------------------------------------
--- Place a specific number of one resource type from a plot list.
--  Rewrite of the original PlaceSpecificNumberOfResources.
--
--  @param resource_id      game resource ID
--  @param quantity          per-plot quantity (0 for unquantified)
--  @param amount            total number of placements desired
--  @param ratio             0..1, throttles placements vs plot list size
--  @param layer             Lekmap_Constants.IMPACT_LAYER constant (-1 to skip impact)
--  @param min_radius        minimum impact radius
--  @param max_radius        maximum impact radius
--  @param plot_list         shuffled array of plot indices
--  @return                  number left unplaced
------------------------------------------------------------------------------
function Lekmap_Resources.PlaceSpecificNumber(resource_id, quantity, amount, ratio, layer, min_radius, max_radius, plot_list)
    if plot_list == nil or #plot_list == 0 then return amount end

    local check_impact = (layer ~= nil and layer > 0)
    local num_to_place = math.min(amount, math.ceil(ratio * #plot_list))
    local num_left     = amount

    for _ = 1, num_to_place do
        for _, plot_index in ipairs(plot_list) do
            local proceed = true
            local px = plot_cache[plot_index].x
            local py = plot_cache[plot_index].y

            if check_impact and Lekmap_Impact.IsImpacted(layer, px, py) then
                proceed = false
            end

            if proceed then
                local resource_plot = Map.GetPlot(px, py)
                if resource_plot:GetResourceType(-1) == -1 then
                    resource_plot:SetResourceType(resource_id, quantity)
                    amounts_placed[resource_id] = (amounts_placed[resource_id] or 0) + (quantity > 0 and quantity or 1)
                    if Game.GetResourceUsageType(resource_id) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY then
                        total_lux_placed = total_lux_placed + 1
                    end
                    num_left = num_left - 1

                    -- Force feature if this resource supports it and plot is bare.
                    local rkey = Lekmap_ResourceDefs.GetKey(resource_id)
                    if rkey then
                        Lekmap_Resources.ForceFeatureAfterPlacement(rkey, px, py, nil)
                    end

                    if check_impact then
                        local radius_add = 0
                        if max_radius > min_radius then
                            radius_add = Map.Rand(1 + max_radius - min_radius, "Resource radius")
                        end
                        Lekmap_Impact.PlaceImpact(layer, px, py, min_radius + radius_add)
                    end
                    if plot_cache[plot_index] then plot_cache[plot_index].has_resource = true end
                    break
                end
            end
        end
    end

    return num_left
end

------------------------------------------------------------------------------
-- COLLISION DATA
------------------------------------------------------------------------------

--- Mark a plot as a collision site (player start, CS, or NW).
function Lekmap_Resources.MarkCollision(x, y)
    collision_data[y * map_width + x + 1] = true
end

--- Check if a plot is a collision site.
function Lekmap_Resources.IsCollision(x, y)
    return collision_data[y * map_width + x + 1] == true
end

--- Import collision data from spawn and NW systems.
local function ImportCollisionData()
    -- Player starts.
    local start_plots = Lekmap_Spawns.GetAllStartPlots()
    if start_plots then
        for _, sp in pairs(start_plots) do
            if sp and sp.x and sp.y then
                Lekmap_Resources.MarkCollision(sp.x, sp.y)
            end
        end
    end
end

------------------------------------------------------------------------------
-- RESOURCE TRACKING ACCESSORS
------------------------------------------------------------------------------

function Lekmap_Resources.GetAmountPlaced(resource_id)
    return amounts_placed[resource_id] or 0
end

function Lekmap_Resources.GetTotalLuxPlaced()
    return total_lux_placed
end

function Lekmap_Resources.IncrementLuxPlaced(amount)
    total_lux_placed = total_lux_placed + (amount or 1)
end

function Lekmap_Resources.GetResourceSetting()
    return resource_setting
end

function Lekmap_Resources.GetBarrenPlots()
    return barren_plots
end

function Lekmap_Resources.GetPlotCache()
    return plot_cache
end

function Lekmap_Resources.GetMapDimensions()
    return map_width, map_height
end

------------------------------------------------------------------------------
-- RESOURCE GRAPHICS FIX
------------------------------------------------------------------------------

--- Fix resource graphics (e.g. Sugar on marsh needs jungle appearance).
--  Rewrite of FixResourceGraphics from the original.
function Lekmap_Resources.FixResourceGraphics()
    local sugar_id = Lekmap_ResourceDefs.GetID("SUGAR")
    if not sugar_id then return end

    for y = 0, map_height - 1 do
        for x = 0, map_width - 1 do
            local plot = Map.GetPlot(x, y)
            if plot:GetResourceType(-1) == sugar_id then
                local feature_type = plot:GetFeatureType()
                if feature_type == FeatureTypes.FEATURE_MARSH then
                    -- Sugar on marsh displays as jungle sugar.
                    plot:SetFeatureType(FeatureTypes.FEATURE_JUNGLE, -1)
                    plot:SetFeatureType(FeatureTypes.FEATURE_MARSH, -1)
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------------------------

local initialized = false

------------------------------------------------------------------------------
--- Initialize the resource system: enum lookups, resource definitions,
--  collision data, and world plot cache.  Safe to call multiple times;
--  subsequent calls are no-ops.
--
--  Must be called before any luxury assignment or plot list generation.
--
--  @param args  table:
--      resource_setting   (number) density 1-10, default 5
------------------------------------------------------------------------------
function Lekmap_Resources.Initialize(args)
    if initialized then return end
    args = args or {}
    print("Lekmap_Resources: Initializing.")

    map_width, map_height = Map.GetGridSize()
    resource_setting = args.resource_setting or 5

    -- Build enum lookups for string-to-ID conversion.
    BuildEnumLookups()

    -- Initialize resource definitions.
    Lekmap_ResourceDefs.Initialize()
    print("Lekmap_Resources: Resource definitions initialized.")

    -- Initialize tracking.
    amounts_placed  = {}
    total_lux_placed = 0
    collision_data  = {}

    -- Import collision data from player starts.
    ImportCollisionData()

    -- Build the world plot cache.
    Lekmap_Resources.BuildWorldPlotCache()

    initialized = true
    print("Lekmap_Resources: Initialization complete.")
end

------------------------------------------------------------------------------
-- MAIN ORCHESTRATOR
------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- Main entry point for all resource placement.
--  Called by the Pangaea script after city-states and natural wonders
--  are placed.
--
--  @param args  table:
--      resource_setting   (number) density 1-10, default 5
--      startingLuxuries / starting_luxuries (number) major start regional lux count (default 3)
--      additionalStartLuxuries / additional_start_luxuries (number) extra near start (default 1)
--      guaranteedStrategics / guaranteed_strategics (bool) stored for strategics (default true)
--      start_quality      (legacy; ignored by new Lekmap_Luxuries — use starting luxuries args)
--      strategic_balance  (bool)   guarantee strategics near starts
--      coastLuxMode / coast_lux_mode (number) Option 17 — see Lekmap_Spawns + Lekmap_Luxuries
--      additionalCoastalLuxuries (number) Option 24 — extra regional scatter for coastal lux
------------------------------------------------------------------------------
function Lekmap_Resources.PlaceAll(args)
    args = args or {}
    print("Lekmap_Resources: Beginning resource placement.")

    -- Ensure initialization has happened (no-op if already called).
    Lekmap_Resources.Initialize(args)

    -- Phase 1: Luxury placement (assignment already done earlier).
    print("Lekmap_Resources: Phase 1 - Luxury placement.")
    Lekmap_Luxuries.PlaceAll(args)

    -- Phase 2: Strategic placement.
    print("Lekmap_Resources: Phase 2 - Strategic placement.")
    Lekmap_Strategics.PlaceAll(args)

    -- Phase 3: Regional start bonuses (major civs + city-states).
    print("Lekmap_Resources: Phase 3 - Bonus placement.")
    if not Lekmap_Bonus or not Lekmap_Bonus.PlaceAllMajorStartBonuses then
        include("Lekmap_Bonus")
    end
    if Lekmap_Bonus and Lekmap_Bonus.PlaceAllMajorStartBonuses then
        print("Lekmap_Bonus: Placing major start bonuses.")
        Lekmap_Bonus.PlaceAllMajorStartBonuses()
    else
        print("Lekmap_Resources: ERROR — Lekmap_Bonus not loaded or missing PlaceAllMajorStartBonuses.")
    end
    if Lekmap_Bonus and Lekmap_Bonus.PlaceAllCityStateStartBonuses then
        print("Lekmap_Bonus: Placing city-state start bonuses.")
        Lekmap_Bonus.PlaceAllCityStateStartBonuses()
    end

    local resource_setting_scatter = args.resource_setting or Lekmap_Resources.GetResourceSetting() or 5
    if Lekmap_Bonus and Lekmap_Bonus.PlaceWorldScatter then
        print("Lekmap_Bonus: World scatter (land bonuses).")
        Lekmap_Bonus.PlaceWorldScatter(resource_setting_scatter)
    end
    if Lekmap_Bonus and Lekmap_Bonus.PlaceSeaResourceScatter then
        print("Lekmap_Bonus: Sea resource scatter.")
        Lekmap_Bonus.PlaceSeaResourceScatter(resource_setting_scatter)
    end

    -- Fix graphics.
    Lekmap_Resources.FixResourceGraphics()

    -- Recalculate areas (required after terrain changes).
    Map.RecalculateAreas()

    -- Debug summary.
    Lekmap_Resources.PrintSummary()
    print("Lekmap_Resources: Resource placement complete.")
end

------------------------------------------------------------------------------
--- Debug: print resource placement summary.
------------------------------------------------------------------------------
function Lekmap_Resources.PrintSummary()
    print("--- Lekmap_Resources Placement Summary ---")
    print("  Total luxury instances placed: " .. total_lux_placed)
    local active = Lekmap_ResourceDefs.active or {}
    for key, res in pairs(active) do
        local count = amounts_placed[res.id] or 0
        if count > 0 then
            print(string.format("  %s (ID %d): %d placed", key, res.id, count))
        end
    end
    print("-------------------------------------------")
end
