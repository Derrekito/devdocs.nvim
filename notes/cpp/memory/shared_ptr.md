### Shared ownership in practice

`std::shared_ptr` (C++11) reference-counts an object: the last owner
to go destroys it. Create with `std::make_shared` — one allocation and
exception-safe:

```cpp
#include <iostream>
#include <memory>

int main()
{
    auto p = std::make_shared<int>(42);
    auto q = p;                          // q shares ownership
    std::cout << *p << " count=" << p.use_count() << '\n';   // 42 count=2
}   // count reaches 0 here, the int is freed
```

Copies share; the object lives until the last `shared_ptr` is gone.
Passing by value is fine — it just bumps the count:

```cpp
void keep(std::shared_ptr<int> sp);      // takes a share by value
```

Prefer `make_shared` to `std::shared_ptr<T>(new T(...))`: it does one
allocation instead of two and can't leak if a surrounding expression
throws.

### Handing out a shared_ptr to yourself

A member function that needs to share ownership of `this` with a
callback or another object can't just write `shared_ptr<T>(this)` — that
builds a second, unrelated control block and double-frees. Inherit from
`std::enable_shared_from_this<T>` (C++11) and call `shared_from_this()`
instead, which reuses the existing control block:

```cpp
#include <iostream>
#include <memory>

struct Session : std::enable_shared_from_this<Session> {
    std::shared_ptr<Session> self() { return shared_from_this(); }
};

int main()
{
    auto s = std::make_shared<Session>();
    auto s2 = s->self();
    std::cout << "count=" << s.use_count() << '\n';   // count=2
}
```

```text
count=2
```

`shared_from_this()` only works once a `shared_ptr` already owns the
object (i.e. after construction via `make_shared`/`shared_ptr`) —
calling it from the constructor, or on an object that was never put in
a `shared_ptr`, throws `std::bad_weak_ptr`.

### Gotchas

- The reference count in the control block is atomic (safe to
  copy/destroy the `shared_ptr` across threads), but the **pointed-to
  object is not** — guard access to the data yourself.
- Two `shared_ptr`s that point at each other never reach count 0 — a
  leak. Break the cycle with `std::weak_ptr` (see the weak_ptr notes for
  a parent/child example).
- Don't make two independent `shared_ptr`s from one raw pointer — each
  builds its own control block and both will delete it (double-free).
- Don't write `shared_ptr<T>(this)` inside a member function to share
  ownership of the current object — use `enable_shared_from_this` and
  `shared_from_this()` instead.
