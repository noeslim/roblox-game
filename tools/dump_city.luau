-- lune run tools/dump_city  ->  writes tools/meshgen/city_layout.json (read by tools/meshgen:
-- city_assets.py for the building dimensions and city_preview.py for the 3D preview of the city)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local CityLayout = require("../src/shared/Logic/CityLayout")
local CityParts = require("../src/shared/Logic/CityParts")
local City = require("../src/shared/Config/City")

local layout = CityLayout.Build(City)

local slabs = {}
for _, s in layout.slabs do
	table.insert(slabs, CityParts.Slab(s))
end
local houses = {}
for _, h in layout.houses do
	local parts, lights = CityParts.House(City, h.index)
	table.insert(houses, { parts = parts, lights = lights })
end
-- shell (hollow ground floor) + furniture of every building, same seed as MapBuilder
local buildings = {}
for _, b in layout.buildings do
	local a = City.Archetypes[b.archetype]
	local shell, door = CityParts.BuildingShell(a, b.color, City.Interiors.WallThickness)
	local furniture, lights = CityParts.Interior(a, math.floor(b.x * 7 + b.z * 13), City.Interiors)
	table.insert(buildings, { shell = shell, door = door or false, furniture = furniture, lights = lights })
end
local specials = {}
for _, s in layout.specials do
	table.insert(specials, CityParts.Special(s, City))
end

fs.writeFile("tools/meshgen/city_layout.json", serde.encode("json", {
	layout = layout,
	config = City,
	slabParts = slabs,
	houseParts = houses,
	specialParts = specials,
	buildingParts = buildings,
}, false))
print(("buildings %d, houses %d, slabs %d, roads %d, props %d, specials %d"):format(#layout.buildings, #layout.houses, #layout.slabs, #layout.roads, #layout.props, #layout.specials))
