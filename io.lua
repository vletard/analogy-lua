analog_io = {}

analog_io.chunk_pattern = analog_io.chunk_pattern or "%S+"

--------------------------------------------------------------------------------
-- Définition de fonctions spécifiques

-- Segmente les chaînes de caractères en arguments et retourne une table contenant les résultats.
-- Si un seul paramètre est fourni, retourne directement la séquence des segments (et non une liste de séquences).
function analog_io.chunk(...)  -- TODO local function
  local segmented = {}
  for _, item in ipairs(table.pack(...)) do
    assert(type(item) == "string")
    local item_segmented = {}
    for w in item:gmatch(analog_io.chunk_pattern) do
      table.insert(item_segmented, w)
    end
    table.insert(segmented, item_segmented)
  end
  if #segmented == 1 then
    return segmented[1]
  else
    return segmented
  end
end

function analog_io.concat(chunked)  -- TODO  local function
  assert(type(chunked) == "table")
  assert(#chunked > 0)
  local str = ""
  local add_spaces = (analog_io.chunk_pattern == "%S+")
  for i, item in ipairs(chunked) do
    assert(type(item) == "string")
    if add_spaces and i > 1 then
      str = str.." "
    end
    str = str..item
  end
  return str
end

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Chargement des paires dans la base de cas

function analog_io.load(keys, values)
  local key_file   = io.open(keys)
  local value_file = io.open(values)

  if not key_file then
    error "Impossible d'ouvrir le fichier des clés."
  elseif not value_file then
    error "Impossible d'ouvrir le fichier des valeurs."
  end
  
  local function read(file)
    return function ()
      local input = file:read()
      return input and analog_io.chunk(input)
    end
  end

  io.stderr:write("Chargement des exemples et construction de l'index...\n")
  assert(0 == knowledge.load(read(key_file), read(value_file)))
  io.stderr:write("...fini (taille lexique = "..#knowledge.lexicon..")\n")
end

-- info{lexicon = knowledge.lexicon, histogram = knowledge.histogram}
-- function explore(tree, n)
--   local max = n
--   for _, c in pairs(tree.children) do
--     local depth = explore(c, n+1)
--     if depth > max then
--       max = depth
--     end
--   end
--   return max
-- end
-- write(explore(knowledge.tree_count, 0))
--------------------------------------------------------------------------------

