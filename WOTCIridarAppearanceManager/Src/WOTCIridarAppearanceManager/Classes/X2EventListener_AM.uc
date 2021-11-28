class X2EventListener_AM extends X2EventListener;

var private name RefreshPawnEventName;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ListenerTemplate_Tactical());
	Templates.AddItem(Create_ListenerTemplate_Strategy());
	Templates.AddItem(Create_ListenerTemplate_CampaignStart());
	
	return Templates;
}
// ItemAddedToSlot listeners are responsible for two things:
// 1. CP Appearance Store support.
// 2. CP Uniforms support.
// If a unit equips an armor they don't have stored appearance for, the mod will check if this unit exists in the character pool, and attempt to load CP unit's stored appearance for that armor.
// If that fails, the mod will look for an appropriate uniform for this soldier.

static private function CHEventListenerTemplate Create_ListenerTemplate_Strategy()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_AppearanceManager_Strategy');

	Template.RegisterInStrategy = true;

	Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot, ELD_Immediate, 50);
	Template.AddCHEvent('UnitRankUp', OnUnitRankUp, ELD_Immediate, 50);
	Template.AddCHEvent('OnCreateCinematicPawn', OnCreateCinematicPawn, ELD_Immediate, 10);
	Template.AddCHEvent(default.RefreshPawnEventName, OnRefreshPawnEvent, ELD_OnStateSubmitted, 50);

	return Template;
}
static private function CHEventListenerTemplate Create_ListenerTemplate_Tactical()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_AppearanceManager_StrategyAndTactical');

	Template.RegisterInTactical = true; // Units shouldn't be able to swap armor mid-mission, but you never know

	Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot, ELD_Immediate, 50);
	Template.AddCHEvent('UnitRankUp', OnUnitRankUp, ELD_Immediate, 50);
	Template.AddCHEvent('PostAliensSpawned', OnPostAliensSpawned, ELD_Immediate, 50);
	Template.AddCHEvent('OnCreateCinematicPawn', OnCreateCinematicPawn, ELD_Immediate, 10);
	Template.AddCHEvent(default.RefreshPawnEventName, OnRefreshPawnEvent, ELD_OnStateSubmitted, 50);

	return Template;
}

static private function CHEventListenerTemplate Create_ListenerTemplate_CampaignStart()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_AppearanceManager_CampaignStart');

	// Needed so that soldier generated at the campaign start properly get their custom Kevlar appearance from CP 
	// even if the CP unit didn't have Kevlar equipped when CP was saved.
	Template.RegisterInCampaignStart = true; 

	Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot_CampaignStart, ELD_Immediate, 50);
	Template.AddCHEvent('UnitRankUp', OnUnitRankUp, ELD_Immediate, 50);

	return Template;
}

static private function EventListenerReturn OnItemAddedToSlot(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;
	local XComGameState_Unit UnitState;

	ItemState = XComGameState_Item(EventData);
	if (ItemState == none || X2ArmorTemplate(ItemState.GetMyTemplate()) == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState == none)
		return ELR_NoInterrupt;

	`AMLOG(UnitState.GetFullName() @ "equipped armor:" @ ItemState.GetMyTemplateName());

	if (UnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ItemState.GetMyTemplateName()))
	{
		`AMLOG(UnitState.GetFullName() @ "already has stored appearance for" @ ItemState.GetMyTemplateName() $ ", exiting.");
		return ELR_NoInterrupt;
	}

	MaybeApplyUniformAppearance(UnitState, ItemState.GetMyTemplateName(), NewGameState);

	return ELR_NoInterrupt;
}

// Same as previous listener, we just skip the HasStoredAppearance() check.
static private function EventListenerReturn OnItemAddedToSlot_CampaignStart(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;
	local XComGameState_Unit UnitState;

	ItemState = XComGameState_Item(EventData);
	if (ItemState == none || X2ArmorTemplate(ItemState.GetMyTemplate()) == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState == none)
		return ELR_NoInterrupt;
	
	`AMLOG(UnitState.GetFullName() @ "equipped armor:" @ ItemState.GetMyTemplateName());

	// Even the Campaign Start listener is too late - randomly generated units will already have stored appearance for Kevlar Armor, so we're skipping that check.
	//if (UnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ItemState.GetMyTemplateName()))
	//{
	//	`AMLOG(UnitState.GetFullName() @ "already has stored appearance for" @ ItemState.GetMyTemplateName() $ ", exiting.");
	//	return ELR_NoInterrupt;
	//}

	MaybeApplyUniformAppearance(UnitState, ItemState.GetMyTemplateName(), NewGameState);

	return ELR_NoInterrupt;
}

