vim.pack.add({
	-- Core AI Engine
	"https://github.com/zbirenbaum/copilot.lua",

	-- Completion Engine & Compatibility Bridge
	'https://github.com/copilotlsp-nvim/copilot-lsp',
	"https://github.com/giuxtaposition/blink-cmp-copilot"
})

require("copilot").setup({
	-- Disable built-in UI modules so they do not conflict with blink.cmp
	suggestion = {
		enabled = false,
		auto_trigger = true,
		keymap = {
			accept = false, -- handled by nvim-cmp / blink.cmp
			next = '<M-]>',
			prev = '<M-[>',
		},
	},
	panel = { enabled = false },
})
