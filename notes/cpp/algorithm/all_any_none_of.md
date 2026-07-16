### all_of / any_of / none_of in practice

These three answer a yes/no question about a whole range with a
predicate, short-circuiting at the first decisive element:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{2, 4, 6, 8};

    bool all_even = std::all_of (v.begin(), v.end(), [](int x){ return x % 2 == 0; });
    bool any_big  = std::any_of (v.begin(), v.end(), [](int x){ return x > 5; });
    bool none_neg = std::none_of(v.begin(), v.end(), [](int x){ return x < 0; });

    std::cout << std::boolalpha
              << all_even << ' ' << any_big << ' ' << none_neg << '\n';   // true true true
}
```

They read better than a loop with a flag and stop early — `any_of`
returns at the first match, `all_of`/`none_of` at the first
counterexample:

```cpp
if (std::any_of(v.begin(), v.end(), [](int x){ return x == 6; }))
    std::cout << "has a 6\n";
```

### Gotchas

- On an **empty** range, `all_of` and `none_of` return `true` while
  `any_of` returns `false` (the vacuous-truth convention) — confirm
  that's the answer you want for empty input.
- They yield a bool, not the element: use `std::find_if` to get the
  matching element, `std::count_if` to count matches.
- `all_of(..., pred)` equals `none_of(..., !pred)` — pick whichever reads
  clearest instead of double-negating.
