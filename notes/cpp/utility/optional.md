### Optionals in practice

`std::optional<T>` (C++17) holds either a value or nothing — a type-safe
"maybe" for functions that can fail without an error code:

```cpp
#include <iostream>
#include <optional>
#include <string>

std::optional<int> to_int(const std::string& s)
{
    try { return std::stoi(s); }
    catch (...) { return std::nullopt; }
}

int main()
{
    if (auto n = to_int("42"))
        std::cout << "got " << *n << '\n';
    else
        std::cout << "not a number\n";
}
```

`value_or` supplies a fallback; `has_value()` / `operator bool` test
presence; `*` and `->` reach the value:

```cpp
std::optional<std::string> name;
std::cout << name.value_or("anonymous") << '\n';   // anonymous
name = "alice";
std::cout << name->size() << '\n';                 // 5
```

### Gotchas

- Dereferencing an empty optional (`*o` / `o->x`) is **undefined
  behavior**; `.value()` instead throws `std::bad_optional_access`.
- `std::optional<bool>` has two kinds of "false" (empty vs holding
  `false`) — test `has_value()` explicitly rather than `operator bool`.
- The value is stored inline (no heap), so a large `T` makes a large
  optional.
