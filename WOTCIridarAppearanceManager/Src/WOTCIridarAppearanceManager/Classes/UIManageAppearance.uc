class UIManageAppearance extends UICustomize;

// TODO:
/*
# Priority

Militia uniforms and raider factions: expand the list of character types in character pool (the one where you select soldier\spark\reaper\skirmisher\templar).

Save modlist in CP files, and warn if mods are missing.

Use UITextContainer to add a vertical scrollbar to biography text

# Character Pool
Fix weapons / Dual Wielding not working in CP?
Search bar for CP units?
Sorting buttons for CP units?

Fix wrong unit being opened in CP sometimes. (Has to do with deleting units?)
-- Apparently the problem is the CP opens the unit you had selected when the interface раздупляется, а не тот юнит по которому кликал. Это ваниллы проблема. Можно пофиксить, наверное

# This screen

Make clicking an item toggle its checkbox?

## Checks:
1. Check if you can customize a unit with all armors in the campaign, then save them into CP, and that they will actually have all that appearance in the next campaign
2. Working with character pool files: creating new one, creating (importing) an existing one, deleting. exporting/importing units with appearance store.
3. Test automatic uniform managemennt settings. 

## Finalization
1. Polish localization

## Addressed

Maybe allow Appearance Store button to work as a "reskin armor" button? - redundant, can be done with this mod's customization screen by importing unit's own appearance from another armor.

## Ideas for later

Uniforms for resistance fighters

Investigate customizing off-duty (Underlay?) appearance.

Make GetApplyChangesNumUnits() take into account gender of the targeted soldier, as depending on selected cosmetic options they may not receive any changes.

AU units with custom rookie class should be able to choose from different classes in CP
I have no idea how they coded that, but it would appear that they stem from a separate species specific rookie template, then get a class independently, while the game properly treats them as rookies, allowing them to train in GTS. however in the character pool there is no option to change their class, which is an issue for anyone using the "use my class" mod

When copying biography, automatically update soldier name and country (MCM toggle)
Equipping weapons in CP will reskin them automatically with XSkin (RustyDios). Probably use a Tuple.

Enter Character Pool from Armory. Seems to be generally working, but has lots of weird behavior: 
incorrect soldier attitude, incorrect stance, legs getting IK'd to the armory floor, Loadout screen softlocking the game when exiting from it.

Enter photobooth from CP. Looks like it would require reworking a lot of the PB's functionality, since it relies on StateObjectReferences for units, which won't work for CP.
*/

enum ECosmeticType
{
	ECosmeticType_Name,
	ECosmeticType_Int,
	ECosmeticType_GenderInt,
	ECosmeticType_Biography
};

var localized string strApplyTo;
var localized string strApplyChangesButton;
var localized string strApplyToThisUnit;
var localized string strApplyToThisUnitTip;
var localized string strApplyToSquadTip;
var localized string strApplyToBarracksTip;
var localized string strApplyToCPTip;
var localized string strFiltersTitle;
var localized string strSelectAppearanceTitle;
var localized string strSearchTitle;
var localized string strNoArmorTemplateError;
var localized string strOriginalAppearance;
var localized string strUniformsTitle;
var localized string strExitScreenPopupTitle;
var localized string strExitScreenPopupText;
var localized string strExitScreenPopup_Leave;
var localized string strExitScreenPopup_Stay;
var localized string strShowAllOptions;
var localized string strCopyPreset;
var localized string strCopyPresetButtonDisabled;
var localized string strNotAvailableInCharacterPool;
var localized string strSameGenderRequired;
var localized string strConfirmApplyChangesTitle;
var localized string strConfirmApplyChangesText;
var localized string strCreatePreset;
var localized string strCreatePresetTitle;
var localized string strCreatePresetText;
var localized string strDuplicatePresetDisallowedText;
var localized string strDuplicatePresetDisallowedTitle;
var localized string strSaveAsUniform;
var localized string strEnterUniformName;
var localized string strFailedToCreateUnitTitle;
var localized string strFailedToCreateUnitText;
var localized string strInvalidEmptyUniformNameTitle;
var localized string strInvalidEmptyUniformNameText;
var localized string strDeletePreset;
var localized string strCannotDeleteThisPreset;

// ==============================================================================
// Screen Options - preserved between game restarts.
var config(AppearanceManager) array<CheckboxPresetStruct> CheckboxPresets;
var config(AppearanceManager) array<name> Presets;
var protected config(AppearanceManager) bool bShowPresets;
var protected config(AppearanceManager) bool bShowCharPoolSoldiers;
var protected config(AppearanceManager) bool bShowUniformSoldiers;
var protected config(AppearanceManager) bool bShowBarracksSoldiers;
var protected config(AppearanceManager) bool bShowDeadSoldiers;
var protected config(AppearanceManager) bool bShowAllCosmeticOptions;
var protected config(AppearanceManager) bool bInitComplete;

// ==============================================================================
// Screen Options - not preserver between game restarts.
var protected bool		bShowCategoryHead;
var protected bool		bShowCategoryBody;
var protected bool		bShowCategoryTattoos;
var protected bool		bShowCategoryArmorPattern;
var protected bool		bShowCategoryWeaponPattern;
var protected bool		bShowCategoryPersonality;
var protected name		CurrentPreset;
var protected string	SearchText;
var protected bool		bCanExitWithoutPopup; // If "false", player will receive a confirmation popup before they can exit the screen. Set to "false" every time player changes anything about unit's appearance.

// ==============================================================================
// Cached Data - Managers, assigned on screen init.
var protected CharacterPoolManager_AM			PoolMgr;
var protected X2BodyPartTemplateManager			BodyPartMgr;
var protected X2StrategyElementTemplateManager	StratMgr;
var protected X2ItemTemplateManager				ItemMgr;
var protected UIPawnMgr							PawnMgr;
var protected XComGameStateHistory				History;

// ==============================================================================
// Cached Data - Selected Unit (Appearance)
var protected TAppearance					SelectedAppearance;
var protected X2SoldierPersonalityTemplate	SelectedAttitude;
var protected XComGameState_Unit			SelectedUnit;
var protected bool							bOriginalAppearanceSelected;

// ==============================================================================
// Cached Data - Armory Unit
var protected XComHumanPawn					ArmoryPawn;
var protected XComGameState_Unit			ArmoryUnit;
var protected vector						OriginalPawnLocation;
var protected TAppearance					OriginalAppearance; // Appearance to restore if the player exits the screen without selecting anything
var protected TAppearance					PreviousAppearance; // Briefly cached appearance, used to check if we need to refresh pawn
var protected name							ArmorTemplateName;
var protected X2SoldierPersonalityTemplate	OriginalAttitude;

// ==============================================================================
// UI Elements - Cosmetic Options list on the left.
var protected UIBGBox	OptionsListBG;
var protected UIList	OptionsList;

// ==============================================================================
// UI Elements - Filters List in the upper right corner.
var protected UIBGBox	FiltersListBG;
var protected UIList	FiltersList;

var protected UIBGBox	AppearanceListBG;
var protected UIList	AppearanceList;

`include(WOTCIridarAppearanceManager\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

// ================================================================================================================================================
// INITIAL SETUP - called once when screen is pushed, or when switching to a new armory unit.

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local UIScreen	   CycleScreen;
	local UIMouseGuard MouseGuard;

	super.InitScreen(InitController, InitMovie, InitName);

	// Cache stuff.
	PoolMgr = `CHARACTERPOOLMGRAM;
	if (PoolMgr == none)
		super.CloseScreen();

	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	PawnMgr = Movie.Pres.GetUIPawnMgr();
	History = `XCOMHISTORY;
	CacheArmoryUnitData();

	// In UICustomize, 'List' is of menu items under the soldier header.
	// We repurpose it as a list of appearances you can copy and move it to the right.
	AppearanceList = List;
	AppearanceListBG = ListBG;

	AppearanceList.OnItemClicked = AppearanceListItemClicked;
	AppearanceList.SetPosition(1920 - AppearanceList.Width - 70, 360);
	AppearanceList.SetHeight(300);

	AppearanceListBG.SetPosition(1920 - AppearanceList.Width - 80, 345);
	AppearanceListBG.SetHeight(730);

	// Mouse guard dims the entire screen when this UIScreen is spawned, not sure why.
	// Setting it to 3D seems to fix it. cc Xymanek
	foreach Movie.Pres.ScreenStack.Screens(CycleScreen)
	{
		MouseGuard = UIMouseGuard(CycleScreen);
		if (MouseGuard == none)
			continue;

		MouseGuard.bIsIn3D = true;
		MouseGuard.SetAlpha(0);
	}

	// Move the soldier name header further into the left upper corner.
	Header.SetPosition(20 + Header.Width, 20);
	
	// Create left list	of soldier customization options.
	OptionsListBG = Spawn(class'UIBGBox', self).InitBG('LeftOptionsListBG', 20, 180);
	OptionsListBG.SetAlpha(80);
	OptionsListBG.SetWidth(582);
	OptionsListBG.SetHeight(1080 - 70 - OptionsListBG.Y);

	OptionsList = Spawn(class'UIList', self);
	OptionsList.bAnimateOnInit = false;
	OptionsList.InitList('LeftOptionsList', 30, 190);
	OptionsList.SetWidth(542);
	OptionsList.SetHeight(1080 - 80 - OptionsList.Y);
	OptionsList.Navigator.LoopSelection = true;
	OptionsList.OnItemClicked = OptionsListItemClicked;
	
	OptionsListBG.ProcessMouseEvents(AppearanceList.OnChildMouseEvent);

	// Create upper right list
	CreateFiltersList();

	if (class'Help'.static.IsUnrestrictedCustomizationLoaded())
	{
		`AMLOG("Unrestricted Customization compatibility: setting timer.");
		SetTimer(0.1f, false, nameof(FixScreenPosition), self);
	}
}

private function CacheArmoryUnitData()
{
	local X2ItemTemplate ArmorTemplate;

	bOriginalAppearanceSelected = true;

	ArmoryUnit = CustomizeManager.UpdatedUnitState;
	if (ArmoryUnit == none)
		super.CloseScreen();

	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn == none)
		super.CloseScreen();

	ArmorTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(ArmoryPawn.m_kAppearance.nmTorso);
	if (ArmorTemplate != none)
	{
		ArmorTemplateName = ArmorTemplate.DataName;
	}

	SelectedUnit = ArmoryUnit;
	OriginalAppearance = ArmoryPawn.m_kAppearance;
	SelectedAppearance = OriginalAppearance;
	OriginalAttitude = ArmoryUnit.GetPersonalityTemplate();
	OriginalPawnLocation = ArmoryPawn.Location;

	UpdatePawnLocation();
}

simulated static function CycleToSoldier(StateObjectReference NewRef)
{
	local UIManageAppearance CustomizeScreen;
	super.CycleToSoldier(NewRef);

	CustomizeScreen = UIManageAppearance(`SCREENSTACK.GetFirstInstanceOf(class'UIManageAppearance'));
	if (CustomizeScreen != none)
	{
		CustomizeScreen.CacheArmoryUnitData();
		CustomizeScreen.UpdateOptionsList();
		CustomizeScreen.UpdatePawnLocation();
	}
}

simulated function UpdateData()
{
	if (ColorSelector != none )
	{
		CloseColorSelector();
	}

	// Override in child classes for custom behavior
	Header.PopulateData(Unit);

	if (CustomizeManager.ActorPawn != none)
	{
		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizeManager.ActorPawn);
	}

	UpdateAppearanceList();
	UpdateOptionsList();
	UpdateUnitAppearance();
}

function UpdatePawnLocation()
{
	local vector PawnLocation;

	PawnLocation = OriginalPawnLocation;

	PawnLocation.X += 20; // Nudge the soldier pawn to the left a little
	ArmoryPawn.SetLocation(PawnLocation);
}

// ================================================================================================================================================
// FILTER LIST MAIN FUNCTIONS - Filter list is located in the upper right corner, it determines which appearances are displayed in the appearance list.

function CreateFiltersList()
{
	local UIMechaListItem SpawnedItem;

	FiltersListBG = Spawn(class'UIBGBox', self).InitBG('UpperRightFiltersListBG', ListBG.X, 10);
	FiltersListBG.SetAlpha(80);
	FiltersListBG.SetWidth(582);
	FiltersListBG.SetHeight(330);

	FiltersList = Spawn(class'UIList', self);
	FiltersList.bAnimateOnInit = false;
	FiltersList.InitList('UpperRightFiltersList', List.X, 20);
	FiltersList.SetWidth(542);
	FiltersList.SetHeight(310);
	FiltersList.Navigator.LoopSelection = true;
	
	FiltersListBG.ProcessMouseEvents(FiltersList.OnChildMouseEvent);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataButton(strApplyTo, strApplyChangesButton, OnApplyChangesButtonClicked);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('ApplyToThisUnit');
	SpawnedItem.UpdateDataCheckbox(`CAPS(strApplyToThisUnit), strApplyToThisUnitTip, true, none, none);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('ApplyToSquad');
	SpawnedItem.UpdateDataCheckbox(`CAPS(class'UITLE_ChallengeModeMenu'.default.m_Header_Squad), strApplyToSquadTip, false, none, none);
	SpawnedItem.SetDisabled(InShell(), strNotAvailableInCharacterPool);

	if (bInArmory)
	{
		SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('ApplyToBarracks');
		SpawnedItem.UpdateDataCheckbox(`CAPS(class'XComKeybindingData'.default.m_arrAvengerBindableLabels[eABC_Barracks]), strApplyToBarracksTip, false, none, none);
	}
	else
	{
		SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('ApplyToCharPool');
		SpawnedItem.UpdateDataCheckbox(`CAPS(class'UICharacterPool'.default.m_strTitle), strApplyToCPTip, false, none, none);
	}

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataDescription(strFiltersTitle);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('FilterGender');
	SpawnedItem.UpdateDataCheckbox(`CAPS(class'UICustomize_Info'.default.m_strGender), "", true, OnFilterCheckboxChanged, none);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('FilterClass');
	SpawnedItem.UpdateDataCheckbox(`CAPS(class'UIPersonnel'.default.m_strButtonLabels[ePersonnelSoldierSortType_Class]), "", false, OnFilterCheckboxChanged, none);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('FilterArmorAppearance');
	SpawnedItem.SetDisabled(ArmorTemplateName == '', strNoArmorTemplateError @ ArmoryUnit.GetFullName());
	SpawnedItem.UpdateDataCheckbox(`CAPS(class'UIArmory_Loadout'.default.m_strInventoryLabels[eInvSlot_Armor]), "", true, OnFilterCheckboxChanged, none); 
}

