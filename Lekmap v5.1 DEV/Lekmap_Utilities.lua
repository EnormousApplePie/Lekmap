--luacheck: globals Lekmap_Utilities globals Map

Lekmap_Utilities = {}

function Lekmap_Utilities.GetPlots(plotArea)
    local plots = {}
    local iW, iH = Map.GetGridSize();
    if plotArea == "global" then
        for y = 0, iH - 1 do
            for x = 0, iW - 1 do
                local plotIndex = y * iW + x + 1;
                table.insert(plots, plotIndex)
            end
        end
        return plots
    end
    if plotArea == "region" then
        return plots
    end
end

function Lekmap_Utilities.Loop(loopType, functionToCall, ...)
    if loopType == "Plot" then
        for plotID = 0, Map.GetPlotCount() - 1, 1 do
            local plot = Map.GetPlotByIndex(plotID)
            functionToCall(plot, ...)
        end
    elseif loopType == "Area" then
        for plotID = 0, Map.GetPlotCount() - 1, 1 do
            local plot = Map.GetPlotByIndex(plotID)
            if plot:IsArea(1) then
                functionToCall(plot, ...)
            end
        end
    elseif loopType == "Rect" then
        for plotID = 0, Map.GetPlotCount() - 1, 1 do
            local plot = Map.GetPlotByIndex(plotID)
            if plot:GetX() >= 0 and plot:GetX() <= 10 and plot:GetY() >= 0 and plot:GetY() <= 10 then
                functionToCall(plot, ...)
            end
        end
    end


end