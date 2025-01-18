-- log
--
-- logging

local log = {}

log.TAGS = {
    warn = ("[WARN]"):yellow(),
    info = ("[INFO]"):cyan(),
    error = ("[ERROR]"):red(),
}
log.DIVIDER = ("-"):rep(80)

function log.format_tag(tag)
    return ("[%s]"):format(tag:upper())
end

function log.tagged(tag, ...)
    local fixed_tag = log.TAGS[tag]
    if fixed_tag == false then return end
    print(fixed_tag or log.format_tag(tag), ...)
end

function log.multiline(...)
    print(...)
end

function log.divider()
    print(log.DIVIDER)
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

function log.error(...)
    log.tagged('error', ...)
end

return log