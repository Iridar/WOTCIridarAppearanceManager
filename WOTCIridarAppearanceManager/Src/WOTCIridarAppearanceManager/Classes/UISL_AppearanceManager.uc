class UISL_AppearanceManager extends UIScreenListener;

var localized string strUseForAutoManageUniform;
var localized string strDisableAutoManageUniform;
var localized string strEnableAutoManageUniform;
var localized string strManageAppearance;
var localized string strStoredAppearance;
var localized string strConvertButtonTitle;
var localized string strConverToUniform;
var localized string strConvertToSoldier;
var localized string strVadlidateAppearance;
var localized string strVadlidateAppearanceButton;
var localized string strConfigureUniform;
var localized string strUniformSoldierFirstName;
var localized string strConvertToUniformPopupTitle;
var localized string strConvertToUniformPopupText;

`include(WOTCIridarAppearanceManager\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

delegate OnClickDelegate();
delegate OnButtonClickedCallback(UIButton ButtonSource);
delegate OnCheckboxChangedCallback(UICheckbox CheckboxControl);

event OnInit(UIScreen Screen)
{
	if (UICustomize_Menu(Screen) != none)
	{	 
		// When screen is initialized, list has no items yet, so need to wait for the list to init.
		UICustomize_Menu(Screen).List.AddOnInitDelegate(OnListInited);
	}
}

simulated function OnListInited(UIPanel Panel)
{
	AddButtons();
}

event OnReceiveFocus(UIScreen Screen)
{
	if (UICustomize_Menu(Screen) != none)
	{	 
		AddButtons();
	}
}

private function AddButtons()
{
	local UICustomize_Menu			CustomizeScreen;;
	local bool						bUnitIsUniform;
	local bool						bAutoManageUniform;
	local XComGameState_Unit		UnitState;
	local CharacterPoolManager_AM	CharPoolMgr;
	local int						ListIndex;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none) 
		return;
	
	CharPoolMgr = `CHARACTERPOOLMGRAM;
	if (CharPoolMgr == none) 
		return;

	UnitState = CustomizeScreen.GetUnit();
	if (UnitState == none) 
		return;

	// Check if "Manage Appearance" list item already exists and is visible - then we don't know need to do anything else.
	if (!ChangesAlreadyMade(CustomizeScreen.List))
	{
		bUnitIsUniform = CharPoolMgr.IsUnitUniform(UnitState);
		if (bUnitIsUniform) 
			RemoveCanAppearAsListItems(CustomizeScreen);

		ListIndex = GetIndexOfLastVisibleListItem(CustomizeScreen.List) + 1;

		// ## Loadout Button - while in Character Pool interface.
		if (!CustomizeScreen.bInArmory)
		{
			CreateOrUpdateListItem(ListIndex, CustomizeScreen, 
				class'UIArmory_MainMenu'.default.m_strLoadout, OnLoadoutItemClicked);
		}

		if (CustomizeScreen.bInArmory)
		{
			bAutoManageUniform = class'Help'.static.IsAutoManageUniformValueSet(UnitState);
		}
		else
		{
			bAutoManageUniform = CharPoolMgr.IsAutoManageUniform(UnitState);
		}

		// ## Auto Manage Uniform toggle - always.
		if (bUnitIsUniform)
		{
			CreateOrUpdateCheckbox(ListIndex, CustomizeScreen, 
				strUseForAutoManageUniform, bAutoManageUniform, OnAutoManageUniformCheckboxChanged);
		}
		else if (`GETMCMVAR(AUTOMATIC_UNIFORM_MANAGEMENT))
		{
			CreateOrUpdateCheckbox(ListIndex, CustomizeScreen, 
				strDisableAutoManageUniform, bAutoManageUniform, OnAutoManageUniformCheckboxChanged);
		}
		else
		{
			CreateOrUpdateCheckbox(ListIndex, CustomizeScreen, 
				strEnableAutoManageUniform, bAutoManageUniform, OnAutoManageUniformCheckboxChanged);
		}

		// ## Manage Appearance Button - always
		CreateOrUpdateListItem(ListIndex, CustomizeScreen, 
			strManageAppearance, OnManageAppearanceItemClicked);

		// ## Appearance Store Button - always
		CreateOrUpdateListItem(ListIndex, CustomizeScreen, 
			strStoredAppearance, OnAppearanceStoreItemClicked);

		if (!CustomizeScreen.bInArmory)
		{
			// ## Convert to Uniform / Convert to Soldier - always while in Character Pool interface
			if (bUnitIsUniform)
			{
				CreateOrUpdateButton(ListIndex, CustomizeScreen, 
					strConvertToSoldier, strConvertButtonTitle, OnSoldierButtonClicked);
			}
			else
			{
				CreateOrUpdateButton(ListIndex, CustomizeScreen, 
					strConverToUniform, strConvertButtonTitle, OnUniformButtonClicked);
			}
		}

			// ## Validate Appearance Button - if MCM is configured to not validate appearance automatically in the current game mode
		if (!`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_DEBUG) || 
			`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_REVIEW))
		{
			CreateOrUpdateButton(ListIndex, CustomizeScreen, 
					strVadlidateAppearance, strVadlidateAppearanceButton, OnValidateButtonClicked);
		}

		// ## Configure Uniform Button - if the unit is uniform
		if (bUnitIsUniform)
		{
			CreateOrUpdateListItem(ListIndex, CustomizeScreen, 
				strConfigureUniform, OnConfigureUniformItemClicked);
		}
	}
	
	// Unfortunately have to keep timer ticking in case UpdateData() is called in CustomizeScreen.
	CustomizeScreen.SetTimer(0.25f, false, nameof(AddButtons), self);
}

private function bool ChangesAlreadyMade(UIList List)
{	
	local UIMechaListItem ListItem;
	local int i;

	for (i = List.ItemCount - 1; i >= 0; i--)
	{
		ListItem = UIMechaListItem(List.GetItem(i));
		if (ListItem.Desc.htmlText == strManageAppearance)
		{
			return ListItem.bIsVisible;
		}
		
	}
	return false;
}

private function int GetIndexOfLastVisibleListItem(UIList List)
{
	local int i;

	for (i = List.ItemCount - 1; i >= 0; i--)
	{
		if (List.GetItem(i).bIsVisible)
			return i;
	}
	return INDEX_NONE;
}

// Get rid of "can appear as" toggles for non-uniforms.
private function RemoveCanAppearAsListItems(UICustomize_Menu CustmozeMenu)
{
	local UIMechaListItem ListItem;
	local int i;

	for (i = CustmozeMenu.List.ItemCount - 1; i >= 0; i--)
	{	
		ListItem = UIMechaListItem(CustmozeMenu.List.GetItem(i));
		if (ListItem == none) continue;

		if (ListItem.Checkbox != none && ListItem.Desc.htmlText == CustmozeMenu.m_strAllowTypeSoldier)
		{
			CustmozeMenu.List.ItemContainer.RemoveChild(ListItem);
		}
		if (ListItem.Checkbox != none && ListItem.Desc.htmlText == CustmozeMenu.m_strAllowTypeVIP)
		{	
			CustmozeMenu.List.ItemContainer.RemoveChild(ListItem);
		}
		if (ListItem.Checkbox != none && ListItem.Desc.htmlText == CustmozeMenu.m_strAllowTypeDarkVIP)
		{
			CustmozeMenu.List.ItemContainer.RemoveChild(ListItem);
		}
	}
}

// ===================================================================
// ON CLICK METHODS

private function OnAutoManageUniformCheckboxChanged(UICheckbox CheckBox)
{
	local UICustomize_Menu			CustomizeScreen;
	local CharacterPoolManager_AM	CharPoolMgr;
	local XComGameState_Unit		UnitState;

	//if (UIMechaListItem(CheckBox.GetParent(class'UIMechaListItem')).bDisabled)
	//{
	//	CheckBox.SetChecked(false, false);
	//	return;
	//}

	CustomizeScreen = UICustomize_Menu(CheckBox.Screen);
	if (CustomizeScreen == none)
		return;

	UnitState = CustomizeScreen.GetUnit();
	if (UnitState == none)
		return;

	CharPoolMgr = `CHARACTERPOOLMGRAM;
	if (CharPoolMgr == none)
		return;

	if (CustomizeScreen.bInArmory)
	{
		SetIsAutoManageUniform(UnitState, CheckBox.bChecked);
	}
	else
	{
		CharPoolMgr.SetIsAutoManageUniform(UnitState, CheckBox.bChecked);
	}
}

