### lower_bound in practice

On a **sorted** range, `std::lower_bound` binary-searches for the first
element **not less than** the target in O(log n). It's the insertion
point that keeps the range sorted:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 3, 5, 7, 9};
    auto it = std::lower_bound(v.begin(), v.end(), 5);
    std::cout << "index " << (it - v.begin()) << '\n';     // 2

    v.insert(std::lower_bound(v.begin(), v.end(), 6), 6);  // keeps v sorted
}
```

`upper_bound` is the first element **strictly greater**; together they
bracket a run of equal keys (`std::equal_range` returns both at once):

```cpp
std::vector<int> v{1, 2, 2, 2, 3};
auto lo = std::lower_bound(v.begin(), v.end(), 2);
auto hi = std::upper_bound(v.begin(), v.end(), 2);
std::cout << "count of 2: " << (hi - lo) << '\n';   // 3
```

To just test membership, `std::binary_search` returns a bool.

### Prefer the member on `std::set`/`std::map`

`std::lower_bound(s.begin(), s.end(), x)` compiles on a `std::set`,
but its iterators are only **bidirectional**, not random-access, so
the free algorithm can't jump — it still steps one element at a time
under the hood and costs O(n), even though it makes only O(log n)
comparisons. The member `.lower_bound()` walks the tree directly and
is genuinely O(log n):

```cpp
#include <algorithm>
#include <iostream>
#include <set>

int main()
{
    std::set<int> s{1, 3, 5, 7, 9};

    auto it = s.lower_bound(5);                          // O(log n)
    auto slow = std::lower_bound(s.begin(), s.end(), 5);  // O(n)
    std::cout << *it << ' ' << *slow << '\n';
}
```

```text
5 5
```

Same story for `std::map` — its `.lower_bound()` searches by key.

### lower_bound with a projection (C++20: ranges)

`std::ranges::lower_bound` (`<algorithm>`) takes the container
directly and accepts a **projection**, so searching a range sorted by
a struct member needs no comparator lambda:

```cpp c++20
#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

struct Person { std::string name; int age; };

int main()
{
    std::vector<Person> people{           // sorted by age
        {"alice", 22}, {"bob", 25}, {"carol", 30}};

    auto it = std::ranges::lower_bound(people, 25, {}, &Person::age);
    if (it != people.end())
        std::cout << it->name << '\n';
}
```

```text
bob
```

### Gotchas

- The range **must already be sorted** by the same ordering — on
  unsorted input the answer is meaningless, not an error.
- It returns `end()` when every element is smaller than the target; check
  before dereferencing.
- If you sorted with a custom comparator, pass the same one to the
  search — the sort order and search comparator must agree.
