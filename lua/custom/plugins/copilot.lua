vim.pack.add({
	-- Core AI Engine
	"https://github.com/zbirenbaum/copilot.lua",

	-- Completion Engine & Compatibility Bridge
	'https://github.com/copilotlsp-nvim/copilot-lsp',
	"https://github.com/giuxtaposition/blink-cmp-copilot"
})

require("copilot").setup({
	suggestion = { enabled = false },
	panel = { enabled = false },
})
