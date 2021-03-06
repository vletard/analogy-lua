local utils = dofile "toolbox.lua"

local knowledge = {
  lexicon    =  {},
  pairs      =  {},
  histogram  =  {},
  commands   =  {},
  tree_count = nil,
}

local function cmp_multitype(op1, op2)
    local type1, type2 = type(op1), type(op2)
    if type1 ~= type2 then --cmp by type
        return type1 < type2
    elseif type1 == "number" and type2 == "number"
        or type1 == "string" and type2 == "string" then
        return op1 < op2 --comp by default
    elseif type1 == "boolean" and type2 == "boolean" then
        return op1 == true
    else
        return tostring(op1) < tostring(op2) --cmp by address
    end
end

-- This overriding of pairs is necessary in order to constistently
-- enumerate tables in the same order
local function pairs(t)
  assert(type(t) == "table")
  local meta = getmetatable(t) or {}
  local keys, index
  if not meta.__factoriel__meta__ then
    keys = {}
    local k = next(t)
    while k do
      table.insert(keys, k)
      k = next(t, k)
    end
    table.sort(keys, cmp_multitype)
    index = {}
    for i, k in ipairs(keys) do
      assert(not index[k])
      index[k] = i
    end
    meta.__factoriel__meta__ = {
      keys = keys,
      index = index
    }
    local tmp = meta.__newindex or rawset
    meta.__newindex = function (t, k, v)
      getmetatable(t).__factoriel__meta__ = nil
      tmp(t, k, v)
    end
  else
    keys  = meta.__factoriel__meta__.keys
    index = meta.__factoriel__meta__.index
  end
  return function (t2, k)
    if t2 == nil then
      t2 = t
    end
    if not t2 == t then
      utils.write{t2 = t2, t = t}
      assert(false)
    end
    local rk, rv = nil, nil
    if k == nil then
      rk = keys[1]
      rv = t2[rk]
    else
      rk = keys[index[k]+1]
      rv = t2[rk]
    end
    assert(rv or not rk)
    return rk, rv
  end
end

--------------------------------------------------------------------------------
-- Implementation of tree-count (Langlais & Yvon, 2008)

local tc = {}

-- Extracting a count vector from one or more forms
function tc.encode(...)
  local counts = {}
  for _, form in ipairs(table.pack(...)) do
    for _, symbol in ipairs(form) do
      counts[symbol] = (counts[symbol] or 0) + 1
    end
  end
  return counts
end

-- Node creation
function tc.node(index, forms, children)
  return { index = index, forms = forms or {}, children = children or {} }
end

-- Node insertion in the tree
function tc.insert(counts, ic, current, parent, alphabet)
  local count = counts[alphabet[ic]] or 0
  assert(current ~= nil)
  if current.index == nil then
    if count ~= 0 then
      current.index = ic
      current.label = alphabet[ic] -- XXX est-ce nécessaire ? si non, supprimer
      local n = tc.node()
      current.children[count] = n
      parent = current
      current = n
    end
  elseif current.index == ic then
    local n = tc.node()
    assert(not current.children[count])
--    if count == 0 then -- XXX new
--      n.forms = current.forms
--      current.forms = {}
--    end
    current.children[count] = n
    parent = current
    current = n
  else
    assert(current.index > ic)
    if count ~= 0 then
      local n1 = tc.node(ic)
      n1.children[0] = current
      local n2 = tc.node()
      n1.children[count] = n2
      if parent then
        for i, c in pairs(parent.children) do
          if c == current then
            parent.children[i] = n1
            break
          end
        end
      end
      parent = n1
      current = n2
    end
  end
