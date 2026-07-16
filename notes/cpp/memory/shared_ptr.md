### Shared ownership in practice

`std::shared_ptr` reference-counts an object: the last owner to go
destroys it. Create with `std::make_shared` — one allocation and
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

### Gotchas

- The reference count in the control block is atomic (safe to
  copy/destroy the `shared_ptr` across threads), but the **pointed-to
  object is not** — guard access to the data yourself.
- Two `shared_ptr`s that point at each other never reach count 0 — a
  leak. Break the cycle with `std::weak_ptr`.
- Don't make two independent `shared_ptr`s from one raw pointer — each
  builds its own control block and both will delete it (double-free).