private function OnFilterCheckboxChanged(UICheckbox CheckBox)
{
	UpdateAppearanceList();
}

function bool GetFilterListCheckboxStatus(name FilterName)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(FiltersList.ItemContainer.GetChildByName(FilterName, false));

	return ListItem != none && ListItem.Checkbox.bChecked;
}

private function OnApplyChangesButtonClicked(UIButton ButtonSource)
{
	local TDialogueBoxData kDialogData;
	local int iNumUnitsToChange;

	if (`GETMCMVAR(MULTIPLE_UNIT_CHANGE_REQUIRES_CONFIRMATION))
	{
		iNumUnitsToChange = GetApplyChangesNumUnits();
		if (iNumUnitsToChange > 1)
		{
			kDialogData.eType = eDialog_Normal;
			kDialogData.strTitle = strConfirmApplyChangesTitle;
			kDialogData.strText = Repl(strConfirmApplyChangesText, "%NUM_UNITS%", iNumUnitsToChange);
			kDialogData.strAccept = class'UISimpleScreen'.default.m_strAccept;
			kDialogData.strCancel = class'UISimpleScreen'.default.m_strCancel;
			kDialogData.fnCallback = OnApplyChangesCloseScreenDialogCallback;
			`PRESBASE.UIRaiseDialog(kDialogData);
			return;
		}
	}

	OnApplyChangesCloseScreenDialogCallback('eUIAction_Accept');
}

private function int GetApplyChangesNumUnits()
{
	local StateObjectReference				SquadUnitRef;
	local int								iNumUnits;
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local XComGameState_HeadquartersXCom	XComHQ;

	if (GetFilterListCheckboxStatus('ApplyToThisUnit'))
	{
		iNumUnits++;
	}

	if (GetFilterListCheckboxStatus('ApplyToCharPool'))
	{
		foreach PoolMgr.CharacterPool(UnitState)
		{
			if (IsUnitSameType(UnitState)) iNumUnits++;
		}
	}

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	if (XComHQ == none)
		return iNumUnits;

	if (GetFilterListCheckboxStatus('ApplyToSquad'))
	{
		foreach XComHQ.Squad(SquadUnitRef)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SquadUnitRef.ObjectID));
			if (UnitState != none && IsUnitSameType(UnitState)) iNumUnits++;
		}
	}
	if (GetFilterListCheckboxStatus('ApplyToBarracks'))
	{
		UnitStates = XComHQ.GetSoldiers(true, true);
		foreach UnitStates(UnitState)
		{
			if (IsUnitSameType(UnitState)) iNumUnits++;
		}
	}
	
	return iNumUnits;
}

private function OnApplyChangesCloseScreenDialogCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		ApplyChanges();

		class'Help'.static.PlayStrategySoundEvent("Play_MenuSelect", self);
	}
}

// ================================================================================================================================================
// APPEARANCE LIST MAIN FUNCTIONS

