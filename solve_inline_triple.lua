#!/usr/bin/env lua

dofile "toolbox.lua"
appa         = dofile "appa.lua"
segmentation = dofile "segmentation.lua"

--------------------------------------------------------------------------------
-- Paramètres 

local chunk_mode = "characters"
-- segmentation.dynamic_square = true

-- local use_squares            =  true
-- local use_cubes              =  true

--------------------------------------------------------------------------------

for input in io.stdin:lines() do
  local triple = {}
  local txt_triple = {}
  for match in input:gmatch("[^\t]+") do
    table.insert(triple, segmentation.chunk(chunk_mode, match))
    table.insert(txt_triple, match)
  end
  assert(#triple == 3)
  
  local results = appa.solve_tab(triple[1], triple[2], triple[3])
  if #results > 0 then
    local selected = results[#results]
    local factor_str = ""
    for _, f in ipairs(selected.factors) do
      factor_str = factor_str.."\t"..segmentation.concat(f[1]).."\t"..segmentation.concat(f[2])
    end
    print(string.format("%03d", #selected.factors).."\t"..segmentation.concat(selected.solution.t)..factor_str)
--    info(segmentation.concat(results[#results].solution.t).."\t: "..txt_triple[3].." :: "..txt_triple[2].." : "..txt_triple[1])
  end
end
