RatedStats - RBG Alerts (Retail)
===================

INSTALL
1. Place RatedStats_RBGAlerts/ (containing RatedStats_RBGAlerts.toc) into World of Warcraft/_retail_/Interface/AddOns/
2. Enable "RatedStats - RBG Alerts" in the AddOns list and /reload.
3. Click "RBG Groups: X" for instructions, then open the RBG Premade Group Finder using Blizzard's own controls.
4. Use the :: grip to drag the widget. Use + / - to expand and collapse the group list.

OPTIONS
/rbgalerts           Open options (Settings -> AddOns -> RBG Alerts)
/rbgalerts finder    Show instructions for opening the RBG Premade Group Finder
/rbgalerts toggle    Show/hide the floating widget
/rbgalerts reset     Reset widget position

The addon listens to the same LFG events tested via WowLua. It does NOT call
C_LFGList.Search() on a timer or automatically refresh the group finder.

Listings are based on result data received by the game client. The count is
not guaranteed to be a complete, live RBG listing count. Entries not observed
again for 20 minutes expire from the widget. Up to eight groups are shown;
more can be viewed by opening Blizzard's finder.

The optional RatedStats_Achiev module supplies highest-PvP-achievement icons
and achievement tooltips for group leaders already known to Rated Stats.
No achievement data is generated or inferred when the module has no record.

STANDALONE INSTALLATION
RatedStats is not required. The included RatedStats.tga supplies both the
widget logo and the AddOns menu icon. Keep it inside RatedStats_RBGAlerts/.
When RatedStats is installed, this addon groups beneath it in the AddOns menu;
otherwise it appears independently. Achievement badges are optional.

After installing this build, restart WoW and verify the logo and AddOns menu
both with RatedStats enabled and with only RBG Alerts enabled.
