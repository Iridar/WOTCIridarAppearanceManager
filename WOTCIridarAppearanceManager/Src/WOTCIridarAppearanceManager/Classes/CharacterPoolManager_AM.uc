class CharacterPoolManager_AM extends CharacterPoolManager;

// This class is a replacement for the game's own CharacterPoolManager with some extra functions and modifications,
// as well as additional information storage about character pool units, which will be automatically serialized (saved)
// in the character pool files created with this mod present.
//
// Apparently, just adding more class variables is enough to have them saved automatically. 
// Presumably this happens because native functions store the character pool .bin file
// by serializing the entire CharacterPoolManager object. It has some serialization rules that prevent it from saving
// the 'CharacterPool' array of Unit States, but there are no special rules for additional data we add here.
// 
// This class mostly expands existing Character Pool functions; the only change in the normal functionality is that 
// we validate units' appearance (to remove broken body parts caused by removed mods) only if the mod is configured to do so via MCM. 
// This is done so that people's Character Pool isn't immediately broken the moment they dare to run the game with a few mods disabled.
// We also allow "dormant" character pool units that don't appear as soldier nor VIPs (vanilla forces them to at least be soldiers).

struct CosmeticOptionStruct
{
	var name OptionName;// Name of the cosmetic option that's part of the TAppearance, e.g. 'nmHead'
	var bool bChecked;	// Bool flag that determines whether this part of TAppearance is a part of the uniform.
};

struct CharacterPoolLoadoutStruct
{
	var name TemplateName;
	var EInventorySlot InventorySlot;
};

struct UniformSettingsStruct
{
	var string GenderArmorTemplate; // Same as in the AppearanceStore. These uniform options are for this armor and gender.
	var array<CosmeticOptionStruct> CosmeticOptions;
};

enum EAutoManageUniformForUnit
{
	EAMUFU_Default,		// Use global MCM setting.
	EAMUFU_AlwaysOn,	// Always automatically apply uniforms to this unit, if there are any valid ones.
	EAMUFU_AlwaysOff	// Never auto apply uniforms to this unit.
};

enum EUniformStatus
{
	EUS_NotUniform,		// This unit is not a uniform.
	EUS_Manual,			// This uniform will be disregarded by the automated uniform manager.
	EUS_AnyClass,		// This uniform will be automatically applied to soldiers of any class.
	EUS_ClassSpecific,	// This uniform will be auto applied only to soldiers of the same class.
	EUS_NonSoldier		// This uniform will be auto applied to non-soldier units, like resistance militia. Separate button is displayed to select which units, exactly.
};

// The technically challenging task is figuring out how to connect the Extra Data with each specific unit in Character Pool array.
// Keeping in mind that the order of units in the array cannot be guaranteed in case some mod decides to inject a Unit State at the start or in the middle,
// and - majorly - because we sort the character pool constantly.

// Normally we'd identify units by their Object ID, but due to how character pool is set up, we can't rely on it, since duplicates are possible.
// When Character Pool is loaded, we can read the Extra Data entries, and we're provided with the unit's 'CharacterPoolDataElement' data.
// We can use it to identify unit's ExtraData entry. The 'CharacterPoolDataElement' includes a lot of info about the unit, including a timestamp, so it's pretty much guaranteed to be unique.
// The 'CharacterPoolDataElement' can be written into extra data for every unit when we're saving character pool.

// However, when Character Pool is saved, and while the game is running, we need a way to identify which Extra Data belongs to which unit.
// To do so, we assign a unique ObjectID to each Extra Data object (when character pool is loaded, and when units are imported from other character pools), 
// and write the same ObjectID into a UnitValue on the UnitState.
// If we attempt to find ExtraData for such a unit and can't find it, it is assumed this unit has no extra data saved, so new one is created.

struct CharacterPoolExtraData
{
	// Used to sync Extra Data with specific UnitStates while the game is in play.
	var int ObjectID; 

	// Used to sync Extra Data with specific units when the CP.bin is saved or loaded.
	var CharacterPoolDataElement CharPoolData; 

	// Actual new info we store about the unit:
	var array<AppearanceInfo> AppearanceStore;

	var array<UniformSettingsStruct> UniformSettings; // For each stored appearance, determines which part of the appearance counts as a part of the uniform.

	var EUniformStatus UniformStatus;	// Only for uniforms.
	var EAutoManageUniformForUnit AutoManageUniformForUnit; // Only for non-uniforms.

	var array<name> NonSoldierUniformTemplates; // List of character templates this non-soldier uniform should be used for.

	var array<CharacterPoolLoadoutStruct> CharacterPoolLoadout; // List of items that should be equipped on this unit in Character Pool.
};
var array<CharacterPoolExtraData> ExtraDatas;

var int iNumExtraDataOnInit; // Helps track if we might need to restore extra data from backup.

const ExtraDataValueName = 'IRI_AppearanceManager_ExtraData_Value';
const NonSoldierUniformSettings = 'NonSoldierUniformSettings';
const BackupCharacterPoolPath = "CharacterPool\\DefaultCharacterPool_AppearanceManagerBackup.bin";

`include(WOTCIridarAppearanceManager\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

// ============================================================================================
// OVERRIDES OF EXISTING FUNCTIONS

// Modified version of super.InitSoldier()
simulated final function InitSoldierAppearance(XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData)
{
	local XGCharacterGenerator CharacterGenerator;
	local TSoldier             CharacterGeneratorResult;

	//`CPOLOG("called for unit:" @ Unit.GetFullName());

	Unit.SetSoldierClassTemplate(CharacterPoolData.m_SoldierClassTemplateName);
	Unit.SetCharacterName(CharacterPoolData.strFirstName, CharacterPoolData.strLastName, CharacterPoolData.strNickName);
	Unit.SetTAppearance(CharacterPoolData.kAppearance);
	Unit.SetCountry(CharacterPoolData.Country);
	Unit.SetBackground(CharacterPoolData.BackgroundText);
	Unit.bAllowedTypeSoldier = CharacterPoolData.AllowedTypeSoldier;
	Unit.bAllowedTypeVIP = CharacterPoolData.AllowedTypeVIP;
	Unit.bAllowedTypeDarkVIP = CharacterPoolData.AllowedTypeDarkVIP;
	Unit.PoolTimestamp = CharacterPoolData.PoolTimestamp;

	// DISABLED - this Firaxis code makes it impossible to have "dormant" units in Character Pool that won't appear in the campaign.
	//if (!(Unit.bAllowedTypeSoldier || Unit.bAllowedTypeVIP || Unit.bAllowedTypeDarkVIP))
	//	Unit.bAllowedTypeSoldier = true;

	// ADDED
	// Skip appearance validation if MCM is configured so.
	if (class'Help'.static.IsAppearanceValidationDisabled())
		return;
	// END OF ADDED

	//No longer re-creates the entire character, just set the invalid attributes to the first element
	//if (!ValidateAppearance(CharacterPoolData.kAppearance))
	if (!FixAppearanceOfInvalidAttributes(Unit.kAppearance))
	{
		//This should't fail now that we attempt to fix invalid attributes
		CharacterGenerator = `XCOMGRI.Spawn(Unit.GetMyTemplate().CharacterGeneratorClass);
		`assert(CharacterGenerator != none);
		CharacterGeneratorResult = CharacterGenerator.CreateTSoldierFromUnit(Unit, none);
		Unit.SetTAppearance(CharacterGeneratorResult.kAppearance);
	}
}

