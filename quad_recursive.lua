#!/usr/bin/env lua

utils = dofile "/people/letard/local/lib/lua/toolbox.lua"
appa         = dofile "appa.lua"
segmentation = dofile "segmentation.lua"

local chunk_mode = "words"
local recursion_bound = tonumber(arg[3]) or math.huge
local exhaustive = (arg[4] == "exhaustive")

local time_unit = 1000000000

if #arg < 2 then
  io.stderr:write("Usage: "..arg[0].." SOURCE TARGET\n\n")
  os.exit(1)
end

local base = {}
local histo = {}

local function load(keys, values)
  local k, v = keys(), values()
  local histoindex = {}
  while k do
    if not v then
      return 1 -- more keys than values
    end
    assert(not (#v[1] == 0 and #k[1] ~=0) and not (#v[1] ~= 0 and #k[1] == 0))
    if #k[1] ~= 0 and #v[1] ~= 0 then
      -- Updating the associations map
      local content = base[utils.tostring(k[1])] or {first = k, second = {}}
      content.second[utils.tostring(v[1])] = v
      base[utils.tostring(k[1])] = content
      histo[utils.tostring(k[1])] = utils.table.len(histo)
    end
    k, v = keys(), values()
  end
  if v then
    return -1 -- more values than keys
  else
    return 0
  end
end

local function load_files(keys, values)
  local key_file   = io.open(keys)
  local value_file = io.open(values)

  if not key_file then
    error "Cannot open source language file."
  elseif not value_file then
    error "Cannot open target language file."
  end
  
  local function read(file)
    return function ()
      local input = file:read()
      return input and segmentation.chunk(chunk_mode, input)
    end
  end

  assert(0 == load(read(key_file, "input"), read(value_file, "output")))
end

local memoization = {}
local function default_table()
  local t = {}
  -- setmetatable(t, { __newindex = function () end }) -- freeze the default table
  return t
end
local function recursive_translation(input, limit, exhaustive, history, depth)
  memoization = {}
  history = history or {}
  depth = depth or 1
  exhaustive = exhaustive or false
  new_history = utils.table.deep_copy(history)
  io.stderr:write("depth : "..depth.." ("..segmentation.concat(input)..")\n")
--  io.stderr:write(utils.table.len(new_history).."\t"..utils.table.len(base).."\n")
  limit = limit or math.huge
  local str = utils.tostring({input, limit})
  local memoized = memoization[str]
  if memoized ~= nil then
    return memoized
  else
    local results_direct = {}
    for i1, example1 in pairs(base) do
        for i2, example2 in pairs(base) do
          if i1 ~= i2 then
            if not history[i1..i2] then
              new_history[i1..i2] = true
              local results = appa.solve_tab(example2.first, example1.first, input)
              if #results > 0 then
                for _, r in ipairs(results) do
                  local match = (base[utils.tostring(r.solution.t[1])] or {}).second or {}
                  if #match == 0 and limit > 1 then
                    match = recursive_translation(r.solution.t, limit-1, exhaustive, new_history, depth + 1)
                  elseif #match > 1 then
                    io.stderr:write(string.format("\nA %3d : %s\nB %3d : %s\n", histo[i1], segmentation.concat(example1.first), histo[i2], segmentation.concat(example2.first)))
                    io.stderr:write(string.format("X : '%s'\n", segmentation.concat(r.solution.t)))
                  end
                  for _, m in pairs(match or {}) do
                    for _, target1 in pairs(example1.second) do
                      for _, target2 in pairs(example2.second) do
                        local translations = appa.solve_tab(target1, target2, m)
                        for _, t in ipairs(translations) do
                          t.solution.t.type = "indirect"
                          memoization[str] = memoization[str] or default_table()
                          table.insert(memoization[str], t.solution.t)
--                           io.stderr:write(string.format("%-60s : %-60s\n%-60s ::\n%-60s : %-60s\n", segmentation.concat(example1.first), segmentation.concat(example2.first), "", segmentation.concat(r.solution.t), segmentation.concat(input)))
--                           io.stderr:write(string.format("%-60s : %-60s\n%-60s ::\n%-60s : %-60s\n\n", segmentation.concat(target1), segmentation.concat(target2), "", segmentation.concat(m), segmentation.concat(t.solution.t)))
                          if not exhaustive then
                            return memoization[str]
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      -- Résolution directe
     if depth == 1 or exhaustive then
       for _, target1 in pairs(example1.second) do
         local direct_results = appa.solve_tab(example1.first, target1, input)
         for _, t in ipairs(direct_results) do
           t.solution.t.type = "direct"
           table.insert(results_direct, t.solution.t)
           io.stderr:write(string.format("%-60s : %-60s\n%-60s ::\n%-60s : %-60s\n\n", segmentation.concat(example1.first), segmentation.concat(target1), "", segmentation.concat(input), segmentation.concat(t.solution.t)))
         end
       end
     end
      -- Fin résolution directe
    end
    memoization[str] = memoization[str] or default_table()
    for _, d in ipairs(results_direct) do
      table.insert(memoization[str], d)
      if not exhaustive then
        break
      end
    end
    return memoization[str]
  end
end





load_files(arg[1], arg[2])

local input_count = 0
for line in io.stdin:lines() do
  local time = utils.time()
  input_count = input_count + 1
  print(string.format("input #%d -> \"%s\"", input_count, line))
  local input = segmentation.chunk(chunk_mode, line)
  local match = base[utils.tostring(input[1])]
  local translations = {}
  if match then
    for _, t in pairs(match.second) do
      t.type = "exact"
      table.insert(translations, t)
      if not exhaustive then
        break
      end
    end
  else
    translations = recursive_translation(input, recursion_bound, exhaustive)
  end
  local nb_cube   = 0
  local nb_square = 0
  local nb_single = 0
  local final = nil
  for _, t in ipairs(translations) do
    if t.type == "direct" then
      nb_square = nb_square + 1
      if not final then
        final = t
      end
    elseif t.type == "indirect" then
      nb_cube = nb_cube + 1
      if not final or final.type == "direct" then
        final = t
      end
    else
      assert(t.type == "exact")
      nb_single = nb_single + 1
      final = t
    end
  end
  print(string.format("detail cube      time = -----   results = %3d", nb_cube))
  print(string.format("detail square    time = -----   results = %3d", nb_square))
  nb_cube   = 0
  nb_square = 0
  nb_single = 0
  for _, t in ipairs(translations) do
    if t.type == "direct" then
      nb_square = nb_square + 1
      print(string.format("result square    %6d -> %s", nb_square, segmentation.concat(t)))
    elseif t.type == "indirect" then
      nb_cube = nb_cube + 1
      print(string.format("result cube      %6d -> %s", nb_cube,   segmentation.concat(t)))
    else
      nb_single = nb_single + 1
      io.stderr:write(utils.tostring(t))
      print(string.format("result single    %6d -> %s", nb_single, segmentation.concat(t)))
    end
  end
  print(string.format("detail totaltime %.3f", (utils.time() - time) / time_unit))
  print("final "..segmentation.concat(final).."\n")
end
