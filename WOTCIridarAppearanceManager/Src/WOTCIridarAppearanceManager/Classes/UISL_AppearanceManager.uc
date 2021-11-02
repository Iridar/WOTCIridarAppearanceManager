class UISL_AppearanceManager extends UIScreenListener;

`include(WOTCIridarAppearanceManager\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

delegate OnClickDelegate();
delegate OnButtonClickedCallback(UIButton ButtonSource);
delegate OnCheckboxChangedCallback(UICheckbox CheckboxControl);

event OnInit(UIScreen Screen)
{
	if (UICustomize_Menu(Screen) != none)
	{	 
		// When screen is initialized, list has no items yet, and our changes to it don't work right.
		Screen.SetTimer(0.05f, false, nameof(AddButtons), self);
	}
}

private function AddButtons()
{
	local UICustomize_Menu			CustomizeScreen;;
	local bool						bUnitIsUniform;
	local bool						bAutoManageUniform;
	local XComGameState_Unit		UnitState;
	local CharacterPoolManager_AM	CharPoolMgr;
	local UIMechaListItem			ListItem;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;
	
	CharPoolMgr = `CHARACTERPOOLMGRAM;
	if (CharPoolMgr == none)
		return;

	UnitState = CustomizeScreen.GetUnit();
	if (UnitState == none)
		return;

	if (CustomizeScreen.List.ItemCount == 0)
	{
		CustomizeScreen.SetTimer(0.25f, false, nameof(AddButtons), self); // If buttons list is still empty, reset the timer and exit.
		return;
	}

	bUnitIsUniform = CharPoolMgr.IsUnitUniform(UnitState);

	// ## Auto Manage Uniform toggle - always, but disabled if unit is a uniform.
	if (CustomizeScreen.bInArmory)
	{
		bAutoManageUniform = class'Help'.static.IsAutoManageUniformValueSet(UnitState);
	}
	else
	{
		bAutoManageUniform = CharPoolMgr.IsAutoManageUniform(UnitState);
	}
	if (`GETMCMVAR(AUTOMATIC_UNIFORM_MANAGEMENT))
	{
		ListItem = CreateOrUpdateCheckbox('IRI_AutoManageUniform_ListItem', CustomizeScreen, true, 
			"Disable automatic uniform management", bAutoManageUniform, OnAutoManageUniformCheckboxChanged); // TODO: Localize
	}
	else
	{
		ListItem = CreateOrUpdateCheckbox('IRI_AutoManageUniform_ListItem', CustomizeScreen, true, 
			"Enable automatic uniform management", bAutoManageUniform, OnAutoManageUniformCheckboxChanged); // TODO: Localize
	}
	if (ListItem != none) ListItem.SetDisabled(bUnitIsUniform);

	// ## Manage Appearance Button - always
	CreateOrUpdateListItem('IRI_ManageAppearance_ListItem', CustomizeScreen, true, 
		"Manage Appearance", OnManageAppearanceItemClicked); // TODO: Localize

	// ## Appearance Store Button - always
	CreateOrUpdateListItem('IRI_AppearanceStore_ListItem', CustomizeScreen, true, 
		"Appearance Store", OnAppearanceStoreItemClicked); // TODO: Localize

	if (!CustomizeScreen.bInArmory)
	{
		// ## Loadout Button - always while in Character Pool interface
		CreateOrUpdateListItem('IRI_Loadout_ListItem', CustomizeScreen, true, 
			"Loadout", OnLoadoutItemClicked); // TODO: Localize

		// ## Convert to Uniform / Convert to Soldier - always while in Character Pool interface
		if (bUnitIsUniform)
		{
			CreateOrUpdateButton('IRI_ConvertUniformSoldier_ListItem', CustomizeScreen, true, 
				"Convert to Soldier", "Convert", OnSoldierButtonClicked); // TODO: Localize
		}
		else
		{
			CreateOrUpdateButton('IRI_ConvertUniformSoldier_ListItem', CustomizeScreen, true, 
				"Convert to Uniform", "Convert", OnUniformButtonClicked); // TODO: Localize
		}
	}

		// ## Validate Appearance Button - if MCM is configured to not validate appearance automatically in the current game mode
	if (!`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_DEBUG) || 
		`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_REVIEW))
	{
		CreateOrUpdateButton('IRI_ValidateAppearance_ListItem', CustomizeScreen, true, 
				"Validate Appearance", "Validate", OnValidateButtonClicked); // TODO: Localize
	}

	// ## Configure Uniform Button - if the unit is uniform
	CreateOrUpdateListItem('IRI_ConfigureUniform_ListItem', CustomizeScreen, bUnitIsUniform, 
		"Configure Uniform", OnConfigureUniformItemClicked); // TODO: Localize
	
	CustomizeScreen.SetTimer(0.25f, false, nameof(AddButtons), self);
}

// ===================================================================
// ON CLICK METHODS

private function OnAutoManageUniformCheckboxChanged(UICheckbox CheckBox)
{
	local UICustomize_Menu			CustomizeScreen;
	local CharacterPoolManager_AM	CharPoolMgr;
	local XComGameState_Unit		UnitState;

	if (CheckBox.GetParent(class'UIMechaListItem').bDisabled)
			return;

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
	local UICustomize_Menu		CustomizeScreen;
	local XComGameState_Unit	UnitState;
	local X2CharacterTemplate	CharacterTemplate;
	local XGCharacterGenerator	CharGen;
	local string				strFirstName;
	local string				strLastName;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
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
	
	`CHARACTERPOOLMGRAM.SetIsUnitUniform(UnitState, false);
	
	CustomizeScreen.List.ClearItems();
	CustomizeScreen.UpdateData();
}

