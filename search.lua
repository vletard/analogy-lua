local search = {
  static_cut = false,
  deviation  = 0,
  deviation_solve  = 0,
}

local params = {
  cube_seg_max_iter_without = math.huge,
  cube_seg_max_iter_with    = math.huge,
  cube_seg_max_time_without = 30,
  cube_seg_max_time_with    = 30,
--  cube_seg_max_length       = math.huge,
  cube_seg_max_triplets1    = math.huge,
  cube_seg_max_triplets2    = math.huge,
  cube_seg_max_segments     = 4,
  debug =  true,
  log   =  true,

  segment_delimiter = nil, -- " # ",
  
  LCS_host = "127.0.0.1",
  LCS_port = 9999,
  LCS_segmentation = "words"
}

-- Return false if the stop parameters have been reached, true if not
local function check_stop_params(iter, time, nb_triplets)
  if search.cube_max_time and (os.time() - time) > search.cube_max_time then
    return true
  end
  if not segmentation.dynamic_cube and not search.static_cut then
    return true
  elseif nb_triplets > 0 then
    return (iter <= params.cube_seg_max_iter_with    and (os.time() - time) <= params.cube_seg_max_time_with   )
  else
    return (iter <= params.cube_seg_max_iter_without and (os.time() - time) <= params.cube_seg_max_time_without)
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
  local triplets = {}
  local triplets_dev = {}

  for _, pair in pairs(knowledge.pairs) do
    if #triplets >= params.cube_seg_max_triplets1 then
      break
    end
    local res = knowledge.retrieve(request, pair.first, search.deviation)
    for _, res_pair in ipairs(res) do
      if #triplets >= params.cube_seg_max_triplets1 then
        break
      end
      if res_pair.delta > 0 then
        local unique_seg = { pair.first, res_pair.first, res_pair.second, request }
        f = function () local res = unique_seg; return res end
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
        table.insert(triplets_dev, { triplet = triplet, dev = res_pair.delta })
      else
        assert(appa.count(pair.first, res_pair.first, res_pair.second, request))
        local f
        if segmentation.dynamic_cube then
          local f_ = segmentation.enumerate_segmentations_list(request, { res_pair.first, res_pair.second }, pair.first, params.cube_seg_max_segments)
          f = function ()
            local seg, list, opposite = f_()
            if not seg then
              return nil
            else
              assert(#list == 2)
              assert(opposite)
              return { opposite, list[1], list[2], seg }
            end
          end
        else
          local unique_seg = { pair.first, res_pair.first, res_pair.second, request }
          f = function () local res = unique_seg; return res end
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
        table.insert(triplets, { f = f, triplet = triplet })
      end
    end
  end
  utils.table.shuffle(triplets)  -- evenly distribute the triplets in case of computation cut
  for _, t in ipairs(triplets) do
    if not generators_end then
      generators_end = t
      generators_start = generators_end
    else
      generators_end.next = t
      generators_end = generators_end.next
    end
  end

  log("[cube] triplets retrieved : "..#triplets.."\n")
  if generators_end then
    generators_end.next = generators_start
  end
--  assert(not generators_start or generators_end.next == generators_start)
  return generators_start, triplets_dev
end

--------------------------------------------------------------------------------
-- Searching for analogical cubes (NL square + FL square)

function search.build_cubes(request, request_txt)
  local solutions = {}
  local per_dev = {}
  local highest_dev = 0
  local triples   = {}
  local unknown   = knowledge.list_unknown(request)
--  if #unknown > 0 then
--    return {}, unknown
--  end
  local g, triplets_dev = enumerate_valid_triplets(request)
  local triplets = {}
  local time = os.time()
  local iter      = 0
  if g then
    local discarded = 0
    while g.next ~= g and check_stop_params(iter, time, #triplets) do -- Iterating over the circular linked list g
      iter = iter + 1
      local seg, l = g.next.f()
      if seg then --and l <= params.cube_seg_max_length then
        if appa.count(seg[1], seg[2], seg[3], seg[4]) then
          write("[cube] latency   : "..(g.next.latency or 0).."\n")
          local triplet = {
            x = {
              request  = seg[1],
              commands = g.next.triplet.x.commands,
            },
            y = {
              request  = seg[2],
              commands = g.next.triplet.y.commands,
            },
            z = {
              request  = seg[3],
              commands = g.next.triplet.z.commands,
            },
            latency = utils.time() - global_time
          }
          table.insert(triplets, triplet)
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
    while seg and check_stop_params(iter, time, #triplets) do
      iter = iter + 1
      if appa.count(seg[1], seg[2], seg[3], seg[4]) then
        write("[cube] latency   : "..(g.next.latency or 0).."\n")
        local triplet = {
          x = {
            request  = seg[1],
            commands = g.next.triplet.x.commands,
          },
          y = {
            request  = seg[2],
            commands = g.next.triplet.y.commands,
          },
          z = {
            request  = seg[3],
            commands = g.next.triplet.z.commands,
          },
          latency = utils.time() - global_time
        }
        table.insert(triplets, triplet)
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
          local res, approx = appa.solve_tab_approx(com_x, com_y, com_z, search.deviation_solve)
          assert(type(approx) == "table")
          if #res > 0 then
            results[0] = results[0] or {}
            for _, s in ipairs(res) do
              table.insert(results[0], {
                x = segmentation.concat(com_x, params.segment_delimiter),
                y = segmentation.concat(com_y, params.segment_delimiter),
                z = segmentation.concat(com_z, params.segment_delimiter),
                t = segmentation.concat(s, params.segment_delimiter),
                final = segmentation.concat(s),
                latency = utils.time() - global_time
              })
            end
          else
            for dev, set in ipairs(approx) do
              results[dev] = results[dev] or {}
              for _, s in ipairs(set) do
                table.insert(results[dev], {
                  x = segmentation.concat(com_x, params.segment_delimiter),
                  y = segmentation.concat(com_y, params.segment_delimiter),
                  z = segmentation.concat(com_z, params.segment_delimiter),
                  t = segmentation.concat(s, params.segment_delimiter),
                  final = segmentation.concat(s),
                  deviation = dev,
                  latency = utils.time() - global_time
                })
              end
            end
          end
        end
      end
    end
    for dev, set in pairs(results) do
      if dev == 0 then
        if #set > 0 then
          table.insert(solutions, {results = set, triple = {
            x = segmentation.concat(x.request, params.segment_delimiter),
            y = segmentation.concat(y.request, params.segment_delimiter),
            z = segmentation.concat(z.request, params.segment_delimiter),
            X = x,
            Y = y,
            Z = z
            },
            latency = t.latency,
            cube = true
          })
        end
      else
        per_dev[dev] = per_dev[dev] or {}
        if #set > 0 then
          table.insert(per_dev[dev], {results = set, triple = {
            x = segmentation.concat(x.request, params.segment_delimiter),
            y = segmentation.concat(y.request, params.segment_delimiter),
            z = segmentation.concat(z.request, params.segment_delimiter),
            X = x,
            Y = y,
            Z = z
            },
            latency = t.latency,
            deviation_solve = dev,
            cube = true
          })
        end
      end
    end
  end

  for _, t in ipairs(triplets_dev) do
    local x, y, z = t.triplet.x, t.triplet.y, t.triplet.z
    local orig1 = request_txt
    local orig2 = segmentation.concat(z.request) 
    local approx1 = appa.solve_tab(x.request, y.request, z.request)
    approx1 = approx1[#approx1]
    if approx1 then approx1 = segmentation.concat(approx1.solution.t); end
    local approx2 = appa.solve_tab(y.request, x.request, request)
    approx2 = approx2[#approx2]
    if approx2 then approx2 = segmentation.concat(approx2.solution.t); end
    if approx1 or approx2 then
      local results = {}
      for _, com_x in pairs(x.commands) do
        for _, com_y in pairs(y.commands) do
          for _, com_z in pairs(z.commands) do
            local res, approx = appa.solve_tab_approx(com_x, com_y, com_z, search.deviation_solve)
            if #res > 0 then
              results[0] = results[0] or {}
              for _, s in ipairs(res) do
                table.insert(results[0], {
                  x = segmentation.concat(com_x, params.segment_delimiter),
                  y = segmentation.concat(com_y, params.segment_delimiter),
                  z = segmentation.concat(com_z, params.segment_delimiter),
                  t = segmentation.concat(s, params.segment_delimiter),
                  final = segmentation.concat(s),
                  latency = utils.time() - global_time
                })
              end
            else
              for dev, set in ipairs(approx) do
                for _, s in ipairs(set) do
                  results[dev] = results[dev] or {}
                  table.insert(results[dev], {
                    x = segmentation.concat(com_x, params.segment_delimiter),
                    y = segmentation.concat(com_y, params.segment_delimiter),
                    z = segmentation.concat(com_z, params.segment_delimiter),
                    t = segmentation.concat(s, params.segment_delimiter),
                    final = segmentation.concat(s),
                    deviation = dev,
                    latency = utils.time() - global_time
                  })
                end
              end
            end
          end
        end
      end
      for dev, set in pairs(results) do
        local final_dev = dev + t.dev
        assert(final_dev > 0)
        if #set > 0 then
          if final_dev > highest_dev then
            highest_dev = final_dev
          end
          local tab = per_dev[final_dev] or {}
          table.insert(tab, {results = set, triple = {
            x = segmentation.concat(x.request, params.segment_delimiter),
            y = segmentation.concat(y.request, params.segment_delimiter),
            z = segmentation.concat(z.request, params.segment_delimiter),
            X = x,
            Y = y,
            Z = z
            },
            latency = t.latency,
            cube = true,
            deviation_search = t.dev,
            deviation_solve = dev,
            approx1 = approx1,
            approx2 = approx2,
            orig1 = orig1,
            orig2 = orig2,
          })
          per_dev[final_dev] = tab
        end
      end
    end
  end
  local solutions_dev = {}
  for i=1,highest_dev do
    for _, s in ipairs(per_dev[i] or {}) do
      table.insert(solutions_dev, s)
    end
  end

  return solutions, unknown, solutions_dev
end
--------------------------------------------------------------------------------


local function find_LCS(request)
  local s = sock.connect_tcp(params.LCS_host, params.LCS_port)
  if not s then
    error("Unable to reach "..params.LCS_host..":"..params.LCS_port)
  end

  -- Always characters first then words or characters (after LCS is identified)
  for i, c in ipairs(request[1]) do
    if i > 1 then
      s:str():write("\t")
    end
    s:str():write(c)
  end
  s:str():write("\n")
  s:str():flush()

  local match = {}
  do
    local line = s:str():read_line()
    while line do
      local sub_str_start, sub_str_end, matches = line:match("^(%d+) (%d+)\t(.*)$")
      sub_str_start = tonumber(sub_str_start) + 1
      sub_str_end   = tonumber(sub_str_end  ) + 1

      for offset, id in matches:gmatch("(%d+) (%d+)") do
        offset = offset + 1
        id = id + 1
        table.insert(match, {
          from   = sub_str_start,
          to     = sub_str_end,
          utt_id = id,
          offset = offset,
          utt_w  = segmentation.constrained_chunk("words", knowledge.pairs[knowledge.ordered[id]].first[1], {{ offset, offset + sub_str_end - sub_str_start}}),
          utt_c  = segmentation.constrained_chunk("characters", knowledge.pairs[knowledge.ordered[id]].first[1], {{ offset, offset + sub_str_end - sub_str_start}}),
          req_w  = segmentation.constrained_chunk("words", request[1], {{ sub_str_start, sub_str_end }}),
          req_c  = segmentation.constrained_chunk("characters", request[1], {{ sub_str_start, sub_str_end }}),
          mapping = knowledge.pairs[knowledge.ordered[id]]
        })
      end
      line = s:str():read_line()
    end
    s:str():close()
  end
  return match
end

function search.build_cubes_LCS(request, request_txt)
  local time = utils.time()
  local unknown   = knowledge.list_unknown(request)
  local solutions = {}
  
  for _, y in pairs(knowledge.pairs) do
    for _, z in ipairs(find_LCS(request)) do
      local y_w = segmentation.chunk("words", segmentation.concat(y.first))
      if appa.count(z.req_w, z.utt_w, y_w) then
        for _, r in ipairs(appa.solve_tab_approx(z.req_w, z.utt_w, y_w)) do
          local r_s = segmentation.chunk("characters", segmentation.concat(r))
          local k = next(knowledge.pairs)
          local x = knowledge.pairs[utils.tostring(r_s[1])]
          if x then
            local results = {}
            for _, c_x in pairs(x.second) do
              for _, c_y in pairs(y.second) do
                for _, c_z in pairs(z.mapping.second) do
                  for _, s in ipairs(appa.solve_tab_approx(c_x, c_y, c_z)) do
                    table.insert(results, {
                      x = segmentation.concat(c_x),
                      y = segmentation.concat(c_y),
                      z = segmentation.concat(c_z),
                      t = segmentation.concat(s),
                      final = segmentation.concat(s),
                      latency = utils.time() - global_time
                    })
                  end
                end
              end
            end

            if #results > 0 then
              local LCS = {}
              for i = z.from, z.to do
                table.insert(LCS, request[1][i])
              end
              table.insert(solutions, {
                triple = {
                  X = {
                    request = r,
                    commands = x.second
                  },
                  Y = {
                    request = y.first,
                    commands = y.second
                  },
                  Z = {
                    request = z.mapping.first,
                    commands = z.mapping.second
                  },
                  x = segmentation.concat(r),
                  y = segmentation.concat(y.first),
                  z = segmentation.concat(z.mapping.first),
                  t = segmentation.concat(request),
                },
                results = results,
                latency = utils.time() - global_time,
                cube = true,
                LCS = LCS
              })
            end
          end
        end
      end
    end
  end

  return solutions, unknown, {}
end


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
  local solutions_approx = {}
  local squares = {}
  local i = 0
  for _, pair in pairs(knowledge.pairs) do
    local only_adding, sum = no_replacement(request[1], pair.first[1])
    if sum == 0 then
      for _, command in pairs(pair.second) do
--        for seg in segmentation.enumerate_segmentations({pair.first, command, request}) do
        do 
          local seg = {pair.first, command, request}
--          io.stderr:write("\nAPPA IN\n"..utils.tostring({segmentation.concat(seg[1]), segmentation.concat(seg[2]), segmentation.concat(seg[3])}).."\n")
          local res, approx = appa.solve_tab_approx(seg[1], seg[2], seg[3], search.deviation_solve)
          for _, s in ipairs(res) do
            table.insert(solutions, { results = { {
              x = segmentation.concat(seg[1], params.segment_delimiter),
              y = segmentation.concat(seg[2], params.segment_delimiter),
              z = segmentation.concat(seg[3], params.segment_delimiter),
              t = segmentation.concat(s, params.segment_delimiter),
              final = segmentation.concat(s),
              latency = utils.time() - global_time,
              } },--[[, triple = {
              x = segmentation.concat(pair.first),
              y = segmentation.concat(command),
              z = request_txt,
              }]]
              latency = utils.time() - global_time,
              square = true})
          end
          for dev, set in ipairs(approx) do
            solutions_approx[dev] = solutions_approx[dev] or {}
            for _, s in ipairs(set) do
              if #s[1] > 0 then
                table.insert(solutions_approx[dev], { results = { {
                  x = segmentation.concat(seg[1], params.segment_delimiter),
                  y = segmentation.concat(seg[2], params.segment_delimiter),
                  z = segmentation.concat(seg[3], params.segment_delimiter),
                  t = segmentation.concat(s, params.segment_delimiter),
                  final = segmentation.concat(s),
                  latency = utils.time() - global_time,
                  } },--[[, triple = {
                  x = segmentation.concat(pair.first),
                  y = segmentation.concat(command),
                  z = request_txt,
                  }]]
                  latency = utils.time() - global_time,
                  deviation = dev,
                  square = true
                })
              end
            end
          end
        end
      end
--    else
--      log("[square] discarded: "..segmentation.concat(pair.first).."\n")
    end
  end
  local approx = {}
  for _, set in ipairs(solutions_approx) do
    for _, s in ipairs(set) do
      table.insert(approx, s)
    end
  end
  return solutions, approx
end
--------------------------------------------------------------------------------

return search
