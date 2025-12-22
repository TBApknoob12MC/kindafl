local op_table,compiler = require('op_table'), {}
compiler.__index = compiler

function compiler:gensym()
  self.gensym_counter = self.gensym_counter + 1
  return "tmp["..self.gensym_counter.."]"
end

function compiler:new()
  return setmetatable({ imported_modules = {}, gensym_counter = 0, macro_list = {}, out = {}, vstack = {}, block_depth = 0}, compiler)
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
        local f = assert(io.open(name .. ".kfl","r"), "Module "..name.." not found")
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
      i = i + 2
      while i <= n and code:sub(i,i):match("%s") do i = i + 1 end
      local name_start = i
      while i <= n and not code:sub(i,i):match("%s") and code:sub(i,i) ~= "|" do i = i + 1 end
      local mname = code:sub(name_start, i-1)
      local args = {}
      local curr = {}
      while i <= n do
        if code:sub(i, i+1) == "||" then
            table.insert(args, table.concat(curr))
            i = i + 2
            break
        elseif code:sub(i, i) == "\\" then
          table.insert(curr, code:sub(i+1, i+1))
          i = i + 2
        elseif code:sub(i, i) == "|" then
          table.insert(args, table.concat(curr))
          curr = {}
          i = i + 1
        else
          table.insert(curr, code:sub(i, i))
          i = i + 1
        end
      end
      local tmpl = self.macro_list[mname]
      if tmpl then
        local new = tmpl
        for idx = #args, 1, -1 do
          local val = args[idx]:match("^%s*(.-)%s*$")
          new = new:gsub("#" .. idx, function() return val end)
        end
        self:flatten(tokens, self:preprocess(new))
      else error("macro " .. mname .. " not defined") end
    elseif code:sub(i, i+1) == "x?" then
      i = i + 3
      while i <= n and code:sub(i,i):match("%s") do i = i + 1 end
      local start = i
      while i <= n and not code:sub(i,i):match("%s") do i = i + 1 end
      local macro_name = code:sub(start, i-1)
      local content_start, depth, else_pos = i, 1, nil
      while i <= n do
        if code:sub(i, i+1) == "x?" then depth = depth + 1
        elseif code:sub(i, i+1) == "fi" then depth = depth - 1
        elseif code:sub(i, i+1) == "el" and depth == 1 then else_pos = i end
        if depth == 0 then break end
        i = i + 1
      end
      local full_content = code:sub(content_start, i-1); i = i + 2 ; print(full_content)
      local true_part, false_part = full_content, ""
      if else_pos then local rel_else = else_pos - content_start ;true_part,false_part = full_content:sub(1, rel_else - 1), full_content:sub(rel_else + 2) end
      if self.macro_list[macro_name] then self:flatten(tokens, self:preprocess(true_part))
      else self:flatten(tokens, self:preprocess(false_part)) end
    elseif code:sub(i,i+1) == "r:" then
      i = i + 2
      local buff = {}
      while i <= n do
        local ch = code:sub(i,i)
        if ch == "\\" then buff[#buff+1] = code:sub(i+1,i+1); i = i + 2
        elseif ch == ";" then i = i + 1; break
        else buff[#buff+1] = ch; i = i + 1 end
      end
      local lua_code, env = table.concat(buff), {self = self,print = print,table = table,string = string,math = math,io = io,tonumber = tonumber,tostring = tostring,pairs = pairs,ipairs = ipairs}
      local chunk, err = load(lua_code, "run", "t", env)
      if chunk then local status, result = pcall(chunk)
        if status and type(result) == "string" then self:flatten(tokens, self:preprocess(result))
        else print("Runtime Error in run: " .. tostring(result)) end
      else print("Syntax Error in run: " .. tostring(err))
      end
    elseif code:sub(i,i) == "[" then
      i = i + 1 ; local start, depth = i, 1
      while i <= n and depth > 0 do
        local ch = code:sub(i,i)
        if ch == "[" then depth = depth + 1 
        elseif ch == "]" then depth = depth - 1 end
        if depth > 0 then i = i + 1 end
      end
      local block = code:sub(start,i - 1); i = i + 1
      emit({type="quot", value=self:preprocess(block)})
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
      elseif self.macro_list[buff] then self:flatten(tokens,self:preprocess(self.macro_list[buff]))
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
    elseif expr.op == "=" then return string.format("(%s == %s)",left, right)
    else return string.format("(%s %s %s)", left, expr.op, right) end
  end
  error("can't materialize expr : " .. tostring(expr.kind))
end

function compiler:flush()
  for _,expr in ipairs(self.vstack) do self.out[#self.out+1] = "push(stack, " .. materialize(expr) .. ")\n" end
  self.vstack, self.gensym_counter = {}, 0
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
  self.out, self.vstack = {}, {}
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
        self.block_depth = self.block_depth + 1
        local b, a = table.remove(self.vstack), table.remove(self.vstack)
        if not (a and b) then
          if b then self.vstack[#self.vstack+1] = b end
          if a then self.vstack[#self.vstack+1] = a end
          self:flush(); self.out[#self.out+1] = ops["do"].."\n"
        elseif a.kind=="const" and b.kind=="const" then
          self:flush(); self.out[#self.out+1] = "for i = "..tostring(b.value)..", "..tostring(a.value - 1).." do\n"
        end
      elseif w == "if" then
        self.block_depth = self.block_depth + 1
        local a = table.remove(self.vstack)
        if not a then
          self:flush(); self.out[#self.out+1] = ops["if"].."\n"
        else
          self:flush(); self.out[#self.out+1] = "if "..materialize(a).." then\n"
        end
      elseif w == "else" then
        self.block_depth = self.block_depth+1
        self:flush(); self.out[#self.out+1] = "else\n"
      elseif w == ";" then
        self:flush(); self.out[#self.out+1] = "end\n"
        self.block_depth = self.block_depth - 1
      elseif w == "!" then
        local idx, val = table.remove(self.vstack), table.remove(self.vstack)
        if not (idx and val) then
          if val then self.vstack[#self.vstack+1] = val end
          if idx then self.vstack[#self.vstack+1] = idx end
          self:flush(); self.out[#self.out+1] = ops["!"].."\n"
        else
          self.out[#self.out+1] = "mem["..materialize(idx).."] = "..materialize(val).."\n"
        end
      elseif w == "@" then
        local idx = table.remove(self.vstack)
        if not idx then
          self:flush(); self.out[#self.out+1] = ops["@"].."\n"
        else
          local var = self:gensym()
          self.out[#self.out+1] = var.." = mem["..materialize(idx).."]\n"
          self.vstack[#self.vstack+1] = {kind="var", value=var}
        end
      elseif w == "strin" or w == "numin" or w == "read" then
        local path = (w == "read" and table.remove(self.vstack)) or nil
        if w == "strin" then self:emit_local_var("tostring(io.read())")
        elseif w == "numin" then self:emit_local_var("tonumber(io.read())")
        elseif w == "read" and path then
          local lua_expr = string.format("(function(r) local t = r:read('*a'); r:close(); return t end)(io.open(%s,'r'))", materialize(path))
          self:emit_local_var(lua_expr)
        elseif w == "read" and not path then
          self:flush(); self.out[#self.out+1] = ops["read"].."\n"
        end
      elseif ops[w] then
        self:flush(); self.out[#self.out+1] = ops[w].."\n"
      else
        self:emit_local_var(w .. "()\n")
      end
    elseif tok.type == "quot" then
      local sub_comp = self:new(); local inner = sub_comp:tcode(tok.value)
      self:flush(); self:emit_local_var("function()\n"..inner.."end")
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