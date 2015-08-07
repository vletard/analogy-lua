local _segmentation = {
  chunk_pattern =
-- "%S+%s*"  -- words including spaces
   "%S+"     -- words
-- "."       -- characters
}

local mode = "words"
local modes = {
  ["words"]              = { dynamic = false, pattern = "%S+"    },
  ["words+spaces"]       = { dynamic = false, pattern = "%S+%s*" },
  ["characters"]         = { dynamic = false, pattern = "."      },
  ["words_dynamic"]      = { dynamic =  true, pattern = "%S+"    },
  ["characters_dynamic"] = { dynamic =  true, pattern = "."      },
}

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
function _segmentation.chunk(...)
  local segmented = {}
  for _, item in ipairs(table.pack(...)) do
    assert(type(item) == "string")
    local item_segmented = {}
    for s in item:gmatch(modes[mode].pattern) do
      table.insert(item_segmented, s)
    end
    local size = #item_segmented
    if modes[mode].dynamic then
      local segments = {}
      for length=1,#item_segmented do
        for position=1,#item_segmented-(length-1) do
          local segment = ""
          for i=position,position+length-1 do
            segment = segment..item_segmented[i]
          end
          table.insert(segments, segment)
        end
      end
      item_segmented = segments
    end
    item_segmented.size = size
    table.insert(segmented, item_segmented)
  end
  if #segmented == 1 then
    return segmented[1]
  else
    return segmented
  end
end

-- Concatenates the given list of symbols into a string
function _segmentation.concat(chunked)
  assert(type(chunked) == "table")
  assert(#chunked > 0)
  local str = ""
  local add_spaces = (modes[mode].pattern == "%S+")
  for i=1,chunked.size do
    local item = chunked[i]
    assert(type(item) == "string")
    if add_spaces and i > 1 then
      str = str.." "
    end
    str = str..item
  end
  return str
end

return _segmentation
