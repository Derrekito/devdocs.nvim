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

### Gotchas

- After `std::move(x)`, `x` is in a **valid but unspecified** state — you
  may assign to it or destroy it, but don't read its value expecting the
  old contents.
- `std::move` on a `const` object silently copies (you can't steal from
  const): it compiles but does nothing useful.
- Don't write `return std::move(local);` — it disables copy elision
  (NRVO) and can pessimize. Just `return local;`.
