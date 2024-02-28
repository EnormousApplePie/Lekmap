--luacheck: globals Game
local ResourceInfos = {}

ResourceInfos.meta = {
    __metatable = "meta ResourceInfos: Access denied",

    Initialize = function(self)

        for resource_data in Game.Resources() do
            local resource_ID = resource_data.ID + 1
            local resourceType = resource_data.ResourceType
            table.insert(self[resource_ID], resource_data)


            self[resource_ID].ValidTerrains = {}
            for resource_terrain_data in Game.Resource_TerrainBooleans() do
                if resource_terrain_data.ResourceType == resourceType then
                    table.insert(self[resource_ID].ValidTerrains, resource_terrain_data.TerrainType)
                end
            end
            self[resource_ID].ValidFeatureTerrains = {}
            for resource_featureterrain_data in Game.Resource_FeatureTerrainBooleans() do
                if resource_featureterrain_data.ResourceType == resourceType then
                    table.insert(self[resource_ID].ValidTerrains, resource_featureterrain_data.TerrainType)
                end
            end
            self[resource_ID].ValidFeatureTypes = {}
            for resource_feature_data in Game.Resource_FeatureBooleans() do
                if resource_feature_data.ResourceType == resourceType then
                    table.insert(self[resource_ID].ValidFeatureTypes, resource_feature_data.FeatureType)
                end
            end
        end

        return setmetatable(ResourceInfos, ResourceInfos.meta)
    end,

    -- might as well check eligibility in its entirety here
    IsValidOn = function(self, typeOfType, typeToCheck)
        local validTable = {}
        if typeOfType == "Terrain" then validTable = self.ValidTerrains
        elseif typeOfType == "FeatureTerrain" then validTable = self.ValidFeatureTerrains
        elseif typeOfType == "Feature" then validTable = self.ValidFeatureTypes
        else error("Invalid checkType: " .. typeOfType) end

        for _, ValidTypes in pairs(validTable) do
            if ValidTypes == typeToCheck then
                return true
            end
        end
        return false
    end,

}

local resource_ID = 0

ResourceInfos:Initialize()

if ResourceInfos[resource_ID]:IsValidOn("Terrain", "TERRAIN_GRASS") then
    print("Resource is valid on grass")
end
