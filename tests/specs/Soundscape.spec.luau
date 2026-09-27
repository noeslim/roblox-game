local Soundscape = require("../../src/shared/Logic/Soundscape")
local CityLayout = require("../../src/shared/Logic/CityLayout")
local City = require("../../src/shared/Config/City")
local Config = require("../../src/shared/Config/Soundscape")

local function center(r)
	return (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
end

return function(t)
	t.test("every district cell of the city is found where the map puts it", function()
		for _, cell in CityLayout.Build(City).cells do
			local x, z = center(cell.rect)
			t.eq(Soundscape.DistrictAt(City, x, z), cell.district)
			t.eq(Soundscape.DistrictAt(City, cell.rect.x0 + 1, cell.rect.z1 - 1), cell.district)
		end
	end)

	t.test("avenues and the outside are the streets", function()
		local layout = CityLayout.Build(City)
		local r = layout.cells[1].rect
		t.eq(Soundscape.DistrictAt(City, r.x1 + City.Grid.AvenueWidth / 2, (r.z0 + r.z1) / 2), "Streets")
		t.eq(Soundscape.DistrictAt(City, layout.half + 500, 0), "Streets")
		t.eq(Soundscape.DistrictAt(City, -layout.half + 1, -layout.half + 1), "Streets")
	end)

	t.test("music priority: raid, then hideout, then the district", function()
		local base = { district = "Chinatown", inHideout = true, raid = true, isNight = true }
		t.eq(Soundscape.Pick(base).music, "Raid")
		base.raid = false
		local p = Soundscape.Pick(base)
		t.eq(p.music, "Hideout")
		t.eq(p.ambience, "Hideout")
		t.truthy(p.muffled)
		base.inHideout = false
		p = Soundscape.Pick(base)
		t.eq(p.music, "Chinatown")
		t.falsy(p.muffled)
	end)

	t.test("day / night tracks, and empty zones fall back to the streets", function()
		local tracks = { Streets = { Day = "s-day", Night = "s-night" }, Chinatown = { Day = "", Night = "c-night" }, Raid = "" }
		t.eq(Soundscape.TrackId(tracks, "Chinatown", true), "c-night")
		t.eq(Soundscape.TrackId(tracks, "Chinatown", false), "s-day")
		t.eq(Soundscape.TrackId(tracks, "Docks", true), "s-night")
		t.eq(Soundscape.TrackId(tracks, "Raid", true), "") -- a raid never plays street music
	end)

	t.test("the config has a track for every district", function()
		for _, row in City.Districts do
			for _, district in row do
				t.truthy(Config.Music[district] ~= nil, district)
			end
		end
	end)

	t.test("basement bounds", function()
		t.truthy(Soundscape.InBasement(0, 3, 0, 48, 48, 14))
		t.falsy(Soundscape.InBasement(0, 20, 0, 48, 48, 14))
		t.falsy(Soundscape.InBasement(40, 3, 0, 48, 48, 14))
	end)
end
