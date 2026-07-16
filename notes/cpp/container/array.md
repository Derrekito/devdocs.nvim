### Arrays in practice

`std::array` is a fixed-size, stack-allocated array with a known
compile-time size — a C array with value semantics and a container API:

```cpp
#include <array>
#include <iostream>

int main()
{
    std::array<int, 4> a{1, 2, 3, 4};   // size is part of the type
    std::cout << a.size() << '\n';       // 4

    for (int x : a) std::cout << x << ' ';
    std::cout << '\n';

    a[0] = 10;                           // unchecked
    a.at(1) = 20;                        // bounds-checked (throws)
    std::cout << a.front() << ' ' << a.back() << '\n';
}
```

Zero-init all elements with `{}`; `fill` sets them after the fact:

```cpp
std::array<int, 8> buf{};   // all zero
buf.fill(7);                // all 7
```

The size is part of the type, so functions taking an array by reference
template on `N` (or take a `std::span` in C++20):

```cpp
template <std::size_t N>
int sum(const std::array<int, N>& a)
{
    int total = 0;
    for (int x : a) total += x;
    return total;
}
```

Unlike a C array it has real value semantics — copy, assign, and return
by value all work:

```cpp
std::array<int, 3> make() { return {1, 2, 3}; }
std::array<int, 3> a = make();
std::array<int, 3> b = a;              // a genuine element-wise copy
```

Structured bindings (C++17) unpack a fixed-size array:

```cpp
std::array<int, 3> p{1, 2, 3};
auto [x, y, z] = p;
```

### Gotchas

- The size is a compile-time constant baked into the type:
  `std::array<int, 3>` and `std::array<int, 4>` are different types, and
  you can't resize. Need a runtime size → `std::vector`.
- `std::array<int, N> a;` (no braces) leaves trivial elements
  **uninitialized**; write `std::array<int, N> a{};` to zero them.
- `operator[]` is unchecked; `at()` throws `std::out_of_range`.
