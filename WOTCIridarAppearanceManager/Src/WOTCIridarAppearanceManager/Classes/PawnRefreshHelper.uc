class PawnRefreshHelper extends Object;

var UIArmory_Loadout_CharPool LoadoutScreen;

var private XComCharacterCustomization	CustomizationManager;
var private CharacterPoolManager_AM		PoolMgr;
var private XComPresentationLayerBase	PresBase;
var private UIPawnMgr					PawnMgr;
var private XComGameStateHistory		History;
var private X2ItemTemplateManager		ItemMgr;
var private XComGameState				TempGameState;

function InitHelper(optional XComCharacterCustomization	_CustomizationManager, optional CharacterPoolManager_AM _PoolMgr)
{
	if (_CustomizationManager != none)
	{
		CustomizationManager = _CustomizationManager;
	}
	else
	{
		CustomizationManager = `PRESBASE.GetCustomizeManager();
	}
	if (_PoolMgr != none)
	{
		PoolMgr = _PoolMgr;
	}
	else
	{
		PoolMgr = `CHARACTERPOOLMGRAM;
	}

	PresBase = `PRESBASE;
	PawnMgr = PresBase.GetUIPawnMgr();
	History = `XCOMHISTORY;
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	`AMLOG("Init complete");
}

function RefreshPawn(optional bool bForce)
{
	local Rotator								UseRotation;
	local Vector								SpawnPawnLocation;
	local PointInSpace							PlacementActor;
	local XComGameState_Unit					UnitState;
	local XComGameStateContext_ChangeContainer	TempContainer;

	UnitState = CustomizationManager.UpdatedUnitState;
	`AMLOG("Refreshing pawn for" @ UnitState.GetFullName());
	
	// # 1.Nuke existing pawn
	PawnMgr.ReleasePawn(PresBase, CustomizationManager.UnitRef.ObjectID, bForce);

	// --------------------------------------------------------------
	// # 2. Equip items on unit.

	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);

	// Equip items saved in CP loadout, if any.
	ApplyCharacterPoolLoadout(UnitState);

	// Give the unit the standard soldier class loadout. If some slots were already filled by CP loadout items, this will just fail to equip standard items there, as intended.
	UnitState.ApplyInventoryLoadout(TempGameState);

	//Add the state to the history so that the visualization functions can operate correctly
	History.AddGameStateToHistory(TempGameState);

	if (LoadoutScreen != none) 
	{
		LoadoutScreen.UpdateEquippedList();
	}

	CustomizationManager.PrimaryWeapon = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, TempGameState);
	CustomizationManager.SecondaryWeapon = UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, TempGameState);
	CustomizationManager.TertiaryWeapon = UnitState.GetItemInSlot(eInvSlot_TertiaryWeapon, TempGameState);

	`AMLOG("Currently equipped armor:" @ UnitState.GetItemInSlot(eInvSlot_Armor, TempGameState, true).GetMyTemplateName() @ "and torso:" @ UnitState.kAppearance.nmTorso);
	`AMLOG("Primary weapon:" @ CustomizationManager.PrimaryWeapon.GetMyTemplateName());

	// --------------------------------------------------------------
	// # 3. Find where we want to spawn the new pawn
	if (CustomizationManager.ActorPawn != none)
	{
		UseRotation = CustomizationManager.ActorPawn.Rotation;
	}
	else 
	{
		UseRotation.Yaw = -16384;
	}
	foreach PresBase.WorldInfo.AllActors(class'PointInSpace', PlacementActor)
	{
		if (PlacementActor != none && PlacementActor.Tag == 'UIPawnLocation_Armory')
			break;
	}
	SpawnPawnLocation = PlacementActor.Location;
	
	// # 4. Spawn the pawn.
	CustomizationManager.ActorPawn = PawnMgr.RequestPawnByState(PresBase, CustomizationManager.UpdatedUnitState, SpawnPawnLocation, UseRotation, OnPawnVisualsCreated);	
}

