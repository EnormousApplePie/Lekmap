------------------------------------------------------------------------------
--	FILE:               Lekmap_TerrainGenerator.lua  (renamed from HBTerrainGenerator.lua)
--	MODIFIED FOR CIV5:  Bob Thomas
--	PYTHON TO LUA:      Shaun Seckman
--	PURPOSE:            Default method for terrain generation
------------------------------------------------------------------------------
--	Copyright (c) 2009, 2010 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

----------------------------------------------------------------------------------
TerrainGenerator = {}
----------------------------------------------------------------------------------
function TerrainGenerator.Create(args)
	--[[ Civ4's truncated "Climate" setting has been abandoned. Civ5 has returned to 
	Civ3-style map options for World Age, Temperature, and Rainfall. Control over the 
	terrain has been removed from the XML.  - Bob Thomas, March 2010  ]]--
	--
	-- Sea Level and World Age map options affect only plot generation.
	-- Temperature map options affect only terrain generation.
	-- Rainfall map options affect only feature generation.
	--
	local args = args or {}
	local temperature = args.temperature or 2 -- Default setting is Temperate.
	local frac_x_exp = args.frac_x_exp or -1
	local frac_y_exp = args.frac_y_exp or -1
	local grain_amount = args.grain_amount or 3
	local grass_moist = args.grass_moist or 2

	-- These settings offer a limited ability for map scripts to modify terrain.
	-- Where these are inadequate, replace the TerrainGenerator with a custom method.
	local temperature_shift = args.temperature_shift or 0.1
	local desert_shift = args.desert_shift or 16
	
	-- Set terrain bands.
	local desert_percent = args.desert_percent or 32
	local plains_percent = args.plains_percent or 65 -- Deserts are processed first, so Plains will take this percentage of whatever remains. - Bob

	if grass_moist == 1 then
		plains_percent = 50
	elseif grass_moist == 3 then
		plains_percent = 80
	end

	local snow_latitude = args.snow_latitude or 0.90
	
	local tundra_level = Map.GetCustomOption(10)

	local tundra_latitude = args.tundra_latitude or 0.59

	if tundra_level == 1 then
		tundra_latitude = 0.65
	elseif tundra_level == 3 then
		tundra_latitude = 0.35
	end

	local grass_latitude = args.grass_latitude or 0.1 -- Above this is actually the latitude where it stops being all grass. - Bob
	
	if grass_moist == 3 then
		grass_latitude = 0.05
	end

	local desert_bottom_latitude = args.desert_bottom_latitude or 0.2
	local desert_top_latitude = args.desert_top_latitude or 0.5
	-- Adjust terrain bands according to user's Temperature selection. (Which must be passed in by the map script.)
	if temperature == 1 then -- World Temperature is Cool.
		desert_percent = desert_percent - desert_shift
		tundra_latitude = tundra_latitude - (temperature_shift * 1.5)
		desert_top_latitude = desert_top_latitude - temperature_shift
		grass_latitude = grass_latitude - (temperature_shift * 0.5)
	elseif temperature == 3 then -- World Temperature is Hot.
		desert_percent = desert_percent + desert_shift
		snow_latitude = snow_latitude + (temperature_shift * 0.5)
		tundra_latitude = tundra_latitude + temperature_shift
		desert_top_latitude = desert_top_latitude + temperature_shift
		grass_latitude = grass_latitude - (temperature_shift * 0.5)
	else -- Normal Temperature.
	end
	
	--[[ Activate printout for debugging only
	print("-") print("- Desert Percentage:", desert_percent)
	print("--- Latitude Readout ---")
	print("- All Grass End Latitude:", grass_latitude)
	print("- Desert Start Latitude:", desert_bottom_latitude)
	print("- Desert End Latitude:", desert_top_latitude)
	print("- Tundra Start Latitude:", tundra_latitude)
	print("- Snow Start Latitude:", snow_latitude)
	print("- - - - - - - - - - - - - -")
	]]--

	local grid_width, grid_height = Map.GetGridSize()
	local world_info = GameInfo.Worlds[Map.GetWorldSize()]

	local data = {
	
		-- member methods
		InitFractals         = TerrainGenerator.InitFractals,
		GetLatitudeAtPlot    = TerrainGenerator.GetLatitudeAtPlot,
		GenerateTerrain      = TerrainGenerator.GenerateTerrain,
		GenerateTerrainAtPlot = TerrainGenerator.GenerateTerrainAtPlot,
	
		-- member variables
		grain_amount    = grain_amount,
		fractal_flags   = Map.GetFractalFlags(),
		map_width       = grid_width,
		map_height      = grid_height,
		
		desert_percent  = desert_percent,
		plains_percent  = plains_percent,

		desert_top_percent    = 100,
		desert_bottom_percent = math.max(0, math.floor(100 - desert_percent)),
		plains_top_percent    = 100,
		plains_bottom_percent = math.max(0, math.floor(100 - plains_percent)),
		
		snow_latitude          = snow_latitude,
		tundra_latitude        = tundra_latitude,
		grass_latitude         = grass_latitude,
		desert_bottom_latitude = desert_bottom_latitude,
		desert_top_latitude    = desert_top_latitude,
		
		frac_x_exp = frac_x_exp,
		frac_y_exp = frac_y_exp,
		
	}

	data:InitFractals()
	
	return data
