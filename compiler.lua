local op_table,compiler = require('op_table'), {}
compiler.__index = compiler

function compiler:gensym()
  local idx = #self.vstack + 1
  return "tmp["..idx.."]"
end

function compiler:new()
  return setmetatable({ imported_modules = {}, gensym_counter = 0, macro_list = {}, out = {}, vstack = {}, lazy_mem = {} }, compiler)
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
      self.macro_list[name] = table.concat(buff)
    elseif code:sub(i,i+1) == "::" then
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
      local ctr,y = 0, self.macro_list[name]; for x in string.gmatch(table.concat(buff),'%S+') do
        ctr = ctr+1; y = y:gsub('#'..ctr,x)
      end
      self:flatten(tokens,self:preprocess(y))
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
    elseif c:match("%s") then i = i + 1
    else
      local start = i
      while i <= n and not code:sub(i,i):match("%s") and code:sub(i,i) ~= "(" and code:sub(i,i+1) ~= 'm"' and code:sub(i,i+1) ~= 's"' and code:sub(i,i+1) ~= 'l"' and code:sub(i,i+1) ~= 'x:' do i = i + 1 end
      local buff = code:sub(start, i-1)
      if tonumber(buff) then emit({type="number", value=tonumber(buff)})
      elseif op_table.op[buff] then emit({type="word", value=buff})
      elseif self.macro_list[buff] then self:flatten(tokens,self:preprocess(macro_list[buff]))
      else emit({type="x", value=buff}) end
    end
  end
  return tokens
end

local function materialize(expr)
  if expr.kind == "const" or expr.kind == "number" then return tostring(expr.value)
  elseif expr.kind == "string" then return string.format("%q", expr.value)
  elseif expr.kind == "var" then return expr.value
  elseif expr.kind == "op" then
    local left, right = materialize(expr.left), expr.right and materialize(expr.right) or ""
    if expr.op == ".." then return string.format("(%s .. %s)", left, right)
    elseif expr.op == "not" then return string.format("(not %s)", left)
    else return string.format("(%s %s %s)", left, expr.op, right) end
  end
  error("can't materialize expr : " .. tostring(expr.kind))
end

