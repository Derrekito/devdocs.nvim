### getline in practice

`std::getline` reads a whole line (up to `\n`, which it consumes but
discards) into a `std::string` — the right tool when the input has
spaces that `>>` would split on:

```cpp
#include <iostream>
#include <string>

int main()
{
    std::string line;
    while (std::getline(std::cin, line))
        std::cout << "line: " << line << '\n';
}
```

A third argument sets a custom delimiter — e.g. split a comma-separated
field via a stream:

```cpp
#include <sstream>

std::istringstream in{"a,b,c"};
std::string field;
while (std::getline(in, field, ','))
    std::cout << '[' << field << "]\n";
```

### Gotchas

- Mixing `>>` and `getline`: after `std::cin >> n` the newline stays in
  the buffer, so the next `getline` returns an empty line. Discard it
  with `std::cin.ignore(std::numeric_limits<std::streamsize>::max(),
  '\n')` (from `<limits>`).
- Loop on the call itself — `while (std::getline(in, line))` — not on
  `in.eof()`, which tests too late and processes a phantom final line.
- `getline` strips the `\n`, but a trailing `\r` from CRLF (Windows)
  files survives — trim it if it matters.