end
----------------------------------------------------------------------------------	
function TerrainGenerator:InitFractals()
	self.deserts = Fractal.Create(self.map_width, self.map_height,
								  self.grain_amount, self.fractal_flags,
								  self.frac_x_exp, self.frac_y_exp)
									
	self.desert_top = self.deserts:GetHeight(self.desert_top_percent)
	self.desert_bottom = self.deserts:GetHeight(self.desert_bottom_percent)

	self.plains = Fractal.Create(self.map_width, self.map_height,
								 self.grain_amount, self.fractal_flags,
								 self.frac_x_exp, self.frac_y_exp)
									
	self.plains_top = self.plains:GetHeight(self.plains_top_percent)
	self.plains_bottom = self.plains:GetHeight(self.plains_bottom_percent)

	self.variation = Fractal.Create(self.map_width, self.map_height,
									self.grain_amount, self.fractal_flags,
									self.frac_x_exp, self.frac_y_exp)

	self.terrain_desert = GameInfoTypes["TERRAIN_DESERT"]
	self.terrain_plains = GameInfoTypes["TERRAIN_PLAINS"]
	self.terrain_snow   = GameInfoTypes["TERRAIN_SNOW"]
	self.terrain_tundra = GameInfoTypes["TERRAIN_TUNDRA"]
	self.terrain_grass  = GameInfoTypes["TERRAIN_GRASS"]
end
----------------------------------------------------------------------------------
function TerrainGenerator:GetLatitudeAtPlot(x, y)
	-- Terrain bands are governed by latitude.
	-- Returns a latitude value between 0.0 (tropical) and 1.0 (polar).
	local lat = math.abs((self.map_height / 2) - y) / (self.map_height / 2)
	
	-- Adjust latitude using self.variation fractal, to roughen the border between bands:
	lat = lat + (128 - self.variation:GetHeight(x, y)) / (255.0 * 5.0)
	-- Limit to the range [0, 1]:
	lat = math.clamp(lat, 0, 1)
	
	return lat
end
----------------------------------------------------------------------------------
function TerrainGenerator:GenerateTerrain()		
	
	local terrain_data = {}
	for x = 0, self.map_width - 1 do
		for y = 0, self.map_height - 1 do 
			local i = y * self.map_width + x
			local terrain = self:GenerateTerrainAtPlot(x, y)
			terrain_data[i] = terrain
		end
	end

	return terrain_data
end
----------------------------------------------------------------------------------
function TerrainGenerator:GenerateTerrainAtPlot(x, y)
	local lat = self:GetLatitudeAtPlot(x, y)

	local plot = Map.GetPlot(x, y)
	if (plot:IsWater()) then
		local current_terrain = plot:GetTerrainType()
		if current_terrain == TerrainTypes.NO_TERRAIN then -- Error handling.
			current_terrain = self.terrain_grass
			plot:SetPlotType(PlotTypes.PLOT_LAND, false, false)
		end
		return current_terrain
	end
	
	local terrain_val = self.terrain_grass

	if(lat >= self.snow_latitude) then
		terrain_val = self.terrain_snow
	elseif(lat >= self.tundra_latitude) then
		terrain_val = self.terrain_tundra
	elseif (lat < self.grass_latitude) then
		terrain_val = self.terrain_grass
	else
		local desert_val = self.deserts:GetHeight(x, y)
		local plains_val = self.plains:GetHeight(x, y)
		if ((desert_val >= self.desert_bottom) and (desert_val <= self.desert_top) and (lat >= self.desert_bottom_latitude) and (lat < self.desert_top_latitude)) then
			terrain_val = self.terrain_desert
		elseif ((plains_val >= self.plains_bottom) and (plains_val <= self.plains_top)) then
			terrain_val = self.terrain_plains
		end
	end
	
	-- Error handling.
	if (terrain_val == TerrainTypes.NO_TERRAIN) then
		return plot:GetTerrainType()
	end

	return terrain_val
end
----------------------------------------------------------------------------------	
