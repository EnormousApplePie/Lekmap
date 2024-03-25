
------------------------------------------------------------------------------
--	FILE:	  AssignStartingPlots.lua
--	AUTHOR:   Bob Thomas
--	PURPOSE:  Civ5's new and improved start plot assignment method.
------------------------------------------------------------------------------
--	REGIONAL DIVISION CONCEPT:   Bob Thomas
--	DIVISION ALGORITHM CONCEPT:  Ed Beach
--	CENTER BIAS CONCEPT:         Bob Thomas
--	RESOURCE BALANCING:          Bob Thomas
--	LUA IMPLEMENTATION:          Bob Thomas
------------------------------------------------------------------------------
--	Copyright (c) 2010 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

include("HBMapmakerUtilities");
include("NaturalWondersCustomMethods");

------------------------------------------------------------------------------
-- NOTE FOR MODDERS: There is a detailed Reference at the end of the file.
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- MOD.EAP: Includes. Also run the config file.
------------------------------------------------------------------------------
include("Lekmap_Config.lua")
include("lekmap_resource_infos.lua")
include("lekmap_utilities.lua")
include("lekmap_place_resources.lua")
include("PlotIterators.lua")
runConfig()

------------------------------------------------------------------------------
--                             FOREWORD

-- Jon wanted a lot of changes to terrain composition for Civ5. These have
-- had the effect of making different parts of each randomly generated maps
-- more distinct, more unique, but it has also necessitated a complete
-- overhaul of where civs are placed on the map and how resources are
-- distributed. The new placements are much more precise, both for civs 
-- and resources. As such, any modifications to terrain or resource types 
-- will no longer be "plug and play" in the XML. Terrain modders will have 
-- to work with this file as well as the XML, to integrate their mods in to
-- the new system.

-- Some civs will be purposely placed in difficult terrain, depending on what
-- a given map instance has to offer. Civs placed in tough environments will
-- receive specific amounts of assistance, primarily in the form of Bonus food
-- from Wheat, Cows, Deer, Bananas, or Fish. This part of the new system is 
-- very precisely calibrated and balanced, so be aware that any changes or 
-- additions to how resources are placed near start points will have a 
-- dramatic effect on the game, and could pose challenges of a sort that were
-- not present in the sphere of Civ4 modding.

-- The Luxury resources are also carefully calibrated. In a given game, some
-- will be clustered near a small number of civs (perhaps even a monopoly 
-- given to one). Some will be placed only near City States, requiring civs 
-- to go through a City State, one way or another, to obtain any instances of
-- that luxury type. Some will be left up to fate, appearing randomly in 
-- whatever is their normal habitat. Yet others may be oversupplied or perhaps
-- even absent from a given game. Which luxuries fall in to which category 
-- will be scrambled, to keep players guessing, and to help further the sense
-- of curiosity when exploring a new map in a new game.

-- Bob Thomas  -  April 16, 2010

-- There is a Reference section at the end of the file.

------------------------------------------------------------------------------
------------------------------------------------------------------------------
AssignStartingPlots = {};
------------------------------------------------------------------------------

-- WARNING: There must not be any recalculation of AreaIDs at any time during
-- the execution of any operations in or attached to this table. Recalculating
-- will invalidate all data based on AreaID relationships with plots, which
-- will destroy Regional definitions for all but the Rectangular method. A fix
-- for scrambled AreaID data is theoretically possible, but I have not spent
-- development resources and time on this, directing attention to other tasks.

------------------------------------------------------------------------------
function AssignStartingPlots.Create()
	-- There are three methods of dividing the map in to regions.
	-- OneLandmass, Continents, Oceanic. Default method is Continents.
	--
	-- Standard start plot finding uses a regional division method, then
	-- assigns one civ per region. Regions with lowest average fertility
	-- get their assignment first, to avoid the poor getting poorer.
	--
	-- Default methods for civ and city state placement both rely on having
	-- regional division data. If the desired process for a given map script
	-- would not define regions of this type, replace the start finder
	-- with your custom method.
	--
	-- Note that this operation relies on inclusion of the Mapmaker Utilities.
	local iW, iH = Map.GetGridSize();
	local feature_atoll;
	for thisFeature in GameInfo.Features() do
		if thisFeature.Type == "FEATURE_ATOLL" then
			feature_atoll = thisFeature.ID;
		end
	end

	-- MOD.EAP: - Communicate with lekmod

	-- we now know we can communicate with lekmod files if needed, useful for later

	-- NOTE: We assume that ararat mountains only exist in lekmod
	-- We could probably use a more robust method, but this is the easiest way to do it for now
	local bLekmod = false;
	for thisFeatureLek in GameInfo.Features() do
		if thisFeatureLek.Type == "FEATURE_ARARAT_MOUNTAIN" then
			bLekmod = true;
		end
	end
	if bLekmod then
		--include our custom script from lekmod
		--include("Mapscriptcustom");
		--printMapScript();
		print("Lekmod Found!")
	end
	-- MOD.EAP: End
	

	-- Main data table ("self dot" table).
	--
	-- Scripters have the opportunity to replace member methods without
	-- having to replace the entire process.
	findStarts = {

		-- Core Process member methods
		__Init = AssignStartingPlots.__Init,
		__InitLuxuryWeights = AssignStartingPlots.__InitLuxuryWeights,
		__CustomInit = AssignStartingPlots.__CustomInit,
		ApplyHexAdjustment = AssignStartingPlots.ApplyHexAdjustment,
		GenerateRegions = AssignStartingPlots.GenerateRegions,
		ChooseLocations = AssignStartingPlots.ChooseLocations,
		BalanceAndAssign = AssignStartingPlots.BalanceAndAssign,
		PlaceNaturalWonders = AssignStartingPlots.PlaceNaturalWonders,
		PlaceResourcesAndCityStates = AssignStartingPlots.PlaceResourcesAndCityStates,
		
		-- Generate Regions member methods
		MeasureStartPlacementFertilityOfPlot = AssignStartingPlots.MeasureStartPlacementFertilityOfPlot,
		MeasureStartPlacementFertilityInRectangle = AssignStartingPlots.MeasureStartPlacementFertilityInRectangle,
		MeasureStartPlacementFertilityOfLandmass = AssignStartingPlots.MeasureStartPlacementFertilityOfLandmass,
		RemoveDeadRows = AssignStartingPlots.RemoveDeadRows,
		DivideIntoRegions = AssignStartingPlots.DivideIntoRegions,
		ChopIntoThreeRegions = AssignStartingPlots.ChopIntoThreeRegions,
		ChopIntoTwoRegions = AssignStartingPlots.ChopIntoTwoRegions,
		CustomOverride = AssignStartingPlots.CustomOverride,

		-- Choose Locations member methods
		MeasureTerrainInRegions = AssignStartingPlots.MeasureTerrainInRegions,
		DetermineRegionTypes = AssignStartingPlots.DetermineRegionTypes,
		PlaceImpactAndRipples = AssignStartingPlots.PlaceImpactAndRipples,
		MeasureSinglePlot = AssignStartingPlots.MeasureSinglePlot,
		EvaluateCandidatePlot = AssignStartingPlots.EvaluateCandidatePlot,
		IterateThroughCandidatePlotList = AssignStartingPlots.IterateThroughCandidatePlotList,
		FindStart = AssignStartingPlots.FindStart,
		FindCoastalStart = AssignStartingPlots.FindCoastalStart,
		FindStartWithoutRegardToAreaID = AssignStartingPlots.FindStartWithoutRegardToAreaID,
		
		-- Balance and Assign member methods
		AttemptToPlaceBonusResourceAtPlot = AssignStartingPlots.AttemptToPlaceBonusResourceAtPlot,
		AttemptToPlaceHillsAtPlot = AssignStartingPlots.AttemptToPlaceHillsAtPlot,
		AttemptToPlaceSmallStrategicAtPlot = AssignStartingPlots.AttemptToPlaceSmallStrategicAtPlot,
		FindFallbackForUnmatchedRegionPriority = AssignStartingPlots.FindFallbackForUnmatchedRegionPriority,
		AddStrategicBalanceResources = AssignStartingPlots.AddStrategicBalanceResources,
		AttemptToPlaceStoneAtGrassPlot = AssignStartingPlots.AttemptToPlaceStoneAtGrassPlot,
		NormalizeStartLocation = AssignStartingPlots.NormalizeStartLocation,
		NormalizeTeamLocations = AssignStartingPlots.NormalizeTeamLocations,
		
		-- Natural Wonders member methods
		ExaminePlotForNaturalWondersEligibility = AssignStartingPlots.ExaminePlotForNaturalWondersEligibility,
		ExamineCandidatePlotForNaturalWondersEligibility = AssignStartingPlots.ExamineCandidatePlotForNaturalWondersEligibility,
		CanBeThisNaturalWonderType = AssignStartingPlots.CanBeThisNaturalWonderType,
		GenerateLocalVersionsOfDataFromXML = AssignStartingPlots.GenerateLocalVersionsOfDataFromXML,
		GenerateNaturalWondersCandidatePlotLists = AssignStartingPlots.GenerateNaturalWondersCandidatePlotLists,
		AttemptToPlaceNaturalWonder = AssignStartingPlots.AttemptToPlaceNaturalWonder,

		-- City States member methods
		AssignCityStatesToRegionsOrToUninhabited = AssignStartingPlots.AssignCityStatesToRegionsOrToUninhabited,
		CanPlaceCityStateAt = AssignStartingPlots.CanPlaceCityStateAt,
		ObtainNextSectionInRegion = AssignStartingPlots.ObtainNextSectionInRegion,
		PlaceCityState = AssignStartingPlots.PlaceCityState,
		PlaceCityStateInRegion = AssignStartingPlots.PlaceCityStateInRegion,
		PlaceCityStates = AssignStartingPlots.PlaceCityStates,	-- Dependent on AssignLuxuryRoles being executed first, so beware.
		NormalizeCityState = AssignStartingPlots.NormalizeCityState,
		NormalizeCityStateLocations = AssignStartingPlots.NormalizeCityStateLocations, -- Dependent on PlaceLuxuries being executed first.
		
		-- MOD: SAPHT new functions
		PlaceResourceImpactCoastalMod = AssignStartingPlots.PlaceResourceImpactCoastalMod,
		ExpandCoastalRing = AssignStartingPlots.ExpandCoastalRing,
		-- Resources member methods
		GenerateGlobalResourcePlotLists = AssignStartingPlots.GenerateGlobalResourcePlotLists,
		PlaceResourceImpact = AssignStartingPlots.PlaceResourceImpact,		-- Note: called from PlaceImpactAndRipples
		ProcessResourceList = AssignStartingPlots.ProcessResourceList,
		PlaceSpecificNumberOfResources = AssignStartingPlots.PlaceSpecificNumberOfResources,
		IdentifyRegionsOfThisType = AssignStartingPlots.IdentifyRegionsOfThisType,
		SortRegionsByType = AssignStartingPlots.SortRegionsByType,
		AssignLuxuryToRegion = AssignStartingPlots.AssignLuxuryToRegion,
		GetLuxuriesSplitCap = AssignStartingPlots.GetLuxuriesSplitCap,		-- New for Expansion, because we have more luxuries now.
		GetCityStateLuxuriesTargetNumber = AssignStartingPlots.GetCityStateLuxuriesTargetNumber,	-- New for Expansion
		GetDisabledLuxuriesTargetNumber = AssignStartingPlots.GetDisabledLuxuriesTargetNumber,
		AssignLuxuryRoles = AssignStartingPlots.AssignLuxuryRoles,
		GetListOfAllowableLuxuriesAtCitySite = AssignStartingPlots.GetListOfAllowableLuxuriesAtCitySite,
		GetRandomLuxuriesTargetNumber = AssignStartingPlots.GetRandomLuxuriesTargetNumber,	-- MOD.Barathor: New
		GenerateLuxuryPlotListsAtCitySite = AssignStartingPlots.GenerateLuxuryPlotListsAtCitySite, -- Also doubles as Ice Removal.
		-- MOD.EAP: Start
		CheckResourceEligibility = AssignStartingPlots.CheckResourceEligibility,
		GenerateGlobalResourcePlotLists_NEW = AssignStartingPlots.GenerateGlobalResourcePlotLists_NEW,
		GetStrategicResourceQuantityValues = AssignStartingPlots.GetStrategicResourceQuantityValues,
		SortResourcePreferenceTable = AssignStartingPlots.SortResourcePreferenceTable,
		GetPreferenceComplexity = AssignStartingPlots.GetPreferenceComplexity,
		ProcessResourceList_NEW = AssignStartingPlots.ProcessResourceList_NEW,
		HandleResourcePreferences = AssignStartingPlots.HandleResourcePreferences,
		FixResource = AssignStartingPlots.FixResource,
		GetJungleRange = AssignStartingPlots.GetJungleRange,
		GenerateMainlandCoastalPlotTables = AssignStartingPlots.GenerateMainlandCoastalPlotTables,
		HandleWaterLuxuriesEligibility = AssignStartingPlots.HandleWaterLuxuriesEligibility,
		PlaceResourceImpactRegionalMod = AssignStartingPlots.PlaceResourceImpactRegionalMod,
		-- MOD.EAP: End
		GenerateLuxuryPlotListsNearCitySite = AssignStartingPlots.GenerateLuxuryPlotListsNearCitySite,
		GenerateLuxuryPlotListsInRegion = AssignStartingPlots.GenerateLuxuryPlotListsInRegion,
		GetIndicesForLuxuryType = AssignStartingPlots.GetIndicesForLuxuryType,
		GetRegionLuxuryTargetNumbers = AssignStartingPlots.GetRegionLuxuryTargetNumbers,
		GetWorldLuxuryTargetNumbers = AssignStartingPlots.GetWorldLuxuryTargetNumbers,
		PlaceMarble = AssignStartingPlots.PlaceMarble,
		PlaceLuxuries = AssignStartingPlots.PlaceLuxuries,
		PlaceSmallQuantitiesOfStrategics = AssignStartingPlots.PlaceSmallQuantitiesOfStrategics,
		PlaceFish = AssignStartingPlots.PlaceFish,
		PlaceFishMainland = AssignStartingPlots.PlaceFishMainland,
		PlaceSexyBonusAtCivStarts = AssignStartingPlots.PlaceSexyBonusAtCivStarts,
		AddExtraBonusesToHillsRegions = AssignStartingPlots.AddExtraBonusesToHillsRegions,
		AddModernMinorStrategicsToCityStates = AssignStartingPlots.AddModernMinorStrategicsToCityStates,
		PlaceOilInTheSea = AssignStartingPlots.PlaceOilInTheSea,
		FixResourceGraphics = AssignStartingPlots.FixResourceGraphics, -- Sugar could not be made visible enough in jungle, so turn any sugar jungle to marsh.
		PrintFinalResourceTotalsToLog = AssignStartingPlots.PrintFinalResourceTotalsToLog,
		GetMajorStrategicResourceQuantityValues = AssignStartingPlots.GetMajorStrategicResourceQuantityValues,
		GetSmallStrategicResourceQuantityValues = AssignStartingPlots.GetSmallStrategicResourceQuantityValues,
		PlaceStrategicAndBonusResources = AssignStartingPlots.PlaceStrategicAndBonusResources,
		
		-- Civ start position variables
		startingPlots = {},				-- Stores x and y coordinates (and "score") of starting plots for civs, indexed by region number
		method = 2,						-- Method of regional division, default is 2
		NoCoastInland = true,			-- Decides if inland civs can spawn on the coast
		iNumCivs = 0,					-- Number of civs at game start
		player_ID_list = {},			-- Correct list of player IDs (includes handling of any 'gaps' that occur in MP games)
		plotDataIsCoastal = {},			-- Stores table of NextToSaltWater plots to reduce redundant calculations
		plotDataIsNextToCoast = {},		-- Stores table of TwoAwayFromSaltWater plots to reduce redundant calculations
		plotDataIsThreeFromCoast = {},	-- Stores table of ThreeAwayFromSaltWater plots to reduce redundant calculations
		plotDataIsFourFromCoast = {},	-- Stores table of FourAwayFromSaltWater plots to reduce redundant calculations
		regionData = {},				-- Stores data returned from regional division algorithm
		regionTerrainCounts = {},		-- Stores counts of terrain elements for all regions
		regionTypes = {},				-- Stores region types
		distanceData = table.fill(0, iW * iH), -- Stores "impact and ripple" data of start points as each is placed
		playerCollisionData = table.fill(false, iW * iH), -- Stores "impact" data only, of start points, to avoid player collisions
		playerCoastalCollisionData = table.fill(false, iW * iH), -- Stores "impact" data only, of start points, to avoid player collisions
		startLocationConditions = {},   -- Stores info regarding conditions at each start location
		bModLuxes = false,				-- Set to true if extra luxes exsist in database

		-- Team info variables (not used in the core process, but necessary to many Multiplayer map scripts)
		bTeamGame,
		iNumTeamsOfCivs,
		teams_with_major_civs,
		number_civs_per_team,
		
		-- Rectangular Division, dimensions within which all regions reside. (Unused by the other methods)
		inhabited_WestX,
		inhabited_SouthY,
		inhabited_Width,
		inhabited_Height,

		-- Natural Wonders variables
		naturalWondersData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the natural wonders layer
		bWorldHasOceans,
		iBiggestLandmassID,
		iNumNW = 0,
		wonder_list = {},
		eligibility_lists = {},
		xml_row_numbers = {},
		placed_natural_wonder = {},
		feature_atoll,
		
		-- City States variables
		cityStatePlots = {},			-- Stores x and y coordinates, and region number, of city state sites
		iNumCityStates = 0,				-- Number of city states at game start
		iNumCityStatesUnassigned = 0,	-- Number of City States still in need of placement method assignment
		iNumCityStatesPerRegion = 0,	-- Number of City States to be placed in each civ's region
		iNumCityStatesUninhabited = 0,	-- Number of City States to be placed on landmasses uninhabited by civs
		iNumCityStatesSharedLux = 0,	-- Number of City States to be placed in regions whose luxury type is shared with other regions
		iNumCityStatesLowFertility = 0,	-- Number of extra City States to be placed in regions with low fertility per land plot
		cityStateData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the city state layer
		city_state_region_assignments = table.fill(-1, 41), -- Stores region number of each city state (-1 if not in a region)
		uninhabited_areas_coastal_plots = {}, -- For use in placing city states outside of Regions
		uninhabited_areas_inland_plots = {},
		iNumCityStatesDiscarded = 0,	-- If a city state cannot be placed without being too close to another start, it will be discarded
		city_state_validity_table = table.fill(false, 41), -- Value set to true when a given city state is successfully assigned a start plot
		
		-- Resources variables
		resources = {},                 -- Stores all resource data, pulled from the XML
		resource_setting,				-- User selection for Resource Setting, chosen on game launch (when applicable)
		amounts_of_resources_placed = table.fill(0, 99), -- Stores amounts of each resource ID placed. WARNING: This table uses adjusted resource ID (+1) to account for Lua indexing. Add 1 to all IDs to index this table.
		luxury_assignment_count = table.fill(0, 99), -- Stores amount of each luxury type assigned to regions. WARNING: current implementation will crash if a Luxury is attached to resource ID 0 (default = iron), because this table uses unadjusted resource ID as table index.
		luxury_low_fert_compensation = table.fill(0, 99), -- Stores number of times each resource ID had extras handed out at civ starts. WARNING: Indexed by resource ID.
		region_low_fert_compensation = table.fill(0, 22); -- Stores number of luxury compensation each region received
		luxury_region_weights = {},		-- Stores weighted assignments for the types of regions
		luxury_fallback_weights = {},	-- In case all options for a given region type got assigned or disabled, also used for Undefined regions
		luxury_city_state_weights = {},	-- Stores weighted assignments for city state exclusive luxuries
		strategicData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the strategic resources layer
		luxuryData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the luxury resources layer
		bonusData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the bonus resources layer
		fishData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the fish layer
		seaOilData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the sea oil layer
		marbleData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the marble layer
		sheepData = table.fill(0, iW * iH), -- Stores "impact and ripple" data in the sheep layer -- Sheep use regular bonus layer PLUS this one
		regions_sorted_by_type = {},	-- Stores table that includes region number and Luxury ID (this is where the two are first matched)
		region_luxury_assignment = {},	-- Stores luxury assignments, keyed by region number.
		iNumTypesUnassigned = 30,		-- Total number of luxuries. Adjust if modifying number of luxury resources.
		iNumMaxAllowedForRegions = 16,	-- Maximum luxury types allowed to be assigned to regional distribution. CANNOT be reduced below 8!
		iNumTypesAssignedToRegions = 0,
		resourceIDs_assigned_to_regions = {},
		iNumTypesAssignedToCS = 3,		-- Luxury types that will be placed only near city states
		resourceIDs_assigned_to_cs = {},
		iNumTypesSpecialCase = 0,		-- Marble affects Wonder construction, so requires special-case handling
		resourceIDs_assigned_to_special_case = {},
		iNumTypesRandom = 0,
		resourceIDs_assigned_to_random = {},
		iNumTypesDisabled = 0,
		resourceIDs_not_being_used = {},
		totalLuxPlacedSoFar = 0,
		realtotalLuxPlacedSoFar = 0,

		-- Plot lists for use with global distribution of Luxuries.
		--
		-- NOTE: These lists are best synchronized with the equivalent plot list generations
		-- for regions and individual city sites, to keep Luxury behavior globally consistent.
		-- All three list sets are acted upon by a single set of indices, which apply only to 
		-- Luxury resources. These are controlled in the function GetIndicesForLuxuryType.
		-- 
		global_luxury_plot_lists = {},
		coast_next_to_land_list = {},
		marsh_list = {},
		flood_plains_list = {},
		hills_open_list = {},
		hills_covered_list = {},
		hills_jungle_list = {},
		hills_forest_list = {},
		jungle_flat_list = {},
		forest_flat_list = {},
		desert_flat_no_feature = {},
		plains_flat_no_feature = {},
		dry_grass_flat_no_feature = {},
		fresh_water_grass_flat_no_feature = {},
		tundra_flat_including_forests = {},
		forest_flat_that_are_not_tundra = {},
		feature_atoll = feature_atoll,
		-- MOD.Barathor: New Plot lists
		-- MOD.Barathor: Start
		dry_plains_flat_no_feature = {},
		fresh_water_plains_flat_no_feature = {},
		tundra_flat_forest = {},
		desert_or_tundra_flat_no_feature = {},
		hills_open_no_tundra = {},
		hills_open_no_desert = {},
		hills_open_no_tundra_no_desert = {},
		hills_open_no_grass = {},
		hills_open_no_grass_no_tundra = {},
		hills_open_no_grass_no_plains = {},
		hills_covered_no_tundra = {},
		hills_covered_no_grass = {},
		hills_covered_no_grass_no_tundra = {},
		flat_covered = {},
		flat_covered_no_grass = {},
		flat_covered_no_tundra = {},
		flat_covered_no_grass_no_tundra = {},
		flat_open = {},
		flat_open_no_grass_no_plains = {},
		flat_open_no_tundra_no_desert = {},
		flat_open_no_desert = {},
		flat_desert_including_flood = {},
		-- MOD.Barathor: End

		-- Additional Plot lists for use with global distribution of Strategics and Bonus.
		--
		-- Unlike Luxuries, which have sophisticated handling to foster supply and demand
		-- in support of Trade and Diplomacy, the Strategic and Bonus resources are 
		-- allowed to conform to the terrain of a given map, with their quantities 
		-- available in any given game only loosely controlled. Thanks to the new method
		-- of quantifying strategic resources, the controls on their distribution no
		-- longer need to be as strenuous. Likewise with Bonus no longer affecting trade.
		grass_flat_no_feature = {},
		tundra_flat_no_feature = {},
		snow_flat_list = {},
		hills_list = {},
		land_list = {},
		coast_list = {},
		mainland_coast_list = {},
		mainland_coast_list_inner = {},
		mainland_coast_list_second = {},
		mainland_coast_list_outer = {},
		non_mainland_coast_list = {},
		coast_list_panagaea = {},
		marble_list = {},
		extra_deer_list = {},
		desert_wheat_list = {},
		banana_list = {},
		barren_plots = 0,
		
		-- Positioner defaults. These are the controls for the "Center Bias" placement method for civ starts in regions.
		centerBias = 40, -- % of radius from region center to examine first
		middleBias = 70, -- % of radius from region center to check second
		minFoodInner = 2, --2
		minProdInner = 1, --1
		minGoodInner = 3, --3
		minFoodMiddle = 4, --4
		minProdMiddle = 2, --0
		minGoodMiddle = 6, --6
		minFoodOuter = 4, --4
		minProdOuter = 4, --2
		minGoodOuter = 8, --8
		maxJunk = 5, --5

		-- Hex Adjustment tables. These tables direct plot by plot scans in a radius 
		-- around a center hex, starting to Northeast, moving clockwise.
		firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}},
		secondRingYIsEven = {
		{1, 2}, {1, 1}, {2, 0}, {1, -1}, {1, -2}, {0, -2},
		{-1, -2}, {-2, -1}, {-2, 0}, {-2, 1}, {-1, 2}, {0, 2}
		},
		thirdRingYIsEven = {
		{1, 3}, {2, 2}, {2, 1}, {3, 0}, {2, -1}, {2, -2},
		{1, -3}, {0, -3}, {-1, -3}, {-2, -3}, {-2, -2}, {-3, -1},
		{-3, 0}, {-3, 1}, {-2, 2}, {-2, 3}, {-1, 3}, {0, 3}
		},
		firstRingYIsOdd = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}},
		secondRingYIsOdd = {		
		{1, 2}, {2, 1}, {2, 0}, {2, -1}, {1, -2}, {0, -2},
		{-1, -2}, {-1, -1}, {-2, 0}, {-1, 1}, {-1, 2}, {0, 2}
		},
		thirdRingYIsOdd = {		
		{2, 3}, {2, 2}, {3, 1}, {3, 0}, {3, -1}, {2, -2},
		{2, -3}, {1, -3}, {0, -3}, {-1, -3}, {-2, -2}, {-2, -1},
		{-3, 0}, {-2, 1}, {-2, 2}, {-1, 3}, {0, 3}, {1, 3}
		},
		-- Direction types table, another method of handling hex adjustments, in combination with Map.PlotDirection()
		direction_types = {
			DirectionTypes.DIRECTION_NORTHEAST,
			DirectionTypes.DIRECTION_EAST,
			DirectionTypes.DIRECTION_SOUTHEAST,
			DirectionTypes.DIRECTION_SOUTHWEST,
			DirectionTypes.DIRECTION_WEST,
			DirectionTypes.DIRECTION_NORTHWEST
			},
		
		-- Handy resource ID shortcuts
		wheat_ID, cow_ID, deer_ID, banana_ID, fish_ID, sheep_ID, stone_ID,
		iron_ID, horse_ID, coal_ID, oil_ID, aluminum_ID, uranium_ID,
		whale_ID, pearls_ID, ivory_ID, fur_ID, silk_ID,
		dye_ID, spices_ID, sugar_ID, cotton_ID, wine_ID, incense_ID,
		gold_ID, silver_ID, gems_ID, marble_ID,
		-- Expansion luxuries
		copper_ID, salt_ID, citrus_ID, truffles_ID, crab_ID, cocoa_ID,
		bison_ID,
		
		-- Mod luxuries
		coffee_ID, tea_ID, tobacco_ID, amber_ID, jade_ID, olives_ID, perfume_ID, coral_ID, lapis_ID, -- MOD.Barathor: New

		-- Even More Resources for Vox Populi (luxuries)
		lavender_ID, obsidian_ID, platinum_ID, poppy_ID, tin_ID, -- MOD.HungryForFood: New
		-- Even More Resources for Vox Populi (bonus)
		coconut_ID, hardwood_ID, lead_ID, maize_ID, pineapple_ID, potato_ID, rice_ID, rubber_ID, sulfur_ID, titanium_ID, -- MOD.HungryForFood: New

		
		
		-- Local arrays for storing Natural Wonder Placement XML data
		EligibilityMethodNumber = {},
		OccurrenceFrequency = {},
		RequireBiggestLandmass = {},
		AvoidBiggestLandmass = {},
		RequireFreshWater = {},
		AvoidFreshWater = {},
		LandBased = {},
		RequireLandAdjacentToOcean = {},
		AvoidLandAdjacentToOcean = {},
		RequireLandOnePlotInland = {},
		AvoidLandOnePlotInland = {},
		RequireLandTwoOrMorePlotsInland = {},
		AvoidLandTwoOrMorePlotsInland = {},
		CoreTileCanBeAnyPlotType = {},
		CoreTileCanBeFlatland = {},
		CoreTileCanBeHills = {},
		CoreTileCanBeMountain = {},
		CoreTileCanBeOcean = {},
		CoreTileCanBeAnyTerrainType = {},
		CoreTileCanBeGrass = {},
		CoreTileCanBePlains = {},
		CoreTileCanBeDesert = {},
		CoreTileCanBeTundra = {},
		CoreTileCanBeSnow = {},
		CoreTileCanBeShallowWater = {},
		CoreTileCanBeDeepWater = {},
		CoreTileCanBeAnyFeatureType = {},
		CoreTileCanBeNoFeature = {},
		CoreTileCanBeForest = {},
		CoreTileCanBeJungle = {},
		CoreTileCanBeOasis = {},
		CoreTileCanBeFloodPlains = {},
		CoreTileCanBeMarsh = {},
		CoreTileCanBeIce = {},
		CoreTileCanBeAtoll = {},
		AdjacentTilesCareAboutPlotTypes = {},
		AdjacentTilesAvoidAnyland = {},
		AdjacentTilesRequireFlatland = {},
		RequiredNumberOfAdjacentFlatland = {},
		AdjacentTilesRequireHills = {},
		RequiredNumberOfAdjacentHills = {},
		AdjacentTilesRequireMountain = {},
		RequiredNumberOfAdjacentMountain = {},
		AdjacentTilesRequireHillsPlusMountains = {},
		RequiredNumberOfAdjacentHillsPlusMountains = {},
		AdjacentTilesRequireOcean = {},
		RequiredNumberOfAdjacentOcean = {},
		AdjacentTilesAvoidFlatland = {},
		MaximumAllowedAdjacentFlatland = {},
		AdjacentTilesAvoidHills = {},
		MaximumAllowedAdjacentHills = {},
		AdjacentTilesAvoidMountain = {},
		MaximumAllowedAdjacentMountain = {},
		AdjacentTilesAvoidHillsPlusMountains = {},
		MaximumAllowedAdjacentHillsPlusMountains = {},
		AdjacentTilesAvoidOcean = {},
		MaximumAllowedAdjacentOcean = {},
		AdjacentTilesCareAboutTerrainTypes = {},
		AdjacentTilesRequireGrass = {},
		RequiredNumberOfAdjacentGrass = {},
		AdjacentTilesRequirePlains = {},
		RequiredNumberOfAdjacentPlains = {},
		AdjacentTilesRequireDesert = {},
		RequiredNumberOfAdjacentDesert = {},
		AdjacentTilesRequireTundra = {},
		RequiredNumberOfAdjacentTundra = {},
		AdjacentTilesRequireSnow = {},
		RequiredNumberOfAdjacentSnow = {},
		AdjacentTilesRequireShallowWater = {},
		RequiredNumberOfAdjacentShallowWater = {},
		AdjacentTilesRequireDeepWater = {},
		RequiredNumberOfAdjacentDeepWater = {},
		AdjacentTilesAvoidGrass = {},
		MaximumAllowedAdjacentGrass = {},
		AdjacentTilesAvoidPlains = {},
		MaximumAllowedAdjacentPlains = {},
		AdjacentTilesAvoidDesert = {},
		MaximumAllowedAdjacentDesert = {},
		AdjacentTilesAvoidTundra = {},
		MaximumAllowedAdjacentTundra = {},
		AdjacentTilesAvoidSnow = {},
		MaximumAllowedAdjacentSnow = {},
		AdjacentTilesAvoidShallowWater = {},
		MaximumAllowedAdjacentShallowWater = {},
		AdjacentTilesAvoidDeepWater = {},
		MaximumAllowedAdjacentDeepWater = {},
		AdjacentTilesCareAboutFeatureTypes = {},
		AdjacentTilesRequireNoFeature = {},
		RequiredNumberOfAdjacentNoFeature = {},
		AdjacentTilesRequireForest = {},
		RequiredNumberOfAdjacentForest = {},
		AdjacentTilesRequireJungle = {},
		RequiredNumberOfAdjacentJungle = {},
		AdjacentTilesRequireOasis = {},
		RequiredNumberOfAdjacentOasis = {},
		AdjacentTilesRequireFloodPlains = {},
		RequiredNumberOfAdjacentFloodPlains = {},
		AdjacentTilesRequireMarsh = {},
		RequiredNumberOfAdjacentMarsh = {},
		AdjacentTilesRequireIce = {},
		RequiredNumberOfAdjacentIce = {},
		AdjacentTilesRequireAtoll = {},
		RequiredNumberOfAdjacentAtoll = {},
		AdjacentTilesAvoidNoFeature = {},
		MaximumAllowedAdjacentNoFeature = {},
		AdjacentTilesAvoidForest = {},
		MaximumAllowedAdjacentForest = {},
		AdjacentTilesAvoidJungle = {},
		MaximumAllowedAdjacentJungle = {},
		AdjacentTilesAvoidOasis = {},
		MaximumAllowedAdjacentOasis = {},
		AdjacentTilesAvoidFloodPlains = {},
		MaximumAllowedAdjacentFloodPlains = {},
		AdjacentTilesAvoidMarsh = {},
		MaximumAllowedAdjacentMarsh = {},
		AdjacentTilesAvoidIce = {},
		MaximumAllowedAdjacentIce = {},
		AdjacentTilesAvoidAtoll = {},
		MaximumAllowedAdjacentAtoll = {},
		TileChangesMethodNumber = {},
		ChangeCoreTileToMountain = {},
		ChangeCoreTileToFlatland = {},
		ChangeCoreTileTerrainToGrass = {},
		ChangeCoreTileTerrainToPlains = {},
		SetAdjacentTilesToShallowWater = {},
		
		-- MOD.EAP:  ID shortcut NEW
		resourceAssignID,
		resourceList = {};	
		-- MOD.EAP: tables for resource placement (might be temporary)
		global_resource_plot_lists = {},
		global_luxury_plot_lists_temp = {},
		ValidTerrainTypes = {},
		ValidFeatureTypes = {},
		ValidTerrainFeatureTypes = {},
		ResourceTypes = {},
		ordered_preference_list = {},
		TerrainList = {},
		FeatureList = {},
		luxuryRegionalData = {},
		bDoRegionalLuxCheck = false,

	}
	
	findStarts:__Init()
	
	findStarts:__InitLuxuryWeights()
	
	-- Entry point for easy overrides, for instance if only a couple things need to change.
	findStarts:__CustomInit()

	return findStarts
end
------------------------------------------------------------------------------
function AssignStartingPlots:__Init()
	-- Set up data tables that record whether a plot is coastal land and whether a plot is adjacent to coastal land.
	self.plotDataIsCoastal, self.plotDataIsNextToCoast = GenerateNextToCoastalLandDataTables()
	self.plotDataIsThreeFromCoast = GenerateThreeFromCoastTable(self.plotDataIsCoastal, self.plotDataIsNextToCoast)
	
	-- Sort the resource preference entries by complexity, so that the most complex entries are evaluated first.
	self:SortResourcePreferenceTable()

	-- Set up data for resource ID shortcuts.
	--print("########## Resource ID's ##########");
	local csvids = "";
	for resource_data in GameInfo.Resources() do
		table.insert(self.resources, resource_data);
		local resourceID = resource_data.ID;
		local resourceType = resource_data.Type;
		-- MOD.EAP : START
		local resourceClass = resource_data.ResourceClassType;
		local bResourceIsHill = resource_data.Hills;
		local bResourceIsFlat = resource_data.Flatlands;
		local bIsMinorResource = resource_data.OnlyMinorCivs;
		local bIsForCiv = resource_data.CivilizationType;
		local iFrequency = resource_data.TilesPer;
		--new entries in resources xml. If not present, they will be false or 0
		local bNoRegional = false;
		local bCanBeLake = false;
		local bCanBeMountain = false;
		local iAmountMajor = 0;
		local iAmountMinor = 0;

		-- MOD.EAP: New resourceinfos
		--[[
		for i, v in ipairs(ResourceInfos[1].ValidTerrains) do
			print(i, v)
		end
		]]


		if resource_data.NoRegional ~= nil then
			bNoRegional = resource_data.NoRegional;
		end
		if resource_data.Lake ~= nil then
			bCanBeLake = resource_data.Lake;
		end
		if resource_data.Mountain ~= nil then
			bCanBeMountain = resource_data.Mountain;
		end
		if resource_data.AmountMajor ~= nil then
			iAmountMajor = resource_data.AmountMajor;
		end
		if resource_data.AmountMinor ~= nil then
			iAmountMinor = resource_data.AmountMinor;
		end

		local bIsSpecial = false;
		if resource_data.Special ~= nil then
			bIsSpecial = resource_data.Special;
		else
			bIsSpecial = CheckSpecialCases(resourceType);
		end

		-- MOD.EAP: END
		
		-- Set up Bonus IDs
		csvids = csvids .. resourceType .. "," .. resourceID .. "\n";
		
		-- MOD.EAP: START

		-- ===============================================================
		-- Resource Types
		-- ===============================================================
		if self.ResourceTypes[resourceID] == nil then
			self.ResourceTypes[resourceID] = {};
		end
		self.ResourceTypes[resourceID] = { 
			ID = resourceID,
			Type = resourceType, 
			Class = resourceClass, 
			canBeHill = bResourceIsHill, 
			canBeFlat = bResourceIsFlat, 
			canBeLake = bCanBeLake,
			noRegional = bNoRegional,
			isForMinor = bIsMinorResource,
			isForCivType = bIsForCiv,
			amountMajor = iAmountMajor,
			amountMinor = iAmountMinor,
			Frequency = iFrequency,
			Special = bIsSpecial
			};
		
		-- ===============================================================
		-- Valid Terrains: List every available terrain type for each resource
		-- ===============================================================
		
		for terrain_data in GameInfo.Terrains() do
			table.insert(self.TerrainList, terrain_data.Type);
		end
		
		for valid_terrain_data in GameInfo.Resource_TerrainBooleans() do
			if valid_terrain_data.ResourceType == resourceType then
				for i, terrainType in ipairs(self.TerrainList) do
					if valid_terrain_data.TerrainType == terrainType then
						if self.ValidTerrainTypes[resourceID] == nil then
							self.ValidTerrainTypes[resourceID] = {};
						end
						table.insert(self.ValidTerrainTypes[resourceID], terrainType );
					end
				end
				-- by default, certain resources also have a hill entry (even though it isnt a terrain type).
				-- a resource with this tag can be placed anywhere on a hill, even if it is an otherwise invalid terrain type.
				if valid_terrain_data.TerrainType == "TERRAIN_HILL" then
					table.insert(self.ValidTerrainTypes[resourceID], "TERRAIN_HILL" );
				end
			end
		end
		
		
		-- ===============================================================
		-- Valid Features
		-- ===============================================================
		for feature_data in GameInfo.Features() do
			table.insert(self.FeatureList, feature_data.Type);
		end

		for valid_feature_data in GameInfo.Resource_FeatureBooleans() do
			if valid_feature_data.ResourceType == resourceType then
				for i, featureType in ipairs(self.FeatureList) do
					if valid_feature_data.FeatureType == featureType then
						if self.ValidFeatureTypes[resourceID] == nil then
							self.ValidFeatureTypes[resourceID] = {};
						end
						table.insert(self.ValidFeatureTypes[resourceID], featureType);
					end
				end
			end
		end
		
		-- ===============================================================
		-- Valid Feature Terrain (Valid Terrains where it also needs a feature)
		-- Uses Terrainlist from ValidTerrains
		-- ===============================================================
		for valid_terrain_feature_data in GameInfo.Resource_FeatureTerrainBooleans() do
			if valid_terrain_feature_data.ResourceType == resourceType then
				for i, terrainFeatureType in ipairs(self.TerrainList) do
					if valid_terrain_feature_data.TerrainType == terrainFeatureType then
						if self.ValidTerrainFeatureTypes[resourceID] == nil then
							self.ValidTerrainFeatureTypes[resourceID] = {};
						end
						table.insert(self.ValidTerrainFeatureTypes[resourceID], terrainFeatureType );
					end
				end
			end
		end
		-- ===============================================================
		for _ , validTerrain in pairs(TerrainTypes) do
			print("TerrainType: " .. validTerrain);
		end

		--===============================================================

		if resourceType == "RESOURCE_WHEAT" then
			self.wheat_ID = resourceID;
		elseif resourceType == "RESOURCE_COW" then
			self.cow_ID = resourceID;
		elseif resourceType == "RESOURCE_DEER" then
			self.deer_ID = resourceID;
		elseif resourceType == "RESOURCE_BANANA" then
			self.banana_ID = resourceID;
		elseif resourceType == "RESOURCE_FISH" then
			self.fish_ID = resourceID;
		elseif resourceType == "RESOURCE_SHEEP" then
			self.sheep_ID = resourceID;
		elseif resourceType == "RESOURCE_STONE" then
			self.stone_ID = resourceID;
		-- Set up Strategic IDs
		elseif resourceType == "RESOURCE_IRON" then
			self.iron_ID = resourceID;
		elseif resourceType == "RESOURCE_HORSE" then
			self.horse_ID = resourceID;
		elseif resourceType == "RESOURCE_COAL" then
			self.coal_ID = resourceID;
		elseif resourceType == "RESOURCE_OIL" then
			self.oil_ID = resourceID;
		elseif resourceType == "RESOURCE_ALUMINUM" then
			self.aluminum_ID = resourceID;
		elseif resourceType == "RESOURCE_URANIUM" then
			self.uranium_ID = resourceID;
		-- Set up Luxury IDs
		elseif resourceType == "RESOURCE_WHALE" then
			self.whale_ID = resourceID;
		elseif resourceType == "RESOURCE_PEARLS" then
			self.pearls_ID = resourceID;
		elseif resourceType == "RESOURCE_IVORY" then
			self.ivory_ID = resourceID;
		elseif resourceType == "RESOURCE_FUR" then
			self.fur_ID = resourceID;
		elseif resourceType == "RESOURCE_SILK" then
			self.silk_ID = resourceID;
		elseif resourceType == "RESOURCE_DYE" then
			self.dye_ID = resourceID;
		elseif resourceType == "RESOURCE_SPICES" then
			self.spices_ID = resourceID;
		elseif resourceType == "RESOURCE_SUGAR" then
			self.sugar_ID = resourceID;
		elseif resourceType == "RESOURCE_COTTON" then
			self.cotton_ID = resourceID;
		elseif resourceType == "RESOURCE_WINE" then
			self.wine_ID = resourceID;
		elseif resourceType == "RESOURCE_INCENSE" then
			self.incense_ID = resourceID;
		elseif resourceType == "RESOURCE_GOLD" then
			self.gold_ID = resourceID;
		elseif resourceType == "RESOURCE_SILVER" then
			self.silver_ID = resourceID;
		elseif resourceType == "RESOURCE_GEMS" then
			self.gems_ID = resourceID;
		elseif resourceType == "RESOURCE_MARBLE" then
			self.marble_ID = resourceID;
		-- Set up Expansion Pack Luxury IDs
		elseif resourceType == "RESOURCE_COPPER" then
			self.copper_ID = resourceID;
		elseif resourceType == "RESOURCE_SALT" then
			self.salt_ID = resourceID;
		elseif resourceType == "RESOURCE_CITRUS" then
			self.citrus_ID = resourceID;
		elseif resourceType == "RESOURCE_TRUFFLES" then
			self.truffles_ID = resourceID;
		elseif resourceType == "RESOURCE_CRAB" then
			self.crab_ID = resourceID;
		elseif resourceType == "RESOURCE_COCOA" then
			self.cocoa_ID = resourceID;
		elseif resourceType == "RESOURCE_BISON" then
			self.bison_ID = resourceID;
		-- Mod Luxury IDs
		elseif resourceType == "RESOURCE_COFFEE" then	-- MOD.Barathor: New
			self.coffee_ID = resourceID;
		elseif resourceType == "RESOURCE_TEA" then		-- MOD.Barathor: New
			self.tea_ID = resourceID;
		elseif resourceType == "RESOURCE_TOBACCO" then	-- MOD.Barathor: New
			self.tobacco_ID = resourceID;
		elseif resourceType == "RESOURCE_AMBER" then	-- MOD.Barathor: New
			self.amber_ID = resourceID;
		elseif resourceType == "RESOURCE_JADE" then		-- MOD.Barathor: New
			self.jade_ID = resourceID;
		elseif resourceType == "RESOURCE_OLIVE" then	-- MOD.Barathor: New
			self.olives_ID = resourceID;
		elseif resourceType == "RESOURCE_PERFUME" then	-- MOD.Barathor: New
			self.perfume_ID = resourceID;
		elseif resourceType == "RESOURCE_CORAL" then	-- MOD.Barathor: New
			self.coral_ID = resourceID;
		elseif resourceType == "RESOURCE_LAPIS" then	-- MOD.Barathor: New
			self.lapis_ID = resourceID;
		-- Even More Resources for Vox Populi (luxuries)
		elseif resourceType == "RESOURCE_LAVENDER" then	-- MOD.HungryForFood: New
			self.lavender_ID = resourceID;
		elseif resourceType == "RESOURCE_OBSIDIAN" then	-- MOD.HungryForFood: New
			self.obsidian_ID = resourceID;
		elseif resourceType == "RESOURCE_PLATINUM" then	-- MOD.HungryForFood: New
			self.platinum_ID = resourceID;
		elseif resourceType == "RESOURCE_POPPY" then	-- MOD.HungryForFood: New
			self.poppy_ID = resourceID;
		elseif resourceType == "RESOURCE_TIN" then		-- MOD.HungryForFood: New
			self.tin_ID = resourceID;
		-- Even More Resources for Vox Populi (bonus)
		elseif resourceType == "RESOURCE_COCONUT" then	-- MOD.HungryForFood: New
			self.coconut_ID = resourceID;
		elseif resourceType == "RESOURCE_HARDWOOD" then	-- MOD.HungryForFood: New
			self.hardwood_ID = resourceID;
		elseif resourceType == "RESOURCE_LEAD" then		-- MOD.HungryForFood: New
			self.lead_ID = resourceID;
		elseif resourceType == "RESOURCE_MAIZE" then	-- MOD.HungryForFood: New
			self.maize_ID = resourceID;
		elseif resourceType == "RESOURCE_PINEAPPLE" then	-- MOD.HungryForFood: New
			self.pineapple_ID = resourceID;
		elseif resourceType == "RESOURCE_POTATO" then	-- MOD.HungryForFood: New
			self.potato_ID = resourceID;
		elseif resourceType == "RESOURCE_RICE" then	-- MOD.HungryForFood: New
			self.rice_ID = resourceID;
		elseif resourceType == "RESOURCE_RUBBER" then	-- MOD.HungryForFood: New
			self.rubber_ID = resourceID;
		elseif resourceType == "RESOURCE_SULFUR" then	-- MOD.HungryForFood: New
			self.sulfur_ID = resourceID;
		elseif resourceType == "RESOURCE_TITANIUM" then	-- MOD.HungryForFood: New
			self.titanium_ID = resourceID;
		end
	end
	
	if self.coral_ID ~= nil then
		self.bModLuxes = true;
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:__InitLuxuryWeights()
	-- Initialize luxury data table. Index == Region Type
	-- Customize this function if the terrain will fall significantly
	-- outside Earth normal, or if region definitions have been modified.
	
	-- Note: The water-based luxuries are set to appear in a region only if that region has its start on the coast.
	-- So the weights shown for those are reduced in practice to the degree that a map has inland starts.


	-- MOD.EAP: attempt to pull weights also from xml if able

	print("########## Lux weights ##########");
	local luxury_region_weights_dummy = {};
	if GameInfo.Resource_LuxuryRegionsWeights ~= nil then
		for weight_data in GameInfo.Resource_LuxuryRegionsWeights() do
			luxuryWeightID = weight_data.ID;
			luxuryType = weight_data.ResourceType;
			regionWeight = { weight_data.RegionTundra, weight_data.RegionJungle, weight_data.RegionForest, weight_data.RegionDesert, 
							weight_data.RegionHills, weight_data.RegionPlains, weight_data.RegionGrass, weight_data.RegionHybrid,
						weight_data.RegionWetlands, weight_data.RegionFallback, weight_data.RegionCityState };

			for i = 1, #regionWeight do
				if regionWeight[i] ~= 0 then
					if luxury_region_weights_dummy[i] == nil then
						luxury_region_weights_dummy[i] = {};
					end
					table.insert(luxury_region_weights_dummy[i], {luxuryType, regionWeight[i]});
				end
			end

			
		end
	end

	-- MOD.EAP: END
		
	
	if self.bModLuxes == true then

		self.luxury_region_weights[1] = {			-- Tundra
		{self.fur_ID,		40},
		{self.marble_ID,	10},
		{self.silver_ID,	40},
		{self.amber_ID,		40},
		{self.salt_ID,		40},
		{self.gold_ID,		10},
		{self.copper_ID,	10},
		{self.gems_ID,		10},
		{self.jade_ID,		10},
		{self.lapis_ID,		10},
		{self.whale_ID,		10},
		{self.crab_ID,		10},
		{self.pearls_ID,	10},
		{self.obsidian_ID,	10},
		{self.coral_ID,		10},	};

		self.luxury_region_weights[2] = {			-- Jungle
		{self.citrus_ID,	40},
		{self.cocoa_ID,		40},
		{self.spices_ID,	40},
		{self.sugar_ID,		40},
		{self.obsidian_ID,	40},
		{self.coconut_ID,	40},
		{self.rubber_ID,	40},
		{self.truffles_ID,	40},
		{self.silk_ID,		10},
		{self.dye_ID,		10},
		{self.fur_ID,		10},
		{self.whale_ID,		10},
		{self.crab_ID,		10},
		{self.pearls_ID,	10},
		{self.coral_ID,		10},	};
		
		self.luxury_region_weights[3] = {			-- Forest
		{self.truffles_ID,	40},
		{self.marble_ID,	05},
		{self.silk_ID,		10},
		{self.dye_ID,		10},
		{self.fur_ID,		40},
		{self.coconut_ID,	10},
		{self.rubber_ID,	10},
		{self.citrus_ID,	10},
		{self.cocoa_ID,		10},
		{self.spices_ID,	10},
		{self.sugar_ID,		10},
		{self.whale_ID,		10},
		{self.crab_ID,		10},
		{self.pearls_ID,	10},
		{self.coral_ID,		10},	};
		
		self.luxury_region_weights[4] = {			-- Desert
		{self.incense_ID,	40},
		{self.marble_ID,	05},
		{self.salt_ID,		40},
		{self.gold_ID,		40},
		{self.lapis_ID,		40},
		{self.obsidian_ID,	10},
		{self.copper_ID,	10},
		{self.silver_ID,	10},
		{self.amber_ID,		10},
		{self.gems_ID,		10},
		{self.jade_ID,		10},
		{self.whale_ID,		10},
		{self.crab_ID,		10},
		{self.pearls_ID,	10},
		{self.coral_ID,		10},	};
		
		self.luxury_region_weights[5] = {			-- Hills
		{self.gold_ID,		30},
		{self.marble_ID,	15},
		{self.silver_ID,	30},
		{self.copper_ID,	30},
		{self.gems_ID,		30},
		{self.salt_ID,		30},
		{self.jade_ID,		30},
		{self.amber_ID,		30},
		{self.lapis_ID,		30},
		{self.obsidian_ID,	30},
		{self.whale_ID,		10},
		{self.crab_ID,		10},
		{self.pearls_ID,	10},
		{self.coral_ID,		10},	};

		
		self.luxury_region_weights[6] = {			-- Plains
		{self.incense_ID,	40},
		{self.marble_ID,	10},
		{self.ivory_ID,		40},
		{self.wine_ID,		40},
		{self.olives_ID,	40},
		{self.coffee_ID,	40},
		{self.tobacco_ID,	10},
		{self.tea_ID,		10},
		{self.perfume_ID,	40},
		{self.cotton_ID,	10},
		{self.whale_ID,		10},
		{self.crab_ID,		10},
		{self.pearls_ID,	10},
		{self.coral_ID,		10},	};
		
		self.luxury_region_weights[7] = {			-- Grass
		{self.tobacco_ID,	40},
		{self.marble_ID,	10},
		{self.tea_ID,		40},
		{self.cotton_ID,	40},
		{self.perfume_ID,	25},
		{self.ivory_ID,		10},
		{self.wine_ID,		10},
		{self.olives_ID,	25},
		{self.coffee_ID,	25},
		{self.whale_ID,		10},
		{self.crab_ID,		10},
		{self.pearls_ID,	10},
		{self.coral_ID,		10},	};
		
		self.luxury_region_weights[8] = {			-- Hybrid
		{self.gold_ID,		30},
		{self.marble_ID,	15},
		{self.silver_ID,	30},					-- MOD.Barathor: Favor very flexible resources, like resources that are mined or in the water.
		{self.copper_ID,	30},
		{self.gems_ID,		30},
		{self.salt_ID,		30},
		{self.jade_ID,		30},
		{self.amber_ID,		30},
		{self.lapis_ID,		30},
		{self.obsidian_ID,	30},
		{self.coffee_ID,	05},
		{self.coconut_ID,	05},
		{self.rubber_ID,	05},
		{self.tobacco_ID,	05},
		{self.tea_ID,		05},
		{self.perfume_ID,	05},
		{self.cotton_ID,	05},
		{self.ivory_ID,		05},
		{self.wine_ID,		05},
		{self.olives_ID,	05},
		{self.incense_ID,	05},
		{self.truffles_ID,	05},
		{self.silk_ID,		05},
		{self.dye_ID,		05},
		{self.fur_ID,		05},
		{self.citrus_ID,	05},
		{self.cocoa_ID,		05},
		{self.spices_ID,	05},
		{self.sugar_ID,		05},
		{self.whale_ID,		20},
		{self.crab_ID,		20},
		{self.pearls_ID,	20},
		{self.coral_ID,		20},	};

		self.luxury_region_weights[9] = {			-- Wetlands
		{self.tobacco_ID,	40},
		{self.tea_ID,		40},
		{self.perfume_ID,	20},
		{self.cotton_ID,	30},
		{self.olives_ID,	20},
		{self.silver_ID,	20},
		{self.sugar_ID,		20},
		{self.copper_ID,	20},
		{self.coral_ID,		20},
		{self.crab_ID,		25},
		{self.pearls_ID,	25},
		{self.coconut_ID,	30},
		{self.rubber_ID,	05},
		{self.whale_ID,		25},
		{self.cocoa_ID,		10},
		{self.truffles_ID,	05},
		{self.spices_ID,	05},
		{self.gems_ID,		20},	};
		
		self.luxury_fallback_weights = {			-- Random / Fallback
		{self.gold_ID,		10},
		{self.silver_ID,	10},					-- MOD.Barathor: Favor water resources since they work great as randoms and make the coasts more interesting. 
		{self.copper_ID,	10},					--				 Also, slightly favor mined resources for their flexibility.
		{self.gems_ID,		10},
		{self.marble_ID,	05},
		{self.salt_ID,		10},
		{self.jade_ID,		10},
		{self.amber_ID,		10},
		{self.lapis_ID,		10},
		{self.obsidian_ID,	10},
		{self.coffee_ID,	05},
		{self.tobacco_ID,	05},
		{self.tea_ID,		05},
		{self.perfume_ID,	05},
		{self.cotton_ID,	05},
		{self.ivory_ID,		05},
		{self.wine_ID,		05},
		{self.olives_ID,	05},
		{self.incense_ID,	05},
		{self.truffles_ID,	05},
		{self.silk_ID,		05},
		{self.dye_ID,		05},
		{self.fur_ID,		05},
		{self.citrus_ID,	05},
		{self.cocoa_ID,		05},
		{self.spices_ID,	05},
		{self.sugar_ID,		05},
		{self.whale_ID,		30},
		{self.crab_ID,		30},
		{self.pearls_ID,	30},
		{self.coconut_ID,	05},
		{self.rubber_ID,	05},
		{self.coral_ID,		30},	};

		self.luxury_city_state_weights = {			-- City States	
		{self.gold_ID,		05},
		{self.obsidian_ID,	05},
		{self.marble_ID,	05},
		{self.silver_ID,	05},					-- MOD.Barathor: Slightly favor water resources since they're flexible and most city-states are coastal.
		{self.copper_ID,	05},					--				 Also, slightly favor mined resources for their flexibility.
		{self.gems_ID,		05},
		{self.salt_ID,		05},
		{self.jade_ID,		05},
		{self.amber_ID,		05},
		{self.lapis_ID,		05},
		{self.coffee_ID,	05},
		{self.tobacco_ID,	05},
		{self.tea_ID,		05},
		{self.perfume_ID,	05},
		{self.cotton_ID,	05},
		{self.ivory_ID,		05},
		{self.wine_ID,		05},
		{self.olives_ID,	05},
		{self.incense_ID,	05},
		{self.truffles_ID,	05},
		{self.silk_ID,		05},
		{self.dye_ID,		05},
		{self.fur_ID,		05},
		{self.citrus_ID,	05},
		{self.cocoa_ID,		05},
		{self.spices_ID,	05},
		{self.sugar_ID,		05},
		{self.coconut_ID,	05},
		{self.rubber_ID,	05},
		{self.whale_ID,		30},
		{self.crab_ID,		30},
		{self.pearls_ID,	30},
		{self.coral_ID,		30},	};
	else
		self.luxury_region_weights[1] = {			-- Tundra
		{self.fur_ID,		40},
		{self.marble_ID,	10},
		{self.whale_ID,		25},
		{self.crab_ID,		25},
		{self.pearls_ID,	25},
		{self.silver_ID,	25},
		{self.copper_ID,	15},
		{self.salt_ID,		20},
		{self.gems_ID,		05},
		{self.dye_ID,		05},	};

		self.luxury_region_weights[2] = {			-- Jungle
		{self.cocoa_ID,		35},
		{self.citrus_ID,	35},
		{self.spices_ID,	35},
		{self.gems_ID,		25},
		{self.sugar_ID,		20},
		{self.pearls_ID,	25},
		{self.copper_ID,	05},
		{self.truffles_ID,	25},
		{self.crab_ID,		25},
		{self.whale_ID,		25},
		{self.silk_ID,		25},
		{self.dye_ID,		25},	};
		
		self.luxury_region_weights[3] = {			-- Forest
		{self.dye_ID,		10},
		{self.silk_ID,		10},
		{self.truffles_ID,	30},
		{self.fur_ID,		10},
		{self.spices_ID,	10},
		{self.citrus_ID,	05},
		{self.salt_ID,		05},
		{self.copper_ID,	05},
		{self.cocoa_ID,		05},
		{self.crab_ID,		25},
		{self.whale_ID,		25},
		{self.pearls_ID,	25},	};
		
		self.luxury_region_weights[4] = {			-- Desert
		{self.incense_ID,	35},
		{self.salt_ID,		25},
		{self.marble_ID,	05},
		{self.gold_ID,		25},
		{self.copper_ID,	25},
		{self.cotton_ID,	15},
		{self.sugar_ID,		15},
		{self.pearls_ID,	25},
		{self.crab_ID,		25},
		{self.whale_ID,		25},
		{self.citrus_ID,	05},	};
		
		self.luxury_region_weights[5] = {			-- Hills
		{self.gold_ID,		30},
		{self.marble_ID,	15},
		{self.silver_ID,	30},
		{self.copper_ID,	30},
		{self.gems_ID,		30},
		{self.pearls_ID,	25},
		{self.salt_ID,		20},
		{self.crab_ID,		25},
		{self.whale_ID,		25},	};
		
		self.luxury_region_weights[6] = {			-- Plains
		{self.ivory_ID,		35},
		{self.wine_ID,		35},
		{self.marble_ID,	05},
		{self.salt_ID,		05},
		{self.incense_ID,	25},
		{self.spices_ID,	25},
		{self.whale_ID,		25},
		{self.pearls_ID,	25},
		{self.crab_ID,		25},
		{self.truffles_ID,	25},
		{self.gold_ID,		25},	};
		
		self.luxury_region_weights[7] = {			-- Grass
		{self.cotton_ID,	30},
		{self.marble_ID,	10},
		{self.silver_ID,	20},
		{self.sugar_ID,		20},
		{self.copper_ID,	20},
		{self.crab_ID,		25},
		{self.pearls_ID,	25},
		{self.whale_ID,		25},
		{self.cocoa_ID,		25},
		{self.truffles_ID,	05},
		{self.spices_ID,	05},
		{self.gems_ID,		25},	};
		
		self.luxury_region_weights[8] = {			-- Hybrid
		{self.ivory_ID,		15},
		{self.cotton_ID,	15},
		{self.wine_ID,		15},
		{self.marble_ID,	10},
		{self.silver_ID,	10},
		{self.salt_ID,		05},
		{self.copper_ID,	20},
		{self.whale_ID,		25},
		{self.pearls_ID,	25},
		{self.crab_ID,		25},
		{self.truffles_ID,	10},
		{self.cocoa_ID,		10},
		{self.spices_ID,	05},
		{self.sugar_ID,		05},
		{self.citrus_ID,	05},
		{self.incense_ID,	05},
		{self.silk_ID,		05},
		{self.gems_ID,		15},
		{self.gold_ID,		05},	};

		self.luxury_region_weights[9] = {			-- Wetlands
		{self.cotton_ID,	30},
		{self.silver_ID,	20},
		{self.sugar_ID,		20},
		{self.copper_ID,	20},
		{self.crab_ID,		25},
		{self.pearls_ID,	25},
		{self.whale_ID,		25},
		{self.cocoa_ID,		10},
		{self.truffles_ID,	05},
		{self.spices_ID,	05},
		{self.gems_ID,		20},	};
		
		self.luxury_fallback_weights = {			-- Fallbacks, in case of extreme map conditions, or
		{self.whale_ID,		10},					-- for games with oodles of civilizations.
		{self.pearls_ID,	10},
		{self.gold_ID,		10},
		{self.marble_ID,	05},
		{self.silver_ID,	05},					-- This list is also used to assign Disabled and Random types.
		{self.gems_ID,		10},					-- So it's important that this list contain every available luxury type.
		{self.ivory_ID,		05},
		{self.fur_ID,		10},					-- NOTE: Marble affects Wonders, so is handled as a special case, on the side.
		{self.dye_ID,		05},
		{self.spices_ID,	05},
		{self.silk_ID,		05},
		{self.sugar_ID,		05},
		{self.cotton_ID,	05},
		{self.wine_ID,		05},
		{self.incense_ID,	05},
		{self.copper_ID,	05},
		{self.salt_ID,		05},
		{self.citrus_ID,	05},
		{self.truffles_ID,	05},
		{self.cocoa_ID,		05},
		{self.crab_ID,		10},	};

		self.luxury_city_state_weights = {			-- Weights for City States
		{self.whale_ID,		5},					-- Leaning toward types that are used less often by civs.
		{self.pearls_ID,	5},
		{self.gold_ID,		5},
		{self.marble_ID,	5},					-- Recommended that this list also contains every available luxury.
		{self.silver_ID,	5},
		{self.gems_ID,		5},					-- NOTE: Marble affects Wonders, so is handled as a special case, on the side.
		{self.ivory_ID,		5},
		{self.fur_ID,		10},
		{self.dye_ID,		20},
		{self.spices_ID,	20},
		{self.silk_ID,		20},
		{self.sugar_ID,		25},
		{self.cotton_ID,	20},
		{self.wine_ID,		20},
		{self.incense_ID,	25},
		{self.copper_ID,	5},
		{self.salt_ID,		5},
		{self.citrus_ID,	5},
		{self.truffles_ID,	5},
		{self.cocoa_ID,		5},
		{self.crab_ID,		5},	};
	end
end	
------------------------------------------------------------------------------
function AssignStartingPlots:__CustomInit()
	-- This function included to provide a quick and easy override for changing 
	-- any initial settings. Add your customized version to the map script.
end
------------------------------------------------------------------------------
-- MOD.EAP: New
function AssignStartingPlots:GenerateMainlandCoastalPlotTables()

	-- This function sets up 3 tables that contains coastal plots that are 1, 2 and 3 tiles away from the mainland.
	-- It also sets up a table containing all mainland coastal plots.
	
	local iW, iH = Map.GetGridSize()
	local plotDataImmediateCoast = {};
	local plotDataNextToImmediateCoast ={};
	local plotDataIsThreeFromMainland = {};

	plotDataImmediateCoast, plotDataNextToImmediateCoast = GenerateMainlandExpandedCoastData();
	plotDataIsThreeFromMainland = GenerateThreeFromMainlandCoast(plotDataImmediateCoast, plotDataNextToImmediateCoast);

	-- create a single combined mainland coast list *and* separate ones
	for x = 0, iW - 1 do
		for y = 0, iH - 1 do
			local i = iW * y + x + 1;
			local plot = Map.GetPlot(x, y);
			local terrainType = plot:GetTerrainType();
			local plotType = plot:GetPlotType();
			if plotDataImmediateCoast[i] == true then
				table.insert(self.mainland_coast_list, i);
				table.insert(self.mainland_coast_list_inner, i);
			elseif plotDataNextToImmediateCoast[i] == true then
				table.insert(self.mainland_coast_list, i);
				table.insert(self.mainland_coast_list_second, i);
			elseif plotDataIsThreeFromMainland[i] == true then
				table.insert(self.mainland_coast_list, i);
				table.insert(self.mainland_coast_list_outer, i);
			elseif terrainType == TerrainTypes.TERRAIN_COAST and not plot:IsLake() then
				table.insert(self.non_mainland_coast_list, i);
			else -- plot is not a coast tile, insert false to keep the table index in sync with the plot index
				table.insert(self.mainland_coast_list, false);
				table.insert(self.mainland_coast_list_inner, false);
				table.insert(self.mainland_coast_list_second, false);
				table.insert(self.mainland_coast_list_outer, false);
				table.insert(self.non_mainland_coast_list, false);
			end
		end
	end
end
------------------------------------------------------------------------------
-- MOD.EAP: New
function AssignStartingPlots:SortResourcePreferenceTable()

	local preference_lists = {};

	-- Use the default values in the config if the table does not exist
	if GameInfo.Resource_Preferences == nil then
		print("Resource_Preferences table does not exist, using default values.")
		preference_lists = Default_Resource_Preferences; 
	else
		for preference_data in GameInfo.Resource_Preferences() do
			table.insert(preference_lists, preference_data);
		end
	end
	while #preference_lists > 0 do
		local chosen_preference_id = nil;
		local chosen_preference_complexity = 0;
		for i, preference_data in pairs(preference_lists) do
			local preference_complexity = self:GetPreferenceComplexity(preference_data);
			if chosen_preference_id == nil then
				chosen_preference_id = i;
				chosen_preference_complexity = preference_complexity;

			else
				if preference_complexity > chosen_preference_complexity then
					chosen_preference_id = i;
					chosen_preference_complexity = preference_complexity;	
				end
			end
		end

		if chosen_preference_complexity == 0 then
			-- no preference data found, just dump the rest in the list
			for i, preference in pairs(preference_lists) do
				table.insert(self.ordered_preference_list, preference);
			end
			preference_lists = {};
		else
			table.insert(self.ordered_preference_list, preference_lists[chosen_preference_id]);
			table.remove(preference_lists, chosen_preference_id);
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetPreferenceComplexity(preference)

	--[[ 
		MOD.EAP: Here we define how complex a preference entry is by adding a score for each element.
		If a terrain type AND a feature type are both specified, the tile is considered more complex. 
		TERRAIN_HILL however is treated as a less complex entry than specifying another terrain type 
		as hills can be any (plains, grassland etc.)
	]]
	
	local complexity = 0;

	if preference.TerrainType ~= "TERRAIN_NONE" then
		complexity = complexity + 10;
		if preference.TerrainType == "TERRAIN_HILL" then
			complexity = complexity - 5;
		end
	end

	if preference.FeatureType ~= "FEATURE_NONE" then
		complexity = complexity + 10;
	end

	return complexity
end
------------------------------------------------------------------------------
function AssignStartingPlots:ApplyHexAdjustment(x, y, plot_adjustments)
	-- Used this bit of code so many times, I had to make it a function.
	local iW, iH = Map.GetGridSize();
	local adjusted_x, adjusted_y;
	if Map:IsWrapX() == true then
		adjusted_x = (x + plot_adjustments[1]) % iW;
	else
		adjusted_x = x + plot_adjustments[1];
	end
	if Map:IsWrapY() == true then
		adjusted_y = (y + plot_adjustments[2]) % iH;
	else
		adjusted_y = y + plot_adjustments[2];
	end
	return adjusted_x, adjusted_y;
end
------------------------------------------------------------------------------
-- Start of functions tied to GenerateRegions()
------------------------------------------------------------------------------
function AssignStartingPlots:MeasureStartPlacementFertilityOfPlot(x, y, checkForCoastalLand)
	-- Fertility of plots is used to divide continents or areas in to Regions.
	-- Regions are used to assign starting plots and place some resources.
	-- Usage: x, y are plot coords, with 0,0 in SW. The check is a boolean.
	--
	--[[ Mountain, Oasis, FloodPlain tiles = -2, 5, 6 and do not count anything else.
	     Rest of the tiles add up values of tile traits.
	     Terrain: Grass 4, Plains 3, Tundra 2, Coast 2, Desert 1, Snow -1
	     Features: Hill 1, Forest 1, FreshWater 1, River 1, Jungle -1, Marsh -1, Ice -1
	     We want players who start in Grass to have the least room to expand. ]]--
	--[[ If you modify the terrain values or add or remove any terrain elements, you
		 will need to add or modify processes here to accomodate your changes. Please 
		 be aware that the default process includes numerous assumptions that your
		 terrain changes may invalidate, so you may need to rebalance the system. ]]--
	--
	local plot = Map.GetPlot(x, y);
	local plotFertility = 0;
	local plotType = plot:GetPlotType();
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	-- Measure Fertility -- Any cases absent from the process have a 0 value.

	if plotType == PlotTypes.PLOT_MOUNTAIN then -- Note, mountains cannot belong to a landmass AreaID, so they usually go unmeasured.
		plotFertility = -1;
	elseif terrainType == TerrainTypes.TERRAIN_SNOW then
		plotFertility = -2;
	elseif featureType == FeatureTypes.FEATURE_ICE then
		plotFertility = -1;
	elseif plotType == PlotTypes.PLOT_OCEAN then
		plotFertility = 2; -- EAP NOTE: we can set this to 0 to make regions ignore coastal tiles potentially. OR make it BIG and make coastals have no room. Let's see
	elseif featureType == FeatureTypes.FEATURE_OASIS then
		plotFertility = 4; -- Reducing Oasis value slightly. -1/26/2011 BT
	elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
		plotFertility = 4; -- Reducing Flood Plains value slightly. -1/26/2011 BT
	else
		if terrainType == TerrainTypes.TERRAIN_GRASS then -- Reversing values for Grass and Plains. -1/26/2011 BT
			plotFertility = 3;
		elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
			plotFertility = 4;
		elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
			plotFertility = 1;
		elseif terrainType == TerrainTypes.TERRAIN_DESERT then
			plotFertility = -1;
		end
		if plotType == PlotTypes.PLOT_HILLS then
			--if terrainType == TerrainTypes.TERRAIN_DESERT then
				plotFertility = plotFertility + 1;
			--else
				plotFertility = plotFertility + 1;
			--end
		end
		if featureType == FeatureTypes.FEATURE_FOREST then
			if terrainType == TerrainTypes.TERRAIN_TUNDRA then
				plotFertility = plotFertility + 0;
			else
				plotFertility = plotFertility + 0; -- Removing forest bonus as a balance tweak. -1/26/2011 BT
			end
		elseif featureType == FeatureTypes.FEATURE_JUNGLE then
			plotFertility = plotFertility - 1;
		elseif featureType == FeatureTypes.FEATURE_MARSH then
			plotFertility = plotFertility - 2; -- Increasing penalty for Marsh plots. -1/26/2011 BT
		end
		if plot:IsRiverSide() or plot:IsFreshWater() then
			plotFertility = plotFertility + 1;
		end
		if checkForCoastalLand == true then -- When measuring only one AreaID, this shortcut helps account for coastal plots not measured.
			if plot:IsCoastalLand() then
				plotFertility = plotFertility + 2;
				-- we can increase this to make corner regions smaller
			end
		end
	end

	return plotFertility
end
------------------------------------------------------------------------------
function AssignStartingPlots:MeasureStartPlacementFertilityInRectangle(iWestX, iSouthY, iWidth, iHeight)
	-- This function is designed to provide initial data for regional division recursion.
	-- Loop through plots in this rectangle and measure Fertility Rating.
	-- Results will include a data table of all measured plots.
	local areaFertilityTable = {};
	local areaFertilityCount = 0;
	local plotCount = iWidth * iHeight;
	for y = iSouthY, iSouthY + iHeight - 1 do -- When generating a plot data table incrementally, process Y first so that plots go row by row.
		for x = iWestX, iWestX + iWidth - 1 do
			local plotFertility = self:MeasureStartPlacementFertilityOfPlot(x, y, false); -- Check for coastal land is disabled.
			table.insert(areaFertilityTable, plotFertility);
			areaFertilityCount = areaFertilityCount + plotFertility;
		end
	end

	-- Returns table, integer, integer.
	return areaFertilityTable, areaFertilityCount, plotCount
end
------------------------------------------------------------------------------
function AssignStartingPlots:MeasureStartPlacementFertilityOfLandmass(iAreaID, iWestX, iEastX, iSouthY, iNorthY, wrapsX, wrapsY)
	-- This function is designed to provide initial data for regional division recursion.
	-- Loop through plots in this landmass and measure Fertility Rating.
	-- Results will include a data table of all plots within the rectangle that includes the entirety of this landmass.
	--
	-- This function will account for any wrapping around the world this landmass may do.
	local iW, iH = Map.GetGridSize()
	local xEnd, yEnd; --[[ These coordinates will be used in case of wrapping landmass, 
	                       extending the landmass "off the map", in to imaginary space 
	                       to process it. Modulo math will correct the coordinates for 
	                       accessing the plot data array. ]]--
	if wrapsX then
		xEnd = iEastX + iW;
	else
		xEnd = iEastX;
	end
	if wrapsY then
		yEnd = iNorthY + iH;
	else
		yEnd = iNorthY;
	end
	--
	local areaFertilityTable = {};
	local areaFertilityCount = 0;
	local plotCount = 0;
	for yLoop = iSouthY, yEnd do -- When generating a plot data table incrementally, process Y first so that plots go row by row.
		for xLoop = iWestX, xEnd do
			plotCount = plotCount + 1;
			local x = xLoop % iW;
			local y = yLoop % iH;
			local plot = Map.GetPlot(x, y);
			local thisPlotsArea = plot:GetArea()
			if thisPlotsArea ~= iAreaID then -- This plot is not a member of the landmass, set value to 0
				table.insert(areaFertilityTable, 0);
			else -- This plot is a member, process it.
				local plotFertility = self:MeasureStartPlacementFertilityOfPlot(x, y, true); -- Check for coastal land is enabled.
				table.insert(areaFertilityTable, plotFertility);
				areaFertilityCount = areaFertilityCount + plotFertility;
			end
		end
	end
	
	-- Note: The table accounts for world wrap, so make sure to translate its index correctly.
	-- Plots in the table run from the southwest corner along the bottom row, then upward row by row, per normal plot data indexing.
	return areaFertilityTable, areaFertilityCount, plotCount
end
------------------------------------------------------------------------------
function AssignStartingPlots:RemoveDeadRows(fertility_table, iWestX, iSouthY, iWidth, iHeight)
	-- Any outside rows in the fertility table of a just-divided region that 
	-- contains all zeroes can be safely removed.
	-- This will improve the accuracy of operations involving any applicable region.
	local iW, iH = Map.GetGridSize()
	local adjusted_table = {};
	local adjusted_WestX;
	local adjusted_SouthY
	local adjusted_Width
	local adjusted_Height;
	
	-- Check for rows to remove on the bottom.
	local adjustSouth = 0;
	for y = 0, iHeight - 1 do
		local bKeepThisRow = false;
		for x = 0, iWidth - 1 do
			local i = y * iWidth + x + 1;
			if fertility_table[i] ~= 0 then
				bKeepThisRow = true;
				break
			end
		end
		if bKeepThisRow == true then
			break
		else
			adjustSouth = adjustSouth + 1;
		end
	end

	-- Check for rows to remove on the top.
	local adjustNorth = 0;
	for y = iHeight - 1, 0, -1 do
		local bKeepThisRow = false;
		for x = 0, iWidth - 1 do
			local i = y * iWidth + x + 1;
			if fertility_table[i] ~= 0 then
				bKeepThisRow = true;
				break
			end
		end
		if bKeepThisRow == true then
			break
		else
			adjustNorth = adjustNorth + 1;
		end
	end

	-- Check for columns to remove on the left.
	local adjustWest = 0;
	for x = 0, iWidth - 1 do
		local bKeepThisColumn = false;
		for y = 0, iHeight - 1 do
			local i = y * iWidth + x + 1;
			if fertility_table[i] ~= 0 then
				bKeepThisColumn = true;
				break
			end
		end
		if bKeepThisColumn == true then
			break
		else
			adjustWest = adjustWest + 1;
		end
	end

	-- Check for columns to remove on the right.
	local adjustEast = 0;
	for x = iWidth - 1, 0, -1 do
		local bKeepThisColumn = false;
		for y = 0, iHeight - 1 do
			local i = y * iWidth + x + 1;
			if fertility_table[i] ~= 0 then
				bKeepThisColumn = true;
				break
			end
		end
		if bKeepThisColumn == true then
			break
		else
			adjustEast = adjustEast + 1;
		end
	end

	if adjustSouth > 0 or adjustNorth > 0 or adjustWest > 0 or adjustEast > 0 then
		-- Truncate this region to remove dead rows.
		adjusted_WestX = (iWestX + adjustWest) % iW;
		adjusted_SouthY = (iSouthY + adjustSouth) % iH;
		adjusted_Width = (iWidth - adjustWest) - adjustEast;
		adjusted_Height = (iHeight - adjustSouth) - adjustNorth;
		-- Reconstruct fertility table. This must be done row by row, so process Y coord first.
		for y = 0, adjusted_Height - 1 do
			for x = 0, adjusted_Width - 1 do
				local i = (y + adjustSouth) * iWidth + (x + adjustWest) + 1;
				local plotFert = fertility_table[i];
				table.insert(adjusted_table, plotFert);
			end
		end
		--
		print("-");
		print("Removed Dead Rows, West: ", adjustWest, " East: ", adjustEast);
		print("Removed Dead Rows, South: ", adjustSouth, " North: ", adjustNorth);
		print("-");
		print("Incoming values: ", iWestX, iSouthY, iWidth, iHeight);
		print("Outgoing values: ", adjusted_WestX, adjusted_SouthY, adjusted_Width, adjusted_Height);
		print("-");
		local incoming_index = table.maxn(fertility_table);
		local outgoing_index = table.maxn(adjusted_table);
		print("Size of incoming fertility table: ", incoming_index);
		print("Size of outgoing fertility table: ", outgoing_index);
		--
		return adjusted_table, adjusted_WestX, adjusted_SouthY, adjusted_Width, adjusted_Height;
	
	else -- Region not adjusted, return original values unaltered.
		return fertility_table, iWestX, iSouthY, iWidth, iHeight;
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:DivideIntoRegions(iNumDivisions, fertility_table, rectangle_data_table)
	-- This is a recursive algorithm. (Original concept and implementation by Ed Beach).
	--
	-- Fertility table is a plot data array including data for all plots to be processed here.
	-- The fertility table is obtained as part of the MeasureFertility functions, or via division during the recursion.
	--
	-- Rectangle table includes seven data fields:
	-- westX, southY, width, height, AreaID, fertilityCount, plotCount
	--
	-- If AreaID is -1, it means the rectangle contains fertility data from all plots regardless of their AreaIDs.
	-- The plotCount is an absolute count of plots within the rectangle, without regard to AreaID membership.
	-- This is going to purposely reduce average fertility per plot for Order-of-Assignment priority.
	-- Rectangles with a lot of non-member plots will tend to be misshapen and need to be on the favorable side of minDistance elements.
	-- print("-"); print("DivideIntoRegions called.");

	--[[ Log dump of incoming table data. Activate for debug only.
	print("Data tables passed to DivideIntoRegions.");
	PrintContentsOfTable(fertility_table)
	PrintContentsOfTable(rectangle_data_table)
	print("End of this instance, DivideIntoRegions tables.");
	]]--
	
	local iNumDivides = 0;
	local iSubdivisions = 0;
	local bPrimeGreaterThanThree = false;
	local firstSubdivisions = 0;
	local laterSubdivisions = 0;

	-- If this rectangle is not to be divided, break recursion and record the data.
	if (iNumDivisions == 1) then -- This area is to be defined as a Region.
		-- Expand rectangle table to include an eighth field for average fertility per plot.
		local fAverageFertility = rectangle_data_table[6] / rectangle_data_table[7]; -- fertilityCount/plotCount
		table.insert(rectangle_data_table, fAverageFertility);
		-- Insert this record in to the instance data for start placement regions for this game.
		-- (This is the crux of the entire regional definition process, determining an actual region.)
		table.insert(self.regionData, rectangle_data_table);
		--
		local iNumberOfThisRegion = table.maxn(self.regionData);
		print("-");
		print("---------------------------------------------");
		print("Defined location of Start Region #", iNumberOfThisRegion);
		print("---------------------------------------------");
		print("-");
		--
		return

	--[[ Divide this rectangle into iNumDivisions worth of subdivisions, then send each
	     subdivision back through this function in a recursive loop. ]]--
	elseif (iNumDivisions > 1) then
		-- See if region is taller or wider.
		local iWidth = rectangle_data_table[3];
		local iHeight = rectangle_data_table[4];
		local bTaller = false;
		if iHeight > iWidth then
			bTaller = true;
		end

		-- If the number of divisions is 2 or 3, no further subdivision is required.
		if (iNumDivisions == 2) then
			iNumDivides = 2;
			iSubdivisions = 1;
		elseif (iNumDivisions == 3) then
			iNumDivides = 3;
			iSubdivisions = 1;
		
		-- If the number of divisions is greater than 3 and a prime number,
		-- divide all of these cases in to an odd plus an even number, then subdivide.
		--
		--[[ Ed's original algorithm skipped this step and produced "extra" divisions,
		     which I would have had to account for. I decided it was far far easier to
		     improve the algorithm and remove all extra divisions than it was to have
		     to write large chunks of code trying to process empty regions. Not to 
		     mention the added precision of using all land on the continent or map to
		     determine where to place major civilizations.  - Bob Thomas, April 2010 ]]--
		elseif (iNumDivisions == 5) then
			bPrimeGreaterThanThree = true;
			chopPercent = 59.2; -- These chopPercents are all set to undershoot slightly, averaging out the actual result closer to target.
			firstSubdivisions = 3; -- This is because if you aim for the exact target, there is never undershoot and almost always overshoot.
			laterSubdivisions = 2; -- So a well calibrated target ends up compensating for that overshoot factor, to improve total fairness.
		elseif (iNumDivisions == 7) then
			bPrimeGreaterThanThree = true;
			chopPercent = 42.2;
			firstSubdivisions = 3;
			laterSubdivisions = 4;
		elseif (iNumDivisions == 11) then
			bPrimeGreaterThanThree = true;
			chopPercent = 27;
			firstSubdivisions = 3;
			laterSubdivisions = 8;
		elseif (iNumDivisions == 13) then
			bPrimeGreaterThanThree = true;
			chopPercent = 38.1;
			firstSubdivisions = 5;
			laterSubdivisions = 8;
		elseif (iNumDivisions == 17) then
			bPrimeGreaterThanThree = true;
			chopPercent = 52.8;
			firstSubdivisions = 9;
			laterSubdivisions = 8;
		elseif (iNumDivisions == 19) then
			bPrimeGreaterThanThree = true;
			chopPercent = 36.7;
			firstSubdivisions = 7;
			laterSubdivisions = 12;

		-- If the number of divisions is greater than 3 and not a prime number,
		-- then chop this rectangle in to 2 or 3 parts and subdivide those.
		elseif (iNumDivisions == 4) then
			iNumDivides = 2;
			iSubdivisions = 2;
		elseif (iNumDivisions == 6) then
			iNumDivides = 3;
			iSubdivisions = 2;
		elseif (iNumDivisions == 8) then
			iNumDivides = 2;
			iSubdivisions = 4;
		elseif (iNumDivisions == 9) then
			iNumDivides = 3;
			iSubdivisions = 3;
		elseif (iNumDivisions == 10) then
			iNumDivides = 2;
			iSubdivisions = 5;
		elseif (iNumDivisions == 12) then
			iNumDivides = 3;
			iSubdivisions = 4;
		elseif (iNumDivisions == 14) then
			iNumDivides = 2;
			iSubdivisions = 7;
		elseif (iNumDivisions == 15) then
			iNumDivides = 3;
			iSubdivisions = 5;
		elseif (iNumDivisions == 16) then
			iNumDivides = 2;
			iSubdivisions = 8;
		elseif (iNumDivisions == 18) then
			iNumDivides = 3;
			iSubdivisions = 6;
		elseif (iNumDivisions == 20) then
			iNumDivides = 2;
			iSubdivisions = 10;
		elseif (iNumDivisions == 21) then
			iNumDivides = 3;
			iSubdivisions = 7;
		elseif (iNumDivisions == 22) then
			iNumDivides = 2;
			iSubdivisions = 11;
		else
			print("Erroneous number of regional divisions : ", iNumDivisions);
		end

		-- Now process the division via one of the three methods.
		-- All methods involve recursion, to obtain the best manner of subdividing each rectangle involved.
		if bPrimeGreaterThanThree then
			print("DivideIntoRegions: Uneven Division for handling prime numbers selected.");
			local results = self:ChopIntoTwoRegions(fertility_table, rectangle_data_table, bTaller, chopPercent);
			local first_section_fertility_table = results[1];
			local first_section_data_table = results[2];
			local second_section_fertility_table = results[3];
			local second_section_data_table = results[4];
			--
			self:DivideIntoRegions(firstSubdivisions, first_section_fertility_table, first_section_data_table)
			self:DivideIntoRegions(laterSubdivisions, second_section_fertility_table, second_section_data_table)

		else
			if (iNumDivides == 2) then
				print("DivideIntoRegions: Divide in to Halves selected.");
				local results = self:ChopIntoTwoRegions(fertility_table, rectangle_data_table, bTaller, 49.5); -- Undershoot by design, to compensate for inevitable overshoot. Gets the actual result closer to target.
				local first_section_fertility_table = results[1];
				local first_section_data_table = results[2];
				local second_section_fertility_table = results[3];
				local second_section_data_table = results[4];
				--
				self:DivideIntoRegions(iSubdivisions, first_section_fertility_table, first_section_data_table)
				self:DivideIntoRegions(iSubdivisions, second_section_fertility_table, second_section_data_table)

			elseif (iNumDivides == 3) then
				print("DivideIntoRegions: Divide in to Thirds selected.");
				local results = self:ChopIntoThreeRegions(fertility_table, rectangle_data_table, bTaller);
				local first_section_fertility_table = results[1];
				local first_section_data_table = results[2];
				local second_section_fertility_table = results[3];
				local second_section_data_table = results[4];
				local third_section_fertility_table = results[5];
				local third_section_data_table = results[6];
				--
				self:DivideIntoRegions(iSubdivisions, first_section_fertility_table, first_section_data_table)
				self:DivideIntoRegions(iSubdivisions, second_section_fertility_table, second_section_data_table)
				self:DivideIntoRegions(iSubdivisions, third_section_fertility_table, third_section_data_table)

			else
				print("Invalid iNumDivides value (from DivideIntoRegions): must be 2 or 3.");
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:ChopIntoThreeRegions(fertility_table, rectangle_data_table, bTaller, chopPercent)
	print("-"); print("ChopIntoThree called.");
	-- Performs the mechanics of dividing a region into three roughly equal fertility subregions.
	local results = {};

	-- Chop off the first third.
	local initial_results = self:ChopIntoTwoRegions(fertility_table, rectangle_data_table, bTaller, 33); -- Undershoot by a bit, tends to make the actual result closer to accurate.
	-- add first subdivision to results
	local temptable = initial_results[1];
	table.insert(results, temptable); 

	--[[ Activate table printouts for debug purposes only, then deactivate when done. ]]--
	--print("Data returned to ChopIntoThree from ChopIntoTwo.");
	--PrintContentsOfTable(temptable)

	local temptable = initial_results[2];
	table.insert(results, temptable);

	--PrintContentsOfTable(temptable)

	-- Prepare the remainder for further processing.
	local second_section_fertility_table = initial_results[3]; 

	--PrintContentsOfTable(second_section_fertility_table)

	local second_section_data_table = initial_results[4];

	--PrintContentsOfTable(second_section_data_table)
	--print("End of this instance, ChopIntoThree tables.");

	-- See if this piece is taller or wider. (Ed's original implementation skipped this step).
	local bTallerForRemainder = false;
	local width = second_section_data_table[3];
	local height = second_section_data_table[4];
	if height > width then
		bTallerForRemainder = true;
	end

	-- Chop the bigger piece in half.		
	local interim_results = self:ChopIntoTwoRegions(second_section_fertility_table, second_section_data_table, bTallerForRemainder, 48.5); -- Undershoot just a little.
	table.insert(results, interim_results[1]); 
	table.insert(results, interim_results[2]); 
	table.insert(results, interim_results[3]); 
	table.insert(results, interim_results[4]); 

	--[[ Returns a table of six entries, each of which is a nested table.
	1: fertility_table of first subdivision
	2: rectangle_data_table of first subdivision.
	3: fertility_table of second subdivision
	4: rectangle_data_table of second subdivision.
	5: fertility_table of third subdivision
	6: rectangle_data_table of third subdivision.  ]]--
	return results
end
------------------------------------------------------------------------------
function AssignStartingPlots:ChopIntoTwoRegions(fertility_table, rectangle_data_table, bTaller, chopPercent)
	-- Performs the mechanics of dividing a region into two subregions.
	--
	-- Fertility table is a plot data array including data for all plots to be processed here.
	-- This data already factors any need for processing AreaID.
	--
	-- Rectangle table includes seven data fields:
	-- westX, southY, width, height, AreaID, fertilityCount, plotCount
	--print("-"); print("ChopIntoTwo called.");

	--[[ Log dump of incoming table data. Activate for debug only.
	print("Data tables passed to ChopIntoTwoRegions.");
	PrintContentsOfTable(fertility_table)
	PrintContentsOfTable(rectangle_data_table)
	print("End of this instance, ChopIntoTwoRegions tables.");
	]]--

	-- Read the incoming data table.
	local iW, iH = Map.GetGridSize()
	local iWestX = rectangle_data_table[1];
	local iSouthY = rectangle_data_table[2];
	local iRectWidth = rectangle_data_table[3];
	local iRectHeight = rectangle_data_table[4];
	local iAreaID = rectangle_data_table[5];
	local iTargetFertility = rectangle_data_table[6] * chopPercent / 100;
	
	-- Now divide the region.
	--
	-- West and South edges remain the same for first region.
	local firstRegionWestX = iWestX;
	local firstRegionSouthY = iSouthY;
	-- scope variables that get decided conditionally.
	local firstRegionWidth, firstRegionHeight;
	local secondRegionWestX, secondRegionSouthY, secondRegionWidth, secondRegionHeight;
	local iFirstRegionFertility = 0;
	local iSecondRegionFertility = 0;
	local region_one_fertility = {};
	local region_two_fertility = {};

	if (bTaller) then -- We will divide horizontally, resulting in first region on bottom, second on top.
		--
		-- Width for both will remain the same as the parent rectangle.
		firstRegionWidth = iRectWidth;
		secondRegionWestX = iWestX;
		secondRegionWidth = iRectWidth;

		-- Measure one row at a time, moving up from bottom, until we have exceeded the target fertility.
		local reachedTargetRow = false;
		local rectY = 0;
		while reachedTargetRow == false do
			-- Process the next row in line.
			for rectX = 0, iRectWidth - 1 do
				local fertIndex = rectY * iRectWidth + rectX + 1;
				local plotFertility = fertility_table[fertIndex];
				-- Add this plot's fertility to the region total so far.
				iFirstRegionFertility = iFirstRegionFertility + plotFertility;
				-- Record this plot in a new fertility table. (Needed for further subdivisions).
				-- Note, building this plot data table incrementally, so it must go row by row.
				table.insert(region_one_fertility, plotFertility);
			end
			if iFirstRegionFertility >= iTargetFertility then
				-- This row has completed the region.
				firstRegionHeight = rectY + 1;
				secondRegionSouthY = (iSouthY + rectY + 1) % iH;
				secondRegionHeight = iRectHeight - firstRegionHeight;
				reachedTargetRow = true;
				break
			else
				rectY = rectY + 1;
			end
		end
		
		-- Debug printout of division location.
		print("Dividing along horizontal line between rows: ", secondRegionSouthY - 1, "-", secondRegionSouthY);
		
		-- Create the fertility table for the second region, the one on top.
		-- Data must be added row by row, to keep the table index behavior consistent.
		for rectY = firstRegionHeight, iRectHeight - 1 do
			for rectX = 0, iRectWidth - 1 do
				local fertIndex = rectY * iRectWidth + rectX + 1;
				local plotFertility = fertility_table[fertIndex];
				-- Add this plot's fertility to the region total so far.
				iSecondRegionFertility = iSecondRegionFertility + plotFertility;
				-- Record this plot in a new fertility table. (Needed for further subdivisions).
				-- Note, building this plot data table incrementally, so it must go row by row.
				table.insert(region_two_fertility, plotFertility);
			end
		end
				
	else -- We will divide vertically, resulting in first region on left, second on right.
		--
		-- Height for both will remain the same as the parent rectangle.
		firstRegionHeight = iRectHeight;
		secondRegionSouthY = iSouthY;
		secondRegionHeight = iRectHeight;
		
		--[[ First region's new fertility table will be a little tricky. We don't know how many 
		     table entries it will need beforehand, and we cannot add the entries sequentially
		     when the data is being generated column by column, yet the table index needs to 
		     proceed row by row. So we will have to make a second pass.  ]]--

		-- Measure one column at a time, moving left to right, until we have exceeded the target fertility.
		local reachedTargetColumn = false;
		local rectX = 0;
		while reachedTargetColumn == false do
			-- Process the next column in line.
			for rectY = 0, iRectHeight - 1 do
				local fertIndex = rectY * iRectWidth + rectX + 1;
				local plotFertility = fertility_table[fertIndex];
				-- Add this plot's fertility to the region total so far.
				iFirstRegionFertility = iFirstRegionFertility + plotFertility;
				-- No table record here, handle later row by row.
			end
			if iFirstRegionFertility >= iTargetFertility then
				-- This column has completed the region.
				firstRegionWidth = rectX + 1;
				secondRegionWestX = (iWestX + rectX + 1) % iW;
				secondRegionWidth = iRectWidth - firstRegionWidth;
				reachedTargetColumn = true;
				break
			else
				rectX = rectX + 1;
			end
		end

		-- Debug printout of division location.
		print("Dividing along vertical line between columns: ", secondRegionWestX - 1, "-", secondRegionWestX);

		-- Create the fertility table for the second region, the one on the right.
		-- Data must be added row by row, to keep the table index behavior consistent.
		for rectY = 0, iRectHeight - 1 do
			for rectX = firstRegionWidth, iRectWidth - 1 do
				local fertIndex = rectY * iRectWidth + rectX + 1;
				local plotFertility = fertility_table[fertIndex];
				-- Add this plot's fertility to the region total so far.
				iSecondRegionFertility = iSecondRegionFertility + plotFertility;
				-- Record this plot in a new fertility table. (Needed for further subdivisions).
				-- Note, building this plot data table incrementally, so it must go row by row.
				table.insert(region_two_fertility, plotFertility);
			end
		end
		-- Now create the fertility table for the first region.
		for rectY = 0, iRectHeight - 1 do
			for rectX = 0, firstRegionWidth - 1 do
				local fertIndex = rectY * iRectWidth + rectX + 1;
				local plotFertility = fertility_table[fertIndex];
				table.insert(region_one_fertility, plotFertility);
			end
		end
	end
	
	-- Now check the newly divided regions for dead rows (all zero values) along
	-- the edges and remove any found.
	--
	-- First region
	local FRFertT, FRWX, FRSY, FRWid, FRHei;
	FRFertT, FRWX, FRSY, FRWid, FRHei = self:RemoveDeadRows(region_one_fertility,
		firstRegionWestX, firstRegionSouthY, firstRegionWidth, firstRegionHeight);
	--
	-- Second region
	local SRFertT, SRWX, SRSY, SRWid, SRHei;
	SRFertT, SRWX, SRSY, SRWid, SRHei = self:RemoveDeadRows(region_two_fertility,
		secondRegionWestX, secondRegionSouthY, secondRegionWidth, secondRegionHeight);
	--
	
	-- Generate the data tables that record the location of the new subdivisions.
	local firstPlots = FRWid * FRHei;
	local secondPlots = SRWid * SRHei;
	local region_one_data = {FRWX, FRSY, FRWid, FRHei, iAreaID, iFirstRegionFertility, firstPlots};
	local region_two_data = {SRWX, SRSY, SRWid, SRHei, iAreaID, iSecondRegionFertility, secondPlots};
	-- Generate the final data.
	local outcome = {FRFertT, region_one_data, SRFertT, region_two_data};
	return outcome
end
------------------------------------------------------------------------------
function AssignStartingPlots:CustomOverride()
	-- This function allows an easy entry point for overrides that need to 
	-- take place after regional division, but before anything else.
end
------------------------------------------------------------------------------


-- MOD SAPHT: First call after create, example args from SmallContinents:
-- 	local args = {
-- 		method = RegionalMethod, -- (==2)
-- method == 1 on fractal map
-- 		start_locations = starts,
-- 		resources = res,
-- 		CoastLux = CoastLux,
-- 		NoCoastInland = OnlyCoastal,
-- 		BalancedCoastal = BalancedCoastal,
-- 		MixedBias = MixedBias;
-- 		};

function AssignStartingPlots:GenerateRegions(args)
	print("Map Generation - Dividing the map in to Regions");
	-- This function stores its data in the instance (self) data table.
	--
	-- The "Three Methods" of regional division:
	-- 1. Biggest Landmass: All civs start on the biggest landmass.
	-- 2. Continental: Civs are assigned to continents. Any continents with more than one civ are divided.
	-- 3. Rectangular: Civs start within a given rectangle that spans the whole map, without regard to landmass sizes.
	--                 This method is primarily applied to Archipelago and other maps with lots of tiny islands.
	-- 4. Rectangular: Civs start within a given rectangle defined by arguments passed in on the function call.
	--                 Arguments required for this method: iWestX, iSouthY, iWidth, iHeight
	local args = args or {};
	local iW, iH = Map.GetGridSize();
	self.method = args.method or self.method; -- Continental method is default.
	self.start_locations = args.start_locations or 2; -- Each map script has to pass in parameter for Resource setting chosen by user.
	self.resource_setting = args.resources or 3;
	self.CoastLux = args.CoastLux or false;
	self.AllowInlandSea = args.AllowInlandSea or 1;
	self.NoCoastInland = args.NoCoastInland;
	self.BalancedCoastal = args.BalancedCoastal;
	self.MixedBias = args.MixedBias;

	-- Determine number of civilizations and city states present in this game.
	self.iNumCivs, self.iNumCityStates, self.player_ID_list, self.bTeamGame, self.teams_with_major_civs, self.number_civs_per_team = GetPlayerAndTeamInfo()
	self.iNumCityStatesUnassigned = self.iNumCityStates;
	print("-"); print("Civs:", self.iNumCivs); print("City States:", self.iNumCityStates);

	if self.method == 1 then -- Biggest Landmass
		-- Identify the biggest landmass.
		local biggest_area = Map.FindBiggestArea(False);
		local iAreaID = biggest_area:GetID();
		-- We'll need all eight data fields returned in the results table from the boundary finder:
		local landmass_data = ObtainLandmassBoundaries(iAreaID);
		local iWestX = landmass_data[1];
		local iSouthY = landmass_data[2];
		local iEastX = landmass_data[3];
		local iNorthY = landmass_data[4];
		local iWidth = landmass_data[5];
		local iHeight = landmass_data[6];
		local wrapsX = landmass_data[7];
		local wrapsY = landmass_data[8];
		
		-- Obtain "Start Placement Fertility" of the landmass. (This measurement is customized for start placement).
		-- This call returns a table recording fertility of all plots within a rectangle that contains the landmass,
		-- with a zero value for any plots not part of the landmass -- plus a fertility sum and plot count.
		local fert_table, fertCount, plotCount = self:MeasureStartPlacementFertilityOfLandmass(iAreaID, 
		                                         iWestX, iEastX, iSouthY, iNorthY, wrapsX, wrapsY);
		-- Now divide this landmass in to regions, one per civ.
		-- The regional divider requires three arguments:
		-- 1. Number of divisions. (For "Biggest Landmass" this means number of civs in the game).
		-- 2. Fertility table. (This was obtained from the last call.)
		-- 3. Rectangle table. This table includes seven data fields:
		-- westX, southY, width, height, AreaID, fertilityCount, plotCount
		-- This is why we got the fertCount and plotCount from the fertility function.
		--
		-- Assemble the Rectangle data table:
		local rect_table = {iWestX, iSouthY, iWidth, iHeight, iAreaID, fertCount, plotCount};
		-- The data from this call is processed in to self.regionData during the process.
		self:DivideIntoRegions(self.iNumCivs, fert_table, rect_table)
		-- The regions have been defined.
	
	elseif self.method == 3 or self.method == 4 then -- Rectangular
		-- Obtain the boundaries of the rectangle to be processed.
		-- If no coords were passed via the args table, default to processing the entire map.
		-- Note that it matters if method 3 or 4 is designated, because the difference affects
		-- how city states are placed, whether they look for any uninhabited lands outside the rectangle.
		self.inhabited_WestX = args.iWestX or 0;
		self.inhabited_SouthY = args.iSouthY or 0;
		self.inhabited_Width = args.iWidth or iW;
		self.inhabited_Height = args.iHeight or iH;

		-- Obtain "Start Placement Fertility" inside the rectangle.
		-- Data returned is: fertility table, sum of all fertility, plot count.
		local fert_table, fertCount, plotCount = self:MeasureStartPlacementFertilityInRectangle(self.inhabited_WestX, 
		                                         self.inhabited_SouthY, self.inhabited_Width, self.inhabited_Height)
		-- Assemble the Rectangle data table:
		local rect_table = {self.inhabited_WestX, self.inhabited_SouthY, self.inhabited_Width, 
		                    self.inhabited_Height, -1, fertCount, plotCount}; -- AreaID -1 means ignore area IDs.
		-- Divide the rectangle.
		self:DivideIntoRegions(self.iNumCivs, fert_table, rect_table)
		-- The regions have been defined.
	
	else -- Continental.
		--[[ Loop through all plots on the map, measuring fertility of each land 
		     plot, identifying its AreaID, building a list of landmass AreaIDs, and
		     tallying the Start Placement Fertility for each landmass. ]]--

		-- region_data: [WestX, EastX, SouthY, NorthY, 
		-- numLandPlotsinRegion, numCoastalPlotsinRegion,
		-- numOceanPlotsinRegion, iRegionNetYield, 
		-- iNumLandAreas, iNumPlotsinRegion]
		local best_areas = {};
		local globalFertilityOfLands = {};

		-- Obtain info on all landmasses for comparision purposes.
		local iGlobalFertilityOfLands = 0;
		local iNumLandPlots = 0;
		local iNumLandAreas = 0;
		local land_area_IDs = {};
		local land_area_plots = {};
		local land_area_fert = {};
		-- Cycle through all plots in the world, checking their Start Placement Fertility and AreaID.
		for x = 0, iW - 1 do
			for y = 0, iH - 1 do
				local i = y * iW + x + 1;
				local plot = Map.GetPlot(x, y);
				if not plot:IsWater() then -- Land plot, process it.
					iNumLandPlots = iNumLandPlots + 1;
					local iArea = plot:GetArea();
					local plotFertility = self:MeasureStartPlacementFertilityOfPlot(x, y, true); -- Check for coastal land is enabled.
					iGlobalFertilityOfLands = iGlobalFertilityOfLands + plotFertility;
					--
					if TestMembership(land_area_IDs, iArea) == false then -- This plot is the first detected in its AreaID.
						iNumLandAreas = iNumLandAreas + 1;
						table.insert(land_area_IDs, iArea);
						land_area_plots[iArea] = 1;
						land_area_fert[iArea] = plotFertility;
					else -- This AreaID already known.
						land_area_plots[iArea] = land_area_plots[iArea] + 1;
						land_area_fert[iArea] = land_area_fert[iArea] + plotFertility;
					end
				end
			end
		end
		
		--[[ Debug printout
		print("* * * * * * * * * *");
		for area_loop, AreaID in ipairs(land_area_IDs) do
			print("Area ID " .. AreaID .. " is land.");
		end ]]--
		print("* * * * * * * * * *");
		for AreaID, fert in pairs(land_area_fert) do
			print("Area ID " .. AreaID .. " has fertility of " .. fert);
		end
		print("* * * * * * * * * *");
		--		
		
		-- Sort areas, achieving a list of AreaIDs with best areas first.
		--
		-- Fertility data in land_area_fert is stored with areaID index keys.
		-- Need to generate a version of this table with indices of 1 to n, where n is number of land areas.
		local interim_table = {};
		for loop_index, data_entry in pairs(land_area_fert) do
			table.insert(interim_table, data_entry);
		end
		
		--[[for AreaID, fert in ipairs(interim_table) do
			print("Interim Table ID " .. AreaID .. " has fertility of " .. fert);
		end
		print("* * * * * * * * * *"); ]]--
		
		-- Sort the fertility values stored in the interim table. Sort order in Lua is lowest to highest.
		table.sort(interim_table);

		for AreaID, fert in ipairs(interim_table) do
			print("Interim Table ID " .. AreaID .. " has fertility of " .. fert);
		end
		print("* * * * * * * * * *");

		-- If less players than landmasses, we will ignore the extra landmasses.
		local iNumRelevantLandAreas = math.min(iNumLandAreas, self.iNumCivs);
		-- Now re-match the AreaID numbers with their corresponding fertility values
		-- by comparing the original fertility table with the sorted interim table.
		-- During this comparison, best_areas will be constructed from sorted AreaIDs, richest stored first.
		local best_areas = {};
		-- Currently, the best yields are at the end of the interim table. We need to step backward from there.
		local end_of_interim_table = table.maxn(interim_table);
		-- We may not need all entries in the table. Process only iNumRelevantLandAreas worth of table entries.
		local fertility_value_list = {};
		local fertility_value_tie = false;
		for tableConstructionLoop = end_of_interim_table, (end_of_interim_table - iNumRelevantLandAreas + 1), -1 do
			if TestMembership(fertility_value_list, interim_table[tableConstructionLoop]) == true then
				fertility_value_tie = true;
				print("*** WARNING: Fertility Value Tie exists! ***");
			else
				table.insert(fertility_value_list, interim_table[tableConstructionLoop]);
			end
		end

		if fertility_value_tie == false then -- No ties, so no need of special handling for ties.
			for areaTestLoop = end_of_interim_table, (end_of_interim_table - iNumRelevantLandAreas + 1), -1 do
				for loop_index, AreaID in ipairs(land_area_IDs) do
					if interim_table[areaTestLoop] == land_area_fert[land_area_IDs[loop_index]] then
						table.insert(best_areas, AreaID);
						break
					end
				end
			end
		else -- Ties exist! Special handling required to protect against a shortfall in the number of defined regions.
			local iNumUniqueFertValues = table.maxn(fertility_value_list);
			for fertLoop = 1, iNumUniqueFertValues do
				for AreaID, fert in pairs(land_area_fert) do
					if fert == fertility_value_list[fertLoop] then
						-- Add ties only if there is room!
						local best_areas_length = table.maxn(best_areas);
						if best_areas_length < iNumRelevantLandAreas then
							table.insert(best_areas, AreaID);
						else
							break
						end
					end
				end
			end
		end
				
		-- Debug printout
		print("-"); print("--- Continental Division, Initial Readout ---"); print("-");
		print("- Global Fertility:", iGlobalFertilityOfLands);
		print("- Total Land Plots:", iNumLandPlots);
		print("- Total Areas:", iNumLandAreas);
		print("- Relevant Areas:", iNumRelevantLandAreas); print("-");
		--

		-- Debug printout
		print("* * * * * * * * * *");
		for area_loop, AreaID in ipairs(best_areas) do
			print("Area ID " .. AreaID .. " has fertility of " .. land_area_fert[AreaID]);
		end
		print("* * * * * * * * * *");
		--

		-- Assign continents to receive start plots. Record number of civs assigned to each landmass.
		local inhabitedAreaIDs = {};
		local numberOfCivsPerArea = table.fill(0, iNumRelevantLandAreas); -- Indexed in synch with best_areas. Use same index to match values from each table.
		for civToAssign = 1, self.iNumCivs do
			local bestRemainingArea;
			local bestRemainingFertility = 0;
			local bestAreaTableIndex;
			-- Loop through areas, find the one with the best remaining fertility (civs added 
			-- to a landmass reduces its fertility rating for subsequent civs).
			--
			print("- - Searching landmasses in order to place Civ #", civToAssign); print("-");
			for area_loop, AreaID in ipairs(best_areas) do
				local thisLandmassCurrentFertility = land_area_fert[AreaID] / (1 + numberOfCivsPerArea[area_loop]);
				if thisLandmassCurrentFertility > bestRemainingFertility then
					bestRemainingArea = AreaID;
					bestRemainingFertility = thisLandmassCurrentFertility;
					bestAreaTableIndex = area_loop;
					--
					print("- Found new candidate landmass with Area ID#:", bestRemainingArea, " with fertility of ", bestRemainingFertility);
				end
			end
			-- Record results for this pass. (A landmass has been assigned to receive one more start point than it previously had).
			numberOfCivsPerArea[bestAreaTableIndex] = numberOfCivsPerArea[bestAreaTableIndex] + 1;
			if TestMembership(inhabitedAreaIDs, bestRemainingArea) == false then
				table.insert(inhabitedAreaIDs, bestRemainingArea);
			end
			print("Civ #", civToAssign, "has been assigned to Area#", bestRemainingArea); print("-");
		end
		print("-"); print("--- End of Initial Readout ---"); print("-");
		
		print("*** Number of Civs per Landmass - Table Readout ***");
		PrintContentsOfTable(numberOfCivsPerArea)
		print("--- End of Civs per Landmass readout ***"); print("-"); print("-");
				
		-- Loop through the list of inhabited landmasses, dividing each landmass in to regions.
		-- Note that it is OK to divide a continent with one civ on it: this will assign the whole
		-- of the landmass to a single region, and is the easiest method of recording such a region.
		local iNumInhabitedLandmasses = table.maxn(inhabitedAreaIDs);
		for loop, currentLandmassID in ipairs(inhabitedAreaIDs) do
			-- Obtain the boundaries of and data for this landmass.
			local landmass_data = ObtainLandmassBoundaries(currentLandmassID);
			local iWestX = landmass_data[1];
			local iSouthY = landmass_data[2];
			local iEastX = landmass_data[3];
			local iNorthY = landmass_data[4];
			local iWidth = landmass_data[5];
			local iHeight = landmass_data[6];
			local wrapsX = landmass_data[7];
			local wrapsY = landmass_data[8];
			-- Obtain "Start Placement Fertility" of the current landmass. (Necessary to do this
			-- again because the fert_table can't be built prior to finding boundaries, and we had
			-- to ID the proper landmasses via fertility to be able to figure out their boundaries.
			local fert_table, fertCount, plotCount = self:MeasureStartPlacementFertilityOfLandmass(currentLandmassID, 
		  	                                         iWestX, iEastX, iSouthY, iNorthY, wrapsX, wrapsY);
			-- Assemble the rectangle data for this landmass.
			local rect_table = {iWestX, iSouthY, iWidth, iHeight, currentLandmassID, fertCount, plotCount};
			-- Divide this landmass in to number of regions equal to civs assigned here.
			iNumCivsOnThisLandmass = numberOfCivsPerArea[loop];
			if iNumCivsOnThisLandmass > 0 and iNumCivsOnThisLandmass <= 22 then -- valid number of civs.
			
				-- Debug printout for regional division inputs.
				print("-"); print("- Region #: ", loop);
				print("- Civs on this landmass: ", iNumCivsOnThisLandmass);
				print("- Area ID#: ", currentLandmassID);
				print("- Fertility: ", fertCount);
				print("- Plot Count: ", plotCount); print("-");
				--
			
				self:DivideIntoRegions(iNumCivsOnThisLandmass, fert_table, rect_table)
			else
				print("Invalid number of civs assigned to a landmass: ", iNumCivsOnThisLandmass);
			end
		end
		--
		-- The regions have been defined.
	end
	
	-- Entry point for easier overrides.
	self:CustomOverride()
	
	-- Printout is for debugging only. Deactivate otherwise.
	-- local tempRegionData = self.regionData;
	-- for i, data in ipairs(tempRegionData) do
	-- 	print("-");
	-- 	print("Data for Start Region #", i);
	-- 	print("WestX:  ", data[1]);
	-- 	print("SouthY: ", data[2]);
	-- 	print("Width:  ", data[3]);
	-- 	print("Height: ", data[4]);
	-- 	print("AreaID: ", data[5]);
	-- 	print("Fertility:", data[6]);
	-- 	print("Plots:  ", data[7]);
	-- 	print("Fert/Plot:", data[8]);
	-- 	print("-");
	-- end
	--
end
------------------------------------------------------------------------------
-- Start of functions tied to ChooseLocations()
------------------------------------------------------------------------------
function AssignStartingPlots:MeasureTerrainInRegions()
	local iW, iH = Map.GetGridSize();
	-- This function stores its data in the instance (self) data table.
	for region_loop, region_data_table in ipairs(self.regionData) do
		local iWestX = region_data_table[1];
		local iSouthY = region_data_table[2];
		local iWidth = region_data_table[3];
		local iHeight = region_data_table[4];
		local iAreaID = region_data_table[5];
		
		local totalPlots, areaPlots = 0, 0;
		local waterCount, flatlandsCount, hillsCount, peaksCount = 0, 0, 0, 0;
		local lakeCount, coastCount, oceanCount, iceCount = 0, 0, 0, 0;
		local grassCount, plainsCount, desertCount, tundraCount, snowCount = 0, 0, 0, 0, 0; -- counts flatlands only!
		local forestCount, jungleCount, marshCount, riverCount, floodplainCount, oasisCount = 0, 0, 0, 0, 0, 0;
		local coastalLandCount, nextToCoastCount = 0, 0;

		-- Iterate through the region's plots, getting plotType, terrainType, featureType and river status.
		for region_loop_y = 0, iHeight - 1 do
			for region_loop_x = 0, iWidth - 1 do
				totalPlots = totalPlots + 1;
				local x = (region_loop_x + iWestX) % iW;
				local y = (region_loop_y + iSouthY) % iH;
				local plot = Map.GetPlot(x, y);
				local area_of_plot = plot:GetArea();
				-- get plot info
				local plotType = plot:GetPlotType()
				local terrainType = plot:GetTerrainType()
				local featureType = plot:GetFeatureType()
				
				-- Mountain and Ocean plot types get their own AreaIDs, but we are going to measure them anyway.
				if plotType == PlotTypes.PLOT_MOUNTAIN then
					peaksCount = peaksCount + 1; -- and that's it for Mountain plots. No other stats.
				elseif plotType == PlotTypes.PLOT_OCEAN then
					waterCount = waterCount + 1;
					if terrainType == TerrainTypes.TERRAIN_COAST then
						if plot:IsLake() then
							lakeCount = lakeCount + 1;
						else
							coastCount = coastCount + 1;
						end
					else
						oceanCount = oceanCount + 1;
					end
					if featureType == FeatureTypes.FEATURE_ICE then
						iceCount = iceCount + 1;
					end

				else
					-- Hills and Flatlands, check plot for region membership. Only process this plot if it is a member.
					if (area_of_plot == iAreaID) or (iAreaID == -1) then
						areaPlots = areaPlots + 1;

						-- set up coastalLand and nextToCoast index
						local i = iW * y + x + 1;
			
						-- Record plot data
						if plotType == PlotTypes.PLOT_HILLS then
							hillsCount = hillsCount + 1;

							if self.plotDataIsCoastal[i] then
								coastalLandCount = coastalLandCount + 1;
							elseif self.plotDataIsNextToCoast[i] then
								nextToCoastCount = nextToCoastCount + 1;
							end

							if plot:IsRiverSide() then
								riverCount = riverCount + 1;
							end

							-- Feature check checking for all types, in case features are not obeying standard allowances.
							if featureType == FeatureTypes.FEATURE_FOREST then
								forestCount = forestCount + 1;
							elseif featureType == FeatureTypes.FEATURE_JUNGLE then
								jungleCount = jungleCount + 1;
							elseif featureType == FeatureTypes.FEATURE_MARSH then
								marshCount = marshCount + 1;
							elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
								floodplainCount = floodplainCount + 1;
							elseif featureType == FeatureTypes.FEATURE_OASIS then
								oasisCount = oasisCount + 1;
							end
								
						else -- Flatlands plot
							flatlandsCount = flatlandsCount + 1;
	
							if self.plotDataIsCoastal[i] then
								coastalLandCount = coastalLandCount + 1;
							elseif self.plotDataIsNextToCoast[i] then
								nextToCoastCount = nextToCoastCount + 1;
							end

							if plot:IsRiverSide() then
								riverCount = riverCount + 1;
							end
				
							if terrainType == TerrainTypes.TERRAIN_GRASS then
								grassCount = grassCount + 1;
							elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
								plainsCount = plainsCount + 1;
							elseif terrainType == TerrainTypes.TERRAIN_DESERT then
								desertCount = desertCount + 1;
							elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
								tundraCount = tundraCount + 1;
							elseif terrainType == TerrainTypes.TERRAIN_SNOW then
								snowCount = snowCount + 1;
							end
				
							-- Feature check checking for all types, in case features are not obeying standard allowances.
							if featureType == FeatureTypes.FEATURE_FOREST then
								forestCount = forestCount + 1;
							elseif featureType == FeatureTypes.FEATURE_JUNGLE then
								jungleCount = jungleCount + 1;
							elseif featureType == FeatureTypes.FEATURE_MARSH then
								marshCount = marshCount + 1;
							elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
								floodplainCount = floodplainCount + 1;
							elseif featureType == FeatureTypes.FEATURE_OASIS then
								oasisCount = oasisCount + 1;
							end
						end
					end
				end
			end
		end
			
		-- Assemble in to an array the recorded data for this region: 23 variables.
		local regionCounts = {
			totalPlots, areaPlots,
			waterCount, flatlandsCount, hillsCount, peaksCount,
			lakeCount, coastCount, oceanCount, iceCount,
			grassCount, plainsCount, desertCount, tundraCount, snowCount,
			forestCount, jungleCount, marshCount, riverCount, floodplainCount, oasisCount,
			coastalLandCount, nextToCoastCount
			}
		--[[ Table Key:
		
		1) totalPlots
		2) areaPlots                 13) desertCount
		3) waterCount                14) tundraCount
		4) flatlandsCount            15) snowCount
		5) hillsCount                16) forestCount
		6) peaksCount                17) jungleCount
		7) lakeCount                 18) marshCount
		8) coastCount                19) riverCount
		9) oceanCount                20) floodplainCount
		10) iceCount                 21) oasisCount
		11) grassCount               22) coastalLandCount
		12) plainsCount              23) nextToCoastCount   ]]--
			
		-- Add array to the data table.
		table.insert(self.regionTerrainCounts, regionCounts);
		
		--Activate printout only for debugging.
		print("-");
		print("--- Region Terrain Measurements for Region #", region_loop, "---");
		print("Total Plots: ", totalPlots);
		print("Area Plots: ", areaPlots);
		print("-");
		print("Mountains: ", peaksCount, " - Cannot belong to a landmass AreaID.");
		print("Total Water Plots: ", waterCount, " - Cannot belong to a landmass AreaID.");
		print("-");
		print("Lake Plots: ", lakeCount);
		print("Coast Plots: ", coastCount, " - Does not include Lakes.");
		print("Ocean Plots: ", oceanCount);
		print("Icebergs: ", iceCount);
		print("-");
		print("Flatlands: ", flatlandsCount);
		print("Hills: ", hillsCount);
		print("-");
		print("Grass Plots: ", grassCount);
		print("Plains Plots: ", plainsCount);
		print("Desert Plots: ", desertCount);
		print("Tundra Plots: ", tundraCount);
		print("Snow Plots: ", snowCount);
		print("-");
		print("Forest Plots: ", forestCount);
		print("Jungle Plots: ", jungleCount);
		print("Marsh Plots: ", marshCount);
		print("Flood Plains: ", floodplainCount);
		print("Oases: ", oasisCount);
		print("-");
		print("Plots Along Rivers: ", riverCount);
		print("Plots Along Oceans: ", coastalLandCount);
		print("Plots Next To Plots Along Oceans: ", nextToCoastCount);
		print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
		
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:DetermineRegionTypes()
	-- Determine region type and conditions. Use self.regionTypes to store the results
	--
	-- REGION TYPES
	-- 0. Undefined
	-- 1. Tundra
	-- 2. Jungle
	-- 3. Forest
	-- 4. Desert
	-- 5. Hills
	-- 6. Plains
	-- 7. Grassland
	-- 8. Hybrid
	-- 9. Marsh

	-- Main loop
	for this_region, terrainCounts in ipairs(self.regionTerrainCounts) do
		-- Set each region to "Undefined Type" as default.
		-- If all efforts fail at determining what type of region this should be, region type will remain Undefined.
		--local totalPlots = terrainCounts[1];
		local totalPlots = terrainCounts[1] ;
		local areaPlots = terrainCounts[2];
		local waterCount = terrainCounts[3];
		local flatlandsCount = terrainCounts[4];
		local hillsCount = terrainCounts[5];
		local peaksCount = terrainCounts[6];
		local lakeCount = terrainCounts[7];
		local coastCount = terrainCounts[8];
		local oceanCount = terrainCounts[9];
		local iceCount = terrainCounts[10];
		local grassCount = terrainCounts[11];
		local plainsCount = terrainCounts[12];
		local desertCount = terrainCounts[13];
		local tundraCount = terrainCounts[14];
		local snowCount = terrainCounts[15];
		local forestCount = terrainCounts[16];
		local jungleCount = terrainCounts[17];
		local marshCount = terrainCounts[18];
		local riverCount = terrainCounts[19];
		local floodplainCount = terrainCounts[20];
		local oasisCount = terrainCounts[21];
		local coastalLandCount = terrainCounts[22];
		local nextToCoastCount = terrainCounts[23];

		print("----------------------------------------------- REGION TYPE CHECKS START -----------------------------------------------");
		print("--- Region Terrain Measurements for Region #", this_region, "---");
		print("Total Plots: ", totalPlots);
		print("Area Plots: ", areaPlots);
		print("-");
		print("Mountains: ", peaksCount, " - Cannot belong to a landmass AreaID.");
		print("Total Water Plots: ", waterCount, " - Cannot belong to a landmass AreaID.");
		print("-");
		print("Lake Plots: ", lakeCount);
		print("Coast Plots: ", coastCount, " - Does not include Lakes.");
		print("Ocean Plots: ", oceanCount);
		print("Icebergs: ", iceCount);
		print("-");
		print("Flatlands: ", flatlandsCount);
		print("Hills: ", hillsCount);
		print("-");
		print("Grass Plots: ", grassCount);
		print("Plains Plots: ", plainsCount);
		print("Desert Plots: ", desertCount);
		print("Tundra Plots: ", tundraCount);
		print("Snow Plots: ", snowCount);
		print("-");
		print("Forest Plots: ", forestCount);
		print("Jungle Plots: ", jungleCount);
		print("Marsh Plots: ", marshCount);
		print("Flood Plains: ", floodplainCount);
		print("Oases: ", oasisCount);
		print("-");
		print("Plots Along Rivers: ", riverCount);
		print("Plots Along Oceans: ", coastalLandCount);
		print("Plots Next To Plots Along Oceans: ", nextToCoastCount);
		print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");

		-- If Rectangular regional division, then water plots would be included in area plots.
		-- Let's recalculate area plots based only on flatland and hills plots.
		if self.method == 3 or self.method == 4 then
			areaPlots = flatlandsCount + hillsCount;
		end

		-- Tundra check first.
		if (tundraCount + snowCount) >= areaPlots * 0.10 then
			table.insert(self.regionTypes, 1);
			print("-");
			print("Region #", this_region, " has been defined as a Tundra Region.");
		
		-- Jungle check.
		elseif (jungleCount >= areaPlots * 0.12) then
			table.insert(self.regionTypes, 2);
			print("-");
			print("Region #", this_region, " has been defined as a Jungle Region.");
		elseif (jungleCount >= areaPlots * 0.10) and (jungleCount + forestCount >= areaPlots * 0.24) then
			table.insert(self.regionTypes, 2);
			print("-");
			print("Region #", this_region, " has been defined as a Jungle Region.");
		
		-- Forest check.
		elseif (forestCount >= areaPlots * 0.19) then
			table.insert(self.regionTypes, 3);
			print("-");
			print("Region #", this_region, " has been defined as a Forest Region.");
		elseif (forestCount >= areaPlots * 0.8) and (jungleCount + forestCount >= areaPlots * 0.3) then
			table.insert(self.regionTypes, 3);
			print("-");
			print("Region #", this_region, " has been defined as a Forest Region.");
		
		-- Desert check.
		elseif (desertCount >= areaPlots * 0.15) then
			table.insert(self.regionTypes, 4);
			print("-");
			print("Region #", this_region, " has been defined as a Desert Region.");
			
		-- Wetlands check.
		elseif ((marshCount) >= areaPlots * 0.11) or (marshCount >= 6) then
			table.insert(self.regionTypes, 9);
			print("-");
			print("Region #", this_region, " has been defined as a Wetlands Region.");
		-- Hills check.
		elseif (hillsCount >= areaPlots * 0.37) then
			table.insert(self.regionTypes, 5);
			print("-");
			print("Region #", this_region, " has been defined as a Hills Region.");
			
		-- Grass check.
		elseif (grassCount >= areaPlots * 0.20) and (grassCount * 0.7 > plainsCount) then
			table.insert(self.regionTypes, 7);
			print("-");
			print("Region #", this_region, " has been defined as a Grassland Region.");
		
		-- Plains check.
		elseif (plainsCount >= areaPlots * 0.27) and (plainsCount * 0.8 > grassCount) then
			table.insert(self.regionTypes, 6);
			print("-");
			print("Region #", this_region, " has been defined as a Plains Region.");
		-- Hybrid check.
		elseif ((grassCount + plainsCount + desertCount + tundraCount + snowCount + hillsCount + peaksCount) > areaPlots * 0.8) then
			table.insert(self.regionTypes, 8);
			print("-");
			print("Region #", this_region, " has been defined as a Hybrid Region.");

		else -- Undefined Region (most likely due to operating on a mod that adds new terrain types.)
			table.insert(self.regionTypes, 0);
			print("-");
			print("Region #", this_region, " has been defined as an Undefined Region.");
		
		end
	end

	--[[
	-- Main loop
	for this_region, terrainCounts in ipairs(self.regionTerrainCounts) do
		-- Set each region to "Undefined Type" as default.
		-- If all efforts fail at determining what type of region this should be, region type will remain Undefined.
		--local totalPlots = terrainCounts[1];
		local totalPlots = terrainCounts[1] ;
		local areaPlots = terrainCounts[2];
		local waterCount = terrainCounts[3];
		local flatlandsCount = terrainCounts[4];
		local hillsCount = terrainCounts[5];
		local peaksCount = terrainCounts[6];
		local lakeCount = terrainCounts[7];
		local coastCount = terrainCounts[8];
		local oceanCount = terrainCounts[9];
		local iceCount = terrainCounts[10];
		local grassCount = terrainCounts[11];
		local plainsCount = terrainCounts[12];
		local desertCount = terrainCounts[13];
		local tundraCount = terrainCounts[14];
		local snowCount = terrainCounts[15];
		local forestCount = terrainCounts[16];
		local jungleCount = terrainCounts[17];
		local marshCount = terrainCounts[18];
		local riverCount = terrainCounts[19];
		local floodplainCount = terrainCounts[20];
		local oasisCount = terrainCounts[21];
		local coastalLandCount = terrainCounts[22];
		local nextToCoastCount = terrainCounts[23];

		print("----------------------------------------------- REGION TYPE CHECKS START -----------------------------------------------");
		print("--- Region Terrain Measurements for Region #", this_region, "---");
		print("Total Plots: ", totalPlots);
		print("Area Plots: ", areaPlots);
		print("-");
		print("Mountains: ", peaksCount, " - Cannot belong to a landmass AreaID.");
		print("Total Water Plots: ", waterCount, " - Cannot belong to a landmass AreaID.");
		print("-");
		print("Lake Plots: ", lakeCount);
		print("Coast Plots: ", coastCount, " - Does not include Lakes.");
		print("Ocean Plots: ", oceanCount);
		print("Icebergs: ", iceCount);
		print("-");
		print("Flatlands: ", flatlandsCount);
		print("Hills: ", hillsCount);
		print("-");
		print("Grass Plots: ", grassCount);
		print("Plains Plots: ", plainsCount);
		print("Desert Plots: ", desertCount);
		print("Tundra Plots: ", tundraCount);
		print("Snow Plots: ", snowCount);
		print("-");
		print("Forest Plots: ", forestCount);
		print("Jungle Plots: ", jungleCount);
		print("Marsh Plots: ", marshCount);
		print("Flood Plains: ", floodplainCount);
		print("Oases: ", oasisCount);
		print("-");
		print("Plots Along Rivers: ", riverCount);
		print("Plots Along Oceans: ", coastalLandCount);
		print("Plots Next To Plots Along Oceans: ", nextToCoastCount);
		print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");

		-- If Rectangular regional division, then water plots would be included in area plots.
		-- Let's recalculate area plots based only on flatland and hills plots.
		if self.method == 3 or self.method == 4 then
			areaPlots = flatlandsCount + hillsCount;
		end

		
			 MOD.Barathor: 
			 Totally revamped this entire function.
			 With the old method, very dominant conditions could be missed, resulting in mislabeled regions.
			 Now, a large decrementing value is added on to the base percentage requirements to filter out very dominant conditions first. 
		
	
		local found_region   = false
		-- MOD.Barathor: These are the minimum values
		local desert_percent 	= 0.30
		local tundra_percent 	= 0.30
		local jungle_percent 	= 0.30
		local forest_percent 	= 0.30
		local hills_percent  	= 0.30
		local wetlands_percent  = 0.30
		local plains_percent 	= 0.30
		local grass_percent  	= 0.30

		-- MOD.Barathor: This variable will decrement until a region is assigned; starts off very high.
		local adjustment     = 0.50
		
		-- MOD.Barathor: Decided to disable this part.
		
		-- MOD.Barathor: An additional value is applied to region types already chosen, to very slightly lessen the chances of choosing it again.
		for loop, region in ipairs(self.regionTypes) do
			if region == 4 then
				desert_percent = desert_percent + 0.05
			elseif region == 1 then
				tundra_percent = tundra_percent + 0.05
			elseif region == 2 then
				jungle_percent = jungle_percent + 0.05
			elseif region == 3 then
				forest_percent = forest_percent + 0.05
			elseif region == 5 then
				hills_percent = hills_percent + 0.05
			elseif region == 6 then
				plains_percent = plains_percent + 0.05
			elseif region == 7 then
				grass_percent = grass_percent + 0.05
			end
		end
		
		
		-- MOD.Barathor: Reordered condition checks and modified what some checks include.
		while found_region == false do
			-- Desert check.
			if (desertCount >= areaPlots * (desert_percent + adjustment)) then
				table.insert(self.regionTypes, 4)
				print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
				print("Region #", this_region, " has been defined as a DESERT Region.")
				found_region = true
				
			-- Tundra check.
			elseif (tundraCount >= areaPlots * (tundra_percent + adjustment)) then
				table.insert(self.regionTypes, 1)
				print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
				print("Region #", this_region, " has been defined as a TUNDRA Region.")
				found_region = true
				
			-- Jungle check.
			elseif (jungleCount >= areaPlots * (jungle_percent + adjustment)) then 
				table.insert(self.regionTypes, 2)
				print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
				print("Region #", this_region, " has been defined as a JUNGLE Region.")
				found_region = true
				
			-- Forest check. 
			elseif (forestCount >= areaPlots * (forest_percent + adjustment)) and (tundraCount < areaPlots * tundra_percent) then
				table.insert(self.regionTypes, 3)
				print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
				print("Region #", this_region, " has been defined as a FOREST Region.")
				found_region = true

			-- Wetlands check.
			elseif ((marshCount + floodplainCount) >= areaPlots * (wetlands_percent + adjustment)) or (floodplainCount >= 10) or (marshCount >= 8) then
				table.insert(self.regionTypes, 9);
				print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
				print("Region #", this_region, " has been defined as a Wetlands Region.");
				found_region = true
			
			else
				if adjustment <= 0 then
					-- Plains check.
					if (plainsCount >= areaPlots * plains_percent) and (plainsCount * 0.8 > grassCount) then
						table.insert(self.regionTypes, 6)
						print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
						print("Region #", this_region, " has been defined as a PLAINS Region.")
						found_region = true
					-- Grass check.
					elseif (grassCount >= areaPlots * grass_percent) and (grassCount * 0.8 > plainsCount) then
						table.insert(self.regionTypes, 7)
						print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
						print("Region #", this_region, " has been defined as a GRASSLAND Region.")
						found_region = true
					
					-- Hills check.
					elseif (hillsCount >= areaPlots * hills_percent) then
						table.insert(self.regionTypes, 5)
						print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
						print("Region #", this_region, " has been defined as a HILLS Region.")
						found_region = true

					else
						-- Hybrid: No conditions dominate or other mods have included new terrain/feature/plot types which aren't recognized here.
						table.insert(self.regionTypes, 8)
						print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
						print("Region #", this_region, " has been defined as a HYBRID Region.")
						found_region = true
					end
				end
				adjustment = adjustment - 0.01
			end
		end
		
		-- MOD.Barathor: New data for very useful debug printouts.
		print("Threshold Values:")
		print(string.format("Desert: %.2f - Tundra: %.2f - Jungle: %.2f - Forest: %.2f - Hills: %.2f - Plains: %.2f - Grass: %.2f", desert_percent, tundra_percent, jungle_percent, forest_percent, hills_percent, plains_percent, grass_percent))		
		print("Region Values:")
		print(string.format("Desert: %.2f - Tundra: %.2f - Jungle: %.2f - Forest: %.2f - Hills: %.2f - Plains: %.2f - Grass: %.2f", desertCount / areaPlots, tundraCount / areaPlots, jungleCount / areaPlots, forestCount / areaPlots, hillsCount / areaPlots, plainsCount / areaPlots, grassCount / areaPlots))
		print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")	
	end
	]]
	--[[
		-- Tundra check first.
		if (tundraCount + snowCount) >= areaPlots * 0.15 then
			table.insert(self.regionTypes, 1);
			print("-");
			print("Region #", this_region, " has been defined as a Tundra Region.");
		
		-- Jungle check.
		elseif (jungleCount >= areaPlots * 0.17) then
			table.insert(self.regionTypes, 2);
			print("-");
			print("Region #", this_region, " has been defined as a Jungle Region.");
		elseif (jungleCount >= areaPlots * 0.15) and (jungleCount + forestCount >= areaPlots * 0.32) then
			table.insert(self.regionTypes, 2);
			print("-");
			print("Region #", this_region, " has been defined as a Jungle Region.");
		
		-- Forest check.
		elseif (forestCount >= areaPlots * 0.24) then
			table.insert(self.regionTypes, 3);
			print("-");
			print("Region #", this_region, " has been defined as a Forest Region.");
		elseif (forestCount >= areaPlots * 0.18) and (jungleCount + forestCount >= areaPlots * 0.32) then
			table.insert(self.regionTypes, 3);
			print("-");
			print("Region #", this_region, " has been defined as a Forest Region.");
		
		-- Desert check.
		elseif (desertCount >= areaPlots * 0.15) then
			table.insert(self.regionTypes, 4);
			print("-");
			print("Region #", this_region, " has been defined as a Desert Region.");
			
		-- Hills check.
		elseif (hillsCount >= areaPlots * 0.47) then
			table.insert(self.regionTypes, 5);
			print("-");
			print("Region #", this_region, " has been defined as a Hills Region.");
		
		-- Wetlands check.
		elseif ((marshCount + floodplainCount) >= areaPlots * 0.12) or (floodplainCount >= 8) or (marshCount >= 6) then
			table.insert(self.regionTypes, 9);
			print("-");
			print("Region #", this_region, " has been defined as a Wetlands Region.");

		-- Grass check.
		elseif (grassCount >= areaPlots * 0.25) and (grassCount * 0.7 > plainsCount) then
			table.insert(self.regionTypes, 7);
			print("-");
			print("Region #", this_region, " has been defined as a Grassland Region.");
		
		-- Plains check.
		elseif (plainsCount >= areaPlots * 0.35) and (plainsCount * 0.8 > grassCount) then
			table.insert(self.regionTypes, 6);
			print("-");
			print("Region #", this_region, " has been defined as a Plains Region.");
		-- Hybrid check.
		elseif ((grassCount + plainsCount + desertCount + tundraCount + snowCount + hillsCount + peaksCount) > areaPlots * 0.8) then
			table.insert(self.regionTypes, 8);
			print("-");
			print("Region #", this_region, " has been defined as a Hybrid Region.");

		else -- Undefined Region (most likely due to operating on a mod that adds new terrain types.)
			table.insert(self.regionTypes, 0);
			print("-");
			print("Region #", this_region, " has been defined as an Undefined Region.");
		
		end
	end
	--]]

end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceImpactAndRipples(x, y, region_number)
	-- This function operates upon the "impact and ripple" data overlays. This
	-- is the core version, which operates on start points. Resources and city 
	-- states have their own data layers, using this same design principle.
	-- Execution of this function handles a single start point (x, y).
	--[[ The purpose of the overlay is to strongly discourage placement of new
	     start points near already-placed start points. Each start placed makes
	     an "impact" on the map, and this impact "ripples" outward in rings, each
	     ring weaker in bias than the previous ring. ... Civ4 attempted to adjust
	     the minimum distance between civs according to a formula that factored
	     map size and number of civs in the game, but the formula was chock full 
	     of faulty assumptions, resulting in an accurate calibration rate of less
	     than ten percent. The failure of this approach is the primary reason 
	     that an all-new positioner was written for Civ5. ... Rather than repeat
	     the mistakes of the old system, in part or in whole, I have opted to go 
	     with a flat 9-tile impact crater for all map sizes and number of civs.
	     The new system will place civs at least 9 tiles away from other civs
	     whenever and wherever a reasonable candidate plot exists at this range. 
	     If a start must be found within that range, it will attempt to balance
	     quality of the location against proximity to another civ, with the bias
	     becoming very heavy inside 7 plots, and all but prohibitive inside 5.
	     The only starts that should see any Civs crowding together are those 
	     with impossible conditions such as cramming more than a dozen civs on 
	     to Tiny or Duel sized maps. ... The Impact and Ripple is aimed mostly
	     at assisting with Rectangular Method regional division on islands maps,
	     as the primary method of spacing civs is the Center Bias factor. The 
	     Impact and Ripple is a second layer of protection, for those rare cases
	     when regional shapes are severely distorted, with little to no land in
	     the region center, and the start having to be placed near the edge, and
	     for cases of extremely thin regional dimension.   ]]--
	-- To establish a bias of 9, we Impact the overlay and Ripple outward 8 times.
	-- Value of 0 in a plot means no influence from existing Impacts in that plot.
	-- Value of 99 means an Impact occurred in that plot and it IS a start point.
	-- Values > 0 and < 99 are "ripples", meaning that plot is near a start point.
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local impact_value = 99;

	local ripple_decider = Map.GetCustomOption(6);
	local ripple_values = {97, 95, 92, 88, 83, 77, 70, 62, 51, 41, 30, 18};	
	if ripple_decider == 1 then
		local ripple_values = {97, 95, 92, 89, 69, 57, 24, 15};
	end
	if ripple_decider == 2 then	
		local ripple_values = {97, 95, 92, 88, 83, 77, 70, 62, 51, 41, 30, 18};
	end
	if ripple_decider == 3 then	
		local ripple_values = {99, 98, 97, 89, 88, 83, 77, 70, 62, 51, 41, 30, 18, 12};
	end
	
	--local ripple_values = {99, 99, 99, 99, 99, 99};

	local odd = self.firstRingYIsOdd;
	local even = self.firstRingYIsEven;
	local nextX, nextY, plot_adjustments;
	local plot = Map.GetPlot(x, y);

	-- Start points need to impact the resource layers, so let's handle that first.
	self:PlaceResourceImpact(x, y, 1, 0) -- Strategic layer, at impact site only.
	self:PlaceResourceImpact(x, y, 2, 3) -- Luxury layer, set all plots within this civ start as off limits.
	self:PlaceResourceImpact(x, y, 3, 3) -- Bonus layer
	self:PlaceResourceImpact(x, y, 4, 0) -- Fish layer -- MOD.EAP: allow fish to be placed near spawns regardless of additional rules.
	-- MOD.EAP: place a ripple impact for regional luxuries
	self:PlaceResourceImpactRegionalMod(x, y, 3, 7, region_number)


	-- MOD.EAP: Also set layers for the new impact system
	LekmapPlaceResources:place_impact(plot, lekmap_resource_impacts.LUXURY_LAYER.LAND, 3, 3)
	LekmapPlaceResources:place_impact(plot, lekmap_resource_impacts.LUXURY_LAYER.OCEAN, 3, 3)
	
	LekmapPlaceResources:place_impact(plot, lekmap_resource_impacts.BONUS_LAYER.LAND, 3, 3)
	LekmapPlaceResources:place_impact(plot, lekmap_resource_impacts.BONUS_LAYER.OCEAN, 3, 3)
	LekmapPlaceResources:place_impact(plot, lekmap_resource_impacts.STRATEGIC_LAYER.LAND, 0, 0)
	LekmapPlaceResources:place_impact(plot, lekmap_resource_impacts.STRATEGIC_LAYER.OCEAN, 0, 0)

	if plot:IsCoastalLand() then
		-- MOD.EAP: SAPHT 10 range city state coastal now in use
		self:PlaceResourceImpactCoastalMod(x, y, 5, 3, 4) -- MOD: SAPHT 8 range city state coastal
	else
		self:PlaceResourceImpact(x, y, 5, 5) -- Add CS layer with radius of 6 tiles
	end

	self:PlaceResourceImpact(x, y, 6, 4) -- Natural Wonders layer, set a minimum distance of 5 plots (4 ripples) away.
	-- Now the main data layer, for start points themselves, and the City State data layer.
	-- Place Impact!
	local impactPlotIndex = y * iW + x + 1;
	self.distanceData[impactPlotIndex] = impact_value;
	self.playerCollisionData[impactPlotIndex] = true;
	self.cityStateData[impactPlotIndex] = 1;

	-- self.playerCoastalCollisionData[impactPlotIndex] = true
	-- Place Ripples
	for ripple_radius, ripple_value in ipairs(ripple_values) do
		-- Moving clockwise around the ring, the first direction to travel will be Northeast.
		-- This matches the direction-based data in the odd and even tables. Each
		-- subsequent change in direction will correctly match with these tables, too.
		--
		-- Locate the plot within this ripple ring that is due West of the Impact Plot.
		local currentX = x - ripple_radius;
		local currentY = y;
		-- Now loop through the six directions, moving ripple_radius number of times
		-- per direction. At each plot in the ring, add the ripple_value for that ring 
		-- to the plot's entry in the distance data table.
		for direction_index = 1, 6 do
			for plot_to_handle = 1, ripple_radius do
				-- Must account for hex factor.
			 	if currentY / 2 > math.floor(currentY / 2) then -- Current Y is odd. Use odd table.
					plot_adjustments = odd[direction_index];
				else -- Current Y is even. Use plot adjustments from even table.
					plot_adjustments = even[direction_index];
				end
				-- Identify the next plot in the ring.
				nextX = currentX + plot_adjustments[1];
				nextY = currentY + plot_adjustments[2];
				-- Make sure the plot exists
				if wrapX == false and (nextX < 0 or nextX >= iW) then -- X is out of bounds.
					-- Do not add ripple data to this plot.
				elseif wrapY == false and (nextY < 0 or nextY >= iH) then -- Y is out of bounds.
					-- Do not add ripple data to this plot.
				else -- Plot is in bounds, process it.
					-- Handle any world wrap.
					local realX = nextX;
					local realY = nextY;
					if wrapX then
						realX = realX % iW;
					end
					if wrapY then
						realY = realY % iH;
					end
					-- Record ripple data for this plot.
					local ringPlotIndex = realY * iW + realX + 1;
					if self.distanceData[ringPlotIndex] > 0 then -- This plot is already in range of at least one other civ!
						-- First choose the greater of the two, existing value or current ripple.
						local stronger_value = math.max(self.distanceData[ringPlotIndex], ripple_value);
						-- Now increase it by 1.2x to reflect that multiple civs are in range of this plot.
						local overlap_value = math.min(97, math.floor(stronger_value * 1.4));
						self.distanceData[ringPlotIndex] = overlap_value;
					else
						self.distanceData[ringPlotIndex] = ripple_value;
					end
					-- Now impact the City State layer if appropriate.
					if ripple_radius <= 6 then
						self.cityStateData[ringPlotIndex] = 1;
					end
				end
				currentX, currentY = nextX, nextY;
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:MeasureSinglePlot(x, y, region_type, distance_from_city)
	local data = table.fill(false, 5);
	-- Note that "Food" is not strictly about tile yield.
	-- Different regions get their food in different ways.
	-- Tundra, Jungle, Forest, Desert, Plains regions will 
	-- get Bonus resource support to cover food shortages.
	--
	-- Data table entries hold results; all begin as false:
	-- [1] "Food"
	-- [2] "Prod"
	-- [3] "Good"
	-- [4] "Junk"
	-- [5] "Count Double" (For hills on city plot as production and snow as junk)
	local iW, iH = Map.GetGridSize();
	local plot = Map.GetPlot(x, y);
	local plotType = plot:GetPlotType()
	local terrainType = plot:GetTerrainType()
	local featureType = plot:GetFeatureType()
	
	if plotType == PlotTypes.PLOT_MOUNTAIN then -- Mountains are Junk
		data[4] = true;
		return data
	elseif plotType == PlotTypes.PLOT_OCEAN then
		if featureType == FeatureTypes.FEATURE_ICE then -- Icebergs are Junk.
			data[4] = true;
		elseif plot:IsLake() then -- Lakes are Food, not good.
			data[1] = true;
		elseif terrainType == TerrainTypes.TERRAIN_COAST then 
			data[1] = true;
			if self.method == 3 or self.method == 4 then -- Shallow water is Good for Archipelago-type maps.
				data[3] = true;
			end
		end
		-- Other water plots are ignored.
		return data
	end

	if featureType == FeatureTypes.FEATURE_JUNGLE and distance_from_city ~= 0 then -- Jungles are Food except in Grass regions and only Good in Jungle regions.
		if plotType == PlotTypes.PLOT_HILLS then -- Jungle hill count as Prod but not Good.
			data[2] = true;
		end
		if region_type ~= 7 then -- Region type is not Grass.
			data[1] = true;
			if region_type == 2 then -- Region type is jungle
				data[3] = true;
			end
		end
		return data
	elseif featureType == FeatureTypes.FEATURE_FOREST and distance_from_city ~= 0 then -- Forests are Prod, Good.
		data[2] = true;
		if plotType == PlotTypes.PLOT_HILLS then
			data[3] = true;
		else
			-- tile under forest is a flat land tile so must be food
			if terrainType ~= TerrainTypes.TERRAIN_TUNDRA then -- must be flat plains or grassland
				data[1] = true;
			end
		end

		return data
	elseif featureType == FeatureTypes.FEATURE_OASIS then -- Oases are Food, Good.
		data[1] = true;
		data[3] = true;
		return data
	elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then -- Flood Plains are Food, Good.
		data[1] = true;
		data[3] = true;
		return data
	elseif featureType == FeatureTypes.FEATURE_MARSH and distance_from_city ~= 0 then -- Marsh are ignored.
		
		-- marsh is good for wetlands region types
		if region_type == 9 then
			data[3] = true;
		else
			data[4] = true;
		end

		return data
	end

	if plotType == PlotTypes.PLOT_HILLS then -- Hills with no features are Prod, Good.
		data[2] = true;
		data[3] = true;
		return data
	end
	
	-- If we have reached this point in the process, the plot is flatlands.
	if terrainType == TerrainTypes.TERRAIN_SNOW then -- Snow are Junk.
		data[4] = true;
		data[5] = true;
		return data
		
	elseif terrainType == TerrainTypes.TERRAIN_DESERT then -- Non-Oasis, non-FloodPlain flat deserts are Junk, except in Desert regions.
		if region_type == 4 then
			data[3] = true;
		else
			data[4] = true;
		end
		return data

	elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then -- Naked Tundra are Junk, except in Tundra Regions where they are Food
		if region_type == 1 then
			data[3] = true;
		else
			data[4] = true;
		end
		return data

	elseif terrainType == TerrainTypes.TERRAIN_PLAINS then -- Plains are Good for all region types, but Food in only non-Grassland.
		data[3] = true;
		if region_type == 1 or region_type == 4 or region_type == 5 or region_type == 6 or region_type == 8 then
			data[1] = true;
		end
		return data

	elseif terrainType == TerrainTypes.TERRAIN_GRASS then -- Grass is Food, Good for all region types.
		data[1] = true;
		data[3] = true;
		return data
	end

	-- If we have arrived here, the plot has non-standard terrain.
	print("Encountered non-standard terrain.");
	return data
end
------------------------------------------------------------------------------
function AssignStartingPlots:EvaluateCandidatePlot(plotIndex, region_type)
	local goodSoFar = true;
	local iW, iH = Map.GetGridSize();
	local x = (plotIndex - 1) % iW;
	local y = (plotIndex - x - 1) / iW;
	local plot = Map.GetPlot(x, y);
	local isEvenY = true;
	if y / 2 > math.floor(y / 2) then
		isEvenY = false;
	end
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local distance_bias = self.distanceData[plotIndex];
	local adjacentMountainCount = 0;
	local foodTotal, prodTotal, goodTotal, junkTotal, riverTotal, coastScore = 0, 0, 0, 0, 0, 0;
	local search_table = {};
	
	-- Check candidate plot to see if it's adjacent to saltwater.
	if self.plotDataIsCoastal[plotIndex] == true then
		coastScore = 40;
	end
		
	-- Check candidate plot for hills and river
	local innerRingScore = 0;
	local result = self:MeasureSinglePlot(x, y, region_type, 0)
	if result[2] then
		innerRingScore = innerRingScore + 4;
		if result[5] then
			innerRingScore = innerRingScore + 4;
		end
	end
	if result[3] then
		goodTotal = goodTotal + 1;
		if result[5] then
			goodTotal = goodTotal + 1;
		end
	end
	if plot:IsRiverSide() or plot:IsFreshWater() then
		riverTotal = riverTotal + 4;
	end
		
	-- Evaluate First Ring
	if isEvenY then
		search_table = self.firstRingYIsEven;
	else
		search_table = self.firstRingYIsOdd;
	end

	for loop, plot_adjustments in ipairs(search_table) do
		local searchX, searchY;
		if wrapX then
			searchX = (x + plot_adjustments[1]) % iW;
		else
			searchX = x + plot_adjustments[1];
		end
		if wrapY then
			searchY = (y + plot_adjustments[2]) % iH;
		else
			searchY = y + plot_adjustments[2];
		end
		--
		if searchX < 0 or searchX >= iW or searchY < 0 or searchY >= iH then
			-- This plot does not exist. It's off the map edge.
			junkTotal = junkTotal + 1;
		else
			local searchPlot = Map.GetPlot(searchX, searchY);
			local result = self:MeasureSinglePlot(searchX, searchY, region_type, 1)
			if result[4] then
				junkTotal = junkTotal + 1;
				if searchPlot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN and adjacentMountainCount == 0 then
					--junkTotal = junkTotal - 1;
					adjacentMountainCount = adjacentMountainCount + 1;
				elseif result[5] then
					junkTotal = junkTotal + 1;
				end
			else
				if result[1] then
					foodTotal = foodTotal + 1;
					if result[5] then
						foodTotal = foodTotal + 1;
					end
				end
				if result[2] then
					prodTotal = prodTotal + 1;
					if result[5] then
						prodTotal = prodTotal + 1;
					end
				end
				if result[3] then
					goodTotal = goodTotal + 1;
					if result[5] then
						goodTotal = goodTotal + 1;
					end
				end
				if searchPlot:IsRiverSide() or plot:IsFreshWater() then
					riverTotal = riverTotal + 2;
				end
			end
		end
	end

	-- Now check the results from the first ring against the established targets.
	if foodTotal < self.minFoodInner then
		goodSoFar = false;
	elseif prodTotal < self.minProdInner then
		goodSoFar = false;
	elseif goodTotal < self.minGoodInner then
		goodSoFar = false;
	end

	-- Set up the "score" for this candidate. Inner ring results weigh the heaviest.
	local weightedFoodInner = {0, 8, 14, 19, 22, 24, 25};
	local foodResultInner = weightedFoodInner[foodTotal + 1];
	local weightedProdInner = {0, 10, 16, 20, 20, 12, 0};
	local prodResultInner = weightedProdInner[prodTotal + 1];
	local goodResultInner = goodTotal * 2;
	innerRingScore = innerRingScore + foodResultInner + prodResultInner + goodResultInner + riverTotal - (junkTotal * 3);
	
	-- Evaluate Second Ring
	if isEvenY then
		search_table = self.secondRingYIsEven;
	else
		search_table = self.secondRingYIsOdd;
	end

	for loop, plot_adjustments in ipairs(search_table) do
		local searchX, searchY;
		if wrapX then
			searchX = (x + plot_adjustments[1]) % iW;
		else
			searchX = x + plot_adjustments[1];
		end
		if wrapY then
			searchY = (y + plot_adjustments[2]) % iH;
		else
			searchY = y + plot_adjustments[2];
		end
		if searchX < 0 or searchX >= iW or searchY < 0 or searchY >= iH then
			-- This plot does not exist. It's off the map edge.
			junkTotal = junkTotal + 1;
		else
			local result = self:MeasureSinglePlot(searchX, searchY, region_type, 2)
			if result[4] then
				junkTotal = junkTotal + 1;
				if result[5] then
					junkTotal = junkTotal + 1;
				end
			else
				if result[1] then
					foodTotal = foodTotal + 1;
					if result[5] then
						foodTotal = foodTotal + 1;
					end
				end
				if result[2] then
					prodTotal = prodTotal + 1;
					if result[5] then
						prodTotal = prodTotal + 1;
					end
				end
				if result[3] then
					goodTotal = goodTotal + 1;
					if result[5] then
						goodTotal = goodTotal + 1;
					end
				end
				local searchPlot = Map.GetPlot(searchX, searchY);
				if searchPlot:IsRiverSide() or plot:IsFreshWater() then
					riverTotal = riverTotal + 2;
				end
			end
		end
	end

	-- Check the results from the second ring against the established targets.
	if foodTotal < self.minFoodMiddle then
		goodSoFar = false;
	elseif prodTotal < self.minProdMiddle then
		goodSoFar = false;
	elseif goodTotal < self.minGoodMiddle then
		goodSoFar = false;
	end
	
	-- Update up the "score" for this candidate. Middle ring results weigh significantly.
	local weightedFoodMiddle = {0, 2, 5, 10, 20, 25, 28, 30, 32, 34, 35}; -- 35 for any further values.
	local foodResultMiddle = 35;
	if foodTotal < 10 then
		foodResultMiddle = weightedFoodMiddle[foodTotal + 1];
	end
	local weightedProdMiddle = {0, 10, 20, 25, 30, 35}; -- 35 for any further values.
	local effectiveProdTotal = prodTotal;
	if foodTotal * 2 < prodTotal then
		effectiveProdTotal = math.ceil(foodTotal / 2);
	end
	local prodResultMiddle = 35;
	if effectiveProdTotal < 5 then
		prodResultMiddle = weightedProdMiddle[effectiveProdTotal + 1];
	end
	local goodResultMiddle = goodTotal * 2;
	local middleRingScore = foodResultMiddle + prodResultMiddle + goodResultMiddle + riverTotal - (junkTotal * 3);
	
	-- Evaluate Third Ring
	if isEvenY then
		search_table = self.thirdRingYIsEven;
	else
		search_table = self.thirdRingYIsOdd;
	end

	for loop, plot_adjustments in ipairs(search_table) do
		local searchX, searchY;
		if wrapX then
			searchX = (x + plot_adjustments[1]) % iW;
		else
			searchX = x + plot_adjustments[1];
		end
		if wrapY then
			searchY = (y + plot_adjustments[2]) % iH;
		else
			searchY = y + plot_adjustments[2];
		end
		if searchX < 0 or searchX >= iW or searchY < 0 or searchY >= iH then
			-- This plot does not exist. It's off the map edge.
			junkTotal = junkTotal + 1;
		else
			local result = self:MeasureSinglePlot(searchX, searchY, region_type, 3)
			if result[4] then
				junkTotal = junkTotal + 1;
				if result[5] then
					junkTotal = junkTotal + 1;
				end
			else
				if result[1] then
					foodTotal = foodTotal + 1;
					if result[5] then
						foodTotal = foodTotal + 1;
					end
				end
				if result[2] then
					prodTotal = prodTotal + 1;
					if result[5] then
						prodTotal = prodTotal + 1;
					end
				end
				if result[3] then
					goodTotal = goodTotal + 1;
					if result[5] then
						goodTotal = goodTotal + 1;
					end
				end
				local searchPlot = Map.GetPlot(searchX, searchY);
				if searchPlot:IsRiverSide() or plot:IsFreshWater() then
					riverTotal = riverTotal + 2;
				end
			end
		end
	end

	-- Check the results from the third ring against the established targets.
	if foodTotal < self.minFoodOuter then
		goodSoFar = false;
	elseif prodTotal < self.minProdOuter then
		goodSoFar = false;
	elseif goodTotal < self.minGoodOuter then
		goodSoFar = false;
	end
	if junkTotal > self.maxJunk then
		goodSoFar = false;
	end

	-- Tally the final "score" for this candidate.
	local outerRingScore = foodTotal + prodTotal + goodTotal + riverTotal - (junkTotal * 2);
	local finalScore = innerRingScore + middleRingScore + outerRingScore + coastScore;

	-- Check Impact and Ripple data to see if candidate is near an already-placed start point.
	if distance_bias > 0 then
		-- This candidate is near an already placed start. This invalidates its 
		-- eligibility for first-pass placement; but it may still qualify as a 
		-- fallback site, so we will reduce its Score according to the bias factor.
		goodSoFar = false;
		finalScore = finalScore - math.floor(finalScore * distance_bias / 100);
	end

	--[[ Debug
	print(".");
	print("Plot:", x, y, " Food:", foodTotal, "Prod: ", prodTotal, "Good:", goodTotal, "Junk:", 
	       junkTotal, "River:", riverTotal, "Score:", finalScore);
	print("Plot:", x, y, " Coastal:", self.plotDataIsCoastal[plotIndex], "Distance Bias:", distance_bias);
	]]--
	
	return finalScore, goodSoFar
end
------------------------------------------------------------------------------
function AssignStartingPlots:IterateThroughCandidatePlotList(plot_list, region_type)
	-- Iterates through a list of candidate plots.
	-- Each plot is identified by its global plot index.
	-- This function assumes all candidate plots can have a city built on them.
	-- Any plots not allowed to have a city should be weeded out when building the candidate list.
	local found_eligible = false;
	local bestPlotScore = -5000;
	local bestPlotIndex;
	local found_fallback = false;
	local bestFallbackScore = -5000;
	local bestFallbackIndex;
	-- Process list of candidate plots.
	for loop, plotIndex in ipairs(plot_list) do
		local score, meets_minimums = self:EvaluateCandidatePlot(plotIndex, region_type)
		-- Test current plot against best known plot.
		if meets_minimums == true then
			found_eligible = true;
			if score > bestPlotScore then
				bestPlotScore = score;
				bestPlotIndex = plotIndex;
			end
		else
			found_fallback = true;
			if score > bestFallbackScore then
				bestFallbackScore = score;
				bestFallbackIndex = plotIndex;
			end
		end
	end
	-- returns table containing six variables: boolean, integer, integer, boolean, integer, integer
	local election_results = {found_eligible, bestPlotScore, bestPlotIndex, found_fallback, bestFallbackScore, bestFallbackIndex};
	return election_results
end
------------------------------------------------------------------------------
function AssignStartingPlots:FindStart(region_number, NoCoast)
	
	print("No Coast: ", NoCoast);
	
	-- This function attempts to choose a start position for a single region.
	-- This function returns two boolean flags, indicating the success level of the operation.
	local bSuccessFlag = false; -- Returns true when a start is placed, false when process fails.
	local bForcedPlacementFlag = false; -- Returns true if this region had no eligible starts and one was forced to occur.

	-- Obtain data needed to process this region.
	local iW, iH = Map.GetGridSize();
	local region_data_table = self.regionData[region_number];
	local iWestX = region_data_table[1];
	local iSouthY = region_data_table[2];
	local iWidth = region_data_table[3];
	local iHeight = region_data_table[4];
	local iAreaID = region_data_table[5];
	local iMembershipEastX = iWestX + iWidth - 1;
	local iMembershipNorthY = iSouthY + iHeight - 1;
	--
	local terrainCounts = self.regionTerrainCounts[region_number];
	--
	local region_type = self.regionTypes[region_number];
	-- Done setting up region data.
	-- Set up contingency.
	local fallback_plots = {};
	
	-- Establish scope of center bias.
	local fCenterWidth = (self.centerBias / 100) * iWidth;
	local iNonCenterWidth = math.floor((iWidth - fCenterWidth) / 2)
	local iCenterWidth = iWidth - (iNonCenterWidth * 2);
	local iCenterWestX = (iWestX + iNonCenterWidth) % iW; -- Modulo math to synch coordinate to actual map in case of world wrap.
	local iCenterTestWestX = (iWestX + iNonCenterWidth); -- "Test" values ignore world wrap for easier membership testing.
	local iCenterTestEastX = (iCenterWestX + iCenterWidth - 1);

	local fCenterHeight = (self.centerBias / 100) * iHeight;
	local iNonCenterHeight = math.floor((iHeight - fCenterHeight) / 2)
	local iCenterHeight = iHeight - (iNonCenterHeight * 2);
	local iCenterSouthY = (iSouthY + iNonCenterHeight) % iH;
	local iCenterTestSouthY = (iSouthY + iNonCenterHeight);
	local iCenterTestNorthY = (iCenterTestSouthY + iCenterHeight - 1);

	-- Establish scope of "middle donut", outside the center but inside the outer.
	local fMiddleWidth = (self.middleBias / 100) * iWidth;
	local iOuterWidth = math.floor((iWidth - fMiddleWidth) / 2)
	local iMiddleWidth = iWidth - (iOuterWidth * 2);
	local iMiddleWestX = (iWestX + iOuterWidth) % iW;
	local iMiddleTestWestX = (iWestX + iOuterWidth);
	local iMiddleTestEastX = (iMiddleTestWestX + iMiddleWidth - 1);

	local fMiddleHeight = (self.middleBias / 100) * iHeight;
	local iOuterHeight = math.floor((iHeight - fMiddleHeight) / 2)
	local iMiddleHeight = iHeight - (iOuterHeight * 2);
	local iMiddleSouthY = (iSouthY + iOuterHeight) % iH;
	local iMiddleTestSouthY = (iSouthY + iOuterHeight);
	local iMiddleTestNorthY = (iMiddleTestSouthY + iMiddleHeight - 1); 

	-- Assemble candidates lists.
	local two_plots_from_ocean = {};
	local three_plots_from_ocean = {};
	local four_plots_from_ocean = {};
	local center_candidates = {};
	local center_river = {};
	local center_coastal = {};
	local center_inland_dry = {};
	local middle_candidates = {};
	local middle_river = {};
	local middle_coastal = {};
	local middle_inland_dry = {};
	local outer_plots = {};
	
	-- Identify candidate plots.
	for region_y = 0, iHeight - 1 do -- When handling global plot indices, process Y first.
		for region_x = 0, iWidth - 1 do
			local x = (region_x + iWestX) % iW; -- Actual coords, adjusted for world wrap, if any.
			local y = (region_y + iSouthY) % iH; --
			local plotIndex = y * iW + x + 1;
			local plot = Map.GetPlot(x, y);
			local plotType = plot:GetPlotType()
			if plotType == PlotTypes.PLOT_HILLS or plotType == PlotTypes.PLOT_LAND then -- Could host a city.
				-- Check if plot is two away from salt water.
				if self.plotDataIsNextToCoast[plotIndex] == true then
					table.insert(two_plots_from_ocean, plotIndex);
				elseif self.plotDataIsThreeFromCoast[plotIndex] == true then
					table.insert(three_plots_from_ocean, plotIndex);
				else
					local area_of_plot = plot:GetArea();
					if area_of_plot == iAreaID or iAreaID == -1 then -- This plot is a member, so it goes on at least one candidate list.
						--
						-- Test whether plot is in center bias, middle donut, or outer donut.
						--
						local test_x = region_x + iWestX; -- "Test" coords, ignoring any world wrap and
						local test_y = region_y + iSouthY; -- reaching in to virtual space if necessary.
						if (test_x >= iCenterTestWestX and test_x <= iCenterTestEastX) and 
						   (test_y >= iCenterTestSouthY and test_y <= iCenterTestNorthY) then -- Center Bias.
							
							if NoCoast == true and self.plotDataIsCoastal[plotIndex] == true then
								-- do nothing
							elseif plot:IsRiverSide() then
								table.insert(center_river, plotIndex);
								table.insert(center_candidates, plotIndex);
							elseif plot:IsFreshWater() or self.plotDataIsCoastal[plotIndex] == true then
								table.insert(center_coastal, plotIndex);
								table.insert(center_candidates, plotIndex);
							else
								table.insert(center_inland_dry, plotIndex);
								table.insert(center_candidates, plotIndex);
							end
							
						elseif (test_x >= iMiddleTestWestX and test_x <= iMiddleTestEastX) and 
						       (test_y >= iMiddleTestSouthY and test_y <= iMiddleTestNorthY) then
							
							if NoCoast == true and self.plotDataIsCoastal[plotIndex] == true then
								--do nothing
							elseif plot:IsRiverSide() then
								table.insert(middle_river, plotIndex);
								table.insert(middle_candidates, plotIndex);
							elseif plot:IsFreshWater() or self.plotDataIsCoastal[plotIndex] == true then
								table.insert(middle_coastal, plotIndex);
								table.insert(middle_candidates, plotIndex);
							else
								table.insert(middle_inland_dry, plotIndex);
								table.insert(middle_candidates, plotIndex);
							end
						else
							if NoCoast == true and self.plotDataIsCoastal[plotIndex] == true then
								--do nothing
							else
								table.insert(outer_plots, plotIndex);
							end
						end
					end
				end
			end
		end
	end

	
	-- Check how many plots landed on each list.
	local iNumDisqualified = table.maxn(two_plots_from_ocean) + table.maxn(three_plots_from_ocean);
	local iNumCenter = table.maxn(center_candidates);
	local iNumCenterRiver = table.maxn(center_river);
	local iNumCenterCoastLake = table.maxn(center_coastal);
	local iNumCenterInlandDry = table.maxn(center_inland_dry);
	local iNumMiddle = table.maxn(middle_candidates);
	local iNumMiddleRiver = table.maxn(middle_river);
	local iNumMiddleCoastLake = table.maxn(middle_coastal);
	local iNumMiddleInlandDry = table.maxn(middle_inland_dry);
	local iNumOuter = table.maxn(outer_plots);
	
	-- Debug printout.
	print("-");
	print("--- Number of Candidate Plots in Region #", region_number, " - Region Type:", region_type, " ---");
	print("-");
	print("Center Of Region at: " .. tostring(iCenterWestX) .. "," .. tostring(iCenterSouthY));
	print("-");
	print("Candidates in Center Bias area: ", iNumCenter);
	print("Which are next to river: ", iNumCenterRiver);
	print("Which are next to lake or sea: ", iNumCenterCoastLake);
	print("Which are inland and dry: ", iNumCenterInlandDry);
	print("-");
	print("Candidates in Middle Donut area: ", iNumMiddle);
	print("Which are next to river: ", iNumMiddleRiver);
	print("Which are next to lake or sea: ", iNumMiddleCoastLake);
	print("Which are inland and dry: ", iNumMiddleInlandDry);
	print("-");
	print("Candidate Plots in Outer area: ", iNumOuter);
	print("-");
	print("Disqualified, two or three plots away from salt water: ", iNumDisqualified);
	print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
	
	
	-- Process lists of candidate plots.
	if iNumCenter + iNumMiddle > 0 then
		if self._lek_prioritize_center then
			print("DEV/SAPHT Using _lek_prioritize_center")
			local candidate_lists = {};
			if iNumCenterRiver > 0 then -- Process center bias river plots.
				table.insert(candidate_lists, center_river);
			end
			if iNumCenterCoastLake > 0 then -- Process center bias lake or coastal plots.
				table.insert(candidate_lists, center_coastal);
			end
			if iNumCenterInlandDry > 0 then -- Process center bias inland dry plots.
				table.insert(candidate_lists, center_inland_dry);
			end
			--
			for loop, plot_list in ipairs(candidate_lists) do -- Up to six plot lists, processed by priority.
				local election_returns = self:IterateThroughCandidatePlotList(plot_list, region_type)
				-- If any candidates are eligible, choose one.
				local found_eligible = election_returns[1];
				if found_eligible then
					local bestPlotScore = election_returns[2]; 
					local bestPlotIndex = election_returns[3];
					local x = (bestPlotIndex - 1) % iW;
					local y = (bestPlotIndex - x - 1) / iW;
					self.startingPlots[region_number] = {x, y, bestPlotScore};
					self:PlaceImpactAndRipples(x, y, region_number)
					return true, false
				end
				-- If none eligible, check for fallback plot.
				local found_fallback = election_returns[4];
				if found_fallback then
					local bestFallbackScore = election_returns[5];
					local bestFallbackIndex = election_returns[6];
					local x = (bestFallbackIndex - 1) % iW;
					local y = (bestFallbackIndex - x - 1) / iW;
					table.insert(fallback_plots, {x, y, bestFallbackScore});
				end
			end

			candidate_lists = {}
			if iNumMiddleRiver > 0 then -- Process middle donut river plots.
				table.insert(candidate_lists, middle_river);
			end
			if iNumMiddleCoastLake > 0 then -- Process middle donut lake or coastal plots.
				table.insert(candidate_lists, middle_coastal);
			end
			if iNumMiddleInlandDry > 0 then -- Process middle donut inland dry plots.
				table.insert(candidate_lists, middle_inland_dry);
			end
			--
			for loop, plot_list in ipairs(candidate_lists) do -- Up to six plot lists, processed by priority.
				local election_returns = self:IterateThroughCandidatePlotList(plot_list, region_type)
				-- If any candidates are eligible, choose one.
				local found_eligible = election_returns[1];
				if found_eligible then
					local bestPlotScore = election_returns[2]; 
					local bestPlotIndex = election_returns[3];
					local x = (bestPlotIndex - 1) % iW;
					local y = (bestPlotIndex - x - 1) / iW;
					self.startingPlots[region_number] = {x, y, bestPlotScore};
					self:PlaceImpactAndRipples(x, y, region_number)
					return true, false
				end
				-- If none eligible, check for fallback plot.
				local found_fallback = election_returns[4];
				if found_fallback then
					local bestFallbackScore = election_returns[5];
					local bestFallbackIndex = election_returns[6];
					local x = (bestFallbackIndex - 1) % iW;
					local y = (bestFallbackIndex - x - 1) / iW;
					table.insert(fallback_plots, {x, y, bestFallbackScore});
				end
			end
		else
			print("DEV/SAPHT Using default center priority")
			local candidate_lists = {};
			if iNumCenterRiver > 0 then -- Process center bias river plots.
				table.insert(candidate_lists, center_river);
			end
			if iNumCenterCoastLake > 0 then -- Process center bias lake or coastal plots.
				table.insert(candidate_lists, center_coastal);
			end
			if iNumCenterInlandDry > 0 then -- Process center bias inland dry plots.
				table.insert(candidate_lists, center_inland_dry);
			end
			if iNumMiddleRiver > 0 then -- Process middle donut river plots.
				table.insert(candidate_lists, middle_river);
			end
			if iNumMiddleCoastLake > 0 then -- Process middle donut lake or coastal plots.
				table.insert(candidate_lists, middle_coastal);
			end
			if iNumMiddleInlandDry > 0 then -- Process middle donut inland dry plots.
				table.insert(candidate_lists, middle_inland_dry);
			end
			--
			for loop, plot_list in ipairs(candidate_lists) do -- Up to six plot lists, processed by priority.
				local election_returns = self:IterateThroughCandidatePlotList(plot_list, region_type)
				-- If any candidates are eligible, choose one.
				local found_eligible = election_returns[1];
				if found_eligible then
					local bestPlotScore = election_returns[2]; 
					local bestPlotIndex = election_returns[3];
					local x = (bestPlotIndex - 1) % iW;
					local y = (bestPlotIndex - x - 1) / iW;
					self.startingPlots[region_number] = {x, y, bestPlotScore};
					self:PlaceImpactAndRipples(x, y, region_number)
					return true, false
				end
				-- If none eligible, check for fallback plot.
				local found_fallback = election_returns[4];
				if found_fallback then
					local bestFallbackScore = election_returns[5];
					local bestFallbackIndex = election_returns[6];
					local x = (bestFallbackIndex - 1) % iW;
					local y = (bestFallbackIndex - x - 1) / iW;
					table.insert(fallback_plots, {x, y, bestFallbackScore});
				end
			end
		end
	end
	-- Reaching this point means no eligible sites in center bias or middle donut subregions!
	
	-- Process candidates from Outer subregion, if any.
	if iNumOuter > 0 then
		local outer_eligible_list = {};
		local found_eligible = false;
		local found_fallback = false;
		local bestFallbackScore = -50;
		local bestFallbackIndex;
		-- Process list of candidate plots.
		for loop, plotIndex in ipairs(outer_plots) do
			local score, meets_minimums = self:EvaluateCandidatePlot(plotIndex, region_type)
			-- Test current plot against best known plot.
			if meets_minimums == true then
				found_eligible = true;
				table.insert(outer_eligible_list, plotIndex);
			else
				found_fallback = true;
				if score > bestFallbackScore then
					bestFallbackScore = score;
					bestFallbackIndex = plotIndex;
				end
			end
		end
		if found_eligible then -- Iterate through eligible plots and choose the one closest to the center of the region.
			local closestPlot;
			local closestDistance = math.max(iW, iH);
			local bullseyeX = iWestX + (iWidth / 2);
			if bullseyeX < iWestX then -- wrapped around: un-wrap it for test purposes.
				bullseyeX = bullseyeX + iW;
			end
			local bullseyeY = iSouthY + (iHeight / 2);
			if bullseyeY < iSouthY then -- wrapped around: un-wrap it for test purposes.
				bullseyeY = bullseyeY + iH;
			end
			if bullseyeY / 2 ~= math.floor(bullseyeY / 2) then -- Y coord is odd, add .5 to X coord for hex-shift.
				bullseyeX = bullseyeX + 0.5;
			end
			
			for loop, plotIndex in ipairs(outer_eligible_list) do
				local x = (plotIndex - 1) % iW;
				local y = (plotIndex - x - 1) / iW;
				local adjusted_x = x;
				local adjusted_y = y;
				if y / 2 ~= math.floor(y / 2) then -- Y coord is odd, add .5 to X coord for hex-shift.
					adjusted_x = x + 0.5;
				end
				
				if x < iWestX then -- wrapped around: un-wrap it for test purposes.
					adjusted_x = adjusted_x + iW;
				end
				if y < iSouthY then -- wrapped around: un-wrap it for test purposes.
					adjusted_y = y + iH;
				end
				local fDistance = math.sqrt( (adjusted_x - bullseyeX)^2 + (adjusted_y - bullseyeY)^2 );
				if fDistance < closestDistance then -- Found new "closer" plot.
					closestPlot = plotIndex;
					closestDistance = fDistance;
				end
			end
			-- Assign the closest eligible plot as the start point.
			local x = (closestPlot - 1) % iW;
			local y = (closestPlot - x - 1) / iW;
			-- Re-get plot score for inclusion in start plot data.
			local score, meets_minimums = self:EvaluateCandidatePlot(closestPlot, region_type)
			-- Assign this plot as the start for this region.
			self.startingPlots[region_number] = {x, y, score};
			self:PlaceImpactAndRipples(x, y, region_number)
			return true, false
		end
		-- Add the fallback plot (best scored plot) from the Outer region to the fallback list.
		if found_fallback then
			local x = (bestFallbackIndex - 1) % iW;
			local y = (bestFallbackIndex - x - 1) / iW;
			table.insert(fallback_plots, {x, y, bestFallbackScore});
		end
	end
	-- Reaching here means no plot in the entire region met the minimum standards for selection.
	
	-- The fallback plot contains the best-scored plots from each test area in this region.
	-- We will compare all the fallback plots and choose the best to be the start plot.
	local iNumFallbacks = table.maxn(fallback_plots);
	if iNumFallbacks > 0 then
		local best_fallback_score = 0
		local best_fallback_x;
		local best_fallback_y;
		for loop, plotData in ipairs(fallback_plots) do
			local score = plotData[3];
			if score > best_fallback_score then
				best_fallback_score = score;
				best_fallback_x = plotData[1];
				best_fallback_y = plotData[2];
			end
		end
		-- Assign the start for this region.
		self.startingPlots[region_number] = {best_fallback_x, best_fallback_y, best_fallback_score};
		self:PlaceImpactAndRipples(best_fallback_x, best_fallback_y, region_number)
		bSuccessFlag = true;
	else
		-- This region cannot have a start and something has gone way wrong.
		-- We'll force a one tile grass island in the SW corner of the region and put the start there.
		print("WARNING: Region #", region_number, " has no eligible start plot! Forcing one...");
		local forcePlot = Map.GetPlot(iWestX, iSouthY);
		bSuccessFlag = true;
		bForcedPlacementFlag = true;
		forcePlot:SetPlotType(PlotTypes.PLOT_LAND, false, true);
		forcePlot:SetTerrainType(TerrainTypes.TERRAIN_GRASS, false, true);
		forcePlot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
		self.startingPlots[region_number] = {iWestX, iSouthY, 0};
		self:PlaceImpactAndRipples(iWestX, iSouthY, region_number)
	end

	return bSuccessFlag, bForcedPlacementFlag
end
------------------------------------------------------------------------------
function AssignStartingPlots:FindCoastalStart(region_number)
	-- This function attempts to choose a start position (which is along an ocean) for a single region.
	-- This function returns two boolean flags, indicating the success level of the operation.
	local bSuccessFlag = false; -- Returns true when a start is placed, false when process fails.
	local bForcedPlacementFlag = false; -- Returns true if this region had no eligible starts and one was forced to occur.
	local AllowInlandSea = self.AllowInlandSea;

	-- Obtain data needed to process this region.
	local iW, iH = Map.GetGridSize();
	local region_data_table = self.regionData[region_number];
	local iWestX = region_data_table[1];
	local iSouthY = region_data_table[2];
	local iWidth = region_data_table[3];
	local iHeight = region_data_table[4];
	local iAreaID = region_data_table[5];
	local iMembershipEastX = iWestX + iWidth - 1;
	local iMembershipNorthY = iSouthY + iHeight - 1;
	--
	local terrainCounts = self.regionTerrainCounts[region_number];
	local coastalLandCount = terrainCounts[22];
	--
	local region_type = self.regionTypes[region_number];
	-- Done setting up region data.
	-- Set up contingency.
	local fallback_plots = {};
	
	-- Check region for AlongOcean eligibility.
	print(coastalLandCount, "coastal land plots in region #", region_number);
	if coastalLandCount < 3 then
		-- This region cannot support an Along Ocean start. Try instead to find an inland start for it.
		bSuccessFlag, bForcedPlacementFlag = self:FindStart(region_number, false)
		if bSuccessFlag == false then
			-- This region cannot have a start and something has gone very wrong.
			-- We'll force a one tile grass island in the SW corner of the region and put the start there.
			print("WARNING: Region #", region_number, " has no eligible start plots! Forcing a start plot.")
			local forcePlot = Map.GetPlot(iWestX, iSouthY);
			bForcedPlacementFlag = true;
			forcePlot:SetPlotType(PlotTypes.PLOT_LAND, false, true);
			forcePlot:SetTerrainType(TerrainTypes.TERRAIN_GRASS, false, true);
			forcePlot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			self.startingPlots[region_number] = {iWestX, iSouthY, 0};
			self:PlaceImpactAndRipples(iWestX, iSouthY, region_number)
		end
		return bSuccessFlag, bForcedPlacementFlag
	end

	-- Establish scope of center bias.
	local fCenterWidth = (self.centerBias / 100) * iWidth;
	local iNonCenterWidth = math.floor((iWidth - fCenterWidth) / 2)
	local iCenterWidth = iWidth - (iNonCenterWidth * 2);
	local iCenterWestX = (iWestX + iNonCenterWidth) % iW; -- Modulo math to synch coordinate to actual map in case of world wrap.
	local iCenterTestWestX = (iWestX + iNonCenterWidth); -- "Test" values ignore world wrap for easier membership testing.
	local iCenterTestEastX = (iCenterWestX + iCenterWidth - 1);

	local fCenterHeight = (self.centerBias / 100) * iHeight;
	local iNonCenterHeight = math.floor((iHeight - fCenterHeight) / 2)
	local iCenterHeight = iHeight - (iNonCenterHeight * 2);
	local iCenterSouthY = (iSouthY + iNonCenterHeight) % iH;
	local iCenterTestSouthY = (iSouthY + iNonCenterHeight);
	local iCenterTestNorthY = (iCenterTestSouthY + iCenterHeight - 1);

	-- Establish scope of "middle donut", outside the center but inside the outer.
	local fMiddleWidth = (self.middleBias / 100) * iWidth;
	local iOuterWidth = math.floor((iWidth - fMiddleWidth) / 2)
	local iMiddleWidth = iWidth - (iOuterWidth * 2);
	--local iMiddleDiameterX = (iMiddleWidth - iCenterWidth) / 2;
	local iMiddleWestX = (iWestX + iOuterWidth) % iW;
	local iMiddleTestWestX = (iWestX + iOuterWidth);
	local iMiddleTestEastX = (iMiddleTestWestX + iMiddleWidth - 1);

	local fMiddleHeight = (self.middleBias / 100) * iHeight;
	local iOuterHeight = math.floor((iHeight - fMiddleHeight) / 2)
	local iMiddleHeight = iHeight - (iOuterHeight * 2);
	--local iMiddleDiameterY = (iMiddleHeight - iCenterHeight) / 2;
	local iMiddleSouthY = (iSouthY + iOuterHeight) % iH;
	local iMiddleTestSouthY = (iSouthY + iOuterHeight);
	local iMiddleTestNorthY = (iMiddleTestSouthY + iMiddleHeight - 1); 

	-- Assemble candidates lists.
	local center_coastal_plots = {};
	local center_plots_on_river = {};
	local center_fresh_plots = {};
	local center_dry_plots = {};
	local middle_coastal_plots = {};
	local middle_plots_on_river = {};
	local middle_fresh_plots = {};
	local middle_dry_plots = {};
	local outer_coastal_plots = {};
	
	-- Identify candidate plots.
	for region_y = 0, iHeight - 1 do -- When handling global plot indices, process Y first.
		for region_x = 0, iWidth - 1 do
			local x = (region_x + iWestX) % iW; -- Actual coords, adjusted for world wrap, if any.
			local y = (region_y + iSouthY) % iH; --
			local plotIndex = y * iW + x + 1;
			if self.plotDataIsCoastal[plotIndex] == true then -- This plot is a land plot next to an ocean.
				local plot = Map.GetPlot(x, y);
				local plotType = plot:GetPlotType()
				if plotType ~= PlotTypes.PLOT_MOUNTAIN and (AllowInlandSea == 1 or plot:IsCoastalLand(50)) then -- Not a mountain plot, nor a plot adjacent to inland sea, or inland sea allowed.
					local area_of_plot = plot:GetArea();
					if area_of_plot == iAreaID or iAreaID == -1 then -- This plot is a member, so it goes on at least one candidate list.
						--
						-- Test whether plot is in center bias, middle donut, or outer donut.
						--
						local test_x = region_x + iWestX; -- "Test" coords, ignoring any world wrap and
						local test_y = region_y + iSouthY; -- reaching in to virtual space if necessary.
						if (test_x >= iCenterTestWestX and test_x <= iCenterTestEastX) and 
						   (test_y >= iCenterTestSouthY and test_y <= iCenterTestNorthY) then
							table.insert(center_coastal_plots, plotIndex);
							if plot:IsRiverSide() then
								table.insert(center_plots_on_river, plotIndex);
							elseif plot:IsFreshWater() then
								table.insert(center_fresh_plots, plotIndex);
							else
								table.insert(center_dry_plots, plotIndex);
							end
						elseif (test_x >= iMiddleTestWestX and test_x <= iMiddleTestEastX) and 
						       (test_y >= iMiddleTestSouthY and test_y <= iMiddleTestNorthY) then
							table.insert(middle_coastal_plots, plotIndex);
							if plot:IsRiverSide() then
								table.insert(middle_plots_on_river, plotIndex);
							elseif plot:IsFreshWater() then
								table.insert(middle_fresh_plots, plotIndex);
							else
								table.insert(middle_dry_plots, plotIndex);
							end
						else
							table.insert(outer_coastal_plots, plotIndex);
						end
					end
				end
			end
		end
	end
	-- Check how many plots landed on each list.
	local iNumCenterCoastal = table.maxn(center_coastal_plots);
	local iNumCenterRiver = table.maxn(center_plots_on_river);
	local iNumCenterFresh = table.maxn(center_fresh_plots);
	local iNumCenterDry = table.maxn(center_dry_plots);
	local iNumMiddleCoastal = table.maxn(middle_coastal_plots);
	local iNumMiddleRiver = table.maxn(middle_plots_on_river);
	local iNumMiddleFresh = table.maxn(middle_fresh_plots);
	local iNumMiddleDry = table.maxn(middle_dry_plots);
	local iNumOuterCoastal = table.maxn(outer_coastal_plots);
	
	-- Debug printout.
	print("-");
	print("--- Number of Candidate Plots next to an ocean in Region #", region_number, " - Region Type:", region_type, " ---");
	print("-");
	print("Center Of Region at: " .. tostring(iCenterWestX) .. "," .. tostring(iCenterSouthY));
	print("-");
	print("Coastal Plots in Center Bias area: ", iNumCenterCoastal);
	print("Which are along rivers: ", iNumCenterRiver);
	print("Which are fresh water: ", iNumCenterFresh);
	print("Which are dry: ", iNumCenterDry);
	print("-");
	print("Coastal Plots in Middle Donut area: ", iNumMiddleCoastal);
	print("Which are along rivers: ", iNumMiddleRiver);
	print("Which are fresh water: ", iNumMiddleFresh);
	print("Which are dry: ", iNumMiddleDry);
	print("-");
	print("Coastal Plots in Outer area: ", iNumOuterCoastal);
	print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
	--
	
	-- Process lists of candidate plots.
	if iNumCenterCoastal + iNumMiddleCoastal > 0 then
		local candidate_lists = {};
		if iNumCenterRiver > 0 then -- Process center bias river plots.
			table.insert(candidate_lists, center_plots_on_river);
		end
		if iNumCenterFresh > 0 then -- Process center bias fresh water plots that are not rivers.
			table.insert(candidate_lists, center_fresh_plots);
		end
		if iNumCenterDry > 0 then -- Process center bias dry plots.
			table.insert(candidate_lists, center_dry_plots);
		end
		if iNumMiddleRiver > 0 then -- Process middle bias river plots.
			table.insert(candidate_lists, middle_plots_on_river);
		end
		if iNumMiddleFresh > 0 then -- Process middle bias fresh water plots that are not rivers.
			table.insert(candidate_lists, middle_fresh_plots);
		end
		if iNumMiddleDry > 0 then -- Process middle bias dry plots.
			table.insert(candidate_lists, middle_dry_plots);
		end

		for loop, plot_list in ipairs(candidate_lists) do -- Up to six plot lists, processed by priority.
			local election_returns = self:IterateThroughCandidatePlotList(plot_list, region_type)
			-- If any riverside candidates are eligible, choose one.
			local found_eligible = election_returns[1];
			if found_eligible then
				local bestPlotScore = election_returns[2]; 
				local bestPlotIndex = election_returns[3];
				local x = (bestPlotIndex - 1) % iW;
				local y = (bestPlotIndex - x - 1) / iW;
				self.startingPlots[region_number] = {x, y, bestPlotScore};
				self:PlaceImpactAndRipples(x, y, region_number)
				return true, false
			end
			-- If none eligible, check for fallback plot.
			local found_fallback = election_returns[4];
			if found_fallback then
				local bestFallbackScore = election_returns[5];
				local bestFallbackIndex = election_returns[6];
				local x = (bestFallbackIndex - 1) % iW;
				local y = (bestFallbackIndex - x - 1) / iW;
				table.insert(fallback_plots, {x, y, bestFallbackScore});
			end
		end
	end
	-- Reaching this point means no strong coastal sites in center bias or middle donut subregions!
	
	-- Process candidates from Outer subregion, if any.
	if iNumOuterCoastal > 0 then
		print("outer plot count found")
		local outer_eligible_list = {};
		local found_eligible = false;
		local found_fallback = false;
		local bestFallbackScore = -50;
		local bestFallbackIndex;
		-- Process list of candidate plots.
		for loop, plotIndex in ipairs(outer_coastal_plots) do
			print("loop: ", loop, " plotIndex: ", plotIndex)
			local score, meets_minimums = self:EvaluateCandidatePlot(plotIndex, region_type)
			-- Test current plot against best known plot.
			if meets_minimums == true then
				found_eligible = true;
				table.insert(outer_eligible_list, plotIndex);
				print("found outer plot in donut")
			else
				found_fallback = true;
				print("found outer FALLBACK plot in donut")
				if score > bestFallbackScore then
					bestFallbackScore = score;
					bestFallbackIndex = plotIndex;
				end
			end
		end

		if found_eligible then -- Iterate through eligible plots and choose the one closest to the center of the region.
			local closestPlot;
			local closestDistance = math.max(iW, iH);
			local bullseyeX = iWestX + (iWidth / 2);
			if bullseyeX < iWestX then -- wrapped around: un-wrap it for test purposes.
				bullseyeX = bullseyeX + iW;
			end
			local bullseyeY = iSouthY + (iHeight / 2);
			if bullseyeY < iSouthY then -- wrapped around: un-wrap it for test purposes.
				bullseyeY = bullseyeY + iH;
			end
			if bullseyeY / 2 ~= math.floor(bullseyeY / 2) then -- Y coord is odd, add .5 to X coord for hex-shift.
				bullseyeX = bullseyeX + 0.5;
			end
			
			for loop, plotIndex in ipairs(outer_eligible_list) do
				local x = (plotIndex - 1) % iW;
				local y = (plotIndex - x - 1) / iW;
				local adjusted_x = x;
				local adjusted_y = y;
				if y / 2 ~= math.floor(y / 2) then -- Y coord is odd, add .5 to X coord for hex-shift.
					adjusted_x = x + 0.5;
				end
				
				if x < iWestX then -- wrapped around: un-wrap it for test purposes.
					adjusted_x = adjusted_x + iW;
				end
				if y < iSouthY then -- wrapped around: un-wrap it for test purposes.
					adjusted_y = y + iH;
				end
				local fDistance = math.sqrt( (adjusted_x - bullseyeX)^2 + (adjusted_y - bullseyeY)^2 );
				if fDistance < closestDistance then -- Found new "closer" plot.
					closestPlot = plotIndex;
					closestDistance = fDistance;
				end
			end
			-- Assign the closest eligible plot as the start point.
			local x = (closestPlot - 1) % iW;
			local y = (closestPlot - x - 1) / iW;
			-- Re-get plot score for inclusion in start plot data.
			local score, meets_minimums = self:EvaluateCandidatePlot(closestPlot, region_type)
			-- Assign this plot as the start for this region.
			print("Found an outer region plot")
			print("x: ", x, " y: ", y)
			self.startingPlots[region_number] = {x, y, score};
			self:PlaceImpactAndRipples(x, y, region_number)
			return true, false
		end
		-- Add the fallback plot (best scored plot) from the Outer region to the fallback list.
		if found_fallback then
			local x = (bestFallbackIndex - 1) % iW;
			local y = (bestFallbackIndex - x - 1) / iW;
			table.insert(fallback_plots, {x, y, bestFallbackScore});
		end
	end
	-- Reaching here means no plot in the entire region met the minimum standards for selection.
	
	-- The fallback plot contains the best-scored plots from each test area in this region.
	-- This region must be something awful on food, or had too few coastal plots with none being decent.
	-- We will compare all the fallback plots and choose the best to be the start plot.
	local iNumFallbacks = table.maxn(fallback_plots);
	if iNumFallbacks > 0 then
		local best_fallback_score = 0
		local best_fallback_x;
		local best_fallback_y;
		for loop, plotData in ipairs(fallback_plots) do
			local score = plotData[3];
			if score > best_fallback_score then
				best_fallback_score = score;
				best_fallback_x = plotData[1];
				best_fallback_y = plotData[2];
			end
		end
		-- Assign the start for this region.
		print("Found a rare case fallback plot")
		print("x: ", best_fallback_x, " y: ", best_fallback_y)
		self.startingPlots[region_number] = {best_fallback_x, best_fallback_y, best_fallback_score};
		self:PlaceImpactAndRipples(best_fallback_x, best_fallback_y, region_number)
		bSuccessFlag = true;
	else
		-- This region cannot support an Along Ocean start. Try instead to find an Inland start for it.
		print("Region #", region_number, " cannot support an Along Ocean start. Trying to find an Inland start for it.");
		bSuccessFlag, bForcedPlacementFlag = self:FindStart(region_number, false)
		if bSuccessFlag == false then
			-- This region cannot have a start and something has gone way wrong.
			-- We'll force a one tile grass island in the SW corner of the region and put the start there.
			local forcePlot = Map.GetPlot(iWestX, iSouthY);
			bSuccessFlag = false;
			bForcedPlacementFlag = true;
			forcePlot:SetPlotType(PlotTypes.PLOT_LAND, false, true);
			forcePlot:SetTerrainType(TerrainTypes.TERRAIN_GRASS, false, true);
			forcePlot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			self.startingPlots[region_number] = {iWestX, iSouthY, 0};
			self:PlaceImpactAndRipples(iWestX, iSouthY, region_number)
		end
	end

	return bSuccessFlag, bForcedPlacementFlag
end
------------------------------------------------------------------------------
function AssignStartingPlots:FindStartWithoutRegardToAreaID(region_number, bMustBeCoast)
	-- This function attempts to choose a start position on the best AreaID section within the Region's rectangle.
	-- This function returns two boolean flags, indicating the success level of the operation.
	local bSuccessFlag = false; -- Returns true when a start is placed, false when process fails.
	local bForcedPlacementFlag = false; -- Returns true if this region had no eligible starts and one was forced to occur.
	
	-- Obtain data needed to process this region.
	local iW, iH = Map.GetGridSize();
	local region_data_table = self.regionData[region_number];
	local iWestX = region_data_table[1];
	local iSouthY = region_data_table[2];
	local iWidth = region_data_table[3];
	local iHeight = region_data_table[4];
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local iMembershipEastX = iWestX + iWidth - 1;
	local iMembershipNorthY = iSouthY + iHeight - 1;
	--
	local region_type = self.regionTypes[region_number];
	local fallback_plots = {};
	-- Done setting up region data.

	-- Obtain info on all landmasses wholly or partially within this region, for comparision purposes.
	local regionalFertilityOfLands = {};
	local iRegionalFertilityOfLands = 0;
	local iNumLandPlots = 0;
	local iNumLandAreas = 0;
	local land_area_IDs = {};
	local land_area_plots = {};
	local land_area_fert = {};
	local land_area_plot_lists = {};
	-- Cycle through all plots in the region, checking their Start Placement Fertility and AreaID.
	for region_y = 0, iHeight - 1 do
		for region_x = 0, iWidth - 1 do
			local x = region_x + iWestX;
			local y = region_y + iSouthY;
			local plot = Map.GetPlot(x, y);
			local plotType = plot:GetPlotType()
			if plotType == PlotTypes.PLOT_HILLS or plotType == PlotTypes.PLOT_LAND then -- Land plot, process it.
				iNumLandPlots = iNumLandPlots + 1;
				local iArea = plot:GetArea();
				local plotFertility = self:MeasureStartPlacementFertilityOfPlot(x, y, false); -- Check for coastal land is disabled.
				iRegionalFertilityOfLands = iRegionalFertilityOfLands + plotFertility;
				if TestMembership(land_area_IDs, iArea) == false then -- This plot is the first detected in its AreaID.
					iNumLandAreas = iNumLandAreas + 1;
					table.insert(land_area_IDs, iArea);
					land_area_plots[iArea] = 1;
					land_area_fert[iArea] = plotFertility;
				else -- This AreaID already known.
					land_area_plots[iArea] = land_area_plots[iArea] + 1;
					land_area_fert[iArea] = land_area_fert[iArea] + plotFertility;
				end
			end
		end
	end

	-- Generate empty (non-nil) tables for each Area ID in the plot lists matrix.
	for loop, areaID in ipairs(land_area_IDs) do
		land_area_plot_lists[areaID] = {};
	end
	-- Cycle through all plots in the region again, adding candidates to the applicable AreaID plot list.
	for region_y = 0, iHeight - 1 do
		for region_x = 0, iWidth - 1 do
			local x = region_x + iWestX;
			local y = region_y + iSouthY;
			local i = y * iW + x + 1;
			local plot = Map.GetPlot(x, y);
			local plotType = plot:GetPlotType()
			if plotType == PlotTypes.PLOT_HILLS or plotType == PlotTypes.PLOT_LAND then -- Land plot, process it.
				local iArea = plot:GetArea();
				if self.plotDataIsCoastal[i] == true then
					table.insert(land_area_plot_lists[iArea], i);
				elseif bMustBeCoast == false and self.plotDataIsNextToCoast[i] == false and self.plotDataIsThreeFromCoast[i] == false then
					table.insert(land_area_plot_lists[iArea], i);
				end
			end
		end
	end
	
	local best_areas = {};
	local regionAreaListUnsorted = {};
	local regionAreaListSorted = {}; -- Have to make this a separate table, not merely a pointer to the first table.
	for areaNum, fert in pairs(land_area_fert) do
		table.insert(regionAreaListUnsorted, {areaNum, fert});
		table.insert(regionAreaListSorted, fert);
	end
	table.sort(regionAreaListSorted);
	
	-- Match each sorted fertilty value to the matching unsorted AreaID number and record in sequence.
	local iNumAreas = table.maxn(regionAreaListSorted);
	for area_order = iNumAreas, 1, -1 do -- Best areas are at the end of the list, so run the list backward.
		for loop, data_pair in ipairs(regionAreaListUnsorted) do
			local unsorted_fert = data_pair[2];
			if regionAreaListSorted[area_order] == unsorted_fert then
				local unsorted_area_num = data_pair[1];
				table.insert(best_areas, unsorted_area_num);
				-- HAVE TO remove the entry from the table in case of ties on fert value.
				table.remove(regionAreaListUnsorted, loop);
				break
			end
		end
	end

	--[[ Debug printout.
	print("-");
	print("--- Number of Candidate Plots in each landmass in Region #", region_number, " - Region Type:", region_type, " ---");
	print("-");
	for loop, iAreaID in ipairs(best_areas) do
		local fert_rating = land_area_fert[iAreaID];
		local plotCount = table.maxn(land_area_plot_lists[iAreaID]);
		print("* Area ID#", iAreaID, "has fertility rating of", fert_rating, "and candidate plot count of", plotCount); print("-");
	end
	print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
	]]--

	-- Now iterate through areas, from best fertility downward, looking for a site good enough to choose.
	for loop, iAreaID in ipairs(best_areas) do
		local plot_list = land_area_plot_lists[iAreaID];
		local election_returns = self:IterateThroughCandidatePlotList(plot_list, region_type)
		-- If any plots in this area are eligible, choose one.
		local found_eligible = election_returns[1];
		if found_eligible then
			local bestPlotScore = election_returns[2]; 
			local bestPlotIndex = election_returns[3];
			local x = (bestPlotIndex - 1) % iW;
			local y = (bestPlotIndex - x - 1) / iW;
			self.startingPlots[region_number] = {x, y, bestPlotScore};
			self:PlaceImpactAndRipples(x, y, region_number)
			return true, false
		end
		-- If none eligible, check for fallback plot.
		local found_fallback = election_returns[4];
		if found_fallback then
			local bestFallbackScore = election_returns[5];
			local bestFallbackIndex = election_returns[6];
			local x = (bestFallbackIndex - 1) % iW;
			local y = (bestFallbackIndex - x - 1) / iW;
			table.insert(fallback_plots, {x, y, bestFallbackScore});
		end
	end
	-- Reaching this point means no strong sites far enough away from any already-placed start points.

	-- We will compare all the fallback plots and choose the best to be the start plot.
	local iNumFallbacks = table.maxn(fallback_plots);
	if iNumFallbacks > 0 then
		local best_fallback_score = 0
		local best_fallback_x;
		local best_fallback_y;
		for loop, plotData in ipairs(fallback_plots) do
			local score = plotData[3];
			if score > best_fallback_score then
				best_fallback_score = score;
				best_fallback_x = plotData[1];
				best_fallback_y = plotData[2];
			end
		end
		-- Assign the start for this region.
		self.startingPlots[region_number] = {best_fallback_x, best_fallback_y, best_fallback_score};
		self:PlaceImpactAndRipples(best_fallback_x, best_fallback_y, region_number)
		bSuccessFlag = true;
	else
		-- Somehow, this region has had no eligible plots of any kind.
		-- We'll force a one tile grass island in the SW corner of the region and put the start there.
		print("WARNING: Region #", region_number, " has no eligible start plots! Forcing a start plot.")
		local forcePlot = Map.GetPlot(iWestX, iSouthY);
		bSuccessFlag = false;
		bForcedPlacementFlag = true;
		forcePlot:SetPlotType(PlotTypes.PLOT_LAND, false, true);
		forcePlot:SetTerrainType(TerrainTypes.TERRAIN_GRASS, false, true);
		forcePlot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
		self.startingPlots[region_number] = {iWestX, iSouthY, 0};
		self:PlaceImpactAndRipples(iWestX, iSouthY, region_number)
	end

	return bSuccessFlag, bForcedPlacementFlag
end
------------------------------------------------------------------------------
function AssignStartingPlots:ChooseLocations(args)
	print("Map Generation - Choosing Start Locations for Civilizations");
	local args = args or {};
	local iW, iH = Map.GetGridSize();
	local mustBeCoast = args.mustBeCoast or false; -- if true, will force all starts on salt water coast if possible
	print("Must be on coast: ", mustBeCoast);
	
	-- Defaults for evaluating potential start plots are assigned in .Create but args
	-- passed in here can override. If args value for a field is nil (no arg) then
	-- these assignments will keep the default values in place.
	self.centerBias = args.centerBias or self.centerBias; -- % of radius from region center to examine first
	self.middleBias = args.middleBias or self.middleBias; -- % of radius from region center to check second
	print(string.format("DEV/SAPHT Center bias %d, %d", self.centerBias, self.middleBias))
	self.minFoodInner = args.minFoodInner or self.minFoodInner;
	self.minProdInner = args.minProdInner or self.minProdInner;
	self.minGoodInner = args.minGoodInner or self.minGoodInner;
	self.minFoodMiddle = args.minFoodMiddle or self.minFoodMiddle;
	self.minProdMiddle = args.minProdMiddle or self.minProdMiddle;
	self.minGoodMiddle = args.minGoodMiddle or self.minGoodMiddle;
	self.minFoodOuter = args.minFoodOuter or self.minFoodOuter;
	self.minProdOuter = args.minProdOuter or self.minProdOuter;
	self.minGoodOuter = args.minGoodOuter or self.minGoodOuter;
	self.maxJunk = args.maxJunk or self.maxJunk;

	-- Measure terrain/plot/feature in regions.
	self:MeasureTerrainInRegions()
	
	-- Determine region type.
	self:DetermineRegionTypes()

	-- Set up list of regions (to be processed in this order).
	--
	-- First, make a list of all average fertility values...
	local regionAssignList = {};
	local averageFertilityListUnsorted = {};
	local averageFertilityListSorted = {}; -- Have to make this a separate table, not merely a pointer to the first table.
	for i, region_data in ipairs(self.regionData) do
		local thisRegionAvgFert = region_data[8];
		table.insert(averageFertilityListUnsorted, {i, thisRegionAvgFert});
		table.insert(averageFertilityListSorted, thisRegionAvgFert);
	end
	-- Now sort the copy low to high.
	table.sort(averageFertilityListSorted);
	-- Finally, match each sorted fertilty value to the matching unsorted region number and record in sequence.
	local iNumRegions = table.maxn(averageFertilityListSorted);
	for region_order = 1, iNumRegions do
		for loop, data_pair in ipairs(averageFertilityListUnsorted) do
			local unsorted_fert = data_pair[2];
			if averageFertilityListSorted[region_order] == unsorted_fert then
				local unsorted_reg_num = data_pair[1];
				table.insert(regionAssignList, unsorted_reg_num);
				-- HAVE TO remove the entry from the table in rare case of ties on fert 
				-- value. Or it will just match this value for a second time, then crash 
				-- when the region it was tied with ends up with nil data.
				table.remove(averageFertilityListUnsorted, loop);
				break
			end
		end
	end

	-- main loop
	-- lets check how many coastal civs are in the game and force that many regions to be coastal
	
	print("<<<<<<<<<<<<<<<<<< START OF REGION MANIPLUATION >>>>>>>>>>>>>>>>>>>>>");
	
	local iNumCoastNeeded = 0;
	local iNumRiverCivs, iNumPriorityCivs = 0, 0;
	local priority_lists = {};
	local res_reg = table.fill(false, self.iNumCivs);
	local reg_still_active = {};
	
	for loop = 1, self.iNumCivs do
		table.insert(reg_still_active, loop);
	end
	
	for loop = 1, self.iNumCivs do
		local playerNum = self.player_ID_list[loop]; -- MP games can have gaps between player numbers, so we cannot assume a sequential set of IDs.
		local player = Players[playerNum];
		local civType = GameInfo.Civilizations[player:GetCivilizationType()].Type;
		print("Player", playerNum, "of Civ Type", civType);
		local bNeedsCoastalStart = CivNeedsCoastalStart(civType);
		-- Roll for coastal start for weak bias civs
		if self.MixedBias and Map.Rand(100, "") >= 60 and CivNeedsPlaceFirstCoastalStart(civType) then
			bNeedsCoastalStart = false;
		end
		if bNeedsCoastalStart == true then
			print("- - - - - - - needs Coastal Start!"); print("-");
			iNumCoastNeeded = iNumCoastNeeded + 1;
		else
			local bNeedsRiverStart = CivNeedsRiverStart(civType)
			if bNeedsRiverStart == true then
				print("- - - - - - - needs River Start!"); print("-");
				iNumRiverCivs = iNumRiverCivs + 1;
			else
				local iNumRegionPriority = GetNumStartRegionPriorityForCiv(civType)
				if iNumRegionPriority > 0 then
					print("- - - - - - - needs Region Priority!"); print("-");
					local table_of_this_civs_priority_needs = GetStartRegionPriorityListForCiv_GetIDs(civType)
					iNumPriorityCivs = iNumPriorityCivs + 1;
					priority_lists[playerNum] = table_of_this_civs_priority_needs;
				end
			end
		end
	end
	
	for regcount = 1, iNumRegions do
		print("Region #", regcount, " Is type: ", self.regionTypes[regcount]);
	end
	
	print("-"); print("-"); print("--- REGION PRIORITY READOUT ---"); print("-");
	local iNumSinglePriority, iNumMultiPriority, iNumNeedFallbackPriority, iNumReserved = 0, 0, 0, 0;
	local single_priority, multi_priority, fallback_priority = {}, {}, {};
	local single_sorted, multi_sorted = {}, {};
	-- Separate priority civs in to two categories: single priority, multiple priority.
	for playerNum, priority_needs in pairs(priority_lists) do
		local len = table.maxn(priority_needs)
		if len == 1 then
			print("Player#", playerNum, "has a single Region Priority of type", priority_needs[1]);
			
			local found_reg = false;
			
			--loop thru all the regions and see if we can find a match
			for regcount = 1, iNumRegions do
				if self.regionTypes[regcount] == priority_needs[1] and found_reg == false then	
					-- this region matches this civ
					
					if res_reg[regcount] == false then
						print("Region match found for player #", playerNum, " Region #:", regcount);
						print("--");
						res_reg[regcount] = true;
						iNumReserved = iNumReserved + 1;
						found_reg = true;
						table.remove(reg_still_active, regcount);
					end
				end
			end
			
			-- if found_reg is still false at this point there are no regions left for this civs type, find the next best
			if found_reg == false then
				local iPriorityType = priority_needs[1];
				local choose_this_region = self:FindFallbackForUnmatchedRegionPriority(iPriorityType, reg_still_active)
				print("Fallback region found for player #", playerNum, " Region #:", choose_this_region);
				res_reg[choose_this_region] = true;
				iNumReserved = iNumReserved + 1;
				table.remove(reg_still_active, choose_this_region);
			end
		else
			print("Player#", playerNum, "has multiple Region Priority, this many types:", len);
			--local priority_data = {playerNum, len};
			--table.insert(multi_priority, priority_data)
			--iNumMultiPriority = iNumMultiPriority + 1;
		end
	end
	-- add extra coastals if balanced coast setting was chosen
	-- only supports 6 or 8 civs
	if self.BalancedCoastal then
		iRoll = Map.Rand(100, "Roll for extra coast");
		local iNumCoastStart = iNumCoastNeeded;
		if iNumRegions == 6 then
			if iNumCoastStart == 0 then
				iNumCoastNeeded = iNumCoastNeeded + (iRoll >= 20 and 1 or 0) + (iRoll >= 45 and 1 or 0) + (iRoll >= 95 and 1 or 0);
			end
			if iNumCoastStart == 1 then
				iNumCoastNeeded = iNumCoastNeeded + (iRoll >= 15 and 1 or 0) + (iRoll >= 90 and 1 or 0)
			end
			if iNumCoastStart == 2 then
				iNumCoastNeeded = iNumCoastNeeded + (iRoll >= 90 and 1 or 0)
			end
		end
		
		if iNumRegions == 8 then
			if iNumCoastStart == 0 then
				iNumCoastNeeded = iNumCoastNeeded + (iRoll >= 15 and 1 or 0) + (iRoll >= 35 and 1 or 0) + (iRoll >= 65 and 1 or 0) + (iRoll >= 85 and 1 or 0)
			end
			if iNumCoastStart == 1 then
				iNumCoastNeeded = iNumCoastNeeded + (iRoll >= 10 and 1 or 0) + (iRoll >= 55 and 1 or 0) + (iRoll >= 85 and 1 or 0)
			end
			if iNumCoastStart == 2 then
				iNumCoastNeeded = iNumCoastNeeded + (iRoll >= 35 and 1 or 0) + (iRoll >= 80 and 1 or 0)  + (iRoll >= 95 and 1 or 0)
			end
			if iNumCoastStart == 3 then
				iNumCoastNeeded = iNumCoastNeeded + (iRoll >= 60 and 1 or 0)  + (iRoll >= 90 and 1 or 0)
			end
			if iNumCoastStart == 4 then
				iNumCoastNeeded = iNumCoastNeeded + (iRoll >= 75 and 1 or 0)  + (iRoll >= 95 and 1 or 0)
			end
		end
		
		-- clear out reservations randomly
		local i = 1;
		while iNumRegions - iNumReserved > iNumCoastNeeded and i <= 100 do
		iRoll = Map.Rand(iNumRegions, "Roll region number to clear");
			if res_reg[iRoll] then
				res_reg[iRoll] = false;
				iNumReserved = iNumReserved - 1;
			end
			i = i + 1;
		end
	end
	-- now we have reserved the bias region all civ left must be coastal, so give them the remanining regions
	
	for assignIndex = 1, iNumRegions do
		local currentRegionNumber = regionAssignList[assignIndex];
		local bSuccessFlag = false;
		local bForcedPlacementFlag = false;
		
		print("Region #" .. currentRegionNumber);
		print("Num coastal still needed " .. tostring(iNumCoastNeeded));
		--print(tostring(self.startLocationConditions[currentRegionNumber][1]));

		if res_reg[currentRegionNumber] == false and iNumCoastNeeded > 0 then
			-- not already reserved, can be coastal
			bSuccessFlag, bForcedPlacementFlag = self:FindCoastalStart(currentRegionNumber)
			iNumCoastNeeded = iNumCoastNeeded - 1;
		else
			print("Don't Allow Spawning on Coast: " .. tostring(self.NoCoastInland));

			bSuccessFlag, bForcedPlacementFlag = self:FindStart(currentRegionNumber, self.NoCoastInland)
		end
		
		--Printout for debug only.
		print("- - -");
		print("Start Plot for Region #", currentRegionNumber, " was successful: ", bSuccessFlag);
		print("Start Plot for Region #", currentRegionNumber, " was forced: ", bForcedPlacementFlag);		
	end
	--

	--[[ Printout of start plots. Debug use only.
	print("-");
	print("--- Table of results, New Start Finder ---");
	for loop, startData in ipairs(self.startingPlots) do
		print("-");
		print("Region#", loop, " has start plot at: ", startData[1], startData[2], "with Fertility Rating of ", startData[3]);
	end
	print("-");
	print("--- Table of results, New Start Finder ---");
	print("-");
	]]--
	
	--[[ Printout of Impact and Ripple data.
	print("--- Impact and Ripple ---");
	PrintContentsOfTable(self.distanceData)
	print("-");  ]]--
end
------------------------------------------------------------------------------
-- Start of functions tied to BalanceAndAssign()
------------------------------------------------------------------------------
function AssignStartingPlots:AttemptToPlaceBonusResourceAtPlot(x, y, bAllowOasis, Fish_Count)
	-- Returns two booleans. First is true if something was placed. Second true if Oasis placed.
	--print("-"); print("Attempting to place a Bonus at: ", x, y);
	local plot = Map.GetPlot(x, y);
	local maxNumGranary = 4
	local maxFishPlace = Fish_Count
	if plot == nil then
		--print("Placement failed, plot was nil.");
		return false
	end
	if plot:GetResourceType(-1) ~= -1 then
		--print("Plot already had a resource.");
		return false
	end
	local terrainType = plot:GetTerrainType()
	if terrainType == TerrainTypes.TERRAIN_SNOW then
		--print("Plot was arctic land buried beneath endless snow.");
		return false
	end
	local featureType = plot:GetFeatureType()
	if featureType == FeatureTypes.FEATURE_OASIS then
		--print("Plot already had an Oasis.");
		return false
	end
	local plotType = plot:GetPlotType()
	--
	
	-- Made by EAP
	-- Note: a lot of this code doesn't do anything, yet, lot of it is for if you increase the iNumFoodBonusNeeded above 3 at the end of the iNumFoodBonusNeeded calculations
	-- Here we place possible fish
	if plotType == PlotTypes.PLOT_OCEAN then
		if maxNumGranary > 0 and maxFishPlace > 0 then
			if terrainType == TerrainTypes.TERRAIN_COAST and featureType == FeatureTypes.NO_FEATURE then
				if plot:IsLake() == false then -- Place Fish
					plot:SetResourceType(self.fish_ID, 1);
					print("Placed Fish.");
					self.amounts_of_resources_placed[self.fish_ID + 1] = self.amounts_of_resources_placed[self.fish_ID + 1] + 1;
					maxFishPlace = maxFishPlace - 1;
					return true, false, true
				end
			end
		end
	end
	if featureType == FeatureTypes.FEATURE_JUNGLE then -- Place Banana
		if maxNumGranary > 0 then
		plot:SetResourceType(self.banana_ID, 1);
		print("Placed Banana.");
		self.amounts_of_resources_placed[self.banana_ID + 1] = self.amounts_of_resources_placed[self.banana_ID + 1] + 1;
		maxNumGranary = maxNumGranary - 1;
		return true, false, false
		else
		return false
		end
	elseif featureType == FeatureTypes.FEATURE_FOREST then -- Place Deer
		if maxNumGranary > 0 then
		plot:SetResourceType(self.deer_ID, 1);
		print("Placed Deer.");
		self.amounts_of_resources_placed[self.deer_ID + 1] = self.amounts_of_resources_placed[self.deer_ID + 1] + 1; 
		maxNumGranary = maxNumGranary - 1;
		return true, false, false
		else
		return false
		end
	elseif featureType == FeatureTypes.FEATURE_FOREST and self.bModLuxes then -- Place Hardwood
		plot:SetResourceType(self.hardwood_ID, 1);
		print("Placed Hardwood.");
		self.amounts_of_resources_placed[self.hardwood_ID + 1] = self.amounts_of_resources_placed[self.hardwood_ID + 1] + 1;
		return true, false, false
	elseif plotType == PlotTypes.PLOT_HILLS and featureType == FeatureTypes.NO_FEATURE and terrainType ~= TerrainTypes.TERRAIN_DESERT then
		-- add a sheep or deer, for deer add forest first
		if maxNumGranary > 0 then
			plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
			plot:SetResourceType(self.deer_ID, 1);
			print("Placed Deer xx.");
			self.amounts_of_resources_placed[self.deer_ID + 1] = self.amounts_of_resources_placed[self.deer_ID + 1] + 1;
			maxNumGranary = maxNumGranary - 1;
			return true, false, false
		else
			return false
		end
	-- Sheep or Deer on Hills, if not desert	
	elseif plotType == PlotTypes.PLOT_HILLS and featureType == FeatureTypes.NO_FEATURE and terrainType ~= TerrainTypes.TERRAIN_DESERT and self.bModLuxes then
		plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
		plot:SetResourceType(self.hardwood_ID, 1);
		print("Placed Hardwood.");
		self.amounts_of_resources_placed[self.hardwood_ID + 1] = self.amounts_of_resources_placed[self.hardwood_ID + 1] + 1;
		return true, false, false
	elseif plotType == PlotTypes.PLOT_HILLS and featureType == FeatureTypes.NO_FEATURE and terrainType ~= TerrainTypes.TERRAIN_DESERT then
		plot:SetResourceType(self.sheep_ID, 1);
		print("Placed Sheep xx.");
		self.amounts_of_resources_placed[self.sheep_ID + 1] = self.amounts_of_resources_placed[self.sheep_ID + 1] + 1;
		return true, false, false
		
	-- Flat grassland Bison, Deer or Cow
	elseif plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE and terrainType == TerrainTypes.TERRAIN_GRASS then
		local placethis = Map.Rand(100, "");
		if placethis < 50 then
			if maxNumGranary > 0 then	
				plot:SetResourceType(self.bison_ID, 1);
				print("Placed Bison.");
				self.amounts_of_resources_placed[self.bison_ID + 1] = self.amounts_of_resources_placed[self.bison_ID + 1] + 1;
				maxNumGranary = maxNumGranary - 1;
				return true, false, false
			else
				return false
			end
		elseif placethis > 50 and placethis < 90 then
			if maxNumGranary > 0 then
				plot:SetResourceType(self.sheep_ID, 1);
				plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true); -- make it a hill
				print("Placed Sheep.");
				self.amounts_of_resources_placed[self.sheep_ID + 1] = self.amounts_of_resources_placed[self.sheep_ID + 1] + 1;
				maxNumGranary = maxNumGranary - 1;
				return true, false, false
			else
				return false
			end
		else
			if maxNumGranary > 0 then	
				plot:SetResourceType(self.stone_ID, 1);
				print("Placed Stone.");
				self.amounts_of_resources_placed[self.stone_ID + 1] = self.amounts_of_resources_placed[self.stone_ID + 1] + 1;
				maxNumGranary = maxNumGranary - 1;
				return true, false, false
			else
				return false
			end
		end
	elseif plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE and terrainType == TerrainTypes.TERRAIN_GRASS then
		local placethis = Map.Rand(100, "");
		if placethis < 67 then
			if maxNumGranary > 0 then
				plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
				plot:SetResourceType(self.deer_ID, 1);
				print("Placed Deer xx.");
				self.amounts_of_resources_placed[self.deer_ID + 1] = self.amounts_of_resources_placed[self.deer_ID + 1] + 1;
				maxNumGranary = maxNumGranary - 1;
				return true, false, false
			else
				return false
			end
		else
			if maxNumGranary > 0 then
				plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
				plot:SetResourceType(self.deer_ID, 1);
				plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true); -- make it a hill
				print("Placed Deer xx.");
				self.amounts_of_resources_placed[self.deer_ID + 1] = self.amounts_of_resources_placed[self.deer_ID + 1] + 1;
				maxNumGranary = maxNumGranary - 1;
				return true, false, false
			else
				return false
			end
		end
	elseif plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE and terrainType == TerrainTypes.TERRAIN_GRASS then
			plot:SetResourceType(self.cow_ID, 1);
			print("Placed Cow.");
			self.amounts_of_resources_placed[self.cow_ID + 1] = self.amounts_of_resources_placed[self.cow_ID + 1] + 1;
		return true, false, false
	
	-- Wheat, Bison, Cow or Hardwood on Flat plains
	elseif plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE and terrainType == TerrainTypes.TERRAIN_PLAINS then
		local placethis = Map.Rand(100, "");
		if placethis < 75 then
			if maxNumGranary > 0 then
				plot:SetResourceType(self.wheat_ID, 1);
				print("Placed Wheat.");
				self.amounts_of_resources_placed[self.wheat_ID + 1] = self.amounts_of_resources_placed[self.wheat_ID + 1] + 1;
				maxNumGranary = maxNumGranary - 1;
				return true, false, false
			else
				return false
			end
		else
			if maxNumGranary > 0 then
				plot:SetResourceType(self.bison_ID, 1);
				print("Placed Bison.");
				self.amounts_of_resources_placed[self.bison_ID + 1] = self.amounts_of_resources_placed[self.bison_ID + 1] + 1;
				maxNumGranary = maxNumGranary - 1;
				return true, false, false
			else
				return false
			end
		end
	elseif plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE and terrainType == TerrainTypes.TERRAIN_PLAINS then
		if maxNumGranary > 0 then
			plot:SetResourceType(self.bison_ID, 1);
			print("Placed Bison.");
			self.amounts_of_resources_placed[self.bison_ID + 1] = self.amounts_of_resources_placed[self.bison_ID + 1] + 1;
			maxNumGranary = maxNumGranary - 1;
			return true, false, false
		else
			return false
		end
	-- Place Wheat on Floodplains
	elseif terrainType == TerrainTypes.TERRAIN_DESERT and plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
		-- Place Wheat
		local placethis = Map.Rand(100, "");
		if placethis < 25 then
			plot:SetResourceType(self.wheat_ID, 1);
			print("Placed Wheat.");
			self.amounts_of_resources_placed[self.wheat_ID + 1] = self.amounts_of_resources_placed[self.wheat_ID + 1] + 1;
			return true, false, false
		elseif placethis > 25 and placethis < 75 then
			plot:SetResourceType(self.sheep_ID, 1);
			plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true); -- make it a hill
			plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			print("Placed Sheep.");
			self.amounts_of_resources_placed[self.sheep_ID + 1] = self.amounts_of_resources_placed[self.sheep_ID + 1] + 1;
			maxNumGranary = maxNumGranary - 1;
			return true, false, false
		else
			if maxNumGranary > 0 then	-- we do actually want a limit on stone placed
				plot:SetResourceType(self.stone_ID, 1);
				print("Placed Stone.");
				self.amounts_of_resources_placed[self.stone_ID + 1] = self.amounts_of_resources_placed[self.stone_ID + 1] + 1;
				maxNumGranary = maxNumGranary - 1;
				return true, false, false
			else
				return false
			end
		end
		
		
	elseif plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE and terrainType == TerrainTypes.TERRAIN_PLAINS then
		plot:SetResourceType(self.cow_ID, 1);
		print("Placed Cow.");
		self.amounts_of_resources_placed[self.cow_ID + 1] = self.amounts_of_resources_placed[self.cow_ID + 1] + 1;
		return true, false, false
	elseif plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE and terrainType == TerrainTypes.TERRAIN_PLAINS and self.bModLuxes then
		plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
		plot:SetResourceType(self.hardwood_ID, 1);
		print("Placed Hardwood.");
		self.amounts_of_resources_placed[self.hardwood_ID + 1] = self.amounts_of_resources_placed[self.hardwood_ID + 1] + 1;
		return true, false, false
		
	-- Tundra support, does not include granary limit since tundra bad (for now)
	elseif terrainType == TerrainTypes.TERRAIN_TUNDRA and plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE then -- Place Deer
					--add forest to the location to make it even better
					plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
					plot:SetResourceType(self.deer_ID, 1);
					print("Placed Deer.");
					self.amounts_of_resources_placed[self.deer_ID + 1] = self.amounts_of_resources_placed[self.deer_ID + 1] + 1;
					return true, false, false
	elseif terrainType == TerrainTypes.TERRAIN_TUNDRA and plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE and self.bModLuxes then -- Place Hardwood
					--add forest to the location to make it even better
					plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
					plot:SetResourceType(self.hardwood_ID, 1);
					print("Placed Hardwood.");
					self.amounts_of_resources_placed[self.hardwood_ID + 1] = self.amounts_of_resources_placed[self.hardwood_ID + 1] + 1;
					return true, false, false
	-- Place Wheat on Desert
	elseif terrainType == TerrainTypes.TERRAIN_DESERT and plotType == PlotTypes.PLOT_LAND and featureType == FeatureTypes.NO_FEATURE then 
		if plot:IsFreshWater() then
			-- Place Wheat
			plot:SetResourceType(self.wheat_ID, 1);
			print("Placed Wheat.");
			self.amounts_of_resources_placed[self.wheat_ID + 1] = self.amounts_of_resources_placed[self.wheat_ID + 1] + 1;
			return true, false, false
		elseif bAllowOasis then -- Place Oasis
					plot:SetFeatureType(FeatureTypes.FEATURE_OASIS, -1);
					print("Placed Oasis.");
					return true, true, false
		else
					print("Not allowed to place any more Oasis help at this site.");
		end
	end
	
	-- Nothing placed.
	return false, false, false
end
------------------------------------------------------------------------------
function AssignStartingPlots:AttemptToPlaceHillsAtPlot(x, y)
	-- This function will add hills at a specified plot, if able.
	--print("-"); print("Attempting to add Hills at: ", x, y);
	local plot = Map.GetPlot(x, y);
	if plot == nil then
		--print("Placement failed, plot was nil.");
		return false
	end
	if plot:GetResourceType(-1) ~= -1 then
		--print("Placement failed, plot had a resource.");
		return false
	end
	local plotType = plot:GetPlotType()
	local featureType = plot:GetFeatureType();
	if plotType == PlotTypes.PLOT_OCEAN then
		--print("Placement failed, plot was water.");
		return false
	elseif plot:IsRiverSide() then
		--print("Placement failed, plot was next to river.");
		return false
	elseif featureType == FeatureTypes.FEATURE_FOREST then
		--print("Placement failed, plot had a forest already.");
		return false
	end	
	-- Change the plot type from flatlands to hills and clear any features.
	plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
	plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
	return true
end
------------------------------------------------------------------------------
function AssignStartingPlots:AttemptToPlaceSmallStrategicAtPlot(x, y)
	-- This function will add a small horse or iron source to a specified plot, if able.
	--print("-"); print("Attempting to add Small Strategic resource at: ", x, y);
	local plot = Map.GetPlot(x, y);
	if plot == nil then
		--print("Placement failed, plot was nil.");
		return false
	end
	if plot:GetResourceType(-1) ~= -1 then
		--print("Plot already had a resource.");
		return false
	end
	local plotType = plot:GetPlotType()
	local terrainType = plot:GetTerrainType()
	local featureType = plot:GetFeatureType()
	if plotType ~= PlotTypes.PLOT_LAND then
		--print("Placement failed, plot was not flat land.");
		return false
	elseif featureType == FeatureTypes.NO_FEATURE then
		if terrainType == TerrainTypes.TERRAIN_GRASS or terrainType == TerrainTypes.TERRAIN_PLAINS then -- Could be horses.
			local choice = self.horse_ID;
			local diceroll = Map.Rand(5, "Selection of Strategic Resource type - Start Normalization LUA");
			if diceroll > 3 then
				choice = self.iron_ID;
				--print("Placed Iron.");
			else
				--print("Placed Horse.");
			end
			plot:SetResourceType(choice, 2);
			self.amounts_of_resources_placed[choice + 1] = self.amounts_of_resources_placed[choice + 1] + 2;
		else -- Can't be horses.
			plot:SetResourceType(self.iron_ID, 2);
			self.amounts_of_resources_placed[self.iron_ID + 1] = self.amounts_of_resources_placed[self.iron_ID + 1] + 2;
			--print("Placed Iron.");
		end
		return true
	end
	--print("Placement failed, feature in the way.");
	return false
end
------------------------------------------------------------------------------
function AssignStartingPlots:AddStrategicBalanceResources(region_number)
	-- This function adds the required Strategic Resources to start plots, for
	-- games that have selected to enable Strategic Resource Balance.
	local iW, iH = Map.GetGridSize();
	local start_point_data = self.startingPlots[region_number];
	local x = start_point_data[1];
	local y = start_point_data[2];
	local plot = Map.GetPlot(x, y);
	local plotIndex = y * iW + x + 1;
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local odd = self.firstRingYIsOdd;
	local even = self.firstRingYIsEven;
	local nextX, nextY, plot_adjustments;
	local iron_list, horse_list, oil_list, alum_list, coal_list, uran_list = {}, {}, {}, {}, {}, {};
	local iron_fallback, horse_fallback, oil_fallback, alum_fallback, coal_fallback, uran_fallback = {}, {}, {}, {}, {}, {};
	local radius = 3;
	local OilToPlace = 2;
	
	--print("- Adding Strategic Balance Resources for start location in Region#", region_number);
	
	for ripple_radius = 1, radius do
		local ripple_value = radius - ripple_radius + 1;
		local currentX = x - ripple_radius;
		local currentY = y;
		for direction_index = 1, 6 do
			for plot_to_handle = 1, ripple_radius do
			 	if currentY / 2 > math.floor(currentY / 2) then
					plot_adjustments = odd[direction_index];
				else
					plot_adjustments = even[direction_index];
				end
				nextX = currentX + plot_adjustments[1];
				nextY = currentY + plot_adjustments[2];
				if wrapX == false and (nextX < 0 or nextX >= iW) then
					-- X is out of bounds.
				elseif wrapY == false and (nextY < 0 or nextY >= iH) then
					-- Y is out of bounds.
				else
					local realX = nextX;
					local realY = nextY;
					if wrapX then
						realX = realX % iW;
					end
					if wrapY then
						realY = realY % iH;
					end
					-- We've arrived at the correct x and y for the current plot.
					local plot = Map.GetPlot(realX, realY);
					local plotType = plot:GetPlotType()
					local terrainType = plot:GetTerrainType()
					local featureType = plot:GetFeatureType()
					local plotIndex = realY * iW + realX + 1;
					-- Check this plot for resource placement eligibility.
					if plotType == PlotTypes.PLOT_HILLS then
						if ripple_radius < 3 then
							table.insert(iron_list, plotIndex)

						else
							table.insert(iron_fallback, plotIndex)

						end
						if terrainType ~= TerrainTypes.TERRAIN_SNOW and featureType == FeatureTypes.NO_FEATURE then
							table.insert(horse_fallback, plotIndex)
						end
					elseif plotType == PlotTypes.PLOT_LAND then
						if featureType == FeatureTypes.NO_FEATURE then
							if terrainType == TerrainTypes.TERRAIN_TUNDRA or terrainType == TerrainTypes.TERRAIN_DESERT then
								if ripple_radius < 3 then
									table.insert(oil_list, plotIndex)
								else
									table.insert(oil_fallback, plotIndex)
								end
								table.insert(iron_fallback, plotIndex)
								table.insert(horse_fallback, plotIndex)
							elseif terrainType == TerrainTypes.TERRAIN_PLAINS or terrainType == TerrainTypes.TERRAIN_GRASS then
								if ripple_radius < 3 then
									table.insert(horse_list, plotIndex)
								else
									table.insert(horse_fallback, plotIndex)
								end
								table.insert(iron_fallback, plotIndex)
								table.insert(oil_fallback, plotIndex)
							elseif terrainType == TerrainTypes.TERRAIN_SNOW then
								if ripple_radius < 3 then
									table.insert(oil_list, plotIndex)
								else
									table.insert(oil_fallback, plotIndex)
								end
							end
						elseif featureType == FeatureTypes.FEATURE_MARSH then		
							if ripple_radius < 3 then
								table.insert(oil_list, plotIndex)
							else
								table.insert(oil_fallback, plotIndex)
							end
							table.insert(iron_fallback, plotIndex)
						elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then		
							table.insert(horse_fallback, plotIndex)
							table.insert(oil_fallback, plotIndex)
						elseif featureType == FeatureTypes.FEATURE_JUNGLE or featureType == FeatureTypes.FEATURE_FOREST then		
							table.insert(iron_fallback, plotIndex)
							table.insert(oil_fallback, plotIndex)
						end
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	end


	local radius = 4;
	for ripple_radius = 1, radius do
		local ripple_value = radius - ripple_radius + 1;
		local currentX = x - ripple_radius;
		local currentY = y;
		for direction_index = 1, 6 do
			for plot_to_handle = 1, ripple_radius do
			 	if currentY / 2 > math.floor(currentY / 2) then
					plot_adjustments = odd[direction_index];
				else
					plot_adjustments = even[direction_index];
				end
				nextX = currentX + plot_adjustments[1];
				nextY = currentY + plot_adjustments[2];
				if wrapX == false and (nextX < 0 or nextX >= iW) then
					-- X is out of bounds.
				elseif wrapY == false and (nextY < 0 or nextY >= iH) then
					-- Y is out of bounds.
				else
					local realX = nextX;
					local realY = nextY;
					if wrapX then
						realX = realX % iW;
					end
					if wrapY then
						realY = realY % iH;
					end
					-- We've arrived at the correct x and y for the current plot.
					local plot = Map.GetPlot(realX, realY);
					local plotType = plot:GetPlotType()
					local terrainType = plot:GetTerrainType()
					local featureType = plot:GetFeatureType()
					local plotIndex = realY * iW + realX + 1;
					-- Check this plot for resource placement eligibility.
					if plotType == PlotTypes.PLOT_HILLS then
						if ripple_radius < 4 then
							table.insert(alum_list, plotIndex)
							table.insert(coal_list, plotIndex)
						else
							table.insert(alum_fallback, plotIndex)
							table.insert(coal_fallback, plotIndex)
						end
						if terrainType ~= TerrainTypes.TERRAIN_SNOW and featureType == FeatureTypes.NO_FEATURE then
							table.insert(horse_fallback, plotIndex)
						end
					elseif plotType == PlotTypes.PLOT_LAND then
						if featureType == FeatureTypes.NO_FEATURE then
							if terrainType == TerrainTypes.TERRAIN_TUNDRA or terrainType == TerrainTypes.TERRAIN_DESERT then
								if ripple_radius < 4 then
									table.insert(coal_list, plotIndex)
									table.insert(alum_list, plotIndex)
									table.insert(oil_fallback, plotIndex)
								else
									table.insert(coal_fallback, plotIndex)
									table.insert(alum_fallback, plotIndex)
								end
							elseif terrainType == TerrainTypes.TERRAIN_PLAINS or terrainType == TerrainTypes.TERRAIN_GRASS then
								if ripple_radius < 4 then
									table.insert(coal_list, plotIndex)
									table.insert(alum_list, plotIndex)
									table.insert(oil_fallback, plotIndex)
								else
									table.insert(alum_fallback, plotIndex)
									table.insert(coal_fallback, plotIndex)
								end
							elseif terrainType == TerrainTypes.TERRAIN_SNOW then
								if ripple_radius < 4 then
									table.insert(coal_list, plotIndex)
									table.insert(alum_list, plotIndex)
									table.insert(oil_fallback, plotIndex)
								else
									table.insert(alum_fallback, plotIndex)
									table.insert(coal_fallback, plotIndex)
								end
							end
						elseif featureType == FeatureTypes.FEATURE_MARSH then		
							if ripple_radius < 4 then
								table.insert(coal_list, plotIndex)
								table.insert(alum_list, plotIndex)
								table.insert(oil_fallback, plotIndex)
							else
								table.insert(alum_fallback, plotIndex)
								table.insert(coal_fallback, plotIndex)
							end
						elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then		
							table.insert(alum_fallback, plotIndex)
							table.insert(coal_fallback, plotIndex)
						elseif featureType == FeatureTypes.FEATURE_JUNGLE or featureType == FeatureTypes.FEATURE_FOREST then		
							table.insert(alum_fallback, plotIndex)
							table.insert(coal_fallback, plotIndex)
							table.insert(oil_fallback, plotIndex)
						end
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	end

	local radius = 6;
	for ripple_radius = 4, radius do
		local ripple_value = radius - ripple_radius + 1;
		local currentX = x - ripple_radius;
		local currentY = y;
		for direction_index = 1, 6 do
			for plot_to_handle = 1, ripple_radius do
			 	if currentY / 2 > math.floor(currentY / 2) then
					plot_adjustments = odd[direction_index];
				else
					plot_adjustments = even[direction_index];
				end
				nextX = currentX + plot_adjustments[1];
				nextY = currentY + plot_adjustments[2];
				if wrapX == false and (nextX < 0 or nextX >= iW) then
					-- X is out of bounds.
				elseif wrapY == false and (nextY < 0 or nextY >= iH) then
					-- Y is out of bounds.
				else
					local realX = nextX;
					local realY = nextY;
					if wrapX then
						realX = realX % iW;
					end
					if wrapY then
						realY = realY % iH;
					end
					-- We've arrived at the correct x and y for the current plot.
					local plot = Map.GetPlot(realX, realY);
					local plotType = plot:GetPlotType()
					local terrainType = plot:GetTerrainType()
					local featureType = plot:GetFeatureType()
					local plotIndex = realY * iW + realX + 1;
					-- Check this plot for resource placement eligibility.
					if plotType == PlotTypes.PLOT_LAND then
						if featureType ~= FeatureTypes.FEATURE_FLOOD_PLAINS then
							if featureType ~= FeatureTypes.FEATURE_OASIS then
								if terrainType == TerrainTypes.TERRAIN_TUNDRA or terrainType == TerrainTypes.TERRAIN_DESERT or terrainType == TerrainTypes.TERRAIN_PLAINS or terrainType == TerrainTypes.TERRAIN_GRASS or terrainType == TerrainTypes.TERRAIN_SNOW then
									table.insert(uran_list, plotIndex)
									table.insert(uran_fallback, plotIndex)
								end
							end
						end
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	end

	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = self:GetMajorStrategicResourceQuantityValues()
	local shuf_list;
	local placed_iron, placed_horse, placed_oil, placed_alum, placed_coal, placed_uran = false, false, false, false, false, false;

	uran_amt = 1;

	if table.maxn(iron_list) > 0 then
		shuf_list = GetShuffledCopyOfTable(iron_list)
		iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.iron_ID, iron_amt, 1, 1, -1, 0, 0, shuf_list);
		if iNumLeftToPlace == 0 then
			placed_iron = true;
		end
	end
	if table.maxn(horse_list) > 0 then
		shuf_list = GetShuffledCopyOfTable(horse_list)
		iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.horse_ID, horse_amt, 1, 1, -1, 0, 0, shuf_list);
		if iNumLeftToPlace == 0 then
			placed_horse = true;
		end
	end
	if table.maxn(oil_list) > 0 then
		shuf_list = GetShuffledCopyOfTable(oil_list)
		iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.oil_ID, oil_amt, 2, 1, -1, 0, 0, shuf_list);
		if iNumLeftToPlace == 0 then
			print("All Oil Placed First Attempt");
			placed_oil = true;
			OilToPlace = 0;
		else
			OilToPlace = 1;
		end
	end
	
	if self.start_locations == 5 or self.start_locations == 6 or self.start_locations == 1 or self.start_locations == 2 then
		if table.maxn(alum_list) > 0 then
			shuf_list = GetShuffledCopyOfTable(alum_list)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.aluminum_ID, alum_amt, 1, 1, 1, 0, 0, shuf_list);
			if iNumLeftToPlace == 0 then
				placed_alum = true;
			end
		end
	end
	
	if self.start_locations == 4 or self.start_locations == 6 or self.start_locations == 1  or self.start_locations == 2 then
		if table.maxn(coal_list) > 0 then
			shuf_list = GetShuffledCopyOfTable(coal_list)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.coal_ID, coal_amt, 1, 1, 1, 0, 0, shuf_list);
			if iNumLeftToPlace == 0 then
				placed_coal = true;
			end
		end
	end

	if self.start_locations == 2 then
		if table.maxn(uran_list) > 0 then
			shuf_list = GetShuffledCopyOfTable(uran_list)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.uranium_ID, uran_amt, 2, 1, 1, 0, 0, shuf_list);
			if iNumLeftToPlace == 0 then
				placed_uran = true;
			end
		end
	end



	if placed_iron == false and table.maxn(iron_fallback) > 0 then
		shuf_list = GetShuffledCopyOfTable(iron_fallback)
		iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.iron_ID, iron_amt, 1, 1, -1, 0, 0, shuf_list);
	end
	if placed_horse == false and table.maxn(horse_fallback) > 0 then
		shuf_list = GetShuffledCopyOfTable(horse_fallback)
		iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.horse_ID, horse_amt, 1, 1, -1, 0, 0, shuf_list);
	end
	if placed_oil == false and table.maxn(oil_fallback) > 0 then
		shuf_list = GetShuffledCopyOfTable(oil_fallback)
		if OilToPlace == 1 then
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.oil_ID, oil_amt, 1, 1, -1, 0, 0, shuf_list);
		else
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.oil_ID, oil_amt, 2, 1, -1, 0, 0, shuf_list);
		end
		print("Fallback Used");
		if iNumLeftToPlace == 0 then
			print("All Oil Placed 2nd Attempt");
		else
			--print("Not All Oil Placed");
		end
	end
	if self.start_locations == 5 or self.start_locations == 6 or self.start_locations == 1 or self.start_locations == 2 then
		if placed_alum == false and table.maxn(alum_fallback) > 0 then
			shuf_list = GetShuffledCopyOfTable(horse_fallback)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.aluminum_ID, alum_amt, 1, 1, 1, 0, 0, shuf_list);
		end
	end
	if self.start_locations == 4 or self.start_locations == 6 or self.start_locations == 1 or self.start_locations == 2 then
		if placed_coal == false and table.maxn(coal_fallback) > 0 then
			shuf_list = GetShuffledCopyOfTable(coal_fallback)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.coal_ID, coal_amt, 1, 1, 1, 0, 0, shuf_list);
		end
	end
	if self.start_locations == 2 then
		if placed_uran == false and table.maxn(uran_fallback) > 0 then
			shuf_list = GetShuffledCopyOfTable(uran_fallback)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.uranium_ID, uran_amt, 2, 1, 1, 0, 0, shuf_list);
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:AttemptToPlaceStoneAtGrassPlot(x, y)
	-- Function modified May 2011 to boost production at heavy grass starts. - BT
	-- Now placing Stone instead of Cows. Returns true if Stone is placed.
	--print("-"); print("Attempting to place Stone at: ", x, y);
	local plot = Map.GetPlot(x, y);
	if plot == nil then
		--print("Placement failed, plot was nil.");
		return false
	end
	if plot:GetResourceType(-1) ~= -1 then
		--print("Plot already had a resource.");
		return false
	end
	local plotType = plot:GetPlotType()
	if plotType == PlotTypes.PLOT_LAND then
		local featureType = plot:GetFeatureType()
		if featureType == FeatureTypes.NO_FEATURE then
			local terrainType = plot:GetTerrainType()
			if terrainType == TerrainTypes.TERRAIN_GRASS then -- Place Stone
				plot:SetResourceType(self.stone_ID, 1);
				--print("Placed Stone.");
				self.amounts_of_resources_placed[self.stone_ID + 1] = self.amounts_of_resources_placed[self.stone_ID + 1] + 1;
				return true
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:NormalizeStartLocation(region_number)
	--[[ This function measures the value of land in two rings around a given start
	     location, primarily for the purpose of determining how much support the site
	     requires in the form of Bonus Resources. Numerous assumptions are built in 
	     to this operation that would need to be adjusted for any modifications to 
	     terrain or resources types and yields, or to game rules about rivers and 
	     other map elements. Nothing is hardcoded in a way that puts it out of the 
	     reach of modders, but any mods including changes to map elements may have a
	     significant workload involved with rebalancing the start finder and the 
	     resource distribution to fit them properly to a mod's custom needs. I have
	     labored to document every function and method in detail to make it as easy
	     as possible to modify this system.  -- Bob Thomas - April 15, 2010  ]]--
	-- 
	print("-------------------------------- NormalizeStartLocation started -------------------------------- ")
	local iW, iH = Map.GetGridSize();
	local start_point_data = self.startingPlots[region_number];
	local x = start_point_data[1];
	local y = start_point_data[2];
	local plot = Map.GetPlot(x, y);
	local plotIndex = y * iW + x + 1;
	local isEvenY = true;
	if y / 2 > math.floor(y / 2) then
		isEvenY = false;
	end
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local innerFourFood, innerThreeFood, innerTwoFood, innerHills, innerForest, innerOneHammer, innerOcean = 0, 0, 0, 0, 0, 0, 0;
	local outerFourFood, outerThreeFood, outerTwoFood, outerHills, outerForest, outerOneHammer, outerOcean = 0, 0, 0, 0, 0, 0, 0;
	local innerCanHaveBonus, outerCanHaveBonus, innerBadTiles, outerBadTiles = 0, 0, 0, 0;
	local iNumFoodBonusNeeded = 0;
	local iNumNativeTwoFoodFirstRing, iNumNativeTwoFoodSecondRing = 0, 0; -- Cities must begin the game with at least three native 2F tiles, one in first ring.
	local search_table = {};
	
	-- Remove any feature Ice from the first ring.
	--self:GenerateLuxuryPlotListsAtCitySite(x, y, 1, true)
	
	print("%%%%%%%%%%%%%%%% PLOT EVALUATION %%%%%%%%%%%%%%%%");
	print("Evaluation for region: ", region_number, "At Location: ", x, y);
	
	-- Set up Conditions checks.
	local alongOcean = false;
	local nextToLake = false;
	local isRiver = false;
	local nearRiver = false;
	local nearMountain = false;
	local forestCount, jungleCount = 0, 0;

	-- Check start plot to see if it's adjacent to saltwater.
	if self.plotDataIsCoastal[plotIndex] == true then
		alongOcean = true;
	end
	
	-- Check start plot to see if it's on a river.
	if plot:IsRiver() then
		isRiver = true;
	end

	-- Data Chart for early game tile potentials
	--
	-- 4F:	Flood Plains, Grass on fresh water (includes forest and marsh).
	-- 3F:	Dry Grass, Plains on fresh water (includes forest and jungle), Tundra on fresh water (includes forest), Oasis
	-- 2F:  Dry Plains, Lake, all remaining Jungles.
	--
	-- 1H:	Plains, Jungle on Plains

	-- Adding evaluation of grassland and plains for balance boost of bonus Cows for heavy grass starts. - 26/1/2011 BT
	local iNumGrass, iNumPlains = 0, 0;

	-- Evaluate First Ring
	if isEvenY then
		search_table = self.firstRingYIsEven;
	else
		search_table = self.firstRingYIsOdd;
	end

	for loop, plot_adjustments in ipairs(search_table) do
		local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
		--
		if searchX < 0 or searchX >= iW or searchY < 0 or searchY >= iH then
			-- This plot does not exist. It's off the map edge.
			innerBadTiles = innerBadTiles + 1;
		else
			local searchPlot = Map.GetPlot(searchX, searchY)
			local plotType = searchPlot:GetPlotType()
			local terrainType = searchPlot:GetTerrainType()
			local featureType = searchPlot:GetFeatureType()
			--
			if plotType == PlotTypes.PLOT_MOUNTAIN then
				local nearMountain = true;
				innerBadTiles = innerBadTiles + 1;
			elseif plotType == PlotTypes.PLOT_OCEAN then
				if searchPlot:IsLake() then
					nextToLake = true;
					if featureType == FeatureTypes.FEATURE_ICE then
						innerBadTiles = innerBadTiles + 1;
					else
						innerTwoFood = innerTwoFood + 1;
						iNumNativeTwoFoodFirstRing = iNumNativeTwoFoodFirstRing + 1;
					end
				else
					if featureType == FeatureTypes.FEATURE_ICE then
						innerBadTiles = innerBadTiles + 1;
					else
						innerOcean = innerOcean + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
					end
				end
			else -- Habitable plot.
				if featureType == FeatureTypes.FEATURE_JUNGLE then
					jungleCount = jungleCount + 1;
					iNumNativeTwoFoodFirstRing = iNumNativeTwoFoodFirstRing + 1;
				elseif featureType == FeatureTypes.FEATURE_FOREST then
					forestCount = forestCount + 1;
				end
				if searchPlot:IsRiver() then
					nearRiver = true;
				end
				if plotType == PlotTypes.PLOT_HILLS then
					innerHills = innerHills + 1;
					if featureType == FeatureTypes.FEATURE_JUNGLE then
						innerTwoFood = innerTwoFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
					elseif featureType == FeatureTypes.FEATURE_FOREST then
						innerCanHaveBonus = innerCanHaveBonus + 1;
					elseif terrainType == TerrainTypes.TERRAIN_GRASS then
						iNumGrass = iNumGrass + 1;
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						iNumPlains = iNumPlains + 1;
					end
				elseif featureType == FeatureTypes.FEATURE_OASIS then
					innerThreeFood = innerThreeFood + 1;
					iNumNativeTwoFoodFirstRing = iNumNativeTwoFoodFirstRing + 1;
				elseif searchPlot:IsFreshWater() then
					if terrainType == TerrainTypes.TERRAIN_GRASS then
						innerFourFood = innerFourFood + 1;
						iNumGrass = iNumGrass + 1;
						if featureType ~= FeatureTypes.FEATURE_MARSH then
							--innerTwoFood = innerTwoFood + 1;
							innerCanHaveBonus = innerCanHaveBonus + 1;
						end
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						end
						if featureType == FeatureTypes.NO_FEATURE then
							iNumNativeTwoFoodFirstRing = iNumNativeTwoFoodFirstRing + 1;
						end
					elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
						innerThreeFood = innerThreeFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
						iNumNativeTwoFoodFirstRing = iNumNativeTwoFoodFirstRing + 1;
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						innerThreeFood = innerThreeFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
						iNumPlains = iNumPlains + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						else
							innerOneHammer = innerOneHammer + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
						--innerThreeFood = innerThreeFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_DESERT then
						innerBadTiles = innerBadTiles + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1; -- Can have Oasis.
					else -- Snow
						innerBadTiles = innerBadTiles + 1;
					end
				else -- Dry Flatlands
					if terrainType == TerrainTypes.TERRAIN_GRASS then
						innerThreeFood = innerThreeFood + 1;
						iNumGrass = iNumGrass + 1;
						if featureType ~= FeatureTypes.FEATURE_MARSH then
							--innerTwoFood = innerTwoFood + 1;
							innerCanHaveBonus = innerCanHaveBonus + 1;
						end
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						end
						if featureType == FeatureTypes.NO_FEATURE then
							iNumNativeTwoFoodFirstRing = iNumNativeTwoFoodFirstRing + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						innerTwoFood = innerTwoFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
						iNumPlains = iNumPlains + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						else
							innerOneHammer = innerOneHammer + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
						innerCanHaveBonus = innerCanHaveBonus + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						else
							innerBadTiles = innerBadTiles + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_DESERT then
						innerBadTiles = innerBadTiles + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1; -- Can have Oasis.
					else -- Snow
						innerBadTiles = innerBadTiles + 1;
					end
				end
			end
		end
	end
				
	-- Evaluate Second Ring
	if isEvenY then
		search_table = self.secondRingYIsEven;
	else
		search_table = self.secondRingYIsOdd;
	end

	for loop, plot_adjustments in ipairs(search_table) do
		local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
		local plot = Map.GetPlot(x, y);
		--
		--
		if searchX < 0 or searchX >= iW or searchY < 0 or searchY >= iH then
			-- This plot does not exist. It's off the map edge.
			outerBadTiles = outerBadTiles + 1;
		else
			local searchPlot = Map.GetPlot(searchX, searchY)
			local plotType = searchPlot:GetPlotType()
			local terrainType = searchPlot:GetTerrainType()
			local featureType = searchPlot:GetFeatureType()
			--
			if plotType == PlotTypes.PLOT_MOUNTAIN then
				local nearMountain = true;
				outerBadTiles = outerBadTiles + 1;
			elseif plotType == PlotTypes.PLOT_OCEAN then
				if searchPlot:IsLake() then
					if featureType == FeatureTypes.FEATURE_ICE then
						outerBadTiles = outerBadTiles + 1;
					else
						outerTwoFood = outerTwoFood + 1;
						iNumNativeTwoFoodSecondRing = iNumNativeTwoFoodSecondRing + 1;
					end
				else
					if featureType == FeatureTypes.FEATURE_ICE then
						outerBadTiles = outerBadTiles + 1;
					elseif terrainType == TerrainTypes.TERRAIN_COAST then
						outerCanHaveBonus = outerCanHaveBonus + 1;
						outerOcean = outerOcean + 1;
					end
				end
			else -- Habitable plot.
				if featureType == FeatureTypes.FEATURE_JUNGLE then
					jungleCount = jungleCount + 1;
					iNumNativeTwoFoodSecondRing = iNumNativeTwoFoodSecondRing + 1;
				elseif featureType == FeatureTypes.FEATURE_FOREST then
					forestCount = forestCount + 1;
				end
				if searchPlot:IsRiver() then
					nearRiver = true;
				end
				if plotType == PlotTypes.PLOT_HILLS then
					outerHills = outerHills + 1;
					if featureType == FeatureTypes.FEATURE_JUNGLE then
						outerTwoFood = outerTwoFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
					elseif featureType == FeatureTypes.FEATURE_FOREST then
						outerCanHaveBonus = outerCanHaveBonus + 1;
					elseif terrainType == TerrainTypes.TERRAIN_GRASS then
						iNumGrass = iNumGrass + 1;
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						iNumPlains = iNumPlains + 1;
					end
				elseif featureType == FeatureTypes.FEATURE_OASIS then
					innerThreeFood = innerThreeFood + 1;
					iNumNativeTwoFoodSecondRing = iNumNativeTwoFoodSecondRing + 1;
				elseif searchPlot:IsFreshWater() then
					if terrainType == TerrainTypes.TERRAIN_GRASS then
						outerFourFood = outerFourFood + 1;
						iNumGrass = iNumGrass + 1;
						if featureType ~= FeatureTypes.FEATURE_MARSH then
							--outerTwoFood = outerTwoFood + 1;
							outerCanHaveBonus = outerCanHaveBonus + 1;
						end
						if featureType == FeatureTypes.FEATURE_FOREST then
							outerForest = outerForest + 1;
						end
						if featureType == FeatureTypes.NO_FEATURE then
							iNumNativeTwoFoodSecondRing = iNumNativeTwoFoodSecondRing + 1;
						end
					elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
						outerThreeFood = outerThreeFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
						iNumNativeTwoFoodSecondRing = iNumNativeTwoFoodSecondRing + 1;
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						outerThreeFood = outerThreeFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
						iNumPlains = iNumPlains + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							outerForest = outerForest + 1;
						else
							outerOneHammer = outerOneHammer + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
						--outerThreeFood = outerThreeFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							outerForest = outerForest + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_DESERT then
						outerBadTiles = outerBadTiles + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1; -- Can have Oasis.
					else -- Snow
						outerBadTiles = outerBadTiles + 1;
					end
				else -- Dry Flatlands
					if terrainType == TerrainTypes.TERRAIN_GRASS then
						outerThreeFood = outerThreeFood + 1;
						iNumGrass = iNumGrass + 1;
						if featureType ~= FeatureTypes.FEATURE_MARSH then
							--outerTwoFood = outerTwoFood + 1;
							outerCanHaveBonus = outerCanHaveBonus + 1;
						end
						if featureType == FeatureTypes.FEATURE_FOREST then
							outerForest = outerForest + 1;
						end
						if featureType == FeatureTypes.NO_FEATURE then
							iNumNativeTwoFoodSecondRing = iNumNativeTwoFoodSecondRing + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						outerTwoFood = outerTwoFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
						iNumPlains = iNumPlains + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							outerForest = outerForest + 1;
						else
							outerOneHammer = outerOneHammer + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
						outerCanHaveBonus = outerCanHaveBonus + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							outerForest = outerForest + 1;
						else
							outerBadTiles = outerBadTiles + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_DESERT then
						outerBadTiles = outerBadTiles + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1; -- Can have Oasis.
					else -- Snow
						outerBadTiles = outerBadTiles + 1;
					end
				end
			end
		end
	end
	
	-- Adjust the hammer situation, if needed.
	local innerHammerScore = (3 * innerHills) + innerForest + innerOneHammer;
	local outerHammerScore = (2 * outerHills) + outerForest + outerOneHammer;
	local earlyHammerScore = (2 * innerForest) + outerForest + innerOneHammer + outerOneHammer;
	
	print("Inner Hammer: ", innerHammerScore);
	print("Outer Hammer: ", outerHammerScore);
	print("Early Hammer: ", earlyHammerScore);
	
	-- If drastic shortage, attempt to add a hill to first ring.
	if (outerHammerScore <= 14 and innerHammerScore <= 6) or innerHammerScore == 0 then -- Change a first ring plot to Hills.
		if isEvenY then
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsEven);
		else
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsOdd);
		end
		for attempt = 1, 6 do
			local plot_adjustments = randomized_first_ring_adjustments[attempt];
			local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
			-- Attempt to place a Hill at the currently chosen plot.
			local placedHill = self:AttemptToPlaceHillsAtPlot(searchX, searchY);
			if placedHill == true then
				innerHammerScore = innerHammerScore + 4;
				print("Added hills next to hammer-poor start plot at ", x, y);
				break
			elseif attempt == 6 then
				print("FAILED to add hills next to hammer-poor start plot at ", x, y);
			end
		end
	end
	
	-- Add mandatory Iron, Horse, Oil to every start if Strategic Balance option is enabled.
	if self.start_locations == 3 or self.start_locations == 4 or self.start_locations == 5 or self.start_locations == 6 or self.start_locations == 1 or self.start_locations == 2 then
		self:AddStrategicBalanceResources(region_number)
	end
	
	-- If early hammers will be too short, attempt to add a small Horse or Iron to second ring.
	if innerHammerScore <= 4 and earlyHammerScore < 8 then -- Add a small Horse or Iron to second ring.
		if isEvenY then
			randomized_second_ring_adjustments = GetShuffledCopyOfTable(self.secondRingYIsEven);
		else
			randomized_second_ring_adjustments = GetShuffledCopyOfTable(self.secondRingYIsOdd);
		end
		for attempt = 1, 12 do
			local plot_adjustments = randomized_second_ring_adjustments[attempt];
			local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
			-- Attempt to place a Hill at the currently chosen plot.
			local placedStrategic = self:AttemptToPlaceSmallStrategicAtPlot(searchX, searchY);
			if placedStrategic == true then
				print("Added small horse / iron next to hammer-poor start plot at ", x, y);
				break
			elseif attempt == 12 then
				print("FAILED to add small strategic resource near hammer-poor start plot at ", x, y);
			end
		end
	end
	
	-- Rate the food situation.
	local innerFoodScore = (4 * innerFourFood) + (2 * innerThreeFood) + innerTwoFood;
	local outerFoodScore = (4 * outerFourFood) + (2 * outerThreeFood) + outerTwoFood;
	local totalFoodScore = innerFoodScore + outerFoodScore;
	local nativeTwoFoodTiles = iNumNativeTwoFoodFirstRing + iNumNativeTwoFoodSecondRing;

	--Debug printout of food scores.
	print("Inner Food: ", innerFoodScore);
	print("Outer Food: ", outerFoodScore);
	print("Total Food: ", totalFoodScore);
	print("Native Two Food: ", nativeTwoFoodTiles);
	
	print("-");
	print("-- - Start Point in Region #", region_number, " has Food Score of ", totalFoodScore, " with rings of ", innerFoodScore, outerFoodScore);
		
	
	-- Six levels for Bonus Resource support, from zero to five.
	if totalFoodScore < 4 and innerFoodScore == 0 then
		iNumFoodBonusNeeded = 2;
	elseif totalFoodScore < 6 then
		iNumFoodBonusNeeded = 2;
	elseif totalFoodScore < 8 then
		iNumFoodBonusNeeded = 2;
	elseif totalFoodScore < 12 and innerFoodScore < 5 then
		iNumFoodBonusNeeded = 3;
	elseif totalFoodScore < 17 and innerFoodScore < 9 then
		iNumFoodBonusNeeded = 3;
	elseif nativeTwoFoodTiles < 2 then
		iNumFoodBonusNeeded = 3;
	elseif totalFoodScore < 24 and innerFoodScore < 11 then
		iNumFoodBonusNeeded = 3;
	elseif nativeTwoFoodTiles == 2 or iNumNativeTwoFoodFirstRing < 2 then
		iNumFoodBonusNeeded = 3;
	elseif nativeTwoFoodTiles > 10 or iNumNativeTwoFoodFirstRing > 3 then
		iNumFoodBonusNeeded = 3;
	elseif totalFoodScore < 20 then
		iNumFoodBonusNeeded = 3;
	end
	
	-- Check for Legendary Start resource option.
	
	if self.start_locations == 1 or self.start_locations == 2 then
		iNumFoodBonusNeeded = iNumFoodBonusNeeded + 1;
	end
	
	-- Here I write some custom IF statements that correct possible mistakes in previous calculations, because I cannot be bothered looking at all the functions individually
	-- This might actually fix some other issues so please, praise me :-) ~EAP
	-- Note: a lot of this code doesn't do anything, yet, lot of it is for if you increase the iNumFoodBonusNeeded above 3 at the end of the iNumFoodBonusNeeded calculations
	
	
	
	-- Give Production Heavy starts that also received a lot of bonus resources, less bonus resources
	
	if innerOneHammer >= 4 and outerOneHammer >= 8 and iNumFoodBonusNeeded >= 4 then
		iNumFoodBonusNeeded = iNumFoodBonusNeeded - 1;
	end
	
	-- Give Empty flat land starts more resources if they didn't already
	if innerHills <= 2 and iNumFoodBonusNeeded <= 3 then
		iNumFoodBonusNeeded = iNumFoodBonusNeeded + 2;
	end 
	
	 --Give heavy forest starts more food if not enough food was assigned
	if innerForest >= 3 or outerForest >= 2 and iNumFoodBonusNeeded <= 1 then
		iNumFoodBonusNeeded = iNumFoodBonusNeeded + 1;
	end
	
	
	-- Flat desert? No pls
	
	if innerBadTiles >= 2 and innerBadTiles <= 3 then
		iNumFoodBonusNeeded = iNumFoodBonusNeeded + 1;
	end
	
	if innerBadTiles >= 4 and innerBadTiles <= 5 then
		iNumFoodBonusNeeded = iNumFoodBonusNeeded + 2;
	end
	-- Let's pray this doesn't happen
	if innerBadTiles >= 6 then
		iNumFoodBonusNeeded = iNumFoodBonusNeeded + 3;
	end
	
	-- Give every start at least one bonus needed (EDIT, MAKE IT 3 INSTEAD)
	if iNumFoodBonusNeeded <= 1 then
		iNumFoodBonusNeeded = iNumFoodBonusNeeded + 2;
	end
	-- But we do not want too many bonus resources
	if iNumFoodBonusNeeded >= 3 then
		iNumFoodBonusNeeded = 3
	end 
	
	
	
	print("Food Bonuses: ", iNumFoodBonusNeeded);
	
	-- Check to see if a Grass tile needs to be added at an all-plains site with zero native 2-food tiles in first two rings.
	--if nativeTwoFoodTiles == 0 and iNumFoodBonusNeeded < 3 then
		--local odd = self.firstRingYIsOdd;
		--local even = self.firstRingYIsEven;
		--local plot_list = {};
		-- For notes on how the hex-iteration works, refer to PlaceResourceImpact()
		--local ripple_radius = 2;
		--local currentX = x - ripple_radius;
		--local currentY = y;
		--for direction_index = 1, 6 do
			--for plot_to_handle = 1, ripple_radius do
			 	--if currentY / 2 > math.floor(currentY / 2) then
					--plot_adjustments = odd[direction_index];
				--else
					--plot_adjustments = even[direction_index];
				--end
				--nextX = currentX + plot_adjustments[1];
				--nextY = currentY + plot_adjustments[2];
				--if wrapX == false and (nextX < 0 or nextX >= iW) then
					-- X is out of bounds.
				--elseif wrapY == false and (nextY < 0 or nextY >= iH) then
					-- Y is out of bounds.
				--else
					--local realX = nextX;
					--local realY = nextY;
					--if wrapX then
						--realX = realX % iW;
					--end
					--if wrapY then
						--realY = realY % iH;
					--end
					-- We've arrived at the correct x and y for the current plot.
					--local plot = Map.GetPlot(realX, realY);
					--if plot:GetResourceType(-1) == -1 then -- No resource here, safe to proceed.
						--local plotType = plot:GetPlotType()
						--local terrainType = plot:GetTerrainType()
						--local featureType = plot:GetFeatureType()
						--local plotIndex = realY * iW + realX + 1;
						-- Now check this plot for eligibility to be converted to flat open grassland.
						--if plotType == PlotTypes.PLOT_LAND then
							--if terrainType == TerrainTypes.TERRAIN_PLAINS then
								--if featureType == FeatureTypes.NO_FEATURE then
									--table.insert(plot_list, plotIndex);
								--end
							--end
						--end
					--end
				--end
				--currentX, currentY = nextX, nextY;
			--end
		--end
		--local iNumConversionCandidates = table.maxn(plot_list);
		--if iNumConversionCandidates == 0 then
			--iNumFoodBonusNeeded = 3;
		--else
			--print("-"); print("*** START HAD NO 2-FOOD TILES, YET ONLY QUALIFIED FOR 2 BONUS; CONVERTING A PLAINS TO GRASS! ***"); print("-");
			--local diceroll = 1 + Map.Rand(iNumConversionCandidates, "Choosing plot to convert to Grass near food-poor Plains start - LUA");
			--local conversionPlotIndex = plot_list[diceroll];
			--local conv_x = (conversionPlotIndex - 1) % iW;
			--local conv_y = (conversionPlotIndex - conv_x - 1) / iW;
			--local plot = Map.GetPlot(conv_x, conv_y);
			--plot:SetTerrainType(TerrainTypes.TERRAIN_GRASS, false, false)
			--self:PlaceResourceImpact(conv_x, conv_y, 1, 0) -- Disallow strategic resources at this plot, to keep it a farm plot.
		--end
	--end
	-- Add Bonus Resources to food-poor start positions.
	if iNumFoodBonusNeeded > 0 then
		local maxBonusesPossible = innerCanHaveBonus + outerCanHaveBonus;

		--print("-");
		print("Food-Poor start ", x, y, " needs ", iNumFoodBonusNeeded, " Bonus, with ", maxBonusesPossible, " eligible plots.");
		--print("-");

		local innerPlaced, outerPlaced = 0, 0;
		local randomized_first_ring_adjustments, randomized_second_ring_adjustments, randomized_third_ring_adjustments;
		if isEvenY then
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsEven);
			randomized_second_ring_adjustments = GetShuffledCopyOfTable(self.secondRingYIsEven);
			randomized_third_ring_adjustments = GetShuffledCopyOfTable(self.thirdRingYIsEven);
		else
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsOdd);
			randomized_second_ring_adjustments = GetShuffledCopyOfTable(self.secondRingYIsOdd);
			randomized_third_ring_adjustments = GetShuffledCopyOfTable(self.thirdRingYIsOdd);
		end

		local tried_all_first_ring = false;
		local tried_all_second_ring = false;
		local tried_all_third_ring = false;
		local allow_oasis = true; -- Permanent flag. (We don't want to place more than one Oasis per location).
		local allow_fishCount = 0;

		-- MOD: sapht this is where to change fish-granary cap balance
		if self._lek_coastal_refish then
			allow_fishcount = 0;
		end

		local placedOasis; -- Records returning result from each attempt.
		while iNumFoodBonusNeeded > 0 do
			if ((innerPlaced < 2 and innerCanHaveBonus > 0) or (self.start_locations == 1 and innerPlaced < 5 and innerCanHaveBonus > 0) or (self.start_locations == 2 and innerPlaced < 5 and innerCanHaveBonus > 0))
			  and tried_all_first_ring == false then
				-- Add bonus to inner ring.
				for attempt = 1, 6 do
					local plot_adjustments = randomized_first_ring_adjustments[attempt];
					local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
					-- Attempt to place a Bonus at the currently chosen plot.
					local placedBonus, placedOasis, placedFish = self:AttemptToPlaceBonusResourceAtPlot(searchX, searchY, allow_oasis, allow_fishCount);
					if placedBonus == true then
						if placedFish == true then -- First fish was placed on this pass, so change permission.
							allow_fishCount = allow_fishCount - 1;
						end
						if allow_oasis == true and placedOasis == true then -- First oasis was placed on this pass, so change permission.
							allow_oasis = false;
						end
						--print("Placed a Bonus in first ring at ", searchX, searchY);
						innerPlaced = innerPlaced + 1;
						innerCanHaveBonus = innerCanHaveBonus - 1;
						iNumFoodBonusNeeded = iNumFoodBonusNeeded - 1;
						break
					elseif attempt == 6 then
						tried_all_first_ring = true;
					end
				end

			elseif ((innerPlaced + outerPlaced < 5 and outerCanHaveBonus > 0) or (self.start_locations == 1 and innerPlaced + outerPlaced < 4 and outerCanHaveBonus > 0) or (self.start_locations == 2 and innerPlaced + outerPlaced < 4 and outerCanHaveBonus > 0))
			  and tried_all_second_ring == false then
				-- Add bonus to second ring.
				for attempt = 1, 12 do
					local plot_adjustments = randomized_second_ring_adjustments[attempt];
					local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
					-- Attempt to place a Bonus at the currently chosen plot.
					local placedBonus, placedOasis, placedFish = self:AttemptToPlaceBonusResourceAtPlot(searchX, searchY, allow_oasis, allow_fishCount);
					if placedBonus == true then
						if placedFish == true then -- First fish was placed on this pass, so change permission.
							allow_fishCount = allow_fishCount - 1;
						end
						if allow_oasis == true and placedOasis == true then -- First oasis was placed on this pass, so change permission.
							allow_oasis = false;
						end
						--print("Placed a Bonus in second ring at ", searchX, searchY);
						outerPlaced = outerPlaced + 1;
						outerCanHaveBonus = outerCanHaveBonus - 1;
						iNumFoodBonusNeeded = iNumFoodBonusNeeded - 1;
						break
					elseif attempt == 12 then
						tried_all_second_ring = true;
					end
				end

			elseif tried_all_third_ring == false then
				-- Add bonus to third ring.
				for attempt = 1, 18 do
					local plot_adjustments = randomized_third_ring_adjustments[attempt];
					local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
					-- Attempt to place a Bonus at the currently chosen plot.
					local placedBonus, placedOasis, placedFish = self:AttemptToPlaceBonusResourceAtPlot(searchX, searchY, allow_oasis, allow_fishCount);
					if placedBonus == true then
						if placedFish == true then -- First fish was placed on this pass, so change permission.
							allow_fishCount = allow_fishCount - 1;
						end
						if allow_oasis == true and placedOasis == true then -- First oasis was placed on this pass, so change permission.
							allow_oasis = false;
						end
						--print("Placed a Bonus in third ring at ", searchX, searchY);
						iNumFoodBonusNeeded = iNumFoodBonusNeeded - 1;
						break
					elseif attempt == 18 then
						tried_all_third_ring = true;
					end
				end
				
			else -- Tried everywhere, have to give up.
				break				
			end
		end
	end

	-- Check for heavy grass and light plains. Adding Stone if grass count is high and plains count is low. - May 2011, BT
	local iNumStoneNeeded = 0;
	if iNumGrass >= 7 and iNumPlains < 2 then
		iNumStoneNeeded = 2;
	elseif iNumGrass >= 6 and iNumPlains <= 4 then
		iNumStoneNeeded = 1;
	elseif iNumGrass >= 9 and iNumPlains <= 1 then
		iNumStoneNeeded = 3;
	end
	
	if iNumStoneNeeded > 0 then -- Add Stone to this grass start.
		local stonePlaced, innerPlaced = 0, 0;
		local randomized_first_ring_adjustments, randomized_second_ring_adjustments;
		if isEvenY then
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsEven);
			randomized_second_ring_adjustments = GetShuffledCopyOfTable(self.secondRingYIsEven);
		else
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsOdd);
			randomized_second_ring_adjustments = GetShuffledCopyOfTable(self.secondRingYIsOdd);
		end
		local tried_all_first_ring = false;
		local tried_all_second_ring = false;
		while iNumStoneNeeded > 0 do
			if innerPlaced < 1 and tried_all_first_ring == false then
				-- Add bonus to inner ring.
				for attempt = 1, 6 do
					local plot_adjustments = randomized_first_ring_adjustments[attempt];
					local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
					-- Attempt to place Cows at the currently chosen plot.
					local placedBonus = self:AttemptToPlaceStoneAtGrassPlot(searchX, searchY);
					if placedBonus == true then
						--print("Placed Stone in first ring at ", searchX, searchY);
						innerPlaced = innerPlaced + 1;
						iNumStoneNeeded = iNumStoneNeeded - 1;
						break
					elseif attempt == 6 then
						tried_all_first_ring = true;
					end
				end

			elseif tried_all_second_ring == false then
				-- Add bonus to second ring.
				for attempt = 1, 12 do
					local plot_adjustments = randomized_second_ring_adjustments[attempt];
					local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
					-- Attempt to place Stone at the currently chosen plot.
					local placedBonus = self:AttemptToPlaceStoneAtGrassPlot(searchX, searchY);
					if placedBonus == true then
						--print("Placed Stone in second ring at ", searchX, searchY);
						iNumStoneNeeded = iNumStoneNeeded - 1;
						break
					elseif attempt == 12 then
						tried_all_second_ring = true;
					end
				end

			else -- Tried everywhere, have to give up.
				break				
			end
		end
	end
	
	-- Record conditions at this start location.
	local results_table = {alongOcean, nextToLake, isRiver, nearRiver, nearMountain, forestCount, jungleCount};
	self.startLocationConditions[region_number] = results_table;
end
------------------------------------------------------------------------------
function AssignStartingPlots:FindFallbackForUnmatchedRegionPriority(iRegionType, regions_still_available)
	-- This function acts upon Civs with a single Region Priority who were unable to be 
	-- matched to a region of their priority type. We will scan remaining regions for the
	-- one with the most plots of the matching terrain type.
	local iMostTundra, iMostTundraForest, iMostJungle, iMostForest, iMostDesert = 0, 0, 0, 0, 0;
	local iMostHills, iMostPlains, iMostGrass, iMostHybrid, iMostWet = 0, 0, 0, 0, 0;
	local bestTundra, bestTundraForest, bestJungle, bestForest, bestDesert = -1, -1, -1, -1, -1;
	local bestHills, bestPlains, bestGrass, bestHybrid, bestWet = -1, -1, -1, -1, -1;

	for loop, region_number in ipairs(regions_still_available) do
		local terrainCounts = self.regionTerrainCounts[region_number];
		--local totalPlots = terrainCounts[1];
		--local areaPlots = terrainCounts[2];
		--local waterCount = terrainCounts[3];
		local flatlandsCount = terrainCounts[4];
		local hillsCount = terrainCounts[5];
		local peaksCount = terrainCounts[6];
		--local lakeCount = terrainCounts[7];
		--local coastCount = terrainCounts[8];
		--local oceanCount = terrainCounts[9];
		--local iceCount = terrainCounts[10];
		local grassCount = terrainCounts[11];
		local plainsCount = terrainCounts[12];
		local desertCount = terrainCounts[13];
		local tundraCount = terrainCounts[14];
		local snowCount = terrainCounts[15];
		local forestCount = terrainCounts[16];
		local jungleCount = terrainCounts[17];
		local marshCount = terrainCounts[18];
		--local riverCount = terrainCounts[19];
		local floodplainCount = terrainCounts[20];
		local oasisCount = terrainCounts[21];
		--local coastalLandCount = terrainCounts[22];
		--local nextToCoastCount = terrainCounts[23];
		
		if iRegionType == 1 then -- Find fallback for Tundra priority
			if tundraCount + snowCount > iMostTundra then
				bestTundra = region_number;
				iMostTundra = tundraCount + snowCount;
			end
			if forestCount > iMostTundraForest and jungleCount == 0 then
				bestTundraForest = region_number;
				iMostTundraForest = forestCount;
			end
		elseif iRegionType == 2 then -- Find fallback for Jungle priority
			if jungleCount > iMostJungle then
				bestJungle = region_number;
				iMostJungle = jungleCount;
			end
		elseif iRegionType == 3 then -- Find fallback for Forest priority
			if forestCount > iMostForest then
				bestForest = region_number;
				iMostForest = forestCount;
			end
		elseif iRegionType == 4 then -- Find fallback for Desert priority
			if desertCount + floodplainCount + oasisCount > iMostDesert then
				bestDesert = region_number;
				iMostDesert = desertCount + floodplainCount + oasisCount;
			end
		elseif iRegionType == 5 then -- Find fallback for Hills priority
			if hillsCount + peaksCount > iMostHills then
				bestHills = region_number;
				iMostHills = hillsCount + peaksCount;
			end
		elseif iRegionType == 6 then -- Find fallback for Plains priority
			if plainsCount > iMostPlains then
				bestPlains = region_number;
				iMostPlains = plainsCount;
			end
		elseif iRegionType == 7 then -- Find fallback for Grass priority
			if grassCount + marshCount > iMostGrass then
				bestGrass = region_number;
				iMostGrass = grassCount + marshCount;
			end
		elseif iRegionType == 8 then -- Find fallback for Hybrid priority
			if grassCount + plainsCount > iMostHybrid then
				bestHybrid = region_number;
				iMostHybrid = grassCount + plainsCount;
			end
		elseif iRegionType == 9 then -- Find fallback for wetlands priority
			if marshCount > iMostWet then
				bestWet = region_number;
				iMostWet = marshCount;
			end
		end
	end
	
	if iRegionType == 1 then
		if bestTundra ~= -1 then
			return bestTundra
		elseif bestTundraForest ~= -1 then
			return bestTundraForest
		end
	elseif iRegionType == 2 and bestJungle ~= -1 then
		return bestJungle
	elseif iRegionType == 3 and bestForest ~= -1 then
		return bestForest
	elseif iRegionType == 4 and bestDesert ~= -1 then
		return bestDesert
	elseif iRegionType == 5 and bestHills ~= -1 then
		return bestHills
	elseif iRegionType == 6 and bestPlains ~= -1 then
		return bestPlains
	elseif iRegionType == 7 and bestGrass ~= -1 then
		return bestGrass
	elseif iRegionType == 9 and bestGrass ~= -1 then
		return bestGrass
	elseif iRegionType == 8 and bestHybrid ~= -1 then
		return bestHybrid
	elseif iRegionType == 9 and bestWet ~= -1 then
		return bestWet
	end

	return -1
end
------------------------------------------------------------------------------
function AssignStartingPlots:NormalizeTeamLocations()
	-- This function will reorganize which Civs are assigned to which start
	-- locations, to ensure that Civs on the same team start near one another.
	--Game:NormalizeStartingPlotLocations() 
end
------------------------------------------------------------------------------
function AssignStartingPlots:BalanceAndAssign(args)
	-- This function determines what level of Bonus Resource support a location
	-- may need, identifies compatibility with civ-specific biases, and places starts.

	-- Normalize each start plot location.
	local iW, iH = Map.GetGridSize();
	local iNumStarts = table.maxn(self.startingPlots);
	for region_number = 1, iNumStarts do
		self:NormalizeStartLocation(region_number)
	end

	-- Check Game Option for disabling civ-specific biases.
	-- If they are to be disabled, then all civs are simply assigned to start plots at random.
	local bDisableStartBias = Game.GetCustomOption("GAMEOPTION_DISABLE_START_BIAS");
	if bDisableStartBias == 1 then
		--print("-"); print("ALERT: Civ Start Biases have been selected to be Disabled!"); print("-");
		local playerList = {};
		for loop = 1, self.iNumCivs do
			local player_ID = self.player_ID_list[loop];
			table.insert(playerList, player_ID);
		end
		local playerListShuffled = GetShuffledCopyOfTable(playerList)
		for region_number, player_ID in ipairs(playerListShuffled) do
			local x = self.startingPlots[region_number][1];
			local y = self.startingPlots[region_number][2];
			local start_plot = Map.GetPlot(x, y)
			local player = Players[player_ID]
			local i = y * iW + x + 1;
			player:SetStartingPlot(start_plot)
		end
		-- If this is a team game (any team has more than one Civ in it) then make 
		-- sure team members start near each other if possible. (This may scramble 
		-- Civ biases in some cases, but there is no cure).
		if self.bTeamGame == true then
			self:NormalizeTeamLocations()
		end
		-- Done with un-biased Civ placement.
		return
	end

	-- If the process reaches here, civ-specific start-location biases are enabled. Handle them now.
	-- Create a randomized list of all regions. As a region gets assigned, we'll remove it from the list.
	local all_regions = {};
	for loop = 1, self.iNumCivs do
		table.insert(all_regions, loop);
	end
	local regions_still_available = GetShuffledCopyOfTable(all_regions)

	local civs_needing_coastal_start = {};
	local civs_priority_coastal_start = {};
	local civs_needing_river_start = {};
	local civs_needing_region_priority = {};
	local civs_needing_region_avoid = {};
	local regions_with_coastal_start = {};
	local regions_with_lake_start = {};
	local regions_with_river_start = {};
	local regions_with_near_river_start = {};
	local civ_status = table.fill(false, GameDefines.MAX_MAJOR_CIVS); -- Have to account for possible gaps in player ID numbers, for MP.
	local region_status = table.fill(false, self.iNumCivs);
	local priority_lists = {};
	local avoid_lists = {};
	local iNumCoastalCivs, iNumRiverCivs, iNumPriorityCivs, iNumAvoidCivs = 0, 0, 0, 0;
	local iNumCoastalCivsRemaining, iNumRiverCivsRemaining, iNumPriorityCivsRemaining, iNumAvoidCivsRemaining = 0, 0, 0, 0;
	
	--print("-"); print("-"); print("--- DEBUG READOUT OF PLAYER START ASSIGNMENTS ---"); print("-");
	
	-- Generate lists of player needs. Each additional need type is subordinate to those
	-- that come before. In other words, each Civ can have only one need type.
	for loop = 1, self.iNumCivs do
		local playerNum = self.player_ID_list[loop]; -- MP games can have gaps between player numbers, so we cannot assume a sequential set of IDs.
		local player = Players[playerNum];
		local civType = GameInfo.Civilizations[player:GetCivilizationType()].Type;
		print("Player", playerNum, "of Civ Type", civType);
		local bNeedsCoastalStart = CivNeedsCoastalStart(civType)
		if args.MixedBias and Map.Rand(100, "") >= 0 and CivNeedsPlaceFirstCoastalStart(civType) then 
			bNeedsCoastalStart = false;
		end
		if bNeedsCoastalStart == true then
			print("- - - - - - - needs Coastal Start!"); print("-");
			iNumCoastalCivs = iNumCoastalCivs + 1;
			iNumCoastalCivsRemaining = iNumCoastalCivsRemaining + 1;
			table.insert(civs_needing_coastal_start, playerNum);
			local bPlaceFirst = CivNeedsPlaceFirstCoastalStart(civType);
			if bPlaceFirst then
				print("- - - - - - - needs to Place First!"); print("-");
				table.insert(civs_priority_coastal_start, playerNum);
			end
		else
			local bNeedsRiverStart = CivNeedsRiverStart(civType)
			if bNeedsRiverStart == true then
				--print("- - - - - - - needs River Start!"); print("-");
				iNumRiverCivs = iNumRiverCivs + 1;
				iNumRiverCivsRemaining = iNumRiverCivsRemaining + 1;
				table.insert(civs_needing_river_start, playerNum);
			else
				local iNumRegionPriority = GetNumStartRegionPriorityForCiv(civType)
				if iNumRegionPriority > 0 then
					--print("- - - - - - - needs Region Priority!"); print("-");
					local table_of_this_civs_priority_needs = GetStartRegionPriorityListForCiv_GetIDs(civType)
					iNumPriorityCivs = iNumPriorityCivs + 1;
					iNumPriorityCivsRemaining = iNumPriorityCivsRemaining + 1;
					table.insert(civs_needing_region_priority, playerNum);
					priority_lists[playerNum] = table_of_this_civs_priority_needs;
				else
					local iNumRegionAvoid = GetNumStartRegionAvoidForCiv(civType)
					if iNumRegionAvoid > 0 then
						--print("- - - - - - - needs Region Avoid!"); print("-");
						local table_of_this_civs_avoid_needs = GetStartRegionAvoidListForCiv_GetIDs(civType)
						iNumAvoidCivs = iNumAvoidCivs + 1;
						iNumAvoidCivsRemaining = iNumAvoidCivsRemaining + 1;
						table.insert(civs_needing_region_avoid, playerNum);
						avoid_lists[playerNum] = table_of_this_civs_avoid_needs;
					end
				end
			end
		end
	end
	
	print("Civs with Coastal Bias:", iNumCoastalCivs);
	print("Civs with River Bias:", iNumRiverCivs);
	print("Civs with Region Priority:", iNumPriorityCivs);
	print("Civs with Region Avoid:", iNumAvoidCivs); print("-");
	
	-- Handle Coastal Start Bias
	if iNumCoastalCivs > 0 then
		-- Generate lists of regions eligible to support a coastal start.
		local iNumRegionsWithCoastalStart, iNumRegionsWithLakeStart, iNumUnassignableCoastStarts = 0, 0, 0;
		for region_number, bAlreadyAssigned in ipairs(region_status) do
			if bAlreadyAssigned == false then
				if self.startLocationConditions[region_number][1] == true then
					print("Region#", region_number, "has a Coastal Start.");
					iNumRegionsWithCoastalStart = iNumRegionsWithCoastalStart + 1;
					table.insert(regions_with_coastal_start, region_number);
				end
			end
		end
		if iNumRegionsWithCoastalStart < iNumCoastalCivs then
			for region_number, bAlreadyAssigned in ipairs(region_status) do
				if bAlreadyAssigned == false then
					if self.startLocationConditions[region_number][2] == true and
					   self.startLocationConditions[region_number][1] == false then
						print("Region#", region_number, "has a Lake Start.");
						iNumRegionsWithLakeStart = iNumRegionsWithLakeStart + 1;
						table.insert(regions_with_lake_start, region_number);
					end
				end
			end
		end
		if iNumRegionsWithCoastalStart + iNumRegionsWithLakeStart < iNumCoastalCivs then
			iNumUnassignableCoastStarts = iNumCoastalCivs - (iNumRegionsWithCoastalStart + iNumRegionsWithLakeStart);
		end
		-- Now assign those with coastal bias to start locations, where possible.
		print("iNumCoastalCivs: " .. iNumCoastalCivs);
		print("iNumUnassignableCoastStarts: " .. iNumUnassignableCoastStarts);
		if iNumCoastalCivs - iNumUnassignableCoastStarts > 0 then
			-- create non-priority coastal start list
			local non_priority_coastal_start = {};
			for loop1, iPlayerNum1 in ipairs(civs_needing_coastal_start) do
				local bAdd = true;
				for loop2, iPlayerNum2 in ipairs(civs_priority_coastal_start) do
					if (iPlayerNum1 == iPlayerNum2) then
						bAdd = false;
					end
				end
				if bAdd then
					table.insert(non_priority_coastal_start, iPlayerNum1);
				end
			end
			
			local shuffled_priority_coastal_start = GetShuffledCopyOfTable(civs_priority_coastal_start);
			local shuffled_non_priority_coastal_start = GetShuffledCopyOfTable(non_priority_coastal_start);
			local shuffled_coastal_civs = {};
			
			-- insert priority coastal starts first
			for loop, iPlayerNum in ipairs(shuffled_priority_coastal_start) do
				table.insert(shuffled_coastal_civs, iPlayerNum);
			end
			
			-- insert non-priority coastal starts second
			for loop, iPlayerNum in ipairs(shuffled_non_priority_coastal_start) do
				table.insert(shuffled_coastal_civs, iPlayerNum);
			end			
			
			for loop, iPlayerNum in ipairs(shuffled_coastal_civs) do
				print("shuffled_coastal_civs[" .. loop .. "]: " .. iPlayerNum);
			end
			
			local shuffled_coastal_regions, shuffled_lake_regions;
			local current_lake_index = 1;
			if iNumRegionsWithCoastalStart > 0 then
				shuffled_coastal_regions = GetShuffledCopyOfTable(regions_with_coastal_start);
			end
			if iNumRegionsWithLakeStart > 0 then
				shuffled_lake_regions = GetShuffledCopyOfTable(regions_with_lake_start);
			end
			for loop, playerNum in ipairs(shuffled_coastal_civs) do
				if loop > iNumCoastalCivs - iNumUnassignableCoastStarts then
					--print("Ran out of Coastal and Lake start locations to assign to Coastal Bias.");
					break
				end
				-- Assign next randomly chosen civ in line to next randomly chosen eligible region.
				if loop <= iNumRegionsWithCoastalStart then
					-- Assign this civ to a region with coastal start.
					local choose_this_region = shuffled_coastal_regions[loop];
					local x = self.startingPlots[choose_this_region][1];
					local y = self.startingPlots[choose_this_region][2];
					local plot = Map.GetPlot(x, y);
					local player = Players[playerNum];
					player:SetStartingPlot(plot);
					--print("Player Number", playerNum, "assigned a COASTAL START BIAS location in Region#", choose_this_region, "at Plot", x, y);
					region_status[choose_this_region] = true;
					civ_status[playerNum + 1] = true;
					iNumCoastalCivsRemaining = iNumCoastalCivsRemaining - 1;
					local a, b, c = IdentifyTableIndex(civs_needing_coastal_start, playerNum)
					if a then
						table.remove(civs_needing_coastal_start, c[1]);
					end
					local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
					if a then
						table.remove(regions_still_available, c[1]);
					end
				else
					-- Out of coastal starts, assign this civ to region with lake start.
					local choose_this_region = shuffled_lake_regions[current_lake_index];
					local x = self.startingPlots[choose_this_region][1];
					local y = self.startingPlots[choose_this_region][2];
					local plot = Map.GetPlot(x, y);
					local player = Players[playerNum];
					player:SetStartingPlot(plot);
					--print("Player Number", playerNum, "with Coastal Bias assigned a fallback Lake location in Region#", choose_this_region, "at Plot", x, y);
					region_status[choose_this_region] = true;
					civ_status[playerNum + 1] = true;
					iNumCoastalCivsRemaining = iNumCoastalCivsRemaining - 1;
					local a, b, c = IdentifyTableIndex(civs_needing_coastal_start, playerNum)
					if a then
						table.remove(civs_needing_coastal_start, c[1]);
					end
					local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
					if a then
						table.remove(regions_still_available, c[1]);
					end
					current_lake_index = current_lake_index + 1;
				end
			end
		--else
			--print("Either no civs required a Coastal Start, or no Coastal Starts were available.");
		end
	end
	
	-- Handle River bias
	if iNumRiverCivs > 0 or iNumCoastalCivsRemaining > 0 then
		-- Generate lists of regions eligible to support a river start.
		local iNumRegionsWithRiverStart, iNumRegionsNearRiverStart, iNumUnassignableRiverStarts = 0, 0, 0;
		for region_number, bAlreadyAssigned in ipairs(region_status) do
			if bAlreadyAssigned == false then
				if self.startLocationConditions[region_number][3] == true then
					iNumRegionsWithRiverStart = iNumRegionsWithRiverStart + 1;
					table.insert(regions_with_river_start, region_number);
				end
			end
		end
		for region_number, bAlreadyAssigned in ipairs(region_status) do
			if bAlreadyAssigned == false then
				if self.startLocationConditions[region_number][4] == true and
				   self.startLocationConditions[region_number][3] == false then
					iNumRegionsNearRiverStart = iNumRegionsNearRiverStart + 1;
					table.insert(regions_with_near_river_start, region_number);
				end
			end
		end
		if iNumRegionsWithRiverStart + iNumRegionsNearRiverStart < iNumRiverCivs then
			iNumUnassignableRiverStarts = iNumRiverCivs - (iNumRegionsWithRiverStart + iNumRegionsNearRiverStart);
		end
		-- Now assign those with river bias to start locations, where possible.
		-- Also handle fallback placement for coastal bias that failed to find a match.
		if iNumRiverCivs - iNumUnassignableRiverStarts > 0 then
			local shuffled_river_civs = GetShuffledCopyOfTable(civs_needing_river_start);
			local shuffled_river_regions, shuffled_near_river_regions;
			if iNumRegionsWithRiverStart > 0 then
				shuffled_river_regions = GetShuffledCopyOfTable(regions_with_river_start);
			end
			if iNumRegionsNearRiverStart > 0 then
				shuffled_near_river_regions = GetShuffledCopyOfTable(regions_with_near_river_start);
			end
			for loop, playerNum in ipairs(shuffled_river_civs) do
				if loop > iNumRiverCivs - iNumUnassignableRiverStarts then
					--print("Ran out of River and Near-River start locations to assign to River Bias.");
					break
				end
				-- Assign next randomly chosen civ in line to next randomly chosen eligible region.
				if loop <= iNumRegionsWithRiverStart then
					-- Assign this civ to a region with river start.
					local choose_this_region = shuffled_river_regions[loop];
					local x = self.startingPlots[choose_this_region][1];
					local y = self.startingPlots[choose_this_region][2];
					local plot = Map.GetPlot(x, y);
					local player = Players[playerNum];
					player:SetStartingPlot(plot);
					--print("Player Number", playerNum, "assigned a RIVER START BIAS location in Region#", choose_this_region, "at Plot", x, y);
					region_status[choose_this_region] = true;
					civ_status[playerNum + 1] = true;
					local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
					if a then
						table.remove(regions_still_available, c[1]);
					end
				else
					-- Assign this civ to a region where a river is near the start.
					local choose_this_region = shuffled_near_river_regions[loop - iNumRegionsWithRiverStart];
					local x = self.startingPlots[choose_this_region][1];
					local y = self.startingPlots[choose_this_region][2];
					local plot = Map.GetPlot(x, y);
					local player = Players[playerNum];
					player:SetStartingPlot(plot);
					--print("Player Number", playerNum, "with River Bias assigned a fallback 'near river' location in Region#", choose_this_region, "at Plot", x, y);
					region_status[choose_this_region] = true;
					civ_status[playerNum + 1] = true;
					local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
					if a then
						table.remove(regions_still_available, c[1]);
					end
				end
			end
		end
		-- Now handle any fallbacks for unassigned coastal bias.
		if iNumCoastalCivsRemaining > 0 and iNumRiverCivs < iNumRegionsWithRiverStart + iNumRegionsNearRiverStart then
			local iNumFallbacksWithRiverStart, iNumFallbacksNearRiverStart = 0, 0;
			local fallbacks_with_river_start, fallbacks_with_near_river_start = {}, {};
			for region_number, bAlreadyAssigned in ipairs(region_status) do
				if bAlreadyAssigned == false then
					if self.startLocationConditions[region_number][3] == true then
						iNumFallbacksWithRiverStart = iNumFallbacksWithRiverStart + 1;
						table.insert(fallbacks_with_river_start, region_number);
					end
				end
			end
			for region_number, bAlreadyAssigned in ipairs(region_status) do
				if bAlreadyAssigned == false then
					if self.startLocationConditions[region_number][4] == true and
					   self.startLocationConditions[region_number][3] == false then
						iNumFallbacksNearRiverStart = iNumFallbacksNearRiverStart + 1;
						table.insert(fallbacks_with_near_river_start, region_number);
					end
				end
			end
			if iNumFallbacksWithRiverStart + iNumFallbacksNearRiverStart > 0 then
			
				local shuffled_coastal_fallback_civs = GetShuffledCopyOfTable(civs_needing_coastal_start);
				local shuffled_river_fallbacks, shuffled_near_river_fallbacks;
				if iNumFallbacksWithRiverStart > 0 then
					shuffled_river_fallbacks = GetShuffledCopyOfTable(fallbacks_with_river_start);
				end
				if iNumFallbacksNearRiverStart > 0 then
					shuffled_near_river_fallbacks = GetShuffledCopyOfTable(fallbacks_with_near_river_start);
				end
				for loop, playerNum in ipairs(shuffled_coastal_fallback_civs) do
					if loop > iNumFallbacksWithRiverStart + iNumFallbacksNearRiverStart then
						--print("Ran out of River and Near-River start locations to assign as fallbacks for Coastal Bias.");
						break
					end
					-- Assign next randomly chosen civ in line to next randomly chosen eligible region.
					if loop <= iNumFallbacksWithRiverStart then
						-- Assign this civ to a region with river start.
						local choose_this_region = shuffled_river_fallbacks[loop];
						local x = self.startingPlots[choose_this_region][1];
						local y = self.startingPlots[choose_this_region][2];
						local plot = Map.GetPlot(x, y);
						local player = Players[playerNum];
						player:SetStartingPlot(plot);
						--print("Player Number", playerNum, "with Coastal Bias assigned a fallback river location in Region#", choose_this_region, "at Plot", x, y);
						region_status[choose_this_region] = true;
						civ_status[playerNum + 1] = true;
						local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
						if a then
							table.remove(regions_still_available, c[1]);
						end
					else
						-- Assign this civ to a region where a river is near the start.
						local choose_this_region = shuffled_near_river_fallbacks[loop - iNumRegionsWithRiverStart];
						local x = self.startingPlots[choose_this_region][1];
						local y = self.startingPlots[choose_this_region][2];
						local plot = Map.GetPlot(x, y);
						local player = Players[playerNum];
						player:SetStartingPlot(plot);
						--print("Player Number", playerNum, "with Coastal Bias assigned a fallback 'near river' location in Region#", choose_this_region, "at Plot", x, y);
						region_status[choose_this_region] = true;
						civ_status[playerNum + 1] = true;
						local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
						if a then
							table.remove(regions_still_available, c[1]);
						end
					end
				end
			end
		end
	end
	
	-- Handle Region Priority
	if iNumPriorityCivs > 0 then
		print("-"); print("-"); print("--- REGION PRIORITY READOUT ---"); print("-");
		local iNumSinglePriority, iNumMultiPriority, iNumNeedFallbackPriority = 0, 0, 0;
		local single_priority, multi_priority, fallback_priority = {}, {}, {};
		local single_sorted, multi_sorted = {}, {};
		-- Separate priority civs in to two categories: single priority, multiple priority.
		for playerNum, priority_needs in pairs(priority_lists) do
			local len = table.maxn(priority_needs)
			if len == 1 then
				print("Player#", playerNum, "has a single Region Priority of type", priority_needs[1]);
				local priority_data = {playerNum, priority_needs[1]};
				table.insert(single_priority, priority_data)
				iNumSinglePriority = iNumSinglePriority + 1;
			else
				print("Player#", playerNum, "has multiple Region Priority, this many types:", len);
				local priority_data = {playerNum, len};
				table.insert(multi_priority, priority_data)
				iNumMultiPriority = iNumMultiPriority + 1;
			end
		end
		-- Single priority civs go first, and will engage fallback methods if no match found.
		if iNumSinglePriority > 0 then
			-- Sort the list so that proper order of execution occurs. (Going to use a blunt method for easy coding.)
			for region_type = 1, 9 do							-- Must expand if new region types are added.
				for loop, data in ipairs(single_priority) do
					if data[2] == region_type then
						--print("Adding Player#", data[1], "to sorted list of single Region Priority.");
						table.insert(single_sorted, data);
					end
				end
			end
			-- Match civs who have a single Region Priority to the region type they need, if possible.
			for loop, data in ipairs(single_sorted) do
				local iPlayerNum = data[1];
				local iPriorityType = data[2];
				print("* Attempting to assign Player#", iPlayerNum, "to a region of Type#", iPriorityType);
				local bFoundCandidate, candidate_regions = false, {};
				for test_loop, region_number in ipairs(regions_still_available) do
					if self.regionTypes[region_number] == iPriorityType then
						table.insert(candidate_regions, region_number);
						bFoundCandidate = true;
						--print("- - Found candidate: Region#", region_number);
					end
				end
				if bFoundCandidate then
					local diceroll = 1 + Map.Rand(table.maxn(candidate_regions), "Choosing from among Candidate Regions for start bias - LUA");
					local choose_this_region = candidate_regions[diceroll];
					local x = self.startingPlots[choose_this_region][1];
					local y = self.startingPlots[choose_this_region][2];
					local plot = Map.GetPlot(x, y);
					local player = Players[iPlayerNum];
					player:SetStartingPlot(plot);
					print("Player Number", iPlayerNum, "with single Region Priority assigned to Region#", choose_this_region, "at Plot", x, y);
					region_status[choose_this_region] = true;
					civ_status[iPlayerNum + 1] = true;
					local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
					if a then
						table.remove(regions_still_available, c[1]);
					end
				else
					table.insert(fallback_priority, data)
					iNumNeedFallbackPriority = iNumNeedFallbackPriority + 1;
					--print("Player Number", iPlayerNum, "with single Region Priority was UNABLE to be matched to its type. Added to fallback list.");
				end
			end
		end
		-- Multiple priority civs go next, with fewest regions of priority going first.
		if iNumMultiPriority > 0 then
			for iNumPriorities = 2, 8 do						-- Must expand if new region types are added.
				for loop, data in ipairs(multi_priority) do
					if data[2] == iNumPriorities then
						--print("Adding Player#", data[1], "to sorted list of multi Region Priority.");
						table.insert(multi_sorted, data);
					end
				end
			end
			-- Match civs who have mulitple Region Priority to one of the region types they need, if possible.
			for loop, data in ipairs(multi_sorted) do
				local iPlayerNum = data[1];
				local iNumPriorityTypes = data[2];
				--print("* Attempting to assign Player#", iPlayerNum, "to one of its Priority Region Types.");
				local bFoundCandidate, candidate_regions = false, {};
				for test_loop, region_number in ipairs(regions_still_available) do
					for inner_loop = 1, iNumPriorityTypes do
						local region_type_to_test = priority_lists[iPlayerNum][inner_loop];
						if self.regionTypes[region_number] == region_type_to_test then
							table.insert(candidate_regions, region_number);
							bFoundCandidate = true;
							--print("- - Found candidate: Region#", region_number);
						end
					end
				end
				if bFoundCandidate then
					local diceroll = 1 + Map.Rand(table.maxn(candidate_regions), "Choosing from among Candidate Regions for start bias - LUA");
					local choose_this_region = candidate_regions[diceroll];
					local x = self.startingPlots[choose_this_region][1];
					local y = self.startingPlots[choose_this_region][2];
					local plot = Map.GetPlot(x, y);
					local player = Players[iPlayerNum];
					player:SetStartingPlot(plot);
					--print("Player Number", iPlayerNum, "with multiple Region Priority assigned to Region#", choose_this_region, "at Plot", x, y);
					region_status[choose_this_region] = true;
					civ_status[iPlayerNum + 1] = true;
					local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
					if a then
						table.remove(regions_still_available, c[1]);
					end
				--else
					--print("Player Number", iPlayerNum, "with multiple Region Priority was unable to be matched.");
				end
			end
		end
		-- Fallbacks are done (if needed) after multiple-region priority is handled. The list is pre-sorted.
		if iNumNeedFallbackPriority > 0 then
			for loop, data in ipairs(fallback_priority) do
				local iPlayerNum = data[1];
				local iPriorityType = data[2];
				print("* Attempting to assign Player#", iPlayerNum, "to a fallback region as similar as possible to Region Type#", iPriorityType);
				local choose_this_region = self:FindFallbackForUnmatchedRegionPriority(iPriorityType, regions_still_available)
				if choose_this_region == -1 then
					--print("FAILED to find fallback region bias for player#", iPlayerNum);
				else
					local x = self.startingPlots[choose_this_region][1];
					local y = self.startingPlots[choose_this_region][2];
					local plot = Map.GetPlot(x, y);
					local player = Players[iPlayerNum];
					player:SetStartingPlot(plot);
					--print("Player Number", iPlayerNum, "with single Region Priority assigned to FALLBACK Region#", choose_this_region, "at Plot", x, y);
					region_status[choose_this_region] = true;
					civ_status[iPlayerNum + 1] = true;
					local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
					if a then
						table.remove(regions_still_available, c[1]);
					end
				end
			end
		end
	end
	
	-- Handle Region Avoid
	if iNumAvoidCivs > 0 then
		--print("-"); print("-"); print("--- REGION AVOID READOUT ---"); print("-");
		local avoid_sorted, avoid_unsorted, avoid_counts = {}, {}, {};
		-- Sort list of civs with Avoid needs, then process in reverse order, so most needs goes first.
		for playerNum, avoid_needs in pairs(avoid_lists) do
			local len = table.maxn(avoid_needs)
			--print("- Player#", playerNum, "has this number of Region Avoid needs:", len);
			local avoid_data = {playerNum, len};
			table.insert(avoid_unsorted, avoid_data)
			table.insert(avoid_counts, len)
		end
		table.sort(avoid_counts)
		for loop, avoid_count in ipairs(avoid_counts) do
			for test_loop, avoid_data in ipairs(avoid_unsorted) do
				if avoid_count == avoid_data[2] then
					table.insert(avoid_sorted, avoid_data[1])
					table.remove(avoid_unsorted, test_loop)
				end
			end
		end
		-- Process the Region Avoid needs.
		for loop = iNumAvoidCivs, 1, -1 do
			local iPlayerNum = avoid_sorted[loop];
			local candidate_regions = {};
			for test_loop, region_number in ipairs(regions_still_available) do
				local bFoundCandidate = true;
				for inner_loop, region_type_to_avoid in ipairs(avoid_lists[iPlayerNum]) do
					if self.regionTypes[region_number] == region_type_to_avoid then
						bFoundCandidate = false;
					end
				end
				if bFoundCandidate == true then
					table.insert(candidate_regions, region_number);
					--print("- - Found candidate: Region#", region_number)
				end
			end
			if table.maxn(candidate_regions) > 0 then
				local diceroll = 1 + Map.Rand(table.maxn(candidate_regions), "Choosing from among Candidate Regions for start bias - LUA");
				local choose_this_region = candidate_regions[diceroll];
				local x = self.startingPlots[choose_this_region][1];
				local y = self.startingPlots[choose_this_region][2];
				local plot = Map.GetPlot(x, y);
				local player = Players[iPlayerNum];
				player:SetStartingPlot(plot);
				--print("Player Number", iPlayerNum, "with Region Avoid assigned to allowed region type in Region#", choose_this_region, "at Plot", x, y);
				region_status[choose_this_region] = true;
				civ_status[iPlayerNum + 1] = true;
				local a, b, c = IdentifyTableIndex(regions_still_available, choose_this_region)
				if a then
					table.remove(regions_still_available, c[1]);
				end
			--else
				--print("Player Number", iPlayerNum, "with Region Avoid was unable to avoid the undesired region types.");
			end
		end
	end
				
	-- Assign remaining civs to start plots.
	local playerList, regionList = {}, {};
	for loop = 1, self.iNumCivs do
		local player_ID = self.player_ID_list[loop];
		if civ_status[player_ID + 1] == false then -- Using C++ player ID, which starts at zero. Add 1 for Lua indexing.
			table.insert(playerList, player_ID);
		end
		if region_status[loop] == false then
			table.insert(regionList, loop);
		end
	end
	local iNumRemainingPlayers = table.maxn(playerList);
	local iNumRemainingRegions = table.maxn(regionList);
	if iNumRemainingPlayers > 0 or iNumRemainingRegions > 0 then
		--print("-"); print("Table of players with no start bias:");
		--PrintContentsOfTable(playerList);
		--print("-"); print("Table of regions still available after bias handling:");
		--PrintContentsOfTable(regionList);
		if iNumRemainingPlayers ~= iNumRemainingRegions then
			print("-"); print("ERROR: Number of civs remaining after handling biases does not match number of regions remaining!"); print("-");
		end
		local playerListShuffled = GetShuffledCopyOfTable(playerList)
		for index, player_ID in ipairs(playerListShuffled) do
			local region_number = regionList[index];
			local x = self.startingPlots[region_number][1];
			local y = self.startingPlots[region_number][2];
			--print("Now placing Player#", player_ID, "in Region#", region_number, "at start plot:", x, y);
			local start_plot = Map.GetPlot(x, y)
			local player = Players[player_ID]
			player:SetStartingPlot(start_plot)
		end
	end

	-- If this is a team game (any team has more than one Civ in it) then make 
	-- sure team members start near each other if possible. (This may scramble 
	-- Civ biases in some cases, but there is no cure).
	if self.bTeamGame == true then
		self:NormalizeTeamLocations()
	end
	--	
end
------------------------------------------------------------------------------
-- Start of functions tied to PlaceNaturalWonders()
------------------------------------------------------------------------------
function AssignStartingPlots:ExaminePlotForNaturalWondersEligibility(x, y)
	-- This function checks only for eligibility requirements applicable to all 
	-- Natural Wonders. If a candidate plot passes all such checks, we will move
	-- on to checking it against specific needs for each particular NW.
	--
	-- Update, May 2011: Control over NW placement is being migrated to XML. Some checks here moved to there.
	local iW, iH = Map.GetGridSize();
	local plotIndex = iW * y + x + 1;
	-- Check for collision with player starts
	if self.naturalWondersData[plotIndex] > 0 then
		return false
	end
	return true
end
------------------------------------------------------------------------------
function AssignStartingPlots:ExamineCandidatePlotForNaturalWondersEligibility(x, y)
	-- This function checks only for eligibility requirements applicable to all 
	-- Natural Wonders. If a candidate plot passes all such checks, we will move
	-- on to checking it against specific needs for each particular NW.
	if self:ExaminePlotForNaturalWondersEligibility(x, y) == false then
		return false
	end
	local iW, iH = Map.GetGridSize();
	-- Now loop through adjacent plots. Using Map.PlotDirection() in combination with
	-- direction types, an alternate first-ring hex adjustment method, instead of the
	-- odd/even tables used elsewhere in this file, which often have to process more rings.
	for loop, direction in ipairs(self.direction_types) do
		local adjPlot = Map.PlotDirection(x, y, direction)
		if adjPlot == nil then
			return false
		else
			local adjX = adjPlot:GetX();
			local adjY = adjPlot:GetY();
			if self:ExaminePlotForNaturalWondersEligibility(adjX, adjY) == false then
				return false
			end
		end
	end
	return true
end
------------------------------------------------------------------------------
function AssignStartingPlots:CanBeThisNaturalWonderType(x, y, wn, rn)
	-- Checks a candidate plot for eligibility to host the supplied wonder type.
	-- "rn" = the row number for this wonder type within the xml Placement data table.
	local plot = Map.GetPlot(x, y);
	-- Use Custom Eligibility method if indicated.
	if self.EligibilityMethodNumber[wn] ~= -1 then
		local method_number = self.EligibilityMethodNumber[wn];
		if NWCustomEligibility(x, y, method_number) == true then
			local iW, iH = Map.GetGridSize();
			local plotIndex = y * iW + x + 1;
			table.insert(self.eligibility_lists[wn], plotIndex);
		end
		return
	end
	-- Run root checks.
	if self.bWorldHasOceans == true then -- Check to see if this wonder requires or avoids the biggest landmass.
		if self.RequireBiggestLandmass[wn] == true then
			local iAreaID = plot:GetArea();
			if iAreaID ~= self.iBiggestLandmassID then
				return
			end
		elseif self.AvoidBiggestLandmass[wn] == true then
			local iAreaID = plot:GetArea();
			if iAreaID == self.iBiggestLandmassID then
				return
			end
		end
	end
	if self.RequireFreshWater[wn] == true then
		if plot:IsFreshWater() == false then
			return
		end
	elseif self.AvoidFreshWater[wn] == true then
		if plot:IsRiver() or plot:IsLake() or plot:IsFreshWater() then
			return
		end
	end
	-- Land or Sea
	if self.LandBased[wn] == true then
		if plot:IsWater() == true then
			return
		end
		local iW, iH = Map.GetGridSize();
		local plotIndex = y * iW + x + 1;
		if self.RequireLandAdjacentToOcean[wn] == true then
			if self.plotDataIsCoastal[plotIndex] == false then
				return
			end
		elseif self.AvoidLandAdjacentToOcean[wn] == true then
			if self.plotDataIsCoastal[plotIndex] == true then
				return
			end
		end
		if self.RequireLandOnePlotInland[wn] == true then
			if self.plotDataIsNextToCoast[plotIndex] == false then
				return
			end
		elseif self.AvoidLandOnePlotInland[wn] == true then
			if self.plotDataIsNextToCoast[plotIndex] == true then
				return
			end
		end
		if self.RequireLandTwoOrMorePlotsInland[wn] == true then
			if self.plotDataIsCoastal[plotIndex] == true then
				return
			elseif self.plotDataIsNextToCoast[plotIndex] == true then
				return
			end
		elseif self.AvoidLandTwoOrMorePlotsInland[wn] == true then
			if self.plotDataIsCoastal[plotIndex] == false and self.plotDataIsNextToCoast[plotIndex] == false then
				return
			end
		end
	end
	-- Core Tile
	if self.CoreTileCanBeAnyPlotType[wn] == false then
		local plotType = plot:GetPlotType()
		if plotType == PlotTypes.PLOT_LAND and self.CoreTileCanBeFlatland[wn] == true then
			-- Continue
		elseif plotType == PlotTypes.PLOT_HILLS and self.CoreTileCanBeHills[wn] == true then
			-- Continue
		elseif plotType == PlotTypes.PLOT_MOUNTAIN and self.CoreTileCanBeMountain[wn] == true then
			-- Continue
		elseif plotType == PlotTypes.PLOT_OCEAN and self.CoreTileCanBeOcean[wn] == true then
			-- Continue
		else -- Plot type does not match an eligible type, reject this plot.
			return
		end
	end
	if self.CoreTileCanBeAnyTerrainType[wn] == false then
		local terrainType = plot:GetTerrainType()
		if terrainType == TerrainTypes.TERRAIN_GRASS and self.CoreTileCanBeGrass[wn] == true then
			-- Continue
		elseif terrainType == TerrainTypes.TERRAIN_PLAINS and self.CoreTileCanBePlains[wn] == true then
			-- Continue
		elseif terrainType == TerrainTypes.TERRAIN_DESERT and self.CoreTileCanBeDesert[wn] == true then
			-- Continue
		elseif terrainType == TerrainTypes.TERRAIN_TUNDRA and self.CoreTileCanBeTundra[wn] == true then
			-- Continue
		elseif terrainType == TerrainTypes.TERRAIN_SNOW and self.CoreTileCanBeSnow[wn] == true then
			-- Continue
		elseif terrainType == TerrainTypes.TERRAIN_COAST and self.CoreTileCanBeShallowWater[wn] == true then
			-- Continue
		elseif terrainType == TerrainTypes.TERRAIN_OCEAN and self.CoreTileCanBeDeepWater[wn] == true then
			-- Continue
		else -- Terrain type does not match an eligible type, reject this plot.
			return
		end
	end
	if self.CoreTileCanBeAnyFeatureType[wn] == false then
		local featureType = plot:GetFeatureType()
		if featureType == FeatureTypes.NO_FEATURE and self.CoreTileCanBeNoFeature[wn] == true then
			-- Continue
		elseif featureType == FeatureTypes.FEATURE_FOREST and self.CoreTileCanBeForest[wn] == true then
			-- Continue
		elseif featureType == FeatureTypes.FEATURE_JUNGLE and self.CoreTileCanBeJungle[wn] == true then
			-- Continue
		elseif featureType == FeatureTypes.FEATURE_OASIS and self.CoreTileCanBeOasis[wn] == true then
			-- Continue
		elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS and self.CoreTileCanBeFloodPlains[wn] == true then
			-- Continue
		elseif featureType == FeatureTypes.FEATURE_MARSH and self.CoreTileCanBeMarsh[wn] == true then
			-- Continue
		elseif featureType == FeatureTypes.FEATURE_ICE and self.CoreTileCanBeIce[wn] == true then
			-- Continue
		elseif featureType == self.feature_atoll and self.CoreTileCanBeAtoll[wn] == true then
			-- Continue
		else -- Feature type does not match an eligible type, reject this plot.
			return
		end
	end
	-- Adjacent Tiles: Plot Types
	if self.AdjacentTilesCareAboutPlotTypes[wn] == true then
		local iNumAnyLand, iNumFlatland, iNumHills, iNumMountain, iNumHillsPlusMountains, iNumOcean = 0, 0, 0, 0, 0, 0;
		for loop, direction in ipairs(self.direction_types) do
			local adjPlot = Map.PlotDirection(x, y, direction)
			local plotType = adjPlot:GetPlotType();
			if plotType == PlotTypes.PLOT_OCEAN then
				iNumOcean = iNumOcean + 1;
			else
				iNumAnyLand = iNumAnyLand + 1;
				if plotType == PlotTypes.PLOT_LAND then
					iNumFlatland = iNumFlatland + 1;
				else
					iNumHillsPlusMountains = iNumHillsPlusMountains + 1;
					if plotType == PlotTypes.PLOT_HILLS then
						iNumHills = iNumHills + 1;
					else
						iNumMountain = iNumMountain + 1;
					end
				end
			end
		end
		if iNumAnyLand > 0 and self.AdjacentTilesAvoidAnyland[wn] == true then
			return
		end
		-- Require
		if self.AdjacentTilesRequireFlatland[wn] == true then
			if iNumFlatland < self.RequiredNumberOfAdjacentFlatland[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireHills[wn] == true then
			if iNumHills < self.RequiredNumberOfAdjacentHills[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireMountain[wn] == true then
			if iNumMountain < self.RequiredNumberOfAdjacentMountain[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireHillsPlusMountains[wn] == true then
			if iNumHillsPlusMountains < self.RequiredNumberOfAdjacentHillsPlusMountains[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireOcean[wn] == true then
			if iNumOcean < self.RequiredNumberOfAdjacentOcean[wn] then
				return
			end
		end
		-- Avoid
		if self.AdjacentTilesAvoidFlatland[wn] == true then
			if iNumFlatland > self.MaximumAllowedAdjacentFlatland[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidHills[wn] == true then
			if iNumHills > self.MaximumAllowedAdjacentHills[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidMountain[wn] == true then
			if iNumMountain > self.MaximumAllowedAdjacentMountain[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidHillsPlusMountains[wn] == true then
			if iNumHillsPlusMountains > self.MaximumAllowedAdjacentHillsPlusMountains[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidOcean[wn] == true then
			if iNumOcean > self.MaximumAllowedAdjacentOcean[wn] then
				return
			end
		end
	end
	-- Adjacent Tiles: Terrain Types
	if self.AdjacentTilesCareAboutTerrainTypes[wn] == true then
		local iNumGrass, iNumPlains, iNumDesert, iNumTundra, iNumSnow, iNumShallowWater, iNumDeepWater = 0, 0, 0, 0, 0, 0, 0;
		for loop, direction in ipairs(self.direction_types) do
			local adjPlot = Map.PlotDirection(x, y, direction)
			local terrainType = adjPlot:GetTerrainType();
			if terrainType == TerrainTypes.TERRAIN_GRASS then
				iNumGrass = iNumGrass + 1;
			elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
				iNumPlains = iNumPlains + 1;
			elseif terrainType == TerrainTypes.TERRAIN_DESERT then
				iNumDesert = iNumDesert + 1;
			elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
				iNumTundra = iNumTundra + 1;
			elseif terrainType == TerrainTypes.TERRAIN_SNOW then
				iNumSnow = iNumSnow + 1;
			elseif terrainType == TerrainTypes.TERRAIN_COAST then
				iNumShallowWater = iNumShallowWater + 1;
			elseif terrainType == TerrainTypes.TERRAIN_OCEAN then
				iNumDeepWater = iNumDeepWater + 1;
			end
		end
		-- Require
		if self.AdjacentTilesRequireGrass[wn] == true then
			if iNumGrass < self.RequiredNumberOfAdjacentGrass[wn] then
				return
			end
		end
		if self.AdjacentTilesRequirePlains[wn] == true then
			if iNumPlains < self.RequiredNumberOfAdjacentPlains[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireDesert[wn] == true then
			if iNumDesert < self.RequiredNumberOfAdjacentDesert[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireTundra[wn] == true then
			if iNumTundra < self.RequiredNumberOfAdjacentTundra[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireSnow[wn] == true then
			if iNumSnow < self.RequiredNumberOfAdjacentSnow[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireShallowWater[wn] == true then
			if iNumShallowWater < self.RequiredNumberOfAdjacentShallowWater[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireGrass[wn] == true then
			if iNumDeepWater < self.RequiredNumberOfAdjacentDeepWater[wn] then
				return
			end
		end
		-- Avoid
		if self.AdjacentTilesAvoidGrass[wn] == true then
			if iNumGrass > self.MaximumAllowedAdjacentGrass[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidPlains[wn] == true then
			if iNumPlains > self.MaximumAllowedAdjacentPlains[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidDesert[wn] == true then
			if iNumDesert > self.MaximumAllowedAdjacentDesert[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidTundra[wn] == true then
			if iNumTundra > self.MaximumAllowedAdjacentTundra[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidSnow[wn] == true then
			if iNumSnow > self.MaximumAllowedAdjacentSnow[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidShallowWater[wn] == true then
			if iNumShallowWater > self.MaximumAllowedAdjacentShallowWater[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidDeepWater[wn] == true then
			if iNumDeepWater > self.MaximumAllowedAdjacentDeepWater[wn] then
				return
			end
		end
	end
	-- Adjacent Tiles: Feature Types
	if self.AdjacentTilesCareAboutFeatureTypes[wn] == true then
		local iNumNoFeature, iNumForest, iNumJungle, iNumOasis, iNumFloodPlains, iNumMarsh, iNumIce, iNumAtoll = 0, 0, 0, 0, 0, 0, 0, 0;
		for loop, direction in ipairs(self.direction_types) do
			local adjPlot = Map.PlotDirection(x, y, direction)
			local featureType = adjPlot:GetFeatureType();
			if featureType == FeatureTypes.NO_FEATURE then
				iNumNoFeature = iNumNoFeature + 1;
			elseif featureType == FeatureTypes.FEATURE_FOREST then
				iNumForest = iNumForest + 1;
			elseif featureType == FeatureTypes.FEATURE_JUNGLE then
				iNumJungle = iNumJungle + 1;
			elseif featureType == FeatureTypes.FEATURE_OASIS then
				iNumOasis = iNumOasis + 1;
			elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
				iNumFloodPlains = iNumFloodPlains + 1;
			elseif featureType == FeatureTypes.FEATURE_MARSH then
				iNumMarsh = iNumMarsh + 1;
			elseif featureType == FeatureTypes.FEATURE_ICE then
				iNumIce = iNumIce + 1;
			elseif featureType == self.feature_atoll then
				iNumAtoll = iNumAtoll + 1;
			end
		end
		-- Require
		if self.AdjacentTilesRequireNoFeature[wn] == true then
			if iNumNoFeature < self.RequiredNumberOfAdjacentNoFeature[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireForest[wn] == true then
			if iNumForest < self.RequiredNumberOfAdjacentForest[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireJungle[wn] == true then
			if iNumJungle < self.RequiredNumberOfAdjacentJungle[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireOasis[wn] == true then
			if iNumOasis < self.RequiredNumberOfAdjacentOasis[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireFloodPlains[wn] == true then
			if iNumFloodPlains < self.RequiredNumberOfAdjacentFloodPlains[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireMarsh[wn] == true then
			if iNumMarsh < self.RequiredNumberOfAdjacentMarsh[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireIce[wn] == true then
			if iNumIce < self.RequiredNumberOfAdjacentIce[wn] then
				return
			end
		end
		if self.AdjacentTilesRequireAtoll[wn] == true then
			if iNumAtoll < self.RequiredNumberOfAdjacentAtoll[wn] then
				return
			end
		end
		-- Avoid
		if self.AdjacentTilesAvoidNoFeature[wn] == true then
			if iNumNoFeature > self.MaximumAllowedAdjacentNoFeature[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidForest[wn] == true then
			if iNumForest > self.MaximumAllowedAdjacentForest[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidJungle[wn] == true then
			if iNumJungle > self.MaximumAllowedAdjacentJungle[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidOasis[wn] == true then
			if iNumOasis > self.MaximumAllowedAdjacentOasis[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidFloodPlains[wn] == true then
			if iNumFloodPlains > self.MaximumAllowedAdjacentFloodPlains[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidMarsh[wn] == true then
			if iNumMarsh > self.MaximumAllowedAdjacentMarsh[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidIce[wn] == true then
			if iNumIce > self.MaximumAllowedAdjacentIce[wn] then
				return
			end
		end
		if self.AdjacentTilesAvoidAtoll[wn] == true then
			if iNumAtoll > self.MaximumAllowedAdjacentAtoll[wn] then
				return
			end
		end
	end

	-- This plot has survived all tests and is eligible to host this wonder type.
	local iW, iH = Map.GetGridSize();
	local plotIndex = y * iW + x + 1;
	table.insert(self.eligibility_lists[wn], plotIndex);
end
------------------------------------------------------------------------------
function AssignStartingPlots:GenerateLocalVersionsOfDataFromXML()
	for nw_number, rn in ipairs(self.xml_row_numbers) do
		table.insert(self.EligibilityMethodNumber, GameInfo.Natural_Wonder_Placement[rn].EligibilityMethodNumber);
		table.insert(self.OccurrenceFrequency, GameInfo.Natural_Wonder_Placement[rn].OccurrenceFrequency);		
		table.insert(self.RequireBiggestLandmass, GameInfo.Natural_Wonder_Placement[rn].RequireBiggestLandmass);
		--table.insert(self.AvoidBiggestLandmass, GameInfo.Natural_Wonder_Placement[rn].AvoidBiggestLandmass);
		table.insert(self.AvoidBiggestLandmass, false);
		table.insert(self.RequireFreshWater, GameInfo.Natural_Wonder_Placement[rn].RequireFreshWater);
		table.insert(self.AvoidFreshWater, GameInfo.Natural_Wonder_Placement[rn].AvoidFreshWater);
		table.insert(self.LandBased, GameInfo.Natural_Wonder_Placement[rn].LandBased);
		table.insert(self.RequireLandAdjacentToOcean, GameInfo.Natural_Wonder_Placement[rn].RequireLandAdjacentToOcean);
		table.insert(self.AvoidLandAdjacentToOcean, GameInfo.Natural_Wonder_Placement[rn].AvoidLandAdjacentToOcean);
		table.insert(self.RequireLandOnePlotInland, GameInfo.Natural_Wonder_Placement[rn].RequireLandOnePlotInland);
		table.insert(self.AvoidLandOnePlotInland, GameInfo.Natural_Wonder_Placement[rn].AvoidLandOnePlotInland);
		table.insert(self.RequireLandTwoOrMorePlotsInland, GameInfo.Natural_Wonder_Placement[rn].RequireLandTwoOrMorePlotsInland);
		table.insert(self.AvoidLandTwoOrMorePlotsInland, GameInfo.Natural_Wonder_Placement[rn].AvoidLandTwoOrMorePlotsInland);

		table.insert(self.CoreTileCanBeAnyPlotType, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeAnyPlotType);
		table.insert(self.CoreTileCanBeFlatland, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeFlatland);
		table.insert(self.CoreTileCanBeHills, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeHills);
		table.insert(self.CoreTileCanBeMountain, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeMountain);
		table.insert(self.CoreTileCanBeOcean, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeOcean);
		table.insert(self.CoreTileCanBeAnyTerrainType, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeAnyTerrainType);
		table.insert(self.CoreTileCanBeGrass, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeGrass);
		table.insert(self.CoreTileCanBePlains, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBePlains);
		table.insert(self.CoreTileCanBeDesert, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeDesert);
		table.insert(self.CoreTileCanBeTundra, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeTundra);
		table.insert(self.CoreTileCanBeSnow, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeSnow);
		table.insert(self.CoreTileCanBeShallowWater, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeShallowWater);
		table.insert(self.CoreTileCanBeDeepWater, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeDeepWater);
		table.insert(self.CoreTileCanBeAnyFeatureType, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeAnyFeatureType);
		table.insert(self.CoreTileCanBeNoFeature, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeNoFeature);
		table.insert(self.CoreTileCanBeForest, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeForest);
		table.insert(self.CoreTileCanBeJungle, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeJungle);
		table.insert(self.CoreTileCanBeOasis, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeOasis);
		table.insert(self.CoreTileCanBeFloodPlains, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeFloodPlains);
		table.insert(self.CoreTileCanBeMarsh, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeMarsh);
		table.insert(self.CoreTileCanBeIce, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeIce);
		table.insert(self.CoreTileCanBeAtoll, GameInfo.Natural_Wonder_Placement[rn].CoreTileCanBeAtoll);

		table.insert(self.AdjacentTilesCareAboutPlotTypes, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesCareAboutPlotTypes);
		table.insert(self.AdjacentTilesAvoidAnyland, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidAnyland);
		table.insert(self.AdjacentTilesRequireFlatland, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireFlatland);
		table.insert(self.RequiredNumberOfAdjacentFlatland, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentFlatland);
		table.insert(self.AdjacentTilesRequireHills, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireHills);
		table.insert(self.RequiredNumberOfAdjacentHills, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentHills);
		table.insert(self.AdjacentTilesRequireMountain, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireMountain);
		table.insert(self.RequiredNumberOfAdjacentMountain, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentMountain);
		table.insert(self.AdjacentTilesRequireHillsPlusMountains, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireHillsPlusMountains);
		table.insert(self.RequiredNumberOfAdjacentHillsPlusMountains, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentHillsPlusMountains);
		table.insert(self.AdjacentTilesRequireOcean, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireOcean);
		table.insert(self.RequiredNumberOfAdjacentOcean, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentOcean);
		table.insert(self.AdjacentTilesAvoidFlatland, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidFlatland);
		table.insert(self.MaximumAllowedAdjacentFlatland, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentFlatland);
		table.insert(self.AdjacentTilesAvoidHills, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidHills);
		table.insert(self.MaximumAllowedAdjacentHills, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentHills);
		table.insert(self.AdjacentTilesAvoidMountain, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidMountain);
		table.insert(self.MaximumAllowedAdjacentMountain, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentMountain);
		table.insert(self.AdjacentTilesAvoidHillsPlusMountains, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidHillsPlusMountains);
		table.insert(self.MaximumAllowedAdjacentHillsPlusMountains, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentHillsPlusMountains);
		table.insert(self.AdjacentTilesAvoidOcean, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidOcean);
		table.insert(self.MaximumAllowedAdjacentOcean, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentOcean);

		table.insert(self.AdjacentTilesCareAboutTerrainTypes, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesCareAboutTerrainTypes);
		table.insert(self.AdjacentTilesRequireGrass, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireGrass);
		table.insert(self.RequiredNumberOfAdjacentGrass, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentGrass);
		table.insert(self.AdjacentTilesRequirePlains, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequirePlains);
		table.insert(self.RequiredNumberOfAdjacentPlains, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentPlains);
		table.insert(self.AdjacentTilesRequireDesert, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireDesert);
		table.insert(self.RequiredNumberOfAdjacentDesert, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentDesert);
		table.insert(self.AdjacentTilesRequireTundra, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireTundra);
		table.insert(self.RequiredNumberOfAdjacentTundra, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentTundra);
		table.insert(self.AdjacentTilesRequireSnow, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireSnow);
		table.insert(self.RequiredNumberOfAdjacentSnow, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentSnow);
		table.insert(self.AdjacentTilesRequireShallowWater, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireShallowWater);
		table.insert(self.RequiredNumberOfAdjacentShallowWater, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentShallowWater);
		table.insert(self.AdjacentTilesRequireDeepWater, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireDeepWater);
		table.insert(self.RequiredNumberOfAdjacentDeepWater, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentDeepWater);
		table.insert(self.AdjacentTilesAvoidGrass, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidGrass);
		table.insert(self.MaximumAllowedAdjacentGrass, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentGrass);
		table.insert(self.AdjacentTilesAvoidPlains, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidPlains);
		table.insert(self.MaximumAllowedAdjacentPlains, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentPlains);
		table.insert(self.AdjacentTilesAvoidDesert, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidDesert);
		table.insert(self.MaximumAllowedAdjacentDesert, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentDesert);
		table.insert(self.AdjacentTilesAvoidTundra, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidTundra);
		table.insert(self.MaximumAllowedAdjacentTundra, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentTundra);
		table.insert(self.AdjacentTilesAvoidSnow, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidSnow);
		table.insert(self.MaximumAllowedAdjacentSnow, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentSnow);
		table.insert(self.AdjacentTilesAvoidShallowWater, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidShallowWater);
		table.insert(self.MaximumAllowedAdjacentShallowWater, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentShallowWater);
		table.insert(self.AdjacentTilesAvoidDeepWater, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidDeepWater);
		table.insert(self.MaximumAllowedAdjacentDeepWater, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentDeepWater);
		
		table.insert(self.AdjacentTilesCareAboutFeatureTypes, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesCareAboutFeatureTypes);
		table.insert(self.AdjacentTilesRequireNoFeature, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireNoFeature);
		table.insert(self.RequiredNumberOfAdjacentNoFeature, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentNoFeature);
		table.insert(self.AdjacentTilesRequireForest, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireForest);
		table.insert(self.RequiredNumberOfAdjacentForest, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentForest);
		table.insert(self.AdjacentTilesRequireJungle, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireJungle);
		table.insert(self.RequiredNumberOfAdjacentJungle, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentJungle);
		table.insert(self.AdjacentTilesRequireOasis, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireOasis);
		table.insert(self.RequiredNumberOfAdjacentOasis, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentOasis);
		table.insert(self.AdjacentTilesRequireFloodPlains, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireFloodPlains);
		table.insert(self.RequiredNumberOfAdjacentFloodPlains, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentFloodPlains);
		table.insert(self.AdjacentTilesRequireMarsh, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireMarsh);
		table.insert(self.RequiredNumberOfAdjacentMarsh, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentMarsh);
		table.insert(self.AdjacentTilesRequireIce, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireIce);
		table.insert(self.RequiredNumberOfAdjacentIce, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentIce);
		table.insert(self.AdjacentTilesRequireAtoll, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesRequireAtoll);
		table.insert(self.RequiredNumberOfAdjacentAtoll, GameInfo.Natural_Wonder_Placement[rn].RequiredNumberOfAdjacentAtoll);
		table.insert(self.AdjacentTilesAvoidNoFeature, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidNoFeature);
		table.insert(self.MaximumAllowedAdjacentNoFeature, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentNoFeature);
		table.insert(self.AdjacentTilesAvoidForest, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidForest);
		table.insert(self.MaximumAllowedAdjacentForest, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentForest);
		table.insert(self.AdjacentTilesAvoidJungle, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidJungle);
		table.insert(self.MaximumAllowedAdjacentJungle, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentJungle);
		table.insert(self.AdjacentTilesAvoidOasis, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidOasis);
		table.insert(self.MaximumAllowedAdjacentOasis, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentOasis);
		table.insert(self.AdjacentTilesAvoidFloodPlains, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidFloodPlains);
		table.insert(self.MaximumAllowedAdjacentFloodPlains, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentFloodPlains);
		table.insert(self.AdjacentTilesAvoidMarsh, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidMarsh);
		table.insert(self.MaximumAllowedAdjacentMarsh, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentMarsh);
		table.insert(self.AdjacentTilesAvoidIce, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidIce);
		table.insert(self.MaximumAllowedAdjacentIce, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentIce);
		table.insert(self.AdjacentTilesAvoidAtoll, GameInfo.Natural_Wonder_Placement[rn].AdjacentTilesAvoidAtoll);
		table.insert(self.MaximumAllowedAdjacentAtoll, GameInfo.Natural_Wonder_Placement[rn].MaximumAllowedAdjacentAtoll);
		
		table.insert(self.TileChangesMethodNumber, GameInfo.Natural_Wonder_Placement[rn].TileChangesMethodNumber);
		table.insert(self.ChangeCoreTileToMountain, GameInfo.Natural_Wonder_Placement[rn].ChangeCoreTileToMountain);
		table.insert(self.ChangeCoreTileToFlatland, GameInfo.Natural_Wonder_Placement[rn].ChangeCoreTileToFlatland);
		table.insert(self.ChangeCoreTileTerrainToGrass, GameInfo.Natural_Wonder_Placement[rn].ChangeCoreTileTerrainToGrass);
		table.insert(self.ChangeCoreTileTerrainToPlains, GameInfo.Natural_Wonder_Placement[rn].ChangeCoreTileTerrainToPlains);
		table.insert(self.SetAdjacentTilesToShallowWater, GameInfo.Natural_Wonder_Placement[rn].SetAdjacentTilesToShallowWater);
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:GenerateNaturalWondersCandidatePlotLists()
	-- This function scans the map for eligible sites for all "Natural Wonders" Features.
	local iW, iH = Map.GetGridSize();
	-- Set up Atolls ID.
	for thisFeature in GameInfo.Features() do
		if thisFeature.Type == "FEATURE_ATOLL" then
			self.feature_atoll = thisFeature.ID;
		end
	end
	-- Set up Landmass check for wonders that avoid the biggest landmass when the world has oceans.
	local biggest_landmass = Map.FindBiggestArea(false)
	self.iBiggestLandmassID = biggest_landmass:GetID()
	local biggest_ocean = Map.FindBiggestArea(true)
	local iNumBiggestOceanPlots = 0;
	if biggest_ocean ~= nil then
		iNumBiggestOceanPlots = biggest_ocean:GetNumTiles()
	end
	if iNumBiggestOceanPlots > (iW * iH) / 4 then
		self.bWorldHasOceans = true;
	else
		self.bWorldHasOceans = false;
	end
	-- Read the XML data. Count the number of wonders.
	for row in GameInfo.Natural_Wonder_Placement() do
		self.iNumNW = self.iNumNW + 1;
	end
	if self.iNumNW == 0 then
		print("-"); print("*** No Natural Wonders found in Civ5Features.xml! ***"); print("-");
		return
	end
	-- Set up NW IDs.
	self.wonder_list = table.fill(-1, self.iNumNW);
	local next_wonder_number = 1;
	for row in GameInfo.Features() do
		if (row.NaturalWonder == true) then
			self.wonder_list[next_wonder_number] = row.Type;
			next_wonder_number = next_wonder_number + 1;
		end
	end
	-- Set up Eligibility Lists.
	for i = 1, self.iNumNW do
		table.insert(self.eligibility_lists, {});
	end
	-- Set up Row Numbers.
	for nw_number, nw_type in ipairs(self.wonder_list) do
		-- Obtain the correct Row number from the xml Placement table.
		local row_number;
		for row in GameInfo.Natural_Wonder_Placement() do
			if row.NaturalWonderType == nw_type then
				row_number = row.ID;
			end
		end
		table.insert(self.xml_row_numbers, row_number);
	end
	-- Load Data from XML.
	self:GenerateLocalVersionsOfDataFromXML()
	-- Main Loop
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			if self:ExamineCandidatePlotForNaturalWondersEligibility(x, y) == true then
				-- Plot has passed checks applicable to all NW types. Move on to specific checks.
				for nw_number, row_number in ipairs(self.xml_row_numbers) do
					self:CanBeThisNaturalWonderType(x, y, nw_number, row_number)
				end
			end
		end
	end
	-- Eligibility will affect which NWs can be used, and number of candidates will affect placement order.
	local iCanBeWonder = {};
	for loop = 1, self.iNumNW do
		table.insert(iCanBeWonder, table.maxn(self.eligibility_lists[loop]));
		--print("Wonder #", loop, "has", iCanBeWonder[loop], "candidate plots.");
	end
	-- Sort the wonders with fewest candidates listed first.
	local NW_eligibility_order, NW_eligibility_unsorted, NW_eligibility_sorted, NW_remaining_to_sort_by_occurrence = {}, {}, {}, {}; 
	for loop = 1, self.iNumNW do
		if iCanBeWonder[loop] > 0 then -- This wonder has eligible sites.
			table.insert(NW_eligibility_unsorted, {loop, iCanBeWonder[loop]});
			table.insert(NW_eligibility_sorted, iCanBeWonder[loop]);
		end
	end
	table.sort(NW_eligibility_sorted);
	
	-- Match each sorted eligibility count to the matching unsorted NW number and record in sequence.
	for NW_order = 1, self.iNumNW do
		for loop, data_pair in ipairs(NW_eligibility_unsorted) do
			local unsorted_count = data_pair[2];
			if NW_eligibility_sorted[NW_order] == unsorted_count then
				local unsorted_NW_num = data_pair[1];
				table.insert(NW_eligibility_order, unsorted_NW_num);
				table.insert(NW_remaining_to_sort_by_occurrence, unsorted_NW_num);
				table.remove(NW_eligibility_unsorted, loop);
				break
			end
		end
	end
	
	-- Debug printout of natural wonder candidate plot lists
	print("-"); print("-"); print("--- Number of Candidate Plots on the map for Natural Wonders ---"); print("-");
	for loop = 1, self.iNumNW do
		print("-", iCanBeWonder[loop], "candidates for", self.wonder_list[loop]);
	end
	print("-"); print("--- End of candidates readout for Natural Wonders ---"); print("-");	
	--

	-- Read in from the XML for each eligible wonder, obtaining OccurrenceFrequency data.
	--
	-- Set up pool of entries and enter an entry for each level of OccurrenceFrequency for each eligible NW.
	local NW_candidate_pool_entries, NW_final_selections = {}, {};
	for loop, iNaturalWonderNumber in ipairs(NW_eligibility_order) do
		local nw_type = self.wonder_list[iNaturalWonderNumber];
		local row_number;
		for row in GameInfo.Natural_Wonder_Placement() do
			if row.NaturalWonderType == nw_type then
				row_number = row.ID;
			end
		end
		local iFrequency = GameInfo.Natural_Wonder_Placement[row_number].OccurrenceFrequency;
		--
		--print("-"); print("NW#", iNaturalWonderNumber, "of ID#", row_number, "has OccurrenceFrequency of:", iFrequency);
		--
		for entry = 1, iFrequency do
			table.insert(NW_candidate_pool_entries, iNaturalWonderNumber);
		end
	end
	--PrintContentsOfTable(NW_candidate_pool_entries)
	local iNumNWtoProcess = table.maxn(NW_remaining_to_sort_by_occurrence)
	if iNumNWtoProcess > 0 then
		-- Choose at random from the entry pool to select the final order of operations for NW placement.
		local entry_count = table.maxn(NW_candidate_pool_entries)
		for loop = 1, iNumNWtoProcess do
			local current_NW_selected = false;
			local current_attempt_to_select = 0;
			while current_NW_selected == false do
				if current_attempt_to_select > 1000 then
					break
				end
				current_attempt_to_select = current_attempt_to_select + 1;
				--print("Selection for #", loop, "NW to be assigned -- ATTEMPT #", current_attempt_to_select);
				local diceroll = 1 + Map.Rand(entry_count, "Checking a random pool entry for NW assignment - Lua");
				local possible_selection = NW_candidate_pool_entries[diceroll];
				local bFoundValue, iNumTimesFoundValue, table_of_indices = IdentifyTableIndex(NW_remaining_to_sort_by_occurrence, possible_selection)
				if bFoundValue then
					table.insert(NW_final_selections, possible_selection)
					table.remove(NW_remaining_to_sort_by_occurrence, table_of_indices[1])
					--print("NW#", possible_selection, "chosen.");
					current_NW_selected = true;
				end
			end
		end
	end
	
	if NW_final_selections ~= nil then
		return NW_final_selections;
	else
		print("ERROR: Failed to produce final selection list of NWs!");
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:AttemptToPlaceNaturalWonder(wonder_number, row_number)
	-- Attempts to place a specific natural wonder. The "wonder_number" is a Lua index while "row_number" is an XML index.
	local iW, iH = Map.GetGridSize();
	local feature_type_to_place;
	for thisFeature in GameInfo.Features() do
		if thisFeature.Type == self.wonder_list[wonder_number] then
			feature_type_to_place = thisFeature.ID;
			break
		end
	end
	local temp_table = self.eligibility_lists[wonder_number];
	local candidate_plot_list = GetShuffledCopyOfTable(temp_table)
	for loop, plotIndex in ipairs(candidate_plot_list) do
		if self.naturalWondersData[plotIndex] == 0 then -- No collision with civ start or other NW, so place wonder here!
			local x = (plotIndex - 1) % iW;
			local y = (plotIndex - x - 1) / iW;
			local plot = Map.GetPlot(x, y);
			-- If called for, force the local terrain to conform to what the wonder needs.
			local method_number = GameInfo.Natural_Wonder_Placement[row_number].TileChangesMethodNumber;
			if method_number ~= -1 then
				-- Custom method for tile changes needed by this wonder.
				NWCustomPlacement(x, y, row_number, method_number)
			else
				-- Check the XML data for any standard type tile changes, execute any that are indicated.
				if GameInfo.Natural_Wonder_Placement[row_number].ChangeCoreTileToMountain == true then
					if not plot:IsMountain() then
						plot:SetPlotType(PlotTypes.PLOT_MOUNTAIN, false, false);
					end
				elseif GameInfo.Natural_Wonder_Placement[row_number].ChangeCoreTileToFlatland == true then
					if plot:GetPlotType() ~= PlotTypes.PLOT_LAND then
						plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
					end
				end
				if GameInfo.Natural_Wonder_Placement[row_number].ChangeCoreTileTerrainToGrass == true then
					if plot:GetTerrainType() ~= TerrainTypes.TERRAIN_GRASS then
						plot:SetTerrainType(TerrainTypes.TERRAIN_GRASS, false, false);
					end
				elseif GameInfo.Natural_Wonder_Placement[row_number].ChangeCoreTileTerrainToPlains == true then
					if plot:GetTerrainType() ~= TerrainTypes.TERRAIN_PLAINS then
						plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, false);
					end
				end
				if GameInfo.Natural_Wonder_Placement[row_number].SetAdjacentTilesToShallowWater == true then
					for loop, direction in ipairs(self.direction_types) do
						local adjPlot = Map.PlotDirection(x, y, direction)
						if adjPlot:GetTerrainType() ~= TerrainTypes.TERRAIN_COAST then
							adjPlot:SetTerrainType(TerrainTypes.TERRAIN_COAST, false, false)
						end
					end
				end
			end
			-- Now place this wonder and record the placement.
			plot:SetFeatureType(feature_type_to_place)
			table.insert(self.placed_natural_wonder, wonder_number);
			self:PlaceResourceImpact(x, y, 6, math.floor(iH / 5))	-- Natural Wonders layer
			self:PlaceResourceImpact(x, y, 1, 1)					-- Strategic layer
			self:PlaceResourceImpact(x, y, 2, 1)					-- Luxury layer
			self:PlaceResourceImpact(x, y, 3, 1)					-- Bonus layer
			self:PlaceResourceImpact(x, y, 5, 2)					-- City State layer
			self:PlaceResourceImpact(x, y, 7, 1)					-- Marble layer
			local plotIndex = y * iW + x + 1;
			self.playerCollisionData[plotIndex] = true;				-- Record exact plot of wonder in the collision list.

			-- MOD.Barathor: Fixed: Added a check for the Great Barrier Reef being placed.  If so, it appropriately applies impact values to its second tile to avoid buggy collisions with water resources.
			-- MOD.Barathor: Start
			if (self.wonder_list[wonder_number] == "FEATURE_REEF") then
				--print("Great Barrier Reef placed... applying impact values to its southeast tile as well.")
				local SEPlot = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_SOUTHEAST)
				local southeastX = SEPlot:GetX()
				local southeastY = SEPlot:GetY()
				self:PlaceResourceImpact(southeastX, southeastY, 1, 1)		-- Strategic layer
				self:PlaceResourceImpact(southeastX, southeastY, 2, 1)		-- Luxury layer
				self:PlaceResourceImpact(southeastX, southeastY, 3, 1)		-- Bonus layer
				local SEplotIndex = southeastY * iW + southeastX + 1
				self.playerCollisionData[SEplotIndex] = true				-- Record exact plot of wonder in the collision list.
			end
			-- MOD.Barathor: End

			--
			--print("- Placed ".. self.wonder_list[wonder_number].. " in Plot", x, y);
			--
			return true
		end
	end
	-- If reached here, this wonder was unable to be placed because all candidates are too close to an already-placed NW.
	return false
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceNaturalWonders(wonderargs)
	local NW_eligibility_order = self:GenerateNaturalWondersCandidatePlotLists()
	local iNumNWCandidates = table.maxn(NW_eligibility_order);
	if iNumNWCandidates == 0 then
		print("No Natural Wonders placed, no eligible sites found for any of them.");
		return
	end
	
	--[[ Debug printout
	print("-"); print("--- Readout of NW Assignment Priority ---");
	for print_loop, order in ipairs(NW_eligibility_order) do
		print("NW Assignment Priority#", print_loop, "goes to NW#", order);
	end
	print("-"); print("-"); ]]--
	
	--set wonder args
	local wonderargs = wonderargs or 15;

	-- Determine how many NWs to attempt to place. Target is regulated per map size.
	-- The final number cannot exceed the number the map has locations to support.
	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 2,
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 3,
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 4,
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 5,
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 6,
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 7
		}

	local target_number = worldsizes[Map.GetWorldSize()];
	
	print("######################");
	print("WonderArgs: ", wonderargs.wonderamt);
	print("######################");

	if wonderargs.wonderamt ~= 14 then
		target_number = wonderargs.wonderamt;
	end

	local iNumNWtoPlace = math.min(target_number, iNumNWCandidates);
	local selected_NWs, fallback_NWs = {}, {};
	for loop, NW in ipairs(NW_eligibility_order) do
		if loop <= iNumNWtoPlace then
			table.insert(selected_NWs, NW);
		else
			table.insert(fallback_NWs, NW);
		end
	end
	
	--[[
	print("-");
	for loop, NW in ipairs(selected_NWs) do
		print("Natural Wonder #", NW, "has been selected for placement.");
	end
	print("-");
	for loop, NW in ipairs(fallback_NWs) do
		print("Natural Wonder #", NW, "has been selected as fallback.");
	end
	print("-");
	--
	print("--- Placing Natural Wonders! ---");
	]]--
	
	-- Place the NWs
	local iNumPlaced = 0;
	for loop, nw_number in ipairs(selected_NWs) do
		local nw_type = self.wonder_list[nw_number];
		-- Obtain the correct Row number from the xml Placement table.
		local row_number;
		for row in GameInfo.Natural_Wonder_Placement() do
			if row.NaturalWonderType == nw_type then
				row_number = row.ID;
			end
		end
		-- Place the wonder, using the correct row data from XML.
		local bSuccess = self:AttemptToPlaceNaturalWonder(nw_number, row_number)
		if bSuccess then
			iNumPlaced = iNumPlaced + 1;
		end
	end
	if iNumPlaced < iNumNWtoPlace then
		for loop, nw_number in ipairs(fallback_NWs) do
			if iNumPlaced >= iNumNWtoPlace then
				break
			end
			local nw_type = self.wonder_list[nw_number];
			-- Obtain the correct Row number from the xml Placement table.
			local row_number;
			for row in GameInfo.Natural_Wonder_Placement() do
				if row.NaturalWonderType == nw_type then
					row_number = row.ID;
				end
			end
			-- Place the wonder, using the correct row data from XML.
			local bSuccess = self:AttemptToPlaceNaturalWonder(nw_number, row_number)
			if bSuccess then
				iNumPlaced = iNumPlaced + 1;
			end
		end
	end
	
	--
	if iNumPlaced >= iNumNWtoPlace then
		print("-- Placed all Natural Wonders --"); print("-"); print("-");
	else
		print("-- Not all Natural Wonders targeted got placed --"); print("-"); print("-");
	end
	--
		
end
------------------------------------------------------------------------------
-- Start of functions tied to PlaceCityStates()
------------------------------------------------------------------------------
function AssignStartingPlots:AssignCityStatesToRegionsOrToUninhabited(args)
	-- Placement methods include:
	-- 1. Assign n Per Region
	-- 2. Assign to uninhabited landmasses
	-- 3. Assign to regions with shared luxury IDs
	-- 4. Assign to low fertility regions

	-- Determine number to assign Per Region
	local iW, iH = Map.GetGridSize()
	local ratio = self.iNumCityStates / self.iNumCivs;
	if ratio > 14 then -- This is a ridiculous number of city states for a game with two civs, but we'll account for it anyway.
		self.iNumCityStatesPerRegion = 10;
	elseif ratio > 11 then -- This is a ridiculous number of cs for two or three civs.
		self.iNumCityStatesPerRegion = 8;
	elseif ratio > 8 then
		self.iNumCityStatesPerRegion = 7;
	elseif ratio > 5.7 then
		self.iNumCityStatesPerRegion = 5;
	elseif ratio > 4.35 then
		self.iNumCityStatesPerRegion = 4;
	elseif ratio > 2.7 then
		self.iNumCityStatesPerRegion = 3;
	elseif ratio > 1.35 then
		self.iNumCityStatesPerRegion = 2;
	else
		self.iNumCityStatesPerRegion = 0;
	end
	-- Assign the "Per Region" City States to their regions.
	--print("- - - - - - - - - - - - - - - - -"); print("Assigning City States to Regions");
	local current_cs_index = 1;

	if self.iNumCityStatesPerRegion > 0 then
		for current_region = 1, self.iNumCivs do
			for cs_to_assign_to_this_region = 1, self.iNumCityStatesPerRegion do
				self.city_state_region_assignments[current_cs_index] = current_region;
				--print("-"); print("City State", current_cs_index, "assigned to Region#", current_region);
				current_cs_index = current_cs_index + 1;
				self.iNumCityStatesUnassigned = self.iNumCityStatesUnassigned - 1;
			end
		end
	end

	-- Determine how many City States to place on uninhabited landmasses.
	-- Also generate lists of candidate plots from uninhabited areas.
	local iNumLandAreas = 0;
	local iNumCivLandmassPlots = 0;
	local iNumUninhabitedLandmassPlots = 0;
	local land_area_IDs = {};
	local land_area_plot_count = {};
	local land_area_plot_tables = {};
	local areas_inhabited_by_civs = {};
	local areas_too_small = {};
	local areas_uninhabited = {};
	--
	if self.method == 3 then -- Rectangular regional division spanning the entire globe, ALL plots belong to inhabited regions.
		self.iNumCityStatesUninhabited = 0;
		--print("Rectangular regional division spanning the whole world: all city states must belong to a region!");
	else -- Possibility of plots that do not belong to any civ's Region. Evaluate these plots and assign an appropriate number of City States to them.
		-- Generate list of inhabited area IDs.
		if self.method == 1 or self.method == 2 then
			for index, region_data in ipairs(self.regionData) do
				local region_areaID = region_data[5];
				if TestMembership(areas_inhabited_by_civs, region_areaID) == false then
					table.insert(areas_inhabited_by_civs, region_areaID);
				end
			end
		end
		-- Iterate through plots and, for each land area, generate a list of all its member plots
		for x = 0, iW - 1 do
			for y = 0, iH - 1 do
				local plotIndex = y * iW + x + 1;
				local plot = Map.GetPlot(x, y);
				local plotType = plot:GetPlotType()
				local terrainType = plot:GetTerrainType()
				if (plotType == PlotTypes.PLOT_LAND or plotType == PlotTypes.PLOT_HILLS) and terrainType ~= TerrainTypes.TERRAIN_SNOW then -- Habitable land plot, process it.
					local iArea = plot:GetArea();
					if self.method == 4 then -- Determine if plot is inside or outside the regional rectangle
						if (x >= self.inhabited_WestX and x <= self.inhabited_WestX + self.inhabited_Width - 1) and
						   (y >= self.inhabited_SouthY and y <= self.inhabited_SouthY + self.inhabited_Height - 1) then -- Civ-inhabited rectangle
							iNumCivLandmassPlots = iNumCivLandmassPlots + 1;
						else
							iNumUninhabitedLandmassPlots = iNumUninhabitedLandmassPlots + 1;
							if self.plotDataIsCoastal[i] == true then
								table.insert(self.uninhabited_areas_coastal_plots, i);
							else
								table.insert(self.uninhabited_areas_inland_plots, i);
							end
						end
					else -- AreaID-based method must be applied, which cannot all be done in this loop
						if TestMembership(land_area_IDs, iArea) == false then -- This plot is the first detected in its AreaID.
							iNumLandAreas = iNumLandAreas + 1;
							table.insert(land_area_IDs, iArea);
							land_area_plot_count[iArea] = 1;
							land_area_plot_tables[iArea] = {plotIndex};
						else -- This AreaID already known.
							land_area_plot_count[iArea] = land_area_plot_count[iArea] + 1;
							table.insert(land_area_plot_tables[iArea], plotIndex);
						end
					end
				end
			end
		end
		-- Complete the AreaID-based method. 
		if self.method == 1 or self.method == 2 then
			-- Obtain counts of inhabited and uninhabited plots. Identify areas too small to use for City States.
			for areaID, plot_count in pairs(land_area_plot_count) do
				if TestMembership(areas_inhabited_by_civs, areaID) == true then 
					iNumCivLandmassPlots = iNumCivLandmassPlots + plot_count;
				else
					iNumUninhabitedLandmassPlots = iNumUninhabitedLandmassPlots + plot_count;
					if plot_count < 60 then
						table.insert(areas_too_small, areaID);
					else
						table.insert(areas_uninhabited, areaID);
					end
				end
			end
			-- Now loop through all Uninhabited Areas that are large enough to use and append their plots to the candidates tables.
			for areaID, area_plot_list in pairs(land_area_plot_tables) do
				if TestMembership(areas_uninhabited, areaID) == true then 
					for loop, plotIndex in ipairs(area_plot_list) do
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local plot = Map.GetPlot(x, y);
						local terrainType = plot:GetTerrainType();
						if terrainType ~= TerrainTypes.TERRAIN_SNOW then
							if self.plotDataIsCoastal[plotIndex] == true then
								table.insert(self.uninhabited_areas_coastal_plots, plotIndex);
							else
								table.insert(self.uninhabited_areas_inland_plots, plotIndex);
							end
						end
					end
				end
			end
		end
		-- Determine the number of City States to assign to uninhabited areas.
		local uninhabited_ratio = iNumUninhabitedLandmassPlots / (iNumCivLandmassPlots + iNumUninhabitedLandmassPlots);
		local max_by_ratio = math.floor(3 * uninhabited_ratio * self.iNumCityStates);
		local max_by_method;
		if self.method == 1 then
			max_by_method = math.ceil(self.iNumCityStates / 4);
		else
			max_by_method = math.ceil(self.iNumCityStates / 2);
		end
		self.iNumCityStatesUninhabited = math.min(self.iNumCityStatesUnassigned, max_by_ratio, max_by_method);
		self.iNumCityStatesUnassigned = self.iNumCityStatesUnassigned - self.iNumCityStatesUninhabited;
	end
	--print("-"); print("City States assigned to Uninhabited Areas: ", self.iNumCityStatesUninhabited);
	-- Update the city state number.
	current_cs_index = current_cs_index + self.iNumCityStatesUninhabited;
	
	if self.iNumCityStatesUnassigned > 0 then
		-- Determine how many to place in support of regions that share their luxury type with two other regions.
		local iNumRegionsSharedLux = 0;
		local shared_lux_IDs = {};
		for resource_ID, amount_assigned_to_regions in ipairs(self.luxury_assignment_count) do
			if amount_assigned_to_regions == 3 then
				iNumRegionsSharedLux = iNumRegionsSharedLux + 3;
				table.insert(shared_lux_IDs, resource_ID);
			end
		end
		if iNumRegionsSharedLux > 0 and iNumRegionsSharedLux <= self.iNumCityStatesUnassigned then
			self.iNumCityStatesSharedLux = iNumRegionsSharedLux;
			self.iNumCityStatesLowFertility = self.iNumCityStatesUnassigned - self.iNumCityStatesSharedLux;
		else
			self.iNumCityStatesLowFertility = self.iNumCityStatesUnassigned;
		end
		--print("CS Shared Lux: ", self.iNumCityStatesSharedLux, " CS Low Fert: ", self.iNumCityStatesLowFertility);
		-- Assign remaining types to their respective regions.
		if self.iNumCityStatesSharedLux > 0 then
			for loop, res_ID in ipairs(shared_lux_IDs) do
				for loop, region_lux_data in ipairs(self.regions_sorted_by_type) do
					local this_region_res = region_lux_data[2];
					if this_region_res == res_ID then
						self.city_state_region_assignments[current_cs_index] = region_lux_data[1];
						--print("-"); print("City State", current_cs_index, "assigned to Region#", region_lux_data[1], " to compensate for Shared Luxury ID#", res_ID);
						current_cs_index = current_cs_index + 1;
						self.iNumCityStatesUnassigned = self.iNumCityStatesUnassigned - 1;
					end
				end
			end
		end
		if self.iNumCityStatesLowFertility > 0 then
			-- If more to assign than number of regions, assign per region.
			while self.iNumCityStatesUnassigned >= self.iNumCivs do
				for current_region = 1, self.iNumCivs do
					self.city_state_region_assignments[current_cs_index] = current_region;
					--print("-"); print("City State", current_cs_index, "assigned to Region#", current_region, " to compensate for Low Fertility");
					current_cs_index = current_cs_index + 1;
					self.iNumCityStatesUnassigned = self.iNumCityStatesUnassigned - 1;
				end
			end
			if self.iNumCityStatesUnassigned > 0 then
				local fert_unsorted, fert_sorted, region_list = {}, {}, {};
				for region_num = 1, self.iNumCivs do
					local area_plots = self.regionTerrainCounts[region_num][2];
					local region_fertility = self.regionData[region_num][6];
					local fertility_per_land_plot = region_fertility / area_plots;
					--print("-"); print("Region#", region_num, "AreaPlots:", area_plots, "Region Fertility:", region_fertility, "Per Plot:", fertility_per_land_plot);
					
					table.insert(fert_unsorted, {region_num, fertility_per_land_plot});
					table.insert(fert_sorted, fertility_per_land_plot);
				end
				table.sort(fert_sorted);
				for current_lowest_fertility, fert_value in ipairs(fert_sorted) do
					for loop, data_pair in ipairs(fert_unsorted) do
						local this_region_fert = data_pair[2];
						if this_region_fert == fert_value then
							local regionNum = data_pair[1];
							table.insert(region_list, regionNum);
							table.remove(fert_unsorted, loop);
							break
						end
					end
				end
				for loop = 1, self.iNumCityStatesUnassigned do
					self.city_state_region_assignments[current_cs_index] = region_list[loop];
					--print("-"); print("City State", current_cs_index, "assigned to Region#", region_list[loop], " to compensate for Low Fertility");
					current_cs_index = current_cs_index + 1;
					self.iNumCityStatesUnassigned = self.iNumCityStatesUnassigned - 1;
				end
			end
		end
	end
	
	-- Debug check
	if self.iNumCityStatesUnassigned ~= 0 then
		print("Wrong number of City States assigned at end of assignment process. This number unassigned: ", self.iNumCityStatesUnassigned);
	else
		print("All city states assigned.");
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:CanPlaceCityStateAt(x, y, area_ID, force_it, ignore_collisions)
	local iW, iH = Map.GetGridSize();
	local plot = Map.GetPlot(x, y)
	local area = plot:GetArea()
	local biggest_area = Map.FindBiggestArea(False);
	local iAreaID = biggest_area:GetID();

	if self.method == 1 then
		if area_ID ~= iAreaID then
			return false
		end
	end

	if area ~= area_ID and area_ID ~= -1 then
		return false
	end
	local plotType = plot:GetPlotType()
	if plotType == PlotTypes.PLOT_OCEAN or plotType == PlotTypes.PLOT_MOUNTAIN then
		return false
	end
	local terrainType = plot:GetTerrainType()
	if terrainType == TerrainTypes.TERRAIN_SNOW then
		return false
	end
	local featureType = plot:GetFeatureType()
	if featureType == FeatureTypes.FEATURE_OASIS then
		return false
	end
	local plotIndex = y * iW + x + 1;
	if self.cityStateData[plotIndex] > 0 and force_it == false then
		return false
	end
	if self.playerCollisionData[plotIndex] == true and ignore_collisions == false then
		--print("-"); print("City State candidate plot rejected: collided with already-placed civ or City State at", x, y);
		return false
	end
	if self.plotDataIsNextToCoast[plotIndex] == true then
		return false
	end
	return true
end
------------------------------------------------------------------------------
function AssignStartingPlots:ObtainNextSectionInRegion(incoming_west_x, incoming_south_y,
	                         incoming_width, incoming_height, iAreaID, force_it, ignore_collisions)
	--print("ObtainNextSectionInRegion called, for AreaID", iAreaID, "with SW plot at ", incoming_west_x, incoming_south_y, " Width/Height at", incoming_width, incoming_height);
	--[[ This function carves off the outermost plots in a region, checks them for City
	     State Placement eligibility, and returns 7 variables: two plot lists, the 
	     coordinates of the inner portion of the area that was not processed on this 
	     round, and a boolean indicating whether the middle of the region was reached. ]]--
	--[[ If this round does not produce a suitable placement site, another round can be 
	     executed on the remaining unprocessed plots, recursively, until the middle of
	     the region has been reached. If the entire region has no eligible plots, then
	     it is likely that something extreme is going on with the map. Then choose a plot 
	     from the outermost portion of the region at random and hope for the best. ]]--
	--
	local iW, iH = Map.GetGridSize();
	local reached_middle = false;
	if incoming_width <= 0 or incoming_height <= 0 then -- Nothing to process
		return {}, {}, -1, -1, -1, -1, true;
	end
	if incoming_width < 4 or incoming_height < 4 then
		reached_middle = true;
	end
	local bTaller = false;
	local rows_to_check = math.ceil(0.2 * incoming_width);
	if incoming_height > incoming_width then
		bTaller = true;
		rows_to_check = math.ceil(0.2 * incoming_height);
	end
	-- Main loop
	local coastal_plots, inland_plots = {}, {};
	for section_y = incoming_south_y, incoming_south_y + incoming_height - 1 do
		for section_x = incoming_west_x, incoming_west_x + incoming_width - 1 do
			if reached_middle then -- Process all plots.
				local x = section_x % iW;
				local y = section_y % iH;
				if self:CanPlaceCityStateAt(x, y, iAreaID, force_it, ignore_collisions) == true then
					local i = y * iW + x + 1;
					if self.plotDataIsCoastal[i] == true then
						table.insert(coastal_plots, i);
					else
						table.insert(inland_plots, i);
					end
				end
			else -- Process only plots near enough to the region edge.
				if bTaller == false then -- Processing leftmost and rightmost columns.
					if section_x < incoming_west_x + rows_to_check or section_x >= incoming_west_x + incoming_width - rows_to_check then
						local x = section_x % iW;
						local y = section_y % iH;
						if self:CanPlaceCityStateAt(x, y, iAreaID, force_it, ignore_collisions) == true then
							local i = y * iW + x + 1;
							if self.plotDataIsCoastal[i] == true then
								table.insert(coastal_plots, i);
							else
								table.insert(inland_plots, i);
							end
						end
					end
				else -- Processing top and bottom rows.
					if section_y < incoming_south_y + rows_to_check or section_y >= incoming_south_y + incoming_height - rows_to_check then
						local x = section_x % iW;
						local y = section_y % iH;
						if self:CanPlaceCityStateAt(x, y, iAreaID, force_it, ignore_collisions) == true then
							local i = y * iW + x + 1;
							if self.plotDataIsCoastal[i] == true then
								table.insert(coastal_plots, i);
							else
								table.insert(inland_plots, i);
							end
						end
					end
				end
			end
		end
	end
	local new_west_x, new_south_y, new_width, new_height;
	if bTaller then
		new_west_x = incoming_west_x + rows_to_check;
		new_south_y = incoming_south_y;
		new_width = incoming_width - (2 * rows_to_check);
		new_height = incoming_height;
	else
		new_west_x = incoming_west_x;
		new_south_y = incoming_south_y + rows_to_check;
		new_width = incoming_width;
		new_height = incoming_height - (2 * rows_to_check);
	end		

	return coastal_plots, inland_plots, new_west_x, new_south_y, new_width, new_height, reached_middle;
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceCityState(coastal_plot_list, inland_plot_list, check_proximity, check_collision)
	-- returns coords, plus boolean indicating whether assignment succeeded or failed.
	-- Argument "check_collision" should be false if plots in lists were already checked, true if not.
	if coastal_plot_list == nil or inland_plot_list == nil then
		print("Nil plot list incoming for PlaceCityState()");
	end
	local iW, iH = Map.GetGridSize()

	print("------------------------------------- CS PLOTS READOUT -------------------------------------");
	print("Inc. Coastal List Size: ", table.maxn(coastal_plot_list));
	print("Inc. Inland List Size: ", table.maxn(inland_plot_list));
	print("--------------------------------------------------------------------------------------------");

	local coastornot = Map.Rand(100, "Chance for coast v inalnd");

	if coastornot >= 42 then

		local iNumCoastal = table.maxn(coastal_plot_list);
		if iNumCoastal > 0 then
			if check_collision == false then
				local diceroll = 1 + Map.Rand(iNumCoastal, "Standard City State placement - LUA");
				local selected_plot_index = coastal_plot_list[diceroll];
				local x = (selected_plot_index - 1) % iW;
				local y = (selected_plot_index - x - 1) / iW;
				return x, y, true;
			else
				local randomized_coastal = GetShuffledCopyOfTable(coastal_plot_list);
				for loop, candidate_plot in ipairs(randomized_coastal) do
					-- if self.playerCollisionData[candidate_plot] == false or (self._lek_collide_coastals and self.playerCoastalCollisionData[candidate_plot] == false) then
					if self.playerCollisionData[candidate_plot] == false then
						-- MOD: SAPHT
						-- Checks if city state is too close to another city state,
						-- or proximity check is disabled
						if check_proximity == false or self.cityStateData[candidate_plot] == 0 then
							local x = (candidate_plot - 1) % iW;
							local y = (candidate_plot - x - 1) / iW;
							return x, y, true;
						end
					end
				end
			end
		end

		local iNumInland = table.maxn(inland_plot_list);
		if iNumInland > 0 then
			if check_collision == false then
				local diceroll = 1 + Map.Rand(iNumInland, "Standard City State placement - LUA");
				local selected_plot_index = inland_plot_list[diceroll];
				local x = (selected_plot_index - 1) % iW;
				local y = (selected_plot_index - x - 1) / iW;
				return x, y, true;
			else
				local randomized_inland = GetShuffledCopyOfTable(inland_plot_list);
				for loop, candidate_plot in ipairs(randomized_inland) do
					if self.playerCollisionData[candidate_plot] == false then
						if check_proximity == false or self.cityStateData[candidate_plot] == 0 then
							local x = (candidate_plot - 1) % iW;
							local y = (candidate_plot - x - 1) / iW;
							return x, y, true;
						end
					end
				end
			end
		end

	else

		local iNumInland = table.maxn(inland_plot_list);
		if iNumInland > 0 then
			if check_collision == false then
				local diceroll = 1 + Map.Rand(iNumInland, "Standard City State placement - LUA");
				local selected_plot_index = inland_plot_list[diceroll];
				local x = (selected_plot_index - 1) % iW;
				local y = (selected_plot_index - x - 1) / iW;
				return x, y, true;
			else
				local randomized_inland = GetShuffledCopyOfTable(inland_plot_list);
				for loop, candidate_plot in ipairs(randomized_inland) do
					if self.playerCollisionData[candidate_plot] == false then
						if check_proximity == false or self.cityStateData[candidate_plot] == 0 then
							local x = (candidate_plot - 1) % iW;
							local y = (candidate_plot - x - 1) / iW;
							return x, y, true;
						end
					end
				end
			end
		end

		local iNumCoastal = table.maxn(coastal_plot_list);
		if iNumCoastal > 0 then
			if check_collision == false then
				local diceroll = 1 + Map.Rand(iNumCoastal, "Standard City State placement - LUA");
				local selected_plot_index = coastal_plot_list[diceroll];
				local x = (selected_plot_index - 1) % iW;
				local y = (selected_plot_index - x - 1) / iW;
				return x, y, true;
			else
				local randomized_coastal = GetShuffledCopyOfTable(coastal_plot_list);
				for loop, candidate_plot in ipairs(randomized_coastal) do
					if self.playerCollisionData[candidate_plot] == false then
						if check_proximity == false or self.cityStateData[candidate_plot] == 0 then
							local x = (candidate_plot - 1) % iW;
							local y = (candidate_plot - x - 1) / iW;
							return x, y, true;
						end
					end
				end
			end
		end
	end

	return 0, 0, false;
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceCityStateInRegion(city_state_number, region_number)
	--print("Place City State in Region called for City State", city_state_number, "Region", region_number);
	local iW, iH = Map.GetGridSize();
	local placed_city_state = false;
	local reached_middle = false;
	local region_data_table = self.regionData[region_number];
	local iWestX = region_data_table[1];
	local iSouthY = region_data_table[2];
	local iWidth = region_data_table[3];
	local iHeight = region_data_table[4];
	local iAreaID = region_data_table[5];
	
	local eligible_coastal, eligible_inland = {}, {};
	
	-- Main loop, first pass, unforced
	local x, y;
	local curWX = iWestX;
	local curSY = iSouthY;
	local curWid = iWidth;
	local curHei = iHeight;
	while placed_city_state == false and reached_middle == false do
		-- Send the remaining unprocessed portion of the region to be processed.
		local nextWX, nextSY, nextWid, nextHei;
		eligible_coastal, eligible_inland, nextWX, nextSY, nextWid, nextHei, 
		  reached_middle = self:ObtainNextSectionInRegion(curWX, curSY, curWid, curHei, iAreaID, false, false) -- Don't force it. Yet.
		curWX, curSY, curWid, curHei = nextWX, nextSY, nextWid, nextHei;
		-- Attempt to place city state using the two plot lists received from the last call.
		x, y, placed_city_state = self:PlaceCityState(eligible_coastal, eligible_inland, false, false) -- Don't need to re-check collisions.
	end
	
	-- Disabling all fallback methods of city state placement. Jon has decided that, rather than
	-- force city states in to locations where they cannot even settle, we will discard them instead.
	--
	-- I am leaving the fallback methods in the code, but disabled, in case they are of any use to modders. - BT

	--[[
	if placed_city_state == false then -- Failed with proximity checks in play. Drop the prox check and force it.
		-- Main loop, second pass, forced
		reached_middle = false;
		local curWX = iWestX;
		local curSY = iSouthY;
		local curWid = iWidth;
		local curHei = iHeight;
		while placed_city_state == false and reached_middle == false do
			-- Send the remaining unprocessed portion of the region to be processed.
			local nextWX, nextSY, nextWid, nextHei;
			eligible_coastal, eligible_inland, nextWX, nextSY, nextWid, nextHei, 
			  reached_middle = self:ObtainNextSectionInRegion(curWX, curSY, curWid, curHei, iAreaID, true, false) -- Force it, but not on top of an already placed player.
			curWX, curSY, curWid, curHei = nextWX, nextSY, nextWid, nextHei;
			-- Attempt to place city state using the two plot lists received from the last call.
			x, y, placed_city_state = self:PlaceCityState(eligible_coastal, eligible_inland, false, false) -- Don't need to re-check collisions.
		end
	end

	
	if placed_city_state == false then -- Failed even trying to force it. Now allow the CS to be placed on top of another.
		-- Main loop, third pass, forced with collision checks completely disabled.
		reached_middle = false;
		local curWX = iWestX;
		local curSY = iSouthY;
		local curWid = iWidth;
		local curHei = iHeight;
		while placed_city_state == false and reached_middle == false do
			-- Send the remaining unprocessed portion of the region to be processed.
			local nextWX, nextSY, nextWid, nextHei;
			eligible_coastal, eligible_inland, nextWX, nextSY, nextWid, nextHei, 
			  reached_middle = self:ObtainNextSectionInRegion(curWX, curSY, curWid, curHei, iAreaID, true, true) -- Force it any way you can.
			curWX, curSY, curWid, curHei = nextWX, nextSY, nextWid, nextHei;
			-- Attempt to place city state using the two plot lists received from the last call.
			x, y, placed_city_state = self:PlaceCityState(eligible_coastal, eligible_inland, false, false) -- Don't need to re-check collisions.
		end
	end

	if placed_city_state == false then -- Getting desperate to place this city state.
		local fallback_plots, fallback_scores, best_fallback_plots, best_fallback_score = {}, {}, {}, 99999999;
		for region_loop_y = 0, iHeight - 1 do
			for region_loop_x = 0, iWidth - 1 do
				local x = (region_loop_x + iWestX) % iW;
				local y = (region_loop_y + iSouthY) % iH;
				local plotIndex = y * iW + x + 1;
				local plot = Map.GetPlot(x, y);
				local plotType = plot:GetPlotType()
				local terrainType = plot:GetTerrainType()
				local featureType = plot:GetFeatureType()
				--
				local iPlotScore = 1 + self.cityStateData[plotIndex];
				if self.playerCollisionData[plotIndex] == true then
					iPlotScore = iPlotScore * 1000;
				end
				if plotType == PlotTypes.PLOT_OCEAN then
					iPlotScore = iPlotScore * 10;
				elseif plotType == PlotTypes.PLOT_MOUNTAIN then
					iPlotScore = iPlotScore * 2;
				elseif terrainType == TerrainTypes.TERRAIN_SNOW then
					iPlotScore = iPlotScore * 3;
				end
				table.insert(fallback_plots, plotIndex);
				table.insert(fallback_scores, iPlotScore);
			end
		end
		for loop, iPlotScore in ipairs(fallback_scores) do
			if iPlotScore < best_fallback_score then
				best_fallback_score = iPlotScore;
			end
		end
		for loop, iPlotScore in ipairs(fallback_scores) do
			if iPlotScore == best_fallback_score then
				table.insert(best_fallback_plots, fallback_plots[loop]);
			end
		end
		local iNumFallbackCandidates = table.maxn(best_fallback_plots);
		local selectedPlotIndex;
		if iNumFallbackCandidates > 0 then
			local diceroll = 1 + Map.Rand(iNumFallbackCandidates, "City State Placement fallback plot - Lua");
			selectedPlotIndex = best_fallback_plots[diceroll];
			x = (selectedPlotIndex - 1) % iW;
			y = (selectedPlotIndex - x - 1) / iW;
			placed_city_state = true;
			local plot = Map.GetPlot(x, y);
			local plotType = plot:GetPlotType()
			if plotType == PlotTypes.PLOT_OCEAN or plotType == PlotTypes.PLOT_MOUNTAIN then
				plot:SetPlotType(PlotTypes.PLOT_LAND, false, false)
			end
			plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, true)
			plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1)
			print("-"); print("Forced placement on emergency fallback plot for City State #", city_state_number); print("-");
		else
			print("ERROR: Can't find any water, mountains, or land in this region. ... Yup, it's bad.");
		end
	end
	]]--

	if placed_city_state == true then
		-- Record and enact the placement.
		self.cityStatePlots[city_state_number] = {x, y, region_number};
		self.city_state_validity_table[city_state_number] = true; -- This is the line that marks a city state as valid to be processed by the rest of the system.
		local city_state_ID = city_state_number + GameDefines.MAX_MAJOR_CIVS - 1;
		local cityState = Players[city_state_ID];
		local cs_start_plot = Map.GetPlot(x, y)
		cityState:SetStartingPlot(cs_start_plot)
		--self:GenerateLuxuryPlotListsAtCitySite(x, y, 1, true) -- Removes Feature Ice from coasts adjacent to the city state's new location
		self:PlaceResourceImpact(x, y, 5, 4) -- City State layer
		self:PlaceResourceImpact(x, y, 2, 3) -- Luxury layer
		self:PlaceResourceImpact(x, y, 1, 0) -- Strategic layer, at start point only.
		self:PlaceResourceImpact(x, y, 3, 3) -- Bonus layer
		self:PlaceResourceImpact(x, y, 4, 3) -- Fish layer
		self:PlaceResourceImpact(x, y, 7, 3) -- Marble layer

		-- MOD.EAP also place the city state in the new impact system
		LekmapPlaceResources:place_impact(cs_start_plot, lekmap_resource_impacts.LUXURY_LAYER.LAND, 3, 3)
		LekmapPlaceResources:place_impact(cs_start_plot, lekmap_resource_impacts.LUXURY_LAYER.OCEAN, 3, 3)
		LekmapPlaceResources:place_impact(cs_start_plot, lekmap_resource_impacts.BONUS_LAYER.LAND, 3, 3)
		LekmapPlaceResources:place_impact(cs_start_plot, lekmap_resource_impacts.BONUS_LAYER.OCEAN, 3, 3)
		LekmapPlaceResources:place_impact(cs_start_plot, lekmap_resource_impacts.STRATEGIC_LAYER.LAND, 0, 0)
		LekmapPlaceResources:place_impact(cs_start_plot, lekmap_resource_impacts.STRATEGIC_LAYER.OCEAN, 0, 0)

		local impactPlotIndex = y * iW + x + 1;
		self.playerCollisionData[impactPlotIndex] = true;
		--print("-"); print("City State", city_state_number, "has been started at Plot", x, y, "in Region#", region_number);
	else
		--print("-"); print("WARNING: Crowding issues for City State #", city_state_number, " - Could not find valid site in Region#", region_number);
		self.iNumCityStatesDiscarded = self.iNumCityStatesDiscarded + 1;
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceCityStates()
	print("Map Generation - Choosing sites for City States");
	-- This function is dependent on AssignLuxuryRoles() having been executed first.
	-- This is because some city state placements are made in compensation for drawing
	-- the short straw in regard to multiple regions being assigned the same luxury type.

	self:AssignCityStatesToRegionsOrToUninhabited()
	
	--print("-"); print("--- City State Placement Results ---");

	local iW, iH = Map.GetGridSize();
	local iUninhabitedCandidatePlots = table.maxn(self.uninhabited_areas_coastal_plots) + table.maxn(self.uninhabited_areas_inland_plots);
	--print("-"); print("."); print(". NUMBER OF UNINHABITED CS CANDIDATE PLOTS: ", iUninhabitedCandidatePlots); print(".");
	for cs_number, region_number in ipairs(self.city_state_region_assignments) do
		if cs_number <= self.iNumCityStates then -- Make sure it's an active city state before processing.
			if region_number == -1 and iUninhabitedCandidatePlots > 0 then -- Assigned to areas outside of Regions.
				--print("Place City States, place in uninhabited called for City State", cs_number);
				iUninhabitedCandidatePlots = iUninhabitedCandidatePlots - 1;
				local cs_x, cs_y, success;
				cs_x, cs_y, success = self:PlaceCityState(self.uninhabited_areas_coastal_plots, self.uninhabited_areas_inland_plots, true, true)
				--
				-- Disabling fallback methods that remove proximity and collision checks. Jon has decided
				-- that city states that do not fit on the map will simply not be placed, but instead discarded.
				--[[
				if not success then -- Try again, this time with proximity checks disabled.
					cs_x, cs_y, success = self:PlaceCityState(self.uninhabited_areas_coastal_plots, self.uninhabited_areas_inland_plots, false, true)
					if not success then -- Try a third time, this time with all collision checks disabled.
						cs_x, cs_y, success = self:PlaceCityState(self.uninhabited_areas_coastal_plots, self.uninhabited_areas_inland_plots, false, false)
					end
				end
				]]--
				--
				if success == true then
					self.cityStatePlots[cs_number] = {cs_x, cs_y, -1};
					self.city_state_validity_table[cs_number] = true; -- This is the line that marks a city state as valid to be processed by the rest of the system.
					local city_state_ID = cs_number + GameDefines.MAX_MAJOR_CIVS - 1;
					local cityState = Players[city_state_ID];
					local cs_start_plot = Map.GetPlot(cs_x, cs_y)
					cityState:SetStartingPlot(cs_start_plot)
					--self:GenerateLuxuryPlotListsAtCitySite(cs_x, cs_y, 1, true) -- Removes Feature Ice from coasts adjacent to the city state's new location
					self:PlaceResourceImpact(cs_x, cs_y, 5, 3) -- City State layer
					self:PlaceResourceImpact(cs_x, cs_y, 2, 3) -- Luxury layer
					self:PlaceResourceImpact(cs_x, cs_y, 1, 0) -- Strategic layer, at start point only.
					self:PlaceResourceImpact(cs_x, cs_y, 3, 3) -- Bonus layer
					self:PlaceResourceImpact(cs_x, cs_y, 4, 3) -- Fish layer
					self:PlaceResourceImpact(cs_x, cs_y, 7, 3) -- Marble layer

					local impactPlotIndex = cs_y * iW + cs_x + 1;
					self.playerCollisionData[impactPlotIndex] = true;
					--print("-"); print("City State", cs_number, "has been started at Plot", cs_x, cs_y, "in Uninhabited Lands");
				else
					--print("-"); print("WARNING: Crowding issues for City State #", city_state_number, " - Could not find valid site in Uninhabited Lands.", region_number);
					self.iNumCityStatesDiscarded = self.iNumCityStatesDiscarded + 1;
				end
			elseif region_number == -1 and iUninhabitedCandidatePlots <= 0 then -- Assigned to areas outside of Regions, but nowhere there to put them!
				local iRandRegion = 1 + Map.Rand(self.iNumCivs, "Emergency Redirect of CS placement, choosing Region - LUA");
				--print("Place City States, place in uninhabited called for City State", cs_number, "but it has no legal site, so is being put in Region#", iRandRegion);
				self:PlaceCityStateInRegion(cs_number, iRandRegion)
			else -- Assigned to a Region.
				--print("Place City States, place in Region#", region_number, "for City State", cs_number);
				self:PlaceCityStateInRegion(cs_number, region_number)
			end
		end
	end
	
	-- Last chance method to place city states that didn't fit where they were supposed to go.
	if self.iNumCityStatesDiscarded > 0 then
		-- Assemble a global plot list of eligible City State sites that remain.
		local cs_last_chance_plot_list = {};
		for y = 0, iH - 1 do
			for x = 0, iW - 1 do
				if self:CanPlaceCityStateAt(x, y, -1, false, false) == true then
					local i = y * iW + x + 1;
					table.insert(cs_last_chance_plot_list, i);
				end
			end
		end
		local iNumLastChanceCandidates = table.maxn(cs_last_chance_plot_list);
		-- If any eligible sites were found anywhere on the map, place as many of the remaining CS as possible.
		if iNumLastChanceCandidates > 0 then
			print("-"); print("-"); print("ALERT: Some City States failed to be placed due to overcrowding. Attempting 'last chance' placement method.");
			print("Total number of remaining eligible candidate plots:", iNumLastChanceCandidates);
			local last_chance_shuffled = GetShuffledCopyOfTable(cs_last_chance_plot_list)
			local cs_list = {};
			for cs_num = 1, self.iNumCityStates do
				if self.city_state_validity_table[cs_num] == false then
					table.insert(cs_list, cs_num);
					--print("City State #", cs_num, "not yet placed, adding it to 'last chance' list.");
				end
			end
			for loop, cs_number in ipairs(cs_list) do
				local cs_x, cs_y, success;
				cs_x, cs_y, success = self:PlaceCityState(last_chance_shuffled, {}, true, true)
				if success == true then
					self.cityStatePlots[cs_number] = {cs_x, cs_y, -1};
					self.city_state_validity_table[cs_number] = true; -- This is the line that marks a city state as valid to be processed by the rest of the system.
					local city_state_ID = cs_number + GameDefines.MAX_MAJOR_CIVS - 1;
					local cityState = Players[city_state_ID];
					local cs_start_plot = Map.GetPlot(cs_x, cs_y)
					cityState:SetStartingPlot(cs_start_plot)
					--self:GenerateLuxuryPlotListsAtCitySite(cs_x, cs_y, 1, true) -- Removes Feature Ice from coasts adjacent to the city state's new location
					self:PlaceResourceImpact(cs_x, cs_y, 5, 3) -- City State layer
					self:PlaceResourceImpact(cs_x, cs_y, 2, 3) -- Luxury layer
					self:PlaceResourceImpact(cs_x, cs_y, 1, 0) -- Strategic layer, at start point only.
					self:PlaceResourceImpact(cs_x, cs_y, 3, 3) -- Bonus layer
					self:PlaceResourceImpact(cs_x, cs_y, 4, 3) -- Fish layer
					self:PlaceResourceImpact(cs_x, cs_y, 7, 3) -- Marble layer

					local impactPlotIndex = cs_y * iW + cs_x + 1;
					self.playerCollisionData[impactPlotIndex] = true;
					self.iNumCityStatesDiscarded = self.iNumCityStatesDiscarded - 1;
					--print("-"); print("City State", cs_number, "has been RESCUED from the trash bin of history and started at Fallback Plot", cs_x, cs_y);
				else
					--print("-"); print("We have run out of possible 'last chance' sites for unplaced city states!");
					break
				end
			end
			if self.iNumCityStatesDiscarded > 0 then
				print("-"); print("ALERT: No eligible city state sites remain. DISCARDING", self.iNumCityStatesDiscarded, "city states. BYE BYE!"); print("-");
			end
		else
			print("-"); print("-"); print("ALERT: No eligible city state sites remain. DISCARDING", self.iNumCityStatesDiscarded, "city states. BYE BYE!"); print("-");
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:NormalizeCityState(x, y)
	-- Similar to the version for normalizing civ starts, but less placed, no third-ring considerations and different weightings.
	local iW, iH = Map.GetGridSize();
	local plot = Map.GetPlot(x, y);
	local isEvenY = true;
	if y / 2 > math.floor(y / 2) then
		isEvenY = false;
	end
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local innerFourFood, innerThreeFood, innerTwoFood, innerHills, innerForest, innerOneHammer, innerOcean = 0, 0, 0, 0, 0, 0, 0;
	local outerFourFood, outerThreeFood, outerTwoFood, outerOcean = 0, 0, 0, 0;
	local innerCanHaveBonus, outerCanHaveBonus, innerBadTiles, outerBadTiles = 0, 0, 0, 0;
	local iNumFoodBonusNeeded = 0;
	local search_table = {};
	
	-- Data Chart for early game tile potentials
	--
	-- 4F:	Flood Plains, Grass on fresh water (includes forest and marsh).
	-- 3F:	Dry Grass, Plains on fresh water (includes forest and jungle), Tundra on fresh water (includes forest), Oasis
	-- 2F:  Dry Plains, Lake, all remaining Jungles.
	--
	-- 1H:	Plains, Jungle on Plains

	-- Evaluate First Ring
	if isEvenY then
		search_table = self.firstRingYIsEven;
	else
		search_table = self.firstRingYIsOdd;
	end

	for loop, plot_adjustments in ipairs(search_table) do
		local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
		--
		if searchX < 0 or searchX >= iW or searchY < 0 or searchY >= iH then -- This plot's off the map edge.
			innerBadTiles = innerBadTiles + 1;
		else
			local searchPlot = Map.GetPlot(searchX, searchY)
			local plotType = searchPlot:GetPlotType()
			local terrainType = searchPlot:GetTerrainType()
			local featureType = searchPlot:GetFeatureType()
			--
			if plotType == PlotTypes.PLOT_MOUNTAIN then
				innerBadTiles = innerBadTiles + 1;
			elseif plotType == PlotTypes.PLOT_OCEAN then
				if searchPlot:IsLake() then
					if featureType == FeatureTypes.FEATURE_ICE then
						innerBadTiles = innerBadTiles + 1;
					else
						innerTwoFood = innerTwoFood + 1;
					end
				else
					if featureType == FeatureTypes.FEATURE_ICE then
						innerBadTiles = innerBadTiles + 1;
					else
						innerOcean = innerOcean + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
					end
				end
			else -- Habitable plot.
				if plotType == PlotTypes.PLOT_HILLS then
					innerHills = innerHills + 1;
					if featureType == FeatureTypes.FEATURE_JUNGLE then
						innerTwoFood = innerTwoFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
					elseif featureType == FeatureTypes.FEATURE_FOREST then
						innerCanHaveBonus = innerCanHaveBonus + 1;
					end
				elseif searchPlot:IsFreshWater() then
					if terrainType == TerrainTypes.TERRAIN_GRASS then
						innerFourFood = innerFourFood + 1;
						if featureType ~= FeatureTypes.FEATURE_MARSH then
							innerCanHaveBonus = innerCanHaveBonus + 1;
						end
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						end
					elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
						innerFourFood = innerFourFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						innerThreeFood = innerThreeFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						else
							innerOneHammer = innerOneHammer + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
						innerThreeFood = innerThreeFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_DESERT then
						innerBadTiles = innerBadTiles + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1; -- Can have Oasis.
					else -- Snow
						innerBadTiles = innerBadTiles + 1;
					end
				else -- Dry Flatlands
					if terrainType == TerrainTypes.TERRAIN_GRASS then
						innerThreeFood = innerThreeFood + 1;
						if featureType ~= FeatureTypes.FEATURE_MARSH then
							innerCanHaveBonus = innerCanHaveBonus + 1;
						end
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						innerTwoFood = innerTwoFood + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						else
							innerOneHammer = innerOneHammer + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
						innerCanHaveBonus = innerCanHaveBonus + 1;
						if featureType == FeatureTypes.FEATURE_FOREST then
							innerForest = innerForest + 1;
						else
							innerBadTiles = innerBadTiles + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_DESERT then
						innerBadTiles = innerBadTiles + 1;
						innerCanHaveBonus = innerCanHaveBonus + 1; -- Can have Oasis.
					else -- Snow
						innerBadTiles = innerBadTiles + 1;
					end
				end
			end
		end
	end
				
	-- Evaluate Second Ring
	if isEvenY then
		search_table = self.secondRingYIsEven;
	else
		search_table = self.secondRingYIsOdd;
	end
	for loop, plot_adjustments in ipairs(search_table) do
		local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
		if searchX < 0 or searchX >= iW or searchY < 0 or searchY >= iH then -- This plot's off the map edge.
			outerBadTiles = outerBadTiles + 1;
		else
			local searchPlot = Map.GetPlot(searchX, searchY)
			local plotType = searchPlot:GetPlotType()
			local terrainType = searchPlot:GetTerrainType()
			local featureType = searchPlot:GetFeatureType()
			--
			if plotType == PlotTypes.PLOT_MOUNTAIN then
				outerBadTiles = outerBadTiles + 1;
			elseif plotType == PlotTypes.PLOT_OCEAN then
				if searchPlot:IsLake() then
					if featureType == FeatureTypes.FEATURE_ICE then
						outerBadTiles = outerBadTiles + 1;
					else
						outerTwoFood = outerTwoFood + 1;
					end
				else
					if featureType == FeatureTypes.FEATURE_ICE then
						outerBadTiles = outerBadTiles + 1;
					elseif terrainType == TerrainTypes.TERRAIN_COAST then
						outerCanHaveBonus = outerCanHaveBonus + 1;
						outerOcean = outerOcean + 1;
					end
				end
			else -- Habitable plot.
				if plotType == PlotTypes.PLOT_HILLS then
					if featureType == FeatureTypes.FEATURE_JUNGLE then
						outerTwoFood = outerTwoFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
					elseif featureType == FeatureTypes.FEATURE_FOREST then
						outerCanHaveBonus = outerCanHaveBonus + 1;
					end
				elseif searchPlot:IsFreshWater() then
					if terrainType == TerrainTypes.TERRAIN_GRASS then
						outerFourFood = outerFourFood + 1;
						if featureType ~= FeatureTypes.FEATURE_MARSH then
							outerCanHaveBonus = outerCanHaveBonus + 1;
						end
					elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
						outerFourFood = outerFourFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						outerThreeFood = outerThreeFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
					elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
						outerThreeFood = outerThreeFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
					elseif terrainType == TerrainTypes.TERRAIN_DESERT then
						outerBadTiles = outerBadTiles + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1; -- Can have Oasis.
					else -- Snow
						outerBadTiles = outerBadTiles + 1;
					end
				else -- Dry Flatlands
					if terrainType == TerrainTypes.TERRAIN_GRASS then
						outerThreeFood = outerThreeFood + 1;
						if featureType ~= FeatureTypes.FEATURE_MARSH then
							outerCanHaveBonus = outerCanHaveBonus + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
						outerTwoFood = outerTwoFood + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1;
					elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
						outerCanHaveBonus = outerCanHaveBonus + 1;
						if featureType ~= FeatureTypes.FEATURE_FOREST then
							outerBadTiles = outerBadTiles + 1;
						end
					elseif terrainType == TerrainTypes.TERRAIN_DESERT then
						outerBadTiles = outerBadTiles + 1;
						outerCanHaveBonus = outerCanHaveBonus + 1; -- Can have Oasis.
					else -- Snow
						outerBadTiles = outerBadTiles + 1;
					end
				end
			end
		end
	end
	
	-- Adjust the hammer situation, if needed.
	local hammerScore = (4 * innerHills) + (2 * innerForest) + innerOneHammer;
	if hammerScore < 6 then -- Change a first ring plot to Hills.
		if isEvenY then
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsEven);
		else
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsOdd);
		end
		for attempt = 1, 6 do
			local plot_adjustments = randomized_first_ring_adjustments[attempt];
			local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
			-- Attempt to place a Hill at the currently chosen plot.
			local placedHill = self:AttemptToPlaceHillsAtPlot(searchX, searchY);
			if placedHill == true then
				hammerScore = hammerScore + 4;
				--print("Added hills next to hammer-poor city state at ", x, y);
				break
			elseif attempt == 6 then
				--print("FAILED to add hills next to hammer-poor city state at ", x, y);
			end
		end
	end
	
	-- Rate the food situation.
	local innerFoodScore = (4 * innerFourFood) + (2 * innerThreeFood) + innerTwoFood;
	local outerFoodScore = (4 * outerFourFood) + (2 * outerThreeFood) + outerTwoFood;
	local totalFoodScore = innerFoodScore + outerFoodScore;

	-- Debug printout of food scores.
	--print("-");
	--print("-- - City State #", city_state_number, " has Food Score of ", totalFoodScore, " with rings of ", innerFoodScore, outerFoodScore);
	--	
	
	-- Three levels for Bonus Resource support, from zero to two.
	iNumFoodBonusNeeded = 1;
	if totalFoodScore < 8 or innerFoodScore < 4 then
		iNumFoodBonusNeeded = 3;
	elseif totalFoodScore < 12 and innerFoodScore < 9 then
		iNumFoodBonusNeeded = 2;
	end
	-- Add Bonus Resources to food-poor city states.
	if iNumFoodBonusNeeded > 0 then
		local maxBonusesPossible = innerCanHaveBonus + outerCanHaveBonus;

		--print("-");
		--print("Food-Poor city state ", x, y, " needs ", iNumFoodBonusNeeded, " Bonus, with ", maxBonusesPossible, " eligible plots.");
		--print("-");

		local innerPlaced, outerPlaced = 0, 0;
		local randomized_first_ring_adjustments, randomized_second_ring_adjustments;
		if isEvenY then
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsEven);
			randomized_second_ring_adjustments = GetShuffledCopyOfTable(self.secondRingYIsEven);
		else
			randomized_first_ring_adjustments = GetShuffledCopyOfTable(self.firstRingYIsOdd);
			randomized_second_ring_adjustments = GetShuffledCopyOfTable(self.secondRingYIsOdd);
		end
		local tried_all_first_ring = false;
		local tried_all_second_ring = false;
		local allow_oasis = true; -- Permanent flag. (We don't want to place more than one Oasis per location).
		local allow_fishCount = 2;
		local placedOasis; -- Records returning result from each attempt.
		while iNumFoodBonusNeeded > 0 do
			if innerPlaced < 2 and innerCanHaveBonus > 0 and tried_all_first_ring == false then -- Add bonus to inner ring.
				for attempt = 1, 6 do
					local plot_adjustments = randomized_first_ring_adjustments[attempt];
					local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
					-- Attempt to place a Bonus at the currently chosen plot.
					local placedBonus, placedOasis, placedFish = self:AttemptToPlaceBonusResourceAtPlot(searchX, searchY, allow_oasis, allow_fishCount);
					if placedBonus == true then
						if placedFish == true then -- First fish was placed on this pass, so change permission.
							allow_fishCount = allow_fishCount - 1;
						end
						if allow_oasis == true and placedOasis == true then -- First oasis was placed on this pass, so change permission.
							allow_oasis = false;
						end
						--print("Placed a Bonus in first ring at ", searchX, searchY);
						innerPlaced = innerPlaced + 1;
						innerCanHaveBonus = innerCanHaveBonus - 1;
						iNumFoodBonusNeeded = iNumFoodBonusNeeded - 1;
						break
					elseif attempt == 6 then
						tried_all_first_ring = true;
					end
				end

			elseif innerPlaced + outerPlaced < 4 and outerCanHaveBonus > 0 and tried_all_second_ring == false then
				-- Add bonus to second ring.
				for attempt = 1, 12 do
					local plot_adjustments = randomized_second_ring_adjustments[attempt];
					local searchX, searchY = self:ApplyHexAdjustment(x, y, plot_adjustments)
					-- Attempt to place a Bonus at the currently chosen plot.
					local placedBonus, placedOasis, placedFish = self:AttemptToPlaceBonusResourceAtPlot(searchX, searchY, allow_oasis, allow_fishCount);
					if placedBonus == true then
						if placedFish == true then -- First fish was placed on this pass, so change permission.
							allow_fishCount = allow_fishCount - 1;
						end
						if allow_oasis == true and placedOasis == true then -- First oasis was placed on this pass, so change permission.
							allow_oasis = false;
						end
						--print("Placed a Bonus in second ring at ", searchX, searchY);
						outerPlaced = outerPlaced + 1;
						outerCanHaveBonus = outerCanHaveBonus - 1;
						iNumFoodBonusNeeded = iNumFoodBonusNeeded - 1;
						break
					elseif attempt == 12 then
						tried_all_second_ring = true;
					end
				end
			
			else -- Tried everywhere, have to give up.
				break				
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:NormalizeCityStateLocations()
	for city_state, data_table in ipairs(self.cityStatePlots) do
		if self.city_state_validity_table[city_state] == true then
			local x = data_table[1];
			local y = data_table[2];
			self:NormalizeCityState(x, y)
		else
			print("WARNING: City State #", city_state, "is not valid in this game. It must have been discarded from overcrowding.");
		end
	end
end
------------------------------------------------------------------------------
-- Start of functions tied to PlaceResourcesAndCityStates()
------------------------------------------------------------------------------
function AssignStartingPlots:GenerateGlobalResourcePlotLists_NEW()
	-- This function generates all global plot lists needed for resource distribution.
	local iW, iH = Map.GetGridSize();
	local results_table = {};
	--
	for resource_ID, resource_data in pairs(self.ResourceTypes) do
		if resource_data.Special == false then -- exclude special case resources
			results_table[resource_ID] = results_table[resource_ID] or {};

			for y = 0, iH - 1 do
				for x = 0, iW - 1 do
					local i = y * iW + x + 1; -- Lua tables/lists/arrays start at 1, not 0 like C++ or Python
					local plot = Map.GetPlot(x, y)
					-- Check if plot has a civ start, CS start, or Natural Wonder
					if self.playerCollisionData[i] == true then
						-- Do not process this plot!
					elseif plot:GetResourceType(-1) ~= -1 then
						-- Plot has a resource already, do not include it.
					elseif LekmapResourceInfos:is_valid_on(resource_ID, x, y, true) then
						
						table.insert(results_table[resource_ID], plot)
					end		
				end
			end
			if #results_table[resource_ID] > 0 then
				self.global_resource_plot_lists[resource_ID] = results_table[resource_ID];
				self.global_luxury_plot_lists_temp[resource_ID] = results_table[resource_ID];
			else
				print("WARNING: Resource", resource_data.Type, "has no plots in its global plot list.")
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:GenerateGlobalResourcePlotLists()
	-- This function generates all global plot lists needed for resource distribution.
	local iW, iH = Map.GetGridSize();
	local temp_coast_next_to_land_list, temp_marsh_list, temp_flood_plains_list = {}, {}, {};
	local temp_hills_open_list, temp_hills_covered_list, temp_hills_jungle_list = {}, {}, {};
	local temp_hills_forest_list, temp_jungle_flat_list, temp_forest_flat_list = {}, {}, {};
	local temp_desert_flat_no_feature, temp_plains_flat_no_feature, temp_dry_grass_flat_no_feature = {}, {}, {};
	local temp_fresh_water_grass_flat_no_feature, temp_tundra_flat_including_forests, temp_forest_flat_that_are_not_tundra = {}, {}, {};
	local temp_dry_plains_flat_no_feature, temp_fresh_water_plains_flat_no_feature = {}, {};							-- MOD.Barathor: New
	local temp_desert_or_tundra_flat_no_feature, temp_tundra_flat_forest = {}, {};										-- MOD.Barathor: New
	local temp_hills_open_no_tundra, temp_hills_open_no_desert, temp_hills_open_no_tundra_no_desert = {}, {}, {};		-- MOD.Barathor: New
	local temp_hills_open_no_grass, temp_hills_open_no_grass_no_tundra, temp_hills_covered_no_tundra = {}, {}, {};		-- MOD.Barathor: New
	local temp_hills_covered_no_grass, temp_hills_covered_no_grass_no_tundra, temp_flat_covered = {}, {}, {};			-- MOD.Barathor: New
	local temp_flat_covered_no_grass, temp_flat_covered_no_tundra, temp_flat_covered_no_grass_no_tundra = {}, {}, {};	-- MOD.Barathor: New
	local temp_flat_open, temp_flat_open_no_grass_no_plains, temp_flat_open_no_tundra_no_desert = {}, {}, {};			-- MOD.Barathor: New
	local temp_flat_open_no_desert, temp_flat_desert_including_flood, temp_hills_open_no_grass_no_plains = {}, {}, {};	-- MOD.Barathor: New

	local temp_hills_list, temp_coast_list, temp_grass_flat_no_feature = {}, {}, {};
	local temp_tundra_flat_no_feature, temp_snow_flat_list, temp_land_list = {}, {}, {}, {};
	local temp_marble_list, temp_deer_list, temp_desert_wheat_list, temp_banana_list = {}, {}, {}, {};
	--
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local i = y * iW + x + 1; -- Lua tables/lists/arrays start at 1, not 0 like C++ or Python
			local plot = Map.GetPlot(x, y)
			-- Check if plot has a civ start, CS start, or Natural Wonder
			if self.playerCollisionData[i] == true then
				-- Do not process this plot!
			elseif plot:GetResourceType(-1) ~= -1 then
				-- Plot has a resource already, do not include it.
			else
				-- Process this plot for inclusion in the plot lists.
				local plotType = plot:GetPlotType()
				local terrainType = plot:GetTerrainType()
				local featureType = plot:GetFeatureType()
				if plotType == PlotTypes.PLOT_MOUNTAIN then
					self.barren_plots = self.barren_plots + 1;
				elseif plotType == PlotTypes.PLOT_OCEAN then
					if featureType ~= self.feature_atoll then
						if featureType == FeatureTypes.FEATURE_ICE then
							self.barren_plots = self.barren_plots + 1;
						elseif plot:IsLake() then
							self.barren_plots = self.barren_plots + 1;
						elseif terrainType == TerrainTypes.TERRAIN_COAST then
							table.insert(temp_coast_list, i);
							if plot:IsAdjacentToLand() then
								table.insert(temp_coast_next_to_land_list, i);
							end
						else
							self.barren_plots = self.barren_plots + 1;
						end
					end
				elseif plotType == PlotTypes.PLOT_HILLS and terrainType ~= TerrainTypes.TERRAIN_SNOW then
					table.insert(temp_hills_list, i);
					if featureType == FeatureTypes.NO_FEATURE then
						table.insert(temp_hills_open_list, i);
						table.insert(temp_marble_list, i);
						if terrainType == TerrainTypes.TERRAIN_TUNDRA then			-- MOD.Barathor: New Condition
							table.insert(temp_hills_open_no_desert, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_grass, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_grass_no_plains, i);	-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_DESERT then
							table.insert(temp_hills_open_no_tundra, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_grass, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_grass_no_tundra, i);	-- MOD.Barathor: New
							table.insert(temp_hills_open_no_grass_no_plains, i);	-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
							table.insert(temp_hills_open_no_tundra, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_desert, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_grass, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_grass_no_tundra, i);	-- MOD.Barathor: New
							table.insert(temp_hills_open_no_tundra_no_desert, i);	-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_GRASS then
							table.insert(temp_hills_open_no_tundra, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_desert, i);				-- MOD.Barathor: New
							table.insert(temp_hills_open_no_tundra_no_desert, i);	-- MOD.Barathor: New
						else
							self.barren_plots = self.barren_plots + 1;				-- MOD.Barathor: New
							table.remove(temp_hills_list);							-- MOD.Barathor: New
						end
					elseif featureType == FeatureTypes.FEATURE_JUNGLE then
						table.insert(temp_banana_list, i);
						table.insert(temp_hills_jungle_list, i);
						table.insert(temp_hills_covered_list, i);
						if terrainType == TerrainTypes.TERRAIN_PLAINS then			-- MOD.Barathor: New Condition
							table.insert(temp_hills_covered_no_tundra, i);			-- MOD.Barathor: New
							table.insert(temp_hills_covered_no_grass, i);			-- MOD.Barathor: New
							table.insert(temp_hills_covered_no_grass_no_tundra, i);	-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_GRASS then
							table.insert(temp_hills_covered_no_tundra, i);			-- MOD.Barathor: New
						end
					elseif featureType == FeatureTypes.FEATURE_FOREST then
						table.insert(temp_hills_forest_list, i);
						table.insert(temp_hills_covered_list, i);
						table.insert(temp_marble_list, i);							-- MOD.Barathor: Updated
						if terrainType == TerrainTypes.TERRAIN_TUNDRA then
							table.insert(temp_deer_list, i);
							table.insert(temp_hills_covered_no_grass, i);			-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_PLAINS then		-- MOD.Barathor: New Condition
							table.insert(temp_hills_covered_no_tundra, i);			-- MOD.Barathor: New
							table.insert(temp_hills_covered_no_grass, i);			-- MOD.Barathor: New
							table.insert(temp_hills_covered_no_grass_no_tundra, i);	-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_GRASS then		-- MOD.Barathor: New Condition
							table.insert(temp_hills_covered_no_tundra, i);			-- MOD.Barathor: New
						end
					else
						self.barren_plots = self.barren_plots + 1;					-- MOD.Barathor: Fixed
						table.remove(temp_hills_list);								-- MOD.Barathor: Fixed
					end
				elseif featureType == FeatureTypes.FEATURE_MARSH then
					table.insert(temp_marsh_list, i);
				elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
					table.insert(temp_flood_plains_list, i);
					table.insert(temp_desert_wheat_list, i);
					table.insert(temp_flat_desert_including_flood, i);				-- MOD.Barathor: New
				elseif plotType == PlotTypes.PLOT_LAND then
					table.insert(temp_land_list, i);
					if featureType == FeatureTypes.FEATURE_JUNGLE then
						table.insert(temp_jungle_flat_list, i);
						table.insert(temp_banana_list, i);
						table.insert(temp_flat_covered, i);								-- MOD.Barathor: New
						if terrainType == TerrainTypes.TERRAIN_PLAINS then				-- MOD.Barathor: New Condition
							table.insert(temp_flat_covered_no_tundra, i);				-- MOD.Barathor: New
							table.insert(temp_flat_covered_no_grass, i);				-- MOD.Barathor: New
							table.insert(temp_flat_covered_no_grass_no_tundra, i);		-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_GRASS then
							table.insert(temp_flat_covered_no_tundra, i);				-- MOD.Barathor: New
						end
					elseif featureType == FeatureTypes.FEATURE_FOREST then
						table.insert(temp_forest_flat_list, i);
						table.insert(temp_flat_covered, i);								-- MOD.Barathor: New
						if terrainType == TerrainTypes.TERRAIN_TUNDRA then
							table.insert(temp_deer_list, i);
							table.insert(temp_tundra_flat_including_forests, i);

							table.insert(temp_tundra_flat_forest, i);					-- MOD.Barathor: New
							table.insert(temp_flat_covered_no_grass, i);				-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_PLAINS then			-- MOD.Barathor: New Condition
							table.insert(temp_forest_flat_that_are_not_tundra, i);
							table.insert(temp_flat_covered_no_tundra, i);				-- MOD.Barathor: New
							table.insert(temp_flat_covered_no_grass_no_tundra, i);		-- MOD.Barathor: New
							table.insert(temp_flat_covered_no_grass, i);				-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_GRASS then			-- MOD.Barathor: New Condition
							table.insert(temp_forest_flat_that_are_not_tundra, i);
							table.insert(temp_flat_covered_no_tundra, i);				-- MOD.Barathor: New
						end
					elseif featureType == FeatureTypes.NO_FEATURE then
						if terrainType == TerrainTypes.TERRAIN_SNOW then
							table.insert(temp_snow_flat_list, i);
						elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
							table.insert(temp_tundra_flat_no_feature, i);
							table.insert(temp_tundra_flat_including_forests, i);
							table.insert(temp_marble_list, i);
							table.insert(temp_desert_or_tundra_flat_no_feature, i);		-- MOD.Barathor: New
							table.insert(temp_flat_open, i);							-- MOD.Barathor: New
							table.insert(temp_flat_open_no_desert, i);					-- MOD.Barathor: New
							table.insert(temp_flat_open_no_grass_no_plains, i);			-- MOD.Barathor: New
						elseif terrainType == TerrainTypes.TERRAIN_DESERT then
							table.insert(temp_desert_flat_no_feature, i);
							table.insert(temp_marble_list, i);
							table.insert(temp_desert_or_tundra_flat_no_feature, i);		-- MOD.Barathor: New
							table.insert(temp_flat_open, i);							-- MOD.Barathor: New
							table.insert(temp_flat_open_no_grass_no_plains, i);			-- MOD.Barathor: New
							table.insert(temp_flat_desert_including_flood, i);			-- MOD.Barathor: New
							if plot:IsFreshWater() then
								table.insert(temp_desert_wheat_list, i);
							end
						elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
							table.insert(temp_plains_flat_no_feature, i);
							table.insert(temp_marble_list, i);								-- MOD.Barathor: Updated
							table.insert(temp_flat_open_no_desert, i);						-- MOD.Barathor: New
							table.insert(temp_flat_open, i);								-- MOD.Barathor: New
							table.insert(temp_flat_open_no_tundra_no_desert, i);			-- MOD.Barathor: New
							if plot:IsFreshWater() then										-- MOD.Barathor: Updated fresh water check
								table.insert(temp_fresh_water_plains_flat_no_feature, i);	-- MOD.Barathor: New
							else
								table.insert(temp_dry_plains_flat_no_feature, i);			-- MOD.Barathor: New
							end
						elseif terrainType == TerrainTypes.TERRAIN_GRASS then
							table.insert(temp_grass_flat_no_feature, i);
							table.insert(temp_marble_list, i);							-- MOD.Barathor: Updated
							table.insert(temp_flat_open_no_desert, i);					-- MOD.Barathor: New
							table.insert(temp_flat_open, i);							-- MOD.Barathor: New
							table.insert(temp_flat_open_no_tundra_no_desert, i);		-- MOD.Barathor: New
							if plot:IsFreshWater() then
								table.insert(temp_fresh_water_grass_flat_no_feature, i);
							else
								table.insert(temp_dry_grass_flat_no_feature, i);
								table.insert(temp_marble_list, i);
							end
						else
							self.barren_plots = self.barren_plots + 1;
							table.remove(temp_land_list);
						end
					else
						self.barren_plots = self.barren_plots + 1;
						table.remove(temp_land_list);
					end
				else
					self.barren_plots = self.barren_plots + 1;
				end
			end
		end
	end
	-- Scramble and record the lists.
	self.coast_next_to_land_list = GetShuffledCopyOfTable(temp_coast_next_to_land_list)
	self.marsh_list = GetShuffledCopyOfTable(temp_marsh_list)
	self.flood_plains_list = GetShuffledCopyOfTable(temp_flood_plains_list)
	self.hills_open_list = GetShuffledCopyOfTable(temp_hills_open_list)
	self.hills_covered_list = GetShuffledCopyOfTable(temp_hills_covered_list)
	self.hills_jungle_list = GetShuffledCopyOfTable(temp_hills_jungle_list)
	self.hills_forest_list = GetShuffledCopyOfTable(temp_hills_forest_list)
	self.jungle_flat_list = GetShuffledCopyOfTable(temp_jungle_flat_list)
	self.forest_flat_list = GetShuffledCopyOfTable(temp_forest_flat_list)
	self.desert_flat_no_feature = GetShuffledCopyOfTable(temp_desert_flat_no_feature)
	self.plains_flat_no_feature = GetShuffledCopyOfTable(temp_plains_flat_no_feature)
	self.dry_grass_flat_no_feature = GetShuffledCopyOfTable(temp_dry_grass_flat_no_feature)
	self.fresh_water_grass_flat_no_feature = GetShuffledCopyOfTable(temp_fresh_water_grass_flat_no_feature)
	self.tundra_flat_including_forests = GetShuffledCopyOfTable(temp_tundra_flat_including_forests)
	self.forest_flat_that_are_not_tundra = GetShuffledCopyOfTable(temp_forest_flat_that_are_not_tundra)
	self.dry_plains_flat_no_feature = GetShuffledCopyOfTable(temp_dry_plains_flat_no_feature)					-- MOD.Barathor: New
	self.fresh_water_plains_flat_no_feature = GetShuffledCopyOfTable(temp_fresh_water_plains_flat_no_feature)	-- MOD.Barathor: New
	self.desert_or_tundra_flat_no_feature = GetShuffledCopyOfTable(temp_desert_or_tundra_flat_no_feature)		-- MOD.Barathor: New
	self.tundra_flat_forest = GetShuffledCopyOfTable(temp_tundra_flat_forest)									-- MOD.Barathor: New
	self.hills_open_no_tundra = GetShuffledCopyOfTable(temp_hills_open_no_tundra)								-- MOD.Barathor: New
	self.hills_open_no_desert = GetShuffledCopyOfTable(temp_hills_open_no_desert)								-- MOD.Barathor: New
	self.hills_open_no_tundra_no_desert = GetShuffledCopyOfTable(temp_hills_open_no_tundra_no_desert)			-- MOD.Barathor: New
	self.hills_open_no_grass = GetShuffledCopyOfTable(temp_hills_open_no_grass)									-- MOD.Barathor: New
	self.hills_open_no_grass_no_tundra = GetShuffledCopyOfTable(temp_hills_open_no_grass_no_tundra)				-- MOD.Barathor: New
	self.hills_open_no_grass_no_plains = GetShuffledCopyOfTable(temp_hills_open_no_grass_no_plains)				-- MOD.Barathor: New
	self.hills_covered_no_tundra = GetShuffledCopyOfTable(temp_hills_covered_no_tundra)							-- MOD.Barathor: New
	self.hills_covered_no_grass = GetShuffledCopyOfTable(temp_hills_covered_no_grass)							-- MOD.Barathor: New
	self.hills_covered_no_grass_no_tundra = GetShuffledCopyOfTable(temp_hills_covered_no_grass_no_tundra)		-- MOD.Barathor: New
	self.flat_covered = GetShuffledCopyOfTable(temp_flat_covered)												-- MOD.Barathor: New
	self.flat_covered_no_grass = GetShuffledCopyOfTable(temp_flat_covered_no_grass)								-- MOD.Barathor: New
	self.flat_covered_no_tundra = GetShuffledCopyOfTable(temp_flat_covered_no_tundra)							-- MOD.Barathor: New
	self.flat_covered_no_grass_no_tundra = GetShuffledCopyOfTable(temp_flat_covered_no_grass_no_tundra)			-- MOD.Barathor: New
	self.flat_open = GetShuffledCopyOfTable(temp_flat_open)														-- MOD.Barathor: New
	self.flat_open_no_grass_no_plains = GetShuffledCopyOfTable(temp_flat_open_no_grass_no_plains)				-- MOD.Barathor: New
	self.flat_open_no_tundra_no_desert = GetShuffledCopyOfTable(temp_flat_open_no_tundra_no_desert)				-- MOD.Barathor: New
	self.flat_open_no_desert = GetShuffledCopyOfTable(temp_flat_open_no_desert)									-- MOD.Barathor: New
	self.flat_desert_including_flood = GetShuffledCopyOfTable(temp_flat_desert_including_flood)					-- MOD.Barathor: New
	--
	self.grass_flat_no_feature = GetShuffledCopyOfTable(temp_grass_flat_no_feature)
	self.tundra_flat_no_feature = GetShuffledCopyOfTable(temp_tundra_flat_no_feature)
	self.snow_flat_list = GetShuffledCopyOfTable(temp_snow_flat_list)
	self.hills_list = GetShuffledCopyOfTable(temp_hills_list)
	self.land_list = GetShuffledCopyOfTable(temp_land_list)
	self.coast_list = GetShuffledCopyOfTable(temp_coast_list)
	self.marble_list = GetShuffledCopyOfTable(temp_marble_list)
	self.extra_deer_list = GetShuffledCopyOfTable(temp_deer_list)
	self.desert_wheat_list = GetShuffledCopyOfTable(temp_desert_wheat_list)
	self.banana_list = GetShuffledCopyOfTable(temp_banana_list)
	--
	-- Set up the Global Luxury Plot Lists matrix, with indices synched to GetIndicesForLuxuryType()
	self.global_luxury_plot_lists = {
	self.coast_next_to_land_list,				-- 1
	self.marsh_list,							-- 2
	self.flood_plains_list,						-- 3
	self.hills_open_list,						-- 4
	self.hills_covered_list,					-- 5
	self.hills_jungle_list,						-- 6
	self.hills_forest_list,						-- 7
	self.jungle_flat_list,						-- 8
	self.forest_flat_list,						-- 9
	self.desert_flat_no_feature,				-- 10
	self.plains_flat_no_feature,				-- 11
	self.dry_grass_flat_no_feature,				-- 12
	self.fresh_water_grass_flat_no_feature,		-- 13
	self.tundra_flat_including_forests,			-- 14
	self.forest_flat_that_are_not_tundra,		-- 15
	self.grass_flat_no_feature,					-- 16	-- MOD.Barathor: New
	self.tundra_flat_no_feature,				-- 17	-- MOD.Barathor: New
	self.dry_plains_flat_no_feature,			-- 18	-- MOD.Barathor: New
	self.fresh_water_plains_flat_no_feature,	-- 19	-- MOD.Barathor: New
	self.desert_or_tundra_flat_no_feature,		-- 20	-- MOD.Barathor: New
	self.tundra_flat_forest,					-- 21	-- MOD.Barathor: New
	self.hills_open_no_tundra,					-- 22	-- MOD.Barathor: New
	self.hills_open_no_desert,					-- 23	-- MOD.Barathor: New
	self.hills_open_no_tundra_no_desert,		-- 24	-- MOD.Barathor: New
	self.hills_open_no_grass,					-- 25	-- MOD.Barathor: New
	self.hills_open_no_grass_no_tundra,			-- 26   -- MOD.Barathor: New
	self.hills_open_no_grass_no_plains,			-- 27   -- MOD.Barathor: New
	self.hills_covered_no_tundra,				-- 28	-- MOD.Barathor: New
	self.hills_covered_no_grass,				-- 29	-- MOD.Barathor: New
	self.hills_covered_no_grass_no_tundra,		-- 30	-- MOD.Barathor: New
	self.flat_covered,							-- 31	-- MOD.Barathor: New
	self.flat_covered_no_grass,					-- 32	-- MOD.Barathor: New
	self.flat_covered_no_tundra,				-- 33	-- MOD.Barathor: New
	self.flat_covered_no_grass_no_tundra,		-- 34	-- MOD.Barathor: New
	self.flat_open,								-- 35	-- MOD.Barathor: New
	self.flat_open_no_grass_no_plains,			-- 36	-- MOD.Barathor: New
	self.flat_open_no_tundra_no_desert,			-- 37	-- MOD.Barathor: New
	self.flat_open_no_desert,					-- 38	-- MOD.Barathor: New
	self.flat_desert_including_flood,			-- 39	-- MOD.Barathor: New
	};

end

function AssignStartingPlots:ExpandCoastalRing(x, y, radius)
	-- MOD: SAPHT
	-- This function shall be called for each *coastal* plot within some radius of a coastal spawn
	-- it should expand to 4 tiles from this plot and avoid placing city states there
	-- That makes it possible for coastal players to plant at least 3 cities, though
	-- it is still possible the spots are bad, blocked by barbs, etc.
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local impact_value = 99;
	local odd = self.firstRingYIsOdd;
	local even = self.firstRingYIsEven;
	local nextX, nextY, plot_adjustments;
	-- Place Impact!
	local impactPlotIndex = y * iW + x + 1;

	self.cityStateData[impactPlotIndex] = impact_value;

	if radius == 0 then
		return
	end
	-- Place Ripples
	if radius > 0 and radius < iH / 2 then
		for ripple_radius = 1, radius do
			local ripple_value = radius - ripple_radius + 1;
			-- Moving clockwise around the ring, the first direction to travel will be Northeast.
			-- This matches the direction-based data in the odd and even tables. Each
			-- subsequent change in direction will correctly match with these tables, too.
			--
			-- Locate the plot within this ripple ring that is due West of the Impact Plot.
			local currentX = x - ripple_radius;
			local currentY = y;
			-- Now loop through the six directions, moving ripple_radius number of times
			-- per direction. At each plot in the ring, add the ripple_value for that ring 
			-- to the plot's entry in the distance data table.
			for direction_index = 1, 6 do
				for plot_to_handle = 1, ripple_radius do
					-- Must account for hex factor.
				 	if currentY / 2 > math.floor(currentY / 2) then -- Current Y is odd. Use odd table.
						plot_adjustments = odd[direction_index];
					else -- Current Y is even. Use plot adjustments from even table.
						plot_adjustments = even[direction_index];
					end
					-- Identify the next plot in the ring.
					nextX = currentX + plot_adjustments[1];
					nextY = currentY + plot_adjustments[2];
					-- Make sure the plot exists
					if wrapX == false and (nextX < 0 or nextX >= iW) then -- X is out of bounds.
						-- Do not add ripple data to this plot.
					elseif wrapY == false and (nextY < 0 or nextY >= iH) then -- Y is out of bounds.
						-- Do not add ripple data to this plot.
					else -- Plot is in bounds, process it.
						-- Handle any world wrap.
						local realX = nextX;
						local realY = nextY;
						if wrapX then
							realX = realX % iW;
						end
						if wrapY then
							realY = realY % iH;
						end
						-- Record ripple data for this plot.
						local ringPlotIndex = realY * iW + realX + 1;

						self.cityStateData[ringPlotIndex] = 1;
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	else
		print("Unsupported Radius length of ", radius, " passed to PlaceResourceImpact()");
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceResourceImpactRegionalMod(x, y, min_radius, radius, region_number)
	-- MOD.EAP: Clone of original function, but only handles a specific new layer for regional resources. This entire system can be writter better, but thats for later.
	-- This function operates upon one of the "impact and ripple" data overlays for resources.
	-- These data layers are a primary way of preventing assignments from clustering too much.
	-- Impact #s - 1 strategic - 2 luxury - 3 bonus - 4 fish - 5 city states - 6 natural wonders - 7 marble - 8 sheep
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local impact_value = 99;
	local odd = self.firstRingYIsOdd;
	local even = self.firstRingYIsEven;
	local nextX, nextY, plot_adjustments;
	-- Place Impact!
	local impactPlotIndex = y * iW + x + 1;
	
	self.luxuryRegionalData[region_number] = table.fill(0, iW * iH);
	self.luxuryRegionalData[region_number][impactPlotIndex] = impact_value;

	if radius == 0 then
		return
	end
	-- Place Ripples
	if radius > 0 and radius < iH / 2 then
		for ripple_radius = min_radius, radius do
			local ripple_value = radius - ripple_radius + 1;
			-- Moving clockwise around the ring, the first direction to travel will be Northeast.
			-- This matches the direction-based data in the odd and even tables. Each
			-- subsequent change in direction will correctly match with these tables, too.
			--
			-- Locate the plot within this ripple ring that is due West of the Impact Plot.
			local currentX = x - ripple_radius;
			local currentY = y;
			-- Now loop through the six directions, moving ripple_radius number of times
			-- per direction. At each plot in the ring, add the ripple_value for that ring 
			-- to the plot's entry in the distance data table.
			for direction_index = 1, 6 do
				for plot_to_handle = 1, ripple_radius do
					-- Must account for hex factor.
				 	if currentY / 2 > math.floor(currentY / 2) then -- Current Y is odd. Use odd table.
						plot_adjustments = odd[direction_index];
					else -- Current Y is even. Use plot adjustments from even table.
						plot_adjustments = even[direction_index];
					end
					-- Identify the next plot in the ring.
					nextX = currentX + plot_adjustments[1];
					nextY = currentY + plot_adjustments[2];
					-- Make sure the plot exists
					if wrapX == false and (nextX < 0 or nextX >= iW) then -- X is out of bounds.
						-- Do not add ripple data to this plot.
					elseif wrapY == false and (nextY < 0 or nextY >= iH) then -- Y is out of bounds.
						-- Do not add ripple data to this plot.
					else -- Plot is in bounds, process it.
						-- Handle any world wrap.
						local realX = nextX;
						local realY = nextY;
						if wrapX then
							realX = realX % iW;
						end
						if wrapY then
							realY = realY % iH;
						end
						-- Record ripple data for this plot.
						local ringPlotIndex = realY * iW + realX + 1;
						
						if self.luxuryRegionalData[region_number][ringPlotIndex] > 0 then
							-- First choose the greater of the two, existing value or current ripple.
							local stronger_value = math.max(self.luxuryRegionalData[ringPlotIndex], ripple_value);
							-- Now increase it by 2 to reflect that multiple civs are in range of this plot.
							local overlap_value = math.min(50, stronger_value + 2);
							self.luxuryRegionalData[region_number][ringPlotIndex] = overlap_value;
						else
							self.luxuryRegionalData[region_number][ringPlotIndex] = ripple_value;
						end
						
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	else
		print("Unsupported Radius length of ", radius, " passed to PlaceResourceImpact()");
	end
	-- print contents of the table
	--print("luxuryRegionalData");
	--for i, v in ipairs(self.luxuryRegionalData[region_number]) do
	--	print("region_number", region_number, "index", i, "plotindex", v);
	--end
end
------------------------------------------------------------------------------

-- MOD: sapht
-- Clone of original function but this one places "coastal ripple structure" which is not the expanding
-- circle of other placements. We use this for the "prevent coastals spawns from being blocked".
-- The original function is used in a ton of places. Replace calls to this one only for city placement
-- and for coastal spawns. But a similar function might be useful for resource distribution.
function AssignStartingPlots:PlaceResourceImpactCoastalMod(x, y, impact_table_number, radius, radiusCoastal)
	-- This function operates upon one of the "impact and ripple" data overlays for resources.
	-- These data layers are a primary way of preventing assignments from clustering too much.
	-- Impact #s - 1 strategic - 2 luxury - 3 bonus - 4 fish - 5 city states - 6 natural wonders - 7 marble - 8 sheep
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local impact_value = 99;
	local odd = self.firstRingYIsOdd;
	local even = self.firstRingYIsEven;
	local nextX, nextY, plot_adjustments;
	-- Place Impact!
	local impactPlotIndex = y * iW + x + 1;

	self.cityStateData[impactPlotIndex] = impact_value;

	if radius == 0 then
		return
	end
	-- Place Ripples
	if radius > 0 and radius < iH / 2 then
		for ripple_radius = 1, radius do
			local ripple_value = radius - ripple_radius + 1;
			-- Moving clockwise around the ring, the first direction to travel will be Northeast.
			-- This matches the direction-based data in the odd and even tables. Each
			-- subsequent change in direction will correctly match with these tables, too.
			--
			-- Locate the plot within this ripple ring that is due West of the Impact Plot.
			local currentX = x - ripple_radius;
			local currentY = y;
			-- Now loop through the six directions, moving ripple_radius number of times
			-- per direction. At each plot in the ring, add the ripple_value for that ring 
			-- to the plot's entry in the distance data table.
			for direction_index = 1, 6 do
				for plot_to_handle = 1, ripple_radius do
					-- Must account for hex factor.
				 	if currentY / 2 > math.floor(currentY / 2) then -- Current Y is odd. Use odd table.
						plot_adjustments = odd[direction_index];
					else -- Current Y is even. Use plot adjustments from even table.
						plot_adjustments = even[direction_index];
					end
					-- Identify the next plot in the ring.
					nextX = currentX + plot_adjustments[1];
					nextY = currentY + plot_adjustments[2];
					-- Make sure the plot exists
					if wrapX == false and (nextX < 0 or nextX >= iW) then -- X is out of bounds.
						-- Do not add ripple data to this plot.
					elseif wrapY == false and (nextY < 0 or nextY >= iH) then -- Y is out of bounds.
						-- Do not add ripple data to this plot.
					else -- Plot is in bounds, process it.
						-- Handle any world wrap.
						local realX = nextX;
						local realY = nextY;
						if wrapX then
							realX = realX % iW;
						end
						if wrapY then
							realY = realY % iH;
						end
						-- Record ripple data for this plot.
						local ringPlotIndex = realY * iW + realX + 1;

						self.cityStateData[ringPlotIndex] = 1;
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	else
		print("Unsupported Radius length of ", radius, " passed to PlaceResourceImpact()");
	end

	if radiusCoastal > 0 and radiusCoastal < iH / 2 then
		for ripple_radius = 1, radiusCoastal do
			local ripple_value = radiusCoastal - ripple_radius + 1;
			-- Moving clockwise around the ring, the first direction to travel will be Northeast.
			-- This matches the direction-based data in the odd and even tables. Each
			-- subsequent change in direction will correctly match with these tables, too.
			--
			-- Locate the plot within this ripple ring that is due West of the Impact Plot.
			local currentX = x - ripple_radius;
			local currentY = y;
			-- Now loop through the six directions, moving ripple_radius number of times
			-- per direction. At each plot in the ring, add the ripple_value for that ring 
			-- to the plot's entry in the distance data table.
			for direction_index = 1, 6 do
				for plot_to_handle = 1, ripple_radius do
					-- Must account for hex factor.
				 	if currentY / 2 > math.floor(currentY / 2) then -- Current Y is odd. Use odd table.
						plot_adjustments = odd[direction_index];
					else -- Current Y is even. Use plot adjustments from even table.
						plot_adjustments = even[direction_index];
					end
					-- Identify the next plot in the ring.
					nextX = currentX + plot_adjustments[1];
					nextY = currentY + plot_adjustments[2];
					local plot = Map.GetPlot(nextX, nextY);
					if plot:IsCoastalLand() then
						-- Make sure the plot exists
						if wrapX == false and (nextX < 0 or nextX >= iW) then -- X is out of bounds.
							-- Do not add ripple data to this plot.
						elseif wrapY == false and (nextY < 0 or nextY >= iH) then -- Y is out of bounds.
							-- Do not add ripple data to this plot.
						else -- Plot is in bounds, process it.
							-- Handle any world wrap.
							local realX = nextX;
							local realY = nextY;
							if wrapX then
								realX = realX % iW;
							end
							if wrapY then
								realY = realY % iH;
							end
							-- Record ripple data for this plot.
							local ringPlotIndex = realY * iW + realX + 1;

							self.cityStateData[ringPlotIndex] = 1;
							-- 
							-- This is the only call that is proper to this modded function
							self:ExpandCoastalRing(nextX, nextY, 3)
						end
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	else
		print("Unsupported RadiusCoastal length of ", radiusCoastal, " passed to PlaceResourceImpact()");
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:PlaceResourceImpact(x, y, impact_table_number, radius)
	-- This function operates upon one of the "impact and ripple" data overlays for resources.
	-- These data layers are a primary way of preventing assignments from clustering too much.
	-- Impact #s - 1 strategic - 2 luxury - 3 bonus - 4 fish - 5 city states - 6 natural wonders - 7 marble - 8 sheep
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local impact_value = 99;
	local odd = self.firstRingYIsOdd;
	local even = self.firstRingYIsEven;
	local nextX, nextY, plot_adjustments;
	-- Place Impact!
	local impactPlotIndex = y * iW + x + 1;
	if impact_table_number == 1 then
		self.strategicData[impactPlotIndex] = impact_value;
	elseif impact_table_number == 2 then
		self.luxuryData[impactPlotIndex] = impact_value;
	elseif impact_table_number == 3 then
		self.bonusData[impactPlotIndex] = impact_value;
	elseif impact_table_number == 4 then
		self.fishData[impactPlotIndex] = 99;
	elseif impact_table_number == 5 then
		self.cityStateData[impactPlotIndex] = impact_value;
	elseif impact_table_number == 6 then
		self.naturalWondersData[impactPlotIndex] = impact_value;
	elseif impact_table_number == 7 then
		self.marbleData[impactPlotIndex] = 1;
	elseif impact_table_number == 8 then
		self.seaOilData[impactPlotIndex] = 99;
	end
	if radius == 0 then
		return
	end
	-- Place Ripples
	if radius > 0 and radius < iH / 2 then
		for ripple_radius = 1, radius do
			local ripple_value = radius - ripple_radius + 1;
			-- Moving clockwise around the ring, the first direction to travel will be Northeast.
			-- This matches the direction-based data in the odd and even tables. Each
			-- subsequent change in direction will correctly match with these tables, too.
			--
			-- Locate the plot within this ripple ring that is due West of the Impact Plot.
			local currentX = x - ripple_radius;
			local currentY = y;
			-- Now loop through the six directions, moving ripple_radius number of times
			-- per direction. At each plot in the ring, add the ripple_value for that ring 
			-- to the plot's entry in the distance data table.
			for direction_index = 1, 6 do
				for plot_to_handle = 1, ripple_radius do
					-- Must account for hex factor.
				 	if currentY / 2 > math.floor(currentY / 2) then -- Current Y is odd. Use odd table.
						plot_adjustments = odd[direction_index];
					else -- Current Y is even. Use plot adjustments from even table.
						plot_adjustments = even[direction_index];
					end
					-- Identify the next plot in the ring.
					nextX = currentX + plot_adjustments[1];
					nextY = currentY + plot_adjustments[2];
					-- Make sure the plot exists
					if wrapX == false and (nextX < 0 or nextX >= iW) then -- X is out of bounds.
						-- Do not add ripple data to this plot.
					elseif wrapY == false and (nextY < 0 or nextY >= iH) then -- Y is out of bounds.
						-- Do not add ripple data to this plot.
					else -- Plot is in bounds, process it.
						-- Handle any world wrap.
						local realX = nextX;
						local realY = nextY;
						if wrapX then
							realX = realX % iW;
						end
						if wrapY then
							realY = realY % iH;
						end
						-- Record ripple data for this plot.
						local ringPlotIndex = realY * iW + realX + 1;
						if impact_table_number == 1 then
							if self.strategicData[ringPlotIndex] > 0 then
								-- First choose the greater of the two, existing value or current ripple.
								local stronger_value = math.max(self.strategicData[ringPlotIndex], ripple_value);
								-- Now increase it by 2 to reflect that multiple civs are in range of this plot.
								local overlap_value = math.min(50, stronger_value + 2);
								self.strategicData[ringPlotIndex] = overlap_value;
							else
								self.strategicData[ringPlotIndex] = ripple_value;
							end
						elseif impact_table_number == 2 then
							if self.luxuryData[ringPlotIndex] > 0 then
								-- First choose the greater of the two, existing value or current ripple.
								local stronger_value = math.max(self.luxuryData[ringPlotIndex], ripple_value);
								-- Now increase it by 2 to reflect that multiple civs are in range of this plot.
								local overlap_value = math.min(50, stronger_value + 2);
								self.luxuryData[ringPlotIndex] = overlap_value;
							else
								self.luxuryData[ringPlotIndex] = ripple_value;
							end
						elseif impact_table_number == 3 then
							if self.bonusData[ringPlotIndex] > 0 then
								-- First choose the greater of the two, existing value or current ripple.
								local stronger_value = math.max(self.bonusData[ringPlotIndex], ripple_value);
								-- Now increase it by 2 to reflect that multiple civs are in range of this plot.
								local overlap_value = math.min(50, stronger_value + 2);
								self.bonusData[ringPlotIndex] = overlap_value;
							else
								self.bonusData[ringPlotIndex] = ripple_value;
							end
						elseif impact_table_number == 4 then
							if self.fishData[ringPlotIndex] > 0 then
								-- First choose the greater of the two, existing value or current ripple.
								local stronger_value = math.max(self.fishData[ringPlotIndex], ripple_value);
								-- Now increase it by 2 to reflect that multiple civs are in range of this plot.
								local overlap_value = math.min(10, stronger_value + 2);
								self.fishData[ringPlotIndex] = overlap_value;
							else
								self.fishData[ringPlotIndex] = ripple_value;
							end
						elseif impact_table_number == 5 then
							self.cityStateData[ringPlotIndex] = 1;
						elseif impact_table_number == 6 then
							if self.naturalWondersData[ringPlotIndex] > 0 then
								-- First choose the greater of the two, existing value or current ripple.
								local stronger_value = math.max(self.naturalWondersData[ringPlotIndex], ripple_value);
								-- Now increase it by 2 to reflect that multiple civs are in range of this plot.
								local overlap_value = math.min(50, stronger_value + 2);
								self.naturalWondersData[ringPlotIndex] = overlap_value;
							else
								self.naturalWondersData[ringPlotIndex] = ripple_value;
							end
						elseif impact_table_number == 7 then
							self.marbleData[ringPlotIndex] = 1;
						elseif impact_table_number == 8 then
							self.seaOilData[ringPlotIndex] = 1;
						end
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	else
		print("Unsupported Radius length of ", radius, " passed to PlaceResourceImpact()");
	end
end
------------------------------------------------------------------------------
--[[
function AssignStartingPlots:HandleResourcePreferences(plot_list, resources_to_place, res_ID, impact_table_number)

	-- Before we place any resources, this function will first check with the resource preferences table.
	-- (if not present uses the config).
	-- It will then continue to run the normal resource placement function using new lists (if neccesary)
	
	if GameInfo.Resource_Preferences == nil then
		print("GameInfo.Resource_Preferences was nil! -ProcessResourceList");
		-- TO DO: use default values from config file
	end

	local non_prefered_plot_list = plot_list;
	if non_prefered_plot_list == nil then
		print("Plot list was nil! -ProcessResourceList");
		return
	end
	local frequency = self.ResourceTypes[res_ID].Frequency;

	-- main loop
	for i, preference_data in pairs(self.ordered_preference_list) do
		local resource_type = preference_data.ResourceType;
		local data_terrain_type = preference_data.TerrainType;
		local data_feature_type = preference_data.FeatureType;
		local preference_value = preference_data.PreferenceValue;
		
		if resource_type == self.ResourceTypes[res_ID].Type then
			local prefered_plot_list = {};
			
			-- seperate the incoming plot_list into terrain/feature types based on the preference data
			if data_feature_type ~= nil or data_terrain_type ~= nil then
				-- check if any plotindex in the plot_list table matches the terrain/feature type
				for index, plotIndex in pairs(non_prefered_plot_list) do
					local iW, iH = Map.GetGridSize();
					local x = (plotIndex - 1) % iW;
					local y = (plotIndex - x - 1) / iW;
					local plot = Map.GetPlot(x, y);
					local terrainType = plot:GetTerrainType();
					local featureType = plot:GetFeatureType();
					local plotType = plot:GetPlotType();
					
					
					if data_terrain_type ~= "TERRAIN_NONE" then
						-- terrain type is specified
						if data_feature_type ~= "FEATURE_NONE" then
							-- feature type is also specified
							if data_terrain_type == "TERRAIN_HILL" then
								-- check if the plot is actually a hill
								if plotType == PlotTypes.PLOT_HILLS and FeatureTypes[data_feature_type] == featureType then
									table.remove(non_prefered_plot_list, plotIndex);
									table.insert(prefered_plot_list, plotIndex);
								end
							-- check if the plot matches both terrain and feature type
							elseif FeatureTypes[data_feature_type] == featureType and TerrainTypes[data_terrain_type] then
								table.remove(non_prefered_plot_list, plotIndex);
								table.insert(prefered_plot_list, plotIndex);
							end
						-- feature type is not specified
						elseif data_terrain_type == "TERRAIN_HILL" then
							-- check if the plot is actually a hill
							if plotType == PlotTypes.PLOT_HILLS then -- hill
								table.remove(non_prefered_plot_list, plotIndex);
								table.insert(prefered_plot_list, plotIndex);
							end
						elseif TerrainTypes[data_terrain_type] == terrainType then
							table.remove(non_prefered_plot_list, plotIndex);
							table.insert(prefered_plot_list, plotIndex);
						end
					elseif data_feature_type ~= "FEATURE_NONE" then
						-- terrain type is not specified but feature type is
						if FeatureTypes[data_feature_type] == featureType then
							table.remove(non_prefered_plot_list, plotIndex);
							table.insert(prefered_plot_list, plotIndex);
						end
					else
						-- neither terrain nor feature type is specified
					end
				end
				local new_frequency = frequency + preference_value;
				if new_frequency < 1 then
					print("Frequency was less than 1! -ProcessResourceList");
					return;
				elseif table.maxn(prefered_plot_list) > 0 then
					if new_frequency == 22 then
						for index, plotIndex in ipairs(prefered_plot_list) do
							local iW, iH = Map.GetGridSize();
							local x = (plotIndex - 1) % iW;
							local y = (plotIndex - x - 1) / iW;
							local plot = Map.GetPlot(x, y);
							local terrainType = plot:GetTerrainType();
							local featureType = plot:GetFeatureType();
						end
					end
					self:ProcessResourceList_NEW(new_frequency, impact_table_number, prefered_plot_list, resources_to_place)
				end
			end
			
		end
	end
	-- place the resource on the remaining plots with the default frequency
	if table.maxn(non_prefered_plot_list) > 0 and frequency > 0 then
		self:ProcessResourceList_NEW(frequency, impact_table_number, non_prefered_plot_list, resources_to_place)
	else
		--print("No plots left to place resource on or frequency is set to 0 for this resource! -ProcessResourceList");
	end
end
--]]
------------------------------------------------------------------------------
function AssignStartingPlots:ProcessResourceList_NEW(frequency, impact_table_number, plot_list, resources_to_place)
	-- This function needs to receive two numbers and two tables.
	-- Length of the plotlist is divided by frequency to get the number of 
	-- resources to place. ... The first table is a list of plot indices.
	-- The second table contains subtables, one per resource type, detailing the
	-- resource ID number, quantity, weighting, and impact radius of each applicable
	-- resource. If radius min and max are different, the radius length is variable
	-- and a die roll will determine a value >= min and <= max.
	--
	-- The system may be easiest to manage if the weightings add up to 100, so they
	-- can be handled as percentages, but this is not required.
	--
	-- Impact #s - 1 strategic - 2 luxury - 3 bonus
	-- Res data  - 1 ID - 2 quantity - 3 weight - 4 radius min - 5 radius max
	--
	-- The plot list will be processed sequentially, so randomize it in advance.
	-- The default lists are terrain-oriented and are randomized during __Init

	if plot_list == nil then
		--print("Plot list was nil! -ProcessResourceList");
		return
	end
	local iW, iH = Map.GetGridSize();
	local iNumTotalPlots = table.maxn(plot_list);
	local iNumResourcesToPlace = math.ceil(iNumTotalPlots / frequency);
	local res_ID, res_quantity, res_weight, res_min, res_max, res_range, res_threshold;
	local totalWeight, accumulatedWeight = 0, 0;
	-- in this new version we no longer make any use of weights nor allow more than one resource to be selected for placement at the same time.
	for index, resource_data in ipairs(resources_to_place) do
		res_ID = resource_data[1];
		res_quantity = resource_data[2];
		res_min = resource_data[3];
		res_max = resource_data[4];
		if res_max > res_min then
			res_range = res_max - res_min + 1;
		else
			res_range = -1;
		end
	end
	-- Main loop
	local current_index = 1;
	local avoid_ripples = true;
	for place_resource = 1, iNumResourcesToPlace do

		local placed_this_res = false;
		local use_this_res_index = index;

		if avoid_ripples == true then -- Still on first pass through plot_list, seek first eligible 0 value on impact matrix.
			for index_to_check = current_index, iNumTotalPlots do
				if index_to_check == iNumTotalPlots then -- Completed first pass of plot_list, now change to seeking lowest value instead of zero value.
					avoid_ripples = false;
				end
				if placed_this_res == true then
					break
				else
					current_index = current_index + 1;
				end
				local plotIndex = plot_list[index_to_check];
				if impact_table_number == 1 then
					if self.strategicData[plotIndex] == 0 then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then -- Placing this strategic resource in this plot.
							local res_addition = 0;
							if res_range ~= -1 then
								res_addition = Map.Rand(res_range, "Resource Radius - Place Resource LUA");
							end
					
							res_plot:SetResourceType(res_ID, res_quantity);
							if (Game.GetResourceUsageType(res_ID) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY) then
								self.totalLuxPlacedSoFar = self.totalLuxPlacedSoFar + 1;
							end
							self:PlaceResourceImpact(x, y, impact_table_number, res_min + res_addition);
							placed_this_res = true;
							self.amounts_of_resources_placed[res_ID + 1] = self.amounts_of_resources_placed[res_ID + 1] + res_quantity;
						end
					end
				elseif impact_table_number == 2 then
					if self.luxuryData[plotIndex] == 0 then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then -- Placing this luxury resource in this plot.
							local res_addition = 0;
							if res_range[use_this_res_index] ~= -1 then
								res_addition = Map.Rand(res_range, "Resource Radius - Place Resource LUA");
							end
							
							res_plot:SetResourceType(res_ID, res_quantity);
							self:PlaceResourceImpact(x, y, impact_table_number, res_min + res_addition);
							placed_this_res = true;
							self.amounts_of_resources_placed[res_ID + 1] = self.amounts_of_resources_placed[res_ID + 1] + 1;
						end
					end
				elseif impact_table_number == 3 then
					if self.bonusData[plotIndex] == 0 then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then -- Placing this bonus resource in this plot.
							local res_addition = 0;
							if res_range ~= -1 then
								res_addition = Map.Rand(res_range, "Resource Radius - Place Resource LUA");
							end
							
							res_plot:SetResourceType(res_ID, res_quantity);
							self:PlaceResourceImpact(x, y, impact_table_number, res_min + res_addition);
							placed_this_res = true;
							self.amounts_of_resources_placed[res_ID + 1] = self.amounts_of_resources_placed[res_ID + 1] + 1;
						end
					end
				end
			end
		end
		if avoid_ripples == false then -- Completed first pass through plot_list, so use backup method.
			local lowest_impact = 98;
			local best_plot;
			for loop, plotIndex in ipairs(plot_list) do
				if impact_table_number == 1 then
					if lowest_impact > self.strategicData[plotIndex] then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then
							lowest_impact = self.strategicData[plotIndex];
							best_plot = plotIndex;
						end
					end
				elseif impact_table_number == 2 then
					if lowest_impact > self.luxuryData[plotIndex] then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then
							lowest_impact = self.luxuryData[plotIndex];
							best_plot = plotIndex;
						end
					end
				elseif impact_table_number == 3 then
					if lowest_impact > self.bonusData[plotIndex] then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then
							lowest_impact = self.bonusData[plotIndex];
							best_plot = plotIndex;
						end
					end
				end
			end
			if best_plot ~= nil then
				local x = (best_plot - 1) % iW;
				local y = (best_plot - x - 1) / iW;
				local res_plot = Map.GetPlot(x, y)
				local res_addition = 0;
				if res_range ~= -1 then
					res_addition = Map.Rand(res_range, "Resource Radius - Place Resource LUA");
				end
				res_plot:SetResourceType(res_ID, res_quantity);
				self:PlaceResourceImpact(x, y, impact_table_number, res_min + res_addition);
				self.amounts_of_resources_placed[res_ID + 1] = self.amounts_of_resources_placed[res_ID + 1] + res_quantity;
			end
		end
	end
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
function AssignStartingPlots:ProcessResourceList(frequency, impact_table_number, plot_list, resources_to_place)
	-- This function needs to receive two numbers and two tables.
	-- Length of the plotlist is divided by frequency to get the number of 
	-- resources to place. ... The first table is a list of plot indices.
	-- The second table contains subtables, one per resource type, detailing the
	-- resource ID number, quantity, weighting, and impact radius of each applicable
	-- resource. If radius min and max are different, the radius length is variable
	-- and a die roll will determine a value >= min and <= max.
	--
	-- The system may be easiest to manage if the weightings add up to 100, so they
	-- can be handled as percentages, but this is not required.
	--
	-- Impact #s - 1 strategic - 2 luxury - 3 bonus
	-- Res data  - 1 ID - 2 quantity - 3 weight - 4 radius min - 5 radius max
	--
	-- The plot list will be processed sequentially, so randomize it in advance.
	-- The default lists are terrain-oriented and are randomized during __Init

	if plot_list == nil then
		--print("Plot list was nil! -ProcessResourceList");
		return
	end
	local iW, iH = Map.GetGridSize();
	local iNumTotalPlots = table.maxn(plot_list);

	local iNumResourcesToPlace = math.ceil(iNumTotalPlots / frequency);
	local iNumResourcesTypes = table.maxn(resources_to_place);
	
	local res_ID, res_quantity, res_weight, res_min, res_max, res_range, res_threshold = {}, {}, {}, {}, {}, {}, {};
	local totalWeight, accumulatedWeight = 0, 0;
	for index, resource_data in ipairs(resources_to_place) do
		res_ID[index] = resource_data[1];
		res_quantity[index] = resource_data[2];
		res_weight[index] = resource_data[3];
		totalWeight = totalWeight + resource_data[3];
		res_min[index] = resource_data[4];
		res_max[index] = resource_data[5];
		if res_max[index] > res_min[index] then
			res_range[index] = res_max[index] - res_min[index] + 1;
		else
			res_range[index] = -1;
		end
	end

	

	for index = 1, iNumResourcesTypes do
		-- We'll roll a die and check each resource in turn to see if it is 
		-- the one to get placed in that particular case. The weightings are 
		-- used to decide how much percentage of the total each represents.
		-- This chunk sets the threshold for each resource in turn.
		local threshold = (res_weight[index] + accumulatedWeight) * 10000 / totalWeight;
		table.insert(res_threshold, threshold);
		accumulatedWeight = accumulatedWeight + res_weight[index];
	end
	-- Main loop
	local current_index = 1;
	local avoid_ripples = true;
	for place_resource = 1, iNumResourcesToPlace do
		local placed_this_res = false;
		local use_this_res_index = 1;
		local diceroll = Map.Rand(10000, "Choose resource type - Distribute Resources - Lua");
		for index, threshold in ipairs(res_threshold) do
			if diceroll < threshold then -- Choose this resource type.
				use_this_res_index = index;
				break
			end
		end
		if avoid_ripples == true then -- Still on first pass through plot_list, seek first eligible 0 value on impact matrix.
			for index_to_check = current_index, iNumTotalPlots do
				if index_to_check == iNumTotalPlots then -- Completed first pass of plot_list, now change to seeking lowest value instead of zero value.
					avoid_ripples = false;
				end
				if placed_this_res == true then
					break
				else
					current_index = current_index + 1;
				end
				local plotIndex = plot_list[index_to_check];
				if impact_table_number == 1 then
					if self.strategicData[plotIndex] == 0 then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then -- Placing this strategic resource in this plot.
							local res_addition = 0;
							if res_range[use_this_res_index] ~= -1 then
								res_addition = Map.Rand(res_range[use_this_res_index], "Resource Radius - Place Resource LUA");
							end
							--print("ProcessResourceList table 1, Resource: " .. res_ID[use_this_res_index] .. ", Quantity: " .. res_quantity[use_this_res_index]);
							res_plot:SetResourceType(res_ID[use_this_res_index], res_quantity[use_this_res_index]);
							if (Game.GetResourceUsageType(res_ID[use_this_res_index]) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY) then
								self.totalLuxPlacedSoFar = self.totalLuxPlacedSoFar + 1;
							end
							self:PlaceResourceImpact(x, y, impact_table_number, res_min[use_this_res_index] + res_addition);
							placed_this_res = true;
							self.amounts_of_resources_placed[res_ID[use_this_res_index] + 1] = self.amounts_of_resources_placed[res_ID[use_this_res_index] + 1] + res_quantity[use_this_res_index];
						end
					end
				elseif impact_table_number == 2 then
					if self.luxuryData[plotIndex] == 0 then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then -- Placing this luxury resource in this plot.
							local res_addition = 0;
							if res_range[use_this_res_index] ~= -1 then
								res_addition = Map.Rand(res_range[use_this_res_index], "Resource Radius - Place Resource LUA");
							end
							--print("ProcessResourceList table 2, Resource: " .. res_ID[use_this_res_index] .. ", Quantity: " .. res_quantity[use_this_res_index]);
							res_plot:SetResourceType(res_ID[use_this_res_index], res_quantity[use_this_res_index]);
							self:PlaceResourceImpact(x, y, impact_table_number, res_min[use_this_res_index] + res_addition);
							placed_this_res = true;
							self.amounts_of_resources_placed[res_ID[use_this_res_index] + 1] = self.amounts_of_resources_placed[res_ID[use_this_res_index] + 1] + 1;
						end
					end
				elseif impact_table_number == 3 then
					if self.bonusData[plotIndex] == 0 then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then -- Placing this bonus resource in this plot.
							local res_addition = 0;
							if res_range[use_this_res_index] ~= -1 then
								res_addition = Map.Rand(res_range[use_this_res_index], "Resource Radius - Place Resource LUA");
							end
							--print("ProcessResourceList table 3, Resource: " .. res_ID[use_this_res_index] .. ", Quantity: " .. res_quantity[use_this_res_index]);
							res_plot:SetResourceType(res_ID[use_this_res_index], res_quantity[use_this_res_index]);
							self:PlaceResourceImpact(x, y, impact_table_number, res_min[use_this_res_index] + res_addition);
							placed_this_res = true;
							self.amounts_of_resources_placed[res_ID[use_this_res_index] + 1] = self.amounts_of_resources_placed[res_ID[use_this_res_index] + 1] + 1;
						end
					end
				end
			end
		end
		if avoid_ripples == false then -- Completed first pass through plot_list, so use backup method.
			local lowest_impact = 98;
			local best_plot;
			for loop, plotIndex in ipairs(plot_list) do
				if impact_table_number == 1 then
					if lowest_impact > self.strategicData[plotIndex] then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then
							lowest_impact = self.strategicData[plotIndex];
							best_plot = plotIndex;
						end
					end
				elseif impact_table_number == 2 then
					if lowest_impact > self.luxuryData[plotIndex] then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then
							lowest_impact = self.luxuryData[plotIndex];
							best_plot = plotIndex;
						end
					end
				elseif impact_table_number == 3 then
					if lowest_impact > self.bonusData[plotIndex] then
						local x = (plotIndex - 1) % iW;
						local y = (plotIndex - x - 1) / iW;
						local res_plot = Map.GetPlot(x, y)
						if res_plot:GetResourceType(-1) == -1 then
							lowest_impact = self.bonusData[plotIndex];
							best_plot = plotIndex;
						end
					end
				end
			end
			if best_plot ~= nil then
				local x = (best_plot - 1) % iW;
				local y = (best_plot - x - 1) / iW;
				local res_plot = Map.GetPlot(x, y)
				local res_addition = 0;
				if res_range[use_this_res_index] ~= -1 then
					res_addition = Map.Rand(res_range[use_this_res_index], "Resource Radius - Place Resource LUA");
				end
				--print("ProcessResourceList backup, Resource: " .. res_ID[use_this_res_index] .. ", Quantity: " .. res_quantity[use_this_res_index]);
				res_plot:SetResourceType(res_ID[use_this_res_index], res_quantity[use_this_res_index]);
				self:PlaceResourceImpact(x, y, impact_table_number, res_min[use_this_res_index] + res_addition);
				self.amounts_of_resources_placed[res_ID[use_this_res_index] + 1] = self.amounts_of_resources_placed[res_ID[use_this_res_index] + 1] + res_quantity[use_this_res_index];
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceSpecificNumberOfResources(resource_ID, quantity, amount,
	                         ratio, impact_table_number, min_radius, max_radius, plot_list)
	-- This function needs to receive seven numbers and one table.
	--
	-- Resource_ID is the type of resource to place.
	-- Quantity is the in-game quantity of the resource, or 0 if unquantified resource type.
	-- Amount is the number of plots intended to receive an assignment of this resource.
	--
	-- Ratio should be > 0 and <= 1 and is what determines when secondary and tertiary lists 
	-- come in to play. The actual ratio is (AmountOfResource / PlotsInList). For instance, 
	-- if we are assigning Sugar resources to Marsh, then if we are to assign eight Sugar 
	-- resources, but there are only four Marsh plots in the list, a ratio of 1 would assign
	-- a Sugar to every single marsh plot, and then have to return an unplaced value of 4; 
	-- but a ratio of 0.5 would assign only two Sugars to the four marsh plots, and return a 
	-- value of 6. Any ratio less than or equal to 0.25 would assign one Sugar and return
	-- seven, as the ratio results will be rounded up not down, to the nearest integer.
	--
	-- Impact tables: -1 = ignore, 1 = strategic, 2 = luxury, 3 = bonus, 4 = fish
	-- Radius is amount of impact to place on this table when placing a resource.
	--
	-- nil tables are not acceptable but empty tables are fine
	--
	-- The plot lists will be processed sequentially, so randomize them in advance.
	-- 
	
	--print("-"); print("PlaceSpecificResource called. ResID:", resource_ID, "Quantity:", quantity, "Amount:", amount, "Ratio:", ratio);
	
	if plot_list == nil then
		--print("Plot list was nil! -PlaceSpecificNumberOfResources");
		return
	end
	local bCheckImpact = false;
	local impact_table = {};
	if impact_table_number == 1 then
		bCheckImpact = true;
		impact_table = self.strategicData;
	elseif impact_table_number == 2 then
		bCheckImpact = true;
		impact_table = self.luxuryData;
	elseif impact_table_number == 3 then
		bCheckImpact = true;
		impact_table = self.bonusData;
	elseif impact_table_number == 4 then
		bCheckImpact = true;
		impact_table = self.fishData;
	elseif impact_table_number == 8 then
		bCheckImpact = true;
		impact_table = self.seaOilData;
	end
	local iW, iH = Map.GetGridSize();
	local iNumLeftToPlace = amount;
	local iNumPlots = table.maxn(plot_list);
	local iNumResources = math.min(amount, math.ceil(ratio * iNumPlots));


	--MOD.EAP: is this resource a regional luxury? Record its region too
	-- Also set ripple data if we handle the luxury layer
	local bIsRegionalLuxuryValid = true;
	local luxuryRegionNumber = -1;
	local luxuryOtherRegionNumbers = {};
	local bCheckImpactRegLux = false;
	for region_number, res_ID in pairs(self.region_luxury_assignment) do
		if res_ID == resource_ID then
			luxuryRegionNumber = region_number;
			-- record every other region number that is not this one
			for region_number2, res_ID2 in pairs(self.region_luxury_assignment) do
				if region_number2 ~= region_number then
					table.insert(luxuryOtherRegionNumbers, region_number2);
				end
			end
			if self.bDoRegionalLuxCheck then
				bCheckImpactRegLux = true;	
			end
			break;
		end
	end
	--MOD.EAP: End

	-- Main loop
	for place_resource = 1, iNumResources do
		for loop, plotIndex in ipairs(plot_list) do
			-- MOD.EAP: Start
			if bCheckImpactRegLux then
				if self.luxuryRegionalData[luxuryRegionNumber][plotIndex] == 0 then -- resource is not in this region's impact table, so skip it
					bIsRegionalLuxuryValid = false; 
				else
					for loop, region_number in pairs(luxuryOtherRegionNumbers) do
						
						if self.luxuryRegionalData[region_number][plotIndex] ~= 0 then
							bIsRegionalLuxuryValid = false;
						end
					end
				end
			end
			
			if bCheckImpactRegLux == false or bIsRegionalLuxuryValid then -- additional check for regional luxury
			-- MOD.EAP: End
				
				if bCheckImpact == false or impact_table[plotIndex] == 0 then
					
					local x = (plotIndex - 1) % iW;
					local y = (plotIndex - x - 1) / iW;
					local res_plot = Map.GetPlot(x, y)

					if res_plot:GetResourceType(-1) == -1 then -- Placing this resource in this plot.
						 
						res_plot:SetResourceType(resource_ID, quantity);
						self.amounts_of_resources_placed[resource_ID + 1] = self.amounts_of_resources_placed[resource_ID + 1] + quantity;
						
						--print("-"); print("Placed Resource#", resource_ID, "at Plot", x, y);
						self.totalLuxPlacedSoFar = self.totalLuxPlacedSoFar + 1;
						iNumLeftToPlace = iNumLeftToPlace - 1;
						if bCheckImpact == true then
							local res_addition = 0;
							if max_radius > min_radius then
								res_addition = Map.Rand(1 + (max_radius - min_radius), "Resource Radius - Place Resource LUA");
							end
							local rad = min_radius + res_addition;
							self:PlaceResourceImpact(x, y, impact_table_number, rad)
						end
						break
					end
				end
			end
		end
	end
	return iNumLeftToPlace
end
------------------------------------------------------------------------------
function AssignStartingPlots:HandleWaterLuxuriesEligibility(resource_ID, plotIndex, try_number)

	if try_number == 1 and (self.mainland_coast_list_inner[plotIndex] ~= false and self.mainland_coast_list_inner[plotIndex] ~= nil) then
		return true;
	elseif try_number == 2 and ((self.mainland_coast_list_second[plotIndex] ~= false and self.mainland_coast_list_second[plotIndex] ~= nil)
	or (self.mainland_coast_list_inner[plotIndex] ~= false and self.mainland_coast_list_inner[plotIndex] ~= nil)) then -- try both 1st and 2nd ring
		return true;
	else
		return false;
	end

end
------------------------------------------------------------------------------
function AssignStartingPlots:IdentifyRegionsOfThisType(region_type)
	-- Necessary for assigning luxury types to regions.
	local regions_of_this_type = {};
	for index, current_type in ipairs(self.regionTypes) do
		if current_type == region_type then
			table.insert(regions_of_this_type, index);
		end
	end
	local length = table.maxn(regions_of_this_type);
	if length > 0 then
		local scrambled = GetShuffledCopyOfTable(regions_of_this_type);
		for index, region_to_add in ipairs(scrambled) do
			table.insert(self.regions_sorted_by_type, {region_to_add}) -- Note: adding region number as a table, so this data can be expanded later.
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:SortRegionsByType()
	-- Necessary for assigning luxury types to regions.
	for check_this_type = 1, 9 do -- Valid range for default Region Types. Any regions modders be alert to this.
		self:IdentifyRegionsOfThisType(check_this_type)
	end
	self:IdentifyRegionsOfThisType(0) -- If any Undefined Regions, put them at the bottom of the list.
end
------------------------------------------------------------------------------
function AssignStartingPlots:AssignLuxuryToRegion(region_number)
	-- Assigns a luxury type to an individual region.
	local region_type = self.regionTypes[region_number];
	local luxury_candidates;
	local CoastLux = self.CoastLux;
	local BalancedRegionals = Map.GetCustomOption(14)

	if region_type > 0 and region_type < 9 then -- Note: if number of Region Types is modified, this line and the table to which it refers need adjustment.
		luxury_candidates = self.luxury_region_weights[region_type];
	else
		luxury_candidates = self.luxury_fallback_weights; -- Undefined Region, enable all possible luxury types.
	end
	--
	-- Build options list.
	local iNumAvailableTypes = 0;
	local resource_IDs, resource_weights, res_threshold = {}, {}, {};
	-- MOD.EAP: Start
	local split_cap = 1
	if self.iNumCivs > 16 then
		split_cap = 2
	end
	-- MOD.EAP: End
	for index, resource_options in ipairs(luxury_candidates) do
		local res_ID = resource_options[1];
		if self.luxury_assignment_count[res_ID] < split_cap then -- This type still eligible.
			local test = TestMembership(self.resourceIDs_assigned_to_regions, res_ID)
			if self.iNumTypesAssignedToRegions < self.iNumMaxAllowedForRegions or test == true then -- Not a new type that would exceed number of allowed types, so continue.

				-- MOD.EAP: Skip resources that are not allowed to be regional
				local bCanBeRegional = true;
				if BalancedRegionals == 1 then
					if self.ResourceTypes[res_ID].noRegional == true or res_ID == self.marble_ID then -- If the tag doesn't exist we just exclude marble like in vanilla
						print("Removing Res ID: " .. res_ID .. " from regional list");
						bCanBeRegional = false;			
					end
				end

				if bCanBeRegional == true then
					print("Adding Res ID: " .. res_ID .. " to regional list");
					
					--[[ MOD.EAP
						Better regional decision making. 
						Check if the start location has any available plots for the luxury candidate, 
						if not remove it from the candidate list.
					]]
					-- loop trough every plot in 3 rings around the starting plot
					local x = self.startingPlots[region_number][1];
					local y = self.startingPlots[region_number][2];
					local iW, iH = Map.GetGridSize();
					local wrapX = Map:IsWrapX();
					local wrapY = Map:IsWrapY();
					local odd = self.firstRingYIsOdd;
					local even = self.firstRingYIsEven;
					local nextX, nextY, plot_adjustments;
					local results_table = {};
					local radius = 3;

					for ripple_radius = 1, radius do
						local ripple_value = radius - ripple_radius + 1;
						local currentX = x - ripple_radius;
						local currentY = y;
						for direction_index = 1, 6 do
							for plot_to_handle = 1, ripple_radius do
								if currentY / 2 > math.floor(currentY / 2) then
									plot_adjustments = odd[direction_index];
								else
									plot_adjustments = even[direction_index];
								end
								nextX = currentX + plot_adjustments[1];
								nextY = currentY + plot_adjustments[2];
								if wrapX == false and (nextX < 0 or nextX >= iW) then
									-- X is out of bounds.
								elseif wrapY == false and (nextY < 0 or nextY >= iH) then
									-- Y is out of bounds.
								else
									local realX = nextX;
									local realY = nextY;
									if wrapX then
										realX = realX % iW;
									end
									if wrapY then
										realY = realY % iH;
									end
									-- We've arrived at the correct x and y for the current plot.
									local plot = Map.GetPlot(realX, realY);		
									local plotIndex = realY * iW + realX + 1;
									--print("checking if this start has any plots for the luxury candidate");
									if self:CheckResourceEligibility(res_ID, realX, realY) then
										table.insert(results_table, plotIndex);
									end
								end
								currentX, currentY = nextX, nextY;
							end
						end
					end

					local target_list = self:GetRegionLuxuryTargetNumbers()
					local target = target_list[self.iNumCivs]
					
					if #results_table < target then
					
						--skip anything else and go to the next resource
					
					-- MOD.EAP: Uses database data now
					elseif self.ValidTerrainTypes[res_ID] ~= nil then
						for i, validTerrain in pairs(self.ValidTerrainTypes[res_ID]) do
							if validTerrain == TerrainTypes.TERRAIN_COAST then
								-- Water-based resources need to run a series of permission checks: coastal start in region, not a disallowed regions type, enough water, etc.
								if self.startLocationConditions[region_number][1] == true then -- This region's start is along an ocean, so water-based luxuries are allowed.
									-- MOD.Barathor: Start
									-- MOD.Barathor: Base required coastal water total off of the target number of regional luxuries to place.
									local target_list = self:GetRegionLuxuryTargetNumbers()
									local target = target_list[self.iNumCivs]
									local water_needed = 8
									if self.regionTerrainCounts[region_number][8] >= water_needed then -- Enough water available.
										table.insert(resource_IDs, res_ID);
										local adjusted_weight = resource_options[2] / (0.1 + (self.luxury_assignment_count[res_ID]/2)) -- If selected before, for a different region, reduce weight.
										table.insert(resource_weights, adjusted_weight);
										iNumAvailableTypes = iNumAvailableTypes + 1;
										break;
									end
								end
							else
								table.insert(resource_IDs, res_ID);
								local adjusted_weight = resource_options[2] / (1 + self.luxury_assignment_count[res_ID])
								table.insert(resource_weights, adjusted_weight);
								iNumAvailableTypes = iNumAvailableTypes + 1;
								break;
							end
						end
					else
						table.insert(resource_IDs, res_ID);
						local adjusted_weight = resource_options[2] / (1 + self.luxury_assignment_count[res_ID])
						table.insert(resource_weights, adjusted_weight);
						iNumAvailableTypes = iNumAvailableTypes + 1;
					end
				end
			end
		end
	end
	
	-- If options list is empty, pick from fallback options. First try to respect water-resources not being assigned to regions without coastal starts.
	if iNumAvailableTypes == 0 then

		for index, resource_options in ipairs(self.luxury_fallback_weights) do
			local res_ID = resource_options[1];
			if self.luxury_assignment_count[res_ID] < 3 then -- This type still eligible.
				local test = TestMembership(self.resourceIDs_assigned_to_regions, res_ID)
				if self.iNumTypesAssignedToRegions < self.iNumMaxAllowedForRegions or test == true then -- Won't exceed allowed types.
					if res_ID == self.whale_ID or res_ID == self.pearls_ID or res_ID == self.crab_ID or self.bModLuxes and res_ID == self.coral_ID then
						-- No coastal luxes if we use this option
						if not self._lek_coastal_refish then
							if self.startLocationConditions[region_number][1] == true then -- This region's start is along an ocean, so water-based luxuries are allowed.
								-- MOD.Barathor: Start
								-- MOD.Barathor: Base required coastal water total off of the target number of regional luxuries to place.
								local target_list = self:GetRegionLuxuryTargetNumbers()
								local target = target_list[self.iNumCivs]
								local water_needed = 8
								if self.regionTerrainCounts[region_number][8] >= water_needed then -- Enough water available.
									table.insert(resource_IDs, res_ID);
									local adjusted_weight = resource_options[2] / (1 + self.luxury_assignment_count[res_ID]) --If selected before, for a different region, reduce weight.
									table.insert(resource_weights, adjusted_weight);
									iNumAvailableTypes = iNumAvailableTypes + 1;
								end
							end
						end
					elseif res_ID == self.salt_ID then
					-- No salt to regions please, sorry
					else
						table.insert(resource_IDs, res_ID);
						local adjusted_weight = resource_options[2] / (1 + self.luxury_assignment_count[res_ID])
						table.insert(resource_weights, adjusted_weight);
						iNumAvailableTypes = iNumAvailableTypes + 1;
					end
				end
			end
		end
	end

	-- If we get to here and still need to assign a luxury type, it means we have to force a water-based luxury in to this region, period.
	-- This should be the rarest of the rare emergency assignment cases, unless modifications to the system have tightened things too far.
	if iNumAvailableTypes == 0 then
		print("-"); print("Having to use emergency Luxury assignment process for Region#", region_number);
		print("This likely means a near-maximum number of civs in this game, and problems with not having enough legal Luxury types to spread around.");
		print("If you are modifying luxury types or number of regions allowed to get the same type, check to make sure your changes haven't violated the math so each region can have a legal assignment.");
		for index, resource_options in ipairs(self.luxury_fallback_weights) do
			local res_ID = resource_options[1];
			if self.luxury_assignment_count[res_ID] < 3 then -- This type still eligible.
				local test = TestMembership(self.resourceIDs_assigned_to_regions, res_ID)
				if self.iNumTypesAssignedToRegions < self.iNumMaxAllowedForRegions or test == true then -- Won't exceed allowed types.
					table.insert(resource_IDs, res_ID);
					local adjusted_weight = resource_options[2] / (1 + self.luxury_assignment_count[res_ID])
					table.insert(resource_weights, adjusted_weight);
					iNumAvailableTypes = iNumAvailableTypes + 1;
				end
			end
		end
	end
	if iNumAvailableTypes == 0 then -- Bad mojo!
		print("-"); print("FAILED to assign a Luxury type to Region#", region_number); print("-");
	end

	-- Choose luxury.
	local coast_lux = false;
	local num_coast_lux = 0;
	local totalWeight = 0;
	local coastal_luxes = {};
	for i, this_weight in ipairs(resource_weights) do
		totalWeight = totalWeight + this_weight;
	end
	local accumulatedWeight = 0;
	print("----------------------------------- Regional Luxury Assignment Readout For Region #" .. tostring(region_number) .. "-----------------------------------");
	for index = 1, iNumAvailableTypes do
		local threshold = (resource_weights[index] + accumulatedWeight) * 10000 / totalWeight;
		table.insert(res_threshold, threshold);
		accumulatedWeight = accumulatedWeight + resource_weights[index];
		
		if resource_IDs[index] == 13 or resource_IDs[index] == 14 or resource_IDs[index] == 32 or resource_IDs[index] == 49 then
			coast_lux = true;
			num_coast_lux = num_coast_lux + 1;
			coastal_luxes[resource_IDs[index]] = true;
			table.insert(coastal_luxes, resource_IDs[index]);
		end

	end
	local use_this_ID;

	print("");
	print("");
	print("Coast Start: " .. tostring(self.startLocationConditions[region_number][1]));
	print("Coast Lux: " .. tostring(coast_lux));

	local sea_lux_cahnce = Map.Rand(100, "Chance for sea lux as coastal");

	if sea_lux_cahnce > 0 and CoastLux == false then
		coast_lux = false;
	end

	if self.startLocationConditions[region_number][1] == true and coast_lux == true then
		local diceroll = 1 + Map.Rand(num_coast_lux, "Choose resource type - Assign Luxury To Region - Lua");
		print("----------------------- Coastal Lux Chosen -----------------------");
		print("Num Coastal Luxes: " .. tostring(num_coast_lux));
		print("Diceroll: " .. tostring(diceroll));
		use_this_ID = coastal_luxes[diceroll];
		print("Res ID: " .. tostring(use_this_ID));
	else
		local diceroll = Map.Rand(10000, "Choose resource type - Assign Luxury To Region - Lua");
		print("Res Diceroll: " .. diceroll);
		for index, threshold in ipairs(res_threshold) do
			if diceroll <= threshold then -- Choose this resource type.
				use_this_ID = resource_IDs[index];
				break
			end
		end
	end

	return use_this_ID;
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetLuxuriesSplitCap()
	-- This data was separated out to allow easy replacement in map scripts.
	local split_cap = 1;
	-- MOD.Barathor: New -- With a new regional luxury cap of 16, there's no need for a split cap higher than 2 to cover the maximum civ count of 22 (16 x 2 = 32)
	--			   In fact, a split cap of 3 isn't needed in the default game until you pass a civ count of 16 (8 x 2 = 16), not 12.  Split caps higher than 2 are not ideal, and are more random and uneven.
	if self.iNumCivs > 16 then	
		split_cap = 2
	end
	--[[	MOD.Barathor: Disabled
	if self.iNumCivs > 12 then
		split_cap = 3;
	elseif self.iNumCivs > 8 then
		split_cap = 2;
	end
	]]--
	return split_cap
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetCityStateLuxuriesTargetNumber()
	-- This data was separated out to allow easy replacement in map scripts.
	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 3,
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 3,
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 4,
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 4,
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 4,
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 4
		}
	local CSluxCount = worldsizes[Map.GetWorldSize()];
	return CSluxCount
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetDisabledLuxuriesTargetNumber()
	-- This data was separated out to allow easy replacement in map scripts.

	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 10,
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 7,
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 0,
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 3,
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 1,
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 0
		}
	local maxToDisable = worldsizes[Map.GetWorldSize()];
	return maxToDisable
end
------------------------------------------------------------------------------

function AssignStartingPlots:GetRandomLuxuriesTargetNumber()
	--[[ MOD.Barathor:
		 This data was separated out to allow easy replacement in map scripts.
		 With more luxuries available, this ensures that the total luxuries used each game
		 still match the default game, except for Huge, which really needed a few more anyway! 
	local worldsizes = {							
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 4,
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 7,
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 12,
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 14,
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 16,
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 18,
		}
	local maxRandoms = worldsizes[Map.GetWorldSize()]
	]]

	--HB base number of luxes avaliable on the chosen map X & Y size
	-- max is 30, min 4
	local iW, iH = Map.GetGridSize();
	--MOD.EAP: Could place values in config file
	local LandXY = iW * iH
	local maxRandoms = 30
	local baseLuxCount = 8

	if LandXY < 6700 then
		maxRandoms = math.ceil((LandXY-720)/((2560-720)/8)+baseLuxCount)
	end

	return maxRandoms
end
------------------------------------------------------------------------------

function AssignStartingPlots:AssignLuxuryRoles()
	-- Each region gets an individual Luxury type assigned to it.
	-- Each Luxury type can be assigned to no more than three regions.
	-- No more than nine total Luxury types will be assigned to regions.
	-- Between two and four Luxury types will be assigned to City States.
	-- Remaining Luxury types will be distributed at random or left out.
	--
	-- Luxury roles must be assigned before City States can be placed.
	-- This is because civs who are forced to share their luxury type with other 
	-- civs may get extra city states placed in their region to compensate.

	self:SortRegionsByType() -- creates self.regions_sorted_by_type, which will be expanded to store all data regarding regional luxuries.

	-- Assign a luxury to each region.
	for index, region_info in ipairs(self.regions_sorted_by_type) do
		local region_number = region_info[1];
		local resource_ID = self:AssignLuxuryToRegion(region_number)
		self.regions_sorted_by_type[index][2] = resource_ID; -- This line applies the assignment.
		self.region_luxury_assignment[region_number] = resource_ID;
		self.luxury_assignment_count[resource_ID] = self.luxury_assignment_count[resource_ID] + 1; -- Track assignments
		--
		print("-"); print("Region#", region_number, " of type ", self.regionTypes[region_number], " has been assigned Luxury ID#", resource_ID);
		--
		local already_assigned = TestMembership(self.resourceIDs_assigned_to_regions, resource_ID)
		if not already_assigned then
			table.insert(self.resourceIDs_assigned_to_regions, resource_ID);
			self.iNumTypesAssignedToRegions = self.iNumTypesAssignedToRegions + 1;

			-- self.iNumTypesUnassigned = self.iNumTypesUnassigned - 1;	-- MOD.Barathor: This is no longer needed.
		end
	end
	
	-- Assign five of the remaining types to be exclusive to City States.
	-- Build options list.
	local iNumAvailableTypes = 0;
	local resource_IDs, resource_weights = {}, {};
	for index, resource_options in ipairs(self.luxury_city_state_weights) do
		local res_ID = resource_options[1];
		local test = TestMembership(self.resourceIDs_assigned_to_regions, res_ID)
		if test == false then
			table.insert(resource_IDs, res_ID);
			table.insert(resource_weights, resource_options[2]);
			iNumAvailableTypes = iNumAvailableTypes + 1;
		else
			--print("Luxury ID#", res_ID, "rejected by City States as already belonging to Regions.");
		end
	end
	if iNumAvailableTypes < 5 then
		print("---------------------------------------------------------------------------------------");
		print("- Luxuries have been modified in ways disruptive to the City State Assignment Process -");
		print("---------------------------------------------------------------------------------------");
	end
	-- Choose luxuries.
	for cs_lux = 1, 8 do
		local totalWeight = 0;
		local res_threshold = {};
		for i, this_weight in ipairs(resource_weights) do
			totalWeight = totalWeight + this_weight;
		end
		local accumulatedWeight = 0;
		for index, weight in ipairs(resource_weights) do
			local threshold = (weight + accumulatedWeight) * 10000 / totalWeight;
			table.insert(res_threshold, threshold);
			accumulatedWeight = accumulatedWeight + resource_weights[index];
		end
		local use_this_ID;
		local diceroll = Map.Rand(10000, "Choose resource type - City State Luxuries - Lua");
		for index, threshold in ipairs(res_threshold) do
			if diceroll < threshold then -- Choose this resource type.
				use_this_ID = resource_IDs[index];
				table.insert(self.resourceIDs_assigned_to_cs, use_this_ID);
				table.remove(resource_IDs, index);
				table.remove(resource_weights, index);

				--self.iNumTypesUnassigned = self.iNumTypesUnassigned - 1;	-- MOD.Barathor: This is no longer needed.
				--print("-"); print("City States have been assigned Luxury ID#", use_this_ID);
				break
			end
		end
	end
	
	-- Assign Marble to special casing.
	-- table.insert(self.resourceIDs_assigned_to_special_case, self.marble_ID);

	-- self.iNumTypesUnassigned = self.iNumTypesUnassigned - 1;	-- MOD.Barathor: This is no longer needed.
	
	--[[ MOD.Barathor.Barthor:
	
	Modified the next block of code so that increasing the civ count on maps below the maximum Regional 
	luxury total (which is now all of them) won't subtract from the Random total first. 
	Instead, the Disabled total will adjust to whatever is leftover after assignments.
	
	This also optimizes the functionality of the Fallback weights table, so that flexible luxuries can 
	be given a heavier weight when needed as a regional fallback and also will be more likely to be chosen 
	for ranodm distribution throughout the map.  The old default method didn't use weightings for choosing
	random luxuries and instead randomly chose a number of luxuries to disable, then chose all the rest.
	
	--]]
	
	-- MOD.Barathor: Start 
	-- MOD.Barathor: Assign some luxuries to random distribution, disable the rest.
	local remaining_resource_IDs, rand_resource_IDs, rand_resource_weights = {}, {}, {}
	for index, resource_options in ipairs(self.luxury_fallback_weights) do
		local res_ID = resource_options[1]
		local test1 = TestMembership(self.resourceIDs_assigned_to_regions, res_ID)
		local test2 = TestMembership(self.resourceIDs_assigned_to_cs, res_ID)
		if test1 == false and test2 == false then
			table.insert(rand_resource_IDs, res_ID)
			table.insert(rand_resource_weights, resource_options[2])
		else
			--print("Luxury ID#", res_ID, "rejected by Randoms as already belonging to Regions or City States.")
		end
	end	
	
	self.iNumTypesRandom = self:GetRandomLuxuriesTargetNumber()	
	for rand_lux = 1, self.iNumTypesRandom do
		local totalWeight = 0
		local res_threshold = {}
		for i, this_weight in ipairs(rand_resource_weights) do
			totalWeight = totalWeight + this_weight
		end
		local accumulatedWeight = 0
		for index, weight in ipairs(rand_resource_weights) do
			local threshold = (weight + accumulatedWeight) * 10000 / totalWeight
			table.insert(res_threshold, threshold)
			accumulatedWeight = accumulatedWeight + rand_resource_weights[index]
		end
		local use_this_ID
		local diceroll = Map.Rand(10000, "Choose resource type - Random Luxuries - Lua")
		for index, threshold in ipairs(res_threshold) do
			if diceroll < threshold then -- Choose this resource type.
				use_this_ID = rand_resource_IDs[index]
				table.insert(self.resourceIDs_assigned_to_random, use_this_ID)
				table.remove(rand_resource_IDs, index)
				table.remove(rand_resource_weights, index)
				print("-") print("Luxury ID#", use_this_ID, "assigned to Random.")
				break
			end
		end
	end
	
	-- MOD.Barathor: Assign remaining luxuries to Disabled.
	for index, resource_options in ipairs(self.luxury_fallback_weights) do
		local res_ID = resource_options[1]
		--print("-") print("Luxury ID#", res_ID, "checking to disable.")
		local test1 = TestMembership(self.resourceIDs_assigned_to_regions, res_ID)
		local test2 = TestMembership(self.resourceIDs_assigned_to_cs, res_ID)
		local test3 = TestMembership(self.resourceIDs_assigned_to_random, res_ID)
		if test1 == false and test2 == false and test3 == false then
			table.insert(self.resourceIDs_not_being_used, res_ID)
			print("-") print("Luxury ID#", res_ID, "disabled.")
		else
			--print("Luxury ID#", res_ID, "cannot be disabled and already assigned.")
		end
	end
	-- MOD.Barathor: End
	

	--[[ -- MOD.Barathor: Disabled old method
	-- Assign appropriate amount to be Disabled, then assign the rest to be Random.
	local maxToDisable = self:GetDisabledLuxuriesTargetNumber()
	self.iNumTypesDisabled = math.min(self.iNumTypesUnassigned, maxToDisable);
	self.iNumTypesRandom = self.iNumTypesUnassigned - self.iNumTypesDisabled;
	local remaining_resource_IDs = {};
	for index, resource_options in ipairs(self.luxury_fallback_weights) do
		local res_ID = resource_options[1];
		local test1 = TestMembership(self.resourceIDs_assigned_to_regions, res_ID)
		local test2 = TestMembership(self.resourceIDs_assigned_to_cs, res_ID)
		if test1 == false and test2 == false then
			table.insert(remaining_resource_IDs, res_ID);
		end
	end
	local randomized_version = GetShuffledCopyOfTable(remaining_resource_IDs)
	local countdown = math.min(self.iNumTypesUnassigned, maxToDisable);
	for loop, resID in ipairs(randomized_version) do
		if countdown > 0 then
			table.insert(self.resourceIDs_not_being_used, resID);
			countdown = countdown - 1;
		else
			table.insert(self.resourceIDs_assigned_to_random, resID);
		end
	end
	--]]
	
	-- Debug printout of luxury assignments.
	print("--- Luxury Assignment Table ---");
	print("-"); print("- - Assigned to Regions - -");
	for index, data in ipairs(self.regions_sorted_by_type) do
		print("Region#", data[1], "has Luxury type", data[2]);
	end
	print("-"); print("Total unique regional luxuries: ", self.iNumTypesAssignedToRegions);		-- MOD.Barathor: New -- I just added this for easier debugging and some other tests.
	print("-"); print("- - Assigned to City States - -");
	for index, type in ipairs(self.resourceIDs_assigned_to_cs) do
		print("Luxury type", type);
	end
	print("-"); print("- - Assigned to Random - -");
	for index, type in ipairs(self.resourceIDs_assigned_to_random) do
		print("Luxury type", type);
	end
	print("-"); print("- - Luxuries handled via Special Case - -");
	for index, type in ipairs(self.resourceIDs_assigned_to_special_case) do
		print("Luxury type", type);
	end
	print("-"); print("- - Disabled - -");
	for index, type in ipairs(self.resourceIDs_not_being_used) do
		print("Luxury type", type);
	end
	print("- - - - - - - - - - - - - - - -");
	--	
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetListOfAllowableLuxuriesAtCitySite(x, y, radius)
	
	local allowed_luxuries = table.fill(false, 99)	-- MOD.Barathor: original = 35; updated to hold higher luxury ID's
	local plot = Map.GetPlot(x, y)
	for loopPlot in PlotAreaSweepIterator(plot, radius, SECTOR_NORTH, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do
		if loopPlot:GetResourceType(-1) == -1 and not loopPlot:IsLake() then
			for i, resource in ipairs(LekmapResourceInfos) do
				if LekmapResourceInfos[i].ResourceClassType == "RESOURCECLASS_LUXURY"
				and LekmapResourceInfos:is_valid_on(resource.ID, x, y, true) then
					allowed_luxuries[resource.ID] = true
				end
			end
		end
	end
return allowed_luxuries end

------------------------------------------------------------------------------
-- MOD.EAP: New function
function AssignStartingPlots:CheckResourceEligibility(resource_ID, x, y)

	--[[ MOD.EAP:
		For luxuries, We can technically check for valid features here, however this would limit the amount of flexibility certain resources have.
		We therefore do all the regular feature checking for luxuries in FixResourceGraphics() instead.
		Non luxury resources do not have to be flexable, so we actually want to handle them by checking valid features and plot types here.
		We still assume that resources will never spawn on atoll, ice, oasis or mountain tiles. This is one of the only hardcoded
		things I will allow, otherwise this function becomes too complicated for too little gain.
	]]

	-- plot info
	local iW, iH = Map.GetGridSize()
	local plot = Map.GetPlot(x, y)
	local plotIndex = y * iW + x + 1
	local terrainType = plot:GetTerrainType()
	local featureType = plot:GetFeatureType()
	local plotType = plot:GetPlotType()

	-- resource info
	local resource = self.ResourceTypes[resource_ID]

	--check if the resource does not have any of the usually illegal feature types in ValidFeatures table
	if featureType == FeatureTypes.FEATURE_ICE 
	or featureType == self.feature_atoll 
	or featureType == FeatureTypes.FEATURE_OASIS 
	or plotType == PlotTypes.PLOT_MOUNTAIN 
	or plot:IsLake() then return false end -- might want to add support for lake resources later

	if resource.isForMinor or resource.isForCivType ~= nil 
	or resource.Special then return false end 
	-- exlude special case resources
	
	-- extra checks for non-luxury resources
	if resource.Class ~= "RESOURCECLASS_LUXURY" then
		if (plotType == PlotTypes.PLOT_HILLS and (not resource.canBeHill)) 
		or (plotType == PlotTypes.PLOT_LAND and (not resource.canBeFlat)) then return false end
		-- if the resource cannot be on flat nor hill terrain, it is considered a water resource and can only spawn on coast.
	end

	function CheckValidDataTable(table)
		if table[resource_ID] == nil then return false end
		for i, validTerrain in pairs(table[resource_ID]) do					
			if TerrainTypes[validTerrain] == terrainType or (plotType == PlotTypes.PLOT_LAND and validTerrain == "TERRAIN_HILL") then
				-- resources that have the terrain hill in their valid terrain table can spawn anywhere on hills if on land.
				if resource.Class == "RESOURCECLASS_LUXURY" then return true end
				if self.ValidFeatureTypes[resource_ID] ~= nil and featureType ~= FeatureTypes.NO_FEATURE then
					for i, validFeature in pairs(self.ValidFeatureTypes[resource_ID]) do
						if FeatureTypes[validFeature] == featureType then return true end
					end
				elseif featureType == FeatureTypes.NO_FEATURE then return true end
			end
		end
	return false end
	if CheckValidDataTable(self.ValidTerrainTypes) 
	or CheckValidDataTable(self.ValidTerrainFeatureTypes) then return true end
	
	-- if no entries found in either table, assume it can be on any terrain (except snow)
	-- this is not supposed to happen anyways if you enter the correct data in the xml.
	if self.ValidTerrainFeatureTypes[resource_ID] == nil and self.ValidTerrainTypes[resource_ID] == nil then
		if terrainType ~= TerrainTypes.TERRAIN_SNOW then
			--print("Could not find any entries for resource ID#", resource_ID, "assigning it to anything");
			return true
		end
	end	
	
return false end
------------------------------------------------------------------------------
function AssignStartingPlots:GenerateLuxuryPlotListsAtCitySite(x, y, radius, luxury_type, bRemoveFeatureIce)

	
--[[
	for _, plot in pairs(plot_list) do
		local x, y = plot:GetX(), plot:GetY()
		local iW, iH = Map.GetGridSize()
		local plotIndex = x * iW + y + 1
		if bRemoveFeatureIce == true then
			if plot:GetFeatureType() == FeatureTypes.FEATURE_ICE then
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1)
			end
		elseif LekmapResourceInfos:is_valid_on(luxury_type, x, y, true) then
			--table.insert(results_table, plotIndex)
		end
	end
--]]
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local odd = self.firstRingYIsOdd;
	local even = self.firstRingYIsEven;
	local nextX, nextY, plot_adjustments;
	local results_table = {};
	-- For notes on how the hex-iteration works, refer to PlaceResourceImpact()
	if radius > 0 and radius < 6 then
		for ripple_radius = 1, radius do
			local ripple_value = radius - ripple_radius + 1;
			local currentX = x - ripple_radius;
			local currentY = y;
			for direction_index = 1, 6 do
				for plot_to_handle = 1, ripple_radius do
				 	if currentY / 2 > math.floor(currentY / 2) then
						plot_adjustments = odd[direction_index];
					else
						plot_adjustments = even[direction_index];
					end
					nextX = currentX + plot_adjustments[1];
					nextY = currentY + plot_adjustments[2];
					if wrapX == false and (nextX < 0 or nextX >= iW) then
						-- X is out of bounds.
					elseif wrapY == false and (nextY < 0 or nextY >= iH) then
						-- Y is out of bounds.
					else
						local realX = nextX;
						local realY = nextY;
						if wrapX then
							realX = realX % iW;
						end
						if wrapY then
							realY = realY % iH;
						end
						-- We've arrived at the correct x and y for the current plot.
						local plot = Map.GetPlot(realX, realY);		
						local plotIndex = realY * iW + realX + 1;
						
						-- If Ice removal is enabled, process only that.
						if bRemoveFeatureIce == true then
							if featureType == FeatureTypes.FEATURE_ICE then
								plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
							end
						-- Otherwise generate the plot list.
						elseif self:CheckResourceEligibility(luxury_type, realX, realY) then
							table.insert(results_table, plotIndex);
						end
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	end

	return results_table
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
function AssignStartingPlots:GenerateLuxuryPlotListsInRegion(region_number)
	local iW, iH = Map.GetGridSize();
	-- This function groups a region's plots in to lists, for Luxury resource assignment.
	local region_data_table = self.regionData[region_number];
	local iWestX = region_data_table[1];
	local iSouthY = region_data_table[2];
	local iWidth = region_data_table[3];
	local iHeight = region_data_table[4];
	local iAreaID = region_data_table[5];
	local region_area_object;

	local results_table = {};

	if iAreaID ~= -1 then
		region_area_object = Map.GetArea(iAreaID);
	end
	-- Iterate through the region's Plots
	for region_loop_y = 0, iHeight - 1 do
		for region_loop_x = 0, iWidth - 1 do
			local x = (region_loop_x + iWestX) % iW;
			local y = (region_loop_y + iSouthY) % iH;
			local plotIndex = y * iW + x + 1;
			local plot = Map.GetPlot(x, y);
			local area_of_plot = plot:GetArea();
			
			--Repurposed to just dump all plots that are part of the region in a table to use later
			table.insert(results_table, plot)
		end
	end
	return results_table
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetRegionLuxuryTargetNumbers()
	-- This data was separated out to allow easy replacement in map scripts.
	--
	-- This table, indexed by civ-count, provides the target amount of luxuries to place in each region.
	-- MOD.Barathor: Updated -- increased inital value when increasing total civ count by 2.  Instead of decreasing by 2, it'll decrease copies of regional luxuries placed by 1.
	-- MOD.Barathor: Rough Example -- Standard 8 civs x 6 copies of each regional luxury = 48 ... 10 x 4 = 40 ... 10 x 5 = 50 ... 50 is closer to 48 than 40
	-- MOD.Barathor: This will not hurt the random luxury total to be placed since it always places a minimum number at least.  
	local duel_values = table.fill(1, 22); -- Max is one per region for all player counts at this size.
	--
	--[[	MOD.Barathor: Disabled -- old values
	local tiny_values = {0, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
	--
	local small_values = {0, 3, 3, 3, 4, 4, 4, 3, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
	--
	local standard_values = {0, 3, 3, 4, 4, 5, 5, 6, 5, 4, 4, 3, 3, 2, 2, 1, 1, 1, 1, 1, 1, 1};
	--
	local large_values = {0, 3, 4, 4, 5, 5, 5, 6, 6, 7, 6, 5, 5, 4, 4, 3, 3, 2, 2, 2, 2, 2};
	--
	local huge_values = {0, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 8, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2};
	]]--
	-- MOD.Barathor: Updated -- new values
	local tiny_values = {0, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
	--
	local small_values = {0, 3, 3, 3, 4, 4, 4, 3, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
	--
	local standard_values = {0, 3, 3, 4, 4, 5, 5, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 1, 1, 1, 1};
	--
	local large_values = {0, 3, 4, 4, 5, 5, 5, 6, 6, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 2, 2};
	--
	local huge_values = {0, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3};
	--
	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = duel_values,
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = tiny_values,
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = small_values,
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = standard_values,
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = large_values,
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = huge_values
		}
	local target_list = worldsizes[Map.GetWorldSize()];
	return target_list
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetWorldLuxuryTargetNumbers()
	-- This data was separated out to allow easy replacement in map scripts.
	--
	-- The first number is the target for total luxuries in the world, NOT
	-- counting the one-per-civ "second type" added at start locations.
	--
	-- The second number affects minimum number of random luxuries placed.
	-- I say "affects" because it is only one part of the formula.
	local worldsizes = {};
	if self.resource_setting == 1 or self.resource_setting == 2 or self.resource_setting == 3 then -- Sparse / Mediocre
		worldsizes = {
			[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {14, 3},
			[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {24, 4},
			[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {36, 4},
			[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {48, 5},
			[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {60, 5},
			[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {76, 6}
		}
	elseif self.resource_setting == 7 or self.resource_setting == 8 or self.resource_setting == 9 or self.resource_setting == 10 then -- Abundant / Plenty
		worldsizes = {
			[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {24, 3},
			[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {40, 4},
			[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {80, 5},
			[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {80, 5},
			[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {100, 5},
			[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {128, 6}
		}
	else -- Standard
		worldsizes = {
			[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {20, 3},
			[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {35, 4},
			--[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {60, 5},
			[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {53, 5},
			[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {60, 5},
			[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {88, 5},
			[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {112, 6}
		}
	end
	local world_size_data = worldsizes[Map.GetWorldSize()];
	return world_size_data
end

------------------------------------------------------------------------------
function AssignStartingPlots:PlaceLuxuries()
	-- This function is dependent upon AssignLuxuryRoles() and PlaceCityStates() having been executed first.

	--[[ MOD.EAP: Rewritten this function to no longer use preference lists and indices. 
 	 Plot lists are now generated solely based on valid terrain using xml data.
	 
	]]

	LekmapPlaceResources:place_luxuries()

	local iW, iH = Map.GetGridSize();
	-- Place Luxuries at civ start locations.
	local used_randoms_as_secondaries =	table.fill(false, 99);
--[[
	for loop, reg_data in ipairs(self.regions_sorted_by_type) do
		local region_number = reg_data[1];
		local this_region_luxury = reg_data[2];
		local x = self.startingPlots[region_number][1];
		local y = self.startingPlots[region_number][2];
		print("-"); print("Attempting to place Luxury#", this_region_luxury, "at start plot", x, y, "in Region#", region_number);
		-- Determine number to place at the start location
		local iNumToPlace = 2;	-- MOD.Barathor: Updated -- original = 1 -- Most times, 2 of the initial type are placed at the start anyway, because of the old fertility checks below.  This will make it consistent.
		if self.start_locations == 1 or self.start_locations == 2 then -- Legendary Start
			iNumToPlace = 3;	-- MOD.Barathor: Updated -- original = 2
		end

		-- First pass, checking only first two rings with a 50% ratio.
		local luxury_plot_lists = self:GenerateLuxuryPlotListsAtCitySite(x, y, 2, this_region_luxury, false)
		local shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
		local iNumLeftToPlace = 0
		--local iNumLeftToPlace = self:PlaceSpecificNumberOfResources(this_region_luxury, 1, iNumToPlace, 0.5, -1, 0, 0, shuf_list);

		if iNumLeftToPlace > 0 then
			print("-"); print("Unable to place all of this Luxury at the start plot at the first pass. Going second pass.");
			-- Second pass, checking three rings with a 100% ratio.
			luxury_plot_lists = self:GenerateLuxuryPlotListsAtCitySite(x, y, 3, this_region_luxury, false)
			shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(this_region_luxury, 1, iNumLeftToPlace, 1, -1, 0, 0, shuf_list);
		end

		if iNumLeftToPlace > 0 then
			print ("Unable to place all of this Luxury at the start plot at the second pass. Placing remainder in the region.");
			-- If we haven't been able to place all of this lux type at the start, it CAN be placed
			-- in the region somewhere. Subtract remainder from this region's compensation, so that the
			-- regional process, later, will attempt to place this remainder somewhere in the region.
			self.luxury_low_fert_compensation[this_region_luxury] = self.luxury_low_fert_compensation[this_region_luxury] - iNumLeftToPlace;
			self.region_low_fert_compensation[region_number] = self.region_low_fert_compensation[region_number] - iNumLeftToPlace;
		end

		if iNumLeftToPlace > 0 and self.iNumTypesRandom > 0 then
			-- We'll attempt to place one source of a Luxury type assigned to random distribution.
			local randoms_to_place = 1;
			for loop, random_res in ipairs(self.resourceIDs_assigned_to_random) do
				local luxury_plot_lists = self:GenerateLuxuryPlotListsAtCitySite(x, y, 3, random_res, false)	
				if randoms_to_place > 0 then
					shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
					randoms_to_place = self:PlaceSpecificNumberOfResources(random_res, 1, 1, 1, -1, 0, 0, shuf_list);
				end
			end
		end
	end
--]]
	-- Place Luxuries at City States.
	-- Candidates include luxuries exclusive to CS, the lux assigned to this CS's region (if in a region), and the randoms.

--[[
	for city_state = 1, self.iNumCityStates do
		-- First check to see if this city state number received a valid start plot.
		if self.city_state_validity_table[city_state] == false then
			-- This one did not! It does not exist on the map nor have valid data, so we will ignore it.
		else
			
			-- OK, it's a valid city state. Process it.
			local region_number = self.city_state_region_assignments[city_state];
			local x = self.cityStatePlots[city_state][1];
			local y = self.cityStatePlots[city_state][2];
			local allowed_luxuries = self:GetListOfAllowableLuxuriesAtCitySite(x, y, 2)
			local lux_possible_for_cs = {}; -- Recorded with ID as key, weighting as data entry
			-- Identify Allowable Luxuries assigned to City States.
			-- If any CS-Only types are eligible, then all combined will have a weighting of 80%
			local cs_only_types = {};
			for loop, res_ID in ipairs(self.resourceIDs_assigned_to_cs) do
				local luxury_plot_lists = self:GenerateLuxuryPlotListsAtCitySite(x, y, 2, res_ID, false)
				if allowed_luxuries[res_ID] and #luxury_plot_lists ~= 0 then
					table.insert(cs_only_types, res_ID);
				end
			end
			local iNumCSAllowed = table.maxn(cs_only_types);
			if iNumCSAllowed > 0 then
				for loop, res_ID in ipairs(cs_only_types) do
					lux_possible_for_cs[res_ID] = 80 / iNumCSAllowed;
				end
			end
			-- Identify Allowable Random Luxuries and the Regional Luxury if any.
			-- If any random types are eligible (plus the regional type if in a region) these combined carry a 20% weighting.
			if self.iNumTypesRandom > 0 or region_number > 0 then
				local random_types_allowed = {};
				for loop, res_ID in ipairs(self.resourceIDs_assigned_to_random) do
					local luxury_plot_lists = self:GenerateLuxuryPlotListsAtCitySite(x, y, 2, res_ID, false)
					if allowed_luxuries[res_ID] and #luxury_plot_lists ~= 0 then
						table.insert(random_types_allowed, res_ID);
					end
				end

				local iNumRandAllowed = table.maxn(random_types_allowed);
				local iNumAllowed = iNumRandAllowed;
				if iNumRandAllowed > 0 then
					for loop, res_ID in ipairs(random_types_allowed) do
						lux_possible_for_cs[res_ID] = 20 / iNumAllowed;
					end
				end
			end

			-- If there are no allowable luxury types at this city site, then this city state gets none.
			local iNumAvailableTypes = table.maxn(lux_possible_for_cs);
			if iNumAvailableTypes == 0 then
				print("City State #", city_state, "has poor land, ineligible to receive a Luxury resource.");
			else
				print("#############################################")
				print("-"); print("City State #", city_state, "is eligible to receive a Luxury resource.");
				print("#############################################")
				-- Calculate probability thresholds for each allowable luxury type.
				local res_threshold = {};
				local totalWeight, accumulatedWeight = 0, 0;
				for res_ID, this_weight in pairs(lux_possible_for_cs) do
					totalWeight = totalWeight + this_weight;
				end

				-- Choose luxury type.
				local use_this_ID;
				local diceroll = Map.Rand(10000, "Choose resource type - Assign Luxury To City State - Lua");

				for res_ID, this_weight in pairs(lux_possible_for_cs) do
					local threshold = (this_weight + accumulatedWeight) * 10000 / totalWeight;
					if diceroll < threshold then
						use_this_ID = res_ID;
						print("CS Given Lux ID: " .. tostring(use_this_ID));
						break
					end
					accumulatedWeight = accumulatedWeight + this_weight;
				end

				print("-"); print("-"); print("-Assigned Luxury Type", use_this_ID, "to City State#", city_state);
				-- Place luxury.
				local luxury_plot_lists = self:GenerateLuxuryPlotListsAtCitySite(x, y, 2, use_this_ID, false)
				local shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
				local iNumLeftToPlace = self:PlaceSpecificNumberOfResources(use_this_ID, 1, 1, 1, -1, 0, 0, shuf_list);
				if iNumLeftToPlace == 0 then
					print("-"); print("Placed Luxury ID#", use_this_ID, "at City State#", city_state, "in Region#", region_number, "located at Plot", x, y);
				end		
			end
		end
	end
--]]
--[[
	-- Place Regional Luxuries
	for region_number, res_ID in ipairs(self.region_luxury_assignment) do
		print("-"); print("- - -"); print("Attempting to place regional luxury #", res_ID, "in Region#", region_number);
		local iNumAlreadyPlaced = self.amounts_of_resources_placed[res_ID + 1];
		local assignment_split = self.luxury_assignment_count[res_ID];
		local shuf_list, iNumLeftToPlace;
		local luxury_plot_lists = self:GenerateLuxuryPlotListsInRegion(region_number, res_ID)

		-- Calibrate number of luxuries per region to world size and number of civs
		-- present. The amount of lux per region should be at its highest when the 
		-- number of civs in the game is closest to "default" for that map size.
		local target_list = self:GetRegionLuxuryTargetNumbers()
		local targetNum = target_list[self.iNumCivs] 		-- MOD.Barathor: Updated -- Keep it simple and consistent.  Plus, fertility compensation above is disabled anyway.
		-- local targetNum = math.floor((target_list[self.iNumCivs] + (0.5 * self.luxury_low_fert_compensation[res_ID])) / assignment_split);	-- MOD.Barathor: Disabled
		targetNum = targetNum - self.region_low_fert_compensation[region_number];
		-- Adjust target number according to Resource Setting.
		if self.resource_setting == 1 or self.resource_setting == 2 then --sparse
			targetNum = targetNum - 2;
		elseif self.resource_setting == 3 or self.resource_setting == 4 or self.resource_setting == 5 or self.resource_setting == 6 then --mediocre
			targetNum = targetNum - 1;
		elseif self.resource_setting == 7 then --plenty
			targetNum = targetNum + 1;
		elseif self.resource_setting == 8 or self.resource_setting == 9 or self.resource_setting == 10 then --abundant
			targetNum = targetNum + 2;
		end
		local iNumThisLuxToPlace = math.max(1, targetNum); -- Always place at least one.

		print("-"); print("Target number for Luxury#", res_ID, "with assignment split of", assignment_split, "is", targetNum);
		
		-- Place luxuries.
		-- MOD.EAP: Make sure to check the lux is not too far from the player or too close to another player
		self.bDoRegionalLuxCheck = true;
		shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
		iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, 1, iNumThisLuxToPlace, 1, 2, 1, 3, shuf_list);

		print("-"); print("-"); print("Number of LuxuryID", res_ID, "left to place in Region#", region_number, "is", iNumLeftToPlace);
		local num_tries = 0;
		while iNumLeftToPlace > 0 and num_tries < 6 do -- could use targetNum
			-- Second pass, checking all 6 times to make sure the target total is reached for this region!
			shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, 1, iNumLeftToPlace, 1, 2, 1, 3, shuf_list);
			num_tries = num_tries + 1;
		end
		if iNumLeftToPlace > 0 then
			print("-"); print("-"); print("Unable to place all of this Luxury in Region#", region_number, "at the second pass. Placing remainder without checking custom ripple data");
			self.bDoRegionalLuxCheck = false;
			shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, 1, iNumLeftToPlace, 1, 2, 1, 3, shuf_list);
		end
	end
--]]
--[[
	-- Place Random Luxuries
	if self.iNumTypesRandom > 0 then
		print("* *"); print("* iNumTypesRandom = ", self.iNumTypesRandom); print("* *");
		-- This table governs targets for total number of luxuries placed in the world, not
		-- including the "extra types" of Luxuries placed at start locations. These targets
		-- are approximate. An additional random factor is added in based on number of civs.
		-- Any difference between regional and city state luxuries placed, and the target, is
		-- made up for with the number of randomly placed luxuries that get distributed.
		local world_size_data = self:GetWorldLuxuryTargetNumbers()
		local targetLuxForThisWorldSize = world_size_data[1];
		local loopTarget = world_size_data[2];
		local extraLux = Map.Rand(self.iNumCivs, "Luxury Resource Variance - Place Resources LUA");
		local iNumRandomLuxTarget = targetLuxForThisWorldSize + extraLux - self.totalLuxPlacedSoFar;
		print("* *"); print("* targetLuxForThisWorldSize = ", targetLuxForThisWorldSize); print("* *");	-- MOD.Barathor: Test
		print("* *"); print("* random to add to target = ", extraLux); print("* *");					-- MOD.Barathor: Test
		print("* *"); print("* totalLuxPlacedSoFar = ", self.totalLuxPlacedSoFar); print("* *");		-- MOD.Barathor: Test
		print("* *"); print("* iNumRandomLuxTarget = ", iNumRandomLuxTarget); print("* *");				-- MOD.Barathor: Test
		local iNumRandomLuxPlaced, iNumThisLuxToPlace = 0, 0;
		-- This table weights the amount of random luxuries to place, with first-selected getting heavier weighting.
		local random_lux_ratios_table = {
		{1},
		{1, 1},
		{1, 1, 1},
		{1, 1, 1, 1},
		{1, 1, 1, 1, 1},
		{1, 1, 1, 1, 1, 1},
		{1, 1, 1, 1, 1, 1, 1},
		{1, 1, 1, 1, 1, 1, 1, 1} };

		for loop, res_ID in ipairs(self.resourceIDs_assigned_to_random) do

			local iW, iH = Map.GetGridSize();
			local LandXY = iW * iH;
			local NumRandToAdd = 4;

			-- MOD.EAP: Edited numbers by -2 to decrease the amount of random luxuries placed.
			if LandXY < 2500 then
				NumRandToAdd = 2;
			elseif LandXY < 6000 then
				NumRandToAdd = 3;
			elseif LandXY < 10000 then
				NumRandToAdd = 4;
			end

			iNumThisLuxToPlace = math.max(NumRandToAdd, math.ceil(iNumRandomLuxTarget / 10));

			local lux_distance = 3;

			-- Place this luxury type.
			if self.global_luxury_plot_lists_temp[res_ID] == nil then
				break;
			end
			current_list = self.global_luxury_plot_lists_temp[res_ID];
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, 1, iNumThisLuxToPlace, 0.5, 2, lux_distance, 0, current_list);
			iNumRandomLuxPlaced = iNumRandomLuxPlaced + iNumThisLuxToPlace - iNumLeftToPlace;
			print("-"); 
			print("Random Luxury ID#:", res_ID);	-- MOD.Barathor: Test
			print("-"); print("Random Luxury Target Number:", iNumThisLuxToPlace);
			print("Random Luxury Target Placed:", iNumThisLuxToPlace - iNumLeftToPlace); print("-");
		end
		print("-"); print("+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+");
		print("+ Random Luxuries Target Number:", iNumRandomLuxTarget);
		print("+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+");
		print("+ Random Luxuries Number Placed:", iNumRandomLuxPlaced);
		print("+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"); print("-");
	end
--]]
--[[
	-- For Resource settings other than Sparse, add a second luxury type at start locations.
	-- This second type will be selected from Random types if possible, CS types if necessary, and other regions' types as a final fallback.
	-- Marble is included in the types possible to be placed.
	local placed2ndLux = true;

	if self.resource_setting ~= 1 then
		-- First pass with 2 rings, then second pass with 3 rings.
		for i = 2, 3 do
			print("|||||||||||||||||||||||||||||||||||| Secondary Lux Check ||||||||||||||||||||||||||||||||||||");

			local coastal_rotation = 1;
			for region_number = 1, self.iNumCivs do
				local x = self.startingPlots[region_number][1];
				local y = self.startingPlots[region_number][2];

				local cplot = Map.GetPlot(x, y)

				local use_this_ID;
				local candidate_types, iNumTypesAllowed = {}, 0;
				local allowed_luxuries = self:GetListOfAllowableLuxuriesAtCitySite(x, y, i)
				print("-"); print("--- Eligible Types List for Second Luxury in Region#", region_number, "---");
				-- See if any Random types are eligible.
				for loop, res_ID in ipairs(self.resourceIDs_assigned_to_random) do
					if allowed_luxuries[res_ID] == true and used_randoms_as_secondaries[res_ID] == false then
						iNumTypesAllowed = iNumTypesAllowed + 1;
						table.insert(candidate_types, res_ID);
					end
				end
				-- Check to see if any Special Case luxuries are eligible. Disallow if Strategic Balance resource setting.
				if (self.start_locations ~= 1) and (self.start_locations ~= 2) and (self.start_locations ~= 3) then
					for loop, res_ID in ipairs(self.resourceIDs_assigned_to_special_case) do
						if allowed_luxuries[res_ID] == true and used_randoms_as_secondaries[res_ID] == false then
							iNumTypesAllowed = iNumTypesAllowed + 1;
							table.insert(candidate_types, res_ID);
						end
					end
				end


				if iNumTypesAllowed > 0 then
					local diceroll = 1 + Map.Rand(iNumTypesAllowed, "Choosing second luxury type at a start location - LUA");
					use_this_ID = candidate_types[diceroll];
				else
					-- See if any City State types are eligible.
					for loop, res_ID in ipairs(self.resourceIDs_assigned_to_cs) do
						if allowed_luxuries[res_ID] == true and used_randoms_as_secondaries[res_ID] == false then
							iNumTypesAllowed = iNumTypesAllowed + 1;
							table.insert(candidate_types, res_ID);
						end
					end
					if iNumTypesAllowed > 0 then
						local diceroll = 1 + Map.Rand(iNumTypesAllowed, "Choosing second luxury type at a start location - LUA");
						use_this_ID = candidate_types[diceroll];
					else
						-- See if anybody else's regional type is eligible.
						local region_lux_ID = self.region_luxury_assignment[region_number];
						for loop, res_ID in ipairs(self.resourceIDs_assigned_to_regions) do
							if res_ID ~= region_lux_ID then
								if allowed_luxuries[res_ID] == true and used_randoms_as_secondaries[res_ID] == false then
									iNumTypesAllowed = iNumTypesAllowed + 1;
									table.insert(candidate_types, res_ID);
								end
							end
						end
						if iNumTypesAllowed > 0 then
							local diceroll = 1 + Map.Rand(iNumTypesAllowed, "Choosing second luxury type at a start location - LUA");
							use_this_ID = candidate_types[diceroll];
						else
							print("-"); print("Failed to place second Luxury type in 2nd ring at start in Region#", region_number, "-- no eligible types!"); print("-");
							placed2ndLux = false;
						end
					end
				end
				print("--- End of Eligible Types list for Second Luxury in Region#", region_number, "---");
				print("Random Res 2 Rings: " .. tostring(use_this_ID));

				if use_this_ID ~= nil then -- Place this luxury type at this start.
					luxury_plot_lists = self:GenerateLuxuryPlotListsAtCitySite(x, y, 2, use_this_ID, false)
					shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
					local iNumLeftToPlace = self:PlaceSpecificNumberOfResources(use_this_ID, 1, 1, 1, -1, 0, 0, shuf_list);
					if iNumLeftToPlace == 0 then
						print("-"); print("Placed Second Luxury type of ID#", use_this_ID, "for start located at Plot", x, y, " in Region#", region_number);
						used_randoms_as_secondaries[use_this_ID] = true;
						print("Random Res State: " .. tostring(used_randoms_as_secondaries[use_this_ID]));
					end
				end
			end
			if placed2ndLux == true then
				break;
			elseif i == 3 then
				-- couldn't find anything in second or third ring :-(
				break;
			else
				i = 3;
			end
		end
	end
--]]
	self.realtotalLuxPlacedSoFar = self.totalLuxPlacedSoFar		-- MOD.Barathor: New -- save the real total of luxuries before it gets corrupted with non-luxury additions which use the luxury placement method
end

------------------------------------------------------------------------------
function AssignStartingPlots:PlaceSmallQuantitiesOfStrategics(frequency, plot_list)
	-- This function distributes small quantities of strategic resources.
	if plot_list == nil then
		--print("No strategics were placed! -SmallQuantities");
		return
	end
	local iW, iH = Map.GetGridSize();
	local iNumTotalPlots = table.maxn(plot_list);
	local iNumToPlace = math.ceil(iNumTotalPlots / frequency);

	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = self:GetSmallStrategicResourceQuantityValues()
	
	-- Main loop
	local current_index = 1;
	for place_resource = 1, iNumToPlace do
		local placed_this_res = false;
		if current_index <= iNumTotalPlots then
			for index_to_check = current_index, iNumTotalPlots do
				if placed_this_res == true then
					break
				else
					current_index = current_index + 1;
				end
				local plotIndex = plot_list[index_to_check];
				if self.strategicData[plotIndex] == 0 then
					local x = (plotIndex - 1) % iW;
					local y = (plotIndex - x - 1) / iW;
					local res_plot = Map.GetPlot(x, y)
					if res_plot:GetResourceType(-1) == -1 then
						-- Placing a small strategic resource here. Need to determine what type to place.
						local selected_ID = -1;
						local selected_quantity = 2;
						local plotType = res_plot:GetPlotType()
						local terrainType = res_plot:GetTerrainType()
						local featureType = res_plot:GetFeatureType()
						if featureType == FeatureTypes.FEATURE_MARSH then
							local diceroll = Map.Rand(4, "Resource selection - Place Small Quantities LUA");
							if diceroll == 0 then
								selected_ID = self.iron_ID;
								selected_quantity = iron_amt;
							elseif diceroll == 1 then
								selected_ID = self.coal_ID;
								selected_quantity = coal_amt;
							else
								selected_ID = self.oil_ID;
								selected_quantity = oil_amt;
							end
						elseif featureType == FeatureTypes.FEATURE_JUNGLE then
							local diceroll = Map.Rand(4, "Resource selection - Place Small Quantities LUA");
							if diceroll == 0 then
								if plotType == PlotTypes.PLOT_HILLS then
									selected_ID = self.iron_ID;
									selected_quantity = iron_amt;
								else
									selected_ID = self.oil_ID;
									selected_quantity = oil_amt;
								end
							elseif diceroll == 1 then
								selected_ID = self.coal_ID;
								selected_quantity = coal_amt;
							else
								selected_ID = self.aluminum_ID;
								selected_quantity = alum_amt;
							end
						elseif featureType == FeatureTypes.FEATURE_FOREST then
							local diceroll = Map.Rand(4, "Resource selection - Place Small Quantities LUA");
							if diceroll == 0 then
								selected_ID = self.uranium_ID;
								selected_quantity = uran_amt;
							elseif diceroll == 1 then
								selected_ID = self.coal_ID;
								selected_quantity = coal_amt;
							else
								selected_ID = self.iron_ID;
								selected_quantity = iron_amt;
							end
						elseif featureType == FeatureTypes.NO_FEATURE then
							if plotType == PlotTypes.PLOT_HILLS then
								if terrainType == TerrainTypes.TERRAIN_GRASS or terrainType == TerrainTypes.TERRAIN_PLAINS then
									local diceroll = Map.Rand(5, "Resource selection - Place Small Quantities LUA");
									if diceroll < 2 then
										selected_ID = self.iron_ID;
										selected_quantity = iron_amt;
									elseif diceroll == 2 then
										selected_ID = self.coal_ID;
										selected_quantity = coal_amt;										
									else
										selected_ID = self.horse_ID;
										selected_quantity = horse_amt;
									end
								else
									local diceroll = Map.Rand(5, "Resource selection - Place Small Quantities LUA");
									if diceroll < 2 then
										selected_ID = self.iron_ID;
										selected_quantity = iron_amt;
									else
										selected_ID = self.coal_ID;
										selected_quantity = coal_amt;
									end
								end
							elseif terrainType == TerrainTypes.TERRAIN_GRASS then
								if res_plot:IsFreshWater() then
									selected_ID = self.horse_ID;
									selected_quantity = horse_amt;
								else
									local diceroll = Map.Rand(5, "Resource selection - Place Small Quantities LUA");
									if diceroll < 2 then
										selected_ID = self.iron_ID;
										selected_quantity = iron_amt;
									else
										selected_ID = self.horse_ID;
										selected_quantity = horse_amt;
									end
								end
							elseif terrainType == TerrainTypes.TERRAIN_PLAINS then
								local diceroll = Map.Rand(5, "Resource selection - Place Small Quantities LUA");
								if diceroll < 2 then
									selected_ID = self.iron_ID;
									selected_quantity = iron_amt;
								else
									selected_ID = self.horse_ID;
									selected_quantity = horse_amt;
								end
							elseif terrainType == TerrainTypes.TERRAIN_DESERT then
								local diceroll = Map.Rand(3, "Resource selection - Place Small Quantities LUA");
								if diceroll == 0 then
									selected_ID = self.iron_ID;
									selected_quantity = iron_amt;
								elseif diceroll == 1 then
									selected_ID = self.aluminum_ID;
									selected_quantity = alum_amt;
								else
									selected_ID = self.oil_ID;
									selected_quantity = oil_amt;
								end
							else
								local diceroll = Map.Rand(4, "Resource selection - Place Small Quantities LUA");
								if diceroll == 0 then
									selected_ID = self.iron_ID;
									selected_quantity = iron_amt;
								elseif diceroll == 1 then
									selected_ID = self.uranium_ID;
									selected_quantity = uran_amt;
								else
									selected_ID = self.oil_ID;
									selected_quantity = oil_amt;
								end
							end
						end
						-- Now place the resource, then impact the strategic data layer.
						if selected_ID ~= -1 then	
							local strat_radius = Map.Rand(4, "Resource Radius - Place Small Quantities LUA");
							if strat_radius > 2 then
								strat_radius = 1;
							end
							res_plot:SetResourceType(selected_ID, selected_quantity);
							self:PlaceResourceImpact(x, y, 1, strat_radius);
							placed_this_res = true;
							self.amounts_of_resources_placed[selected_ID + 1] = self.amounts_of_resources_placed[selected_ID + 1] + selected_quantity;
						end
					end
				end
			end
		end
	end
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function AssignStartingPlots:PlaceFishMainland(frequency, plot_list)
	-- This function places fish at members of plot_list. (Sounds fishy to me!)
	if plot_list == nil then
		--print("No fish were placed! -PlaceFish");
		return
	end
	local iW, iH = Map.GetGridSize();
	local iNumTotalPlots = table.maxn(plot_list);
	local iNumFishToPlace = math.ceil(iNumTotalPlots / frequency);
	
	-- Main loop
	local current_index = 1;
	for place_resource = 1, iNumFishToPlace do
		local placed_this_res = false;
		if current_index <= iNumTotalPlots then
			for index_to_check = current_index, iNumTotalPlots do
				if placed_this_res == true then
					break
				else
					current_index = current_index + 1;
				end
				local plotIndex = plot_list[index_to_check];

				if self.fishData[plotIndex] == 0 then
					local x = (plotIndex - 1) % iW;
					local y = (plotIndex - x - 1) / iW;
					local res_plot = Map.GetPlot(x, y)
					--TODO: Check feature (Atoll)
					local featureType = res_plot:GetFeatureType()

					if featureType ~= self.feature_atoll and featureType == FeatureTypes.NO_FEATURE and plot:IsLake() == false then

						if res_plot:GetResourceType(-1) == -1 then
							-- Placing fish here. First decide impact radius of this fish.
							local fish_radius = Map.Rand(0, "Fish Radius - Place Fish LUA") + 1;
							--if fish_radius > 4 then
							--	fish_radius = 3;
							--end

							res_plot:SetResourceType(self.fish_ID, 1);
							self:PlaceResourceImpact(x, y, 4, fish_radius);
							placed_this_res = true;
							self.amounts_of_resources_placed[self.fish_ID + 1] = self.amounts_of_resources_placed[self.fish_ID + 1] + 1;
						end
					end
				end
			end
		end
	end
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function AssignStartingPlots:PlaceFish(frequency, plot_list)
	-- This function places fish at members of plot_list. (Sounds fishy to me!)
	if plot_list == nil then
		--print("No fish were placed! -PlaceFish");
		return
	end
	local iW, iH = Map.GetGridSize();
	local iNumTotalPlots = table.maxn(plot_list);
	local iNumFishToPlace = math.ceil(iNumTotalPlots / frequency);
	local bMainlandCoast = false;

	-- Main loop
	local current_index = 1;
	for place_resource = 1, iNumFishToPlace do
		local placed_this_res = false;
		if current_index <= iNumTotalPlots then
			for index_to_check = current_index, iNumTotalPlots do
				if placed_this_res == true then
					break
				else
					current_index = current_index + 1;
				end
				local plotIndex = plot_list[index_to_check];
				bMainlandCoast = false;

				if self.method == 1 and self.mainland_coast_list[plotIndex] ~= false then
					bMainlandCoast = true;
				end

				

				if self.fishData[plotIndex] == 0 and bMainlandCoast == false then
					local x = (plotIndex - 1) % iW;
					local y = (plotIndex - x - 1) / iW;
					local res_plot = Map.GetPlot(x, y)
					local featureType = res_plot:GetFeatureType()
					if featureType ~= self.feature_atoll and featureType == FeatureTypes.NO_FEATURE and plot:IsLake() == false then
						if res_plot:GetResourceType(-1) == -1 then
							-- Placing fish here. First decide impact radius of this fish.
							local fish_radius = Map.Rand(4, "Fish Radius - Place Fish LUA") + 1;
							--if fish_radius > 4 then
							--	fish_radius = 3;
							--end

							res_plot:SetResourceType(self.fish_ID, 1);
							self:PlaceResourceImpact(x, y, 4, fish_radius);
							placed_this_res = true;
							self.amounts_of_resources_placed[self.fish_ID + 1] = self.amounts_of_resources_placed[self.fish_ID + 1] + 1;
						end
					end
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceSexyBonusAtCivStarts()
	-- This function will place a Bonus resource in the third ring around a Civ's start.
	-- The added Bonus is meant to make the start look more sexy, so to speak.
	-- Third-ring resources will take a long time to bring online, but will assist the site in the late game.
	-- Alternatively, it may assist a different city if another city is settled close enough to the capital and takes control of this tile.
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	local odd = self.firstRingYIsOdd;
	local even = self.firstRingYIsEven;
	local nextX, nextY, plot_adjustments;
	local bonus_type_associated_with_region_type = {};
	if self.bModLuxes then
		bonus_type_associated_with_region_type = {self.deer_ID, self.banana_ID, 
		self.deer_ID, self.wheat_ID, self.maize_ID, self.sheep_ID, self.wheat_ID, self.cow_ID, self.cow_ID, self.wheat_ID, self.hardwood_ID, self.maize_ID};
	else
		bonus_type_associated_with_region_type = {self.deer_ID, self.banana_ID, 
		self.deer_ID, self.wheat_ID, self.wheat_ID, self.sheep_ID, self.wheat_ID, self.cow_ID, self.cow_ID, self.wheat_ID, self.sheep_ID, self.banana_ID};
	end
	for region_number = 1, self.iNumCivs do
		local x = self.startingPlots[region_number][1];
		local y = self.startingPlots[region_number][2];
		local region_type = self.regionTypes[region_number];
		local use_this_ID = bonus_type_associated_with_region_type[region_type];
		local plot_list, fish_list = {}, {};
		-- For notes on how the hex-iteration works, refer to PlaceResourceImpact()
		local ripple_radius = 2;
		local currentX = x - ripple_radius;
		local currentY = y;
		for direction_index = 1, 6 do
			for plot_to_handle = 1, ripple_radius do
			 	if currentY / 2 > math.floor(currentY / 2) then
					plot_adjustments = odd[direction_index];
				else
					plot_adjustments = even[direction_index];
				end
				nextX = currentX + plot_adjustments[1];
				nextY = currentY + plot_adjustments[2];
				if wrapX == false and (nextX < 0 or nextX >= iW) then
					-- X is out of bounds.
				elseif wrapY == false and (nextY < 0 or nextY >= iH) then
					-- Y is out of bounds.
				else
					local realX = nextX;
					local realY = nextY;
					if wrapX then
						realX = realX % iW;
					end
					if wrapY then
						realY = realY % iH;
					end
					-- We've arrived at the correct x and y for the current plot.
					local plot = Map.GetPlot(realX, realY);
					local featureType = plot:GetFeatureType()
					if plot:GetResourceType(-1) == -1 and featureType ~= FeatureTypes.FEATURE_OASIS then -- No resource or Oasis here, safe to proceed.
						local plotType = plot:GetPlotType()
						local terrainType = plot:GetTerrainType()
						local plotIndex = realY * iW + realX + 1;
						-- Now check this plot for eligibility for the applicable Bonus type for this region.
						if use_this_ID == self.deer_ID then
							if featureType == FeatureTypes.FEATURE_FOREST then
								table.insert(plot_list, plotIndex);
							elseif terrainType == TerrainTypes.TERRAIN_TUNDRA and plotType == PlotTypes.PLOT_LAND then
								table.insert(plot_list, plotIndex);
							end
						elseif use_this_ID == self.hardwood_ID and self.bModLuxes then
							if featureType == FeatureTypes.FEATURE_FOREST then
								table.insert(plot_list, plotIndex);
							elseif terrainType == TerrainTypes.TERRAIN_TUNDRA and plotType == PlotTypes.PLOT_LAND then
								table.insert(plot_list, plotIndex);
							end
						elseif use_this_ID == self.banana_ID then
							if featureType == FeatureTypes.FEATURE_JUNGLE then
								table.insert(plot_list, plotIndex);
							end
						elseif use_this_ID == self.wheat_ID then
							if plotType == PlotTypes.PLOT_LAND then
								if terrainType == TerrainTypes.TERRAIN_PLAINS and featureType == FeatureTypes.NO_FEATURE then
									table.insert(plot_list, plotIndex);
								elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
									table.insert(plot_list, plotIndex);
								elseif terrainType == TerrainTypes.TERRAIN_DESERT and plot:IsFreshWater() then
									table.insert(plot_list, plotIndex);
								end
							end
						elseif use_this_ID == self.maize_ID and self.bModLuxes then
							if plotType == PlotTypes.PLOT_LAND then
								if terrainType == TerrainTypes.TERRAIN_PLAINS and featureType == FeatureTypes.NO_FEATURE then
									table.insert(plot_list, plotIndex);
								end
							end
						elseif use_this_ID == self.sheep_ID then
							if plotType == PlotTypes.PLOT_HILLS and featureType == FeatureTypes.NO_FEATURE then
								if terrainType == TerrainTypes.TERRAIN_PLAINS or terrainType == TerrainTypes.TERRAIN_GRASS or terrainType == TerrainTypes.TERRAIN_TUNDRA then
									table.insert(plot_list, plotIndex);
								end
							end
						elseif use_this_ID == self.cow_ID then
							if plotType == PlotTypes.PLOT_LAND then
								if terrainType == TerrainTypes.TERRAIN_GRASS or terrainType == TerrainTypes.TERRAIN_PLAINS then
									if featureType == FeatureTypes.NO_FEATURE then
										table.insert(plot_list, plotIndex);
									end
								end
							end
						end
						if plotType == PlotTypes.PLOT_OCEAN then
							if not plot:IsLake() then
								if featureType ~= self.feature_atoll and featureType ~= FeatureTypes.FEATURE_ICE then
									if terrainType == TerrainTypes.TERRAIN_COAST then
										table.insert(fish_list, plotIndex);
									end
								end
							end
						end
					end
				end
				currentX, currentY = nextX, nextY;
			end
		end
		local iNumCandidates = table.maxn(plot_list);
		if iNumCandidates > 0 then
			--print("Placing 'sexy Bonus' in third ring of start location in Region#", region_number);
			local shuf_list = GetShuffledCopyOfTable(plot_list)
			local iNumLeftToPlace = self:PlaceSpecificNumberOfResources(use_this_ID, 1, 1, 1, -1, 0, 0, shuf_list);
			if iNumCandidates > 1 and use_this_ID == self.sheep_ID then
				-- Hills region, attempt to give them a second Sexy Sheep.
				--print("Placing a second 'sexy Sheep' in third ring of start location in Hills Region#", region_number);
				iNumLeftToPlace = self:PlaceSpecificNumberOfResources(use_this_ID, 1, 1, 1, -1, 0, 0, shuf_list);
			end
		else
			local iFishCandidates = table.maxn(fish_list);
			if iFishCandidates > 0 then
				--print("Placing 'sexy Fish' in third ring of start location in Region#", region_number);
				local shuf_list = GetShuffledCopyOfTable(fish_list)
				local iNumLeftToPlace = self:PlaceSpecificNumberOfResources(self.fish_ID, 1, 1, 1, -1, 0, 0, shuf_list);
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:AddExtraBonusesToHillsRegions()
	-- Hills regions are very low on food, yet not deemed by the fertility measurements to be so.
	-- Spreading some food bonus around in these regions will help bring them up closer to par.
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map:IsWrapY();
	-- Identify Hills Regions, if any.
	local hills_regions, iNumHillsRegions = {}, 0;
	for region_number = 1, self.iNumCivs do
		if self.regionTypes[region_number] == 5 then
			iNumHillsRegions = iNumHillsRegions + 1;
			table.insert(hills_regions, region_number);
		end
	end
	if iNumHillsRegions == 0 then -- We're done.
		return
	end
	-- Process Hills Regions
	local shuffled_hills_regions = GetShuffledCopyOfTable(hills_regions)
	for loop, region_number in ipairs(shuffled_hills_regions) do
		local iWestX = self.regionData[region_number][1];
		local iSouthY = self.regionData[region_number][2];
		local iWidth = self.regionData[region_number][3];
		local iHeight = self.regionData[region_number][4];
		local iAreaID = self.regionData[region_number][5];
		--
		local terrainCounts = self.regionTerrainCounts[region_number];
		--local totalPlots = terrainCounts[1];
		local areaPlots = terrainCounts[2];
		--local waterCount = terrainCounts[3];
		local flatlandsCount = terrainCounts[4];
		local hillsCount = terrainCounts[5];
		local peaksCount = terrainCounts[6];
		--local lakeCount = terrainCounts[7];
		--local coastCount = terrainCounts[8];
		--local oceanCount = terrainCounts[9];
		--local iceCount = terrainCounts[10];
		local grassCount = terrainCounts[11];
		local plainsCount = terrainCounts[12];
		--local desertCount = terrainCounts[13];
		--local tundraCount = terrainCounts[14];
		--local snowCount = terrainCounts[15];
		--local forestCount = terrainCounts[16];
		--local jungleCount = terrainCounts[17];
		--local marshCount = terrainCounts[18];
		--local riverCount = terrainCounts[19];
		--local floodplainCount = terrainCounts[20];
		--local oasisCount = terrainCounts[21];
		--local coastalLandCount = terrainCounts[22];
		--local nextToCoastCount = terrainCounts[23];
		--
		-- Check how badly infertile the region is by comparing hills and mountains to flat farmlands.
		local hills_ratio = (hillsCount + peaksCount) / areaPlots;
		local farm_ratio = (grassCount + plainsCount) / areaPlots;
		if self.method == 3 then -- Need to ignore water tiles, which are included in areaPlots with this regional division method.
			hills_ratio = (hillsCount + peaksCount) / (hillsCount + peaksCount + flatlandsCount);
			farm_ratio = (grassCount + plainsCount) / (hillsCount + peaksCount + flatlandsCount);
		end
		-- If the infertility quotient is greater than 1, this will increase how
		-- many Bonus get placed, up to a max of double the normal ratio.
		local infertility_quotient = 1 + math.max(0, hills_ratio - farm_ratio);
		
		--print("Infertility Quotient for Hills Region#", region_number, " is:", infertility_quotient);
		
		--
		-- Generate plot lists for the extra Bonus placements.
		local dry_hills, flat_plains, flat_grass, flat_tundra, jungles, forests = {}, {}, {}, {}, {}, {};
		for region_loop_y = 0, iHeight - 1 do
			for region_loop_x = 0, iWidth - 1 do
				local x = (region_loop_x + iWestX) % iW;
				local y = (region_loop_y + iSouthY) % iH;
				local plot = Map.GetPlot(x, y);
				local plotIndex = y * iW + x + 1;
				local area_of_plot = plot:GetArea();
				local plotType = plot:GetPlotType()
				local terrainType = plot:GetTerrainType()
				local featureType = plot:GetFeatureType()
				if plotType == PlotTypes.PLOT_LAND or plotType == PlotTypes.PLOT_HILLS then
					-- Check plot for region membership. Only process this plot if it is a member.
					if (area_of_plot == iAreaID) or (iAreaID == -1) then
						if plot:GetResourceType(-1) == -1 then
							if featureType == FeatureTypes.FEATURE_JUNGLE then
								table.insert(jungles, plotIndex);
							elseif featureType == FeatureTypes.FEATURE_FOREST then
								table.insert(forests, plotIndex);
							elseif featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
								table.insert(flat_plains, plotIndex);
							elseif featureType == FeatureTypes.NO_FEATURE then
								if plotType == PlotTypes.PLOT_HILLS then
									if (terrainType == TerrainTypes.TERRAIN_GRASS or terrainType == TerrainTypes.TERRAIN_PLAINS or terrainType == TerrainTypes.TERRAIN_TUNDRA) then
										if plot:IsFreshWater() == false then
											table.insert(dry_hills, plotIndex);
										end
									end
								elseif plotType == PlotTypes.PLOT_LAND then
									if terrainType == TerrainTypes.TERRAIN_PLAINS then
										table.insert(flat_plains, plotIndex);
									elseif terrainType == TerrainTypes.TERRAIN_DESERT and plot:IsFreshWater() then
										table.insert(flat_plains, plotIndex);
									elseif terrainType == TerrainTypes.TERRAIN_GRASS then
										table.insert(flat_grass, plotIndex);
									elseif terrainType == TerrainTypes.TERRAIN_TUNDRA then
										table.insert(flat_tundra, plotIndex);
									end
								end
							end
						end
					end
				end
			end
		end
		
		--[[
		print("-"); print("--- Extra-Bonus Plot Counts for Hills Region#", region_number, "---");
		print("- Jungles:", table.maxn(jungles));
		print("- Forests:", table.maxn(forests));
		print("- Tundra:", table.maxn(flat_tundra));
		print("- Plains:", table.maxn(flat_plains));
		print("- Grass:", table.maxn(flat_grass));
		print("- Dry Hills:", table.maxn(dry_hills));
		]]--
		
		-- Now that the plot lists are ready, place the Bonuses.
		if table.maxn(dry_hills) > 0 then
			local resources_to_place = {
			{self.sheep_ID, 1, 100, 1, 1} };
			self:ProcessResourceList(9 / infertility_quotient, 3, dry_hills, resources_to_place)
		end
		if table.maxn(jungles) > 0 then
			local resources_to_place = {
			{self.banana_ID, 1, 100, 1, 2} };
			self:ProcessResourceList(14 / infertility_quotient, 3, jungles, resources_to_place)
		end
		if table.maxn(flat_tundra) > 0 then
			local resources_to_place = {
			{self.deer_ID, 1, 100, 0, 1} };
			self:ProcessResourceList(14 / infertility_quotient, 3, flat_tundra, resources_to_place)
		end
		if table.maxn(flat_tundra) > 0 then
			local resources_to_place = {
			{self.hardwood_ID, 1, 100, 0, 1} };
			self:ProcessResourceList(14 / infertility_quotient, 3, flat_tundra, resources_to_place)
		end
		if table.maxn(flat_plains) > 0 then
			local resources_to_place = {
			{self.wheat_ID, 1, 100, 0, 2} };
			self:ProcessResourceList(18 / infertility_quotient, 3, flat_plains, resources_to_place)
		end
		
		if table.maxn(flat_grass) > 0 then
			local resources_to_place = {
			{self.cow_ID, 1, 100, 1, 2} };
			self:ProcessResourceList(20 / infertility_quotient, 3, flat_grass, resources_to_place)
		end
		if table.maxn(forests) > 0 then
			local resources_to_place = {
			{self.deer_ID, 1, 100, 1, 2} };
			self:ProcessResourceList(24 / infertility_quotient, 3, forests, resources_to_place)
		end
		if self.bModLuxes then
			if table.maxn(forests) > 0 then
				local resources_to_place = {
				{self.hardwood_ID, 1, 100, 1, 2} };
				self:ProcessResourceList(24 / infertility_quotient, 3, forests, resources_to_place)
			end
			if table.maxn(flat_plains) > 0 then
				local resources_to_place = {
				{self.maize_ID, 1, 100, 0, 2} };
				self:ProcessResourceList(18 / infertility_quotient, 3, flat_plains, resources_to_place)
			end
		end
		
		--
		--print("-"); print("Added extra Bonus resources to Hills Region#", region_number);
		--
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:AddModernMinorStrategicsToCityStates()
	-- This function added Spring 2011. Purpose is to add a small strategic to most city states.
	--[[ MOD.EAP: 
		This function has been rewritten to unhardcode the resources. Now pulls data from xml. 
		Will include any post-industrial strategic resource, even uranium
	]]
	local strat_major_amount, strat_minor_amount = self:GetStrategicResourceQuantityValues()
	local amount_modern_strategics = {};
	for resource_ID, resource in pairs(self.ResourceTypes) do
		if resource.Class == "RESOURCECLASS_MODERN" then -- post-industrial strategic resources
			table.insert(amount_modern_strategics, resource_ID);
		end
	end

	local shuff_modern_strategics = GetShuffledCopyOfTable(amount_modern_strategics)

	for city_state = 1, self.iNumCityStates do
		-- First check to see if this city state number received a valid start plot.
		if self.city_state_validity_table[city_state] == false then
			-- This one did not! It does not exist on the map nor have valid data, so we will ignore it.
		else
			-- OK, it's a valid city state. Process it.
			local x = self.cityStatePlots[city_state][1];
			local y = self.cityStatePlots[city_state][2];
		
			-- Choose strategic type. Always add a chance of placing nothing. Note that this chance will be less the more modern strat resources exist.
			local diceroll = Map.Rand(#amount_modern_strategics + 1, "Choose resource type - CS Strategic LUA");
			
			if diceroll > 0 then
				-- This city state selected for minor strategic resource placement.
				
				local use_this_ID, res_amt, luxury_plot_lists, shuf_list;
				use_this_ID = shuff_modern_strategics[diceroll];
				
				if strat_minor_amount[use_this_ID] == 0 or strat_minor_amount[use_this_ID] == nil then
					-- no value found, use the default amount or skip it
					res_amt = Default_Stategic_Resource_Amounts_Minor[use_this_ID] or 1;
				else
					res_amt = strat_minor_amount[use_this_ID];
				end
					
				-- Place strategic.
				luxury_plot_lists = self:GenerateLuxuryPlotListsAtCitySite(x, y, 3, use_this_ID, false)
				shuf_list = GetShuffledCopyOfTable(luxury_plot_lists)
				local iNumLeftToPlace = self:PlaceSpecificNumberOfResources(use_this_ID, res_amt, 1, 1, -1, 0, 0, shuf_list);
				if iNumLeftToPlace == 0 then
					--print("-"); print("Placed Minor Strategic ID#", use_this_ID, "at City State#", city_state, "located at Plot", x, y);
				end
			else
				--print("-"); print("-"); print("-City State#", city_state, "gets no strategic resource assigned to it.");
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceOilInTheSea()
	-- Places sources of Oil in Coastal waters, equal to half what's on the 
	-- land. If the map has too little ocean, then whatever will fit.
	--
	-- WARNING: This operation will render the Strategic Resource Impact Table useless for
	-- further operations, so should always be called last, even after minor placements.

	--MOD.EAP: Leaving this hardcoded for the time being.  Will need to be rewritten to pull data from xml.
	local oil_ID;
	for resource_ID, resource in pairs(self.ResourceTypes) do
		if resource.Class == "RESOURCECLASS_MODERN" then -- post-industrial strategic resources
			if resource.Type == "RESOURCE_OIL" then
				oil_ID = resource_ID;
			end
		end
	end
	local sea_oil_amt = 4;
	if self.resource_setting == 1 or self.resource_setting == 2 then -- sparse
		sea_oil_amt = sea_oil_amt - 2;
	elseif self.resource_setting == 3 then -- mediocre
		sea_oil_amt = sea_oil_amt - 1;
	elseif self.resource_setting == 7 then -- plenty
		sea_oil_amt = sea_oil_amt + 1;
	elseif self.resource_setting == 8 or self.resource_setting == 9 or self.resource_setting == 10 then -- Abundant
		sea_oil_amt = sea_oil_amt + 2;
	end
	local iNumLandOilUnits = self.amounts_of_resources_placed[oil_ID + 1];
	local iNumToPlace = math.floor((iNumLandOilUnits / 2) / (sea_oil_amt / 2));

	print("+++++++++++++++++++++++++++++++++++++++++++++ Adding Oil resources to the Sea +++++++++++++++++++++++++++++++++++++++++++++");
	print("Land Oil Count: " .. tostring(iNumLandOilUnits));
	print("Number to Place: " .. tostring(iNumToPlace));
	iNumLeftToPlace = self:PlaceSpecificNumberOfResources(oil_ID, sea_oil_amt, iNumToPlace, 1, 8, 7, 10, self.coast_list);
	print("Number not Placed: " .. tostring(iNumLeftToPlace));
end
------------------------------------------------------------------------------
function AssignStartingPlots:FixResourceGraphics()

	--[[ MOD.EAP: 

		Rewritten. This function only handles the main plot loop. 
		Plot examination for terrain/feature/plotType validity is now handled in FixResource()

		 ]]


	print("+++++++++++++++++++++++++++++++++++++++++++++ Fixing Resource Graphics +++++++++++++++++++++++++++++++++++++++++++++");

	local iW, iH = Map.GetGridSize()
	
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			
			local plot = Map.GetPlot(x, y)
			local res_ID = plot:GetResourceType(-1)
			local featureType = plot:GetFeatureType()
			-- MOD.EAP: Incense fix
			local terrainType = plot:GetTerrainType()
			-- MOD.EAP: END

			local plotType = plot:GetPlotType()

			self:FixResource(x,y)
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:FixResource(x,y)

	--[[ MOD.EAP:

		This Function handles plot examination for terrain/feature/plotType validity.
		Mainly uses for luxuries, as we want luxuries to be more flexible when initially placed.
		General TerrainType placement should already be correct. Here we check just for Features and the Terrain on which
		these resources can have certain features (ValidTerrainFeatureTypes), as well as hill/flat eligibility.

	]]
	
	local lat, avgJungleRange = self:GetJungleRange(x,y)
	
	local plot = Map.GetPlot(x, y)
	local res_ID = plot:GetResourceType(-1)
	local featureType = plot:GetFeatureType()
	local terrainType = plot:GetTerrainType()
	local plotType = plot:GetPlotType()
			
	if self.ResourceTypes[res_ID] == nil then return end -- must have a resource that exist in the resources table

	-- here we set terrains/features for non-luxuries if needed. Usually for specific resources.
	if self.ResourceTypes[res_ID].Type == "RESOURCE_DEER" and featureType ~= FeatureTypes.FEATURE_FOREST then
		plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1)
	end

	-- ValidTerrainTypes should already be handled. ValidFeatures should be handled in some cases, but not all, so we check here.
	-- Also do check for hill/flat eligibility
	if self.ResourceTypes[res_ID].Class ~= "RESOURCECLASS_LUXURY"
	and self.ResourceTypes[res_ID].Type ~= "RESOURCE_HARDWOOD" then return end -- hardcoding hardwood for now



	if self.ResourceTypes[res_ID].HillRequired and plotType ~= PlotTypes.PLOT_HILLS then
		plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true)
	elseif self.ResourceTypes[res_ID].FlatRequired and plotType == PlotTypes.PLOT_HILLS then
		plot:SetPlotType(PlotTypes.PLOT_LAND, false, true)
	end
	-- TODO: Add support for TreeRequired

	--if the resource is on a plottype (flat or hill) that it can't be on, swap it.
	if self.ResourceTypes[res_ID].canBeHill == false 
	and self.ResourceTypes[res_ID].canBeFlat
	and plotType == PlotTypes.PLOT_HILLS then
		plot:SetPlotType(PlotTypes.PLOT_LAND, false, true)
	end
	if self.ResourceTypes[res_ID].canBeFlat == false 
	and self.ResourceTypes[res_ID].canBeHill
	and plotType == PlotTypes.PLOT_LAND then
		plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true)
	end

	-- here we do some manual edits based on our own balance interpretations
	-- first is to set any resource on flat desert/tundra to be on desert/tundra hills instead
	if plotType == PlotTypes.PLOT_LAND 
	and (terrainType == TerrainTypes.TERRAIN_DESERT or terrainType == TerrainTypes.TERRAIN_TUNDRA) 
	and featureType ~= FeatureTypes.FEATURE_FLOOD_PLAINS then
		plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true)
	end
	if terrainType == TerrainTypes.TERRAIN_SNOW then
		plot:SetTerrainType(TerrainTypes.TERRAIN_TUNDRA, false, true)
		plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1)
	end

	-- moving on to checking correct features for resources
	if featureType ~= FeatureTypes.NO_FEATURE then
		if self.ValidFeatureTypes[res_ID] == nil then
			-- resource has no valid feature entries yet is on one. Remove it.
			if featureType == FeatureTypes.FEATURE_FLOOD_PLAINS then
				if self.ResourceTypes[res_ID].canBeFlat == false then
					plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
					plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
					return;
				end
				-- if the resource can be flat we keep the flood plains. Gosh flood plains are hard to handle.
			else
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1)
			end
		else -- has an entry	
			-- remove a feature if the resource is not valid on it
			local validFeatureOnPlot = false
			for i, validFeatureType in pairs(self.ValidFeatureTypes[res_ID]) do
				if FeatureTypes[validFeatureType] == featureType then
					validFeatureOnPlot = true;
					break;
				end
			end
			if validFeatureOnPlot == false then
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			end
		end
	end
	if self.ValidFeatureTypes[res_ID] ~= nil and featureType == FeatureTypes.NO_FEATURE then	
		
		-- check if we want to add a feature
		-- Function will return once it has made a change.
		for i, validFeature in pairs(self.ValidFeatureTypes[res_ID]) do
			if self.ValidTerrainFeatureTypes[res_ID] ~= nil then
				for i, validTerrainFeature in pairs(self.ValidTerrainFeatureTypes[res_ID]) do
					if TerrainTypes[validTerrainFeature] == terrainType then
						--resource is on valid terrain for a feature.
						-- handle placing forest/jungle by checking latitude (jungle line)	
						if FeatureTypes[validFeature] == FeatureTypes.FEATURE_FOREST or FeatureTypes[validFeature] == FeatureTypes.FEATURE_JUNGLE then
							if terrainType == TerrainTypes.TERRAIN_DESERT then break end -- floodplains check
							for _, validFeatureJungle in pairs(self.ValidFeatureTypes[res_ID]) do
								if FeatureTypes[validFeatureJungle] == FeatureTypes.FEATURE_JUNGLE then
									if lat <= avgJungleRange then
										plot:SetFeatureType(FeatureTypes.FEATURE_JUNGLE, -1)
										plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, true)
										return
									else
										plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1)
										return
									end
								end
							end
							if FeatureTypes[validFeature] == FeatureTypes.FEATURE_FOREST then
								plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1)
								return
							end
						elseif terrainType == TerrainTypes.TERRAIN_DESERT and FeatureTypes[validFeature] == FeatureTypes.FEATURE_FLOOD_PLAINS then -- TODO: Do this better
							plot:SetFeatureType(FeatureTypes.FEATURE_FLOOD_PLAINS, -1)
							return
						elseif terrainType == TerrainTypes.TERRAIN_GRASS and FeatureTypes[validFeature] == FeatureTypes.FEATURE_MARSH then
							plot:SetFeatureType(FeatureTypes.FEATURE_MARSH, -1)
							return
						elseif terrainType == TerrainTypes.TERRAIN_COAST or terrainType == TerrainTypes.TERRAIN_OCEAN then
							plot:SetFeatureType(FeatureTypes[validFeature], -1)
							return;
						end
					end
				end
			end
		end
	end
	

end
------------------------------------------------------------------------------
function AssignStartingPlots:GetJungleRange(x,y)

	local lat , avgJungleRange;
	local iW, iH = Map.GetGridSize()
	if (y >= (iH/2)) then
		lat = math.abs((iH/2) - y)/(iH/2)
	else
		lat = math.abs((iH/2) - (y + 1))/(iH/2)
	end
	local rain = Map.GetCustomOption(2)
	if rain == 1 then
		-- Arid
		avgJungleRange = 0.08
	elseif rain == 3 then
		-- Wet
		avgJungleRange = 0.25
	else
		-- Normal or Random
		avgJungleRange = 0.12
	end

	return lat, avgJungleRange
end
------------------------------------------------------------------------------
function AssignStartingPlots:PrintFinalResourceTotalsToLog()
	print("-");
	print("--- Table of Results, New Start Finder ---");
	for loop, startData in ipairs(self.startingPlots) do
		print("-");
		print("Region#", loop, " has start plot at: ", startData[1], startData[2], "with Fertility Rating of ", startData[3]);
	end
	print("-");
	print("--- End of Start Finder Results Table ---");
	print("-");
	print("-");
	print("--- Table of Final Results, City State Placements ---");
	print("-");
	for cs_number = 1, self.iNumCityStates do
		if self.city_state_validity_table[cs_number] == true then
			local data_table = self.cityStatePlots[cs_number];
			local x = data_table[1];
			local y = data_table[2];
			local regNum = data_table[3];
			print("- City State", cs_number, "in Region", regNum, "is located at Plot", x, y);
		else
			print("- City State", cs_number, "was discarded due to overcrowding.");
		end
	end
	print("-");
	print("- - - - -");
	print("-");
	print("--- Table of Final Results, Resource Distribution ---");
	print("-");
	print("- LUXURY Resources -");
	-- MOD.Barathor: Updated: Added ID numbers to each resource name and reordered them for much easier testing!
	print(self.whale_ID,    "Whale...: ", self.amounts_of_resources_placed[self.whale_ID + 1])
	print(self.pearls_ID,   "Pearls..: ", self.amounts_of_resources_placed[self.pearls_ID + 1])
	print(self.gold_ID,     "Gold....: ", self.amounts_of_resources_placed[self.gold_ID + 1])
	print(self.silver_ID,   "Silver..: ", self.amounts_of_resources_placed[self.silver_ID + 1])
	print(self.gems_ID,     "Gems....: ", self.amounts_of_resources_placed[self.gems_ID + 1])
	print(self.marble_ID,   "Marble..: ", self.amounts_of_resources_placed[self.marble_ID + 1])
	print(self.ivory_ID,    "Ivory...: ", self.amounts_of_resources_placed[self.ivory_ID + 1])
	print(self.fur_ID,      "Fur.....: ", self.amounts_of_resources_placed[self.fur_ID + 1])
	print(self.dye_ID,      "Dye.....: ", self.amounts_of_resources_placed[self.dye_ID + 1])
	print(self.spices_ID,   "Spices..: ", self.amounts_of_resources_placed[self.spices_ID + 1])
	print(self.silk_ID,     "Silk....: ", self.amounts_of_resources_placed[self.silk_ID + 1])
	print(self.sugar_ID,    "Sugar...: ", self.amounts_of_resources_placed[self.sugar_ID + 1])
	print(self.cotton_ID,   "Cotton..: ", self.amounts_of_resources_placed[self.cotton_ID + 1])
	print(self.wine_ID,     "Wine....: ", self.amounts_of_resources_placed[self.wine_ID + 1])
	print(self.incense_ID,  "Incense.: ", self.amounts_of_resources_placed[self.incense_ID + 1])
	print("- Expansion LUXURY Resources -");
	print(self.copper_ID,   "Copper..: ", self.amounts_of_resources_placed[self.copper_ID + 1])
	print(self.salt_ID,     "Salt....: ", self.amounts_of_resources_placed[self.salt_ID + 1])
	print(self.crab_ID,     "Crab....: ", self.amounts_of_resources_placed[self.crab_ID + 1])
	print(self.truffles_ID, "Truffles: ", self.amounts_of_resources_placed[self.truffles_ID + 1])
	print(self.citrus_ID,   "Citrus..: ", self.amounts_of_resources_placed[self.citrus_ID + 1])
	print(self.cocoa_ID,    "Cocoa...: ", self.amounts_of_resources_placed[self.cocoa_ID + 1])
	-- MOD.Barathor: Start

	if self.bModLuxes == true then
		print("- Mod LUXURY Resources -")
		print(self.coffee_ID,   "Coffee..: ", self.amounts_of_resources_placed[self.coffee_ID + 1])
		print(self.tea_ID,      "Tea.....: ", self.amounts_of_resources_placed[self.tea_ID + 1])
		print(self.tobacco_ID,  "Tobacco.: ", self.amounts_of_resources_placed[self.tobacco_ID + 1])
		print(self.amber_ID,    "Amber...: ", self.amounts_of_resources_placed[self.amber_ID + 1])
		print(self.jade_ID,     "Jade....: ", self.amounts_of_resources_placed[self.jade_ID + 1])
		print(self.olives_ID,   "Olives..: ", self.amounts_of_resources_placed[self.olives_ID + 1])
		print(self.perfume_ID,  "Perfume.: ", self.amounts_of_resources_placed[self.perfume_ID + 1])
		print(self.coral_ID,  	"Coral...: ", self.amounts_of_resources_placed[self.coral_ID + 1])
		print(self.lapis_ID,  	"Lapis...: ", self.amounts_of_resources_placed[self.lapis_ID + 1])
		print(self.obsidian_ID,  "Obsidian: ", self.amounts_of_resources_placed[self.obsidian_ID + 1])
		print(self.rubber_ID,    "Rubber...: ", self.amounts_of_resources_placed[self.rubber_ID + 1])
		print(self.coconut_ID,    "Rubber...: ", self.amounts_of_resources_placed[self.coconut_ID + 1])
	end

	print("-")

	print("+ TOTAL.Lux: ", self.realtotalLuxPlacedSoFar)	-- MOD.Barathor: Fixed: The old variable gets corrupted with non-luxury additions after all luxuries have been placed.  This will display the correct total.
	-- MOD.Barathor: End
	print("-");
	print("- STRATEGIC Resources -");
	print(self.iron_ID,     "Iron....: ", self.amounts_of_resources_placed[self.iron_ID + 1])
	print(self.horse_ID,    "Horse...: ", self.amounts_of_resources_placed[self.horse_ID + 1])
	print(self.coal_ID,     "Coal....: ", self.amounts_of_resources_placed[self.coal_ID + 1])
	print(self.oil_ID,      "Oil.....: ", self.amounts_of_resources_placed[self.oil_ID + 1])
	print(self.aluminum_ID, "Aluminum: ", self.amounts_of_resources_placed[self.aluminum_ID + 1])
	print(self.uranium_ID,  "Uranium.: ", self.amounts_of_resources_placed[self.uranium_ID + 1])
	print("-");
	print("- BONUS Resources -");
	print(self.wheat_ID,    "Wheat...: ", self.amounts_of_resources_placed[self.wheat_ID + 1])
	print(self.cow_ID,      "Cow.....: ", self.amounts_of_resources_placed[self.cow_ID + 1])
	print(self.sheep_ID,    "Sheep...: ", self.amounts_of_resources_placed[self.sheep_ID + 1])
	print(self.deer_ID,     "Deer....: ", self.amounts_of_resources_placed[self.deer_ID + 1])
	print(self.banana_ID,   "Banana..: ", self.amounts_of_resources_placed[self.banana_ID + 1])
	print(self.fish_ID,     "Fish....: ", self.amounts_of_resources_placed[self.fish_ID + 1])
	print(self.stone_ID,    "Stone...: ", self.amounts_of_resources_placed[self.stone_ID + 1])
	print(self.bison_ID,    "Bison...: ", self.amounts_of_resources_placed[self.bison_ID + 1])
	if self.bModLuxes then
		print(self.hardwood_ID, "Hardwood: ", self.amounts_of_resources_placed[self.hardwood_ID + 1])
		print(self.maize_ID,    "Maize...: ", self.amounts_of_resources_placed[self.maize_ID + 1])
		print(self.lead_ID_ID,    "Maize...: ", self.amounts_of_resources_placed[self.maize_ID + 1])
		print("-");
		print("-----------------------------------------------------");
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetStrategicResourceQuantityValues()
	-- This function determines quantity per tile for each strategic resource's major deposit size.
	-- default values if not specified in the database.
	-- MOD.EAP: Now does it automatically based on the amount entered in the database.
	local strat_minor_amount = {}
	local strat_major_amount = {}
	print("+++++++++++++++++++++++++++++++++++++++++++++ Getting Strat Amount Values +++++++++++++++++++++++++++++++++++++++++++++");
	for resource_ID, resource in pairs(self.ResourceTypes) do
		if resource.amountMajor > 0 or resource.amountMinor > 0 then
			if self.resource_setting == 1 or self.resource_setting == 2 or (self.resource_setting == 3 and resource.amountMinor > 0) then
				-- Sparse. -50% of the default amount, but never less than 1.
				strat_major_amount[resource_ID] = math.max(1, math.floor(resource.amountMajor * 0.5));
				strat_minor_amount[resource_ID] = math.max(1, math.floor(resource.amountMinor * 0.5));
			elseif self.resource_setting == 3 then
				-- Mediocre. -25% of the default amount, but ever less than 1.
				strat_major_amount[resource_ID] = math.max(1, math.floor(resource.amountMajor * 0.75));
			elseif self.resource_setting == 7 then
				-- Plenty. +25% of the default amount.
				strat_major_amount[resource_ID] = math.floor(resource.amountMajor * 1.25);
			elseif self.resource_setting == 8 or self.resource_setting == 9 or self.resource_setting == 10 or (self.resource_setting == 7 and resource.amountMinor > 0) then
				-- Abundant. +50% of the default amount.
				strat_major_amount[resource_ID] = math.floor(resource.amountMajor * 1.5);
				strat_minor_amount[resource_ID] = math.floor(resource.amountMinor * 1.5);
			else
				-- Default amount.
				strat_major_amount[resource_ID] = resource.amountMajor;
				strat_minor_amount[resource_ID] = resource.amountMinor;
			end
			print(strat_major_amount[resource_ID])
		end
	end
	return strat_major_amount, strat_minor_amount
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
function AssignStartingPlots:GetMajorStrategicResourceQuantityValues()
	-- This function determines quantity per tile for each strategic resource's major deposit size.
	-- Note: scripts that cannot place Oil in the sea need to increase amounts on land to compensate.
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 4, 7, 6, 7, 8;
	-- Check the resource setting.
	if self.resource_setting == 1 or self.resource_setting == 2 then -- Sparse
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 2, 5, 4, 5, 6;
	elseif self.resource_setting == 3 then -- mediocre
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 3, 6, 5, 6, 7;
	elseif self.resource_setting == 7 then -- plenty
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 5, 8, 7, 8, 9;
	elseif self.resource_setting == 8 or self.resource_setting == 9 or self.resource_setting == 10 then -- Abundant
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 6, 9, 8, 9, 10;
	end
	return uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetSmallStrategicResourceQuantityValues()
	-- This function determines quantity per tile for each strategic resource's small deposit size.
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 2, 4, 2, 3, 3;
	-- Check the resource setting.
	if self.resource_setting == 1 or self.resource_setting == 2 or self.resource_setting == 3 then -- Sparse / Mediocre
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 1, 1, 2, 1, 2, 2;
	elseif self.resource_setting == 7 or self.resource_setting == 8 or self.resource_setting == 9 or self.resource_setting == 10 then -- Plenty / Abundant
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 3, 3, 3, 3, 3;
	end
	return uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceStrategicAndBonusResources()
	-- KEY: {Resource ID, Quantity (0 = unquantified), weighting, minimum radius, maximum radius}
	-- KEY: (frequency (1 per n plots in the list), impact list number, plot list, resource data)
	--
	-- The radius creates a zone around the plot that other resources of that
	-- type will avoid if possible. See ProcessResourceList for impact numbers.
	--
	-- Order of placement matters, so changing the order may affect a later dependency.
	
	-- Adjust amounts, if applicable, based on Resource Setting.
	local strat_major_amount = {}
	local strat_minor_amount = {}
	strat_major_amount, strat_minor_amount = self:GetStrategicResourceQuantityValues()
	
	-- Adjust appearance rate per Resource Setting chosen by user.
	local bonus_multiplier = 0.70;

	if self.resource_setting == 1 then -- Near to nothing
		bonus_multiplier = 1;
	elseif self.resource_setting == 2 then -- 
		bonus_multiplier = 0.90;
	elseif self.resource_setting == 3 then -- 
		bonus_multiplier = 0.85;
	elseif self.resource_setting == 4 then -- 
		bonus_multiplier = 0.80;
	elseif self.resource_setting == 6 then -- 
		bonus_multiplier = 0.60;
	elseif self.resource_setting == 7 then -- 
		bonus_multiplier = 0.50;
	elseif self.resource_setting == 8 then -- 
		bonus_multiplier = 0.40;
	elseif self.resource_setting == 9 then -- 
		bonus_multiplier = 0.30;
	elseif self.resource_setting == 10 then -- filled the map full
		bonus_multiplier = 0.20;
	end

	--
	--MOD.EAP: Note: resources_to_place means the following: {Resource ID, Quantity, weighting, minimum impact radius, maximum impact radius}
	-- Place Strategic resources using major values.
	--[[
	local temp_bonus_resource_list = {};
	local temp_strat_resource_list = {};
	for resource_ID, resource in pairs(self.ResourceTypes) do
		if strat_major_amount[resource_ID] == 0 or strat_major_amount[resource_ID] == nil then
			-- no value found, use the default amount or set it to 1
			strat_major_amount[resource_ID] = Default_Stategic_Resource_Amounts_Major[resource_ID] or 1;
		end
		if (resource.Class == "RESOURCECLASS_MODERN" or resource.Class == "RESOURCECLASS_RUSH") and resource.Special == false then	
			table.insert(temp_strat_resource_list, resource_ID);
		elseif resource.Class == "RESOURCECLASS_BONUS" and resource.Special == false then
			table.insert(temp_bonus_resource_list, resource_ID);
		end
	end

	local shuff_bonus_resource_list = GetShuffledCopyOfTable(temp_bonus_resource_list);
	local shuff_strat_resource_list = GetShuffledCopyOfTable(temp_strat_resource_list);
	local resources_to_place = {};
	local shuff_global_resource_list = {};
	
	-- Place Strategic resources using major values.
	for loop, resource_ID in ipairs(shuff_strat_resource_list) do
		if shuff_global_resource_list[resource_ID] == nil and self.global_resource_plot_lists[resource_ID] ~= nil then
			shuff_global_resource_list[resource_ID] = GetShuffledCopyOfTable(self.global_resource_plot_lists[resource_ID]);
		end
		-- use default ripple values. TODO: add a way to specify these in the XML.
		resources_to_place = { {resource_ID, strat_major_amount[resource_ID], 1, 3} };

		self:HandleResourcePreferences(shuff_global_resource_list[resource_ID], resources_to_place, resource_ID, 1)
	end
	--]]
	-- default preferences for strategic resources
	-- uranium: 33
	-- oil: 39
	-- aluminum: 22
	-- iron: 16
	-- coal: 22
	-- horse: 10

	--temp defaults
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 4, 7, 6, 7, 8;

	print("Map Generation - Placing Strategics");
	local resources_to_place = {
	{self.oil_ID, strat_major_amount[self.oil_ID], 65, 1, 4},
	{self.uranium_ID, uran_amt, 35, 1, 4} };
	self:ProcessResourceList(7, 1, self.marsh_list, resources_to_place)

	local resources_to_place = {
	{self.oil_ID, strat_major_amount[self.oil_ID], 55, 1, 5},
	{self.aluminum_ID, alum_amt, 15, 1, 2},
	{self.iron_ID, iron_amt, 35, 1, 2} };
	self:ProcessResourceList(16, 1, self.tundra_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.oil_ID, strat_major_amount[self.oil_ID], 65, 1, 5},
	{self.aluminum_ID, alum_amt, 15, 1, 2},
	{self.iron_ID, iron_amt, 20, 1, 2} };
	self:ProcessResourceList(15, 1, self.snow_flat_list, resources_to_place)

	local resources_to_place = {
	{self.oil_ID, strat_major_amount[self.oil_ID], 70, 1, 2},
	{self.iron_ID, iron_amt, 30, 1, 2} };
	self:ProcessResourceList(11, 1, self.desert_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.iron_ID, iron_amt, 26, 1, 3},
	{self.coal_ID, coal_amt, 35, 1, 3},
	{self.aluminum_ID, alum_amt, 39, 1, 3} };
	self:ProcessResourceList(22, 1, self.hills_list, resources_to_place)

	local resources_to_place = {
	{self.coal_ID, coal_amt, 30, 1, 2},
	{self.uranium_ID, uran_amt, 70, 1, 2} };
	self:ProcessResourceList(33, 1, self.jungle_flat_list, resources_to_place)
	local resources_to_place = {
	{self.coal_ID, coal_amt, 25, 1, 2},
	{self.oil_ID, strat_major_amount[self.oil_ID], 25, 1, 5},
	{self.uranium_ID, uran_amt, 50, 10, 0} };
	self:ProcessResourceList(39, 1, self.forest_flat_list, resources_to_place)

	local resources_to_place = {
	{self.horse_ID, horse_amt, 100, 1, 5} };
	self:ProcessResourceList(10, 1, self.dry_grass_flat_no_feature, resources_to_place)
	local resources_to_place = {
	{self.horse_ID, horse_amt, 100, 1, 5} };
	self:ProcessResourceList(10, 1, self.plains_flat_no_feature, resources_to_place)
	self:AddModernMinorStrategicsToCityStates() -- Added spring 2011
	
	self:PlaceSmallQuantitiesOfStrategics(35 * bonus_multiplier, self.land_list);
	
	self:PlaceOilInTheSea();

	
	-- Check for low or missing Strategic resources
	if self.amounts_of_resources_placed[self.iron_ID + 1] < 8 then
		--print("Map has very low iron, adding another.");
		local resources_to_place = { {self.iron_ID, iron_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.hills_list, resources_to_place) -- 99999 means one per that many tiles: a single instance.
	end
	if self.amounts_of_resources_placed[self.iron_ID + 1] < 4 * self.iNumCivs then
		--print("Map has very low iron, adding another.");
		local resources_to_place = { {self.iron_ID, iron_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.land_list, resources_to_place)
	end
	if self.amounts_of_resources_placed[self.horse_ID + 1] < 4 * self.iNumCivs then
		print("Map has very low horse, adding another.");
		local resources_to_place = { {self.horse_ID, horse_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.plains_flat_no_feature, resources_to_place)
		
		--print("Map has very low horse, adding another.");
		local resources_to_place = { {self.horse_ID, horse_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.dry_grass_flat_no_feature, resources_to_place)
	end
	if self.amounts_of_resources_placed[self.coal_ID + 1] < 8 then
		--print("Map has very low coal, adding another.");
		local resources_to_place = { {self.coal_ID, coal_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.hills_list, resources_to_place)
	end
	if self.amounts_of_resources_placed[self.coal_ID + 1] < 4 * self.iNumCivs then
		--print("Map has very low coal, adding another.");
		local resources_to_place = { {self.coal_ID, coal_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.land_list, resources_to_place)
	end
	if self.amounts_of_resources_placed[self.oil_ID + 1] < 4 * self.iNumCivs then
		print("Map has very low oil, adding another.");
		local resources_to_place = { {self.oil_ID, oil_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.land_list, resources_to_place)
	end
	if self.amounts_of_resources_placed[self.aluminum_ID + 1] < 4 * self.iNumCivs then
		--print("Map has very low aluminum, adding another.");
		local resources_to_place = { {self.aluminum_ID, alum_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.hills_list, resources_to_place)
	end
	
	while self.amounts_of_resources_placed[self.uranium_ID + 1] < 5 * self.iNumCivs do
		print("Map has very low uranium, adding another.");
		local resources_to_place = { {self.uranium_ID, uran_amt, 100, 0, 0} };
		self:ProcessResourceList(99999, 1, self.land_list, resources_to_place)
	end
	
	
	-- Place Bonus Resources
	print("Map Generation - Placing Bonuses");
	
	self:GenerateMainlandCoastalPlotTables();

	if self.method == 1 then
		local fish_coast_inner = GetShuffledCopyOfTable(self.mainland_coast_list_inner)
		local fish_coast_second = GetShuffledCopyOfTable(self.mainland_coast_list_second)
		local fish_coast_outer = GetShuffledCopyOfTable(self.mainland_coast_list_outer)

		self:PlaceFish(1 * bonus_multiplier, fish_coast_inner);
		self:PlaceFishMainland(1 * bonus_multiplier, fish_coast_second);
		--self:PlaceFishMainland(1 * bonus_multiplier, fish_coast_outer);

		self:PlaceFish(16 * bonus_multiplier, self.non_mainland_coast_list);
	else
		self:PlaceFish(16 * bonus_multiplier, self.coast_list);
	end


	self:PlaceSexyBonusAtCivStarts()
	self:AddExtraBonusesToHillsRegions()


	-- MOD.EAP : Begin distribution of bonus resources.
	--[[
	for loop, resource_ID in ipairs(shuff_bonus_resource_list) do
		if shuff_global_resource_list[resource_ID] == nil and self.global_resource_plot_lists[resource_ID] ~= nil then
			shuff_global_resource_list[resource_ID] = GetShuffledCopyOfTable(self.global_resource_plot_lists[resource_ID]);
		end
		-- use default ripple values. TODO: add a way to specify these in the XML.
		resources_to_place = { {resource_ID, strat_major_amount[resource_ID], 1, 3} };

		self:HandleResourcePreferences(shuff_global_resource_list[resource_ID], resources_to_place, resource_ID, 1)
		--
	end
	]]
	local resources_to_place = {
	{self.deer_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(6 * bonus_multiplier, 3, self.extra_deer_list, resources_to_place)

	local resources_to_place = {
	{self.wheat_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(6 * bonus_multiplier, 3, self.desert_wheat_list, resources_to_place)

	local resources_to_place = {
	{self.deer_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(8 * bonus_multiplier, 3, self.tundra_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.banana_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(10 * bonus_multiplier, 3, self.banana_list, resources_to_place)

	local resources_to_place = {
	{self.wheat_ID, 1, 100, 1, 3} };
	self:ProcessResourceList(30 * bonus_multiplier, 3, self.plains_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.bison_ID, 1, 100, 2, 3} };
	self:ProcessResourceList(15 * bonus_multiplier, 3, self.plains_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.cow_ID, 1, 100, 2, 3} };
	self:ProcessResourceList(22 * bonus_multiplier, 3, self.plains_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.cow_ID, 1, 100, 2, 3} };
	self:ProcessResourceList(22 * bonus_multiplier, 3, self.grass_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.stone_ID, 1, 100, 1, 1} };
	self:ProcessResourceList(20 * bonus_multiplier, 3, self.dry_grass_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.bison_ID, 1, 100, 1, 1} };
	self:ProcessResourceList(20 * bonus_multiplier, 3, self.dry_grass_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.sheep_ID, 1, 100, 1, 1} };
	self:ProcessResourceList(20 * bonus_multiplier, 3, self.hills_open_list, resources_to_place)

	local resources_to_place = {
	{self.stone_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(10 * bonus_multiplier, 3, self.tundra_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.stone_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(16 * bonus_multiplier, 3, self.desert_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.deer_ID, 1, 100, 3, 4} };
	self:ProcessResourceList(22 * bonus_multiplier, 3, self.forest_flat_that_are_not_tundra, resources_to_place)
	
	if self.bModLuxes then
		local resources_to_place = {
		{self.hardwood_ID, 1, 100, 1, 2} };
		self:ProcessResourceList(22 * bonus_multiplier, 3, self.hills_covered_list, resources_to_place)

		local resources_to_place = {
		{self.hardwood_ID, 1, 100, 1, 2} };
		self:ProcessResourceList(22 * bonus_multiplier, 3, self.flat_covered, resources_to_place)

		local resources_to_place = {
		{self.hardwood_ID, 1, 100, 1, 2} };
		self:ProcessResourceList(22 * bonus_multiplier, 3, self.tundra_flat_forest, resources_to_place)
		
		local resources_to_place = {
		{self.maize_ID, 1, 100, 1, 2} };
		self:ProcessResourceList(35 * bonus_multiplier, 3, self.plains_flat_no_feature, resources_to_place)
	end
	
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceResourcesAndCityStates()
	-- This function controls nearly all resource placement. Only resources
	-- placed during Normalization operations are handled elsewhere.
	--
	-- Luxury resources are placed in relationship to Regions, adapting to the
	-- details of the given map instance, including number of civs and city 
	-- states present. At Jon's direction, Luxuries have been implemented to
	-- be diplomatic widgets for trading, in addition to sources of Happiness.
	--
	-- Strategic and Bonus resources are terrain-adjusted. They will customize
	-- to each map instance. Each terrain type has been measured and has certain 
	-- resource types assigned to it. You can customize resource placement to 
	-- any degree desired by controlling generation of plot groups to feed in
	-- to the process. The default plot groups are terrain-based, but any
	-- criteria you desire could be used to determine plot group membership.
	--
	-- If any default methods fail to meet a specific need, don't hesitate to 
	-- replace them with custom methods. I have labored to make this new 
	-- system as accessible and powerful as any ever before offered.

	print("Map Generation - Assigning Luxury Resource Distribution");
	self:AssignLuxuryRoles()
	self:PlaceCityStates()
	-- Generate global plot lists for resource distribution.
	self:GenerateGlobalResourcePlotLists()
	--MOD.EAP: New global resource list generation
	self:GenerateGlobalResourcePlotLists_NEW()
	--MOD.EAP: End
	print("Map Generation - Placing Luxuries");
	self:PlaceLuxuries()

	-- Place Strategic and Bonus resources.
	self:PlaceStrategicAndBonusResources()
	self:NormalizeCityStateLocations()	
	-- MOD.EAP : Fixes incorrect feature/plot types for resources or overrides feature/terrain/plotypes.
	self:FixResourceGraphics()
	
	-- Necessary to implement placement of Natural Wonders, and possibly other plot-type changes.
	-- This operation must be saved for last, as it invalidates all regional data by resetting Area IDs.
	Map.RecalculateAreas();

	-- Activate for debug only
	self:PrintFinalResourceTotalsToLog()
	--
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                             REFERENCE
------------------------------------------------------------------------------
--[[
APPENDIX A - ORDER OF OPERATIONS

1. StartPlotSystem() is called from MapGenerator() in MapGenerator.lua

2. If left to default, StartPlotSystem() executes. However, since the core map
options (World Age, etc) are now custom-handled in each map script, nearly every
script needs to overwrite this function to process the Resources option. Many
scripts also need to pass in arguments, such as division method or bias adjustments.

3. AssignStartingPlots.Create() organizes the table that includes all member
functions and all common data.

4. AssignStartingPlots.Create() executes __Init() and __InitLuxuryWeights() to
populate data structures with values applicable to the current game and map. An
empty override is also provided via __CustomInit() to allow for easy modifications
on a small scale, instead of needing to replace all of the Create() function: for
instance, if a script wants to change only a couple of values in the self dot table.

5. AssignStartingPlots:DivideIntoRegions() is called. This function and its
children carry out the creation of Region Data, to be acted on by later methods.
-a. Division method is chosen by parameter. Default is Method 2, Continental.
-b. Four core methods are included. Refer to the function for details.
-c. If applicable, start locations are assigned to specific Areas (landmasses).
-d. Each populated landmass is processed. Any with more than one civ assigned 
to them are divided in to Regions. Any with one civ are designated as a Region.
If a Rectuangular method is chosen, the map is divided without regard to Areas.
-e. Regional division occurs based on "Start Placement Fertility" measurements,
which are hard-coded in the function that measures the worth of a given plot. To
change these values for a script or mod, override the applicable function.
-f. All methods generate a database of Regions. The data includes coordinates
of the southwest corner of the region, plus width and height. If width or 
height, counting from the SW corner, would exceed a map edge, world-wrap is 
implied. As such, all processes that act on Regions need to account for wrap.
Other data included are the AreaID of the region (-1 if a division method in
use that ignores Areas), the total Start Placement Fertility measured in that
region, the total plot count of the region's rectangle, and fertility/plot. (I 
was not told until later that no Y-Wrap support would be available. As such, 
the entire default system is wired for Y-Wrap support, which seems destined to 
lie dormant unless this code is re-used with Civ6 or some other game with Y-Wrap.)

6. AssignStartingPlots:ChooseLocations() is called.
-a. Each Region defined in self.regionData has its terrain types measured.
-b. Using the terrain types, each Region is classified. The classifications
should match the definitions in Regions.XML -- or Regions.xml needs to be 
altered to match the internal classifications of any modified process. The 
Regional classifications affect favored types of terrain for the start plot
selection in that Region, plus affect matching of start locations with those
civilizations who come with Terrain Bias (preferring certain conditions to 
support their specific abilities), as well as the pool from which the Region's
Luxury type will be selected.
-c. An order of processing for Regions is determined. Regions of lowest average
fertility get their start plots chosen first. When a start plot is selected, it
creates a zone around itself where any additional starts will be reluctant to
appear, so the order matters. We give those with the worst land the best pick
of the land they have, while those with the best land will be the ones (if any)
to suffer being "pushed around" by proximity to already-chosen start plots.
-d. Start plots are chosen. There is a method that forces starts to occur along
the oceans, another method that allows for inland placement, and a third method
that ignores AreaID and instead looks for the most fertile Area available.

7. AssignStartingPlots:BalanceAndAssign() is called.
-a. Each start plot is evaluated for land quality. Those not meeting playable
standards are modified via adding Bonus Resources, Oases, or Hills. Ice, if
any, is removed from the waters immediately surrounding the start plot.
-b. The civilizations active in the current game are checked for Terrain Bias.
Any civs with biases are given first pick of start locations, seeking their
particular type of bias. Then civs who have a bias against certain terrain
conditions are given pick of what is left. Finally, civs without bias are
randomly assigned to the remaining regions.
-c. If the game is a Team game, start locations may be exchanged in an effort
to ensure that teammates start near one another. (This may upset Biases).

8. AssignStartingPlots:PlaceNaturalWonders() is called.
-a. All plots on the map are evaluated for eligibility for each Natural
wonder. Map scripts can overwrite eligibility calculations for any given NW
type, where desired. Lists of candidate plots are assembled for each NW.
-b. Some NW's with stricter eligibility may be prioritized to always appear
when eligible. The number of NWs that are eligible is checked against the 
map. If the map can support more than the number allowed for that game (based
on map size), then the ones that will be placed are selected at random.
-c. The order of placement gives priority to any "always appear if eligible"
wonders, then priority after that goes to the wonder with the fewest candidates.
-d. There are minimum distance considerations for both civ starts and other
Natural Wonders, reflected in the Impact Data Layers. If collisions eliminate
all of a wonder's candidate plots, then a replacement wonder will be "pulled 
off the bench and put in the game", if such a replacement is available.

9. AssignStartingPlots:PlaceResourcesAndCityStates() is called.
-a. Luxury resources are assigned roles. Each Region draws from a weighted
pool of Luxury types applicable to its dominant terrain type. This process
occurs according to Region Type, with Type 1 (Tundra) going first. Where
multiple regions of the same type occur, those within each category are
randomized in the selection order. When all regions have been matched to a
Luxury type (and each Luxury type can be spread across up to three regions)
then the City States pick three of the remaining types, at random. The
number of types to be disabled for that map size are removed, then the 
remainder are assigned to be distributed globally, at random. Note that all
of these values are subject to modification. See Great Plains, for example.
-b. City States are assigned roles. If enough of them (1.35x civ count, at 
least), then one will be assigned to each region. If the CS count way
exceeds the civ count, multiple CS may be assigned per region. Of those
not assigned to a region off the bat, the land of the map must be evaluated
to determine how much land exists outside of any region (if any). City
States get assigned to these "Uninhabited" lands next. Then we check for
any Luxuries that got split three-ways (a misfortune for those regions)
and, if there are enough unassigned CS remaining to give each such region
a bonus CS, this is done. Any remaining CS are awarded to Regions with the
lowest average fertility per land plot (and bound to have more total land
around as a result).
-c. The city state locations are chosen. Two methods exist: regional
placement, which strongly favors the edges of regions (civ starts strongly
favor the center of regions), and Uninhabited, which are completely random.
-d. Any city states that were unable to be placed where they were slated to 
go (due to proximity collisions, aka "overcrowded area", then are moved to 
a "last chance" fallback list and will be squeezed in anywhere on the map 
that they can fit. If even that fails, the city state is discarded.
-e. Luxury resources are placed. Each civ gets at least one at its start
location. Regions of low fertility can get up to two more at their starts.
Then each city state gets one luxury, the type depending on what is 
possible to place at their territory, crossed with the pool of types
available to city states in that game. Then, affected by what has already
been placed on the map, the amount of luxuries for each given region are
determined and placed. Finally, based on what has been placed so far, the
amount of the remaining types is determined, and they are placed globally.
-f. Each civ is given a second Luxury type at its start plot (except in 
games using the Resources core map option available on most scripts, and
choosing the Sparse setting.) This second Luxury type CAN be Marble, which
boosts wonder production. (Marble is not in the normal rotation, though.)
-g. City State locations low on food (typical) or hammers get some help
in the normalization process: mostly food Bonus resources.
-h. Strategic resources are placed globally. The terrain balance greatly
affects location and quantity of various types and their balance. So the
game is going to play differently on different map scripts.
-i. Bonus resources are distributed randomly, with weightings. (Poor 
terrain types get more assistance, particularly the Tundra. Hills regions
get extra Bonus support as well.)
-j. Various cleanup operations occur, including placing Oil in the sea, 
fixing Sugar terrain -- and as the very last item, recalculating Area IDs, 
which invalidates the entire Region Data pool, so it MUST come last.

10. Process ends. Map generation continues according to MapGenerator()
------------------------------------------------------------------------------

APPENDIX B - ADVICE FOR MODDERS

Depending upon the game areas being modified, it may be necessary to modify
the start placement and resource distribution code to support your effort.

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
If you are modifying Civilizations:

* You can plug your new or modified civilizations in to the Terrain Bias 
system via table entries in Civ5Civilizations.xml

1. Start Along Ocean
2. Start Along River		-- Ended up inactive for the initial civ pool, but is operational in the code.
3. Start Region Priority
4. Start Region Avoid

Along Ocean is boolean, defaulting to false, and is processed first, 
overriding all other concerns. Along River is boolean and comes next.

Priority and Avoid refer to "region types", of which there are eight. Each 
of these region types is dominated by the associated terrain.
1. Tundra
2. Jungle
3. Forest
4. Desert
5. Hills
6. Plains
7. Grass
8. Hybrid (of plains and grass).
9. Wetlands 

The defintions are sequential, so that a region that might qualify for
more than one designation gets the lowest-number it qualifies for.

The Priority and Avoid can be multiple-case. There are multiple-case Avoid
needs in the initial Civ pool, but only single-case Priority needs. This is
because the single-case needs have a fallback method that will place the civ
in the region with the most of its favored terrain type, if no region is 
available that is dominated by that terrain. Whereas any Civ that has multiple
Priority needs must find an exact region match to one of its needs or it gets
no bias. Thus I found that all of the biases desired for the initial Civ pool
were able to be met via single Priority.

Any clash between Priority and Avoid, Priority wins. 

I hope you enjoy this new ability to flavor and influence start locations.
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
If you are modifying Resources:

XML no longer plays any role whatsoever on the distribution of Resources, but
it does still define available resource types and how they will interact with
the game.

Do not place a Luxury resource type at the top of the list, in ID slot #0.
Other than that, you can do what you will with the list and how they are ordered.

Be warned, there is NO automatic handling of resource balance and appearance for
new or modified resource types. Gone is the Civ4 method of XML-based terrain
permissions. Gone is plug-and-play with new resource types. If you remove any
types from the list, you will need to disable the hard-coded handling of those
types present in the resource distribution. If you modify or add types, you will
not see them in the game until you add them to the hard-coded distribution.

The distribution is handled wholly within this file, here in Lua. Whether you 
approve of this change is your prerogative, but it does come with benefits in
the form of greatly increased power over how the resources are placed.

Bonus resources are used as the primary method for start point balancing, both
for civs and city states. Bonus Resources do nothing at all other than affect
yields of an individual tile and the type of improvement needed in that tile.

If you modify or add bonus resources, you may want to modify Normalization
methods as well, so your mod interacts with this subsystem. These are the 
methods involved with Bonus resource normalization:

AttemptToPlaceBonusResourceAtPlot()
AttemptToPlaceHillsAtPlot()
AttemptToPlaceSmallStrategicAtPlot()
NormalizeStartLocation()
NormalizeCityState()
NormalizeCityStateLocations()	-- Dependent on PlaceLuxuries being executed first.
AddExtraBonusesToHillsRegions()

Strategic Resources are now quantified, so their placement is no longer of the
nature of on/off, and having extra of something may help. Strategics are no longer
a significant part of the trading system. As such, their balance is looser in
Civ5 than it had to be in Civ4 or Civ3. Strategics are now placed globally, but
you can modify this to any method you choose. The default method is here:

PlaceStrategicAndBonusResources()

And it primarily relies upon the per-tile approach of this method:

ProcessResourceList()

Bonus resources are the same, for their global distribution. Additional functions
that provide custom handling are here:

AddStrategicBalanceResources()	-- Only called when this game launch option is in effect.
PlaceMarble()
PlaceSmallQuantitiesOfStrategics()
PlaceFish()
PlaceSexyBonusAtCivStarts()
PlaceOilInTheSea()
FixSugarJungles()

All three types of Resources, which each play a different role in the game, are
dependent upon the new "Impact and Ripple" data layers to detect previously
placed instances and remain at appropriate distances. By replacing a singular,
hardcoded "minimum distance" with the impact-and-ripple, I have been able to
introduce variable distances. This creates a less contrived-looking result and
allows for some clustering of resources without letting the clusters grow too 
large, and without predetermining the nature and distribution of clusters. You
can most easily understand the net effect of this change by examing the fish
distribution. You will see that is less regular than the Civ4 method, yet still
avoids packing too many fish in to any given area. Larger clusters are possible
but quite rare, and the added variance should make city placement more interesting.

Another benefit of the Impact and Ripple is that it is Hex Accurate. The ripples
form a true hexagon (radiating outward from the impact plot, with weightings and
biases weakening the farther away from the impact it sits) instead of a rectangle
defined by an x-y coordinate area scan.

What this means for you, as a Resources modder, is that you will need to grasp
the operation of Impact and Ripple in order to properly calibrate any placements
of resources that you decide to make. This is true for all three types. Each has
its own layer of Impact and Ripple, but you could choose to remove a resource 
from participation in a given layer, assign it to a different layer or to its own
layer, or even discard this method and come up with your own. Realize that each
resource placed will impact its layer, rippling outward from its plot to whatever
radius range you have selected, and then bar any later placements from being close
to that resource.

Everywhere in this code that a civ start is placed, or a city state, or a resource,
there are associated Impacts and Ripples on one or more data layers. The 
interaction of all this activity is why a common database was needed. Yet because
none of this data affects the game after game launch and the map has been set, it 
is all handled locally here in Lua, then is discarded and its memory recycled.

Meanwhile, Luxury resources are more tightly controlled than ever. The Regional
Division methods are as close to fair as I could make them, considering the highly
varied and unpredicatable landforms generated by the various map scripts. They
are fair enough to form a basis for distributing Luxuries in a way to create
supply and demand, to foster trade and diplomacy.


All Luxury resource placements are handled via this method:

PlaceSpecificNumberOfResources()

This method also handles placement of sea-based sources of Oil.


Like ProcessResourceList(), this method acts upon a plot list fed to it, but 
instead of handling large numbers of plots and placing one for every n plots, it
tends to handle much smaller number of plots, and will return the number it was
unable to place for whatever reason (collisions with the luxury data layer being
the main cause, and not enough members in the plot list to receive all the
resources being placed is another) so that fallback methods can try again.

As I mentioned earlier, XML no longer governs resource placement. Gone are the 
XML terrain permissions, a hardwired "all or nothing" approach that could allow
a resource to appear in forest (any forest), or not. The new method allows for 
more subtlety, such as creating a plot list that includes only forests on hills,
or which can allow a resource to appear along rivers in the plains but only 
away from rivers in grasslands. The sky is the limit, now, when it comes to 
customizing resource appearance. Any method you can measure and implement, and
translate in to a list of candidate plots, you can apply here.

The default permissions are now contained in an interaction between two married
functions: terrain-based plot lists and a function matching each given resource
to a selection of lists appropriate to that resource.

The three list-generating functions are these:

GenerateGlobalResourcePlotLists()
GenerateLuxuryPlotListsAtCitySite()
GenerateLuxuryPlotListsInRegion()


The indexing function is:

GetIndicesForLuxuryType()


The process uses one of these three list generations (depending on whether it 
is currently trying to assign Luxuries globally, regionally, or in support of
a specific civ or city state start location).

Other methods determine WHICH Luxury fits which role and how much of it to place;
then these processes come up with candidate plot lists, and then the indexing
matches the appropriate lists to the specific luxury type. Finally, all of this
data is passed to the function that actually places the Luxury, which is:

PlaceSpecificNumberOfResources()


If you want to modify the terrain permissions of existing Luxury types, you 
need only handle the list generators and the indexing function.


If you want to modify which Luxury types get assigned to which Region types:

__InitLuxuryWeights()
IdentifyRegionsOfThisType()
SortRegionsByType()
AssignLuxuryToRegion()

All weightings for regional matching are contained here. But beware, the
system has to handle up to 22 civilizations and 41 city states, so the 
combination of self.iNumMaxAllowedForRegions and the number of regions to
which any given Luxury can be assigned must multiply out to more than 22.

The default system allows up to 8 types for regions, up to 3 regions per type,
factoring out to 24 maximum allowable, barely enough to cover 22 civs.

Perhaps in an Expansion pack, more Luxury types could be added, to ease the
stress on the system. As it is, I had to spend a lot of political capital 
with Jon to get us to Fifteen Luxury Types, and have enough to make this
new concept and this new system work. The amount is plenty for the default
numbers of civs for each map size, though. If too many types come available
in a given game, it could upset the game balance regarding Happiness and Trade.


If you wish to add new Luxury types, there is quite a bit involved. You will 
either have to plug your modifications in to the existing system, or replace
the entire system. I have worked to make it as easy as possible to interact
with the new system, documenting every function, every design element. And
since this entire system exists here in Lua, nothing is beyond your reach.

The "handy resource ID shortcuts" will free you from needing to order the
luxuries in the XML in any particular fashion. These IDs will adapt to the
XML list. But you will have to create new shortcuts for any added or renamed
Luxury types, and activate the shortcuts here:

__Init()

You will also need to deactivate or remove any code handling luxury types
that your mod removes. I recommend using an editor with a Find feature and 
scan the file for all instances of keys that you want to remove. At each
instance found, if the key is in a group, you can safely remove it from 
the group so long as the group retains at least one key in it. If the key
is the only one being acted upon, you may need to replace it with a different
key or else deactivate that chunk of code. (If the method attempts to act
upon a nil-value key, that will cause an Assert and the start finder will
exit without finishing all of its operations.)

If you are going to plug in to the new system, you need to determine if the
default terrain-based plot lists meet your needs. If not, create new list 
types for all three list-generation methods and index them as applicable.

GenerateGlobalResourcePlotLists()
GenerateLuxuryPlotListsAtCitySite()
GenerateLuxuryPlotListsInRegion()
GetIndicesForLuxuryType()

You will also need to modify functions that determine which Luxury types
can be placed at City States (this affects which luxury each receives).

GetListOfAllowableLuxuriesAtCitySite()


Finally, the command center of Luxury Distribution is here:

PlaceLuxuries()
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
If you are modifying Terrain:

You will need to update every aspect of the new system to make it operate
correctly on your terrain changes. Or you will need to replace the entire system.

I'm sorry if that is bad news, but if you modified Terrain for Civ4, you likely
experienced it being applied inconsistently (not working on lots of map scripts)
and ran in to barriers where something you wanted to do was impossible, because
only certain limited permissions were enabled through the XML. You may even have
had to rise to the level of modifying the game core DLLs in C++ to open up more
functionality.

Whatever interactions with the game core your terrain needs to make remain in the
XML and the C++. The only relevant aspects here involve how your terrain interacts
with map generation, start placement, and resource distribution.

I have modified the base map generation methods to include more parameters and
options, so that more of the map scripts can rely on them. This means less 
hardcoding in individual scripts, to where an update to the core methods that 
includes new terrain types or feature types will have a wider reach.

As for start placement and resources, a big part of Jon's vision for Civ5 was to
bring back grandiose terrain, realistically large regions of Desert, Tundra, 
Plains, and so on. But this type of map, combined with the old start generation
method, tended to force starts on grassland, and do other things counter to the
vision. So I designed the new system to more accurately divide the map, not by 
strict tile count, but by relative worth, trying to give each civ as fair a patch
of land as possible. Where the terrain would be too harsh, we would support it
with Bonus resources, which could now be placed in any quantity needed, thanks to
being untied from the trade system. The regonal division divides the map, then
the classification system identifies each region's dominant terrain type and aims
to give the civ who starts there a flavored environment, complete with a start in
or near that type of terrain, enough Bonus to remove the worst cases of "bad luck", 
and a cluster of luxury resources at hand that is appropriate to that region type.

In doing all of this, I have hard-coded the system with countless assumptions 
based on the default terrain. If you wish to make use of this system in tandem 
with new types of terrain or with modified yields of existing terrain, or both,
you will need to rewire the system, mold it to the specific needs of the new
terrain balance that you are crafting.

This begins with the Start Placement Fertility, which is measured per plot here:

MeasureStartPlacementFertilityOfPlot()


Measurements are processed in two ways, but you likely don't need to mod these:

MeasureStartPlacementFertilityInRectangle()
MeasureStartPlacementFertilityOfLandmass()


Once you have regions dividing in ways appropriate to your new terrain, you will
need to update terrain measurements and regional classifications here:

MeasureTerrainInRegions()
DetermineRegionTypes()

You may also have XML work to do in regard to regions. The region list is here:
CIV5Regions.xml

And each Civilization's specific regional or terrain bias is found here:
CIV5Civilizations.xml


Start plot location is a rather sizable operation, spanning half a dozen functions.

MeasureSinglePlot()
EvaluateCandidatePlot()
IterateThroughCandidatePlotList()
FindStart()
FindCoastalStart()
FindStartWithoutRegardToAreaID()
ChooseLocations()

Depending on the nature of your modifications, you may need to recalibrate this 
entire system. However, like with Start Fertility, the core of the system is 
handled at the plot level, evaluating the meaning of each type of plot for each
type of region. I have enacted a simple mechanism at the core, with only four
categories of plot measurement: Food, Prod, Good, Junk. The food label may be
misleading, as this is the primary mechanism for biasing starting terrain. For
instance, in tundra regions I have tundra tiles set as Food, but grass are not.
A desert region sets Plains as Food but Grass is not, while a Jungle region sets
Grass as Food but Plains aren't. The Good tiles act as a hedge, and are the main
way of differentiating one candidate site from another, so that among a group of
plots of similar terrain, the best tends to get picked. I also have the overall
standards set reasonably low to keep the Center Bias element of the system at 
the forefront of start placement. This is chiefly because the exact quality of 
the initial starting location is less urgent than maintaining as good of a 
positioning as possible among civs. Balancing the quality of the start plot
against positioning near the center of each region was a fun challenge to 
tackle, and I feel that I have succeeded in my design goals. Just be aware that
any change loosening the bias toward the center could ripple through the system.

Regional terrain biases that purposely put starts in non-ideal terrain are
intended to be supported via Normalization and other compensations built in to
the system in general. Yet the normalization used in Civ5 is much more lightly
applied than Civ4's methods. The new system modifies the actual terrain as
little as possible, giving support mostly through the addition of Bonus type
resources, which add food. Jon wanted starts to occur in a variety of terrain
yet for each to be competitive. He directed me to use resources to balance it.


If your terrain modifications affect tile yields, or introduce new elements in
to the ecosystem, it is likely your mod would benefit from adjusting the start
site normalization process.

AttemptToPlaceBonusResourceAtPlot()
AttemptToPlaceHillsAtPlot()
AttemptToPlaceSmallStrategicAtPlot()
NormalizeStartLocation()
PlaceSexyBonusAtCivStarts()
AddExtraBonusesToHillsRegions()

City State placement is subordinate to civ placement, in the new system. The 
city states get no consideration whatsoever to the quality of their starts, only
to the location relative to civilizations. So this is the one area of the system
that is likely to be unaffected by terrain mods, except at Normalization:

NormalizeCityState()
NormalizeCityStateLocations()


Finally, a terrain mod is sure to scramble the hard-coded and carefully balanced
resource distribution system. That entire system is predicated upon the nature
of default terrain, what it yields, how the pieces interact, how they are placed
by map scripts, and in general governed by a measured sense of realism, informed
by gameplay needs and a drive for simplicity. From the order of operations upon
regions (sorted by dominant terrain type) to the interwoven nature of resource
terrain preferences, it is unlikely the default implementation will properly 
support any significant terrain mod. The work needed to integrate a terrain mod
in to resource distribution would be similar to that needed for a resource mod,
so I will refer you back to that section of the appendix for additional info.
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
If you are modifying game rules:

The new system is rife with dependencies upon elements in the default rules. This
need not be a barrier to your mod, but it will surely assist in your cause to
be alert to possible side effects of game rules changes. One of the biggest
dependencies lies with rules that govern tile improvements: how much they benefit,
where they are possible to build, when upgrades to their yield output come online
and so forth. Evaluations for Fertility that governs regional division, for 
Normalization that props up weaker locations, and the logic of resource distribution
(such as placing numerous Deer in the tundra to make small cities viable there)
all depend in large part on the current game rules. So if, for instance, your mod
were to remove or push back the activation of yield boost at Fresh Water farms, 
this would impact the accuracy of the weighting that the start finder places on
fresh water plots and on fresh water grasslands in particular. This is the type of
assumption built in to the system now. In a way it is unfriendly to mods, but it 
also provides a stronger support for the default rule set, and sets an example of
how the system could support mods as well, if re-calibrated successfully.

The start placement and resource distribution systems include no mechanism for
automatically detecting game rules modifications, or terrain or resource mods, 
either. So to the degree that your mod may impact the logic of start placement,
you may want to consider making adjustments to the system, to ensure that it
behaves in ways productive to your mod.
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

------------------------------------------------------------------------------

APPENDIX C - ACKNOWLEDGEMENTS

Thanks go to Jon for turning me loose on this system. I had the vision for
this system as far back as the middle of vanilla Civ4 development, but I did
not get the opportunity to act on it until now. Designing, coding, testing 
and implementing my baby here have been a true pleasure. That the effort has
enabled a key element of Jon's overall vision for the game is a pride point.

Thanks to Ed Beach for his brilliant algorithm, which has enhanced the value
and performance of this system to a great degree.

Thanks to Shaun Seckman and Brian Wade for numerous instances of assistance
with Lua programming issues, and for providing the initial ports of Python to
Lua, which gave me an easy launching point for all of my tasks.

Thanks to everyone on the Civ5 development team whom I met on my visit to 
Firaxis HQ in Baltimore, who were so warm and welcoming and supportive. It
has been a joy to be part of such a positive working environment and to 
contribute to a team like this. If every gamer got to see the inside of
the studio and how things really work, I believe they would be inspired.

Thanks to all on the web team, who provided direct and indirect support. I
can't reveal any details here, but each of you knows who you are.

Finally, special thanks to my wife, Jaime, who offered advice, input,
feedback and general support throughout my design and programming effort.

- Robert B. Thomas	(Sirian)		April 26, 2010
]]--
------------------------------------------------------------------------------
