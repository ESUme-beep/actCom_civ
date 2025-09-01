-- dumpData
-- Author: ESUme-beep
-- DateCreated: 8/31/2025 10:14:28 PM
-- Description: This files dumps data to a user defined folder
--------------------------------------------------------------
MaxCoordX = 0
MaxCoordY = 0
StringedPlotTable = {}

-- find out how big the map is
function GetMaxCoords()
	local x_coord = 0
	local y_coord = 0
	local plot_in_bounds = true
	while plot_in_bounds == true do
		if MaxCoordX == 0 then
			x_coord = x_coord + 1
			local x_in_bounds = Map.IsPlot(x_coord, y_coord)
			if x_in_bounds == false then
				MaxCoordX = x_coord -1
			end
		end

		if MaxCoordY == 0 then
			y_coord = y_coord + 1
			local y_in_bounds = Map.IsPlot(x_coord, y_coord)
			if y_in_bounds == false then
				MaxCoordY = y_coord -1
			end
		end

		if MaxCoordX ~= 0 and MaxCoordY ~= 0 then
			plot_in_bounds = false
		end
	end
end

-- gets plot data
function GetPlotDataString(plot)
    if plot == nil then
        return "nil plot"
    end
    
    local x = plot:GetX()
    local y = plot:GetY()
    local terrain_type = GameInfo.Terrains[plot:GetTerrainType()]
    local feature_type = GameInfo.Features[plot:GetFeatureType()]
    local resource_type = GameInfo.Resources[plot:GetResourceType()]
    local owner = plot:GetOwner()
    
    return string.format("Plot(%d,%d): Terrain=%s, Feature=%s, Resource=%s, Owner=%d", 
    x, y, 
    terrain_type and terrain_type.Name or "None",
    feature_type and feature_type.Name or "None", 
    resource_type and resource_type.Name or "None",
    owner)
end

-- gets tiles and adds them to table of processed tiles
function ProcessTiles()
	for x=0, MaxCoordX do
		for y=0, MaxCoordY do
			local tile_ref = Map.GetPlot(x,y)
			local tile_data_string = GetPlotDataString(tile_ref)
			local x_string = tostring(x) .. ","
			local y_string = tostring(y)
			local coord = x_string .. y_string
			StringedPlotTable[coord] = tile_data_string
		end
	end
end

-- dumps map data to text file
function DumpMapDataString()
    print("BEGIN_EXPORTING_MAP_DATA")
	for str_coord, junk in pairs(StringedPlotTable) do
        local fancy_string = StringedPlotTable[str_coord] .. "\n"
		print(fancy_string)
	end
	print("ENDING_EXPORTING_MAP_DATA")
end

if MaxCoordX == 0 then
	GetMaxCoords()
	ProcessTiles()
	DumpMapDataString()
end