function UpdateAppearanceList()
{
	local UIMechaListItem_Soldier			SpawnedItem;
	local XComGameState_Unit				CheckUnit;
	local XComGameState_HeadquartersXCom	XComHQ;
	local array<XComGameState_Unit>			Soldiers;

	List.ClearItems();

	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataButton(`YELLOW(strSelectAppearanceTitle), 
		strSearchTitle $ SearchText == "" ? "" : ":" @ SearchText, OnSearchButtonClicked);
	
	// First entry is always "No change"
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataCheckbox(strOriginalAppearance, "", bOriginalAppearanceSelected, AppearanceOptionCheckboxChanged, none);
	SpawnedItem.StoredAppearance.Appearance = OriginalAppearance;
	SpawnedItem.bOriginalAppearance = true;
	SpawnedItem.UpdateDataButton(strOriginalAppearance, strSaveAsUniform, OnSaveAsUniformButtonClicked);

	// Uniforms
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('bShowUniformSoldiers');
	SpawnedItem.UpdateDataCheckbox(`YELLOW(`CAPS(strUniformsTitle)), "", bShowUniformSoldiers, AppearanceOptionCheckboxChanged, none);

	if (bShowUniformSoldiers)
	{
		foreach PoolMgr.CharacterPool(CheckUnit)
		{
			if (PoolMgr.GetUniformStatus(CheckUnit) > EUS_NotUniform)
			{
				CreateAppearanceStoreEntriesForUnit(CheckUnit, true);
			}
		}
	}

	// Character pool
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('bShowCharPoolSoldiers');
	SpawnedItem.UpdateDataCheckbox(`YELLOW(`CAPS(class'UICharacterPool'.default.m_strTitle)), "", bShowCharPoolSoldiers, AppearanceOptionCheckboxChanged, none);

	if (bShowCharPoolSoldiers)
	{
		foreach PoolMgr.CharacterPool(CheckUnit)
		{
			if (PoolMgr.GetUniformStatus(CheckUnit) == EUS_NotUniform)
			{
				CreateAppearanceStoreEntriesForUnit(CheckUnit, true);
			}
		}
	}
	if (!InShell())
	{
		// Soldiers in barracks
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('bShowBarracksSoldiers');
		SpawnedItem.UpdateDataCheckbox(`YELLOW(`CAPS(class'XComKeybindingData'.default.m_arrAvengerBindableLabels[eABC_Barracks])), "", bShowBarracksSoldiers, AppearanceOptionCheckboxChanged, none);

		XComHQ = `XCOMHQ;
		if (bShowBarracksSoldiers)
		{
			Soldiers = XComHQ.GetSoldiers(); 
			foreach Soldiers(CheckUnit)
			{
				CreateAppearanceStoreEntriesForUnit(CheckUnit);
			}
		}
		// Soldiers in morgue
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('bShowDeadSoldiers');
		SpawnedItem.UpdateDataCheckbox(`YELLOW(`CAPS(class'UIPersonnel_BarMemorial'.default.m_strTitle)), "", bShowDeadSoldiers, AppearanceOptionCheckboxChanged, none);

		if (bShowDeadSoldiers)
		{
			Soldiers = GetDeadSoldiers(XComHQ);
			foreach Soldiers(CheckUnit)
			{
				CreateAppearanceStoreEntriesForUnit(CheckUnit);
			}
		}
	}
}

private function AppearanceListItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(AppearanceList.GetItem(ItemIndex));
	if (ListItem.bDisabled)
		return;

	switch (ListItem.MCName)
	{
		case 'bShowCharPoolSoldiers':
			bShowCharPoolSoldiers = !bShowCharPoolSoldiers;
			default.bShowCharPoolSoldiers = bShowCharPoolSoldiers;
			SaveConfig();
			UpdateAppearanceList();
			return;
		case 'bShowUniformSoldiers':
			bShowUniformSoldiers = !bShowUniformSoldiers;
			default.bShowUniformSoldiers = bShowUniformSoldiers;
			SaveConfig();
			UpdateAppearanceList();
			return;
		case 'bShowBarracksSoldiers':
			bShowBarracksSoldiers = !bShowBarracksSoldiers;
			default.bShowBarracksSoldiers = bShowBarracksSoldiers;
			SaveConfig();
			UpdateAppearanceList();
			return;
		case 'bShowDeadSoldiers':
			bShowDeadSoldiers = !bShowDeadSoldiers;
			default.bShowDeadSoldiers = bShowDeadSoldiers;
			SaveConfig();
			UpdateAppearanceList();
			return;
		default:
			break;
	}

	AppearanceOptionCheckboxChanged(GetListItem(ItemIndex).Checkbox);

	bCanExitWithoutPopup = ArmoryUnit.kAppearance == OriginalAppearance;
}

private function AppearanceOptionCheckboxChanged(UICheckbox CheckBox)
{
	local UIMechaListItem			ListItem;
	local UIMechaListItem_Soldier	SoldierListItem;
	local bool						bSkip;
	local int						Index;
	local int						i;

	Index = AppearanceList.GetItemIndex(CheckBox.ParentPanel);
	if (Index == INDEX_NONE)
		return;

	// Uncheck other members of the appearance list
	for (i = 0; i < AppearanceList.ItemCount; i++)
	{
		// Except for the checkbox that was clicked on
		if (i == Index)
			continue;

		ListItem = UIMechaListItem(AppearanceList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		// And categories' checkboxes
		bSkip = false;
		switch(ListItem.MCName)
		{
			case 'bShowCharPoolSoldiers':
			case 'bShowBarracksSoldiers':
			case 'bShowDeadSoldiers':
			case 'bShowUniformSoldiers':
				bSkip = true;
				break;
			default:
				break;
		}
		if (bSkip) 
			continue;
		
		`AMLOG("Unchecking:" @ ListItem.MCName);
		ListItem.Checkbox.SetChecked(false, false);
	}
	// And force check whiever checkbox was clicked on.
	CheckBox.SetChecked(true, false);

	SoldierListItem = UIMechaListItem_Soldier(CheckBox.ParentPanel);
	
	// Store info about appearance that was clicked.
	SelectedAppearance = SoldierListItem.StoredAppearance.Appearance;
	SelectedAttitude = SoldierListItem.PersonalityTemplate;
	SelectedUnit = SoldierListItem.UnitState;
	bOriginalAppearanceSelected = SoldierListItem.bOriginalAppearance;

	UpdateOptionsList();
	ApplyPresetCheckboxPositions();
	UpdateUnitAppearance();	
}

private function OnSearchButtonClicked(UIButton ButtonSource)
{
	local TInputDialogData kData;

	if (SearchText != "")
	{
		SearchText = "";
		UpdateAppearanceList();
	}
	else
	{
		kData.strTitle = strSearchTitle;
		kData.iMaxChars = 99;
		kData.strInputBoxText = SearchText;
		kData.fnCallback = OnSearchInputBoxAccepted;

		Movie.Pres.UIInputDialog(kData);
	}
}

private function OnSearchInputBoxAccepted(string text)
{
	SearchText = text;
	UpdateAppearanceList();
}

private function OnSaveAsUniformButtonClicked(UIButton ButtonSource)
{
	local TInputDialogData kData;

	kData.strTitle = strEnterUniformName;
	kData.iMaxChars = 99;
	kData.strInputBoxText = GetFriendlyGender(ArmoryPawn.m_kAppearance.iGender);
	kData.fnCallback = OnSaveAsUniformInputBoxAccepted;

	Movie.Pres.UIInputDialog(kData);
}

private function OnSaveAsUniformInputBoxAccepted(string strLastName)
{
	local XComGameState_Unit NewUnit;

	if (strLastName != "")
	{
		NewUnit = PoolMgr.CreateSoldierForceGender(ArmoryUnit.GetMyTemplateName(), EGender(ArmoryPawn.m_kAppearance.iGender));
		if (NewUnit == none)
		{
			ShowInfoPopup(strFailedToCreateUnitTitle, strFailedToCreateUnitText @ ArmoryUnit.GetMyTemplateName(), eDialog_Warning);
			return;
		}

		NewUnit.SetTAppearance(ArmoryPawn.m_kAppearance);

		NewUnit.SetCharacterName(class'UISL_AppearanceManager'.default.strUniformSoldierFirstName, strLastName, "");
		PoolMgr.SetUniformStatus(NewUnit, EUS_Manual);

		NewUnit.kAppearance.iAttitude = 0;
		NewUnit.UpdatePersonalityTemplate();
		NewUnit.bAllowedTypeSoldier = false;
		NewUnit.bAllowedTypeVIP = false;
		NewUnit.bAllowedTypeDarkVIP = false;

		NewUnit.StoreAppearance(ArmoryPawn.m_kAppearance.iGender, ArmorTemplateName);
		PoolMgr.CharacterPool.AddItem(NewUnit);
		SaveCosmeticOptionsForUnit(NewUnit); // This calls SaveCharacterPool()

		UpdateAppearanceList();
	}
	else 
	{
		ShowInfoPopup(strInvalidEmptyUniformNameTitle, strInvalidEmptyUniformNameText, eDialog_Alert);
	}
}

simulated function SaveCosmeticOptionsForUnit(XComGameState_Unit UnitState)
{
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local CosmeticOptionStruct			CosmeticOption;
	local UIMechaListItem				ListItem;
	local int i;

	for (i = 1; i < OptionsList.ItemCount; i++) // Skip 0th member that is for sure "ShowAllCosmetics"
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none || !IsCosmeticOption(ListItem.MCName))
			continue;

		`AMLOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked);

		CosmeticOption.OptionName = ListItem.MCName;
		CosmeticOption.bChecked = ListItem.Checkbox.bChecked;
		CosmeticOptions.AddItem(CosmeticOption);
	}

	PoolMgr.SaveCosmeticOptionsForUnit(CosmeticOptions, UnitState, GetGenderArmorTemplate());
}

private function CreateAppearanceStoreEntriesForUnit(const XComGameState_Unit UnitState, optional bool bCharPool)
{
	local AppearanceInfo			StoredAppearance;
	local X2ItemTemplate			ArmorTemplate;
	local EGender					Gender;
	local name						LocalArmorTemplateName;
	local string					DisplayString;
	local bool						bCurrentAppearanceFound;
	local string					UnitName;
	local UIMechaListItem_Soldier	SpawnedItem;

	if (!IsUnitSameType(UnitState))
		return;

	if (GetFilterListCheckboxStatus('FilterClass') && ArmoryUnit.GetSoldierClassTemplateName() != UnitState.GetSoldierClassTemplateName())
		return;

	UnitName = class'Help'.static.GetUnitDisplayString(UnitState);
	if (bCharPool && IsUnitPresentInCampaign(UnitState)) // If unit was already drawn from the CP, color their entry green.
			UnitName = `GREEN(UnitName);

	// Cycle through Appearance Store, which may or may not include unit's current appearance.
	foreach UnitState.AppearanceStore(StoredAppearance)
	{	
		// Skip current appearance of current unit
		if (StoredAppearance.Appearance == OriginalAppearance && UnitState == ArmoryUnit)
			continue;

		Gender = EGender(int(Right(StoredAppearance.GenderArmorTemplate, 1)));
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			continue;

		LocalArmorTemplateName = name(Left(StoredAppearance.GenderArmorTemplate, Len(StoredAppearance.GenderArmorTemplate) - 1));
		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != LocalArmorTemplateName)
			continue;

		ArmorTemplate = ItemMgr.FindItemTemplate(LocalArmorTemplateName);

		DisplayString = UnitName @ "|";

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayString @= ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayString @= string(LocalArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayString @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayString @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}

		if (class'Help'.static.IsAppearanceCurrent(StoredAppearance.Appearance, UnitState.kAppearance))
		{
			bCurrentAppearanceFound = true;

			DisplayString @= class'Help'.default.strCurrentAppearance;
		}

		if (SearchText != "" && InStr(DisplayString, SearchText,, true) == INDEX_NONE) // ignore case
			continue;
		
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.StoredAppearance = StoredAppearance;
		SpawnedItem.SetPersonalityTemplate();
		SpawnedItem.UnitState = UnitState;
		SpawnedItem.UpdateDataCheckbox(DisplayString, "", SelectedAppearance == SpawnedItem.StoredAppearance.Appearance && SpawnedItem.UnitState == SelectedUnit, AppearanceOptionCheckboxChanged, none);
		SpawnedItem.SetDisabled(StoredAppearance.Appearance == OriginalAppearance && UnitState == ArmoryUnit); // Lock current appearance of current unit
	}

	// If Appearance Store didn't contain unit's current appearance, add unit's current appearance to the list as well.
	// As long it's not the currently selected unit there's no value in having them in the list.
	if (!bCurrentAppearanceFound)
	{
		// Skip current appearance of current unit
		if (UnitState.kAppearance == OriginalAppearance && UnitState == ArmoryUnit)
			return;

		Gender = EGender(UnitState.kAppearance.iGender);
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			return;

		// Can't use Item State cuz Character Pool units would have none.
		ArmorTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(UnitState.kAppearance.nmTorso);

		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != ArmorTemplate == none ? '' : ArmorTemplate.DataName)
			return;

		DisplayString = UnitState.GetFullName() @ "|";

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayString @= ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayString @= string(LocalArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayString @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayString @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}
		DisplayString @= class'Help'.default.strCurrentAppearance;

		if (SearchText != "" && InStr(DisplayString, SearchText,, true) == INDEX_NONE) // ignore case
			return;
		
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(DisplayString, "", false, AppearanceOptionCheckboxChanged, none);
		SpawnedItem.StoredAppearance.Appearance = UnitState.kAppearance;
		SpawnedItem.SetPersonalityTemplate();
		SpawnedItem.UnitState = UnitState;
		SpawnedItem.SetDisabled(UnitState == ArmoryUnit); // Lock current appearance of current unit
	}
}

private function array<XComGameState_Unit> GetDeadSoldiers(XComGameState_HeadquartersXCom XComHQ)
{
	local XComGameState_Unit Soldier;
	local array<XComGameState_Unit> Soldiers;
	local int idx;

	for (idx = 0; idx < XComHQ.DeadCrew.Length; idx++)
	{
		Soldier = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.DeadCrew[idx].ObjectID));

		if (Soldier != none && Soldier.IsSoldier())
		{
			Soldiers.AddItem(Soldier);
		}
	}
	return Soldiers;
}

private function bool IsUnitSameType(const XComGameState_Unit UnitState)
{	
	if (!class'Help'.static.IsUnrestrictedCustomizationLoaded())
	{	
		// If Unrestricted Customization is not present, then soldier cosmetics should respect
		// per-character-template customization.
		if (UnitState.GetMyTemplateName() != ArmoryUnit.GetMyTemplateName())
			return false;
	}
	else
	{
		// Filter out SPARKs and other non-soldier units.
		if (ArmoryUnit.UnitSize != UnitState.UnitSize)
				return false;

		if (ArmoryUnit.UnitHeight != UnitState.UnitHeight)
			return false;
	}
	return true;
}

// ================================================================================================================================================
// FUNCTIONS FOR APPLYING APPEARANCE CHANGES

private function UpdateUnitAppearance()
{
	local TAppearance NewAppearance;

	PreviousAppearance = ArmoryPawn.m_kAppearance;
	NewAppearance = OriginalAppearance;
	CopyAppearance(NewAppearance, SelectedAppearance);

	bCanExitWithoutPopup = NewAppearance == OriginalAppearance;
		
	ArmoryUnit.SetTAppearance(NewAppearance);
	ArmoryPawn.SetAppearance(NewAppearance);
	ApplyChangesToUnitWeapons(ArmoryUnit, NewAppearance, none);
	UpdateHeader();

	if (ShouldRefreshPawn(NewAppearance))
	{
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);

		// After ReCreatePawnVisuals, the CustomizeManager.ActorPawn, ArmoryPawn and become 'none'
		// Apparently there's some sort of threading issue at play, so we use a timer to get a reference to the new pawn with a slight delay.
		//OnRefreshPawn();
		SetTimer(0.01f, false, nameof(OnRefreshPawn), self);
	}	
	else
	{
		UpdatePawnAttitudeAnimation(); // OnRefreshPawn() will call this automatically
	}
}

private function bool ShouldRefreshPawn(const TAppearance NewAppearance)
{
	if (PreviousAppearance.iGender != NewAppearance.iGender)
	{
		return true;
	}
	if (PreviousAppearance.nmWeaponPattern != NewAppearance.nmWeaponPattern)
	{
		return true;
	}
	if (PreviousAppearance.iWeaponTint != NewAppearance.iWeaponTint)
	{
		return true;
	}
	return false;
}

// Can't use an Event Listener in CP, so using a timer (ugh)
final function OnRefreshPawn()
{
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn != none)
	{
		UpdatePawnLocation();
		UpdatePawnAttitudeAnimation();
		ApplyChangesToUnitWeapons(ArmoryUnit, ArmoryPawn.m_kAppearance, none);

		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizeManager.ActorPawn);
	}
	else
	{
		SetTimer(0.01f, false, nameof(OnRefreshPawn), self);
	}
}

private function UpdatePawnAttitudeAnimation()
{
	if (ArmoryPawn == none)
		return;

	if (IsCheckboxChecked('iAttitude'))
	{
		IdleAnimName = SelectedAttitude.IdleAnimName;
	}
	else
	{
		IdleAnimName = OriginalAttitude.IdleAnimName;
	}
	if (!ArmoryPawn.GetAnimTreeController().IsPlayingCurrentAnimation(IdleAnimName))
	{
		ArmoryPawn.PlayHQIdleAnim(IdleAnimName);
		ArmoryPawn.CustomizationIdleAnim = IdleAnimName;
	}
}

private function UpdateHeader()
{
	local string strFirstName;
	local string strNickname;
	local string strLastName;
	local string StatusTimeValue;
	local string StatusTimeLabel;
	local string StatusDesc;
	local string strDisplayName;
	local string flagIcon;
	local X2CountryTemplate	CountryTemplate;

	if (IsCheckboxChecked('FirstName'))
		strFirstName = SelectedUnit.GetFirstName();
	else
		strFirstName = ArmoryUnit.GetFirstName();

	if (IsCheckboxChecked('Nickname'))
		strNickname = SelectedUnit.GetNickName();
	else
		strNickname = ArmoryUnit.GetNickName();

	if (IsCheckboxChecked('LastName'))
		strLastName = SelectedUnit.GetLastName();
	else
		strLastName = ArmoryUnit.GetLastName();

	if (IsCheckboxChecked('nmFlag'))
		CountryTemplate = X2CountryTemplate(StratMgr.FindStrategyElementTemplate(SelectedAppearance.nmFlag));
	else
		CountryTemplate = X2CountryTemplate(StratMgr.FindStrategyElementTemplate(OriginalAppearance.nmFlag));
	
	if (CountryTemplate!= none)
	{
		flagIcon = CountryTemplate.FlagImage;
	}

	class'UIUtilities_Strategy'.static.GetPersonnelStatusSeparate(ArmoryUnit, StatusDesc, StatusTimeLabel, StatusTimeValue, , true); 
	
	if (strNickname == "")
		strDisplayName = strFirstName @ strLastName;
	else
		strDisplayName = strFirstName @ "'" $ strNickname $ "'" @ strLastName;

	Header.SetSoldierInfo( Caps(strDisplayName),
						Header.m_strStatusLabel, StatusDesc,
						Header.m_strMissionsLabel, string(Unit.GetNumMissions()),
						Header.m_strKillsLabel, string(Unit.GetNumKills()),
						Unit.GetSoldierClassIcon(), Caps(ArmoryUnit.GetSoldierClassDisplayName()),
						Unit.GetSoldierRankIcon(), Caps(ArmoryUnit.GetSoldierRankName()),
						flagIcon, ArmoryUnit.ShowPromoteIcon(), StatusTimeValue @ StatusTimeLabel);
}

simulated function CloseScreen()
{	
	local TDialogueBoxData kDialogData;

	if (bCanExitWithoutPopup ||
		bOriginalAppearanceSelected || 
		!GetFilterListCheckboxStatus('ApplyToThisUnit') &&
		!GetFilterListCheckboxStatus('ApplyToCharPool') &&
		!GetFilterListCheckboxStatus('ApplyToSquad') &&
		!GetFilterListCheckboxStatus('ApplyToBarracks'))
	{
		CancelChanges();
		ArmoryPawn.SetLocation(OriginalPawnLocation);
		SavePresetCheckboxPositions();
		super.CloseScreen();
	}
	else
	{
		kDialogData.strTitle = strExitScreenPopupTitle;
		kDialogData.eType = eDialog_Warning;
		kDialogData.strText = strExitScreenPopupText;
		kDialogData.strAccept = strExitScreenPopup_Leave;
		kDialogData.strCancel = strExitScreenPopup_Stay;
		kDialogData.fnCallback = OnCloseScreenDialogCallback;
		Movie.Pres.UIRaiseDialog(kDialogData);
	}
}

private function OnCloseScreenDialogCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		CancelChanges();
		ArmoryPawn.SetLocation(OriginalPawnLocation);
		SavePresetCheckboxPositions();
		super.CloseScreen();
	}
}

private function ApplyChanges()
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local StateObjectReference				SquadUnitRef;
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;

	// Current Unit
	if (GetFilterListCheckboxStatus('ApplyToThisUnit') && !bOriginalAppearanceSelected)
	{
		ApplyChangesToArmoryUnit();
	}
	else
	{
		CancelChanges();
	}

	// Character Pool
	if (GetFilterListCheckboxStatus('ApplyToCharPool'))
	{
		foreach PoolMgr.CharacterPool(UnitState)
		{
			if (!IsUnitSameType(UnitState)) continue;

			ApplyChangesToUnit(UnitState);
		}
		PoolMgr.SaveCharacterPool();
	}

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	if (XComHQ == none)
		return;

	// Squad
	if (GetFilterListCheckboxStatus('ApplyToSquad'))
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes to squad");
		foreach XComHQ.Squad(SquadUnitRef)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SquadUnitRef.ObjectID));
			if (UnitState == none || UnitState.IsDead() || !IsUnitSameType(UnitState))
				continue;

			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
			ApplyChangesToUnit(UnitState, NewGameState);
		}
		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Barracks except for squad and soldiers away on Covert Action
	if (GetFilterListCheckboxStatus('ApplyToBarracks'))
	{
		UnitStates = XComHQ.GetSoldiers(true, true);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes to barracks");
		foreach UnitStates(UnitState)
		{
			if (!IsUnitSameType(UnitState)) continue;

			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
			ApplyChangesToUnit(UnitState, NewGameState);
		}
		if (NewGameState.GetNumGameStateObjects() > 0)
		{
			`GAMERULES.SubmitGameState(NewGameState);
		}
		else
		{
			`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		}
	}

	bCanExitWithoutPopup = true;
}

private function ApplyChangesToUnit(XComGameState_Unit UnitState, optional XComGameState NewGameState)
{
	local TAppearance	NewAppearance;
	local string		strFirstName;
	local string		strNickname;
	local string		strLastName;

	`AMLOG(UnitState.GetFullName());

	if (IsCheckboxChecked('FirstName'))
		strFirstName = SelectedUnit.GetFirstName();
	else
		strFirstName = UnitState.GetFirstName();

	if (IsCheckboxChecked('Nickname'))
		strNickname = SelectedUnit.GetNickName();
	else
		strNickname = UnitState.GetNickName();

	if (IsCheckboxChecked('LastName'))
		strLastName = SelectedUnit.GetLastName();
	else
		strLastName = UnitState.GetLastName();

	if (IsCheckboxChecked('nmFlag'))
		UnitState.SetCountry(ArmoryPawn.m_kAppearance.nmFlag);

	UnitState.SetCharacterName(strFirstName, strLastName, strNickname);

	if (IsCheckboxChecked('Biography'))
		UnitState.SetBackground(SelectedUnit.GetBackground());

	NewAppearance = UnitState.kAppearance;
	CopyAppearance(NewAppearance, SelectedAppearance);

	UnitState.SetTAppearance(NewAppearance);
	UnitState.UpdatePersonalityTemplate();
	UnitState.StoreAppearance();

	ApplyChangesToUnitWeapons(UnitState, NewAppearance, NewGameState);
}

private function ApplyChangesToUnitWeapons(XComGameState_Unit UnitState, TAppearance NewAppearance, XComGameState NewGameState)
{
	local XComGameState_Item		InventoryItem;
	local XComGameState_Item		NewInvenoryItem;
	local array<XComGameState_Item> InventoryItems;
	local X2WeaponTemplate			WeaponTemplate;
	local bool						bSubmit;

	`AMLOG("Tint:" @ IsCheckboxChecked('iWeaponTint') @ "pattern:" @ IsCheckboxChecked('nmWeaponPattern'));

	// There are two separate tasks: updating weapon appearance in Shell (in CP) and in Armory.
	// In CP this happens automatically, because when we refresh the pawn, the unit's weapons automatically draw their customization from the unit state.
	// So we exit early out of this function.
	if (InShell())
		return;

	// While in Armory, we have to actually update the weapon appearance on Item States, which always requires submitting a Game State.
	// So if a NewGameState wasn't provided, we create our own, ~~with blackjack and hookers~~
	if (NewGameState == none)
	{		
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply weeapon appearance changes");
		bSubmit = true;
	}
	InventoryItems = UnitState.GetAllInventoryItems(NewGameState, true);
	`AMLOG("Num inventory items:" @ InventoryItems.Length);
	foreach InventoryItems(InventoryItem)
	{
		WeaponTemplate = X2WeaponTemplate(InventoryItem.GetMyTemplate());
		if (WeaponTemplate == none)
			continue;

		`AMLOG(WeaponTemplate.DataName @ InventoryItem.InventorySlot @ InventoryItem.ObjectID);
		
		NewInvenoryItem = XComGameState_Item(NewGameState.ModifyStateObject(InventoryItem.Class, InventoryItem.ObjectID));
		if (IsCheckboxChecked('iWeaponTint'))
		{
			if (WeaponTemplate.bUseArmorAppearance)
			{
				NewInvenoryItem.WeaponAppearance.iWeaponTint = NewAppearance.iArmorTint;
			}
			else
			{
				NewInvenoryItem.WeaponAppearance.iWeaponTint = NewAppearance.iWeaponTint;
			}
		}
		else
		{
			if (WeaponTemplate.bUseArmorAppearance)
			{
				NewInvenoryItem.WeaponAppearance.iWeaponTint = OriginalAppearance.iArmorTint;
			}
			else
			{
				NewInvenoryItem.WeaponAppearance.iWeaponTint = OriginalAppearance.iWeaponTint;
			}
		}

		if (IsCheckboxChecked('nmWeaponPattern'))
		{
			NewInvenoryItem.WeaponAppearance.nmWeaponPattern = NewAppearance.nmWeaponPattern;
		}
		else
		{
			NewInvenoryItem.WeaponAppearance.nmWeaponPattern = OriginalAppearance.nmWeaponPattern;
		}
		
	}
	if (bSubmit)
	{
		if (NewGameState.GetNumGameStateObjects() > 0)
		{
			`GAMERULES.SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}
	// This doesn't seem to do anything.
	//ArmoryPawn.CreateVisualInventoryAttachments(Movie.Pres.GetUIPawnMgr(), UnitState, NewGameState);
}

private function ApplyChangesToArmoryUnit()
{
	local XComGameState NewGameState;
	local string strFirstName;
	local string strNickname;
	local string strLastName;

	ArmoryUnit.SetTAppearance(ArmoryPawn.m_kAppearance);

	if (IsCheckboxChecked('FirstName'))
		strFirstName = SelectedUnit.GetFirstName();
	else
		strFirstName = ArmoryUnit.GetFirstName();

	if (IsCheckboxChecked('Nickname'))
		strNickname = SelectedUnit.GetNickName();
	else
		strNickname = ArmoryUnit.GetNickName();

	if (IsCheckboxChecked('LastName'))
		strLastName = SelectedUnit.GetLastName();
	else
		strLastName = ArmoryUnit.GetLastName();

	if (IsCheckboxChecked('nmFlag'))
		ArmoryUnit.SetCountry(ArmoryPawn.m_kAppearance.nmFlag);

	ArmoryUnit.SetCharacterName(strFirstName, strLastName, strNickname);

	if (IsCheckboxChecked('Biography'))
		ArmoryUnit.SetBackground(SelectedUnit.GetBackground());

	ArmoryUnit.StoreAppearance();
	CustomizeManager.SubmitUnitCustomizationChanges();

	if (!InShell())
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes");
		ArmoryUnit = XComGameState_Unit(NewGameState.ModifyStateObject(ArmoryUnit.Class, ArmoryUnit.ObjectID));
		ArmoryUnit.UpdatePersonalityTemplate();

		ApplyChangesToUnitWeapons(ArmoryUnit, ArmoryPawn.m_kAppearance, NewGameState);
		`GAMERULES.SubmitGameState(NewGameState);
	}
	ArmoryPawn.CustomizationIdleAnim = ArmoryUnit.GetPersonalityTemplate().IdleAnimName;

	OriginalAppearance = ArmoryPawn.m_kAppearance;
	OriginalAttitude = ArmoryUnit.GetPersonalityTemplate();

	UpdateOptionsList();
	UpdateUnitAppearance();
}

function CancelChanges()
{
	PreviousAppearance = ArmoryPawn.m_kAppearance;
	ArmoryUnit.SetTAppearance(OriginalAppearance);
	ArmoryPawn.SetAppearance(OriginalAppearance);

	if (ShouldRefreshPawn(OriginalAppearance))
	{
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
	}	
	else
	{
		UpdatePawnAttitudeAnimation();
	}
}

// ================================================================================================================================================
// OPTIONS LIST - List of checkboxes on the left that determines which parts of the appearance should be copied from CP unit to Armory unit.

private function CopyAppearance(out TAppearance NewAppearance, const out TAppearance UniformAppearance)
{
	local bool bGenderChange;

	if (IsCheckboxChecked('iGender'))
	{
		bGenderChange = true;
		NewAppearance.iGender = UniformAppearance.iGender; 
		NewAppearance.nmPawn = UniformAppearance.nmPawn; 
		NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
		NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
		NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	}
	if (bGenderChange || NewAppearance.iGender == UniformAppearance.iGender)
	{		
		if (IsCheckboxChecked('nmHead'))				{NewAppearance.nmHead = UniformAppearance.nmHead; 
														NewAppearance.nmEye = UniformAppearance.nmEye; 
														NewAppearance.nmTeeth = UniformAppearance.nmTeeth; 
														NewAppearance.iRace = UniformAppearance.iRace;}
		if (IsCheckboxChecked('nmHaircut'))				NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
		if (IsCheckboxChecked('nmBeard'))				NewAppearance.nmBeard = UniformAppearance.nmBeard;
		if (IsCheckboxChecked('nmTorso'))				NewAppearance.nmTorso = UniformAppearance.nmTorso;
		if (IsCheckboxChecked('nmArms'))				NewAppearance.nmArms = UniformAppearance.nmArms;
		if (IsCheckboxChecked('nmLegs'))				NewAppearance.nmLegs = UniformAppearance.nmLegs;
		if (IsCheckboxChecked('nmHelmet'))				NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
		if (IsCheckboxChecked('nmFacePropLower'))		NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
		if (IsCheckboxChecked('nmFacePropUpper'))		NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
		if (IsCheckboxChecked('nmVoice'))				NewAppearance.nmVoice = UniformAppearance.nmVoice;
		if (IsCheckboxChecked('nmScars'))				NewAppearance.nmScars = UniformAppearance.nmScars;
		if (IsCheckboxChecked('nmFacePaint'))			NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
		if (IsCheckboxChecked('nmLeftArm'))				NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
		if (IsCheckboxChecked('nmRightArm'))			NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
		if (IsCheckboxChecked('nmLeftArmDeco'))			NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
		if (IsCheckboxChecked('nmRightArmDeco'))		NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
		if (IsCheckboxChecked('nmLeftForearm'))			NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
		if (IsCheckboxChecked('nmRightForearm'))		NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
		if (IsCheckboxChecked('nmThighs'))				NewAppearance.nmThighs = UniformAppearance.nmThighs;
		if (IsCheckboxChecked('nmShins'))				NewAppearance.nmShins = UniformAppearance.nmShins;
		if (IsCheckboxChecked('nmTorsoDeco'))			NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
		//if (IsCheckboxChecked('iRace'))				NewAppearance.iRace = UniformAppearance.iRace;
		//if (IsCheckboxChecked('iFacialHair'))			NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
		//if (IsCheckboxChecked('iVoice'))				NewAppearance.iVoice = UniformAppearance.iVoice;
		//if (IsCheckboxChecked('nmTorso_Underlay'))	NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
		//if (IsCheckboxChecked('nmArms_Underlay'))		NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
		//if (IsCheckboxChecked('nmLegs_Underlay'))		NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	}

	if (IsCheckboxChecked('iHairColor'))			NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (IsCheckboxChecked('iSkinColor'))			NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (IsCheckboxChecked('iEyeColor'))				NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (IsCheckboxChecked('nmFlag'))				NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (IsCheckboxChecked('iAttitude'))				NewAppearance.iAttitude = UniformAppearance.iAttitude;
	if (IsCheckboxChecked('iArmorTint'))			NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (IsCheckboxChecked('iArmorTintSecondary'))	NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (IsCheckboxChecked('iWeaponTint'))			NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (IsCheckboxChecked('iTattooTint'))			NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (IsCheckboxChecked('nmWeaponPattern'))		NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (IsCheckboxChecked('nmPatterns'))			NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	if (IsCheckboxChecked('nmTattoo_LeftArm'))		NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (IsCheckboxChecked('nmTattoo_RightArm'))		NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	//if (IsCheckboxChecked('iArmorDeco'))			NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	//if (IsCheckboxChecked('nmLanguage'))			NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	//if (IsCheckboxChecked('bGhostPawn'))			NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
}

private function bool IsCheckboxChecked(name OptionName)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(OptionsList.ItemContainer.GetChildByName(OptionName, false));

	return ListItem != none && ListItem.Checkbox.bChecked;
}

final function SetOptionsListCheckbox(name OptionName, bool bChecked)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(OptionsList.ItemContainer.GetChildByName(OptionName, false));

	if (ListItem != none)
	{
		ListItem.Checkbox.SetChecked(bChecked, false);
	}
}

function UpdateOptionsList()
{
	// Can't do it here, otherwise the relationship between CurrentPreset and checkboxes will be broken!
	//SavePresetCheckboxPositions();

	OptionsList.ClearItems();

	CreateOptionShowAll();

	// PRESETS
	CreateOptionPresets();

	if (!bShowAllCosmeticOptions && bOriginalAppearanceSelected)
		return;

	// HEAD
	if (MaybeCreateOptionCategory('bShowCategoryHead', class'UICustomize_Menu'.default.m_strEditHead))
	{
		MaybeCreateAppearanceOption('iGender',				OriginalAppearance.iGender,				SelectedAppearance.iGender,				ECosmeticType_GenderInt);
		MaybeCreateAppearanceOption('iSkinColor',			OriginalAppearance.iSkinColor,			SelectedAppearance.iSkinColor,			ECosmeticType_Int);
		MaybeCreateAppearanceOption('nmHead',				OriginalAppearance.nmHead,				SelectedAppearance.nmHead,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmHelmet',				OriginalAppearance.nmHelmet,			SelectedAppearance.nmHelmet,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmFacePropUpper',		OriginalAppearance.nmFacePropUpper,		SelectedAppearance.nmFacePropUpper,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmFacePropLower',		OriginalAppearance.nmFacePropLower,		SelectedAppearance.nmFacePropLower,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmHaircut',			OriginalAppearance.nmHaircut,			SelectedAppearance.nmHaircut,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmBeard',				OriginalAppearance.nmBeard,				SelectedAppearance.nmBeard,				ECosmeticType_Name);
		MaybeCreateOptionColorInt('iHairColor',				OriginalAppearance.iHairColor,			SelectedAppearance.iHairColor,			ePalette_HairColor);
		MaybeCreateOptionColorInt('iEyeColor',				OriginalAppearance.iEyeColor,			SelectedAppearance.iEyeColor,			ePalette_EyeColor);
		MaybeCreateAppearanceOption('nmScars',				OriginalAppearance.nmScars,				SelectedAppearance.nmScars,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmFacePaint',			OriginalAppearance.nmFacePaint,			SelectedAppearance.nmFacePaint,			ECosmeticType_Name);
		//MaybeCreateAppearanceOption('iRace',				OriginalAppearance.iRace,				SelectedAppearance.iRace,				ECosmeticType_Int);
		//MaybeCreateAppearanceOption('iFacialHair',		OriginalAppearance.iFacialHair,			SelectedAppearance.iFacialHair,			ECosmeticType_Int);
		//MaybeCreateAppearanceOption('nmEye',				OriginalAppearance.nmEye,				SelectedAppearance.nmEye,				ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmTeeth',			OriginalAppearance.nmTeeth,				SelectedAppearance.nmTeeth,				ECosmeticType_Name);
	}
	// BODY
	if (MaybeCreateOptionCategory('bShowCategoryBody', class'UICustomize_Menu'.default.m_strEditBody))
	{
		MaybeCreateAppearanceOption('nmTorso',				OriginalAppearance.nmTorso,				SelectedAppearance.nmTorso,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmTorsoDeco',			OriginalAppearance.nmTorsoDeco,			SelectedAppearance.nmTorsoDeco,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmArms',				OriginalAppearance.nmArms,				SelectedAppearance.nmArms,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmLeftArm',			OriginalAppearance.nmLeftArm,			SelectedAppearance.nmLeftArm,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmLeftArmDeco',		OriginalAppearance.nmLeftArmDeco,		SelectedAppearance.nmLeftArmDeco,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmLeftForearm',		OriginalAppearance.nmLeftForearm,		SelectedAppearance.nmLeftForearm,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmRightArm',			OriginalAppearance.nmRightArm,			SelectedAppearance.nmRightArm,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmRightArmDeco',		OriginalAppearance.nmRightArmDeco,		SelectedAppearance.nmRightArmDeco,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmRightForearm',		OriginalAppearance.nmRightForearm,		SelectedAppearance.nmRightForearm,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmLegs',				OriginalAppearance.nmLegs,				SelectedAppearance.nmLegs,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmThighs',				OriginalAppearance.nmThighs,			SelectedAppearance.nmThighs,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmShins',				OriginalAppearance.nmShins,				SelectedAppearance.nmShins,				ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmTorso_Underlay',		OriginalAppearance.nmTorso_Underlay,	SelectedAppearance.nmTorso_Underlay,	ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmArms_Underlay',		OriginalAppearance.nmArms_Underlay,		SelectedAppearance.nmArms_Underlay,		ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmLegs_Underlay',		OriginalAppearance.nmLegs_Underlay,		SelectedAppearance.nmLegs_Underlay,		ECosmeticType_Name);
	}
	// TATTOOS - thanks to Xym for Localize()
	if (MaybeCreateOptionCategory('bShowCategoryTattoos', Localize("UIArmory_Customize", "m_strBaseLabels[eUICustomizeBase_Tattoos]", "XComGame")))
	{
		MaybeCreateAppearanceOption('nmTattoo_LeftArm',		OriginalAppearance.nmTattoo_LeftArm,	SelectedAppearance.nmTattoo_LeftArm,	ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmTattoo_RightArm',	OriginalAppearance.nmTattoo_RightArm,	SelectedAppearance.nmTattoo_RightArm,	ECosmeticType_Name);
		MaybeCreateOptionColorInt('iTattooTint',			OriginalAppearance.iTattooTint,			SelectedAppearance.iTattooTint,			ePalette_ArmorTint);
	}
	// ARMOR PATTERN
	if (MaybeCreateOptionCategory('bShowCategoryArmorPattern', class'UICustomize_Body'.default.m_strArmorPattern))
	{
		MaybeCreateAppearanceOption('nmPatterns',			OriginalAppearance.nmPatterns,			SelectedAppearance.nmPatterns,			ECosmeticType_Name);
		MaybeCreateOptionColorInt('iArmorTint',				OriginalAppearance.iArmorTint,			SelectedAppearance.iArmorTint,			ePalette_ArmorTint);
		MaybeCreateOptionColorInt('iArmorTintSecondary',	OriginalAppearance.iArmorTintSecondary, SelectedAppearance.iArmorTintSecondary, ePalette_ArmorTint, false);
		//MaybeCreateAppearanceOption('iArmorDeco',			OriginalAppearance.iArmorDeco,			SelectedAppearance.iArmorDeco,			ECosmeticType_Name);
	}
	// WEAPON PATTERN
	if (MaybeCreateOptionCategory('bShowCategoryWeaponPattern', class'UICustomize_Weapon'.default.m_strWeaponPattern))
	{
		MaybeCreateAppearanceOption('nmWeaponPattern',		OriginalAppearance.nmWeaponPattern,		SelectedAppearance.nmWeaponPattern,		ECosmeticType_Name);
		MaybeCreateOptionColorInt('iWeaponTint',			OriginalAppearance.iWeaponTint,			SelectedAppearance.iWeaponTint,			ePalette_ArmorTint);	
	}
	// PERSONALITY
	if (MaybeCreateOptionCategory('bShowCategoryPersonality', Localize("UIArmory_Customize", "m_strBaseLabels[eUICustomizeBase_Personality]", "XComGame")))
	{
		MaybeCreateOptionAttitude();
		MaybeCreateAppearanceOption('nmVoice',				OriginalAppearance.nmVoice,				SelectedAppearance.nmVoice,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmFlag',				OriginalAppearance.nmFlag,				SelectedAppearance.nmFlag,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('FirstName',			ArmoryUnit.GetFirstName(),				SelectedUnit.GetFirstName(),			ECosmeticType_Name);
		MaybeCreateAppearanceOption('LastName',				ArmoryUnit.GetLastName(),				SelectedUnit.GetLastName(),				ECosmeticType_Name);
		MaybeCreateAppearanceOption('Nickname',				ArmoryUnit.GetNickName(),				SelectedUnit.GetNickName(),				ECosmeticType_Name);
		MaybeCreateAppearanceOption('Biography',			ArmoryUnit.GetBackground(),				SelectedUnit.GetBackground(),			ECosmeticType_Biography);
		//MaybeCreateAppearanceOption('nmLanguage',			OriginalAppearance.nmLanguage,			SelectedAppearance.nmLanguage,			ECosmeticType_Name);
	}
}

private function MaybeCreateAppearanceOption(name OptionName, coerce string CurrentCosmetic, coerce string NewCosmetic, ECosmeticType CosmeticType)
{	
	local UIMechaListItem_Button	SpawnedItem;
	local string					strDesc;
	local bool						bChecked;
	local bool						bDisabled;
	local bool						bNewIsSameAsCurrent;

	`AMLOG(`showvar(OptionName) @ `showvar(CurrentCosmetic) @ `showvar(NewCosmetic));

	//if (OptionName == 'nmBeard' && ArmoryUnit.kAppearance.iGender == eGender_Female)
	//{
	//	return;
	//}

	// Don't create the cosmetic option if both the current appearance and selected appearance are the same or empty.
	switch (CosmeticType)
	{
		case ECosmeticType_Int:
		case ECosmeticType_GenderInt:
			bNewIsSameAsCurrent = int(CurrentCosmetic) == int(NewCosmetic);
			break;
		case ECosmeticType_Name:
			if (CurrentCosmetic == NewCosmetic || class'Help'.static.IsCosmeticEmpty(CurrentCosmetic) && class'Help'.static.IsCosmeticEmpty(NewCosmetic))
			{
				bNewIsSameAsCurrent = true;
			}
			break;
		case ECosmeticType_Biography:
			bNewIsSameAsCurrent = CurrentCosmetic == NewCosmetic;
			break;
		default:
			`AMLOG("WARNING :: Unknown cosmetic type:" @ CosmeticType); // Shouldn't ever happen, really
			return;
	}
	
	if (bNewIsSameAsCurrent && !bShowAllCosmeticOptions)
		return;

	`AMLOG("Creating option");

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	// If this option doesn't care about gender, then we load the saved preset for it.
	if (IsOptionGenderAgnostic(OptionName))
	{
		bChecked = GetOptionCheckboxPosition(OptionName);
	}
	else if (OriginalAppearance.iGender != SelectedAppearance.iGender) // Is gender change required?
	{
		// Disallow toggling the checkbox if the option cares about gender and we're changing either from non-empty or to non-empty.
		bDisabled = CosmeticType == ECosmeticType_Name && (!class'Help'.static.IsCosmeticEmpty(CurrentCosmetic) || class'Help'.static.IsCosmeticEmpty(NewCosmetic));

		if (IsCheckboxChecked('iGender')) // Are we doing gender change?
		{
			bChecked = true;
		}
		else
		{
			bChecked = false;
		}
	}

	switch (CosmeticType)
	{
		case ECosmeticType_Int:
			if (bNewIsSameAsCurrent)
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ CurrentCosmetic;
			else
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ CurrentCosmetic @ "->" @ NewCosmetic;
			SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OnOptionCheckboxChanged, none);
			break;

		case ECosmeticType_Name:
			if (bNewIsSameAsCurrent)
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetBodyPartFriendlyName(OptionName, CurrentCosmetic);
			else
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetBodyPartFriendlyName(OptionName, CurrentCosmetic) @ "->" @ GetBodyPartFriendlyName(OptionName, NewCosmetic);
			
			SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OnOptionCheckboxChanged, none);
			break;

		case ECosmeticType_GenderInt:
			if (bNewIsSameAsCurrent)
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetFriendlyGender(int(CurrentCosmetic));
			else
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetFriendlyGender(int(CurrentCosmetic)) @ "->" @ GetFriendlyGender(int(NewCosmetic));

			SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OnOptionCheckboxChanged, none);
			break;

		case ECosmeticType_Biography:
			strDesc = class'UICustomize_Info'.default.m_strEditBiography;	
			SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OnOptionCheckboxChanged, none);
			SpawnedItem.UpdateDataButton(strDesc, class'UICustomize_Info'.default.m_strPreviewVoice, OnPreviewBiographyButtonClicked);
			break;

		default:
			break;
	}

	SpawnedItem.SetDisabled(!bShowAllCosmeticOptions && bDisabled, strSameGenderRequired); // Have to do this after checkbox has been assigned to the list item.
}

private function MaybeCreateOptionAttitude()
{
	local UIMechaListItem SpawnedItem;
	local string strDesc;

	if (OriginalAppearance.iAttitude != SelectedAppearance.iAttitude || bShowAllCosmeticOptions)
	{
		SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('iAttitude');

		strDesc = class'UICustomize_Info'.default.m_strAttitude $ ":" @ OriginalAttitude.FriendlyName;
		if (OriginalAppearance.iAttitude != SelectedAppearance.iAttitude)
		{
			strDesc @= "->" @ SelectedAttitude.FriendlyName;
		}
									 
		SpawnedItem.UpdateDataCheckbox(strDesc, "", GetOptionCheckboxPosition('iAttitude'), OnOptionCheckboxChanged, none);
	}
}

private function MaybeCreateOptionColorInt(name OptionName, int iValue, int iNewValue, EColorPalette PaletteType, optional bool bPrimary = true)
{
	local UIMechaListItem_Color		SpawnedItem;
	local XComLinearColorPalette	Palette;
	local LinearColor				ParamColor;
	local LinearColor				NewParamColor;

	if (!bShowAllCosmeticOptions && iValue == iNewValue)
		return;

	SpawnedItem = Spawn(class'UIMechaListItem_Color', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName), 
			"",
			GetOptionCheckboxPosition(OptionName),
			OnOptionCheckboxChanged, 
			none);

	Palette = `CONTENT.GetColorPalette(PaletteType);
	if (bPrimary)
	{
		ParamColor = Palette.Entries[iValue].Primary;
		NewParamColor = Palette.Entries[iNewValue].Primary;
	}
	else
	{
		ParamColor = Palette.Entries[iValue].Secondary;
		NewParamColor = Palette.Entries[iNewValue].Secondary;
	}
	SpawnedItem.HTMLColorChip2 = GetHTMLColorFromLinearColor(NewParamColor);
	SpawnedItem.strColorText_1 = string(iValue);
	SpawnedItem.strColorText_2 = string(iNewValue);
	SpawnedItem.UpdateDataColorChip(GetOptionFriendlyName(OptionName), GetHTMLColorFromLinearColor(ParamColor));	
}

private function OnPreviewBiographyButtonClicked(UIButton ButtonSource)
{
	local UIScreen_Biography BioScreen;

	SavePresetCheckboxPositions();
	BioScreen = Movie.Pres.Spawn(class'UIScreen_Biography', self);
	Movie.Pres.ScreenStack.Push(BioScreen);
	BioScreen.ShowText(ArmoryUnit.GetBackground(), SelectedUnit.GetBackground());
}

function OnOptionCheckboxChanged(UICheckbox CheckBox)
{
	SavePresetCheckboxPositions();

	`AMLOG(CheckBox.GetParent(class'UIMechaListItem_Button').MCName @ CheckBox.bChecked);

	switch (CheckBox.GetParent(class'UIMechaListItem_Button').MCName)
	{
		case 'iGender':
			UpdateOptionsList();
			break;
		case 'bShowAllCosmeticOptions':
			bShowAllCosmeticOptions = !bShowAllCosmeticOptions;
			default.bShowAllCosmeticOptions = bShowAllCosmeticOptions;
			SaveConfig();
			UpdateOptionsList();
			return;
		default:
			break;
	}

	UpdateUnitAppearance();
}

function UIMechaListItem_Button CreateOptionShowAll()
{
	local UIMechaListItem_Button SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('bShowAllCosmeticOptions'); 
	SpawnedItem.UpdateDataCheckbox(strShowAllOptions, "", bShowAllCosmeticOptions, OnOptionCheckboxChanged, none);

	return SpawnedItem;
}

// ================================================================================================================================================
// OPTION LIST PRESETS

private function SavePresetCheckboxPositions()
{
	local CheckboxPresetStruct	NewStruct;
	local UIMechaListItem		ListItem;
	local int					Index;
	local bool					bFound;
	local int i;

	`AMLOG(GetFuncName() @ "Options in the list:" @ OptionsList.ItemCount @ "Saved options:" @ CheckboxPresets.Length);

	NewStruct.Preset = CurrentPreset;

	if (Presets.Length > 0)
	{
		i = Presets.Length + 2; // 2 list members above the 0th preset.
	}
	for (i = i; i < OptionsList.ItemCount; i++) // "i = i" bypasses compile error. Just need to have something in there.
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		`AMLOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked);

		bFound = false;
		for (Index = 0; Index < CheckboxPresets.Length; Index++)
		{
			if (CheckboxPresets[Index].OptionName == ListItem.MCName &&
				CheckboxPresets[Index].Preset == CurrentPreset)
			{
				CheckboxPresets[Index].bChecked = ListItem.Checkbox.bChecked;
				bFound = true;
				break;
			}
		}

		if (!bFound)
		{
			NewStruct.OptionName = ListItem.MCName;
			NewStruct.bChecked = ListItem.Checkbox.bChecked;
			CheckboxPresets.AddItem(NewStruct);
		}
	}
	
	default.CheckboxPresets = CheckboxPresets; // This is actually necessary
	SaveConfig();
}

private function ApplyPresetCheckboxPositions()
{
	local CheckboxPresetStruct CheckboxPreset;

	foreach CheckboxPresets(CheckboxPreset)
	{
		if (CheckboxPreset.Preset == CurrentPreset)
		{
			`AMLOG("Setting preset checkbox:" @ CheckboxPreset.OptionName @ CheckboxPreset.bChecked);
			SetOptionsListCheckbox(CheckboxPreset.OptionName, CheckboxPreset.bChecked);
		}
	}
}