private function SetIsAutoManageUniform(XComGameState_Unit UnitState, const bool bValue)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(GetFuncName() @ UnitState.GetFullName() @ bValue);

	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
	if (bValue)
	{
		UnitState.SetUnitFloatValue(class'Help'.default.AutoManageUniformValueName, 1.0f, eCleanup_Never);
	}
	else
	{
		UnitState.ClearUnitValue(class'Help'.default.AutoManageUniformValueName);
	}
	`GAMERULES.SubmitGameState(NewGameState);
}

private function OnManageAppearanceItemClicked()
{
	local UIManageAppearance		CustomizeScreen;
	local XComPresentationLayerBase	Pres;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`AMLOG("ERROR :: No PresBase:" @ Pres == none @ "or no ScreenStack:" @  Pres.ScreenStack == none @ ", exiting.");
		return;
	}

	CustomizeScreen = Pres.Spawn(class'UIManageAppearance', Pres);
	Pres.ScreenStack.Push(CustomizeScreen);
	CustomizeScreen.UpdateData();
}

private function OnAppearanceStoreItemClicked()
{
	local UIAppearanceStore			CustomizeScreen;
	local XComPresentationLayerBase	Pres;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`AMLOG("ERROR :: No PresBase:" @ Pres == none @ "or no ScreenStack:" @  Pres.ScreenStack == none @ ", exiting.");
		return;
	}

	CustomizeScreen = Pres.Spawn(class'UIAppearanceStore', Pres);
	Pres.ScreenStack.Push(CustomizeScreen);
	CustomizeScreen.UpdateData();
}

private function OnConfigureUniformItemClicked()
{
	local UIManageAppearance_Uniform	CustomizeScreen;
	local XComPresentationLayerBase		Pres;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`AMLOG("ERROR :: No PresBase:" @ Pres == none @ "or no ScreenStack:" @  Pres.ScreenStack == none @ ", exiting.");
		return;
	}

	CustomizeScreen = Pres.Spawn(class'UIManageAppearance_Uniform', Pres);
	Pres.ScreenStack.Push(CustomizeScreen);
	CustomizeScreen.UpdateData();
}

