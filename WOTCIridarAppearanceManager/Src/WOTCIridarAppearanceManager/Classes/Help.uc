class Help extends Object abstract config(AppearanceManager_DEFAULT);

var config array<string> EmptyCosmeticPartialNames;

var private name AutoManageUniformForUnitValueName;

var localized string strCurrentAppearance;

var private config bool bIsUnrestrictedCustomizationLoaded;
var private config bool bIsUnrestrictedCustomizationLoadedChecked;

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


// Base game is pawn content request logic is hardcoded to not request certain body parts for clerks. 
// Also History doesn't exist in the Shell, so can't request UnitState.
static final function RequestFullPawnContentForClerk(XComGameState_Unit UnitState, XComHumanPawn HumanPawn, const out TAppearance m_kAppearance)
{
	local PawnContentRequest kRequest;
	//local XGUnit GameUnit;
	local name UnderlayName;
	local bool HasCustomUnderlay; // for issue #251	
	
	HasCustomUnderlay = class'CHHelpers'.default.CustomUnderlayCharTemplates.Find(UnitState.GetMyTemplateName()) != INDEX_NONE; 
	HumanPawn.bShouldUseUnderlay = HumanPawn.ShouldUseUnderlay(UnitState);

	//Underlay is the outfit that characters wear when they are in the background of the ship. It is a custom uni-body mesh that saves on mesh component draws and updates.
	UnderlayName = HumanPawn.GetUnderlayName(HumanPawn.bShouldUseUnderlay, m_kAppearance);		
	if (HasCustomUnderlay && UnderlayName != '') //issue #251 start
	{
		UnderlayName = m_kAppearance.nmTorso_Underlay;
	}
	// issue #251 end
	//GameUnit = XGUnit(GetGameUnit());
	//`log(self @ GetFuncName() @ `showvar(GameUnit) @ `showvar(m_bSetAppearance) @ `showvar(m_bSetArmorKit), , 'DevStreaming');

	HumanPawn.PawnContentRequests.Length = 0;
	HumanPawn.PatternsContent.Length = 0;

	//Order matters here, because certain pieces of content can affect other pieces of content. IE. a selected helmet can affect which mesh the hair uses, or disable upper or lower face props
	if ((!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmTorso != '') || (HumanPawn.bShouldUseUnderlay && UnderlayName != ''))
	{
		kRequest.ContentCategory = 'Torso';
		kRequest.TemplateName = HumanPawn.bShouldUseUnderlay ? UnderlayName : m_kAppearance.nmTorso;
		kRequest.BodyPartLoadedFn = HumanPawn.OnTorsoLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmTorsoDeco != '')
	{
		kRequest.ContentCategory = 'TorsoDeco';
		kRequest.TemplateName = m_kAppearance.nmTorsoDeco;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmHead != '')
	{
		kRequest.ContentCategory = 'Head';
		kRequest.TemplateName = m_kAppearance.nmHead;
		kRequest.BodyPartLoadedFn = HumanPawn.OnHeadLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	//Helmets can affect: beard, lower face prop, upper face prop, hair mesh
	if (m_kAppearance.nmHelmet != '')
	{
		kRequest.ContentCategory = 'Helmets';
		kRequest.TemplateName = m_kAppearance.nmHelmet;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	//Lower face props can affect: beard
	if (m_kAppearance.nmFacePropLower != '')
	{
		kRequest.ContentCategory = 'FacePropsLower';
		kRequest.TemplateName = m_kAppearance.nmFacePropLower;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmHaircut != '')
	{
		kRequest.ContentCategory = 'Hair';
		kRequest.TemplateName = m_kAppearance.nmHaircut;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmBeard != '')
	{
		kRequest.ContentCategory = 'Beards';
		kRequest.TemplateName = m_kAppearance.nmBeard;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmFacePropUpper != '')
	{
		kRequest.ContentCategory = 'FacePropsUpper';
		kRequest.TemplateName = m_kAppearance.nmFacePropUpper;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	// issue #251: allow arms underlay usage only when it's a custom underlay
	if ((!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmArms != '') || (HumanPawn.bShouldUseUnderlay && HasCustomUnderlay))
	{
		kRequest.ContentCategory = 'Arms';
		kRequest.TemplateName = HumanPawn.bShouldUseUnderlay ? m_kAppearance.nmArms_Underlay : m_kAppearance.nmArms;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmLeftArm != '')
	{
		kRequest.ContentCategory = 'LeftArm';
		kRequest.TemplateName = m_kAppearance.nmLeftArm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmRightArm != '')
	{
		kRequest.ContentCategory = 'RightArm';
		kRequest.TemplateName = m_kAppearance.nmRightArm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmLeftArmDeco != '')
	{
		kRequest.ContentCategory = 'LeftArmDeco';
		kRequest.TemplateName = m_kAppearance.nmLeftArmDeco;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmRightArmDeco != '')
	{
		kRequest.ContentCategory = 'RightArmDeco';
		kRequest.TemplateName = m_kAppearance.nmRightArmDeco;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmLeftForearm != '')
	{
		kRequest.ContentCategory = 'LeftForearm';
		kRequest.TemplateName = m_kAppearance.nmLeftForearm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmRightForearm != '')
	{
		kRequest.ContentCategory = 'RightForearm';
		kRequest.TemplateName = m_kAppearance.nmRightForearm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}
	// issue #251: allow legs underlay usage only when it's a custom underlay
	if ((!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmLegs != '') || (HumanPawn.bShouldUseUnderlay && HasCustomUnderlay))
	{
		kRequest.ContentCategory = 'Legs';
		kRequest.TemplateName = HumanPawn.bShouldUseUnderlay ? m_kAppearance.nmLegs_Underlay : m_kAppearance.nmLegs;
		kRequest.BodyPartLoadedFn = HumanPawn.OnLegsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmThighs != '')
	{
		kRequest.ContentCategory = 'Thighs';
		kRequest.TemplateName = m_kAppearance.nmThighs;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmShins != '')
	{
		kRequest.ContentCategory = 'Shins';
		kRequest.TemplateName = m_kAppearance.nmShins;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmEye != '')
	{
		kRequest.ContentCategory = 'Eyes';
		kRequest.TemplateName = m_kAppearance.nmEye;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmTeeth != '')
	{
		kRequest.ContentCategory = 'Teeth';
		kRequest.TemplateName = m_kAppearance.nmTeeth;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmPatterns != '')
	{
		kRequest.ContentCategory = 'Patterns';
		kRequest.TemplateName = m_kAppearance.nmPatterns;
		kRequest.BodyPartLoadedFn = HumanPawn.OnPatternsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmWeaponPattern != '')
	{
		kRequest.ContentCategory = 'Patterns';
		kRequest.TemplateName = m_kAppearance.nmWeaponPattern;
		kRequest.BodyPartLoadedFn = HumanPawn.OnPatternsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmTattoo_LeftArm != '')
	{
		kRequest.ContentCategory = 'Tattoos';
		kRequest.TemplateName = m_kAppearance.nmTattoo_LeftArm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnTattoosLoaded_LeftArm;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmTattoo_RightArm != '')
	{
		kRequest.ContentCategory = 'Tattoos';
		kRequest.TemplateName = m_kAppearance.nmTattoo_RightArm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnTattoosLoaded_RightArm;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmScars != '')
	{
		kRequest.ContentCategory = 'Scars';
		kRequest.TemplateName = m_kAppearance.nmScars;
		kRequest.BodyPartLoadedFn = HumanPawn.OnScarsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmFacePaint != '')
	{
		kRequest.ContentCategory = 'Facepaint';
		kRequest.TemplateName = m_kAppearance.nmFacePaint;
		kRequest.BodyPartLoadedFn = HumanPawn.OnFacePaintLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmVoice != '' && `TACTICALGRI != none) //Only load the voices for tactical. In strategy play them on demand
	{
		kRequest.ContentCategory = 'Voice';
		kRequest.TemplateName = m_kAppearance.nmVoice;
		kRequest.BodyPartLoadedFn = HumanPawn.OnVoiceLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	//  Make the requests later. If they come back synchronously, their callbacks will also happen synchronously, and it can throw things out of whack
	HumanPawn.MakeAllContentRequests();
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
	if (default.bIsUnrestrictedCustomizationLoadedChecked)
	{
		return default.bIsUnrestrictedCustomizationLoaded;
	}

	default.bIsUnrestrictedCustomizationLoadedChecked = true;
	default.bIsUnrestrictedCustomizationLoaded = IsModActive('UnrestrictedCustomization');

	return default.bIsUnrestrictedCustomizationLoaded;
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

static function string ColourText(string strValue, string strColour)
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