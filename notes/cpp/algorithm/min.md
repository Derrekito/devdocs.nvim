### std::min in practice

`std::min` returns the smaller of two values — or the smallest of an
initializer list:

```cpp
#include <algorithm>
#include <iostream>

int main()
{
    std::cout << std::min(3, 7) << '\n';           // 3
    std::cout << std::min({4, 1, 8, 2}) << '\n';   // 1  (initializer list)
}
```

A custom comparator picks "smallest" by any key — e.g. the shorter
string:

```cpp
#include <string>
std::string a = "hello", b = "hi";
const std::string& shorter =
    std::min(a, b, [](const std::string& x, const std::string& y){
        return x.size() < y.size();
    });                                            // "hi"
```

For the smallest element of a **container/range** use
`std::min_element`, which returns an iterator (not `std::min`):

```cpp
#include <vector>
std::vector<int> v{5, 2, 8, 1};
auto it = std::min_element(v.begin(), v.end());    // *it == 1
```

### Gotchas

- `std::min(a, b)` returns a **reference**; binding it to `const auto&`
  while an argument is a temporary leaves a dangling reference. Bind to
  `auto` (a copy) when either argument is a temporary.
- On a tie it returns the **first** argument — matters when equal keys
  wrap different objects.
- Both extremes at once → `std::minmax` (returns a pair); bounding a
  value into `[lo, hi]` → `std::clamp`.
