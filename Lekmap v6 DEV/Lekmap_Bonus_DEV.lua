------------------------------------------------------------------------------
--  TEMP: start-area bonus refactor. Not hooked into map gen yet.
------------------------------------------------------------------------------
--luacheck: globals Lekmap_Bonus_DEV Lekmap_Spawns Lekmap_Resources Lekmap_ResourceDefs
--luacheck: globals Lekmap_Regions Lekmap_CityStates Lekmap_Utilities Map

Lekmap_Bonus_DEV = {}

local SUB = {
    GRANARY = "GRANARY",
    STABLE  = "STABLE",
    COASTAL = "COASTAL",
    QUARRY  = "QUARRY",
    OTHER   = "OTHER",
}

Lekmap_Bonus_DEV.SUBCLASS_ORDER = {
    SUB.GRANARY, SUB.STABLE, SUB.COASTAL, SUB.QUARRY, SUB.OTHER,
}

Lekmap_Bonus_DEV.SUBCLASS_POOLS = {
    [SUB.GRANARY] = { "WHEAT", "BANANA", "DEER", "BISON" },
    [SUB.STABLE]  = { "SHEEP", "COW", "MAIZE" },
    [SUB.COASTAL] = { "FISH" },
    [SUB.QUARRY]  = { "STONE" },
    [SUB.OTHER]   = { "HARDWOOD" },
}

------------------------------------------------------------------------------
-- Global defaults: subclass search rings + slot counts by map resource option (1–10).
-- Per terrain region (START_BY_REGION): major = civ starts, minor = city-state starts.
-- Each branch merges: global row -> default_slots -> slots_by_setting[setting].
-- Ring weights: per-subclass table [ring] = weight; max ring = *search_ring_by_subclass.
------------------------------------------------------------------------------
Lekmap_Bonus_DEV.START_CONFIG = {
    -- Max hex ring (distance from start) scanned for that subclass.
    major_search_ring_by_subclass = {
        GRANARY = 3, STABLE = 3, COASTAL = 3, QUARRY = 3, OTHER = 3,
    },

    -- Weight per ring 1..max (roll which ring to search first for this placement try).
    major_ring_weights_by_subclass = {
        GRANARY = { [1] = 45, [2] = 35, [3] = 20 },
        STABLE  = { [1] = 30, [2] = 35, [3] = 35 },
        COASTAL = { [1] = 25, [2] = 30, [3] = 45 },
        QUARRY  = { [1] = 25, [2] = 35, [3] = 40 },
        OTHER   = { [1] = 25, [2] = 35, [3] = 40 },
    },

    major_counts_by_resource_setting = {
        [1]  = { GRANARY = 1, STABLE = 0, COASTAL = 0, QUARRY = 0, OTHER = 0 },
        [2]  = { GRANARY = 1, STABLE = 1, COASTAL = 0, QUARRY = 0, OTHER = 0 },
        [3]  = { GRANARY = 1, STABLE = 2, COASTAL = 1, QUARRY = 0, OTHER = 1 },
        [4]  = { GRANARY = 1, STABLE = 2, COASTAL = 1, QUARRY = 1, OTHER = 1 },
        [5]  = { GRANARY = 3, STABLE = 3, COASTAL = 2, QUARRY = 2, OTHER = 2 },
        [6]  = { GRANARY = 3, STABLE = 3, COASTAL = 2, QUARRY = 2, OTHER = 2 },
        [7]  = { GRANARY = 4, STABLE = 4, COASTAL = 3, QUARRY = 3, OTHER = 3 },
        [8]  = { GRANARY = 4, STABLE = 4, COASTAL = 3, QUARRY = 3, OTHER = 3 },
        [9]  = { GRANARY = 5, STABLE = 5, COASTAL = 4, QUARRY = 4, OTHER = 4 },
        [10] = { GRANARY = 5, STABLE = 5, COASTAL = 4, QUARRY = 4, OTHER = 4 },
    },

    city_state_search_ring_by_subclass = {
        GRANARY = 2, STABLE = 2, COASTAL = 2, QUARRY = 2, OTHER = 2,
    },

    minor_ring_weights_by_subclass = {
        GRANARY = { [1] = 40, [2] = 60 },
        STABLE  = { [1] = 35, [2] = 65 },
        COASTAL = { [1] = 35, [2] = 65 },
        QUARRY  = { [1] = 35, [2] = 65 },
        OTHER   = { [1] = 35, [2] = 65 },
    },

    city_state_counts_by_resource_setting = {
        [1]  = { GRANARY = 1, STABLE = 0, COASTAL = 0, QUARRY = 0, OTHER = 0 },
        [2]  = { GRANARY = 1, STABLE = 0, COASTAL = 0, QUARRY = 0, OTHER = 0 },
        [3]  = { GRANARY = 1, STABLE = 1, COASTAL = 1, QUARRY = 0, OTHER = 0 },
        [4]  = { GRANARY = 1, STABLE = 1, COASTAL = 2, QUARRY = 0, OTHER = 0 },
        [5]  = { GRANARY = 2, STABLE = 2, COASTAL = 2, QUARRY = 1, OTHER = 1 },
        [6]  = { GRANARY = 2, STABLE = 2, COASTAL = 2, QUARRY = 1, OTHER = 1 },
        [7]  = { GRANARY = 2, STABLE = 2, COASTAL = 3, QUARRY = 2, OTHER = 2 },
        [8]  = { GRANARY = 3, STABLE = 2, COASTAL = 3, QUARRY = 2, OTHER = 2 },
        [9]  = { GRANARY = 3, STABLE = 2, COASTAL = 4, QUARRY = 3, OTHER = 3 },
        [10] = { GRANARY = 3, STABLE = 2, COASTAL = 4, QUARRY = 3, OTHER = 3 },
    },
}

