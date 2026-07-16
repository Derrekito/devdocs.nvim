### String to integer in practice

`std::stoi` / `std::stol` / `std::stoll` parse an integer from the front
of a string:

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

### Gotchas

- No leading digits throws `std::invalid_argument`; a value too big
  throws `std::out_of_range`. Wrap untrusted input in `try`/`catch` (or
  return `std::optional`).
- Because they stop at the first bad char, `"12abc"` silently parses as
  `12` — inspect `pos` if trailing junk should be an error.
- For hot paths or no-throw parsing, `std::from_chars` (`<charconv>`,
  C++17) is faster and reports errors without exceptions. Floats parse
  with `std::stof`/`std::stod`.