private function OnPawnVisualsCreated(XComUnitPawn inPawn)
{
	local XComLWTuple			OverrideTuple; //for issue #229
	local float					CustomScale; // issue #229
	local XComGameState_Unit	UnitState;
	
	CustomizationManager.ActorPawn = inPawn;
	CustomizationManager.ActorPawn.GotoState('CharacterCustomization');
	UnitState = CustomizationManager.UpdatedUnitState;

	`LOG(GetFuncName() @ " running for unit:" @ UnitState.GetFullName(),, 'IRITEST');

	//Create the visuals for the weapons, using the temp game state
	XComUnitPawn(CustomizationManager.ActorPawn).CreateVisualInventoryAttachments(PawnMgr, UnitState, TempGameState);

	//Destroy the temporary game state change that granted the unit a load out
	History.ObliterateGameStatesFromHistory(1);

	//Now clear the items from the unit so we don't accidentally save them
	UnitState.EmptyInventoryItems();

	UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizationManager.ActorPawn);
	
	//-------------------------------------------------------------
	// Not sure if events will work in CP.

	//start issue #229: instead of boolean check, always trigger event to check if we should use custom unit scale.
	CustomScale = UnitState.UseLargeArmoryScale() ? CustomizationManager.LargeUnitScale : 1.0f;
 	//set up a Tuple for return value
	OverrideTuple = new class'XComLWTuple';
	OverrideTuple.Id = 'OverrideCharCustomizationScale';
	OverrideTuple.Data.Add(3);
	OverrideTuple.Data[0].kind = XComLWTVBool;
	OverrideTuple.Data[0].b = false;
	OverrideTuple.Data[1].kind = XComLWTVFloat;
	OverrideTuple.Data[1].f = CustomScale;
	OverrideTuple.Data[2].kind = XComLWTVObject;
	OverrideTuple.Data[2].o = UnitState;
	`XEVENTMGR.TriggerEvent('OverrideCharCustomizationScale', OverrideTuple, UnitState, none);
	
	//if the unit should use the large armory scale by default, then either they'll use the default scale
	//or a custom one given by a mod according to their character template
	if(OverrideTuple.Data[0].b || UnitState.UseLargeArmoryScale()) 
	{
		CustomScale = OverrideTuple.Data[1].f;
		XComUnitPawn(CustomizationManager.ActorPawn).Mesh.SetScale(CustomScale);
	}
	//end issue #229
}

