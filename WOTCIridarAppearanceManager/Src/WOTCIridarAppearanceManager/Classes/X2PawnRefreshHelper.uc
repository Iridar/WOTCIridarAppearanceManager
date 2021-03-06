class X2PawnRefreshHelper extends Object;

var UIArmory_Loadout_CharPool	LoadoutScreen;
var UIAppearanceStore			AppearanceStoreScreen;
var UIManageAppearance			ManageAppearanceScreen;
var UICustomize					CustomizeScreen;

var private XComCharacterCustomization	CustomizationManager;
var private CharacterPoolManager_AM		PoolMgr;
var private XComPresentationLayerBase	PresBase;
var private UIPawnMgr					PawnMgr;
var private XComGameStateHistory		History;
var private X2ItemTemplateManager		ItemMgr;
var private XComGameState				TempGameState;

static final function RefreshPawn_Static(optional bool bForce, optional XComCharacterCustomization _CustomizationManager, optional CharacterPoolManager_AM _PoolMgr, optional UICustomize _CustomizeScreen)
{
	local X2PawnRefreshHelper PawnRefreshHelper;
	PawnRefreshHelper = new class'X2PawnRefreshHelper';
	PawnRefreshHelper.CustomizeScreen = _CustomizeScreen;
	PawnRefreshHelper.InitHelper(_CustomizationManager, _PoolMgr);
	PawnRefreshHelper.RefreshPawn(bForce);
}

final function InitHelper(optional XComCharacterCustomization _CustomizationManager, optional CharacterPoolManager_AM _PoolMgr)
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

function array<CharacterPoolLoadoutStruct> RefreshPawn(optional bool bForce)
{
	local Rotator								UseRotation;
	local Vector								SpawnPawnLocation;
	local PointInSpace							PlacementActor;
	local XComGameState_Unit					UnitState;
	local XComGameStateContext_ChangeContainer	TempContainer;
	local array<CharacterPoolLoadoutStruct>		ReturnArray;

	UnitState = CustomizationManager.UpdatedUnitState;
	`AMLOG("Refreshing pawn for" @ UnitState.GetFullName());

	// # 0. Find where we want to spawn the new pawn
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

	// # 1.Nuke existing pawn
	PawnMgr.ReleasePawn(PresBase, CustomizationManager.UnitRef.ObjectID, bForce);

	// --------------------------------------------------------------
	// # 2. Equip items on unit.
	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);

	// Equip items saved in CP loadout, if any.
	ReturnArray = ApplyCharacterPoolLoadout(UnitState); // Returns loadout actually equipped on the soldier, used for validation by calling code to make sure the item they wanted to equip was equipped.

	// Give the unit the standard soldier class loadout. If some slots were already filled by CP loadout items, this will just fail to equip standard items there, as intended.
	UnitState.ApplyInventoryLoadout(TempGameState);

	// Wanted to create an HQ state here to prevent million of log warnings caused by ValidateLoadout(), but for some reason that prevents faction soldier helmets from being used in character pool.
	// Doesn't make sense, considering the game state is obliterated afterwards, but it is what it is.
	//TempGameState.CreateNewStateObject(class'XComGameState_HeadquartersXCom');

	// Validate loadout to do stuff like granting a free heavy weapon to the unit when they equip exo suit.
	// Causes three billion redscreens, but needs to be done.
	UnitState.ValidateLoadout(TempGameState); 

	// Didn't expect to need this here. Shouldn't weapon tints and stuff be already based on unit's appearance?
	ApplyChangesToUnitWeapons(UnitState, UnitState.kAppearance);

	//Add the state to the history so that the visualization functions can operate correctly
	History.AddGameStateToHistory(TempGameState);

	if (LoadoutScreen != none) 
	{
		LoadoutScreen.UpdateEquippedList();
		//LoadoutScreen.UpdateData();
		LoadoutScreen.Header.PopulateData(UnitState);
	}

	CustomizationManager.PrimaryWeapon = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, TempGameState);
	CustomizationManager.SecondaryWeapon = UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, TempGameState);
	CustomizationManager.TertiaryWeapon = UnitState.GetItemInSlot(eInvSlot_TertiaryWeapon, TempGameState);

	`AMLOG("Currently equipped armor:" @ UnitState.GetItemInSlot(eInvSlot_Armor, TempGameState, true).GetMyTemplateName() @ "and torso:" @ UnitState.kAppearance.nmTorso @ "Primary weapon:" @ CustomizationManager.PrimaryWeapon.GetMyTemplateName());
	
	// # 3. Spawn the pawn.
	CustomizationManager.ActorPawn = PawnMgr.RequestPawnByState(PresBase, CustomizationManager.UpdatedUnitState, SpawnPawnLocation, UseRotation, OnPawnVisualsCreated);	

	return ReturnArray;
}