--[[
  START_BY_REGION[terrain_type].major | .minor
    terrain_type: 1 TUNDRA … 9 WETLANDS (same as Lekmap_Regions.GetRegionType(region_index)).

    major  — civ start bonuses: weights, optional default_slots, optional slots_by_setting.
    minor  — city-state start bonuses: same fields, all optional.
             If minor is omitted or has no weights, minor uses major.weights for that terrain.
             If minor has no slot overrides, only city_state_counts_by_resource_setting applies.

    COASTAL subclass slots are cleared when the start is not coastal (majors: along_ocean;
    minors: AdjacentToSaltWater or passed is_coastal).

    weights — GRANARY: per-key weight (omit = 0). Single-resource pool: omit = 1; 0 = forbid.

  Merge order: global counts for that branch -> branch.default_slots -> branch.slots_by_setting[setting]
]]
Lekmap_Bonus_DEV.START_BY_REGION = {

    -- TUNDRA
    [1] = {
        major = {
            weights = {
                WHEAT = 8, COW = 10, BANANA = 0, DEER = 45, MAIZE = 0, BISON = 10, SHEEP = 20, STONE = 20, HARDWOOD = 35,
            },
        },
        -- minor = { weights = {...}, default_slots = {...}, slots_by_setting = {...} },
    },

    -- JUNGLE
    [2] = {
        major = {
            weights = {
                WHEAT = 0, COW = 15, BANANA = 55, DEER = 15, MAIZE = 0, BISON = 0, SHEEP = 15,
                STONE = 15, HARDWOOD = 35,
            },
            slots_by_setting = {
                [1]  = { GRANARY = 1, STABLE = 0 },
                [2]  = { GRANARY = 1, STABLE = 0 },
                [3]  = { GRANARY = 1, STABLE = 0 },
                [4]  = { GRANARY = 1, STABLE = 0 },
                [5]  = { GRANARY = 4, STABLE = 1 },
                [6]  = { GRANARY = 4, STABLE = 1 },
                [7]  = { GRANARY = 5, STABLE = 2 },
                [8]  = { GRANARY = 5, STABLE = 2 },
                [9]  = { GRANARY = 6, STABLE = 3 },
                [10] = { GRANARY = 6, STABLE = 3 },
            },
        },
    },

    -- FOREST
    [3] = {
        major = {
            weights = {
                WHEAT = 10, COW = 30, BANANA = 0, DEER = 35, MAIZE = 10, BISON = 5,
                STONE = 1, HARDWOOD = 35,
            },
            slots_by_setting = {
                [1]  = { OTHER = 0 },
                [2]  = { OTHER = 0 },
                [3]  = { OTHER = 0 },
                [4]  = { OTHER = 0 },
                [5]  = { OTHER = 2 },
                [6]  = { OTHER = 2 },
                [7]  = { OTHER = 3 },
                [8]  = { OTHER = 3 },
                [9]  = { OTHER = 3 },
                [10] = { OTHER = 3 },
            },
        },
    },

    -- DESERT
    [4] = {
        major = {
            weights = {
                WHEAT = 35, COW = 8, BANANA = 0, DEER = 5, MAIZE = 30, BISON = 10,
                STONE = 20, HARDWOOD = 0, SHEEP = 35,
            },
            default_slots = { OTHER = 0 },
        },
    },

    -- HILLS
    [5] = {
        major = {
            weights = {
                WHEAT = 15, COW = 10, BANANA = 0, DEER = 20, MAIZE = 12, BISON = 8,
                HARDWOOD = 0, SHEEP = 35,
            },
            default_slots = { OTHER = 0 },
            slots_by_setting = {
                [7] = { GRANARY = 2, STABLE = 2 },
                [8] = { GRANARY = 2, STABLE = 2 },
                [9] = { GRANARY = 2, STABLE = 3 },
                [10] = { GRANARY = 2, STABLE = 4, QUARRY = 1 },
            },
        },
    },

    -- PLAINS
    [6] = {
        major = {
            weights = {
                WHEAT = 30, COW = 22, BANANA = 0, DEER = 10, MAIZE = 25, BISON = 18,
                STONE = 18, HARDWOOD = 10,
            },
        },
    },

    -- GRASS
    [7] = {
        major = {
            weights = {
                WHEAT = 22, COW = 35, BANANA = 0, DEER = 12, MAIZE = 15, BISON = 22,
            },
            slots_by_setting = {
                [9]  = { GRANARY = 4, STABLE = 1 },
                [10] = { GRANARY = 4, STABLE = 2 },
            },
        },
    },

    -- HYBRID
    [8] = {
        major = {
            weights = {
                WHEAT = 20, COW = 22, BANANA = 8, DEER = 18, MAIZE = 18, BISON = 12,
                STONE = 15, HARDWOOD = 22,
            },
        },
    },

    -- WETLANDS
    [9] = {
        major = {
            weights = {
                WHEAT = 10, COW = 18, BANANA = 35, DEER = 20, MAIZE = 10, BISON = 0,
                STONE = 0,
            },
            default_slots = { QUARRY = 0 },
        },
    },
}

