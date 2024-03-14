
--luacheck: globals PlaceResources start_plot_database GameInfo Map PlotAreaSweepIterator Lekmap_ResourceInfos
--luacheck: globals GetShuffledCopyOfTable ResourceImpacts PlaceImpact PlotTypes table
--luacheck: ignore CENTRE_EXCLUDE CENTRE_INCLUDE DIRECTION_CLOCKWISE DIRECTION_OUTWARDS SECTOR_NORTH include
include("PlotIterators")

--determine the length of GameInfo.Resources()

PlaceResources = {}

ResourceImpacts = {

    BONUS_LAYER = {
        OCEAN = {},
        LAND = {},
    },
    LUXURY_LAYER = {
        OCEAN = {},
        LAND = {},
    },
    STRATEGIC_LAYER = {
        OCEAN = {},
        LAND = {},
    },
    CITY_LAYER = {
        MINOR = {},
        MAJOR = {},
    },
    WONDER_LAYER = {},
}

function PlaceResources:PlaceImpact(placed_plot, resource_ID, radiusMin, radiusMax)

    local radius
    if radiusMin ~= radiusMax then
        radius = Map.Rand(radiusMax, "Random radius") + radiusMin
        print("Lekmap - PlaceResources.PlaceImpact - Radius: ", radius)
    else
        radius = radiusMin
    end

    local resource_layer = self.AssignAppropriateLayer(placed_plot, resource_ID)
    for loopPlot in PlotAreaSweepIterator(placed_plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE,
    DIRECTION_OUTWARDS, CENTRE_INCLUDE) do

        resource_layer[loopPlot] = true
    end

end

function PlaceResources:CheckImpact(plot, resource_ID)

    local resource_layer = self.AssignAppropriateLayer(plot, resource_ID)
    if resource_layer[plot] == nil then return false end
    if resource_layer[plot] then return true end

return false end

function PlaceResources.AssignAppropriateLayer(plot, resource_ID)

    -- Check for the resource class and plot type to determine the appropriate impact layer
    -- Then return the appropriate impact layer for the resource
    local resource_class = Lekmap_ResourceInfos[resource_ID].ResourceClassType
    local plotType = plot:GetPlotType()

    if resource_class == "RESOURCECLASS_BONUS" then
        if plotType == PlotTypes.PLOT_OCEAN then
            return ResourceImpacts.BONUS_LAYER.OCEAN
        else
            return ResourceImpacts.BONUS_LAYER.LAND
        end
    elseif resource_class == "RESOURCECLASS_LUXURY" then
        if plotType == PlotTypes.PLOT_OCEAN then
            return ResourceImpacts.LUXURY_LAYER.OCEAN
        else
            return ResourceImpacts.LUXURY_LAYER.LAND
        end
    elseif resource_class == "RESOURCECLASS_RUSH" or resource_class == "RESOURCECLASS_MODERN" then
        if plotType == PlotTypes.PLOT_OCEAN then
            return ResourceImpacts.STRATEGIC_LAYER.OCEAN
        else
            return ResourceImpacts.STRATEGIC_LAYER.LAND
        end
    end
end

function PlaceResources:PlaceResource(plot_list, resource_ID, amountToPlace, bCheckImpact, bPlaceImpact, radiusMin, radiusMax)

    local amountPlaced = 0
    while amountPlaced < amountToPlace do
        if #plot_list < amountToPlace then
            amountToPlace = #plot_list
            print("Not enough valid plots to place all resources:", resource_ID)
        end
        for i, plot in ipairs(plot_list) do
            if amountPlaced >= amountToPlace then break end
            if bCheckImpact then
                -- first check for impact, remove any plots that have an impact.
                if self:CheckImpact(plot, resource_ID) then
                    print("ResourceImpacts - Impact detected, removing plot: ", plot:GetX(), plot:GetY())
                    table.remove(plot_list, i)
                    break
                end
            end
            if bPlaceImpact then self:PlaceImpact(plot, resource_ID, radiusMin, radiusMax) end
            plot:SetResourceType(resource_ID, 1)
            amountPlaced = amountPlaced + 1
        end
    end
return amountPlaced end

function PlaceResources.GenerateValidPlots(resource_ID, radius, x, y, bSoftCheck)
    local valid_plots = {}
    local center_plot = Map.GetPlot(x, y)
    for loopPlot in PlotAreaSweepIterator(center_plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE,
    DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do
        local LoopX, LoopY = loopPlot:GetX(), loopPlot:GetY()
        if loopPlot:GetResourceType() == -1
        and Lekmap_ResourceInfos:IsValidOn(resource_ID, LoopX, LoopY, bSoftCheck) then
            table.insert(valid_plots, loopPlot)
        end
    end
return valid_plots end

function PlaceResources:PlaceLuxuries()

    local amountPlaced = 0
    self:PlaceRegionalsCapital(amountPlaced)
end

function PlaceResources:PlaceRegionalsCapital(amountPlaced)

    for _, region_data in ipairs(start_plot_database.regions_sorted_by_type) do
        local amountToPlace = Map.GetCustomOption(21) or 3
        local region_number = region_data[1]
        local region_luxury = region_data[2]
        local center_plotX = start_plot_database.startingPlots[region_number][1]
        local center_plotY = start_plot_database.startingPlots[region_number][2]

        local valid_plots = {}
        -- loop trough the first 2 rings, expanding the search area if not enough plots have been found
        for i = 2, 3 do
            if #valid_plots < amountToPlace then
                valid_plots = self.GenerateValidPlots(region_luxury, i, center_plotX, center_plotY)
            else break end
        end
        local shuffled_list = GetShuffledCopyOfTable(valid_plots)
        if #shuffled_list < amountToPlace then amountToPlace = #shuffled_list end

        amountPlaced = self:PlaceResource(shuffled_list, region_luxury, amountToPlace, false, true, 1, 1)
        --TODO: need to include impact
    end
return amountPlaced end

function PlaceResources:PlaceCityStateLuxuries()

    for city_state = 1, start_plot_database.iNumCityStates do
        if start_plot_database.city_state_validity_table[city_state] then
            --
        end

    end
end