private function bool GetOptionCheckboxPosition(const name OptionName)
{
	local CheckboxPresetStruct CheckboxPreset;

	foreach CheckboxPresets(CheckboxPreset)
	{
		if (CheckboxPreset.Preset == CurrentPreset && CheckboxPreset.OptionName == OptionName)
		{
			return CheckboxPreset.bChecked;
		}
	}
}

private function CreateOptionPresets()
{
	local UIMechaListItem_Button SpawnedItem;
	local name PresetName;

	if (Presets.Length == 0)
		return;

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(); 
	SpawnedItem.UpdateDataCheckbox("", "", bShowPresets, OptionShowPresetsChanged);
	SpawnedItem.UpdateDataButton(`GREEN(`CAPS(class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset)), strCreatePreset, OnCreatePresetButtonClicked);

	`AMLOG(GetFuncName() @ `showvar(CurrentPreset) @ `showvar(bShowPresets));

	if (!bShowPresets)
		return;

	foreach Presets(PresetName)
	{
		CreateOptionPreset(PresetName, GetPresetFriendlyName(PresetName), "", CurrentPreset == PresetName);
	}
	UpdatePresetListItemsButtons();
}

private function CreateOptionPreset(name OptionName, string strText, string strTooltip, optional bool bChecked)
{
	local UIMechaListItem_Button SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);
	SpawnedItem.UpdateDataCheckbox(strText, strTooltip, bChecked, OptionPresetCheckboxChanged, none);

	`AMLOG(`showvar(OptionName) @ `showvar(bChecked));
}

