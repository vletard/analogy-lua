local _segmentation = {
}

local  input_mode = "words"
local output_mode = "words"
local modes = {
  ["words"]              = { dynamic = false, sep = " ", pattern = "%S+"    },
  ["bars"]               = { dynamic = false, sep = " ", pattern = "[^|]+"  },
  ["words+spaces"]       = { dynamic = false, sep = "",  pattern = "%S+%s*" },
  ["characters"]         = { dynamic = false, sep = "",  pattern = "[%z\1-\127\194-\244][\128-\191]*"      },
  ["words_dynamic"]      = { dynamic =  true, pattern = "%S+"    },
  ["characters_dynamic"] = { dynamic =  true, pattern = "."      },
  ["symbols_dynamic"]    = { dynamic =  true }
}

_segmentation.dynamic = false

local function check_mode(new_mode)
  assert(type(new_mode) == "string")
  if not modes[new_mode] then
    local mode_str = ""
    for m, _ in pairs(modes) do
      if mode_str ~= "" then
        mode_str = mode_str..", "
      end
      mode_str = mode_str.."'"..m.."'"
    end
    error("Illegal mode '"..new_mode.."'. Legal modes are: "..mode_str)
    -- return false
  end
  return true
end

function _segmentation.set_input_mode(new_mode)
  if check_mode(new_mode) then
    input_mode = new_mode
  end
end

function _segmentation.set_output_mode(new_mode)
  if check_mode(new_mode) then
    output_mode = new_mode
  end
end

function _segmentation.get_input_mode()
  return input_mode
end

function _segmentation.get_output_mode()
  return output_mode
end

-- Segmenting the given character strings and returns a table of the results.
-- If only one string is passed, directly returns the sequence of symbols (rather than the list of sequences)
function _segmentation.chunk(mode, ...)
  check_mode(mode)
  local segmented = {}
  for _, item in ipairs(table.pack(...)) do
    assert(type(item) == "string" or mode == "symbols_dynamic")
    local item_segmented = { [1] = {} }
    if mode == "symbols_dynamic" then
      item_segmented[1] = utils.table.deep_copy(item)
    else
      for s in item:gmatch(modes[mode].pattern, "%1") do
        table.insert(item_segmented[1], s)
      end
    end
    if modes[mode].dynamic then
      local space = ((modes[mode].pattern == "%S+") and " " or "")
      local size = #item_segmented[1]
      for length=2,size do
        item_segmented[length] = {}
        for position=1,size-(length-1) do
          local segment = ""
          for i=position,position+length-1 do
            if segment ~= "" then
              segment = segment..space
            end
            segment = segment..item_segmented[1][i]
          end
          table.insert(item_segmented[length], segment)
        end
      end
    end
    item_segmented.mode = mode
    table.insert(segmented, item_segmented)
  end
  if #segmented == 1 then
    return segmented[1]
  else
    return segmented
  end
end

