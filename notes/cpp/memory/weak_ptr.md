### Weak references in practice

`std::weak_ptr` observes a `shared_ptr` **without** owning it — it does
not keep the object alive. Its main job is breaking reference cycles:

```cpp
#include <memory>

struct Node {
    std::shared_ptr<Node> next;   // owns the next node
    std::weak_ptr<Node>   prev;   // observes the previous — no cycle
};
```

To use the object, `lock()` it — you get a `shared_ptr` that is non-null
only if the object is still alive:

```cpp
#include <iostream>
#include <memory>

int main()
{
    auto sp = std::make_shared<int>(7);
    std::weak_ptr<int> wp = sp;

    if (auto locked = wp.lock())         // still alive?
        std::cout << "value: " << *locked << '\n';

    sp.reset();                          // last owner gone
    std::cout << "expired: " << std::boolalpha << wp.expired() << '\n';
}
```

### Gotchas

- You can't dereference a `weak_ptr` directly — always `lock()` and check
  the result against null before using it.
- `expired()` is only a snapshot; in threaded code the last owner could
  drop right after the check. `lock()` is the atomic, race-free "test and
  acquire".
- A live `weak_ptr` keeps the **control block** alive (not the object),
  so huge numbers of long-lived weak_ptrs still cost a little memory.
