Created by Iridar

More info here: https://www.patreon.com/Iridar


[WOTC] Iridar's Appearance Manager

This mod adds new functionality to Character Pool and new robust interface to manage units' appearance, as well as an automated Uniform Manager.

[h1]New Soldier Customization UI[/h1]
[list]
[*] New "Manage Appearance" screen. Allows copying units' entire or partial appearance onto other units, as well as quickly importing soldier appearance from Character Pool or Memorial, or putting uniforms on soldiers. You can also make sweeping changes to your entire squad, barracks or Character Pool. This can be used, for example, to quickly set the same camouflage for the entire squad.
[*] New "Stored Appearance" screen. Allows viewing, "equipping" and deleting stored soldier appearance for each armor they have ever equipped.[/list]

[h1]Character Pool Changes[/h1]
[list]
[*] Character Pool list is now sorted and shows soldiers' class.
[*] A "Search" button has been added to quickly filter out soldiers based on their name or class.
[*] Character Pool now saves Appearance Store - individual unit appearance for each armor.
[*] It's now possible to pre-customize appearance of Character Pool units for each armor by equipping said armor on the new Loadout screen. Weapons can also be previewed in Character Pool.
[*] "Dormant" character pool units that do not appear in the campaign are now allowed.
[*] Appearance validation is now turned off in debug game mode, and can be also turned off in normal game mode. Appearance validation is the game attempting to correct the appearance of Character Pool units if their cosmetic body parts became missing, typically because you have deactivated cosmetic mods with those body parts. Disabling validation allows temporarily disabling cosmetic mods without losing the customized appearance of your entire Character Pool. If appearance validation is currently disabled, a new button is added to soldier customization screen to perform it manually for specific soldiers.
[*] Individual Character Pool units can be converted to Uniforms. Uniforms are grouped separately on the Manage Appearance screen, and may be applied to soldiers manually or automatically.[list]

[h1]Automated Uniform Manager[/h1]
[list]
[*] When soldiers equip new armor for the first time, the mod will look for a suitable Uniform in Character Pool, and apply it automatically. 
[*] Individual soldiers and Uniforms can be excluded from participating in this automated process.
[*] This system can be disabled globally in Mod Config Menu. If disabled globally, individual units can still be included in the automated process.
[*] You can also work with Uniforms manually using the Manage Appearance screen.
[*] Uniforms can be shared through Character Pool files.[/list]

[h1]REQUIREMENTS[/h1]
[list]
[*] [url=https://steamcommunity.com/workshop/filedetails/?id=1134256495][b]X2 WOTC Community Highlander[/b][/url] is required.[/list]

[h1]COMPATIBILITY[/h1]

Appearance Manager replaces [i][b]CharacterPoolManager[/b][/i] and will be incompatible with any mod that does the same. It also has the following ModClassOverrides:
[code]
UICharacterPool - can be safely disabled by removing its entry in this mod's XComEngine.ini. Doing so will disable sorting and the "Search" button.
UICharacterPool_ListPools - required for the mod to Import and Export additional information to and from Character Pool files created with this mod.[/code]

[list]
[*] [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1135440846]Unrestricted Customization - Wotc[/url][/b] (and its [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2438621356]Redux version[/url][/b]) - limited compatibility. These mods can work together, but the Uniform Manager and Stored Appearance screen will become useless due to what Unrestricted Customization does to Appearance Store.
[*] [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1136878667]WOTC Extended Character Pool[/url][/b] - compatible if you disable Appearance Manager's ModClassOverride for [b][i]UICharacterPool[/i][/b].
[/list]

[h1]COMPANION MODS[/h1]
[list]
[*] [url=https://steamcommunity.com/sharedfiles/filedetails/?id=2518586673][b][WOTC] No Tech Gated Helmets[/b][/url] - allows equipping any helmet in Character Pool.[/list]

[h1]CREDITS[/h1]

Huge thanks to [b]Xymanek (Astral Descend)[/b] for crucial code support and UI improvements.

Please [b][url=https://www.patreon.com/Iridar]support me on Patreon[/url][/b] if you require tech support, have a suggestion for a feature, or simply wish to help me create more awesome mods.

# More info on Appearance Store

This mod expands the Character Pool so that Character Pool units can benefit from the game's Appearance Store mechanic.
Even without any mods, during the campaign soldiers remember their appearance for each armor they have ever equipped. 
But this information is lost when the unit is saved to the Character Pool.