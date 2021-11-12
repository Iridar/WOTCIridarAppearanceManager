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
	EAMUMU_AlwaysOff	// Never auto apply uniforms to this unit.
};

enum EUniformStatus
{
	EUS_NotUniform,		// This unit is not a uniform.
	EUS_Manual,			// This uniform will be disregarded by the automated uniform manager.
	EUS_AnyClass,		// This uniform will be automatically applied to soldiers of any class.
	EUS_ClassSpecific,	// This uniform will be auto applied only to soldiers of the same class.
	EUS_NonSoldier		// This uniform will be auto applied to non-soldier units, like resistance militia. Separate button is displayed to select which units, exactly.
};

struct CharacterPoolExtraData
{
	// Used to sync Extra Data with specific UnitStates while the game is in play.
	// It will end up being saved in the Character Pool file, even though we don't need it there.
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

const NonSoldierUniformSettings = 'NonSoldierUniformSettings';

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
	if (!class'Help'.static.IsAppearanceValidationDisabled())
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

	`AMLOG("Loading Extra Data for" @ Unit.GetFullName());

	// Use Character Pool Data to locate saved Extra Data for this unit.
	// Save unit's ObjectID in Extra Data so we can find it later when we will be saving the Character Pool into the .bin file, 
	// as well as if we need to change some Extra Data property for this unit.
	Index = GetExtraDataIndexForCharPoolData(CharacterPoolData);
	ExtraDatas[Index].ObjectID = Unit.ObjectID;

	// Read actual Extra Data.
	Unit.AppearanceStore = ExtraDatas[Index].AppearanceStore;
}

function SaveCharacterPool()
{
	local XComGameState_Unit UnitState;
	local int Index;

	foreach CharacterPool(UnitState)
	{
		`AMLOG("Saving Extra Data for" @ UnitState.GetFullName());

		// Use unit's Object ID to locate Extra Data for this unit.
		// Save unit's Character Pool Data in Extra Data so we can find it later when we will be loading the Character Pool from the .bin file.
		FillCharacterPoolData(UnitState); // This writes info about Unit State into 'CharacterPoolSerializeHelper'.
		Index = GetExtraDataIndexForUnit(UnitState);
		ExtraDatas[Index].CharPoolData = CharacterPoolSerializeHelper;

		// Save actual Extra Data.
		ExtraDatas[Index].AppearanceStore = UnitState.AppearanceStore;
	}

	super.SaveCharacterPool();
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
	local int Index;

	super.RemoveUnit(Character);

	// Remove stored Extra Data for this unit, if there is any.
	// Not using GetExtraDataIndexForUnit() here, since it would create Extra Data if it doesn't exist, which we don't need.
	Index = ExtraDatas.Find('ObjectID', Character.ObjectID);
	if (Index != INDEX_NONE)
	{
		ExtraDatas.Remove(Index, 1);
	}
}

function XComGameState_Unit CreateCharacter(XComGameState StartState, optional ECharacterPoolSelectionMode SelectionModeOverride = eCPSM_None, optional name CharacterTemplateName, optional name ForceCountry, optional string UnitName )
{
	local XComGameState_Unit UnitState;

	UnitState = super.CreateCharacter(StartState, SelectionModeOverride, CharacterTemplateName, ForceCountry, UnitName);

	// Newly created units' AutoManageUniformForUnit flag should be the same as the eponymous setting in character pool.
	if (IsCharacterPoolCharacter(UnitState))
	{
		class'Help'.static.SetAutoManageUniformForUnitValue(UnitState, GetAutoManageUniformForUnit(UnitState));
	}	

	return UnitState;
}

// ============================================================================================
// INTERFACE FUNCTIONS 

// Helper method that fixes unit's appearance if they have bodyparts from mods that are not currently active.
simulated final function ValidateUnitAppearance(XComGameState_Unit UnitState)
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


final function EUniformStatus GetUniformStatus(XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].UniformStatus;
}

final function SetUniformStatus(const XComGameState_Unit UnitState, const EUniformStatus eValue)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].UniformStatus = eValue;
	SaveCharacterPool();
}

final function EAutoManageUniformForUnit GetAutoManageUniformForUnit(XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].AutoManageUniformForUnit;
}
final function SetAutoManageUniformForUnit(const XComGameState_Unit UnitState, const int eValue)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].AutoManageUniformForUnit = EAutoManageUniformForUnit(eValue);
	SaveCharacterPool();
}

