#!/usr/bin/env lua

dofile "/people/letard/local/lib/lua/toolbox.lua"
dofile "knowledge.lua"
dofile "appa.lua"
dofile "io.lua"


--------------------------------------------------------------------------------
-- Paramètres 

analog_io.chunk_pattern =
-- "%S+%s*"  -- words including spaces
   "%S+"     -- words
-- "."       -- characters

-- local use_squares            =  true
-- local use_cubes              =  true
local   key_file = 
   "../case_base/2015_05_bash/train/01.in.txt"
-- "../case_base/2014_01_R/train/01.in.txt"
-- "../case_base/perso/in.txt"

local value_file = 
   "../case_base/2015_05_bash/train/01.out.txt"
-- "../case_base/2014_01_R/train/01.out.txt"
-- "../case_base/perso/out.txt"

--------------------------------------------------------------------------------

function info(arg)
  write(arg)
end


analog_io.load(key_file, value_file)

local function fact(n)
  assert(n >= 0)
  if n == 0 then
    return 1
  else
    return n * fact(n-1)
  end
end

local total = 0
local triples = {}
for _, command in pairs(knowledge.commands) do
--  info(string.format("%4d | \"%s\"", utils.table.len(command.second), analog_io.concat(command.first)))
  local n = utils.table.len(command.second)
  local c = (n <= 3) and n or fact(n) / fact(n - 3)
  total = total + c
  for _a, a in pairs(command.second) do
    for _b, b in pairs(command.second) do
      if _b ~= _a then
        for _c, c in pairs(command.second) do
          if _c ~= _b and _c ~= _a then
            info(analog_io.concat(a).."\t"..analog_io.concat(b).."\t"..analog_io.concat(c))
            table.insert(triples, {a, b, c})
            -- local results = appa.solve(a, b, c)
            -- if #results > 0 then
            --   table.insert(combines, results[#results].solution)
            -- end
          end
        end
      end
    end
  end
end

-- io.stderr:write(total.."\n")
