### Unique ownership in practice

`std::unique_ptr` owns a heap object and frees it automatically — one
owner, no copies. Create it with `std::make_unique`, never a bare `new`:

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

### Gotchas

- Move-only: passing a `unique_ptr` by value needs `std::move` at the
  call site — there is no copy.
- Never build one from a raw `new` you also keep elsewhere — two owners
  double-free. `make_unique` never names the raw pointer, so it can't
  happen.
- `.get()` does not transfer ownership; don't `delete` it or feed it to
  another smart pointer.
