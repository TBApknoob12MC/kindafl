local state, str_acc, lib_acc , imported_modules, export, init_code = "statement", "", "", {}, {}, [[
stack, mem, lib = {}, {}, {}
function dump(do_mem)
  local iter,tbl ,init ; if do_mem then iter,tbl,init = pairs(mem) else iter,tbl,init = ipairs(stack) end
  local acc = {} ; for k,v in iter,tbl,init do if do_mem then table.insert(acc,tostring(k).." : "..tostring(v).." ") else table.insert(acc,tostring(v).." ") end end
  table.insert(stack,table.concat(acc)) end
function d() dump(false); print('stack: '..table.remove(stack)) end
function m() dump(true); print('mem: '..table.remove(stack)) end

]]
local function preprocess(code)
  local output = {}
  local i = 1
  while i <= #code do
    if code:sub(i,i+1) == 'm"' then
      i = i + 2
      local modname = ""
      while i <= #code and code:sub(i,i) ~= '"' do
        modname = modname .. code:sub(i,i)
        i = i + 1 end
      i = i + 1
      if not imported_modules[modname] then
        imported_modules[modname] = true
        local f, err = io.open(modname..'.kindafl','r')
        if not f then error("Module "..modname.." not found: "..err) end
        local modcode = f:read("*a") ; f:close()
        modcode = preprocess(modcode)
        table.insert(output, modcode) end
    elseif code:sub(i,i+1) == 'c"' then
      i = i + 2
      while i <= #code and code:sub(i,i) ~= '"' do
        i = i + 1 end
      table.insert(output,"")
    else
      table.insert(output, code:sub(i,i))
      i = i + 1 end end
    return table.concat(output)
end
local function tstatement(cur)
  local actions = {
    ["+"] = "table.insert(stack, table.remove(stack) + table.remove(stack))",
    ["-"] = "table.insert(stack, table.remove(stack) - table.remove(stack))",
    ["*"] = "table.insert(stack, table.remove(stack) * table.remove(stack))",
    ["/"] = "table.insert(stack, table.remove(stack) / table.remove(stack))",
    ["="] = "table.insert(stack, table.remove(stack) == table.remove(stack))",
    [">"] = "table.insert(stack, table.remove(stack) > table.remove(stack))",
    ["<"] = "table.insert(stack, table.remove(stack) < table.remove(stack))",
    ["and"] = "table.insert(stack, table.remove(stack) and table.remove(stack))",
    ["or"] = "table.insert(stack, table.remove(stack) or table.remove(stack))",
    ["not"] = "table.insert(stack, not table.remove(stack))",
    ["."] = "print(table.remove(stack))",
    ["dump"] = "dump(false)", ["mem"] = "dump(true)",
    ["dup"] = "table.insert(stack, stack[#stack])",
    ["swap"] = "local x, y = table.remove(stack), table.remove(stack)\ntable.insert(stack, x)\ntable.insert(stack, y)",
    ["drop"] = "table.remove(stack)",
    ["do"] = "for i = table.remove(stack), table.remove(stack) - 1 do", ["i"] = "table.insert(stack, i)",
    ["if"] = "if table.remove(stack) == true then", ["else"] = "else",
    ["!"] = "mem[table.remove(stack)] = table.remove(stack)",
    ["@"] = "table.insert(stack, mem[table.remove(stack)])",
    [":"] = "function ", [";"] = "end", ["\""] = "",
    ["io_read"] = "local r = io.open(table.remove(stack):match('%S+'),'r')\ntable.insert(stack,r:read(table.remove(stack):match('%S+')))\nr:close()",
    ["io_write"] = "local w = io.open(table.remove(stack):match('%S+'),'w')\nw:write(table.remove(stack))\nw:close()",
    ["inp"] = "table.insert(stack,io.read())",
    ["cat"] = "table.insert(stack,table.concat({tostring(table.remove(stack)),tostring(table.remove(stack))}))",
    ["rl"] = "load(table.remove(stack))()" }
  if state == "statement" then
    if actions[cur] then return actions[cur] .. "\n" end
    if cur ==  "s\"" then state = "string"; return "" end
    if cur == "l\"" then state = "lod" ; return "" end
    if tonumber(cur) then return "table.insert(stack, "..tonumber(cur)..")\n" 
    else return cur.."()\n" end
  elseif state == "string" then
    if cur == "\"" then
      local tmp = str_acc ; str_acc = "" ;state = "statement" 
      return "table.insert(stack, \""..tmp.."\")\n" end
    str_acc = str_acc .." "..cur
    return ""
  elseif state == "lod" then
    if cur == "\"" then
      local tmp = lib_acc ; lib_acc = "" ; state = "statement"
      local f = io.open(tmp,'r') ; local dat = f:read('*a') ; f:close() ; return dat.."\n" end
    lib_acc = lib_acc..cur ; return "" end
end
local function tline(line)
  local ret_val = {}
  for v in string.gmatch(line, '%S+') do table.insert(ret_val, tstatement(v)) end
  return table.concat(ret_val)
end
local function tcode(str)
  local ret_val = {}
  for line in string.gmatch(str, '[^\n]+') do table.insert(ret_val, tline(line)) end
  return table.concat(ret_val)
end
local function compile(c)
  return table.concat({init_code, tcode(c)})
end
if arg[1] == "c" then
  if arg[2] and arg[3] then
    local inp = io.open(arg[2],'r') ; local pp = preprocess(inp:read('*a')) ; inp:close()
    local lua_code = compile(pp) ; local out = io.open(arg[3],"w") ; out:write(lua_code) ; out:close()
  else io.write("please provide both source and output file.") end
elseif arg[1] == "r" then
  print(init_code)
  load(init_code)()
  if arg[2] then
    local inp = io.open(arg[2],'r') ; local pp = preprocess(inp:read('*a')) ; inp:close()
    local lua_code = tcode(pp) ;print(lua_code); load(lua_code)() end
  while true do
    local repl_inp = io.read() ; if repl_inp == "q" then break end
    local pp = preprocess(repl_inp) ; local lua_code = tcode(pp) ; print(lua_code); load(lua_code)() ; load('d()')() end
else print("kindaforthless compiler/repl:\n\tc -> compile source to lua :\n\t\t<kindafl> c <input.kindafl> <output.kindafl>\n\tr -> kindafl read-eval-print-loop (can take a file as an entry):\n\t\t<kindafl> r <optional_entry.kindafl>\n\nmy language is kinda forth less *speed face*") end
export.init_code = init_code ; function export.preprocess(str) return preprocess(str) end ; function export.comp(s) return tcode(s) end ; return export