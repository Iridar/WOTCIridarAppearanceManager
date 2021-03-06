class UIArmory_Loadout_CharPool extends UIArmory_Loadout;

// Modified Loadout screen, used to "equip" armors and weapons in Character Pool.
// All changes done to Unit States on this screen don't submit gamestates.

var XComCharacterCustomization		CustomizationManager;
var CharacterPoolManager_AM			CharPoolMgr;
var private	X2PawnRefreshHelper		PawnRefreshHelper;

var private config(ExcludedItems) array<name> EXCLUDED_CP_LOADOUT_ITEMS;

simulated function InitArmory(StateObjectReference UnitRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	super.InitArmory(UnitRef, DispEvent, SoldSpawnEvent, NavBackEvent, HideEvent, RemoveEvent, bInstant, InitCheckGameState);

	CharPoolMgr = `CHARACTERPOOLMGRAM;

	PawnRefreshHelper = new class'X2PawnRefreshHelper';
	PawnRefreshHelper.LoadoutScreen = self;
	PawnRefreshHelper.InitHelper(CustomizationManager, CharPoolMgr);
	PawnRefreshHelper.RefreshPawn(false); // Have to refresh pawn to update the list of equipped items properly. Passing 'false' is enough to not nuke the pawn.
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

	SelectedSlot = GetSelectedSlot();
	if (SelectedSlot == eInvSlot_Unknown) 
		return;

	UnitState = GetUnit();
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
	if (ActiveList != none)
	{
		OnSelectionChanged(ActiveList, ActiveList.SelectedIndex);
	}

	// Nuke the Game State once we no longer need it.
	History.ObliterateGameStatesFromHistory(1);
}

private function bool ShouldShowTemplate(const X2ItemTemplate ItemTemplate)
{
	 return ItemTemplate.iItemSize > 0 &&		//	Item worth wearing (e.g. not an XPAD)
			ItemTemplate.HasDisplayData() &&	//	Has localized name
			ItemTemplate.strImage != "" &&		//	Has inventory icon
			!HasItemBeenHiddenByItemHider(ItemTemplate) &&
			EXCLUDED_CP_LOADOUT_ITEMS.Find(ItemTemplate.DataName) == INDEX_NONE;
}

// Compatibility with Item Hider mod.
private function bool HasItemBeenHiddenByItemHider(const X2ItemTemplate Template)
{
	return  Template.CreatorTemplateName == '' &&
			Template.CanBeBuilt == false &&
			Template.HideInInventory == true &&
			Template.HideInLootRecovered == true &&
			Template.UpgradeItem == '' &&
			Template.BaseItem == '';
			//Template.bInfiniteItem == false && 
			//Template.PointsToComplete == 999999 &&
			//Template.Requirements.RequiredEngineeringScore == 999999 &&
			//Template.Requirements.bVisibleifPersonnelGatesNotMet == false &&
			//Template.OnBuiltFn == none &&
			//Template.Cost.ResourceCosts.Length == 0 &&
			//Template.Cost.ArtifactCosts.Length == 0;
}


// Completely replaced the original functionality. Since in Character Pool units don't have any items equipped, we remember the unit's entire character pool loadout,
// end equip it entirely every time. When we need to "equip" a new item, we put the item into the CP loadout, and make the unit equip the entire loadout.
simulated function bool EquipItem(UIArmory_LoadoutItem Item)
{
	local array<CharacterPoolLoadoutStruct>	CharacterPoolLoadout;
	local CharacterPoolLoadoutStruct		LoadoutElement;
	local XComGameState_Unit				UnitState;
	local EInventorySlot					InventorySlot;
	local bool								bIsArmor;
	
	InventorySlot = GetSelectedSlot();
	UnitState = GetUnit();
	if (UnitState == none || InventorySlot == eInvSlot_Unknown)
		return false;

	`AMLOG(UnitState.GetFullName() @ "adding" @ Item.ItemTemplate.DataName @ GetSelectedSlot() @ "into loadout");

	bIsArmor = X2ArmorTemplate(Item.ItemTemplate) != none && InventorySlot == eInvSlot_Armor;
	if (bIsArmor)
	{
		UnitState.StoreAppearance();
	}
	
	CharPoolMgr.AddItemToCharacterPoolLoadout(UnitState, GetSelectedSlot(), Item.ItemTemplate.DataName);
	CharPoolMgr.SaveCharacterPool();

	CharacterPoolLoadout = PawnRefreshHelper.RefreshPawn(true);

	foreach CharacterPoolLoadout(LoadoutElement)
	{
		if (LoadoutElement.InventorySlot == InventorySlot && LoadoutElement.TemplateName == Item.ItemTemplate.DataName)
		{	
			class'Help'.static.PlayStrategySoundEvent(X2EquipmentTemplate(Item.ItemTemplate).EquipSound, self);
			if (bIsArmor)
			{
				UnitState.StoreAppearance(, Item.ItemTemplate.DataName);
			}
			return true;
		}
	}

	return false;
}