--  assert(not (current.children[0] and #current.forms > 0))
--  assert(not (parent.children[0] and #parent.forms > 0))
  return current, parent
end

-- Searching and setting a count vector within the tree
function tc.search(counts, tree, alphabet)
  local i = 0
  local parent = nil
  local current = tree
  local A = #alphabet
  while current.index ~= nil and i <= A do
    if i > current.index then
      break
    elseif i < current.index then
      if (counts[alphabet[i]] or 0) == 0 then
        i = i + 1
      else
        break
      end
    else
      local s = current.children[counts[alphabet[i]] or 0]
      if s then
        parent = current
        current = s
        i = i + 1
      else
        break
      end
    end
  end
  return current, parent, i
end

-- Building the tree
function tc.build(alphabet, forms)
  local tree = tc.node(0, nil, { [0] = tc.node() })
  local A = #alphabet
  for _, pair in pairs(forms) do
--    print("debug "..segmentation.concat(pair.first))
    local f = pair.first[1]
    local counts = tc.encode(f)
    local current, parent, i = tc.search(counts, tree, alphabet)
    while i <= A do
      current, parent = tc.insert(counts, i, current, parent, alphabet)
      i = i + 1
    end
    table.insert(current.forms, pair.first)
--    print("debug "..#current.forms)
  end
  return tree
end

function tc.retrieve_generic(tree, counts, deviation)
  assert(deviation >= 0)
  local missing = 0
  for w, c in pairs(counts) do
    local h = knowledge.histogram[w]
    if not h then
      knowledge.histogram[w] = 0
      table.insert(knowledge.lexicon, w)
      print("new token \""..w.."\"")
    end
    if (h or 0) == 0 then
      missing = missing + c
      if missing > deviation then -- More than deviation occurrences are missing
        return {}
      end
    end
  end

  local frontier = { { knowledge.tree_count, knowledge.tree_count, delta = 0 } }
  local A = #knowledge.lexicon
  local i = 0
  while i <= A and utils.table.len(frontier) ~= 0 do
    local res = {}
    local token = knowledge.lexicon[i]
    local count = counts[token] or 0
    for _, p in ipairs(frontier) do
      local p1    = p[1]
      local p2    = p[2]
      local delta = p.delta
--      assert(not (p1.children[0] and #p1.forms > 0))
--      assert(not (p2.children[0] and #p2.forms > 0))
      for adjust = 0, deviation - delta do
        if p1.index == p2.index and p1.index == i then
          for count1, child1 in pairs(p1.children) do
            for count2, child2 in pairs(p2.children) do
              if math.abs(count1 + count2 - count) == adjust then
                table.insert(res, { child1, child2, delta = delta + adjust })
              end
            end
          end
          if #p2.forms > 0 then
            local child1 = p1.children[count - delta]
            if child1 then
              table.insert(res, { child1, p2, delta = delta + adjust })
            end
            child1 = p1.children[count + delta]
            if child1 then
              table.insert(res, { child1, p2, delta = delta + adjust })
            end
          end
          if #p1.forms > 0 then
            local child2 = p2.children[count - delta]
            if child2 then
              table.insert(res, { p1, child2, delta = delta + adjust })
            end
            child2 = p2.children[count + delta]
            if child2 then
              table.insert(res, { p1, child2, delta = delta + adjust })
            end
          end
        elseif p1.index == i then
          local s = p1.children[count - adjust]
          if s then
            table.insert(res, { s , p2, delta = delta + adjust })
          end
          if adjust > 0 then
            s = p1.children[count + adjust]
            if s then
              table.insert(res, { s , p2, delta = delta + adjust })
            end
          end
          if count == adjust and #p1.forms > 0 then
            table.insert(res, { p1, p2, delta = delta + adjust })
          end
        elseif p2.index == i then
          local s = p2.children[count - adjust]
          if s then
            table.insert(res, { p1, s , delta = delta + adjust })
          end
          if adjust > 0 then
            s = p2.children[count + adjust]
            if s then
              table.insert(res, { p1, s , delta = delta + adjust })
            end
          end
          if count == adjust and #p2.forms > 0 then
            table.insert(res, { p1, p2, delta = delta + adjust })
          end
        elseif count == adjust then
          table.insert(res, { p1, p2, delta = delta + adjust })
        end
      end
    end
    frontier = res
    i = i + 1
  end
  local forms = {}
  for _, p in ipairs(frontier) do
    local p1 = p[1]
    local p2 = p[2]
    local delta = p.delta
    for _, f1 in ipairs(p1.forms) do
      for _, f2 in ipairs(p2.forms) do
        assert(delta > 0 or utils.deepcompare(tc.encode(f1[1], f2[1]), counts))
        table.insert(forms, {first = f1, second = f2, delta = delta})
      end
    end
  end
  return forms
end


--------------------------------------------------------------------------------

function knowledge.list_unknown(request)
  local unknown_symbols = {}
  for _, symbol in ipairs(request[1]) do
    if (knowledge.histogram[symbol] or 0) == 0 then
      table.insert(unknown_symbols, symbol)
    end
  end
  return unknown_symbols
end

function knowledge.retrieve(request, match, deviation)
  local counts = tc.encode(request[1], match[1])
  local res
  if type(knowledge.tree_count) ~= "table" then
    assert(knowledge.tree_count == nil)
    knowledge.init()
    assert(type(knowledge.tree_count) == "table")
    knowledge.init = nil
  end
  if deviation then
    res = tc.retrieve_generic(knowledge.tree_count, counts, deviation)
  else
    res = {}
    for _, f in ipairs(tc.retrieve_generic(knowledge.tree_count, counts, 0)) do
      table.insert(res, { first = f.first, second = f.second })
    end
  end
--  print("debug "..segmentation.concat(match))
  return res
end

-- Loads the pairs in input
-- The keys and values parameters must be iterators over segmented sequences
-- Returns 1 if there are more keys than values, -1 if the converse is true, 0 if the numbers match
function knowledge.load(keys, values)
  local k, v = keys(), values()
  local histo = {}
  local histoindex = {}
  while k do
    if not v then
      return 1 -- more keys than values
    end
    assert(not (#v[1] == 0 and #k[1] ~=0) and not (#v[1] ~= 0 and #k[1] == 0))
    if #k[1] ~= 0 and #v[1] ~= 0 then
      -- Updating the reverse associations map
      local r_content = knowledge.commands[utils.tostring(v[1])] or {first = v, second = {}}
      r_content.second[utils.tostring(k[1])] = k
      knowledge.commands[utils.tostring(v[1])] = r_content

      -- Updating the associations map
      local content = knowledge.pairs[utils.tostring(k[1])] or {first = k, second = {}}
      content.second[utils.tostring(v[1])] = v
      knowledge.pairs[utils.tostring(k[1])] = content

      -- Updating the histogram of the segments
      for _, length in ipairs(k) do
        for _, segment in ipairs(length) do
          histo[utils.tostring(segment)] = (histo[utils.tostring(segment)] or 0) + 1
        end
      end
    end
    k, v = keys(), values()
  end
  if v then
    return -1 -- more values than keys
  else
    knowledge.histogram = histo
    knowledge.init = function()
      local occurrencies, values = {}, {}
      for segment, occ in pairs(histo) do
        local t = occurrencies[occ] or {}
        if #t == 0 then
          table.insert(values, occ)
        end
        table.insert(t, segment)
        occurrencies[occ] = t
      end
      table.sort(values, function (a, b) return b < a end)
      local lexicon = {}
      for _, occ in ipairs(values) do
        for _, segment in ipairs(occurrencies[occ]) do
          table.insert(lexicon, segment)
        end
      end
      knowledge.lexicon   = lexicon
      knowledge.tree_count = tc.build(knowledge.lexicon, knowledge.pairs)
    end
--     local fd = io.open("/tmp/knowledge", "w")
--     fd:write(utils.tostring(knowledge.tree_count))
--     fd:close()
    return 0
  end
end

return knowledge
