### std::max in practice

`std::max` returns the larger of two values — or the largest of an
initializer list. The initializer-list overload is C++11; both it and
the two-argument overload became `constexpr` in C++14:

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
returns an iterator. In C++20, `std::ranges::max_element(v)` takes the
container directly:

```cpp
#include <vector>
std::vector<int> v{5, 2, 8, 1};
auto it = std::max_element(v.begin(), v.end());    // *it == 8
```

### Avoid a dangling reference from a temporary

`std::max` returns a `const&` to whichever argument is larger. That's
fine for named objects that outlive the statement, but binding it when
an argument is a temporary leaves a dangling reference the moment the
full expression ends — returning by reference across the call does not
extend the temporary's lifetime:

```cpp
std::string longer_of(std::string a, std::string b)
{
    return a.size() >= b.size() ? a : b;
}

// WRONG: the temporary from longer_of(...) is destroyed at the end of
// this statement, leaving `bad` dangling.
const std::string& bad = std::max(longer_of("hi", "hey"),
                                   std::string("hello"));

// RIGHT: copy the winner instead of binding a reference to it.
std::string good = std::max(longer_of("hi", "hey"),
                             std::string("hello"));
```

### Get both extremes of a range in one pass

`std::minmax_element` (C++11) finds both extremes in a single pass,
returning a pair of iterators — cheaper than calling `min_element` and
`max_element` separately:

```cpp
#include <vector>
std::vector<int> v{5, 2, 8, 1};
auto [lo, hi] = std::minmax_element(v.begin(), v.end());
std::cout << *lo << ' ' << *hi << '\n';   // 1 8
```

### Gotchas

- `std::max(a, b)` returns a **reference** — `const auto& m =
  std::max(f(), g());` dangles once the temporaries die. Bind to `auto`
  (a copy) when an argument is a temporary.
- Mixed types don't compile: `std::max(0, 1.5)` fails deduction (int vs
  double). Match them — `std::max(0.0, 1.5)` — or force the type with
  `std::max<double>(0, 1.5)`.
- On a tie it returns the **first** argument. For both extremes in one
  pass use `std::minmax` (pair of values) or `std::minmax_element`
  (pair of iterators), both C++11.
