appa = {
}

local params = {
  step_sampling =   500,               -- Valeur d'échantillonage pour chaque mélange
  max_iter      =  1000,               -- Nombre maximal d'itérations pour la recherche  
  min_iter      =    50,               -- Nombre minimal d'itérations pour la recherche (échantillonnage)
  min_occur     =   100,               -- Nombre minimal d'occurrences pour arrêter la recherche
  min_coef      =   100,               -- Ratio minimal entre les deux meilleures occurrences : 1 + min_coef / meilleure_occurrence
  timeout       =     1,
  debug         = false,
}

math.randomseed(os.time())

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

if not params.debug then
  write = function() end
end

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

-- A, B et C sont des séquences d'éléments sous forme de tables à indices numériques
function appa.solve(A, B, C)
  write(string.format("__TT__ %19s : %19s :: %19s : ?", analog_io.concat(A), analog_io.concat(B), analog_io.concat(C)))
  local time = os.time()

  -- Si A == C alors B == D
  if utils.deepcompare(A, C) then
    return { { solution = B, occurrences = 1 } }
  elseif utils.deepcompare(A, B) then
    return { { solution = C, occurrences = 1 } }
  elseif utils.deepcompare(B, C) then
    return { { solution = A, occurrences = 1 } }
  end

  -- Vérification de l'inégalité sur les éléments du lexique avant de poursuivre
  do
    local total = {}
    for _, w in ipairs(B) do
      total[w] = (total[w] or 0) + 1
    end
    for _, w in ipairs(C) do
      total[w] = (total[w] or 0) + 1
    end
    for _, w in ipairs(A) do
      local val = (total[w] or 0) - 1
      if val < 0 then
        write(" INEQUAL = '"..w.."'\n")
        return {}
      else
        total[w] = val
      end
    end
    write " PASSED"
  end

  local solutions = {} -- indexe les solutions et leurs occurrences
  local max = {}       -- contient les n éléments ayant le plus d'occurrences (représentation en chaîne de caractères)
  local modif = true
  local it = 0
  local start_time = os.time()

--   local memoized_complements = {}

 --   local counter = 1
  while (#max < 2 and it < params.min_iter)
     or (#max >= 1 and solutions[max[1]].second < 100)
     or (#max >= 2
--        and (write(max[1].."/"..max[2].." \n") or true)
        and solutions[max[1]].second/solutions[max[2]].second < 1 + params.min_coef / solutions[max[1]].second -- and (write("PASSED") or write_ref {max1 = solutions[max[1]].second, max2 = solutions[max[2]].second, ratio = 1+params.min_coef / solutions[max[1]].second, m1 = max[1], m2 = max[2]} or true)
        and modif == true
        and (os.time() - start_time < params.timeout and it < params.max_iter)
        )
     do
    --write(utils.tostring({it = it, time = os.time() - start_time, timeout = params.timeout, min_it = params.min_iter}).."\n")
    it = it + 1
--    write "shuffling\n"
    S = shuffle(B, C)
 --   write("shuffle('"..concat(B).."', '"..concat(C).."') ("..#B..", "..#C..") -> "..utils.table.len(S).."\n")
    modif = false
    for _, sw in pairs(S) do
      local s, w = sw.first, sw.second
      local comp = complement(s, A) -- memoized_complements[utils.tostring{s, A}]
--       if not comp then
--         comp = complement(s, A)
--         memoized_complements[utils.tostring{s, A}] = comp
--       end
--        write("shuffle "..counter.."\n")
--        counter = counter + 1
      for _, c_n2 in pairs(comp) do
        local c, n2 = c_n2.first, c_n2.second
        local c_str = utils.tostring(c)
        modif = true
        local pack = solutions[c_str] or {first = c, second = 0}
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
  return sort(solutions)
end

function appa.check(x, y, z, t)
  local X, Y, Z, T = #x, #y, #z, #t
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
        for l=0,T do
          if i == j and j == k and k == l then
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

-- INCORRECT
-- function appa.tabular_solve(x, y, z)
--   local X, Y, Z = #x, #y, #z
--   local s = {}
--   s.crawl = function (a, b, c)
--     return (((a * Y) + b) * Z) + c
--   end
--   for i=-1,0 do
--     for j=-1,0 do
--       for k=-1,0 do
--         s[s.crawl(i, j, k)] = {}
--       end
--     end
--   end
--   for i=0,X do
--     for j=0,Y do
--       for k=0,Z do
--         if not (i == j and j == k and k == 0) then
--           if x[i] == y[j] then
--             for _, pref in ipairs(s[s.crawl(i-1, j-1, k)]) do
--               table.insert(s[s.crawl(i, j, k)], pref)
--             end
--           end
--           if x[i] == z[k] then
--             for _, pref in ipairs(s[s.crawl(i-1, j, k-1)]) do
--               table.insert(s[s.crawl(i, j, k)], pref)
--             end
--           end
--           for _, pref in ipairs(s[s.crawl(i, j-1, k)]) do
--             table.insert(s[s.crawl(i, j, k)], pref..y[j])
--           end
--           for _, pref in ipairs(s[s.crawl(i, j, k-1)]) do
--             table.insert(s[s.crawl(i, j, k)], pref..z[k])
--           end
--         end
--       end
--     end
--   end
--   return s[s.crawl(X, Y, Z)]
-- end
