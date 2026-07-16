### Hash maps in practice

`std::unordered_map` gives average O(1) lookup and insert with **no
ordering**. The canonical use is frequency counting:

```cpp
#include <iostream>
#include <string>
#include <unordered_map>
#include <vector>

int main()
{
    std::vector<std::string> words{"a", "b", "a", "c", "b", "a"};

    std::unordered_map<std::string, int> freq;
    for (const auto& w : words)
        ++freq[w];                    // a missing key value-inits to 0 first

    for (const auto& [word, n] : freq)
        std::cout << word << ": " << n << '\n';
}
```

Same "`[]` inserts a default" behavior as `std::map` — probe with `find`
or (C++20) `contains` when you don't want that side effect:

```cpp
if (freq.find("z") == freq.end())
    std::cout << "no z\n";
```

`reserve` when you know the element count — it cuts the rehashing a
growing table would do:

```cpp
std::unordered_map<int, int> m;
m.reserve(10000);
```

### Gotchas

- Iteration order is unspecified and changes on rehash — never depend on
  it. Use `std::map` when you need sorted keys.
- A custom key type needs a hash: specialize `std::hash<Key>`, or pass a
  hasher as the third template argument.
- Pointers and references to elements survive a rehash, but
  **iterators do not**.
