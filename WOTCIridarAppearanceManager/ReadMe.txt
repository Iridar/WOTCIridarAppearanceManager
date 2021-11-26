Created by Iridar

More info here: https://www.patreon.com/Iridar

Forest Walk by Alexander Nakarada | https://www.serpentsoundstudios.com
Music promoted by https://www.chosic.com/free-music/all/
Attribution 4.0 International (CC BY 4.0)
https://creativecommons.org/licenses/by/4.0/



[WOTC] Iridar's Appearance Manager

Adds new functionality to Character Pool and new interface to manage units' appearance, as well as an automated Uniform Manager.

For a brief overview of the mod's functions, check the introduction video above, or click the link below for an in-depth explanation.

[b][url=https://steamcommunity.com/workshop/filedetails/discussion/2664422411/3194737075878800834/]>>> DETAILED INSTRUCTIONS <<<[/url][/b]

[h1]New Soldier Customization UI[/h1]
[list]
[*] New "Manage Appearance" screen. Allows copying units' entire or partial appearance onto other units, as well as quickly importing soldier appearance from Character Pool or Memorial, or putting uniforms on soldiers. You can also make sweeping changes to your entire Squad, Barracks or Character Pool. This can be used, for example, to quickly set the same camouflage for the entire Squad.
[*] New "Stored Appearance" screen. Allows viewing, "equipping" and deleting stored appearance for each armor the soldier have ever equipped.[/list]

[h1]Character Pool Changes[/h1]
[list]
[*] Character Pool soldier list is now sorted and shows soldiers' class.
[*] A "Search" button has been added to quickly filter out soldiers based on their name or class.
[*] You can now Shift+Click to select or deselect multiple soldiers in Character Pool.
[*] Character Pool now saves Appearance Store - individual unit appearance for each armor.
[*] It's now possible to pre-customize appearance of Character Pool units for each armor by equipping said armor on the new Loadout screen. Weapons can also be previewed in Character Pool.
[*] "Dormant" character pool units that do not appear in the campaign are now allowed.
[*] Appearance validation is now turned off in debug game mode, and can be also turned off in normal game mode. Appearance validation is the game attempting to correct the appearance of Character Pool units if their cosmetic body parts become missing, typically because cosmetic mods with those body parts have been deactivated. Disabling validation allows temporarily disabling cosmetic mods without losing the customized appearance of your Character Pool. If appearance validation is currently disabled, a new button is added to soldier customization screen to perform it manually for specific soldiers.
[*] Individual Character Pool units can be converted to Uniforms. Uniforms are grouped separately on the Manage Appearance screen, and may be applied to soldiers manually or automatically.[/list]

[h1]Automated Uniform Manager[/h1]
[list]
[*] When soldiers equip new armor for the first time, the mod will look for a suitable Uniform in Character Pool, and apply it automatically. 
[*] Individual soldiers and Uniforms can be excluded from participating in this automated process.
[*] This system can be disabled globally in Mod Config Menu. If disabled globally, individual units can still be included in the automated process.
[*] You can also work with Uniforms manually using the Manage Appearance screen.
[*] Uniforms can be shared through Character Pool files.[/list]

[h1]Be careful with[/h1]
[list]
[*] Disabling the mod - Appearance Manager is safe to disable temporarily, as long as you don't make [b][i]any[/i][/b] changes to character pool units.
[*] Any stored appearance on the Uniform unit will count as a potential uniform, so when you are done setting up a uniform, make sure to go to Stored Appearance screen and delete any unwanted appearances.
[*] Be very careful when you [b]Apply Сhanges[/b] to multiple units. Double check cosmetic options you have enabled, otherwise you might accidentally give the same face to all soldiers in your barracks, for example.[/list]

[h1]REQUIREMENTS[/h1]
[list]
[*] [url=https://steamcommunity.com/workshop/filedetails/?id=1134256495][b]X2 WOTC Community Highlander[/b][/url] is required.
[*] [url=https://steamcommunity.com/sharedfiles/filedetails/?id=667104300][b][WotC] Mod Config Menu[/b][/url] is supported, but not a hard requirement.
[*]Safe to add or remove mid-campaign.[/list]

[h1]COMPATIBILITY[/h1]

Appearance Manager replaces [i][b]CharacterPoolManager[/b][/i] and will be incompatible with any mod that does the same. It also has the following ModClassOverrides:
[code]
UICharacterPool - can be safely disabled by removing its entry in this mod's XComEngine.ini. Doing so will disable sorting and the "Search" button.

UICharacterPool_ListPools - required for the mod to Import and Export additional information to and from Character Pool files created with this mod.[/code][list]
[*] [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1135440846]Unrestricted Customization - Wotc[/url][/b] (and its [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2438621356]Redux version[/url][/b]) - [b]limited compatibility[/b]. These mods can work together, but the Uniform Manager and Stored Appearance screen will become useless due to what Unrestricted Customization does to Appearance Store.
[*] [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1136878667]WOTC Extended Character Pool[/url][/b] - compatible if you disable Appearance Manager's ModClassOverride for [b][i]UICharacterPool[/i][/b].
[*] [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2589916279][WOTC] Item Hider[/url][/b] - compatible, hidden items do not appear as equippable in Character Pool Loadout screen.
[/list]

Other than that, should be compatible with anything and everything.

[h1]CONFIGURATION[/h1]

Presets and MCM settings for this mod are stored in this file. You might want to back it up when deleting User Config folder.
[code]..\Documents\my games\XCOM2 War of the Chosen\XComGame\ConfigXComAppearanceManager.ini[/code]

Mod's default configuration is located here:
[code]..\steamapps\workshop\content\268500\2664422411\Config\[/code]

[h1]COMPANION MODS[/h1]
[list]
[*] [url=https://steamcommunity.com/sharedfiles/filedetails/?id=2518586673][b][WOTC] No Tech Gated Helmets[/b][/url] - allows equipping any helmet in Character Pool.
[*] [url=https://steamcommunity.com/sharedfiles/filedetails/?id=1125727531][b]WOTC Use My Class[/b][/url] - makes soldiers properly promote to the soldier class set in Character Pool.[/list]

[h1]KNOWN ISSUES[/h1]

In case of non-soldier uniforms for some characters, like Shen, their body will clip through the cosmetic body parts added by their uniform.

Mod causes a ton of log warnings and redscreens while working with Character Pool Loadout. Those are annoying, but completely harmless, and fixing them all would require way more effort and Highlander changes than its worth.

[h1]CREDITS[/h1]

Huge thanks to [b]Xymanek (Astral Descend)[/b] for crucial code support and UI improvements.
Thanks to my beta testers: [b]RustyDios, lago508, Deadput[/b].
Blame [b]Veehementia[/b] for making me think that making this mod was a good idea.

Please [b][url=https://www.patreon.com/Iridar]support me on Patreon[/url][/b] if you require tech support, have a suggestion for a feature, or simply wish to help me create more awesome mods.


# DETAILED GUIDE

This is a complete review of how the mod works and what it does. There's a lot of information to cover, but if you do read through it, you will know how to use 100% of the mod's functionality. But before we proceed you must understand what Appearance Store is.

Appearance Store is a system that exists even without any mods, in the base game itself. It makes each unit remember their appearance for each specific armor and gender. E.g. soldier's female Plated appearance can be completely different from their female Kevlar appearance, and will be applied to the unit automatically whenever you equip Plated Armor or switch genders.

In the base game, this information is not preserved in Character Pool. Only units' Kevlar appearance is stored, and only for their current gender. 

[h1]Character Pool Changes[/h1]

The mod replaces the base game Character Pool with an improved and expanded version. The main point of that expansion is storing additional information about Character Pool units, such as Appearance Store, their Character Pool loadout, and their uniform status.

This additional information is stored in the Character Pool file itself. If Character Pool is saved while this mod is deactivated - and the game saves Character Pool very often - all the extra information previously stored in the character pool file will be lost.

To prevent this, the mod automatically stores a backup copy of the character pool file, and will restore extra data from it automatically when the game is launched. So temporarily disabling the Appearance Manager is fine, as long as you don't make any changes to Character Pool soldiers.

The "expanded" Character Pool files can be shared with other people, same as always, but obviously they will need the Appearance Manager mod to access the extra information stored there.

As another minor feature, you are now allowed to have "dormant" Character Pool units. In the base game, if you uncheck all three "Can Appear As ..." checkboxes, the game will automatically set "Can Appear As Soldier" checkbox to true the next time you start it. So the game itself does not allow you to have Character Pool units that will not appear during the campaign. Appearance Manager changes this behavior, and now you can uncheck all three checkboxes, and this will actually stick.

Such dormant soldiers will have their name colored as light grey color in the Character Pool list.

[h1]Character Pool Loadout[/h1]

The Loadout screen allows equipping different armor and weapons on Character Pool units. Equipping different Armors allows you to pre-customize soldier appearance for that specific armor, and this appearance will be used automatically when the soldier equips that armor for the first time during the campaign.

Equipping weapons is purely cosmetic and currently serves no specific purpose.

There is only one Character Pool loadout stored per unit. It is equipped automatically on the soldier whenever you enter the customization screen for that soldier in Character Pool.

[h1]Stored Appearance Screen[/h1]

This screen allows browsing the Appearance Store for each unit. You can click on individual stored appearance to "equip" it. The mod will then attempt to equip the Armor that was used to customize that appearance.

If you do so in the Armory, during an actual campaign, the mod will attempt to equip that specific armor. E.g. if you click on Rage Suit appearance, the mod will look for the Rage Suit in your HQ inventory and equip it, if it finds it.

You can also delete specific stored appearance by clicking the "Delete" button on it, except for the soldier's current appearance.

[h1]Appearance Validation[/h1]

Base game always forcibly validates appearance of character pool units whenever the game is started. If you use mod-added cosmetic body parts for your soldiers, and then start the game without those mods, soldiers will have missing body parts. Appearance Validation fixes such soldiers, defaulting them to standard kevlar appearance.

This is useful so that your soldiers don't get stuck with missing body parts, because if that would happen, you would be unable to fix soldier appearance by customizing them differently.

However, it also means that if you disable your cosmetic mods even for one game start, you will ruin your entire character pool - your soldiers will lose their custom appearance and will be reset to kevlar body parts.

Appearance Manager can disable this Appearance Validation so that you can safely temporarily disable your cosmetic mods. This is especially useful for modmakers, who typically use the minimum amount of mods while making mods, as it makes the game start much faster.

In Mod Config Menu, you can disable Appearance Validation separately in "normal" and "debug" game mode. "Normal" is when you start the game with the "-review" launch argument. By default, Appearance Validation is disabled only in "debug" mode.

When Appearance Validation is disabled in your current game mode, the Validate Appearance button is added to soldier customization screen, allowing you to manually validate appearance of individual soldiers.

[h1]Manage Appearance Screen[/h1]

This screen allows copying entire or partial appearance of units onto other units. There's quite a lot to go through, so I'll go section by section.

[b]APPEARANCE LIST[/b]

Appearance List in the right part of the screen contains the list of soldier appearances you can work with, entitled as "SELECT APPEARANCE". This is specifically the list of appearances, not soldiers. If a soldier has several appearances stored, all of them will be listed separately. There is a "SEARCH" button you can click to filter appearances by their name.

At the top of the list is the selected soldier's "ORIGINAL APPEARANCE" - the appearance the soldier had when you entered the screen, or after you have clicked the "Apply Changes" button. Original Appearance will be selected automatically when you enter the screen. It has a "Save as Uniform" button you can click to save selected soldier's current appearance into Character Pool as a Uniform. This is mostly useful during the campaign, so you can save a specific appearance of a specific unit into Character Pool to reuse it later.

The Appearance List has several Headers: Uniforms, Character Pool, Barracks and Memorial. Under each Header there will be a list of appearances of soldiers from that category. Barracks and Memorial headers are shown only during a campaign, not in Character Pool.

Each Header has an eye icon you can click to "fold" the group, hiding all of its members.

During the campaign, character pool soldiers that are already in your campaign will be highlighted in green. This is done so that you know not to import the entire unit from character pool to avoid the same soldier appearing twice.

[b]FILTERS[/b]

In the upper right corner of the screen, there is a "FILTERS" sub menu, with the following elements:
GENDER - enabled by default. While this filter is enabled, appearances for genders different from the gender of your currently selected unit will not be shown. The reason for this is that different genders usually have different body parts, even if they look kinda the same, so unless you're willing to change the gender of your currently selected soldier while copying the appearance, there's not much you can do with appearances for other genders.
CLASS - disabled by default. If enabled, appearances of soldiers of a different soldier class will not be listed.
ARMOR - enabled by default. If enabled, the appearance list will include only appearances made for the same armor as the one equipped on the currently selected unit. E.g. if they have kevlar armor equipped, only kevlar appearances will be shown in the list. If you disable this filter, you'll be able to do things like copying Kevlar appearance while actually having Plated armor equipped, but then you will be unable to customize soldier's Plated appearance until you copy it again from somewhere else. You will be able to choose only from Kevlar cosmetic options. This happens because the game's customization system doesn't actually check which armor item the unit has equipped; it works by looking at the cosmetic torso in the unit's appearance.

[b]COSMETIC OPTIONS LIST[/B]

When you select an appearance from the Appearance List, the Cosmetic Options List on the left will show the differences between the appearance of the currently selected soldier, and the appearance you have selected from the Appearance List.

Each part of the appearance is represented by name, description that says what is changing to what, as well as its own checkbox. The checkbox determines whether that part of the selected appearance will be copied onto the unit.

E.g. Hair: Short -> Long Curls [x]

As long as that checkbox is enabled, soldier's original "Short" haircut will be replaced by the "Long Curls" haircut from the selected appearance.

If you don't want that change to happen, simply uncheck the checkbox. 

Another example:

Lower Face Prop: None -> Cigarette [ ]

This shows that the unit does not have any lower face prop set, but in the selected appearance the lower face prop is a cigarette. You check the checkbox to copy that part of the appearance.

All changes done to the checkboxes in this list are immediately automatically previewed, so it should be easy to notice.

Similarly to Appearance List, the Cosmetic Option List has Headers like Head, Body, etc. They can also be hidden by clicking the eye icon on the right. Just keep in mind that while a group is hidden, the mod will consider all of the checkboxes in that group as unchecked.

[b]APPLY CHANGES BUTTON[/b]

This button is located at bottom middle part of the screen. When you are satisfied with the soldier's appearance, you have to click on it to apply the changes before you exit the screen. The button is displayed in the green color only while there are changes to apply.

[b]PRESETS[/b]

At the top of the Cosmetic Options list there is a list of Presets. The Presets are an optional feature that is intended to make it easier to handle the checkboxes in the Cosmetic Options list. The preset system may seem complicated, but its only purpose is to save your time spent on clicking on checkboxes. If you don't want to interact with it, you can have the preset list hidden by clicking on the eye icon in its header and forget it even exists.

Preset is used to store the status of every checkbox in the Cosmetic Options list - whether it was checked or unchecked.

"Default" preset is simply the default preset loaded when you open the screen. 

"Uniform" preset includes soldier's body customization, helmet/hat and armor and weapon colors. You can change this preset, but you cannot delete it, as it is also used by the Uniform System for uniforms that you have not configured manually. This is explained in more detail further below.

"Patterns" preset enables just the armor and weapon patterns.

"Entire Unit" preset enables all checkboxes, so that you can copy everything about the selected unit and appearance. This is essentially the "Import unit from Character Pool" preset.

"Nothing" preset just has all checkboxes disabled.

While you are in the Default preset, other presets have "Copy Preset" button on them. You can click that button to copy that preset into your default preset. That way you can interact with a preset without changing it. For example, let's say you want to copy the patterns and a helmet from the selected appearance. Then you can copy the "Patterns" preset, which will enable all of the armor and weapon colors options, and disable everything else. Then you can enable the Helmet option, and have everything done in just two clicks.

While you have a preset other than Default selected, the button on that preset will allow you to delete that preset, except for the Uniform preset, which cannot be deleted. 

Finally, you can click the "Create Preset" button to create a preset with your currently selected Cosmetic Options. When you click that button, you will be prompted for the name of that preset. This name has limitations: it must be under 63 characters in length, and it should not include any symbols except for english letters and numbers. Empty spaces are not allowed, and will be replaced with the "_" underscore symbol.

[b]SHOW ALL OPTIONS[/b]

The "Show All Options" checkbox is located at the top of the Cosmetic Options List. While it is enabled, all of the cosmetic options will be displayed, even if they do not differ between the unit and selected appearance.

This makes the cosmetic options list very long. It is mostly useful when you want to configure a preset, and you want access to all of the cosmetic options. The second use case is when making changes to not just currently selected unit, but to entire squad, or entire barracks, as covered below.

[b]APPLY TO[/b]

This small menu in the upper right corner of the screen lets you select which units will have cosmetic changes applied to them.

The options include:
"This Unit" - the currently selected unit on the Manage Appearance Screen.
"Squad" - currently selected Squad on Avenger, except for the selected unit. This option is enabled only during a campaign.
"Barracks" - all soldiers in the Avenger Barracks, except for the selected unit and squad. This option is enabled only during a campaign.
"Character Pool" - all soldiers in the character pool, except for the selected unit. This option is enabled only in the Character Pool.

If the checkbox for the group is enabled, your cosmetic changes will be applied to all soldiers when you click the Apply Changes button.

This functionality is useful, for example, if you want to apply the same camouflage to your entire squad for a specific mission. However, it must be used with great care, as you may accidentally apply too many changes to too many units, making them all look like clones, ruining your barracks  or character pool.

While doing this you don't necessarily have to copy some other unit's appearance onto your currently selected unit. 

Even while you have soldier's Original Appearance selected, you can enable the Show All Options toggle, then enable the checkboxes for the appearance options you have to copy onto other soldiers, and hit "Apply Changes", and the selected parts of the original appearance of the currently selected unit will be copied onto other units.

Keep in mind that some parts of the appearance will not be copied on soldiers of different gender. E.g. you cannot give the same cosmetic torso to both males and females.

No parts of the appearance will be copied on soldiers of a different type. E.g. regular soldier customization will not be copied on top of a Reaper or a SPARK - the only exception here are universal things, like patterns and tattoos.

[h1]Uniform Manager[/h1]

Appearance Manager has a built-in Uniform Manager that can be used in both manual and automatic mode.

While in Character Pool, you can convert individual soldiers to Uniforms. Each soldier in your Character Pool can be either a Uniform or regular soldier.

When a soldier is converted to a Uniform, their first name is automatically changed into "UNIFORM", and you are prompted to enter their new last name, which will serve as that uniform's description. This is done purely for your benefit as a mod user, so that you can easily distinguish which units are uniforms, and which are not. The mod uses separate internal value to track whether a particular unit is a uniform or not, so feel free to name your Uniforms however you want.

Keep in mind the Appearance Store mechanic. A single Uniform unit can store a separate appearance for each armor and gender combinations. By equipping different armors on the Loadout screen, and changing the Uniform's gender, you can customize the Uniform's appearance for each armor and gender combination, and each stored appearance will count as a separate uniform.

Each Uniform unit has a "Uniform Management" setting. It determines whether this uniform will be applied to other units automatically or not, and if yes - to which units.

"Do not apply automatically" - default selection. In this mode, the Uniform will not be automatically applied to anybody, but you can still apply it to soldiers manually using Manage Appearance screen, where uniforms are grouped separately from other units.
Other Uniform Management settings switch the Uniform into automated mode. Automated uniform management is always tied to armor and gender; you have to keep this in mind at all times. If you set up a Uniform for Kevlar male appearance, and select the "any class" mode, this uniform's appearance will be copied onto any male unit that equips Kevlar armor for the first time. But it will not affect, say, Reapers, because they have their own Kevlar Armor.


"Apply to any soldier class" - In this mode, the uniform will be applied automatically to any soldier of any soldier class when they equip that armor for the first time. 
"Apply to same soldier class" - Uniform will be applied only to soldiers of the same class. Class-specific uniforms take priority over any-class uniforms. Class-specific uniforms are applied immediately on promotion to squaddie rank.
"Apply to non-soldier characters" - In this special mode, the uniform will be applied to non-soldier characters, such as Resistance Militia, Raider Faction units, or even NPCs on the Avenger. When you set this Uniform mode, a new button will appear - "Select non-soldier characters". You can click this button to enter the screen where you can select specific character templates which will be eligible for this uniform. Keep in mind that in this specific mode, the uniform will not use the Appearance Store mechanic. It will not care what kind of armor is equipped on the targeted unit, as indeed many of them do not have any specific armor equipped at all. So only the current appearance of the Uniform will matter.
The list of eligible character templates includes only characters that use the same Human Pawn as regular soldiers. This does not include most of the enemies, which use the Alien Pawn. So uniforms for ADVENT soldiers, for example, are not possible for this mod.
---
You have to be careful about changing Uniform's gender, as then the Uniform may end up with stored appearance for the other gender that you don't want to actually use. After you set up a Uniform, it's recommended that you always examine its Stored Appearances, and make sure it only has the Appearances you actually want to use as Uniforms.

Each non-Uniform soldier, both in Character Pool and during the campaign, has its own "Uniform Management" setting. It determines whether the mod can apply uniforms to them automatically or not. 

The default setting is "Global", which means when deciding whether a uniform can be applied to this unit or not, the mod will look at the global setting in Mod Config Menu, where the Automated Uniform Management can be disabled or enabled globally.

For each specific soldier, you can also select "Always accept uniforms" and "Never accept uniforms", which will let this unit bypass the global setting. 

That way you can either keep the system enabled for most of your units, but have some specific soldiers excluded from the uniform management system, or you can keep the entire system disabled globally, but still have it operational for a few specific units.

[h1]Mod Config Menu[/h1]

Additional MCM options that have not been covered so far:

"Show the Manage Appearance screen in 2D" - normally Manage Appearance screen is displayed in 3D, where the unit stands in front, and the curved interface is displayed behind them. It looks nice, and is in line with most other soldier customization screens in this game. However, it leaves a lot of space unused, and units with big and bulky cosmetics or weapons can obscure parts of the interface, making it inconvenient. This MCM setting allows you to force the 2D mode for the screen, which will occupy more space on the screen, and render the unit behind the interface. Try both and see which mode you like more.
"Require confirmation to apply changes to multiple units" - if enabled, then while on Manage Appearance Screen, the mod will ask for your confirmation if you attempt to apply changes to multiple units. This is done to prevent accidentally changing the appearance of too many units at the same time as much as possible.
"Enable debug logging" - if enabled, the mod will output debug logging into your "..\Documents\my games\XCOM2 War of the Chosen\XComGame\Logs\Launch.log" file. The mod spams logs a lot, so this setting is disabled by default. However, if you experience some kind of an issue with this mod, then enable debug logging and attempt to reproduce the problem, and then send the Launch.log file to me, with a detailed description of what you were doing, what was the intended result, and what has actually happened, and I'll do my best to fix it. The mod is quite complicated, so there could always be bugs.

[h1]Misc Changes[/h1]

The base game does not let you rotate the soldier on some customization screens, which is annoying and inconsistent for seemingly no good reason. Appearance Manager makes it so you can rotate the soldier on any customization screen. 

[h1]Sharing Character Pool Files[/h1]

With Appearance Manager, you can share Uniforms and units pre-customized for multiple Armors just by exporting them into a Character Pool file, and sending it to other people, though obviously they will require the Appearance Manager mod to access that additional information, like Appearance Store.

If they don’t have Appearance Manager, they will still be able to use the character pool file, but the extra information will not be available to them.

If you are a modmaker, you can create mods to share your Character Pool with Uniforms or units.

All you have to do is create a mod with the "CharacterPool" folder, with your Character Pool .bin file(s) inside of it. No configuration or script files are necessary.
