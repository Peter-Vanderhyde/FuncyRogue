# Funcy — Language Rules & Standard Library (Living Spec)

> This document describes the syntax, semantics, and built-ins of the **Funcy** language used in `.fy` files.

## 1) Lexical & Basics

* **Comments:** `# line comment`
* **Blocks:** `{ ... }` after statements like `func`, `if`, `for`, `while`, `class`.
* **Statements end** by newline or `}`; no semicolons needed (but allowed).
* **Identifiers:** ASCII letters, digits, `_`; start with letter or `_`.
* **Literals:**

  * Integers: `0`, `42`, `-7`
  * Floats: `3.14`, `0.5`
  * Booleans: `true`, `false`
  * Strings: `"double quoted"` (printing/debug may display with `'single quotes'`)
  * Lists: `[1, 2, 3]`
  * Dictionaries: `{ "k": 1, "v": 2 }`
  * Null/None: `null`
* **Operators (common):**

  * Arithmetic: `+ - * / %`
  * Comparisons: `== != < <= > >=`
  * Logical: `not`, `and`, `or`
  * Membership: `in`, `not in`

## 2) Types

Builtin runtime types (debug output may show as `Type:...`):

* `Integer`, `Float`, `Boolean`, `String`, `List`, `Dictionary`
* `Function`, `BuiltInFunction`, `Class`, `Instance`, `Type`, `None`

### Truthiness

* `false`, `0`, `0.0`, `""`, `[]`, `{}`, `null` → **falsey**
* Everything else → truthy

## 3) Variables & Scope

* **Assignment:** `x = expr`
* **Scopes:** Blocks (`{...}`) create scope. Functions create their own local environment.
* **Globals:** To assign to a variable defined in the outermost/global scope from inside a function, declare it:

  ```funcy
  global x;
  x = x + 1;
  ```

  Reading might work without `global`, but **any assignment requires `global`** to target the outermost variable.

## 4) Functions

### Definition & Call

```funcy
func add(a, b) {
    return a + b;
}

print(add(1, 2));
```

* **Arity checking**: Calling with the wrong number of args raises an **Arity Mismatch** error.
* Named/keyword args are supported where applicable (builtins usually do **not** accept labeled args).
* `return expr` (or `return` for implicit `null`).
* Anonymous functions are **not** supported.
* Default arguments allowed (`func foo(x=5)`).

## 5) Classes & Instances

### Definition

```funcy
class Counter {
    func &Counter(start=0) {      # constructor — note the leading &
        &value = start;           # instance field (prefixed with & inside class)
    }

    func &inc() { &value += 1; }  # instance method (mutates via &field)
    func &get() { return &value; }
}
```

### Usage

```funcy
c = Counter(10);
c.inc();
print(c.get());   # 11
```

* Inside a class:

  * `&field` declares/uses instance variables.
  * Methods must be `func &name(...)` to be callable on instances.
* Outside:

  * Call as `obj.method()` — **no `&`** outside.
  * `&` only appears in the definition or when assigning to a field inside class code.

## 6) Control Flow

### If / Elif / Else

```funcy
if cond1 {
    ...
} elif cond2 {
    ...
} else {
    ...
}
```

### While

```funcy
while cond {
    ...
}
```

### For

```funcy
for x in list {
    print(x);
}

for i in range(0, 10) {
    ...
}
```

### C-Style For

```funcy
func init() { ... }
func cond() { return ... }
func inc()  { ... }

for init(), cond(), inc() {
    ...
}
```

## 7) Built-in Functions

* `print(x, y, ...)`
* `length(obj)`
* `type(obj)`
* `str(obj)` — convert to string (dicts/lists → JSON-like string)
* `int(str_or_num)`
* `float(str_or_num)`
* `randInt(min, max)`
* `randChoice(list)`
* `enumerate(list)` — returns list of `[index, value]`
* `time()` — ms since epoch
* `readFile(path)` → string
* `writeFile(path, string)`
* `appendFile(path, string)`
* `string.toJson()` — parse JSON string into dict/list

## 8) String Methods

* `s.split(delim=" ")`
* `s.replace(old, new)`
* `s.lower()`
* `s.upper()`
* Indexing: `s[i]`

## 9) List Methods

* `.append(x)`
* `.clear()`
* Slicing: `lst[start:end]`

## 10) Dictionary Methods

* `.keys()` — list of keys
* `.values()` — list of values
* Membership: `"key" in dict`

## 11) Null & Boolean

* `null` is the null value.
* Booleans are lowercase `true` / `false`.

---

# Entire list of built-in functions

### General Functions:

