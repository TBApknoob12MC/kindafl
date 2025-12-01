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
- **Memory table:** Store/load variables via `!` and `@`.
- **Strings and lua code:** Push strings (`s" hello "`) and include lua code from files (`l" filename "`).
- **Module import:** `m"modulename"` includes other `.kindafl` scripts.
- **IO:** Read/write files, input from user.
- **REPL:** Interactive shell to play with the language.

---

## Usage

### 1. Compile a kindafl source to Lua

```bash
lua(5.2|5.3|5.4) kindafl.lua (c|m) <source.kindafl> <output.lua>
```

- **`c`**: Compile mode,
OR
- **`m`**: Module compile mode
- **`<source.kindafl>`**: Path to your kindafl source file
- **`<output.lua>`**: Where to write the generated Lua code

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
c" comment " # comment
: x 1 ; # word/function
1 2 + # push 1 and 2, pop them and add, push final result
1 4 ! # store 1 at key 4
4 @ # fetch value at key 4 and push - here : 1
s" hi " # string
l" file.lua " # include file
m"module" # include another kfl file
```
---

## require the compiler in your code:

You can use the module and call exported functions:

- `init_code`: initial Lua setup string
- `preprocess(source_str)`: preprocess source
- `comp(code_str)`: transpile source to Lua code string

---

## License

MPL-2.0

---

