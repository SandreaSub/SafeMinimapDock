A small minimap button organizer for WoW 1.12.

SafeMinimapDock lets you manually collect minimap addon buttons into a simple dock without automatically scanning or grabbing every minimap frame.

Buttons are arranged in rows of 5 icons.

## Features

- 5 minimap buttons per row
- Compact spacing
- Icons automatically return to their saved dock after login
- Hover the dock area to reveal the icons
- Short fade-in/fade-out
- Dock background stays hidden during normal use
- No automatic minimap scanning
- Designed for WoW 1.12 / Lua 5.0

## Commands

## /mdock add
Hover your mouse over a minimap button and type : /mdock add
The button will be added to the dock.
Repeat this for each minimap button you want to add.

## /mdock remove
Hover over a button already in the dock and type : /mdock remove
The button will be removed from the dock and its original positioning behavior restored.

## /mdock show
Shows the dock background and the MINIMAP handle and keeps the icons visible.
Use this when you want to see or move the dock.

## /mdock hide
Returns the dock to its normal hidden mode.
The frame and MINIMAP handle disappear. The icons will only appear when you hover over the dock area and will fade out again when you move away.

## /mdock list
Lists all minimap buttons currently registered with SafeMinimapDock.

## /mdock reset
Resets the dock position.

## Moving the dock
Use /mdock show
Then drag the MINIMAP handle to wherever you want the icons.
Once you're finished, use : /mdock hide
The dock becomes invisible again, while hovering over its location reveals your minimap buttons.

## Notes
SafeMinimapDock intentionally uses a simple approach.
It does not automatically scan the minimap for buttons. You choose which buttons are added with `/mdock add`.
Registered buttons are remembered between sessions and are restored to the dock when you log back in.
