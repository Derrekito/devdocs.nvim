### Stacks in practice

`std::stack` is a LIFO adaptor over another container (a `std::deque` by
default) — it exposes only push/top/pop:

```cpp
#include <iostream>
#include <stack>

int main()
{
    std::stack<int> s;
    s.push(1);
    s.push(2);
    s.push(3);

    while (!s.empty()) {
        std::cout << s.top() << ' ';   // 3 2 1 (last in, first out)
        s.pop();
    }
    std::cout << '\n';
}
```

The classic use — matching brackets, where you push openers and pop on
closers:

```cpp
#include <string>
bool balanced(const std::string& in)
{
    std::stack<char> st;
    for (char c : in) {
        if (c == '(') st.push(c);
        else if (c == ')') {
            if (st.empty()) return false;   // unmatched close
            st.pop();
        }
    }
    return st.empty();                      // nothing left open
}
```

### Gotchas

- `top()` and `pop()` on an **empty** stack are undefined behavior —
  always guard with `!s.empty()`.
- `pop()` only removes; it does **not** return the element. Read `top()`
  first, then `pop()` (the split keeps `pop` exception-safe).
- No iteration, no indexing — a stack hides the underlying container by
  design. If you need to scan the elements, use a `std::vector`/`deque`
  directly.
