local icons = {}
local local_path = debug.getinfo(1, "S").source:match("^@(.-)[^/]+$")

icons.cpu = local_path .. "cpu.svg" 
icons.ram = local_path .. "ram.svg"
icons.audio = local_path .. "audio.svg"
icons.browser = local_path .. "browser.svg"
icons.terminal = local_path .. "terminal.svg"
icons.file_manager = local_path .. "file_manager.svg"
icons.setup = local_path .. "setup.svg"

icons.lock = local_path .. "lock.svg"
icons.sleep = local_path .. "sleep.svg"
icons.poweroff = local_path .. "poweroff.svg"


return icons