# Neotest Odin

[Neotest](https://github.com/nvim-neotest/neotest) adapter for running [Odin](https://github.com/odin-lang/Odin) tests in [Neovim](https://github.com/neovim/neovim).

## ⚙️ Requirements

- [`Odin` installed](https://odin-lang.org/docs/install/) and available in PATH
- [Neotest](https://github.com/nvim-neotest/neotest#installation)
- [Treesitter](https://github.com/nvim-treesitter/nvim-treesitter#installation) with Odin support

## 📦 Setup

Install & configure using the package manager of your choice.
Example using lazy.nvim:

```lua
return {
    "nvim-neotest/neotest",
    dependencies = {
        "Su3h7aM/neotest-odin", -- Installation
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "nvim-neotest/nvim-nio",
    },
    opts = {
        adapters = {
            -- Registration
            ["neotest-odin"] = {}
        }
    }
}
```

## ⭐ Features

- Can run tests in individual `.odin` files

## 📄 Logs

Enabling logging in `neotest` automatically enables logging in `neotest-odin` as well:

```lua
require("neotest").setup({
    log_level = vim.log.levels.DEBUG,
    -- ...
})
```