------------------------------------------------------------------------------

local function IsMajorStartCoastal(region_index)
    local c = Lekmap_Spawns.GetStartConditions(region_index)
    return c and c.along_ocean == true
end

local function RegionTypeForIndex(region_index)
    local r = Lekmap_Regions.GetRegionType(region_index) or 7
    if r < 1 or r > 9 then
        return 7
    end
    return r
end

local function CopySlotRow(source)
    return {
        GRANARY = source.GRANARY or 0,
        STABLE  = source.STABLE or 0,
        COASTAL = source.COASTAL or 0,
        QUARRY  = source.QUARRY or 0,
        OTHER   = source.OTHER or 0,
    }
end

local function MergeSlotRow(base, overlay)
    if not overlay then
        return base
    end
    local out = CopySlotRow(base)
    for k, v in pairs(overlay) do
        out[k] = v
    end
    return out
end

local BRANCH_MAJOR = "major"
local BRANCH_MINOR = "minor"

local function StartPackForTerrain(rtype)
    return Lekmap_Bonus_DEV.START_BY_REGION[rtype]
end

local function StartBranchTable(pack, branch)
    if not pack then
        return nil
    end
    if branch == BRANCH_MAJOR then
        return pack.major
    end
    if branch == BRANCH_MINOR then
        return pack.minor
    end
    return nil
end

--- @param branch  BRANCH_MAJOR | BRANCH_MINOR
--- @param along_coastal  if false, COASTAL subclass count is forced to 0 after merge
local function ResolvedStartSlots(rtype, setting, branch, along_coastal)
    local cfg = Lekmap_Bonus_DEV.START_CONFIG
    local global
    if branch == BRANCH_MAJOR then
        global = cfg.major_counts_by_resource_setting[setting]
            or cfg.major_counts_by_resource_setting[5]
    else
        global = cfg.city_state_counts_by_resource_setting[setting]
            or cfg.city_state_counts_by_resource_setting[5]
    end
    global = global or { GRANARY = 1, STABLE = 0, COASTAL = 0, QUARRY = 0, OTHER = 0 }

    local pack = StartPackForTerrain(rtype)
    local branch_tbl = StartBranchTable(pack, branch)
    local row = CopySlotRow(global)
    if branch_tbl then
        row = MergeSlotRow(row, branch_tbl.default_slots)
        row = MergeSlotRow(row, branch_tbl.slots_by_setting and branch_tbl.slots_by_setting[setting])
    end
    if along_coastal == false then
        row.COASTAL = 0
    end
    return row
end

