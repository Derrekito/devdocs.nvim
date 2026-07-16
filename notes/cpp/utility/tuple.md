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

### Calling a function with a tuple's contents

`std::apply` (C++17) unpacks a tuple straight into a function call —
handy when the arguments arrive bundled (e.g. from a parser or stored
for later):

```cpp
#include <iostream>
#include <tuple>

int volume(int w, int h, int d) { return w * h * d; }

int main()
{
    auto dims = std::make_tuple(2, 3, 4);
    std::cout << std::apply(volume, dims) << '\n';   // 24
}
```

```text
24
```

### Gotchas

- `std::get<I>(t)` indexes at **compile time** — `I` must be a constant,
  not a runtime value.
- Prefer structured bindings (C++17) to `get`/`tie` for readability; use
  `std::ignore` with `tie` to skip a field you don't need.
- `std::apply` is also **C++17** — the argument count/types must match
  the callable exactly, or it fails to compile.
- A tuple with many fields is a code smell — a named struct documents
  what each field means.
