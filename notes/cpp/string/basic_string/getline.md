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

### Read all lines into a vector

```cpp
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

int main()
{
    std::istringstream in{"one\ntwo\nthree\n"};
    std::vector<std::string> lines;
    for (std::string line; std::getline(in, line); )
        lines.push_back(line);
    std::cout << lines.size() << " lines, last: " << lines.back() << '\n';
}
```

```text
3 lines, last: three
```

### Fix the `>>` then `getline` pitfall

`operator>>` leaves the trailing newline in the buffer, so a `getline`
right after it reads that leftover newline as an empty line:

```cpp
#include <iostream>
#include <sstream>
#include <string>

int main()
{
    std::istringstream in{"3\nhello world\n"};
    int n;
    in >> n;                  // consumes "3", leaves "\nhello world\n"
    std::string line;
    std::getline(in, line);   // reads up to the very next '\n' -> empty
    std::cout << "n=" << n << " line=[" << line << "]\n";
}
```

```text
n=3 line=[]
```

Skip the leftover newline with `std::ws` before the `getline`:

```cpp
#include <iostream>
#include <sstream>
#include <string>

int main()
{
    std::istringstream in{"3\nhello world\n"};
    int n;
    in >> n >> std::ws;       // >> std::ws eats the leftover '\n' too
    std::string line;
    std::getline(in, line);
    std::cout << "n=" << n << " line=[" << line << "]\n";
}
```

```text
n=3 line=[hello world]
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
