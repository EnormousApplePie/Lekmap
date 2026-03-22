------------------------------------------------------------------------------
--  FILE:     Lekmap_Luxuries.lua
--  AUTHOR:   EnormousApplePie
--  PURPOSE:  Luxury resource assignment and placement for Lekmap.
--            Assigns luxury roles (regional, city-state, random, disabled),
--            places luxuries at civ starts, in regions, and randomly.
------------------------------------------------------------------------------
--  Depends on:
--      Lekmap_Constants.lua      (IMPACT_LAYER, REGION_TYPE)
--      Lekmap_ResourceDefs.lua   (weight tables, active set, ResolveWeightTable)
--      Lekmap_Resources.lua      (GeneratePlotList, PlaceSpecificNumber, PlaceOne)
--      Lekmap_Regions.lua        (region data, types, terrain counts)
--      Lekmap_Spawns.lua         (start plots, conditions, CoastLux setting)
--      Lekmap_Impact.lua         (PlaceImpact)
--  Engine globals: Map, GameInfo, Game
------------------------------------------------------------------------------
--luacheck: globals Lekmap_Luxuries Lekmap_ResourceDefs Lekmap_Resources Lekmap_Regions
--luacheck: globals Lekmap_Spawns Lekmap_Impact Lekmap_Utilities
--luacheck: globals Lekmap_Constants
--luacheck: globals Map GameInfo Game

Lekmap_Luxuries = {}

------------------------------------------------------------------------------
-- PRIVATE STATE
------------------------------------------------------------------------------

--- Luxury assigned to each region: region_luxury[region_index] = resourceKey
local region_luxury = {}

--- Assignment tracking: how many regions share each luxury key.
local luxury_assignment_count = {}

--- Role lists (resource keys, not IDs).
local assigned_to_regions  = {}  -- keys assigned as regional luxuries
local assigned_to_cs       = {}  -- keys assigned to city states
local assigned_to_random   = {}  -- keys assigned for random distribution
local disabled_luxuries    = {}  -- keys not being placed this game

--- Unique types assigned to regions.
local num_types_assigned_to_regions = 0

------------------------------------------------------------------------------
-- TARGET NUMBER CALCULATIONS
------------------------------------------------------------------------------

--- Maximum number of regions that can share the same luxury.
function Lekmap_Luxuries.GetSplitCap(num_civs)
    if num_civs > 16 then return 2 end
    return 1
end

--- Target number of luxury types assigned to city states.
function Lekmap_Luxuries.GetCSTarget()
    local targets = {
        [GameInfo.Worlds.WORLDSIZE_DUEL.ID]     = 3,
        [GameInfo.Worlds.WORLDSIZE_TINY.ID]      = 3,
        [GameInfo.Worlds.WORLDSIZE_SMALL.ID]     = 4,
        [GameInfo.Worlds.WORLDSIZE_STANDARD.ID]  = 4,
        [GameInfo.Worlds.WORLDSIZE_LARGE.ID]     = 4,
        [GameInfo.Worlds.WORLDSIZE_HUGE.ID]      = 4,
    }
    return targets[Map.GetWorldSize()] or 4
end

--- Target number of luxury types for random distribution.
function Lekmap_Luxuries.GetRandomTarget()
    local map_width, map_height = Map.GetGridSize()
    local land_area = map_width * map_height
    local max_randoms = 30
    local base_luxury_count = 4
    if land_area < 6700 then
        max_randoms = (land_area - 720) / ((2560 - 720) / 8) + base_luxury_count
    end
    return math.floor(max_randoms)
end

