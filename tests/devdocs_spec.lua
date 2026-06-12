-- Tests for the devdocs module: config, index lookup, page display.

local function reload()
  package.loaded["devdocs"] = nil
  return require("devdocs")
end

local function write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

-- Build a fake installed docset under a tmp data dir.
local function make_fixture()
  local dir = vim.fn.tempname()
  local root = dir .. "/cpp"
  write_file(root .. "/index.json", vim.json.encode({
    entries = {
      { name = "std::foo",      path = "utility/foo",  type = "Utilities" },
      { name = "std::foo::bar", path = "utility/foo/bar", type = "Utilities" },
    },
  }))
  write_file(root .. "/pages-md/utility/foo.md", "# std::foo\n\nFoo docs.\n")
  return dir
end

describe("devdocs", function()
  it("setup merges user config over defaults", function()
    local d = reload()
    d.setup({ docsets = { cpp = { slug = "cpp-custom" } } })
    assert.equals("cpp-custom", d.config.docsets.cpp.slug)
    assert.is_not_nil(d.config.docsets.python, "other docsets survive the merge")
    assert.equals("cpp", d.config.filetypes.cpp)
  end)

  it("installed() reflects which docsets have an index on disk", function()
    local d = reload()
    d.setup({ data_dir = make_fixture() })
    assert.same({ "cpp" }, d.installed())
  end)

  it("_find_entry matches exact names and docset prefixes", function()
    local d = reload()
    d.setup({ data_dir = make_fixture() })
    assert.equals("utility/foo", d._find_entry("cpp", "std::foo").path)
    assert.equals("utility/foo", d._find_entry("cpp", "foo").path, "std:: prefix tried")
    assert.is_nil(d._find_entry("cpp", "nonexistent"))
  end)

  it("open() shows the page in a markdown scratch buffer", function()
    local d = reload()
    d.setup({ data_dir = make_fixture() })
    d.open("foo", "cpp")
    local buf = vim.api.nvim_get_current_buf()
    assert.equals("devdocs://cpp/std::foo", vim.api.nvim_buf_get_name(buf))
    assert.equals("markdown", vim.bo[buf].filetype)
    assert.is_false(vim.bo[buf].modifiable)
    -- regular buftype: renderers pad nofile buffers with NormalFloat (an LSP
    -- hover heuristic), bleeding a float-colored band in normal splits
    assert.equals("", vim.bo[buf].buftype)
    assert.is_false(vim.bo[buf].modified)
    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    assert.equals("# std::foo", first)
    vim.cmd.close()
  end)

  it("doc pages navigate man-style: follow replaces in-window, <C-T> goes back", function()
    local d = reload()
    local dir = make_fixture()
    write_file(dir .. "/cpp/pages-md/utility/bar.md", "# std::bar\n\nBar docs, see `std::foo`.\n")
    write_file(dir .. "/cpp/index.json", vim.json.encode({ entries = {
      { name = "std::foo", path = "utility/foo", type = "U" },
      { name = "std::bar", path = "utility/bar", type = "U" },
    } }))
    d.setup({ data_dir = dir })

    local wins_before = #vim.api.nvim_list_wins()
    d.open("std::bar", "cpp")
    assert.equals("devdocs://cpp/std::bar", vim.api.nvim_buf_get_name(0))
    assert.equals(wins_before + 1, #vim.api.nvim_list_wins(), "first page opens a split")

    local function buf_map(lhs)
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
        if m.lhs == lhs then return m end
      end
    end
    assert.is_not_nil(buf_map("K"), "K mapped in doc buffer")
    assert.is_not_nil(buf_map("gK"), "gK mapped in doc buffer")

    -- follow the std::foo reference with K
    vim.fn.search("std::foo")
    buf_map("K").callback()
    assert.equals("devdocs://cpp/std::foo", vim.api.nvim_buf_get_name(0), "followed reference")
    assert.equals(wins_before + 1, #vim.api.nvim_list_wins(), "follow reuses the window")

    -- <C-T> back to the previous page
    buf_map("<C-T>").callback()
    assert.equals("devdocs://cpp/std::bar", vim.api.nvim_buf_get_name(0), "back-navigated")

    -- g? / <C-H> open the less-style help float; q closes it
    local help = buf_map("g?")
    assert.is_not_nil(help, "g? mapped for pager help")
    assert.is_not_nil(buf_map("<C-H>"), "<C-H> mapped for pager help")
    assert.is_nil(buf_map("h"), "h motion left untouched")
    help.callback()
    local cfg = vim.api.nvim_win_get_config(0)
    assert.is_truthy(cfg.relative ~= "", "help is a floating window")
    vim.cmd.close() -- help float
    vim.cmd.close() -- doc page
  end)

  it("viewer='man' highlights code blocks via treesitter string parsing", function()
    local d = reload()
    local dir = make_fixture()
    -- 'c' parser ships with nvim core (cpp needs nvim-treesitter, absent in
    -- the --noplugin test env)
    write_file(dir .. "/cpp/pages-md/utility/foo.md", table.concat({
      "# std::foo",
      "",
      "Intro text.",
      "",
      "```c",
      "int main(void) { return 42; }",
      "```",
      "",
    }, "\n"))
    d.setup({ data_dir = dir, viewer = "man" })
    d.open("std::foo", "cpp")

    local buf = vim.api.nvim_get_current_buf()
    assert.equals("man", vim.bo[buf].filetype)
    local ns = vim.api.nvim_get_namespaces()["devdocs.code"]
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
    assert.is_true(#marks > 1, "code block got background + syntax extmarks, got " .. #marks)
    local has_bg, has_syntax = false, false
    for _, m in ipairs(marks) do
      if m[4].line_hl_group == "DevdocsCodeBlock" then has_bg = true end
      if (m[4].hl_group or ""):match("^@") then has_syntax = true end
    end
    assert.is_true(has_bg, "block background applied")
    assert.is_true(has_syntax, "treesitter captures applied")
    vim.cmd.close()
  end)

  it("viewer='man' shows the page through :Man machinery", function()
    local d = reload()
    d.setup({ data_dir = make_fixture(), viewer = "man" })
    d.open("foo", "cpp")
    local buf = vim.api.nvim_get_current_buf()
    assert.equals("man", vim.bo[buf].filetype, "Man! applied")
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, 5, false), "\n")
    assert.is_truthy(text:match("std::foo"), "title present in rendered page")
    vim.cmd.close()
  end)

  it("viewer='man' keeps troff warnings out of the page", function()
    local d = reload()
    local dir = make_fixture()
    -- an unbreakable word longer than the typeset width makes troff warn on
    -- stderr ("cannot break line"); that must never appear as page content
    write_file(dir .. "/cpp/pages-md/utility/foo.md",
      "# std::foo\n\n" .. string.rep("x", 120) .. " end of text.\n")
    d.setup({ data_dir = dir, viewer = "man", width = 60 })
    d.open("std::foo", "cpp")
    local buf = vim.api.nvim_get_current_buf()
    for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      assert.is_falsy(l:match("^troff:"), "troff warning leaked into buffer: " .. l)
    end
    vim.cmd.close()
  end)

  it("viewer='man' typesets at the configured width", function()
    local d = reload()
    d.setup({ data_dir = make_fixture(), viewer = "man", width = 60 })
    d.open("foo", "cpp")
    local buf = vim.api.nvim_get_current_buf()
    local max = 0
    for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      max = math.max(max, vim.fn.strdisplaywidth(l))
    end
    assert.is_true(max <= 60, "no rendered line exceeds width=60, widest was " .. max)
    assert.is_true(max >= 50, "header line typeset near the full width, widest was " .. max)
    vim.cmd.close()
  end)

  it("lookup_cword resolves the docset from the buffer filetype", function()
    local d = reload()
    d.setup({ data_dir = make_fixture() })
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "std::foo x;" })
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].filetype = "cpp"
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    d.lookup_cword()
    assert.equals("devdocs://cpp/std::foo", vim.api.nvim_buf_get_name(0),
      "qualified name captured via iskeyword ':' and opened")
    vim.cmd.close()
  end)