event InitSoldier(XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData)
{
	local int Index;

	InitSoldierAppearance(Unit, CharacterPoolData);

	// Use Character Pool Data to locate saved Extra Data for this unit.
	Index = GetExtraDataIndexForCharPoolData(CharacterPoolData, true);
	`AMLOG(Unit.GetFullName() @ "Got index:" @ `ShowVar(Index));

	// The current order of this Extra Data in the array will serve as its unique Object ID.
	ExtraDatas[Index].ObjectID = Index;

	// We record this ObjectID on the unit as a UnitValue so we can connect this ExtraData to this Unit.
	Unit.SetUnitFloatValue(ExtraDataValueName, ExtraDatas[Index].ObjectID, eCleanup_Never);

	// Read actual Extra Data.
	Unit.AppearanceStore = ExtraDatas[Index].AppearanceStore;
}

function SaveCharacterPool()
{
	local XComGameState_Unit UnitState;
	local int Index;
	local array<CharacterPoolExtraData> NewExtraDatas;

	foreach CharacterPool(UnitState)
	{
		// Originally these were set to "false" when the unit was first converted into a uniform,
		// but 'bAllowedTypeSoldier' seemingly gets reset to "true" at some point, not sure when, but not particularly interested in finding out.
		// Just hard reset them every time.
		if (GetUniformStatus(UnitState) > EUS_NotUniform)
		{
			UnitState.bAllowedTypeSoldier = false;
			UnitState.bAllowedTypeVIP = false;
			UnitState.bAllowedTypeDarkVIP = false;
		}
		else if (UnitState.PoolTimestamp == class'X2StrategyGameRulesetDataStructures'.static.GetSystemDateTimeString())
		{
			// Without this mod, CP Units are automatically set to be allowed as soldiers if none of the "allowed as" checkboxes are toggled on. 
			// This mod disables that functionality, allowing dormant CP units to be a thing.
			// But it also means we need to set "allowed as soldier" to true when the soldier is just imported into the CP.
			// Presumably, they're imported right from the armory, as soldiers, so it would make sense if they could appear as soldiers by default,
			// without the player needing to go into CP and set the checkbox manually, so by doing this bit here we preserve the part of the original functionality.
			// It's probably why it was a thing in the first place.
			// Doing this right here specifically allows us to avoid replacing the functionaltiy of the "save to character pool" button itself.
			`AMLOG("This unit was just added to character pool. Setting \"allowed as soldier\" to true:" @ UnitState.PoolTimestamp);
			UnitState.bAllowedTypeSoldier = true;
		}

		// Save unit's Character Pool Data in Extra Data so we can find it later when we will be loading the Character Pool from the .bin file.

		FillCharacterPoolData(UnitState); // This writes info about Unit State into 'CharacterPoolSerializeHelper'.
		Index = GetExtraDataIndexForUnit(UnitState); // Locate Extra Data for this unit using ExtraData's ObjectID and UnitValue on the unit.
		ExtraDatas[Index].CharPoolData = CharacterPoolSerializeHelper;
		ExtraDatas[Index].AppearanceStore = UnitState.AppearanceStore;

		`AMLOG("Saving Extra Data for" @ UnitState.GetFullName() @ "ExtraData Index:" @ Index @ "Unit Index:" @ CharacterPool.Find(UnitState) @ "out of:" @ CharacterPool.Length);

		// Use a temporary array to store Extra Datas for units we're saving.
		NewExtraDatas.AddItem(ExtraDatas[Index]);
	}

	// Assign temporary array to the permanent one. That way we're sure to save only the Extra Data that is relevant to current Character Pool units. Prevents char pool file bloat.
	ExtraDatas = NewExtraDatas;
	super.SaveCharacterPool();

	// Starting the game with Appearance Manager disabled will cause all Extra Data to be lost.
	// To prevent fatal changes to the Character Pool, always save a backup.
	//PoolFileName = BackupCharacterPoolPath;
	//super.SaveCharacterPool();
	//PoolFileName = default.PoolFileName;

	// EDIT: Doing it the way above appears to make the game use the backup pool as default one if AM is deactivated.
	// Save backup pool only if this is the game's default character pool. Otherwise we cause inception by doing BackupPool.SaveCharacterPool();
	if (PoolFileName == default.PoolFileName)
	{
		SaveBackupCharacterPool();
	}
}

private function SaveBackupCharacterPool()
{
	local CharacterPoolManager_AM BackupPool;

	BackupPool = new class'CharacterPoolManager_AM';
	BackupPool.PoolFileName = BackupCharacterPoolPath;
	BackupPool.CharacterPool = CharacterPool;
	BackupPool.ExtraDatas = ExtraDatas;
	BackupPool.SaveCharacterPool();
}

// Replace pointless 'assert' with 'return none' so we can do error detecting
// in case player attempts to import a unit with a custom char template that's not present with their current modlist.
event XComGameState_Unit CreateSoldier(name DataTemplateName)
{
	local XComGameState							SoldierContainerState;
	local XComGameState_Unit					NewSoldierState;	
	local X2CharacterTemplateManager			CharTemplateMgr;	
	local X2CharacterTemplate					CharacterTemplate;
	local TSoldier								CharacterGeneratorResult;
	local XGCharacterGenerator					CharacterGenerator;
	local XComGameStateHistory					History;
	local XComGameStateContext_ChangeContainer	ChangeContainer;

	CharTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	if (CharTemplateMgr == none)
	{
		`AMLOG("ERROR :: Failed to retrieve X2CharacterTemplateManager");
		return none;
	}

	CharacterTemplate = CharTemplateMgr.FindCharacterTemplate(DataTemplateName);	
	if (CharacterTemplate == none)
	{
		`AMLOG("ERROR :: Failed to find Character Template:" @ CharacterTemplate);
		return none;
	}

	CharacterGenerator = `XCOMGAME.Spawn(CharacterTemplate.CharacterGeneratorClass);
	if (CharacterGenerator == none)
	{
		`AMLOG("ERROR :: Failed to spawn CharacterGeneratorClass:" @ CharacterTemplate.CharacterGeneratorClass.Name @ "for Character Template:" @ CharacterTemplate.DataName);
		return none;
	}

	History = `XCOMHISTORY;
	
	//Create a game state to use for creating a unit
	ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Character Pool Manager");
	SoldierContainerState = History.CreateNewGameState(true, ChangeContainer);

	NewSoldierState = CharacterTemplate.CreateInstanceFromTemplate(SoldierContainerState);
	NewSoldierState.RandomizeStats();

	NewSoldierState.bAllowedTypeSoldier = true;

	CharacterGeneratorResult = CharacterGenerator.CreateTSoldier(DataTemplateName);
	NewSoldierState.SetTAppearance(CharacterGeneratorResult.kAppearance);
	NewSoldierState.SetCharacterName(CharacterGeneratorResult.strFirstName, CharacterGeneratorResult.strLastName, CharacterGeneratorResult.strNickName);
	NewSoldierState.SetCountry(CharacterGeneratorResult.nmCountry);
	class'XComGameState_Unit'.static.NameCheck(CharacterGenerator, NewSoldierState, eNameType_Full);

	NewSoldierState.GenerateBackground(, CharacterGenerator.BioCountryName);
	
	//Tell the history that we don't actually want this game state
	History.CleanupPendingGameState(SoldierContainerState);

	return NewSoldierState;
}

function RemoveUnit(XComGameState_Unit Character)
{	
	local UnitValue UV;
	local int Index;

	if (Character.GetUnitValue(ExtraDataValueName, UV))
	{
		// Remove stored Extra Data for this unit, if there is any.
		// Not using GetExtraDataIndexForUnit() here, since it would create Extra Data if it doesn't exist, which we don't need.
		Index = ExtraDatas.Find('ObjectID', UV.fValue);
		if (Index != INDEX_NONE)
		{
			ExtraDatas.Remove(Index, 1);
		}
	}
	super.RemoveUnit(Character);
}

// TODO: Handle ExtraData <> UnitState.UnitValue connection when importing and exporting characters between character pools.

// Modified version of the original. If the created unit is taken from Character Pool, load CP unit's extra data for the newly created unit.
function XComGameState_Unit CreateCharacter(XComGameState StartState, optional ECharacterPoolSelectionMode SelectionModeOverride = eCPSM_None, optional name CharacterTemplateName, optional name ForceCountry, optional string UnitName )
{
	local array<int> Indices;
	local int i;

	local X2CharacterTemplateManager CharTemplateMgr;	
	local X2CharacterTemplate CharacterTemplate;
	local XGCharacterGenerator CharacterGenerator;
	local TSoldier CharacterGeneratorResult;

	local XComGameState_Unit SoldierState;
	local XComGameState_Unit Unit;
	local XComGameState_Unit SelectedUnit;
	local int RemoveValue;

	local int SelectedIndex;

	local ECharacterPoolSelectionMode Mode;

	Mode = GetSelectionMode(SelectionModeOverride);

	if( CharacterPool.Length == 0 )
		Mode = eCPSM_RandomOnly;

	// by this point, we should have either pool or random as our mode
	`assert( Mode != eCPSM_None && Mode != eCPSM_Mixed);

	// pool only can still fall through and do random if there's no pool characters unused or available
	if( Mode == eCPSM_PoolOnly )
	{

		for( i=0; i<CharacterPool.Length; i++ )
		{
			if (GetUniformStatus(CharacterPool[i]) > EUS_NotUniform) // ADDED: Skip uniform units. Might not be necessary, but let's be safe.
				continue;

			if(UnitName == "" || CharacterPool[i].GetFullName() == UnitName)
			{
				Indices.AddItem(i);
			}
		}

		if( Indices.Length != 0 )
		{

			// this may need to be sped up with a map and a hash
			foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', Unit )
			{
				RemoveValue = -1;

				for( i=0; i<Indices.Length; i++ )
				{
					if( CharacterPool[Indices[i]].GetFirstName() == Unit.GetFirstName() &&
						CharacterPool[Indices[i]].GetLastName() == Unit.GetLastName() &&
					    UnitName == "")
					{
						RemoveValue = Indices[i];
					}

					if( RemoveValue != -1 )
					{
						Indices.RemoveItem( RemoveValue );
						RemoveValue = -1; //Reset the search.
						i--;
					}
				}
			}

			// Avoid duplicates by removing character pool units which have already been created and added to the start state
			foreach StartState.IterateByClassType(class'XComGameState_Unit', Unit)
			{
				RemoveValue = -1;

				for (i = 0; i < Indices.Length; i++)
				{
					if (CharacterPool[Indices[i]].GetFirstName() == Unit.GetFirstName() &&
						CharacterPool[Indices[i]].GetLastName() == Unit.GetLastName() &&
						UnitName == "")
					{
						RemoveValue = Indices[i];
					}

					if (RemoveValue != -1)
					{
						Indices.RemoveItem(RemoveValue);
						RemoveValue = -1; //Reset the search.
						i--;
					}
				}
			}
		}
	}

	CharTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	`assert(CharTemplateMgr != none);

	if(CharacterTemplateName == '')
	{
		CharacterTemplateName = 'Soldier';
	}
	CharacterTemplate = CharTemplateMgr.FindCharacterTemplate(CharacterTemplateName);
	SoldierState = CharacterTemplate.CreateInstanceFromTemplate(StartState);

	//Filter the character pool possibilities by their allowed types
	if (!(CharacterTemplate.bUsePoolVIPs || CharacterTemplate.bUsePoolSoldiers || CharacterTemplate.bUsePoolDarkVIPs))
		`log("Character template requested from pool, but doesn't want any types:" @ CharacterTemplate.Name);

	for (i = 0; i < Indices.Length; i++)
	{
		if (!TypeFilterPassed(CharacterPool[Indices[i]], CharacterTemplate))
		{
			Indices.RemoveItem(Indices[i]);
			i--;
		}
	}
	

	// Indices.Length will be 0 if no characters left in pool or doing a random selection...
	if( Indices.Length != 0 )
	{
		SelectedIndex = `SYNC_RAND( Indices.Length ); 
		
		SelectedUnit = CharacterPool[ Indices[ SelectedIndex ] ];

		SoldierState.SetTAppearance( SelectedUnit.kAppearance );
		SoldierState.SetCharacterName(SelectedUnit.GetFirstName(), SelectedUnit.GetLastName(), SelectedUnit.GetNickName(false));
		SoldierState.SetCountry(SelectedUnit.GetCountry());
		SoldierState.SetBackground(SelectedUnit.GetBackground());

		// ADDED
		// Newly created units' AutoManageUniformForUnit flag should be the same as the eponymous setting in character pool.
		class'Help'.static.SetAutoManageUniformForUnitValue(SoldierState, GetAutoManageUniformForUnit(SelectedUnit));

		// Copy over saved appearance store. It's written into CP units on CP Init.
		SoldierState.AppearanceStore = SelectedUnit.AppearanceStore;

		`AMLOG("Loaded Appearance Store for:" @ SoldierState.GetFullName() @ "from:" @ SelectedUnit.GetFullName() @ SoldierState.AppearanceStore.Length);
		// END OF ADDED
	}
	else
	{
		CharacterGenerator = `XCOMGRI.Spawn(CharacterTemplate.CharacterGeneratorClass);
		`assert(CharacterGenerator != none);

		// Single Line for Issue #70
		/// HL-Docs: ref:Bugfixes; issue:70
		/// `CharacterPoolManager:CreateCharacter` now honors ForceCountry
		CharacterGeneratorResult = CharacterGenerator.CreateTSoldier(CharacterTemplateName, , ForceCountry);

		SoldierState.SetTAppearance(CharacterGeneratorResult.kAppearance);
		SoldierState.SetCharacterName(CharacterGeneratorResult.strFirstName, CharacterGeneratorResult.strLastName, CharacterGeneratorResult.strNickName);
		SoldierState.SetCountry(CharacterGeneratorResult.nmCountry);
		if(!SoldierState.HasBackground())
			SoldierState.GenerateBackground( , CharacterGenerator.BioCountryName);
		class'XComGameState_Unit'.static.NameCheck(CharacterGenerator, SoldierState, eNameType_Full);
	}

	SoldierState.StoreAppearance(); // Save the soldiers appearance so char pool customizations are correct if you swap armors
	return SoldierState;

}

