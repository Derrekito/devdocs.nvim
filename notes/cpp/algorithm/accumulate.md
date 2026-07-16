### Accumulate in practice

`std::accumulate` (from `<numeric>`) folds a range into one value. The
default is sum:

```cpp
#include <iostream>
#include <numeric>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4, 5};
    int sum = std::accumulate(v.begin(), v.end(), 0);      // 15
    std::cout << sum << '\n';
}
```

Any binary op — product, min, or a custom fold:

```cpp
long prod = std::accumulate(v.begin(), v.end(), 1L,
                            [](long acc, int x){ return acc * x; });   // 120
```

Join strings — the init value fixes the accumulator (result) type:

```cpp
#include <iterator>
#include <string>
std::vector<std::string> words{"a", "b", "c"};
std::string joined = std::accumulate(std::next(words.begin()), words.end(),
                                     words.front(),
                                     [](std::string acc, const std::string& w){
                                         return acc + "," + w;
                                     });   // "a,b,c"
```

### The int-seed truncation bug, demonstrated

The accumulator's type comes from the **init value**, not from the
range. Seed a `double` sum with `0` (an `int`) and every partial sum
gets truncated back to `int` on each step:

```cpp
#include <iostream>
#include <numeric>
#include <vector>

int main()
{
    std::vector<double> prices{1.50, 2.25, 3.75};

    double wrong = std::accumulate(prices.begin(), prices.end(), 0);
    double right = std::accumulate(prices.begin(), prices.end(), 0.0);

    std::cout << wrong << ' ' << right << '\n';
}
```

```text
6 7.5
```

### Sum without caring about order (C++17: `std::reduce`)

`std::reduce` (`<numeric>`) is `accumulate` without a guaranteed
evaluation order — that's what lets an execution policy parallelize
it. The binary op must therefore be associative and commutative (plain
`+` on numbers qualifies; string concatenation does not):

```cpp
#include <iostream>
#include <numeric>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4, 5};
    std::cout << std::reduce(v.begin(), v.end(), 0) << '\n';
}
```

```text
15
```

### Sum of squares without a temporary vector (C++17: `transform_reduce`)

`std::transform_reduce` fuses a `transform` and a `reduce` into one
pass — no intermediate container:

```cpp
#include <functional>
#include <iostream>
#include <numeric>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4};
    long sq_sum = std::transform_reduce(v.begin(), v.end(), 0L,
                                        std::plus<>{},
                                        [](int x){ return x * x; });
    std::cout << sq_sum << '\n';   // 1+4+9+16
}
```

```text
30
```

It also has a two-range overload (dot product): pass two iterator
pairs and a binary op instead of a unary one.

### Gotchas

- The **init value's type is the accumulator type**. `accumulate(first,
  last, 0)` over `double`s truncates every add to `int` — pass `0.0`.
- A sum that can overflow `int` needs a wider init (`0L`, `0LL`).
- For a running total (not a single fold) use `std::partial_sum`, also
  in `<numeric>`.
