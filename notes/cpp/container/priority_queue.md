### Priority queues in practice

`std::priority_queue` is a heap adaptor: `top()` is always the largest
element, and push/pop are O(log n). By default it's a **max-heap**:

```cpp
#include <iostream>
#include <queue>

int main()
{
    std::priority_queue<int> pq;
    for (int x : {3, 1, 4, 1, 5}) pq.push(x);

    while (!pq.empty()) {
        std::cout << pq.top() << ' ';   // 5 4 3 1 1 (largest first)
        pq.pop();
    }
    std::cout << '\n';
}
```

For a **min-heap** (smallest on top), use `std::greater` — note the
three template arguments it requires:

```cpp
#include <functional>
#include <vector>

std::priority_queue<int, std::vector<int>, std::greater<int>> minpq;
minpq.push(3); minpq.push(1); minpq.push(4);
std::cout << minpq.top() << '\n';       // 1
```

Order by a custom key with a comparator — e.g. tasks by ascending
priority number:

```cpp
struct Task { int priority; std::string name; };
auto cmp = [](const Task& a, const Task& b){ return a.priority > b.priority; };
std::priority_queue<Task, std::vector<Task>, decltype(cmp)> tasks(cmp);
tasks.push({2, "b"});
tasks.push({1, "a"});
std::cout << tasks.top().name << '\n';   // a (lowest priority number first)
```

### Gotchas

- The comparator's sense is **inverted** from what feels natural:
  `std::less` (the default) gives a **max**-heap; `std::greater` gives a
  min-heap. A custom `cmp` returning `a.priority > b.priority` puts the
  *smallest* priority on top.
- `top()` is `const` — you can't modify the element in place; `pop()`
  doesn't return it either (read `top()`, then `pop()`).
- No iteration and no way to find/update an arbitrary element (no
  decrease-key). If you need that, keep a separate index or use a
  different structure.