// ============================================================================================
// INTERFACE FUNCTIONS 

// Helper method that fixes unit's appearance if they have bodyparts from mods that are not currently active.
final function ValidateUnitAppearance(XComGameState_Unit UnitState)
{
	local XGCharacterGenerator CharacterGenerator;
	local TSoldier             CharacterGeneratorResult;

	if (!FixAppearanceOfInvalidAttributes(UnitState.kAppearance))
	{
		CharacterGenerator = `XCOMGRI.Spawn(UnitState.GetMyTemplate().CharacterGeneratorClass);
		if (CharacterGenerator != none)
		{
			CharacterGeneratorResult = CharacterGenerator.CreateTSoldierFromUnit(UnitState, none);
			UnitState.SetTAppearance(CharacterGeneratorResult.kAppearance);
		}
	}
}

final function XComGameState_Unit AddUnitToCharacterPool(XComGameState_Unit NewUnit, optional CharacterPoolExtraData NewExtraData)
{
	// Besides adding a unit to character pool, the function is used to update Extra Data for unit.
	// Previously this function created a copy of the original unit for the reason explained in this old comment:
		// Reason: imagine scenario, we're imporing a Unit X from Character Pool A to Character Pool B.
		// In CharPool A, UX has its own Extra Data, connected to the unit by Unit Value.
		// If we add reference to the Unit X into CharPool B, CharPool B will need to have its own copy of Extra Data.
		// And Unit X will need a new Unit Value to be connected to it.
		// But if we overwrite the Unit Value on Unit X, 
		// their connection to its own Extra Data in its own CharPool A will be broken.
		// Essentially we'd break Extra Data for every unit we attempt to export from any Character Pool.
		// So in order to prevent that, we duplicate the passed unit, and then apply Unit Value to that instead.

	// But it turned out creating a new unit like that makes native code spaz out in specific circumstances, 
	// so I decided to live with exporting a unit being destructive to the connection between unit and their extra data,
	// I just changed the vanilla code to make sure these destructive changes are reversed or left unsaved.

	NewExtraData.ObjectID = FindFreeExtraDataObjectID();
	NewUnit.SetUnitFloatValue(ExtraDataValueName, NewExtraData.ObjectID, eCleanup_Never);

	ExtraDatas.AddItem(NewExtraData);

	if (CharacterPool.Find(NewUnit) == INDEX_NONE)
	{
		`AMLOG("Adding new unit to Character Pool." @ NewUnit.GetFullName());
		CharacterPool.AddItem(NewUnit);
	}
	else
	{
		`AMLOG("Updated Extra Data for Unit." @ NewUnit.GetFullName());
	}

	return NewUnit;
}

final function CharacterPoolExtraData GetExtraDataForUnit(const XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ];
}

final function EUniformStatus GetUniformStatus(XComGameState_Unit UnitState)
{
	if (CharacterPool.Find(UnitState) == INDEX_NONE)
	{
		return EUS_NotUniform;
	}
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].UniformStatus;
}

final function SetUniformStatus(const XComGameState_Unit UnitState, const EUniformStatus eValue)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].UniformStatus = eValue;
	SaveCharacterPool();
}

final function EAutoManageUniformForUnit GetAutoManageUniformForUnit(const XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].AutoManageUniformForUnit;
}
final function SetAutoManageUniformForUnit(const XComGameState_Unit UnitState, const int eValue)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].AutoManageUniformForUnit = EAutoManageUniformForUnit(eValue);
	SaveCharacterPool();
}

// Used with Unrestricted Customization to figure out what armor is equipped on the unit bypassing the regular cosmtic torso -> armor name system.
final function name GetCharacterPoolEquippedArmor(const XComGameState_Unit UnitState)
{
	local array<CharacterPoolLoadoutStruct> SavedLoadout;
	local CharacterPoolLoadoutStruct		SavedItem;

	local name								UseLoadoutName;
	local X2SoldierClassTemplate			SoldierClassTemplate;
	local X2CharacterTemplate				CharTemplate;
	local X2ItemTemplateManager				ItemTemplateManager;
	local InventoryLoadoutItem				LoadoutItem;
	local X2ArmorTemplate					ArmorTemplate;
	local InventoryLoadout					Loadout;

	SavedLoadout = GetCharacterPoolLoadout(UnitState);
	foreach SavedLoadout(SavedItem)
	{
		if (SavedItem.InventorySlot == eInvSlot_Armor)
		{
			return SavedItem.TemplateName;
		}
	}

	CharTemplate = UnitState.GetMyTemplate();
	if (CharTemplate != none)
	{
		UseLoadoutName = CharTemplate.DefaultLoadout;
	}
	SoldierClassTemplate = UnitState.GetSoldierClassTemplate();
	if (SoldierClassTemplate != none  && SoldierClassTemplate.SquaddieLoadout != '')
	{
		UseLoadoutName = SoldierClassTemplate.SquaddieLoadout;
	}
	if (UseLoadoutName == '')
		return 'KevlarArmor';

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach ItemTemplateManager.Loadouts(Loadout)
	{
		if (Loadout.LoadoutName == UseLoadoutName)
		{
			foreach Loadout.Items(LoadoutItem)
			{
				ArmorTemplate = X2ArmorTemplate(ItemTemplateManager.FindItemTemplate(LoadoutItem.Item));
				if (ArmorTemplate != none && ArmorTemplate.InventorySlot == eInvSlot_Armor)
				{
					return ArmorTemplate.DataName;
				}
			}
			return 'KevlarArmor';
		}
	}		

	return 'KevlarArmor';
}

final function array<CharacterPoolLoadoutStruct> GetCharacterPoolLoadout(const XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].CharacterPoolLoadout;
}
final function SetCharacterPoolLoadout(const XComGameState_Unit UnitState, array<CharacterPoolLoadoutStruct> CharacterPoolLoadout)
{
	CharacterPoolLoadout.Sort(SortCharacterPoolLoadout);
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].CharacterPoolLoadout = CharacterPoolLoadout;
	SaveCharacterPool();
}
final function AddItemToCharacterPoolLoadout(const XComGameState_Unit UnitState, const EInventorySlot InventorySlot, const name TemplateName)
{
	local array<CharacterPoolLoadoutStruct>	CharacterPoolLoadout;
	local CharacterPoolLoadoutStruct		LoadoutElement;
	local int	iMaxNumItems;
	local int	iNumItems;
	local int	ExtraDataIndex;
	local bool	bUpdateExistingItem;
	local bool	bItemUpdated;
	local int i;

	// This function needs to decide whether it wants to create a new loadout item or replace an existing one.
	// In case of regular slots, a new item replaces existing item, if any. If none exist, new item is added.
	// For multi-item slots, a new item replaces existing item if no more items can fit the slot. If there's still room, new item is added.

	`AMLOG(UnitState.GetFullName() @ InventorySlot @ TemplateName);

	ExtraDataIndex =  GetExtraDataIndexForUnit(UnitState);
	CharacterPoolLoadout = ExtraDatas[ExtraDataIndex].CharacterPoolLoadout;

	if (class'CHItemSlot'.static.SlotIsMultiItem(InventorySlot))
	{
		// Get max number of items that can fit into the slot.
		iMaxNumItems = class'CHItemSlot'.static.SlotGetMaxItemCount(InventorySlot, UnitState);

		// Calculate how many items are actually equipped.
		foreach CharacterPoolLoadout(LoadoutElement)
		{
			if (LoadoutElement.InventorySlot == InventorySlot) iNumItems++;
		}

		// If the slot is already at capacity, we tell it to replace the first item it can find in the slot.
		if (iNumItems >= iMaxNumItems)
		{
			`AMLOG("This multi item slot has no more room, will attempt to replace one of the existing items.");
			bUpdateExistingItem = true;
		}
	}
	else 
	{
		// If the slot only holds one item, then we always replace the existing item in the slot, duh.
		bUpdateExistingItem = true;
	}

	// Replace first item in the slot we can find.
	if (bUpdateExistingItem)
	{
		for (i = 0; i < CharacterPoolLoadout.Length; i++)
		{
			if (CharacterPoolLoadout[i].InventorySlot == InventorySlot)
			{	
				`AMLOG(i @ "Replacing existing item:" @ CharacterPoolLoadout[i].TemplateName);
				CharacterPoolLoadout[i].TemplateName = TemplateName;
				bItemUpdated = true;
				break;
			}
		}
	}

	// If the function was unable to update an existing item because it doesn't exist, we add one.
	if (!bItemUpdated)
	{
		`AMLOG("Adding new item into loadout.");
		LoadoutElement.InventorySlot = InventorySlot;
		LoadoutElement.TemplateName = TemplateName;
		CharacterPoolLoadout.AddItem(LoadoutElement);
	}

	CharacterPoolLoadout.Sort(SortCharacterPoolLoadout);
	ExtraDatas[ExtraDataIndex].CharacterPoolLoadout = CharacterPoolLoadout;
	SaveCharacterPool();
}

final function RemoveItemFromCharacterPoolLoadout(const XComGameState_Unit UnitState, const EInventorySlot InventorySlot, const name TemplateName)
{
	local array<CharacterPoolLoadoutStruct>	CharacterPoolLoadout;
	local int ExtraDataIndex;
	local int i;

	`AMLOG(UnitState.GetFullName() @ InventorySlot @ TemplateName);

	ExtraDataIndex = GetExtraDataIndexForUnit(UnitState);
	CharacterPoolLoadout = ExtraDatas[ExtraDataIndex].CharacterPoolLoadout;

	for (i = CharacterPoolLoadout.Length - 1; i >= 0; i--)
	{
		if (CharacterPoolLoadout[i].TemplateName == TemplateName &&
			CharacterPoolLoadout[i].InventorySlot == InventorySlot)
		{	
			CharacterPoolLoadout.Remove(i, 1);
			break;
		}
	}
	
	ExtraDatas[ExtraDataIndex].CharacterPoolLoadout = CharacterPoolLoadout;
	SaveCharacterPool();
}

// Sort loadout items by inventory slot, so that it goes Armor > Weapons > Rest.
private function int SortCharacterPoolLoadout(CharacterPoolLoadoutStruct LoadoutElementA, CharacterPoolLoadoutStruct LoadoutElementB)
{
	if (LoadoutElementA.InventorySlot > LoadoutElementB.InventorySlot) return 1;
	if (LoadoutElementA.InventorySlot < LoadoutElementB.InventorySlot) return -1;
	return 0;
}

final function array<CosmeticOptionStruct> GetCosmeticOptionsForUnit(const XComGameState_Unit UnitState, const string GenderArmorTemplate)
{
	local array<CosmeticOptionStruct> ReturnArray;
	local int SettingsIndex;
	local int Index;

	Index = GetExtraDataIndexForUnit(UnitState);
	SettingsIndex = ExtraDatas[Index].UniformSettings.Find('GenderArmorTemplate', GenderArmorTemplate);
	if (SettingsIndex != INDEX_NONE)
	{
		ReturnArray = ExtraDatas[Index].UniformSettings[SettingsIndex].CosmeticOptions;
	}
	
	return ReturnArray;
}

final function bool IsUnitNonSoldierUniformForCharTemplate(const XComGameState_Unit UnitState, const name CharTemplateName)
{
	local array<name> NonSoldierUniformTemplates;

	NonSoldierUniformTemplates = ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].NonSoldierUniformTemplates;

	`AMLOG(UnitState.GetFullName() @ "is for this many templates:" @ NonSoldierUniformTemplates.Length);

	return NonSoldierUniformTemplates.Find(CharTemplateName) != INDEX_NONE;
}
final function AddUnitNonSoldierUniformForCharTemplate(const XComGameState_Unit UnitState, const name CharTemplateName)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].NonSoldierUniformTemplates.AddItem(CharTemplateName);
	SaveCharacterPool();
}
final function RemoveUnitNonSoldierUniformForCharTemplate(const XComGameState_Unit UnitState, const name CharTemplateName)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].NonSoldierUniformTemplates.RemoveItem(CharTemplateName);
	SaveCharacterPool();
}

final function SaveCosmeticOptionsForUnit(const array<CosmeticOptionStruct> CosmeticOptions, const XComGameState_Unit UnitState, const string GenderArmorTemplate)
{
	local UniformSettingsStruct NewUniformSetting;
	local int SettingsIndex;
	local int Index;

	Index = GetExtraDataIndexForUnit(UnitState);
	
	SettingsIndex = ExtraDatas[Index].UniformSettings.Find('GenderArmorTemplate', GenderArmorTemplate);
	if (SettingsIndex != INDEX_NONE)
	{
		ExtraDatas[Index].UniformSettings[SettingsIndex].CosmeticOptions = CosmeticOptions;
	}
	else
	{
		NewUniformSetting.GenderArmorTemplate = GenderArmorTemplate;
		NewUniformSetting.CosmeticOptions = CosmeticOptions;
		ExtraDatas[Index].UniformSettings.AddItem(NewUniformSetting);
	}
	SaveCharacterPool();
}

// Called from X2EventListener_AM.
final function bool ShouldAutoManageUniform(const XComGameState_Unit UnitState)
{
	// The Unit Value checked by this function is set on the Unit when the Unit is created from Character Pool.
	switch (class'Help'.static.GetAutoManageUniformForUnitValue(UnitState))
	{
		case EAMUFU_Default:
			return `GETMCMVAR(AUTOMATIC_UNIFORM_MANAGEMENT);
		case EAMUFU_AlwaysOn:
			return true;
		case EAMUFU_AlwaysOff:
			return false;
		default:
			return false;
	}
}

