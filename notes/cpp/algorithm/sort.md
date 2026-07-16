### Sorting in practice

The default is ascending with `operator<`:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{5, 2, 8, 1, 9};
    std::sort(v.begin(), v.end());          // 1 2 5 8 9
    for (int x : v) std::cout << x << ' ';
    std::cout << '\n';
}
```

Descending — pass a comparator (or `std::greater<>{}` from
`<functional>`):

```cpp
std::sort(v.begin(), v.end(), std::greater<>{});
std::sort(v.begin(), v.end(), [](int a, int b){ return a > b; });
```

Sort structs by a member with a lambda. The comparator answers "does
`a` come **before** `b`?" and must be a strict weak ordering — use `<`,
never `<=`:

```cpp
struct Person { std::string name; int age; };

std::vector<Person> people{{"alice", 30}, {"bob", 25}, {"carol", 30}};
std::sort(people.begin(), people.end(),
          [](const Person& a, const Person& b){ return a.age < b.age; });
```

Need equal elements to keep their original order? `std::sort` doesn't
promise that — use `std::stable_sort`:

```cpp
std::stable_sort(people.begin(), people.end(),
                 [](const Person& a, const Person& b){ return a.age < b.age; });
```

Only need the smallest few? `std::partial_sort` (or `std::nth_element`
for just the split point) beats a full sort:

```cpp
std::partial_sort(v.begin(), v.begin() + 3, v.end());  // 3 smallest, in order
```

Once sorted, `std::binary_search` / `std::lower_bound` give O(log n)
lookups:

```cpp
if (std::binary_search(v.begin(), v.end(), 8))
    std::cout << "found\n";
```

### Gotchas

- `std::sort` needs **random-access** iterators: fine on
  `vector`/`array`/`deque`/C arrays, but not `std::list` (use
  `list::sort`) or `std::map`.
- A comparator that isn't a strict weak ordering — e.g. returning
  `a <= b` — is undefined behavior and can crash in optimized builds.
- Sorting reorders elements, so any pointer you held "by position" now
  points at a different element.
