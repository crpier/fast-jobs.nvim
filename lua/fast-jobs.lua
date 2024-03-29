local Path = require("plenary.path")
local Job = require("plenary.job")

local popup = require("plenary.popup")
local config_file = vim.fn.stdpath("data") .. "/fast_jobs.json"

M = {}

local function mysplit(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

local Menu_buf_no
local Current_config

local function get_project_cmds()
	local res = Current_config["projects"][vim.loop.cwd()]
	if res == nil then
		res = {}
		Current_config["projects"][vim.loop.cwd()] = res
	end
	return res
end

M.initial_config = function()
	local config = { projects= {} }
	Current_config = config
	Path:new(config_file):write(vim.fn.json_encode(Current_config), "w")
end

M.save_commands = function()
	local lines = vim.api.nvim_buf_get_lines(Menu_buf_no, 0, -1, true)
	local res = Current_config["projects"][vim.loop.cwd()]
	if res == nil then
		Current_config["projects"][vim.loop.cwd()] = {}
	end
	Current_config["projects"][vim.loop.cwd()] = lines
	Path:new(config_file):write(vim.fn.json_encode(Current_config), "w")
end

M.setup = function()
	local ok, file = pcall(function()
		return Path:new(config_file):read()
	end)
	if not ok then
		M.initial_config()
		return
	end
	local config = vim.fn.json_decode(file)
	Current_config = config
end

M.run_cmd_async = function(line_no)
	local line = get_project_cmds()[line_no]
	local words = mysplit(line, " ")
	local command = words[1]
	local args = { unpack(words, 2) }
	print(vim.inspect(command))
	print(vim.inspect(args))
	Job:new({
		command = command,
		args = args,
		cwd = vim.loop.cwd(),
		-- env = { ["a"] = "b" },
		on_start = function(_)
			print("Running " .. command .. " with args " .. vim.inspect(args))
		end,
		on_exit = function(j, return_val)
			print(return_val)
			print(vim.inspect(j:result()))
		end,
	}):start() -- or start()
end

M.create_window = function()
	local width = 60
	local height = 20
	local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

	local contents = get_project_cmds()
	local bufnr = vim.api.nvim_create_buf(false, false)
	Menu_buf_no = bufnr
	local win_id, _ = popup.create(Menu_buf_no, {
		title = "Jobs",
		highlight = "HarpoonWindow",
		line = math.floor(((vim.o.lines - height) / 2) - 1),
		col = math.floor((vim.o.columns - width) / 2),
		minwidth = width,
		minheight = height,
		borderchars = borderchars,
	})

	vim.api.nvim_win_set_option(win_id, "number", true)
	vim.api.nvim_buf_set_option(Menu_buf_no, "buftype", "acwrite")
	vim.api.nvim_buf_set_name(Menu_buf_no, "jobs menu")
	vim.api.nvim_buf_set_lines(Menu_buf_no, 0, #contents, false, contents)
	vim.api.nvim_buf_set_option(Menu_buf_no, "bufhidden", "delete")
	vim.api.nvim_create_autocmd({ "BufWriteCmd" }, { buffer = Menu_buf_no, callback = M.save_commands })
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = Menu_buf_no,
		callback = M.save_commands,
	})
	vim.api.nvim_create_autocmd({ "BufModifiedSet" }, { buffer = Menu_buf_no, command = "set nomodified" })
	vim.api.nvim_buf_set_keymap(Menu_buf_no, "n", "q", "ZZ", { silent = true })
end

M.setup()

return M
