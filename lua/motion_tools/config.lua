local M = {}

M.defaults = {
  labels = "asdfghjklqwertyuiopzxcvbnm",
  multi_window = true,
  max_matches = 1000,
  search = { enabled = true, timeout = 100, max_count = 9999, center = true },
  mappings = false,
}

function M.resolve(opts)
  if opts ~= nil and type(opts) ~= "table" then
    error("motion-tools: options must be a table")
  end
  local config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  assert(
    type(config.labels) == "string" and #config.labels >= 2,
    "motion-tools: labels need at least two ASCII letters"
  )
  local seen = {}
  for char in config.labels:gmatch(".") do
    assert(char:match("%a") and not seen[char], "motion-tools: labels must be unique ASCII letters")
    seen[char] = true
  end
  for _, field in ipairs({ "multi_window", "mappings" }) do
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
