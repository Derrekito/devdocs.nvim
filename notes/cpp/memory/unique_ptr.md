### Unique ownership in practice

`std::unique_ptr` (C++11) owns a heap object and frees it
automatically — one owner, no copies. Create it with
`std::make_unique` (**C++14** — a later addition than `unique_ptr`
itself), never a bare `new`:

```cpp
#include <iostream>
#include <memory>

struct Widget {
    int id;
    explicit Widget(int i) : id(i) { std::cout << "make " << id << '\n'; }
    ~Widget() { std::cout << "drop " << id << '\n'; }
};

int main()
{
    auto w = std::make_unique<Widget>(1);
    std::cout << "id = " << w->id << '\n';
}   // Widget destroyed here, automatically
```

It can't be copied, only **moved** — `std::move` transfers ownership:

```cpp
auto a = std::make_unique<Widget>(2);
auto b = std::move(a);      // a is now empty (nullptr); b owns the Widget
```

The idiomatic factory return — ownership passes to the caller:

```cpp
std::unique_ptr<Widget> make_widget(int id)
{
    return std::make_unique<Widget>(id);   // moved out
}
```

`get()` borrows the raw pointer for non-owning use; `reset()` frees
early:

```cpp
auto w = std::make_unique<Widget>(3);
Widget* raw = w.get();      // borrow — do NOT delete
w.reset();                  // free now; w == nullptr
```

For dynamic arrays use the `[]` form (though `std::vector` is usually
the better choice):

```cpp
auto buf = std::make_unique<int[]>(16);   // 16 value-initialized ints
buf[0] = 42;
```

### Pimpl: hiding a type behind unique_ptr

The pointer-to-implementation idiom hides a class's private members
(and their `#include`s) from callers of the header, cutting rebuild
cascades. It needs `unique_ptr` for the forward-declared member, plus
an out-of-line destructor — at the point the header is parsed, `Impl`
is incomplete, and `unique_ptr`'s default deleter needs a complete type
to call `delete`:

```cpp
#include <iostream>
#include <memory>

class Widget {
public:
    Widget();
    ~Widget();          // declared here, defined where Impl is complete
    void speak() const;
private:
    struct Impl;         // forward declaration only
    std::unique_ptr<Impl> impl;
};

struct Widget::Impl {
    int id = 7;
    void speak() const { std::cout << "widget " << id << '\n'; }
};

Widget::Widget() : impl(std::make_unique<Impl>()) {}
Widget::~Widget() = default;   // defined here, where Impl is complete
void Widget::speak() const { impl->speak(); }

int main()
{
    Widget w;
    w.speak();
}
```

```text
widget 7
```

In a real header/source split, `~Widget()` is declared (not `= default`
inline) in the header and defined in the `.cpp` file alongside `Impl` —
that's what makes `Impl` complete at the point the destructor actually
needs it.

### Custom deleters

The second template argument controls how the object is freed —
useful for C APIs (`fclose`, `free`) or any resource that isn't plain
`delete`:

```cpp
#include <cstdio>
#include <memory>

struct FileCloser {
    void operator()(FILE* f) const { if (f) fclose(f); }
};

int main()
{
    std::unique_ptr<FILE, FileCloser> fp(fopen("/dev/null", "r"));
    if (fp) fputs("opened\n", stdout);
}
```

```text
opened
```

A stateless deleter like `FileCloser` costs nothing extra; a captureful
lambda deleter grows the `unique_ptr` beyond one pointer, unlike
`shared_ptr` where the deleter always lives in the control block.

### Gotchas

- Move-only: passing a `unique_ptr` by value needs `std::move` at the
  call site — there is no copy.
- Never build one from a raw `new` you also keep elsewhere — two owners
  double-free. `make_unique` never names the raw pointer, so it can't
  happen.
- `.get()` does not transfer ownership; don't `delete` it or feed it to
  another smart pointer.
- Pimpl's `~Widget()` must be **declared** in the header and **defined**
  where `Impl` is complete (usually the `.cpp` file) — an implicit or
  `= default` destructor generated in the header fails to compile
  because it can't see `Impl`'s definition.
- A custom deleter changes the pointer's type
  (`unique_ptr<T, Deleter>`) — functions taking `unique_ptr<T>` (the
  default deleter) won't accept one with a custom deleter.
