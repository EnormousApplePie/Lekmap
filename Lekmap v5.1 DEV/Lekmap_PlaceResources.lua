
--luacheck: globals PlaceResources start_plot_database GameInfo Map PlotAreaSweepIterator Lekmap_ResourceInfos
--luacheck: globals GetShuffledCopyOfTable
--luacheck: ignore CENTRE_EXCLUDE DIRECTION_CLOCKWISE DIRECTION_OUTWARDS SECTOR_NORTH include
include("PlotIterators")

PlaceResources = {}

function PlaceResources:PlaceLuxuries()

    function self.PlaceResource(plot_list, resource_ID, amountToPlace)
        local amountPlaced = 0
        while amountPlaced < amountToPlace do
            for _, plot in ipairs(plot_list) do
                if amountPlaced >= amountToPlace then break end
                print(plot:GetX(), plot:GetY())
                print("Placing resource: ", resource_ID)
                plot:SetResourceType(resource_ID, 1)
                amountPlaced = amountPlaced + 1
            end
        end
    return amountPlaced end

    function self.GenerateValidPlots(resource_ID, radius, x, y)
        local valid_plots = {}
        local center_plot = Map.GetPlot(x, y)
        for loopPlot in PlotAreaSweepIterator(center_plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE,
        DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do
            local LoopX, LoopY = loopPlot:GetX(), loopPlot:GetY()
            if loopPlot:GetResourceType() == -1
            and Lekmap_ResourceInfos:IsValidOn(resource_ID, LoopX, LoopY, true) then
                table.insert(valid_plots, loopPlot)
            end
        end
    return valid_plots end

    local amountPlaced = 0
    self:PlaceRegionalsCapital(amountPlaced)
end

function PlaceResources:PlaceRegionalsCapital(amountPlaced)

    for _, region_data in ipairs(start_plot_database.regions_sorted_by_type) do
        local amountToPlace = Map.GetCustomOption(21) or 5
        local region_number = region_data[1]
        local region_luxury = region_data[2]
        local center_plotX = start_plot_database.startingPlots[region_number][1]
        local center_plotY = start_plot_database.startingPlots[region_number][2]

        print(region_luxury)
        local valid_plots = {}
        -- loop trough the 3 rings, expanding the search area if not enough plots have been found
        for i = 2, 3 do
            if #valid_plots < amountToPlace then
                valid_plots = self.GenerateValidPlots(region_luxury, i, center_plotX, center_plotY)
            else break end
        end
        local shuffled_list = GetShuffledCopyOfTable(valid_plots)
        if #shuffled_list < amountToPlace then amountToPlace = #shuffled_list end

        amountPlaced = self.PlaceResource(shuffled_list, region_luxury, amountToPlace)
        --need to include impact
    end
return amountPlaced end