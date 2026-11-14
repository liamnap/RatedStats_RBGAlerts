# RatedStats - RBG Alerts

A lightweight, standalone World of Warcraft Retail addon that helps you keep track of advertised Rated Battleground groups.

RBG Alerts displays a movable group counter and an expandable list of RBG listings received through Blizzard's Premade Group Finder. Optional chat and sound alerts help you notice newly observed groups.

## Features

- Movable widget with an RBG group count and an expandable list of up to eight groups.
- Group names, leaders, member counts and listing ages.
- Optional chat notifications for newly observed groups.
- Optional sound alerts for newly observed listings aged two minutes or less.
- Controls to hide the widget, hide the group list, lock its position or reset its position.
- Bundled Rated Stats logo: the main RatedStats addon is not required.
- Optional achievement badges and tooltips when RatedStats_Achiev is loaded and has information about a group leader.

## How it works

Open Blizzard's Group Finder and navigate to **Player vs. Player > Premade Groups > Rated Battlegrounds**, then search using Blizzard's controls. RBG Alerts updates as your client receives listing events.

This is a premade-listing watcher, not a matchmaking queue tracker. It cannot tell you which teams are queued, how long a queue will take, or show every RBG group across the region. It does not run automatic searches or refresh the Group Finder for you.

Groups are removed when the client reports them delisted, or when a complete readable results update excludes them while the RBG search panel is visible. Listings that have not been observed for over 20 minutes expire during the 30-second cleanup cycle. A missing removal update can therefore leave an old group visible temporarily.

When Blizzard restricts access to listing data, unreadable results are skipped. Incomplete results do not trigger removal of other cached groups, although normal expiry still applies. Reloading the UI clears the observed list; preferences and widget position are saved.

## Installation

Install through CurseForge when a release is available, or install manually:

1. Place the `RatedStats_RBGAlerts` folder inside `World of Warcraft/_retail_/Interface/AddOns/`.
2. Ensure the folder directly contains `RatedStats_RBGAlerts.toc`, `RBGAlerts.lua` and `RatedStats.tga`. Avoid an extra nested folder or a GitHub branch suffix such as `-main`.
3. Restart WoW and enable **RatedStats - RBG Alerts** in the AddOns menu.

## Usage and settings

- Drag the `::` grip to move the widget when its position is unlocked.
- Use `+` or `-` to expand or collapse the group list.
- Click the header or a group row for instructions on opening the RBG finder. These clicks do not search, apply to a group or queue you.
- Type `/rbgalerts` to open settings.

When Rated Stats is enabled and its settings category is available, **RBG Alerts** appears beneath **Rated Stats** in Settings > AddOns. Otherwise it has its own settings entry. In the AddOns enable/disable menu, it also groups beneath RatedStats when that addon is installed.

| Command | Action |
| --- | --- |
| `/rbgalerts` | Open settings |
| `/rbgalerts finder` | Show manual Group Finder instructions |
| `/rbgalerts toggle` | Show or hide the widget |
| `/rbgalerts reset` | Reset the widget position |

## Optional integration

RBG Alerts works without any other Rated Stats addon. RatedStats_Achiev supplies achievement information only when available; RBG Alerts does not inspect or infer achievements for unknown leaders.

## Reporting issues

Include your WoW version, RBG Alerts version, steps to reproduce, and the full Lua error if one appeared. Mention whether RatedStats and RatedStats_Achiev were enabled. Screenshots are helpful for display issues.
