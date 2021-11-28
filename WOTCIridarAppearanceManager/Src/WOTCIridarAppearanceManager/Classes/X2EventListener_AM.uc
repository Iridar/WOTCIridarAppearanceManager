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
		UnitState.StoreAppearance(UnitState.kAppearance.iGender, ArmorTemplateName);

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
		if (UnitState.GetMyTemplateName() == 'Clerk')
		{
			HumanPawn.SetAppearance(NewAppearance, false);
			RequestFullPawnContentForClerk(UnitState, HumanPawn, NewAppearance);
		}
		else
		{
			HumanPawn.SetAppearance(NewAppearance, true);
		}
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

// Base game is pawn content request logic is hardcoded to not request certain body parts for clerks. 
static private function RequestFullPawnContentForClerk(XComGameState_Unit UnitState, XComHumanPawn HumanPawn, const out TAppearance m_kAppearance)
{
	local PawnContentRequest kRequest;
	//local XGUnit GameUnit;
	local name UnderlayName;
	local bool HasCustomUnderlay; // for issue #251	
	
	HasCustomUnderlay = class'CHHelpers'.default.CustomUnderlayCharTemplates.Find(UnitState.GetMyTemplateName()) != INDEX_NONE; 
	HumanPawn.bShouldUseUnderlay = HumanPawn.ShouldUseUnderlay(UnitState);

	//Underlay is the outfit that characters wear when they are in the background of the ship. It is a custom uni-body mesh that saves on mesh component draws and updates.
	UnderlayName = HumanPawn.GetUnderlayName(HumanPawn.bShouldUseUnderlay, m_kAppearance);		
	if (HasCustomUnderlay && UnderlayName != '') //issue #251 start
	{
		UnderlayName = m_kAppearance.nmTorso_Underlay;
	}
	// issue #251 end
	//GameUnit = XGUnit(GetGameUnit());
	//`log(self @ GetFuncName() @ `showvar(GameUnit) @ `showvar(m_bSetAppearance) @ `showvar(m_bSetArmorKit), , 'DevStreaming');

	HumanPawn.PawnContentRequests.Length = 0;
	HumanPawn.PatternsContent.Length = 0;

	//Order matters here, because certain pieces of content can affect other pieces of content. IE. a selected helmet can affect which mesh the hair uses, or disable upper or lower face props
	if ((!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmTorso != '') || (HumanPawn.bShouldUseUnderlay && UnderlayName != ''))
	{
		kRequest.ContentCategory = 'Torso';
		kRequest.TemplateName = HumanPawn.bShouldUseUnderlay ? UnderlayName : m_kAppearance.nmTorso;
		kRequest.BodyPartLoadedFn = HumanPawn.OnTorsoLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmTorsoDeco != '')
	{
		kRequest.ContentCategory = 'TorsoDeco';
		kRequest.TemplateName = m_kAppearance.nmTorsoDeco;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmHead != '')
	{
		kRequest.ContentCategory = 'Head';
		kRequest.TemplateName = m_kAppearance.nmHead;
		kRequest.BodyPartLoadedFn = HumanPawn.OnHeadLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	//Helmets can affect: beard, lower face prop, upper face prop, hair mesh
	if (m_kAppearance.nmHelmet != '')
	{
		kRequest.ContentCategory = 'Helmets';
		kRequest.TemplateName = m_kAppearance.nmHelmet;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	//Lower face props can affect: beard
	if (m_kAppearance.nmFacePropLower != '')
	{
		kRequest.ContentCategory = 'FacePropsLower';
		kRequest.TemplateName = m_kAppearance.nmFacePropLower;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmHaircut != '')
	{
		kRequest.ContentCategory = 'Hair';
		kRequest.TemplateName = m_kAppearance.nmHaircut;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmBeard != '')
	{
		kRequest.ContentCategory = 'Beards';
		kRequest.TemplateName = m_kAppearance.nmBeard;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmFacePropUpper != '')
	{
		kRequest.ContentCategory = 'FacePropsUpper';
		kRequest.TemplateName = m_kAppearance.nmFacePropUpper;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	// issue #251: allow arms underlay usage only when it's a custom underlay
	if ((!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmArms != '') || (HumanPawn.bShouldUseUnderlay && HasCustomUnderlay))
	{
		kRequest.ContentCategory = 'Arms';
		kRequest.TemplateName = HumanPawn.bShouldUseUnderlay ? m_kAppearance.nmArms_Underlay : m_kAppearance.nmArms;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmLeftArm != '')
	{
		kRequest.ContentCategory = 'LeftArm';
		kRequest.TemplateName = m_kAppearance.nmLeftArm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmRightArm != '')
	{
		kRequest.ContentCategory = 'RightArm';
		kRequest.TemplateName = m_kAppearance.nmRightArm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmLeftArmDeco != '')
	{
		kRequest.ContentCategory = 'LeftArmDeco';
		kRequest.TemplateName = m_kAppearance.nmLeftArmDeco;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmRightArmDeco != '')
	{
		kRequest.ContentCategory = 'RightArmDeco';
		kRequest.TemplateName = m_kAppearance.nmRightArmDeco;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmLeftForearm != '')
	{
		kRequest.ContentCategory = 'LeftForearm';
		kRequest.TemplateName = m_kAppearance.nmLeftForearm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmRightForearm != '')
	{
		kRequest.ContentCategory = 'RightForearm';
		kRequest.TemplateName = m_kAppearance.nmRightForearm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnArmsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}
	// issue #251: allow legs underlay usage only when it's a custom underlay
	if ((!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmLegs != '') || (HumanPawn.bShouldUseUnderlay && HasCustomUnderlay))
	{
		kRequest.ContentCategory = 'Legs';
		kRequest.TemplateName = HumanPawn.bShouldUseUnderlay ? m_kAppearance.nmLegs_Underlay : m_kAppearance.nmLegs;
		kRequest.BodyPartLoadedFn = HumanPawn.OnLegsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmThighs != '')
	{
		kRequest.ContentCategory = 'Thighs';
		kRequest.TemplateName = m_kAppearance.nmThighs;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (!HumanPawn.bShouldUseUnderlay && m_kAppearance.nmShins != '')
	{
		kRequest.ContentCategory = 'Shins';
		kRequest.TemplateName = m_kAppearance.nmShins;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmEye != '')
	{
		kRequest.ContentCategory = 'Eyes';
		kRequest.TemplateName = m_kAppearance.nmEye;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmTeeth != '')
	{
		kRequest.ContentCategory = 'Teeth';
		kRequest.TemplateName = m_kAppearance.nmTeeth;
		kRequest.BodyPartLoadedFn = HumanPawn.OnBodyPartLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmPatterns != '')
	{
		kRequest.ContentCategory = 'Patterns';
		kRequest.TemplateName = m_kAppearance.nmPatterns;
		kRequest.BodyPartLoadedFn = HumanPawn.OnPatternsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmWeaponPattern != '')
	{
		kRequest.ContentCategory = 'Patterns';
		kRequest.TemplateName = m_kAppearance.nmWeaponPattern;
		kRequest.BodyPartLoadedFn = HumanPawn.OnPatternsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmTattoo_LeftArm != '')
	{
		kRequest.ContentCategory = 'Tattoos';
		kRequest.TemplateName = m_kAppearance.nmTattoo_LeftArm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnTattoosLoaded_LeftArm;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmTattoo_RightArm != '')
	{
		kRequest.ContentCategory = 'Tattoos';
		kRequest.TemplateName = m_kAppearance.nmTattoo_RightArm;
		kRequest.BodyPartLoadedFn = HumanPawn.OnTattoosLoaded_RightArm;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmScars != '')
	{
		kRequest.ContentCategory = 'Scars';
		kRequest.TemplateName = m_kAppearance.nmScars;
		kRequest.BodyPartLoadedFn = HumanPawn.OnScarsLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmFacePaint != '')
	{
		kRequest.ContentCategory = 'Facepaint';
		kRequest.TemplateName = m_kAppearance.nmFacePaint;
		kRequest.BodyPartLoadedFn = HumanPawn.OnFacePaintLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	if (m_kAppearance.nmVoice != '' && `TACTICALGRI != none) //Only load the voices for tactical. In strategy play them on demand
	{
		kRequest.ContentCategory = 'Voice';
		kRequest.TemplateName = m_kAppearance.nmVoice;
		kRequest.BodyPartLoadedFn = HumanPawn.OnVoiceLoaded;
		HumanPawn.PawnContentRequests.AddItem(kRequest);
	}

	//  Make the requests later. If they come back synchronously, their callbacks will also happen synchronously, and it can throw things out of whack
	HumanPawn.MakeAllContentRequests();
	
}

defaultproperties
{
	RefreshPawnEventName = "IRI_AM_RefreshPawnEvent";
}