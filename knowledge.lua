dofile "/people/letard/local/lib/lua/toolbox.lua"

knowledge = {
  lexicon    =  {},
  pairs      =  {},
  histogram  =  {},
  commands   =  {},
  tree_count = nil,
}


--------------------------------------------------------------------------------
-- Implémentation de l'arbre de comptage (Langlais & Yvon, 2008)

local tc = {}

-- Extraction d'un vecteur de comptage à partir d'une ou plusieurs formes
function tc.encode(...)
  local counts = {}
  for _, form in ipairs(table.pack(...)) do
    for _, symbol in ipairs(form) do
      counts[symbol] = (counts[symbol] or 0) + 1
    end
  end
  return counts
end

-- Création d'un noeud
function tc.node(index, forms, children)
  return { index = index, forms = forms or {}, children = children or {} }
end

-- Insertion d'un noeud dans l'arbre
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

-- Recherche et positionnement d'un vecteur de comptage dans l'arbre
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

-- Construction
function tc.build(alphabet, forms)
  local tree = tc.node(0, nil, { [0] = tc.node() })
  local A = #alphabet
  for _, pair in pairs(forms) do
    local f = pair.first
    local counts = tc.encode(f)
    local current, parent, i = tc.search(counts, tree, alphabet)
    while i <= A do
      current, parent = tc.insert(counts, i, current, parent, alphabet)
      i = i + 1
    end
    table.insert(current.forms, f)
  end
  return tree
end

function tc.retrieve(tree, counts)
  local frontier = {[knowledge.tree_count] = knowledge.tree_count}
  local A = #knowledge.lexicon
  local i = 0
  for w, _ in pairs(counts) do
    if not knowledge.histogram[w] then
      return {} -- Il y a un symbole de counts qui n'existe pas dans le lexique
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
        assert(utils.deepcompare(tc.encode(f1, f2), counts))
        table.insert(forms, {first = f1, second = f2})
      end
    end
  end
  return forms
end


--------------------------------------------------------------------------------

function knowledge.retrieve(request, match)
  return tc.retrieve(knowledge.tree_count, tc.encode(request, match))
end

-- Charge les paires d'éléments dans la base d'exemples.
-- Les paramètres keys et values doivent être des itérateurs !
-- Retourne 1 si plus de clés que de valeurs, -1 si plus de valeurs que de clés, 0 sinon.
function knowledge.load(keys, values)
  local k, v = keys(), values()
  local histo = {}
  while k do
    if not v then
      return 1
    end
    assert(not (#v == 0 and #k ~=0) and not (#v ~= 0 and #k == 0))
    if #k ~= 0 and #v ~= 0 then
      local r_content = knowledge.commands[utils.tostring(v)] or {first = v, second = {}}
      r_content.second[utils.tostring(k)] = k
      knowledge.commands[utils.tostring(v)] = r_content

      local content = knowledge.pairs[utils.tostring(k)] or {first = k, second = {}}
      content.second[utils.tostring(v)] = v
      knowledge.pairs[utils.tostring(k)] = content

      for _, w in ipairs(k) do
        histo[utils.tostring(w)] = (histo[utils.tostring(w)] or 0) + 1
      end
    end
    k, v = keys(), values()
  end
  local occurrencies, values = {}, {}
  for w, o in pairs(histo) do
    local t = occurrencies[o] or {}
    if #t == 0 then
      table.insert(values, o)
    end
    table.insert(t, w)
    occurrencies[o] = t
  end
  table.sort(values, function (a, b) return b < a end)
  local lexicon = {}
  for _, o in ipairs(values) do
    for _, w in ipairs(occurrencies[o]) do
      table.insert(lexicon, w)
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
