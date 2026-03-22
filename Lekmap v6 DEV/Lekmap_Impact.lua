------------------------------------------------------------------------------
--  FILE:     Lekmap_Impact.lua
--  AUTHOR:   EnormousApplePie
--  PURPOSE:  Impact and ripple data layer system for Lekmap.
--            Tracks "claimed" hexes per layer to prevent resource clustering
--            and maintain spacing between start locations, city states, and
--            natural wonders.
--
--            Each layer is a flat array of integers.  A value of 0 means the
--            plot is unclaimed.  99 marks a direct impact site.  Values
--            between 1 and 98 are ripple strengths (lower = farther away).
--            Overlapping ripples are combined to discourage dense packing.
------------------------------------------------------------------------------
--  Depends on:
--      Lekmap_Constants.lua   (Lekmap_Constants.IMPACT_LAYER)
--      Lekmap_HexUtil.lua     (PlotRingIterator)
--  Engine globals: Map
------------------------------------------------------------------------------
--luacheck: globals Lekmap_Impact Lekmap_Constants Lekmap_HexUtil Map

Lekmap_Impact = {}

------------------------------------------------------------------------------
-- PRIVATE STATE
------------------------------------------------------------------------------
local layers     = {}   -- layers[layer_id] = flat integer array
local map_width  = 0    -- cached at init
local map_height = 0    -- cached at init

------------------------------------------------------------------------------
-- NAMED CONSTANTS
------------------------------------------------------------------------------
local IMPACT_CENTER         = 99   -- value written at the impact site itself
local DEFAULT_OVERLAP_BONUS = 2    -- additive bonus when ripples overlap
local DEFAULT_OVERLAP_CAP   = 50   -- max value from overlap accumulation
local LAYER_COUNT           = 6    -- must match Lekmap_Constants.IMPACT_LAYER size

------------------------------------------------------------------------------
-- INTERNAL HELPERS
------------------------------------------------------------------------------

--- Convert (x, y) to a 1-based flat index.
local function PlotIndex(x, y)
    return y * map_width + x + 1
end

--- Apply a single ripple value to one plot in a layer, handling overlap.
--- @param  data          the layer array
--- @param  index         1-based flat index of the target plot
--- @param  ripple_value  base ripple strength for this ring
--- @param  flat          if true, just stamp the value (no overlap math)
--- @param  bonus         additive overlap bonus   (ignored when flat)
--- @param  scale         multiplicative overlap    (ignored when flat; nil = use additive)
--- @param  cap           maximum value after overlap
local function ApplyRipple(data, index, ripple_value, flat, bonus, scale, cap)
    if flat then
        data[index] = ripple_value
        return
    end

    local existing = data[index]
    if existing > 0 then
        local stronger = math.max(existing, ripple_value)
        if scale then
            data[index] = math.min(cap, math.floor(stronger * scale))
        else
            data[index] = math.min(cap, stronger + bonus)
        end
    else
        data[index] = ripple_value
    end
end

--- Walk every plot on hex ring at the given distance around (center_x,
--- center_y) and apply a ripple.
local function WalkRing(data, center_x, center_y, ring, ripple_value, flat, bonus, scale, cap)
    local center_plot = Map.GetPlot(center_x, center_y)
    if center_plot == nil then return end

    for ring_plot in Lekmap_HexUtil.PlotRingIterator(center_plot, ring) do
        local rx    = ring_plot:GetX()
        local ry    = ring_plot:GetY()
        local index = PlotIndex(rx, ry)
        ApplyRipple(data, index, ripple_value, flat, bonus, scale, cap)
    end
end

------------------------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------------------------

--- Allocate (or reset) all impact layers to zero.
--- Must be called once after the map grid is available.
function Lekmap_Impact.Initialize()
    map_width, map_height = Map.GetGridSize()
    local size = map_width * map_height
    for layer_id = 1, LAYER_COUNT do
        layers[layer_id] = {}
        for plot_index = 1, size do
            layers[layer_id][plot_index] = 0
        end
    end
    print("Lekmap_Impact: initialized " .. LAYER_COUNT .. " layers (" .. size .. " plots each).")
end

