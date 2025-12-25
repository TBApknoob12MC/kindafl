local kfl = require('compiler')
local comp = kfl:new()
if arg[1] == "c" then
  if arg[2] and arg[3] then
    local inp, err = io.open(arg[2], 'r')
    if not inp then error("error opening source file: "..err) ; return end
    local pp = comp:preprocess(inp:read('*a'))
    inp:close()
    local lua_code = comp:tcode(pp)
    local out = io.open(arg[3], "w")
    out:write(lua_code)
    out:close()
  else
    io.write("please provide both source and output file.")
  end
elseif arg[1] == "r" then
  dbg = false
  if arg[2] then
    local inp, err= io.open(arg[2], 'r')
    if not inp then error("error opening source file: "..err) ; return end
    local pp = comp:preprocess(inp:read('*a'))
    inp:close()
    local lua_code = comp:tcode(pp)
    local chunk, err = load(lua_code)
    if chunk then 
      local status, runtime_err = pcall(chunk)
      if status then 
        if type(d) == "function" then d() end
      else print("runtime error: "..tostring(runtime_err)) end
    else print("error in compiled code: "..tostring(err)) end
  end
  while true do
    local repl_inp = io.read()
    if repl_inp == "q" then break 
    elseif repl_inp == "dbg" then dbg = not dbg
    elseif repl_inp == "clr" then stack = {}
    else
      local pp = comp:preprocess(repl_inp)
      local lua_code = comp:tcode(pp)
      if dbg then print(lua_code) end
      local chunk, err = load(lua_code)
      if chunk then
        local status, runtime_err = pcall(chunk)
        if status then
        if type(d) == "function" then d() end
        else print("runtime error: "..tostring(runtime_err)) end
      else print("error in compiled code: "..tostring(err))
      end
    end
  end
else
  print([[
  kindaforthless cli:
      c -> compile source to lua :
        <kindafl> c <input.kindafl> <output.kindafl>
      r -> kindafl read-eval-print-loop (can take a file as an entry):
        <kindafl> r <optional_entry.kindafl>
        
  my language is kinda forth less *speed face*
  ]])
end
