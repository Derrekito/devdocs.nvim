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

### Chaining optional-returning parsers

A common shape: several steps can each fail, and you want to bail out
on the first empty result without a pyramid of `if`s. Plain C++17 does
this by hand:

```cpp
#include <iostream>
#include <optional>
#include <string>

std::optional<int> to_int(const std::string& s)
{
    try { return std::stoi(s); }
    catch (...) { return std::nullopt; }
}

std::optional<int> half_if_even(int n)
{
    if (n % 2 != 0) return std::nullopt;
    return n / 2;
}

int main()
{
    auto result = to_int("18");
    if (result) result = half_if_even(*result);

    std::cout << result.value_or(-1) << '\n';   // 9
}
```

C++23 adds `and_then` / `transform` / `or_else` to chain this without
the manual `if`. `and_then` takes a callable that itself returns an
`optional` (it flattens); `transform` takes one that returns a plain
value (it wraps the result):

```cpp c++23
#include <iostream>
#include <optional>
#include <string>

std::optional<int> to_int(const std::string& s)
{
    try { return std::stoi(s); }
    catch (...) { return std::nullopt; }
}

std::optional<int> half_if_even(int n)
{
    if (n % 2 != 0) return std::nullopt;
    return n / 2;
}

int main()
{
    auto result = to_int("18").and_then(half_if_even)
                               .transform([](int n){ return n * 10; });
    std::cout << result.value_or(-1) << '\n';   // 90
}
```

### Gotchas

- Dereferencing an empty optional (`*o` / `o->x`) is **undefined
  behavior**; `.value()` instead throws `std::bad_optional_access`.
- `std::optional<bool>` has two kinds of "false" (empty vs holding
  `false`) — test `has_value()` explicitly rather than `operator bool`.
- The value is stored inline (no heap), so a large `T` makes a large
  optional.
- `and_then`/`transform`/`or_else` are **C++23**; on C++17/20 chain
  manually as above, or reach for a small library if you do this a lot.
