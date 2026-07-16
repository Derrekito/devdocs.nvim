### std::function in practice

`std::function<R(Args...)>` is a type-erased wrapper that can hold any
callable with a matching signature — a lambda, a free function, or a
functor — so you can store and pass them uniformly:

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
