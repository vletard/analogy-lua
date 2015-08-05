#!/usr/bin/env lua

dofile "/people/letard/local/lib/lua/toolbox.lua"
dofile "knowledge.lua"
dofile "appa.lua"
dofile "io.lua"
dofile "search.lua"


--------------------------------------------------------------------------------
-- Paramètres


analog_io.chunk_pattern =
-- "%S+%s*"  -- words including spaces
   "%S+"     -- words
-- "."       -- characters

local interactive            = false
local use_squares            =  true
local use_cubes              = false

if #arg == 1 then
  if arg[1] == "intra"     then
    use_squares = false
    use_cubes   =  true
  elseif arg[1] == "inter" then
    use_squares =  true
    use_cubes   = false
  elseif arg[1] == "both"  then
    use_squares =  true
    use_cubes   =  true
  elseif arg[1] == "singletons" then
    use_squares = false
    use_cubes   = false
  else
    error("Argument 1 incorrect ('"..arg[1].."')")
  end
end

local   key_file = 
 "../case_base/2015_05_bash/train/01_l.in.txt" -- case_base 01
-- "../case_base/2015_05_bash/train/01.in.txt"

-- "../case_base/2015_05_bash/train/01.in.g01_l.txt" -- case_base 01 (generation_01)
-- "../case_base/2015_05_bash/train/01.in.g01_tmp_l.txt"
-- "../case_base/2015_05_bash/train/01.in.g01_tmp.txt"

-- "../case_base/2014_01_R/train/01.in.txt"

-- "../case_base/perso/in.txt"

local value_file = 
 "../case_base/2015_05_bash/train/01.out.txt" -- case_base 01

-- "../case_base/2015_05_bash/train/01.out.g01.txt" -- case_base 01 (generation_01)
-- "../case_base/2015_05_bash/train/01.out.g01_tmp_fixed.txt"
-- "../case_base/2015_05_bash/train/01.out.g01_tmp.txt"

-- "../case_base/2014_01_R/train/01.out.txt"

-- "../case_base/perso/out.txt"

--------------------------------------------------------------------------------

function info(arg)
  write(arg)
end


analog_io.load(key_file, value_file)

--------------------------------------------------------------------------------
-- Lecture des requêtes en entrée

if interactive then
  io.stderr:write "requête : "