--- Target luxuries to place per region, indexed by civ count.
function Lekmap_Luxuries.GetRegionTargets()
    local duel     = { [1]=1,[2]=1,[3]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1,[9]=1,[10]=1,[11]=1,[12]=1,[13]=1,[14]=1,[15]=1,[16]=1,[17]=1,[18]=1,[19]=1,[20]=1,[21]=1,[22]=1 }
    local tiny     = { [1]=0,[2]=2,[3]=2,[4]=2,[5]=2,[6]=2,[7]=1,[8]=1,[9]=1,[10]=1,[11]=1,[12]=1,[13]=1,[14]=1,[15]=1,[16]=1,[17]=1,[18]=1,[19]=1,[20]=1,[21]=1,[22]=1 }
    local small    = { [1]=0,[2]=3,[3]=3,[4]=3,[5]=4,[6]=4,[7]=4,[8]=3,[9]=2,[10]=2,[11]=2,[12]=2,[13]=1,[14]=1,[15]=1,[16]=1,[17]=1,[18]=1,[19]=1,[20]=1,[21]=1,[22]=1 }
    local standard = { [1]=0,[2]=3,[3]=3,[4]=4,[5]=4,[6]=5,[7]=5,[8]=6,[9]=5,[10]=5,[11]=4,[12]=4,[13]=3,[14]=3,[15]=2,[16]=2,[17]=1,[18]=1,[19]=1,[20]=1,[21]=1,[22]=1 }
    local large    = { [1]=0,[2]=3,[3]=4,[4]=4,[5]=5,[6]=5,[7]=5,[8]=6,[9]=6,[10]=7,[11]=6,[12]=6,[13]=5,[14]=5,[15]=4,[16]=4,[17]=3,[18]=3,[19]=2,[20]=2,[21]=2,[22]=2 }
    local huge     = { [1]=0,[2]=4,[3]=5,[4]=5,[5]=6,[6]=6,[7]=6,[8]=6,[9]=7,[10]=7,[11]=7,[12]=8,[13]=7,[14]=7,[15]=6,[16]=6,[17]=5,[18]=5,[19]=4,[20]=4,[21]=3,[22]=3 }
    local lookup = {
        [GameInfo.Worlds.WORLDSIZE_DUEL.ID]     = duel,
        [GameInfo.Worlds.WORLDSIZE_TINY.ID]      = tiny,
        [GameInfo.Worlds.WORLDSIZE_SMALL.ID]     = small,
        [GameInfo.Worlds.WORLDSIZE_STANDARD.ID]  = standard,
        [GameInfo.Worlds.WORLDSIZE_LARGE.ID]     = large,
        [GameInfo.Worlds.WORLDSIZE_HUGE.ID]      = huge,
    }
    return lookup[Map.GetWorldSize()] or standard
end

--- World luxury targets: { totalTarget, minRandomMultiplier }.
function Lekmap_Luxuries.GetWorldTargets(resource_setting)
    local sparse = {
        [GameInfo.Worlds.WORLDSIZE_DUEL.ID]     = { 14, 3 },
        [GameInfo.Worlds.WORLDSIZE_TINY.ID]      = { 24, 4 },
        [GameInfo.Worlds.WORLDSIZE_SMALL.ID]     = { 36, 4 },
        [GameInfo.Worlds.WORLDSIZE_STANDARD.ID]  = { 48, 5 },
        [GameInfo.Worlds.WORLDSIZE_LARGE.ID]     = { 60, 5 },
        [GameInfo.Worlds.WORLDSIZE_HUGE.ID]      = { 76, 6 },
    }
    local abundant = {
        [GameInfo.Worlds.WORLDSIZE_DUEL.ID]     = { 24, 3 },
        [GameInfo.Worlds.WORLDSIZE_TINY.ID]      = { 40, 4 },
        [GameInfo.Worlds.WORLDSIZE_SMALL.ID]     = { 80, 5 },
        [GameInfo.Worlds.WORLDSIZE_STANDARD.ID]  = { 80, 5 },
        [GameInfo.Worlds.WORLDSIZE_LARGE.ID]     = { 100, 5 },
        [GameInfo.Worlds.WORLDSIZE_HUGE.ID]      = { 128, 6 },
    }
    local normal = {
        [GameInfo.Worlds.WORLDSIZE_DUEL.ID]     = { 20, 3 },
        [GameInfo.Worlds.WORLDSIZE_TINY.ID]      = { 35, 4 },
        [GameInfo.Worlds.WORLDSIZE_SMALL.ID]     = { 60, 5 },
        [GameInfo.Worlds.WORLDSIZE_STANDARD.ID]  = { 60, 5 },
        [GameInfo.Worlds.WORLDSIZE_LARGE.ID]     = { 88, 5 },
        [GameInfo.Worlds.WORLDSIZE_HUGE.ID]      = { 112, 6 },
    }

    local set
    if resource_setting <= 3 then
        set = sparse
    elseif resource_setting >= 7 then
        set = abundant
    else
        set = normal
    end
    return set[Map.GetWorldSize()] or { 60, 5 }
end

------------------------------------------------------------------------------
-- WEIGHTED ROLL HELPER
------------------------------------------------------------------------------

