-- Player Homes: game-independent Luanti mod
-- Uses only standard Luanti Lua APIs.
-- License: MIT

local modname = minetest.get_current_modname()
local storage = minetest.get_mod_storage()

local homes_by_player = {}
local teleport_ready_at = {}

local function setting_number(name, default, min_value)
    local value = minetest.settings:get(name)
    if value == nil or value == "" then
        return default
    end
    local n = tonumber(value)
    if not n then
        minetest.log("warning", "[playerhomes] Invalid number for " .. name .. "; using default " .. default)
        return default
    end
    if min_value and n < min_value then
        return min_value
    end
    return n
end

local function max_homes()
    return math.floor(setting_number("playerhomes_max_homes", 5, 1))
end

local function cooldown_seconds()
    return setting_number("playerhomes_teleport_cooldown", 0, 0)
end

local function get_homes(player_name)
    if homes_by_player[player_name] then
        return homes_by_player[player_name]
    end

    local raw = storage:get_string("homes:" .. player_name)
    local homes = {}
    if raw ~= "" then
        local ok, decoded = pcall(minetest.deserialize, raw)
        if ok and type(decoded) == "table" then
            for name, pos in pairs(decoded) do
                if type(name) == "string" and type(pos) == "table"
                    and tonumber(pos.x) and tonumber(pos.y) and tonumber(pos.z) then
                    homes[name] = { x = tonumber(pos.x), y = tonumber(pos.y), z = tonumber(pos.z) }
                end
            end
        end
    end

    homes_by_player[player_name] = homes
    return homes
end

local function save_homes(player_name)
    storage:set_string("homes:" .. player_name, minetest.serialize(get_homes(player_name)))
end