// Direct copy of the original CreateSoldier() with the option to force specific gender. Used to save soldier appearance as uniform.
event XComGameState_Unit CreateSoldierForceGender(name DataTemplateName, optional EGender eForceGender)
{
	local XComGameState							SoldierContainerState;
	local XComGameState_Unit					NewSoldierState;	
	local X2CharacterTemplateManager			CharTemplateMgr;	
	local X2CharacterTemplate					CharacterTemplate;
	local TSoldier								CharacterGeneratorResult;
	local XGCharacterGenerator					CharacterGenerator;
	local XComGameStateHistory					History;
	local XComGameStateContext_ChangeContainer	ChangeContainer;

	CharTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	if (CharTemplateMgr == none)
	{
		`AMLOG("ERROR :: Failed to retrieve X2CharacterTemplateManager");
		return none;
	}

	CharacterTemplate = CharTemplateMgr.FindCharacterTemplate(DataTemplateName);	
	if (CharacterTemplate == none)
	{
		`AMLOG("ERROR :: Failed to find Character Template:" @ CharacterTemplate);
		return none;
	}

	CharacterGenerator = `XCOMGAME.Spawn(CharacterTemplate.CharacterGeneratorClass);
	if (CharacterGenerator == none)
	{
		`AMLOG("ERROR :: Failed to spawn CharacterGeneratorClass:" @ CharacterTemplate.CharacterGeneratorClass.Name @ "for Character Template:" @ CharacterTemplate);
		return none;
	}

	History = `XCOMHISTORY;
	
	//Create a game state to use for creating a unit
	ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Character Pool Manager");
	SoldierContainerState = History.CreateNewGameState(true, ChangeContainer);

	NewSoldierState = CharacterTemplate.CreateInstanceFromTemplate(SoldierContainerState);
	NewSoldierState.RandomizeStats();

	NewSoldierState.bAllowedTypeSoldier = true;

	CharacterGeneratorResult = CharacterGenerator.CreateTSoldier(DataTemplateName, eForceGender);
	NewSoldierState.SetTAppearance(CharacterGeneratorResult.kAppearance);
	NewSoldierState.SetCharacterName(CharacterGeneratorResult.strFirstName, CharacterGeneratorResult.strLastName, CharacterGeneratorResult.strNickName);
	NewSoldierState.SetCountry(CharacterGeneratorResult.nmCountry);
	class'XComGameState_Unit'.static.NameCheck(CharacterGenerator, NewSoldierState, eNameType_Full);

	NewSoldierState.GenerateBackground(, CharacterGenerator.BioCountryName);
	
	//Tell the history that we don't actually want this game state
	History.CleanupPendingGameState(SoldierContainerState);

	return NewSoldierState;
}

// ============================================================================================
// INTERNAL FUNCTIONS
/*
final function bool IsCharacterPoolCharacter(const XComGameState_Unit UnitState)
{
	local int Index;	

	// This check is primitive, but this is what the original Character Pool does to see if this CP unit is already in the campaign.
	for (Index = 0; Index < CharacterPool.Length; Index++)
	{
		if (UnitState.GetFullName() == CharacterPool[Index].GetFullName())
		{
			return true;
		}
	}

	return false;
}*/

private function int GetExtraDataIndexForUnit(const XComGameState_Unit UnitState)
{
	local XComGameState_Unit		PoolUnit;
	local CharacterPoolExtraData	ExtraData;
	local UnitValue					UV;
	local int Index;

	if (UnitState.GetUnitValue(ExtraDataValueName, UV))
	{
		// If this unit has Extra Data on record, then return index to it.
		Index = ExtraDatas.Find('ObjectID', int(UV.fValue));
		if (Index != INDEX_NONE)
		{
			return Index;
		}
	}

	// If not, then create it and return index to final member of the Extra Data array.
	Index = CharacterPool.Find(UnitState);
	if (Index != INDEX_NONE)
	{
		ExtraData.ObjectID = FindFreeExtraDataObjectID();
		ExtraDatas.AddItem(ExtraData);

		PoolUnit = CharacterPool[Index];
		PoolUnit.SetUnitFloatValue(ExtraDataValueName, ExtraData.ObjectID, eCleanup_Never);

		`AMLOG(UnitState.GetFullName() @ "ExtraData didn't exist and had to be created, new ObjectID:" @ ExtraData.ObjectID);
	
		return ExtraData.ObjectID;
	}
	`AMLOG("WARNING :: You are attempting to get ExtraData for a unit that's not in Character Pool! Don't do that!" @ UnitState.GetFullName() @ GetScriptTrace());
	return INDEX_NONE;
}

private function int FindFreeExtraDataObjectID()
{
	local int i;

	i = 0;
	do
	{
		i++;
	}
	until (ExtraDatas.Find('ObjectID', i) == INDEX_NONE);

	return i;
}

private function int GetExtraDataIndexForCharPoolData(const out CharacterPoolDataElement CharacterPoolData, optional const bool bCalledFromInitSoldier)
{
	local CharacterPoolExtraData	EmptyExtraData;
	local int						Index;

	Index = ExtraDatas.Find('CharPoolData', CharacterPoolData);
	if (Index != INDEX_NONE)
	{
		if (bCalledFromInitSoldier)
		{
			iNumExtraDataOnInit++;
		}
		return Index;
	}
	else
	{
		ExtraDatas.AddItem(EmptyExtraData);

		return ExtraDatas.Length - 1;
	}	
}
/*
private function PrintCPData(const out CharacterPoolDataElement CharacterPoolData)
{
	`AMLOG(`ShowVar(CharacterPoolData.strFirstName));
	`AMLOG(`ShowVar(CharacterPoolData.strLastName));
	`AMLOG(`ShowVar(CharacterPoolData.strNickName));
	`AMLOG(`ShowVar(CharacterPoolData.m_SoldierClassTemplateName));
	`AMLOG(`ShowVar(CharacterPoolData.CharacterTemplateName));
	`AMLOG(`ShowVar(CharacterPoolData.Country));
	`AMLOG(`ShowVar(CharacterPoolData.AllowedTypeSoldier));
	`AMLOG(`ShowVar(CharacterPoolData.AllowedTypeVIP));
	`AMLOG(`ShowVar(CharacterPoolData.AllowedTypeDarkVIP));
	`AMLOG(`ShowVar(CharacterPoolData.PoolTimestamp));
	`AMLOG(`ShowVar(CharacterPoolData.BackgroundText));
}*/

// ---------------------------------------------------------------------------
// UNIFORM FUNCTIONS
final function bool GetUniformAppearanceForUnit(out TAppearance NewAppearance, const XComGameState_Unit UnitState, const name ArmorTemplateName, optional bool bClassUniformOnly = false)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;
	
	UniformStates = GetClassSpecificUniforms(ArmorTemplateName, NewAppearance.iGender, UnitState.GetSoldierClassTemplateName());
	if (UniformStates.Length > 0)
	{
		UniformState = UniformStates[`SYNC_RAND(UniformStates.Length)];

		`AMLOG(UnitState.GetFullName() @ "selected random class uniform:" @ UniformState.GetFullName() @ "out of possible:" @ UniformStates.Length);

		CopyUniformAppearance(NewAppearance, UniformState, ArmorTemplateName);
		return true;		
	}

	if (bClassUniformOnly)
		return false;

	UniformStates = GetAnyClassUniforms(ArmorTemplateName, NewAppearance.iGender);
	if (UniformStates.Length > 0)
	{
		UniformState = UniformStates[`SYNC_RAND(UniformStates.Length)];

		`AMLOG(UnitState.GetFullName() @ "selected random non-class uniform:" @ UniformState.GetFullName() @ "out of possible:" @ UniformStates.Length);

		CopyUniformAppearance(NewAppearance, UniformState, ArmorTemplateName);
		return true;
	}

	return false;
}

private function array<XComGameState_Unit> GetClassSpecificUniforms(const name ArmorTemplateName, const int iGender, const name SoldierClass)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;

	foreach CharacterPool(UniformState)
	{
		if (GetUniformStatus(UniformState) == EUS_ClassSpecific && 
			UniformState.GetSoldierClassTemplateName() == SoldierClass && 
			UniformState.HasStoredAppearance(iGender, ArmorTemplateName))
		{
			`AMLOG(UniformState.GetFullName() @ "is class uniform for:" @ SoldierClass);
			UniformStates.AddItem(UniformState);
		}
		else `AMLOG(UniformState.GetFullName() @ "is NOT class uniform for:" @ SoldierClass @ "Uniform status:" @ GetEnum(enum'EUniformStatus', GetUniformStatus(UniformState)) @ "Soldier class:" @ UniformState.GetSoldierClassTemplateName() @ "Stored appearance:" @ UniformState.HasStoredAppearance(iGender, ArmorTemplateName));
	}
	return UniformStates;
}
private function array<XComGameState_Unit> GetAnyClassUniforms(const name ArmorTemplateName, const int iGender)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;

	foreach CharacterPool(UniformState)
	{
		if (GetUniformStatus(UniformState) == EUS_AnyClass &&
			UniformState.HasStoredAppearance(iGender, ArmorTemplateName))
		{
			`AMLOG(UniformState.GetFullName() @ "is a non-class uniform");
			UniformStates.AddItem(UniformState);
		}
	}
	return UniformStates;
}

final function bool GetUniformAppearanceForNonSoldier(out TAppearance NewAppearance, const XComGameState_Unit UnitState)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;
	local bool						bIgnoreGender;

	// You'd never tell, but apparently Bradford is a female at least sometimes. Using bForceAppearance.
	// Tygan doesn't have a gender at all... using bAppearanceDefinesPawn.
	bIgnoreGender = UnitState.GetMyTemplate().bForceAppearance || !UnitState.GetMyTemplate().bAppearanceDefinesPawn;
	
	UniformStates = GetNonSoldierUniformsForUnit(NewAppearance.iGender, UnitState, bIgnoreGender);
	if (UniformStates.Length > 0)
	{
		UniformState = UniformStates[`SYNC_RAND(UniformStates.Length)];

		`AMLOG(UnitState.GetFullName() @ "selected random class uniform:" @ UniformState.GetFullName() @ "out of possible:" @ UniformStates.Length);
		
		CopyUniformAppearance(NewAppearance, UniformState, NonSoldierUniformSettings, bIgnoreGender);
		return true;		
	}

	return false;
}

private function array<XComGameState_Unit> GetNonSoldierUniformsForUnit(const int iGender, const XComGameState_Unit UnitState, const bool bIgnoreGender)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;

	foreach CharacterPool(UniformState)
	{
		if (GetUniformStatus(UniformState) == EUS_NonSoldier &&
			(bIgnoreGender || UniformState.kAppearance.iGender == iGender) && 
			IsUnitNonSoldierUniformForCharTemplate(UniformState, UnitState.GetMyTemplateName()))
		{
			`AMLOG(UniformState.GetFullName() @ "is a non-soldier uniform for" @ UnitState.GetFullName() @ UniformState.kAppearance.iGender @ UnitState.GetMyTemplateName());
			UniformStates.AddItem(UniformState);
		}
		//else 
		//{
		//	if (UniformState.kAppearance.iGender != iGender)	
		//	{
		//		`AMLOG("Uniform:" @ UniformState.GetFullName() @ "Unit:" @ UnitState.GetFullName());
		//		`AMLOG("Uniform gender:" @ GetEnum(enum'EGender', UniformState.kAppearance.iGender) @ "given gender:" @ GetEnum(enum'EGender', iGender) @ "Unit state gender:" @ GetEnum(enum'EGender', UnitState.kAppearance.iGender));
		//	}		
		//	//`AMLOG(UniformState.GetFullName() @ "is a non-soldier uniform:" @ GetUniformStatus(UniformState) == EUS_NonSoldier @ "is gender match:" @ UniformState.kAppearance.iGender == iGender @ "is for char template:" @ IsUnitNonSoldierUniformForCharTemplate(UniformState, UnitState.GetMyTemplateName()));
		//}
	}
	return UniformStates;
}

private function CopyUniformAppearance(out TAppearance NewAppearance, const XComGameState_Unit UniformState, const name ArmorTemplateName, const optional bool bIgnoreGender)
{
	local TAppearance					UniformAppearance;
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local bool							bGenderChange;
	local string						GenderArmorTemplate;
	local EUniformStatus				UniformStatus;

	UniformStatus = GetUniformStatus(UniformState);
	if (UniformStatus == EUS_NonSoldier)
	{
		UniformAppearance = UniformState.kAppearance;
		CosmeticOptions = GetCosmeticOptionsForUnit(UniformState, string(NonSoldierUniformSettings));
	}
	else
	{
		UniformState.GetStoredAppearance(UniformAppearance, NewAppearance.iGender, ArmorTemplateName);
		GenderArmorTemplate = ArmorTemplateName $ NewAppearance.iGender;
		CosmeticOptions = GetCosmeticOptionsForUnit(UniformState, GenderArmorTemplate);
	}

	if (CosmeticOptions.Length > 0)
	{	
		if (bIgnoreGender || ShouldCopyUniformPiece('iGender', CosmeticOptions)) {bGenderChange = true;
																 NewAppearance.iGender = UniformAppearance.iGender; 
																 NewAppearance.nmPawn = UniformAppearance.nmPawn;
																 NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
																 NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
																 NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
		}
		if (bGenderChange || NewAppearance.iGender == UniformAppearance.iGender)
		{		
			if (ShouldCopyUniformPiece('nmHead', CosmeticOptions)) {NewAppearance.nmHead = UniformAppearance.nmHead; 
																	NewAppearance.nmEye = UniformAppearance.nmEye; 
																	NewAppearance.nmTeeth = UniformAppearance.nmTeeth; 
																	NewAppearance.iRace = UniformAppearance.iRace;}
			if (ShouldCopyUniformPiece('nmHaircut', CosmeticOptions)) NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
			if (ShouldCopyUniformPiece('nmBeard', CosmeticOptions)) NewAppearance.nmBeard = UniformAppearance.nmBeard;
			if (ShouldCopyUniformPiece('nmTorso', CosmeticOptions)) NewAppearance.nmTorso = UniformAppearance.nmTorso;
			if (ShouldCopyUniformPiece('nmArms', CosmeticOptions)) NewAppearance.nmArms = UniformAppearance.nmArms;
			if (ShouldCopyUniformPiece('nmLegs', CosmeticOptions)) NewAppearance.nmLegs = UniformAppearance.nmLegs;
			if (ShouldCopyUniformPiece('nmHelmet', CosmeticOptions)) NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
			if (ShouldCopyUniformPiece('nmFacePropLower', CosmeticOptions)) NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
			if (ShouldCopyUniformPiece('nmFacePropUpper', CosmeticOptions)) NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
			if (ShouldCopyUniformPiece('nmVoice', CosmeticOptions)) NewAppearance.nmVoice = UniformAppearance.nmVoice;
			if (ShouldCopyUniformPiece('nmScars', CosmeticOptions)) NewAppearance.nmScars = UniformAppearance.nmScars;
			if (ShouldCopyUniformPiece('nmFacePaint', CosmeticOptions)) NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
			if (ShouldCopyUniformPiece('nmLeftArm', CosmeticOptions)) NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
			if (ShouldCopyUniformPiece('nmRightArm', CosmeticOptions)) NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
			if (ShouldCopyUniformPiece('nmLeftArmDeco', CosmeticOptions)) NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
			if (ShouldCopyUniformPiece('nmRightArmDeco', CosmeticOptions)) NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
			if (ShouldCopyUniformPiece('nmLeftForearm', CosmeticOptions)) NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
			if (ShouldCopyUniformPiece('nmRightForearm', CosmeticOptions)) NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
			if (ShouldCopyUniformPiece('nmThighs', CosmeticOptions)) NewAppearance.nmThighs = UniformAppearance.nmThighs;
			if (ShouldCopyUniformPiece('nmShins', CosmeticOptions)) NewAppearance.nmShins = UniformAppearance.nmShins;
			if (ShouldCopyUniformPiece('nmTorsoDeco', CosmeticOptions)) NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
		}
		if (ShouldCopyUniformPiece('iHairColor', CosmeticOptions)) NewAppearance.iHairColor = UniformAppearance.iHairColor;
		if (ShouldCopyUniformPiece('iSkinColor', CosmeticOptions)) NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
		if (ShouldCopyUniformPiece('iEyeColor', CosmeticOptions)) NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
		if (ShouldCopyUniformPiece('nmFlag', CosmeticOptions)) NewAppearance.nmFlag = UniformAppearance.nmFlag;
		if (ShouldCopyUniformPiece('iAttitude', CosmeticOptions)) NewAppearance.iAttitude = UniformAppearance.iAttitude;
		if (ShouldCopyUniformPiece('iArmorTint', CosmeticOptions)) NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
		if (ShouldCopyUniformPiece('iArmorTintSecondary', CosmeticOptions)) NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
		if (ShouldCopyUniformPiece('iWeaponTint', CosmeticOptions)) NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
		if (ShouldCopyUniformPiece('iTattooTint', CosmeticOptions)) NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
		if (ShouldCopyUniformPiece('nmWeaponPattern', CosmeticOptions)) NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
		if (ShouldCopyUniformPiece('nmPatterns', CosmeticOptions)) NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
		if (ShouldCopyUniformPiece('nmTattoo_LeftArm', CosmeticOptions)) NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
		if (ShouldCopyUniformPiece('nmTattoo_RightArm', CosmeticOptions)) NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;

		//if (ShouldCopyUniformPiece('iArmorDeco', CosmeticOptions)) NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
		//if (ShouldCopyUniformPiece('nmLanguage', CosmeticOptions)) NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
		//if (ShouldCopyUniformPiece('bGhostPawn', CosmeticOptions)) NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
		//if (ShouldCopyUniformPiece('iFacialHair', CosmeticOptions)) NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
		//if (ShouldCopyUniformPiece('iVoice', CosmeticOptions)) NewAppearance.iVoice = UniformAppearance.iVoice;
	}
	else
	{
		class'UIManageAppearance'.static.CopyAppearance_Static(NewAppearance, UniformAppearance, 'PresetUniform');
	}
}

private function bool ShouldCopyUniformPiece(const name OptionName, const out array<CosmeticOptionStruct> CosmeticOptions)
{
	local int Index;

	Index = CosmeticOptions.Find('OptionName', OptionName);
	if (Index != INDEX_NONE)
	{
		return CosmeticOptions[Index].bChecked;
	}
	return false;
}

// ============================================================================
// SORTING FUNCTIONS

final function SortCharacterPoolBySoldierClass()
{
	CharacterPool.Sort(SortCharacterPoolBySoldierClassFn);
}

final function SortCharacterPoolBySoldierName()
{
	CharacterPool.Sort(SortCharacterPoolBySoldierNameFn);
}

final function SortCharacterPoolByUniformStatus()
{
	CharacterPool.Sort(SortCharacterPoolByUniformStatusFn);
}


private final function int SortCharacterPoolBySoldierNameFn(XComGameState_Unit UnitA, XComGameState_Unit UnitB)
{
	if (UnitA.GetFullName() < UnitB.GetFullName())
	{
		return 1;
	}
	else if (UnitA.GetFullName() > UnitB.GetFullName())
	{
		return -1;
	}
	return 0;
}

private final function int SortCharacterPoolBySoldierClassFn(XComGameState_Unit UnitA, XComGameState_Unit UnitB)
{
	local X2SoldierClassTemplate TemplateA;
	local X2SoldierClassTemplate TemplateB;

	TemplateA = UnitA.GetSoldierClassTemplate();
	TemplateB = UnitB.GetSoldierClassTemplate();

	// Put units without soldier class template below those with one.
	if (TemplateA == none)
	{
		if (TemplateB == none)
		{
			return 0;	
		}		
		else
		{
			return -1;
		}
	}
	else if (TemplateB == none)
	{
		return 1;
	}

	if (TemplateA.DisplayName == TemplateB.DisplayName)
	{
		return 0;
	}
	
	if (TemplateA.DataName == 'Rookie')
	{
		return 1;
	}
	if (TemplateB.DataName == 'Rookie')
	{
		return -1;
	}
	
	if (TemplateA.DisplayName < TemplateB.DisplayName)
	{
		return 1;
	}
	return -1;
}

private final function int SortCharacterPoolByUniformStatusFn(XComGameState_Unit UnitA, XComGameState_Unit UnitB)
{
	local EUniformStatus UniformStatusA; 
	local EUniformStatus UniformStatusB;

	UniformStatusA = GetUniformStatus(UnitA);
	UniformStatusB = GetUniformStatus(UnitB);

	if (UniformStatusA < UniformStatusB)
	{
		return 1;
	}
	else if (UniformStatusA > UniformStatusB)
	{
		return -1;
	}
	return 0;
}