private function OnPawnVisualsCreated(XComUnitPawn inPawn)
{
	local XComLWTuple			OverrideTuple; //for issue #229
	local float					CustomScale; // issue #229
	local XComGameState_Unit	UnitState;
	
	CustomizationManager.ActorPawn = inPawn;
	CustomizationManager.ActorPawn.GotoState('CharacterCustomization');
	UnitState = CustomizationManager.UpdatedUnitState;

	if (LoadoutScreen != none) 
	{
		LoadoutScreen.ActorPawn = inPawn;
	}
	else if (ManageAppearanceScreen != none)
	{
		ManageAppearanceScreen.ArmoryPawn = XComHumanPawn(inPawn);
		ManageAppearanceScreen.UpdatePawnAttitudeAnimation(); // Play HQ Idle Anim
	}
	else if (AppearanceStoreScreen != none)
	{
		AppearanceStoreScreen.ArmoryPawn = XComHumanPawn(inPawn);
		AppearanceStoreScreen.UpdateData(); // Play HQ Idle Anim
	}
	else if (CustomizeScreen != none)
	{
		CustomizeScreen.UpdateData(); // Play HQ Idle Anim
	}

	`AMLOG("Running for unit:" @ UnitState.GetFullName() @ "Pawn state:" @ CustomizationManager.ActorPawn.GetStateName());

	//Create the visuals for the weapons, using the temp game state
	XComUnitPawn(CustomizationManager.ActorPawn).CreateVisualInventoryAttachments(PawnMgr, UnitState, TempGameState);

	`AMLOG("Created visual attachments.");

	//Destroy the temporary game state change that granted the unit a load out
	//Hack! Nuking gamestate is not guaranteed. However, this function is only ever called in CP, where History is more or less irrelevant.
	History.ObliterateGameStatesFromHistory(1);

	`AMLOG("Obliterated Game State.");

	//Now clear the items from the unit so we don't accidentally save them
	UnitState.EmptyInventoryItems();

	`AMLOG("Cleared out inventory.");

	if (CustomizeScreen != none)
	{
		UIMouseGuard_RotatePawn(CustomizeScreen.MouseGuardInst).SetActorPawn(CustomizationManager.ActorPawn);
		`AMLOG("Assigned pawn to mouse guard.");
	}

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

	`AMLOG("Triggered 'OverrideCharCustomizationScale' event.");
	
	//if the unit should use the large armory scale by default, then either they'll use the default scale
	//or a custom one given by a mod according to their character template
	if(OverrideTuple.Data[0].b || UnitState.UseLargeArmoryScale()) 
	{
		CustomScale = OverrideTuple.Data[1].f;
		XComUnitPawn(CustomizationManager.ActorPawn).Mesh.SetScale(CustomScale);
	}
	`AMLOG("Set custom scale:" @ CustomScale);
	//end issue #229
}

private function array<CharacterPoolLoadoutStruct> ApplyCharacterPoolLoadout(XComGameState_Unit UnitState)
{
	local array<CharacterPoolLoadoutStruct>		CharacterPoolLoadout;
	local CharacterPoolLoadoutStruct			LoadoutElement;
	local X2ItemTemplate						ItemTemplate;
	local XComGameState_Item					ItemState;
	local array<int>							FailedToEquipItemIndices;
	local int									i;
	
	CharacterPoolLoadout = PoolMgr.GetCharacterPoolLoadout(UnitState);
	if (CharacterPoolLoadout.Length == 0) 
	{ 
		`AMLOG("No char pool loadout, exiting."); 
		return CharacterPoolLoadout;
	}

	// -------------------------------------------------------------------------------------------------------
	// BEGIN EQUIPPING THE LOADOUT

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

	return CharacterPoolLoadout;
}


