local ollama_path = "ollpilot-nvim.ollpilot"
if vim.fn.getcwd() == "/Users/maksymbo/Desktop/www/pets/ollpilot" then
	package.path = package.path
		.. ";/Users/maksymbo/Desktop/www/pets/ollpilot/lua/?.lua"
		.. ";/Users/maksymbo/Desktop/www/pets/ollpilot/lua/?/init.lua"
		.. ";/Users/maksymbo/Desktop/www/pets/ollpilot/lua/ollpilot-nvim/?.lua"
		.. ";/Users/maksymbo/Desktop/www/pets/ollpilot/lua/ollpilot-nvim/?/init.lua"
end

local ollama = require(ollama_path)
-- Setup with default or user configuration
ollama.setup()
local ollama = require(ollama_path)
-- Setup with default or user configuration
ollama.setup()

-- Expose commands to the user
vim.api.nvim_create_user_command("Ollpilot", function()
	ollama.open_ollpilot_window()
end, {})

vim.api.nvim_create_user_command("OllpilotSuggest", function()
	ollama.suggest_line_solution()
end, { desc = "Get suggestion for current line" })