private function OnLoadoutItemClicked()
{
	local UICustomize_Menu				CustomizeScreen;
	local XComPresentationLayerBase		Pres;
	local UIArmory_Loadout_CharPool		ArmoryScreen;
	local XComGameState_Unit			UnitState;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`AMLOG("ERROR :: No PresBase:" @ Pres == none @ "or no ScreenStack:" @  Pres.ScreenStack == none @ ", exiting.");
		return;
	}

	CustomizeScreen = UICustomize_Menu(Pres.ScreenStack.GetCurrentScreen());
	if (CustomizeScreen == none)
	{
		return;
	}

	UnitState = CustomizeScreen.GetUnit(); 
	if (UnitState == none)
		return;

	ArmoryScreen = Pres.Spawn(class'UIArmory_Loadout_CharPool', Pres);
	Pres.ScreenStack.Push(ArmoryScreen);
	ArmoryScreen.CustomizationManager = Pres.GetCustomizeManager();
	ArmoryScreen.InitArmory(UnitState.GetReference());
}

simulated private function OnSoldierButtonClicked(UIButton ButtonSource)
{
	local UICustomize_Menu			CustomizeScreen;
	local XComGameState_Unit		UnitState;
	local X2CharacterTemplate		CharacterTemplate;
	local XGCharacterGenerator		CharGen;
	local string					strFirstName;
	local string					strLastName;
	local CharacterPoolManager_AM	CharPoolMgr;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	CharPoolMgr = `CHARACTERPOOLMGRAM;
	if (CharPoolMgr == none)
		return;

	UnitState = CustomizeScreen.CustomizeManager.UpdatedUnitState;
	if (UnitState == none)
		return;

	CharacterTemplate = UnitState.GetMyTemplate();
	if (CharacterTemplate == none)
		return;

	CharGen = `XCOMGRI.Spawn(CharacterTemplate.CharacterGeneratorClass);	
	if (CharGen == none)
		return;
	
	// Give soldier an appropriate random name
	CharGen.GenerateName(UnitState.kAppearance.iGender, UnitState.kAppearance.nmFlag, strFirstName, strLastName, UnitState.kAppearance.iRace);

	// Firaxis noodle code in faction soldier chargens makes it necessary
	if (strFirstName == "")
		strFirstName = CharGen.kSoldier.strFirstName;

	if (strLastName == "")
		strLastName = CharGen.kSoldier.strLastName;

	UnitState.SetCharacterName(strFirstName, strLastName, CharGen.kSoldier.strNickName);
	CustomizeScreen.CustomizeManager.CommitChanges();
	
	CharPoolMgr.SetIsAutoManageUniform(UnitState, false);
	CharPoolMgr.SetIsUnitUniform(UnitState, false);
	
	CustomizeScreen.List.ClearItems();
	CustomizeScreen.UpdateData();

	// If we relied on the existing timer for AddButtons() after doing UpdateData(),
	// there would be a visible delay between the list updating and the new buttons being added.
	// So we want to call AddButtons() immediately, but it would set a second timer, 
	// so to prevent timer-ception, first remove the existing timer.l
	CustomizeScreen.ClearTimer(nameof(AddButtons), self);
	AddButtons();
}

private function OnUniformButtonClicked(UIButton ButtonSource)
{
	local TDialogueBoxData kDialogData;

	kDialogData.eType = eDialog_Normal;
	kDialogData.strTitle = strConvertToUniformPopupTitle;
	kDialogData.strText = strConvertToUniformPopupText;
	kDialogData.strAccept = class'UISimpleScreen'.default.m_strAccept;
	kDialogData.strCancel = class'UISimpleScreen'.default.m_strCancel;
	kDialogData.fnCallback = OnUniformButtonCallback;
	`PRESBASE.UIRaiseDialog(kDialogData);
}

