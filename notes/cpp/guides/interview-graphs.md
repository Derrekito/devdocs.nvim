# Interview: BFS/DFS skeletons

### Build an adjacency list from edges

```cpp
int n = 5;
std::vector<std::pair<int, int>> edges{{0, 1}, {0, 2}, {1, 3}, {3, 4}};
std::vector<std::vector<int>> adj(n);
for (auto [u, v] : edges) {
    adj[u].push_back(v);
    adj[v].push_back(u);                  // drop for directed graphs
}
std::cout << adj[0].size() << '\n';
```

```text
2
```

### BFS with distances

```cpp
std::vector<int> dist(n, -1);             // -1 doubles as "unvisited"
std::queue<int> q;
dist[0] = 0;
q.push(0);
while (!q.empty()) {
    int u = q.front(); q.pop();
    for (int v : adj[u])
        if (dist[v] == -1) {
            dist[v] = dist[u] + 1;
            q.push(v);
        }
}
std::cout << dist[4] << '\n';             // 0 -> 1 -> 3 -> 4
```

```text
3
```

### DFS (recursive)

```cpp
int count_reachable(int u, const std::vector<std::vector<int>>& g,
                    std::vector<char>& seen)
{
    seen[u] = 1;
    int total = 1;
    for (int v : g[u])
        if (!seen[v]) total += count_reachable(v, g, seen);
    return total;
}
```

```cpp
std::vector<char> seen(n, 0);             // vector<char>, not vector<bool>
std::cout << count_reachable(0, adj, seen) << '\n';
```

```text
5
```

### Grid BFS (number of islands pattern)

```cpp
#include <iostream>
#include <queue>
#include <vector>

int main()
{
    std::vector<std::string> grid{"110", "010", "001"};
    int rows = grid.size(), cols = grid[0].size(), islands = 0;
    int dr[] = {1, -1, 0, 0}, dc[] = {0, 0, 1, -1};

    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++) {
            if (grid[r][c] != '1') continue;
            islands++;
            std::queue<std::pair<int, int>> q;
            grid[r][c] = '0';             // mark visited in place
            q.push({r, c});
            while (!q.empty()) {
                auto [cr, cc] = q.front(); q.pop();
                for (int d = 0; d < 4; d++) {
                    int nr = cr + dr[d], nc = cc + dc[d];
                    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                    if (grid[nr][nc] != '1') continue;
                    grid[nr][nc] = '0';
                    q.push({nr, nc});
                }
            }
        }
    std::cout << islands << '\n';
}
```

```text
2
```

### Topological order (Kahn's algorithm)

```cpp
int m = 4;
std::vector<std::vector<int>> dag(m);
std::vector<int> indeg(m, 0);
for (auto [u, v] : std::vector<std::pair<int, int>>{{0, 1}, {0, 2}, {1, 3}, {2, 3}}) {
    dag[u].push_back(v);
    indeg[v]++;
}
std::queue<int> ready;
for (int i = 0; i < m; i++)
    if (indeg[i] == 0) ready.push(i);
std::vector<int> order;
while (!ready.empty()) {
    int u = ready.front(); ready.pop();
    order.push_back(u);
    for (int v : dag[u])
        if (--indeg[v] == 0) ready.push(v);
}
// order.size() < m  <=>  the graph has a cycle
std::cout << order.size() << ' ' << order.back() << '\n';
```

```text
4 3
```

### Gotchas

- Mark visited **when pushing**, not when popping — popping-time marks
  let the same node enter the queue twice.
- Grid problems: bounds-check before indexing, and mutating the grid
  ('1' → '0') is the cheapest visited-set.
- Recursion depth: a 10^5-node path graph can overflow the stack —
  mention the iterative rewrite even if you code the recursive one.
