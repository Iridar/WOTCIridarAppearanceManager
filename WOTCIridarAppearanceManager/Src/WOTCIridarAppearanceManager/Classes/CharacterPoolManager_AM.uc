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

struct UniformSettingsStruct
{
	var string GenderArmorTemplate; // Same as in the AppearanceStore. These uniform options are for this armor and gender.
	var array<CosmeticOptionStruct> CosmeticOptions;
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
	var bool bIsUniform;		// Whether this unit is a uniform.
	var bool bIsAnyClassUniform;// Whether this unit's appearance can be applied to any soldier class, or only the matching ones.
	var bool bAutoManageUniform;// Universal flag. 
								// If this unit is a uniform, then they will be considered by the automated Uniform Manager only if this flag is set to true.
								// This allows having uniforms that can be used only by the player manually. 
								// If this unit is NOT a uniform, and:
								// If automatic uniform management is enabled in MCM, then if this flag is 'true', this unit will be excluded from uniform management.
								// If automatic uniform management is disabled in MCM, then if this flag is 'true', this unit will receive uniform management.
};
var array<CharacterPoolExtraData> ExtraDatas;

`include(WOTCIridarAppearanceManager\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)
`define XOR(a, b) !`a && `b || `a && !`b

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
	if (!`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_DEBUG) || 
		`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_REVIEW))
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


final function bool IsUnitUniform(XComGameState_Unit UnitState) 
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].bIsUniform;
}
final function bool IsUnitAnyClassUniform(XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].bIsAnyClassUniform;
}
final function bool IsAutoManageUniform(XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].bAutoManageUniform;
}
final function SetIsUnitUniform(XComGameState_Unit UnitState, bool bValue)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].bIsUniform = bValue;
	SaveCharacterPool();
}
final function SetIsUnitAnyClassUniform(XComGameState_Unit UnitState, bool bValue)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].bIsAnyClassUniform = bValue;
	SaveCharacterPool();
}
final function SetIsAutoManageUniform(const XComGameState_Unit UnitState, const bool bValue)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].bAutoManageUniform = bValue;
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
	// If MCM setting of global uniform management is NOT enabled, we want to manage this unit's uniform if the flag on the unit IS set.
	// If MCM setting of global uniform management IS enabled, we want to mange this unit's uniform if the flag on the unit is NOT set.
	// Which boils down to "exclusive OR" logical operation.
	return `XOR(`GETMCMVAR(AUTOMATIC_UNIFORM_MANAGEMENT), IsAutoManageUniformFlagSet(UnitState));
}

// ============================================================================================
// INTERNAL FUNCTIONS

private function bool IsAutoManageUniformFlagSet(const XComGameState_Unit UnitState)
{
	if (IsCharacterPoolCharacter(UnitState))
	{
		return IsAutoManageUniform(UnitState);
	}
	return class'Help'.static.IsAutoManageUniformValueSet(UnitState);
}

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
		if (IsUnitUniform(UniformState) && 
			IsAutoManageUniform(UniformState) && // Only Auto Manage Uniforms are used for the automated system.
			!IsUnitAnyClassUniform(UniformState) && 
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
		if (IsUnitUniform(UniformState) && 
			IsAutoManageUniform(UniformState) &&
			IsUnitAnyClassUniform(UniformState) &&
			UniformState.HasStoredAppearance(iGender, ArmorTemplateName))
		{
			`AMLOG(UniformState.GetFullName() @ "is a non-class uniform");
			UniformStates.AddItem(UniformState);
		}
	}
	return UniformStates;
}


private function CopyUniformAppearance(out TAppearance NewAppearance, const XComGameState_Unit UniformState, const name ArmorTemplateName)
{
	local TAppearance					UniformAppearance;
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local bool							bGenderChange;
	local string						GenderArmorTemplate;

	UniformState.GetStoredAppearance(UniformAppearance, NewAppearance.iGender, ArmorTemplateName);

	GenderArmorTemplate = ArmorTemplateName $ NewAppearance.iGender;
	CosmeticOptions = GetCosmeticOptionsForUnit(UniformState, GenderArmorTemplate);
	
	if (CosmeticOptions.Length > 0)
	{	
		if (ShouldCopyUniformPiece('iGender', CosmeticOptions)) {bGenderChange = true;
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