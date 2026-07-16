### Pairs in practice

`std::pair` bundles two values — it's the type of a map element and a
common "two things at once" return:

```cpp
#include <iostream>
#include <string>
#include <utility>

std::pair<bool, int> parse(const std::string& s)
{
    if (s.empty()) return {false, 0};
    return {true, std::stoi(s)};
}

int main()
{
    auto [ok, value] = parse("42");      // structured bindings (C++17)
    if (ok) std::cout << value << '\n';
}
```

`.first` / `.second` reach the members; `std::make_pair` deduces the
types (or use braces / class-template argument deduction):

```cpp
auto p = std::make_pair(1, std::string{"one"});
std::cout << p.first << " = " << p.second << '\n';
std::pair q{2, 3.5};                     // CTAD -> pair<int, double>
```

### Gotchas

- Prefer structured bindings (`auto [a, b] = p;`) to `.first`/`.second` —
  far clearer, especially when iterating a map.
- `make_pair` decays its arguments (arrays to pointers, drops
  references); brace-init `std::pair<T, U>{a, b}` keeps exactly the types
  you name.
- More than two fields? Use `std::tuple`, or better, a named struct.
