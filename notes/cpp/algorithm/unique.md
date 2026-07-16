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
first:

```cpp
std::vector<int> v{3, 1, 2, 1, 3, 2};
std::sort(v.begin(), v.end());
v.erase(std::unique(v.begin(), v.end()), v.end());   // 1 2 3
```

### Gotchas

- `unique` alone leaves unspecified leftovers in the tail — forgetting
  the `erase` is the classic bug (the container keeps its original size).
- It collapses only **adjacent** duplicates; on unsorted input,
  non-adjacent repeats survive (note the two `1`s in the first example).
- A custom predicate can redefine "equal" (e.g. case-insensitive), but it
  must be consistent with how the range was sorted.