private function OnUniformButtonCallback(Name eAction)
{
	local UICustomize_Menu			CustomizeScreen;
	local XComGameState_Unit		UnitState;
	local CharacterPoolManager_AM	CharPoolMgr;

	if (eAction != 'eUIAction_Accept')
		return;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	CharPoolMgr = `CHARACTERPOOLMGRAM;
	if (CharPoolMgr == none)
		return;

	UnitState = CustomizeScreen.CustomizeManager.UpdatedUnitState;
	if (UnitState == none)
		return;

	UnitState.SetCharacterName(strUniformSoldierFirstName, class'Help'.static.GetFriendlyGender(UnitState.kAppearance.iGender), "");

	UnitState.kAppearance.iAttitude = 0; // Set by the Book attitude so the soldier stops squirming.
	UnitState.UpdatePersonalityTemplate();

	UnitState.bAllowedTypeSoldier = false;
	UnitState.bAllowedTypeVIP = false;
	UnitState.bAllowedTypeDarkVIP = false;
	CustomizeScreen.CustomizeManager.CommitChanges();
	CustomizeScreen.CustomizeManager.ReCreatePawnVisuals(CustomizeScreen.CustomizeManager.ActorPawn, true);

	CharPoolMgr.SetIsAutoManageUniform(UnitState, true); 
	CharPoolMgr.SetIsUnitUniform(UnitState, true);
	
	CustomizeScreen.List.ClearItems();
	CustomizeScreen.UpdateData();	

	CustomizeScreen.ClearTimer(nameof(AddButtons), self);
	AddButtons();
}

private function OnValidateButtonClicked(UIButton ButtonSource)
{
	local XComGameState_Unit			UnitState;
	local UICustomize_Menu				CustomizeScreen;
	local CharacterPoolManager_AM		CharPool;
	//local XComGameState_Item			ItemState;
	local TAppearance					FixAppearance;
	local int i;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	UnitState = CustomizeScreen.CustomizeManager.UpdatedUnitState;
	if (UnitState == none)
		return;

	CharPool = `CHARACTERPOOLMGRAM;
	if (CharPool == none)
		return;

	`AMLOG(UnitState.GetFullName());

	// Validate current appearance
	CharPool.ValidateUnitAppearance(CustomizeScreen.CustomizeManager.UpdatedUnitState);	

	// Validate appearance store, remove entries that could not be validated
	for (i = UnitState.AppearanceStore.Length - 1; i >= 0; i--)
	{
		FixAppearance = UnitState.AppearanceStore[i].Appearance;
		if (CharPool.FixAppearanceOfInvalidAttributes(FixAppearance))
		{
			`AMLOG("Successfully validated Appearance Store entry for Gender Armor:" @ UnitState.AppearanceStore[i].GenderArmorTemplate @ ", it required no changes:" @ FixAppearance == UnitState.AppearanceStore[i].Appearance);
			UnitState.AppearanceStore[i].Appearance = FixAppearance;
		}
		else
		{
			`AMLOG("Failed to validate Appearance Store entry for Gender Armor:" @ UnitState.AppearanceStore[i].GenderArmorTemplate @ ", removing it");
			UnitState.AppearanceStore.Remove(i, 1);
		}
	}

	//ItemState = CustomizeScreen.CustomizeManager.UpdatedUnitState.GetItemInSlot(eInvSlot_Armor);
	//if (ItemState != none)
	//{
	//	CustomizeScreen.CustomizeManager.UpdatedUnitState.StoreAppearance(, ItemState.GetMyTemplateName());
	//}
	//else CustomizeScreen.CustomizeManager.UpdatedUnitState.StoreAppearance();

	CustomizeScreen.CustomizeManager.CommitChanges();
	CustomizeScreen.CustomizeManager.ReCreatePawnVisuals(CustomizeScreen.CustomizeManager.ActorPawn, true);
	CustomizeScreen.UpdateData();

	CustomizeScreen.ClearTimer(nameof(AddButtons), self);
	AddButtons();
}

// ===================================================================
// INTERNAL HELPERS

private function CreateOrUpdateListItem(out int ListIndex, UICustomize_Menu CustomizeScreen, string strDesc, delegate<OnClickDelegate> OnListItemClicked)
{
	local UIMechaListItem ListItem;

	ListItem = CustomizeScreen.GetListItem(ListIndex++);

	// Update only when necessary to prevent UI flickering.
	if (ListItem.Desc.htmlText != strDesc || string(ListItem.OnClickDelegate) != string(OnListItemClicked))
	{
		ListItem.UpdateDataDescription(strDesc, OnListItemClicked);
	}

	ListItem.Show();
}

private function CreateOrUpdateCheckbox(out int ListIndex, UICustomize_Menu CustomizeScreen, string strDesc, bool bIsChecked, delegate<OnCheckboxChangedCallback> OnCheckboxChanged)
{
	local UIMechaListItem ListItem;

	ListItem = CustomizeScreen.GetListItem(ListIndex++);

	if (ListItem.Desc.htmlText != strDesc || ListItem.Checkbox.bChecked != bIsChecked || string(ListItem.Checkbox.onChangedDelegate) != string(OnCheckboxChanged))
	{
		ListItem.UpdateDataCheckbox(strDesc, "", bIsChecked, OnCheckboxChanged);
	}

	ListItem.Show();
}

private function CreateOrUpdateButton(out int ListIndex, UICustomize_Menu CustomizeScreen, string strDesc, string strButtonLabel, delegate<OnButtonClickedCallback> OnButtonClicked)
{
	local UIMechaListItem ListItem;

	ListItem = CustomizeScreen.GetListItem(ListIndex++);
	if (ListItem.Desc.htmlText != strDesc || ListItem.Button.Text !=  strButtonLabel || string(ListItem.OnButtonClickedCallback) != string(OnButtonClicked))
	{
		ListItem.UpdateDataButton(strDesc, strButtonLabel, OnButtonClicked);
	}

	ListItem.Show();
}

// ----------------------------------------------------------------------


defaultproperties
{
	ScreenClass = none;
}