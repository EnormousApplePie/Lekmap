
--luacheck: globals Lekmap_PlaceResources start_plot_database GameInfo Map PlotAreaSweepIterator Lekmap_ResourceInfos
--luacheck: globals GetShuffledCopyOfTable Lekmap_ResourceImpacts PlaceImpact PlotTypes table Lekmap_Utilities
--luacheck: ignore CENTRE_EXCLUDE CENTRE_INCLUDE DIRECTION_CLOCKWISE DIRECTION_OUTWARDS SECTOR_NORTH include GameDefines
include("PlotIterators")

Lekmap_PlaceResources = {}

------------------------------------------------------------------------------------------------------------------------
-- ///// Resource impact (masking layer) functions and tables
------------------------------------------------------------------------------------------------------------------------

Lekmap_ResourceImpacts = {

    BONUS_LAYER = {
        OCEAN = {},
        LAND = {},
    },
    LUXURY_LAYER = {
        OCEAN = {},
        LAND = {},
        REGIONAL = table.fill({}, GameDefines.MAX_MAJOR_CIVS),
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
-- This function automatically determines the appropriate impact layer for the resource type entered.
-- However you can choose to manually enter the layer as well rather than the resource ID.
function Lekmap_PlaceResources:PlaceImpact(placed_plot, resource_ID_or_layer, radiusMin, radiusMax)

    local radius
    if radiusMin ~= radiusMax then radius = Map.Rand(radiusMax, "Random radius") + radiusMin
    else radius = radiusMin end
    print(resource_ID_or_layer)
    local resource_layer
    if type(resource_ID_or_layer) == "number" then
        resource_layer = self.AssignAppropriateLayer(placed_plot, resource_ID_or_layer)
    else resource_layer = resource_ID_or_layer end

    for loopPlot in PlotAreaSweepIterator(placed_plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE,
    DIRECTION_OUTWARDS, CENTRE_INCLUDE) do
        resource_layer[loopPlot] = true
    end
end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:CheckImpact(plot, resource_ID_or_layer)

    local resource_layer
    if type(resource_ID_or_layer) == "number" then
        resource_layer = self.AssignAppropriateLayer(plot, resource_ID_or_layer)
    else resource_layer = resource_ID_or_layer end
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
            return Lekmap_ResourceImpacts.BONUS_LAYER.OCEAN
        else return Lekmap_ResourceImpacts.BONUS_LAYER.LAND end
    elseif resource_class == "RESOURCECLASS_LUXURY" then
        if plotType == PlotTypes.PLOT_OCEAN then
            return Lekmap_ResourceImpacts.LUXURY_LAYER.OCEAN
        else return Lekmap_ResourceImpacts.LUXURY_LAYER.LAND end
    elseif resource_class == "RESOURCECLASS_RUSH" or resource_class == "RESOURCECLASS_MODERN" then
        if plotType == PlotTypes.PLOT_OCEAN then
            return Lekmap_ResourceImpacts.STRATEGIC_LAYER.OCEAN
        else return Lekmap_ResourceImpacts.STRATEGIC_LAYER.LAND end
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
        end
        for i, plot in ipairs(plot_list) do
            if amountPlaced >= amountToPlace then break end
            if bCheckImpact then
                -- first check for impact, remove any plots that have an impact.
                if self:CheckImpact(plot, resource_ID) then
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

    Lekmap_ResourceInfos:AssignLuxuryRoles()
    local amountPlaced = {}
    self:PlaceRegionalsCapital(amountPlaced)
    self:PlaceRegionals(amountPlaced)
    self:PlaceCityStateLuxuries()
    self:PlaceSecondaryLuxCapital()
    self:PlaceRandomLuxuries()

end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceRegionalsCapital(amountPlaced)

    print("Regional Luxury List")
    for k, v in pairs(Lekmap_ResourceInfos.regional_luxury_list) do
        print(k, Lekmap_ResourceInfos[v].Type)
    end
    for region_number, resource_ID in ipairs(Lekmap_ResourceInfos.regional_luxury_list) do
        local amountToPlace = Map.GetCustomOption(21) or 3
        local center_plotX = start_plot_database.startingPlots[region_number][1]
        local center_plotY = start_plot_database.startingPlots[region_number][2]
        local center_plot = Map.GetPlot(center_plotX, center_plotY)

        local valid_plots = {}
        amountPlaced[region_number] = 0
        -- loop trough the first ring, expanding the search area if not enough plots have been found
        for i = 1, 3 do
            if (#valid_plots < amountToPlace) or (amountPlaced[region_number] >= amountToPlace) then
                amountToPlace = amountToPlace - amountPlaced[region_number]
                valid_plots = self:GenerateValidPlots(resource_ID, i, center_plotX, center_plotY, true)
                local shuffled_list = GetShuffledCopyOfTable(valid_plots)
                amountPlaced[region_number] = amountPlaced[region_number] + self:PlaceResource(
                    shuffled_list, resource_ID, amountToPlace, false, true, 1, 1)
            else break end
        end
        self:PlaceImpact(center_plot, Lekmap_ResourceImpacts.LUXURY_LAYER.REGIONAL[region_number], 6, 6)
    end

return amountPlaced end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceRegionals(amountPlaced)

    for region_number, resource_ID in ipairs(Lekmap_ResourceInfos.regional_luxury_list) do
        local amount_already_placed = amountPlaced[region_number] or 0
        -- amount to place now based on number of major players.
        local amount_players = Lekmap_Utilities.GetNumberOfPlayers()
        local amountToPlace = (amount_players - amount_already_placed) or 3

        local center_plotX = start_plot_database.startingPlots[region_number][1]
        local center_plotY = start_plot_database.startingPlots[region_number][2]
        local region_plots = start_plot_database:GenerateLuxuryPlotListsInRegion(region_number)

        local placement_plots = {}
        local function CheckRegionImpact(valid_plot)
            for _, other_region in ipairs(start_plot_database.regions_sorted_by_type) do
                local other_region_number = other_region[1]
                if other_region_number ~= region_number then
                    local impact_layer = Lekmap_ResourceImpacts.LUXURY_LAYER.REGIONAL
                    for _, impact_plot in ipairs(impact_layer[other_region_number]) do
                        if valid_plot:GetX() == impact_plot:GetX()
                        and valid_plot:GetY() == impact_plot:GetY() then
                        return false end
                    end
                end
            end
        return true end
        for i = 6, 15 do
            -- try the first 6 rings around the starting plot (effectively 3 rings around the capitals 3rd ring)
            -- then move outwards to the 15th ring if not enough plots have been found
            local valid_plots = self:GenerateValidPlots(resource_ID, i, center_plotX, center_plotY, true, true)
            for _, valid_plot in ipairs(valid_plots) do
                for _, region_plot in ipairs(region_plots) do
                    if valid_plot:GetX() == region_plot:GetX()
                    and valid_plot:GetY() == region_plot:GetY()
                    and CheckRegionImpact(valid_plot) then
                        table.insert(placement_plots, valid_plot)
                    break end
                end
            end
            if #placement_plots >= amountToPlace then break end
        end

        if #placement_plots < amountToPlace then amountToPlace = #placement_plots end
        -- TODO: make own region list function
        local shuffled_list = GetShuffledCopyOfTable(placement_plots)
        self:PlaceResource(shuffled_list, resource_ID, amountToPlace, true, true, 1, 1)
    end

end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceCityStateLuxuries()

    for k, v in pairs(Lekmap_ResourceInfos.city_state_luxury_list) do
        print(k, Lekmap_ResourceInfos[v].Type)
    end
    for city_state = 1, start_plot_database.iNumCityStates do
        if start_plot_database.city_state_validity_table[city_state] then
			local city_plotX = start_plot_database.cityStatePlots[city_state][1]
			local city_plotY = start_plot_database.cityStatePlots[city_state][2]

            local luxury_list = Lekmap_ResourceInfos.city_state_luxury_list

            if #luxury_list == 0 then
                print("No valid luxury found for city state: ", city_state)
            else
                local direcoll = Map.Rand(#luxury_list, "Random luxury") + 1
                print(direcoll, luxury_list[direcoll])
                local chosen_resource_ID = luxury_list[direcoll]
                local valid_plots = self:GenerateValidPlots(chosen_resource_ID, 2, city_plotX, city_plotY)
                --TODO: might want to add a weight system to not have the same luxury in every city state
                local shuffled_list = GetShuffledCopyOfTable(valid_plots)
                self:PlaceResource(shuffled_list, chosen_resource_ID, 1, false, true, 1, 1)
            end
        end
    end

end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceSecondaryLuxCapital()

    for region_number, resource_ID in ipairs(Lekmap_ResourceInfos.secondary_luxury_list) do

        local center_plotX = start_plot_database.startingPlots[region_number][1]
        local center_plotY = start_plot_database.startingPlots[region_number][2]

        for i = 2, 3 do
            local valid_plots = self:GenerateValidPlots(resource_ID, i, center_plotX, center_plotY, true)
            if #valid_plots > 0 then
                local shuffled_list = GetShuffledCopyOfTable(valid_plots)
                self:PlaceResource(shuffled_list, resource_ID, 1, false, true, 1, 1)
            break end
        end

    end

end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_PlaceResources:PlaceRandomLuxuries()

    --TODO: implement a custom target number for random luxuries
    local random_luxury_target = 50
    local amountToPlace = math.ceil(random_luxury_target / #Lekmap_ResourceInfos.random_luxury_list)
    local amountPlaced = 0
    for _, resource_ID in ipairs(Lekmap_ResourceInfos.random_luxury_list) do
        if amountPlaced >= random_luxury_target then break end
        local valid_plots = start_plot_database.global_resource_plot_lists[resource_ID]
        local shuffled_list = GetShuffledCopyOfTable(valid_plots)
        amountPlaced = amountPlaced + self:PlaceResource(shuffled_list, resource_ID, amountToPlace, true, true, 3, 4)
    end

end
------------------------------------------------------------------------------------------------------------------------