local op_table = require('op_table')
local compiler = {}
compiler.__index = compiler

function compiler:gensym()
  self.gensym_counter = self.gensym_counter + 1
  return "_t"..self.gensym_counter
end

function compiler:new()
  return setmetatable({imported_modules = {}, gensym_counter = 0, macro_list = {}}, compiler)
end

function compiler:flatten(into, list)
  for _,v in ipairs(list) do into[#into+1] = v end
end

function compiler:preprocess(code)
  local tokens, i, n = {}, 1, #code
  local emit = function(t) tokens[#tokens+1] = t end
  while i <= n do
    local c = code:sub(i,i)
    if code:sub(i,i+1) == 'm"' then
      i = i + 2
      local name = ""
      while i <= n and code:sub(i,i) ~= '"' do name = name .. code:sub(i,i); i = i + 1 end
      i = i + 1
      if not self.imported_modules[name] then
        self.imported_modules[name] = true
        local f = assert(io.open(name .. ".kindafl","r"), "Module "..name.." not found")
        local text = f:read("*a"); f:close()
        self:flatten(tokens, self:preprocess(text))
      end
    elseif code:sub(i,i+1) == "x:" then
      i = i + 2 ; local buff = {}
      while i <= n do
        local ch = code:sub(i,i)
        if ch == " " or ch == ";" then break end
        if ch == "\\" then buff[#buff+1] = code:sub(i+1,i+1); i = i + 2
        else buff[#buff+1] = ch; i = i + 1 end
      end
      local name = table.concat(buff); buff = {}
      while i <= n and code:sub(i,i):match("%s") and code:sub(i,i) ~= ";" do i = i + 1 end
      while i <= n do
        local ch = code:sub(i,i)
        if ch == ";" then i = i + 1; break
        elseif ch == "\\" then buff[#buff+1] = code:sub(i+1,i+1); i = i + 2
        else buff[#buff+1] = ch; i = i + 1 end 
      end
      self.macro_list[name] = self:preprocess(table.concat(buff))
    elseif code:sub(i,i+1) == 's"' then
      i = i + 2
      local buff = {}
      while i <= n do
        local ch = code:sub(i,i)
        if ch == '"' then i = i + 1; break
        elseif ch == "\\" then buff[#buff+1] = code:sub(i,i+1); i = i + 2
        else buff[#buff+1] = ch; i = i + 1 end
      end
      emit({type="string", value=table.concat(buff)})
    elseif code:sub(i,i+1) == 'l"' then
      i = i + 2
      local name = ""
      while i <= n and code:sub(i,i) ~= '"' do name = name .. code:sub(i,i); i = i + 1 end
      i = i + 1
      emit({type="load", value=name})
    elseif c == "(" then
      i = i + 1
      while i <= n and code:sub(i,i) ~= ")" do i = i + 1 end
      i = i + 1
    elseif c:match("%s") then
      i = i + 1
    else
      local start = i
      while i <= n and not code:sub(i,i):match("%s") and code:sub(i,i) ~= "(" and code:sub(i,i+1) ~= 'm"' and code:sub(i,i+1) ~= 's"' and code:sub(i,i+1) ~= 'l"' and code:sub(i,i+1) ~= 'x:' do i = i + 1 end
      local buff = code:sub(start, i-1)
      if tonumber(buff) then emit({type="number", value=tonumber(buff)})
      elseif op_table()[buff] then emit({type="word", value=buff})
      elseif self.macro_list[buff] then self:flatten(tokens,self.macro_list[buff])
      else emit({type="x", value=buff}) end
    end
  end
  return tokens
end

function compiler:tcode(tokens)
  local out, ops, vstack, lazy_mem = {}, op_table(), {}, {}
  local function materialize(expr)
    if expr.kind == "const" or expr.kind == "number" then return tostring(expr.value)
    elseif expr.kind == "string" then return string.format("%q", expr.value)
    elseif expr.kind == "var" then return expr.value
    elseif expr.kind == "op" then
      local left = materialize(expr.left)
      local right = expr.right and materialize(expr.right) or ""
      if expr.op == ".." then return string.format("(%s .. %s)", left, right)
      elseif expr.op == "not" then return string.format("(not %s)", left)
      else return string.format("(%s %s %s)", left, expr.op, right) end
    end
    error("can't materialize expr : " .. tostring(expr.kind))
  end
  local function emit(s) out[#out+1] = s end
  local function flush()
    for _,expr in ipairs(vstack) do emit("push(stack, " .. materialize(expr) .. ")\n") end
    vstack = {}
  end
  for _,tok in ipairs(tokens) do
    if tok.type == "string" then vstack[#vstack+1] = {kind="string", value=tok.value}
    elseif tok.type == "load" then
      flush()
      local path = tok.value .. ".lua"
      local f = assert(io.open(path,"r"),"Cannot load library: "..path)
      emit(f:read("*a").."\n"); f:close()
    elseif tok.type == "number" then vstack[#vstack+1] = {kind="const", value=tok.value}
    elseif tok.type == "word" then
      local w, b, a, skip_vpush_var = tok.value, nil, nil, false
      local is_binop = (w=="+" or w=="-" or w=="*" or w=="/" or w=="=" or w==">" or w=="<" or w=="and" or w=="or" or w=="cat")
      if is_binop or w=="not" then
        b = table.remove(vstack)
        a = table.remove(vstack)
        if not (a and (b or w=="not")) then
          if b then vstack[#vstack+1] = b end
          if a then vstack[#vstack+1] = a end
          flush(); emit(ops[w].."\n")
        elseif a.kind=="const" and ((b and b.kind=="const") or w=="not") then
          local res
          if w=="+" then res = a.value+b.value
          elseif w=="-" then res = a.value-b.value
          elseif w=="*" then res = a.value*b.value
          elseif w=="/" then res = a.value/b.value
          elseif w=="=" then res = a.value==b.value
          elseif w==">" then res = a.value>b.value
          elseif w=="<" then res = a.value<b.value
          elseif w=="and" then res = (a.value and b.value)
          elseif w=="or" then res = (a.value or b.value)
          elseif w=="not" then res = not a.value
          elseif w=="cat" and a.kind=="string" and b.kind=="string" then res = a.value .. b.value end
          if w=="cat" and a.kind=="string" and b.kind=="string" then
             vstack[#vstack+1] = {kind="string", value = a.value .. b.value}
          elseif w=="cat" then
             vstack[#vstack+1] = {kind="op", op="..", left=a, right=b}
          else
             vstack[#vstack+1] = {kind="const", value = res}
          end
        elseif w=="cat" then
           vstack[#vstack+1] = {kind="op", op="..", left=a, right=b}
        elseif w=="not" then
           vstack[#vstack+1] = {kind="op", op="not", left=a}
           b = nil
        else
          vstack[#vstack+1] = {kind="op", op=w, left=a, right=b}
        end
      elseif w == "dup" then
        if #vstack == 0 then flush(); emit(ops["dup"].."\n")
        else vstack[#vstack+1] = vstack[#vstack] end
      elseif w == "swap" then
        if #vstack < 2 then flush(); emit(ops["swap"].."\n")
        else vstack[#vstack], vstack[#vstack-1] = vstack[#vstack-1], vstack[#vstack] end
      elseif w == "drop" then
        if #vstack == 0 then flush(); emit(ops["drop"].."\n")
        else table.remove(vstack) end
      elseif w == "!" then
        local val = table.remove(vstack)
        local idx = table.remove(vstack)
        if not (idx and val) then
          if val then vstack[#vstack+1] = val end
          if idx then vstack[#vstack+1] = idx end
          flush(); emit(ops["!"].."\n")
        elseif idx.kind=="const" and val.kind=="const" then
          lazy_mem[idx.value] = val.value
        else flush(); emit(ops["!"].."\n") end
      elseif w == "@" then
        local idx = table.remove(vstack)
        if not idx then
          flush(); emit(ops["@"].."\n"); skip_vpush_var = true
        elseif idx.kind=="const" and lazy_mem[idx.value] ~= nil then
          vstack[#vstack+1] = {kind="const", value = lazy_mem[idx.value]}; skip_vpush_var = true
        else
          local var = self:gensym()
          emit("local "..var.." = mem["..materialize(idx).."]\n")
          vstack[#vstack+1] = {kind="var", value=var}; skip_vpush_var = true
        end
      elseif w == "strin" or w == "numin" or w == "read" then
        local path = (w == "read" and table.remove(vstack)) or nil
        local var, lua_expr = self:gensym(), nil
        if w == "strin" then lua_expr = "tostring(io.read())"
        elseif w == "numin" then lua_expr = "tonumber(io.read())"
        elseif w == "read" and path then
          lua_expr = string.format("(function(r) local t = r:read('*a'); r:close(); return t end)(io.open(%s,'r'))", materialize(path))
        elseif w == "read" and not path then
          flush(); emit(ops["read"].."\n"); skip_vpush_var = true
        end
        if not skip_vpush_var then
          flush()
          emit("local "..var.." = "..lua_expr.."\n")
          vstack[#vstack+1] = {kind="var", value=var}
        end
      elseif ops[w] then
        flush(); emit(ops[w].."\n")
      else
        flush()
        local var = self:gensym()
        emit("local "..var.." = "..w .. "()\n")
        vstack[#vstack+1] = {kind="var", value=var}
      end
    elseif tok.type == "x" then
      flush()
      local var = self:gensym()
      emit("local "..var.." = "..tok.value .. "()\n")
      vstack[#vstack+1] = {kind="var", value=var}
    else
      error("unknown token type: "..tostring(tok.type))
    end
  end
  flush()
  return table.concat(out)
end

return compiler