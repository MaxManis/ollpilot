local utils = require("ollpilot-nvim.utils") -- add 'ollpilot-nvim' before publish
local M = {}

-- Initialize the plugin
function M.setup(user_config)
  utils.setup_config(user_config)
end

-- Send prompt to Ollama
local function query_ollama(prompt, callback, useContext)
  local request_body = vim.json.encode({
    model = utils.config.model,
    prompt = prompt,
    stream = false,
  })

  if useContext then
    request_body = utils.create_request_body(prompt)
  end

  if vim.system then
    local cmd = {
      "curl",
      "-s",
      utils.config.host .. "/api/generate",
      "-H",
      "Content-Type: application/json",
      "-d",
      request_body,
    }

    vim.system(cmd, { text = true }, function(obj)
      if obj.code ~= 0 then
        vim.notify("Ollama request failed: " .. obj.stderr, vim.log.levels.ERROR)
        return
      end

      local ok, json = pcall(vim.json.decode, obj.stdout)
      if not ok then
        vim.notify("Failed to parse Ollama response", vim.log.levels.ERROR)
        return
      end

      if json.response then
        callback(json.response)
      else
        vim.notify("Unexpected response format: " .. vim.inspect(json), vim.log.levels.WARN)
      end
    end)
  else
    -- Fallback for Neovim < 0.10
    local cmd = string.format(
      "curl -s -X POST %s/api/generate -H \"Content-Type: application/json\" -d '%s'",
      utils.config.host,
      vim.fn.shellescape(request_body)
    )

    vim.fn.jobstart(cmd, {
      on_stdout = function(_, data)
        utils.handle_response(data, callback)
      end,
      on_stderr = function(_, data)
        vim.notify("Ollama error: " .. table.concat(data, ""), vim.log.levels.ERROR)
      end,
      stdout_buffered = true,
      stderr_buffered = true,
    })
  end
end

