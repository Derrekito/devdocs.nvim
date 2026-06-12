-- LSP-aware lookup: the word under the cursor is often not the thing to
-- document — a variable should resolve to its TYPE (oss ->
-- std::basic_ostringstream) and a member to Type::member (str ->
-- std::basic_ostringstream::str). clangd knows both:
-- textDocument/symbolInfo gives {name, containerName} for members, and hover
-- exposes a variable's type as "Type: `std::ostringstream (aka
-- basic_ostringstream<char>)`". Candidates are validated against the docset
-- index by the caller, so wrong guesses cost nothing.

local M = {}

-- Normalize a type spelling to index form: drop template args, cv/ref
-- qualifiers, implementation inline namespaces, and trailing '::'.
-- LSP responses encode JSON null as vim.NIL (truthy userdata), so anything
-- non-string normalizes to "".
function M.normalize_type(t)
  if type(t) ~= "string" then return "" end
  t = t:gsub("%b<>", "")
  t = t:gsub("__cxx11::", ""):gsub("__1::", "")
  t = t:gsub("const ", ""):gsub("volatile ", "")
  t = t:gsub("^%s+", ""):gsub("[%s&%*]+$", "")
  t = t:gsub("::$", "")
  return t
end

-- Candidates from a clangd hover markdown blob. Two shapes:
--   variables:        "Type: `X (aka Y)`"
--   keywords (auto):  no Type line; the deduced type sits alone in the
--                     trailing code fence, e.g. ```cpp\ndirectory_entry\n```
function M.hover_candidates(markdown)
  if type(markdown) ~= "string" then return {} end
  local ty = markdown:match("Type: `([^`\n]+)`")
  if not ty then
    local fence = markdown:match("```%w*\n(.-)\n?```%s*$")
    if fence then
      local lines = {}
      for line in fence:gmatch("[^\n]+") do
        if not line:match("^%s*//") and line:match("%S") then
          lines[#lines + 1] = line
        end
      end
      -- only trust a lone line that looks like a type, not a declaration
      if #lines == 1 and not lines[1]:find("(", 1, true) then
        ty = lines[1]
      end
    end
  end
  if not ty then return {} end
  local primary = ty:match("^(.-)%s*%(aka%s") or ty
  local aka = ty:match("%(aka%s+(.*)%)%s*$")
  local out = {}
  for _, raw in ipairs({ primary, aka }) do
    if raw then
      local n = M.normalize_type(raw)
      if n ~= "" then
        table.insert(out, n)
        if not n:match("^std::") then table.insert(out, "std::" .. n) end
      end
    end
  end
  return out
end

-- Candidate from a clangd textDocument/symbolInfo response (member case).
function M.symbol_candidates(res)
  local sym = type(res) == "table" and res[1]
  if not (type(sym) == "table" and type(sym.name) == "string") then return {} end
  local container = M.normalize_type(sym.containerName)
  if container == "" or not container:find("::", 1, true) then
    -- container is a bare function/file scope, not a qualified type
    return {}
  end
  return { container .. "::" .. sym.name }
end

-- Ask the buffer's LSP for lookup candidates; cb receives a (possibly empty)
-- ordered list. Member resolution (symbolInfo) outranks type-of-variable
-- (hover); both fire in parallel with a guard timeout.
function M.candidates(bufnr, cb)
  if #vim.lsp.get_clients({ bufnr = bufnr }) == 0 then
    cb({})
    return
  end
  local params = vim.lsp.util.make_position_params(0, "utf-16")
  local results = { sym = {}, hover = {} }
  local pending, fired = 2, false
  local function step()
    pending = pending - 1
    if pending > 0 or fired then return end
    fired = true
    local out = {}
    vim.list_extend(out, results.sym)
    vim.list_extend(out, results.hover)
    cb(out)
  end
  vim.lsp.buf_request(bufnr, "textDocument/symbolInfo", params, function(_, res)
    results.sym = M.symbol_candidates(res)
    step()
  end)
  vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(_, res)
    local md = res and res.contents and res.contents.value
    results.hover = M.hover_candidates(md)
    step()
  end)
  vim.defer_fn(function()
    if not fired then
      fired = true
      cb({})
    end
  end, 2000)
end

return M