local function sorted_home_names(homes)
    local names = {}
    for name in pairs(homes) do
        names[#names + 1] = name
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

local function valid_home_name(name)
    if type(name) ~= "string" then return false end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or #name > 32 then return false end
    if name:find("[,%[%];]") then return false end
    if name:find("[%c]") then return false end
    return true, name
end

local function player_message(player, message)
    minetest.chat_send_player(player:get_player_name(), message)
end

local function set_home(player, requested_name)
    local name_ok, name = valid_home_name(requested_name)
    if not name_ok then
        player_message(player, "Usage: /sethome <name> (1-32 characters; avoid commas, brackets, and semicolons).")
        return
    end

    local player_name = player:get_player_name()
    local homes = get_homes(player_name)
    if not homes[name] then
        local count = 0
        for _ in pairs(homes) do count = count + 1 end
        if count >= max_homes() then
            player_message(player, "You have reached your home limit (" .. max_homes() .. ").")
            return
        end
    end

    homes[name] = vector.round(player:get_pos())
    save_homes(player_name)
    player_message(player, "Home '" .. name .. "' saved.")
end

local function teleport_home(player, requested_name)
    local player_name = player:get_player_name()
    local homes = get_homes(player_name)
    local name = requested_name

    if not name or name == "" then
        local names = sorted_home_names(homes)
        if #names == 0 then
            player_message(player, "You have no saved homes. Use /sethome <name> first.")
            return
        end
        if #names == 1 then
            name = names[1]
        else
            player_message(player, "Choose a home with /home, or use /home <name>.")
            return
        end
    end

    local pos = homes[name]
    if not pos then
        player_message(player, "No home named '" .. name .. "'. Use /homes to see your homes.")
        return
    end

    local cooldown = cooldown_seconds()
    local now = minetest.get_gametime()
    local ready_at = teleport_ready_at[player_name] or 0
    if cooldown > 0 and now < ready_at then
        player_message(player, "Please wait " .. math.ceil(ready_at - now) .. " more second(s) before teleporting again.")
        return
    end

    -- Raise the player slightly to reduce the chance of spawning inside the floor.
    local destination = { x = pos.x, y = pos.y + 1, z = pos.z }
    player:set_pos(destination)
    if cooldown > 0 then
        teleport_ready_at[player_name] = now + cooldown
    end
    player_message(player, "Teleported to home '" .. name .. "'.")
end

local function delete_home(player, requested_name)
    local name_ok, name = valid_home_name(requested_name)
    if not name_ok then
        player_message(player, "Usage: /delhome <name>")
        return
    end
    local player_name = player:get_player_name()
    local homes = get_homes(player_name)
    if not homes[name] then
        player_message(player, "No home named '" .. name .. "'.")
        return
    end
    homes[name] = nil
    save_homes(player_name)
    player_message(player, "Home '" .. name .. "' deleted.")
end

local FORMNAME = "playerhomes:menu"

local function show_menu(player, message)
    local player_name = player:get_player_name()
    local homes = get_homes(player_name)
    local names = sorted_home_names(homes)
    local formspec = {
        "formspec_version[4]",
        "size[10,8]",
        "label[0.5,0.35;Player Homes]",
        "label[0.5,0.8;Homes: " .. #names .. "/" .. max_homes() .. " | Teleport cooldown: " .. cooldown_seconds() .. "s]",
        "textlist[0.5,1.2;4.2,4.7;home_list;"
    }
    local escaped_names = {}
    for _, name in ipairs(names) do
        escaped_names[#escaped_names + 1] = minetest.formspec_escape(name)
    end
    formspec[#formspec + 1] = table.concat(escaped_names, ",")
    formspec[#formspec + 1] = ";1]"
    formspec[#formspec + 1] = "button[5,1.5;4.2,0.8;teleport;Teleport to selected]"
    formspec[#formspec + 1] = "button[5,2.5;4.2,0.8;delete;Delete selected]"
    formspec[#formspec + 1] = "field[5.2,4;4,0.8;new_name;New home name;]"
    formspec[#formspec + 1] = "button[5,4.7;4.2,0.8;save;Save current position]"
    formspec[#formspec + 1] = "button[0.5,6.3;2,0.8;refresh;Refresh]"
    formspec[#formspec + 1] = "label[0.5,7.15;" .. minetest.formspec_escape(message or "") .. "]"
    formspec[#formspec + 1] = "label[5,6.0;Commands: /sethome, /home, /homes, /delhome]"
    minetest.show_formspec(player_name, FORMNAME, table.concat(formspec))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORMNAME or not player then return false end
    if fields.quit then return true end

    local player_name = player:get_player_name()
    local homes = get_homes(player_name)
    local names = sorted_home_names(homes)
    local selected = nil

    if fields.home_list then
        local event = minetest.explode_textlist_event(fields.home_list)
        if event and event.index and names[event.index] then
            selected = names[event.index]
            -- Persist selection only for this form submission.
            player:get_meta():set_string("playerhomes_selected", selected)
        end
    end

    selected = selected or player:get_meta():get_string("playerhomes_selected")
    if fields.teleport then
        if selected ~= "" then teleport_home(player, selected) end
        show_menu(player)
    elseif fields.delete then
        if selected ~= "" then
            delete_home(player, selected)
            player:get_meta():set_string("playerhomes_selected", "")
        end
        show_menu(player)
    elseif fields.save then
        set_home(player, fields.new_name or "")
        show_menu(player)
    elseif fields.refresh then
        show_menu(player)
    end
    return true
end)

minetest.register_chatcommand("sethome", {
    params = "<name>",
    description = "Save your current position as a named home",
    privs = {},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "You must be online to set a home." end
        if not param or param:match("^%s*$") then return false, "Usage: /sethome <name>" end
        set_home(player, param)
        return true, ""
    end,
})

minetest.register_chatcommand("home", {
    params = "[name]",
    description = "Open the homes menu or teleport to a named home",
    privs = {},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "You must be online to use homes." end
        if param and param:match("%S") then
            teleport_home(player, param:match("^%s*(.-)%s*$"))
        else
            show_menu(player)
        end
        return true, ""
    end,
})

minetest.register_chatcommand("homes", {
    description = "List your saved homes",
    privs = {},
    func = function(name)
        local homes = get_homes(name)
        local names = sorted_home_names(homes)
        if #names == 0 then return true, "You have no saved homes." end
        return true, "Your homes (" .. #names .. "/" .. max_homes() .. "): " .. table.concat(names, ", ")
    end,
})

minetest.register_chatcommand("delhome", {
    params = "<name>",
    description = "Delete one of your saved homes",
    privs = {},
    func = function(name, param)
        if not param or param:match("^%s*$") then return false, "Usage: /delhome <name>" end
        local player = minetest.get_player_by_name(name)
        if not player then return false, "You must be online to delete a home." end
        delete_home(player, param:match("^%s*(.-)%s*$"))
        return true, ""
    end,
})

minetest.register_chatcommand("homehelp", {
    description = "Show Player Homes help",
    privs = {},
    func = function()
        return true, "Player Homes: /sethome <name>, /home [name], /homes, /delhome <name>. /home opens the menu."
    end,
})

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    teleport_ready_at[name] = nil
end)

minetest.log("action", "[playerhomes] Loaded game-independent Player Homes mod.")