local function ResolvedMajorSlots(region_index, setting)
    local rtype = RegionTypeForIndex(region_index)
    local along = IsMajorStartCoastal(region_index)
    return ResolvedStartSlots(rtype, setting, BRANCH_MAJOR, along)
end

--- @param region_number  civ region index for terrain type, or nil / <1 for uninhabited CS (uses grass 7)
local function TerrainTypeForCityStateRegion(region_number)
    if region_number and region_number >= 1 then
        return Lekmap_Regions.GetRegionType(region_number) or 7
    end
    return 7
end

--- Weights for a terrain row; minor falls back to major.weights when minor.weights is absent.
local function StartResourceWeights(rtype, branch)
    local pack = StartPackForTerrain(rtype)
    if not pack then
        return {}
    end
    if branch == BRANCH_MINOR then
        local m = pack.minor
        if m and m.weights then
            return m.weights
        end
        local maj = pack.major
        if maj and maj.weights then
            return maj.weights
        end
        return {}
    end
    local maj = pack.major
    if maj and maj.weights then
        return maj.weights
    end
    return {}
end

local function MajorResourceWeights(region_index)
    local rtype = RegionTypeForIndex(region_index)
    return StartResourceWeights(rtype, BRANCH_MAJOR)
end

local function RingForSubclass(subclass, is_city_state)
    local cfg = Lekmap_Bonus_DEV.START_CONFIG
    local tbl = is_city_state and cfg.city_state_search_ring_by_subclass
        or cfg.major_search_ring_by_subclass
    if tbl and tbl[subclass] then
        return tbl[subclass]
    end
    return 2
end

--- Weighted random ring in 1..max_ring (uniform if no weights or zero total).
local function PickSearchRing(subclass, is_city_state)
    local max_ring = RingForSubclass(subclass, is_city_state)
    if max_ring < 1 then
        return 1
    end
    local cfg = Lekmap_Bonus_DEV.START_CONFIG
    local wtbl = is_city_state and cfg.minor_ring_weights_by_subclass
        or cfg.major_ring_weights_by_subclass
    wtbl = wtbl and wtbl[subclass]
    local total = 0
    if wtbl then
        for r = 1, max_ring do
            total = total + (wtbl[r] or 0)
        end
    end
    if total <= 0 then
        return 1 + Map.Rand(max_ring, "Lekmap_Bonus_DEV ring uniform")
    end
    local roll = Map.Rand(total, "Lekmap_Bonus_DEV ring weight")
    local acc = 0
    for r = 1, max_ring do
        acc = acc + (wtbl[r] or 0)
        if roll < acc then
            return r
        end
    end
    return max_ring
end

local function BuildWeightedCandidates(pool, weight_table)
    local total = 0
    local rows = {}
    if not pool then
        return rows, 0
    end
    weight_table = weight_table or {}
    local singleton_pool = #pool == 1
    for _, key in ipairs(pool) do
        local w = weight_table[key]
        if w == nil then
            w = singleton_pool and 1 or 0
        end
        if w > 0 and Lekmap_ResourceDefs.GetID(key) then
            total = total + w
            table.insert(rows, { resource_key = key, weight = w })
        end
    end
    return rows, total
end

