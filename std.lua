stack, mem, lib, f = {}, {}, {}, {}
mem[1] = 1
function dump(do_mem)
  local iter, tbl, init
  if do_mem then
    iter, tbl, init = pairs(mem)
  else
    iter, tbl, init = ipairs(stack)
  end
  local acc = {}
  for k, v in iter, tbl, init do
    if do_mem then
      table.insert(acc, tostring(k).." : "..tostring(v).." ")
    else
      table.insert(acc, tostring(v).." ")
    end
  end
  table.insert(stack, table.concat(acc))
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
  if #t < 1 then return 0 end
  return table.remove(t)
end

function nxt()
mem[1] = mem[1] + 1
push(stack, mem[1])
end