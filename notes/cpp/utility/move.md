### std::move in practice

`std::move` doesn't move anything — it **casts** its argument to an
rvalue so the next operation can steal (move-construct/assign) from it
instead of copying. Use it to hand off resources you're done with:

```cpp
#include <iostream>
#include <string>
#include <vector>

int main()
{
    std::string big(1000, 'x');
    std::vector<std::string> v;

    v.push_back(std::move(big));   // moved, not copied
    std::cout << "moved-from size: " << big.size() << '\n';   // 0
    std::cout << "stored size: "    << v[0].size() << '\n';   // 1000
}
```

Common when passing a "sink" argument you construct locally:

```cpp
struct Buffer { std::vector<int> data; };

Buffer make()
{
    std::vector<int> tmp(100, 7);
    return Buffer{std::move(tmp)};   // move the vector into the struct, no copy
}
```

### Moved-from state: what you may still do

`std::move` (C++11) leaves the source in a "valid but unspecified"
state — the moved-from object is still a live, destructible object of
its type, just with contents you shouldn't rely on. Standard library
types additionally guarantee it's safe to assign a fresh value or call
methods with no preconditions (like `empty()` or `clear()`):

```cpp
#include <iostream>
#include <string>
#include <vector>

int main()
{
    std::string s = "hello";
    std::vector<std::string> v;
    v.push_back(std::move(s));

    // s is valid but unspecified here — do NOT read s expecting "hello"
    s = "reused";                 // fine: assignment has no precondition
    std::cout << s << '\n';       // reused
}
```

```text
reused
```

### When not to move: local returns

Returning a local by value already elides the copy/move under NRVO (not
guaranteed by the standard, but done by every mainstream compiler), or
performs a move automatically as of C++11 when elision doesn't apply
because the return is of a local variable. Wrapping it in `std::move`
does not help and can *disable* that elision, forcing a move where the
compiler could have skipped both:

```cpp
#include <vector>

std::vector<int> good()
{
    std::vector<int> v(100, 1);
    return v;               // may elide entirely, else auto-moves
}

std::vector<int> worse()
{
    std::vector<int> v(100, 1);
    return std::move(v);    // blocks elision; forces a move
}
```

The same applies to a function parameter taken by value and returned —
`std::move` there is correct only because a by-value parameter isn't a
local eligible for elision.

### Gotchas

- After `std::move(x)`, `x` is in a **valid but unspecified** state — you
  may assign to it or destroy it, but don't read its value expecting the
  old contents.
- `std::move` on a `const` object silently copies (you can't steal from
  const): it compiles but does nothing useful.
- Don't write `return std::move(local);` — it disables copy elision
  (NRVO) and can pessimize. Just `return local;`.
- `std::move_if_noexcept` (C++11) is what containers like `vector` use
  internally when reallocating: it moves only if the move constructor is
  `noexcept`, otherwise it copies, preserving the strong exception
  guarantee. You rarely call it directly, but it's why a type without a
  `noexcept` move constructor gets silently copied during
  `vector::resize`/reallocation instead of moved.
