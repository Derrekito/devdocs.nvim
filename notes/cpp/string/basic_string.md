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

Numbers cross over with `std::to_string` (out, C++11) and
`std::stoi` / `std::stod` (in, C++11 — they throw
`std::invalid_argument` or `std::out_of_range` on bad input):

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

### Split a string into tokens

No built-in `split` — walk `find` from each delimiter to the next and
collect substrings into a `std::vector<std::string>`:

```cpp
#include <iostream>
#include <string>
#include <vector>

std::vector<std::string> split(const std::string& s, char delim)
{
    std::vector<std::string> out;
    std::size_t start = 0;
    while (start <= s.size()) {
        std::size_t end = s.find(delim, start);
        if (end == std::string::npos) end = s.size();
        out.push_back(s.substr(start, end - start));
        start = end + 1;
    }
    return out;
}

int main()
{
    for (const auto& tok : split("a,b,,c", ','))
        std::cout << '[' << tok << "]\n";
}
```

```text
[a]
[b]
[]
[c]
```

(For whitespace-delimited splitting where empty tokens should collapse,
`std::getline` over an `istringstream` — see `getline.md` — is usually
less code.)

### Join strings with a separator

```cpp
#include <iostream>
#include <string>
#include <string_view>
#include <vector>

std::string join(const std::vector<std::string>& parts,
                  std::string_view sep)
{
    std::string out;
    for (std::size_t i = 0; i < parts.size(); ++i) {
        if (i) out += sep;
        out += parts[i];
    }
    return out;
}

int main()
{
    std::cout << join({"a", "b", "c"}, ", ") << '\n';
}
```

```text
a, b, c
```

### Trim leading and trailing whitespace

`find_first_not_of` / `find_last_not_of` locate the first/last
non-whitespace character; slice between them. Guard the all-whitespace
case, where the first search returns `npos`:

```cpp
#include <iostream>
#include <string>

std::string trim(std::string s)
{
    const char* ws = " \t\n\r";
    auto first = s.find_first_not_of(ws);
    if (first == std::string::npos) return "";   // all whitespace
    auto last = s.find_last_not_of(ws);
    return s.substr(first, last - first + 1);
}

int main()
{
    std::cout << '[' << trim("  hi there  \n") << "]\n";
}
```

```text
[hi there]
```

### Check prefixes, suffixes, and substrings

`starts_with` / `ends_with` are C++20; `contains` is C++23. Before
C++20, `compare`/`find` do the job at index 0:

```cpp
#include <iostream>
#include <string>

int main()
{
    std::string s = "hello.txt";
    bool is_hidden = s.compare(0, 1, ".") == 0;     // pre-C++20 starts_with
    std::cout << std::boolalpha << is_hidden << '\n';
}
```

```text
false
```

```cpp c++20
std::string s = "hello.txt";
std::cout << s.starts_with("hello") << '\n';   // true
std::cout << s.ends_with(".txt") << '\n';      // true
```

```cpp c++23
std::string s = "hello.txt";
std::cout << s.contains("lo.t") << '\n';   // true
```

### Gotchas

- `find` returns `std::string::npos` (a large unsigned value) on failure,
  never a negative number.
- `std::string_view` does not own its data — never return one that refers
  to a local `std::string` or other temporary; it dangles.
- `s[s.size()]` reads the null terminator (`'\0'`, well-defined); any
  index past that is UB. Use `at()` for bounds-checked access.
- `data()` returns a mutable `char*` since C++17 (it was `const` before),
  so you can write through it in place — but it's still not guaranteed
  null-terminated unless you go through `c_str()` or index up to
  `size()`.
