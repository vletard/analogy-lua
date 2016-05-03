-- Feel free to write any remark to letard@limsi.fr

do
  local sec, nano = os.time()
  math.randomseed(nano or sec)
end

local function get_time()
  local f = io.popen("date '+%s%N'")
  local time_ns = tonumber(f:read())
  f:close()
  assert(time_ns)
  return time_ns
end

local true_pairs, true_ipairs = pairs, ipairs


--[[
  Creates and returns an unmodifiable table from the one provided.
  Non mutability affects ONLY the FIRST level of objects, subtables and other
  metatables are still editable.
]]
local id = os.time()
function table.unmodifiable (t)
  assert (type(t) == "table")
  cpy = {}
  for k, v in pairs(t) do
    cpy[k] = v
  end
  meta = getmetatable(t)
  if meta then
    setmetatable(cpy, {__index = meta.__index})
  end
  unmodifiable = {}
  setmetatable(unmodifiable, {
    __index = cpy,
    __metatable = {__index = cpy, __unmodifiable = id},
    __newindex = function ()
      error "This table is not mutable."
  end})
  return unmodifiable
end
 
local function shuffleTable( t )
  assert( t, "shuffleTable() expected a table, got nil" )
  local iterations = #t
  local j
                   
  for i = iterations, 2, -1 do
    j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

