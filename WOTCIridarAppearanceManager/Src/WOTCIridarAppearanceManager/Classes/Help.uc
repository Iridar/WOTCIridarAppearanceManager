class Help extends Object abstract config(AppearanceManager_DEFAULT);

var config array<string> EmptyCosmeticPartialNames;

var name AutoManageUniformValueName;

static final function string GetUnitDisplayString(const XComGameState_Unit UnitState)
{
	local X2SoldierClassTemplate	ClassTemplate;
	local string					SoldierString;

	ClassTemplate = UnitState.GetSoldierClassTemplate();
	if (ClassTemplate != none)
	{
		SoldierString = ClassTemplate.DisplayName $ ": ";
	}

	SoldierString $= UnitState.GetFirstName();

	if (UnitState.GetNickName() != "")
	{
		SoldierString @= "\"" $ UnitState.GetNickName() $ "\"";
	}

	SoldierString @= UnitState.GetLastName();
	
	return SoldierString;
}

static final function string GetFriendlyGender(int iGender)
{
	local EGender EnumGender;

	EnumGender = EGender(iGender);

	switch (EnumGender)
	{
	case eGender_Male:
		return class'XComCharacterCustomization'.default.Gender_Male;
	case eGender_Female:
		return class'XComCharacterCustomization'.default.Gender_Female;
	default:
		return class'UIPhotoboothBase'.default.m_strEmptyOption;
	}
}


static final function bool IsAutoManageUniformValueSet(const XComGameState_Unit UnitState)
{
	local UnitValue UV;

	return UnitState.GetUnitValue(default.AutoManageUniformValueName, UV);
}

static final function X2ItemTemplate GetItemTemplateFromCosmeticTorso(const name nmTorso)
{
	local name						ArmorTemplateName;
	local X2BodyPartTemplate		ArmorPartTemplate;
	local X2BodyPartTemplateManager BodyPartMgr;
	local X2ItemTemplateManager		ItemMgr;

	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	ArmorPartTemplate = BodyPartMgr.FindUberTemplate("Torso", nmTorso);
	if (ArmorPartTemplate != none)
	{
		ArmorTemplateName = ArmorPartTemplate.ArmorTemplate;
		if (ArmorTemplateName != '')
		{
			ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
			return ItemMgr.FindItemTemplate(ArmorTemplateName);
		}
	}
	return none;
}

static final function bool IsUnrestrictedCustomizationLoaded()
{
	return IsModActive('UnrestrictedCustomization');
}

static final function bool IsModActive(name ModName)
{
    local XComOnlineEventMgr    EventManager;
    local int                   Index;

    EventManager = `ONLINEEVENTMGR;

    for (Index = EventManager.GetNumDLC() - 1; Index >= 0; Index--) 
    {
        if (EventManager.GetDLCNames(Index) == ModName) 
        {
            return true;
        }
    }
    return false;
}

static final function bool IsAppearanceCurrent(TAppearance TestAppearance, TAppearance CurrentAppearance)
{
	// These parts of the appearance may end up with both '_Blank' entry and just simply be empty.
	// Have to equalize these before we can do a direct comparison.
	EqualizeAppearance(TestAppearance);
	EqualizeAppearance(CurrentAppearance);

	return TestAppearance == CurrentAppearance;
}

static final function EqualizeAppearance(out TAppearance Appearance)
{
	if (Appearance.nmScars == '') Appearance.nmScars = 'Scars_BLANK';
	if (Appearance.nmBeard == '') Appearance.nmBeard = 'MaleBeard_Blank';
	if (Appearance.nmTattoo_LeftArm == '') Appearance.nmTattoo_LeftArm = 'Tattoo_Arms_BLANK';
	if (Appearance.nmTattoo_RightArm == '') Appearance.nmTattoo_RightArm = 'Tattoo_Arms_BLANK';
	if (Appearance.nmHaircut == '') Appearance.nmHaircut = 'FemHair_Blank';
	if (Appearance.nmHaircut == '') Appearance.nmHaircut = 'MaleHair_Blank';
	if (Appearance.nmFacePropLower == '') Appearance.nmFacePropLower = 'Prop_FaceLower_Blank';
	if (Appearance.nmFacePropUpper == '') Appearance.nmFacePropUpper = 'Prop_FaceUpper_Blank';
	if (Appearance.nmFacePaint == '') Appearance.nmFacePaint = 'Facepaint_BLANK';
}

static final function bool IsCosmeticEmpty(coerce string Cosmetic)
{
	local string CheckString;

	if (Cosmetic == "" || Cosmetic == "None")
		return true;

	foreach default.EmptyCosmeticPartialNames(CheckString)
	{
		//`CPOLOG(`showvar(Cosmetic) @ `showvar(CheckString));
		if (InStr(Cosmetic, CheckString,, true) != INDEX_NONE) // Ignore case
			return true;
	}
	return false;
}

defaultproperties
{
	AutoManageUniformValueName = "IRI_AutoManageUniform_Value"
}