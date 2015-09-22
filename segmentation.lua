local _segmentation = {
}

local mode = "words"
local modes = {
  ["words"]              = { dynamic = false, pattern = "%S+"    },
  ["words+spaces"]       = { dynamic = false, pattern = "%S+%s*" },
  ["characters"]         = { dynamic = false, pattern = "."      },
  ["words_dynamic"]      = { dynamic =  true, pattern = "%S+"    },
  ["characters_dynamic"] = { dynamic =  true, pattern = "."      },
  ["symbols_dynamic"]    = { dynamic =  true }
}

_segmentation.dynamic = false

function _segmentation.set_mode(new_mode)
  if not modes[new_mode] then
    local mode_str = ""
    for m, _ in pairs(legal_modes) do
      if mode_str ~= "" then
        mode_str = mode_str..", "
      end
      mode_str = mode_str.."'"..m.."'"
    end
    error("Illegal mode '"..new_mode.."'. Legal modes are: "..mode_str)
  end
  mode = new_mode
end

-- Segmenting the given character strings and returns a table of the results.
-- If only one string is passed, directly returns the sequence of symbols (rather than the list of sequences)
function _segmentation.chunk(mode, ...)
  assert(modes[mode])
  local segmented = {}
  for _, item in ipairs(table.pack(...)) do
    assert(type(item) == "string" or mode == "symbols_dynamic")
    local item_segmented = { [1] = {} }
    if mode == "symbols_dynamic" then
      item_segmented[1] = utils.table.deep_copy(item)
    else
      for s in item:gmatch(modes[mode].pattern) do
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

function _segmentation.chunk_NL(...)
  return _segmentation.chunk(mode, ...)
end

function _segmentation.chunk_FL(...)
  return _segmentation.chunk("words", ...)
end

-- Concatenates the given list of symbols into a string
-- If sep is specified (string), it will be added between segments
function _segmentation.concat(chunked, sep)
  assert(type(chunked) == "table")
  assert(sep == nil or type(sep) == "string")
  assert(#chunked > 0)
  local mode = chunked.mode
  assert(modes[mode])
  local str = ""
  local space = sep or ((modes[mode].pattern == "%S+") and " " or "")
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
--  error "Function actually in use !"
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

  if msg_activate_memoization then
    local tmp = msg_memoized[utils.tostring(symbols)]
    if tmp then
      assert(tmp.top, tmp.base, tmp.index)
      return tmp.top, tmp.base, tmp.index
    end
  end

  local index = {}

  local base = nil
  local base_end = nil
  for _, s in ipairs(symbols) do
    index[s] = { segment = s, next = nil }
    if base_end == nil then
      base = index[s]
      base_end = base
    else
      assert(base_end.next == nil)
      base_end.next = index[s]
      base_end = base_end.next
    end
  end

  local top = base
  while top.next ~= nil do
    local new = nil
    local new_end = nil

    local current = top
    while current.next ~= nil do
      local to_add = current
      while to_add.right do
        to_add = to_add.right
      end
      to_add = to_add.next
      local s = current.segment..space..to_add.segment
      index[s] = { segment = s, next = nil, left = current, right = current.next }
      if new_end == nil then
        new = index[s]
        new_end = new
      else
        new_end.next = index[s]
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

-- Enumerates the segmentations of the sequence more efficiently thanks to the list of target sequences provided
function _segmentation.enumerate_segmentations_list(sequence, list)
  local space = modes[sequence.mode].pattern == "%S+" and " " or ""

  local sequence_top, sequence_base, sequence_index = make_segmentation_graph(sequence)
  local list_index  = {}
  local list_bases  = {}
  local list_spaces = {}

  for i, s in ipairs(list) do
    table.insert(list_spaces, modes[s.mode].pattern == "%S+" and " " or "")
    local _, base, index = make_segmentation_graph(s)
    for segment, link in pairs(index) do
      local sublist = list_index[segment] or {}
      assert(not sublist[link])
      sublist[link] = true
      list_index[segment] = sublist
    end
    table.insert(list_bases, base)
  end

  local segmentations = { segment_list = { sequence_top }, next = nil }
  local segmentations_last = segmentations

  local function find_segments(segment_list, index, sequence_list)
    do
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
      
      local old_sequence_list = sequence_list
      sequence_list = {}
      for _, s in ipairs(old_sequence_list) do
        local new_s = nil
        local new_s_end = nil
        local link  = s
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
        table.insert(sequence_list, new_s)
      end
    end

    -- Checking each segment of the submitted list
    for i, segment_box in ipairs(segment_list) do
      local segment = segment_box.segment
      local l = index[segment] or {}

      -- If there is no entry of the segment in the index, the segmentation is invalid
      if utils.table.len(l) == 0 then
        return false, false, i
      else
        local seg = next(l)
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
        local pending = { link = seg, source = true }
        local witness = 0
        for j, s in ipairs(sequence_list) do
          local meta_link = s
          if s.link == start then
            sequence_list[j] = pending
            witness = witness + 1
          else
            while meta_link.next do
              if meta_link.next.link == start then
                assert(witness == 0)
                local tmp = meta_link
                meta_link = meta_link.next
                tmp.next = pending
                witness = 1
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
      end
    end
    return index, sequence_list
  end

  return function ()
    if segmentations == nil then
      return nil
    end
    local index, sequence_list, to_split = find_segments(segmentations.segment_list, list_index, list_bases)
    while not index do
      assert(type(to_split) == "number")

      local top_down_left = segmentations.segment_list[to_split].left
      local bottom_up_right = segmentations.segment_list[to_split]
      while bottom_up_right.right do
        bottom_up_right = bottom_up_right.right
      end
      while top_down_left do
        assert(top_down_left.segment..space..bottom_up_right.segment == segmentations.segment_list[to_split].segment)
        local s_l = {}
        for i=1,to_split-1 do
          table.insert(s_l, segmentations.segment_list[i])
        end
        table.insert(s_l, top_down_left)
        table.insert(s_l, bottom_up_right)
        for i=to_split+1,#segmentations.segment_list do
          table.insert(s_l, segmentations.segment_list[i])
        end
        segmentations_last.next = { segment_list = s_l, next = nil }
        segmentations_last = segmentations_last.next
        top_down_left = top_down_left.left
        bottom_up_right = bottom_up_right.top_left
      end
      segmentations = segmentations.next
      if not segmentations then
        return nil
      end
      assert(type(segmentations.segment_list) == "table")
      index, sequence_list, to_split = find_segments(segmentations.segment_list, list_index, list_bases)
    end
    local s = segmentations
    segmentations = segmentations.next
    local output = { {}, mode = sequence.mode }
    for _, item in ipairs(s.segment_list) do
      table.insert(output[1], item.segment)
    end
    
    local result_list = {}
    for i, meta_link in ipairs(sequence_list) do
      local result = { {}, mode = list[i].mode }
      local source = true
      while meta_link do
        if meta_link.source == true then
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
      table.insert(result_list, result)
    end
    return output, result_list
  end
end

return _segmentation