private function OnCopyPresetButtonClicked(UIButton ButtonSource)
{
	local CheckboxPresetStruct	NewPresetStruct;
	local name					CopyPreset;
	local int i;

	CopyPreset = ButtonSource.GetParent(class'UIMechaListItem_Button').MCName;

	`AMLOG("Copying preset" @ CopyPreset @ "into" @ CurrentPreset);

	// Wipe settings for the current present
	for (i = CheckboxPresets.Length - 1; i >= 0; i--)
	{
		if (CheckboxPresets[i].Preset == CurrentPreset)
		{
			CheckboxPresets.Remove(i, 1);
		}
	}
	// Copy the new settings
	for (i = CheckboxPresets.Length - 1; i >= 0; i--)
	{
		if (CheckboxPresets[i].Preset == CopyPreset)
		{
			NewPresetStruct = CheckboxPresets[i];
			NewPresetStruct.Preset = CurrentPreset;
			CheckboxPresets.AddItem(NewPresetStruct);
		}
	}

	default.CheckboxPresets = CheckboxPresets;
	SaveConfig();

	UpdateOptionsList();
	ApplyPresetCheckboxPositions();
	UpdateUnitAppearance();
}

private function OnCreatePresetButtonClicked(UIButton ButtonSource)
{
	local TInputDialogData kData;

	kData.strTitle = strCreatePresetTitle;
	kData.iMaxChars = 63;
	kData.strInputBoxText = Repl(GetPresetFriendlyName(CurrentPreset), " ", "_") $ strCreatePresetText;
	kData.fnCallbackAccepted = OnCreatePresetInputBoxAccepted;

	Movie.Pres.UIInputDialog(kData);
}

function OnCreatePresetInputBoxAccepted(string text)
{
	local CheckboxPresetStruct	NewPresetStruct;
	local name					NewPresetName;
	local int i;

	text = Repl(text, " ", "_"); // Oh, you want to break this preset by putting spaces into a 'name'? I'm afraid I can't let you do that, Dave..

	NewPresetName = name(text);

	if (Presets.Find(NewPresetName) != INDEX_NONE)
	{
		// Not letting you create duplicates either.
		ShowInfoPopup(strDuplicatePresetDisallowedTitle, strDuplicatePresetDisallowedText, eDialog_Warning);
		return;
	}

	Presets.AddItem(NewPresetName);

	// Copy settings from current preset to the new preset
	for (i = CheckboxPresets.Length - 1; i >= 0; i--)
	{
		if (CheckboxPresets[i].Preset == CurrentPreset)
		{
			NewPresetStruct = CheckboxPresets[i];
			NewPresetStruct.Preset = NewPresetName;
			CheckboxPresets.AddItem(NewPresetStruct);
		}
	}

	default.CheckboxPresets = CheckboxPresets;
	default.Presets = Presets;
	self.SaveConfig();

	CurrentPreset = NewPresetName;
	//ApplyPresetCheckboxPositions(); // No need, settins would be identical.
	UpdateOptionsList();
}

function OptionsListItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIMechaListItem ListItem;

	// Exit early if the player clicked on the first two members in the list, or anywhere below the presets.
	if (ItemIndex < 2 || ItemIndex >= Presets.Length + 2) // +2 members above the first preset in the list
		return;
	
	ListItem = UIMechaListItem(OptionsList.GetItem(ItemIndex));
	if (ListItem != none)
	{
		OptionPresetCheckboxChanged(ListItem.Checkbox);
	}
}

function OptionShowPresetsChanged(UICheckbox CheckBox)
{
	bShowPresets = CheckBox.bChecked;
	default.bShowPresets = bShowPresets;
	self.SaveConfig();
	UpdateOptionsList();
}

function OptionPresetCheckboxChanged(UICheckbox CheckBox)
{
	local name PresetName;
	local name CyclePreset;

	PresetName = CheckBox.GetParent(class'UIMechaListItem_Button').MCName;
	if (Presets.Find(PresetName) != INDEX_NONE)
	{
		SavePresetCheckboxPositions();
		CurrentPreset = PresetName;

		`AMLOG("Activating preset:" @ CurrentPreset);
	
		// Toggle off all other preset checkboxes
		foreach Presets(CyclePreset)
		{
			SetOptionsListCheckbox(CyclePreset, CyclePreset == CurrentPreset);
		}
		ApplyPresetCheckboxPositions();
		UpdateUnitAppearance();
		UpdatePresetListItemsButtons();
	}
}

