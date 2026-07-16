### Weak references in practice

`std::weak_ptr` (C++11) observes a `shared_ptr` **without** owning it —
it does not keep the object alive. Its main job is breaking reference
cycles:

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

### Breaking a parent/child ownership cycle

The classic leak: a `Parent` owns its `Child`ren via `shared_ptr`, and
each `Child` points back to its `Parent` — also via `shared_ptr`. The
cycle keeps both alive forever, even after the last outside reference
is gone. Make the back-pointer a `weak_ptr` and the cycle disappears:

```cpp
#include <iostream>
#include <memory>
#include <vector>

struct Child;

struct Parent {
    std::vector<std::shared_ptr<Child>> children;   // owns children
    ~Parent() { std::cout << "Parent destroyed\n"; }
};

struct Child {
    std::weak_ptr<Parent> parent;   // observes only — no cycle
    ~Child() { std::cout << "Child destroyed\n"; }
};

int main()
{
    auto parent = std::make_shared<Parent>();
    auto child  = std::make_shared<Child>();
    child->parent = parent;               // weak: no bump to parent's count
    parent->children.push_back(child);    // strong: parent owns child

    if (auto p = child->parent.lock())
        std::cout << "child can reach parent\n";

    // Dropping the one strong reference to `parent` here destroys both,
    // since child's back-reference no longer keeps parent's count alive.
}
```

```text
child can reach parent
Parent destroyed
Child destroyed
```

Had `Child::parent` been a `shared_ptr<Parent>` instead, both objects
would keep each other's count at 1 forever after `main` returns —
neither destructor would run, and neither `std::cout` line would print.

### Gotchas

- You can't dereference a `weak_ptr` directly — always `lock()` and check
  the result against null before using it.
- `expired()` is only a snapshot; in threaded code the last owner could
  drop right after the check. `lock()` is the atomic, race-free "test and
  acquire".
- A live `weak_ptr` keeps the **control block** alive (not the object),
  so huge numbers of long-lived weak_ptrs still cost a little memory.
