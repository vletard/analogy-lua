utils = dofile "/people/letard/local/lib/lua/toolbox.lua"

local knowledge = {
  lexicon    =  {},
  pairs      =  {},
  histogram  =  {},
  commands   =  {},
  tree_count = nil,
}


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
      current.label = alphabet[ic]
      local n = tc.node()
      current.children[count] = n
      parent = current
      current = n
    end
  elseif current.index == ic then
    local n = tc.node()
    assert(not current.children[count])
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
      if parent == nil then
        parent = n1
      else
        for i, c in pairs(parent.children) do
          if c == current then
            parent.children[i] = n1
            break
          end
        end
      end
      current = n2
    end
  end
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
    local f = pair.first[1]
    local counts = tc.encode(f)
    local current, parent, i = tc.search(counts, tree, alphabet)
    while i <= A do
      current, parent = tc.insert(counts, i, current, parent, alphabet)
      i = i + 1
    end
    table.insert(current.forms, pair.first)
  end
  return tree
end

function tc.retrieve(tree, counts)
  local frontier = {[knowledge.tree_count] = knowledge.tree_count}
  local A = #knowledge.lexicon
  local i = 0
  for w, _ in pairs(counts) do
    if not knowledge.histogram[w] then
      return {} -- At least on symbol is not present in the lexicon
                -- Note that if the check is performed sooner (more optimal) this case should never occur
    end
  end
  while i <= A and utils.table.len(frontier) ~= 0 do
    local res = {}
    local count = counts[knowledge.lexicon[i]] or 0
    for p1, p2 in pairs(frontier) do
      if p1.index == p2.index and p1.index == i then
        for count1, child1 in pairs(p1.children) do
          for count2, child2 in pairs(p2.children) do
            if count1 + count2 == count then
              assert(not res[child1])
              res[child1] = child2
            end
          end
        end
      elseif p1.index == i then
        local s = p1.children[count]
        if s then
          assert(not res[s])
          res[s] = p2
        end
      elseif p2.index == i then
        local s = p2.children[count]
        if s then
          assert(not res[p1])
          res[p1] = s
        end
      elseif count == 0 then
        assert(not res[p1])
        res[p1] = p2
      end
    end
    frontier = res
    i = i + 1
  end
  local forms = {}
  for p1, p2 in pairs(frontier) do
    for _, f1 in ipairs(p1.forms) do
      for _, f2 in ipairs(p2.forms) do
        assert(utils.deepcompare(tc.encode(f1[1], f2[1]), counts))
        table.insert(forms, {first = f1, second = f2})
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

function knowledge.retrieve(request, match)
  return tc.retrieve(knowledge.tree_count, tc.encode(request[1], match[1]))
end

-- Loads the pairs in input
-- The keys and values parameters must be iterators
-- Returns 1 if there are more keys than values, -1 if the converse is true, 0 if the numbers match
function knowledge.load(keys, values)
  local k, v = keys(), values()
  local histo = {}
  while k do
    if not v then
      return 1
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
  knowledge.histogram = histo
  knowledge.lexicon   = lexicon
  if v then
    return -1
  else
    knowledge.tree_count = tc.build(knowledge.lexicon, knowledge.pairs)
    return 0
  end
end

return knowledge
