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

Works for any comparable type — floats, for instance:

```cpp
double x = std::clamp(1.5, 0.0, 1.0);  // 1.0
```

### Clamp by a custom ordering

A comparator overload, also C++17, clamps by any `Compare` instead of
`operator<` — e.g. clamping a string by its length rather than its
lexical value:

```cpp
#include <string>

auto by_length = [](const std::string& a, const std::string& b){
    return a.size() < b.size();
};
std::string clamped = std::clamp(std::string("hi"),
                                  std::string("abc"),
                                  std::string("abcdefgh"),
                                  by_length);   // "abc" (too short)
```

### NaN inputs make the result unspecified

`std::clamp` compares with `<`, and every comparison against NaN is
`false`. If `v`, `lo`, or `hi` is NaN, which branch runs — and
therefore what's returned — is unspecified. Don't rely on NaN being
clamped to a bound, or on it passing through untouched:

```cpp
#include <cmath>
#include <limits>

double nan = std::numeric_limits<double>::quiet_NaN();
double r = std::clamp(nan, 0.0, 1.0);   // unspecified: don't rely on a
                                         // particular result here
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
