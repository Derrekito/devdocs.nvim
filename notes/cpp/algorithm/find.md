### Find in practice

`std::find` locates the first element equal to a value and returns
`end()` when there's no match — always test that first:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{4, 8, 15, 16, 23};

    if (auto it = std::find(v.begin(), v.end(), 15); it != v.end())
        std::cout << "at index " << (it - v.begin()) << '\n';
    else
        std::cout << "absent\n";
}
```

`std::find_if` takes a predicate instead of a value:

```cpp
auto it = std::find_if(v.begin(), v.end(),
                       [](int x){ return x > 10; });   // first > 10
```

`std::find_if_not` is the negation — the first element that fails the
predicate:

```cpp
auto brk = std::find_if_not(v.begin(), v.end(),
                            [](int x){ return x % 2 == 0; });   // first odd
```

### Gotchas

- The result is an **iterator**, not an index or bool — compare against
  `end()`; get a position with `it - v.begin()` (random-access ranges
  only).
- `std::find` is linear (O(n)). On a **sorted** range use
  `std::binary_search` / `std::lower_bound`; on `std::set`/`std::map` use
  their `.find()` member.
- For finding text inside a string use `std::string::find`, not
  `std::find`.
