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

std::cout << std::fixed << std::setprecision(2) << 3.14159 << '\n';  // 3.14
std::cout << std::setw(8) << std::right << 42 << '\n';               // "      42"
std::cout << std::boolalpha << (1 < 2) << '\n';                      // true
std::cout << std::hex << 255 << '\n';                                // ff
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

### Gotchas

- `std::endl` flushes the buffer on every call — in a loop that's a real
  cost. Prefer `'\n'` and let the stream flush on its own.
- After `std::cin >> n`, the newline stays in the buffer, so a following
  `std::getline` reads an empty line. Skip it with
  `std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n')`
  (from `<limits>`) or `std::cin >> std::ws`.
- Once a stream hits `failbit`, further reads are no-ops until you call
  `.clear()` (and usually discard the bad input).
