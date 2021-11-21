class UIAppearanceStore extends UICustomize;

// This screen lists unit's AppearanceStore elements, allows to preview and delete them.

var XComHumanPawn					ArmoryPawn;

var private X2ItemTemplateManager	ItemMgr;
var private XComGameState_Unit		UnitState;
var private TAppearance				OriginalAppearance;
var private TAppearance				SelectedAppearance;
var private bool					bPawnRefreshIsCooldown;
var private CharacterPoolManager_AM PoolMgr;
var private bool					bPawnIsRefreshing;
var private X2PawnRefreshHelper		PawnRefreshHelper;

const PAWN_REFRESH_COOLDOWN = 0.15f;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	PoolMgr = `CHARACTERPOOLMGRAM;

	CacheArmoryUnitData();
	List.OnSelectionChanged = OnListItemSelected;
	List.OnItemClicked = AppearanceListItemClicked;

	if (!bInArmory)
	{
		PawnRefreshHelper = new class'X2PawnRefreshHelper';
		PawnRefreshHelper.AppearanceStoreScreen = self;
		PawnRefreshHelper.InitHelper(CustomizeManager, PoolMgr);
	}
	if (class'Help'.static.IsUnrestrictedCustomizationLoaded())
	{
		SetTimer(0.1f, false, nameof(FixScreenPosition), self);
	}
}

private function CacheArmoryUnitData()
{
	UnitState = CustomizeManager.UpdatedUnitState;
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	OriginalAppearance = ArmoryPawn.m_kAppearance;
}

// Attempt to equip the armor item associated with the stored appearance.
private function AppearanceListItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIMechaListItem_AppearanceStore	ListItem;
	local bool								bSuccess;

	if (ItemIndex == INDEX_NONE)
		return;

	// Quit with an error sound if the unit's appearance hasn't been updated yet.
	// A bit clunky, but I've exhausted all other options in making the unit appearance update properly if the list item element is clicked on too quickly.
	ListItem = UIMechaListItem_AppearanceStore(List.GetItem(ItemIndex));
	if (ListItem == none || ListItem.ArmorTemplateName == '' || ListItem.bIsCurrentAppearance || IsTimerActive(nameof(DelayedSetPawnAppearance), self))
	{
		class'Help'.static.PlayStrategySoundEvent("Play_MenuClickNegative", self);
		return;
	}

	if (bInArmory)
	{
		bSuccess = EquipArmorStrategy(ListItem.ArmorTemplateName);
	}
	else
	{
		bSuccess = EquipArmorCharacterPool(ListItem.ArmorTemplateName);
	}
	if (bSuccess)
	{	
		PlayArmorEquipSound(ListItem.ArmorTemplateName);
		if (bPawnIsRefreshing) 
		{
			SetTimer(0.1f, false, nameof(OnRefreshPawn_CloseScreen), self);
		}
		else
		{
			super.CloseScreen();
		}
	}
	else
	{
		class'Help'.static.PlayStrategySoundEvent("Play_MenuClickNegative", self);
	}
}

private function bool EquipArmorCharacterPool(const name ArmorTemplateName)
{
	local array<CharacterPoolLoadoutStruct> SavedCharacterPoolLoadout;
	local array<CharacterPoolLoadoutStruct> NewCharacterPoolLoadout;

	SavedCharacterPoolLoadout = PoolMgr.GetCharacterPoolLoadout(UnitState); // Save previous loadout

	PoolMgr.AddItemToCharacterPoolLoadout(UnitState, eInvSlot_Armor, ArmorTemplateName);

	NewCharacterPoolLoadout = PawnRefreshHelper.RefreshPawn(true);

	// If the new loadout contains the armor we wanted to equip, then it means it was in fact equipped successfully.
	if (class'Help'.static.GetArmorTemplateNameFromCharacterPoolLoadout(NewCharacterPoolLoadout) == ArmorTemplateName)
	{
		return true;
	}
	else
	{
		`AMLOG("Failed to equip:" @ ArmorTemplateName @ ", restoring saved loadout and exiting.");
		PoolMgr.SetCharacterPoolLoadout(UnitState, SavedCharacterPoolLoadout); // If we failed to equip all of the items, restore saved loadout.
		PawnRefreshHelper.RefreshPawn(true);
		return false;
	}
}

