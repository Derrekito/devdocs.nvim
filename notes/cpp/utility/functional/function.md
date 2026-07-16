### std::function in practice

`std::function<R(Args...)>` (C++11) is a type-erased wrapper that can
hold any callable with a matching signature — a lambda, a free
function, or a functor — so you can store and pass them uniformly:

```cpp
#include <functional>
#include <iostream>

int add(int a, int b) { return a + b; }

int main()
{
    std::function<int(int, int)> op = add;          // free function
    std::cout << op(2, 3) << '\n';                  // 5

    int base = 10;
    op = [base](int a, int b){ return base + a + b; };   // lambda with capture
    std::cout << op(2, 3) << '\n';                  // 15
}
```

The point is heterogeneous storage — a table of callbacks, all the same
type despite different underlying lambdas:

```cpp
#include <map>
#include <string>

std::map<std::string, std::function<int(int, int)>> ops{
    {"+", [](int a, int b){ return a + b; }},
    {"*", [](int a, int b){ return a * b; }},
};
std::cout << ops["*"](6, 7) << '\n';                // 42
```

An empty `std::function` is falsy — check before calling:

```cpp
std::function<void()> cb;
if (cb) cb();                                       // skipped: cb is empty
```

### Wrapping a member function as a callback

A `std::function` can't bind a member function pointer directly — wrap
it in a lambda that captures the object (or use `std::bind_front`,
C++20, shown second):

```cpp
#include <functional>
#include <iostream>

struct Counter {
    int n = 0;
    void tick() { ++n; }
};

int main()
{
    Counter c;
    std::function<void()> cb = [&c]{ c.tick(); };
    cb(); cb(); cb();
    std::cout << c.n << '\n';   // 3
}
```

```text
3
```

```cpp c++20
#include <functional>
#include <iostream>

struct Counter {
    int n = 0;
    void tick() { ++n; }
};

int main()
{
    Counter c;
    std::function<void()> cb = std::bind_front(&Counter::tick, &c);
    cb(); cb();
    std::cout << c.n << '\n';   // 2
}
```

```text
2
```

### Gotchas

- Calling an empty `std::function` throws `std::bad_function_call` —
  guard with `if (fn)` when a callback may be unset.
- It type-erases behind a virtual call and may heap-allocate for large
  captures, so it's slower than a raw lambda. In hot paths prefer a
  template parameter (`template <class F> void run(F&&)`) or, from C++23,
  `std::move_only_function`.
- Capturing a reference/pointer in the stored lambda outlives nothing for
  you — the `std::function` keeps the lambda alive, but a dangling
  capture inside it still dangles.
- `std::bind_front` is **C++20**; on C++17 wrap the call in a lambda as
  in the first example instead.
