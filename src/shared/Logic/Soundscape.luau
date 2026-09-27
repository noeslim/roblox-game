--!strict
-- Which music and ambience to play where (roadmap 2.4). Pure: the client hands in where the player
-- is and what is going on; the ids come from Config/Soundscape.

local Soundscape = {}

export type Context = {
	district: string, -- Soundscape.DistrictAt, "Streets" on the avenues
	inHideout: boolean, -- inside a trap house basement
	raid: boolean, -- a raid on your own stash
	isNight: boolean,
}
export type Pick = { music: string, ambience: string, muffled: boolean }

-- District of the cell containing (x, z), or "Streets" (avenues, ring road, outside the city).
function Soundscape.DistrictAt(city: any, x: number, z: number): string
	local G = city.Grid
	local N, C, A = G.Cells, G.CellSize, G.AvenueWidth
	local half = (N * C + (N + 1) * A) / 2
	local lx = x - city.Origin.x + half - A
	local lz = z - city.Origin.z + half - A
	local col = math.floor(lx / (C + A)) + 1
	local row = math.floor(lz / (C + A)) + 1
	if col < 1 or col > N or row < 1 or row > N then
		return "Streets"
	end
	-- on the avenue after the cell
	if lx - (col - 1) * (C + A) > C or lz - (row - 1) * (C + A) > C then
		return "Streets"
	end
	return city.Districts[row][col]
end

-- Inside a basement: local position relative to the plot origin (center of the floor top).
function Soundscape.InBasement(lx: number, ly: number, lz: number, sizeX: number, sizeZ: number, height: number): boolean
	return math.abs(lx) <= sizeX / 2 + 2 and math.abs(lz) <= sizeZ / 2 + 2 and ly > -1 and ly < height + 1
end

function Soundscape.Pick(ctx: Context): Pick
	local music = ctx.district
	if ctx.raid then
		music = "Raid"
	elseif ctx.inHideout then
		music = "Hideout"
	end
	return {
		music = music,
		ambience = if ctx.inHideout then "Hideout" else ctx.district,
		muffled = ctx.inHideout,
	}
end

local function resolve(track: any, isNight: boolean): string
	if type(track) == "string" then
		return track
	elseif type(track) == "table" then
		local id = if isNight then track.Night else track.Day
		return if type(id) == "string" then id else ""
	end
	return ""
end

-- The id to play for a zone key; an empty zone falls back to "Streets", then "".
function Soundscape.TrackId(tracks: { [string]: any }, key: string, isNight: boolean): string
	local id = resolve(tracks[key], isNight)
	if id == "" and key ~= "Raid" and key ~= "Hideout" then
		id = resolve(tracks.Streets, isNight)
	end
	return id
end

return Soundscape