------------------------------------------------------------------------------
--- Place an impact at (x, y) on a single layer with outward ripples.
---
--- @param  layer    layer constant (1-6)
--- @param  x        plot X coordinate
--- @param  y        plot Y coordinate
--- @param  radius   number of ripple rings (0 = center only)
--- @param  options  (optional) table to customise ripple behaviour:
---     center_value  : value at center          (default 99)
---     flat          : all ripples = 1, no overlap math (default false)
---     ripple_values : array of explicit per-ring values (overrides decay)
---     overlap_bonus : additive overlap          (default 2; ignored if scale set)
---     overlap_scale : multiplicative overlap    (e.g. 1.4 for player spawns)
---     overlap_cap   : maximum after overlap     (default 50)
------------------------------------------------------------------------------
function Lekmap_Impact.PlaceImpact(layer, x, y, radius, options)
    local data = layers[layer]
    if data == nil then
        print("Lekmap_Impact.PlaceImpact: invalid layer " .. tostring(layer))
        return
    end

    local opts          = options or {}
    local center_value  = opts.center_value  or opts.centerValue  or IMPACT_CENTER
    local flat          = opts.flat          or false
    local ripple_values = opts.ripple_values or opts.rippleValues or nil
    local bonus         = opts.overlap_bonus or opts.overlapBonus or DEFAULT_OVERLAP_BONUS
    local scale         = opts.overlap_scale or opts.overlapScale or nil
    local cap           = opts.overlap_cap   or opts.overlapCap   or DEFAULT_OVERLAP_CAP

    -- Stamp the center.
    local center_index  = PlotIndex(x, y)
    data[center_index]  = center_value

    if radius <= 0 then return end

    -- Walk outward rings.
    for ring = 1, radius do
        local ripple_value
        if ripple_values then
            ripple_value = ripple_values[ring] or 1
        elseif flat then
            ripple_value = 1
        else
            ripple_value = radius - ring + 1
        end
        WalkRing(data, x, y, ring, ripple_value, flat, bonus, scale, cap)
    end
end

------------------------------------------------------------------------------
--- Place the same impact on multiple layers simultaneously.
---
--- @param  layer_list  array of layer constants
--- @param  x           plot X coordinate
--- @param  y           plot Y coordinate
--- @param  radius      number of ripple rings
--- @param  options     (optional) same as PlaceImpact
------------------------------------------------------------------------------
function Lekmap_Impact.PlaceImpactMulti(layer_list, x, y, radius, options)
    for _, layer in ipairs(layer_list) do
        Lekmap_Impact.PlaceImpact(layer, x, y, radius, options)
    end
end

------------------------------------------------------------------------------
--- Place an impact on a single layer within a region rectangle only.
--- Ripples that fall outside the region bounds are discarded.
---
--- @param  layer          layer constant
--- @param  x              plot X coordinate
--- @param  y              plot Y coordinate
--- @param  radius         number of ripple rings
--- @param  west_x         western edge of the region
--- @param  south_y        southern edge of the region
--- @param  region_width   region width in tiles
--- @param  region_height  region height in tiles
--- @param  options        (optional) same as PlaceImpact
------------------------------------------------------------------------------
function Lekmap_Impact.PlaceRegionalImpact(layer, x, y, radius, west_x, south_y, region_width, region_height, options)
    local data = layers[layer]
    if data == nil then
        print("Lekmap_Impact.PlaceRegionalImpact: invalid layer " .. tostring(layer))
        return
    end

    local opts          = options or {}
    local center_value  = opts.center_value  or opts.centerValue  or IMPACT_CENTER
    local flat          = opts.flat          or false
    local ripple_values = opts.ripple_values or opts.rippleValues or nil
    local bonus         = opts.overlap_bonus or opts.overlapBonus or DEFAULT_OVERLAP_BONUS
    local scale         = opts.overlap_scale or opts.overlapScale or nil
    local cap           = opts.overlap_cap   or opts.overlapCap   or DEFAULT_OVERLAP_CAP

    local wraps_x   = Map:IsWrapX()
    local east_x    = (west_x + region_width - 1) % map_width
    local north_y   = south_y + region_height - 1

    local function InRegion(px, py)
        if py < south_y or py > north_y then return false end
        if wraps_x then
            if west_x <= east_x then
                return px >= west_x and px <= east_x
            else
                return px >= west_x or px <= east_x
            end
        else
            return px >= west_x and px < west_x + region_width
        end
    end

    if InRegion(x, y) then
        data[PlotIndex(x, y)] = center_value
    end

    if radius <= 0 then return end

    local center_plot = Map.GetPlot(x, y)
    if center_plot == nil then return end

    for ring = 1, radius do
        local ripple_value
        if ripple_values then
            ripple_value = ripple_values[ring] or 1
        elseif flat then
            ripple_value = 1
        else
            ripple_value = radius - ring + 1
        end
        for ring_plot in Lekmap_HexUtil.PlotRingIterator(center_plot, ring) do
            local rx = ring_plot:GetX()
            local ry = ring_plot:GetY()
            if InRegion(rx, ry) then
                ApplyRipple(data, PlotIndex(rx, ry), ripple_value, flat, bonus, scale, cap)
            end
        end
    end
