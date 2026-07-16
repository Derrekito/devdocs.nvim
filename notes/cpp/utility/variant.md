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

### The `overloaded{}` visitor idiom

`std::visit` needs one callable that handles every alternative. Instead
of a chain of `if constexpr`, combine several lambdas — one per type —
into one overload set with a small helper struct. The struct itself is
plain C++17; what makes the *construction* terse is class template
argument deduction (CTAD) picking up the deduction guide implied by the
aggregate's constructors, which is a C++17 feature too, so the whole
idiom works as-is under `-std=c++17`:

```cpp
#include <iostream>
#include <string>
#include <variant>

template <class... Ts>
struct overloaded : Ts... { using Ts::operator()...; };
template <class... Ts>
overloaded(Ts...) -> overloaded<Ts...>;   // deduction guide

int main()
{
    std::variant<int, double, std::string> v = 3.14;

    std::visit(overloaded{
        [](int i)                 { std::cout << "int " << i << '\n'; },
        [](double d)               { std::cout << "dbl " << d << '\n'; },
        [](const std::string& s)  { std::cout << "str " << s << '\n'; },
    }, v);
}
```

```text
dbl 3.14
```

This scales far better than a generic lambda once each alternative
needs different handling, and the compiler flags a missing case at
the call to `visit` (not at some later use).

### Gotchas

- `std::get<T>(v)` on the wrong alternative throws
  `std::bad_variant_access`; reach for `get_if` when unsure.
- A `visit` visitor must handle **every** alternative and return a common
  type — a generic lambda `[](const auto&)` is the easy way to cover them
  all.
- `index()` gives the active alternative (0-based); a default-constructed
  variant holds its first alternative.
- All of `variant`, `visit`, and the `overloaded{}` CTAD trick require
  **C++17**; nothing here needs a newer standard.
