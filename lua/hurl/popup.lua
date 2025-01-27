local Popup = require('nui.popup')
local event = require('nui.utils.autocmd').event
local Layout = require('nui.layout')

local utils = require('hurl.utils')

local M = {}
local popups = {
  bottom = Popup({
    border = 'single',
    enter = true,
    buf_options = { filetype = 'json' },
  }),
  top = Popup({
    border = { style = 'rounded' },
    buf_options = { filetype = 'bash' },
  }),
}

local layout = Layout(
  {
    relative = 'editor',
    position = _HURL_GLOBAL_CONFIG.popup_position,
    size = _HURL_GLOBAL_CONFIG.popup_size,
  },
  Layout.Box({
    Layout.Box(popups.top, { size = {
      height = '20%',
    } }),
    Layout.Box(popups.bottom, { grow = 1 }),
  }, { dir = 'col' })
)

-- Show content in a popup
---@param data table
---   - body string
---   - headers table
---@param type 'json' | 'html' | 'text'
M.show = function(data, type)
  layout:mount()

  -- Close popup when buffer is closed
  if _HURL_GLOBAL_CONFIG.auto_close then
    for _, popup in pairs(popups) do
      popup:on(event.BufLeave, function()
        vim.schedule(function()
          local current_buffer = vim.api.nvim_get_current_buf()
          for _, p in pairs(popups) do
            if p.bufnr == current_buffer then
              return
            end
          end
          layout:unmount()
        end)
      end)
    end
  end

  local function quit()
    vim.cmd('q')
    layout:unmount()
  end

  -- Map q to quit
  popups.top:map('n', 'q', function()
    quit()
  end)
  popups.bottom:map('n', 'q', function()
    quit()
  end)

  -- Map <Ctr-n> to next popup
  popups.top:map('n', '<C-n>', function()
    vim.api.nvim_set_current_win(popups.bottom.winid)
  end)
  popups.bottom:map('n', '<C-n>', function()
    vim.api.nvim_set_current_win(popups.top.winid)
  end)
  -- Map <Ctr-p> to previous popup
  popups.top:map('n', '<C-p>', function()
    vim.api.nvim_set_current_win(popups.bottom.winid)
  end)
  popups.bottom:map('n', '<C-p>', function()
    vim.api.nvim_set_current_win(popups.top.winid)
  end)

  -- Add headers to the top
  local headers_table = utils.render_header_table(data.headers)
  -- Hide header block if empty headers
  if headers_table.line == 0 then
    vim.api.nvim_win_close(popups.top.winid, true)
  else
    if headers_table.line > 0 then
      vim.api.nvim_buf_set_lines(popups.top.bufnr, 0, 1, false, headers_table.headers)
    end
  end

  local content = utils.format(data.body, type)
  if not content then
    utils.log_info('No content')
    return
  end

  -- Add content to the bottom
  vim.api.nvim_buf_set_lines(popups.bottom.bufnr, 0, -1, false, content)

  -- Set content to highlight, refer https://github.com/MunifTanjim/nui.nvim/issues/76#issuecomment-1001358770
  vim.api.nvim_buf_set_option(popups.bottom.bufnr, 'filetype', type)
end

M.clear = function()
  -- Check if popup is open
  if not popups.bottom.winid then
    return
  end
  -- Clear the buffer and adding `Processing...` message
  vim.api.nvim_buf_set_lines(popups.top.bufnr, 0, -1, false, { 'Processing...' })
  vim.api.nvim_buf_set_lines(popups.bottom.bufnr, 0, -1, false, { 'Processing...' })
end

return M
