class UIManageAppearance extends UICustomize;

// TODO:
/*
# Bugs to be aware of:

Validate Appearance caused double pawn. Need for Validate Appearance occured when deleting appearance stores caused the unit to glitch out.
Attempting to switch the gender of a newly generated Reaper somehow switched their gender to None. It cannot be switched off of None.
The intermittent neanderthal bug.


# Bugs that were already fixed, potentially:

When entering Manage Appearance screen, gender sometimes doesn't refresh automatically, deforming the pawn.
The Uniform preset somehow got broken. 
Pawn sometimes remains on character pool screen. 

## Checks performed:
1. Saves stored appearance in CP.
2. Saves stored apearance when importing a unit from campaign into CP.
3. Individual uniform setting.
4. Saves stored appearance when exported and imported.
5. Deleting stored appearance.
6. Appearance validation options and button.
7. Appearance list.
8. Applying weapon pattern changes in CP and armory.
9. Appearance list - memorial and barracks
10. Saving, creating, deleting presets.
11. Applying changes to squad, barracks

## Addressed

Make chevron animation on Apply Changes button go away when there's no changes to apply. Alternatively, hide the button.
Should Apply Changes button select Original Apperance? --No, it shouldn't, user might want to copy stuff one by one from selected appearance.
Maybe allow Appearance Store button to work as a "reskin armor" button? - redundant, can be done with this mod's customization screen by importing unit's own appearance from another armor.

## Ideas for later

Cycle "can appear as" filters while on Character Pool screen.

Make the mod put on uniforms on friendly units that enter combat mid-mission, like from Additional Mission Types mod. (Void Light / resistance beacon item)

Make text on UIMechaListItem_Button long enough to be obscured by the button scroll from under the button rather than go under it.

Make clicking a list item in cosmetic options list toggle its checkbox.

Do CP units need a way to select whether they want to accept only class-specific or AnyClass uniforms?

Make the CP UI open customization menu for the soldier you clicked on, not the soldier under the mouse cursor when the UI code decides the sun is high enough to start working.

Sorting buttons for CP units?

Optimize performance on this screen? Don't create options all the time, maybe?

Patch Shen (and maybe Tygan) in a plugin mod so they can be uniform'd without their Mesh on their Pawn clipping.

Set up uniforms from the armory

Lock specific customization slots on the soldier, and lock them between all stored appearances whenever armor is equipped.

Compatibility with Allies Unknown classes? Can't select them in the CP or something like that.
Allies Unknown units with custom rookie class should be able to choose from different classes in CP
I have no idea how they coded that, but it would appear that they stem from a separate species specific rookie template, then get a class independently, while the game properly treats them as rookies, allowing them to train in GTS. however in the character pool there is no option to change their class, which is an issue for anyone using the "use my class" mod

Compatibility with Trainable Faction Soldiers? When switching to their class in character pool, the pawn gets "outdated", still wearing the last equipped armor on the soldier. Exiting and entering soldier customization fixes it.

Save modlist in CP files, and warn if mods are missing.

Make character pool loadout actually show up in game, with a toggle.

Investigate customizing off-duty (Underlay?) appearance.

Make GetApplyChangesNumUnits() take into account gender of the targeted soldier, as depending on selected cosmetic options they may not receive any changes.

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
var localized string strRacePrefix;
var localized string strApplyChangesButtonDisabled;
var localized string strInvalidPresetNameText;

// ==============================================================================
// Screen Options - preserved between game restarts.
var protected config(AppearanceManager) array<CheckboxPresetStruct> CheckboxPresets;
var protected config(AppearanceManager) array<name> Presets;
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
var protected X2PawnRefreshHelper				PawnRefreshHelper;

// ==============================================================================
// Cached Data - Selected Unit (Appearance)
var protected TAppearance					SelectedAppearance;
var protected X2SoldierPersonalityTemplate	SelectedAttitude;
var protected XComGameState_Unit			SelectedUnit;
var protected bool							bOriginalAppearanceSelected;

// ==============================================================================
// Cached Data - Armory Unit
var XComHumanPawn							ArmoryPawn;
var protected XComGameState_Unit			ArmoryUnit;
var protected vector						OriginalPawnLocation;
var protected TAppearance					OriginalAppearance; // Appearance to restore if the player exits the screen without selecting anything
var protected TAppearance					PreviousAppearance; // Briefly cached appearance, used to check if we need to refresh pawn
var /*protected*/ name						ArmorTemplateName; // Unprotected for the console command hack
var protected X2SoldierPersonalityTemplate	OriginalAttitude;

// ==============================================================================
// UI Elements - Cosmetic Options list on the left.
var protected UIBGBox	OptionsListBG;
var protected UIList	OptionsList;

// ==============================================================================
// UI Elements - Filters List in the upper right corner.
var protected UIBGBox	FiltersListBG;
var protected UIList	FiltersList;
var protected UIList	ApplyToList;

var protected UIBGBox	AppearanceListBG;
var protected UIList	AppearanceList;
var protected UILargeButton	ApplyChangesButton;

`include(WOTCIridarAppearanceManager\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

// ================================================================================================================================================
// INITIAL SETUP - called once when screen is pushed, or when switching to a new armory unit.

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// Cache stuff.
	PoolMgr = `CHARACTERPOOLMGRAM;
	if (PoolMgr == none)
		super.CloseScreen();

	List.Hide();
	ListBG.Hide();

	PawnRefreshHelper = new class'X2PawnRefreshHelper';
	PawnRefreshHelper.ManageAppearanceScreen = self;
	PawnRefreshHelper.InitHelper(CustomizeManager, PoolMgr);
	
	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	PawnMgr = Movie.Pres.GetUIPawnMgr();
	History = `XCOMHISTORY;
	CacheArmoryUnitData();

	// Create upper right list
	CreateFiltersList();

	AppearanceListBG = Spawn(class'UIBGBox', self);
	AppearanceListBG.LibID = class'UIUtilities_Controls'.const.MC_X2Background;
	AppearanceListBG.InitBG('armoryMenuBG_AM');
	AppearanceListBG.SetPosition(FiltersListBG.X, FiltersListBG.Y + FiltersListBG.Height + 10);
	AppearanceListBG.SetWidth(582);
	AppearanceListBG.SetHeight(1080 - AppearanceListBG.Y - 80);

	AppearanceList = Spawn(class'UIList', self).InitList('armoryMenuList_AM');
	AppearanceList.ItemPadding = 5;
	AppearanceList.bStickyHighlight = false;
	AppearanceList.SetWidth(542);
	AppearanceList.OnItemClicked = AppearanceListItemClicked;
	AppearanceList.SetPosition(ApplyToList.X, FiltersListBG.Y + FiltersListBG.Height + 20 + 5);
	AppearanceList.SetHeight(1080 - AppearanceList.Y - 80 - 20);

	AppearanceListBG.ProcessMouseEvents(AppearanceList.OnChildMouseEvent);

	// Mouse guard dims everything below the screen (most importantly the soldier) if we are a 2D screen.
	// Make it invisible (but still hit-test-able) - same logic as in UIMouseGuard for 3D
	if (!bIsIn3D) MouseGuardInst.SetAlpha(0);

	// Move the soldier name header further into the left upper corner.
	Header.SetPosition(20 + Header.Width, 10);
	
	// Create left list	of soldier customization options.
	OptionsListBG = Spawn(class'UIBGBox', self);
	OptionsListBG.LibID = class'UIUtilities_Controls'.const.MC_X2Background;
	OptionsListBG.InitBG('LeftOptionsListBG', 20, 170);
	OptionsListBG.SetAlpha(80);
	OptionsListBG.SetWidth(582);
	OptionsListBG.SetHeight(1080 - 60 - OptionsListBG.Y - 20);

	OptionsList = Spawn(class'UIList', self);
	OptionsList.bAnimateOnInit = false;
	OptionsList.InitList('LeftOptionsList', 30, 185);
	OptionsList.SetWidth(542);
	OptionsList.SetHeight(1080 - 75 - OptionsList.Y - 20);
	OptionsList.Navigator.LoopSelection = false;
	OptionsList.OnItemClicked = OptionsListItemClicked;
	
	OptionsListBG.ProcessMouseEvents(OptionsList.OnChildMouseEvent);

	if (class'Help'.static.IsUnrestrictedCustomizationLoaded())
	{
		`AMLOG("Unrestricted Customization compatibility: setting timer.");
		SetTimer(0.1f, false, nameof(FixScreenPosition), self);
	}

	CreateApplyChangesButton();
}