- `abs(value) -> int|float` - Returns the absolute value of a number.
- `all(list) -> bool` - Returns `true` if all elements of the list are true or the list is empty.
- `any(list) -> bool` - Returns `true` if any element of the list is true.
- `appendFile(file, content) -> Null` - Will add the content onto the end of the existing file content, or create a new file with that content.
- `bool(value) -> bool` - Converts a value to its boolean equivalent.
- `callable(var) -> bool` - Checks if the variable is callable.
- `dict(iterable={}) -> dict` - Creates a dictionary from another dictionary, or a list of key-value pairs.
- `divMod(a, b) -> list` - Returns a list with the quotient and remainder of `a` divided by `b`.
- `enumerate(list) -> list` - Returns index-value pairs for a list.
- `float(value) -> float` - Converts a value to a floating-point number.
- `globals() -> dict` - Returns a dictionary of global variables.
- `input(prompt="") -> string` - Prompts user for input.
- `int(value) -> int` - Converts a value to an integer.
- `length(var) -> int` - Gives the length or size of a string, list, or dictionary.
- `list(iterable=[]) -> list` - Converts an iterable to a list.
- `locals() -> dict` - Returns a dictionary of local variables in the current scope.
- `map(func, list) -> list` - Applies a function to each item in the list and returns a list of results.
- `max(arg1, ...) -> int|float|string|obj` - Returns the maximum value of several arguments, or a list of values.
- `min(arg1, ...) -> int|float|string|obj` - Returns the minimum value of several arguments, or a list of values.
- `print(arg1, ...) -> Null` - Prints arguments.
- `randChoice(list) -> int|float|string|bool|obj` - Picks a random element from a list and returns it.
- `randInt(min, max) -> int` - Chooses a random integer between and including the minimum and maximum given values.
- `range(start=0, end, step=1) -> list` - Generates a range of numbers.
- `readFile(file_path_str) -> string` - Reads from a file. Throws error if file does not exist.
- `reversed(list) -> list` - Returns a reversed version of the sequence.
- `round(value, precision=0) -> float` - Rounds a number to the given precision.
- `str(value) -> string` - Converts a value to a string. Dictionaries converted into a string will maintain json compatible formatting so they can be saved in json files.
- `sum(list) -> int|float` - Returns the sum of all elements in a list.
- `time() -> int` - Returns milliseconds since the start of the application as an integer.
- `type(var) -> Type` - Returns the type of the variable.
- `writeFile(file_path_str, contents) -> Null` - Writes a string to a file. Creates a new file if it does not already exist.
- `zip(list1, list1, ...) -> list` - Combines lists into a list of value pair lists.

### List Functions:

- `append(value) -> Null` - Adds a value to the list.
- `clear() -> Null` - Removes all elements from the list.
- `copy() -> list` - Returns a deep copy of the list.
- `index(value) -> int` - Returns the index of the first occurrence of a value. Errors if no match is found.
- `insert(index, value) -> Null` - Inserts a value at the specified index.
- `pop(index=-1) -> int|float|string|bool|obj|Null` - Removes and returns an item by index.
- `remove(value) -> Null` - Removes the first occurrence of a value. Errors if no match is found.
- `size() -> int` - Returns the number of elements.

### Dictionary Functions:

- `clear() -> Null` - Removes all key-value pairs.
- `copy() -> dict` - Returns a deep copy of the dictionary.
- `get(key, default_return=Null) -> int|float|string|bool|obj|Null` - Retrieves the value for a key.
- `items() -> list` - Returns key-value pairs as a list.
- `keys() -> list` - Returns all keys as a list.
- `pop(key) -> int|float|string|bool|obj|Null` - Removes a key and its value.
- `setDefault(key, default_value) -> int|float|string|bool|obj|Null` - Returns the value of a key or sets it to a default value.
- `size() -> int` - Returns the number of key-value pairs.
- `update(dict) -> Null` - Merges another dictionary.
- `values() -> list` - Returns all values as a list.

### String Functions:

- `capitalize() -> string` - Capitalizes the first letter of the string.
- `endsWith(suffix) -> bool` - Checks if the string ends with the specified suffix.
- `find(sub) -> int` - Finds the first occurrence of a substring and returns the index. Returns -1 if no match is found.
- `isAlpha() -> bool` - Checks if the string contains only alphabetic characters.
- `isAlphaNum() -> bool` - Checks if the string is alphanumeric.
- `isDigit() -> bool` - Checks if the string is numeric.
- `isSpace() -> bool` - Checks if the string contains only spaces.
- `isWhitespace() -> bool` - Checks if the string contains only whitespace.
- `join(list) -> string` - Joins a list of strings.
- `length() -> int` - Returns string length.
- `lower() -> string` - Converts to lowercase.
- `replace(old, new) -> string` - Replaces substrings.
- `split(split_str=" ") -> list` - Splits into a list by a separator.
- `strip(strip_str=whitespace_chars) -> string` - Removes characters from both ends.
- `toJson() -> dictionary` - Converts a string that is in json format into a dictionary object. Pairs well with reading json files.
- `upper() -> string` - Converts to uppercase.

### Instance Functions:

- `delAttr(name_str) -> Null` - Deletes an attribute by name.
- `getAttr(name_str) -> int|float|string|bool|obj|Null` - Gets attributes of an instance using a name string.
- `hasAttr(name_str) -> bool` - Checks if an attribute exists.
- `setAttr(name_str, value) -> Null` - Sets attributes of an instance using a name string.

### Float Functions:

- `isInt() -> bool` - Checks if the float is equivalent to an integer.

**Note:** This document is meant to evolve — add/remove/change features here when Funcy changes or when AI output mistakes need correction.

Null is uppercase