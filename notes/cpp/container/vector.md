### Vectors in practice

Build one and iterate — range-for is the default; index only when you
need the position:

```cpp
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3};
    v.push_back(4);

    for (int x : v)
        std::cout << x << ' ';
    std::cout << '\n';

    for (std::size_t i = 0; i < v.size(); ++i)
        std::cout << i << ':' << v[i] << ' ';
    std::cout << '\n';
}
```

`reserve` up front when you know the final size — it avoids the repeated
reallocations a growing vector would otherwise do:

```cpp
std::vector<int> v;
v.reserve(1000);
for (int i = 0; i < 1000; ++i)
    v.push_back(i * i);
```

Prefer `emplace_back` (C++11) to construct the element in place (no
temporary) for non-trivial types:

```cpp
std::vector<std::pair<int, std::string>> people;
people.emplace_back(42, "alice");   // constructs the pair in the vector
```

Removing elements: the **erase–remove** idiom deletes every match in one
pass (a plain `erase` in a loop is O(n²) and invalidates iterators):

```cpp
std::vector<int> v{1, 2, 3, 2, 4, 2};
v.erase(std::remove(v.begin(), v.end(), 2), v.end());  // v == {1, 3, 4}
```

Bounds: `operator[]` is unchecked; `at()` throws `std::out_of_range`.
Reach for `at()` when the index comes from outside your control.

### `reserve` vs `resize`

They look similar but do different things. `reserve(n)` grows
**capacity** only — no new elements, `size()` is unchanged, and
`push_back` afterward doesn't reallocate until `n` is exceeded.
`resize(n)` changes **size** — it value-initializes (or copies) new
elements if growing, and destroys elements if shrinking:

```cpp
std::vector<int> v{1, 2, 3};

v.reserve(10);
std::cout << v.size() << ' ' << v.capacity() << '\n';   // 3 10

v.resize(5);
std::cout << v.size() << '\n';                          // 5
std::cout << v[3] << ' ' << v[4] << '\n';                // 0 0
```

```text
3 10
5
0 0
```

### Erase by value or predicate (C++20: `std::erase`/`std::erase_if`)

The free functions replace the erase–remove idiom directly — no
iterators, no `std::remove` step:

```cpp c++20
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 2, 4, 2};
    std::erase(v, 2);                          // v == {1, 3, 4}

    std::vector<int> w{1, 2, 3, 4, 5, 6};
    std::erase_if(w, [](int x) { return x % 2 == 0; });   // w == {1, 3, 5}

    for (int x : v) std::cout << x << ' ';
    std::cout << '\n';
    for (int x : w) std::cout << x << ' ';
    std::cout << '\n';
}
```

```text
1 3 4 
1 3 5 
```

### Gotchas

- A `push_back`/`emplace_back` that reallocates invalidates all
  iterators, pointers, and references into the vector — re-acquire them
  after the vector grows.
- `std::vector<bool>` is a bit-packed specialization, not a real
  container of `bool`; `operator[]` returns a proxy, not `bool&`. Use
  `std::vector<char>` or `std::deque<bool>` if you need real references.
- `size()` is unsigned (`size_type`); comparing it against a signed loop
  counter warns under `-Wsign-compare`.
