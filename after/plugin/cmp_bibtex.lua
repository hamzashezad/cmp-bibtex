local ok, bibtex = pcall(require, "cmp_bibtex")
if not ok then
	vim.notify("cmp-bibtex failed to load")
	return
end

local cmp_ok, cmp = pcall(require, "cmp")
if not cmp_ok then
	vim.notify("nvim-cmp failed to load")
	return
end

cmp.register_source("bibtex", bibtex.new())