simulated function bool ShowInLockerList(XComGameState_Item Item, EInventorySlot SelectedSlot)
{
	local X2ItemTemplate ItemTemplate;

	ItemTemplate = Item.GetMyTemplate();
	
	return class'CHItemSlot'.static.SlotShowItemInLockerList(SelectedSlot, GetUnit(), Item, ItemTemplate, CheckGameState);
}

simulated function UpdateData(optional bool bRefreshPawn)
{
	//Header.PopulateData(GetUnit()); // Needs to be done only while refreshing the pawn.
	//UpdateEquippedList(); 
	UpdateLockerList();
}

// Slightly modified original function. Left it as messy as the original.
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

simulated function ResetAvailableEquipment() { }

// -----------------------------------------------
// Populate Header only when refreshing the pawn.
simulated function OnSelectionChanged(UIList ContainerList, int ItemIndex)
{
	//local UIArmory_LoadoutItem ContainerSelection, EquippedSelection;
	//local StateObjectReference EmptyRef, ContainerRef, EquippedRef;

	//ContainerSelection = UIArmory_LoadoutItem(ContainerList.GetSelectedItem());
	//EquippedSelection = UIArmory_LoadoutItem(EquippedList.GetSelectedItem());

	//ContainerRef = ContainerSelection != none ? ContainerSelection.ItemRef : EmptyRef;
	//EquippedRef = EquippedSelection != none ? EquippedSelection.ItemRef : EmptyRef;

	//if((ContainerSelection == none) || !ContainerSelection.IsDisabled)
	//	Header.PopulateData(GetUnit(), ContainerRef, EquippedRef);

	InfoTooltip.HideTooltip();
	if(`ISCONTROLLERACTIVE)
	{
		ClearTimer(nameof(DelayedShowTooltip));
		SetTimer(0.21f, false, nameof(DelayedShowTooltip));
	}
	UpdateNavHelp();
}
simulated function ChangeActiveList(UIList kActiveList, optional bool bSkipAnimation)
{
	local UIArmory_LoadoutItem LoadoutItem;

	ActiveList = kActiveList;

	LoadoutItem = UIArmory_LoadoutItem(EquippedList.GetSelectedItem());
	
	if(kActiveList == EquippedList)
	{
		if(!bSkipAnimation)
			MC.FunctionVoid("closeList");

		// unlock selected item
		if (LoadoutItem != none)
			LoadoutItem.SetLocked(false);
		// disable list item selection on LockerList, enable it on EquippedList
		LockerListContainer.DisableMouseHit();
		EquippedListContainer.EnableMouseHit();

		//Header.PopulateData(GetUnit());
		Navigator.RemoveControl(LockerListContainer);
		Navigator.AddControl(EquippedListContainer);
		EquippedList.EnableNavigation();
		LockerList.DisableNavigation();
		Navigator.SetSelected(EquippedListContainer);
		if (EquippedList.SelectedIndex < 0)
		{
			EquippedList.SetSelectedIndex(0);
		}
		else
		{
			EquippedList.GetSelectedItem().OnReceiveFocus();
		}
	}
	else
	{
		if(!bSkipAnimation)
			MC.FunctionVoid("openList");
		
		// lock selected item
		if (LoadoutItem != none)
			LoadoutItem.SetLocked(true);
		// disable list item selection on LockerList, enable it on EquippedList
		LockerListContainer.EnableMouseHit();
		EquippedListContainer.DisableMouseHit();

		LockerList.SetSelectedIndex(0, true);
		Navigator.RemoveControl(EquippedListContainer);
		Navigator.AddControl(LockerListContainer);
		EquippedList.DisableNavigation();
		LockerList.EnableNavigation();
		Navigator.SetSelected(LockerListContainer);
		LockerList.Navigator.SelectFirstAvailable();
	}
}

defaultproperties
{
	bUseNavHelp = false
}