local compiler = {}
compiler.__index = compiler

function compiler:new()
  return setmetatable({imported_modules = {}}, compiler)
end

function compiler:flatten(into, list)
  for _,v in ipairs(list) do into[#into+1] = v end
end

function compiler:preprocess(code)
  local tokens = {}
  local i = 1
  local n = #code
  
  local function emit(t)
    tokens[#tokens+1] = t
  end
  
  while i <= n do
    local c = code:sub(i,i)
    if code:sub(i,i+1) == 'm"' then
      i = i + 2
      local name = ""
      while i <= n and code:sub(i,i) ~= '"' do
        name = name .. code:sub(i,i)
        i = i + 1
      end
      i = i + 1
      if not self.imported_modules[name] then
        self.imported_modules[name] = true
        local f = assert(io.open(name .. ".kindafl","r"),
                 "Module "..name.." not found")
        local text = f:read("*a")
        f:close()
        local subtoks = self:preprocess(text)
        self:flatten(tokens, subtoks)
      end
    elseif code:sub(i,i+1) == 's"' then
      i = i + 2
      local buff = {}
      while i <= n do
        local ch = code:sub(i,i)
        if ch == '"' then
          i = i + 1
          break
        elseif ch == "\\" then
          buff[#buff+1] = code:sub(i, i+1)
          i = i + 2
        else
          buff[#buff+1] = ch
          i = i + 1
        end
      end
      emit({type="string", value=table.concat(buff)})
    elseif code:sub(i,i+1) == 'l"' then
      i = i + 2
      local name = ""
      while i <= n and code:sub(i,i) ~= '"' do
        name = name .. code:sub(i,i)
        i = i + 1
      end
      i = i + 1
      emit({type="load", value=name})
    elseif c == "(" then
      i = i + 1
      while i <= n and code:sub(i,i) ~= ")" do
        i = i + 1
      end
      i = i + 1
    elseif c:match("%s") then
      i = i + 1
    else
      local start = i
      while i <= n and not code:sub(i,i):match("%s") and
      code:sub(i,i) ~= "(" and
      code:sub(i,i+1) ~= 'm"' and
      code:sub(i,i+1) ~= 's"' and
      code:sub(i,i+1) ~= 'l"' do
        i = i + 1
      end
      emit(code:sub(start, i-1))
    end
  end
  return tokens
end

function compiler:op_table()
  local var = "local b,a = pop(stack), pop(stack)\n"
  return {
    ["+"] = var.."push(stack, a + b )",
    ["-"] = var.."push(stack, a - b )",
    ["*"] = var.."push(stack, a * b )",
    ["/"] = var.."push(stack, a / b )",
    ["="] = var.."push(stack, a == b )",
    [">"] = var.."push(stack, a > b )",
    ["<"] = var.."push(stack, a < b )",
    ["and"] = var.."push(stack, a and b )",
    ["or"] = var.."push(stack, a or b )",
    ["not"] = "push(stack, not pop(stack))",
    ["."] = "print(pop(stack))",
    ["dump"] = "dump(false)",
    ["mem"] = "dump(true)",
    ["dup"] = "push(stack, stack[#stack])",
    ["swap"] = var.."push(stack, b)\npush(stack, a)",
    ["drop"] = "pop(stack)",
    ["do"] = "for i = pop(stack), pop(stack) - 1 do",
    ["wt"] = "while true do",
    ["i"] = "push(stack, i)",
    ["br"] = "break",
    ["begin"] = "repeat",
    ["until"] = "until pop(stack)",
    ["if"] = "if pop(stack) then",
    ["else"] = "else",
    [":"] = "function ",
    [";"] = "end",
    ["!"] = "mem[pop(stack)] = pop(stack)",
    ["@"] = "push(stack, mem[pop(stack)])",
    ["read"] = "local r = io.open(pop(stack),'r')\npush(stack,r:read('*a'))\nr:close()",
    ["write"] = "local w = io.open(pop(stack),'w')\nw:write(pop(stack))\nw:close()",
    ["strin"] = "push(stack, tostring(io.read()))",
    ["numin"] = "push(stack, tonumber(io.read()))",
    ["cat"] = var.."push(stack, tostring(a) .. tostring(b))",
    ["match"] = var.."push(stack, tostring(a):match(tostring(b)))"
  }
end

function compiler:tcode(tokens)
  local out = {}
  local ops = self:op_table()
  local function emit(s)
    out[#out+1] = s
  end
  for _,tok in ipairs(tokens) do
    if type(tok) == "table" and tok.type == "string" then
      local v = tok.value:gsub('"','\"')
      emit('push(stack, "'..v..'")\n')
    elseif type(tok) == "table" and tok.type == "load" then
      local path = tok.value .. ".lua"
      local f = assert(io.open(path,"r"),"Cannot load library: "..path)
      emit(f:read("*a").."\n")
      f:close()
    else
      local w = tok
      if tonumber(w) then
        emit("push(stack, "..tonumber(w)..")\n")
      elseif ops[w] then
        emit(ops[w] .. "\n")
      else
        emit(w .. "()\n")
      end
    end
  end
  return table.concat(out)
end

return compiler
