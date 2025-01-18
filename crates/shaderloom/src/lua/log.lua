-- log
--
-- logging

local log = {}

log.TAGS = {
    warn = ("[WARN]"):yellow(),
    info = ("[INFO]"):cyan(),
}

function log.format_tag(tag)
    return ("[%s]"):format(tag:upper())
end

function log.tagged(tag, ...)
    local fixed_tag = log.TAGS[tag]
    if fixed_tag == false then return end
    print(fixed_tag or log.format_tag(tag), ...)
end

function log.info(...)
    log.tagged('info', ...)
end

function log.warn(...)
    log.tagged('warn', ...)
end

function log.debug(...)
    log.tagged('debug', ...)
end

return log