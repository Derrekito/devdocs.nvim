### Hash sets in practice

`std::unordered_set` stores **unique** keys with average O(1)
lookup/insert and **no ordering** — the fast membership test:

```cpp
#include <iostream>
#include <unordered_set>

int main()
{
    std::unordered_set<int> seen{1, 2, 3};

    auto [it, inserted] = seen.insert(2);   // already present
    std::cout << "inserted 2: " << std::boolalpha << inserted << '\n';   // false

    if (seen.count(3)) std::cout << "has 3\n";   // or seen.contains(3) in C++20
}
```

The canonical use — dedupe / "have I seen this?" in one pass:

```cpp
#include <string>
#include <vector>

std::vector<std::string> input{"a", "b", "a", "c", "b"};
std::unordered_set<std::string> seen;
for (const auto& s : input)
    if (seen.insert(s).second)          // .second is true only the first time
        std::cout << "first: " << s << '\n';
```

`reserve` when you know the count — it cuts rehashing as the table grows:

```cpp
std::unordered_set<int> s;
s.reserve(10000);
```

### Gotchas

- Iteration order is unspecified and shifts on rehash — never depend on
  it. Use `std::set` when you need sorted keys.
- A custom key type needs a hash: specialize `std::hash<Key>`, or pass a
  hasher as a template argument.
- Use the member `.count()` / `.find()`, not `std::find(...)` over the
  range — the member is O(1) average, the algorithm is O(n).
