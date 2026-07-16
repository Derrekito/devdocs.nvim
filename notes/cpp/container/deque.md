### Deques in practice

`std::deque` (double-ended queue) is like `std::vector` but with cheap
O(1) push/pop at **both** ends — the go-to for queues and sliding
windows:

```cpp
#include <deque>
#include <iostream>

int main()
{
    std::deque<int> d{2, 3};
    d.push_front(1);          // 1 2 3
    d.push_back(4);           // 1 2 3 4

    std::cout << d.front() << ' ' << d.back() << '\n';   // 1 4
    d.pop_front();            // 2 3 4

    for (int x : d) std::cout << x << ' ';               // random access too
    std::cout << '\n';
    std::cout << d[1] << '\n';                           // 3
}
```

Use it as a FIFO queue — push on one end, pop the other:

```cpp
std::deque<int> q;
q.push_back(10);
q.push_back(20);
int next = q.front();
q.pop_front();            // dequeued 10
```

### Gotchas

- Elements are **not** contiguous (a deque is a sequence of chunks), so
  there's no `.data()` and you can't hand it to APIs expecting a flat
  `T*` buffer — use `std::vector` for that.
- `push_back`/`push_front` invalidate all **iterators**, but references
  and pointers to existing elements stay valid (unlike `vector`, where a
  reallocation invalidates everything).
- For a pure stack or queue interface, `std::stack` / `std::queue` wrap a
  deque and hide the parts you shouldn't touch.
