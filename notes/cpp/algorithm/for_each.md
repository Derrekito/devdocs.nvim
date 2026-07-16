### for_each in practice

`std::for_each` applies a callable to every element in a range. A plain
range-for is usually clearer, but `for_each` shines when you already
have a callable or want to run over a sub-range:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4};
    std::for_each(v.begin(), v.end(),
                  [](int x){ std::cout << x << ' '; });   // 1 2 3 4
    std::cout << '\n';
}
```

Mutate in place with a by-reference lambda:

```cpp
std::for_each(v.begin(), v.end(), [](int& x){ x *= 10; });   // 10 20 30 40
```

Accumulate side state through a mutable capture (here, a running sum):

```cpp
long sum = 0;
std::for_each(v.begin(), v.end(), [&sum](int x){ sum += x; });
std::cout << "sum = " << sum << '\n';
```

### Process only the first N elements (C++17: `for_each_n`)

`std::for_each_n` takes a start and a count instead of a start/end
pair — no need to compute `v.begin() + n` yourself:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4, 5};
    std::for_each_n(v.begin(), 3, [](int x){ std::cout << x << ' '; });
    std::cout << '\n';
}
```

```text
1 2 3
```

### for_each with a projection (C++20: ranges)

`std::ranges::for_each` (`<algorithm>`) takes the container directly
and accepts a **projection**, applied before the callable — handy for
running a side effect over one field of a struct:

```cpp c++20
#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

struct Person { std::string name; int age; };

int main()
{
    std::vector<Person> people{{"alice", 30}, {"bob", 25}};
    std::ranges::for_each(people, [](int age){ std::cout << age << ' '; },
                          &Person::age);
    std::cout << '\n';
}
```

```text
30 25
```

### Gotchas

- Prefer a range-for (`for (int x : v)`) for the whole container — it's
  more readable; reach for `for_each` for a sub-range or an existing
  functor.
- The unary op runs in order for `for_each`, so side effects are safe
  (unlike `std::transform`, which doesn't promise sequencing).
- To sum or fold, `std::accumulate` (`<numeric>`) says the intent more
  directly than a `for_each` with a captured accumulator.
