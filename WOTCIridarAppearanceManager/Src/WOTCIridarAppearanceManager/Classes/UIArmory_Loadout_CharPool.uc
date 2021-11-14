class UIArmory_Loadout_CharPool extends UIArmory_Loadout;

var XComCharacterCustomization		CustomizationManager;
var private CharacterPoolManager_AM	CharPoolMgr;
var private name					CachedPreviousArmorName;

var private config(ExcludedItems) array<name> EXCLUDED_SKINS;

// Modified Loadout screen, used to "equip" armors and weapons in Character Pool.
// All changes done to Unit States on this screen don't submit gamestates.

simulated function InitArmory(StateObjectReference UnitRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	super.InitArmory(UnitRef, DispEvent, SoldSpawnEvent, NavBackEvent, HideEvent, RemoveEvent, bInstant, InitCheckGameState);

	CharPoolMgr = `CHARACTERPOOLMGRAM;
	Header.Hide();
}

simulated function XComGameState_Unit GetUnit()
{
	return CustomizationManager.UpdatedUnitState;
}

simulated function ResetAvailableEquipment() { }

// Build a list of all items that can be potentially equipped into the selected slot on the current unit.
// Item States are then immediately nuked, but loadout list items will retain their templates.
simulated function UpdateLockerList()
{
	local XComGameState_Item					Item;
	local EInventorySlot						SelectedSlot;
	local array<TUILockerItem>					LockerItems;
	local TUILockerItem							LockerItem;

	local X2ItemTemplateManager					ItemMgr;
	local X2EquipmentTemplate					EqTemplate;
	local X2DataTemplate						DataTemplate;

	local XComGameStateHistory					History;	
	local XComGameState							TempGameState;
	local XComGameStateContext_ChangeContainer	TempContainer;
	local XComGameState_Unit					UnitState;

	UnitState = GetUnit();
	SelectedSlot = GetSelectedSlot();
	History = `XCOMHISTORY;
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	LocTag.StrValue0 = class'CHItemSlot'.static.SlotGetName(SelectedSlot);
	MC.FunctionString("setRightPanelTitle", `XEXPAND.ExpandString(m_strLockerTitle));
		
	`AMLOG(UnitState.GetFullName() @ "and slot:" @ SelectedSlot);
		
	// Use a temporary Game State to build a list of armors that can be potentially equipped on this unit.
	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);
	
	foreach ItemMgr.IterateTemplates(DataTemplate)
	{
		EqTemplate = X2EquipmentTemplate(DataTemplate);
		if (EqTemplate == none || !ShouldShowTemplate(EqTemplate) || !UnitState.CanAddItemToInventory(EqTemplate, SelectedSlot, TempGameState))
			continue;

		Item = EqTemplate.CreateInstanceFromTemplate(TempGameState);
		if (ShowInLockerList(Item, SelectedSlot))
		{
			LockerItem.Item = Item;
			LockerItem.DisabledReason = GetDisabledReason(Item, SelectedSlot);
			LockerItem.CanBeEquipped = LockerItem.DisabledReason == "";
			LockerItems.AddItem(LockerItem);
		}
	}

	// Have to submit the Game State, because UIArmory_LoadoutItem will read the History.
	History.AddGameStateToHistory(TempGameState);

	//LockerItems.Sort(SortLockerListByUpgrades);
	LockerItems.Sort(SortLockerListByTier);
	//LockerItems.Sort(SortLockerListByEquip);

	LockerList.ClearItems();
	foreach LockerItems(LockerItem)
	{
		UIArmory_LoadoutItem(LockerList.CreateItem(class'UIArmory_LoadoutItem_CharPool')).InitLoadoutItem(LockerItem.Item, SelectedSlot, false, LockerItem.DisabledReason);
	}
	// If we have an invalid SelectedIndex, just try and select the first thing that we can.
	// Otherwise let's make sure the Navigator is selecting the right thing.
	if(LockerList.SelectedIndex < 0 || LockerList.SelectedIndex >= LockerList.ItemCount)
	{
		LockerList.Navigator.SelectFirstAvailable();
	}
	else
	{
		LockerList.Navigator.SetSelected(LockerList.GetSelectedItem());
	}
	OnSelectionChanged(ActiveList, ActiveList.SelectedIndex);

	// Nuke the Game State once we no longer need it.
	History.ObliterateGameStatesFromHistory(1);
}

