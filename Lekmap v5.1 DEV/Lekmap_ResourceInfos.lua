--luacheck: globals GameInfo globals Lekmap_ResourceInfos globals Map start_plot_database Lekmap_PlaceResources
--luacheck: globals Lekmap_Utilities
--luacheck: ignore FeatureTypes PlotTypes TerrainTypes table

local TerrainData = {}
for terrain_data in GameInfo.Terrains() do
    TerrainData[terrain_data.ID] = terrain_data
end
local FeatureData = {}
for feature_data in GameInfo.Features() do
    FeatureData[feature_data.ID] = feature_data
end

Lekmap_ResourceInfos = {}
------------------------------------------------------------------------------------------------------------------------
-- /// Initialize ResourceInfos table
------------------------------------------------------------------------------------------------------------------------
function Lekmap_ResourceInfos:Initialize()

    -- Access the game database for resource data
    for resource_data in GameInfo.Resources() do
        local resource_ID = resource_data.ID
        local resourceType = resource_data.Type
        if self[resource_ID] == nil then self[resource_ID] = {} end

        for row, data in pairs(resource_data) do
            self[resource_ID][row] = data
        end

        self[resource_ID].ValidTerrains = table.fill(false, #TerrainData)

        for row in GameInfo.Resource_TerrainBooleans() do
            local terrainType = row.TerrainType
            if row.ResourceType == resourceType then
                self[resource_ID].ValidTerrains[TerrainTypes[terrainType]] = true
            end
        end

        self[resource_ID].ValidFeatureTerrains = table.fill(false, #TerrainData)
        for row in GameInfo.Resource_FeatureTerrainBooleans() do
            local terrainType = row.TerrainType
            if row.ResourceType == resourceType then
                self[resource_ID].ValidFeatureTerrains[TerrainTypes[terrainType]] = true
            end
        end

        self[resource_ID].ValidFeatureTypes = table.fill(false, #FeatureData)
        for row in GameInfo.Resource_FeatureBooleans() do
            local featureType = row.FeatureType
            if row.ResourceType == resourceType then
                self[resource_ID].ValidFeatureTypes[FeatureTypes[featureType]] = true
            end
        end
        if GameInfo.Resource_Preferences ~= nil then
            self:InitializePreferences(resource_ID)
        end
    end

return self end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_ResourceInfos:InitializePreferences(resource_ID)
    for preference_data in GameInfo.Resource_Preferences() do
        if self[resource_ID].Preferences == nil then self[resource_ID].Preferences = {} end
        for row, data in pairs(preference_data) do
            if row.ResourceType == self[resource_ID].Type then
                self[resource_ID].Preferences[row] = data
            end
        end
    end
end
------------------------------------------------------------------------------------------------------------------------
-- /// Resource validity checks
------------------------------------------------------------------------------------------------------------------------
function Lekmap_ResourceInfos:IsValidOn(resource_ID, x, y, bSoftCheck)

    local plot = Map.GetPlot(x, y)
    local terrainType = plot:GetTerrainType()
    local featureType = plot:GetFeatureType()
    local plotType = plot:GetPlotType()

	if featureType == FeatureTypes.FEATURE_ICE
	or featureType == self.feature_atoll
	or featureType == FeatureTypes.FEATURE_OASIS
	or plotType == PlotTypes.PLOT_MOUNTAIN
	or plot:IsLake() then return false end -- might want to add support for lake resources later

    -- for availability sake, only allow coastal luxuries to spawn next to land (otherwise they will be hard to reach)
    if self[resource_ID].ResourceClassType == "RESOURCECLASS_LUXURY"
    and plotType == PlotTypes.PLOT_OCEAN
    and (not plot:IsAdjacentToLand()) then return false end


    -- softcheck skips any feature/plottype checks for maximum availability
    if bSoftCheck and ((self[resource_ID].ValidTerrains[terrainType]
    or self[resource_ID].ValidTerrains[TerrainTypes["TERRAIN_HILL"]] and plotType == PlotTypes.PLOT_HILLS)
    or self[resource_ID].ValidFeatureTerrains[terrainType]) then return true

    -- Resources with hills as valid terrain are valid on any terrain type with a hill
    elseif ((self[resource_ID].ValidTerrains[terrainType]
    or (self[resource_ID].ValidTerrains[TerrainTypes["TERRAIN_HILL"]] and plotType == PlotTypes.PLOT_HILLS))
    and featureType == FeatureTypes.NO_FEATURE)

    or (self[resource_ID].ValidFeatureTerrains[terrainType]
    and self[resource_ID].ValidFeatureTypes[featureType]) then

        if self[resource_ID].ValidTerrains[TerrainTypes["TERRAIN_HILL"]] then return true end
        if (plotType == PlotTypes.PLOT_LAND and self[resource_ID].Flatlands)
        or (plotType == PlotTypes.PLOT_HILLS and self[resource_ID].Hills)
        or (plotType == PlotTypes.PLOT_OCEAN) then return true end
    end

return false end
------------------------------------------------------------------------------------------------------------------------
-- /// Assign Luxury Roles functions
------------------------------------------------------------------------------------------------------------------------
function Lekmap_ResourceInfos:AssignLuxuryRoles()

    local luxury_list = {}
    for resource_ID, resource_data in ipairs(self) do
        if resource_data.ResourceClassType == "RESOURCECLASS_LUXURY"
        and (not resource_data.Special) and resource_data.CivilizationType == nil
        and (not resource_data.OnlyMinorCivs) then
           table.insert(luxury_list, resource_ID)
        end
    end
    self.regional_luxury_list = self:AssignRegionalLuxuries(luxury_list)
    self.city_state_luxury_list = self:AssignCityStateLuxuries(luxury_list)

end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_ResourceInfos:ChooseLuxury(choose_from_list, luxury_list, luxury_rol_list,
     x, y , spawnAmount, instance_number, radius)
    local numberOfTries = 0
    repeat
        if #choose_from_list <= 0 then break end
        local chosen_luxury = choose_from_list[Map.Rand(#choose_from_list, "") + 1]
        -- Check if the luxury has enough valid plots to spawn
        local valid_plots = Lekmap_PlaceResources:GenerateValidPlots(
            chosen_luxury, radius, x, y, true)
        if #valid_plots >= spawnAmount then
            luxury_list = Lekmap_Utilities.RemoveFromTable(luxury_list, chosen_luxury)
            luxury_rol_list[instance_number] = chosen_luxury
        else
            choose_from_list = Lekmap_Utilities.RemoveFromTable(choose_from_list, chosen_luxury)
        end
        numberOfTries = numberOfTries + 1
    until luxury_rol_list[instance_number] ~= nil or numberOfTries >= #choose_from_list
end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_ResourceInfos:AssignRegionalLuxuries(luxury_list)

    -- here we should also implement the new luxury weight system
    local regional_luxury_list = {}
    --TODO: Should implement a new way of creating the region and startplot tables
    for _, region_data in ipairs(start_plot_database.regions_sorted_by_type) do

        local region_number = region_data[1]
        local center_plotX = start_plot_database.startingPlots[region_number][1]
        local center_plotY = start_plot_database.startingPlots[region_number][2]
        local temporary_luxury_list = {}
        for _, resource_ID in ipairs(luxury_list) do
            table.insert(temporary_luxury_list, resource_ID)
        end

        for i = #temporary_luxury_list, 1, -1 do
            local resource_ID = temporary_luxury_list[i]
            print(self[resource_ID].Type, self[resource_ID].NoRegional)
            -- remove any luxuries that are not allowed to be a regional luxury based on the map option
            if Map.GetCustomOption(14) == 1 and self[resource_ID].NoRegional then
                table.remove(temporary_luxury_list, i)
            -- if the region has a coastal start and the map option guarantees a coastal luxury,
            -- remove any non-coastal luxuries from the list
            elseif Map.GetCustomOption(17) == 1 and start_plot_database.startLocationConditions[region_number][1] then
                if not (self[resource_ID].ValidTerrains[TerrainTypes["TERRAIN_COAST"]]) then
                    if not (self[resource_ID].ValidFeatureTerrains[TerrainTypes["TERRAIN_COAST"]]) then
                        table.remove(temporary_luxury_list, i)
                    end
                end
            end
        end

        local spawnAmount = Map.GetCustomOption(21) or 3
        self:ChooseLuxury(temporary_luxury_list, luxury_list, regional_luxury_list,
        center_plotX, center_plotY, spawnAmount, region_number, 3)

    end

return regional_luxury_list end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_ResourceInfos:AssignCityStateLuxuries(luxury_list)

    local city_state_luxury_list = {}
    for city_state = 1, start_plot_database.iNumCityStates do
        if start_plot_database.city_state_validity_table[city_state] then
			local city_plotX = start_plot_database.cityStatePlots[city_state][1]
			local city_plotY = start_plot_database.cityStatePlots[city_state][2]
            local temporary_luxury_list = {}

           -- pool of luxuries for city-states to choose from. Based on the number of city-states, max 8 luxuries
            for _ = 1, math.min(8, math.ceil(start_plot_database.iNumCityStates / 2)) do
                local random_luxury = luxury_list[Map.Rand(#luxury_list, "") + 1]
                table.insert(temporary_luxury_list, random_luxury)
            end

            self:ChooseLuxury(temporary_luxury_list, luxury_list, city_state_luxury_list,
            city_plotX, city_plotY, 1, city_state, 2)

        end
    end

return city_state_luxury_list end
------------------------------------------------------------------------------------------------------------------------
function Lekmap_ResourceInfos:AssignRandomLuxuries(luxury_list)

    --TODO: make random luxuries use region weights.
    local random_luxury_list = {}
end