function CreateApplyChangesButton()
{
	local int iconYOffset;

	ApplyChangesButton = Spawn(class'UILargeButton', NavHelp.Screen);
	ApplyChangesButton.LibID = 'X2ContinueButton';
	ApplyChangesButton.bHideUntilRealized = true;

	switch (GetLanguage()) 
	{
	case "JPN":
		iconYOffset = -10;
		break;
	case "KOR":
		iconYOffset = -20;
		break;
	default:
		iconYOffset = -15;
		break;
	}
	if(`IsControllerActive)
	{
		ApplyChangesButton.InitLargeButton('AM_ApplyChangesButton', 
		class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetAdvanceButtonIcon(), 
		28, 28, iconYOffset) @ `CAPS(strApplyChangesButton));
	}
	else
	{
		ApplyChangesButton.InitLargeButton('AM_ApplyChangesButton', `CAPS(strApplyChangesButton));
	}
	ApplyChangesButton.DisableNavigation();
	ApplyChangesButton.AnchorBottomCenter();
	ApplyChangesButton.OffsetY = -10;
	ApplyChangesButton.OnClickedDelegate = OnApplyChangesClicked;
	ApplyChangesButton.Show();
	ApplyChangesButton.ShowBG(true);
	ApplyChangesButton.SetDisabled(true, strApplyChangesButtonDisabled); // Disabled reason doesn't seem to be working. Oh well.
}

// Button should be disabled if there are no changes to apply to this unit,
// unless we want to copy parts of the soldier's original appearance to other units.
function UpdateApplyChangesButtonVisibility()
{
	if (bShowAllCosmeticOptions && bOriginalAppearanceSelected)
	{
		ApplyChangesButton.SetDisabled(!GetApplyToListCheckboxStatus('ApplyToCharPool') && !GetApplyToListCheckboxStatus('ApplyToSquad') && !GetApplyToListCheckboxStatus('ApplyToBarracks'), strApplyChangesButtonDisabled);
	}
	else
	{
		ApplyChangesButton.SetDisabled(bCanExitWithoutPopup, strApplyChangesButtonDisabled);
	}
}

private function CacheArmoryUnitData()
{
	local X2ItemTemplate		ArmorTemplate;
	local XComGameState_Item	ItemState;

	bOriginalAppearanceSelected = true;

	ArmoryUnit = CustomizeManager.UpdatedUnitState;
	if (ArmoryUnit == none)
	{
		super.CloseScreen();
	}
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn == none)
	{
		super.CloseScreen();
	}

	if (class'Help'.static.IsUnrestrictedCustomizationLoaded())
	{
		ItemState = ArmoryUnit.GetItemInSlot(eInvSlot_Armor);
		if (ItemState != none)
		{
			ArmorTemplateName = ItemState.GetMyTemplateName();
		}
		else
		{
			ArmorTemplateName = PoolMgr.GetCharacterPoolEquippedArmor(ArmoryUnit);
		}
	}
	else
	{
		ArmorTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(ArmoryUnit.kAppearance.nmTorso);
		if (ArmorTemplate != none)
		{
			ArmorTemplateName = ArmorTemplate.DataName;
		}
	}

	SelectedUnit = ArmoryUnit;
	OriginalAppearance = ArmoryUnit.kAppearance;
	PreviousAppearance = OriginalAppearance;
	SelectedAppearance = OriginalAppearance;
	OriginalAttitude = ArmoryUnit.GetPersonalityTemplate();
	OriginalPawnLocation = ArmoryPawn.Location;
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
		UIMouseGuard_RotatePawn(MouseGuardInst).SetActorPawn(CustomizeManager.ActorPawn);
	}

	UpdateAppearanceList();
	UpdateOptionsList();
	UpdateUnitAppearance();
}

simulated function Show()
{
	super.Show();
	if (ApplyChangesButton != none) ApplyChangesButton.Show();
}

simulated function Hide()
{
	super.Hide();
	if (ApplyChangesButton != none) ApplyChangesButton.Hide();
}

// ================================================================================================================================================
// FILTER LIST MAIN FUNCTIONS - Filter list is located in the upper right corner, it determines which appearances are displayed in the appearance list.

function CreateFiltersList()
{
	local UIMechaListItem SpawnedItem;
	local UIManageAppearance_ListHeaderItem HeaderItem;

	FiltersListBG = Spawn(class'UIBGBox', self);
	FiltersListBG.LibID = class'UIUtilities_Controls'.const.MC_X2Background;
	FiltersListBG.InitBG('UpperRightFiltersListBG');
	FiltersListBG.SetAlpha(80);
	FiltersListBG.SetWidth(582);
	FiltersListBG.SetHeight(200);
	FiltersListBG.SetPosition(1920 - FiltersListBG.Width - 20, 10);

	ApplyToList = Spawn(class'UIList', self);
	ApplyToList.bAnimateOnInit = false;
	ApplyToList.InitList('UpperRightFiltersList');
	ApplyToList.SetPosition(FiltersListBG.X + 10, 25);
	ApplyToList.SetWidth(FiltersListBG.Width / 2 - 15);
	ApplyToList.SetHeight(FiltersListBG.Height - 20);
	ApplyToList.Navigator.LoopSelection = true;
	
	FiltersListBG.ProcessMouseEvents(FiltersList.OnChildMouseEvent);

	FiltersList = Spawn(class'UIList', self);
	FiltersList.bAnimateOnInit = false;
	FiltersList.InitList('UpperRightApplyToList');
	FiltersList.SetPosition(FiltersListBG.X + 10 + ApplyToList.Width + 10, 25);
	FiltersList.SetWidth(ApplyToList.Width);
	FiltersList.SetHeight(ApplyToList.Height);
	FiltersList.Navigator.LoopSelection = false;
	

	HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', ApplyToList.itemContainer);
	HeaderItem.bAnimateOnInit = false;
	HeaderItem.InitHeader();
	HeaderItem.SetLabel(strApplyTo);

	SpawnedItem = Spawn(class'UIMechaListItem', ApplyToList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('ApplyToThisUnit');
	SpawnedItem.UpdateDataCheckbox(`CAPS(strApplyToThisUnit), strApplyToThisUnitTip, true, OnApplyToCheckboxChanged, none);

	SpawnedItem = Spawn(class'UIMechaListItem', ApplyToList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('ApplyToSquad');
	SpawnedItem.UpdateDataCheckbox(`CAPS(class'UITLE_ChallengeModeMenu'.default.m_Header_Squad), strApplyToSquadTip, false, OnApplyToCheckboxChanged, none);
	SpawnedItem.SetDisabled(!bInArmory, strNotAvailableInCharacterPool);

	if (bInArmory)
	{
		SpawnedItem = Spawn(class'UIMechaListItem', ApplyToList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('ApplyToBarracks');
		SpawnedItem.UpdateDataCheckbox(`CAPS(class'XComKeybindingData'.default.m_arrAvengerBindableLabels[eABC_Barracks]), strApplyToBarracksTip, false, OnApplyToCheckboxChanged, none);
	}
	else
	{
		SpawnedItem = Spawn(class'UIMechaListItem', ApplyToList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('ApplyToCharPool');
		SpawnedItem.UpdateDataCheckbox(`CAPS(class'UICharacterPool'.default.m_strTitle), strApplyToCPTip, false, OnApplyToCheckboxChanged, none);
	}

	HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', FiltersList.itemContainer);
	HeaderItem.bAnimateOnInit = false;
	HeaderItem.InitHeader();
	HeaderItem.SetLabel(strFiltersTitle);

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
	SpawnedItem.UpdateDataCheckbox(`CAPS(class'UIArmory_Loadout'.default.m_strInventoryLabels[eInvSlot_Armor]), "", ArmorTemplateName != '', OnFilterCheckboxChanged, none); 
	SpawnedItem.SetDisabled(ArmorTemplateName == '', strNoArmorTemplateError @ ArmoryUnit.GetFullName());
}

private function OnApplyToCheckboxChanged(UICheckbox CheckBox)
{
	UpdateApplyChangesButtonVisibility();
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

function bool GetApplyToListCheckboxStatus(name FilterName)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(ApplyToList.ItemContainer.GetChildByName(FilterName, false));

	return ListItem != none && ListItem.Checkbox.bChecked;
}

private function OnApplyChangesClicked(UIButton Button)
{
	local TDialogueBoxData kDialogData;
	local int iNumUnitsToChange;

	if (`GETMCMVAR(MULTIPLE_UNIT_CHANGE_REQUIRES_CONFIRMATION))
	{
		// Show confirmation popup if we're changing more than one unit, counting the armory unit,
		// or if we're changing units other than armory unit.
		iNumUnitsToChange = GetApplyChangesNumUnits();
		if (iNumUnitsToChange > 1 || iNumUnitsToChange != 0 && bOriginalAppearanceSelected && (	GetApplyToListCheckboxStatus('ApplyToCharPool') || 
																								GetApplyToListCheckboxStatus('ApplyToSquad') || 
																								GetApplyToListCheckboxStatus('ApplyToBarracks')))
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
	local TAppearance						TestAppearance;

	if (GetApplyToListCheckboxStatus('ApplyToThisUnit'))
	{
		if (OriginalAppearance != SelectedAppearance)
		{
			iNumUnits++;
		}
	}

	if (GetApplyToListCheckboxStatus('ApplyToCharPool'))
	{
		foreach PoolMgr.CharacterPool(UnitState)
		{
			if (UnitState.ObjectID == ArmoryUnit.ObjectID)
				continue;

			// Check if we'd make any changes to unit's appearance.
			TestAppearance = UnitState.kAppearance;
			CopyAppearance(TestAppearance, SelectedAppearance, UnitState, SelectedUnit);
			if (TestAppearance != UnitState.kAppearance)
			{
				iNumUnits++;
			}
		}
	}

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	if (XComHQ == none)
		return iNumUnits;

	if (GetApplyToListCheckboxStatus('ApplyToSquad'))
	{
		foreach XComHQ.Squad(SquadUnitRef)
		{
			if (SquadUnitRef.ObjectID == ArmoryUnit.ObjectID)
				continue;

			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SquadUnitRef.ObjectID));
			if (UnitState != none)
			{
				TestAppearance = UnitState.kAppearance;
				CopyAppearance(TestAppearance, SelectedAppearance, UnitState, SelectedUnit);
				if (TestAppearance != UnitState.kAppearance)
				{
					iNumUnits++;
				}
			}
		}
	}
	if (GetApplyToListCheckboxStatus('ApplyToBarracks'))
	{
		UnitStates = XComHQ.GetSoldiers(true, true);
		foreach UnitStates(UnitState)
		{
			if (UnitState.ObjectID == ArmoryUnit.ObjectID)
				continue;

			TestAppearance = UnitState.kAppearance;
			CopyAppearance(TestAppearance, SelectedAppearance, UnitState, SelectedUnit);
			if (TestAppearance != UnitState.kAppearance)
			{
				iNumUnits++;
			}
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
	local UIManageAppearance_ListHeaderItem HeaderItem;
	local XComGameState_Unit				CheckUnit;
	local XComGameState_HeadquartersXCom	XComHQ;
	local array<XComGameState_Unit>			Soldiers;
	local string							strDisplaySearchText;

	AppearanceList.ClearItems();

	HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', AppearanceList.itemContainer);
	HeaderItem.bAnimateOnInit = false;
	HeaderItem.InitHeader();
	HeaderItem.SetLabel(`CAPS(strSelectAppearanceTitle));
	HeaderItem.DisableCollapseToggle();
	HeaderItem.bActionButtonEnabled = true;

	strDisplaySearchText = strSearchTitle;
	if (SearchText != "")
	{
		if (Len(SearchText) > 12)
		{
			strDisplaySearchText $= ":" @ Left(SearchText, 11) $ "...";
		}
		else
		{
			strDisplaySearchText $= ":" @ SearchText;
		}
	}

	HeaderItem.ActionButton.SetText(strDisplaySearchText);
	HeaderItem.OnActionInteracted = OnSearchButtonClicked;
	HeaderItem.RealizeLayoutAndNavigation();
	HeaderItem.ActionButton.SetX(HeaderItem.ActionButton.X - 45); // Nudge the action button to the left since there's no eye icon on this header.
		
	// First entry is always "No change"
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataCheckbox(strOriginalAppearance, "", bOriginalAppearanceSelected, AppearanceOptionCheckboxChanged, none);
	SpawnedItem.StoredAppearance.Appearance = OriginalAppearance;
	SpawnedItem.bOriginalAppearance = true;
	SpawnedItem.UpdateDataButton(strOriginalAppearance, strSaveAsUniform, OnSaveAsUniformButtonClicked);

	// Uniforms
	HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', AppearanceList.itemContainer);
	HeaderItem.bAnimateOnInit = false;
	HeaderItem.InitHeader('bShowUniformSoldiers');
	HeaderItem.SetLabel(`CAPS(strUniformsTitle));
	HeaderItem.EnableCollapseToggle(bShowUniformSoldiers);
	HeaderItem.OnCollapseToggled = AppearanceListCategoryCollapseChanged;
	HeaderItem.RealizeLayoutAndNavigation();

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
	HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', AppearanceList.itemContainer);
	HeaderItem.bAnimateOnInit = false;
	HeaderItem.InitHeader('bShowCharPoolSoldiers');
	HeaderItem.SetLabel(`CAPS(class'UICharacterPool'.default.m_strTitle));
	HeaderItem.EnableCollapseToggle(bShowCharPoolSoldiers);
	HeaderItem.OnCollapseToggled = AppearanceListCategoryCollapseChanged;
	HeaderItem.RealizeLayoutAndNavigation();

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
	if (bInArmory)
	{
		// Soldiers in barracks
		HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', AppearanceList.itemContainer);
		HeaderItem.bAnimateOnInit = false;
		HeaderItem.InitHeader('bShowBarracksSoldiers');
		HeaderItem.SetLabel(`CAPS(class'XComKeybindingData'.default.m_arrAvengerBindableLabels[eABC_Barracks]));
		HeaderItem.EnableCollapseToggle(bShowBarracksSoldiers);
		HeaderItem.OnCollapseToggled = AppearanceListCategoryCollapseChanged;
		HeaderItem.RealizeLayoutAndNavigation();

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
		HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', AppearanceList.itemContainer);
		HeaderItem.bAnimateOnInit = false;
		HeaderItem.InitHeader('bShowDeadSoldiers');
		HeaderItem.SetLabel(`CAPS(class'UIPersonnel_BarMemorial'.default.m_strTitle));
		HeaderItem.EnableCollapseToggle(bShowDeadSoldiers);
		HeaderItem.OnCollapseToggled = AppearanceListCategoryCollapseChanged;
		HeaderItem.RealizeLayoutAndNavigation();

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
	if (ListItem == none || ListItem.bDisabled)
		return;

	`AMLOG("Clicked on appearance list member:" @ ItemIndex @ ListItem.MCName);
	AppearanceOptionCheckboxChanged(ListItem.Checkbox);

	bCanExitWithoutPopup = ArmoryUnit.kAppearance == OriginalAppearance;
	UpdateApplyChangesButtonVisibility();
}

private function AppearanceOptionCheckboxChanged(UICheckbox CheckBox)
{
	local UIMechaListItem			ListItem;
	local UIMechaListItem_Soldier	SoldierListItem;
	local int						Index;
	local int						i;

	Index = AppearanceList.GetItemIndex(CheckBox.ParentPanel);
	if (Index == INDEX_NONE)
		return;

	// Uncheck other members of the appearance list
	// Except for the checkbox that was clicked on (The "i == Index" one)
	for (i = 0; i < AppearanceList.ItemCount; i++)
	{
		ListItem = UIMechaListItem(AppearanceList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;
		
		`AMLOG("Unchecking:" @ ListItem.MCName);
		ListItem.Checkbox.SetChecked(i == Index, false);
	}
	// And force check whiever checkbox was clicked on.
	//CheckBox.SetChecked(true, false);

	SoldierListItem = UIMechaListItem_Soldier(CheckBox.ParentPanel);
	
	// Store info about appearance that was clicked.
	SelectedAppearance = SoldierListItem.StoredAppearance.Appearance;
	SelectedAttitude = SoldierListItem.PersonalityTemplate;
	SelectedUnit = SoldierListItem.UnitState;
	bOriginalAppearanceSelected = SoldierListItem.bOriginalAppearance;

	UpdateOptionsList();
	ApplyCheckboxPresetPositions();
	UpdateUnitAppearance();	

	class'Help'.static.PlayStrategySoundEvent("SoundGlobalUI.Play_MenuSelect", self);
}

private function OnSearchButtonClicked(UIManageAppearance_ListHeaderItem HeaderItem)
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
		kData.fnCallbackAccepted = OnSearchInputBoxAccepted;

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
	kData.fnCallbackAccepted = OnSaveAsUniformInputBoxAccepted;

	Movie.Pres.UIInputDialog(kData);
}

private function OnSaveAsUniformInputBoxAccepted(string strLastName)
{
	local XComGameState_Unit NewUnit;

	if (strLastName != "")
	{
		//NewUnit = PoolMgr.CreateSoldierForceGender(ArmoryUnit.GetMyTemplateName(), EGender(ArmoryPawn.m_kAppearance.iGender));
		//if (NewUnit == none)
		//{
		//	ShowInfoPopup(strFailedToCreateUnitTitle, strFailedToCreateUnitText @ ArmoryUnit.GetMyTemplateName(), eDialog_Warning);
		//	return;
		//}

		NewUnit = PoolMgr.CreateSoldier(ArmoryUnit.GetMyTemplateName());
		NewUnit.SetTAppearance(ArmoryPawn.m_kAppearance);
		NewUnit.SetCharacterName(class'UISL_AppearanceManager'.default.strUniformSoldierFirstName, strLastName, "");
		NewUnit.SetCountry(ArmoryUnit.GetCountry());
		NewUnit.kAppearance.iAttitude = 0;
		NewUnit.UpdatePersonalityTemplate();
		NewUnit.bAllowedTypeSoldier = false;
		NewUnit.bAllowedTypeVIP = false;
		NewUnit.bAllowedTypeDarkVIP = false;
		NewUnit = PoolMgr.AddUnitToCharacterPool(NewUnit);
		
		PoolMgr.SetUniformStatus(NewUnit, EUS_Manual);
		NewUnit.StoreAppearance(ArmoryPawn.m_kAppearance.iGender, ArmorTemplateName);
		SaveCosmeticOptionsForUnit(NewUnit); // This calls SaveCharacterPool()
		
		PoolMgr.SortCharacterPoolBySoldierName();
		PoolMgr.SortCharacterPoolBySoldierClass();
		PoolMgr.SortCharacterPoolByUniformStatus();

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
		if (ListItem == none || ListItem.Checkbox == none || ListItem.bDisabled || !IsCosmeticOption(ListItem.MCName))
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
	local UIMechaListItem_Soldier	SpawnedItem;
	local EUniformStatus			UniformStatus;
	local XComGameState_Item		ItemState;

	if (!IsUnitSameType(UnitState))
		return;

	if (GetFilterListCheckboxStatus('FilterClass') && ArmoryUnit.GetSoldierClassTemplateName() != UnitState.GetSoldierClassTemplateName())
		return;

	`AMLOG("Running for:" @ UnitState.GetFullName());

	if (class'Help'.static.IsUnrestrictedCustomizationLoaded() && UnitState != ArmoryUnit)
	{	
		`AMLOG("Unrestricted Customization compatibility enabled.");

		Gender = EGender(UnitState.kAppearance.iGender);
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			return;

		if (bCharPool)
		{
			// Can't use Item State cuz Character Pool units would have none.
			LocalArmorTemplateName = PoolMgr.GetCharacterPoolEquippedArmor(UnitState);
			`AMLOG("Armpr saved in Character Pool Loadout:" @ LocalArmorTemplateName);
		}
		else
		{
			ItemState = UnitState.GetItemInSlot(eInvSlot_Armor);
			if (ItemState != none)
			{
				ArmorTemplate = ItemState.GetMyTemplate();
				if (ArmorTemplate != none)
				{
					LocalArmorTemplateName = ArmorTemplate.DataName;
					`AMLOG("Armpr equipped on the unit:" @ LocalArmorTemplateName);
				}
			}
		}
		
		`AMLOG(UnitState.GetFullName() @ "cosmetic torso:" @ UnitState.kAppearance.nmTorso @ "found armor template:" @ LocalArmorTemplateName);

		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != LocalArmorTemplateName)
		{
			`AMLOG("This armor template is different to equipped on the unit:" @ ArmorTemplateName @ ", so skipping unit's current appearance");
			return;
		}

		DisplayString = GetUnitDisplayStringForAppearanceList(UnitState, Gender);
		if (bCharPool && IsUnitPresentInCampaign(UnitState)) // If unit was already drawn from the CP, color their entry green.
			DisplayString = `GREEN(DisplayString);

		ArmorTemplate = ItemMgr.FindItemTemplate(LocalArmorTemplateName);
		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayString $= ArmorTemplate.FriendlyName $ " ";
		}
		else
		{
			DisplayString $= string(LocalArmorTemplateName) $ " ";
		}

		if (Gender == eGender_Male)
		{
			DisplayString $= "|" @ class'XComCharacterCustomization'.default.Gender_Male $ " ";
		}
		else if (Gender == eGender_Female)
		{
			DisplayString $= "|" @ class'XComCharacterCustomization'.default.Gender_Female $ " ";
		}
		
		if (SearchText != "" && InStr(DisplayString, SearchText,, true) == INDEX_NONE) // ignore case
			return;
		
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(DisplayString, "", false, AppearanceOptionCheckboxChanged, none);
		SpawnedItem.StoredAppearance.Appearance = UnitState.kAppearance;
		SpawnedItem.SetPersonalityTemplate();
		SpawnedItem.UnitState = UnitState;
		return;
	}

	// Cycle through Appearance Store, which may or may not include unit's current appearance.
	foreach UnitState.AppearanceStore(StoredAppearance)
	{	
		// Skip current appearance of current unit
		if (UnitState == ArmoryUnit && class'Help'.static.IsAppearanceCurrent(StoredAppearance.Appearance, OriginalAppearance))
			continue;

		Gender = EGender(int(Right(StoredAppearance.GenderArmorTemplate, 1)));
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			continue;

		LocalArmorTemplateName = name(Left(StoredAppearance.GenderArmorTemplate, Len(StoredAppearance.GenderArmorTemplate) - 1));
		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != LocalArmorTemplateName)
			continue;

		`AMLOG(`ShowVar(LocalArmorTemplateName) @ GetEnum(enum'EGender', Gender));

		DisplayString = GetUnitDisplayStringForAppearanceList(UnitState, Gender);

		ArmorTemplate = ItemMgr.FindItemTemplate(LocalArmorTemplateName);
		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayString $= ArmorTemplate.FriendlyName $ " ";
		}
		else
		{
			DisplayString $= string(LocalArmorTemplateName) $ " ";
		}

		if (Gender == eGender_Male)
		{
			DisplayString $= "|" @ class'XComCharacterCustomization'.default.Gender_Male $ " ";
		}
		else if (Gender == eGender_Female)
		{
			DisplayString $= "|" @ class'XComCharacterCustomization'.default.Gender_Female $ " ";
		}

		if (class'Help'.static.IsAppearanceCurrent(StoredAppearance.Appearance, UnitState.kAppearance))
		{
			bCurrentAppearanceFound = true;

			DisplayString $= class'Help'.default.strCurrentAppearance;
		}

		if (SearchText != "" && InStr(DisplayString, SearchText,, true) == INDEX_NONE) // ignore case
			continue;

		UniformStatus = PoolMgr.GetUniformStatus(UnitState);
		if (UniformStatus > EUS_NotUniform)
		{
			class'Help'.static.ApplySoldierNameColorBasedOnUniformStatus(DisplayString, UniformStatus);
		}
		else if (bCharPool && IsUnitPresentInCampaign(UnitState))
		{
			// If unit was already drawn from the CP, color their entry green.
			DisplayString = `GREEN(DisplayString);
		}

		`AMLOG(DisplayString);
		
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', AppearanceList.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.StoredAppearance = StoredAppearance;
		SpawnedItem.SetPersonalityTemplate();
		SpawnedItem.UnitState = UnitState;
		SpawnedItem.UpdateDataCheckbox(DisplayString, "", SelectedAppearance == SpawnedItem.StoredAppearance.Appearance && SpawnedItem.UnitState == SelectedUnit, AppearanceOptionCheckboxChanged, none);
		//SpawnedItem.SetDisabled(StoredAppearance.Appearance == OriginalAppearance && UnitState == ArmoryUnit); // Lock current appearance of current unit
	}

	`AMLOG("Done working with Appearance Store, looking at current appearance.");

	// If Appearance Store didn't contain unit's current appearance, add unit's current appearance to the list as well.
	// As long it's not the currently selected unit. There's no value in having that one in the list.
	if (!bCurrentAppearanceFound && UnitState != ArmoryUnit)
	{
		Gender = EGender(UnitState.kAppearance.iGender);
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			return;

		// Can't use Item State cuz Character Pool units would have none.
		`AMLOG("About to call GetItemTemplateFromCosmeticTorso()");

		ArmorTemplate = GetItemTemplateFromCosmeticTorso(UnitState.kAppearance.nmTorso);

		`AMLOG("Called GetItemTemplateFromCosmeticTorso()");

		if (ArmorTemplate != none)
		{
			LocalArmorTemplateName = ArmorTemplate.DataName;
		}
		else
		{
			LocalArmorTemplateName = '';
		}
		
		`AMLOG(UnitState.GetFullName() @ "cosmetic torso:" @ UnitState.kAppearance.nmTorso @ "found armor template:" @ LocalArmorTemplateName);

		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != LocalArmorTemplateName)
		{
			`AMLOG("This armor template is different to equipped on the unit:" @ ArmorTemplateName @ ", so skipping unit's current appearance");
			return;
		}
		DisplayString = GetUnitDisplayStringForAppearanceList(UnitState, Gender);
		if (bCharPool && IsUnitPresentInCampaign(UnitState)) // If unit was already drawn from the CP, color their entry green.
			DisplayString = `GREEN(DisplayString);

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayString $= ArmorTemplate.FriendlyName $ " ";
		}
		else
		{
			DisplayString $= string(LocalArmorTemplateName) $ " ";
		}

		if (Gender == eGender_Male)
		{
			DisplayString $= "|" @ class'XComCharacterCustomization'.default.Gender_Male $ " ";
		}
		else if (Gender == eGender_Female)
		{
			DisplayString $= "|" @ class'XComCharacterCustomization'.default.Gender_Female $ " ";
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
	}
}

private function X2ItemTemplate GetItemTemplateFromCosmeticTorso(const name nmTorso)
{
	local name						FunctionArmorTemplateName;
	local X2BodyPartTemplate		FunctionArmorPartTemplate;
	local X2ItemTemplate			FunctionItemTemplate;

	`AMLOG("Running for" @ `showvar(nmTorso));
	`AMLOG(GetScriptTrace());

	FunctionArmorPartTemplate = BodyPartMgr.FindUberTemplate("Torso", nmTorso);
	`AMLOG("Found ArmorPartTemplate:" @ FunctionArmorPartTemplate.DataName @ FunctionArmorPartTemplate.ArmorTemplate);
	if (FunctionArmorPartTemplate != none)
	{
		FunctionArmorTemplateName = FunctionArmorPartTemplate.ArmorTemplate;
		`AMLOG(`showvar(FunctionArmorTemplateName));
		if (FunctionArmorTemplateName != '')
		{
			FunctionItemTemplate = ItemMgr.FindItemTemplate(FunctionArmorTemplateName);
			`AMLOG("Found armor template:" @ FunctionItemTemplate.DataName);
			return FunctionItemTemplate;
		}
	}
	return none;
}

