--luacheck: globals GameInfo globals Lekmap_ResourceInfos globals Map
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