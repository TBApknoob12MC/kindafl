local compiler = {}
compiler.__index = compiler
function compiler.new() return setmetatable({state = "statement", str_acc = "", lib_acc = "", imported_modules = {}},compiler) end
function compiler:preprocess(code)
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
      if not self.imported_modules[modname] then
        self.imported_modules[modname] = true
        local f, err = io.open(modname..'.kindafl','r')
        if not f then error("Module "..modname.." not found: "..err) end
        local modcode = f:read("*a")
        f:close()
        modcode = self:preprocess(modcode)
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

function compiler:tstatement(cur)
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
    ["match"] = "push(stack,pop(stack):match(pop(stack)))"
  }
  
  if self.state == "statement" then
    if actions[cur] then return actions[cur] .. "\n"
    elseif cur == 's"' then
      self.state = "string"
      return ""
    elseif cur == 'l"' then
      self.state = "lod"
      return ""
    elseif tonumber(cur) then
      return "push(stack, "..tonumber(cur)..")\n"
    else
      return cur.."()\n"
    end
  elseif self.state == "string" then
    if cur == "\"" then
      local tmp = self.str_acc
      self.str_acc = ""
      self.state = "statement"
      return "push(stack, \""..tmp:gsub("^ ", "").."\")\n"
    end
    self.str_acc = self.str_acc .." "..cur
    return ""
  elseif self.state == "lod" then
    if cur == "\"" then
      local tmp = self.lib_acc:gsub("^ ", "")
      self.lib_acc = ""
      self.state = "statement"
      local f = io.open(tmp..".lua", 'r')
      local dat = f:read('*a')
      f:close()
      return dat.."\n"
    end
    self.lib_acc = self.lib_acc.." "..cur
    return ""
  end
end

function compiler:tcode(str)
  local ret_val = {}
  local line_ret = {}
  for line in string.gmatch(str, '[^\n]+') do
    for v in string.gmatch(line, '%S+') do
      table.insert(line_ret, self:tstatement(v))
    end
    table.insert(ret_val,table.concat(line_ret))
    line_ret = {}
  end
  return table.concat(ret_val)
end

return compiler