end)

describe("notes", function()
  local function setup_with_notes()
    local d = reload()
    local dir = make_fixture()
    local ndir = vim.fn.tempname()
    -- annotation for the existing std::foo page
    write_file(ndir .. "/cpp/utility/foo.md",
      "### Gotchas\n\nFoo annotation text.\n\n```c\nint x = 1;\n```\n")
    -- custom page (no matching generated page)
    write_file(ndir .. "/cpp/guides/foo-patterns.md",
      "# Foo patterns\n\nCustom page content.\n")
    d.setup({ data_dir = dir, notes_dirs = { ndir } })
    return d, dir, ndir
  end

  it("annotations are appended to the page in the markdown viewer", function()
    local d = setup_with_notes()
    d.open("std::foo", "cpp")
    local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert.is_truthy(text:match("Foo docs%."), "original page content present")
    assert.is_truthy(text:match("### Gotchas"), "annotation heading present")
    assert.is_truthy(text:match("Foo annotation text"), "annotation body present")
    vim.cmd.close()
  end)

  it("annotations render in the man viewer too", function()
    local d = setup_with_notes()
    require("devdocs").setup({ viewer = "man" })
    d.open("std::foo", "cpp")
    local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert.equals("man", vim.bo.filetype)
    assert.is_truthy(text:match("Gotchas"), "annotation section typeset")
    assert.is_truthy(text:match("Foo annotation text"), "annotation body typeset")
    vim.cmd.close()
  end)

  it("custom pages are indexed by heading and open from their file", function()
    local d = setup_with_notes()
    local entries = require("devdocs.notes").custom_entries()
    assert.equals(1, #entries)
    assert.equals("Foo patterns", entries[1].name)
    assert.equals("cpp", entries[1].docset)

    d.open("Foo patterns", "cpp")
    assert.equals("devdocs://cpp/Foo patterns", vim.api.nvim_buf_get_name(0))
    local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert.is_truthy(text:match("Custom page content"))
    vim.cmd.close()
  end)

  it(":DevdocsNote opens (and seeds) the annotation file for the page", function()
    local d, _, ndir = setup_with_notes()
    -- remove the existing annotation so note() takes the create-and-seed path
    os.remove(ndir .. "/cpp/utility/foo.md")
    d.open("std::foo", "cpp")
    d.note()
    assert.equals(ndir .. "/cpp/utility/foo.md", vim.api.nvim_buf_get_name(0))
    assert.equals("### Notes", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], "seeded heading")
    vim.cmd("bwipeout!") -- discard the unsaved note
    vim.cmd.close()
  end)
end)