function array<CharacterPoolLoadoutStruct> RefreshPawn_UseAppearance(const out TAppearance UseAppearance, optional bool bForce)
{
	local Rotator								UseRotation;
	local Vector								SpawnPawnLocation;
	local PointInSpace							PlacementActor;
	local XComGameState_Unit					UnitState;
	local XComGameStateContext_ChangeContainer	TempContainer;
	local array<CharacterPoolLoadoutStruct>		ReturnArray;

	UnitState = CustomizationManager.UpdatedUnitState;
	`AMLOG("Refreshing pawn for" @ UnitState.GetFullName());

	// # 0. Find where we want to spawn the new pawn
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

	// # 1.Nuke existing pawn
	PawnMgr.ReleasePawn(PresBase, CustomizationManager.UnitRef.ObjectID, bForce);

	// --------------------------------------------------------------
	// # 2. Equip items on unit.
	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);

	// Equip items saved in CP loadout, if any.
	ReturnArray = ApplyCharacterPoolLoadout(UnitState); // Returns loadout actually equipped on the soldier, used for validation by calling code to make sure the item they wanted to equip was equipped.

	// Give the unit the standard soldier class loadout. If some slots were already filled by CP loadout items, this will just fail to equip standard items there, as intended.
	UnitState.ApplyInventoryLoadout(TempGameState);

	//TempGameState.CreateNewStateObject(class'XComGameState_HeadquartersXCom');

	// Validate loadout to do stuff like granting a free heavy weapon to the unit when they equip exo suit.
	// Causes three billion redscreens, but needs to be done.
	UnitState.ValidateLoadout(TempGameState); 

	// Apply Tint and Pattern to whatever weapons we end up having equipped.
	ApplyChangesToUnitWeapons(UnitState, UseAppearance);

	// Set appearance after equipping all items, cuz equipping armor would change it.
	UnitState.SetTAppearance(UseAppearance);

	//Add the state to the history so that the visualization functions can operate correctly
	History.AddGameStateToHistory(TempGameState);

	if (LoadoutScreen != none) 
	{
		LoadoutScreen.UpdateEquippedList();
		//LoadoutScreen.UpdateData();
		LoadoutScreen.Header.PopulateData(UnitState);
	}

	CustomizationManager.PrimaryWeapon = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, TempGameState);
	CustomizationManager.SecondaryWeapon = UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, TempGameState);
	CustomizationManager.TertiaryWeapon = UnitState.GetItemInSlot(eInvSlot_TertiaryWeapon, TempGameState);

	`AMLOG("Currently equipped armor:" @ UnitState.GetItemInSlot(eInvSlot_Armor, TempGameState, true).GetMyTemplateName() @ "and torso:" @ UnitState.kAppearance.nmTorso @ "Primary weapon:" @ CustomizationManager.PrimaryWeapon.GetMyTemplateName());
	
	// # 3. Spawn the pawn.
	CustomizationManager.ActorPawn = PawnMgr.RequestPawnByState(PresBase, CustomizationManager.UpdatedUnitState, SpawnPawnLocation, UseRotation, OnPawnVisualsCreated);	

	return ReturnArray;
}

private function ApplyChangesToUnitWeapons(XComGameState_Unit UnitState, const TAppearance NewAppearance)
{
	local XComGameState_Item		InventoryItem;
	local array<XComGameState_Item> InventoryItems;
	local X2WeaponTemplate			WeaponTemplate;

	InventoryItems = UnitState.GetAllInventoryItems(TempGameState, true);
	foreach InventoryItems(InventoryItem)
	{
		WeaponTemplate = X2WeaponTemplate(InventoryItem.GetMyTemplate());
		if (WeaponTemplate == none)
			continue;

		`AMLOG(WeaponTemplate.DataName @ InventoryItem.InventorySlot @ InventoryItem.ObjectID);
		if (WeaponTemplate.bUseArmorAppearance)
		{
			InventoryItem.WeaponAppearance.iWeaponTint = NewAppearance.iArmorTint;
		}
		else
		{
			InventoryItem.WeaponAppearance.iWeaponTint = NewAppearance.iWeaponTint;
		}
		InventoryItem.WeaponAppearance.nmWeaponPattern = NewAppearance.nmWeaponPattern;
	}
}