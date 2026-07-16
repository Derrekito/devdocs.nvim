### Listing directories in practice

`std::filesystem` — including `directory_iterator` — is **C++17**.
Build with `-std=c++17` or later; on GCC 8 also link `-lstdc++fs`.

The minimal loop — every entry in one directory (not recursive):

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main()
{
    for (const fs::directory_entry& entry : fs::directory_iterator{"/proc"})
        std::cout << entry.path() << '\n';
}
```

Each `entry` is a `directory_entry`: `entry.path()` gives the full path,
and cheap cached queries tell you what it is without extra `stat` calls:

```cpp
for (const auto& entry : fs::directory_iterator{"."})
{
    if (entry.is_directory())
        std::cout << "[dir]  " << entry.path().filename() << '\n';
    else if (entry.is_regular_file())
        std::cout << "[file] " << entry.path().filename() << '\n';
}
```

Filtering by extension — note `path().extension()` compares with the dot:

```cpp
for (const auto& entry : fs::directory_iterator{"src"})
    if (entry.path().extension() == ".cpp")
        std::cout << entry.path() << '\n';
```

Walking a whole tree is the same loop with
`recursive_directory_iterator`:

```cpp
for (const auto& entry : fs::recursive_directory_iterator{"include"})
    if (entry.is_regular_file())
        std::cout << entry.path() << '\n';
```

Iteration order is **unspecified** — directories are not sorted. Collect
and sort when order matters:

```cpp
#include <algorithm>
#include <vector>

std::vector<fs::path> paths;
for (const auto& entry : fs::directory_iterator{"."})
    paths.push_back(entry.path());
std::sort(paths.begin(), paths.end());
```

### Recursive walk, filtered and fault-tolerant

Combine `recursive_directory_iterator` with the `std::error_code`
overload to keep walking past a subdirectory you can't read (a
permission-denied `.git` object folder, a broken symlink) instead of
throwing and aborting the whole scan. This example builds its own tiny
tree under `temp_directory_path()` so the output is deterministic:

```cpp
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <vector>

namespace fs = std::filesystem;

int main()
{
    fs::path root = fs::temp_directory_path() / "devdocs_walk_demo";
    fs::remove_all(root);
    fs::create_directories(root / "src");
    fs::create_directories(root / "build");
    std::ofstream(root / "src" / "main.cpp") << "// demo\n";
    std::ofstream(root / "src" / "util.cpp") << "// demo\n";
    std::ofstream(root / "build" / "main.o")  << "demo\n";

    std::error_code ec;
    std::vector<fs::path> cpp_files;
    for (auto it = fs::recursive_directory_iterator(
             root, fs::directory_options::skip_permission_denied, ec);
         it != fs::recursive_directory_iterator(); it.increment(ec))
    {
        if (ec)
        {
            std::cerr << "warning: " << ec.message() << '\n';
            ec.clear();
            continue;
        }
        if (it->is_regular_file() && it->path().extension() == ".cpp")
            cpp_files.push_back(it->path());
    }

    std::sort(cpp_files.begin(), cpp_files.end());
    for (const auto& p : cpp_files)
        std::cout << p.filename().string() << '\n';

    fs::remove_all(root);   // clean up
}
```

```text
main.cpp
util.cpp
```

`directory_options::skip_permission_denied` stops the constructor
itself from throwing/erroring on an unreadable top-level directory;
the `ec` check inside the loop additionally guards `increment()`, which
is where a deeper unreadable subdirectory surfaces.

### Error handling

The constructor **throws** `fs::filesystem_error` on a missing or
unreadable directory. For paths you don't control, use the non-throwing
overload with `std::error_code`:

```cpp
std::error_code ec;
for (const auto& entry : fs::directory_iterator{"/maybe/missing", ec})
    std::cout << entry.path() << '\n';
if (ec)
    std::cerr << "cannot list: " << ec.message() << '\n';
```

### Gotchas

- The special entries `.` and `..` are already skipped — no need to filter
  them like with POSIX `readdir`.
- `directory_iterator` is a single-pass input iterator: copies share state,
  so collect paths into a container if you need to iterate twice.
- Build with `-std=c++17` or later; on GCC 8 link `-lstdc++fs`.
