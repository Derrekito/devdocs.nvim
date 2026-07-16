### Stream I/O in practice

Write to `std::cout`, errors to `std::cerr`; chain with `<<`:

```cpp
#include <iostream>
#include <string>

int main()
{
    std::string name = "alice";
    int age = 30;
    std::cout << name << " is " << age << " years old\n";
    std::cerr << "diagnostics go to stderr\n";
}
```

Formatting lives in `<iomanip>`. `setprecision`/`fixed`/`boolalpha`/`hex`
are **sticky** (they stay until changed); `setw` applies only to the next
field:

```cpp
#include <iomanip>
#include <iostream>

std::cout << std::fixed << std::setprecision(2) << 3.14159 << '\n'; // 3.14
std::cout << std::setw(8) << std::right << 42 << '\n';        // "      42"
std::cout << std::boolalpha << (1 < 2) << '\n';                     // true
std::cout << std::hex << 255 << '\n';                                 // ff
```

Reading: always test the stream — a failed extraction leaves the target
unchanged and sets `failbit`:

```cpp
int n;
if (std::cin >> n)
    std::cout << "got " << n << '\n';
else
    std::cout << "not a number\n";
```

`while (stream >> x)` is the idiom for "read until EOF or bad input":

```cpp
int x;
long total = 0;
while (std::cin >> x)
    total += x;
```

Whole lines with `std::getline` (keeps embedded spaces `>>` would stop
at):

```cpp
std::string line;
while (std::getline(std::cin, line))
    std::cout << "line: " << line << '\n';
```

### Build a formatted string instead of printing it

`std::ostringstream` (`<sstream>`) accepts the same `<<` chain and
manipulators as `std::cout`, but collects the result into a string you
can return, log, or pass on:

```cpp
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

std::string format_price(double v)
{
    std::ostringstream out;
    out << '$' << std::fixed << std::setprecision(2) << v;
    return out.str();
}

int main()
{
    std::cout << format_price(3.5) << '\n';
}
```

```text
$3.50
```

### Format output with std::format (C++20)

`std::format` (`<format>`) replaces most `<iomanip>` chains with a
single Python-style format string — no stream state to reset between
calls:

```cpp c++20
#include <format>
#include <iostream>

int main()
{
    std::cout << std::format("{} is {:.2f}\n", "pi", 3.14159);
    std::cout << std::format("{:>8}\n", 42);   // right-align, width 8
    std::cout << std::format("{:#x}\n", 255);  // hex with 0x prefix
}
```

```text
pi is 3.14
      42
0xff
```

### Gotchas

- `std::endl` flushes the buffer on every call — in a loop that's a real
  cost. Prefer `'\n'` and let the stream flush on its own.
- After `std::cin >> n`, the newline stays in the buffer, so a following
  `std::getline` reads an empty line. Skip it with
  `std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n')`
  (from `<limits>`) or `std::cin >> std::ws`.
- Once a stream hits `failbit`, further reads are no-ops until you call
  `.clear()` (and usually discard the bad input).
