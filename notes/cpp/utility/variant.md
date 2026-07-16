### Variants in practice

`std::variant<A, B, ...>` (C++17) is a type-safe union — it holds
exactly one of its alternatives and remembers which:

```cpp
#include <iostream>
#include <string>
#include <variant>

int main()
{
    std::variant<int, std::string> v = 42;
    v = "hello";                         // now holds a string

    if (std::holds_alternative<std::string>(v))
        std::cout << std::get<std::string>(v) << '\n';
}
```

`std::visit` applies a callable to whichever alternative is active — the
exhaustive way to handle every case:

```cpp
std::variant<int, double, std::string> v = 3.14;
std::visit([](const auto& x){ std::cout << x << '\n'; }, v);
```

`get_if` is the no-throw probe: it returns a pointer, null when that
alternative isn't active:

```cpp
if (auto* p = std::get_if<double>(&v))
    std::cout << "double: " << *p << '\n';
```

### Gotchas

- `std::get<T>(v)` on the wrong alternative throws
  `std::bad_variant_access`; reach for `get_if` when unsure.
- A `visit` visitor must handle **every** alternative and return a common
  type — a generic lambda `[](const auto&)` is the easy way to cover them
  all.
- `index()` gives the active alternative (0-based); a default-constructed
  variant holds its first alternative.
