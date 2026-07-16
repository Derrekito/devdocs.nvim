### Reverse in practice

`std::reverse` flips a range in place:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4, 5};
    std::reverse(v.begin(), v.end());
    for (int x : v) std::cout << x << ' ';    // 5 4 3 2 1
    std::cout << '\n';
}
```

Any bidirectional range works — reverse a `std::string`, or just a
sub-range:

```cpp
#include <string>
std::string s = "hello";
std::reverse(s.begin(), s.end());             // "olleh"

std::vector<int> v{1, 2, 3, 4, 5};
std::reverse(v.begin(), v.begin() + 3);       // 3 2 1 4 5  (first three only)
```

To iterate reversed **without** mutating, use reverse iterators or
`std::reverse_copy` into another range:

```cpp
std::vector<int> v{1, 2, 3};
for (auto it = v.rbegin(); it != v.rend(); ++it)
    std::cout << *it << ' ';                  // 3 2 1, v unchanged
std::cout << '\n';
```

### Reverse a container directly with C++20 ranges

`std::ranges::reverse` (C++20) takes the container instead of a
begin/end pair:

```cpp c++20
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4, 5};
    std::ranges::reverse(v);
    for (int x : v) std::cout << x << ' ';    // 5 4 3 2 1
    std::cout << '\n';
}
```

### Gotchas

- It mutates in place; when you need the original intact, use
  `std::reverse_copy` (destination must have room) or `rbegin()`/`rend()`
  to read backwards.
- Needs **bidirectional** iterators — fine for `vector`/`string`/`list`,
  but not a forward-only range or a plain input stream.
- Reversing a `std::string` byte-wise corrupts multi-byte UTF-8; reverse
  by code point / grapheme if the text isn't plain ASCII.
- `std::reverse` became `constexpr` in C++20, so a reversal can run at
  compile time inside a `constexpr` function.
