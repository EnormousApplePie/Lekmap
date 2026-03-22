--luacheck: globals GameInfo globals LekmapResourceInfos globals Map start_plot_database LekmapPlaceResources
--luacheck: globals LekmapUtilities
--luacheck: ignore FeatureTypes PlotTypes TerrainTypes table

local terrain_data_table = {}
for terrain_data in GameInfo.Terrains() do
   terrain_data_table[terrain_data.ID] = terrain_data
end
local feature_data_table = {}
for feature_data in GameInfo.Features() do
   feature_data_table[feature_data.ID] = feature_data
end

LekmapResourceInfos = {}
------------------------------------------------------------------------------------------------------------------------
-- /// Initialize ResourceInfos table
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:initialize()

   -- Access the game database for resource data
   for resource_data in GameInfo.Resources() do
      local resource_id = resource_data.ID
      local resourceType = resource_data.Type
      if self[resource_id] == nil then
         self[resource_id] = {}
      end

      for row, data in pairs(resource_data) do
         self[resource_id][row] = data
      end

      self[resource_id].ValidTerrains = table.fill(false, #terrain_data_table)

      for row in GameInfo.Resource_TerrainBooleans() do
         local terrain_type = row.TerrainType
         if row.ResourceType == resourceType then
            self[resource_id].ValidTerrains[TerrainTypes[terrain_type]] = true
         end
      end

      self[resource_id].ValidFeatureTerrains = table.fill(false, #terrain_data_table)
      for row in GameInfo.Resource_FeatureTerrainBooleans() do
         local terrain_type = row.TerrainType
         if row.ResourceType == resourceType then
            self[resource_id].ValidFeatureTerrains[TerrainTypes[terrain_type]] = true
         end
      end

      self[resource_id].ValidFeatureTypes = table.fill(false, #feature_data_table)
      for row in GameInfo.Resource_FeatureBooleans() do
         local feature_type = row.FeatureType
         if row.ResourceType == resourceType then
            self[resource_id].ValidFeatureTypes[FeatureTypes[feature_type]] = true
         end
      end

      if GameInfo.Resource_Preferences ~= nil then
         self:initialize_preferences(resource_id)
      end
      self:generate_global_plot_list(resource_id)
   end

return self end
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:initialize_preferences(resource_id)

   for preference_data in GameInfo.Resource_Preferences() do
      if self[resource_id].Preferences == nil then
         self[resource_id].Preferences = {}
      end
      for row, data in pairs(preference_data) do
         if row.ResourceType == self[resource_id].Type then
            self[resource_id].Preferences[row] = data
         end
      end
   end
end
------------------------------------------------------------------------------------------------------------------------
-- /// Resource validity checks
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:is_valid_on(resource_id, x, y, is_soft_check)

   local plot = Map.GetPlot(x, y)
   local terrain_type = plot:GetTerrainType()
   local feature_type = plot:GetFeatureType()
   local plot_type = plot:GetPlotType()

   if feature_type == FeatureTypes.FEATURE_ICE
   or feature_type == self.feature_atoll
   or feature_type == FeatureTypes.FEATURE_OASIS
   or plot_type == PlotTypes.PLOT_MOUNTAIN
   or plot:IsLake() then return false end -- might want to add support for lake resources later

   -- for availability sake, only allow coastal luxuries to spawn next to land (otherwise they will be hard to reach)
   if self[resource_id].ResourceClassType == "RESOURCECLASS_LUXURY"
   and plot_type == PlotTypes.PLOT_OCEAN
   and (not plot:IsAdjacentToLand()) then return false end

   -- softcheck skips any feature/plottype checks for maximum availability
   if is_soft_check and ((self[resource_id].ValidTerrains[terrain_type]
   or self[resource_id].ValidTerrains[TerrainTypes["TERRAIN_HILL"]] and plot_type == PlotTypes.PLOT_HILLS)
   or self[resource_id].ValidFeatureTerrains[terrain_type]) then return true

   -- Resources with hills as valid terrain are valid on any terrain type with a hill
   elseif ((self[resource_id].ValidTerrains[terrain_type]
   or (self[resource_id].ValidTerrains[TerrainTypes["TERRAIN_HILL"]] and plot_type == PlotTypes.PLOT_HILLS))
   and feature_type == FeatureTypes.NO_FEATURE)
   or (self[resource_id].ValidFeatureTerrains[terrain_type]
   and self[resource_id].ValidFeatureTypes[feature_type]) then
      if self[resource_id].ValidTerrains[TerrainTypes["TERRAIN_HILL"]] then return true end
      if (plot_type == PlotTypes.PLOT_LAND and self[resource_id].Flatlands)
      or (plot_type == PlotTypes.PLOT_HILLS and self[resource_id].Hills)
      or (plot_type == PlotTypes.PLOT_OCEAN) then return true end
   end

return false end
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:generate_global_plot_list(resource_id)

   -- This function generates all global plot lists needed for resource distribution.
   local global_plot_list = LekmapUtilities.get_plots_global()
   self.global_resource_plots = {}
   if self.global_resource_plots[resource_id] == nil then
      self.global_resource_plots[resource_id] = {}
   end

   for _, plot in ipairs(global_plot_list) do
      local plotX, plotY = plot:GetX(), plot:GetY()
      local is_soft_check = false
      if self[resource_id].ResourceClassType == "RESOURCECLASS_LUXURY" then is_soft_check = true end
      if self:is_valid_on(resource_id, plotX, plotY, is_soft_check) then
         table.insert(self.global_resource_plots[resource_id], plot)
      end
   end

end
------------------------------------------------------------------------------------------------------------------------
-- /// Assign Luxury Roles functions
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:assign_luxury_roles()

   local luxury_list = {}
   for resource_id, resource_data in ipairs(self) do
      if resource_data.ResourceClassType == "RESOURCECLASS_LUXURY"
      and (not resource_data.Special) and resource_data.CivilizationType == nil
      and (not resource_data.OnlyMinorCivs) then
         table.insert(luxury_list, resource_id)
      end
   end

   self.regional_luxury_list = self:assign_region_luxuries(luxury_list)
   self.city_state_luxury_list = self:assign_city_state_luxuries(luxury_list)
   self.secondary_luxury_list = self:assign_secondary_luxuries(luxury_list)
   -- Random luxuries should always be assigned last
   self.random_luxury_list = self:assign_random_luxuries(luxury_list)

end
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:ChooseLuxury(choose_from_list, luxury_list, luxury_role_list,
   x, y , spawnAmount, instance_number, radius)

   local numberOfTries = 0
   local chosen_luxury
   repeat
      if #choose_from_list <= 0 then break end
      chosen_luxury = choose_from_list[Map.Rand(#choose_from_list, "") + 1]
      -- Check if the luxury has enough valid plots to spawn
      local valid_plots = LekmapPlaceResources:generate_valid_plots(chosen_luxury, radius, x, y, true)
      if #valid_plots >= spawnAmount then
         luxury_role_list[instance_number] = chosen_luxury
         luxury_list = LekmapUtilities.remove_from_table(luxury_list, chosen_luxury)
      else
         choose_from_list = LekmapUtilities.remove_from_table(choose_from_list, chosen_luxury)
      end
      numberOfTries = numberOfTries + 1
   until luxury_role_list[instance_number] ~= nil or numberOfTries >= #choose_from_list

end
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:assign_region_luxuries(luxury_list)

   -- here we should also implement the new luxury weight system
   local regional_luxury_list = {}
   -- TODO: Should implement a new way of creating the region and startplot tables
   for _, region_data in ipairs(start_plot_database.regions_sorted_by_type) do
      local region_number = region_data[1]
      local center_plotX = start_plot_database.startingPlots[region_number][1]
      local center_plotY = start_plot_database.startingPlots[region_number][2]
      local temporary_luxury_list = {}
      for _, resource_id in ipairs(luxury_list) do
         table.insert(temporary_luxury_list, resource_id)
      end

      for i = #temporary_luxury_list, 1, -1 do
         local resource_id = temporary_luxury_list[i]
         -- remove any luxuries that are not allowed to be a regional luxury based on the map option
         if Map.GetCustomOption(14) == 1 and self[resource_id].NoRegional then
            table.remove(temporary_luxury_list, i)
            -- if the region has a coastal start and the map option guarantees a coastal luxury,
            -- remove any non-coastal luxuries from the list
         elseif Map.GetCustomOption(17) == 1 and start_plot_database.startLocationConditions[region_number][1] then
            if not (self[resource_id].ValidTerrains[TerrainTypes["TERRAIN_COAST"]]) then
               if not (self[resource_id].ValidFeatureTerrains[TerrainTypes["TERRAIN_COAST"]]) then
                  table.remove(temporary_luxury_list, i)
               end
            end
         end
      end

      local spawnAmount = Map.GetCustomOption(21) or 3
      self:ChooseLuxury(temporary_luxury_list, luxury_list, regional_luxury_list, center_plotX, center_plotY, spawnAmount, region_number, 3)
    end

return regional_luxury_list end
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:assign_city_state_luxuries(luxury_list)

   local temporary_luxury_list = {}
   -- Pool of luxuries for city-states to choose from is based on the number of city-states, max 8.
   for _ = 1, math.min(8, math.ceil(start_plot_database.iNumCityStates / 2)) do
      local random_luxury = luxury_list[Map.Rand(#luxury_list, "") + 1]
      table.insert(temporary_luxury_list, random_luxury)
   end

   local city_state_luxury_list = {}
   for city_state = 1, start_plot_database.iNumCityStates do
      if start_plot_database.city_state_validity_table[city_state] then
         local city_plot_x = start_plot_database.cityStatePlots[city_state][1]
         local city_plot_y = start_plot_database.cityStatePlots[city_state][2]
         self:ChooseLuxury(temporary_luxury_list, luxury_list, city_state_luxury_list, city_plot_x, city_plot_y, 1, city_state, 2)
      end
   end

return city_state_luxury_list end
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:assign_secondary_luxuries(luxury_list)

   local secondary_luxury_list = {}
   for _, region_data in ipairs(start_plot_database.regions_sorted_by_type) do
      -- TODO: Should implement region weights
      local region_number = region_data[1]
      local city_plot_x = start_plot_database.startingPlots[region_number][1]
      local city_plot_y = start_plot_database.startingPlots[region_number][2]
      local temporary_luxury_list = luxury_list
      self:ChooseLuxury(temporary_luxury_list, luxury_list, secondary_luxury_list, city_plot_x, city_plot_y, 1, region_number, 3)
   end

return secondary_luxury_list end
------------------------------------------------------------------------------------------------------------------------
function LekmapResourceInfos:assign_random_luxuries(luxury_list)

   -- TODO: Make random luxuries use region weights.
   local random_luxury_list = {}

   -- Put every remaining item in the list
   for _, resource_id in ipairs(luxury_list) do
      table.insert(random_luxury_list, resource_id)
      table.remove(luxury_list, resource_id)
   end

return random_luxury_list end

return LekmapResourceInfos
