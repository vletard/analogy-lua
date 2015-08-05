search = {}

--------------------------------------------------------------------------------
-- Recherche de cubes analogiques

function search.build_cubes(request, request_txt)
  local solutions = {}
  local triples = {}
  for _, pair in pairs(knowledge.pairs) do
    for _, res_pair in ipairs(knowledge.retrieve(request, pair.first)) do
      local x = {
        request  = res_pair.first,
        commands = knowledge.pairs[utils.tostring(res_pair.first)].second,
      }
      local y = {
        request  = res_pair.second,
        commands = knowledge.pairs[utils.tostring(res_pair.second)].second,
      }
      local z = {
        request  = pair.first,
        commands = pair.second,
      }
      local t = {
        request  = request,
      }
      if appa.check(x.request, y.request, z.request, t.request) then
        table.insert(triples, {x = x, 
                               y = y,
                               z = z
                              })
--        local res = appa.solve(x.command, y.command, z.command)
--        x.request = analog_io.concat(x.request)
--        x.command = analog_io.concat(x.command)
--        y.request = analog_io.concat(y.request)
--        y.command = analog_io.concat(y.command)
--        z.request = analog_io.concat(z.request)
--        z.command = analog_io.concat(z.command)
--        table.insert(solutions, {res[#res], res[#res-1], triple = { x = x, y = y, z = z }})
      end
    end
  end

  for _, t in ipairs(triples) do
    local x, y, z = t.x, t.y, t.z
    local results = {}
    for _, com_x in pairs(x.commands) do
      for _, com_y in pairs(y.commands) do
        for _, com_z in pairs(z.commands) do
          local res = appa.solve(com_x, com_y, com_z)
          if #res > 0 then
            local t = res[#res]
            t.solution = analog_io.concat(t.solution)
            table.insert(results, {
              x = analog_io.concat(com_x),
              y = analog_io.concat(com_y),
              z = analog_io.concat(com_z),
              t = t
            })
          end
        end
      end
    end
    table.insert(solutions, {results = results, triple = {
      x = analog_io.concat(x.request),
      y = analog_io.concat(y.request),
      z = analog_io.concat(z.request),
      X = x,
      Y = y,
      Z = z
    }})
  end
  return solutions
end
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Recherche de carrés analogiques

-- Retourne si la différence entre a et b ne consiste qu'en un ajout, ainsi que la somme globale des insertions/suppressions
local function only_adding_sum(a, b)
  local sum = {}
  for _, w in ipairs(a) do
    sum[w] = (sum[w] or 0) + 1
  end
  for _, w in ipairs(b) do
    sum[w] = (sum[w] or 0) - 1
  end
  local pos, neg
  local S = 0
  for w, s in pairs(sum) do
    S = S + s
    if s > 0 then
      pos = w
    elseif s < 0 then
      neg = w
    end
  end
  return (not (pos and neg)), S
end

function search.build_squares(request, request_txt)
  local solutions = {}
  local squares = {}
  local i = 0
  for _, pair in pairs(knowledge.pairs) do
    local only_adding, sum = only_adding_sum(request, pair.first)
    if sum == 0 then
      for _, command in pairs(pair.second) do
        local res = appa.solve(pair.first, command, request)
        if #res > 0 then
          local t = res[#res]
          t.solution = analog_io.concat(t.solution)
          table.insert(solutions, { results = { { t = t } }, triple = {
            x = analog_io.concat(pair.first),
            y = analog_io.concat(command),
            z = request_txt,
            }, square = true})
        end
      end
    end
  end
  return solutions
end
--------------------------------------------------------------------------------


