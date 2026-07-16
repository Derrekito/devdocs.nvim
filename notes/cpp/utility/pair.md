### Pairs in practice

`std::pair` bundles two values — it's the type of a map element and a
common "two things at once" return:

```cpp
#include <iostream>
#include <string>
#include <utility>

std::pair<bool, int> parse(const std::string& s)
{
    if (s.empty()) return {false, 0};
    return {true, std::stoi(s)};
}

int main()
{
    auto [ok, value] = parse("42");      // structured bindings (C++17)
    if (ok) std::cout << value << '\n';
}
```

`.first` / `.second` reach the members; `std::make_pair` deduces the
types (or use braces / class-template argument deduction):

```cpp
auto p = std::make_pair(1, std::string{"one"});
std::cout << p.first << " = " << p.second << '\n';
std::pair q{2, 3.5};                     // CTAD -> pair<int, double>
```

### Iterating a map with structured bindings

`std::map`/`std::unordered_map` iterate as `pair<const Key, Value>` —
structured bindings (C++17) turn the usual `it->first`/`it->second`
noise into named variables:

```cpp
#include <iostream>
#include <map>
#include <string>

int main()
{
    std::map<std::string, int> scores{{"alice", 90}, {"bob", 85}};
    for (const auto& [name, score] : scores)
        std::cout << name << ": " << score << '\n';
}
```

```text
alice: 90
bob: 85
```

### Sorting by pair for free lexicographic order

`std::pair` compares lexicographically out of the box — `.first` first,
`.second` breaks ties. Sorting a vector of pairs needs no comparator at
all when that's the order you want:

```cpp
#include <algorithm>
#include <iostream>
#include <utility>
#include <vector>

int main()
{
    std::vector<std::pair<int, std::string>> ranked{
        {2, "bob"}, {1, "carol"}, {1, "alice"},
    };
    std::sort(ranked.begin(), ranked.end());   // by rank, then name

    for (const auto& [rank, name] : ranked)
        std::cout << rank << ' ' << name << '\n';
}
```

```text
1 alice
1 carol
2 bob
```

### Gotchas

- Prefer structured bindings (`auto [a, b] = p;`) to `.first`/`.second` —
  far clearer, especially when iterating a map.
- `make_pair` decays its arguments (arrays to pointers, drops
  references); brace-init `std::pair<T, U>{a, b}` keeps exactly the types
  you name.
- Lexicographic comparison compares `.second` even when `.first` differs
  in a way you didn't intend to break ties on — write a custom comparator
  if that's not the order you want.
- More than two fields? Use `std::tuple`, or better, a named struct.
