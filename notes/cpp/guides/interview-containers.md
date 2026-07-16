# Interview: which container

The 10-second decision: `vector` unless you have a reason. Membership
or counting → `unordered_map`/`unordered_set`. Sorted order or range
queries → `map`/`set`. Top-k / "always take the smallest" →
`priority_queue`. Both-ends pushes → `deque`.

### Declaration idioms

```cpp
std::vector<int> v;                       // the default answer
int rows = 3, cols = 4;
std::vector<std::vector<int>> grid(rows, std::vector<int>(cols, 0));
std::unordered_map<std::string, int> freq;
std::unordered_set<int> seen;
std::map<int, int> ordered;               // sorted keys, O(log n)
std::priority_queue<int> maxheap;
std::priority_queue<int, std::vector<int>, std::greater<int>> minheap;
std::deque<int> dq;                       // O(1) push/pop both ends
```

Rough costs: vector push_back amortized O(1), random access O(1);
unordered_map/set average O(1) per op (worst O(n), fine to state in an
interview); map/set O(log n); priority_queue push/pop O(log n), top
O(1).

### Counting things

```cpp
std::vector<int> nums{1, 2, 2, 3, 2};
std::unordered_map<int, int> count;
for (int x : nums) count[x]++;            // operator[] default-inserts 0
std::cout << count[2] << '\n';
```

```text
3
```

### Membership test

```cpp
std::unordered_set<int> s{1, 2, 3};
if (s.count(2)) std::cout << "yes\n";     // 0-or-1; contains() is C++20
```

```text
yes
```

### Gotchas

- `map[k]` / `unordered_map[k]` **insert** a default value when the
  key is missing — fine for counting, wrong for "look but don't
  touch". Use `find` or `at` for pure lookups.
- Erasing while iterating: `it = c.erase(it)` (else `++it`) — never
  `c.erase(it++)` habits you half-remember.
- `vector<bool>` is a bit-packed proxy, not a real container of bool;
  use `std::vector<char>` for visited flags if it bites you.
- Iterators/references into a `vector` die on reallocation
  (`push_back` can move everything); node-based `map`/`set`/`list`
  keep them stable except the erased element.