-- Create Ollpilot interaction window
function M.open_ollpilot_window()
  -- Create main buffer and window
  local buf = vim.api.nvim_create_buf(false, true)
  utils.source_buf = vim.api.nvim_get_current_buf()
  local win_opts = utils.create_window_config()
  local main_win = vim.api.nvim_open_win(buf, true, win_opts)
  M.main_win = main_win -- Store main window reference

  -- First configure the buffer (modifiable)
  M.output_buf = buf
  vim.api.nvim_buf_set_option(M.output_buf, "filetype", "markdown")
  vim.api.nvim_buf_set_lines(M.output_buf, 0, -1, false, { "Response will appear here..." })

  -- Then set as readonly
  vim.api.nvim_buf_set_option(M.output_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(M.output_buf, "readonly", true)

  -- Rest of window setup...
  local win_width = vim.api.nvim_win_get_width(main_win)
  local win_height = vim.api.nvim_win_get_height(main_win)
  local input_height = math.min(3, math.floor(win_height * 0.2))
  local output_height = win_height - input_height - 2 -- -1 for border

  -- Set main window height for output area
  vim.api.nvim_win_set_height(main_win, output_height)
  vim.api.nvim_win_set_option(main_win, "winhl", "Normal:NormalFloat")

  -- Create and configure input window
  M.input_buf = vim.api.nvim_create_buf(false, true)
  M.input_win = vim.api.nvim_open_win(M.input_buf, false, {
    relative = "win",
    win = main_win,
    width = win_width - 2,
    height = input_height,
    row = output_height + 1,
    col = 1,
    style = "minimal",
    border = "double",
    title = "Ask:",
  })

  -- Configure input buffer
  vim.api.nvim_buf_set_option(M.input_buf, "buftype", "prompt")
  vim.api.nvim_buf_set_option(M.input_buf, "filetype", "markdown")
  vim.fn.prompt_setprompt(M.input_buf, "❯ ")

  -- Set cursor to input window immediately
  vim.api.nvim_set_current_win(M.input_win)

  -- Set keymaps
  vim.keymap.set({ "n", "i" }, "<CR>", function()
    M.send_prompt()
  end, { buffer = M.input_buf })
  vim.keymap.set("n", "q", M.close_window, { buffer = M.input_buf })

  vim.keymap.set("n", "q", M.close_window, { buffer = M.output_buf })
end

function M.close_window()
  if M.main_win and vim.api.nvim_win_is_valid(M.main_win) then
    vim.api.nvim_win_close(M.main_win, true)
  end
  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_win_close(M.input_win, true)
  end
  if M.output_buf and vim.api.nvim_buf_is_valid(M.output_buf) then
    vim.api.nvim_buf_delete(M.output_buf, { force = true })
  end
  if M.input_buf and vim.api.nvim_buf_is_valid(M.input_buf) then
    vim.api.nvim_buf_delete(M.input_buf, { force = true })
  end

  -- Set cursor to current file window
  if utils.source_buf and vim.api.nvim_buf_is_valid(utils.source_buf) then
    -- vim.api.nvim_set_current_win(utils.source_buf)
  end

  M.main_win = nil
  M.input_win = nil
  M.output_buf = nil
  M.input_buf = nil
end

-- Send prompt from the Ollama buffer
function M.send_prompt()
  if not M.input_buf or not vim.api.nvim_buf_is_valid(M.input_buf) then
    vim.notify("Ollama buffer not found", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
  local prompt = table.concat(lines, "\n")

  if #prompt == 0 then
    vim.notify("Prompt cannot be empty", vim.log.levels.WARN)
    return
  end

  vim.schedule(function()
    -- Clear input buffer
    vim.api.nvim_buf_set_lines(M.input_buf, 0, -1, false, { "" })
    -- Make output buffer modifiable temporarily
    vim.api.nvim_buf_set_option(M.output_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M.output_buf, 0, -1, false, { "Loading response..." })
  end)

  query_ollama(prompt, function(response)
    if not response or #response == 0 then
      vim.schedule(function()
        vim.api.nvim_buf_set_lines(M.output_buf, 0, -1, false, { "No response received" })
        vim.api.nvim_buf_set_option(M.output_buf, "modifiable", false)
      end)
      return
    end
    vim.schedule(function()
      vim.api.nvim_buf_set_lines(M.output_buf, 0, -1, false, vim.split(response, "\n"))
      vim.api.nvim_buf_set_option(M.output_buf, "modifiable", false)

      -- Add copy keymap
      vim.keymap.set("n", "y", function()
        local lines = vim.api.nvim_buf_get_lines(M.output_buf, 0, -1, false)
        vim.fn.setreg('"', table.concat(lines, "\n"))
        vim.notify("Copied to clipboard", vim.log.levels.INFO)
      end, { buffer = M.output_buf })
    end)
  end, true)
end

-- NOTE: PART 2:
local virtual_text_ns = vim.api.nvim_create_namespace("ollpilot_suggestions")

function M.suggest_line_solution()
  -- Get context around cursor (3 lines before/after by default)
  local context = utils.get_context_around_cursor(5, 5)
  local prompt = utils.create_context_prompt(context)

  -- NOTE: does not work for now, lsp integration should be fixed to be able use it here
  -- prompt = M.enhance_context("symbol", prompt)

  -- Show loading indicator
  vim.notify("Generating suggestion...", vim.log.levels.INFO)

  query_ollama(prompt, function(response)
    vim.schedule(function()
      -- Clear any existing virtual text
      vim.api.nvim_buf_clear_namespace(0, virtual_text_ns, 0, -1)

      -- Clean the response (remove empty lines and trim whitespace)
      local cleaned_response = vim.trim(response:gsub("\n\n+", "\n"))
      -- remove regular code formating like ```
      cleaned_response = vim.trim(cleaned_response:gsub("^```%w+", ""))
      cleaned_response = vim.trim(cleaned_response:gsub("```", ""))

      -- Split into lines if multiline
      local response_lines = vim.split(cleaned_response, "\n")

      -- Add suggestion as virtual text
      vim.api.nvim_buf_set_extmark(0, virtual_text_ns, context.line_number - 1, 0, {
        virt_text = { { cleaned_response, "Comment" } },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })

      -- Set up accept/reject keymaps
      vim.keymap.set("n", "<leader>sa", function()
        vim.api.nvim_buf_set_lines(0, context.line_number - 1, context.line_number, false, response_lines)
        vim.api.nvim_buf_clear_namespace(0, virtual_text_ns, 0, -1)
      end, { buffer = true, desc = "Accept suggestion" })

      vim.keymap.set("n", "<leader>sr", function()
        vim.api.nvim_buf_clear_namespace(0, virtual_text_ns, 0, -1)
      end, { buffer = true, desc = "Reject suggestion" })
    end)
  end, false)
end

function M.grep_project(pattern, limit)
  local cmd = string.format("rg --vimgrep -n --max-count=%d '%s'", limit or 10, pattern)
  local result = vim.fn.systemlist(cmd)
  return table.concat(result, "\n")
end

function M.get_lsp_references()
  -- Check if LSP is available (compatible with older Neovim versions)
  local clients = vim.lsp.get_active_clients({ bufnr = 0 })
  if #clients == 0 then
    return {}
  end

  local params = vim.lsp.util.make_position_params()
  local references = {}
  local has_references = false

  -- Use vim.lsp.buf_request_all for better compatibility
  local responses = vim.lsp.buf_request_sync(0, "textDocument/references", params)
  if not responses then
    return {}
  end

  for client_id, response in pairs(responses) do
    if response and response.result then
      has_references = true
      local items = vim.lsp.util.locations_to_items(response.result, client_id)
      for _, item in ipairs(items) do
        table.insert(references, {
          filename = item.filename,
          lnum = item.lnum,
          text = item.text,
        })
      end
    end
  end

  return references
end

function M.enhance_context(context_type, current_context)
  local enhancements = {}

  if context_type == "symbol" then
    -- Get related symbols in project
    local symbol_name = vim.fn.expand("<cword>")
    table.insert(enhancements, "Related symbols in project:")
    table.insert(enhancements, M.grep_project(symbol_name, 5))

    -- Get LSP references
    local references = M.get_lsp_references()
    utils.debug_log("REFERENCES:" .. table.concat(references))
    if references then
      table.insert(enhancements, "LSP references:")
      for _, ref in ipairs(references) do
        table.insert(enhancements, string.format("%s:%d", ref.filename, ref.lnum))
      end
    end
  end

  if context_type == "file" then
    -- Get imports/dependencies
    local imports = M.get_file_imports()
    if #imports > 0 then
      table.insert(enhancements, "File dependencies:")
      table.insert(enhancements, table.concat(imports, "\n"))
    end

    -- Get file history (if available)
    local git_blame = M.get_git_blame()
    if git_blame then
      table.insert(enhancements, "Recent changes:")
      table.insert(enhancements, git_blame)
    end
  end

  return current_context .. "\n\n" .. table.concat(enhancements, "\n")
end

return M
