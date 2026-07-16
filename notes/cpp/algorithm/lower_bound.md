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

### Gotchas

- The range **must already be sorted** by the same ordering — on
  unsorted input the answer is meaningless, not an error.
- It returns `end()` when every element is smaller than the target; check
  before dereferencing.
- If you sorted with a custom comparator, pass the same one to the
  search — the sort order and search comparator must agree.