simulated private function OnUniformButtonClicked(UIButton ButtonSource)
{
	local UICustomize_Menu		CustomizeScreen;
	local XComGameState_Unit	UnitState;
	//local X2ItemTemplate		ItemTemplate;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	// TODO: Add a popup with confirmation prompt here

	UnitState = CustomizeScreen.CustomizeManager.UpdatedUnitState;
	if (UnitState == none)
		return;

	// Duh shouldn't use armor name in the unit name, since one unit can hold appearance for many armors
	//ItemTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(UnitState.kAppearance.nmTorso);

	UnitState.SetCharacterName("UNIFORM", class'Help'.static.GetFriendlyGender(UnitState.kAppearance.iGender), ""); // TODO: Localize

	UnitState.kAppearance.iAttitude = 0; // Set by the Book attitude so the soldier stops squirming.
	UnitState.UpdatePersonalityTemplate();
	UnitState.bAllowedTypeSoldier = false;
	UnitState.bAllowedTypeVIP = false;
	UnitState.bAllowedTypeDarkVIP = false;
	CustomizeScreen.CustomizeManager.CommitChanges();
	CustomizeScreen.CustomizeManager.ReCreatePawnVisuals(CustomizeScreen.CustomizeManager.ActorPawn, true);

	`CHARACTERPOOLMGRAM.SetIsUnitUniform(UnitState, true);

	CustomizeScreen.List.ClearItems();
	CustomizeScreen.UpdateData();	
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
}

// ===================================================================
// INTERNAL HELPERS

private function UIMechaListItem CreateOrUpdateListItem(const name MCName, UICustomize_Menu CustomizeScreen, bool bShouldShow, string strDesc, delegate<OnClickDelegate> OnListItemClicked)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(CustomizeScreen.List.ItemContainer.GetChildByName(MCName, false));
	if (ListItem != none) 
	{	
		if (bShouldShow)
		{
			if (!ListItem.bIsVisible) 
				ListItem.Show();

			// Update only when necessary to prevent UI flickering.
			if (ListItem.Desc.htmlText != strDesc || string(ListItem.OnClickDelegate) != string(OnListItemClicked))
				ListItem.UpdateDataDescription(strDesc, OnListItemClicked);
		}
		else
		{
			ListItem.Hide();
		}
	}
	else if (bShouldShow)
	{
		ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		ListItem.InitListItem(MCName).bAnimateOnInit = false;
		ListItem.UpdateDataDescription(strDesc, OnListItemClicked);
	}
	return ListItem;
}

private function UIMechaListItem CreateOrUpdateCheckbox(const name MCName, UICustomize_Menu CustomizeScreen, bool bShouldShow, string strDesc, bool bIsChecked, delegate<OnCheckboxChangedCallback> OnCheckboxChanged)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(CustomizeScreen.List.ItemContainer.GetChildByName(MCName, false));
	if (ListItem != none) 
	{	
		if (bShouldShow)
		{
			if (!ListItem.bIsVisible) 
				ListItem.Show();

			if (ListItem.Desc.htmlText != strDesc || ListItem.Checkbox.bChecked != bIsChecked || string(ListItem.Checkbox.onChangedDelegate) != string(OnCheckboxChanged))
				ListItem.UpdateDataCheckbox(strDesc, "", bIsChecked, OnCheckboxChanged);
		}
		else
		{
			ListItem.Hide();
		}
	}
	else if (bShouldShow)
	{
		ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		ListItem.InitListItem(MCName).bAnimateOnInit = false;
		ListItem.UpdateDataCheckbox(strDesc, "", bIsChecked, OnCheckboxChanged);
	}
	return ListItem;
}

private function UIMechaListItem CreateOrUpdateButton(const name MCName, UICustomize_Menu CustomizeScreen, bool bShouldShow, string strDesc, string strButtonLabel, delegate<OnButtonClickedCallback> OnButtonClicked)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(CustomizeScreen.List.ItemContainer.GetChildByName(MCName, false));
	if (ListItem != none) 
	{	
		if (bShouldShow)
		{
			if (!ListItem.bIsVisible) 
				ListItem.Show();

			if (ListItem.Desc.htmlText != strDesc || ListItem.Button.Text !=  strButtonLabel || string(ListItem.OnButtonClickedCallback) != string(OnButtonClicked))
				ListItem.UpdateDataButton(strDesc, strButtonLabel, OnButtonClicked);
		}
		else
		{
			ListItem.Hide();
		}
	}
	else if (bShouldShow)
	{
		ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		ListItem.InitListItem(MCName).bAnimateOnInit = false;
		ListItem.UpdateDataButton(strDesc, strButtonLabel, OnButtonClicked);
	}
	return ListItem;
}

// ----------------------------------------------------------------------

event OnReceiveFocus(UIScreen Screen)
{
	OnInit(Screen);
}

defaultproperties
{
	ScreenClass = none;
}