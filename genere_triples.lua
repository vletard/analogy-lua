#!/usr/bin/env lua

utils        = dofile "/people/letard/local/lib/lua/toolbox.lua"
knowledge    = dofile "knowledge.lua"
appa         = dofile "appa.lua"
segmentation = dofile "segmentation.lua"

segmentation.set_input_mode ("characters")
segmentation.set_output_mode("words")

if #arg < 2 then
  io.stderr:write("Usage: "..arg[0].." KEY_FILE VALUE_FILE")
  os.exit()
end
key_file   = arg[1]
value_file = arg[2]

--------------------------------------------------------------------------------

function info(arg)
  write(arg)
end
appa  .set_debug(false)

local function load_files(keys, values)
  local key_file   = io.open(keys)
  local value_file = io.open(values)

  if not key_file then
    error "Cannot open key file."
  elseif not value_file then
    error "Cannot open value file."
  end
  
  local function read(file, IO)
    return function ()
      local input = file:read()
      return input and segmentation["chunk_"..IO](input)
    end
  end

  io.stderr:write("Loading examples and building index...\n")
  assert(0 == knowledge.load(read(key_file, "input"), read(value_file, "output")))
  io.stderr:write("...done (lexicon size = "..#knowledge.lexicon..")\n")
end


load_files(key_file, value_file)

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
            info(segmentation.concat(a).."\t"..segmentation.concat(b).."\t"..segmentation.concat(c))
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
