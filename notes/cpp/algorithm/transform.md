### Transform in practice

`std::transform` maps a range through a function into an output range.
Into a fresh container — size it first:

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main()
{
    std::vector<int> v{1, 2, 3, 4};
    std::vector<int> out(v.size());

    std::transform(v.begin(), v.end(), out.begin(),
                   [](int x){ return x * x; });   // 1 4 9 16
    for (int x : out) std::cout << x << ' ';
    std::cout << '\n';
}
```

In place — write back over the input (uppercasing a string):

```cpp
#include <cctype>
std::string s = "hello";
std::transform(s.begin(), s.end(), s.begin(),
               [](unsigned char c){ return std::toupper(c); });   // HELLO
```

Two input ranges with a binary op (element-wise add):

```cpp
std::vector<int> a{1, 2, 3}, b{10, 20, 30}, sum(3);
std::transform(a.begin(), a.end(), b.begin(), sum.begin(),
               [](int x, int y){ return x + y; });   // 11 22 33
```

### Transform a member without a `.field` lambda (C++20: ranges)

`std::ranges::transform` (`<algorithm>`) takes the range directly and
accepts a **projection**, applied before the operation — useful for
mapping one field of a struct without writing it into the lambda body:

```cpp c++20
#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

struct Person { std::string name; int age; };

int main()
{
    std::vector<Person> people{
        {"alice", 30}, {"bob", 25}, {"carol", 22}};
    std::vector<int> next_birthday(people.size());

    std::ranges::transform(people, next_birthday.begin(),
                           [](int age){ return age + 1; },
                           &Person::age);
    for (int a : next_birthday) std::cout << a << ' ';
    std::cout << '\n';
}
```

```text
31 26 23
```

### Gotchas

- The destination must have room; writing into an empty vector is UB.
  `resize` it, or use `std::back_inserter(out)` to grow as you go.
- Pass a `char` to `std::toupper`/`tolower` as `unsigned char` — a
  negative `char` is UB for the `<cctype>` functions.
- The unary form doesn't promise left-to-right order; don't rely on it
  for sequenced side effects (use `for_each` or a plain loop).