-- Segmenting the given splitted str and returns a table of the results.
-- The parameter chunks is a list of pairs of indices for the non splittable chunks.
function _segmentation.constrained_chunk(mode, split_str, chunks)
  chunks = chunks or {}
  assert(type(mode) == "string")
  assert(type(split_str) == "table")
  local segmented = { [1] = {}, mode = mode }
  if mode == "characters" then
    local c_i = 1
    local buffer = ""
    for i, c in ipairs(split_str) do
      if chunks[c_i] and i >= chunks[c_i][1] then
        assert(i <= chunks[c_i][2])
        buffer = buffer..c
        if i == chunks[c_i][2] then
          if #buffer > 0 then
            table.insert(segmented[1], buffer)
            buffer = ""
          end
          c_i = c_i + 1
        end
      else
        table.insert(segmented[1], c)
      end
    end
  elseif mode == "words" then

    -- Reducing the spans of the non splittable chunks
    -- Left to right
    for _, nsc in ipairs(chunks) do
      while not (nsc[1] == 1 or split_str[nsc[1]-1]:sub(-1):match("%s")) do
        nsc[1] = nsc[1] + 1
        if nsc[1] >= nsc[2] then
          break
        end
      end
    end

    -- and right to left
    for _, nsc in ipairs(chunks) do
      while not (nsc[2] == #split_str or split_str[nsc[2]+1]:sub(1, 1):match("%s")) do
        nsc[2] = nsc[2] - 1
        if nsc[1] >= nsc[2] then
          break
        end
      end
    end

    -- Removing empty non splittable chunks
    do
      local chunks_ = chunks
      chunks = {}
      for _, nsc in ipairs(chunks_) do
        if nsc[1] < nsc[2] then
          table.insert(chunks, nsc)
        end
      end
    end

    local buffer = ""
    local c_i = 1
    for i, c in ipairs(split_str) do
      if chunks[c_i] and i >= chunks[c_i][1] then
        assert(i <= chunks[c_i][2])
        buffer = buffer..c
        if i == chunks[c_i][2] then
          if #buffer > 0 then
            table.insert(segmented[1], buffer)
            buffer = ""
          end
          c_i = c_i + 1
        end
      elseif c:match("%s") then
        if #buffer > 0 then
          table.insert(segmented[1], buffer)
          buffer = ""
        end
      else
        buffer = buffer..c
      end
    end
    if #buffer > 0 then
      table.insert(segmented[1], buffer)
    end
  else
    error("constrained_chunk does not work with mode '"..mode.."'")
  end
--  utils.write({ mode = mode, spli_str = split_str, chunks = chunks, result = segmented})
  return segmented
end

-- Transforms the character chunked input into a word chunked output
-- Useful when the input segments do not necessarily have the same length
-- The boolean character_styled can be set to true for character style word segmentation
function _segmentation.group_words(chunked, character_styled)
  assert(type(chunked) == "table")
  assert(type(chunked[1]) == "table")
  assert(chunked.mode == "characters")
  character_styled = character_styled or false
  if character_styled then
    error("character_styled parameter is not considered yet")
  end
  local new_chunked = { [1] = {}, mode = "words"}
  local buffer = ""
  for i, c in ipairs(chunked[1]) do
    if c:match("%s") then
      if #buffer > 0 then
        table.insert(new_chunked, buffer)
        buffer = ""
      end
    else
      buffer = buffer..c
    end
  end
  return new_chunked
end

function _segmentation.chunk_input(...)
  return _segmentation.chunk(input_mode, ...)
end

function _segmentation.chunk_output(...)
  return _segmentation.chunk(output_mode, ...)
end

-- Concatenates the given list of symbols into a string
-- If sep is specified (string), it will be added between segments
function _segmentation.concat(chunked, sep)
  assert(type(chunked) == "table")
  assert(sep == nil or type(sep) == "string")
  assert(#chunked > 0)
  local mode = chunked.mode
  check_mode(mode)
  local str = ""
  local space = sep or modes[mode].sep or ""
  if not space:match("^%s*$") then
    space = space:gsub("^%s*(%S.*)", "%1"):gsub("(.*%S)%s*$", "%1")
    space = " "..space.." "
  end
  assert(type(chunked[1]) == "table")
  for i, item in ipairs(chunked[1]) do
    assert(type(item) == "string")
    if i > 1 then
      str = str..space
    end
    str = str..item
  end
  return str
end


local function preselect_matching_segments(seq1, seq2, output)
  output = output or {}
  local index = {}
  for l=2,#seq1 do
    for i, symbol in ipairs(seq1[l]) do
      index[symbol] = { i, i + l }
    end
  end
  for l=#seq2,2,-1 do
    for i, symbol in ipairs(seq2[l]) do
      local coords = index[symbol]
      if coords then
        local symbols = {}
        for j=1,coords[1]-1 do
          table.insert(symbols, seq1[1][j])
        end
        table.insert(symbols, symbol)
        for j=coords[2],#seq1[1] do
          table.insert(symbols, seq1[1][j])
        end

        local seq1_merged = _segmentation.chunk("symbols_dynamic", symbols)
        local str = utils.tostring(seq1_merged)
        if not output[str] then
          output[str] = { s = seq1_merged, n = utils.table.len(output) }
        else
          assert(utils.deepcompare(output[str].s, seq1_merged))
        end
        if utils.table.len(output) < 10 then
          local symbols = {}
          for j=1,i-1 do
            table.insert(symbols, seq2[1][j])
          end
          table.insert(symbols, symbol)
          for j=i+l,#seq2[1] do
            table.insert(symbols, seq2[1][j])
          end
          local seq2_cut = _segmentation.chunk("symbols_dynamic", symbols)
          preselect_matching_segments(seq1_merged, seq2_cut, output)
        end
        return output
      end
    end
  end
  return { { s = seq1, n = 0 } }
end

function _segmentation.preselect_matching_segments(seq1, seq2)
  error "Function actually in use !"
  local output = {}
  local min = math.huge
  for _, item in pairs(preselect_matching_segments(seq1, seq2)) do
    local size = #item.s[1]
    output[size] = output[size] or {}
    table.insert(output[size], item.s --[[ { s = item.s[1], n = item.n } ]] )
    min = math.min(min, size)
  end
  return output[min]
end

-- Enumerates all the segmentations of the sequences of the given length
local function enumerate_segmentations(sequences, length)
  local size = 0
  local nb = #sequences
  local spaces = {}
  for _, s in ipairs(sequences) do
    size = size + #s[1] - 1
    table.insert(spaces, modes[s.mode].pattern == "%S+" and " " or "")
  end
  assert(type(length) == "number")
  if length < nb then
    error "Cannot split a sequence into 0 segment."
  end
  if length > size + nb then
    return function () return nil end
  end
  local positions
  return function ()
    if positions == nil then
      positions = {}
      for i=1,length-nb do
        table.insert(positions, i)
      end
    else
      local increment = false
      for i=length-nb,1,-1 do
        if (positions[i+1] or size + 1) > positions[i]+1 then
          positions[i] = positions[i] + 1
          for j=i+1,length-nb do
            positions[j] = positions[i] + j - i
          end
          increment = true
          break
        end
      end
      if not increment then
        return nil
      end
    end
    local segmentation = {}
    local cuts = {}
    local total = 0
    local i = 1
    for n, s in ipairs(sequences) do
      seg = { { "" }, mode = s.mode }
      cuts[n] = 0
      local j = 1
      for pos, symbol in ipairs(s[1]) do
        assert(type(symbol == "string"))
        if seg[1][j] == "" then
          seg[1][j] = seg[1][j]..symbol
        else
          seg[1][j] = seg[1][j]..spaces[n]..symbol
        end
        if pos + total == (positions[i] or 0) and pos < #s[1] then
          table.insert(seg[1], "")
          i = i + 1
          j = j + 1
          cuts[n] = cuts[n] + 1
        end
      end
      total = total + #s[1] - 1
      table.insert(segmentation, seg)
    end
    return segmentation, cuts
  end
end

-- Enumerates all the segmentations of the sequences in desc order
-- Important: the parameter MUST be a list of sequences !
function _segmentation.enumerate_segmentations(sequences)
  local length = 0
  local nb = #sequences
  for _, s in ipairs(sequences) do
    length = length + #s[1]
  end
  local f = function () return nil end
  return function ()
    local res = f()
    if res == nil and length >= nb then
      f = enumerate_segmentations(sequences, length)
      length = length - 1
      res = f()
    end
    return res
  end
end

-- Enumerates all the analogy-compliant segmentations in desc order
function _segmentation.enumerate_analogical_segmentations(A, B, C, D)
  local sequences = { A, B, C, D }
  local max_length = 0
  local nb = 4
  local length
  for _, s in ipairs(sequences) do
    max_length = max_length + #s[1]
  end
  local f = function () return nil end
  return function ()
    local res, cuts = f()
    while res == nil or ((cuts[1] ~= cuts[2] or cuts[3] ~= cuts[4]) and (cuts[1] ~= cuts[3] or cuts[2] ~= cuts[4])) do
      if res == nil then
        if (length or (nb - 1)) > max_length then
          return nil
        end
        length = (length or (nb - 1)) + 1
        f = enumerate_segmentations(sequences, length)
      end
      res, cuts = f()
    end
    return res, length
  end
end

local msg_memoized = {}
local msg_activate_memoization = false
-- Takes a list of terminal symbols and builds the aggregation graph of them
-- The index of the aggregated segments is returned in second position
local function make_segmentation_graph(sequence)
  local symbols = sequence[1]
  local space = modes[sequence.mode].pattern == "%S+" and " " or ""

  if msg_activate_memoization then -- If memoization is active, look for a previous computation
    local tmp = msg_memoized[utils.tostring(symbols)]
    if tmp then
      assert(tmp.top, tmp.base, tmp.index)
      tmp = utils.table.deep_copy(tmp)
      return tmp.top, tmp.base, tmp.index
    end
  end

  local index = {}

  local base = nil
  local base_end = nil
  for _, s in ipairs(symbols) do
    local struct_seg = { segment = s, next = nil }
    index[s] = index[s] or {}
    index[s][struct_seg] = true
    if base_end == nil then
      base = struct_seg
      base_end = base
    else
      assert(base_end.next == nil)
      base_end.next = struct_seg
      base_end = base_end.next
    end
  end

  local top = base -- starting from top = base
  while top.next ~= nil do -- until top has no next
    local new = nil
    local new_end = nil

    local current = top
    while current.next ~= nil do  -- iterate over the links
      local to_add = current
      while to_add.right do
        to_add = to_add.right
      end
      to_add = to_add.next  -- get the next of the rightmost element of current
      local s = current.segment..space..to_add.segment -- compose the new segment by appending the next rightmost terminal to current
      local struct_seg = { segment = s, next = nil, left = current, right = current.next }
      index[s] = index[s] or {}
      index[s][struct_seg] = true
      if new_end == nil then
        new = struct_seg
        new_end = new
      else
        new_end.next = struct_seg
        new_end = new_end.next
      end
      current.top_right     = new_end
      current.next.top_left = new_end
      current = current.next
      top = new
    end
  end
  if msg_activate_memoization then
    msg_memoized[utils.tostring(symbols)] = { top = top, base = base, index = index }
  end
  return top, base, index
end

----------------------------------------------------------------------------
-- Below are defined functions linked to enumerate_segmentations_list
----------------------------------------------------------------------------

-- Returns a linked list of the segments in seq (which is a base of segmentation graph)
local function create_sequence(seq)
  local new_s = nil
  local new_s_end = nil
  local link  = seq
  while link do
    if not new_s_end then
      new_s = { link = link }
      new_s_end = new_s
    else
      new_s_end.next = { link = link }
      new_s_end = new_s_end.next
    end
    link = link.next
  end
  return new_s
end

-- Updates the sequence_list to include the segment seg
-- Returns the updated list and index or false if the segment cannot be found
local function update_sequence_list(sequence_list, index, seg)
  do
    -- Copying the index structure
    local old_index = index
    index = {}
    for segment, links in pairs(old_index) do
      local map = {}
      for link, val in pairs(links) do
        assert(val == true)
        map[link] = true
      end
      index[segment] = map
    end

    -- Copying the sequence_list structure
    local old_sequence_list = sequence_list
    sequence_list = {}
    for _, s in ipairs(old_sequence_list) do
      local new = { link = s.link, source = s.source }
      local new_end = new
      local item = s.next
      while item do 
        new_end.next = { link = item.link, source = item.source }
        new_end = new_end.next
        item = item.next
      end
      table.insert(sequence_list, new)
    end
  end

  index[seg.segment][seg] = nil

  local start = seg
  local stop  = seg

  -- Establishing start and stop in the terminal subsegments of seg
  while start.left do
    start = start.left
  end
  while stop.right do
    stop = stop.right
  end

  -- Updating the parallel segment sequences (to merge subsegments into seg)
  local pending = { link = seg, source = true } -- source means the frontiers of this segment are real (cannot be merged)
  local witness = 0
  for j, s in ipairs(sequence_list) do -- for each listed sequence
    local meta_link = s
    if s.link == start then -- if its link is the start of the segment
      sequence_list[j] = pending -- replacing the first item
      witness = witness + 1 -- and end this step
    else
      while meta_link.next do 
        if meta_link.next.link == start then -- if the next of meta_link is start
          assert(witness == 0)
          local tmp = meta_link
          meta_link = meta_link.next
          tmp.next = pending -- replace with the merged segment
          witness = 1 -- and end this step
          break
        else
          meta_link = meta_link.next
        end
      end
    end
    while meta_link do
      if meta_link.link == stop then
        assert(witness == 1)
        pending.next = meta_link.next
        witness = 2
      end
      meta_link = meta_link.next
    end
    assert(witness ~= 1)
  end
  assert(witness == 2)

  -- Removing the subsegments of seg from the index
  while start.top_left or start.top_right do
    assert(stop.top_right or stop.top_left)
    local current = start
    while current ~= stop.next do
      index[current.segment][current] = nil
      current = current.next
    end
    start = start.top_left or start.top_right
    stop  = stop.top_right or stop.top_left
  end
  assert(start == stop)
  index[start.segment][start] = nil
  
  return sequence_list, index
end

-- mappings, to_split and seg_i are only recursive parameters
local function find_segments(segment_list, index, sequence_list, mappings, to_split, seg_i)
  if not seg_i then
    -- sequence_list is initially the list of bases of the sequences' segmentation graphs
    -- it is transformed below into the linked list of the links to the used segments, see create_sequence()
    local input_sequence_list = sequence_list
    sequence_list = {}
    for _, seq in ipairs(input_sequence_list) do
      table.insert(sequence_list, create_sequence(seq))
    end
  end

  local mappings = mappings or {} -- set of results to be returned
  local to_split = to_split or {} -- set of indexes of invalid segments found
  local seg_i = seg_i or 1

  local segment = segment_list[seg_i].segment -- select a segment
  local l = index[segment] or {}  -- search for it in index

  -- If there is no entry of the segment in the index, the segmentation is invalid
  if utils.table.len(l) == 0 then
    to_split[seg_i] = true
  else
    for seg, _ in pairs(l) do
      local new_sequence_list, new_index = update_sequence_list(sequence_list, index, seg)
      assert(new_sequence_list)

      if seg_i < #segment_list then
        find_segments(segment_list, new_index, new_sequence_list, mappings, to_split, seg_i + 1)
      else
        table.insert(mappings, { sequence_list = new_sequence_list})
      end
    end
  end
  return mappings, to_split
end

-- Enumerates the segmentations of the sequence more efficiently thanks to the list of target sequences provided
-- The opposite sequence is optional, if provided, the returned function will output a third item for the segmented opposite
-- max_segments specifies the maximum number of segments for sequence to be divided in
local time = 0
function _segmentation.enumerate_segmentations_list(sequence, list, opposite, max_segments)
  local tmp_time = utils.time()
  local space = modes[sequence.mode].pattern == "%S+" and " " or ""
  local max_segments = max_segments or math.huge

  local sequence_top, sequence_base, _ = make_segmentation_graph(sequence) -- Links for the segmentation graph
  local list_index  = {}  -- Index of the segments in the sequences from the list
  local list_bases  = {}  -- Base link for the segmentation graph of each sequence in the list
  local list_spaces = {}  -- Character to be inserted between segments for each sequence in the list

  -- Make segmentation graphs for all sequences in the list
  for i, s in ipairs(list) do
    table.insert(list_spaces, modes[s.mode].pattern == "%S+" and " " or "")
    local _, base, index = make_segmentation_graph(s)
    for segment_txt, links in pairs(index) do
      local sublist = list_index[segment_txt] or {}
      for link, _ in pairs(links) do
        assert(not sublist[link])
        sublist[link] = true
      end
      list_index[segment_txt] = sublist
    end
    table.insert(list_bases, base)
  end

  local opposite_base, opposite_index
  if opposite then
    local _, base, index = make_segmentation_graph(opposite)
    opposite_base = base
    opposite_index = {}
    for segment_txt, links in pairs(index) do
      local new_links = {}
      for l, _ in pairs(links) do
        new_links[l] = true
      end
      opposite_index[segment_txt] = new_links
    end
  end

  local segmentations = { segment_list = { sequence_top }, next = nil } -- Queue of segmentations to be examined
  local segmentations_last = segmentations  -- End of queue

  local mappings = {}
  local output

  return function ()
    local valid = false
    local result_list, result_opposite

    while not valid do
      valid = true

      while #mappings == 0 do
        if segmentations == nil then
          return nil  -- No more segmentation to make nor return
        end
        local to_split
        mappings, to_split = find_segments(segmentations.segment_list, list_index, list_bases) -- Looking for a valid set of segments 
        if #segmentations.segment_list < max_segments then
          for splt, _ in pairs(to_split) do  -- for each segment to be subdivided
            assert(type(splt) == "number") -- splt is the index of a segment not found
            
            local top_down_left = segmentations.segment_list[splt].left
            local bottom_up_right = segmentations.segment_list[splt]
            while bottom_up_right.right do  -- Finding the "right"most segment in the graph
              bottom_up_right = bottom_up_right.right
            end
            while top_down_left do
              assert(top_down_left.segment..space..bottom_up_right.segment == segmentations.segment_list[splt].segment)
              local s_l = {}
              for i=1,splt-1 do -- add all the segments before the one to split
                table.insert(s_l, segmentations.segment_list[i])
              end
              table.insert(s_l, top_down_left) -- the first chunk
              table.insert(s_l, bottom_up_right) -- the second one
              for i=splt+1,#segmentations.segment_list do -- then all the segments after the one splitted
                table.insert(s_l, segmentations.segment_list[i])
              end
              segmentations_last.next = { segment_list = s_l, next = nil }
              segmentations_last = segmentations_last.next
              top_down_left = top_down_left.left
              bottom_up_right = bottom_up_right.top_left
            end
          end
        end
        local s = segmentations
        output = { {}, mode = sequence.mode }
        for _, item in ipairs(s.segment_list) do
          table.insert(output[1], item.segment)
        end
        segmentations = segmentations.next
      end
      
      local m = mappings[#mappings]
      mappings[#mappings] = nil
      local sequence_list = m.sequence_list
      
      local opposite_segments = {}

      result_list = {}
      for i, s in ipairs(sequence_list) do

        local result = { {}, mode = list[i].mode }
        local source = true
        local meta_link = s
        while meta_link do
          if meta_link.source == true then

            -- if opposite is provided and we just finished merging a segment
            if opposite and source == false then
              table.insert(opposite_segments, { segment = result[1][#result[1]] } ) -- inserting a segment-shaped item for the needs of the function
            end

            table.insert(result[1], meta_link.link.segment)
            source = true
          elseif source == true then
            table.insert(result[1], meta_link.link.segment)
            source = false
          else
            result[1][#result[1]] = result[1][#result[1]]..list_spaces[i]..meta_link.link.segment
          end
          meta_link = meta_link.next
        end
        if opposite and source == false then
          table.insert(opposite_segments, { segment = result[1][#result[1]] } )
        end

        table.insert(result_list, result)
      end

      if opposite then

        local opposite_mapping, opposite_to_split = find_segments(opposite_segments, opposite_index, {opposite_base})
        if #opposite_mapping > 0 then
--          assert(utils.table.len(opposite_to_split) == 0)

          result_opposite = {{}}
          result_opposite.mode = opposite.mode
          local item = opposite_mapping[1].sequence_list[1]  -- Only the first mapping is used, TODO how to use the whole list in order to precompute analogies ?
          while item do
            table.insert(result_opposite[1], item.link.segment)
            item = item.next
          end
        else
          valid = false
        end
      end
    end

    -- TODO fix the duplicate outputs
    return output, result_list, result_opposite
  end
end

return _segmentation
