
--luacheck: globals Lekmap_Utilities globals Map include findStarts Lekmap_Globals GetPlayerAndTeamInfo

Lekmap_Utilities = {}

Lekmap_Utilities.GetPlots = {}

function Lekmap_Utilities.GetPlots.Global()
    local plots = {}
    local iW, iH = Map.GetGridSize();
    for y = 0, iH - 1 do
        for x = 0, iW - 1 do
            local plotIndex = y * iW + x + 1;
            table.insert(plots, plotIndex)
        end
    end
end

function Lekmap_Utilities.GetNumberOfPlayers()
    local iNumCivs = 0
	for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local player = Players[i]
		if player:IsEverAlive() then
			iNumCivs = iNumCivs + 1;
		end
	end
return iNumCivs end

function Lekmap_Utilities.RemoveFromTable(incoming_table, value)
    for i = #incoming_table, 1, -1 do
        if incoming_table[i] == value then
            table.remove(incoming_table, i)
        end
    end
return incoming_table end
