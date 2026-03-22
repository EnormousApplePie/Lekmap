
--luacheck: globals LekmapUtilities globals Map include findStarts Lekmap_Globals GetPlayerAndTeamInfo

LekmapUtilities = {}

function LekmapUtilities.get_plots_global()
   local plots = {}
   local iW, iH = Map.GetGridSize();
   for y = 0, iH - 1 do
      for x = 0, iW - 1 do
         local plot = Map.GetPlot(x, y)
         table.insert(plots, plot)
      end
   end
return plots end

function LekmapUtilities.get_number_of_players()
   local iNumCivs = 0
	for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
	   local player = Players[i]
		if player:IsEverAlive() then
			iNumCivs = iNumCivs + 1;
		end
	end
return iNumCivs end

function LekmapUtilities.remove_from_table(incoming_table, value)
   for i = #incoming_table, 1, -1 do
      if incoming_table[i] == value then
         table.remove(incoming_table, i)
      end
   end
return incoming_table end
