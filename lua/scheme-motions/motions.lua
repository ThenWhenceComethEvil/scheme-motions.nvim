local M = {}

local ts = require("nvim-treesitter.ts_utils")
local pred = require("scheme-motions.predicates")
local Cursor = require("scheme-motions.cursor")

---@param node TSNode
---@return TSNode?
--
-- Depth-first search, returning in order:
--    1. First child (if found)
--    2. Next sibling (if found)
-- Recurse up the tree until hitting the document root.
local function next_named(node)
   if node:named_child_count() > 0 then
      return node:named_child(0)
   end

   repeat
      if node:next_named_sibling() then
         return node:next_named_sibling()
      end
      node = node:parent()
   until not node:parent()
end


---@param node TSNode
---#return TSNode?
--
-- Depth first backwards search, returning in order:
--    1. Previous sibling's deepest leaf node
--    2. Node's paent
local function prev_named(node)
   if not node:prev_named_sibling() then
      return node:parent()
   end

   node = node:prev_named_sibling()
   while node:named_child_count() > 0 do
      node = node:named_child(node:named_child_count() - 1) --[[@as TSNode]]
   end

   return node
end


---@param direction "next" | "prev"
---@param predicate fun(node: TSNode, cursor: Cursor): boolean
--
-- Sets cursor location to the next TSNode matching a predicate. Repeaatedly
-- calls `next_node()` or `prev_node()` until `predicate(node, cursor)` is
-- true.
local function move_to(direction, predicate)
   local cursor = Cursor:get()
   local node   = ts.get_node_at_cursor()

   local fn
   if direction == "prev" then
      fn = prev_named
   elseif direction == "next" then
      fn = next_named
   else
      error("Expecting non-nil TSNode.", 2)
   end

   local MAX_RECR = 1000
   repeat
      node = fn(node) --[[@as TSNode]]
      MAX_RECR = MAX_RECR - 1
   until
      predicate(node, cursor) or
      MAX_RECR < 0

   if MAX_RECR < 0 then
      error("Maximum recursion depth hit.")
   end

   if node then
      cursor:set(node, "start")
   end
end


--- Unvances cursor (skipping comments) to the start of the previous form.
function M.prev_form_start()
   move_to("prev", function(node, cursor)
      return not node
         or  pred.is_form(node)
         and cursor:is_ahead(node, "start")
   end)
end


--- Advances cursor (skipping comments) to the start of the next form.
function M.next_form_start()
   move_to("next", function(node, cursor)
      return not node
         or  pred.is_form(node)
         and cursor:is_behind(node, "start")
   end)
end


return M