end

------------------------------------------------------------------------------
--- Place a coastal-aware impact on the CITY_STATE layer.
---
--- Behaviour:
---   1) Stamp center with 99, then flat-fill rings 1..inner_radius (all = 1).
---   2) Walk rings 1..outer_radius.  For each coastal land plot found,
---      expand the CITY_STATE impact outward by expand_radius from that
---      coastal plot (flat = 1).
---
--- @param  x              impact center X
--- @param  y              impact center Y
--- @param  inner_radius   standard CS exclusion radius (flat, value = 1)
--- @param  outer_radius   scan radius for coastal expansion
--- @param  expand_radius  how far each coastal plot expands the exclusion
------------------------------------------------------------------------------
function Lekmap_Impact.PlaceCoastalImpact(x, y, inner_radius, outer_radius, expand_radius)
    local IMPACT_LAYER = Lekmap_Constants.IMPACT_LAYER
    local city_state_layer = IMPACT_LAYER.CITY_STATE
    local data = layers[city_state_layer]
    if data == nil then return end

    local flat_options = { flat = true, center_value = IMPACT_CENTER }

    Lekmap_Impact.PlaceImpact(city_state_layer, x, y, inner_radius, flat_options)

    if outer_radius <= 0 then return end

    local center_plot = Map.GetPlot(x, y)
    if center_plot == nil then return end

    local coastal_expand_options = { flat = true, center_value = IMPACT_CENTER }

    for ring = 1, outer_radius do
        for ring_plot in Lekmap_HexUtil.PlotRingIterator(center_plot, ring) do
            if ring_plot:IsCoastalLand() then
                local coastal_x = ring_plot:GetX()
                local coastal_y = ring_plot:GetY()
                Lekmap_Impact.PlaceImpact(city_state_layer, coastal_x, coastal_y, expand_radius, coastal_expand_options)
            end
        end
    end
end

------------------------------------------------------------------------------
--- Read the current impact value at a plot on a given layer.
--- @param  layer  layer constant (1-6)
--- @param  x      plot X coordinate
--- @param  y      plot Y coordinate
--- @return impact value (0 if unclaimed or invalid)
------------------------------------------------------------------------------
function Lekmap_Impact.GetValue(layer, x, y)
    local data = layers[layer]
    if data == nil then return 0 end
    return data[PlotIndex(x, y)] or 0
end

------------------------------------------------------------------------------
--- Check whether a plot has any impact (value > 0) on a given layer.
--- @param  layer  layer constant (1-6)
--- @param  x      plot X coordinate
--- @param  y      plot Y coordinate
--- @return true if impacted
------------------------------------------------------------------------------
function Lekmap_Impact.IsImpacted(layer, x, y)
    return Lekmap_Impact.GetValue(layer, x, y) > 0
end

------------------------------------------------------------------------------
--- Reset a single layer to all zeros.
--- @param  layer  layer constant (1-6)
------------------------------------------------------------------------------
function Lekmap_Impact.ClearLayer(layer)
    local data = layers[layer]
    if data == nil then return end
    for plot_index = 1, map_width * map_height do
        data[plot_index] = 0
    end
end

------------------------------------------------------------------------------
--- Reset all layers to all zeros.
------------------------------------------------------------------------------
function Lekmap_Impact.ClearAll()
    for layer_id = 1, LAYER_COUNT do
        Lekmap_Impact.ClearLayer(layer_id)
    end
end

------------------------------------------------------------------------------
--- Debug: print summary of non-zero values in a layer.
--- @param  layer  layer constant (1-6)
------------------------------------------------------------------------------
function Lekmap_Impact.PrintLayerSummary(layer)
    local data = layers[layer]
    if data == nil then
        print("Lekmap_Impact.PrintLayerSummary: invalid layer " .. tostring(layer))
        return
    end
    local impacted_count = 0
    local max_value = 0
    for plot_index = 1, map_width * map_height do
        if data[plot_index] > 0 then
            impacted_count = impacted_count + 1
            if data[plot_index] > max_value then
                max_value = data[plot_index]
            end
        end
    end
    print("  Layer " .. tostring(layer) .. ": " .. impacted_count .. " impacted plots, max value = " .. max_value)
end

------------------------------------------------------------------------------
--- Debug: print summary of all layers.
------------------------------------------------------------------------------
function Lekmap_Impact.PrintAllSummaries()
    print("Lekmap_Impact layer summaries:")
    for layer_id = 1, LAYER_COUNT do
        Lekmap_Impact.PrintLayerSummary(layer_id)
    end
end
