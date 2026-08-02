-- Bag Stock Preview
--
-- QoL: while browsing the BUY list at a Pokemart, shows how many of the
-- highlighted item are already sitting in the player's Bag, replacing the
-- clerk's "Take your time." line in the bottom text box.
--
-- Earlier drafts drew this as a manual overlay via render.hud, which needed
-- letterbox/scale geometry that turned out to be unreliable on this build
-- (the hook's viewport argument came through nil). This version sidesteps
-- all of that: ShopMenu.buy() (src/ui/ShopMenu.lua) already puts its
-- messages -- the greeting, "Not enough money.", the purchase confirm --
-- in one plain mutable field, list.footer, and ListMenu:draw already knows
-- how to box and paginate whatever string is in there. So instead of
-- drawing anything ourselves, this just writes to that same field, and the
-- engine's own rendering does the rest, pixel-identical to every other
-- shop message.
--
-- Runs on input.step (src/core/Game.lua), which fires once per frame
-- *before* that frame's draw pass, so the footer is already up to date by
-- the time ListMenu:draw reads it -- no one-frame lag the way writing it
-- from a post-draw hook like render.hud would have.
--
-- Never fights the shop's own messages: the moment the player presses A,
-- ShopMenu overwrites list.footer itself (an insufficient-funds notice, the
-- price confirm, "Thank you!"), and this mod backs off and leaves it alone
-- as long as the footer isn't still either the original greeting or our
-- own last-written text. It only starts overwriting again once ShopMenu
-- resets footer back to the greeting on its own (cancelling out of the
-- quantity box, declining the price confirm, etc).

return function(mod)
  mod.hooks:wrap("input.step", function(next, game, dt)
    next(game, dt)

    local top = game.stack and game.stack:top()
    -- ShopMenu.buy() titles its ListMenu "BUY" (src/ui/ShopMenu.lua); the
    -- SELL list has a different title, so this never touches it.
    if not (top and top.title == "BUY" and top.items) then return end

    -- First frame we see this particular list instance: remember whatever
    -- it opened with, which is always the plain greeting at that point.
    if top._bagPreviewGreet == nil then
      top._bagPreviewGreet = top.footer
    end

    local isGreeting = top.footer == top._bagPreviewGreet
    local isOurs = top.footer ~= nil and top.footer == top._bagPreviewLastSet
    if not (isGreeting or isOurs) then return end

    local item = top.items[top.index]
    if not item or not item.value then return end

    local owned = (game.save and game.save.inventory
      and game.save.inventory[item.value]) or 0
    local text = ("In Bag: %d"):format(owned)

    top.footer = text
    top._bagPreviewLastSet = text
  end)
end
