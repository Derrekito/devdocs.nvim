### std::min in practice

`std::min` returns the smaller of two values — or the smallest of an
initializer list. The initializer-list overload is C++11; both it and
the two-argument overload became `constexpr` in C++14:

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
`std::min_element`, which returns an iterator (not `std::min`). In
C++20, `std::ranges::min_element(v)` takes the container directly:

```cpp
#include <vector>
std::vector<int> v{5, 2, 8, 1};
auto it = std::min_element(v.begin(), v.end());    // *it == 1
```

### Avoid a dangling reference from a temporary

`std::min` returns a `const&` to whichever argument is smaller. Binding
that to a reference is fine when the arguments are named objects that
outlive the statement, but if an argument is a temporary, the
reference dangles the moment the full expression ends:

```cpp
std::string make_id() { return "id-42"; }

// WRONG: the temporary from make_id() is destroyed at the end of this
// statement (returning by reference across the call to std::min does
// not extend its lifetime), leaving `bad` dangling.
const std::string& bad = std::min(make_id(), std::string("id-99"));

// RIGHT: copy the winner instead of binding a reference to it.
std::string good = std::min(make_id(), std::string("id-99"));
```

### Get both extremes in one pass

`std::minmax(a, b)` (C++11) returns a `std::pair` of
`{smallest, largest}` instead of two separate calls:

```cpp
auto [lo, hi] = std::minmax(3, 7);
std::cout << lo << ' ' << hi << '\n';   // 3 7
```

### Gotchas

- `std::min(a, b)` returns a **reference**; binding it to `const auto&`
  while an argument is a temporary leaves a dangling reference. Bind to
  `auto` (a copy) when either argument is a temporary.
- On a tie it returns the **first** argument — matters when equal keys
  wrap different objects.
- Both extremes at once → `std::minmax` (pair of values) or
  `std::minmax_element` (pair of iterators, C++11); bounding a value
  into `[lo, hi]` → `std::clamp` (C++17).
