local patched = false

local M = {}

local api = vim.api
local fn = vim.fn
local utils
local view
local config
local icon_state

local severity_levels = { Error = 1, Warning = 2, Information = 3, Hint = 4 }

local sign_names = {
	{ "NvimTreeSignError", "NvimTreeLspDiagnosticsError" },
	{ "NvimTreeSignWarning", "NvimTreeLspDiagnosticsWarning" },
	{ "NvimTreeSignInformation", "NvimTreeLspDiagnosticsInformation" },
	{ "NvimTreeSignHint", "NvimTreeLspDiagnosticsHint" },
}

local signs = {}

local function add_sign(linenr, severity)
	local buf = view.View.bufnr
	if not api.nvim_buf_is_valid(buf) or not api.nvim_buf_is_loaded(buf) then
		return
	end
	local sign_name = sign_names[severity][1]
	table.insert(signs, fn.sign_place(1, "NvimTreeDiagnosticSigns", sign_name, buf, { lnum = linenr + 1 }))
end

function M.update()
	if vim.g.coc_service_initialized ~= 1 then
		return
	end

	local buffer_severity = {}
	local diagnostics = {}

	for _, diagnostic in ipairs(fn.CocAction("diagnosticList")) do
		local bufname = diagnostic.file
		local severity = severity_levels[diagnostic.severity]

		local severities = diagnostics[bufname] or {}
		table.insert(severities, severity)
		diagnostics[bufname] = severities
	end

	for bufname, severties in pairs(diagnostics) do
		if not buffer_severity[bufname] then
			local severity = math.min(unpack(severties))
			buffer_severity[bufname] = severity
		end
	end

	local nodes = require("nvim-tree.lib").Tree.entries
	if #signs > 0 then
		fn.sign_unplacelist(vim.tbl_map(function(sign)
			return {
				buffer = view.View.bufnr,
				group = "NvimTreeDiagnosticSigns",
				id = sign,
			}
		end, signs))
		signs = {}
	end
	for bufname, severity in pairs(buffer_severity) do
		if 0 < severity and severity < 5 then
			local node, line = utils.find_node(nodes, function(node)
				return node.absolute_path == bufname
			end)
			if node then
				add_sign(line, severity)
			end
		end
	end
end

local function patch()
	patched = true

	utils = require("nvim-tree.utils")
	view = require("nvim-tree.view")
	config = require("nvim-tree.config")
	icon_state = config.get_icon_state()

	fn.sign_define(sign_names[1][1], { text = icon_state.icons.lsp.error, texthl = sign_names[1][2] })
	fn.sign_define(sign_names[2][1], { text = icon_state.icons.lsp.warning, texthl = sign_names[2][2] })
	fn.sign_define(sign_names[3][1], { text = icon_state.icons.lsp.info, texthl = sign_names[3][2] })
	fn.sign_define(sign_names[4][1], { text = icon_state.icons.lsp.hint, texthl = sign_names[4][2] })
end

package.loaded["nvim-tree.diagnostics"] = setmetatable({}, {
	__index = function(_, k)
		if not patched then
			patch()
		end
		return M[k]
	end,
})