// Generate appearance name without redundant info.
// If the apperance is from a uniform unit, we don't need to display "UNIFORM" name, it's already in the uniform apperance list.
// Same for Last Name, which is equal to unit's gender by default.
private function string GetUnitDisplayStringForAppearanceList(const XComGameState_Unit UnitState, const EGender Gender)
{
	local X2SoldierClassTemplate	ClassTemplate;
	local string					strNickname;
	local string					strFirstName;
	local string					strLastName;
	local string					SoldierString;
	local bool						bAddDelim;
	local string					strClassName;

	ClassTemplate = UnitState.GetSoldierClassTemplate();
	if (ClassTemplate != none)
	{
		strClassName = ClassTemplate.DisplayName;
		SoldierString = strClassName $ ": ";
	}
	
	strFirstName = UnitState.GetFirstName();
	if (strClassName != "") strFirstName = Repl(strFirstName, strClassName, ""); // Remove soldier class name from unit's name, since it will be displayed separately anyway. The "!=" check is super important, doing Repl("string", "", "") causes a freeze.
	RemoveEdgeEmptySpaces(strFirstName);
	if (strFirstName != class'UISL_AppearanceManager'.default.strUniformSoldierFirstName)
	{
		SoldierString $= strFirstName $ " ";
		bAddDelim = true;
	}

	
	strNickname = UnitState.GetNickName();
	// If the soldier is uniform, removing their nickname if it's the same as their soldier class name
	if (strClassName != "" && PoolMgr.GetUniformStatus(UnitState) > EUS_NotUniform) strNickname = Repl(strNickname, strClassName, "");

	RemoveEdgeEmptySpaces(strNickname);
	if (strNickname != "" && strNickname != "''")
	{
		SoldierString $= strNickname $ " ";
		bAddDelim = true;
	}

	strLastName = UnitState.GetLastName();
	if (strClassName != "") strLastName = Repl(strLastName, strClassName, "");
	switch (Gender)
	{
		case eGender_Male:
			strLastName = Repl(strLastName, class'XComCharacterCustomization'.default.Gender_Male, "");
			break;
		case eGender_Female:
			strLastName = Repl(strLastName, class'XComCharacterCustomization'.default.Gender_Female, "");
			break;
		default:
			break;
	}	
	RemoveEdgeEmptySpaces(strLastName);
	if (strLastName != "")
	{
		SoldierString $= strLastName $ " ";
		bAddDelim = true;
	}

	if (bAddDelim)
	{
		SoldierString $= "| ";
	}
	return SoldierString;
}
// Remove empty spaces from the left and right ends of the string.
private function string RemoveEdgeEmptySpaces(out string strInput)
{
	while (Left(strInput, 1) == " ")
	{
		strInput = Right(strInput, Len(strInput) - 1);
	}
	while (Right(strInput, 1) == " ")
	{
		strInput = Left(strInput, Len(strInput) - 1);
	}
	return strInput;
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
	// Always filter out SPARKs and other non-soldier units.
	if (ArmoryUnit.UnitSize != UnitState.UnitSize || ArmoryUnit.UnitHeight != UnitState.UnitHeight)
			return false;

	// Compare character templates.
	if (UnitState.GetMyTemplateName() != ArmoryUnit.GetMyTemplateName())
	{
		// If they don't match, then allow cross-character customization only if UC is present.
		return class'Help'.static.IsUnrestrictedCustomizationLoaded();
	}

	// If they do match, then we have nothing to worry about.
	return true;
}

