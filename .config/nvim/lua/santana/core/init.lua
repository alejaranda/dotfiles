local M = {}

local function notify_error(mod, err)
  vim.notify(('[core] failed to load %s\n%s'):format(mod, err), vim.log.levels.ERROR)
end

function M.load(modules, prefix)
  prefix = prefix or ''

  for _, name in ipairs(modules) do
    local mod = prefix .. name
    local ok, err = pcall(require, mod)
    if not ok then
      notify_error(mod, err)
    end
  end
end

M.load({
  'options',
  'keymaps',
  'autocmds',
}, 'santana.core.')

return M
