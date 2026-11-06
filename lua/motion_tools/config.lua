local M = {}

M.defaults = {
  labels = "asdfghjklqwertyuiopzxcvbnm",
  live_labels = true,
  multi_window = true,
  max_matches = 1000,
  search = { enabled = true, timeout = 100, max_count = 9999, center = true },
  mappings = false,
  textobjects = {
    mappings = {
      inside = false,
      around = false,
      inside_next = false,
      around_next = false,
      inside_prev = false,
      around_prev = false,
      goto_start = false,
      goto_end = false,
    },
    search = { lines = 500, max_bytes = 1024 * 1024 },
    objects = {},
    treesitter = {
      f = { inside = "function.inner", around = "function.outer" },
      c = { inside = "class.inner", around = "class.outer" },
      o = {
        inside = { "block.inner", "conditional.inner", "loop.inner" },
        around = { "block.outer", "conditional.outer", "loop.outer" },
      },
    },
  },
}

function M.resolve(opts)
  if opts ~= nil and type(opts) ~= "table" then
    error("motion-tools: options must be a table")
  end
  local config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  local objects = config.textobjects
  assert(
    objects.search.lines >= 0 and objects.search.lines % 1 == 0,
    "textobjects.search.lines must be a nonnegative integer"
  )
  assert(objects.search.max_bytes > 0, "textobjects.search.max_bytes must be positive")
  for name, lhs in pairs(objects.mappings) do
    assert(
      type(lhs) == "string" or lhs == false,
      "text-object mapping " .. name .. " must be a string or false"
    )
  end
  assert(
    type(config.labels) == "string" and #config.labels >= 2,
    "motion-tools: labels need at least two ASCII letters"
  )
  local seen = {}
  for char in config.labels:gmatch(".") do
    assert(char:match("%a") and not seen[char], "motion-tools: labels must be unique ASCII letters")
    seen[char] = true
  end
  for _, field in ipairs({ "live_labels", "multi_window", "mappings" }) do
    assert(type(config[field]) == "boolean", "motion-tools: " .. field .. " must be boolean")
  end
  assert(
    type(config.max_matches) == "number" and config.max_matches >= 1 and config.max_matches % 1 == 0,
    "motion-tools: invalid max_matches"
  )
  assert(type(config.search) == "table", "motion-tools: search must be a table")
  for _, field in ipairs({ "enabled", "center" }) do
    assert(
      type(config.search[field]) == "boolean",
      "motion-tools: search." .. field .. " must be boolean"
    )
  end
  for _, field in ipairs({ "timeout", "max_count" }) do
    assert(
      type(config.search[field]) == "number" and config.search[field] >= 1,
      "motion-tools: search." .. field .. " must be positive"
    )
  end
  return config
end

M.options = M.resolve()
return M
