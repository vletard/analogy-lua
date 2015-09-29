#!/usr/bin/env lua

dofile "/people/letard/local/lib/lua/toolbox.lua"
knowledge    = dofile "knowledge.lua"
appa         = dofile "appa.lua"
search       = dofile "search.lua"
segmentation = dofile "segmentation.lua"


--------------------------------------------------------------------------------
-- Parameters

segmentation.set_mode("words_dynamic")
local interactive            = false


-- End parameters
--------------------------------------------------------------------------------

local key_file, value_file


if #arg < 3 then
  io.stderr:write("Usage: "..arg[0].." KEY_FILE VALUE_FILE ANALOGICAL_MODE [dynamic]")
  io.stderr:write("\nANALOGICAL_MODE is one of intra, inter, both, singletons")
  os.exit()
end
key_file   = arg[1]
value_file = arg[2]
if arg[3] == "intra"     then
  use_squares = false
  use_cubes   =  true
elseif arg[3] == "inter" then
  use_squares =  true
  use_cubes   = false
elseif arg[3] == "both"  then
  use_squares =  true
  use_cubes   =  true
elseif arg[3] == "singletons" then
  use_squares = false
  use_cubes   = false
else
  io.stderr:write("Third argument is incorrect ('"..arg[1].."')\n")
  os.exit()
end
if #arg >= 4 then
  if arg[4] == "dynamic" then
    segmentation.dynamic = true
  else
    io.stderr:write("Fourth argument is incorrect ('"..arg[1].."'): must be 'dynamic' or nothing.\n")
    os.exit()
  end
end

-- local   key_file = 
--  "../case_base/2015_05_bash/train/01_l.in.txt" -- case_base 01
-- -- "../case_base/2015_05_bash/train/01.in.txt"
-- 
-- -- "../case_base/2015_05_bash/train/01.in.g01_l.txt" -- case_base 01 (generation_01)
-- -- "../case_base/2015_05_bash/train/01.in.g01_tmp_l.txt"
-- -- "../case_base/2015_05_bash/train/01.in.g01_tmp.txt"
-- 
-- -- "../case_base/2014_01_R/train/01.in.txt"
-- 
-- -- "../case_base/perso/in.txt"
-- 
-- local value_file = 
--  "../case_base/2015_05_bash/train/01.out.txt" -- case_base 01
-- 
-- -- "../case_base/2015_05_bash/train/01.out.g01.txt" -- case_base 01 (generation_01)
-- -- "../case_base/2015_05_bash/train/01.out.g01_tmp_fixed.txt"
-- -- "../case_base/2015_05_bash/train/01.out.g01_tmp.txt"
-- 
-- -- "../case_base/2014_01_R/train/01.out.txt"
-- 
-- -- "../case_base/perso/out.txt"

--------------------------------------------------------------------------------
-- Log and debug

local function info(arg)
  write(arg)
end
appa  .set_debug(false)
search.set_debug(false)

search.set_log  ( true)

--------------------------------------------------------------------------------