private function ApplyCharacterPoolLoadout(XComGameState_Unit UnitState)
{
	local array<CharacterPoolLoadoutStruct>		CharacterPoolLoadout;
	local CharacterPoolLoadoutStruct			LoadoutElement;
	local X2ItemTemplate						ItemTemplate;
	local XComGameState_Item					ItemState;
	local X2WeaponTemplate						WeaponTemplate;
	local array<int>							FailedToEquipItemIndices;
	local int									i;
	
	CharacterPoolLoadout = PoolMgr.GetCharacterPoolLoadout(UnitState);
	if (CharacterPoolLoadout.Length == 0) 
	{ 
		`AMLOG("No char pool loadout, exiting."); 
		return;
	}

	// -------------------------------------------------------------------------------------------------------
	// BEGING EQUIPPING THE LOADOUT

	foreach CharacterPoolLoadout(LoadoutElement, i)
	{
		`AMLOG("LoadoutElement:" @ LoadoutElement.TemplateName @ LoadoutElement.InventorySlot);

		ItemTemplate = ItemMgr.FindItemTemplate(LoadoutElement.TemplateName);
		if (ItemTemplate == none)
		{
			// TODO: Do this only if validation is turned on?
			FailedToEquipItemIndices.AddItem(i);
			continue;
		}		

		ItemState = ItemTemplate.CreateInstanceFromTemplate(TempGameState);
		if (UnitState.AddItemToInventory(ItemState, LoadoutElement.InventorySlot, TempGameState))
		{
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
		PoolMgr.SetCharacterPoolLoadout(UnitState, CharacterPoolLoadout);
	}
}
/*
function ApplyInventoryLoadout(XComGameState ModifyGameState)
{
	local X2ItemTemplateManager ItemTemplateManager;
	local InventoryLoadout Loadout;
	local InventoryLoadoutItem LoadoutItem;
	local bool bFoundLoadout;
	local X2EquipmentTemplate EquipmentTemplate;
	local X2WeaponTemplate WeaponTemplate;
	local XComGameState_Item NewItem;
	local name UseLoadoutName, RequiredLoadout;
	local X2SoldierClassTemplate SoldierClassTemplate;

	if (NonDefaultLoadout != '')      
	{
		//  If loadout is specified, always use that.
		UseLoadoutName = NonDefaultLoadout;
	}
	else
	{
		//  If loadout was not specified, use the character template's default loadout, or the squaddie loadout for the soldier class (if any).
		UseLoadoutName = GetMyTemplate().DefaultLoadout;
		SoldierClassTemplate = GetSoldierClassTemplate();
		if (SoldierClassTemplate != none && SoldierClassTemplate.SquaddieLoadout != '')
			UseLoadoutName = SoldierClassTemplate.SquaddieLoadout;
	}

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach ItemTemplateManager.Loadouts(Loadout)
	{
		if (Loadout.LoadoutName == UseLoadoutName)
		{
			bFoundLoadout = true;
			break;
		}
	}
	if (bFoundLoadout)
	{
		foreach Loadout.Items(LoadoutItem)
		{
			EquipmentTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate(LoadoutItem.Item));
			if (EquipmentTemplate != none)
			{
				NewItem = EquipmentTemplate.CreateInstanceFromTemplate(ModifyGameState);

				//Transfer settings that were configured in the character pool with respect to the weapon. Should only be applied here
				//where we are handing out generic weapons.
				if(EquipmentTemplate.InventorySlot == eInvSlot_PrimaryWeapon || EquipmentTemplate.InventorySlot == eInvSlot_SecondaryWeapon ||
					EquipmentTemplate.InventorySlot == eInvSlot_TertiaryWeapon)
				{
					WeaponTemplate = X2WeaponTemplate(NewItem.GetMyTemplate());
					if (WeaponTemplate != none && WeaponTemplate.bUseArmorAppearance)
					{
						NewItem.WeaponAppearance.iWeaponTint = kAppearance.iArmorTint;
					}
					else
					{
						NewItem.WeaponAppearance.iWeaponTint = kAppearance.iWeaponTint;
					}

					NewItem.WeaponAppearance.nmWeaponPattern = kAppearance.nmWeaponPattern;
				}

				AddItemToInventory(NewItem, EquipmentTemplate.InventorySlot, ModifyGameState);
			}
		}
	}
	//  Always apply the template's required loadout.
	RequiredLoadout = GetMyTemplate().RequiredLoadout;
	if (RequiredLoadout != '' && RequiredLoadout != UseLoadoutName && !HasLoadout(RequiredLoadout, ModifyGameState))
		ApplyInventoryLoadout(ModifyGameState, RequiredLoadout);

	// Give Kevlar armor if Unit's armor slot is empty
	if(IsSoldier() && GetItemInSlot(eInvSlot_Armor, ModifyGameState) == none)
	{
		EquipmentTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate('KevlarArmor'));
		NewItem = EquipmentTemplate.CreateInstanceFromTemplate(ModifyGameState);
		AddItemToInventory(NewItem, eInvSlot_Armor, ModifyGameState);
	}


}*/

/*
// Store appearance for the previously equipped armor before equipping new one.
if (LoadoutElement.InventorySlot == eInvSlot_Armor && PreviousArmorName != '' && PreviousArmorName != LoadoutElement.TemplateName)
{
	`AMLOG("Storing appearance for previous armor:" @ PreviousArmorName @ "Old torso:" @ UnitState.kAppearance.nmTorso);
	UnitState.StoreAppearance(UnitState.kAppearance.iGender, PreviousArmorName);
}

if (LoadoutElement.InventorySlot == eInvSlot_Armor)
{
	if (UnitState.HasStoredAppearance(UnitState.kAppearance.iGender, LoadoutElement.TemplateName))
	{
		UnitState.GetStoredAppearance(StoredAppearance, UnitState.kAppearance.iGender, LoadoutElement.TemplateName);
		`AMLOG("Attempting to equip new armor. It has stored appeareance with torso:" @ StoredAppearance.nmTorso);
	}
	else
	{
		`AMLOG("Attempting to equip new armor. It does not have stored appeareance" );
	}
}*/

/*
private function ApplyCharacterPoolLoadout(XComGameState_Unit UnitState, XComGameState TempGameState)
{
	local array<CharacterPoolLoadoutStruct>		CharacterPoolLoadout;
	local CharacterPoolLoadoutStruct			LoadoutElement;
	local X2ItemTemplate						ItemTemplate;
	local XComGameState_Item					EquippedItem;
	local XComGameState_Item					ItemState;
	local array<XComGameState_Item>				ItemStates;
	local X2WeaponTemplate						WeaponTemplate;
	local array<int>							FailedToEquipItemIndices;
	
	local int									iMaxNumItems;
	local int									i;
	
	CharacterPoolLoadout = PoolMgr.GetCharacterPoolLoadout(UnitState);
	if (CharacterPoolLoadout.Length == 0) 
	{ 
		`AMLOG("No char pool loadout, exiting."); 
		return;
	}

	// -------------------------------------------------------------------------------------------------------
	// BEGING EQUIPPING THE LOADOUT

	foreach CharacterPoolLoadout(LoadoutElement, i)
	{
		`AMLOG("LoadoutElement:" @ LoadoutElement.TemplateName @ LoadoutElement.InventorySlot);

		// ## 1. First see if we can at least get the template for the item we want to equip.
		ItemTemplate = ItemMgr.FindItemTemplate(LoadoutElement.TemplateName);
		if (ItemTemplate == none)
		{
			// TODO: Do this only if validation is turned on?
			FailedToEquipItemIndices.AddItem(i);
			continue;
		}		

		// ## 2. Unequip existing items in the slot we intend to use, if necessary.
		if (class'CHItemSlot'.static.SlotIsMultiItem(LoadoutElement.InventorySlot))
		{
			// Get max number of items that can fit into the slot.
			iMaxNumItems = class'CHItemSlot'.static.SlotGetMaxItemCount(LoadoutElement.InventorySlot, UnitState);
			ItemStates = UnitState.GetAllItemsInSlot(LoadoutElement.InventorySlot, TempGameState, true, true);

			// If the slot is already at capacity, we unequip the first item that's not in the CP loadout.
			if (ItemStates.Length >= iMaxNumItems)
			{
				foreach ItemStates(EquippedItem)
				{
					if (!IsItemInCharacterPoolLoadout(CharacterPoolLoadout, EquippedItem.GetMyTemplateName(), EquippedItem.InventorySlot))
					{
						if (UnitState.RemoveItemFromInventory(EquippedItem, TempGameState))
						{
							TempGameState.PurgeGameStateForObjectID(EquippedItem.ObjectID);
							break;
						}
						else
						{
							continue; // Go to next multi slot item.
						}
					}
				}
			}
		}
		else 
		{
			EquippedItem = UnitState.GetItemInSlot(LoadoutElement.InventorySlot, TempGameState, true);
			if (EquippedItem != none)
			{
				if (UnitState.RemoveItemFromInventory(EquippedItem, TempGameState))
				{
					TempGameState.PurgeGameStateForObjectID(EquippedItem.ObjectID);
				}
				else
				{
					`AMLOG("Failed to remove existing item:" @ EquippedItem.GetMyTemplateName() @ "from slot:" @ LoadoutElement.InventorySlot);
					FailedToEquipItemIndices.AddItem(i);
					continue; // Go to next CP Loadout item.
				}
			}
		}
		
		// ## 3. Attempt to equip the item.
		ItemState = ItemTemplate.CreateInstanceFromTemplate(TempGameState);
		if (UnitState.AddItemToInventory(ItemState, LoadoutElement.InventorySlot, TempGameState))
		{
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
		PoolMgr.SetCharacterPoolLoadout(UnitState, CharacterPoolLoadout);
	}
}

private function bool IsItemInCharacterPoolLoadout(const out array<CharacterPoolLoadoutStruct> CharacterPoolLoadout, const name TemplateName, const EInventorySlot InventorySlot)
{
	local CharacterPoolLoadoutStruct LoadoutElement;

	foreach CharacterPoolLoadout(LoadoutElement)
	{
		if (LoadoutElement.TemplateName == TemplateName && LoadoutElement.InventorySlot == InventorySlot)
		{
			return true;
		}
	}
	return false;
}*/