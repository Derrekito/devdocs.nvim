### Sets in practice

`std::set` stores **unique**, **sorted** keys. Insert reports whether the
value was new; lookup is O(log n):

```cpp
#include <iostream>
#include <set>

int main()
{
    std::set<int> s{3, 1, 4, 1, 5};      // duplicates dropped -> {1, 3, 4, 5}

    auto [it, inserted] = s.insert(9);
    std::cout << "inserted 9: " << std::boolalpha << inserted << '\n';
    s.insert(3);                          // no-op, already present

    for (int x : s) std::cout << x << ' ';   // ascending: 1 3 4 5 9
    std::cout << '\n';
}
```

Membership: `count` (0 or 1) or, in C++20, `contains`:

```cpp
if (s.count(4)) std::cout << "has 4\n";
```

Because it's ordered, you get range queries for free with
`lower_bound` / `upper_bound`:

```cpp
std::set<int> s{10, 20, 30, 40, 50};
for (auto it = s.lower_bound(20); it != s.upper_bound(40); ++it)
    std::cout << *it << ' ';              // 20 30 40
std::cout << '\n';
```

### Gotchas

- Elements are **immutable** through the set — you can't edit a key in
  place (it would break the ordering); erase and re-insert instead.
- Use the member `s.find(x)` / `s.count(x)`, not `std::find(s.begin(),
  s.end(), x)` — the member is O(log n), the algorithm is O(n).
- Need duplicates? `std::multiset`. Don't need ordering? `std::
  unordered_set` gives average O(1) lookup.
