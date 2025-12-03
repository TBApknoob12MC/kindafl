local state, str_acc, lib_acc, imported_modules, export = "statement", "", "", {}, {}
local function preprocess(code)
  local output = {}
  local i = 1
  while i <= #code do
    if code:sub(i, i+1) == 'm"' then
      i = i + 2
      local modname = ""
      while i <= #code and code:sub(i, i) ~= '"' do
        modname = modname .. code:sub(i, i)
        i = i + 1
      end
      i = i + 1
      if not imported_modules[modname] then
        imported_modules[modname] = true
        local f, err = io.open(modname..'.kindafl','r')
        if not f then error("Module "..modname.." not found: "..err) end
        local modcode = f:read("*a")
        f:close()
        modcode = preprocess(modcode)
        table.insert(output, modcode)
      end
    elseif code:sub(i, i+1) == 'c"' then
      i = i + 2
      while i <= #code and code:sub(i, i) ~= '"' do
        i = i + 1
      end
      table.insert(output, "")
    else
      table.insert(output, code:sub(i, i))
      i = i + 1
    end
  end
  return table.concat(output)
end

local function tstatement(cur)
  local actions = {
    ["+"] = "push(stack, pop(stack) + pop(stack))",
    ["-"] = "push(stack, pop(stack) - pop(stack))",
    ["*"] = "push(stack, pop(stack) * pop(stack))",
    ["/"] = "push(stack, pop(stack) / pop(stack))",
    ["="] = "push(stack, pop(stack) == pop(stack))",
    [">"] = "push(stack, pop(stack) > pop(stack))",
    ["<"] = "push(stack, pop(stack) < pop(stack))",
    ["and"] = "push(stack, pop(stack) and pop(stack))",
    ["or"] = "push(stack, pop(stack) or pop(stack))",
    ["not"] = "push(stack, not pop(stack))",
    ["."] = "print(pop(stack))",
    ["dump"] = "dump(false)",
    ["mem"] = "dump(true)",
    ["dup"] = "push(stack, stack[#stack])",
    ["swap"] = "local x, y = pop(stack), pop(stack)\npush(stack, x)\npush(stack, y)",
    ["drop"] = "pop(stack)",
    ["do"] = "for i = pop(stack), pop(stack) - 1 do",
    ["i"] = "push(stack, i)",
    ["if"] = "if pop(stack) == true then",
    ["else"] = "else",
    ["!"] = "mem[pop(stack)] = pop(stack)",
    ["@"] = "push(stack, mem[pop(stack)])",
    [":"] = "function ",
    [";"] = "end",
    ["\""] = "",
    ["read"] = "local r = io.open(pop(stack),'r')\npush(stack,r:read('*a'))\nr:close()",
    ["write"] = "local w = io.open(pop(stack),'w')\nw:write(pop(stack))\nw:close()",
    ["inp"] = "push(stack,io.read())",
    ["cat"] = "push(stack,table.concat({tostring(pop(stack)),tostring(pop(stack))}))",
    ["match"] = "push(stack,pop(stack):match(pop(stack)))",
    ["rl"] = "load(pop(stack))()"
  }
  
  if state == "statement" then
    if actions[cur] then return actions[cur] .. "\n" end
    if cur == 's"' then
      state = "string"
      return ""
    end
    if cur == 'l"' then
      state = "lod"
      return ""
    end
    if tonumber(cur) then
      return "push(stack, "..tonumber(cur)..")\n"
    else
      return cur.."()\n"
    end
  elseif state == "string" then
    if cur == "\"" then
      local tmp = str_acc
      str_acc = ""
      state = "statement"
      return "push(stack, \""..tmp:gsub("^ ", "").."\")\n"
    end
    str_acc = str_acc .." "..cur
    return ""
  elseif state == "lod" then
    if cur == "\"" then
      local tmp = lib_acc:gsub("^ ", "")
      lib_acc = ""
      state = "statement"
      local f = io.open(tmp..".lua", 'r')
      local dat = f:read('*a')
      f:close()
      return dat.."\n"
    end
    lib_acc = lib_acc.." "..cur
    return ""
  end
end

local function tcode(str)
  local ret_val = {}
  local line_ret = {}
  for line in string.gmatch(str, '[^\n]+') do
    for v in string.gmatch(line, '%S+') do
      table.insert(line_ret, tstatement(v))
    end
    table.insert(ret_val,table.concat(line_ret))
    line_ret = {}
  end
  return table.concat(ret_val)
end

if arg[1] == "c" then
  if arg[2] and arg[3] then
    local inp = io.open(arg[2], 'r')
    local pp = preprocess(inp:read('*a'))
    inp:close()
    local lua_code = tcode(pp)
    local out = io.open(arg[3], "w")
    out:write(lua_code)
    out:close()
  else
    io.write("please provide both source and output file.")
  end
elseif arg[1] == "p" then
  if arg[2] and arg[3] then
    local inp = io.open(arg[2], 'r')
    local pp = preprocess(inp:read('*a'))
    inp:close()
    local out = io.open(arg[3], "w")
    out:write(pp)
    out:close()
  else
    io.write("please provide both source and output file.")
  end
elseif arg[1] == "r" then
  if arg[2] then
    local inp = io.open(arg[2], 'r')
    local pp = preprocess(inp:read('*a'))
    inp:close()
    local lua_code = tcode(pp)
    print(lua_code)
    load(lua_code)()
  end
  while true do
    local repl_inp = io.read()
    if repl_inp == "q" then break end
    local pp = preprocess(repl_inp)
    local lua_code = tcode(pp)
    print(lua_code)
    load(lua_code)()
    load('d()')()
  end
else
  print([[
  kindaforthless compiler/repl:
      p -> preprocess source:
        <kindafl> input.kindafl> <output.kindafl> 
      c -> compile source to lua :
        <kindafl> c <input.kindafl> <output.kindafl>
      r -> kindafl read-eval-print-loop (can take a file as an entry):
        <kindafl> r <optional_entry.kindafl>
        
  my language is kinda forth less *speed face*
  ]])
end

function export.preprocess(str)
  return preprocess(str)
end

function export.comp(s)
  return tcode(s)
end

return export