private function UpdatePresetListItemsButtons()
{
	local UIMechaListItem_Button	ListItem;
	local name						PresetName;
	
	foreach Presets(PresetName)
	{
		if (PresetName == 'PresetDefault') // Default preset doesn't have a button to update.
			continue;

		ListItem = UIMechaListItem_Button(OptionsList.ItemContainer.GetChildByName(PresetName));
		if (ListItem != none)
		{		
			// If the currently selected preset is the default one, then set all buttons to copy mode and enable them.
			if (CurrentPreset == 'PresetDefault')
			{
				ListItem.UpdateDataButton(ListItem.Desc.htmlText, strCopyPreset, OnCopyPresetButtonClicked);
				ListItem.Button.SetDisabled(false);
				ListItem.Button.RemoveTooltip();
			}
			else if (PresetName == CurrentPreset) // Otherwise - currently selected preset can be deleted.
			{
				ListItem.UpdateDataButton(ListItem.Desc.htmlText, strDeletePreset, OnDeletePresetButtonClicked);
				if (PresetName == 'PresetUniform')
				{
					ListItem.Button.SetDisabled(true, strCannotDeleteThisPreset); // Cannot allow deleting the uniform preset.
				}
				else
				{
					ListItem.Button.SetDisabled(false);
					ListItem.Button.RemoveTooltip();
				}
			}
			else // And all other preset buttons are set to copy mode and disabled.
			{
				ListItem.UpdateDataButton(ListItem.Desc.htmlText, strCopyPreset, OnCopyPresetButtonClicked);
				ListItem.Button.SetDisabled(true, strCopyPresetButtonDisabled);
			}							
		}
	}
}

private function OnDeletePresetButtonClicked(UIButton ButtonSource)
{
	//local name DeletePreset;
	local int i;

	//DeletePreset = ButtonSource.GetParent(class'UIMechaListItem_Button').MCName;

	`AMLOG("Deleting preset:" @ CurrentPreset @ "This preset exists:" @ Presets.Find(CurrentPreset) != INDEX_NONE);

	Presets.RemoveItem(CurrentPreset);

	// Wipe preset settings for the preset we're deleting.
	for (i = CheckboxPresets.Length - 1; i >= 0; i--)
	{
		if (CheckboxPresets[i].Preset == CurrentPreset)
		{
			CheckboxPresets.Remove(i, 1);
		}
	}

	default.Presets = Presets;
	default.CheckboxPresets = CheckboxPresets;
	SaveConfig();

	CurrentPreset = 'PresetDefault';
	UpdateOptionsList();
	ApplyPresetCheckboxPositions();
	UpdateUnitAppearance();
}

// ================================================================================================================================================
// OPTION LIST CATEGORIES

private function bool MaybeCreateOptionCategory(name CategoryName, string strText)
{
	local UIMechaListItem SpawnedItem;
	local bool bChecked;

	if (bShowAllCosmeticOptions || ShouldShowCategoryOption(CategoryName))
	{
		SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem(CategoryName); 
		
		bChecked = bShowAllCosmeticOptions || GetOptionCategoryCheckboxStatus(CategoryName);

		SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.GetColoredText(`CAPS(strText), eUIState_Warning),
			"", bChecked, OptionCategoryCheckboxChanged, none);

		SpawnedItem.SetDisabled(bShowAllCosmeticOptions);

		return bChecked || bShowAllCosmeticOptions;
	}
	return bShowAllCosmeticOptions;
}

private function bool ShouldShowCategoryOption(name CategoryName)
{
	switch (CategoryName)
	{
		case 'bShowCategoryHead': return ShouldShowHeadCategory();
		case 'bShowCategoryBody': return ShouldShowBodyCategory();
		case 'bShowCategoryTattoos': return ShouldShowTattooCategory();
		case 'bShowCategoryArmorPattern': return ShouldShowArmorPatternCategory();
		case 'bShowCategoryWeaponPattern': return ShouldShowWeaponPatternCategory();
		case 'bShowCategoryPersonality': return ShouldShowPersonalityCategory();
		default:
			return false;
	}
}

