# kindaforthless
kinda forth, less - forth-ish language that compiles to lua 

`please guys I made this...
my language is kinda forthless
**speed face**`

**"one can implement a forth in a weekend"**
 -- a wise man said; and he was right.

---

## Features

- **Stack-based execution:** Operates on values via stack manipulation.
- **Arithmetic and logical ops:** `+`, `-`, `*`, `/`, `and`, `or`, `not`, `=`, `<`, `>`, etc.
- **Memory table:** Store/load values via `!` and `@`.
- **Strings and lua code:** Push strings (`s" hello "`) and include lua code from files (`l" filename "`).
- **Module import:** `m"modulename"` includes other `.kindafl` scripts.
- **IO:** Read/write files, input from user.
- **REPL:** Interactive shell to play with the language.
- **Tiny standard library:** Just enough to make kfl work.
- **lua interop:** Can call lua functions, but one should provide an interface for it to access the stack.
---

## Usage

### 1. Compile a kindafl source to Lua

```bash
lua(5.2|5.3|5.4) kindafl.lua (p|c) <source> <output>
```

- **`c`**: Compile mode,
OR
- **`p`**: Preprocess only
- **`<source>`**: Path to your kindafl source file
- **`<output>`**: Where to write the generated Lua or kfl code

### 2. Use the REPL (interactive shell)

```bash
lua kindafl.lua r          # start empty REPL
lua kindafl.lua r <file>   # start REPL after running a kindafl file
```

- **`r`**: Read-Eval-Print-Loop

At the REPL, type your kindafl code line by line. Enter `q` to quit.

---

## Kindafl Language 

```
l" std " # include lua file std.lua : should be included at top of the main source file
c"comment" # comment
: x 1 ; # word/function named x that pushes 1 to stack
1 2 + # push 1 and 2, pop them and add, push final result
1 4 ! # store 1 at key 4
4 @ # fetch value at key 4 and push - here : 1
s" hi " # string
l" another_file " # include another lua source file named another_file.lua
m"module" # include another kfl file
a_lua_function # call lua functions
```
---

## require the compiler in your code:

You can use the module and call exported functions:

- `preprocess(source_str)`: preprocess source
- `tcode(code_str)`: transpile source to Lua code string

---

## License

MPL-2.0

---