local function sorted_pairs(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return function (t, key)
    local next_key
    if key == nil then
      next_key = keys[1]
    else 
      next_key = keys[(utils.table.contains(keys, key) or #keys) + 1]
    end
    return next_key, t[next_key]
  end, t
end

--[[
  Returns an enumeration fitted to a non mutable table if needed.
]]
local function improved_pairs(table)
  if type(table) == "table" then
    local meta = getmetatable(table)
    if meta and meta.__unmodifiable == id then
      assert(#table == 0)
      return sorted_pairs(meta.__index)
    end
  else
    io.stderr:write(debug.traceback())
    error ("bad argument #1 to 'pairs' (table expected, got "..type(table)..")")
  end
  return sorted_pairs(table)
end

--[[
  Returns an enumeration fitted to a non mutable table if needed.
]]
local function ipairs (table)
  if type(table) == "table" then
    meta = getmetatable(table)
    if meta and meta.__unmodifiable == id then
      assert(#table == 0)
      return true_ipairs(meta.__index)
    end
  else
    print (debug.traceback())
    error ("bad argument #1 to 'pairs' (table expected, got "..type(table)..")")
  end
  return true_ipairs(table)
end

--[[  table.forall(t, f)
  Same as foreach but executes f recursively on objects of the metatable as
  well. Ignores autoreferences in metatables (but not in the included objects).
]]
table.forall = function (t, f)
  local function forall(t, f, refs, res)
    refs[t] = true
    for k, v in true_pairs(t) do
      res[k] = f(k, v)
    end
    local m = getmetatable(t)
    if m and type(m.__index) == "table" and not refs[m] then
      forall(m.__index, f, refs, res)
    end
    return res
  end
  return forall(t, f, {}, {})
end

--[[ table.insertall(t, t2)
  Inserts all the elements of t2 which are mapped with an integer to the table t.
]]
table.insertall = function (t, t2)
  for _, v in ipairs(t2) do
    table.insert(t, v)
  end
end

--[[
  Returns the (first) key mapped to the specified item, or false if not found.
]]
local function contains(array, item)
  for k, v  in pairs(array) do
    if v == item then
      return k
    end
  end
  return false
end

table.iflatten = function (t)
  local i = 1
  local length = #t
  local fun
  return function ()
    if fun then
      local res = fun()
      if res then
        return res
      else
        fun = nil
      end
    end
    if i <= length then
      if type(t[i]) == "table" and #t[i] > 0 then
        fun = table.iflatten(t[i])
        i = i + 1
        return fun()
      else
        i = i + 1
        return t[i-1]
      end
    else
      return nil
    end
  end
end

--[[
  Returns the (first) key mapped to the specified item, or false if not found.
  Items are compared with deepcompare.
]]
local function deepcontains(array, item)
  for k, v in pairs(array) do
    if utils.deepcompare(v, item) then
      return k
    end
  end
  return false
end

local function keys(array, selector)
  local set = {}
  for k, _ in selector(array) do
    table.insert(set, k)
  end
  return set
end

table.keys = function(array)
  return keys(array, pairs)
end

table.ikeys = function(array)
  return keys(array, ipairs)
end

--[[
  Counts ALL elements of the table and returns the result.
]]
local function len(t)
  local counter = 0
  for _ in pairs(t) do
    counter = counter + 1
  end
  return counter
end
--[[
hashcode = function (obj)
  local hash
  if type(obj) == "string" then
    local hash = 
    local length = obj:len()
    for i = 1, length do
      hash = hash 
    end
  else
    return hashcode(tostring(obj))
  end
  
  local int_len = #t
  local total_len 
end


table.set_deep_index_ = function (t, bool)
  
  bool = ((bool == nil) and true) or bool
  local __index, __newindex = nil, nil
  local meta = getmetatable(t)
  
  if (type(meta) == "table") then
    if not bool then
      meta.__index = nil
      meta.__newindex = nil
      meta.hashtable = nil
      return t
    elseif meta.__index or meta.__newindex then
      error("Setting deep index require no preexistant metaindices.")
    end
  end
  meta = meta or {}
  meta.hashtable = meta.hashtable or {}
  meta.__index = function (t, i)
        for _, j in pairs(meta.hashtable[hashcode(i)] or {}) do
          if deepcompare(i, j) then
            return rawget(t, j)
          end
        end
        return nil
      end
  meta.__newindex = function (t, i, v)
        local hash = hashcode(i)
        meta.hashtable[hash] = meta.hashtable[hash] or {}
        table.insert(meta.hashtable[hash], i)
        return rawset(t, i, v)
      end
  setmetatable(t, meta)
  return t
end
]]

-- Deep key checking instead of reference (makes no difference between 2 distinct tables with the same content)
local function set_deep_index(t, bool)
  error "Function deprecated"
  bool = ((bool == nil) and true) or bool
  local __index, __newindex = nil, nil
  local meta = getmetatable(t)
  
  if (type(meta) == "table") then
    if not bool then
      meta.__index    = nil
      meta.__newindex = nil
      meta.mapping    = nil
      return t
    elseif meta.__index or meta.__newindex or meta.mapping then
      error("Setting deep index require no preexistant metaindices.")
    end
  end
  meta = meta or {}
  meta.__index = function (t, i)
        return rawget(t, utils.tostring(i))
      end
  meta.__newindex = function (t, i, v)
        return rawset(t, utils.tostring(i), v)
      end
  setmetatable(t, meta)
  return t
end

-- No more modifications on these variables.
local table, print, tostring, assert, next, type, pairs, ipairs, setmetatable, getmetatable = table, print, tostring, assert, next, type, pairs, ipairs, setmetatable, getmetatable

queue = {
  peek = function (q) return q[1] end,
  poll = function (q) return table.remove(q, 1) end,
  offer = table.insert
}

stack = {
  peek = function (s) return s[#s] end,
  pop = function (s) return table.remove(s, #s) end,
  push = table.insert,
  get = function (s, n) return s[#s -(n-1)] end
}

function scandir(directory) -- TODO dans toolbox.lua
  local t = {}
  for filename in io.popen('ls -a "'..directory..'"'):lines() do
    table.insert(t, filename)
  end
  return t
end

function unsetmetatable (t)
  setmetatable(t, nil)
end

--[[ string.lines(str)
  Returns an iterator on the lines of the string.
]]
function string.lines(str)
  return str:gmatch("([^\n]+)")
end

--[[ toString(obj, params)
  Returns a complete and recursive string representation of the object.
  Works with tables (including autoreferent ones) and all basic types).
  The depth argument can be specified to limit the exploration (negative value
  is unlimited depth).
]]
function toString(obj, params, ref)
  local tmp = {}
  setmetatable(tmp, {counter = 0})
  local ref = ref or tmp
  params = params or {}
  params.level = params.level or 0
  params.depth = params.depth or -1
  params.ref   = params.ref   or false
  params.noref = params.noref or false
  if params.meta == nil then
    params.meta  = true
  end
  if params.depth == params.level then
    return tostring(obj)
  end

  if type(obj) == "table" then
    getmetatable(ref).counter = getmetatable(ref).counter + 1
    ref[obj] = getmetatable(ref).counter
    local t = obj
    local ref_str = ""
    if not params.noref then
      ref_str = "ref."..getmetatable(ref).counter..(params.ref and (" "..tostring(obj)) or "")
    end
    local repr = "{"..ref_str.."\n"
    local first = true
    
    local keys = {}
    for k, _ in pairs(t) do
      table.insert(keys, k)
    end
    table.sort(keys, function (a, b)
                if type(a) == type(b) then
                  if type(a) == "number" then
                    return a < b
                  else
                    return tostring(a) > tostring(b)
                  end
                else
                  return type(a) < type(b)
                end
    end)
    for _, k in true_ipairs(keys) do
      local v = t[k]
      if first then
        first = false
      else
        repr = repr.."\n"
      end
  
      for i = 1, params.level do
        repr = repr.."\t"
      end
      
      local r = ref[k]
      if not r then
        local val = toString(k, {depth = params.depth, level = params.level + 1, meta = params.meta, ref = params.ref, protect = params.protect, noref = params.noref}, ref)
        if params.protect then
          if not val:match '^"[a-zA-Z_][a-zA-Z0-9_]*"$' then
            val = "["..val.."]"
          else
            val = val:match('^"(.+)"$')
          end
        end
        repr = repr..val
      else
        if params.noref then
          error "Cannot write a recursive structure without using references."
        end
        repr = repr.."[ref_to."..r.."]"
      end
      
      repr = repr.." = "
      
      local r = ref[v]
      if not r then
        if type(v) == "string" then
          if params.protect then
            local val = v
            val = val:gsub('\\', '\\\\')
            val = val:gsub("\n", "\\n")
            val = val:gsub('"', '\\"')
            repr = repr..'"'..val..'"'
          else
            repr = repr..'`'..v..'´'
          end
        else
          repr = repr..toString(v, {depth = params.depth, level = params.level + 1, meta = params.meta, ref = params.ref, protect = params.protect, noref = params.noref}, ref)
        end
      else
        if params.noref then
          error "Cannot write a recursive structure without using references."
        end
        repr = repr.."[ref_to."..r.."]"
      end

    end
    
    local meta = getmetatable(obj)
    if not params.noref and meta and params.meta then
      if first then
        first = false
      else
        repr = repr.."\n"
      end
      for i = 1, params.level do
        repr = repr.."\t"
      end
      repr = repr.."metatable = "..toString(meta, {depth = params.depth, level = params.level + 1, meta = params.meta, ref = params.ref, protect = params.protect}, ref)
    end
    
    repr = repr.."\n"
    for i = 1, params.level do
      repr = repr.."\t"
    end
    repr = repr.."}"
    return repr
  else
    if type(obj) == "string" and params.protect then
      local val = obj
      val = val:gsub('\\', '\\\\')
      val = val:gsub("\n", "\\n")
      val = val:gsub('"', '\\"')
      return '"'..val..'"'
    else
      return tostring(obj)
    end
  end
end


local function export(obj, fd)
  if fd and type(fd.write) ~= "function" then
    error(tostring(fd).." invalid file descriptor.")
  end
  local str = toString(obj, {protect = true, noref = true})
  if fd then
    fd:write("return "..str.."\n")
  end
  return str
end

--[[  plain_export(obj, fd, path)
  Writes a lua string representation of the provided object to fd or stdout if
  not specified.
  Works with nil, boolean, number, string and table types.
  The path arguments specifies the root name of the output object.
]]
local function plain_export(obj, fd, path, ref, keys)
  local root = false
  if fd and type(fd.write) ~= "function" then
    error(tostring(fd).." invalid file descriptor.")
  end
  local fd = fd or io.output()
  local path = path or "t"
  local keys = keys or path.."_keys"
  if not ref then
    root = true
    fd:write("--"..path.."\n--"..keys.."\n\n")
    
    fd:write("-- Note : This file can be edited by hand respecting the lua syntax,\n"
        .. "-- however if you have to load it with plain_import(), you must consider the following :\n"
        .. "-- * use only the two structures : "..path.." and the temporary "..keys.."\n"
        .. "-- * do not use any multiline expression including --[[ multiline comments ]]\n"
        .. "-- * do not change the two first commented lines\n\n\n")

    fd:write("local "..keys.." = {}\n")
  end
  local ref = ref or {counter = 0}
  local repr = ""
  if path:sub(-1) ~= "]" then
    repr = "local "
  end
  repr = repr..path.." = "
  
  if type(obj) == "table" then
    
    local meta = getmetatable(obj)
    if meta then
      error ("Object contains a metatable, it cannot be represented.")
    end
    
    ref.counter = ref.counter + 1
    ref[obj] = path

    local t = obj
    local repr = repr.."{}\n"
    for k, v in pairs(t) do
    
      local current_path
      
      if type(k) == "string" then
        k = k:gsub('\\', '\\\\')
        k = k:gsub("\n", "\\n")
        k = k:gsub('"', '\\"')
        current_path = "[\""..k.."\"]"
      elseif type(k) == "boolean" or type(k) == "number" then
        current_path = "["..tostring(k).."]"
      elseif type(k) == "table" then
        if not ref[k] then
          local tmp_path = keys.."["..(ref.counter + 1).."]"
          plain_export(k, fd, tmp_path, ref, keys)
          
          assert (ref[k] == tmp_path)
        end
        print "test"
        
        current_path = "["..ref[k].."]"
      else
        error ("Plain exportation is only compatible with nil, boolean, string, number and table types, not for "..type(k))
      end
      
      local value = nil
      
      if type(v) == "string" then
        v = v:gsub('\\', '\\\\')
        v = v:gsub("\n", "\\n")
        v = v:gsub("\"", "\\\"")
        value = "\""..v.."\""
      elseif type(v) == "boolean" or type(v) == "number" then
        value = tostring(v)
      elseif type(v) == "table" then
        if not ref[v] then
          fd:write(repr)
          repr = ""
          plain_export(v, fd, path..current_path, ref, keys)
        else
          value = ref[v]
        end
      else
        error ("Plain exportation is only compatible with nil, boolean, string, number and table types, not for "..type(v))
      end
      
      if value then
        repr = repr..path..current_path.." = "..value.."\n"
      end

      fd:write(repr)
      repr = ""
    end
    
    fd:write(repr)
  elseif type(obj) == "string" then
    obj = obj:gsub("\n", "\\n")
    obj = obj:gsub("\"", "\\\"")
    fd:write(repr.."\""..tostring(obj).."\"\n")
  elseif type(obj) == "number" or type(obj) == "boolean" or type(obj) == "nil" then
    fd:write(repr..tostring(obj).."\n")
  else
    error ("Plain exportation is only compatible with nil, boolean, string, number and table types, not for "..type(k))
  end
  if root then
    fd:write("return "..path.."\n")
  end
end

--[[
  Corresponding importation to plain_export above. This function is only useful
  in case of LARGE files. Otherwise a simple dofile() does the stuff.
]]
function plain_import(file)
  local fd
  if type(file) == "string" then
    fd = io.open(file)
  else
    fd = file or io.input()
  end
  local line = fd:read()
  local line_nb = 1
  if not line or line:sub(1, 2) ~= "--" then
    error "Format d'entrée non reconnu."
  end
  local name = line:sub(3)
  line = fd:read()
  line_nb = line_nb + 1
  if not line or line:sub(1, 2) ~= "--" then
    error "Format d'entrée non reconnu."
  end
  local keys_name = line:sub(3)
  line = fd:read()
  line_nb = line_nb + 1
  local var
  local keys = {}
  while line do
    if line ~= "return "..name then
      local exec = "return function ("..name..", "..keys_name..")\n\t"..line.."\n\treturn "..name.."\nend"
      local loading = loadstring(exec)
      if not loading then
        io.stderr:write(debug.traceback().."\n")
        error("Erreur lors du chargement du fichier ligne "..line_nb)
      end
      loading = loading()
      var = loading(var, keys)
    end
    line = fd:read()
    line_nb = line_nb + 1
  end
  if type(var) ~= "table" then
    error "Format d'entrée non reconnu."
  end
  if type(file) == "string" then
    fd:close()
  end
  return var
end

local function _write(toString, ...)
  local printResult = ""
  local first = true
  for i,v in ipairs(table.pack(...)) do
    if first then
      first = false
    else
      printResult = printResult .. "\t"
    end
    printResult = printResult .. toString(v)
  end
  if first then
    assert (#printResult == 0)
    printResult = tostring(nil)
  end
  return print(printResult)
end

--[[
  Same as print(...) but uses toString above instead of predefined tostring.
]]
function write (...)
  return _write(toString, ...)
end


--[[
  Same as write with depth control.
  The depth argument can be specified to limit the exploration (negative value
  is unlimited depth).
]]
function write_depth(depth, ...)
  local toString = function (obj) return toString(obj, {depth = depth}) end
  return _write(toString, ...)
end

function write_ref(...)
  local toString = function (obj) return toString(obj, {ref = true}) end
  return _write(toString, ...)
end

--[[
  Copies an object (except functions) and return its copy.
]]
local function deepcopy(t, refs)
  return restore_autoref(remove_autoref(t))
end

--[[ deepcompare(t1, t2, ignore_mt)
  Compares two structures recursively for strict equality.
  Set the ignore_mt parameter to true to ignore metatables.
  
  Source copied from luacode.org
]]
function deepcompare__(t1, t2, ignore_mt, refs)  -- Deprecated, do not take account of the auto references
  local ty1 = type(t1)
  local ty2 = type(t2)
  
  if ty1 ~= ty2 then
    return false
  end
  
  -- non-table types can be directly compared
  if ty1 ~= 'table' then
    return t1 == t2
  end
  -- same references means equality
  if t1 == t2 then
    return true
  end
  
  ignore_mt = not not ignore_mt
  refs = refs or {}
  if refs[t1] or refs[t2] and not (refs[t1] and refs[t2]) then
    return false
  else
    refs[t1] = true
    refs[t2] = true
  end
  
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then
    return t1 == t2
  end
  for k1, v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not deepcompare__(v1, v2) then
      return false
    end
  end
  for k2, v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not deepcompare__(v1, v2) then
      return false
    end
  end
  return true
end

-- Not sexy but working (assuming the printing order in toString is deterministic)
local function deepcompare(t1, t2)
  if t1 == t2 then
    return true
  else
    return toString(t1, {meta = false}) == toString(t2, {meta = false})
  end
end


local function contains_obj(array, item)
  for k, v in pairs(array) do
    if type(v) == "table" and v.noref == item then
      return k
    end
  end
  return false
end

--[[ remove_autoref(obj)
  Transforms the given object in a non-autoreferent one, ready to serialization.
  'no_functions' is a boolean removing functions if set to true
]]
function remove_autoref (obj, no_functions, refs, assoc)
  no_functions = not not no_functions
  if type(obj) ~= "table" then
    if type(obj) == "function" and no_functions then
      return nil
    else
      return obj
    end
  end
  refs = refs or {}
  assoc = assoc or {}

  assert (not assoc[obj])
  assoc[obj] = {}
  table.insert(refs, {noref = assoc[obj], kpairs = {}, vpairs = {}, kvpairs = {}})
  local current = #refs
  
  local meta = getmetatable(obj)
  if meta then
    metaref = not assoc[meta] or contains_obj(refs, assoc[meta])
    assert (metaref)
    if metaref == true then
      _, refs[current].meta = remove_autoref(meta, no_functions, refs, assoc)
    else
      refs[current].meta = metaref
    end
  end

  for k, v in pairs(obj) do
    local kref = not assoc[k] or contains_obj(refs, assoc[k])
    local vref = not assoc[v] or contains_obj(refs, assoc[v])
    assert (kref and vref)
    
    if kref == true then
      if type(k) == "table" then
        _, kref = remove_autoref(k, no_functions, refs, assoc)
      else
        kref = false
      end
    end
    if vref == true then
      if type(v) == "table" then
        _, vref = remove_autoref(v, no_functions, refs, assoc)
      else
        vref = false
      end
    end
    
    -- obj[k] = nil
    if kref and vref then
      refs[current].kvpairs[kref] = vref
    elseif kref then
      assert (type(v) ~= "table")
      if type(v) ~= "function" or not no_functions then
        refs[current].kpairs[kref] = v
      end
    elseif vref then
      assert (type(k) ~= "table")
      if type(k) ~= "function" or not no_functions then
        refs[current].vpairs[k] = vref
      end
    else
      assert (type(k) ~= "table" and type(v) ~= "table")
      if (type(k) ~= "function" and type(v) ~= "function") or not no_functions then
        assoc[obj][k] = v
      end
    end
  end
  
  if current == 1 then
    return refs
  else
    return refs, current
  end
end


--[[ restore_autoref(refs)
  Rebuild the initial object from the flattened references output by
  remove_autoref.
]]
function restore_autoref (refs, current, assoc)
  if type(refs) ~= "table" then
    return refs
  end
  assert (not current == not assoc)
  local current = current or 1
  local assoc = assoc or {}
  assoc[current] = {}
  local obj = assoc[current]
  
  assert (refs[current].noref and refs[current].vpairs
      and refs[current].kpairs and refs[current].kvpairs)
  
  for k, v in pairs(refs[current].noref) do
    obj[k] = v
  end
  
  for k, ref in pairs(refs[current].vpairs) do
    if not assoc[ref] then
      restore_autoref(refs, ref, assoc)
    end
    obj[k] = assoc[ref]
  end
  for ref, v in pairs(refs[current].kpairs) do
    if not assoc[ref] then
      restore_autoref(refs, ref, assoc)
    end
    obj[assoc[ref]] = v
  end
  for kr, vr in pairs(refs[current].kvpairs) do
    if not assoc[kr] then
      restore_autoref(refs, kr, assoc)
    end
    if not assoc[vr] then
      restore_autoref(refs, vr, assoc)
    end
    obj[assoc[kr]] = assoc[vr]
  end

--  if obj < #refs then
--    restore_autoref(refs, obj +1)
--  end

  if refs[current].meta then
    if not assoc[refs[current].meta] then
      restore_autoref(refs, refs[current].meta, assoc)
    end
    setmetatable(obj, assoc[refs[current].meta])
  end
  
  assert (current ~= 1 or #assoc == #refs)
  return obj
end

local function lines(str)
  if not str:lines()() then
    local done = false
    return function ()
      if not done then
        done = true
        return ""
      end
    end
  else
    return str:lines()
  end
end

local function display(rows, params)
  params = params or {}
  params.h_sep = params.h_sep or " "
  params.v_sep = params.v_sep or ""
  params.display_index   = params.display_index   == nil and true or false
  params.display_caption = params.display_caption == nil and true or false
  params.only_numeric    = params.only_numeric  or false
  params.tostring        = params.tostring      or toString
  if type(rows) ~= "table" then
    error "Table of rows expected for argument #1."
  end
  if params.index and type(params.index) ~= "table" then
    error "Index must be a table."
  end
  if params.cols and type(params.cols) ~= "table" then
    error "Selected comumns (cols) must be a table."
  end
  local indexes_caption = "__idx"
  local c_len = {}
  local total = 0
  local index_len = 0
  local all_cols = {}
  for process = 1,2 do
    local first = true
    local tab = params.index or params.only_numeric and table.ikeys(rows) or table.keys(rows)
    local b_i = 1
    local i = tab[b_i]
    while i do
      local r
      if first and process == 2 and not params.display_caption then
        for i in params.v_sep:gmatch(".") do
          print(string.rep(i, total + #params.h_sep * (table.len(c_len) + 1)))
        end
      end
      if first and process == 2 and params.display_caption then
        r = {}
        for _, c in ipairs(all_cols) do
          r[c] = c
        end
        if params.display_index then
          r[indexes_caption] = indexes_caption
        end
        b_i = b_i - 1
      else
        r = rows[i]
      end
      if type(r) ~= "table" then
        r = { no_table = r }
      end
      local line_iterators = {}
      local cols_indexes   = {}
      if params.display_index then
        local str
        if first then
          str = params.tostring(indexes_caption)
        else
          str = params.tostring(i)
        end
        if str == "" then
          str = " "
        end
        if index_len < #str then
          assert(process == 1)
          index_len = #str
        end
        line_iterators[indexes_caption] = lines(str)
        table.insert(cols_indexes, indexes_caption)
      end
      for _, c in ipairs((process == 2 and all_cols) or params.cols or table.keys(r)) do
        local c_i = table.contains(all_cols, c)
--        table.insert(line_iterators, str:lines())
        if not c_i then
          assert(process == 1)
          table.insert(all_cols, c)
        end
        local content = r[c]
        local str = params.tostring(c)
        line_iterators[str] = lines(content == nil and "" or params.tostring(content))
        table.insert(cols_indexes, str)
      end
--      write{process = process, line_iterators = line_iterators}
      local str
      local continue = true
      while continue do
        str = ""
        continue = false
        for index, c_name in ipairs(cols_indexes) do
          local it = line_iterators[c_name]
          local line = it()
          if line then
            continue = true
            if process == 1 then
              local len = c_len[c_name] or 0
              if #line > len then
                c_len[c_name] = #line
              end
              if params.display_caption then
                for l in c_name:lines() do
                  if #l > c_len[c_name] then
                    c_len[c_name] = #l
                  end
                end
              end
            else
              assert(process == 2)
            end
          end
          if process == 2 then
            if index == 1 then
              str = str..params.h_sep
            end
            local num
            if tonumber(line) then
              num = ""
            else
              num = "-"
            end
            str = str..string.format(" %"..num..c_len[c_name].."s %s", line or "", params.h_sep)
          end
        end
        if process == 2 and continue then
          print(str)
        end
      end
      if process == 2 then
        for i in params.v_sep:gmatch(".") do
--          write{total = total, h_sep = #params.h_sep, c_len = table.len(c_len)}
          print(string.rep(i, total + #params.h_sep * (table.len(c_len) + 1)))
        end
      end
      first = false
      b_i = b_i+1
      i = tab[b_i]
    end
    if process == 1 then
      local MAX = math.huge
      for k, l in pairs(c_len) do
        if l > MAX then
          c_len[k] = MAX
        end
        total = total + c_len[k] + 2
      end
      total = total
    end
  end
end

local quote_pattern = "§§§_"
local table_pattern = "§§_§"

local function unquote(str)
  local final = ""
  local quotes = {}
  local state = 0
  for c in str:gmatch(".") do
    if state == 0 then
      if c == '"' or c == "'" then
        state = (c == '"' and 1 or 3)
        table.insert(quotes, c)
        final = final..quote_pattern..#quotes..quote_pattern
      else
        final = final..c
      end
    elseif state % 2 == 1 then
      assert(state == 1 or state == 3)
      quotes[#quotes] = quotes[#quotes]..c
      if c == "\\" then
        state = state + 1
      elseif (c == '"' and state == 1) or (c == "'" and state == 3) then
        state = 0
      end
    elseif state % 2 == 0 then
      assert (state == 2 or state == 4)
      quotes[#quotes] = quotes[#quotes]..c
      state = state - 1
    else
      assert(false)
    end
  end
  if state ~= 0 then
    return false
  end
  return final, quotes
end

local function requote(str, quotes)
  for i, q in ipairs(quotes) do
    str = str:gsub(quote_pattern..i..quote_pattern, q:gsub("%%", "%%%%"))
  end
  return str
end

local function remove_tables(str)
  local final = ""
  local tables = {}
  local stack = 0
  for c in str:gmatch(".") do
    if c == "{" then
      if stack == 0 then
        table.insert(tables, c)
      else
        tables[#tables] = tables[#tables]..c
      end
      stack = stack + 1
    elseif c == "}" then
      if stack == 0 then
        return false
      else
        tables[#tables] = tables[#tables]..c
      end
      stack = stack - 1
      if stack == 0 then
        final = final..table_pattern..#tables..table_pattern
      end
    else
      if stack == 0 then
        final = final..c
      else
        tables[#tables] = tables[#tables]..c
      end
    end
  end
  if stack ~= 0 then
    return false
  end
  return final, tables
end

local function restore_tables(str, tables)
  for i, t in ipairs(tables) do
    str = str:gsub(table_pattern..i..table_pattern, t)
  end
  return str
end

local nan = math.log(-1)
local function factorial(n)
  if n == 0 then
    return 1
  elseif n < 0 then
    return nan
  else
    return n * factorial(n-1)
  end
end

local function help(f)
  if f == utils.display then
    print 'utils.display(rows, options = {\
  h_sep = "",\
  v_sep = "",\
  display_index   = true,\
  display_caption = true,\
  only_numeric    = false,\
  tostring        = toString\
})'
  elseif f == utils.plain_export then
    print 'utils.plain_export(obj, fd, path)\
  Writes a lua string representation of the provided object to fd or stdout if\
  not specified.\
  Works with nil, boolean, number, string and table types.\
  The path arguments specifies the root name of the output object.'
  elseif f == utils.plain_import then
    print 'utils.plain_import(file)\
  Reads and loads the content in the file descriptor provided.\
  If none, the standard input is read.\
  Alternatively, the parameter can be a filename.\
  For files smaller than the available RAM, dofile can be used instead.'
  else
    print "Update needed for this documentation function."
  end
end

utils = {
  tostring = function (arg) return toString(arg) end,
  tostring_inline = function (arg) return toString(arg):gsub("\t", ""):gsub("\n", " ") end,
  write = write,
  write_ref = write_ref,
  write_depth = write_depth,
  plain_import = plain_import,
  plain_export = plain_export,
  export = export,
  scandir = scandir,
  display = display,
  table = {
    set_deep_index = set_deep_index,
    deep_copy      = deepcopy,
    contains       = contains,
    deepcontains   = deepcontains,
    len            = len,
    shuffle        = shuffleTable,
  },
  string = {
    unquote        = unquote,
    requote        = requote,
    remove_tables  = remove_tables,
    restore_tables = restore_tables,
  },
  math = {
    nan = nan,
    factorial = factorial,
  },
  deepcompare = deepcompare,
  help = help,
  pairs = improved_pairs,
  ipairs = ipairs,
  time = get_time,
}

return utils
