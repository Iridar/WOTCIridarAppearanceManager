class X2EventListener_AM extends X2EventListener;

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

static function CHEventListenerTemplate Create_ListenerTemplate_Strategy()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_AppearanceManager_Strategy');

	Template.RegisterInStrategy = true;

	Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot, ELD_Immediate, 50);
	Template.AddCHEvent('UnitRankUp', OnUnitRankUp, ELD_Immediate, 50);

	return Template;
}
static function CHEventListenerTemplate Create_ListenerTemplate_Tactical()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_AppearanceManager_StrategyAndTactical');

	Template.RegisterInTactical = true; // Units shouldn't be able to swap armor mid-mission, but you never know

	Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot, ELD_Immediate, 50);
	Template.AddCHEvent('UnitRankUp', OnUnitRankUp, ELD_Immediate, 50);
	Template.AddCHEvent('PostAliensSpawned', OnPostAliensSpawned, ELD_Immediate, 50);

	return Template;
}

static function CHEventListenerTemplate Create_ListenerTemplate_CampaignStart()
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

static function EventListenerReturn OnItemAddedToSlot(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
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

	MaybeApplyUniformAppearance(UnitState, ItemState.GetMyTemplateName());

	return ELR_NoInterrupt;
}

// Same as previous listener, we just skip the HasStoredAppearance() check.
static function EventListenerReturn OnItemAddedToSlot_CampaignStart(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
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

	// Even the Campaign Start listener is too late - units already have stored appearance for Kevlar Armor.
	// However, we can allow ourselves to ignore this at campaign start. 
	// If the unit was randomly generated, then we want to replace their appearance with a uniform anyway.
	// If the unit is present in CP, then we'll just import their appearance on top of them again anyway, and no actual changes will happen.

	MaybeApplyUniformAppearance(UnitState, ItemState.GetMyTemplateName());

	return ELR_NoInterrupt;
}

static private function MaybeApplyUniformAppearance(XComGameState_Unit UnitState, name ArmorTemplateName, optional bool bClassUniformOnly = false)
{
	local CharacterPoolManager_AM	CharacterPool;
	local TAppearance				NewAppearance;
	
	CharacterPool = `CHARACTERPOOLMGRAM;
	if (CharacterPool == none || !CharacterPool.ShouldAutoManageUniform(UnitState))
		return;

	NewAppearance = UnitState.kAppearance;
	if (CharacterPool.GetUniformAppearanceForUnit(NewAppearance, UnitState, ArmorTemplateName, bClassUniformOnly))
	{
		`AMLOG(UnitState.GetFullName() @ "aplying uniform appearance for:" @ ArmorTemplateName);

		UnitState.SetTAppearance(NewAppearance);
		UnitState.StoreAppearance(UnitState.kAppearance.iGender, ArmorTemplateName);
	}
	else `AMLOG(UnitState.GetFullName() @ "has no uniform for:" @ ArmorTemplateName);
}


static function EventListenerReturn OnUnitRankUp(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
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

	

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnPostAliensSpawned(Object EventData, Object EventSource, XComGameState StartState, Name Event, Object CallbackData)
{
	local XComGameState_Unit		UnitState;
	local CharacterPoolManager_AM	CharacterPool;
	local TAppearance				NewAppearance;

	CharacterPool = `CHARACTERPOOLMGRAM;
	if (CharacterPool == none)
		return ELR_NoInterrupt;

	foreach StartState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		`AMLOG(UnitState.GetFullName() @ UnitState.GetMyTemplateGroupName());

		if (UnitState.GetMyTemplateGroupName() == 'CivilianMilitia')
		{
			`AMLOG(UnitState.GetFullName() @ "is militia" @ UnitState.GetMyTemplateName() @ UnitState.GetItemInSlot(eInvSlot_Armor, StartState).GetMyTemplateName());
			/*
			NewAppearance = UnitState.kAppearance;
			if (CharacterPool.GetUniformAppearanceForMilitia(NewAppearance, UnitState))
			{
				`AMLOG("Aplying uniform appearance");

				UnitState.SetTAppearance(NewAppearance);
				UnitState.StoreAppearance();
			}
			else `AMLOG("Has no uniform");*/
		}
	}

	return ELR_NoInterrupt;
}
