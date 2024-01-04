local get_key = function(line)
	return line:match("%@.*%{(.*),$")
end

local get_specific_key = function(line, key)
	return vim.trim(line):match(
		key .. "%s*=%s*(.*),?$"
	)
end

local parse_authors = function(line)
	if line == nil or line == "" then
		return {}
	end

	local authors = vim.split(line, " and ")
	return authors
end

local clean = function(title)
	local cleaned = string.gsub(title, "[{}\"]", "")
	if vim.endswith(cleaned, ",") then
		cleaned = cleaned:sub(1, -2)
	end
	return cleaned
end

local get_citations = function(lines)
	local citations = {}

	local keys = {}
	local titles = {}
	local authors = {}
	local years = {}

	for _, line in pairs(lines) do
		local key = get_key(line)
		local title = get_specific_key(line, "title")
		local author = get_specific_key(line, "author")
		local year = get_specific_key(line, "year")

		if key ~= nil then
			table.insert(keys, key)
		end

		if title ~= nil then
			local cleaned_title, _ = clean(title)
			table.insert(titles, cleaned_title)
		end

		if author ~= nil then
			local cleaned_author, _ = clean(author)
			table.insert(authors, cleaned_author)
		end

		if year ~= nil then
			local cleaned_year, _ = clean(year)
			table.insert(years, cleaned_year)
		end
	end

	for i, key in pairs(keys) do
		local citation = {
			key = key,
			title = titles[i],
			authors = parse_authors(authors[i]),
			year = years[i],
		}

		table.insert(citations, citation)
	end

	return citations
end

local source = {}

local default_config = {
	refs_file = "refs.bib",
	extended = true,
}

local get_md_list = function(tbl, numbered)
	if tbl == nil then
		return ""
	end

	if numbered == nil then
		numbered = false
	end

	local str = ""
	for k, v in pairs(tbl) do
		if numbered then
			str = string.format("%s%s. %s\n", str, k, v)
		end

		str = string.format("%s- %s\n", str, v)
	end

	return str
end

local get_item_from_citation = function(citation, extended)
	if extended == nil then
		extended = false
	end

	local documentation = citation.title

	if extended then
		documentation = string.format("@_%s_: **%s**\n", citation.key, citation.title)

		if citation.year ~= nil then
			documentation = documentation .. string.format("\n**Year**: %s\n", citation.year)
		end

		if #citation.authors > 0 then
			documentation = documentation .. string.format("**Author(s)**:\n %s\n", get_md_list(citation.authors))
		end
	end

	return {
		label = "@" .. citation.key,
		kind = 1,
		documentation = {
			kind = "markdown",
			value = documentation,
		}
	}
end

source.get_trigger_characters = function()
	return { "@" }
end

source.new = function()
	return setmetatable({}, { __index = source })
end

source.complete = function(self, params, callback)
	local input = string.sub(params.context.cursor_before_line, params.offset - 1)
	local prefix = string.sub(params.context.cursor_before_line, 1, params.offset - 1)

	if vim.startswith(input, "@") and (prefix == "@" or vim.endswith(prefix, " @")) then
		local items = {}

		local refs_file = vim.fn.expand(default_config.refs_file)
		if vim.fn.filereadable(refs_file) == 0 then
			return
		end

		local lines = vim.fn.readfile(refs_file)
		local citations = get_citations(lines)

		for _, citation in pairs(citations) do
			table.insert(
				items,
				vim.list_extend(
					get_item_from_citation(citation, true),
					{
						textEdit = {
							newText = "@" .. citation.key,
							range = {
								start = {
									line = params.context.cursor.row - 1,
									character = params.context.cursor.col - 1 - #input,
								},
								["end"] = {
									line = params.context.cursor.row - 1,
									character = params.context.cursor.col - 1,
								},
							},
						},
					}
				)
			)
		end

		callback({ items = items, isIncomplete = true })
	else
		callback({ isIncomplete = true })
	end
end

return source
