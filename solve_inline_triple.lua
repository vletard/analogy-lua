#!/usr/bin/env lua

dofile "/people/letard/local/lib/lua/toolbox.lua"
appa         = dofile "appa.lua"
segmentation = dofile "segmentation.lua"

--------------------------------------------------------------------------------
-- Paramètres 

local chunk_mode = "characters"

-- local use_squares            =  true
-- local use_cubes              =  true

--------------------------------------------------------------------------------

function info(arg)
  write(arg)
end


assert(arg[1])
local triple = {}
local txt_triple = {}
for match in arg[1]:gmatch("[^\t]+") do
  table.insert(triple, segmentation.chunk(chunk_mode, match))
  table.insert(txt_triple, match)
end
assert(#triple == 3)

local results = appa.solve(triple[1], triple[2], triple[3])
if #results > 0 then
  info(segmentation.concat(results[#results].solution.t).."\t: "..txt_triple[3].." :: "..txt_triple[2].." : "..txt_triple[1])
end
