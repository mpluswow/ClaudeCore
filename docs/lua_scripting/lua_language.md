# Lua 5.2 & WoW Client Mod Reference

Complete reference for Lua 5.2 (used by Eluna/mod-ale server scripting) and WoW 3.3.5a client modification tools.

> **Critical distinction:**
> - **WoW client AddOns** = Lua **5.1** (limited sandbox, no `goto`, `unpack` is global, `getfenv`/`setfenv` exist)
> - **Eluna server scripting** = Lua **5.2+** (`table.unpack`, `_ENV`, `goto`, `bit32`, `load` signature changed)
> - See Section 11 for the full diff table.

---

## Table of Contents

1. [Basic Functions (Global)](#1-basic-functions-global)
2. [string.* Functions](#2-string-functions)
3. [table.* Functions](#3-table-functions)
4. [math.* Functions](#4-math-functions)
5. [io.* Functions](#5-io-functions)
6. [os.* Functions](#6-os-functions)
7. [coroutine.* Functions](#7-coroutine-functions)
8. [package.* / require](#8-package--require)
9. [bit32.* Functions (Lua 5.2 only)](#9-bit32-functions-lua-52-only)
10. [debug.* Functions](#10-debug-functions)
11. [Error Handling](#11-error-handling)
12. [String Pattern Syntax](#12-string-pattern-syntax)
13. [Metatables & Metamethods](#13-metatables--metamethods)
14. [OOP Pattern with setmetatable](#14-oop-pattern-with-setmetatable)
15. [Language Features: Closures, Varargs, goto](#15-language-features-closures-varargs-goto)
16. [Lua 5.1 vs 5.2 — Critical Differences](#16-lua-51-vs-52--critical-differences)
17. [awesome_wotlk DLL Enhancements](#17-awesome_wotlk-dll-enhancements)

---

## 1. Basic Functions (Global)

These are available globally without a module prefix.

### `assert(v [, message])` → v, ...
If `v` is `nil` or `false`, raises an error with `message` (default: "assertion failed!"). Otherwise returns all arguments unchanged. Commonly used to validate function inputs or propagate errors from functions that return `nil, errmsg`.
```lua
assert(type(x) == "number", "x must be a number")
local f = assert(io.open(path, "r"))  -- errors with io error message if open fails
```

### `collectgarbage([opt [, arg]])` → varies
Controls the garbage collector. `opt` string selects action:
- `"collect"` (default) — run a full GC cycle
- `"stop"` / `"restart"` — stop/restart the GC
- `"count"` — returns memory used in KB (float, fractional = bytes within KB)
- `"step"` — run one GC step; returns true if completed a cycle
- `"setpause"` — set pause value (100 = no extra pause); returns old value
- `"setstepmul"` — set step multiplier; returns old value
- `"isrunning"` — returns boolean (Lua 5.2+)
- `"generational"` / `"incremental"` — change GC mode (Lua 5.2+ experimental)

### `dofile([filename])` → ...
Loads and executes the file as a Lua chunk. Returns values from the chunk. Without argument, reads from stdin. Errors propagate to the caller.

### `error(message [, level])`
Terminates the current function and passes `message` as the error. `level` indicates where error is attributed: `1`=current function (default), `2`=calling function, `0`=no position info. `message` can be any value (table, number, etc.), not just a string.
```lua
error("something went wrong")
error("bad argument #1", 2)          -- error points to caller
error({code=404, msg="not found"})   -- table as error object
```

### `_G`
A global variable holding the global environment table. In Lua 5.2, this is the initial value of `_ENV` for the main chunk. Modifying `_G` does not affect `_ENV` of other functions.

### `getmetatable(object)` → table or nil
Returns the metatable of `object`. If the metatable has a `__metatable` field, returns that instead (protecting the metatable from inspection). Returns `nil` if no metatable.

### `ipairs(t)` → iterator, t, 0
Returns an iterator function, the table `t`, and initial value `0`. The iterator yields successive integer-key pairs `(1, t[1]), (2, t[2]), ...` stopping at the first nil value.
```lua
for i, v in ipairs({"a","b","c"}) do print(i, v) end
-- 1  a
-- 2  b
-- 3  c
```
**Note:** Does not traverse non-integer keys or holes. In Lua 5.2, `__ipairs` metamethod can customize behavior.

### `load(chunk [, chunkname [, mode [, env]]])` → function or nil, err
Loads a chunk. `chunk` can be a string or a function (called repeatedly to get pieces). Returns the compiled function or `nil` plus error message. `mode` can be `"t"` (text), `"b"` (binary), or `"bt"` (both). `env` sets the upvalue `_ENV` for the function.
```lua
local f = load("return 1 + 2")
print(f())  --> 3

-- Run with custom environment:
local env = {print = print, x = 42}
local f = load("print(x)", "test", "t", env)
f()  --> 42
```
**Lua 5.1:** `loadstring(str)` and `load(func)` were separate. In 5.2 they are merged.

### `loadfile([filename [, mode [, env]]])` → function or nil, err
Same as `load` but reads from a file. Without argument, reads from stdin.

### `next(table [, index])` → key, value or nil
Returns the next key-value pair after `index` in the table (traversal order is unspecified for non-integer keys). Pass `nil` or omit `index` to get the first pair. Returns `nil` when the table is exhausted. Used internally by `pairs`.
```lua
local k, v = next(t)      -- first pair
local k2, v2 = next(t, k) -- pair after k
```

### `pairs(t)` → iterator, t, nil
Returns an iterator suitable for traversing all key-value pairs of `t`, including non-integer keys. Order is not defined. In Lua 5.2, if `t` has a `__pairs` metamethod, that is called instead.
```lua
for k, v in pairs({a=1, b=2, c=3}) do print(k, v) end
```

### `pcall(f [, arg1, ...])` → bool, ...
Calls `f` with given arguments in *protected mode*. Catches all errors. Returns `true` plus results on success, or `false` plus the error object on failure. See Section 11 for details.

### `print(...)`
Outputs arguments to stdout separated by tabs, followed by newline. Calls `tostring` on each argument. Not meant for formatted output (use `string.format` + `io.write` for that).

### `rawequal(v1, v2)` → bool
Equality comparison without invoking `__eq` metamethod.

### `rawget(table, index)` → value
Gets `table[index]` without invoking `__index` metamethod.

### `rawlen(v)` → integer (Lua 5.2+)
Returns the length of a table or string without invoking `__len` metamethod. **Does not exist in Lua 5.1.**

### `rawset(table, index, value)` → table
Sets `table[index] = value` without invoking `__newindex` metamethod. Returns the table.

### `require(modname)` → ...
Loads a module. Looks in `package.loaded[modname]` first. If not found, searches using `package.searchers` (Lua 5.2) / `package.loaders` (Lua 5.1). Caches result in `package.loaded[modname]`. See Section 8.

### `select(index, ...)` → ...
If `index` is a number, returns all arguments from position `index` onwards. If `index` is `"#"`, returns total count of extra args.
```lua
select(2, "a", "b", "c")    --> "b", "c"
select("#", "a", "b", "c")  --> 3
```

### `setmetatable(table, metatable)` → table
Sets `metatable` as the metatable of `table`. If `metatable` is `nil`, removes the metatable. Errors if the current metatable has a `__metatable` field. Returns the table.

### `tonumber(e [, base])` → number or nil
Converts `e` to a number. If `base` given (2–36), parses `e` as a string integer in that base. Returns `nil` if conversion fails.
```lua
tonumber("42")      --> 42
tonumber("0xff")    --> 255
tonumber("10", 2)   --> 2  (binary)
tonumber("ff", 16)  --> 255
```

### `tostring(v)` → string
Converts value to string. Calls `__tostring` metamethod if present. Numbers are formatted reasonably. Functions/tables/userdata give type+address by default.

### `type(v)` → string
Returns the type name as a string. Possible values: `"nil"`, `"boolean"`, `"number"`, `"string"`, `"table"`, `"function"`, `"thread"`, `"userdata"`.
```lua
type(nil)        --> "nil"
type(true)       --> "boolean"
type(42)         --> "number"
type("hello")    --> "string"
type({})         --> "table"
type(print)      --> "function"
```

### `_VERSION` → string
Global string with the Lua version: `"Lua 5.2"` (or `"Lua 5.1"` in the WoW client).

### `xpcall(f, msgh [, arg1, ...])` → bool, ...
Like `pcall` but calls `msgh(err)` *before* the stack unwinds on error, allowing traceback capture. In Lua 5.1, extra args not supported. See Section 11.

---

## 2. `string.*` Functions

Strings in Lua have a metatable with `__index = string`, so method syntax works: `("hello"):upper()`.

### `string.byte(s [, i [, j]])` → integer, ...
Returns internal numeric codes (ASCII/UTF-8 byte values) of characters `s[i]` through `s[j]`. Default `i=1`, `j=i`.
```lua
string.byte("ABC")        --> 65
string.byte("ABC", 2)     --> 66
string.byte("ABC", 1, 3)  --> 65, 66, 67
```

### `string.char(...)` → string
Converts integer codes back to a string.
```lua
string.char(65, 66, 67)  --> "ABC"
```

### `string.dump(function [, strip])` → string
Returns the binary representation of `function` as a string. `strip=true` (Lua 5.2+) strips debug info. Useful for serializing compiled functions.

### `string.find(s, pattern [, init [, plain]])` → start, end [, captures...] or nil
Searches for `pattern` starting at position `init` (default 1; negative counts from end). Returns start/end positions plus any captures, or `nil`. If `plain=true`, disables pattern magic (literal search).
```lua
string.find("hello world", "world")       --> 7, 11
string.find("hello world", "(%a+)", 7)    --> 7, 11, "world"
string.find("a+b", "+", 1, true)          --> 2, 2  (literal +)
```

### `string.format(formatstring, ...)` → string
Produces formatted output like C `printf`. See Section 12 for format specifiers.
```lua
string.format("%05.2f", 3.1)        --> "03.10"
string.format("%08x", 255)          --> "000000ff"
string.format("%-10s|", "hello")    --> "hello     |"
string.format("%q", 'say "hi"')     --> '"say \"hi\""'
```

### `string.gmatch(s, pattern)` → iterator
Returns an iterator that yields successive matches of `pattern` in `s`. If captures present, yields them; otherwise yields the whole match. `^` anchor not useful here.
```lua
for word in string.gmatch("one two three", "%a+") do
  print(word)
end
for k, v in string.gmatch("a=1, b=2", "(%a+)=(%d+)") do
  print(k, v)
end
```

### `string.gsub(s, pattern, repl [, n])` → string, count
Replaces all (or first `n`) matches of `pattern` in `s`. Returns the new string and the replacement count.
- `repl` as **string**: `%0`=whole match, `%1`–`%9`=captures, `%%`=literal `%`
- `repl` as **function**: called with captures (or whole match); return value replaces match (nil/false = no replacement)
- `repl` as **table**: `repl[capture1]` used as replacement (nil/false = no replacement)
```lua
string.gsub("hello world", "%a+", string.upper)   --> "HELLO WORLD", 2
string.gsub("hello", "(h)(e)", "%2%1")             --> "ehlllo", 1
string.gsub("$x + $y", "%$(%a+)", {x="10", y="20"}) --> "10 + 20", 2
```

### `string.len(s)` → integer
Returns length in bytes. Same as `#s`.

### `string.lower(s)` → string
Returns a copy with all uppercase letters converted to lowercase.

### `string.match(s, pattern [, init])` → captures... or nil
Returns captures from the first match, or the whole match if no captures. Returns `nil` on no match.
```lua
string.match("2026-03-17", "(%d+)-(%d+)-(%d+)")  --> "2026", "03", "17"
string.match("hello", "%a+")                      --> "hello"
```

### `string.rep(s, n [, sep])` → string
Returns `s` repeated `n` times. `sep` is inserted between repetitions (**Lua 5.2+ only**).
```lua
string.rep("ab", 3)       --> "ababab"
string.rep("ab", 3, ",")  --> "ab,ab,ab"  -- 5.2+ only
```

### `string.reverse(s)` → string
Returns `s` with byte order reversed.

### `string.sub(s, i [, j])` → string
Returns the substring from position `i` to `j` (default `j=-1`). Negative indices count from the end (`-1` = last char).
```lua
string.sub("ABCDEF", 2, 4)   --> "BCD"
string.sub("ABCDEF", -3)     --> "DEF"
string.sub("ABCDEF", 2, -2)  --> "BCDE"
```

### `string.upper(s)` → string
Returns a copy with all lowercase letters converted to uppercase.

---

## 3. `table.*` Functions

### `table.concat(t [, sep [, i [, j]]])` → string
Concatenates elements `t[i]` through `t[j]` into a string separated by `sep`. Elements must be strings or numbers. Default: `sep=""`, `i=1`, `j=#t`.
```lua
table.concat({"a","b","c"}, ", ")      --> "a, b, c"
table.concat({1,2,3}, "-", 2, 3)       --> "2-3"
```

### `table.insert(t, [pos,] value)`
Inserts `value` at position `pos` (default: appends to end), shifting up subsequent elements.
```lua
local t = {1, 2, 3}
table.insert(t, 4)      -- {1,2,3,4}
table.insert(t, 2, 99)  -- {1,99,2,3,4}
```

### `table.move(a1, f, e, t [, a2])` → a2 (Lua 5.2+)
Copies elements `a1[f..e]` to `a2` (default: `a1`) starting at index `t`. Handles overlapping ranges correctly. Returns `a2`.
```lua
local t = {1,2,3,4,5}
table.move(t, 1, 3, 2)  -- shift right: {1,1,2,3,5}
```

### `table.pack(...)` → table (Lua 5.2+)
Packs all arguments into a new table with field `n` set to the total count. Preserves `nil` values (unlike `{...}` which stops at nil under some circumstances).
```lua
local t = table.pack(10, 20, nil, 40)
-- t = {10, 20, nil, 40, n=4}
print(t.n)  --> 4
```

### `table.remove(t [, pos])` → value
Removes and returns the element at `pos` (default: last element), shifting subsequent elements down.
```lua
table.remove(t)     -- removes and returns last element
table.remove(t, 1)  -- removes and returns first element
```

### `table.sort(t [, comp])`
Sorts `t` in-place. Optional `comp(a, b)` function must return `true` if `a` should come before `b`. Default is `<` (ascending). Sort is **not stable**.
```lua
table.sort(t)                                     -- ascending
table.sort(t, function(a, b) return a > b end)    -- descending
table.sort(t, function(a, b) return a.name < b.name end)  -- by field
```

### `table.unpack(t [, i [, j]])` → ... (Lua 5.2+)
### `unpack(t [, i [, j]])` → ... (Lua 5.1 / WoW client)
Returns elements `t[i]` through `t[j]` as separate values. Default: `i=1`, `j=#t`.
```lua
-- Lua 5.2 (Eluna):
print(table.unpack({10, 20, 30}))    --> 10  20  30
local a, b = table.unpack({5, 6, 7}) -- a=5, b=6 (7 discarded)

-- Passing table as varargs to a function:
math.max(table.unpack({3,1,4,1,5,9}))  --> 9
```

---

## 4. `math.*` Functions

All trigonometric functions work in **radians**. Use `math.rad()` / `math.deg()` to convert.

| Function | Signature | Description |
|----------|-----------|-------------|
| `math.abs` | `(x) → number` | Absolute value |
| `math.ceil` | `(x) → integer` | Round toward positive infinity |
| `math.floor` | `(x) → integer` | Round toward negative infinity |
| `math.max` | `(x, ...) → number` | Maximum of all arguments |
| `math.min` | `(x, ...) → number` | Minimum of all arguments |
| `math.sqrt` | `(x) → number` | Square root |
| `math.sin` | `(x) → number` | Sine (radians) |
| `math.cos` | `(x) → number` | Cosine (radians) |
| `math.tan` | `(x) → number` | Tangent (radians) |
| `math.asin` | `(x) → number` | Arc sine → radians |
| `math.acos` | `(x) → number` | Arc cosine → radians |
| `math.atan` | `(x) → number` | Arc tangent → radians |
| `math.atan2` | `(y, x) → number` | Arc tangent of y/x (quadrant-correct) |
| `math.sinh` | `(x) → number` | Hyperbolic sine |
| `math.cosh` | `(x) → number` | Hyperbolic cosine |
| `math.tanh` | `(x) → number` | Hyperbolic tangent |
| `math.deg` | `(x) → number` | Radians to degrees |
| `math.rad` | `(x) → number` | Degrees to radians |
| `math.exp` | `(x) → number` | e^x (natural exponential) |
| `math.log` | `(x [, base]) → number` | Logarithm; base defaults to e. **Lua 5.2+** accepts optional base |
| `math.log10` | `(x) → number` | Base-10 log (**Lua 5.1 only**; use `math.log(x,10)` in 5.2) |
| `math.pow` | `(x, y) → number` | x^y (same as `x^y` operator; **removed in Lua 5.3**) |
| `math.fmod` | `(x, y) → number` | Floating-point remainder of x/y (same sign as x) |
| `math.modf` | `(x) → integer, fraction` | Returns integral part AND fractional part as two values |
| `math.frexp` | `(x) → mantissa, exponent` | Decomposes x = m × 2^e where 0.5 ≤ m < 1 |
| `math.ldexp` | `(m, e) → number` | Returns m × 2^e |
| `math.random` | `() → float` | Pseudo-random float in [0, 1) |
| `math.random` | `(n) → integer` | Pseudo-random integer in [1, n] |
| `math.random` | `(m, n) → integer` | Pseudo-random integer in [m, n] |
| `math.randomseed` | `(x)` | Seeds the pseudo-random generator |
| `math.huge` | constant | Positive infinity (`1/0`) |
| `math.pi` | constant | π ≈ 3.14159265358979 |

```lua
math.modf(3.7)        --> 3,  0.7
math.modf(-3.7)       --> -3, -0.7
math.atan2(1, 0)      --> 1.5707... (π/2)
math.log(100, 10)     --> 2.0  (log base 10; Lua 5.2+ only)
math.random(1, 6)     --> random die roll 1-6
math.floor(3.9)       --> 3
math.ceil(3.1)        --> 4
```

---

## 5. `io.*` Functions

The `io` library provides file I/O. Files are userdata with methods (`:read()`, `:write()`, `:close()`, etc.).

### `io.open(filename [, mode])` → file or nil, errmsg
Opens a file. Mode string: `"r"` (read, default), `"w"` (write/truncate), `"a"` (append), `"r+"` (read+write), `"w+"` (read+write/truncate), `"a+"` (read+append). Append `"b"` for binary mode (`"rb"`, `"wb"`, etc.). Returns file handle or `nil, errmsg`.
```lua
local f, err = io.open("log.txt", "w")
if not f then error(err) end
f:write("hello\n")
f:close()
```

### `io.close([file])`
Closes `file` (or the default output file if omitted).

### `io.flush()`
Flushes the default output file.

### `io.input([file])` → file
Sets the default input file. If `file` is a string, opens it. If omitted, returns the current default.

### `io.output([file])` → file
Sets the default output file. If `file` is a string, opens it for writing. If omitted, returns the current default.

### `io.lines([filename [, ...]])` → iterator
Returns an iterator that reads from `filename` (or default input) line by line. Auto-closes the file when done (when opened by name).
```lua
for line in io.lines("data.txt") do
  print(line)
end
```

### `io.popen(prog [, mode])` → file
Opens a pipe to/from program `prog`. `mode` is `"r"` (read stdout) or `"w"` (write stdin). Platform-specific.

### `io.read([format, ...])` → ...
Reads from default input. Formats: `"*l"` / `"l"` (line without newline, default), `"*L"` / `"L"` (line with newline), `"*n"` / `"n"` (number), `"*a"` / `"a"` (whole file), number (read N bytes).

### `io.tmpfile()` → file
Returns a temporary file handle opened for read/write. Deleted on program exit.

### `io.type(obj)` → string or nil
Returns `"file"` (open file), `"closed file"`, or `nil` (not a file).

### `io.write(...)` → file or nil, errmsg
Writes all arguments to default output (no newline, no tab). Arguments must be strings or numbers. Returns the file handle on success.

### File handle methods (`:method()` syntax)
```lua
file:read(...)     -- same formats as io.read
file:write(...)    -- same as io.write but to this file
file:lines(...)    -- iterator like io.lines
file:close()       -- close the file
file:flush()       -- flush write buffers
file:seek([whence [, offset]]) → position
  -- whence: "set" (from start), "cur" (from current), "end" (from end)
  -- returns new position in bytes from start; no args = get current position
file:setvbuf(mode [, size])
  -- mode: "no", "full", "line"
```

---

## 6. `os.*` Functions

### `os.clock()` → number
CPU time used by the program in seconds. Use for measuring elapsed CPU time.
```lua
local t = os.clock()
-- ... do work ...
print(os.clock() - t, "seconds CPU time")
```

### `os.date([format [, time]])` → string or table
Formats the time `time` (default: current time). If `format` starts with `!`, uses UTC. If `format` is `"*t"`, returns a table.

Table fields: `year`, `month` (1–12), `day` (1–31), `hour` (0–23), `min` (0–59), `sec` (0–60), `wday` (1=Sun), `yday` (1–366), `isdst` (bool).

Format codes: `%Y` (4-digit year), `%y` (2-digit year), `%m` (01–12), `%d` (01–31), `%H` (00–23), `%M` (00–59), `%S` (00–60), `%A` (full weekday), `%a` (abbreviated weekday), `%B` (full month), `%b` (abbreviated month), `%p` (AM/PM), `%X` (time), `%x` (date), `%c` (date+time).
```lua
os.date("%Y-%m-%d")          --> "2026-03-17"
os.date("%H:%M:%S")          --> "14:30:00"
os.date("*t").hour           --> 14
os.date("!%Y-%m-%dT%H:%M:%SZ")  --> UTC ISO 8601
```

### `os.difftime(t2, t1)` → number
Returns `t2 - t1` in seconds.

### `os.execute([command])` → status, kind, code
Executes a shell command. Without argument, returns `true` if a shell is available. Returns exit status, `"exit"` or `"signal"`, and the exit code/signal number. (Return values changed in Lua 5.2.)

### `os.exit([code [, close]])` (Lua 5.2+)
Terminates the process. `code` can be `true` (success), `false` (failure), or an integer. `close=true` calls all `__close` metamethods and finalizers.

### `os.getenv(varname)` → string or nil
Returns the value of the environment variable `varname`, or `nil` if not set.

### `os.remove(filename)` → true or nil, errmsg
Removes a file or empty directory.

### `os.rename(oldname, newname)` → true or nil, errmsg
Renames/moves a file.

### `os.setlocale(locale [, category])` → string or nil
Sets locale. Returns the new locale name or `nil` on failure. Categories: `"all"`, `"collate"`, `"ctype"`, `"monetary"`, `"numeric"`, `"time"`.

### `os.time([t])` → integer
Returns current time as seconds since epoch. If table `t` given (fields: `year`, `month`, `day`, `hour`=12, `min`=0, `sec`=0, `isdst`=false), converts to epoch.
```lua
os.time()                          --> 1742169000 (example)
os.time({year=2026, month=1, day=1}) --> epoch for 2026-01-01 noon
```

### `os.tmpname()` → string
Returns a file path usable for a temporary file. You must open and manage the file yourself (differs from `io.tmpfile()`).

---

## 7. `coroutine.*` Functions

Coroutines are cooperative multitasking within a single thread. Each coroutine has its own stack and local variables. Only one coroutine runs at a time.

### `coroutine.create(f)` → thread
Creates a new coroutine from function `f`. Returns it as a `thread` value in `"suspended"` state.

### `coroutine.resume(co [, val1, ...])` → bool, ...
Starts or continues coroutine `co`. On first call, extra args are passed to `f`. On subsequent calls, extra args are the return values of `yield`. Runs in protected mode. Returns:
- `true, yield_values...` — coroutine called `yield`
- `true, return_values...` — coroutine returned normally
- `false, error_message` — coroutine raised an error
```lua
local co = coroutine.create(function(a, b)
  coroutine.yield(a + b)
  return a * b
end)
print(coroutine.resume(co, 3, 4))  --> true  7   (yielded)
print(coroutine.resume(co))        --> true  12  (returned)
print(coroutine.resume(co))        --> false "cannot resume dead coroutine"
```

### `coroutine.yield([val1, ...])` → ...
Suspends the running coroutine. Values passed to `yield` become extra returns of `resume`. Returns the values passed to the next `resume` call.

### `coroutine.status(co)` → string
Returns the status:
- `"running"` — the coroutine is currently executing
- `"suspended"` — waiting to be resumed (or just created)
- `"normal"` — resumed another coroutine (is active but not running)
- `"dead"` — finished or errored

### `coroutine.wrap(f)` → function
Creates a coroutine and returns a wrapper function. Each call to the wrapper resumes the coroutine and returns yielded values. Errors propagate normally (not caught as with `resume`).
```lua
local gen = coroutine.wrap(function()
  for i = 1, 3 do coroutine.yield(i) end
end)
print(gen())  --> 1
print(gen())  --> 2
print(gen())  --> 3
-- gen()      -- error: cannot resume dead coroutine
```

### `coroutine.running()` → thread, bool (Lua 5.2+)
Returns the running coroutine and a boolean that is `true` if it is the main thread.

**Producer-consumer pattern:**
```lua
local co = coroutine.create(function()
  local items = {"a", "b", "c"}
  for _, item in ipairs(items) do
    coroutine.yield(item)
  end
end)

while true do
  local ok, val = coroutine.resume(co)
  if not ok or val == nil then break end
  print(val)
end
```

**Key Lua 5.2 coroutine change:** `pcall` and metamethods can now `yield` (they could not in Lua 5.1).

---

## 8. `package.*` / require

### `require(modname)` → ...
Loads a module. Steps:
1. Check `package.loaded[modname]` — return cached result if present
2. Search through `package.searchers` (Lua 5.2) / `package.loaders` (Lua 5.1)
3. Call the loader, cache and return the result
```lua
local json = require("json")
local utils = require("mymod.utils")  -- maps to mymod/utils.lua
```

### `package.loaded` (table)
Cache of already-loaded modules. Set `package.loaded["mod"] = nil` to force re-require.

### `package.path` (string)
Semicolon-separated list of patterns for finding Lua files. `?` replaced by module name (dots become path separators). Example: `"./?.lua;./lib/?.lua"`.

### `package.cpath` (string)
Like `package.path` but for C libraries (`.so` / `.dll`).

### `package.preload` (table)
Table of loader functions. If `package.preload[modname]` exists, it is called before searching files.

### `package.searchers` (table) — Lua 5.2
### `package.loaders` (table) — Lua 5.1
Array of searcher functions. Default searchers: (1) check `preload`, (2) search Lua files via `path`, (3) search C libs via `cpath`, (4) all-in-one C loader.

### `package.searchpath(name, path [, sep [, rep]])` → filename or nil, errmsg (Lua 5.2+)
Searches for `name` in `path` string. Replaces `sep` (default `.`) with `rep` (default path separator) in name, then substitutes in each `?` template.

### `package.loadlib(libname, funcname)` → function or nil, errmsg, where
Loads C library `libname` and returns function `funcname` from it. Low-level; prefer `require`.

### `package.config` (string)
Platform-specific configuration string (path separator, etc.).

---

## 9. `bit32.*` Functions (Lua 5.2 only)

The `bit32` library treats all numbers as **unsigned 32-bit integers**. Input values are reduced modulo 2^32. Results are always in [0, 2^32).

**Note:** `bit32` was present in Lua 5.2 and removed in Lua 5.3 (which added native integer bitwise operators). In the WoW client (Lua 5.1), it does not exist.

### `bit32.band([...])` → integer
Bitwise AND of all arguments. With no args returns 0xFFFFFFFF.
```lua
bit32.band(0xFF, 0x0F)   --> 15  (0x0F)
```

### `bit32.bor([...])` → integer
Bitwise OR of all arguments. With no args returns 0.
```lua
bit32.bor(0x01, 0x02, 0x04)  --> 7
```

### `bit32.bxor([...])` → integer
Bitwise XOR of all arguments.
```lua
bit32.bxor(0xFF, 0x0F)   --> 240  (0xF0)
```

### `bit32.bnot(x)` → integer
Bitwise NOT (complement). Equivalent to `0xFFFFFFFF XOR x`.
```lua
bit32.bnot(0)   --> 4294967295  (0xFFFFFFFF)
bit32.bnot(1)   --> 4294967294
```

### `bit32.btest([...])` → bool
Returns `true` if the bitwise AND of all arguments is not zero.
```lua
bit32.btest(0xFF, 0x04)  --> true  (flag is set)
bit32.btest(0xF0, 0x0F)  --> false (no common bits)
```

### `bit32.lshift(x, disp)` → integer
Left shift `x` by `disp` positions. Vacated bits are filled with 0. If `disp >= 32` or `disp <= -32`, result is 0.
```lua
bit32.lshift(1, 4)   --> 16
bit32.lshift(1, 31)  --> 2147483648
```

### `bit32.rshift(x, disp)` → integer
Logical right shift (unsigned). Vacated bits are 0.
```lua
bit32.rshift(16, 4)  --> 1
bit32.rshift(0xFF, 4) --> 15
```

### `bit32.arshift(x, disp)` → integer
Arithmetic right shift (signed). The most significant bit is replicated.
```lua
bit32.arshift(0x80000000, 1)  --> 0xC0000000 (sign extended)
```

### `bit32.lrotate(x, disp)` → integer
Rotate `x` left by `disp` bits (bits shifted out reenter on the right).
```lua
bit32.lrotate(1, 4)   --> 16
```

### `bit32.rrotate(x, disp)` → integer
Rotate `x` right by `disp` bits.

### `bit32.extract(n, field [, width])` → integer
Extracts `width` (default 1) bits from `n` starting at bit position `field` (0 = LSB). Returns the extracted value as unsigned integer.
```lua
bit32.extract(0xABCD, 8, 8)  --> 0xAB
bit32.extract(0xFF, 4, 4)    --> 15
```

### `bit32.replace(n, v, field [, width])` → integer
Returns a copy of `n` with `width` (default 1) bits starting at `field` replaced by the low bits of `v`.
```lua
bit32.replace(0xFF00, 0xAB, 0, 8)  --> 0xFF AB
```

**WoW-relevant pattern** — checking unit flags (similar to how awesome_wotlk implements UnitIsControlled):
```lua
local UNIT_FLAG_STUNNED   = bit32.lshift(1, 20)  -- 0x00100000
local UNIT_FLAG_CONFUSED  = bit32.lshift(1, 2)   -- 0x00000004
local flags = GetUnitFlags(unit)  -- hypothetical

if bit32.btest(flags, UNIT_FLAG_STUNNED) then
  -- unit is stunned
end
```

---

## 10. `debug.*` Functions

The debug library provides reflective capabilities. Use sparingly; it can break normal scoping and GC assumptions.

### `debug.debug()`
Enters an interactive REPL loop reading lines from stdin. Continues until `cont` is typed. Useful as a breakpoint when called from `xpcall`.

### `debug.gethook([thread])` → func, mask, count
Returns the current hook function, hook mask string, and hook count for a thread (default: current thread).

### `debug.getinfo([thread,] f [, what])` → table
Returns a table with information about function `f` (a function, or a stack level number). `what` selects fields:
- `"n"` — name, namewhat
- `"S"` — source, short_src, linedefined, lastlinedefined, what
- `"l"` — currentline
- `"t"` — istailcall
- `"u"` — nups (upvalue count), nparams, isvararg
- `"f"` — func (the function itself)
- `"L"` — activelines
```lua
debug.getinfo(1, "nSl")  -- info about current function
debug.getinfo(print)     -- info about print
```

### `debug.getlocal([thread,] level, local)` → name, value
Returns the name and value of local variable `local` at stack level `level`. Returns `nil` if no variable with that index.

### `debug.setlocal([thread,] level, local, value)` → name
Sets the value of a local variable.

### `debug.getmetatable(object)` → table or nil
Returns the metatable of `object` regardless of `__metatable` protection (unlike `getmetatable`).

### `debug.setmetatable(object, table)` → object
Sets the metatable of `object`, bypassing `__metatable` protection.

### `debug.getregistry()` → table
Returns the Lua registry (a special global table used by C extensions).

### `debug.getupvalue(f, up)` → name, value
Returns the name and current value of upvalue number `up` of function `f`.

### `debug.setupvalue(f, up, value)` → name
Sets the value of upvalue `up` of function `f`. Returns the upvalue's name.

### `debug.upvalueid(f, n)` → id (Lua 5.2+)
Returns a unique identifier for the n-th upvalue of function `f`. Useful to check if two closures share the same upvalue.

### `debug.upvaluejoin(f1, n1, f2, n2)` (Lua 5.2+)
Makes the n1-th upvalue of f1 refer to the same upvalue as the n2-th upvalue of f2. (Shares state between closures.)

### `debug.getuservalue(u)` → value (Lua 5.2+)
Returns the Lua value associated with userdata `u`.

### `debug.setuservalue(udata, value)` → udata (Lua 5.2+)
Sets the Lua value associated with userdata `udata`.

### `debug.sethook([thread,] hook, mask [, count])`
Sets a hook function called on events. `mask` string: `"c"` (calls), `"r"` (returns), `"l"` (line steps). `count > 0` adds a count hook (called every N instructions). `hook=nil` removes the hook.
```lua
debug.sethook(function(event)
  print(event, debug.getinfo(2, "nSl").currentline)
end, "l")  -- trace every line
```

### `debug.traceback([thread,] [message [, level]])` → string
Returns a string with a traceback of the call stack. `level` specifies where to start (default 1). Called in `xpcall` handlers for rich error messages.
```lua
xpcall(riskyFn, function(err)
  print(debug.traceback(err, 2))
end)
```

---

## 11. Error Handling

### `pcall(f [, arg1, ...])` → bool, ...
Calls `f` with arguments in *protected mode*. Catches all runtime errors and `error()` calls. Returns:
- `true, result1, ...` on success
- `false, error_object` on error (the error object can be any Lua value)
```lua
local ok, result = pcall(function(x)
  if x < 0 then error("negative!") end
  return math.sqrt(x)
end, -1)
-- ok=false, result="input:2: negative!"

-- With table error objects:
local ok, err = pcall(function()
  error({code=404, msg="not found"})
end)
if not ok then
  print(err.code, err.msg)  -- 404  not found
end
```

### `xpcall(f, msgh [, arg1, ...])` → bool, ...
Like `pcall` but calls `msgh(err)` **before the stack unwinds**, enabling full traceback capture.
- **Lua 5.1 (WoW client):** `xpcall(f, msgh)` — no extra args. Wrap: `xpcall(function() f(a,b) end, msgh)`
- **Lua 5.2+ (Eluna):** Extra args pass through: `xpcall(f, msgh, a, b)`
```lua
local function errorHandler(err)
  return debug.traceback(tostring(err), 2)
end

local ok, result = xpcall(riskyFn, errorHandler, arg1, arg2)
```

### `error(message [, level])`
Terminates current function and raises an error. Level controls where the error position points:
- `level=1` (default) — the error function itself
- `level=2` — the calling function (most useful for argument checking)
- `level=0` — no position info added
```lua
local function checkType(v, expected)
  if type(v) ~= expected then
    error("expected " .. expected .. ", got " .. type(v), 2)
  end
end
```

### `assert(v [, msg])` → v, ...
If `v` is falsy, raises error with `msg`. Otherwise returns all arguments. A concise guard:
```lua
assert(n > 0, "n must be positive")
local data = assert(loadData(), "failed to load")
```

---

## 12. String Pattern Syntax

Lua patterns are **not** POSIX/Perl regex. Notable limitations: no `|` alternation, no `{n,m}` counted quantifiers, no lookahead/lookbehind.

### Magic Characters (must escape with `%` to match literally)
```
( ) . % + - * ? [ ^ $
```

### Character Classes

| Class | Matches | Complement |
|-------|---------|------------|
| `.` | Any character | — |
| `%a` | Letters (a-z, A-Z) | `%A` |
| `%d` | Digits 0-9 | `%D` |
| `%l` | Lowercase letters | `%L` |
| `%u` | Uppercase letters | `%U` |
| `%s` | Whitespace (space, tab, newline, etc.) | `%S` |
| `%w` | Alphanumeric (letters + digits) | `%W` |
| `%p` | Punctuation characters | `%P` |
| `%c` | Control characters | `%C` |
| `%x` | Hexadecimal digits (0-9, a-f, A-F) | `%X` |
| `%z` | Null byte (char code 0) | `%Z` |
| `%g` | Printable non-space (**Lua 5.2+ only**) | `%G` |

### Character Sets `[...]`
- `[abc]` — matches a, b, or c
- `[a-z0-9]` — ranges
- `[%a%d_]` — mix of classes and literals
- `[^abc]` — negation (anything except a, b, c)
- Hyphen at start or end of set is literal: `[-+]`

### Quantifiers

| Quantifier | Meaning | Strategy |
|------------|---------|----------|
| `*` | 0 or more | Greedy (longest match) |
| `+` | 1 or more | Greedy |
| `?` | 0 or 1 | Optional |
| `-` | 0 or more | Lazy (shortest match) |

```lua
-- Greedy vs lazy:
string.match("/*comment*/", "/%*.*%*/")    --> "/*comment*/"  (greedy *)
string.match("/*a*/ /*b*/", "/%*.-%*/")   --> "/*a*/"        (lazy -)
```

### Anchors
- `^` at **start** of pattern — anchors to start of string
- `$` at **end** of pattern — anchors to end of string
```lua
string.match("hello123", "^%a+")   --> "hello"   (only at start)
string.match("hello123", "%d+$")   --> "123"     (only at end)
```

### Captures `( )`
Parentheses define captures returned by `match`, `find`, and `gmatch`. Empty capture `()` returns a position number.
```lua
string.match("2026-03-17", "(%d+)-(%d+)-(%d+)")  --> "2026", "03", "17"
string.match("hello", "()%a+()")                  --> 1, 6  (positions)
```

### Backreferences `%1`–`%9`
Refer to previously captured text in the *same pattern*:
```lua
string.match("aabbcc", "(%a)%1")   --> "a"  (matches doubled letter)
```

### Balanced Match `%bxy`
Matches a balanced string starting with `x` and ending with `y`. Handles nesting.
```lua
string.match("(a(b)c)", "%b()")   --> "(a(b)c)"
string.match("{a{b}c}", "%b{}")   --> "{a{b}c}"
```

### Frontier Pattern `%f[set]` (Lua 5.2+)
Matches an empty position between a character NOT in `set` and a character IN `set`. A zero-width match useful for word boundaries.
```lua
string.gsub("THE END", "%f[%a]%a+", string.lower)  --> "the end"
```

### `string.format` Specifiers

| Specifier | Meaning |
|-----------|---------|
| `%d`, `%i` | Signed decimal integer |
| `%u` | Unsigned decimal integer |
| `%o` | Octal integer |
| `%x`, `%X` | Hexadecimal lower/upper |
| `%e`, `%E` | Scientific notation |
| `%f` | Decimal float |
| `%g`, `%G` | Shorter of `%e`/`%f` |
| `%c` | Character from integer code |
| `%s` | String (calls `tostring` if needed) |
| `%q` | Quoted string (Lua-readable, with escapes) |
| `%%` | Literal `%` |

Flags between `%` and letter: `-` (left-align), `+` (force sign), ` ` (space for positive), `0` (zero-pad), width (minimum field width), `.precision`.
```lua
string.format("%010.4f", math.pi)   --> "003.1416"
string.format("%-10s|%s", "hi", "!")  --> "hi        |!"
string.format("%q", 'line1\nline2')  -- quoted with escapes
```

---

## 13. Metatables & Metamethods

A metatable is a regular Lua table attached to another table (or userdata) via `setmetatable`. It defines how the object behaves under various operations. Retrieve with `getmetatable`.

### Setting a Metatable
```lua
local mt = {}
local obj = setmetatable({}, mt)
```

### Arithmetic Metamethods
Called when an operand is a table/userdata (or when neither operand is a string/number for `..`).

| Metamethod | Trigger | Signature |
|------------|---------|-----------|
| `__add(a, b)` | `a + b` | Either operand triggers check |
| `__sub(a, b)` | `a - b` | |
| `__mul(a, b)` | `a * b` | |
| `__div(a, b)` | `a / b` | |
| `__mod(a, b)` | `a % b` | |
| `__pow(a, b)` | `a ^ b` | |
| `__unm(a)` | `-a` | Unary minus |
| `__concat(a, b)` | `a .. b` | Only if not both string/number |
| `__len(a)` | `#a` | Tables can override `#` in Lua 5.2+; only userdata in 5.1 |

### Comparison Metamethods
| Metamethod | Trigger | Notes |
|------------|---------|-------|
| `__eq(a, b)` | `a == b` | Only called when values are not rawequal. In Lua 5.2, both values must have the same metamethod; in 5.1, same metatable required |
| `__lt(a, b)` | `a < b` | |
| `__le(a, b)` | `a <= b` | Falls back to `not (b < a)` using `__lt` if not defined |

### Table Access Metamethods
| Metamethod | Trigger | Behavior |
|------------|---------|----------|
| `__index(t, k)` | `t[k]` when key absent | Can be a **function** `(t, k)` → value, or a **table** (Lua redoes lookup there). Enables prototype chains. |
| `__newindex(t, k, v)` | `t[k] = v` when key absent | Can be a **function** `(t, k, v)` or a **table** (assignment redirected there). Only fires when key is **not already present** in the table. |

```lua
-- __index as function:
mt.__index = function(t, k)
  return "default"
end

-- __index as table (prototype chain):
local proto = {greet = function(self) print("hello") end}
mt.__index = proto
obj:greet()  -- found in proto via __index

-- __newindex to track writes:
mt.__newindex = function(t, k, v)
  print("setting", k, "=", v)
  rawset(t, k, v)  -- rawset bypasses __newindex; prevents infinite loop
end
```

### Other Metamethods
| Metamethod | Trigger | Notes |
|------------|---------|-------|
| `__call(obj, ...)` | `obj(...)` — calling a non-function | Receives `obj` as first arg, then all call args |
| `__tostring(a)` | `tostring(a)` | Controls output of `print()` and `tostring()` |
| `__gc(a)` | GC collects `a` | **Tables** get `__gc` in Lua 5.2+; only userdata in 5.1. Called before object is freed. |
| `__mode` | — | String `"k"` (weak keys), `"v"` (weak values), `"kv"` (both). Set on the **metatable of a table** to make it a weak table. |
| `__pairs(t)` | `pairs(t)` | Lua 5.2+: customize iteration with `pairs` |
| `__ipairs(t)` | `ipairs(t)` | Lua 5.2+: customize iteration with `ipairs` |
| `__metatable` | `getmetatable(t)` | If present, `getmetatable` returns this value instead of the real metatable (protects it). Also blocks `setmetatable`. |

### rawget / rawset / rawequal / rawlen
Bypass all metamethods:
```lua
rawget(t, k)          -- t[k] without __index
rawset(t, k, v)       -- t[k]=v without __newindex
rawequal(a, b)        -- a==b without __eq
rawlen(t)             -- #t without __len (Lua 5.2+)
```

### Key Detail: __newindex Only on New Keys
`__newindex` is only invoked when the key does **not** already exist in the table. To intercept all writes, keep the actual data in a separate table and use `rawset`:
```lua
local data = {}
local proxy = setmetatable({}, {
  __index = data,
  __newindex = function(t, k, v)
    print("write:", k, "=", v)
    data[k] = v  -- store in the backing table
  end
})
proxy.x = 10  -- triggers __newindex
proxy.x = 20  -- also triggers __newindex (key is in data, not proxy)
```

---

## 14. OOP Pattern with `setmetatable`

### Basic Class
```lua
local Animal = {}
Animal.__index = Animal  -- self-referential: instance lookup falls through to Animal

function Animal:new(name, sound)
  local instance = setmetatable({}, self)
  instance.name = name
  instance.sound = sound
  return instance
end

function Animal:speak()
  print(self.name .. " says " .. self.sound)
end

function Animal:__tostring()
  return "Animal(" .. self.name .. ")"
end

local cat = Animal:new("Cat", "meow")
cat:speak()          --> "Cat says meow"
print(tostring(cat)) --> "Animal(Cat)"
```

**Why `Animal.__index = Animal` works:** When a key is missing from `instance`, Lua checks `instance`'s metatable for `__index`. Since the metatable is `Animal` and `Animal.__index = Animal`, Lua looks up the key in `Animal` itself — the class table.

### Inheritance
```lua
local Dog = setmetatable({}, {__index = Animal})  -- Dog inherits from Animal
Dog.__index = Dog

function Dog:new(name)
  local instance = Animal.new(self, name, "woof")  -- call parent constructor
  return instance
end

function Dog:fetch(item)
  print(self.name .. " fetches the " .. item)
end

local rex = Dog:new("Rex")
rex:speak()        --> "Rex says woof"   (inherited from Animal)
rex:fetch("ball")  --> "Rex fetches the ball"
print(rex:IsKindOf and "yes" or "no")  -- nil, not defined
```

### Checking Membership
```lua
function Animal:IsA(class)
  local mt = getmetatable(self)
  while mt do
    if mt == class then return true end
    mt = getmetatable(mt)  -- walk the chain
  end
  return false
end
```

---

## 15. Language Features: Closures, Varargs, goto

### Closures
A closure captures references to upvalues (variables from enclosing scopes). The captured variable is shared across all closures that reference it.
```lua
function makeCounter(start)
  local count = start or 0
  return {
    inc  = function() count = count + 1 end,
    dec  = function() count = count - 1 end,
    get  = function() return count end,
  }
end

local c = makeCounter(10)
c.inc(); c.inc()
print(c.get())  --> 12
```

**Pitfall — loop closures:**
```lua
local funcs = {}
for i = 1, 3 do
  -- BAD: all three share the same `i` upvalue which ends at 4
  funcs[i] = function() return i end
end
-- All return 4 after the loop

-- GOOD: create a new local per iteration
for i = 1, 3 do
  local j = i
  funcs[i] = function() return j end
end
-- funcs[1]() = 1, funcs[2]() = 2, funcs[3]() = 3
```

### Varargs (`...`)
A function defined with `...` can receive any number of extra arguments.
```lua
local function sum(...)
  local total = 0
  for _, v in ipairs({...}) do total = total + v end
  return total
end
print(sum(1, 2, 3, 4))  --> 10

-- select for varargs:
local function logAll(fmt, ...)
  local n = select("#", ...)    -- count args
  print(string.format(fmt, ...))
end

-- table.pack preserves nils (Lua 5.2+):
local function first3(...)
  local t = table.pack(...)
  return t[1], t[2], t[3]
end
```

### `goto` Statement (Lua 5.2+)
Unconditional jump to a label `::name::`. Restrictions: cannot jump into a block, cannot jump over a local variable declaration, cannot jump out of a function.
```lua
-- continue-like pattern (Lua has no continue):
for i = 1, 10 do
  if i % 2 == 0 then goto continue end
  print(i)  -- only odd numbers
  ::continue::
end

-- break from nested loops:
for i = 1, 5 do
  for j = 1, 5 do
    if i * j > 10 then goto done end
  end
end
::done::
print("finished")
```

### Multiple Returns and Multiple Assignment
```lua
local function minmax(t)
  local mn, mx = t[1], t[1]
  for _, v in ipairs(t) do
    if v < mn then mn = v end
    if v > mx then mx = v end
  end
  return mn, mx
end

local lo, hi = minmax({3,1,4,1,5,9})  --> lo=1, hi=9

-- Only first value used in most contexts:
local x = minmax({3,1,4})  --> x=1, second value discarded
local t = {minmax({3,1,4})}  --> t={1, 4}  (all values in table literal)
```

### `_ENV` (Lua 5.2+)
The global environment is an upvalue `_ENV` of every chunk. `_G` is the initial value of `_ENV`. You can sandbox code by loading with a custom environment:
```lua
local sandbox = {print = print, math = math}
local fn = load("return math.sqrt(9)", "sandbox", "t", sandbox)
print(fn())  --> 3.0
```

---

## 16. Lua 5.1 vs 5.2 — Critical Differences

**WoW 3.3.5a client uses Lua 5.1. Eluna server scripting uses Lua 5.2.**

| Feature | Lua 5.1 (WoW Client AddOns) | Lua 5.2 (Eluna/Server Scripts) |
|---------|------------------------------|--------------------------------|
| **`unpack`** | Global: `unpack(t)` | Moved to `table.unpack(t)`; global `unpack` removed |
| **`table.pack`** | Does not exist | `table.pack(...)` → table with `.n` field |
| **`table.move`** | Does not exist | `table.move(a1, f, e, t [, a2])` |
| **Global environment** | `_G`; `getfenv()`/`setfenv()` available | `_ENV` upvalue; `getfenv`/`setfenv` removed |
| **`loadstring`** | `loadstring(str)` separate from `load` | `loadstring` removed; use `load(str)` |
| **`load`** | `load(func)` only takes a reader function | `load(str_or_func [, name, mode, env])` |
| **`goto`** | Not available | `goto label` / `::label::` supported |
| **`rawlen`** | Does not exist | `rawlen(t)` — length without `__len` |
| **Bit operations** | No built-in (use external BitLib) | `bit32` library: `band`, `bor`, `bxor`, `bnot`, `lshift`, `rshift`, `extract`, `replace`, etc. |
| **`math.log`** | Natural log only: `math.log(x)` | Optional base: `math.log(x [, base])` |
| **`math.log10`** | `math.log10(x)` available | Removed; use `math.log(x, 10)` |
| **`string.rep` sep** | No separator argument | `string.rep(s, n, sep)` — separator added |
| **`xpcall` args** | `xpcall(f, handler)` — no extra args | `xpcall(f, handler, arg1, arg2, ...)` |
| **`pcall`/metamethods yielding** | Cannot yield across pcall/metamethods | Can yield across pcall and metamethods |
| **`coroutine.running`** | Returns just the coroutine | Returns coroutine + bool (true if main thread) |
| **`__gc` on tables** | Only on userdata | Tables can have `__gc` finalizers |
| **`__len`** | Only strings and userdata | Tables can override `#` operator |
| **`__eq`** | Requires same metatable on both operands | Requires same metamethod function on both |
| **`__pairs`/`__ipairs`** | Not available | `pairs`/`ipairs` call these if present |
| **`package.loaders`** | `package.loaders` (array) | Renamed to `package.searchers` |
| **`package.searchpath`** | Does not exist | `package.searchpath(name, path)` |
| **`module()`** | Available | Removed |
| **`\z` in strings** | Not supported | `\z` in a string literal skips following whitespace |
| **Hex floats** | Not supported | `0x1.8p+1` hex float literals |
| **`string.format %g`** | Produces `'-0'` for negative zero | Fixed behavior |
| **Empty statement** | Not valid | `;` is valid as an empty statement |
| **`break` placement** | Must be last statement in a block | Can appear anywhere |
| **`collectgarbage` options** | Fewer options | Adds `"isrunning"`, `"generational"`, `"incremental"` |

**Compatibility shim for cross-version code:**
```lua
-- Make 5.2-style table functions work in 5.1:
table.unpack = table.unpack or unpack
table.pack = table.pack or function(...)
  return {n = select('#', ...), ...}
end

-- bit32-like ops using WoW's built-in bit library (if present):
-- In WoW client, use the `bit` library if available, or manual math
local function band(a, b)  -- fallback
  local result = 0
  local bit = 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then result = result + bit end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end
```

---

## 17. awesome_wotlk DLL Enhancements

**Source:** https://github.com/FrostAtom/awesome_wotlk

A C++ DLL-based improvement library for WoW 3.3.5a (build 12340). Adds new Lua functions, events, and CVars to the unmodified client via binary patching + DLL loading.

### Architecture Overview

Two components:
1. **`AwesomeWotlkPatch.exe`** — a static binary patcher that modifies `Wow.exe` to load `AwesomeWotlkLib.dll` on startup and copies the DLL to the game folder.
2. **`AwesomeWotlkLib.dll`** — the runtime library (C++) that hooks into game internals at startup.

**Key dependencies:** Microsoft Detours (function interception).

### Hooking Technique

The DLL uses **Microsoft Detours** to intercept 8 game functions at hardcoded memory addresses specific to build 12340:

| Hook Target | Address | Purpose |
|-------------|---------|---------|
| `CVars_Initialize` | `0x0051D9B0` | Register custom console variables |
| `FrameScript_FillEvents` | — | Inject custom Lua events |
| `Lua_OpenFrameXMLApi` | — | Add custom Lua libraries to the scripting environment |
| `FrameScript_FireOnUpdate` | — | Execute per-frame callbacks |
| `LoadGlueXML` | — | Post-load callbacks after UI XML |
| `LoadCharacters` | — | Fire callbacks during character selection |
| `GetFromClipboard` | `0x008726F0` | UTF-8 clipboard read fix |
| `SetToClipboard` | `0x008727E0` | UTF-8 clipboard write fix |
| `Camera_Initialize` | — | Inject custom FOV |

**Pattern:** Each hook stores the original function pointer, uses `DetourAttach()` to redirect, and the wrapper calls the original after custom logic. Naked assembly (`__declspec(naked)`) is used where register preservation is required.

### Binary Patch Format (Patch.h)
```cpp
struct PatchDetails {
    unsigned virtualAddress;  // e.g. 0x004DCCF0
    const char* hexBytes;     // x86 opcodes as hex string
};
```
The patcher reads the PE file, converts virtual addresses to file offsets using section headers, and `memcpy`s the new bytes in.

### New Lua API Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `C_NamePlate.GetNamePlates` | `() → table` | Returns table of all currently visible nameplate frames |
| `C_NamePlate.GetNamePlateForUnit` | `(unitId: string) → frame` | Returns the nameplate frame for the given unit token |
| `UnitIsControlled` | `(unitId: string) → bool` | True if unit has FLEEING, CONFUSED, STUNNED, or PACIFIED flags set |
| `UnitIsDisarmed` | `(unitId: string) → bool` | True if unit is disarmed |
| `UnitIsSilenced` | `(unitId: string) → bool` | True if unit is silenced |
| `GetInventoryItemTransmog` | `(unitId: string, slot: number) → itemId, enchantId` | Returns visible item entry + enchant for the given equipment slot (1-based) |
| `FlashWindow` | `()` | Calls Windows API `FlashWindow()` on the game HWND |
| `IsWindowFocused` | `() → 1 or 0` | 1 if game window is the foreground window |
| `FocusWindow` | `()` | Calls `SetForegroundWindow()` on game HWND |
| `CopyToClipboard` | `(text: string)` | UTF-8 safe clipboard copy |

### New Events

| Event | arg1 | Description |
|-------|------|-------------|
| `NAME_PLATE_CREATED` | `namePlateBase` (frame) | Fires when a nameplate frame is created |
| `NAME_PLATE_UNIT_ADDED` | `unitId` (string) | Fires when a nameplate becomes visible |
| `NAME_PLATE_UNIT_REMOVED` | `unitId` (string) | Fires before a nameplate is hidden |

```lua
-- Usage example:
local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:SetScript("OnEvent", function(self, event, unitId)
  if event == "NAME_PLATE_UNIT_ADDED" then
    local plate = C_NamePlate.GetNamePlateForUnit(unitId)
    -- customize the nameplate frame here
  end
end)
```

### New CVars

| CVar | Default | Range | Description |
|------|---------|-------|-------------|
| `nameplateDistance` | 41 | — | Nameplate visibility distance in yards |
| `cameraFov` | 100 | 1–200 | Camera field of view (100=default, higher=fisheye) |

```lua
SetCVar("cameraFov", "120")   -- wider FOV
SetCVar("nameplateDistance", "60")
```

### Bug Fixes

**Non-English clipboard:** The original client incorrectly handled multi-byte characters in clipboard operations, showing `"???"` for non-ASCII text. The fix replaces `GetFromClipboard` / `SetToClipboard` with UTF-16 → UTF-8 converting wrappers using Windows `WideCharToMultiByte`/`MultiByteToWideChar`.

### Auto-Login Command Line

```
Wow.exe -login "USERNAME" -password "PASSWORD" -realmlist "HOST" -realmname "REALMNAME" -character "CHARNAME"
```

The `CommandLine.cpp` module hooks `PostLoad` (login screen) and `CharEnum` (character selection) Glue events. On `PostLoad`, it sets the `realmList`/`realmName` CVars and calls `NetClient::Login()`. On `CharEnum`, it calls `LoginUI::EnterWorld()` for the matched character. Each action executes exactly once per session (`static bool s_once`).

### WoW 3.3.5a Client Memory Map (from GameClient.h)

Relevant hardcoded addresses for build 12340:

| Symbol | Address | Description |
|--------|---------|-------------|
| Game window handle | `0x00D41620` | HWND of main window |
| Target GUID | `0x00BD07B0` | Current target's GUID |
| WorldFrame pointer | `0x00B7436C` | Main 3D scene frame |
| Active camera function | `0x004F5960` | Returns the active camera object |

**Object model:** `Object → Unit → Player` hierarchy. Units have 7 power types tracked as arrays, extensive flag fields for combat states, and faction/equipment slot data. Player extends with guild, duel arbiter, character appearance, and quest/item arrays.

### Source Files

```
src/
  AwesomeWotlkLib/
    Entry.cpp       -- DLL entry point, DetourAttach calls
    Hooks.cpp       -- All Detours hook wrappers
    GameClient.h    -- WoW data structures and memory addresses
    NamePlates.cpp  -- C_NamePlate API + events
    UnitAPI.cpp     -- UnitIsControlled/Disarmed/Silenced
    Inventory.cpp   -- GetInventoryItemTransmog
    Misc.cpp        -- FlashWindow, FocusWindow, CopyToClipboard, cameraFov CVar
    CommandLine.cpp -- Auto-login feature
    BugFixes.cpp    -- Clipboard UTF-8 fix
    Utils.cpp       -- UTF-8/UTF-16 conversion utilities
  AwesomeWotlkPatch/
    Main.cpp        -- Reads Wow.exe, applies binary patches, copies DLL
    Patch.h         -- Patch struct + s_patches[] array with addresses/bytes
```

**Community:** Discord: https://discord.gg/NNnBTK5c8e | Telegram: https://t.me/wow_soft
