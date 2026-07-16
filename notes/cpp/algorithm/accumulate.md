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

### Gotchas

- The **init value's type is the accumulator type**. `accumulate(first,
  last, 0)` over `double`s truncates every add to `int` — pass `0.0`.
- A sum that can overflow `int` needs a wider init (`0L`, `0LL`).
- For a sum of products use `std::inner_product`; for a running total,
  `std::partial_sum` — both also in `<numeric>`.
