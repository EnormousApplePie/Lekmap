
--luacheck: globals Lekmap_Utilities globals Map include findStarts
include("HBAssignStartingPlots")

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

function Lekmap_Utilities.GetPlots.Ring(x, y, radius)
    local iW, iH = Map.GetGridSize();
    local wrapX = Map:IsWrapX();
    local wrapY = Map:IsWrapY();
    local odd = findStarts.firstRingYIsOdd;
    local even = findStarts.firstRingYIsEven;
    local nextX, nextY, plot_adjustments;
    local return_table = {}
        for ripple_radius = 1, radius do

        local currentX = x - ripple_radius;
        local currentY = y;
        for direction_index = 1, 6 do
            for _ = 1, ripple_radius do
                    if currentY / 2 > math.floor(currentY / 2) then
                    plot_adjustments = odd[direction_index];
                else
                    plot_adjustments = even[direction_index];
                end
                nextX = currentX + plot_adjustments[1]
                nextY = currentY + plot_adjustments[2]

                if not (wrapX == false and (nextX < 0 or nextX >= iW))
                and not (wrapY == false and (nextY < 0 or nextY >= iH)) then

                    local realX = nextX
                    local realY = nextY
                    if wrapX then
                        realX = realX % iW
                    end
                    if wrapY then
                        realY = realY % iH
                    end
                    -- We've arrived at the correct x and y for the current plot.
                    local plot = Map.GetPlot(realX, realY)
                    table.insert(return_table, plot)
                end
                currentX, currentY = nextX, nextY
            end
        end
    end
    return return_table
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