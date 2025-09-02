# civ 6 adapter file
import tables, rdstdin, strutils

type
  directions = enum
    d_sw, d_w, d_nw, d_ne, d_e, d_se

  districtType = enum
    d_economy, d_science, d_faith, d_military, d_wonder

  technology = object
    techName: string
    resCost: int
    techUnlocks: seq[string]

  techNode = object
    nodeTech: technology

  terrainType = object
    terrainName: string
    terrainBlocking: bool
    unitMoveCost: int
    milAttributes: seq[string]
    resAttributes: seq[string]

  resource = object
    resourceName: string
    resourceAmount: int

  terrainFeature = object
    featureName: string
    featureBlocking: bool
    featureTags: seq[string]
    featureResource: resource

  mapCell = object
    cellPosition: array[2, int]
    cellTerrain: terrainType
    cellFeature: terrainFeature
    cellResource: resource

  worldMap = object
    worldName: string
    worldWidth: int = 10
    worldHeight: int = 10
    worldSize: int = 100
    worldCells: Table[string, mapCell]

  cityDistrict = object
    districtType: districtType
    districtPos: array[2, int]

  city = object
    cityName: string
    cityHealth: int
    cityPosition: array[2, int]
    cityDistricts: seq[cityDistrict]
    cityTerritory: seq[mapCell]

  civUnit = object
    unitType: string
    unitHealth: int
    unitMovement: int
    unitDamage: int
    unitPos: array[2, int]

  leaderPersonality = object
    personalityTitle: string = "neutral"
    peaceful: float = 0.5
    aggressive: float = 0.5
    religious: float = 0.5
    scientist: float = 0.5
    expansionist: float = 0.5
    isolationist: float = 0.5
    diplomatic: float = 0.5
    forceful: float = 0.5
    trading: float = 0.5

  civLeader = object
    leaderName: string
    leaderPersonality: leaderPersonality
    leaderGoal: string
    leaderStrategy: string
    leaderLikes: seq[string]
    leaderDislikes: seq[string]

  civ = object
    civName: string
    civLeader: civLeader
    civCities: seq[string]
    civUnits: seq[civUnit]
  
  civIntel = object
    intel_id: string
    intelCivs: seq[string]
    intelUnits: seq[civUnit]

# little func to convert direction enum to coord direction
func get_direction_coord(direction: string): array[2, int] =
  case direction:
    of "d_sw":
      result = [-1, -1]
    of "d_w":
      result = [-1, 0]
    of "d_nw":
      result = [-1, 1]
    of "d_ne":
      result = [1, 1]
    of "d_e":
      result = [1, 0]
    of "d_se":
      result = [1, -1]
    else:
      result = [0, 0]
  return result     

# parses raw world data string and divides it into a sequence of world cell strings
func parse_world_string(world_strings: string): seq[string] =
  var 
    splitup: seq[string]
    mut_ws: string = world_strings
  splitup =  splitLines(mut_ws)
  var i: int = 0
  for sub_string in splitup:
    let sub_string: string = sub_string
    i += 1
    if "start_padding" in sub_string or "BEGIN_EXPORTING_MAP_DATA" in sub_string:
      continue
    elif sub_string == " ":
      continue
    elif "ENDING_EXPORTING_MAP_DATA" in sub_string:
      break
    result.add(sub_string)
  return result

# turns a string sequence into a table of cells
func cells_from_string(cell_strings: seq[string]): Table[string, mapCell] =
  for cell_string in cell_strings:
    let sub_strings: seq[string] = cell_string.split(',')
    var  
      cell: mapCell
      cell_key: string
    for sub_string in sub_strings:
      var sub_string: string = sub_string.replaceWord("DumpData: ", "").strip()
      
      if "Position" in sub_string:
        var 
          coords: array[2, int]
          i: int = 0
        if "DumpData" in sub_string:
          sub_string = sub_string.replaceWord("DumpData: Position=(", "").replace(")", "")
        cell_key = sub_string
        for coord in sub_string.split('.'):
          coords[i]= ord(coord[0])
          i += 1
        cell.cellPosition = coords
      
      elif "Terrain" in sub_string:
        let terrain_name: string = sub_string.replaceWord("Terrain=LOC_TERRAIN_", "").replaceWord("_NAME", "")
        var 
          terrain_type: terrainType
          terrain_blocking: bool = false
        if "MOUNTAIN" in terrain_name:
          terrain_blocking = true
        terrain_type.terrainName = terrain_name 
        terrain_type.terrainBlocking = terrain_blocking
        cell.cellTerrain = terrain_type
      
      elif "Feature" in sub_string and "none" notin sub_string:
        let feature_name: string = sub_string.replaceWord(" Feature=LOC_FEATURE_", "").replaceWord("_Name", "")
        var 
          feature_type: terrainFeature
          feature_blocking: bool = false
        if "ICE" in feature_name:
          feature_blocking = true
        feature_type.featureName = feature_name 
        feature_type.featureBlocking = feature_blocking
        cell.cellFeature = feature_type

      elif "Resource" in sub_string:
        if "None" in sub_string:
          continue
        var res_name: resource
        res_name.resourceName = sub_string
        cell.cellResource = res_name
      
      else:
        continue
      result[cell_key] = cell
  return result

# some table definitions with global variables
var 
  map_units: Table[string, seq[civUnit]]
  civs: Table[string, civ]
  personalities: Table[string, leaderPersonality]
  leaders: Table[string, civLeader]
  cities: Table[string, seq[city]]
  turn_events: seq[string]

# inits world map
proc init_worldmap(world_name: string, world_data_string: string): worldMap =
  var
    parsed_world: seq[string] = parse_world_string(world_data_string)
    cell_table: Table[string, mapCell] = cells_from_string(parsed_world)
    max_x: int = 0
    max_y: int = 0
  result.worldName = world_name
  for k, v in cell_table:
    let 
      x: int = ord(k[0])
      y: int = ord(k[1])
    if x > max_x:
      max_x = x
    if y > max_y:
      max_y = y
    result.worldCells[k] = v
  result.worldWidth = max_x
  result.worldHeight = max_y
  result.worldSize = max_x * max_y
  return result

# bottom up tech tree generation
proc init_tech_tree(techs: seq[string], tech_relations: seq[seq[string]], research_cost: seq[int]): seq[techNode] =
  var i: int = 0
  for tech in techs:
    let tech: string = tech
    var 
      current: technology
      current_node: techNode
    current.techName = tech
    current.res_cost = research_cost[i]
    current.techUnlocks = tech_relations[i]
    current_node.nodeTech = current
    for relation in current.techUnlocks:
      result.add(current_node)
    i += 1
  return result

var 
  world_data_file: string = readFile("map_data.txt")

try:
  let game_map: worldMap = init_worldmap("bouglas", world_data_file)
  echo game_map.worldWidth
except:
  echo "failed init proc"