final function array<CharacterPoolLoadoutStruct> GetCharacterPoolLoadout(const XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].CharacterPoolLoadout;
}
final function UpdateCharacterPoolLoadout(const XComGameState_Unit UnitState, const EInventorySlot InventorySlot, const name TemplateName)
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
			`AMLOG("No more room in this multi item slot, should replace other item");
			bUpdateExistingItem = true;
		}
	}
	else 
	{
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
		`AMLOG("Adding new item into loadout");
		LoadoutElement.InventorySlot = InventorySlot;
		LoadoutElement.TemplateName = TemplateName;
		CharacterPoolLoadout.AddItem(LoadoutElement);
	}

	ExtraDatas[ExtraDataIndex].CharacterPoolLoadout = CharacterPoolLoadout;
	SaveCharacterPool();
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
	switch (GetAutoManageUniformForUnit(UnitState))
	{
		case EAMUFU_Default:
			return `GETMCMVAR(AUTOMATIC_UNIFORM_MANAGEMENT);
		case EAMUFU_AlwaysOn:
			return true;
		case EAMUMU_AlwaysOff:
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
}

private function int GetExtraDataIndexForUnit(XComGameState_Unit UnitState)
{
	local CharacterPoolExtraData ExtraData;
	local int Index;

	// If this unit has Extra Data on record, then return index to it.
	Index = ExtraDatas.Find('ObjectID', UnitState.ObjectID);
	if (Index != INDEX_NONE)
	{
		return Index;
	}
	else
	{
		// If not, then create it and return index to final member of the Extra Data array.
		ExtraData.ObjectID = UnitState.ObjectID;
		ExtraDatas.AddItem(ExtraData);

		return ExtraDatas.Length - 1;
	}	
}

private function int GetExtraDataIndexForCharPoolData(const out CharacterPoolDataElement CharacterPoolData)
{
	local CharacterPoolExtraData ExtraData;
	local int Index;

	Index = ExtraDatas.Find('CharPoolData', CharacterPoolData);
	if (Index != INDEX_NONE)
	{
		return Index;
	}
	else
	{
		ExtraDatas.AddItem(ExtraData);

		return ExtraDatas.Length - 1;
	}	
}

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
	
	UniformStates = GetNonSoldierUniformsForUnit(NewAppearance.iGender, UnitState);
	if (UniformStates.Length > 0)
	{
		UniformState = UniformStates[`SYNC_RAND(UniformStates.Length)];

		`AMLOG(UnitState.GetFullName() @ "selected random class uniform:" @ UniformState.GetFullName() @ "out of possible:" @ UniformStates.Length);
		
		CopyUniformAppearance(NewAppearance, UniformState, NonSoldierUniformSettings, UnitState.GetMyTemplate().bForceAppearance);
		return true;		
	}

	return false;
}

private function array<XComGameState_Unit> GetNonSoldierUniformsForUnit(const int iGender, const XComGameState_Unit UnitState)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;

	foreach CharacterPool(UniformState)
	{
		if (GetUniformStatus(UniformState) == EUS_NonSoldier &&
			(UniformState.kAppearance.iGender == iGender || UnitState.GetMyTemplate().bForceAppearance) && // You'd never tell, but apparently Bradford is a female at least sometimes. 
			IsUnitNonSoldierUniformForCharTemplate(UniformState, UnitState.GetMyTemplateName()))
		{
			`AMLOG(UniformState.GetFullName() @ "is a non-soldier uniform for" @ UnitState.GetFullName() @ UniformState.kAppearance.iGender @ UnitState.GetMyTemplateName());
			UniformStates.AddItem(UniformState);
		}
		else 
		{
			if (UniformState.kAppearance.iGender != iGender)	
			{
				`AMLOG("Uniform:" @ UniformState.GetFullName() @ "Unit:" @ UnitState.GetFullName());
				`AMLOG("Uniform gender:" @ GetEnum(enum'EGender', UniformState.kAppearance.iGender) @ "given gender:" @ GetEnum(enum'EGender', iGender) @ "Unit state gender:" @ GetEnum(enum'EGender', UnitState.kAppearance.iGender));
			}		
			//`AMLOG(UniformState.GetFullName() @ "is a non-soldier uniform:" @ GetUniformStatus(UniformState) == EUS_NonSoldier @ "is gender match:" @ UniformState.kAppearance.iGender == iGender @ "is for char template:" @ IsUnitNonSoldierUniformForCharTemplate(UniformState, UnitState.GetMyTemplateName()));
		}
	}
	return UniformStates;
}

private function CopyUniformAppearance(out TAppearance NewAppearance, const XComGameState_Unit UniformState, const name ArmorTemplateName, const optional bool bForceAppearance)
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
		if (ShouldCopyUniformPiece('iGender', CosmeticOptions)) {bGenderChange = true;
																 NewAppearance.iGender = UniformAppearance.iGender; 
																 NewAppearance.nmPawn = UniformAppearance.nmPawn;
																 NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
																 NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
																 NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
		}
		if (bGenderChange || NewAppearance.iGender == UniformAppearance.iGender || UniformStatus == EUS_NonSoldier && bForceAppearance)
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