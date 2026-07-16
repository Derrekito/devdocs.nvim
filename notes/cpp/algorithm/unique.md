### Unique in practice

`std::unique` removes **consecutive** duplicates. Like `remove`, it
doesn't shrink the container — it shuffles the survivors to the front and
returns the new logical end, which you then `erase`:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 1, 2, 3, 3, 3, 1};
    v.erase(std::unique(v.begin(), v.end()), v.end());
    for (int x : v) std::cout << x << ' ';     // 1 2 3 1
    std::cout << '\n';
}
```

Only adjacent equals collapse, so to drop **all** duplicates, sort
first — this is the classic sort–unique–erase idiom:

```cpp
std::vector<int> v{3, 1, 2, 1, 3, 2};
std::sort(v.begin(), v.end());
v.erase(std::unique(v.begin(), v.end()), v.end());   // 1 2 3
```

### Deduplicate a vector with C++20 ranges

`std::ranges::sort` and `std::ranges::unique` (C++20) take the
container directly, and `ranges::unique` returns a subrange instead of
a bare iterator — its `.begin()` is the same "new logical end" you
still pass to `erase`:

```cpp c++20
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{3, 1, 2, 1, 3, 2};
    std::ranges::sort(v);
    v.erase(std::ranges::unique(v).begin(), v.end());
    for (int x : v) std::cout << x << ' ';   // 1 2 3
    std::cout << '\n';
}
```

### Gotchas

- `unique` alone leaves unspecified leftovers in the tail — forgetting
  the `erase` is the classic bug (the container keeps its original size).
- It collapses only **adjacent** duplicates; on unsorted input,
  non-adjacent repeats survive (note the two `1`s in the first example).
- A custom predicate can redefine "equal" (e.g. case-insensitive), but it
  must be consistent with how the range was sorted.
- Don't confuse the erase call above with C++20's `std::erase(container,
  value)` (in `<vector>` etc.) — that free function removes every
  element **equal to a given value**, not adjacent duplicates.
