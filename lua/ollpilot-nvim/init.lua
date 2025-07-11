local ollpilot_path = "ollpilot-nvim.ollpilot"
if vim.fn.getcwd() == "/Users/maksymbo/Desktop/www/pets/ollpilot" then
	package.path = package.path
		.. ";/Users/maksymbo/Desktop/www/pets/ollpilot/lua/?.lua"
		.. ";/Users/maksymbo/Desktop/www/pets/ollpilot/lua/?/init.lua"
		.. ";/Users/maksymbo/Desktop/www/pets/ollpilot/lua/ollpilot-nvim/?.lua"
		.. ";/Users/maksymbo/Desktop/www/pets/ollpilot/lua/ollpilot-nvim/?/init.lua"
end

local M = require(ollpilot_path)
-- Setup with default or user configuration
M.setup()

-- Expose commands to the user
vim.api.nvim_create_user_command("Ollpilot", function()
	M.open_ollpilot_window()
end, {})

vim.api.nvim_create_user_command("OllpilotSuggest", function()
	M.suggest_line_solution()
end, { desc = "Get suggestion for current line" })

return M