describe("LSP candidate resolution", function()
  -- fixtures captured from real clangd 22 responses
  local HOVER = "### variable `oss`\n\n---\nType: `std::ostringstream (aka basic_ostringstream<char>)`\n\n---\n```cpp\n// In f\nstd::ostringstream oss\n```"

  it("normalizes type spellings to index form", function()
    local d = reload()
    assert.equals("std::basic_ostringstream", d._normalize_type("std::__cxx11::basic_ostringstream::"))
    assert.equals("basic_ostringstream", d._normalize_type("basic_ostringstream<char>"))
    assert.equals("std::string", d._normalize_type("const std::string &"))
    assert.equals("std::vector", d._normalize_type("std::vector<int, std::allocator<int>> *"))
  end)

  it("extracts type candidates from clangd hover (aka form)", function()
    local d = reload()
    local c = d._hover_candidates(HOVER)
    assert.same({ "std::ostringstream", "basic_ostringstream", "std::basic_ostringstream" }, c)
  end)

  it("builds qualified member candidates from symbolInfo", function()
    local d = reload()
    assert.same({ "std::basic_ostringstream::str" },
      d._symbol_candidates({ { name = "str", containerName = "std::basic_ostringstream::" } }))
    assert.same({}, d._symbol_candidates({ { name = "oss", containerName = "f" } }),
      "function-scope container is not a type")
    assert.same({}, d._symbol_candidates(nil))
  end)

  it("tolerates vim.NIL (JSON null) in LSP responses", function()
    local d = reload()
    -- clangd sends containerName: null for project-local symbols like
    -- LinuxParser::UpTime resolved at namespace scope
    assert.same({}, d._symbol_candidates({ { name = "UpTime", containerName = vim.NIL } }))
    assert.same({}, d._symbol_candidates({ { name = vim.NIL } }))
    assert.same({}, d._hover_candidates(vim.NIL))
    assert.equals("", d._normalize_type(vim.NIL))
  end)

  it("_lsp_candidates returns empty without an LSP client", function()
    local d = reload()
    local got
    d._lsp_candidates(vim.api.nvim_get_current_buf(), function(c) got = c end)
    vim.wait(500, function() return got ~= nil end, 50)
    assert.same({}, got)
  end)
end)

describe("convert.py wrapping", function()
  it("wraps prose at --width but never code fences", function()
    local long = string.rep("lorem ipsum dolor ", 12) -- ~200 chars
    local code = "int a_very_long_declaration_line_that_must_stay_intact_no_matter_what(void);"
    local html = "<html><body><h1>t</h1><p>" .. long .. "</p><pre>" .. code .. "</pre>"
      .. "<ul><li>" .. long .. "</li></ul></body></html>"
    local dir = vim.fn.tempname()
    write_file(dir .. "/pages/w.html", html)
    local out = vim.fn.system({ "python", vim.fn.getcwd() .. "/scripts/convert.py", dir, "w", "--width=80" })
    assert.equals(0, vim.v.shell_error, out)
    local in_fence = false
    for line in out:gmatch("[^\n]+") do
      if line:match("^```") then
        in_fence = not in_fence
      elseif in_fence then
        assert.is_truthy(line:find(code, 1, true), "fence content intact")
      else
        assert.is_true(#line <= 80, "prose wrapped: " .. line)
      end
    end
    assert.is_truthy(out:match("\n%- lorem"), "list item present")
    assert.is_truthy(out:match("\n  %a"), "list continuation has hanging indent")
  end)
end)

describe("convert.py", function()
  it("converts cppreference structures to markdown", function()
    local html = [[
<html><body>
<h1>std::frob</h1>
<table class="t-dcl-begin"><tr class="t-dcl">
  <td><span>void frob( int x );</span></td><td>(1)</td><td>(since C++17)</td>
</tr></table>
<p><span class="t-li">1)</span> Frobs <code>x</code> thoroughly.</p>
<dl><dt>param</dt><dd><p>the thing</p></dd></dl>
</body></html>]]
    local dir = vim.fn.tempname()
    write_file(dir .. "/pages/frob.html", html)
    local out = vim.fn.system({ "python", vim.fn.getcwd() .. "/scripts/convert.py", dir, "frob" })
    assert.equals(0, vim.v.shell_error, out)
    assert.is_truthy(out:match("# std::frob"), "heading")
    assert.is_truthy(out:match("```cpp\nvoid frob%( int x %);  // %(1%) %(since C%+%+17%)"), "dcl fence")
    assert.is_truthy(out:match("1%) Frobs `x` thoroughly%."), "overload line with inline code")
    assert.is_truthy(out:match("%*%*param%*%*"), "dl term bolded")
  end)
end)