private static function bool AreUnitsSameType(const XComGameState_Unit FirstUnit, const XComGameState_Unit SecondUnit)
{	
	if (FirstUnit.UnitSize != SecondUnit.UnitSize || FirstUnit.UnitHeight != SecondUnit.UnitHeight)
			return false;

	if (FirstUnit.GetMyTemplateName() != SecondUnit.GetMyTemplateName())
	{
		return class'Help'.static.IsUnrestrictedCustomizationLoaded();
	}

	return true;
}

// ================================================================================================================================================
// FUNCTIONS FOR APPLYING APPEARANCE CHANGES

private function UpdateUnitAppearance()
{
	local TAppearance NewAppearance;

	PreviousAppearance = ArmoryUnit.kAppearance;
	NewAppearance = OriginalAppearance;
	CopyAppearance(NewAppearance, SelectedAppearance, ArmoryUnit, SelectedUnit);

	bCanExitWithoutPopup = NewAppearance == OriginalAppearance;
	UpdateApplyChangesButtonVisibility();
		
	ArmoryUnit.SetTAppearance(NewAppearance);
	ArmoryPawn.SetAppearance(NewAppearance, false);
	class'Help'.static.RequestFullPawnContentForClerk(ArmoryUnit, ArmoryPawn, NewAppearance);

	ApplyChangesToUnitWeapons(ArmoryUnit, NewAppearance, none);
	UpdateHeader();

	if (ShouldRefreshPawn(NewAppearance))
	{
		if (bInArmory)
		{
			CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
		}
		else
		{
			PawnRefreshHelper.RefreshPawn_UseAppearance(NewAppearance, true);
		}

		// After ReCreatePawnVisuals, the CustomizeManager.ActorPawn, ArmoryPawn and become 'none'
		// Apparently there's some sort of threading issue at play, so we use a timer to get a reference to the new pawn with a slight delay.
		//OnRefreshPawn();
		SetTimer(0.01f, false, nameof(OnRefreshPawn), self);
	}	
	else
	{
		CustomizeManager.UpdateCamera(eUICustomizeCat_Face);
		UpdatePawnAttitudeAnimation(); // OnRefreshPawn() will call this automatically
	}
}