private function bool EquipArmorStrategy(const name ArmorTemplateName)
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Item				ItemState;
	local XComGameState_Item				NewItemState;
	local XComGameState_Item				PreviousItemState;
	local XComGameState						NewGameState;
	local XComGameState_Unit				NewUnitState;
	//local TAppearance						OldAppearance;

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	if (XComHQ == none)
		return false;

	ItemState = XComHQ.GetItemByName(ArmorTemplateName);
	if (ItemState == none)
	{
		`AMLOG(ArmorTemplateName @ "not found in HQ inventory");
		return false;
	}

	//OldAppearance = UnitState.kAppearance;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Equip armor for stored appearance on:" @ UnitState.GetFullName() @ ArmorTemplateName);
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));
	NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));

	XComHQ.GetItemFromInventory(NewGameState, ItemState.GetReference(), NewItemState);
	if (NewItemState == none)
	{
		`AMLOG("Failed to get" @ ArmorTemplateName @ "from HQ inventory.");
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		return false;
	}

	PreviousItemState = NewUnitState.GetItemInSlot(eInvSlot_Armor);
	if (PreviousItemState != none)
	{
		`AMLOG("Slot is currently occupied by:" @ PreviousItemState.GetMyTemplateName() @ ", attempting to unequip.");
		if (NewUnitState.RemoveItemFromInventory(PreviousItemState, NewGameState))
		{
			`AMLOG("Unequipped successfully");
			XComHQ.PutItemInInventory(NewGameState, PreviousItemState);
		}
		else
		{
			`AMLOG("Failed to unequip");
			`XCOMHISTORY.CleanupPendingGameState(NewGameState);
			return false;
		}
	}

	`AMLOG("Attempting to equip:" @ NewItemState.GetMyTemplateName() @ "current torso:" @ NewUnitState.kAppearance.nmTorso);

	if (NewUnitState.AddItemToInventory(NewItemState, eInvSlot_Armor, NewGameState))
	{
		NewUnitState.ValidateLoadout(NewGameState); // Need to do this to prevent things like soldier having a heavy weapon when switching from EXO suit to kevlar.

		//NewUnitState.SetTAppearance(SelectedAppearance); // Should happen automatically when the armor is equippped
		`GAMERULES.SubmitGameState(NewGameState);
		//CustomizeManager.SubmitUnitCustomizationChanges();


		`AMLOG("Equipped successfully, new torso:" @ NewUnitState.kAppearance.nmTorso);
		/if (OldAppearance != NewUnitState.kAppearance) // Refresh pawn only when necessary to reduce pawn flicker // EDIT: have to refresh every time to get rid of the heavy weapon model. Or draw one.
		//{
			CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
			bPawnIsRefreshing = true;
		//}
		return true;
	}
	else
	{
		`AMLOG("Failed to equip item:" @ NewItemState.GetMyTemplateName());
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		return false;
	}	
}

simulated function UpdateAppearanceList()
{
	local UIMechaListItem_AppearanceStore ListItem;
	local AppearanceInfo	StoredAppearance;
	local X2ItemTemplate	ArmorTemplate;
	local EGender			Gender;
	local name				ArmorTemplateName;
	local string			DisplayName;
	local int i;

	HideListItems();

	foreach UnitState.AppearanceStore(StoredAppearance)
	{
		Gender = EGender(int(Right(StoredAppearance.GenderArmorTemplate, 1)));
		ArmorTemplateName = name(Left(StoredAppearance.GenderArmorTemplate, Len(StoredAppearance.GenderArmorTemplate) - 1));
		ArmorTemplate = ItemMgr.FindItemTemplate(ArmorTemplateName);

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayName = ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayName = string(ArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}

		if (class'Help'.static.IsAppearanceCurrent(StoredAppearance.Appearance, OriginalAppearance))
		{
			DisplayName @= class'Help'.default.strCurrentAppearance;
			ListItem = UIMechaListItem_AppearanceStore(GetListItem(i++));
			ListItem.UpdateDataDescription(DisplayName); // Deleting current appearance may not work as people expect it to.
			ListItem.ArmorTemplateName = ArmorTemplateName;
			ListItem.bIsCurrentAppearance = true;
		}
		else
		{
			ListItem = UIMechaListItem_AppearanceStore(GetListItem(i++));
			ListItem.UpdateDataButton(DisplayName, class'UISaveLoadGameListItem'.default.m_sDeleteLabel, OnDeleteButtonClicked);
			ListItem.ArmorTemplateName = ArmorTemplateName;
		}
	}
}

