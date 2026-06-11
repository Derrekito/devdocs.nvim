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
    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    assert.equals("# std::foo", first)
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
