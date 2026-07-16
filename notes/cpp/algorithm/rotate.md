### Rotate in practice

`std::rotate` cyclically shifts a range so that the element at `middle`
becomes the new first — everything before it wraps around to the end:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4, 5};
    std::rotate(v.begin(), v.begin() + 2, v.end());   // middle = index 2
    for (int x : v) std::cout << x << ' ';            // 3 4 5 1 2
    std::cout << '\n';
}
```

It returns an iterator to where the old first element landed. A common
use is moving one element to a new position (slide-insert) without
erasing and re-inserting:

```cpp
std::vector<int> v{10, 20, 30, 40};
// move v[0] to just before v[3]: rotate the sub-range [begin, begin+3)
std::rotate(v.begin(), v.begin() + 1, v.begin() + 3);   // 20 30 10 40
```

For a right rotation by `k`, rotate about `end() - k`:

```cpp
std::vector<int> v{1, 2, 3, 4, 5};
std::rotate(v.begin(), v.end() - 2, v.end());   // 4 5 1 2 3
```

### Gotchas

- `middle` must lie within `[first, last]`; it's the element that ends up
  first. Left-rotate by `k` → `first + k`; right-rotate by `k` →
  `last - k`.
- It mutates in place; use `std::rotate_copy` to write the rotation into
  a separate range and keep the original.
- Rotating an empty range or with `middle == first`/`middle == last` is a
  well-defined no-op — no need to special-case it.
