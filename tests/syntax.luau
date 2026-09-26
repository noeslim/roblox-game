--!strict
-- Compiles every .luau file under src/ to catch syntax errors (Roblox APIs are not executed).
-- Usage: lune run tests/syntax
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local errors = 0
local count = 0

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				errors += 1
				print("✗ " .. path .. "\n   " .. tostring(err))
			end
		end
	end
end

walk("src")
print(string.format("%d files compiled, %d syntax errors", count, errors))
if errors > 0 then
	process.exit(1)
end