static private function MaybeApplyUniformAppearance(XComGameState_Unit UnitState, name ArmorTemplateName, XComGameState NewGameState, optional bool bClassUniformOnly = false)
{
	local CharacterPoolManager_AM		CharacterPool;
	local TAppearance					NewAppearance;
	local XComGameState_Item			ItemState;
	local XComGameState_Item			NewItemState;
	local array<XComGameState_Item>		ItemStates;
	local X2WeaponTemplate				WeaponTemplate;

	local name							LocalArmorTemplateName;
	local EGender						Gender;
	local int							i;

	CharacterPool = `CHARACTERPOOLMGRAM;
	if (CharacterPool == none || !CharacterPool.ShouldAutoManageUniform(UnitState))
		return;

	// Normally we apply uniforms to soldiers only when they equip an armor they *don't* have stored appearance for.
	// So applying uniforms to stored appearance sounds absurd.
	// But 'bClassUniformOnly' is true only when this function runs for the soldier on their promotion to squaddie,
	// at which point we might want to replace their stored appearance with class-specific uniforms.
	// For currently equipped armor this is handled automatically, but that currently equipped armor my turn out to be Plated or Powered,
	// so going through stored appearances allows us to apply uniform changes to armor appearance for previous tiers.
	if (bClassUniformOnly)
	{
		for (i = 0; i < UnitState.AppearanceStore.Length; i++)
		{
			LocalArmorTemplateName = name(Left(UnitState.AppearanceStore[i].GenderArmorTemplate, Len(UnitState.AppearanceStore[i].GenderArmorTemplate) - 1));
			if (LocalArmorTemplateName == '')
				continue;

			Gender = EGender(int(Right(UnitState.AppearanceStore[i].GenderArmorTemplate, 1)));

			NewAppearance = UnitState.AppearanceStore[i].Appearance;
			if (CharacterPool.GetUniformAppearanceForUnit(NewAppearance, UnitState, LocalArmorTemplateName, true /*bClassUniformOnly*/))
			{
				`AMLOG(UnitState.GetFullName() @ "saving uniform appearance for stored apperance for:" @ LocalArmorTemplateName @ GetEnum(enum'EGender', Gender));

				UnitState.AppearanceStore[i].Appearance = NewAppearance;
			}
		}
	}

	NewAppearance = UnitState.kAppearance;
	if (CharacterPool.GetUniformAppearanceForUnit(NewAppearance, UnitState, ArmorTemplateName, bClassUniformOnly))
	{
		`AMLOG(UnitState.GetFullName() @ "aplying uniform appearance for:" @ ArmorTemplateName);

		UnitState.SetTAppearance(NewAppearance);
		UnitState.StoreAppearance(, ArmorTemplateName);

		// Weapon camo needs to be updated separately.
		ItemStates = UnitState.GetAllInventoryItems(NewGameState, true);
		foreach ItemStates(ItemState)
		{
			NewItemState = XComGameState_Item(NewGameState.GetGameStateForObjectID(ItemState.ObjectID));
			if (NewItemState == none)
				NewItemState = XComGameState_Item(NewGameState.ModifyStateObject(ItemState.Class, ItemState.ObjectID));

			WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());
			if (WeaponTemplate == none) continue;

			if (WeaponTemplate.bUseArmorAppearance)
			{
				NewItemState.WeaponAppearance.iWeaponTint = NewAppearance.iArmorTint;
			}
			else
			{
				NewItemState.WeaponAppearance.iWeaponTint = NewAppearance.iWeaponTint;
			}
		
			NewItemState.WeaponAppearance.nmWeaponPattern = NewAppearance.nmWeaponPattern;
		}

		// At this point we want to refresh the soldier pawn so that uniform takes effect,
		// but doing so _right meow_ wouldn't work, because at this point Game State with our state changes
		// has not been submitted yet, so we delay this until the game state is submitted.
		`XEVENTMGR.TriggerEvent(default.RefreshPawnEventName, UnitState, UnitState, NewGameState);
	}
	else `AMLOG(UnitState.GetFullName() @ "has no uniform for:" @ ArmorTemplateName);
}

static private function EventListenerReturn OnUnitRankUp(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState == none || UnitState.GetRank() > 1)
		return ELR_NoInterrupt;

	ItemState = UnitState.GetItemInSlot(eInvSlot_Armor, NewGameState);
	if (ItemState == none)
		return ELR_NoInterrupt;

	`AMLOG(UnitState.GetFullName() @ "promoted to rank:" @ UnitState.GetRank() @ ", and has armor equipped:" @ ItemState.GetMyTemplateName());

	MaybeApplyUniformAppearance(UnitState, ItemState.GetMyTemplateName(), NewGameState, true);

	return ELR_NoInterrupt;
}

