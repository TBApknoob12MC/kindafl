stack, mem, lib,tmp, f = {}, {}, {}, {}, {}
mem[1] = 1
function dump(do_mem)
  local d = ""
  if do_mem then
    local acc = {}
    for k, v in pairs(mem) do
      table.insert(acc, tostring(k).." : "..tostring(v))
    end
    d = table.concat(acc,", ")
  else
    local acc = {} ; for i = 1, #stack do table.insert(acc,tostring(stack[i])) end
    d = table.concat(acc," ")
  end
  table.insert(stack, d)
end

function d()
  dump(false)
  print('stack: '..table.remove(stack))
end

function m()
  dump(true)
  print('mem: '..table.remove(stack))
end

function push(t,v)
  table.insert(t,v)
end

function pop(t)
  if #t < 1 then error("stack underflow") end
  return table.remove(t)
end

function nxt()
mem[1] = mem[1] + 1
push(stack, mem[1])
end