-- Beamer stores each frame body as a macro argument and typesets it later,
-- so SyncTeX stamps every glyph with the line of \end{frame}.
-- Frames are re-read from a temporary file (the fragile path). This module
-- pads that file with comments so its line numbers match the source, then
-- points the SyncTeX records at the .tex file.

labslide_sx = labslide_sx or {}

function labslide_sx.outpath(name)
  local dir = status.output_directory
  if type(dir) == "string" and dir ~= "" then
    if dir:sub(-1) == "/" then
      return dir .. name
    end
    return dir .. "/" .. name
  end
  return name
end

function labslide_sx.add_fragile()
  local s = token.get_macro("labslide@opts") or ""
  local i = s:find("]", 1, true)
  if not i then
    s = s .. "[fragile]"
  else
    s = s:sub(1, i - 1) .. ",fragile" .. s:sub(i)
  end
  token.set_macro("beamer@frameoptions", s, "global")
end

function labslide_sx.on_begin()
  labslide_sx.begin_line = tex.inputlineno
  labslide_sx.tag = tex.get_synctex_tag()
  if labslide_sx.begin_line and labslide_sx.begin_line > 0 then
    tex.setcount("global", "labslide@sxline", labslide_sx.begin_line)
  end
end

function labslide_sx.pad_file()
  local path = labslide_sx.outpath(tex.jobname .. ".sx.vrb")
  local f = io.open(path, "rb")
  if not f then
    texio.write_nl("labslide synctex: missing " .. path)
    return
  end
  local body = f:read("*a")
  f:close()
  if not body or body == "" then
    return
  end
  -- on_begin's inputlineno is already the line where the first verbatim
  -- line belongs: the \begin{frame} line when a title was written into the
  -- file, or the first body line when beamer has read past a title-less begin.
  local begin_line = labslide_sx.begin_line or 1
  local target = begin_line
  if target < 1 then
    target = 1
  end
  local chunks = {}
  for i = 1, target - 1 do
    chunks[i] = "%\n"
  end
  chunks[#chunks + 1] = body
  if not body:match("\n$") then
    chunks[#chunks + 1] = "\n"
  end
  local g = io.open(path, "wb")
  if not g then
    texio.write_nl("labslide synctex: cannot rewrite " .. path)
    return
  end
  g:write(table.concat(chunks))
  g:close()
end

local function normalize_input_path(path)
  return (path:gsub("/+%./", "/"))
end

local function retarget_input_lines(data)
  local main = data:match("Input:%d+:([^\n]*" .. tex.jobname .. "%.tex)")
  if not main then
    return data, false
  end
  main = normalize_input_path(main)
  local changed = false
  local out = data:gsub("(Input:%d+:)([^\n]+)", function(prefix, path)
    local orig = path
    if path:find(".sx.vrb", 1, true) or path:find(".sxtitle.vrb", 1, true) then
      path = main
    end
    path = normalize_input_path(path)
    if path ~= orig then
      changed = true
    end
    return prefix .. path
  end)
  return out, changed
end

function labslide_sx.finish()
  local gzpath = labslide_sx.outpath(tex.jobname .. ".synctex.gz")
  local ok, gzip = pcall(require, "gzip")
  if ok and gzip then
    local r = gzip.open(gzpath, "rb")
    if r then
      local data = r:read("*a")
      r:close()
      if data then
        local out, changed = retarget_input_lines(data)
        if changed then
          local w = gzip.open(gzpath, "wb")
          if w then
            w:write(out)
            w:close()
          end
        end
      end
    end
  end
  for _, name in ipairs({tex.jobname .. ".sx.vrb", tex.jobname .. ".sxtitle.vrb"}) do
    pcall(os.remove, labslide_sx.outpath(name))
  end
end

luatexbase.add_to_callback("process_input_buffer", function(line)
  local name = status.filename or ""
  if labslide_sx.tag and (name:find(".sx.vrb", 1, true) or name:find(".sxtitle.vrb", 1, true)) then
    tex.set_synctex_tag(labslide_sx.tag)
    tex.force_synctex_tag(labslide_sx.tag)
  end
  return line
end, "labslide_synctex")

luatexbase.add_to_callback("wrapup_run", function()
  labslide_sx.finish()
end, "labslide_synctex_finish")