local function load_files(keys, values)
  local key_file   = io.open(keys)
  local value_file = io.open(values)

  if not key_file then
    error "Cannot open key file."
  elseif not value_file then
    error "Cannot open value file."
  end
  
  local function read(file, NLFL)
    return function ()
      local input = file:read()
      return input and segmentation["chunk_"..NLFL](input)
    end
  end

  io.stderr:write("Loading examples and building index...\n")
  assert(0 == knowledge.load(read(key_file, "NL"), read(value_file, "FL")))
  io.stderr:write("...done (lexicon size = "..#knowledge.lexicon..")\n")
end


load_files(key_file, value_file)

--------------------------------------------------------------------------------
-- Reading requests from stdin (1 request = 1 line)
local num_input = 0

if interactive then
  io.stderr:write "requête : "
end
for request_txt in io.lines() do
  num_input = num_input + 1
  request = segmentation.chunk_NL(request_txt)

  local square = { time = 0, nb = 0 }
  local cube   = { time = 0, nb = 0, unknown = {} }
  local time = os.time()
  local solutions = {}
  local existing = knowledge.pairs[utils.tostring(request[1])]
  if existing then
    local results = {}
    for _, com in pairs(existing.second) do
      table.insert(results, segmentation.concat(com))
    end
    table.insert(solutions, {results = results, singleton = { x = request_txt }})
  else
    local loc_time
    if use_squares then
      loc_time = os.time()
      local squares = search.build_squares(request, request_txt)
      for _, s in ipairs(squares) do
        table.insert(solutions, s)
        square.nb = square.nb + 1
      end
      square.time = os.time() - loc_time
    end
    if use_cubes then
      loc_time = os.time()
      local cubes
      cubes, cube.unknown = search.build_cubes(request, request_txt)
      for _, s in ipairs(cubes) do
        table.insert(solutions, s)
        cube.nb = cube.nb + 1
      end
      cube.time = os.time() - loc_time
    end
  end

  local list = {}
  ------------------------------------------------------------------------
  -- Logging
  ------------------------------------------------------------------------
  if use_cubes then
  local unknown = ""
    for _, symbol in ipairs(cube.unknown) do
      if unknown ~= "" then
        unknown = unknown..", "
      end
      unknown = unknown..symbol
      print(string.format("unknown symbol   - %s", symbol))
    end
--    print(string.format("unknown symbols  - %s", unknown))
  end
  if not interactive then
    print("input #"..num_input.." -> \""..request_txt.."\"")
  end
  if #solutions > 0 then
    if solutions[1].singleton then
      assert(#solutions == 1)
      table.insert(list, solutions[1].results[1])
      print(string.format("result single%3d \"%s\" -> %s", #list, request_txt, solutions[1].results[1]))
    else
      print(string.format("detail square    time = %3d   results = %3d          ", square.time, square.nb))
      print(string.format("detail cube      time = %3d   results = %3d          ", cube.time, cube.nb))
      for _, s in ipairs(solutions) do
        local nb = 0
        print ""
        for _, r in ipairs(s.results) do
          nb = nb + 1
          if s.square then
            table.insert(list, r.final)
            print(string.format("result square%3d -> %s", #list, r.final))
            print(string.format("detail triple    x = \"%s\"\ty = \"%s\"\tz = \"%s\"", r.x, r.y, r.z))
          else
            table.insert(list, r.t.solution)
            print(string.format("result cube  %3d -> %s", #list, r.t.solution))
            print(string.format("detail triple O  x = \"%s\"\ty = \"%s\"\tz = \"%s\"", r.x, r.y, r.z))
          end
        end
        if not s.square then
--          print(string.format("result cube1     \"%s\"", request_txt))
          print(string.format("detail triple I  x = \"%s\"\ty = \"%s\"\tz = \"%s\"",
            s.triple.x,
            s.triple.y,
            s.triple.z
--            segmentation.concat(s.triple.X.commands[next(s.triple.X.commands)]), 
--            segmentation.concat(s.triple.Y.commands[next(s.triple.Y.commands)]), 
--            segmentation.concat(s.triple.Z.commands[next(s.triple.Z.commands)]) 
          ))
          print(string.format("detail commands  x = %2d\ty = %2d\tz = %2d",
            utils.table.len(s.triple.X.commands),
            utils.table.len(s.triple.Y.commands),
            utils.table.len(s.triple.Z.commands)
          ))
        end
--        print(string.format("detail triple I  x = \"%s\"   y = \"%s\"   z = \"%s\"", s.triple.x, s.triple.y, s.triple.z))
      end
    end
  else
    if use_cubes then
      print(string.format("result not found (%d US) \"%s\"", #cube.unknown, request_txt))
    else
      print(string.format("result not found \"%s\"", request_txt))
    end
  end
  print(string.format("detail totaltime %3d", os.time() - time))
  print(string.format("final %s", #list > 0 and list[math.random(#list)] or ""))  -- TODO better choice !!!!
  print ""

  if interactive then
    if #list > 0 then
      io.stderr:write "execute with bash (type number or 0) : "
      local execution = tonumber(io.read())
      if execution and execution > 0 and execution <= #list then
        os.execute(list[execution])
      end
    end
    io.stderr:write "requête : "
  end
end
if interactive then
  io.stderr:write ""
end
--------------------------------------------------------------------------------
