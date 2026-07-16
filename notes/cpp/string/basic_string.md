### Strings in practice

Build and grow with `+` / `+=`; index it like any container:

```cpp
#include <iostream>
#include <string>

int main()
{
    std::string s = "hello";
    s += ", world";
    s.push_back('!');
    std::cout << s << " (" << s.size() << " chars)\n";
}
```

Search and slice with `find` + `substr`. `find` returns
`std::string::npos` when there's no match — always test against that,
not `-1`:

```cpp
std::string path = "/usr/local/bin";
if (auto pos = path.find_last_of('/'); pos != std::string::npos)
    std::cout << path.substr(pos + 1) << '\n';   // bin
```

Numbers cross over with `std::to_string` (out) and
`std::stoi` / `std::stod` (in — they throw `std::invalid_argument` or
`std::out_of_range` on bad input):

```cpp
std::string n = std::to_string(42);
int back = std::stoi(n);
```

Split a line on a delimiter with `std::getline` over a stream — it keeps
the embedded spaces that `operator>>` would stop at:

```cpp
#include <sstream>

std::istringstream in{"one two three"};
std::string token;
while (std::getline(in, token, ' '))
    std::cout << '[' << token << "]\n";
```

Pass strings you only read as `std::string_view` (C++17) — no copy, and
it also binds to string literals and `char*`:

```cpp
#include <string_view>

std::size_t count_a(std::string_view sv)
{
    std::size_t n = 0;
    for (char c : sv)
        if (c == 'a') ++n;
    return n;
}
```

### Gotchas

- `find` returns `std::string::npos` (a large unsigned value) on failure,
  never a negative number.
- `std::string_view` does not own its data — never return one that refers
  to a local `std::string` or other temporary; it dangles.
- `s[s.size()]` reads the null terminator (`'\0'`, well-defined); any
  index past that is UB. Use `at()` for bounds-checked access.
