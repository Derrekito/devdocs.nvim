### String to integer in practice

`std::stoi` / `std::stol` / `std::stoll` (C++11) parse an integer from
the front of a string:

```cpp
#include <iostream>
#include <string>

int main()
{
    int n = std::stoi("42");
    long big = std::stol("10000000000");
    std::cout << n << ' ' << big << '\n';
}
```

They skip leading whitespace and stop at the first non-digit; an optional
out-parameter reports where parsing stopped:

```cpp
std::size_t pos = 0;
int n = std::stoi("42px", &pos);   // n = 42, pos = 2
std::cout << "rest: " << std::string("42px").substr(pos) << '\n';   // px
```

A third argument sets the base (0 = auto-detect a `0x`/`0` prefix):

```cpp
int hex = std::stoi("ff", nullptr, 16);   // 255
```

### Parse without exceptions using from_chars (C++17)

`std::from_chars` (`<charconv>`) never throws and never allocates — it
reports failure through a returned `std::errc`. It also does *not* skip
leading whitespace or accept a `+` sign, unlike `stoi`:

```cpp
#include <charconv>
#include <iostream>
#include <string_view>

int main()
{
    std::string_view s = "42px";
    int n = 0;
    auto [ptr, ec] = std::from_chars(s.data(), s.data() + s.size(), n);

    if (ec == std::errc{})
        std::cout << "n=" << n << " rest=" << (ptr - s.data()) << '\n';
    else
        std::cout << "parse failed\n";
}
```

```text
n=42 rest=2
```

Bad input reports `std::errc::invalid_argument` instead of throwing —
useful for validating untrusted data in a hot loop:

```cpp
std::string_view bad = "not a number";
int n = 0;
auto [ptr, ec] = std::from_chars(bad.data(), bad.data() + bad.size(), n);
if (ec == std::errc::invalid_argument)
    std::cout << "no conversion\n";
```

```text
no conversion
```

### Wrap stoi for optional-based parsing

When you want `stoi`'s convenience (whitespace/sign handling) but not
its exceptions, catch locally and return `std::optional`:

```cpp
#include <iostream>
#include <optional>
#include <string>

std::optional<int> parse_int(const std::string& s)
{
    try {
        std::size_t pos = 0;
        int n = std::stoi(s, &pos);
        if (pos != s.size()) return std::nullopt;   // trailing junk
        return n;
    } catch (const std::exception&) {
        return std::nullopt;
    }
}

int main()
{
    std::cout << parse_int("42").value_or(-1) << '\n';
    std::cout << parse_int("42x").value_or(-1) << '\n';
}
```

```text
42
-1
```

### Gotchas

- No leading digits throws `std::invalid_argument`; a value too big
  throws `std::out_of_range`. Wrap untrusted input in `try`/`catch` (or
  return `std::optional`).
- Because they stop at the first bad char, `"12abc"` silently parses as
  `12` — inspect `pos` if trailing junk should be an error.
- For hot paths or no-throw parsing, `std::from_chars` (`<charconv>`,
  C++17) is faster and reports errors without exceptions. Floats parse
  with `std::stof`/`std::stod`.
