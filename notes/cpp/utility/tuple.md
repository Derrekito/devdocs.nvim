### Tuples in practice

`std::tuple` holds a fixed set of heterogeneous values — handy for
returning several results at once:

```cpp
#include <iostream>
#include <string>
#include <tuple>

std::tuple<std::string, int, double> record()
{
    return {"alice", 30, 1.75};
}

int main()
{
    auto [name, age, height] = record();   // unpack (C++17)
    std::cout << name << ' ' << age << ' ' << height << '\n';
}
```

`std::get<I>` accesses by index; `std::tie` unpacks into existing
variables (and is the classic field-by-field comparison trick):

```cpp
auto t = std::make_tuple(1, 2, 3);
std::cout << std::get<0>(t) << '\n';

int a, b, c;
std::tie(a, b, c) = t;                     // assign into existing vars
```

### Gotchas

- `std::get<I>(t)` indexes at **compile time** — `I` must be a constant,
  not a runtime value.
- Prefer structured bindings to `get`/`tie` for readability; use
  `std::ignore` with `tie` to skip a field you don't need.
- A tuple with many fields is a code smell — a named struct documents
  what each field means.