private function bool ShouldShowHeadCategory()
{	
	return  OriginalAppearance.iRace != SelectedAppearance.iRace ||
			OriginalAppearance.iSkinColor != SelectedAppearance.iSkinColor ||
			OriginalAppearance.nmHead != SelectedAppearance.nmHead ||
			OriginalAppearance.nmHelmet != SelectedAppearance.nmHelmet ||
			OriginalAppearance.nmFacePropLower != SelectedAppearance.nmFacePropLower ||
			OriginalAppearance.nmFacePropUpper != SelectedAppearance.nmFacePropUpper ||
			OriginalAppearance.nmHaircut != SelectedAppearance.nmHaircut ||
			OriginalAppearance.nmBeard != SelectedAppearance.nmBeard ||
			OriginalAppearance.iHairColor != SelectedAppearance.iHairColor ||
			OriginalAppearance.iEyeColor != SelectedAppearance.iEyeColor ||
			OriginalAppearance.nmScars != SelectedAppearance.nmScars || 
			OriginalAppearance.nmFacePaint != SelectedAppearance.nmFacePaint;
}

private function bool ShouldShowBodyCategory()
{	
	return  OriginalAppearance.nmTorso != SelectedAppearance.nmTorso ||
			OriginalAppearance.nmArms != SelectedAppearance.nmArms ||				
			OriginalAppearance.nmLegs != SelectedAppearance.nmLegs ||					
			OriginalAppearance.nmLeftArm != SelectedAppearance.nmLeftArm ||
			OriginalAppearance.nmRightArm != SelectedAppearance.nmRightArm ||
			OriginalAppearance.nmLeftArmDeco != SelectedAppearance.nmLeftArmDeco ||
			OriginalAppearance.nmRightArmDeco != SelectedAppearance.nmRightArmDeco ||		
			OriginalAppearance.nmLeftForearm != SelectedAppearance.nmLeftForearm ||	
			OriginalAppearance.nmRightForearm != SelectedAppearance.nmRightForearm ||		
			OriginalAppearance.nmThighs != SelectedAppearance.nmThighs ||
			OriginalAppearance.nmShins != SelectedAppearance.nmShins ||				
			OriginalAppearance.nmTorsoDeco != SelectedAppearance.nmTorsoDeco;
}

private function bool ShouldShowTattooCategory()
{	
	return   OriginalAppearance.nmTattoo_LeftArm != SelectedAppearance.nmTattoo_LeftArm ||
			 OriginalAppearance.nmTattoo_RightArm != SelectedAppearance.nmTattoo_RightArm ||
			 ShouldShowTatooColorOption();
}
private function bool ShouldShowTatooColorOption()
{
	// Show tattoo color only if we're changing it *and* at least one of the tattoos for the new appearance isn't empty
	return	OriginalAppearance.iTattooTint != SelectedAppearance.iTattooTint && 
			!class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmTattoo_LeftArm) &&
			!class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmTattoo_RightArm);
}

private function bool ShouldShowArmorPatternCategory()
{	
	return OriginalAppearance.nmPatterns != SelectedAppearance.nmPatterns ||		
		   OriginalAppearance.iArmorTint != SelectedAppearance.iArmorTint ||				
		   OriginalAppearance.iArmorTintSecondary != SelectedAppearance.iArmorTintSecondary;
}

private function bool ShouldShowWeaponPatternCategory()
{	
	return	OriginalAppearance.nmWeaponPattern != SelectedAppearance.nmWeaponPattern ||
			OriginalAppearance.iWeaponTint != SelectedAppearance.iWeaponTint;
}

private function bool ShouldShowPersonalityCategory()
{	
	return	OriginalAppearance.iAttitude != SelectedAppearance.iAttitude ||
			OriginalAppearance.nmVoice != SelectedAppearance.nmVoice ||		
			OriginalAppearance.nmFlag != SelectedAppearance.nmFlag ||
			ArmoryUnit.GetFirstName() != SelectedUnit.GetFirstName() ||
			ArmoryUnit.GetLastName() != SelectedUnit.GetLastName() ||
			ArmoryUnit.GetNickName() != SelectedUnit.GetNickName() ||
			ArmoryUnit.GetBackground() != SelectedUnit.GetBackground();				
}

private function bool GetOptionCategoryCheckboxStatus(name CategoryName)
{
	switch (CategoryName)
	{
		case 'bShowCategoryHead': return bShowCategoryHead;
		case 'bShowCategoryBody': return bShowCategoryBody;
		case 'bShowCategoryTattoos': return bShowCategoryTattoos;
		case 'bShowCategoryArmorPattern': return bShowCategoryArmorPattern;
		case 'bShowCategoryWeaponPattern': return bShowCategoryWeaponPattern;
		case 'bShowCategoryPersonality': return bShowCategoryPersonality;
		default:
			return false;
	}
}

private function SetOptionCategoryCheckboxStatus(name CategoryName, bool bNewValue)
{
	switch (CategoryName)
	{
		case 'bShowCategoryHead': bShowCategoryHead = bNewValue; break;
		case 'bShowCategoryBody': bShowCategoryBody = bNewValue; break;
		case 'bShowCategoryTattoos': bShowCategoryTattoos = bNewValue; break;
		case 'bShowCategoryArmorPattern': bShowCategoryArmorPattern = bNewValue; break;
		case 'bShowCategoryWeaponPattern': bShowCategoryWeaponPattern = bNewValue; break;
		case 'bShowCategoryPersonality': bShowCategoryPersonality = bNewValue; break;
		default:
			return;
	}
}

private function OptionCategoryCheckboxChanged(UICheckbox CheckBox)
{
	SetOptionCategoryCheckboxStatus(CheckBox.GetParent(class'UIMechaListItem').MCName, CheckBox.bChecked);
	UpdateOptionsList();
}

// ================================================================================================================================================
// LOCALIZATION HELPERS

