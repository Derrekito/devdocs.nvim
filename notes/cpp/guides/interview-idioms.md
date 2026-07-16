# Interview idioms

The moves you should be able to type without thinking. Each compiles
as shown.

### Sort by a custom key

```cpp
struct Job { std::string name; int priority; };

std::vector<Job> jobs{{"build", 2}, {"deploy", 3}, {"test", 1}};
std::sort(jobs.begin(), jobs.end(),
          [](const Job& a, const Job& b) { return a.priority < b.priority; });
std::cout << jobs.front().name << '\n';   // lowest priority first
```

```text
test
```

Descending: flip to `>` — never `<=` (undefined behavior).

### Min-heap for top-k

```cpp
// keep the k LARGEST seen so far in a min-heap of size k
std::vector<int> data{5, 1, 9, 3, 7};
int k = 2;
std::priority_queue<int, std::vector<int>, std::greater<int>> heap;
for (int x : data) {
    heap.push(x);
    if ((int)heap.size() > k) heap.pop();  // evict the smallest
}
std::cout << heap.top() << '\n';           // k-th largest
```

```text
7
```

### Two pointers (sorted pair sum)

```cpp
std::vector<int> a{1, 3, 4, 6, 9};        // sorted
int target = 10, l = 0, r = (int)a.size() - 1;
while (l < r) {
    int sum = a[l] + a[r];
    if (sum == target) break;
    if (sum < target) l++; else r--;
}
std::cout << a[l] << '+' << a[r] << '\n';
```

```text
1+9
```

### Sliding window (longest substring, no repeats)

```cpp
std::string s = "abcabcbb";
std::unordered_map<char, int> last;       // char -> last index seen
int best = 0, start = 0;
for (int i = 0; i < (int)s.size(); i++) {
    auto it = last.find(s[i]);
    if (it != last.end() && it->second >= start) start = it->second + 1;
    last[s[i]] = i;
    best = std::max(best, i - start + 1);
}
std::cout << best << '\n';
```

```text
3
```

### Prefix sums

```cpp
std::vector<int> nums{2, 4, 1, 3};
std::vector<long long> pre(nums.size() + 1, 0);
for (size_t i = 0; i < nums.size(); i++) pre[i + 1] = pre[i] + nums[i];
// sum of [l, r) is pre[r] - pre[l]
std::cout << pre[3] - pre[1] << '\n';     // 4 + 1
```

```text
5
```

### Binary search on a sorted vector

```cpp
std::vector<int> v{10, 20, 20, 30};
auto lo = std::lower_bound(v.begin(), v.end(), 20); // first >= 20
auto hi = std::upper_bound(v.begin(), v.end(), 20); // first  > 20
std::cout << (lo - v.begin()) << ' ' << (hi - lo) << '\n'; // index, count
```

```text
1 2
```

### Dedupe a vector

```cpp
std::vector<int> d{3, 1, 3, 2, 1};
std::sort(d.begin(), d.end());
d.erase(std::unique(d.begin(), d.end()), d.end());
std::cout << d.size() << '\n';
```

```text
3
```

### Gotchas under pressure

- Sums and products: reach for `long long` before the overflow bites
  (`1e5` elements × `1e5` values is already past `int`).
- `size()` is unsigned — `(int)v.size() - 1` or cast before comparing
  with a possibly-negative index.
- Pass big containers as `const std::vector<int>&`, not by value —
  interviewers notice.