local function WeightedPick(rows, total)
    if total <= 0 or #rows == 0 then
        return nil
    end
    local roll = Map.Rand(total, "Lekmap_Bonus_DEV res weight")
    local acc = 0
    for _, row in ipairs(rows) do
        acc = acc + row.weight
        if roll < acc then
            return row.resource_key
        end
    end
    return rows[#rows].resource_key
end

local function PlotXYFromRingIndex(plot_index)
    if not plot_index then return nil, nil end
    local w, h = Map.GetGridSize()
    if w < 1 then return nil, nil end
    local i0 = plot_index - 1
    local y = math.floor(i0 / w)
    local x = i0 - y * w
    return x, y
end

local function TryPlaceResourceInRingResolved(start_plot, resource_key, ring, context_region_index)
    local indices = Lekmap_Resources.GetShuffledRingPlotIndices(start_plot.x, start_plot.y, ring)
    for _, plot_index in ipairs(indices) do
        local x, y = PlotXYFromRingIndex(plot_index)
        if x and y and Lekmap_Resources.TryPlaceStartBonusAtPlot(resource_key, x, y, context_region_index) then
            return true
        end
    end
    return false
end

--- One placement try for this subclass: weighted resource pick, weighted ring, intraclass fallbacks.
local function TryPlaceOneFromSubclass(start_plot, subclass, weight_table, is_city_state, context_region_index)
    local pool = Lekmap_Bonus_DEV.SUBCLASS_POOLS[subclass]
    if not pool then
        return false
    end

    local rows, total = BuildWeightedCandidates(pool, weight_table)
    if total <= 0 then
        return false
    end

    local order = {}
    local first = WeightedPick(rows, total)
    if first then
        table.insert(order, first)
    end
    table.sort(rows, function(a, b) return a.weight > b.weight end)
    for _, row in ipairs(rows) do
        if row.resource_key ~= first then
            table.insert(order, row.resource_key)
        end
    end

    for _, resource_key in ipairs(order) do
        local ring = PickSearchRing(subclass, is_city_state)
        if TryPlaceResourceInRingResolved(start_plot, resource_key, ring, context_region_index) then
            return true
        end
    end

    -- Second pass: same resources, other rings (if max_ring > 1)
    local max_ring = RingForSubclass(subclass, is_city_state)
    if max_ring > 1 then
        for _, resource_key in ipairs(order) do
            for r = 1, max_ring do
                if TryPlaceResourceInRingResolved(start_plot, resource_key, r, context_region_index) then
                    return true
                end
            end
        end
    end

    return false
end

--- @param along_coastal  if false, COASTAL subclass is skipped (fish etc.)
--- @param context_region_index  region # for feature forcing (majors); CS may pass assigned region or nil
local function PlaceStartBonusesAtPlot(start_plot, rtype, branch, along_coastal, context_region_index)
    if not start_plot or start_plot.x == nil or start_plot.y == nil then
        return 0
    end

    local setting = Lekmap_Resources.GetResourceSetting() or 5
    local is_city_state = (branch == BRANCH_MINOR)
    local counts = ResolvedStartSlots(rtype, setting, branch, along_coastal)
    local weight_table = StartResourceWeights(rtype, branch)
    local remaining = CopySlotRow(counts)
    local placed = 0

    while true do
        local placed_this_round = false
        for _, subclass in ipairs(Lekmap_Bonus_DEV.SUBCLASS_ORDER) do
            local n = remaining[subclass] or 0
            if n > 0 then
                if TryPlaceOneFromSubclass(start_plot, subclass, weight_table, is_city_state, context_region_index) then
                    remaining[subclass] = n - 1
                    placed = placed + 1
                    placed_this_round = true
                end
            end
        end
        if not placed_this_round then
            break
        end
    end

    return placed
end

function Lekmap_Bonus_DEV.PlaceMajorStartBonusForRegion(region_index)
    local start_plot = Lekmap_Spawns.GetStartPlot(region_index)
    local rtype = RegionTypeForIndex(region_index)
    local along = IsMajorStartCoastal(region_index)
    return PlaceStartBonusesAtPlot(start_plot, rtype, BRANCH_MAJOR, along, region_index)
end

function Lekmap_Bonus_DEV.PlaceAllMajorStartBonuses()
    local num_regions = Lekmap_Regions.GetRegionCount()
    for region_index = 1, num_regions do
        Lekmap_Bonus_DEV.PlaceMajorStartBonusForRegion(region_index)
    end
end

--- @param is_coastal  optional; if nil, derived from AdjacentToSaltWater(x,y)
function Lekmap_Bonus_DEV.PlaceCityStateStartBonus(cs_number, x, y, is_coastal)
    local pdata = Lekmap_CityStates.GetPlot and Lekmap_CityStates.GetPlot(cs_number)
    if not pdata and (x == nil or y == nil) then
        return 0
    end
    local px = x or (pdata and pdata.x)
    local py = y or (pdata and pdata.y)
    if px == nil or py == nil then
        return 0
    end
    local start_plot = { x = px, y = py }
    local rn = pdata and pdata.region_number
    local along = is_coastal
    if along == nil then
        along = Lekmap_Utilities.AdjacentToSaltWater(px, py)
    end
    local rtype = TerrainTypeForCityStateRegion(rn)
    local ctx = (rn and rn >= 1) and rn or nil
    return PlaceStartBonusesAtPlot(start_plot, rtype, BRANCH_MINOR, along, ctx)
end

function Lekmap_Bonus_DEV.PlaceAllCityStateStartBonuses()
    local all = Lekmap_CityStates.GetAllPlots and Lekmap_CityStates.GetAllPlots()
    if not all then
        return
    end
    for cs_number, _ in pairs(all) do
        Lekmap_Bonus_DEV.PlaceCityStateStartBonus(cs_number)
    end
end