private function bool ShouldRefreshPawn(const TAppearance NewAppearance)
{
	`AMLOG("Previous gender:" @ GetEnum(enum'EGender', PreviousAppearance.iGender) @ "New gender:" @ GetEnum(enum'EGender', NewAppearance.iGender));
	if (PreviousAppearance.iGender != NewAppearance.iGender)
	{
		return true;
	}
	if (PreviousAppearance.nmTorso != NewAppearance.nmTorso) // Unfortuantely needed to clear EXO Suit exo arms
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
		UpdatePawnAttitudeAnimation();
		//ApplyChangesToUnitWeapons(ArmoryUnit, ArmoryPawn.m_kAppearance, none);

		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(MouseGuardInst).SetActorPawn(CustomizeManager.ActorPawn);
	}
	else
	{
		SetTimer(0.01f, false, nameof(OnRefreshPawn), self);
	}
}

final function UpdatePawnAttitudeAnimation()
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
		!GetApplyToListCheckboxStatus('ApplyToThisUnit') &&
		!GetApplyToListCheckboxStatus('ApplyToCharPool') &&
		!GetApplyToListCheckboxStatus('ApplyToSquad') &&
		!GetApplyToListCheckboxStatus('ApplyToBarracks'))
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

simulated function OnRemoved()
{
	if (ApplyChangesButton != none) ApplyChangesButton.Remove();
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
	if (GetApplyToListCheckboxStatus('ApplyToThisUnit') && !bOriginalAppearanceSelected)
	{
		ApplyChangesToArmoryUnit();
	}
	else
	{
		CancelChanges();
	}

	// Character Pool
	if (GetApplyToListCheckboxStatus('ApplyToCharPool'))
	{
		foreach PoolMgr.CharacterPool(UnitState)
		{
			if (UnitState.ObjectID == ArmoryUnit.ObjectID)
				continue;

			ApplyChangesToUnit(UnitState);
		}
		PoolMgr.SaveCharacterPool();
	}

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	if (XComHQ == none)
		return;

	// Squad
	if (GetApplyToListCheckboxStatus('ApplyToSquad'))
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes to squad");
		foreach XComHQ.Squad(SquadUnitRef)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SquadUnitRef.ObjectID));
			if (UnitState == none || UnitState.IsDead() || UnitState.ObjectID == ArmoryUnit.ObjectID)
				continue;

			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
			ApplyChangesToUnit(UnitState, NewGameState);
		}
		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Barracks except for squad and soldiers away on Covert Action
	if (GetApplyToListCheckboxStatus('ApplyToBarracks'))
	{
		UnitStates = XComHQ.GetSoldiers(true, true);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes to barracks");
		foreach UnitStates(UnitState)
		{
			if (UnitState.ObjectID == ArmoryUnit.ObjectID)
				continue;

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
	ApplyChangesButton.SetDisabled(true, strApplyChangesButtonDisabled);
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
	CopyAppearance(NewAppearance, SelectedAppearance, UnitState, ArmoryUnit);

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
	if (!bInArmory)
		return;

	// While in Armory, we have to actually update the weapon appearance on Item States, which always requires submitting a Game State.
	// So if a NewGameState wasn't provided, we create our own, ~~with blackjack and hookers~~
	// (This function gets a GameState when applying changes to armory unit's weapon in armory)
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

	if (bInArmory)
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
	ArmoryPawn.SetAppearance(OriginalAppearance, false);
	class'Help'.static.RequestFullPawnContentForClerk(ArmoryUnit, ArmoryPawn, OriginalAppearance);

	if (ShouldRefreshPawn(OriginalAppearance))
	{
		if (bInArmory)
		{
			CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
		}
		else
		{
			PawnRefreshHelper.RefreshPawn_UseAppearance(OriginalAppearance, true);
		}
	}	
	else
	{
		UpdatePawnAttitudeAnimation();
	}
}

// ================================================================================================================================================
// OPTIONS LIST - List of checkboxes on the left that determines which parts of the appearance should be copied from CP unit to Armory unit.

private function CopyAppearance(out TAppearance NewAppearance, const out TAppearance UniformAppearance, const XComGameState_Unit TargetUnit, const XComGameState_Unit SourceUnit)
{
	local bool bGenderChange;
	local TAppearance UnchangedAppearance;

	UnchangedAppearance = NewAppearance;
	`AMLOG("To:" @ TargetUnit.GetFullName() @ "from" @ SourceUnit.GetFullName());

	if (ShouldCopyOption('iGender', TargetUnit, SourceUnit))
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
		if (ShouldCopyOption('nmHead', TargetUnit, SourceUnit))				{	NewAppearance.nmHead = UniformAppearance.nmHead; 
																				NewAppearance.nmEye = UniformAppearance.nmEye; 
																				NewAppearance.nmTeeth = UniformAppearance.nmTeeth; 
																				NewAppearance.iRace = UniformAppearance.iRace;}
		if (ShouldCopyOption('nmHaircut', TargetUnit, SourceUnit))				NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
		if (ShouldCopyOption('nmBeard', TargetUnit, SourceUnit))				NewAppearance.nmBeard = UniformAppearance.nmBeard;
		if (ShouldCopyOption('nmTorso', TargetUnit, SourceUnit))				NewAppearance.nmTorso = UniformAppearance.nmTorso;
		if (ShouldCopyOption('nmArms', TargetUnit, SourceUnit))					NewAppearance.nmArms = UniformAppearance.nmArms;
		if (ShouldCopyOption('nmLegs', TargetUnit, SourceUnit))					NewAppearance.nmLegs = UniformAppearance.nmLegs;
		if (ShouldCopyOption('nmHelmet', TargetUnit, SourceUnit))				NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
		if (ShouldCopyOption('nmFacePropLower', TargetUnit, SourceUnit))		NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
		if (ShouldCopyOption('nmFacePropUpper', TargetUnit, SourceUnit))		NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
		if (ShouldCopyOption('nmVoice', TargetUnit, SourceUnit))				NewAppearance.nmVoice = UniformAppearance.nmVoice;
		if (ShouldCopyOption('nmScars', TargetUnit, SourceUnit))				NewAppearance.nmScars = UniformAppearance.nmScars;
		if (ShouldCopyOption('nmFacePaint', TargetUnit, SourceUnit))			NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
		if (ShouldCopyOption('nmLeftArm', TargetUnit, SourceUnit))				NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
		if (ShouldCopyOption('nmRightArm', TargetUnit, SourceUnit))				NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
		if (ShouldCopyOption('nmLeftArmDeco', TargetUnit, SourceUnit))			NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
		if (ShouldCopyOption('nmRightArmDeco', TargetUnit, SourceUnit))			NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
		if (ShouldCopyOption('nmLeftForearm', TargetUnit, SourceUnit))			NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
		if (ShouldCopyOption('nmRightForearm', TargetUnit, SourceUnit))			NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
		if (ShouldCopyOption('nmThighs', TargetUnit, SourceUnit))				NewAppearance.nmThighs = UniformAppearance.nmThighs;
		if (ShouldCopyOption('nmShins', TargetUnit, SourceUnit))				NewAppearance.nmShins = UniformAppearance.nmShins;
		if (ShouldCopyOption('nmTorsoDeco', TargetUnit, SourceUnit))			NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
		//if (ShouldCopyOption('iRace'))				NewAppearance.iRace = UniformAppearance.iRace;
		//if (ShouldCopyOption('iFacialHair'))			NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
		//if (ShouldCopyOption('iVoice'))				NewAppearance.iVoice = UniformAppearance.iVoice;
		//if (ShouldCopyOption('nmTorso_Underlay'))		NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
		//if (ShouldCopyOption('nmArms_Underlay'))		NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
		//if (ShouldCopyOption('nmLegs_Underlay'))		NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	}

	if (ShouldCopyOption('iHairColor', TargetUnit, SourceUnit))				NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (ShouldCopyOption('iSkinColor', TargetUnit, SourceUnit))				NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (ShouldCopyOption('iEyeColor', TargetUnit, SourceUnit))				NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (ShouldCopyOption('nmFlag', TargetUnit, SourceUnit))					NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (ShouldCopyOption('iAttitude', TargetUnit, SourceUnit))				NewAppearance.iAttitude = UniformAppearance.iAttitude;
	if (ShouldCopyOption('iArmorTint', TargetUnit, SourceUnit))				NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (ShouldCopyOption('iArmorTintSecondary', TargetUnit, SourceUnit))	NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (ShouldCopyOption('iWeaponTint', TargetUnit, SourceUnit))			NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (ShouldCopyOption('iTattooTint', TargetUnit, SourceUnit))			NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (ShouldCopyOption('nmWeaponPattern', TargetUnit, SourceUnit))		NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (ShouldCopyOption('nmPatterns', TargetUnit, SourceUnit))				NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	if (ShouldCopyOption('nmTattoo_LeftArm', TargetUnit, SourceUnit))		NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (ShouldCopyOption('nmTattoo_RightArm', TargetUnit, SourceUnit))		NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	//if (ShouldCopyOption('iArmorDeco'))			NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	//if (IsCheckboxChecked('nmLanguage'))			NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	//if (IsCheckboxChecked('bGhostPawn'))			NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;

	`AMLOG("Appearance changed:" @ NewAppearance != UnchangedAppearance);
}

private function bool ShouldCopyOption(const name OptionName, const XComGameState_Unit TargetUnit, const XComGameState_Unit SourceUnit)
{
	if (IsCheckboxChecked(OptionName))
	{
		if (IsOptionCharacterSpecific(OptionName))
		{
			return AreUnitsSameType(TargetUnit, SourceUnit);
		}
		return true;
	}
	return false;
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

	if (ListItem != none && !ListItem.bDisabled)
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

	UpdateApplyChangesButtonVisibility();
}

private function MaybeCreateAppearanceOption(name OptionName, coerce string CurrentCosmetic, coerce string NewCosmetic, ECosmeticType CosmeticType)
{	
	local UIMechaListItem_Button	SpawnedItem;
	local string					strDesc;
	local bool						bChecked;
	local bool						bDisabled;
	local bool						bNewIsSameAsCurrent;

	`AMLOG(`showvar(OptionName) @ `showvar(CurrentCosmetic) @ `showvar(NewCosmetic) @ "Gender-agnostic:" @ IsOptionGenderAgnostic(OptionName));

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

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	// If appearances are of different gender and this option does cares about gender
	if (OriginalAppearance.iGender != SelectedAppearance.iGender && !IsOptionGenderAgnostic(OptionName)) 
	{	
		`AMLOG("Appearance are of different genders and this option is not gender agnostic");
		// Treat this option like any other only if we're changing from empty cosmetic to non empty, and we do change the gender at the same time.
		// Then the player can choose whether they want to keep their previous empty cosmetic, or replace it with a new-non empty one.
		// Have to hope really hard that empty cosmetics are same between males and females, because they can be differnt, and technically are in some cases (like bald hair).
		// If this proves to be not the case, only the else() part of this condition should remain.
		if (class'Help'.static.IsCosmeticEmpty(CurrentCosmetic) && !class'Help'.static.IsCosmeticEmpty(NewCosmetic) && IsCheckboxChecked('iGender'))
		{
			`AMLOG("Original cosmetic is empty and new cosmetic is not empty, and gender option is checked. Treating this option like any other.");
			bChecked = GetOptionCheckboxPosition(OptionName);
		}
		else
		{
			`AMLOG("All other cases. Disable option and sync it to gender.");
			// In all other cases, we disallow the player to do anything to this cosmetic option, and force copy it along with the gender. Or force not-copy it, if gender remains unchanged.
			bDisabled = true;
			bChecked = IsCheckboxChecked('iGender');
		}
	}
	else
	{
		`AMLOG("Appearance are of same gender or this option doesn't care about gender.");
		// If this option doesn't care about gender, or gender change is not needed for this appearance import, then we load the saved preset for it.
		bChecked = GetOptionCheckboxPosition(OptionName);
	}

	if (OptionName == 'nmBeard' && OriginalAppearance.iGender == eGender_Female && !IsCheckboxChecked('iGender'))
	{
		bDisabled = true; // Beards should be disabled when copying appearance to females.
		bChecked = false;
	}

	`AMLOG("Created option. Is disabled:" @ bDisabled @ "Is checked:" @ bChecked @ "Is gender-agnostic:" @ IsOptionGenderAgnostic(OptionName));

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
			if (OptionName == 'nmHead') // We always change face and race together, so display them together as well.
			{
				if (bNewIsSameAsCurrent)
					strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetRaceFriendlyName(ArmoryUnit.kAppearance.iRace) @ GetBodyPartFriendlyName(OptionName, CurrentCosmetic);
				else
					strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetRaceFriendlyName(ArmoryUnit.kAppearance.iRace) @ GetBodyPartFriendlyName(OptionName, CurrentCosmetic) @ "->" @ GetRaceFriendlyName(SelectedAppearance.iRace) @ GetBodyPartFriendlyName(OptionName, NewCosmetic);
			}
			else
			{
				if (bNewIsSameAsCurrent)
					strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetBodyPartFriendlyName(OptionName, CurrentCosmetic);
				else
					strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetBodyPartFriendlyName(OptionName, CurrentCosmetic) @ "->" @ GetBodyPartFriendlyName(OptionName, NewCosmetic);
			}
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

	`AMLOG("Enter");

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

	`AMLOG("Middle");

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

	`AMLOG("Leave");
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
		if (ListItem == none || ListItem.Checkbox == none || ListItem.bDisabled) // Don't save positions for disabled items. They have their checkbox locked to gender, and we don't want to ruin the preset.
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
	
	SavePresetConfig();
}

function SavePresetConfig()
{	
	default.CheckboxPresets = CheckboxPresets; // This is actually necessary
	default.Presets = Presets;
	SaveConfig();
}

private function ApplyCheckboxPresetPositions()
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
	local UIManageAppearance_ListHeaderItem HeaderItem;
	local name PresetName;

	if (Presets.Length == 0)
		return;

	HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', OptionsList.itemContainer);
	HeaderItem.bAnimateOnInit = false;
	HeaderItem.InitHeader();
	HeaderItem.SetLabel(`CAPS(class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset));
		
	HeaderItem.EnableCollapseToggle(bShowPresets);
	HeaderItem.OnCollapseToggled = OnPresetsCollapseToggled;

	HeaderItem.bActionButtonEnabled = true;
	HeaderItem.ActionButton.SetText(strCreatePreset);
	HeaderItem.OnActionInteracted = OnCreatePresetClicked;

	HeaderItem.RealizeLayoutAndNavigation();

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

	SavePresetConfig();
	UpdateOptionsList();
	ApplyCheckboxPresetPositions();
	UpdateUnitAppearance();
}

