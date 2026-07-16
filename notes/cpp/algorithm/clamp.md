### Clamp in practice

`std::clamp(v, lo, hi)` (C++17) confines a value to the range
`[lo, hi]` — below `lo` it returns `lo`, above `hi` it returns `hi`,
otherwise `v` unchanged:

```cpp
#include <algorithm>
#include <iostream>

int main()
{
    std::cout << std::clamp(5, 0, 10)  << '\n';   // 5  (in range)
    std::cout << std::clamp(-3, 0, 10) << '\n';   // 0  (below lo)
    std::cout << std::clamp(42, 0, 10) << '\n';   // 10 (above hi)
}
```

Handy for keeping a value in bounds — a volume, an index, a color
channel:

```cpp
int volume = 130;
volume = std::clamp(volume, 0, 100);   // 100
```

Works for any comparable type — floats, for instance (a comparator
overload also exists to clamp by a custom ordering):

```cpp
double x = std::clamp(1.5, 0.0, 1.0);  // 1.0
```

### Gotchas

- It's undefined behavior if `hi < lo` (an inverted range) — validate the
  bounds if they come from input.
- `std::clamp` returns a **reference** to one of its arguments; assigning
  it while an argument is a temporary can dangle. It's safe for the
  common `x = std::clamp(x, lo, hi)` with named bounds.
- All three arguments must be the **same type** — `std::clamp(x, 0, 255)`
  with a `double x` fails to deduce; use `0.0`/`255.0` or
  `std::clamp<double>(...)`.
