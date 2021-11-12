# [WOTC] Iridar's Appearance Manager

This mod adds new functionality to Character Pool and new robust interface to manage units' appearance, as well as an automated soldier uniform manager.

# New Soldier Customization UI

1. New "Manage Appearance" screen. It allows easily copying units' entire or partial appearance onto other units, as well as quickly importing soldier appearance from character pool, or putting uniforms on soldiers. 
You can also make sweeping changes to your entire squad, barracks or character pool. This can be used, for example, to quickly set the same camouflage for the entire squad.

2. New "Stored Appearance" screen, which allows viewing and deleting stored soldier appearance for each armor they have ever equipped.

# Character Pool Changes

1. Character Pool list is now sorted and shows soldiers' class, and also has a search button.
2. Character Pool now saves Appearance Store - individual unit appearance for each armor.
3. "Dormant" character pool units that do not appear in the campaign are now allowed.
4. It's now possible to pre-customize appearance of Character Pool units for each armor by equipping said armor on the new Loadout screen. You can also equip weapons in character pool, but this is entirely cosmetic, and will not be used outside character pool.
5. Appearance validation is now turned off by default in debug mode, and can be also turned off in normal mode (in Mod Config Menu). Appearance validation is the game attempting to correct the appearance of character pool units if their cosmetic body parts become missing, typically because you have deactivated cosmetic mods with those body parts. Disabling validation allows to temporarily disable cosmetic mods without losing the customized appearance of your entire character pool. If appearance validation is currently disabled, a new button is added to soldier customization screen to perform it manually for specific soldiers.
6. Individual Character Pool units can be converted to Uniforms. Uniforms are grouped separately on the Manage Appearance screen, and can be used by the Uniform Manager (see below).

# Automated Uniform Manager

When soldiers equip new armor for the first time, or are promoted to squaddie rank, the mod will look for a suitable Uniform in Character Pool, and apply it automatically. 

Individual soldiers and Uniforms can be excluded from participating in this automated process.

This system can be disabled globally in Mod Config Menu. If disabled globally, individual units can still be included in the automated process.

You can also work with Uniforms manually on the Manage Appearance screen.

Uniforms can be shared with other people by exporting them into Character Pool Files, just like regular units.

For each Gender+Armor pair of each Uniform unit, you can configure which parts of that appearance are actually a part of the uniform. For example, you can make a generic uniform that applies to all units, and then class-specific uniforms that only change unit's Torso Deco and Helmet slots.

# More info on Appearance Store

This mod expands the Character Pool so that Character Pool units can benefit from the game's Appearance Store mechanic.
Even without any mods, during the campaign soldiers remember their appearance for each armor they have ever equipped. 
But this information is lost when the unit is saved to the Character Pool.