private function OnCreatePresetClicked (UIManageAppearance_ListHeaderItem HeaderItem)
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

	if (text == "")
	{
		// No empty preset names
		ShowInfoPopup(strDuplicatePresetDisallowedTitle, strInvalidPresetNameText, eDialog_Warning);
		return;
	}

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

			`AMLOG("Copied:" @ i @ CurrentPreset @ NewPresetStruct.Preset @ NewPresetStruct.OptionName @ NewPresetStruct.bChecked);
		}
	}

	SavePresetConfig();

	CurrentPreset = NewPresetName;
	//ApplyCheckboxPresetPositions(); // No need, settings would be identical.
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

function OnPresetsCollapseToggled (UIManageAppearance_ListHeaderItem HeaderItem)
{
	bShowPresets = HeaderItem.bSectionVisible;
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
		ApplyCheckboxPresetPositions();
		UpdateUnitAppearance();
		UpdatePresetListItemsButtons();

		class'Help'.static.PlayStrategySoundEvent("SoundGlobalUI.Play_MenuSelect", self);
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

	SavePresetConfig();
	CurrentPreset = 'PresetDefault';
	UpdateOptionsList();
	ApplyCheckboxPresetPositions();
	UpdateUnitAppearance();
}

// ================================================================================================================================================
// OPTION LIST CATEGORIES

private function bool MaybeCreateOptionCategory(name CategoryName, string strText)
{
	local UIManageAppearance_ListHeaderItem HeaderItem;
	local bool bChecked;

	if (bShowAllCosmeticOptions || ShouldShowCategoryOption(CategoryName))
	{
		bChecked = GetOptionCategoryCheckboxStatus(CategoryName);
		
		HeaderItem = Spawn(class'UIManageAppearance_ListHeaderItem', OptionsList.itemContainer);
		HeaderItem.bAnimateOnInit = false;
		HeaderItem.InitHeader(CategoryName);
		HeaderItem.SetLabel(`CAPS(strText));
		
		if (!bShowAllCosmeticOptions)
		{
			HeaderItem.EnableCollapseToggle(bChecked);
			HeaderItem.OnCollapseToggled = OptionCategoryCollapseChanged;
			HeaderItem.RealizeLayoutAndNavigation();
		}

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
	return /* OriginalAppearance.iRace != SelectedAppearance.iRace ||*/ // Race toggled together with face
			OriginalAppearance.iSkinColor != SelectedAppearance.iSkinColor ||
			OriginalAppearance.nmHead != SelectedAppearance.nmHead ||
			OriginalAppearance.nmHelmet != SelectedAppearance.nmHelmet && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) ||
			OriginalAppearance.nmFacePropLower != SelectedAppearance.nmFacePropLower && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) ||
			OriginalAppearance.nmFacePropUpper != SelectedAppearance.nmFacePropUpper && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) ||
			OriginalAppearance.nmHaircut != SelectedAppearance.nmHaircut && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) ||
			OriginalAppearance.nmBeard != SelectedAppearance.nmBeard && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) ||
			OriginalAppearance.iHairColor != SelectedAppearance.iHairColor ||
			OriginalAppearance.iEyeColor != SelectedAppearance.iEyeColor ||
			OriginalAppearance.nmScars != SelectedAppearance.nmScars && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) || 
			OriginalAppearance.nmFacePaint != SelectedAppearance.nmFacePaint && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet) && !class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmHelmet);
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

		case 'bShowCharPoolSoldiers': bShowCharPoolSoldiers = bNewValue; default.bShowCharPoolSoldiers = bShowCharPoolSoldiers; break;
		case 'bShowUniformSoldiers': bShowUniformSoldiers = bNewValue; default.bShowUniformSoldiers = bShowUniformSoldiers; break;
		case 'bShowBarracksSoldiers': bShowBarracksSoldiers = bNewValue; default.bShowBarracksSoldiers = bShowBarracksSoldiers; break;
		case 'bShowDeadSoldiers': bShowDeadSoldiers = bNewValue; default.bShowDeadSoldiers = bShowDeadSoldiers; break;
		default:
			return;
	}
}

