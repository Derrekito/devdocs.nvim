### Common algorithms in practice

Every algorithm takes an **iterator range**, not a container, and most
pair with a lambda predicate. Searching:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{3, 1, 4, 1, 5, 9, 2, 6};

    if (auto it = std::find(v.begin(), v.end(), 4); it != v.end())
        std::cout << "found 4 at index " << (it - v.begin()) << '\n';

    auto even = std::find_if(v.begin(), v.end(),
                             [](int x){ return x % 2 == 0; });
    if (even != v.end())
        std::cout << "first even: " << *even << '\n';
}
```

Counting and whole-range predicates:

```cpp
auto ones = std::count(v.begin(), v.end(), 1);
auto bigs = std::count_if(v.begin(), v.end(), [](int x){ return x > 4; });

bool all_pos = std::all_of(v.begin(), v.end(), [](int x){ return x > 0; });
bool any_big = std::any_of(v.begin(), v.end(), [](int x){ return x > 8; });
```

`transform` maps a range into an output — size the destination first, or
use an inserter:

```cpp
std::vector<int> squares(v.size());
std::transform(v.begin(), v.end(), squares.begin(),
               [](int x){ return x * x; });
```

`copy_if` + `std::back_inserter` grows the target as it goes:

```cpp
#include <iterator>

std::vector<int> evens;
std::copy_if(v.begin(), v.end(), std::back_inserter(evens),
             [](int x){ return x % 2 == 0; });
```

`min_element` / `max_element` return iterators, not values:

```cpp
auto lo = std::min_element(v.begin(), v.end());
auto hi = std::max_element(v.begin(), v.end());
std::cout << "range: " << *lo << ".." << *hi << '\n';
```

Fold/sum lives in `<numeric>`, not `<algorithm>`:

```cpp
#include <numeric>
int total = std::accumulate(v.begin(), v.end(), 0);
```

### Erase elements matching a predicate

Pre-C++20, "removing" is a two-step dance: `std::remove_if` shuffles
the survivors to the front and returns the new logical end, then
`erase` drops the leftover tail — the erase-remove idiom:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{3, 1, 4, 1, 5, 9, 2, 6};
    v.erase(std::remove_if(v.begin(), v.end(),
                           [](int x){ return x % 2 == 0; }),
            v.end());
    for (int x : v) std::cout << x << ' ';
    std::cout << '\n';
}
```

```text
3 1 1 5 9
```

`std::erase_if` (C++20, in `<vector>`/`<algorithm>`) collapses that into
one call and works the same way across containers:

```cpp c++20
#include <vector>

std::vector<int> v{3, 1, 4, 1, 5, 9, 2, 6};
std::erase_if(v, [](int x){ return x % 2 == 0; });   // 3 1 1 5 9
```

### Operate on containers directly with ranges (C++20)

`std::ranges::` algorithms (`<algorithm>`) take the container itself —
no `.begin()`/`.end()` pair — and are otherwise drop-in replacements:

```cpp c++20
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{3, 1, 4, 1, 5, 9, 2, 6};
    std::ranges::sort(v);
    if (auto it = std::ranges::find(v, 5); it != v.end())
        std::cout << "found 5\n";
    for (int x : v) std::cout << x << ' ';
    std::cout << '\n';
}
```

```text
found 5
1 1 2 3 4 5 6 9
```

### Gotchas

- These are range-based, not container-based:
  `std::find(v.begin(), v.end(), x)`, not `std::find(v, x)` — the
  container form is the C++20 `std::ranges::find(v, x)`.
- `transform`'s destination must already have room (`resize` it) unless
  you write through an inserter like `std::back_inserter`.
- "Removing" algorithms (`std::remove`, `std::unique`) only shuffle
  elements and return the new logical end; you still `erase` the tail —
  the erase–remove idiom.