--- Roll from a weighted list of { key, weight } pairs. Returns the chosen key.
--  Removes the chosen entry from the lists to avoid re-selection.
local function WeightedRoll(keys, weights)
    local total_weight = 0
    for _, w in ipairs(weights) do total_weight = total_weight + w end
    if total_weight <= 0 then return nil end

    local accumulated = 0
    local thresholds = {}
    for i, w in ipairs(weights) do
        accumulated = accumulated + w
        thresholds[i] = accumulated * 10000 / total_weight
    end

    local roll = Map.Rand(10000, "Luxury weighted roll")
    for i, t in ipairs(thresholds) do
        if roll < t then
            local chosen = keys[i]
            table.remove(keys, i)
            table.remove(weights, i)
            return chosen
        end
    end
    -- Fallback: last entry.
    local last = #keys
    local chosen = keys[last]
    table.remove(keys, last)
    table.remove(weights, last)
    return chosen
end

--- Test membership in a list.
local function IsMember(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

------------------------------------------------------------------------------
-- ROLE ASSIGNMENT
------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- Assign a luxury type to a specific region based on region type and weights.
--  Returns the chosen resource key (string).
------------------------------------------------------------------------------
function Lekmap_Luxuries.AssignToRegion(region_index)
    local region_type = Lekmap_Regions.GetRegionType(region_index)
    local weight_table = Lekmap_ResourceDefs.LUXURY_REGION_WEIGHTS[region_type]
    if not weight_table then
        weight_table = Lekmap_ResourceDefs.LUXURY_FALLBACK_WEIGHTS
    end

    -- Build candidate list from weight table, filtering already-capped luxuries.
    local split_cap = Lekmap_Luxuries.GetSplitCap(Lekmap_Regions.GetRegionCount())
    local keys, weights = {}, {}
    for _, entry in ipairs(weight_table) do
        local key    = entry[1]
        local weight = entry[2]
        if Lekmap_ResourceDefs.IsActive(key) then
            local count = luxury_assignment_count[key] or 0
            if count < split_cap then
                table.insert(keys, key)
                table.insert(weights, weight)
            end
        end
    end

    if #keys == 0 then
        -- Fallback: use the fallback table with no cap check.
        for _, entry in ipairs(Lekmap_ResourceDefs.LUXURY_FALLBACK_WEIGHTS) do
            if Lekmap_ResourceDefs.IsActive(entry[1]) then
                table.insert(keys, entry[1])
                table.insert(weights, entry[2])
            end
        end
    end

    if #keys == 0 then
        print("Lekmap_Luxuries: WARNING - no luxury candidates for region " .. region_index)
        return nil
    end

    local chosen = WeightedRoll(keys, weights)
    return chosen
end

------------------------------------------------------------------------------
--- Assign roles to all luxury types: regional, city-state, random, disabled.
------------------------------------------------------------------------------
function Lekmap_Luxuries.AssignRoles()
    local num_regions = Lekmap_Regions.GetRegionCount()

    -- Reset state.
    region_luxury               = {}
    luxury_assignment_count     = {}
    assigned_to_regions         = {}
    assigned_to_cs              = {}
    assigned_to_random          = {}
    disabled_luxuries           = {}
    num_types_assigned_to_regions = 0

    -- Phase 1: Assign a luxury to each region.
    for r = 1, num_regions do
        local key = Lekmap_Luxuries.AssignToRegion(r)
        if key then
            region_luxury[r] = key
            luxury_assignment_count[key] = (luxury_assignment_count[key] or 0) + 1
            if not IsMember(assigned_to_regions, key) then
                table.insert(assigned_to_regions, key)
                num_types_assigned_to_regions = num_types_assigned_to_regions + 1
            end
            print("Lekmap_Luxuries: Region " .. r .. " -> " .. key)
        end
    end

    -- Phase 2: Assign city-state exclusive luxuries.
    local cs_keys, cs_weights = {}, {}
    for _, entry in ipairs(Lekmap_ResourceDefs.LUXURY_CITY_STATE_WEIGHTS) do
        local key = entry[1]
        if Lekmap_ResourceDefs.IsActive(key) and not IsMember(assigned_to_regions, key) then
            table.insert(cs_keys, key)
            table.insert(cs_weights, entry[2])
        end
    end
    local cs_target = Lekmap_Luxuries.GetCSTarget()
    for _ = 1, math.min(cs_target, #cs_keys) do
        local chosen = WeightedRoll(cs_keys, cs_weights)
        if chosen then
            table.insert(assigned_to_cs, chosen)
        end
    end

    -- Phase 3: Assign random luxuries from remaining pool.
    local random_keys, random_weights = {}, {}
    for _, entry in ipairs(Lekmap_ResourceDefs.LUXURY_FALLBACK_WEIGHTS) do
        local key = entry[1]
        if Lekmap_ResourceDefs.IsActive(key)
        and not IsMember(assigned_to_regions, key)
        and not IsMember(assigned_to_cs, key) then
            table.insert(random_keys, key)
            table.insert(random_weights, entry[2])
        end
    end
    local random_target = Lekmap_Luxuries.GetRandomTarget()
    for _ = 1, math.min(random_target, #random_keys) do
        local chosen = WeightedRoll(random_keys, random_weights)
        if chosen then
            table.insert(assigned_to_random, chosen)
            print("Lekmap_Luxuries: " .. chosen .. " assigned to Random.")
        end
    end

    -- Phase 4: Disable remaining luxuries.
    for _, entry in ipairs(Lekmap_ResourceDefs.LUXURY_FALLBACK_WEIGHTS) do
        local key = entry[1]
        if Lekmap_ResourceDefs.IsActive(key)
        and not IsMember(assigned_to_regions, key)
        and not IsMember(assigned_to_cs, key)
        and not IsMember(assigned_to_random, key) then
            table.insert(disabled_luxuries, key)
            print("Lekmap_Luxuries: " .. key .. " disabled.")
        end
    end

    -- Debug summary.
    print("--- Lekmap_Luxuries Role Summary ---")
    print("  Regional types: " .. num_types_assigned_to_regions)
    print("  CS types: " .. #assigned_to_cs)
    print("  Random types: " .. #assigned_to_random)
    print("  Disabled types: " .. #disabled_luxuries)
    print("------------------------------------")
end

------------------------------------------------------------------------------
-- NEAR-SPAWN PLACEMENT
------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- Place the assigned regional luxury near a civ start.
--  Scans rings 1-2 first (50% ratio), then rings 1-3 (100% ratio) as fallback.
--
--  @param region_index  1-based region number
--  @param num_to_place  how many to place (default 2, 3 for Legendary)
--  @return number left unplaced
------------------------------------------------------------------------------
function Lekmap_Luxuries.PlaceAtCivStart(region_index, num_to_place)
    num_to_place = num_to_place or 2

    local key = region_luxury[region_index]
    if not key then return num_to_place end

    local start_plot = Lekmap_Spawns.GetStartPlot(region_index)
    if not start_plot then return num_to_place end

    local resource_id = Lekmap_ResourceDefs.GetID(key)
    if not resource_id then return num_to_place end

    -- Pass 1: rings 1-2, 50% ratio.
    local plot_list = Lekmap_Resources.GeneratePlotList(key, { x = start_plot.x, y = start_plot.y, radius = 2 })
    local left = Lekmap_Resources.PlaceSpecificNumber(resource_id, 1, num_to_place, 0.5, -1, 0, 0, plot_list)

    -- Pass 2: rings 1-3, 100% ratio.
    if left > 0 then
        plot_list = Lekmap_Resources.GeneratePlotList(key, { x = start_plot.x, y = start_plot.y, radius = 3 })
        left = Lekmap_Resources.PlaceSpecificNumber(resource_id, 1, left, 1.0, -1, 0, 0, plot_list)
    end

    if left > 0 then
        print("Lekmap_Luxuries: " .. left .. " of " .. key .. " unplaced at start of region " .. region_index)
    end
    return left
end

------------------------------------------------------------------------------
--- Place a city-state luxury near a city-state location.
--
--  @param x, y                    city state location
--  @param city_state_luxury_key   resource key to place (from assigned_to_cs list)
--  @return true if placed
------------------------------------------------------------------------------
function Lekmap_Luxuries.PlaceAtCityState(x, y, city_state_luxury_key)
    local IMPACT_LAYER = Lekmap_Constants.IMPACT_LAYER

    if not city_state_luxury_key then return false end

    local resource_id = Lekmap_ResourceDefs.GetID(city_state_luxury_key)
    if not resource_id then return false end

    local plot_list = Lekmap_Resources.GeneratePlotList(city_state_luxury_key, { x = x, y = y, radius = 2 })
    local left = Lekmap_Resources.PlaceSpecificNumber(resource_id, 1, 1, 1.0,
        IMPACT_LAYER.LUXURY, 3, 5, plot_list)
    return left == 0
end

------------------------------------------------------------------------------
-- WORLD PLACEMENT
------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- Place copies of the regional luxury throughout its region.
--
--  @param region_index  region number
--  @param target_count  how many to place in the region
--  @return number placed
------------------------------------------------------------------------------
function Lekmap_Luxuries.PlaceInRegion(region_index, target_count)
    local IMPACT_LAYER = Lekmap_Constants.IMPACT_LAYER

    local key = region_luxury[region_index]
    if not key or target_count <= 0 then return 0 end

    local resource_id = Lekmap_ResourceDefs.GetID(key)
    if not resource_id then return 0 end

    local plot_list = Lekmap_Resources.GeneratePlotListInRegion(key, region_index)
    local left = Lekmap_Resources.PlaceSpecificNumber(resource_id, 1, target_count, 0.5,
        IMPACT_LAYER.LUXURY, 3, 5, plot_list)

    local placed = target_count - left
    return placed
end

------------------------------------------------------------------------------
--- Place random-role luxuries across the map.
--
--  @param world_target  total luxury target for the world
--  @param min_random    minimum random multiplier
------------------------------------------------------------------------------
function Lekmap_Luxuries.PlaceRandom(world_target, min_random)
    local IMPACT_LAYER = Lekmap_Constants.IMPACT_LAYER

    local current_total = Lekmap_Resources.GetTotalLuxPlaced()
    local remaining = world_target - current_total
    if remaining <= 0 then return end

    -- Distribute evenly among random types.
    local num_random_types = #assigned_to_random
    if num_random_types == 0 then return end

    local per_type = math.max(min_random, math.ceil(remaining / num_random_types))

    for _, key in ipairs(assigned_to_random) do
        local resource_id = Lekmap_ResourceDefs.GetID(key)
        if resource_id then
            local plot_list = Lekmap_Resources.GeneratePlotList(key, "world")
            Lekmap_Resources.PlaceSpecificNumber(resource_id, 1, per_type, 0.25,
                IMPACT_LAYER.LUXURY, 3, 5, plot_list)
        end
    end
end

------------------------------------------------------------------------------
-- ORCHESTRATOR
------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- Assign luxury roles (regional, city-state, random, disabled).
--  Called EARLY in the pipeline -- before city-states are placed --
--  so that city-state logic can query GetRegionLuxury().
--  Does NOT place any resources on the map.
------------------------------------------------------------------------------
function Lekmap_Luxuries.AssignAll()
    print("Lekmap_Luxuries: Assigning luxury roles.")
    Lekmap_Luxuries.AssignRoles()
    print("Lekmap_Luxuries: Role assignment complete.")
end

------------------------------------------------------------------------------
--- Main entry point for luxury placement.
--  Called by Lekmap_Resources.PlaceAll().
--  Assumes AssignAll() has already been called.
------------------------------------------------------------------------------
function Lekmap_Luxuries.PlaceAll(args)
    args = args or {}
    print("Lekmap_Luxuries: Beginning luxury placement.")

    local num_regions      = Lekmap_Regions.GetRegionCount()
    local resource_setting = Lekmap_Resources.GetResourceSetting()
    local start_type       = args.startQuality or 0
    local num_to_place_at_start = 2
    if start_type == 1 or start_type == 2 then -- Legendary Start
        num_to_place_at_start = 3
    end

    -- Step 1: Place at civ starts.
    print("Lekmap_Luxuries: Placing at civ starts.")
    for r = 1, num_regions do
        Lekmap_Luxuries.PlaceAtCivStart(r, num_to_place_at_start)
    end

    -- Step 2: Place in regions.
    -- region_targets gives TOTAL regional lux count (capital + region combined).
    -- Subtract what was already placed at the capital to get remaining.
    print("Lekmap_Luxuries: Placing in regions.")
    local region_targets = Lekmap_Luxuries.GetRegionTargets()
    local total_target = region_targets[num_regions] or 1
    local region_extra = math.max(0, total_target - num_to_place_at_start)
    print("Lekmap_Luxuries: Total target per region = " .. total_target
        .. " (cap=" .. num_to_place_at_start .. ", region=" .. region_extra .. ")")
    for r = 1, num_regions do
        Lekmap_Luxuries.PlaceInRegion(r, region_extra)
    end

    -- Step 3: Place random luxuries.
    print("Lekmap_Luxuries: Placing random luxuries.")
    local world_data = Lekmap_Luxuries.GetWorldTargets(resource_setting)
    Lekmap_Luxuries.PlaceRandom(world_data[1], world_data[2])

    print("Lekmap_Luxuries: Luxury placement complete. Total placed: " .. Lekmap_Resources.GetTotalLuxPlaced())
end

------------------------------------------------------------------------------
-- ACCESSORS
------------------------------------------------------------------------------

function Lekmap_Luxuries.GetRegionLuxury(region_index)
    return region_luxury[region_index]
end

function Lekmap_Luxuries.GetAssignedToRegions()
    return assigned_to_regions
end

function Lekmap_Luxuries.GetAssignedToCS()
    return assigned_to_cs
end

function Lekmap_Luxuries.GetAssignedToRandom()
    return assigned_to_random
end
