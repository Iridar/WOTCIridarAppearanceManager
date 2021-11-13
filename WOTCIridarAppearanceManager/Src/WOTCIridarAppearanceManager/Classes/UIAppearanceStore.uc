class UIAppearanceStore extends UICustomize;

// This screen lists unit's AppearanceStore elements, allows to preview and delete them.

// TODO: This screen suffers from being darkened by MouseGuard as well.

var private X2ItemTemplateManager	ItemMgr;
var private XComGameState_Unit		UnitState;
var private TAppearance				OriginalAppearance;
var private TAppearance				SelectedAppearance;
var private XComHumanPawn			ArmoryPawn;
var private bool					bPawnRefreshIsCooldown;
var private CharacterPoolManager_AM PoolMgr;

const PAWN_REFRESH_COOLDOWN = 0.15f;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	PoolMgr = `CHARACTERPOOLMGRAM;

	CacheArmoryUnitData();
	List.OnSelectionChanged = OnListItemSelected;
	List.OnItemClicked = AppearanceListItemClicked;

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
	local array<CharacterPoolLoadoutStruct> CharacterPoolLoadout;
	local XComGameState_Item				ItemState;
	local XComGameState_Item				NewItemState;
	local XComGameState_Item				PreviousItemState;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState						NewGameState;
	local XComGameState_Unit				NewUnitState;

	if (ItemIndex == INDEX_NONE)
		return;

	ListItem = UIMechaListItem_AppearanceStore(List.GetItem(ItemIndex));
	if (ListItem == none || ListItem.ArmorTemplateName == '' || ListItem.bIsCurrentAppearance)
	{
		class'Help'.static.PlayStrategySoundEvent("Play_MenuClickNegative", self);
		return;
	}

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	if (XComHQ == none) // Then we're character pool.
	{
		CharacterPoolLoadout = PoolMgr.GetCharacterPoolLoadout(UnitState); // Save previous loadout
		PoolMgr.UpdateCharacterPoolLoadout(UnitState, eInvSlot_Armor, ListItem.ArmorTemplateName);
		if (!class'UIArmory_Loadout_CharPool'.static.EquipCharacterPoolLoadout())
		{
			`AMLOG("Failed to equip the entire Character Pool loadout, exiting." @ ListItem.ArmorTemplateName);
			PoolMgr.SetCharacterPoolLoadout(UnitState, CharacterPoolLoadout); // If we failed to equip all of the items, play the fail sound and restore saved loadout.
			class'UIArmory_Loadout_CharPool'.static.EquipCharacterPoolLoadout();
			class'Help'.static.PlayStrategySoundEvent("Play_MenuClickNegative", self);
		}
		else
		{
			SetAppearanceAndMaybeRefreshPawn();
			PlayArmorEquipSound(ListItem.ArmorTemplateName);
			super.CloseScreen();
		}
	}
	else // We're in the Armory
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Equip armor for stored appearance on:" @ UnitState.GetFullName() @ ListItem.ArmorTemplateName);
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));
		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));

		ItemState = XComHQ.GetItemByName(ListItem.ArmorTemplateName);
		if (ItemState == none)
		{
			`AMLOG("No such item in HQ inventory:" @ ListItem.ArmorTemplateName);
			`XCOMHISTORY.CleanupPendingGameState(NewGameState);
			class'Help'.static.PlayStrategySoundEvent("Play_MenuClickNegative", self);
			return;
		}

		XComHQ.GetItemFromInventory(NewGameState, ItemState.GetReference(), NewItemState);
		if (NewItemState != none)
		{
			PreviousItemState = NewUnitState.GetItemInSlot(eInvSlot_Armor);
			if (PreviousItemState != none)
			{
				if (NewUnitState.RemoveItemFromInventory(PreviousItemState, NewGameState))
				{
					XComHQ.PutItemInInventory(NewGameState, PreviousItemState);
				}
				else
				{
					`AMLOG("Failed to free the inventory slot containing item:" @ PreviousItemState.GetMyTemplateName());
					`XCOMHISTORY.CleanupPendingGameState(NewGameState);
					class'Help'.static.PlayStrategySoundEvent("Play_MenuClickNegative", self);
					return;
				}
			}

			if (NewUnitState.AddItemToInventory(NewItemState, eInvSlot_Armor, NewGameState))
			{
				`GAMERULES.SubmitGameState(NewGameState);
				PlayArmorEquipSound(ListItem.ArmorTemplateName);
				SetAppearanceAndMaybeRefreshPawn();
				super.CloseScreen();
			}
			else
			{
				// Failed to equip item.
				`AMLOG("Failed to equip item:" @ NewItemState.GetMyTemplateName());
				`XCOMHISTORY.CleanupPendingGameState(NewGameState);
				class'Help'.static.PlayStrategySoundEvent("Play_MenuClickNegative", self);
			}
		}
	}
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


/*
final function array<CharacterPoolLoadoutStruct> GetCharacterPoolLoadout(const XComGameState_Unit UnitState)
{
	return ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].CharacterPoolLoadout;
}
final function SetCharacterPoolLoadout(const XComGameState_Unit UnitState, array<CharacterPoolLoadoutStruct> CharacterPoolLoadout)
{
	ExtraDatas[ GetExtraDataIndexForUnit(UnitState) ].CharacterPoolLoadout = CharacterPoolLoadout;
	SaveCharacterPool();
}
final function UpdateCharacterPoolLoadout(const XComGameState_Unit UnitState, const EInventorySlot InventorySlot, const name TemplateName)
{
*/


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

simulated function UpdateData()
{
	local UIMechaListItem_AppearanceStore ListItem;
	local AppearanceInfo	StoredAppearance;
	local X2ItemTemplate	ArmorTemplate;
	local EGender			Gender;
	local name				ArmorTemplateName;
	local string			DisplayName;
	local int i;

	super.UpdateData();
	if (UnitState == none)
		return;

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
			ListItem = GetListItem_AM(i++);
			ListItem.UpdateDataDescription(DisplayName); // Deleting current appearance may not work as people expect it to.
			ListItem.ArmorTemplateName = ArmorTemplateName;
			ListItem.bIsCurrentAppearance = true;
		}
		else
		{
			ListItem = GetListItem_AM(i++);
			ListItem.UpdateDataButton(DisplayName, class'UISaveLoadGameListItem'.default.m_sDeleteLabel, OnDeleteButtonClicked);
			ListItem.ArmorTemplateName = ArmorTemplateName;
		}
	}
}

// Use UIMechaListItem_AppearanceStore instead of regular UIMechaListItem.
simulated function UIMechaListItem_AppearanceStore GetListItem_AM(int ItemIndex, optional bool bDisableItem, optional string DisabledReason)
{
	local UIMechaListItem_AppearanceStore CustomizeItem;
	local UIPanel Item;

	if(List.ItemCount <= ItemIndex)
	{
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
	SetPawnAppearance(SelectedAppearance);
}

private function SetPawnAppearance(TAppearance NewAppearance)
{
	// Have to update appearance in the unit state, since it will be used to recreate the pawn.
	UnitState.SetTAppearance(NewAppearance);
	//ArmoryPawn.SetAppearance(NewAppearance);
		
	// Normally we'd refresh the pawn only in case of gender change, 
	// but here we need to refresh pawn every time to get rid of WAR Suit's exo attachments.
	CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);

	// Can't use an Event Listener in Shell, so using a timer (ugh)
	SetTimer(0.1f, false, nameof(OnRefreshPawn), self);
}

private function SetAppearanceAndMaybeRefreshPawn()
{
	UnitState.SetTAppearance(SelectedAppearance);

	if (ArmoryPawn == none || ArmoryPawn.m_kAppearance != SelectedAppearance)
	{
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
	}
}

final function OnRefreshPawn()
{
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn != none)
	{
		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizeManager.ActorPawn);
	}
	else
	{
		SetTimer(0.1f, false, nameof(OnRefreshPawn), self);
	}
}

simulated function CloseScreen()
{	
	SetPawnAppearance(OriginalAppearance);
	super.CloseScreen();
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
}

simulated function PrevSoldier()
{
	UnitState.SetTAppearance(OriginalAppearance);
	super.PrevSoldier();
	CacheArmoryUnitData();
	UpdateData();
}

simulated function NextSoldier()
{
	UnitState.SetTAppearance(OriginalAppearance);
	super.NextSoldier();
	CacheArmoryUnitData();
	UpdateData();
}