function compiler:flush()
  for _,expr in ipairs(self.vstack) do self.out[#self.out+1] = "push(stack, " .. materialize(expr) .. ")\n" end
  self.vstack = {}
end

function compiler:emit_local_var(lua_expr,is_fun)
  local var = self:gensym()
  if is_fun then self.out[#self.out+1] = lua_expr
  else self.out[#self.out+1] = var.." = "..lua_expr.."\n" 
  self.vstack[#self.vstack+1] = {kind="var", value=var} end
end

function compiler:process_op(w, a, b)
  local fold_func = op_table.const_fold[w]
  local is_constant_foldable = a and ((b and b.kind == "const" and a.kind == "const") or (w == "not" and a.kind == "const"))
  local res, kind
  if fold_func and is_constant_foldable then
    res = fold_func(a.value, b and b.value)
    if res ~= nil then
      kind = (w == "cat" and type(res) == "string") and "string" or "const"
      self.vstack[#self.vstack+1] = {kind = kind, value = res}
      return true
    end
  end
  if w == "cat" then
    self.vstack[#self.vstack+1] = {kind="op", op="..", left=a, right=b}
  elseif w == "not" then
    self.vstack[#self.vstack+1] = {kind="op", op="not", left=a}
  else
    self.vstack[#self.vstack+1] = {kind="op", op=w, left=a, right=b}
  end
  return true
end

function compiler:tcode(tokens)
  self.out, self.vstack, self.lazy_mem = {}, {}, {}
  local ops = op_table.op
  local is_binop = function(w)
    return (w=="+" or w=="-" or w=="*" or w=="/" or w=="=" or w==">" or w=="<" or w=="and" or w=="or" or w=="cat")
  end
  for tok_idx,tok in ipairs(tokens) do
    if tok.type == "string" then self.vstack[#self.vstack+1] = {kind="string", value=tok.value}
    elseif tok.type == "load" then
      self:flush()
      local path = tok.value .. ".lua"
      local f = assert(io.open(path,"r"),"Cannot load library: "..path)
      self.out[#self.out+1] = f:read("*a").."\n"; f:close()
    elseif tok.type == "number" then self.vstack[#self.vstack+1] = {kind="const", value=tok.value}
    elseif tok.type == "word" then
      local w, skip_vpush_var = tok.value, false
      if is_binop(w) or w=="not" then
        local b, a = table.remove(self.vstack), table.remove(self.vstack)
        if not (a and (b or w=="not")) then
          if b then self.vstack[#self.vstack+1] = b end
          if a then self.vstack[#self.vstack+1] = a end
          self:flush(); self.out[#self.out+1] = ops[w].."\n"
        else
          self:process_op(w, a, b)
        end
      elseif w == "dup" or w == "over" or w == "swap" or w == "drop" then
        local optimized = false
        if w == "dup" and #self.vstack >= 1 then
          self.vstack[#self.vstack+1] = self.vstack[#self.vstack]
          optimized = true
        elseif w == "over" and #self.vstack >= 2 then
          self.vstack[#self.vstack+1] = self.vstack[#self.vstack - 1]
          optimized = true
        elseif w == "swap" and #self.vstack >= 2 then
          self.vstack[#self.vstack], self.vstack[#self.vstack - 1] = self.vstack[#self.vstack - 1], self.vstack[#self.vstack]
          optimized = true
        elseif w == "drop" and #self.vstack >= 1 then
          table.remove(self.vstack)
          optimized = true
        end
        if not optimized then
          self:flush(); self.out[#self.out+1] = ops[w].."\n"
        end
      elseif w == "do" then
        local b, a = table.remove(self.vstack), table.remove(self.vstack)
        if not (a and b) then
          if b then self.vstack[#self.vstack+1] = b end
          if a then self.vstack[#self.vstack+1] = a end
          self:flush(); self.out[#self.out+1] = ops["do"].."\n"
        elseif a.kind=="const" and b.kind=="const" then
          self.out[#self.out+1] = "for i = "..tostring(b.value)..", "..tostring(a.value - 1).." do\n"
        end
      elseif w == "!" then
        local idx,val = table.remove(self.vstack), table.remove(self.vstack)
        if not (idx and val) then
          if val then self.vstack[#self.vstack+1] = val end
          if idx then self.vstack[#self.vstack+1] = idx end
          self:flush(); self.out[#self.out+1] = ops["!"].."\n"
        elseif idx.kind=="const" and val.kind=="const" then
          self.lazy_mem[idx.value] = val.value
          self.out[#self.out+1] = "mem["..idx.value.."] = "..val.value.."\n"
        else self:flush(); self.out[#self.out+1] = ops["!"].."\n" end
      elseif w == "@" then
        local idx = table.remove(self.vstack)
        if not idx then
          self:flush(); self.out[#self.out+1] = ops["@"].."\n"; skip_vpush_var = true
        elseif idx.kind=="const" and self.lazy_mem[idx.value] ~= nil then
          self.vstack[#self.vstack+1] = {kind="const", value = self.lazy_mem[idx.value]}; skip_vpush_var = true
        else
          local var = self:gensym()
          self.out[#self.out+1] = var.." = mem["..materialize(idx).."]\n"
          self.vstack[#self.vstack+1] = {kind="var", value=var}; skip_vpush_var = true
        end
      elseif w == "strin" or w == "numin" or w == "read" then
        local path = (w == "read" and table.remove(self.vstack)) or nil
        if w == "strin" then self:emit_local_var("tostring(io.read())")
        elseif w == "numin" then self:emit_local_var("tonumber(io.read())")
        elseif w == "read" and path then
          local lua_expr = string.format("(function(r) local t = r:read('*a'); r:close(); return t end)(io.open(%s,'r'))", materialize(path))
          self:emit_local_var(lua_expr)
        elseif w == "read" and not path then
          self:flush(); self.out[#self.out+1] = ops["read"].."\n"; skip_vpush_var = true
        end
      elseif ops[w] then
        self:flush(); self.out[#self.out+1] = ops[w].."\n"
      else
        self:emit_local_var(w .. "()\n")
      end
    elseif tok.type == "x" then
      self:emit_local_var(tok.value .. "()\n",((tok_idx - 1 > 0 ) and tokens[tok_idx - 1].value == ":") or nil)
    else
      error("unknown token type: "..tostring(tok.type))
    end
  end
  self:flush()
  return table.concat(self.out)
end

return compiler