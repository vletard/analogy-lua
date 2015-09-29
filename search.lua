local search = {}

local params = {
  cube_seg_max_iter      = 10000,
  cube_seg_max_length    = math.huge,
  cube_seg_max_triplets1 = math.huge,
  cube_seg_max_triplets2 = math.huge,
  debug = false,
  log   = false,
}

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
function search.set_debug(bool)
  params.debug = bool
  if not params.debug then
    write = function() end
  else
    write = __write
  end
end
search.set_debug(params.debug)

function search.set_log(bool)
  params.log = bool
  if not params.log then
    log = function() end
  else
    log = utils.write
  end
end
search.set_debug(params.debug)


-- Returns the list of enumeration functions for each valid triplet found in the knowledge base for the given request.
local function enumerate_valid_triplets(request)
  local generators_start, generators_end
  local counter = 0
  for _, pair in pairs(knowledge.pairs) do
    if counter >= params.cube_seg_max_triplets1 then
      break
    end
    local res = knowledge.retrieve(request, pair.first)
    for _, res_pair in ipairs(res) do
      if counter >= params.cube_seg_max_triplets1 then
        break
      end
      if appa.count(pair.first, res_pair.first, res_pair.second, request) then
        local f
        if segmentation.dynamic then
          f = segmentation.enumerate_analogical_segmentations(pair.first, res_pair.first, res_pair.second, request)
        else
          local unique_seg = { pair.first, res_pair.first, res_pair.second, request }
          f = function () local res = unique_seg; unique_seg = nil; return res end
        end
        local triplet = {
          x = {
            request  = pair.first,
            commands = pair.second,
          },
          y = {
            request  = res_pair.first,
            commands = knowledge.pairs[utils.tostring(res_pair.first[1])].second,
          },
          z = {
            request  = res_pair.second,
            commands = knowledge.pairs[utils.tostring(res_pair.second[1])].second,
          }
        }
        if not generators_end then
          generators_end = { f = f, triplet = triplet }
          generators_start = generators_end
          counter = 1
        else
          generators_end.next = { f = f, triplet = triplet }
          generators_end = generators_end.next
          counter = counter + 1
        end
      end
    end
  end
  log("[cube] triplets retrieved : "..counter.."\n")
  if generators_end then
    generators_end.next = generators_start
  end
--  assert(not generators_start or generators_end.next == generators_start)
  return generators_start
end

--------------------------------------------------------------------------------
-- Searching for analogical cubes (NL square + FL square)

function search.build_cubes(request, request_txt)
  local solutions = {}
  local triples   = {}
  local unknown   = knowledge.list_unknown(request)
  if #unknown > 0 then
    return {}, unknown
  end
  local g = enumerate_valid_triplets(request)
  local triplets = {}
  local time = os.time()
  local iter      = 0
  if g then
    local discarded = 0
    while g.next ~= g and ((iter <= params.cube_seg_max_iter and #triplets < params.cube_seg_max_triplets2) or not segmentation.dynamic) do
      iter = iter + 1
      local seg, l = g.next.f()
      if seg and l <= params.cube_seg_max_length then
        if appa.count(seg[1], seg[2], seg[3], seg[4]) then
          write("[cube] latency   : "..(g.next.latency or 0).."\n")
          table.insert(triplets, g.next.triplet)
--          write(utils.tostring({["#triplets"] = #triplets, time = os.time() - time, size = l, iter = iter}).."\n")
          write(segmentation.concat(seg[1], "|").." : "..segmentation.concat(seg[2], "|").." :: "..segmentation.concat(seg[3], "|").." : "..segmentation.concat(seg[4], "|").."\n")
          g.next = g.next.next
          discarded = discarded + 1
          write("[cube] discarded : "..discarded.."\n")
        else
          g = g.next
        end
        g.next.latency = (g.next.latency or 0) + 1
      else
        g.next = g.next.next
        discarded = discarded + 1
        write("[cube] discarded : "..discarded.."\n")
      end
    end
    local seg, l = g.f()
    while seg and ((iter <= params.cube_seg_max_iter and #triplets < params.cube_seg_max_triplets2) or not segmentation.dynamic) and l <= params.cube_seg_max_length do
      iter = iter + 1
      if appa.count(seg[1], seg[2], seg[3], seg[4]) then
        write("[cube] latency   : "..(g.next.latency or 0).."\n")
        table.insert(triplets, g.next.triplet)
 --       write(utils.tostring({["#triplets"] = #triplets, time = os.time() - time, size = l}).."\n")
        write(segmentation.concat(seg[1], "|").." : "..segmentation.concat(seg[2], "|").." :: "..segmentation.concat(seg[3], "|").." : "..segmentation.concat(seg[4], "|").."\n")
        discarded = discarded + 1
        write("[cube] discarded : "..discarded.."\n")
        break
      end
      seg, l = g.f()
    end
  end

  for _, t in ipairs(triplets) do
    local x, y, z = t.x, t.y, t.z
    local results = {}
    for _, com_x in pairs(x.commands) do
      for _, com_y in pairs(y.commands) do
        for _, com_z in pairs(z.commands) do
          local res = appa.solve(com_x, com_y, com_z)
          if #res > 0 then
            local t = res[#res]
            t.solution = segmentation.concat(t.solution)
            table.insert(results, {
              x = segmentation.concat(com_x),
              y = segmentation.concat(com_y),
              z = segmentation.concat(com_z),
              t = t
            })
          end
        end
      end
    end
    table.insert(solutions, {results = results, triple = {
      x = segmentation.concat(x.request),
      y = segmentation.concat(y.request),
      z = segmentation.concat(z.request),
      X = x,
      Y = y,
      Z = z
    }})
  end
  return solutions, {}
end
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Searching for analogical squares

-- Tests whether the difference between a and b is only an addition (no replacement)
-- Returns the boolean for the test and the global sum of insertions/deletions
local function no_replacement(a, b)
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
    local only_adding, sum = no_replacement(request[1], pair.first[1])
    if sum == 0 then
      for _, command in pairs(pair.second) do
--        for seg in segmentation.enumerate_segmentations({pair.first, command, request}) do
        do 
          local seg = {pair.first, command, request}
          local res = appa.solve(seg[1], seg[2], seg[3])
          if #res > 0 then
            local s = res[#res].solution
            table.insert(solutions, { results = { {
              x = segmentation.concat(s.x, " # "),
              y = segmentation.concat(s.y, " # "),
              z = segmentation.concat(s.z, " # "),
              t = segmentation.concat(s.t, " # "),
              final = segmentation.concat(s.t)
              } }--[[, triple = {
              x = segmentation.concat(pair.first),
              y = segmentation.concat(command),
              z = request_txt,
              }]], square = true})
          end
        end
      end
    end
  end
  return solutions
end
--------------------------------------------------------------------------------

return search