end
local request_txt = io.read()
while request_txt do
  request = analog_io.chunk(request_txt)

  local square = { time = 0, nb = 0 }
  local cube   = { time = 0, nb = 0 }
  local time = os.time()
  local solutions = {}
  local existing = knowledge.pairs[utils.tostring(request)]
  if existing then
    local results = {}
    for _, com in pairs(existing.second) do
      table.insert(results, analog_io.concat(com))
    end
    table.insert(solutions, {results = results, singleton = { x = request_txt }})
  else
    local loc_time
    if use_squares then
      loc_time = os.time()
      for _, s in ipairs(search.build_squares(request, request_txt)) do
        table.insert(solutions, s)
        square.nb = square.nb + 1
      end
      square.time = os.time() - loc_time
    end
    if use_cubes then
      loc_time = os.time()
      for _, s in ipairs(search.build_cubes(request, request_txt)) do
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
  if #solutions > 0 then
    if solutions[1].singleton then
      assert(#solutions == 1)
      table.insert(list, solutions[1].results[1])
      print(string.format("result single%3d \"%s\" -> %s", #list, request_txt, solutions[1].results[1]))
    else
      for _, s in ipairs(solutions) do
        local nb = 0
        for _, r in ipairs(s.results) do
          nb = nb + 1
          if s.square then
            table.insert(list, r.t.solution)
            print(string.format("result square%3d \"%s\" -> %s", #list, request_txt, r.t.solution))
            print(string.format("detail more      time = %3d   results = %3d          ", square.time, square.nb))
          else
            table.insert(list, r.t.solution)
            print(string.format("result cube  %3d \"%s\" -> %s", #list, request_txt, r.t.solution))
            print(string.format("detail triple O  x = \"%s\"   y = \"%s\"   z = \"%s\"", r.x, r.y, r.z))
            print(string.format("detail more      time = %3d   results = %3d          ", cube.time, cube.nb))
          end
        end
        if nb == 0 and not s.square then
          print(string.format("result noanalogy \"%s\"", request_txt))
          print(string.format("detail triple O  x = \"%s\"   y = \"%s\"   z = \"%s\"",
            concat(s.triple.X.commands[next(s.triple.X.commands)]), 
            concat(s.triple.Y.commands[next(s.triple.Y.commands)]), 
            concat(s.triple.Z.commands[next(s.triple.Z.commands)]) 
          ))
          print(string.format("detail commands  x = %2d   y = %2d   z = %2d",
            utils.table.len(s.triple.X.commands),
            utils.table.len(s.triple.Y.commands),
            utils.table.len(s.triple.Z.commands)
          ))
        end
        print(string.format("detail triple I  x = \"%s\"   y = \"%s\"   z = \"%s\"", s.triple.x, s.triple.y, s.triple.z))
      end
    end
  else
    print(string.format("result not found \"%s\"", request_txt))
  end
  print(string.format("detail totaltime %3d", os.time() - time))
  print(string.format("final %s", #list > 0 and list[math.random(#list)] or ""))  -- TODO better choice !!!!
  print ""

--   info(os.time())
--   local search_space = {} -- utils.table.set_deep_index {}
--   local max_len = 0
--   for _, w in ipairs(request) do
--     for _, k in ipairs(knowledge.vocabulary[w] or {}) do
--       local sub_ss = search_space[#w] or --[[ utils.table.set_deep_index ]] {}
--       sub_ss[k] = true
--       search_space[#w] = sub_ss
--       if #w > max_len then
--         max_len = #w
--       end
--     end
--   end
--   info(os.time())
-- 
--   info("Répartition : ")
--   local tmp = search_space
--   search_space = {}
--   for i=1,max_len do
--     local n = max_len + 1 - i
--     local list = tmp[n]
--     if list then
--       info(n.." -> "..utils.table.len(list))
--       for k, _ in pairs(list) do
--         table.insert(search_space, k)
--       end
--     end
--   end
--   info("Proportion de la base utilisée : "..utils.table.len(search_space).."/"..utils.table.len(knowledge.pairs))
--   info(os.time())
-- 
--   local analogy1 = utils.table.set_deep_index({})
--   for sum=1,2*#search_space do
--     for term=1,sum-1 do
--       local k1 = search_space[term]
--       local k2 = search_space[sum-term]
--       if not utils.deepcompare(k1, k2) then
--         local solutions = appa.solve(request, k1,    k2   )
--         if #solutions > 0 then
--           analogy1[{request, k1,    k2   , solutions[#solutions].solution}] = 1
--         end
--         local solutions = appa.solve(k1,    request, k2   )
--         if #solutions > 0 then
--           analogy1[{k1,    request, k2   , solutions[#solutions].solution}] = 2
--         end
--         local solutions = appa.solve(k1,    k2,    request)
--         if #solutions > 0 then
--           analogy1[{k1,    k2,    request, solutions[#solutions].solution}] = 3
--         end
--       end
--     end
--   end
-- 
--   if table.len(analogy1) == 0 then
--     io.stderr:write("Aucun triplet analogique trouvé.".."\n")
--     os.exit()
--   end
--   
--   io.stderr:write(utils.tostring{analogy1 = analogy1}.."\n")
--   
--   analogy2 = {}
--   tested = {}
--   for k, v in pairs(analogy1) do
--     local example = knowledge.pairs[k[4]]
--     if example then
--       local v1, v2, v3, v4 = knowledge.get(k[1]), knowledge.get(k[2]), knowledge.get(k[3]), knowledge.get(k[4])
--       local solutions
--       if v == 1 then
--         solutions = appa.solve(v4, v2, v3)
--       elseif v == 2 then
--         solutions = appa.solve(v3, v1, v4)
--       elseif v == 3 then
--         solutions = appa.solve(v2, v1, v4)
--       end
--       if #solutions > 0 then
--         local s = {v1, v2, v3, v4}
--         s[v] = solutions[#solutions].solution
--   --      table.insert(analogy3, {k, s})
--         table.insert(analogy2, s[v])
--       else
--         io.stderr:write("Pas de solution pour :\n "..v1.." : "..v2.." :: "..v3.." : ?".."\n")
--       end
--     elseif not tested[k[4]] then
--       io.stderr:write("Pas d'image pour \""..k[4].."\"".."\n")
--       tested[k[v]] = true
--     end
--   end

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
  request_txt = io.read()
end
if interactive then
  io.stderr:write ""
end
--------------------------------------------------------------------------------
