### std::max in practice

`std::max` returns the larger of two values — or the largest of an
initializer list:

```cpp
#include <algorithm>
#include <iostream>

int main()
{
    std::cout << std::max(3, 7) << '\n';           // 7
    std::cout << std::max({4, 1, 8, 2}) << '\n';   // 8
}
```

Two everyday idioms — a running maximum, and flooring a value:

```cpp
int best = 0;
for (int x : {3, -1, 9, 4})
    best = std::max(best, x);                      // best == 9

int nonneg = std::max(0, -5);                      // 0  (floor at zero)
```

For the largest element of a **range** use `std::max_element`, which
returns an iterator:

```cpp
#include <vector>
std::vector<int> v{5, 2, 8, 1};
auto it = std::max_element(v.begin(), v.end());    // *it == 8
```

### Gotchas

- `std::max(a, b)` returns a **reference** — `const auto& m =
  std::max(f(), g());` dangles once the temporaries die. Bind to `auto`
  (a copy) when an argument is a temporary.
- Mixed types don't compile: `std::max(0, 1.5)` fails deduction (int vs
  double). Match them — `std::max(0.0, 1.5)` — or force the type with
  `std::max<double>(0, 1.5)`.
- On a tie it returns the **first** argument. For both extremes in one
  pass use `std::minmax` / `std::minmax_element`.
