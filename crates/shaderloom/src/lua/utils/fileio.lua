-- utils.fileio
--
-- utilities for dealing with files

local fileio = {}

function fileio.join_path(...)
    -- assume we can use "/" as a path separator!
    return table.concat({...}, "/")
end

function fileio.try_read(filename)
    local f = io.open(filename)
    if not f then
        print("Failed read.")
        return nil
    end
    local data = assert(f:read("a"))
    f:close()
    return data
end

function fileio.read(filename)
    return assert(
        fileio.try_read(filename), 
        ("Failed to read '%s'"):format(filename)
    )
end

function fileio.write(filename, data)
    local dest = assert(io.open(filename, "wb"), "Failed to open output file '" .. filename .. "'!")
    dest:write(data)
    dest:close()
end

function fileio.try_read_multidir(dirs, filename)
    for _, dir in ipairs(dirs) do
        local data = fileio.try_read(fileio.join_path(dir, filename))
        if data then return data end
    end
    return nil
end

function fileio.create_resolver(include_dirs)
    return function(name)
        local data = fileio.try_read_multidir(include_dirs, name)
        if not data then
            error(("Missing include: '%s'"):format(name))
        end
        return data
    end
end

return fileio