private function OnListItemSelected(UIList ContainerList, int ItemIndex)
{
	if (UnitState == none || ItemIndex == INDEX_NONE)
		return;

	// 1. When player mouseovers a list entry, remember the appearance of that entry
	SelectedAppearance = UnitState.AppearanceStore[ItemIndex].Appearance;
	if (ArmoryPawn != none && ArmoryPawn.m_kAppearance == SelectedAppearance)
		return;

	// 3. If the timer is already running while the player mouseovers another entry, restart the timer.
	// That way pawn refresh will be delayed until the player stops running the mouse through the list.
	// So no pointless pawn flickering.
	// Some kind of delay needs to exist anyway, because otherwise rapidly refreshing the pawn of some soldiers (Reapers, at least) can cause the game to crash.
	if (IsTimerActive(nameof(DelayedSetPawnAppearance), self))
	{	
		ClearTimer(nameof(DelayedSetPawnAppearance), self);
	}

	// 2. And start a timer to update the pawn to that appearance with a delay.
	// You can thank Xym for this implementation. My own was more responsive, but also more complicated.
	SetTimer(PAWN_REFRESH_COOLDOWN, false, nameof(DelayedSetPawnAppearance), self); 
}

private function ResetPawnRefreshCooldown()
{
	bPawnRefreshIsCooldown = false;
}

private function DelayedSetPawnAppearance()
{
	`AMLOG(SelectedAppearance.nmTorso);
	SetPawnAppearance(SelectedAppearance);
}

private function SetPawnAppearance(TAppearance NewAppearance)
{
	if (bInArmory)
	{
		UnitState.SetTAppearance(NewAppearance);
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
		bPawnIsRefreshing = true;
		SetTimer(0.1f, false, nameof(OnRefreshPawn), self);
	}
	else
	{
		PawnRefreshHelper.RefreshPawn_UseAppearance(NewAppearance, true);
	}
}

final function OnRefreshPawn()
{
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn != none)
	{
		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(MouseGuardInst).SetActorPawn(CustomizeManager.ActorPawn);
		bPawnIsRefreshing = false;
	}
	else
	{
		SetTimer(0.1f, false, nameof(OnRefreshPawn), self);
	}
}

final function OnRefreshPawn_CloseScreen()
{
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn != none)
	{
		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(MouseGuardInst).SetActorPawn(CustomizeManager.ActorPawn);
		super.CloseScreen();
	}
	else
	{
		SetTimer(0.1f, false, nameof(OnRefreshPawn_CloseScreen), self);
	}
}

private function OnDeleteButtonClicked(UIButton ButtonSource)
{
	local int Index;

	SetPawnAppearance(OriginalAppearance);
	Index = List.GetItemIndex(ButtonSource);
	UnitState.AppearanceStore.Remove(Index, 1);
	CustomizeManager.CommitChanges(); // This will submit a Game State with appearance store changes and save CP.
	List.ClearItems();
	UpdateData();
	UpdateAppearanceList();
}


simulated function UIMechaListItem GetListItem(int ItemIndex, optional bool bDisableItem, optional string DisabledReason)
{
	local UIMechaListItem_AppearanceStore CustomizeItem;
	local UIPanel Item;

	if (List.ItemCount <= ItemIndex)
	{
		// Use UIMechaListItem_AppearanceStore instead of regular UIMechaListItem.
		CustomizeItem = Spawn(class'UIMechaListItem_AppearanceStore', List.ItemContainer);
		CustomizeItem.bAnimateOnInit = false;
		CustomizeItem.InitListItem();
	}
	else
	{
		Item = List.GetItem(ItemIndex);
		CustomizeItem = UIMechaListItem_AppearanceStore(Item);
	}

	CustomizeItem.SetDisabled(bDisableItem, DisabledReason != "" ? DisabledReason : m_strNeedsVeteranStatus);

	return CustomizeItem;
}

private function PlayArmorEquipSound(const name ArmorTemplateName)
{
	local X2EquipmentTemplate ArmorTemplate;

	ArmorTemplate = X2EquipmentTemplate(ItemMgr.FindItemTemplate(ArmorTemplateName));
	if (ArmorTemplate != none)
	{
		class'Help'.static.PlayStrategySoundEvent(ArmorTemplate.EquipSound, self);
	}
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
		`AMLOG("Applying compatibility for Unrestricted Customization on UIScreen:" @ self.Class.Name);
		SetPosition(0, 0);
		return;
	}
	// In case of interface lags, we restart the timer until the issue is successfully resolved.
	SetTimer(0.1f, false, nameof(FixScreenPosition), self);
}

simulated function CloseScreen()
{	
	SetPawnAppearance(OriginalAppearance);
	super.CloseScreen();
}

private function CloseScreenWithoutUpdate()
{	
	`AMLOG("This");
	super.CloseScreen();
}

simulated function PrevSoldier()
{
	UnitState.SetTAppearance(OriginalAppearance);
	super.PrevSoldier();
	CacheArmoryUnitData();
	UpdateData();
	UpdateAppearanceList();
}

simulated function NextSoldier()
{
	UnitState.SetTAppearance(OriginalAppearance);
	super.NextSoldier();
	CacheArmoryUnitData();
	UpdateData();
	UpdateAppearanceList();
}
