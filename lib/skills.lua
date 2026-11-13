local file = require("file")
local log = require("log")

local M = {}

-- parse_name(text) -> the "name:" value of a SKILL.md front matter, or nil.
function M.parse_name(text)
    local front = text:match("^%-%-%-\r?\n(.-)\r?\n%-%-%-")
    if front == nil then
        return nil
    end
    for line in front:gmatch("[^\r\n]+") do
        local value = line:match("^name:%s*(.-)%s*$")
        if value ~= nil then
            value = (value:gsub("^[\"'](.*)[\"']$", "%1"))
            if value ~= "" then
                return value
            end
            return nil
        end
    end
    return nil
end

-- discover(root) -> every skill under root as { name, dir }, where dir holds SKILL.md.
function M.discover(root)
    local found = {}
    for _, path in ipairs(file.glob(file.join_path(root, "**", "SKILL.md"))) do
        local name = M.parse_name(file.read(path))
        if name ~= nil and not name:match("^[%w][%w._-]*$") then
            log.warn("mise-skill: ignored " .. path .. ": invalid skill name " .. name)
        elseif name ~= nil then
            table.insert(found, { name = name, dir = path:sub(1, #path - #"/SKILL.md") })
        end
    end
    if #found == 0 then
        error("mise-skill: no SKILL.md with a name was found in " .. root)
    end
    return found
end

-- same_contents(matches) -> true when every match has an identical SKILL.md, as when a
-- repository symlinks to its own skills.
local function same_contents(matches)
    local first = file.read(file.join_path(matches[1].dir, "SKILL.md"))
    for i = 2, #matches do
        if file.read(file.join_path(matches[i].dir, "SKILL.md")) ~= first then
            return false
        end
    end
    return true
end

-- select(found, wanted) -> the skills to link. wanted is the skills tool option: nil means
-- all of them, a string means one. Unknown names fail. Names shared by skills whose SKILL.md
-- contents differ fail; identical copies resolve to the first.
function M.select(found, wanted)
    local by_name, order = {}, {}
    for _, skill in ipairs(found) do
        if by_name[skill.name] == nil then
            by_name[skill.name] = {}
            table.insert(order, skill.name)
        end
        table.insert(by_name[skill.name], skill)
    end
    if type(wanted) == "string" then
        wanted = { wanted }
    end
    local names = wanted or order
    local selected = {}
    for _, name in ipairs(names) do
        local matches = by_name[name]
        if matches == nil then
            error("mise-skill: no skill named " .. name .. " (found: " .. table.concat(order, ", ") .. ")")
        elseif #matches > 1 then
            local dirs = {}
            for _, skill in ipairs(matches) do
                table.insert(dirs, skill.dir)
            end
            if same_contents(matches) then
                log.debug(
                    "mise-skill: "
                        .. name
                        .. " has identical copies; using "
                        .. dirs[1]
                        .. ", skipping "
                        .. table.concat(dirs, ", ", 2)
                )
            else
                error("mise-skill: more than one skill is named " .. name .. ": " .. table.concat(dirs, ", "))
            end
        end
        table.insert(selected, matches[1])
    end
    return selected
end

return M
