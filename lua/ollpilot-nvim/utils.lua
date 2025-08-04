local M = {}

-- Configuration defaults
M.config = {
  model = "qwen2.5-coder:1.5b", -- default model
  host = "http://localhost:11434",
  floating_window = true,
  window_width = 0.8,
  window_height = 0.6,
  -- NOTE: PART 2 config
  suggestion = {
    lines_before = 3,
    lines_after = 3,
    accept_key = "<leader>sa",
    reject_key = "<leader>sr",
    highlight = "Comment",
  },
}

-- Track the source buffer separately
M.source_buf = nil

-- Initialize the plugin configuration
function M.setup_config(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

-- Get current filename
function M.get_current_file_name()
  if not M.source_buf or not vim.api.nvim_buf_is_valid(M.source_buf) then
    return "No valid source buffer available"
  end

  local filepath = vim.api.nvim_buf_get_name(M.source_buf)
  local filename = filepath ~= "" and vim.fn.fnamemodify(filepath, ":t") or "[No Name]"
  return filename
end

-- Get enhanced context including file information
function M.get_enhanced_context()
  local filename = M.get_current_file_name()
  local filetype = vim.api.nvim_buf_get_option(M.source_buf, "filetype")
  local content = table.concat(vim.api.nvim_buf_get_lines(M.source_buf, 0, -1, false), "\n")
  local files = vim.fn.globpath(vim.fn.getcwd(), "**/*." .. filetype, false, true)
  local project_overview = table.concat(files, "\n")

  return string.format(
    "File: %s\n" .. "Filetype: %s\n" .. "Project files:\n%s\n" .. "Content:\n```%s\n%s\n```",
    filename,
    filetype,
    project_overview,
    filetype,
    content
  )
end

-- Create the Ollama API request body
function M.create_request_body(prompt)
  local context = M.get_enhanced_context()
  local full_prompt = string.format(
    "You are Qwen, created by Alibaba Cloud. You are a helpful assistant.\n\n%s\n\nBased on the above file, %s",
    context,
    prompt
  )

  return vim.json.encode({
    model = M.config.model,
    prompt = full_prompt,
    stream = true,
  })
end

-- Handle the Ollama API response
function M.handle_response(data, callback)
  local response = table.concat(data, "")
  local ok, json = pcall(vim.fn.json_decode, response)

  if ok and json.response then
    callback(json.response)
  else
    vim.notify("Failed to process response: " .. response, vim.log.levels.ERROR)
  end
end

function M.update_window_title(win, model)
  vim.api.nvim_win_set_config(win, {
    title = {
      { " ✨ Ollpilot ", "Title" },
      { "Model: " .. model, "Comment" },
    },
  })
end

-- Create window configuration for floating window
function M.create_window_config()
  local width = math.floor(vim.o.columns * M.config.window_width)
  local height = math.floor(vim.o.lines * M.config.window_height)
  local row_pos = math.floor((vim.o.lines - height) / 2)
  local col_pos = math.floor((vim.o.columns - width) / 2)

  return {
    relative = "editor",
    width = width,
    height = height,
    col = col_pos,
    row = row_pos,
    style = "minimal",
    border = {
      { "╭", "FloatBorder" },
      { "─", "FloatBorder" },
      { "╮", "FloatBorder" },
      { "│", "FloatBorder" },
      { "╯", "FloatBorder" },
      { "─", "FloatBorder" },
      { "╰", "FloatBorder" },
      { "│", "FloatBorder" },
    },
    title = {
      { " ✨ Ollpilot ", "Title" },
      { "Model: " .. M.config.model, "Comment" },
    },
    title_pos = "center",
    footer = {
      { "File: " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") .. "; ", "Comment" },
      { "Press <CR> to submit, q to close",                                         "MoreMsg" },
    },
    footer_pos = "right",
    noautocmd = true,
  }
end

-- NOTE: PART
function M.get_context_around_cursor(lines_before, lines_after)
  local buf = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local total_lines = vim.api.nvim_buf_line_count(buf)

  -- Calculate line ranges
  local start_line = math.max(1, cursor_line - lines_before)
  local end_line = math.min(total_lines, cursor_line + lines_after)

  -- Get surrounding lines
  local before = vim.api.nvim_buf_get_lines(buf, start_line - 1, cursor_line - 1, false)
  local target = vim.api.nvim_buf_get_lines(buf, cursor_line - 1, cursor_line, false)[1]
  local after = vim.api.nvim_buf_get_lines(buf, cursor_line, end_line, false)

  return {
    before = before,
    target = target,
    after = after,
    line_number = cursor_line,
  }
end

function M.create_context_prompt(context)
  return string.format(
    "You are Qwen, created by Alibaba Cloud. You are a helpful assistant.\n\n"
    .. "Code before:\n```\n%s\n```\n"
    .. "Target line (line %d):\n```\n%s\n```\n"
    .. "Code after:\n```\n%s\n```\n"
    .. "Please suggest the best implementation for the target line. "
    .. "Respond with just the code solution, no explanations.",
    table.concat(context.before, "\n"),
    context.line_number,
    context.target,
    table.concat(context.after, "\n")
  )
end

function M.debug_log(data)
  vim.notify(vim.inspect(data), vim.log.levels.DEBUG)
end

return M
