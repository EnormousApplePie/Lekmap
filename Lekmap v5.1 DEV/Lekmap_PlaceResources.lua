
--luacheck: globals Lekmap_PlaceResources start_plot_database GameInfo Map PlotAreaSweepIterator Lekmap_ResourceInfos
--luacheck: globals GetShuffledCopyOfTable ResourceImpacts PlaceImpact PlotTypes table Lekmap_Utilities
--luacheck: ignore CENTRE_EXCLUDE CENTRE_INCLUDE DIRECTION_CLOCKWISE DIRECTION_OUTWARDS SECTOR_NORTH include
include("PlotIterators")

--determine the length of GameInfo.Resources()

Lekmap_PlaceResources = {}

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
------------------------------------------------------------------------------------------------------------------------
-- ///// Resource impact (masking layer) functions
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceImpact(placed_plot, resource_ID, radiusMin, radiusMax)

    local radius
    if radiusMin ~= radiusMax then radius = Map.Rand(radiusMax, "Random radius") + radiusMin
    else radius = radiusMin end

    local resource_layer = self.AssignAppropriateLayer(placed_plot, resource_ID)
    for loopPlot in PlotAreaSweepIterator(placed_plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE,
    DIRECTION_OUTWARDS, CENTRE_INCLUDE) do
        resource_layer[loopPlot] = true
    end
end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:CheckImpact(plot, resource_ID)

    local resource_layer = self.AssignAppropriateLayer(plot, resource_ID)
    if resource_layer[plot] == nil then return false end
    if resource_layer[plot] then return true end

return false end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources.AssignAppropriateLayer(plot, resource_ID)

    --[[ Check for the resource class and plot type to determine the appropriate impact layer automatically,
         then return the appropriate impact layer for the resource ]]
    local resource_class = Lekmap_ResourceInfos[resource_ID].ResourceClassType
    local plotType = plot:GetPlotType()

    if resource_class == "RESOURCECLASS_BONUS" then
        if plotType == PlotTypes.PLOT_OCEAN then
            return ResourceImpacts.BONUS_LAYER.OCEAN
        else return ResourceImpacts.BONUS_LAYER.LAND end
    elseif resource_class == "RESOURCECLASS_LUXURY" then
        if plotType == PlotTypes.PLOT_OCEAN then
            return ResourceImpacts.LUXURY_LAYER.OCEAN
        else return ResourceImpacts.LUXURY_LAYER.LAND end
    elseif resource_class == "RESOURCECLASS_RUSH" or resource_class == "RESOURCECLASS_MODERN" then
        if plotType == PlotTypes.PLOT_OCEAN then
            return ResourceImpacts.STRATEGIC_LAYER.OCEAN
        else return ResourceImpacts.STRATEGIC_LAYER.LAND end
    end

end
------------------------------------------------------------------------------------------------------------------------
-- ///// Resource placement and validity functions
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceResource(plot_list, resource_ID, amountToPlace, bCheckImpact, bPlaceImpact, radiusMin, radiusMax)

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
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:GenerateValidPlots(resource_ID, radius, x, y, bSoftCheck, bCheckImpact)
    local valid_plots = {}
    local center_plot = Map.GetPlot(x, y)
    for loopPlot in PlotAreaSweepIterator(center_plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE,
    DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do
        local LoopX, LoopY = loopPlot:GetX(), loopPlot:GetY()
        if loopPlot:GetResourceType() == -1
        and Lekmap_ResourceInfos:IsValidOn(resource_ID, LoopX, LoopY, bSoftCheck) then
            if bCheckImpact and self:CheckImpact(loopPlot, resource_ID) then
                print("ResourceImpacts - Impact detected, removing plot: ", LoopX, LoopY)
            else
                table.insert(valid_plots, loopPlot)
            end
        end
    end
return valid_plots end
------------------------------------------------------------------------------------------------------------------------
-- ///// Luxury placement functions
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceLuxuries()

    local amountPlaced = {}
    self:PlaceRegionalsCapital(amountPlaced)
    self:PlaceRegionals(amountPlaced)
    self:PlaceCityStateLuxuries()

end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceRegionalsCapital(amountPlaced)

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
                valid_plots = self:GenerateValidPlots(region_luxury, i, center_plotX, center_plotY)
            else break end
        end
        local shuffled_list = GetShuffledCopyOfTable(valid_plots)
        if #shuffled_list < amountToPlace then amountToPlace = #shuffled_list end

        amountPlaced[region_number] = self:PlaceResource(shuffled_list, region_luxury, amountToPlace, false, true, 1, 1)
    end

return amountPlaced end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceRegionals(amountPlaced)

    for region_number, res_ID in ipairs(start_plot_database.region_luxury_assignment) do
        local amount_already_placed = amountPlaced[region_number] or 0
        -- amount to place now based on number of major players.
        local amount_players = Lekmap_Utilities.GetNumberOfPlayers()
        local amountToPlace = (amount_players - amount_already_placed) or 3

        local center_plotX = start_plot_database.startingPlots[region_number][1]
        local center_plotY = start_plot_database.startingPlots[region_number][2]
        local region_plots = start_plot_database:GenerateLuxuryPlotListsInRegion(region_number)

        for i = 6, 10 do
            valid_plots = self:GenerateValidPlots(res_ID, i, center_plotX, center_plotY, true)
            for i, valid_plot in ipairs(valid_plots) do
                --check if the valid plot exists in the region_plots
                
            end
        end

        -- TODO: make own region list function
        local shuffled_list = GetShuffledCopyOfTable(valid_plots)
        self:PlaceResource(shuffled_list, res_ID, amountToPlace, true, true, 1, 1)
    end

end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceCityStateLuxuries()

    for city_state = 1, start_plot_database.iNumCityStates do
        if start_plot_database.city_state_validity_table[city_state] then
			local city_plotX = start_plot_database.cityStatePlots[city_state][1]
			local city_plotY = start_plot_database.cityStatePlots[city_state][2]

            local luxury_list = start_plot_database.resourceIDs_assigned_to_cs
            local luxury_valid_list = {}

            for _, resource_ID in ipairs(luxury_list) do
                local candidate_valid_plots = self:GenerateValidPlots(resource_ID, 2, city_plotX, city_plotY)
                if #candidate_valid_plots > 0 then
                    table.insert(luxury_valid_list, resource_ID)
                end
            end

            if #luxury_valid_list == 0 then
                print("No valid luxury found for city state: ", city_state)
            else
                local direcoll = Map.Rand(#luxury_valid_list, "Random luxury")
                if direcoll == 0 then direcoll = 1 end
                local chosen_resource_ID = luxury_valid_list[direcoll]
                local valid_plots = self:GenerateValidPlots(chosen_resource_ID, 2, city_plotX, city_plotY)
                --TODO: might want to add a weight system to not have the same luxury in every city state
                local shuffled_list = GetShuffledCopyOfTable(valid_plots)
                self:PlaceResource(shuffled_list, chosen_resource_ID, 1, false, true, 1, 1)
            end
        end
    end

end
------------------------------------------------------------------------------------------------------------------------