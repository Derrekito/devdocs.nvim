### Maps in practice

`std::map` keeps keys **sorted** and unique. Insert a few ways, then
look up:

```cpp
#include <iostream>
#include <map>
#include <string>

int main()
{
    std::map<std::string, int> ages;
    ages["alice"] = 30;             // insert, or overwrite if present
    ages.insert({"bob", 25});       // insert only if absent
    ages.emplace("carol", 40);

    std::cout << ages["alice"] << '\n';   // 30
}
```

**`operator[]` inserts a default when the key is missing** — a silent
trap in what looks like a read. To check without inserting, use `find`
or (C++20) `contains`:

```cpp
if (auto it = ages.find("dave"); it != ages.end())
    std::cout << it->second << '\n';
else
    std::cout << "absent\n";
```

Iteration is in ascending key order; structured bindings (C++17) unpack
each pair:

```cpp
for (const auto& [name, age] : ages)
    std::cout << name << " = " << age << '\n';
```

Update-or-insert without a throwaway value: `insert_or_assign` to
overwrite, `try_emplace` to insert only when absent (unlike `[]`,
neither default-constructs then assigns):

```cpp
ages.insert_or_assign("alice", 31);   // updates in place
ages.try_emplace("erin", 22);         // inserts only if absent
```

### Gotchas

- `operator[]` requires a default-constructible value and **mutates the
  map**, so it won't compile on a `const map` — avoid it in read-only
  lookups.
- Stored keys are immutable; you can't edit a key in place, only erase
  and re-insert.
- Want average O(1) lookup and don't need ordering? Use
  `std::unordered_map`.
