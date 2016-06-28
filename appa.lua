local appa = {
}

local params = {
  step_sampling =   500,               -- Valeur d'échantillonage pour chaque mélange
  max_iter      =  1000,               -- Nombre maximal d'itérations pour la recherche  
  min_iter      =     5,               -- Nombre minimal d'itérations pour la recherche (échantillonnage)
  min_occur     =   100,               -- Nombre minimal d'occurrences pour arrêter la recherche
  min_coef      =   100,               -- Ratio minimal entre les deux meilleures occurrences : 1 + min_coef / meilleure_occurrence
  timeout       =     1,
  debug         = false,
  max_segments  = 5,
  max_concurrent_paths = 1
}

math.randomseed(os.time())
 
function reverse_list(l)
  local reversed = {}
  for i=#l,0,-1 do
    table.insert(reversed, l[i])
  end
  return reversed
end

local function shuffleTable( t )
  local rand = math.random 
  assert( type(t) == "table")
  local iterations = #t
  local j
       
  for i = iterations, 2, -1 do
    j = rand(i)
    t[i], t[j] = t[j], t[i]
  end
end

local stack = ""
local write = function(arg)
  local str = utils.tostring(arg)
  if str:sub(-1) == "\n" then
    io.stderr:write(stack..str)
    stack = ""
  else
    stack = stack..str
  end
end

local __write = write
function appa.set_debug(bool)
  params.debug = bool
  if not params.debug then
    write = function() end
  else
    write = __write
  end
end
appa.set_debug(params.debug)

local function stats(item)
  assert(type(item) == "table")
  local stats = {}
  for _, v in ipairs(item) do
    stats[v] = (stats[v] or 0) + 1
  end
  return stats
end

local function sort(solutions)
  local tmp, indexes = {}, {}
  for _, s_n in pairs(solutions) do
    local s, n = s_n.first, s_n.second
    local tmp2 = tmp[n]
    if not tmp2 then
      tmp2 = {s}
      table.insert(indexes, n)
    else
      table.insert(tmp2, s)
    end
    tmp[n] = tmp2
  end
  table.sort(indexes) --, function (a, b) return a > b end)
  solutions = {}
  for _, i in ipairs(indexes) do
    for _, item in ipairs(tmp[i]) do
      table.insert(solutions, { solution = item, occurrences = i })
    end
  end
  return solutions
end

local function shuffle_rand(y, z)
  local shuffle = {}
  local i, j = 1, 1
  while y[i] or z[j] do
    if not y[i] then
      table.insert(shuffle, z[j])
      j = j + 1
    elseif not z[j] or math.random(2) == 1 then
      table.insert(shuffle, y[i])
      i = i + 1
    else
      table.insert(shuffle, z[j])
      j = j + 1
    end
  end
  return shuffle
end

local function shuffle(y, z)
  local set = {}
  for i=1,params.step_sampling do
    local s = shuffle_rand(y, z)
    local prev = set[utils.tostring(s)] or { first = s, second = 0 }
    prev.second = prev.second + 1
    set[utils.tostring(s)] = prev
  end
  return set
end

