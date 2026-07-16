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

### Gotchas

- A view **does not own** its data — never return one that refers to a
  local `std::string` or a temporary; it dangles the moment that owner
  dies.
- Not guaranteed null-terminated: don't hand `.data()` to C APIs that
  expect a `\0` terminator — use `std::string` for that.
- It's read-only as a span; build a `std::string` when you need to own or
  mutate the characters.
