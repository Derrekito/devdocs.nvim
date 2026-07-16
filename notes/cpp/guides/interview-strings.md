# Interview: string cookbook

### Split on a delimiter

```cpp
std::string csv = "red,green,blue";
std::vector<std::string> parts;
std::stringstream ss(csv);
std::string tok;
while (std::getline(ss, tok, ','))
    parts.push_back(tok);
std::cout << parts.size() << ' ' << parts[1] << '\n';
```

```text
3 green
```

Whitespace split is even shorter: `while (ss >> tok)`.

### Join with a separator

```cpp
std::string out;
for (size_t i = 0; i < parts.size(); i++) {
    if (i) out += '-';
    out += parts[i];
}
std::cout << out << '\n';
```

```text
red-green-blue
```

### Parse and format numbers

```cpp
int n = std::stoi("42");                  // throws on garbage/overflow
std::string s2 = std::to_string(n * 2);
std::cout << s2 << '\n';
```

```text
84
```

### Case transforms and classification

```cpp
std::string word = "Hello123";
for (char& c : word) c = (char)std::tolower((unsigned char)c);
int digits = 0;
for (char c : word)
    if (std::isdigit((unsigned char)c)) digits++;
std::cout << word << ' ' << digits << '\n';
```

```text
hello123 3
```

The `(unsigned char)` cast is the correct spelling — plain `char` can
be negative and makes `isdigit`/`tolower` undefined behavior.

### Find and npos

```cpp
std::string text = "one two three";
auto pos = text.find("two");
if (pos != std::string::npos)
    std::cout << "at " << pos << '\n';    // compare to npos, never -1
```

```text
at 4
```

### Reverse the words in a sentence

```cpp
std::string sentence = "world the hello";
std::stringstream in(sentence);
std::vector<std::string> words;
std::string w;
while (in >> w) words.push_back(w);
std::reverse(words.begin(), words.end());
for (size_t i = 0; i < words.size(); i++)
    std::cout << words[i] << (i + 1 < words.size() ? ' ' : '\n');
```

```text
hello the world
```

### Gotchas

- Build with `+=` in a loop (amortized O(1) growth); repeated
  `a = a + b` copies the whole string every time.
- `substr` copies — fine at interview scale, worth *saying* you know.
- Frequency-count letters with `int cnt[26]` and `c - 'a'` when the
  problem guarantees lowercase — fastest to write and run.