static private function EventListenerReturn OnPostAliensSpawned(Object EventData, Object EventSource, XComGameState StartState, Name Event, Object CallbackData)
{
	local XComGameState_Unit		UnitState;
	local CharacterPoolManager_AM	CharacterPool;
	local TAppearance				NewAppearance;

	CharacterPool = `CHARACTERPOOLMGRAM;
	if (CharacterPool == none)
		return ELR_NoInterrupt;

	foreach StartState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		//if (UnitState.IsSoldier())
		//	continue;

		`AMLOG(UnitState.GetFullName() @ UnitState.GetMyTemplateGroupName());
			
		NewAppearance = UnitState.kAppearance;
		if (CharacterPool.GetUniformAppearanceForNonSoldier(NewAppearance, UnitState))
		{
			`AMLOG("Aplying uniform appearance");

			UnitState.SetTAppearance(NewAppearance);
			UnitState.StoreAppearance();
		}
		else `AMLOG("Has no uniform");
	}
	return ELR_NoInterrupt;
}


static private function EventListenerReturn OnCreateCinematicPawn(Object EventData, Object EventSource, XComGameState StartState, Name Event, Object CallbackData)
{
	local XComGameState_Unit		UnitState;
	local XComHumanPawn				HumanPawn;
	local CharacterPoolManager_AM	CharacterPool;
	local TAppearance				NewAppearance;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none || UnitState.IsSoldier()) // Used only for non-soldiers.
		return ELR_NoInterrupt;

	HumanPawn = XComHumanPawn(EventData);
	if (HumanPawn == none)
		return ELR_NoInterrupt;

	CharacterPool = `CHARACTERPOOLMGRAM;
	if (CharacterPool == none)
		return ELR_NoInterrupt;
			
	NewAppearance = HumanPawn.m_kAppearance;
	`AMLOG(UnitState.GetFullName() @ UnitState.GetMyTemplateGroupName() @ "Old torso:" @ NewAppearance.nmTorso);

	if (CharacterPool.GetUniformAppearanceForNonSoldier(NewAppearance, UnitState))
	{
		//if (NewAppearance.nmTorso != '')
		//{	
		//	  HumanPawn.Mesh = none; // Crashes the gume
		//}
		`AMLOG("Aplying uniform appearance.");
		`AMLOG(`ShowVar(NewAppearance.nmTorso));
		`AMLOG(`ShowVar(NewAppearance.nmArms));
		`AMLOG(`ShowVar(NewAppearance.nmLeftArm));
		`AMLOG(`ShowVar(NewAppearance.nmRightArm));
		`AMLOG(`ShowVar(NewAppearance.nmLegs));
		//HumanPawn.bShouldUseUnderlay = false;
		UnitState.SetTAppearance(NewAppearance);
		HumanPawn.SetAppearance(NewAppearance, false);
		class'Help'.static.RequestFullPawnContentForClerk(UnitState, HumanPawn, NewAppearance);
	}
	else `AMLOG("Has no uniform");
	
	return ELR_NoInterrupt;
}


static private function EventListenerReturn OnRefreshPawnEvent(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit	UnitState;
	local UIArmory				ArmoryScreen;
	local Rotator				CachedSoldierRotation;
	local UIScreenStack			ScreenStack;
	local int i;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none)
		return ELR_NoInterrupt;

	ScreenStack = `SCREENSTACK;
	if (ScreenStack == none)
		return ELR_NoInterrupt;

	for (i = ScreenStack.Screens.Length - 1; i >= 0; --i)
	{
		ArmoryScreen = UIArmory(ScreenStack.Screens[i]);
		if (ArmoryScreen != none && ArmoryScreen.ActorPawn != none && UnitState.ObjectID == ArmoryScreen.UnitReference.ObjectID)
		{
			CachedSoldierRotation = ArmoryScreen.ActorPawn.Rotation;
			ArmoryScreen.ReleasePawn(true);
			ArmoryScreen.CreateSoldierPawn(CachedSoldierRotation);
		}
	}
	
	return ELR_NoInterrupt;
}


defaultproperties
{
	RefreshPawnEventName = "IRI_AM_RefreshPawnEvent";
}