private function OptionCategoryCollapseChanged (UIManageAppearance_ListHeaderItem HeaderItem)
{
	SetOptionCategoryCheckboxStatus(HeaderItem.MCName, HeaderItem.bSectionVisible);
	UpdateOptionsList();
}

private function AppearanceListCategoryCollapseChanged (UIManageAppearance_ListHeaderItem HeaderItem)
{
	SetOptionCategoryCheckboxStatus(HeaderItem.MCName, HeaderItem.bSectionVisible);
	SaveConfig();
	UpdateAppearanceList();
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
		if (BodyPartTemplate != none)
		{
			if (BodyPartTemplate.DisplayName != "")
			{
				return BodyPartTemplate.DisplayName;
			}
			else
			{	
				`AMLOG("No localized name for body part template:" @ BodyPartTemplate.DataName @ `showvar(PartType) @ `showvar(OptionName));
			}
		}
	}	
	return string(CosmeticTemplateName);
}

private function string GetRaceFriendlyName(const int iRace)
{
	return strRacePrefix $ string(iRace);
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
	case'Biography': return class'UICustomize_Info'.default.m_strEditBiography;

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

// Think like "Is it okay to copy this option from Soldier to Skirmisher? Or from Reaper to Templar?"
private function bool IsOptionCharacterSpecific(const name OptionName)
{
	switch (OptionName)
	{
	// Head
	case 'iGender': return true; // Technically gender isn't, but it's blocked by all other options that are.
	case 'iHairColor': return true;
	case 'iSkinColor': return true;
	case 'nmScars': return true;
	case 'iRace': return true;
	case 'nmHead': return true;
	case 'nmHaircut': return true;
	case 'nmBeard': return true;
	case 'nmPawn': return true;
	case 'nmEye': return true;
	case 'nmTeeth': return true;
	case 'nmFacePropLower': return true;
	case 'nmFacePropUpper': return true;

	case 'nmHelmet': return false;
	case 'iEyeColor': return false;

	// Patterns
	case 'iArmorTint': return false;
	case 'iArmorTintSecondary': return false;
	case 'iWeaponTint': return false;
	case 'nmWeaponPattern': return false;
	case 'nmPatterns': return false;

	// Tattoos
	case 'iTattooTint': return false;
	case 'nmTattoo_LeftArm': return false;
	case 'nmTattoo_RightArm': return false;
	
	// Body
	case 'nmTorso': return true;
	case 'nmArms': return true;
	case 'nmLegs': return true;
	case 'nmTorso_Underlay': return true;
	case 'nmArms_Underlay': return true;
	case 'nmLegs_Underlay': return true;
	case 'nmFacePaint': return true;
	case 'nmLeftArm': return true;
	case 'nmRightArm': return true;
	case 'nmLeftArmDeco': return true;
	case 'nmRightArmDeco': return true;
	case 'nmLeftForearm': return true;
	case 'nmRightForearm': return true;
	case 'nmThighs': return true;
	case 'nmShins': return true;
	case 'nmTorsoDeco': return true;

	// Personality
	case 'iAttitude': return true; // Templars got only one attitude.
	case 'nmVoice': return true;
	case 'nmFlag': return true; // Skirmishers have their own flag

	case 'FirstName': return false;
	case 'LastName': return false;
	case 'Nickname': return false;
	case 'Biography': return false;

	//case 'iFacialHair': return false;
	//case 'iArmorDeco': return false;
	//case 'bGhostPawn': return false;
	//case 'iVoice': return true;
	//case 'nmLanguage': return true;
	default:
		return true;
	}
}

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
	case 'Biography': return true;
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
		case'nmHaircut': return true;
		case'iHairColor': return true;
		case'nmBeard': return true;
		case'iSkinColor': return true;
		case'iEyeColor': return true;
		case'nmFlag': return true;
		case'iAttitude': return true;
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
		case'nmFacePropLower': return true;
		case'nmFacePropUpper': return true;
		case'nmPatterns': return true;
		case'nmVoice': return true;
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
		case'FirstName': return true;
		case'LastName': return true;
		case'Nickname': return true;
		case'Biography': return true;

		// These never exist as selectable cosmetic options.
		//case'nmEye': return true;
		//case'nmTeeth': return true;
		//case'iVoice': return true;
		//case'iFacialHair': return true;
		//case'iArmorDeco': return true;
		//case'nmLanguage': return true;
		//case'bGhostPawn': return true;
		//case'iRace': return true;
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
	DisplayTag = "UIBlueprint_Promotion"
	CameraTag = "UIBlueprint_Promotion"

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