local function complement(s, x, prefix, i, j, result)
--  utils.write {
--    s      = segmentation.concat({s     , mode = "characters"}),
--    x      = segmentation.concat({x     , mode = "characters"}),
--    prefix = (not prefix or #prefix == 0) and "" or segmentation.concat({prefix, mode = "characters"}),
--    result = (not result or #result == 0) and "" or segmentation.concat({result, mode = "characters"}),
--    i = i,
--    j = j,
--  }
  prefix = prefix or {}
  i = i or 1
  j = j or 1
  result = result or {}
  local str = utils.tostring(prefix)
  
  if i > #s then
    if j > #x then
      local res = result[str] or {first = prefix, second = 0}
      res.second = res.second + 1
      result[str] = res
    end
    return result
  end
  if i <= #s then
    local pref = utils.table.deep_copy(prefix)
    table.insert(pref, s[i])
    complement(s, x, pref, i+1, j, result)
  end
  if j <= #x and s[i] == x[j] then
    complement(s, x, prefix, i+1, j+1, result)
  end
  return result
end

-- Checks whether the counts of the terminal symbols of the sequences in parameter are valid for analogy or not.
-- Note that the sequence D is optional, if absent, the triplet is checked for counts inequality.
-- 
-- The actual half-count per segment is returned in second place.
function appa.count(A, B, C, D)
  local segments = {}
  local total = {}
  for _, item in ipairs {B, C} do
    for _, w in ipairs(item[1]) do
      segments[w] = (segments[w] or 0) + 1
      total[w] = (total[w] or 0) + 1
    end
  end
  for _, item in ipairs {A, D or {{}} } do
    for _, w in ipairs(item[1]) do
      local val = (total[w] or 0) - 1
      if val < 0 then
        write(" INEQUAL = '"..w.."'\n")
        return false
      else
        total[w] = val
      end
    end
  end
  return true, segments
end

-- A, B et C sont des séquences d'éléments sous forme de tables à indices numériques
function appa.solve(A, B, C)
  write(string.format("__TT__ %19s : %19s :: %19s : ?", segmentation.concat(A, "| "), segmentation.concat(B, "| "), segmentation.concat(C, "| ")))
  local time = os.time()

  -- Si A == C alors B == D
  if utils.deepcompare(A, C) then
    local sol = {
      x = { { segmentation.concat(A) }, mode = A.mode },
      y = { { segmentation.concat(B) }, mode = B.mode },
      z = { { segmentation.concat(C) }, mode = C.mode },
    }
    assert(sol.x[1][1] == sol.z[1][1])
    sol.t = sol.y
    return { { solution = sol, occurrences = 1 } }
  elseif utils.deepcompare(A, B) then
    local sol = {
      x = { { segmentation.concat(A) }, mode = A.mode },
      y = { { segmentation.concat(B) }, mode = B.mode },
      z = { { segmentation.concat(C) }, mode = C.mode },
    }
    assert(sol.x[1][1] == sol.y[1][1])
    sol.t = sol.z
    return { { solution = sol, occurrences = 1 } }
--  elseif utils.deepcompare(B, C) then
--    return { { solution = A, occurrences = 1 } }
  end

  -- Checking symbol counts
  local test, segments = appa.count(A, B, C)
  if test then
    write " PASSED"
  else
    return {}
  end

  for _, item in ipairs {B, C} do
    for _, seg in ipairs(item) do
      for _, s in ipairs(seg) do
        segments[s] = (segments[s] or 0) + 1
      end
    end
  end

  if segmentation.dynamic_square then
    local first_seg, result_list = segmentation.enumerate_segmentations_list(A, {B, C}, nil, params.max_segments)()
    if first_seg == nil then
      return {}
    end

    A = first_seg
    B = result_list[1]
    C = result_list[2]
  end
--  utils.write({A=A, B=B, C=C})

  local solutions = {} -- index of the solutions and there occurrences
  local max = {}       -- holds the n solutions having the biggest numbers of occurrences (string representations)
  local modif = true
  local it = 0
  local start_time = os.time()

--   local memoized_complements = {}

  local counter = 1
  while (#max < 2 and it < params.min_iter)
     or (#max == 1 and solutions[max[1]].second < 100)
     or (#max >= 2
--        and (write(max[1].."/"..max[2].." \n") or true)
        and solutions[max[1]].second/solutions[max[2]].second < 1 + params.min_coef / solutions[max[1]].second -- and (write("PASSED") or write_ref {max1 = solutions[max[1]].second, max2 = solutions[max[2]].second, ratio = 1+params.min_coef / solutions[max[1]].second, m1 = max[1], m2 = max[2]} or true)
        and modif == true
        and (os.time() - start_time < params.timeout and it < params.max_iter)
        )
     do
--  write(utils.tostring({it = it, time = os.time() - start_time, timeout = params.timeout, min_it = params.min_iter, ["#max"] = #max, sol1 = #max >= 1 and solutions[max[1]].second}))
-- -- write{solutions = solutions}
--  write "\n"
    it = it + 1
--    write "shuffling\n"
    S = shuffle(B[1], C[1])
--    write("shuffle('"..segmentation.concat(B).."', '"..segmentation.concat(C).."') ("..#B..", "..#C..") -> "..utils.table.len(S).."\n")
    modif = false
    for _, sw in pairs(S) do
      local s, w = sw.first, sw.second
      local comp = complement(s, A[1]) -- memoized_complements[utils.tostring{s, A}]
--       if not comp then
--         comp = complement(s, A)
--         memoized_complements[utils.tostring{s, A}] = comp
--       end
--        write("shuffle "..counter.."\n")
--        counter = counter + 1
      for _, c_n2 in pairs(comp) do
--        write{c_n2 = c_n2, it = it, comp = utils.table.len(comp), S = utils.table.len(S)}
--        write "\n"
        local c, n2 = { c_n2.first }, c_n2.second
        
        -- The segmentation mode is inherited by analogy too
        if A.mode == C.mode then
          c.mode = B.mode
        else
          assert(A.mode == B.mode)
          c.mode = C.mode
        end

        local c_str = utils.tostring(c)
        modif = true
        local pack  = solutions[c_str] or {first = { x = A, y = B, z = C, t = c }, second = 0 }
        pack.second = pack.second + w
        solutions[c_str] = pack
        local val = pack.second
        if #max == 0 then
          table.insert(max, c_str)
        assert(max[1] ~= max[2])
        elseif #max == 1 then
          if c_str ~= max[1] then
            if val > solutions[max[1]].second then
              max[2] = max[1]
              max[1] = c_str
            else
              table.insert(max, c_str)
            end
          end
        elseif val > solutions[max[1]].second then
          if max[2] == c_str then
            max[2] = max[1]
          end
          max[1] = c_str
        elseif val > solutions[max[2]].second and c_str ~= max[1] then
          max[2] = c_str
        end
      end
    end
--    write "shuffle end\n"
    assert(not (modif and #max == 0))
  end
  write(" "..(os.time() - time).."\n")
  local sorted = sort(solutions)
  return sort(solutions)
end

function appa.check_n4(x, y, z, t)
  local X, Y, Z, T = #x, #y, #z, #t
  if X + T ~= Z + Y then
    return false
  end
  local a = {}
  a.crawl = function (a, b, c, d)
    return (((a * (Y+1) + b) * (Z+1)) + c) * (T+1) + d
  end
  for i=-1,0 do
    for j=-1,0 do
      for k=-1,0 do
        for l=-1,0 do
          a[a.crawl(i, j, k, l)] = false
        end
      end
    end
  end
  for i=0,X do
    for j=0,Y do
      for k=0,Z do
        for l=0,T do -- TODO remove the 4th loop
          if i == 0 and i == j and j == k and k == l then
            a[a.crawl(i, j, k, l)] = true
          else
            a[a.crawl(i, j, k, l)] = ((a[a.crawl(i-1, j-1, k  , l  )] and x[i] == y[j])
                                   or (a[a.crawl(i-1, j  , k-1, l  )] and x[i] == z[k])
                                   or (a[a.crawl(i  , j-1, k  , l-1)] and t[l] == y[j]) 
                                   or (a[a.crawl(i  , j  , k-1, l-1)] and t[l] == z[k])) or nil
          end
        end
      end
    end
  end
  return a[a.crawl(X, Y, Z, T)] or false
end

function appa.check(x, y, z, t)
  local n3 = appa.check_n3(x, y, z, t)
  assert(n3 == appa.check_n4(x, y, z, t))
  return n3
end

function appa.check_n3(x, y, z, t)
  local X, Y, Z, T = #x, #y, #z, #t
  if X + T ~= Z + Y then
    return false
  end
  local a = {}
  a.crawl = function (a, b, c)
    return (a * (Y+1) + b) * (Z+1) + c
  end
  for i=0,X do
    for j=0,Y do
      for k=0,Z do
        if i == 0 and j == 0 and k == 0 then
          a[a.crawl(i, j, k)] = 0
        else
          local l = nil
          if x[i] == y[j] then
            local ll = a[a.crawl(i-1, j-1, k  )]
            assert(ll == (l or ll))
            l = ll
          end
          if x[i] == z[k] then
            local ll = a[a.crawl(i-1, j  , k-1)]
            assert(ll == (l or ll))
            l = ll
          end
          do
            local ll = a[a.crawl(i  , j-1, k  )]
            if ll and ll < T and t[ll+1] == y[j] then
              assert(ll+1 == (l or (ll+1)))
              l = ll+1
            end
          end
          do
            local ll = a[a.crawl(i  , j  , k-1)]
            if ll and ll < T and t[ll+1] == z[k] then
              assert(ll+1 == (l or (ll+1)))
              l = ll+1
            end
          end
          a[a.crawl(i, j, k)] = l
        end
      end
    end
  end
  return a[a.crawl(X, Y, Z)] == T
end


function appa.solve_tab(A, B, C)
  local mode = A.mode

  -- TODO solve in character mode then check for the presence of all segments of the word segmented sequences
  -- and delegate this code to segmentation.lua (or segmentation.c)
  if A.mode == "words" or B.mode == "words" or C.mode == "words" then
    mode = "words"
    if A.mode ~= "words" then
      A = segmentation.chunk("words", segmentation.concat(A))
    elseif B.mode ~= "words" then
      B = segmentation.chunk("words", segmentation.concat(B))
    elseif C.mode ~= "words" then
      C = segmentation.chunk("words", segmentation.concat(C))
    end
  end

  assert(A.mode == B.mode and A.mode == C.mode)

  -- Si A == C alors B == D
  if utils.deepcompare(A, C) then
    return {
      {
        solution = {
          x = A,
          y = B,
          z = C,
          t = utils.table.deep_copy(B)
        },
        factors = { A[1], B[1] }
      }
    }
  elseif utils.deepcompare(A, B) then
    return {
      {
        solution = {
          x = A,
          y = B,
          z = C,
          t = utils.table.deep_copy(C)
        },
        factors = { A[1], C[1] }
      }
    }
  end

  -- Checking symbol counts
  local test, segments = appa.count(A, B, C)
  if not test then
    return {}
  end

  x = A[1]
  y = B[1]
  z = C[1]
  local X, Y, Z = #x, #y, #z
  local a = {}
  a.crawl = function (a, b, c)
    return ((a * (Y+1) + b) * (Z+1)) + c
  end
  local default_empty = { ij = math.huge, ik = math.huge, j = math.huge, k = math.huge }
  for i=0,X do
    for j=0,Y do
      for k=0,Z do
        if Y - j + Z - k >= X - i and j + k >= i then
          if i == 0 and i == j and j == k then
            a[a.crawl(i, j, k)] = { ij = 1, ik = 1, j = 1, k = 1 }
          else
            assert(a[a.crawl(i, j, k)] == nil)
            local S = {}
            if i > 0 and j > 0 and x[i] == y[j] then
              local prev = a[a.crawl(i-1, j-1, k  )] or default_empty
              local min = math.huge
              local path = {}
              for _, p in ipairs { "ij", "k" } do
                if prev[p] <= min then
                  if prev[p] < min then
                    path = {}
                  end
                  min = prev[p]
                  table.insert(path, p)
                end
              end
              for _, p in ipairs { "ik", "j" } do
                if prev[p] + 1 <= min then
                  if prev[p] < min then
                    path = {}
                  end
                  min = prev[p] + 1
                  table.insert(path, p)
                end
              end
              S.ij      = min
              S.ij_path = path
            else
              S.ij = math.huge
            end
            if i > 0 and k > 0 and x[i] == z[k] then
              local prev = a[a.crawl(i-1, j  , k-1)] or default_empty
              local min = math.huge
              local path = {}
              for _, p in ipairs { "ik", "j" } do
                if prev[p] <= min then
                  if prev[p] < min then
                    path = {}
                  end
                  min = prev[p]
                  table.insert(path, p)
                end
              end
              for _, p in ipairs { "ij", "k" } do
                if prev[p] + 1 <= min then
                  if prev[p] < min then
                    path = {}
                  end
                  min = prev[p] + 1
                  table.insert(path, p)
                end
              end
              S.ik      = min
              S.ik_path = path
            else
              S.ik = math.huge
            end
            if j > 0 then
              local prev = a[a.crawl(i  , j-1, k  )] or default_empty
              local min = math.huge
              local path = {}
              for _, p in ipairs { "ik", "j" } do
                if prev[p] <= min then
                  if prev[p] < min then
                    path = {}
                  end
                  min = prev[p]
                  table.insert(path, p)
                end
              end
              for _, p in ipairs { "ij", "k" } do
                if prev[p] + 1 <= min then
                  if prev[p] < min then
                    path = {}
                  end
                  min = prev[p] + 1
                  table.insert(path, p)
                end
              end
              S.j      = min
              S.j_path = path
            else
              S.j = math.huge
            end
            if k > 0 then
              local prev = a[a.crawl(i  , j  , k-1)] or default_empty
              local min = math.huge
              local path = {}
              for _, p in ipairs { "ij", "k" } do
                if prev[p] <= min then
                  if prev[p] < min then
                    path = {}
                  end
                  min = prev[p]
                  table.insert(path, p)
                end
              end
              for _, p in ipairs { "ik", "j" } do
                if prev[p] + 1 <= min then
                  if prev[p] < min then
                    path = {}
                  end
                  min = prev[p] + 1
                  table.insert(path, p)
                end
              end
              S.k      = min
              S.k_path = path
            else
              S.k = math.huge
            end
            a[a.crawl(i, j, k)] = S
          end
        end
      end
    end
  end
  local solution = {}
  local factors = { {{ mode = A.mode }, { mode = A.mode}} }
  do
    local i, j, k = X, Y, Z
    local path
    while i > 0 or j > 0 or k > 0 do
      local cell = a[a.crawl(i, j, k)]
      local min = "ij"
      if i == X and j == Y and k == Z then
        if cell.ik < cell[min] then
          min = "ik"
        end
        if cell.j  < cell[min] then
          min = "j"
        end
        if cell.k  < cell[min] then
          min = "k"
        end
        if cell[min] == math.huge then
          return {}
        end
      else
        min = path
      end
      path = cell[min.."_path"][1]
      if min == "j" then
        solution[j+k-i] = y[j]
        table.insert(factors[#factors][2], y[j])
        if path == "k" or path == "ij" then
          factors[#factors][1] = { reverse_list(factors[#factors][1]), mode = A.mode }
          factors[#factors][2] = { reverse_list(factors[#factors][2]), mode = A.mode }
          table.insert(factors, {{ mode = A.mode }, { mode = A.mode}})
        end
        j = j-1
      elseif min == "k" then
        solution[j+k-i] = z[k]
        table.insert(factors[#factors][2], z[k])
        if path == "j" or path == "ik" then
          factors[#factors][1] = { reverse_list(factors[#factors][1]), mode = A.mode }
          factors[#factors][2] = { reverse_list(factors[#factors][2]), mode = A.mode }
          table.insert(factors, {{ mode = A.mode }, { mode = A.mode}})
        end
        k = k-1
      elseif min == "ij" then
        table.insert(factors[#factors][1], x[i])
        if path == "j" or path == "ik" then
          factors[#factors][1] = { reverse_list(factors[#factors][1]), mode = A.mode }
          factors[#factors][2] = { reverse_list(factors[#factors][2]), mode = A.mode }
          table.insert(factors, {{ mode = A.mode }, { mode = A.mode}})
        end
        i, j = i-1, j-1
      elseif min == "ik" then
        table.insert(factors[#factors][1], x[i])
        if path == "k" or path == "ij" then
          factors[#factors][1] = { reverse_list(factors[#factors][1]), mode = A.mode }
          factors[#factors][2] = { reverse_list(factors[#factors][2]), mode = A.mode }
          table.insert(factors, {{ mode = A.mode }, { mode = A.mode}})
        end
        i, k = i-1, k-1
      end
    end
  end
  factors = reverse_list(factors)
  factors[1][1] = { reverse_list(factors[1][1]), mode = A.mode }
  factors[1][2] = { reverse_list(factors[1][2]), mode = A.mode }
  return {
    {
      solution = {
        x = A,
        y = B,
        z = C,
        t = {
          solution,
          mode = mode
        },
      },
      factors = factors
    }
  }
end

function appa.solve_tab_approx(A, B, C, deviation_max)
  deviation_max = deviation_max or 0
  local mode = A.mode

  -- TODO solve in character mode then check for the presence of all segments of the word segmented sequences
  -- and delegate this code to segmentation.lua (or segmentation.c)
  if A.mode == "words" or B.mode == "words" or C.mode == "words" then
    mode = "words"
    if A.mode ~= "words" then
      A = segmentation.chunk("words", segmentation.concat(A))
    elseif B.mode ~= "words" then
      B = segmentation.chunk("words", segmentation.concat(B))
    elseif C.mode ~= "words" then
      C = segmentation.chunk("words", segmentation.concat(C))
    end
  end

  assert(A.mode == B.mode and A.mode == C.mode)

  -- Si A == C alors B == D
  if utils.deepcompare(A, C) then
    return { utils.table.deep_copy(B) }, {}
  elseif utils.deepcompare(A, B) then
    return { utils.table.deep_copy(C) }, {}
  end

--  -- Checking symbol counts
--  local test, segments = appa.count(A, B, C)
--  if not test then
--    return {}
--  end
  local compatibilities = {
    Di  = { ["true"] = { "Di", "ij", "Dij", "ik", "Dik", "j", "Dj", "k", "Dk" }, ["false"] = {} },
    ij  = { ["true"] = { "Di", "ij", "Dik", "Dj", "k", "Dk" }, ["false"] = { "Dij", "ik", "j" } },
    Dij = { ["true"] = { "Di", "Dij", "ik", "j", "k", "Dk" }, ["false"] = { "ij", "Dik", "Dj" } },
    ik  = { ["true"] = { "Di", "ik", "Dij", "Dk", "j", "Dj" }, ["false"] = { "Dik", "ij", "k" } },
    Dik = { ["true"] = { "Di", "Dik", "ij", "k", "j", "Dj" }, ["false"] = { "ik", "Dij", "Dk" } },
    j   = { ["true"] = { "Di", "Dij", "ik", "Dik", "j", "Dk" }, ["false"] = { "ij", "Dj", "k" } },
    Dj  = { ["true"] = { "Di", "ij", "Dij", "ik", "Dik", "Dj", "k", "Dk" }, ["false"] = { "j" } },
    k   = { ["true"] = { "Di", "Dik", "ij", "Dij", "k", "Dj" }, ["false"] = { "ik", "Dk", "j" } },
    Dk  = { ["true"] = { "Di", "ik", "Dik", "ij", "Dij", "Dk", "j", "Dj" }, ["false"] = { "k" } },
--  D   = 
--  ijk  ?
--  Dijk ?
  }

  x = A[1]
  y = B[1]
  z = C[1]
  local X, Y, Z = #x, #y, #z
  local a = {}
  a.crawl = function (a, b, c)
    return ((a * (Y+1) + b) * (Z+1)) + c
  end
  local default_empty = {}
  for dev = 0, deviation_max do
    for p, _ in pairs(compatibilities) do
      local default = {}
      default[p] = math.huge
    end
    default_empty[dev] = default
  end
  local loop=false
  for i=0,X do
    for j=0,Y do
      for k=0,Z do
        if deviation_max > 0 or (Y - j + Z - k >= X - i and j + k >= i) then
          if i == 0 and i == j and j == k then
            a[a.crawl(i, j, k)] = { [0] = { ij = 1, ik = 1, j = 1, k = 1 } }
          else
            loop=true
            assert(a[a.crawl(i, j, k)] == nil)
            local S = {}
            for dev = 0, deviation_max do
              if dev == 0 then
                S[dev] = {}
              end
              if dev < deviation_max then
                S[dev+1] = {}
              end
              if i > 0 then
                if j > 0 then
                  local prev = (a[a.crawl(i-1, j-1, k  )] or default_empty)[dev] or {}
                  if x[i] == y[j] then
                    local min = math.huge
                    local path = {}
                    for _, p in ipairs(compatibilities.ij["true"]) do
                      if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                        if prev[p] < min then
                          path = {}
                        end
                        min = prev[p]
                        table.insert(path, p)
                      end
                    end
                    for _, p in ipairs(compatibilities.ij["false"]) do
                      if prev[p] and prev[p] ~= math.huge and (prev[p] + 1 <= min) then
                        if prev[p] < min then
                          path = {}
                        end
                        min = prev[p] + 1
                        table.insert(path, p)
                      end
                    end
                    S[dev].ij      = min
                    S[dev].ij_path = path
                  elseif dev < deviation_max then  -- substitution of x[i] by y[j]
                    local min = math.huge
                    local path = {}
                    for _, p in ipairs(compatibilities.Dij["true"]) do
                      if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                        if prev[p] < min then
                          path = {}
                        end
                        min = prev[p]
                        table.insert(path, p)
                      end
                    end
                    for _, p in ipairs(compatibilities.Dij["false"]) do
                      if prev[p] and prev[p] ~= math.huge and (prev[p] + 1 <= min) then
                        if prev[p] < min then
                          path = {}
                        end
                        min = prev[p] + 1
                        table.insert(path, p)
                      end
                    end
                    S[dev+1].Dij      = min
                    S[dev+1].Dij_path = path
                  end
                else
                  S[dev].ij = math.huge
                  if dev < deviation_max then
                    S[dev+1].Dij = math.huge
                  end
                end
                if k > 0 then
                  local prev = (a[a.crawl(i-1, j  , k-1)] or default_empty)[dev] or {}
                  local min = math.huge
                  local path = {}
                  if x[i] == z[k] then
                    for _, p in ipairs(compatibilities.ik["true"]) do
                      if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                        if prev[p] < min then
                          path = {}
                        end
                        min = prev[p]
                        table.insert(path, p)
                      end
                    end
                    for _, p in ipairs(compatibilities.ik["false"]) do
                      if prev[p] and prev[p] ~= math.huge and (prev[p] + 1 <= min) then
                        if prev[p] < min then
                          path = {}
                        end
                        min = prev[p] + 1
                        table.insert(path, p)
                      end
                    end
                    S[dev].ik      = min
                    S[dev].ik_path = path
                  elseif dev < deviation_max then  -- substitution of x[i] by z[k]
                    local min = math.huge
                    local path = {}
                    for _, p in ipairs(compatibilities.Dik["true"]) do
                      if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                        if prev[p] < min then
                          path = {}
                        end
                        min = prev[p]
                        table.insert(path, p)
                      end
                    end
                    for _, p in ipairs(compatibilities.Dik["false"]) do
                      if prev[p] and prev[p] ~= math.huge and (prev[p] + 1 <= min) then
                        if prev[p] < min then
                          path = {}
                        end
                        min = prev[p] + 1
                        table.insert(path, p)
                      end
                    end
                    S[dev+1].Dik      = min
                    S[dev+1].Dik_path = path
                  end
                else
                  S[dev].ik = math.huge
                  if dev < deviation_max then
                    S[dev+1].Dik = math.huge
                  end
                end
                if dev < deviation_max then  -- deletion of x[i]
                  local prev = (a[a.crawl(i-1, j, k)] or default_empty)[dev] or {}
                  local min = math.huge
                  local path = {}
                  for _, p in ipairs(compatibilities.Di["true"]) do
                    if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                      if prev[p] < min then
                        path = {}
                      end
                      min = prev[p]
                      table.insert(path, p)
                    end
                  end
                  for _, p in ipairs(compatibilities.Di["false"]) do
                    if prev[p] and prev[p] ~= math.huge and (prev[p] + 1 <= min) then
                      if prev[p] < min then
                        path = {}
                      end
                      min = prev[p] + 1
                      table.insert(path, p)
                    end
                  end
                  S[dev+1].Di      = min
                  S[dev+1].Di_path = path
                end
              elseif dev < deviation_max then
                S[dev+1].Di = math.huge
              end
              if j > 0 then
                local prev = (a[a.crawl(i  , j-1, k  )] or default_empty)[dev] or {}
                local min = math.huge
                local path = {}
                  for _, p in ipairs(compatibilities.j["true"]) do
                  if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                    if prev[p] < min then
                      path = {}
                    end
                    min = prev[p]
                    table.insert(path, p)
                  end
                end
                  for _, p in ipairs(compatibilities.j["false"]) do
                  if prev[p] and prev[p] ~= math.huge and (prev[p] + 1 <= min) then
                    if prev[p] < min then
                      path = {}
                    end
                    min = prev[p] + 1
                    table.insert(path, p)
                  end
                end
                S[dev].j      = min
                S[dev].j_path = path
                if dev < deviation_max then  -- deletion of y[j]
                  local min = math.huge
                  local path = {}
                  for _, p in ipairs(compatibilities.Dj["true"]) do
                    if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                      if prev[p] < min then
                        path = {}
                      end
                      min = prev[p]
                      table.insert(path, p)
                    end
                  end
                  for _, p in ipairs(compatibilities.Dj["false"]) do
                    if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                      if prev[p] < min then
                        path = {}
                      end
                      min = prev[p] + 1
                      table.insert(path, p)
                    end
                  end
                  S[dev+1].Dj      = min
                  S[dev+1].Dj_path = path
                end
              else
                S.j = math.huge
                if dev < deviation_max then
                  S[dev+1].Dj = math.huge
                end
              end
              if k > 0 then
                local prev = (a[a.crawl(i  , j  , k-1)] or default_empty)[dev] or {}
                local min = math.huge
                local path = {}
                for _, p in ipairs(compatibilities.k["true"]) do
                  if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                    if prev[p] < min then
                      path = {}
                    end
                    min = prev[p]
                    table.insert(path, p)
                  end
                end
                for _, p in ipairs(compatibilities.k["false"]) do
                  if prev[p] and prev[p] ~= math.huge and (prev[p] + 1 <= min) then
                    if prev[p] < min then
                      path = {}
                    end
                    min = prev[p] + 1
                    table.insert(path, p)
                  end
                end
                S[dev].k      = min
                S[dev].k_path = path
                if dev < deviation_max then  -- deletion of z[k]
                  local min = math.huge
                  local path = {}
                  for _, p in ipairs(compatibilities.Dk["true"]) do
                    if prev[p] and prev[p] ~= math.huge and (prev[p] <= min) then
                      if prev[p] < min then
                        path = {}
                      end
                      min = prev[p]
                      table.insert(path, p)
                    end
                  end
                  for _, p in ipairs(compatibilities.Dk["false"]) do
                    if prev[p] and prev[p] ~= math.huge and (prev[p] + 1 <= min) then
                      if prev[p] < min then
                        path = {}
                      end
                      min = prev[p] + 1
                      table.insert(path, p)
                    end
                  end
                  S[dev+1].Dk      = min
                  S[dev+1].Dk_path = path
                end
              else
                S.k = math.huge
                if dev < deviation_max then
                  S[dev+1].Dk = math.huge
                end
              end
            end
            a[a.crawl(i, j, k)] = S
          end
        end
      end
    end
  end
  if not loop then -- rare case: when X > Y + Z, there is no exact solution and the optimization skips the loop
    local final_cell = {}
    for i = 0, deviation_max do
      final_cell[i] = {}
    end
    a[a.crawl(X, Y, Z)] = final_cell
  end
  local exact = {}
  local approximations = {}
  for dev_track = 0, deviation_max do
    local final = {}
    local solutions = { { i = X, j = Y, k = Z, dev = dev_track, path = {} } }
--     local paths = { {} }
--     local mins = { {} }
--     local coords = { { i = X, j = Y, k = Z } }
    local factors
    while #solutions > 0 do
      local solutions_next = {}
      local max = math.min(params.max_concurrent_paths, #solutions)
      shuffleTable(solutions)
      for n = 1, max do
        local sol = solutions[n]
        local i, j, k = sol.i, sol.j, sol.k
        local cell = a[a.crawl(i, j, k)][sol.dev]
        local min = {}
        if i == X and j == Y and k == Z then
          local m = math.huge
          for _, p in ipairs { "ij", "ik", "j", "k", "Di", "Dj", "Dk", "Dij", "Dik" } do
            if (cell[p] or math.huge) <= m then
              if (cell[p] or math.huge) < m then
                min = {}
                m = cell[p]
              end
              table.insert(min, p)
              m = cell[p] or math.huge
            end
          end
          factors = cell[min[1]] or math.huge
          if factors == math.huge then
            solutions_next = {}
            break
          end
        else
          min = { sol.path[#sol.path] }
        end
        for _, m in ipairs(min) do
          for _, p in ipairs(cell[m.."_path"]) do
--            utils.write { min = min, path = path }
            local s_next = {}
            for k, v in pairs(sol) do
              s_next[k] = utils.table.deep_copy(v)
            end
            table.insert(s_next.path, p)
            if m == "j" then
              s_next[j+k-i] = y[j]
              s_next.j = s_next.j-1
            elseif m == "k" then
              s_next[j+k-i] = z[k]
              s_next.k = s_next.k-1
            elseif m == "ij" then
              s_next.i = s_next.i-1
              s_next.j = s_next.j-1
            elseif m == "ik" then
              s_next.i = s_next.i-1
              s_next.k = s_next.k-1
            elseif m == "Di" then
              s_next.i = s_next.i-1
              assert(s_next.dev > 0)
              s_next.dev = s_next.dev - 1
            elseif m == "Dj" then
              s_next.j = s_next.j-1
              assert(s_next.dev > 0)
              s_next.dev = s_next.dev - 1
            elseif m == "Dk" then
              s_next.k = s_next.k-1
              assert(s_next.dev > 0)
              s_next.dev = s_next.dev - 1
            elseif m == "Dij" then
              s_next.i = s_next.i-1
              s_next.j = s_next.j-1
              assert(s_next.dev > 0)
              s_next.dev = s_next.dev - 1
            elseif m == "Dik" then
              s_next.i = s_next.i-1
              s_next.k = s_next.k-1
              assert(s_next.dev > 0)
              s_next.dev = s_next.dev - 1
            end
            assert(s_next.i >= 0 and s_next.j >= 0 and s_next.k >= 0)
            if s_next.i == 0 and s_next.j == 0 and s_next.k == 0 then
              local f = {}
              for _, e in ipairs(s_next) do
                table.insert(f, e)
              end
              local repr = utils.tostring(f)
              local current = final[repr]
              if current then
                current.n = current.n + 1
              else
                final[repr] = { f, mode = mode, n = 1 }
              end
            else
              table.insert(solutions_next, s_next)
            end
          end
        end
      end
      solutions = solutions_next
    end
    if dev_track == 0 then
      exact = final
    else
      table.insert(approximations, final)
    end
  end
  assert(type(exact) == "table" and type(approximations) == "table")
  local i_exact = {}
  for _, e in pairs(exact) do
    table.insert(i_exact, e)
  end
  local i_approx = {}
  for dev, approx in ipairs(approximations) do
    local l_approx = {}
    for _, e in pairs(approx) do
      table.insert(l_approx, e)
    end
    i_approx[dev] = l_approx
  end
  return i_exact, i_approx
end

-- appa.solve_tab = function (A, B, C) appa.solve_tab_approx(A, B, C) end


function appa.solve_tree(x, y, z)
  local function sort_f(node1, node2)
    return node1.value > node2.value
  end
  local X, Y, Z = #x, #y, #z
  local node_list = { {
    segments = 0,
    value = 0,
    i = 0,
    j = 0,
    k = 0,
  } }
  local mem = {}
  while node_list[1] and node_list[1].i + node_list[1].j + node_list[1].k < X + Y + Z do
    local node = node_list[1]
    if node.j < Y then
      local new_node = {
        segments = node.segments + 1,
        i = node.i,
        j = node.j + 1,
        k = node.k,
        output = { segment = y[node.j + 1], prev = node.output }
      }
      new_node.value = (new_node.i + new_node.j + new_node.k) / new_node.segments
      if new_node.value > 1 then
        table.insert(node_list, new_node)
      end
    end
    if node.k < Z then
      local new_node = {
        segments = node.segments + 1,
        i = node.i,
        j = node.j,
        k = node.k + 1,
        output = { segment = z[node.k + 1], prev = node.output }
      }
      new_node.value = (new_node.i + new_node.j + new_node.k) / new_node.segments
      if new_node.value > 1 then
        table.insert(node_list, new_node)
      end
    end
    if node.i < X and node.j < Y and x[node.i + 1] == y[node.j + 1] then
      local new_node = {
        segments = node.segments + 1,
        i = node.i + 1,
        j = node.j + 1,
        k = node.k,
        output = { segment = nil, prev = node.output }
      }
      new_node.value = (new_node.i + new_node.j + new_node.k) / new_node.segments
      table.insert(node_list, new_node)
      if node.k < Z then
        local new_node = {
          segments = node.segments + 1,
          i = node.i + 1,
          j = node.j + 1,
          k = node.k + 1,
          output = { segment = z[node.k + 1], prev = node.output }
        }
        new_node.value = (new_node.i + new_node.j + new_node.k) / new_node.segments
        table.insert(node_list, new_node)
      end
    end
    if node.i < X and node.k < Z and x[node.i + 1] == z[node.k + 1] then
      local new_node = {
        segments = node.segments + 1,
        i = node.i + 1,
        j = node.j,
        k = node.k + 1,
        output = { segment = nil, prev = node.output }
      }
      new_node.value = (new_node.i + new_node.j + new_node.k) / new_node.segments
      table.insert(node_list, new_node)
      if node.k < Y then
        local new_node = {
          segments = node.segments + 1,
          i = node.i + 1,
          j = node.j + 1,
          k = node.k + 1,
          output = { segment = y[node.j + 1], prev = node.output }
        }
        new_node.value = (new_node.i + new_node.j + new_node.k) / new_node.segments
        table.insert(node_list, new_node)
      end
    end
    node_list[1] = node_list[#node_list]
    node_list[#node_list] = nil
    table.sort(node_list, sort_f)
    do
      local node = node_list[1]
      if node then
        local str = ""
        local utt = node.output
        while utt do
          str = str..(utt.segment or "_")
          utt = utt.prev
        end
        str = string.reverse(str)
        -- utils.write {
        --   i = node.i, j = node.j, k = node.k,
        --   output = str,
        --   segments = node.segments,
        --   value = node.value,
        -- }
        -- print ""
        io.stderr:write("\r"..str.."                                                      ")
        -- assert(not mem[str])
        -- mem[str] = true
      end
    end
  end
  if node_list[1] then
    local inv_res, res = {}, {}
    local out = node_list[1].output
    while out do
      if out.segment then
        table.insert(inv_res, out.segment)
      end
      out = out.prev
    end
    for i, e in ipairs(inv_res) do
      res[#inv_res - i + 1] = e
    end
    return res
  else
    return {}
  end

end

return appa
