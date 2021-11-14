class UIArmory_LoadoutItem_CharPool extends UIArmory_LoadoutItem;

var private XComGameState_Item ItemState;

// Disable some stuff to remove calls to XCOMHQ that cause redscreens.
simulated function UIArmory_LoadoutItem InitLoadoutItem(XComGameState_Item Item, EInventorySlot InitEquipmentSlot, optional bool InitSlot, optional string InitDisabledReason)
{
	InitPanel();
	
	// Keep the reference to the Item State.
	ItemState = Item;
	if (ItemState != none)
	{
		ItemRef = ItemState.GetReference();
		ItemTemplate = ItemState.GetMyTemplate();
	}

	EquipmentSlot = InitEquipmentSlot;

	if(InitSlot)
	{
		bLoadoutSlot = true;
		// Issue #118
		//SetSlotType(class'UIArmory_Loadout'.default.m_strInventoryLabels[int(InitEquipmentSlot)]);
		SetSlotType(class'CHItemSlot'.static.SlotGetName(InitEquipmentSlot));
	}
	else if(Movie.Stack.GetLastInstanceOf(class'UIMPShell_Lobby') != none || Movie.Stack.GetLastInstanceOf(class'UIMPShell_MainMenu') != none)
	{
		SetSlotType(ItemTemplate.MPCost @ class'UIMPShell_SquadLoadoutList'.default.m_strPointTotalPostfix);
	}
	else
	{
		//if (Item != None)
		//{
		//	if (ItemTemplate.bInfiniteItem && !Item.HasBeenModified())
		//	{
				SetInfinite(true);
		//	}
		//	else
		//	{
		//		SetCount(class'UIUtilities_Strategy'.static.GetXComHQ().GetNumItemInInventory(ItemTemplate.DataName));
		//	}
		//}
	}

	if (InitDisabledReason != "")
	{
		SetDisabled(true, class'UIUtilities_Text'.static.GetColoredText(InitDisabledReason, eUIState_Bad));
	}

	/// HL-Docs: ref:Bugfixes; issue:701
	/// Allows armory UI to highlight the item the player needs to build during the tutorial even if it's not the item with the exact template name `'Medikit'`
	//if (ItemTemplate != none && ItemTemplate.DataName == class'UIInventory_BuildItems'.default.TutorialBuildItem // Issue #701 from 'Medikit'
	//	&& class'XComGameState_HeadquartersXCom'.static.NeedsToEquipMedikitTutorial())
	//{
	//	// spawn the attention icon externally so it draws on top of the button and image 
	//	Spawn(class'UIPanel', self).InitPanel('attentionIconMC', class'UIUtilities_Controls'.const.MC_AttentionIcon)
	//		.SetPosition(2, 4)
	//		.SetSize(70, 70);
	//
	//	MC.FunctionVoid("showAttentionIcon");
	//}

	// Create the Drop Item button
	if(bLoadoutSlot && !IsDisabled)
	{
		// add a custom text box since the flash component reports back with from the bg subcomponent
		TooltipID = Movie.Pres.m_kTooltipMgr.AddNewTooltipTextBox(m_strDropItem, 0, 0, MCPath $ ".DropItemButton.bg");
	}

	PopulateData(ItemState);

	return self;
}

function OnDropItemClicked(UIButton kButton)
{
	local UIArmory_Loadout_CharPool LoadoutScreen;

	LoadoutScreen = UIArmory_Loadout_CharPool(Screen);
	
	LoadoutScreen.CharPoolMgr.RemoveItemFromCharacterPoolLoadout(LoadoutScreen.CustomizationManager.UpdatedUnitState, ItemState.InventorySlot, ItemState.GetMyTemplateName());
	ItemState = none;
	LoadoutScreen.UpdateData(true);
}
