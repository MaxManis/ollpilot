# Ollpilot Nvim Plugin for Neovim

This plugin integrates with the Ollama AI models for text generation and contextual help in Neovim. It allows you to interact with Ollama by sending prompts, generating suggestions, searching for project symbols and LSP references, and viewing file history.

## Features

- **Generation**: Send a prompt to an Ollama server and retrieve the response.
- **Streaming**: Response tokens streaming.
- **Suggestion**: Generate suggestions in the current buffer based on the context around the cursor.

### Later...

- **Grep Project**: Search the project for symbols and LSP references.
- **File History**: View recent changes in the file.

## Installation

1. **Install Neovim** if you haven't already.

## Configuration

You can configure Ollama by editing the `init.lua` file and adding or modifying the following settings:

```lua
require 'ollama'.setup {
  host = "http://localhost:1333",
  model = "llama-7b",
  floating_window = true,
  debug_log = true,
}
```

### Configuration Options

- **host**: The URL of your Ollama server. Default is `http://localhost:1333`.
- **model**: The name of the Ollama model to use.
- **floating_window**: Whether to open a floating window for the Ollama interaction. Default is `true`.
- **debug_log**: Enable or disable debug logging for troubleshooting. Default is `false`.

## Usage

1. Open Neovim and start typing your prompt.
2. Run `Ollpilot` to open a window and send the prompt to Ollama.
3. The response will be displayed in the same window.

### Keybindings

- **q**: Close the Ollama interaction window.

**In Ollpilot window:**

- **<leader>os**: change models size to S(smalle - default)
- **<leader>om**: change models size to M(medium)
- **<leader>ol**: change models size to L(large)

## Contribution

Feel free to contribute by creating pull requests or issues on the [GitHub repository](https://github.com/ollpilot-nvim/ollama.nvim).
