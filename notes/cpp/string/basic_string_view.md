### string_view in practice

`std::string_view` (C++17) is a non-owning window over character data —
a `{pointer, length}` pair. Take it by value for read-only string
parameters: it binds to `std::string`, string literals, and `char*` with
no copy:

```cpp
#include <iostream>
#include <string_view>

void log(std::string_view msg)           // no allocation, no copy
{
    std::cout << "[log] " << msg << '\n';
}

int main()
{
    std::string owned = "hello";
    log(owned);        // from a std::string
    log("world");      // from a literal
}
```

Slicing is free — `substr` returns another view, not a new buffer:

```cpp
std::string_view path = "/usr/local/bin";
std::string_view last = path.substr(path.find_last_of('/') + 1);   // "bin"
```

### Never return a view into a local temporary

The classic dangling bug: build a `std::string` inside a function, then
return a `std::string_view` of it. The string is destroyed when the
function returns, so the view immediately dangles — this compiles
cleanly and only misbehaves at runtime:

```cpp
#include <string>
#include <string_view>

// BAD: `local` is destroyed on return; the view outlives its owner.
std::string_view greet_bad(std::string_view name)
{
    std::string local = "Hello, " + std::string(name);
    return local;   // implicit std::string -> std::string_view, dangles
}
```

Fix it by returning an owning `std::string` instead — only return a view
when it points into something the *caller* already owns (a parameter, a
member, a string literal):

```cpp
#include <string>
#include <string_view>

std::string greet_good(std::string_view name)
{
    return "Hello, " + std::string(name);   // caller owns the result
}
```

### Build a view over a non-null-terminated buffer

Construct from a pointer and explicit length when the data isn't (or
might not be) `\0`-terminated — e.g. a slice of a larger buffer:

```cpp
#include <iostream>
#include <string_view>

int main()
{
    char buf[] = {'a', 'b', 'c', 'd', 'e'};
    std::string_view mid(buf + 1, 3);   // "bcd", no terminator needed
    std::cout << mid << '\n';
}
```

```text
bcd
```

### Check prefixes and suffixes (C++20)

`starts_with` / `ends_with` avoid a manual `substr` + `==`:

```cpp c++20
#include <iostream>
#include <string_view>

int main()
{
    std::string_view file = "report.pdf";
    std::cout << file.starts_with("report") << ' '
              << file.ends_with(".pdf") << '\n';
}
```

```text
1 1
```

### Gotchas

- A view **does not own** its data — never return one that refers to a
  local `std::string` or a temporary; it dangles the moment that owner
  dies.
- Not guaranteed null-terminated: don't hand `.data()` to C APIs that
  expect a `\0` terminator — use `std::string` for that.
- It's read-only as a span; build a `std::string` when you need to own or
  mutate the characters.