private function string GetBodyPartFriendlyName(name OptionName, coerce string Cosmetic)
{
	local X2BodyPartTemplate	BodyPartTemplate;
	local name					CosmeticTemplateName;
	local string				PartType;

	if (class'Help'.static.IsCosmeticEmpty(Cosmetic))
		return class'UIPhotoboothBase'.default.m_strEmptyOption; // "none"

	if (OptionName == 'nmFlag')
		return GetFriendlyCountryName(Cosmetic);

	PartType = GetPartType(OptionName);
	CosmeticTemplateName = name(Cosmetic);
	if (PartType != "" && CosmeticTemplateName != '')
	{
		BodyPartTemplate = BodyPartMgr.FindUberTemplate(PartType, CosmeticTemplateName);
	}

	if (BodyPartTemplate != none && BodyPartTemplate.DisplayName != "")
	{
		`AMLOG("No localized name for body part template:" @ BodyPartTemplate.DataName @ `showvar(PartType) @ `showvar(OptionName));
		return BodyPartTemplate.DisplayName;
	}

	return string(CosmeticTemplateName);
}

private function string GetPartType(name OptionName)
{
	switch (OptionName)
	{
	case'nmHead': return "Head";
	case'nmHaircut': return "Hair";
	case'nmBeard': return "Beards";
	case'nmVoice': return "Voice";
	case'nmFlag': return ""; // Handled separately
	case'nmPatterns': return "Patterns";
	case'nmWeaponPattern': return "Patterns";
	case'nmTorso': return "Torso";
	case'nmArms': return "Arms";
	case'nmLegs': return "Legs";
	case'nmHelmet': return "Helmets";
	case'nmEye': return "Eyes";
	case'nmTeeth': return "Teeth";
	case'nmFacePropUpper': return "FacePropsUpper";
	case'nmFacePropLower': return "FacePropsLower";
	case'nmTattoo_LeftArm': return "Tattoos";
	case'nmTattoo_RightArm': return "Tattoos";
	case'nmScars': return "Scars";
	case'nmTorso_Underlay': return "Torso";
	case'nmArms_Underlay': return "Arms";
	case'nmLegs_Underlay': return "Legs";
	case'nmFacePaint': return "Facepaint";
	case'nmLeftArm': return "LeftArm";
	case'nmRightArm': return "RightArm";
	case'nmLeftArmDeco': return "LeftArmDeco";
	case'nmRightArmDeco': return "RightArmDeco";
	case'nmLeftForearm': return "LeftForearm";
	case'nmRightForearm': return "RightForearm";
	case'nmThighs': return "Thighs";
	case'nmShins': return "Shins";
	case'nmTorsoDeco': return "TorsoDeco";
	default:
		return "";
	}
	
	//DecoKits
	//case'nmLanguage': return "";
}

static private function bool ShouldCopyUniformPiece(const name UniformPiece, const name PresetName)
{
	local CheckboxPresetStruct CheckboxPreset;

	foreach default.CheckboxPresets(CheckboxPreset)
	{
		if (CheckboxPreset.OptionName == UniformPiece &&
			CheckboxPreset.Preset == PresetName)
		{
			return CheckboxPreset.bChecked;
		}
	}
	return false;
}

static final function CopyAppearance_Static(out TAppearance NewAppearance, const TAppearance UniformAppearance, const name PresetName)
{
	local bool bGenderChange;

	if (ShouldCopyUniformPiece('iGender', PresetName))
	{
		bGenderChange = true;
		NewAppearance.iGender = UniformAppearance.iGender; 
		NewAppearance.nmPawn = UniformAppearance.nmPawn;
		NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
		NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
		NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	}
	if (bGenderChange || NewAppearance.iGender == UniformAppearance.iGender)
	{		
		if (ShouldCopyUniformPiece('nmHead', PresetName)) {NewAppearance.nmHead = UniformAppearance.nmHead; 
														   NewAppearance.nmEye = UniformAppearance.nmEye; 
														   NewAppearance.nmTeeth = UniformAppearance.nmTeeth; 
														   NewAppearance.iRace = UniformAppearance.iRace;}
		if (ShouldCopyUniformPiece('nmHaircut', PresetName)) NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
		if (ShouldCopyUniformPiece('nmBeard', PresetName)) NewAppearance.nmBeard = UniformAppearance.nmBeard;
		if (ShouldCopyUniformPiece('nmTorso', PresetName)) NewAppearance.nmTorso = UniformAppearance.nmTorso;
		if (ShouldCopyUniformPiece('nmArms', PresetName)) NewAppearance.nmArms = UniformAppearance.nmArms;
		if (ShouldCopyUniformPiece('nmLegs', PresetName)) NewAppearance.nmLegs = UniformAppearance.nmLegs;
		if (ShouldCopyUniformPiece('nmHelmet', PresetName)) NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
		if (ShouldCopyUniformPiece('nmFacePropLower', PresetName)) NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
		if (ShouldCopyUniformPiece('nmFacePropUpper', PresetName)) NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
		if (ShouldCopyUniformPiece('nmVoice', PresetName)) NewAppearance.nmVoice = UniformAppearance.nmVoice;
		if (ShouldCopyUniformPiece('nmScars', PresetName)) NewAppearance.nmScars = UniformAppearance.nmScars;
		if (ShouldCopyUniformPiece('nmFacePaint', PresetName)) NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
		if (ShouldCopyUniformPiece('nmLeftArm', PresetName)) NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
		if (ShouldCopyUniformPiece('nmRightArm', PresetName)) NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
		if (ShouldCopyUniformPiece('nmLeftArmDeco', PresetName)) NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
		if (ShouldCopyUniformPiece('nmRightArmDeco', PresetName)) NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
		if (ShouldCopyUniformPiece('nmLeftForearm', PresetName)) NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
		if (ShouldCopyUniformPiece('nmRightForearm', PresetName)) NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
		if (ShouldCopyUniformPiece('nmThighs', PresetName)) NewAppearance.nmThighs = UniformAppearance.nmThighs;
		if (ShouldCopyUniformPiece('nmShins', PresetName)) NewAppearance.nmShins = UniformAppearance.nmShins;
		if (ShouldCopyUniformPiece('nmTorsoDeco', PresetName)) NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
	}
	if (ShouldCopyUniformPiece('iHairColor', PresetName)) NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (ShouldCopyUniformPiece('iSkinColor', PresetName)) NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (ShouldCopyUniformPiece('iEyeColor', PresetName)) NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (ShouldCopyUniformPiece('nmFlag', PresetName)) NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (ShouldCopyUniformPiece('iAttitude', PresetName)) NewAppearance.iAttitude = UniformAppearance.iAttitude;
	if (ShouldCopyUniformPiece('iArmorTint', PresetName)) NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (ShouldCopyUniformPiece('iArmorTintSecondary', PresetName)) NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (ShouldCopyUniformPiece('iWeaponTint', PresetName)) NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (ShouldCopyUniformPiece('iTattooTint', PresetName)) NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (ShouldCopyUniformPiece('nmWeaponPattern', PresetName)) NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (ShouldCopyUniformPiece('nmPatterns', PresetName)) NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	if (ShouldCopyUniformPiece('nmTattoo_LeftArm', PresetName)) NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (ShouldCopyUniformPiece('nmTattoo_RightArm', PresetName)) NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;

	//if (ShouldCopyUniformPiece('iArmorDeco', PresetName)) NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	//if (ShouldCopyUniformPiece('bGhostPawn', PresetName)) NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
	//if (ShouldCopyUniformPiece('nmLanguage', PresetName)) NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	//if (ShouldCopyUniformPiece('iFacialHair', PresetName)) NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
	//if (ShouldCopyUniformPiece('iVoice', PresetName)) NewAppearance.iVoice = UniformAppearance.iVoice;
}

// =============================================================================================================================
// LOCALIZATION HELPERS

private function string GetFriendlyCountryName(coerce name CountryTemplateName)
{
	local X2CountryTemplate	CountryTemplate;

	CountryTemplate = X2CountryTemplate(StratMgr.FindStrategyElementTemplate(CountryTemplateName));

	return CountryTemplate != none ? CountryTemplate.DisplayName : string(CountryTemplateName);
}

private function string GetFriendlyGender(int iGender)
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

static private function string GetOptionFriendlyName(name OptionName)
{
	switch (OptionName)
	{
	case'iRace': return class'UICustomize_Head'.default.m_strRace;
	case'iGender': return class'UICustomize_Info'.default.m_strGender;
	case'iHairColor': return class'UICustomize_Head'.default.m_strHairColor;
	case'iSkinColor': return class'UICustomize_Head'.default.m_strSkinColor;
	case'iEyeColor': return class'UICustomize_Head'.default.m_strEyeColor;
	case'iAttitude': return class'UICustomize_Info'.default.m_strAttitude;
	case'iArmorTint': return class'UICustomize_Body'.default.m_strMainColor;
	case'iArmorTintSecondary': return class'UICustomize_Body'.default.m_strSecondaryColor;
	case'iWeaponTint': return class'UICustomize_Weapon'.default.m_strWeaponColor;
	case'iTattooTint': return class'UICustomize_Body'.default.m_strTattooColor;
	case'nmHead': return class'UICustomize_Head'.default.m_strFace;
	case'nmHaircut': return class'UICustomize_Head'.default.m_strHair;
	case'nmBeard': return class'UICustomize_Head'.default.m_strFacialHair;
	case'nmVoice': return class'UICustomize_Info'.default.m_strVoice;
	case'nmFlag': return class'UICustomize_Info'.default.m_strNationality;
	case'nmPatterns': return class'UICustomize_Body'.default.m_strArmorPattern;
	case'nmWeaponPattern': return class'UICustomize_Weapon'.default.m_strWeaponPattern;
	case'nmTorso': return class'UICustomize_Body'.default.m_strTorso;
	case'nmArms': return class'UICustomize_Body'.default.m_strArms;
	case'nmLegs': return class'UICustomize_Body'.default.m_strLegs;
	case'nmHelmet': return class'UICustomize_Head'.default.m_strHelmet;
	case'nmFacePropUpper': return class'UICustomize_Head'.default.m_strUpperFaceProps;
	case'nmFacePropLower': return class'UICustomize_Head'.default.m_strLowerFaceProps;
	case'nmTattoo_LeftArm': return class'UICustomize_Body'.default.m_strTattoosLeft;
	case'nmTattoo_RightArm': return class'UICustomize_Body'.default.m_strTattoosRight;
	case'nmScars': return class'UICustomize_Head'.default.m_strScars;
	case'nmFacePaint': return class'UICustomize_Head'.default.m_strFacepaint;
	case'nmLeftArm': return class'UICustomize_Body'.default.m_strLeftArm;
	case'nmRightArm': return class'UICustomize_Body'.default.m_strRightArm;
	case'nmLeftArmDeco': return class'UICustomize_Body'.default.m_strLeftArmDeco;
	case'nmRightArmDeco': return class'UICustomize_Body'.default.m_strRightArmDeco;
	case'nmLeftForearm': return class'UICustomize_Body'.default.m_strLeftForearm;
	case'nmRightForearm': return class'UICustomize_Body'.default.m_strRightForearm;
	case'nmThighs': return class'UICustomize_Body'.default.m_strThighs;
	case'nmShins': return class'UICustomize_Body'.default.m_strShins;
	case'nmTorsoDeco': return class'UICustomize_Body'.default.m_strTorsoDeco;
	case'FirstName': return class'UICustomize_Info'.default.m_strFirstNameLabel;
	case'LastName': return class'UICustomize_Info'.default.m_strLastNameLabel;
	case'Nickname': return class'UICustomize_Info'.default.m_strNicknameLabel;

	//case'nmEye': return "Eye type";
	//case'nmTeeth': return "Teeth";
	//case'nmLanguage': return "Language";
	//case'nmTorso_Underlay': return "Torso Underlay";
	//case'nmArms_Underlay': return "Arms Underlay";
	//case'nmLegs_Underlay': return "Legs Underlay";
	//case'iFacialHair': return class'UICustomize_Head'.default.m_strFacialHair;
	//case'iArmorDeco': return class'UICustomize_Body'.default.m_strMainColor;
	default:
		return string(OptionName);
	}
}

private function string GetPresetFriendlyName(const name PresetName)
{
	local string strFriendlyName;

	strFriendlyName = Localize("UIManageAppearance", string(PresetName), "WOTCIridarAppearanceManager");
	if (strFriendlyName != "" && InStr(strFriendlyName, "WOTCIridarAppearanceManager.UIManageAppearance.") == INDEX_NONE) // Happens if there's no localization for this preset.
	{
		return strFriendlyName;
	}
	return string(PresetName);
}

// =============================================================================================================================
// UNIMPORTANT HELPER METHODS

private function bool IsOptionGenderAgnostic(const name OptionName)
{
	switch (OptionName)
	{
	// Gender agnostic
	case 'iGender': return true; // Counter-intuitive, but we need to return 'true' here so that this option itself is not disabled.
	case 'iHairColor': return true;
	case 'iSkinColor': return true;
	case 'iEyeColor': return true;
	case 'nmFlag': return true;
	case 'iAttitude': return true;
	case 'iArmorTint': return true;
	case 'iArmorTintSecondary': return true;
	case 'iWeaponTint': return true;
	case 'iTattooTint': return true;
	case 'nmTattoo_LeftArm': return true;
	case 'nmTattoo_RightArm': return true;
	case 'nmWeaponPattern': return true;
	case 'nmPatterns': return true;
	case 'FirstName': return true;
	case 'LastName': return true;
	case 'Nickname': return true;
	//case 'iVoice': return true;
	//case 'nmLanguage': return true;

	//Gender specific
	case 'iRace': return false;
	case 'nmHead': return false;
	case 'nmHaircut': return false;
	case 'nmBeard': return false;
	case 'nmPawn': return false;
	case 'nmTorso': return false;
	case 'nmArms': return false;
	case 'nmLegs': return false;
	case 'nmHelmet': return false;
	case 'nmEye': return false;
	case 'nmTeeth': return false;
	case 'nmFacePropLower': return false;
	case 'nmFacePropUpper': return false;
	case 'nmVoice': return false;
	case 'nmScars': return false;
	case 'nmTorso_Underlay': return false;
	case 'nmArms_Underlay': return false;
	case 'nmLegs_Underlay': return false;
	case 'nmFacePaint': return false;
	case 'nmLeftArm': return false;
	case 'nmRightArm': return false;
	case 'nmLeftArmDeco': return false;
	case 'nmRightArmDeco': return false;
	case 'nmLeftForearm': return false;
	case 'nmRightForearm': return false;
	case 'nmThighs': return false;
	case 'nmShins': return false;
	case 'nmTorsoDeco': return false;

	//case 'iFacialHair': return false;
	//case 'iArmorDeco': return false;
	//case 'bGhostPawn': return false;
	default:
		return true;
	}
}

static final function SetInitialSoldierListSettings()
{
	local UIManageAppearance	CDO;
	local AM_MCM_Defaults		CDO_Defaults;

	if (!default.bInitComplete)
	{
		CDO = UIManageAppearance(class'XComEngine'.static.GetClassDefaultObject(class'UIManageAppearance'));
		CDO_Defaults = AM_MCM_Defaults(class'XComEngine'.static.GetClassDefaultObject(class'AM_MCM_Defaults'));

		CDO.bInitComplete = true;
		CDO.bShowPresets = CDO_Defaults.bShowPresets;
		CDO.bShowCharPoolSoldiers = CDO_Defaults.bShowCharPoolSoldiers;
		CDO.bShowUniformSoldiers = CDO_Defaults.bShowUniformSoldiers;	
		CDO.bShowBarracksSoldiers = CDO_Defaults.bShowBarracksSoldiers;
		CDO.bShowDeadSoldiers = CDO_Defaults.bShowDeadSoldiers;
		CDO.bShowAllCosmeticOptions = CDO_Defaults.bShowAllCosmeticOptions;
		CDO.Presets = CDO_Defaults.Presets;
		CDO.CheckboxPresets = CDO_Defaults.CheckboxPresets;
		CDO.SaveConfig();
	}
}

private function string GetHTMLColorFromLinearColor(LinearColor ParamColor)
{
	local string ColorString;

	ColorString = Right(ToHex(int(ParamColor.R * 255.0f)), 2) $ Right(ToHex(int(ParamColor.G * 255.0f)), 2)  $ Right(ToHex(int(ParamColor.B * 255.0f)), 2);
	
	return ColorString;
}

private function FixScreenPosition()
{
	// Unrestricted Customization does two things we want to get rid of:
	// 1. Shifts the entire screen's position (breaking the intended UI element placement)
	// 2. Adds a 'tool panel' with buttons like Copy / Paste / Randomize appearance,
	// which would be nice to have, but it's (A) redundant and (B) there's no room for it.
	local UIPanel Panel;
	if (Y == -100)
	{
		foreach ChildPanels(Panel)
		{
			if (Panel.Class.Name == 'uc_ui_ToolPanel')
			{
				Panel.Hide();
				break;
			}
		}
		`AMLOG("Unrestricted Customization compatibility: applied.");
		SetPosition(0, 0);
		return;
	}
	// In case of lags, we restart the timer until the issue is successfully resolved.
	`AMLOG("Unrestricted Customization compatibility: failed to apply, restarting timer.");
	SetTimer(0.1f, false, nameof(FixScreenPosition), self);
}

// Don't look at me, that's how CP itself does this check :shrug:
final function bool IsUnitPresentInCampaign(const XComGameState_Unit CheckUnit)
{
	local XComGameState_Unit CycleUnit;

	foreach History.IterateByClassType(class'XComGameState_Unit', CycleUnit)
	{
		if (CycleUnit.GetFirstName() == CheckUnit.GetFirstName() &&
			CycleUnit.GetLastName() == CheckUnit.GetLastName())
		{
			return true;
		}
	}
	return false;
}

private function ShowInfoPopup(string strTitle, string strText, optional EUIDialogBoxDisplay eType)
{
	local TDialogueBoxData kDialogData;

	kDialogData.strTitle = strTitle;
	kDialogData.strText = strText;
	kDialogData.eType = eType;
	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericOK;

	Movie.Pres.UIRaiseDialog(kDialogData);
}

// Exclude presets and category checkboxes
final function bool IsCosmeticOption(const name OptionName)
{
	switch(OptionName)
	{
		case'nmHead': return true;
		case'iGender': return true;
		case'iRace': return true;
		case'nmHaircut': return true;
		case'iHairColor': return true;
		case'iFacialHair': return true;
		case'nmBeard': return true;
		case'iSkinColor': return true;
		case'iEyeColor': return true;
		case'nmFlag': return true;
		case'iVoice': return true;
		case'iAttitude': return true;
		case'iArmorDeco': return true;
		case'iArmorTint': return true;
		case'iArmorTintSecondary': return true;
		case'iWeaponTint': return true;
		case'iTattooTint': return true;
		case'nmWeaponPattern': return true;
		case'nmPawn': return true;
		case'nmTorso': return true;
		case'nmArms': return true;
		case'nmLegs': return true;
		case'nmHelmet': return true;
		case'nmEye': return true;
		case'nmTeeth': return true;
		case'nmFacePropLower': return true;
		case'nmFacePropUpper': return true;
		case'nmPatterns': return true;
		case'nmVoice': return true;
		case'nmLanguage': return true;
		case'nmTattoo_LeftArm': return true;
		case'nmTattoo_RightArm': return true;
		case'nmScars': return true;
		case'nmTorso_Underlay': return true;
		case'nmArms_Underlay': return true;
		case'nmLegs_Underlay': return true;
		case'nmFacePaint': return true;
		case'nmLeftArm': return true;
		case'nmRightArm': return true;
		case'nmLeftArmDeco': return true;
		case'nmRightArmDeco': return true;
		case'nmLeftForearm': return true;
		case'nmRightForearm': return true;
		case'nmThighs': return true;
		case'nmShins': return true;
		case'nmTorsoDeco': return true;
		case'bGhostPawn': return true;
	default:
		return false;
	}
}

final function string GetGenderArmorTemplate()
{
	return ArmorTemplateName $ ArmoryUnit.kAppearance.iGender;
}

// --------------------------------------------------------------------------------------

defaultproperties
{
	CurrentPreset = "PresetDefault"
	bCanExitWithoutPopup = true

	bShowCategoryHead = true
	bShowCategoryBody = true
	bShowCategoryTattoos = true
	bShowCategoryArmorPattern = true
	bShowCategoryWeaponPattern = true
	bShowCategoryPersonality = true
}

/*
private function LogAllOptions()
{
	local UIMechaListItem ListItem;
	local int i;

	`AMLOG(GetFuncName() @  OptionsList.ItemCount);
	`AMLOG("----------------------------------------------------------");

	for (i = 0; i < OptionsList.ItemCount; i++)
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none)
			continue;
			
		`AMLOG("List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ ListItem.Checkbox != none);
	}
	`AMLOG("----------------------------------------------------------");
}
*/