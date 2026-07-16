### Queues in practice

`std::queue` is a FIFO adaptor over another container (a `std::deque` by
default) — push at the back, pop from the front:

```cpp
#include <iostream>
#include <queue>

int main()
{
    std::queue<int> q;
    q.push(1);
    q.push(2);
    q.push(3);

    while (!q.empty()) {
        std::cout << q.front() << ' ';   // 1 2 3 (first in, first out)
        q.pop();
    }
    std::cout << '\n';
}
```

The canonical use — breadth-first processing, where you enqueue work and
drain it in arrival order:

```cpp
std::queue<int> work;
work.push(10);
while (!work.empty()) {
    int job = work.front();
    work.pop();
    if (job > 0) work.push(job - 5);   // enqueue follow-up work
}
```

### Gotchas

- `front()`, `back()`, and `pop()` on an **empty** queue are undefined
  behavior — guard with `!q.empty()`.
- `pop()` removes but doesn't return; read `front()` first, then `pop()`.
- No iteration or random access. For a double-ended or scannable
  structure use `std::deque` directly; for LIFO use `std::stack`.