private function bool ShouldShowTemplate(const X2ItemTemplate ItemTemplate)
{
	 return ItemTemplate.iItemSize > 0 &&		//	Item worth wearing (e.g. not an XPAD)
			ItemTemplate.HasDisplayData() &&	//	Has localized name
			ItemTemplate.strImage != "" &&		//	Has inventory icon
			EXCLUDED_SKINS.Find(ItemTemplate.DataName) == INDEX_NONE;
}

// Cosmetically equip new item. Mostly intended for Armor, but works with other items too.
simulated function bool EquipItem(UIArmory_LoadoutItem Item)
{
	local XComGameState_Unit	UnitState;
	local X2ItemTemplate		ItemTemplate;

	UnitState = GetUnit();
	if (UnitState == none)
		return false;

	`AMLOG(UnitState.GetFullName() @ "adding" @ Item.ItemTemplate.DataName @ GetSelectedSlot() @ "into loadout");

	// Sort of a hack, cache previously equipped armor template name so that we can store appearance for it in EquipCharacterPoolLoadout() called by OnRefreshPawn().
	// Normally EquipCharacterPoolLoadout() can figure out which armor was previously equipped on its own, by reading the saved CP loadout,
	// but since we're changing that loadout right before calling EquipCharacterPoolLoadout(), we have to remember previously equipped armor ourselves,
	// and pass it to EquipCharacterPoolLoadout() later.
	CachedPreviousArmorName = class'Help'.static.GetEquippedArmorTemplateName(UnitState, CharPoolMgr);
	`AMLOG("CachedPreviousArmorName from CP loadout:" @ CachedPreviousArmorName);
	if (CachedPreviousArmorName == '')
	{
		ItemTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(UnitState.kAppearance.nmTorso);
		if (ItemTemplate != none)
		{	
			CachedPreviousArmorName = ItemTemplate.DataName;
			`AMLOG("CachedPreviousArmorName from cosmetic torso:" @ CachedPreviousArmorName @ UnitState.kAppearance.nmTorso);
		}
	}

	CharPoolMgr.AddItemToCharacterPoolLoadout(UnitState, GetSelectedSlot(), Item.ItemTemplate.DataName);
	CharPoolMgr.SaveCharacterPool();

	CustomizationManager.ReCreatePawnVisuals(CustomizationManager.ActorPawn, true);

	SetTimer(0.01f, false, nameof(OnRefreshPawn), self);
	
	return true;
}

private function OnRefreshPawn()
{
	if (CustomizationManager.ActorPawn != none)
	{
		`AMLOG("Equipping character pool loadout.");
		// UIArmory and children keep a reference to the pawn, and release the reference when screen is removed. 
		// Update the reference so it can be cleaned up later. Otherwise the pawn may keep existing long after the screen is gone.
		ActorPawn = CustomizationManager.ActorPawn; 
		EquipCharacterPoolLoadout(CachedPreviousArmorName);
		
		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizationManager.ActorPawn);
	}
	else
	{
		`AMLOG("Restarting timer");
		SetTimer(0.01f, false, nameof(OnRefreshPawn), self);
	}
}

static final function array<CharacterPoolLoadoutStruct> EquipCharacterPoolLoadout(optional name PreviousArmorName)
{
	local CharacterPoolManager_AM				LocalPoolMgr;
	local array<CharacterPoolLoadoutStruct>		CharacterPoolLoadout;
	local CharacterPoolLoadoutStruct			LoadoutElement;
	local X2ItemTemplateManager					ItemMgr;
	local X2ItemTemplate						ItemTemplate;
	local XComGameStateHistory					LocalHistory;
	local XComGameState_Item					ItemState;
	local XComGameState							TempGameState;
	local XComGameStateContext_ChangeContainer	TempContainer;	
	local bool									bEquippedAtLeastOneItem;
	local X2WeaponTemplate						WeaponTemplate;
	local XComGameState_Unit					UnitState;
	local XComPresentationLayerBase				PresBase;
	local UICustomize							CustomizeScreen;
	local XComUnitPawn							UnitPawn;
	local TAppearance							NewAppearance;
	local XComCharacterCustomization			CustomizeManager;
	local UIArmory_Loadout_CharPool				LoadoutScreen;
	local name									EquippedArmorName;	
	local array<int>							FailedToEquipItemIndices;
	local int									i;

	// -------------------------------------------------------------------------------------------------------
	// INIT
	`AMLOG("Beginning init. Previous armor:" @ PreviousArmorName);

	PresBase = `PRESBASE;
	if (PresBase == none) { `AMLOG("No PresBase, exiting."); return CharacterPoolLoadout; }

	LocalPoolMgr = `CHARACTERPOOLMGRAM;
	if (LocalPoolMgr == none) { `AMLOG("No Pool Manager, exiting."); return CharacterPoolLoadout; }

	// This function is either called by UISL_AppearanceManager, which runs on UICustomize_Menu init, or from this screen. We don't really care which, we just need Customize Manager.
	CustomizeScreen = UICustomize(PresBase.ScreenStack.GetCurrentScreen());
	if (CustomizeScreen == none) 
	{ 
		LoadoutScreen = UIArmory_Loadout_CharPool(PresBase.ScreenStack.GetCurrentScreen());
		if (LoadoutScreen == none)	return CharacterPoolLoadout;

		CustomizeManager = LoadoutScreen.CustomizationManager;
	}
	else CustomizeManager = CustomizeScreen.CustomizeManager;

	if (CustomizeManager == none || CustomizeManager.UpdatedUnitState == none) return CharacterPoolLoadout;

	UnitPawn = XComUnitPawn(CustomizeManager.ActorPawn);
	if (UnitPawn == nonE) { `AMLOG("No unit pawn"); return CharacterPoolLoadout; }

	UnitState = CustomizeManager.UpdatedUnitState;
	
	CharacterPoolLoadout = LocalPoolMgr.GetCharacterPoolLoadout(UnitState);
	if (CharacterPoolLoadout.Length == 0) 
	{ 
		`AMLOG("No char pool loadout"); 
		return CharacterPoolLoadout; 
	}
	else if (PreviousArmorName == '') // Attempt to figure out which armor was equipped on the unit previously, if it wasn't passed to us already.
	{
		PreviousArmorName = class'Help'.static.GetArmorTemplateNameFromCharacterPoolLoadout(CharacterPoolLoadout);
	}

	`AMLOG("Finished init. Previous armor:" @ PreviousArmorName);

	LocalHistory = `XCOMHISTORY;
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	// -------------------------------------------------------------------------------------------------------
	// BEGING EQUIPPING THE LOADOUT

	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = LocalHistory.CreateNewGameState(true, TempContainer);
	
	foreach CharacterPoolLoadout(LoadoutElement, i)
	{
		`AMLOG("LoadoutElement:" @ LoadoutElement.TemplateName @ LoadoutElement.InventorySlot);

		ItemTemplate = ItemMgr.FindItemTemplate(LoadoutElement.TemplateName);
		if (ItemTemplate == none)
			continue;

		// Store appearance for the previously equipped armor before equipping new one.
		if (LoadoutElement.InventorySlot == eInvSlot_Armor && PreviousArmorName != '' && PreviousArmorName != LoadoutElement.TemplateName)
		{
			`AMLOG("Storing appearance for previous armor:" @ PreviousArmorName @ "Old torso:" @ UnitState.kAppearance.nmTorso);
			UnitState.StoreAppearance(UnitState.kAppearance.iGender, PreviousArmorName);
		}

		ItemState = ItemTemplate.CreateInstanceFromTemplate(TempGameState);
		if (UnitState.AddItemToInventory(ItemState, LoadoutElement.InventorySlot, TempGameState))
		{
			bEquippedAtLeastOneItem = true;

			switch (LoadoutElement.InventorySlot)
			{
				case eInvSlot_PrimaryWeapon:
					CustomizeManager.PrimaryWeapon = ItemState;
					break;
				case eInvSlot_SecondaryWeapon:
					CustomizeManager.SecondaryWeapon = ItemState;
					break;
				case eInvSlot_TertiaryWeapon:
					CustomizeManager.TertiaryWeapon = ItemState;
					break;
				case eInvSlot_Armor:
					EquippedArmorName = ItemTemplate.DataName;
					break;
				default:
					break;
			}

			`AMLOG("Equipped item successfully.");

			WeaponTemplate = X2WeaponTemplate(ItemTemplate);
			if (WeaponTemplate != none && WeaponTemplate.bUseArmorAppearance)
				ItemState.WeaponAppearance.iWeaponTint = UnitState.kAppearance.iArmorTint;
			else
				ItemState.WeaponAppearance.iWeaponTint = UnitState.kAppearance.iWeaponTint;
			ItemState.WeaponAppearance.nmWeaponPattern = UnitState.kAppearance.nmWeaponPattern;
		}
		else 
		{
			`AMLOG("Failed to equip item.");
			FailedToEquipItemIndices.AddItem(i);
		}
	}

	// -------------------------------------------------------------------------------------------------------
	// CLEANUP LOADOUT
	// The loadout has to be equipped in the specific order, since items are sorted by inventory slot.
	// So we can't delete loadout items as we cycle through the loadout, because we're cycling through it forwards.
	// So after we're done equipping the loadout, remove all items we failed to equip.
	// Then the saved loadout can be used as a source-of-truth - if the loadout item is there, then it was equipped successfully.
	for (i = FailedToEquipItemIndices.Length - 1; i >= 0; i--)
	{
		CharacterPoolLoadout.Remove(FailedToEquipItemIndices[i], 1);
	}
	if (FailedToEquipItemIndices.Length > 0)
	{
		LocalPoolMgr.SetCharacterPoolLoadout(UnitState, CharacterPoolLoadout);
	}

	// -------------------------------------------------------------------------------------------------------
	// POST-EQUIP ACTIONS

	if (bEquippedAtLeastOneItem)
	{
		NewAppearance = UnitState.kAppearance;
		UnitPawn.SetAppearance(NewAppearance);
		`AMLOG("Storing appearance for new armor. New torso:" @ NewAppearance.nmTorso);
		UnitState.StoreAppearance(UnitState.kAppearance.iGender, EquippedArmorName);
		CustomizeManager.CommitChanges();

		LocalHistory.AddGameStateToHistory(TempGameState);
		UnitPawn.CreateVisualInventoryAttachments(PresBase.GetUIPawnMgr(), UnitState);

		if (LoadoutScreen != none) LoadoutScreen.UpdateEquippedList();

		LocalHistory.ObliterateGameStatesFromHistory(1);	
		UnitState.EmptyInventoryItems();
	}
	else
	{	
		LocalHistory.CleanupPendingGameState(TempGameState);
	}

	// Return the equipped loadout so that function callers can validate if the item they wanted to equip was equipped.
	return CharacterPoolLoadout;
}

simulated function bool ShowInLockerList(XComGameState_Item Item, EInventorySlot SelectedSlot)
{
	local X2ItemTemplate ItemTemplate;

	ItemTemplate = Item.GetMyTemplate();
	
	return class'CHItemSlot'.static.SlotShowItemInLockerList(SelectedSlot, GetUnit(), Item, ItemTemplate, CheckGameState);
}

simulated function UpdateData(optional bool bRefreshPawn)
{
	UpdateLockerList();
}

// Slightly modified original function. Leave it as messy as the original.
// Purpose: show equipped cosmetic armor's icon in the "equipped" list.
simulated function UpdateEquippedList()
{
	//local int i, numUtilityItems; // Issue #118, unneeded
	local UIArmory_LoadoutItem Item;
	//ocal array<XComGameState_Item> UtilityItems; // Issue #118, unneeded
	local XComGameState_Unit UpdatedUnit;
	local int prevIndex;
	local CHUIItemSlotEnumerator En; // Variable for Issue #118
	local X2ItemTemplate		ItemTemplate;
	local XComHumanPawn			UnitPawn;


	prevIndex = EquippedList.SelectedIndex;
	UpdatedUnit = GetUnit();
	EquippedList.ClearItems();

	// Clear out tooltips from removed list items
	Movie.Pres.m_kTooltipMgr.RemoveTooltipsByPartialPath(string(EquippedList.MCPath));
	
	// Issue #171 Start
	// Realize Inventory so mods changing utility slots get updated faster
	UpdatedUnit.RealizeItemSlotsCount(CheckGameState);
	// Issue #171 End

	// Issue #118 Start
	// Here used to be a lot of code handling individual slots, this has been abstracted in CHItemSlot (and the Enumerator)
	//CreateEnumerator(XComGameState_Unit _UnitState, optional XComGameState _CheckGameState, optional array<CHSlotPriority> _SlotPriorities, optional bool _UseUnlockHints, optional array<EInventorySlot> _OverrideSlotsList)
	En = class'CHUIItemSlotEnumerator'.static.CreateEnumerator(UpdatedUnit, CheckGameState);
	while (En.HasNext())
	{
		En.Next();
		Item = UIArmory_LoadoutItem(EquippedList.CreateItem(class'UIArmory_LoadoutItem_CharPool'));
		if (CannotEditSlotsList.Find(En.Slot) != INDEX_NONE)
			Item.InitLoadoutItem(En.ItemState, En.Slot, true, m_strCannotEdit);
		else if (En.IsLocked)
			Item.InitLoadoutItem(En.ItemState, En.Slot, true, En.LockedReason);
		else
			Item.InitLoadoutItem(En.ItemState, En.Slot, true);

		// ADDED
		// Use cosmetic torso to figure out which armor template could have been used for it.
		if (En.ItemState == none && En.Slot == eInvSlot_Armor)
		{
			UnitPawn = XComHumanPawn(CustomizationManager.ActorPawn);
			if (UnitPawn != none)
			{
				ItemTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(UnitPawn.m_kAppearance.nmTorso);
				if (ItemTemplate != none)
				{
					SetItemImage(Item, ItemTemplate);
					Item.SetTitle(ItemTemplate.GetItemFriendlyName());
					Item.SetSubTitle(ItemTemplate.GetLocalizedCategory());
				}
			}
		}
		// END OF ADDED
	}
	EquippedList.SetSelectedIndex(prevIndex < EquippedList.ItemCount ? prevIndex : 0);
	// Force item into view
	EquippedList.NavigatorSelectionChanged(EquippedList.SelectedIndex);
	// Issue #118 End
}

// Hodge podge function of existing code responsible for showing item's icon.
simulated private function SetItemImage(UIArmory_LoadoutItem LoadoutItem, X2ItemTemplate ItemTemplate)
{
	local int i;
	local bool bUpdate;
	local array<string> NewImages;
	// Issue #171 variables
	local array<X2DownloadableContentInfo> DLCInfos;

	if(ItemTemplate.strImage == "")
	{
		LoadoutItem.MC.FunctionVoid("setImages");
		return;
	}

	NewImages.AddItem(ItemTemplate.strImage);

	// Start Issue #171
	DLCInfos = `ONLINEEVENTMGR.GetDLCInfos(false);
	for(i = 0; i < DLCInfos.Length; ++i)
	{
		// Single line for Issue #962 - pass on Item State.
		DLCInfos[i].OverrideItemImage_Improved(NewImages, LoadoutItem.EquipmentSlot, ItemTemplate, UIArmory(LoadoutItem.Screen).GetUnit(), none);
	}
	// End Issue #171

	bUpdate = false;
	for( i = 0; i < NewImages.Length; i++ )
	{
		if( LoadoutItem.Images.Length <= i || LoadoutItem.Images[i] != NewImages[i] )
		{
			bUpdate = true;
			break;
		}
	}

	//If no image at all is defined, mark it as empty 
	if( NewImages.length == 0 )
	{
		NewImages.AddItem("");
		bUpdate = true;
	}

	if(bUpdate)
	{
		LoadoutItem.Images = NewImages;
		
		LoadoutItem.MC.BeginFunctionOp("setImages");
		LoadoutItem.MC.QueueBoolean(false); // always first

		for( i = 0; i < LoadoutItem.Images.Length; i++ )
			LoadoutItem.MC.QueueString(LoadoutItem.Images[i]); 

		LoadoutItem.MC.EndOp();
	}
}

defaultproperties
{
	bUseNavHelp = false
}