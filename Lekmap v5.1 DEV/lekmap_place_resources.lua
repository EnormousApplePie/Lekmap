
--luacheck: globals LekmapPlaceResources start_plot_database GameInfo Map PlotAreaSweepIterator LekmapResourceInfos
--luacheck: globals GetShuffledCopyOfTable lekmap_resource_impacts place_impact PlotTypes table LekmapUtilities
--luacheck: ignore CENTRE_EXCLUDE CENTRE_INCLUDE DIRECTION_CLOCKWISE DIRECTION_OUTWARDS SECTOR_NORTH include GameDefines
include("PlotIterators")

LekmapPlaceResources = {}

------------------------------------------------------------------------------------------------------------------------
-- ///// Resource impact (masking layer) functions and tables
------------------------------------------------------------------------------------------------------------------------

lekmap_resource_impacts = {

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
function LekmapPlaceResources:place_impact(placed_plot, resource_id_or_layer, radius_min, radius_max)

   local radius
   if radius_min ~= radius_max then
      radius = Map.Rand(radius_max, "Random radius") + radius_min
   else
      radius = radius_min
   end

   local resource_layer
   if type(resource_id_or_layer) == "number" then
      resource_layer = self.get_appropriate_layer(placed_plot, resource_id_or_layer)
   else
      resource_layer = resource_id_or_layer
   end

   for loopPlot in PlotAreaSweepIterator(placed_plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE,
   DIRECTION_OUTWARDS, CENTRE_INCLUDE) do
      resource_layer[loopPlot] = true
   end
end
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources:check_impact(plot, resource_id_or_layer)

   local resource_layer
   if type(resource_id_or_layer) == "number" then
      resource_layer = self.get_appropriate_layer(plot, resource_id_or_layer)
   else
      resource_layer = resource_id_or_layer
   end
   if resource_layer[plot] == nil then return false end
   if resource_layer[plot] then return true end

return false end
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources.get_appropriate_layer(plot, resource_id)

   --[[ Check for the resource class and plot type to determine the appropriate impact layer automatically,
      then return the appropriate impact layer for the resource ]]
   local resource_class = LekmapResourceInfos[resource_id].ResourceClassType
   local plotType = plot:GetPlotType()

   if resource_class == "RESOURCECLASS_BONUS" then
      if plotType == PlotTypes.PLOT_OCEAN then
         return lekmap_resource_impacts.BONUS_LAYER.OCEAN
      else
         return lekmap_resource_impacts.BONUS_LAYER.LAND
      end
   elseif resource_class == "RESOURCECLASS_LUXURY" then
      if plotType == PlotTypes.PLOT_OCEAN then
         return lekmap_resource_impacts.LUXURY_LAYER.OCEAN
      else
         return lekmap_resource_impacts.LUXURY_LAYER.LAND
      end
   elseif resource_class == "RESOURCECLASS_RUSH" or resource_class == "RESOURCECLASS_MODERN" then
      if plotType == PlotTypes.PLOT_OCEAN then
         return lekmap_resource_impacts.STRATEGIC_LAYER.OCEAN
      else
         return lekmap_resource_impacts.STRATEGIC_LAYER.LAND
      end
   end

end
------------------------------------------------------------------------------------------------------------------------
-- ///// Resource placement and validity functions
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources:place_resource(plot_list, resource_id, amount_to_place, check_impact,
   place_impact, radius_min, radius_max)

   local amount_placed = 0
   while amount_placed < amount_to_place do
      if #plot_list < amount_to_place then
            amount_to_place = #plot_list
      end
      for i, plot in ipairs(plot_list) do

         if amount_placed >= amount_to_place then break end
         if check_impact then
            -- first check for impact, remove any plots that have an impact.
            if self:check_impact(plot, resource_id) then
               table.remove(plot_list, i)
               break
            end
         end
         if place_impact then
            self:place_impact(plot, resource_id, radius_min, radius_max) 
         end
         plot:SetResourceType(resource_id, 1)
         amount_placed = amount_placed + 1

      end

   end

return amount_placed end
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources:generate_valid_plots(resource_id, radius, x, y, is_soft_check, check_impact)

   local valid_plots = {}
   local center_plot = Map.GetPlot(x, y)
   for loopPlot in PlotAreaSweepIterator(center_plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE,
      DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do

      local LoopX, LoopY = loopPlot:GetX(), loopPlot:GetY()
      if loopPlot:GetResourceType() == -1
      and LekmapResourceInfos:is_valid_on(resource_id, LoopX, LoopY, is_soft_check) then
         if check_impact and self:check_impact(loopPlot, resource_id) then
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
function LekmapPlaceResources:place_luxuries()

   LekmapResourceInfos:assign_luxury_roles()
   local amount_placed = {}
   self:place_regional_luxuries_capital(amount_placed)
   self:place_regional_luxuries(amount_placed)
   self:place_city_state_luxuries()
   self:place_secondary_luxuries_capital()
   self:place_random_luxuries()

end
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources:place_regional_luxuries_capital(amount_placed)

   print("Regional Luxury List")
   for k, v in pairs(LekmapResourceInfos.regional_luxury_list) do
      print(k, LekmapResourceInfos[v].Type)
   end
   for region_number, resource_id in ipairs(LekmapResourceInfos.regional_luxury_list) do

      local amount_to_place = Map.GetCustomOption(21) or 3
      local center_plot_x = start_plot_database.startingPlots[region_number][1]
      local center_plot_y = start_plot_database.startingPlots[region_number][2]
      local center_plot = Map.GetPlot(center_plot_x, center_plot_y)

      local valid_plots = {}
      amount_placed[region_number] = 0
      -- loop trough the first ring, expanding the search area if not enough plots have been found
      for i = 1, 3 do

         if (#valid_plots < amount_to_place) or (amount_placed[region_number] >= amount_to_place) then
            amount_to_place = amount_to_place - amount_placed[region_number]
            valid_plots = self:generate_valid_plots(resource_id, i, center_plot_x, center_plot_y, true)
            local shuffled_list = GetShuffledCopyOfTable(valid_plots)
            amount_placed[region_number] = amount_placed[region_number] +
               self:place_resource(shuffled_list, resource_id, amount_to_place, false, true, 1, 1)
         else break end

      end
      self:place_impact(center_plot, lekmap_resource_impacts.LUXURY_LAYER.REGIONAL[region_number], 6, 6)

   end

return amount_placed end
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources:place_regional_luxuries(amount_placed)

   for region_number, resource_id in ipairs(LekmapResourceInfos.regional_luxury_list) do

      local amount_already_placed = amount_placed[region_number] or 0
      -- amount to place now based on number of major players.
      local amount_players = LekmapUtilities.get_number_of_players()
      local amount_to_place = (amount_players - amount_already_placed) or 3

      local center_plot_x = start_plot_database.startingPlots[region_number][1]
      local center_plot_y = start_plot_database.startingPlots[region_number][2]
      local region_plots = start_plot_database:GenerateLuxuryPlotListsInRegion(region_number)

      local placement_plots = {}
      local function CheckRegionImpact(valid_plot)
         for _, other_region in ipairs(start_plot_database.regions_sorted_by_type) do

            local other_region_number = other_region[1]
            if other_region_number ~= region_number then
               local impact_layer = lekmap_resource_impacts.LUXURY_LAYER.REGIONAL
               for _, impact_plot in ipairs(impact_layer[other_region_number]) do
                  if valid_plot:GetX() == impact_plot:GetX()
                  and valid_plot:GetY() == impact_plot:GetY() then return false end
               end
            end

         end
      return true end

      for i = 6, 15 do

         -- try the first 6 rings around the starting plot (effectively 3 rings around the capitals 3rd ring)
         -- then move outwards to the 15th ring if not enough plots have been found
         local valid_plots = self:generate_valid_plots(resource_id, i, center_plot_x, center_plot_y, true, true)
         for _, valid_plot in ipairs(valid_plots) do
            for _, region_plot in ipairs(region_plots) do
               if valid_plot:GetX() == region_plot:GetX()
               and valid_plot:GetY() == region_plot:GetY()
               and CheckRegionImpact(valid_plot) then
                  table.insert(placement_plots, valid_plot)
               break end
            end
         end
         if #placement_plots >= amount_to_place then break end

      end

      if #placement_plots < amount_to_place then amount_to_place = #placement_plots end
      -- TODO: make own region list function
      local shuffled_list = GetShuffledCopyOfTable(placement_plots)
      self:place_resource(shuffled_list, resource_id, amount_to_place, true, true, 1, 1)

   end

end
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources:place_city_state_luxuries()

   print("City-State Assigned Luxuries")
   for k, v in pairs(LekmapResourceInfos.city_state_luxury_list) do
      print(k, LekmapResourceInfos[v].Type)
   end

   for city_state = 1, start_plot_database.iNumCityStates do

      if start_plot_database.city_state_validity_table[city_state] then
         local city_plotX = start_plot_database.cityStatePlots[city_state][1]
         local city_plotY = start_plot_database.cityStatePlots[city_state][2]

         local luxury_list = LekmapResourceInfos.city_state_luxury_list
         local resource_id = luxury_list[city_state]

         if #luxury_list == 0 or resource_id == nil then
            print("No valid luxury found for city state: ", city_state, "or city state is not valid")
         else
            local valid_plots = self:generate_valid_plots(resource_id, 2, city_plotX, city_plotY, true)
            --TODO: might want to add a weight system to not have the same luxury in every city state
            local shuffled_list = GetShuffledCopyOfTable(valid_plots)
            self:place_resource(shuffled_list, resource_id, 1, false, true, 1, 1)
         end
      end

   end

end
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources:place_secondary_luxuries_capital()

   print("Secondary Luxury List")
   for k, v in pairs(LekmapResourceInfos.secondary_luxury_list) do
      print(k, LekmapResourceInfos[v].Type)
   end

   for region_number, resource_id in ipairs(LekmapResourceInfos.secondary_luxury_list) do

      local center_plot_x = start_plot_database.startingPlots[region_number][1]
      local center_plot_y = start_plot_database.startingPlots[region_number][2]
      for i = 2, 3 do
         local valid_plots = self:generate_valid_plots(resource_id, i, center_plot_x, center_plot_y, true)
         if #valid_plots > 0 then
               local shuffled_list = GetShuffledCopyOfTable(valid_plots)
               self:place_resource(shuffled_list, resource_id, 1, false, true, 1, 1)
         break end
      end

   end

end
------------------------------------------------------------------------------------------------------------------------
function LekmapPlaceResources:place_random_luxuries()

   --TODO: implement a custom target number for random luxuries
   local random_luxury_target = 50
   local amount_to_place = math.ceil(random_luxury_target / #LekmapResourceInfos.random_luxury_list)
   local amount_placed = 0
   for _, resource_id in ipairs(LekmapResourceInfos.random_luxury_list) do
      if amount_placed >= random_luxury_target then break end
      local valid_plots = start_plot_database.global_resource_plot_lists[resource_id]
      local shuffled_list = GetShuffledCopyOfTable(valid_plots)
      amount_placed = amount_placed + self:place_resource(shuffled_list, resource_id, amount_to_place, true, true, 3, 4)
   end

end
------------------------------------------------------------------------------------------------------------------------