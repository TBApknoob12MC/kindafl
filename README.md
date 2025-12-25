# kindaforthless
kinda forth, less - forth-ish language that compiles to lua 

`please guys I made this...
my language is kinda forthless
**speed face**`

Maintaining full compatibility with forth wasn't, isn't and won't be any objective of kindaforthless.

**"one can implement a forth in a weekend"**
 -- a wise man said; and he was right.

---

## Features
- **Stack-based execution:** Operates on values via stack manipulation.
- **Arithmetic and logical ops:** `+`, `-`, `*`, `/`, `and`, `or`, `not`, `=`, `<`, `>`, etc.
- **Memory table:** Store/load values via `!` and `@`.
- **Strings and lua code:** Push strings (`s"hello"`) and include lua code from files (`l"filename"`).
- **Module import:** `m"modulename"` includes other `.kindafl` scripts.
- **IO:** Read/write files, input from user.
- **REPL:** Interactive shell to play with the language.
- **Tiny standard library:** Just enough to make kfl work.
- **Macros:** Words, but they get replaced with its content at compile time.
- **Optimized codegen:** Cool stuff for optimized code generation.
- **lua interop:** Can call lua functions, but one should provide an interface for it to access the stack.
---

## Usage

### 1. Compile a kindafl source to Lua

```bash
lua(5.2|5.3|5.4) kindafl.lua c <source> <output>
```

- **`c`**: Compile mode
- **`<source>`**: Path to your kindafl source file
- **`<output>`**: Where to write the generated Lua or kfl code

### 2. Use the REPL (interactive shell)

```bash
lua kindafl.lua r          # start empty REPL
lua kindafl.lua r <file>   # start REPL after running a kindafl file
```

- **`r`**: Read-Eval-Print-Loop mode

At the REPL, type your kindafl code line by line. Enter `q` to quit.

---

## Kindafl Language 

For more information, check out the [docs](https://github.com/TBApknoob12MC/kindafl/wiki)

```
m"std" (include kfl file std.kfl : should be included at top of the main source file)
(this is a comment)
: x 1 ; (word/function named x that pushes 1 to stack)
1 2 + (push 1 and 2, pop them and add, push final result)
10 1 do i . ; (for-ish loops)
1 4 ! (store 1 at key 4)
4 @ (fetch value at key 4 and push - here : 1)
::var varname || (create variable varname)
5 varname ! (set varname to 5)
s"hi" (string)
l"another_file" (include another lua source file named another_file.lua)
m"module" (include another kfl file)
a_lua_function (call lua functions)
[ 1 2 + ] (quotations - blocks that can be executed later with exec)
exec (execute topmost value in stack - here it is 1 2 +)
<{ x y ? x y + }> (scoped blocks with local variables)
x:a_macro 1 2 ; (macros)
a_macro + (substitutes a_macro with its contents 1 2 and adds them)
x:macro_with_args #1 #2 + ; (macros with arguments)
::macro_with_args 5 | 6 || (call macro_with_args with arguments 5 and 6 -> substitutes with 5 6 +)
r: return "1 2 +" ; (run lua code at compile time and compile its return value)
```

---

## License

MPL-2.0

---
