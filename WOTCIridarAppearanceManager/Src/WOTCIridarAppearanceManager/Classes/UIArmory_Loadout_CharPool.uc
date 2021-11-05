class UIArmory_Loadout_CharPool extends UIArmory_Loadout;

var XComCharacterCustomization		CustomizationManager;
var private CharacterPoolManager	CharPoolMgr;

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
		if (EqTemplate == none || !UnitState.CanAddItemToInventory(EqTemplate, SelectedSlot, TempGameState))
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
		UIArmory_LoadoutItem(LockerList.CreateItem(class'UIArmory_LoadoutItem')).InitLoadoutItem(LockerItem.Item, SelectedSlot, false, LockerItem.DisabledReason);
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

// Cosmetically equip new item. Mostly intended for Armor, but works with other items too.
simulated function bool EquipItem(UIArmory_LoadoutItem Item)
{
	local XComGameState_Item					NewItem;
	local EInventorySlot						SelectedSlot;
	local bool									EquipSucceeded;
	local X2WeaponTemplate						WeaponTemplate;
	local X2EquipmentTemplate					EquipmentTemplate;
	local XComGameStateHistory					History;	
	local XComGameState							TempGameState;
	local XComGameStateContext_ChangeContainer	TempContainer;	
	local TAppearance							NewAppearance;
	local XComGameState_Unit					UnitState;

	UnitState = GetUnit();
	if (UnitState == none)
		return false;

	History = `XCOMHISTORY;
	SelectedSlot = GetSelectedSlot();

	`AMLOG(UnitState.GetFullName() @ "attempting to equip item:" @ Item.ItemTemplate.DataName @ "into slot:" @ SelectedSlot $ ". Current torso:" @ UnitState.kAppearance.nmTorso);

	// Create and equip new item.
	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);
	NewItem = Item.ItemTemplate.CreateInstanceFromTemplate(TempGameState);
	
	EquipSucceeded = UnitState.AddItemToInventory(NewItem, SelectedSlot, TempGameState); 
	if (EquipSucceeded)
	{
		`AMLOG("Item equipped. New torso:" @ UnitState.kAppearance.nmTorso);

		WeaponTemplate = X2WeaponTemplate(Item.ItemTemplate);
		if (WeaponTemplate != none && WeaponTemplate.bUseArmorAppearance)
		{
			NewItem.WeaponAppearance.iWeaponTint = UnitState.kAppearance.iArmorTint;
		}
		else
		{
			NewItem.WeaponAppearance.iWeaponTint = UnitState.kAppearance.iWeaponTint;
		}
		NewItem.WeaponAppearance.nmWeaponPattern = UnitState.kAppearance.nmWeaponPattern;

		EquipmentTemplate = X2EquipmentTemplate(Item.ItemTemplate);
		if (EquipmentTemplate != none && EquipmentTemplate.EquipSound != "")
		{
			class'Help'.static.PlayStrategySoundEvent(EquipmentTemplate.EquipSound, self);
		}
	}

	History.AddGameStateToHistory(TempGameState);
	
	CreateVisualAttachments(UnitState);
	
	History.ObliterateGameStatesFromHistory(1);	

	UnitState.EmptyInventoryItems();

	if (EquipSucceeded)
	{
		// Always refresh and save unit's appearance in case equipping the item modified it.
		NewAppearance = UnitState.kAppearance;
		XComUnitPawn(CustomizationManager.ActorPawn).SetAppearance(NewAppearance);

		if (SelectedSlot == eInvSlot_Armor)
		{
			UnitState.StoreAppearance(NewAppearance.iGender, Item.ItemTemplate.DataName);
		}
		else
		{
			UnitState.StoreAppearance(NewAppearance.iGender);
		}
		CustomizationManager.CommitChanges();
		

		CharPoolMgr.SaveCharacterPool();
	}
	return EquipSucceeded;
}

simulated private function CreateVisualAttachments(XComGameState_Unit UnitState)
{
	local UIPawnMgr					PawnMgr;
	local XComPresentationLayerBase	PresBase;
	local XComUnitPawn				UnitPawn;

	PresBase = XComPresentationLayerBase(CustomizationManager.Outer);
	if (PresBase == none)
	{
		`AMLOG("Error, no PresBase");
		return;
	}
	
	PawnMgr = PresBase.GetUIPawnMgr();
	if (PawnMgr == none)
	{
		`AMLOG("Error, no PawnMgr");
		return;
	} 

	UnitPawn = XComUnitPawn(CustomizationManager.ActorPawn);
	if (UnitPawn == none)
	{
		`AMLOG("Error, no Unit Pawn");
		return;
	} 

	`AMLOG(UnitState.GetFullName());	
	UnitPawn.CreateVisualInventoryAttachments(PawnMgr, UnitState);
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
	UpdateEquippedList();
	//Header.PopulateData(GetUnit());
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
		Item = UIArmory_LoadoutItem(EquippedList.CreateItem(class'UIArmory_LoadoutItem'));
		if (CannotEditSlotsList.Find(En.Slot) != INDEX_NONE)
			Item.InitLoadoutItem(En.ItemState, En.Slot, true, m_strCannotEdit);
		else if (En.IsLocked)
			Item.InitLoadoutItem(En.ItemState, En.Slot, true, En.LockedReason);
		else
			Item.InitLoadoutItem(En.ItemState, En.Slot, true);

		// ADDED
		// Use cosmetic torso to figure out which armor template could have been used for it.
		if (En.Slot == eInvSlot_Armor)
		{
			ItemTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(UpdatedUnit.kAppearance.nmTorso);
			if (ItemTemplate != none)
			{
				SetItemImage(Item, ItemTemplate);
				Item.SetTitle(ItemTemplate.GetItemFriendlyName());
				Item.SetSubTitle(ItemTemplate.GetLocalizedCategory());
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