class Help extends Object abstract config(AppearanceManager_DEFAULT);

var config array<string> EmptyCosmeticPartialNames;

var private name AutoManageUniformForUnitValueName;

var localized string strCurrentAppearance;

`include(WOTCIridarAppearanceManager\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

static final function string GetUnitDisplayString(const XComGameState_Unit UnitState)
{
	local X2SoldierClassTemplate	ClassTemplate;
	local string					SoldierString;
	local string					strNickname;

	ClassTemplate = UnitState.GetSoldierClassTemplate();
	if (ClassTemplate != none)
	{
		SoldierString = ClassTemplate.DisplayName $ ": ";
	}

	// GetName(eNameType_FullNick) doesn't work so hot, since it adds unit's rank, which we don't need.
	SoldierString $= UnitState.GetFirstName();
	strNickname = UnitState.GetNickName();
	if (strNickname != "")
	{
		SoldierString @= strNickname;
	}
	SoldierString @= UnitState.GetLastName();
	
	return SoldierString;
}

final static function ApplySoldierNameColorBasedOnUniformStatus(out string strDisplayName, const EUniformStatus UniformStatus)
{
	switch (UniformStatus)
	{
		case EUS_Manual:
			strDisplayName = class'Help'.static.GetHTMLColoredText(strDisplayName, class'UIUtilities_Colors'.const.SCIENCE_HTML_COLOR); // Blue
			break;
		case EUS_AnyClass:
			strDisplayName = class'Help'.static.GetHTMLColoredText(strDisplayName, class'UIUtilities_Colors'.const.GOOD_HTML_COLOR); // Green
			break;
		case EUS_ClassSpecific:
			strDisplayName = class'Help'.static.GetHTMLColoredText(strDisplayName, class'UIUtilities_Colors'.const.WARNING_HTML_COLOR); // Yellow
			break;
		case EUS_NonSoldier:
			strDisplayName = class'Help'.static.GetHTMLColoredText(strDisplayName, class'UIUtilities_Colors'.const.BAD_HTML_COLOR); // Red
			break;
		default:
			break;
	}
}

static final function string GetHTMLColoredText(string txt, string HTML_Color, optional int fontSize = -1, optional string align)
{
	local string retTxt, prefixTxt;

	if(Len(txt) == 0) return txt;

	if(align != "")
		prefixTxt $=  "<p align='"$align$"'>";

	if(fontSize > 0)
		prefixTxt $= "<font size='" $ fontSize $ "' color='#";
	else
		prefixTxt $= "<font color='#";

	prefixTxt $= HTML_Color;

	prefixTxt $= "'>";
	retTxt = prefixTxt $txt$"</font>";

	if(align != "")
		retTxt $= "</p>";

	return retTxt;
}

static final function name GetArmorTemplateNameFromCharacterPoolLoadout(const array<CharacterPoolLoadoutStruct> CharacterPoolLoadout)
{
	local CharacterPoolLoadoutStruct LoadoutElement;

	foreach CharacterPoolLoadout(LoadoutElement)
	{
		if (LoadoutElement.InventorySlot == eInvSlot_Armor)
		{
			return LoadoutElement.TemplateName;
		}
	}
	return '';
}

static final function name GetEquippedArmorTemplateName(const XComGameState_Unit UnitState, optional CharacterPoolManager_AM CharPoolMgr)
{
	local array<CharacterPoolLoadoutStruct>	CharacterPoolLoadout;
	local XComGameState_Item				ItemState;
	
	if (IsInStrategy())
	{
		ItemState = UnitState.GetItemInSlot(eInvSlot_Armor);
		if (ItemState != none)
		{
			return ItemState.GetMyTemplateName();
		}
	}
	else
	{
		if (CharPoolMgr == none)
		{
			CharPoolMgr = `CHARACTERPOOLMGRAM;
		}
		if (CharPoolMgr != none)
		{
			CharacterPoolLoadout = CharPoolMgr.GetCharacterPoolLoadout(UnitState);
			return class'Help'.static.GetArmorTemplateNameFromCharacterPoolLoadout(CharacterPoolLoadout);
		}
	}
	return '';
}

static final function bool IsInStrategy()
{
	return `HQGAME  != none && `HQPC != None && `HQPRES != none;
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


static final function int GetAutoManageUniformForUnitValue(const XComGameState_Unit UnitState)
{
	local UnitValue UV;

	UnitState.GetUnitValue(default.AutoManageUniformForUnitValueName, UV);

	return UV.fValue;
}

static final function SetAutoManageUniformForUnitValue_SubmitGameState(XComGameState_Unit UnitState, int NewValue)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(GetFuncName() @ UnitState.GetFullName() @ NewValue);
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
	UnitState.SetUnitFloatValue(default.AutoManageUniformForUnitValueName, NewValue, eCleanup_Never);
	`GAMERULES.SubmitGameState(NewGameState);
}

static final function SetAutoManageUniformForUnitValue(XComGameState_Unit UnitState, int NewValue)
{
	UnitState.SetUnitFloatValue(default.AutoManageUniformForUnitValueName, NewValue, eCleanup_Never);
}

static final function X2ItemTemplate GetItemTemplateFromCosmeticTorso(const name nmTorso)
{
	local name						ArmorTemplateName;
	local X2BodyPartTemplate		ArmorPartTemplate;
	local X2BodyPartTemplateManager BodyPartMgr;
	local X2ItemTemplateManager		ItemMgr;
	local X2ItemTemplate			ItemTemplate;

	`AMLOG("Running for" @ `showvar(nmTorso));
	`AMLOG(GetScriptTrace());

	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	ArmorPartTemplate = BodyPartMgr.FindUberTemplate("Torso", nmTorso);
	`AMLOG("Found ArmorPartTemplate:" @ ArmorPartTemplate.DataName @ ArmorPartTemplate.ArmorTemplate);
	if (ArmorPartTemplate != none)
	{
		ArmorTemplateName = ArmorPartTemplate.ArmorTemplate;
		`AMLOG(`showvar(ArmorTemplateName));
		if (ArmorTemplateName != '')
		{
			ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
			ItemTemplate = ItemMgr.FindItemTemplate(ArmorTemplateName);
			`AMLOG("Found armor template:" @ ItemTemplate.DataName);
			return ItemTemplate;
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
	if (Appearance.nmLeftArm != '' && Appearance.nmRightArm != '') Appearance.nmArms = '';
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

// Sound managers don't exist in Shell, have to do it by hand.
static final function PlayStrategySoundEvent(string strKey, Actor InActor)
{
	local string	SoundEventPath;
	local AkEvent	SoundEvent;

	foreach class'XComStrategySoundManager'.default.SoundEventPaths(SoundEventPath)
	{
		if (InStr(SoundEventPath, strKey) != INDEX_NONE)
		{
			SoundEvent = AkEvent(`CONTENT.RequestGameArchetype(SoundEventPath));
			if (SoundEvent != none)
			{
				InActor.WorldInfo.PlayAkEvent(SoundEvent);
				return;
			}
		}
	}
}

static final function bool IsAppearanceValidationDisabled()
{	
	return !`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_DEBUG) || `XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_REVIEW);
}

static function string ColourText (string strValue, string strColour)
{
	return "<font color='#" $ strColour $ "'>" $ strValue $ "</font>";
}

defaultproperties
{
	AutoManageUniformForUnitValueName = "IRI_AutoManageUniform_Value"
}

// Unused stuff below
/*
simulated private function string GetColorFriendlyText(coerce string strText, LinearColor ParamColor)
{
	return "<font color='#" $ GetHTMLColor(ParamColor) $ "'>" $ strText $ "</font>";
}
*/