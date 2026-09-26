--!strict
-- Minimal test runner for Lune.  Usage: lune run tests/run [filter]
local fs = require("@lune/fs")
local process = require("@lune/process")

local filter = process.args[1]

local passed, failed = 0, 0
local failures: { string } = {}

local function fmt(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

local function makeT(specName: string)
	local t = {}

	function t.test(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			passed += 1
			print("  ✓ " .. name)
		else
			failed += 1
			print("  ✗ " .. name)
			print("      " .. tostring(err))
			table.insert(failures, specName .. " > " .. name .. "\n      " .. tostring(err))
		end
	end

	function t.eq(actual: any, expected: any, msg: string?)
		if actual ~= expected then
			error((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
		end
	end

	function t.near(actual: number, expected: number, tolerance: number?, msg: string?)
		local tol = tolerance or 1e-6
		if math.abs(actual - expected) > tol then
			error((msg and (msg .. ": ") or "") .. "expected ~" .. fmt(expected) .. ", got " .. fmt(actual), 2)
		end
	end

	function t.truthy(v: any, msg: string?)
		if not v then
			error(msg or ("expected truthy, got " .. fmt(v)), 2)
		end
	end

	function t.falsy(v: any, msg: string?)
		if v then
			error(msg or ("expected falsy, got " .. fmt(v)), 2)
		end
	end

	function t.throws(fn: () -> (), msg: string?)
		local ok = pcall(fn)
		if ok then
			error(msg or "expected function to throw", 2)
		end
	end

	return t
end

local files = fs.readDir("tests/specs")
table.sort(files)

for _, file in files do
	if string.sub(file, -10) == ".spec.luau" and (filter == nil or string.find(file, filter, 1, true)) then
		local name = string.sub(file, 1, -11)
		print("\n" .. name)
		local ok, spec = pcall(require, "./specs/" .. name .. ".spec")
		if not ok then
			failed += 1
			print("  ✗ failed to load: " .. tostring(spec))
			table.insert(failures, name .. " (load error)\n      " .. tostring(spec))
		else
			(spec :: any)(makeT(name))
		end
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("\nFailures:")
	for _, f in failures do
		print("  - " .. f)
	end
	process.exit(1)
end
