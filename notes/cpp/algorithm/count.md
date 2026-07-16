### Count in practice

`std::count` tallies elements equal to a value; `std::count_if` tallies
those satisfying a predicate:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 2, 3, 2, 4};

    auto twos = std::count(v.begin(), v.end(), 2);
    auto evens = std::count_if(v.begin(), v.end(),
                               [](int x){ return x % 2 == 0; });
    std::cout << "2s: " << twos << ", evens: " << evens << '\n';   // 2s: 3, evens: 4
}
```

Count occurrences of a character in a string (any range works):

```cpp
#include <string>
std::string s = "mississippi";
auto sn = std::count(s.begin(), s.end(), 's');   // 4
```

### Gotchas

- The return type is the iterator's `difference_type` (a signed integer,
  typically `long`), not `int` — store it in `auto` to sidestep
  `-Wsign-compare` / narrowing.
- `count` is O(n): it scans the whole range every call. On a `std::set` /
  `std::map`, use the member `.count()` (O(log n)); on a sorted range,
  `std::equal_range` gives the span in O(log n).
- Only testing "is there at least one?" Use `std::any_of` (or
  `std::find` != `end()`) — it stops at the first match instead of
  counting them all.
