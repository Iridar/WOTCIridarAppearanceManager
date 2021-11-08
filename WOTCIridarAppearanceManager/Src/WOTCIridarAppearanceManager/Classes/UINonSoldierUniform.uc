class UINonSoldierUniform extends UICustomize;

var private X2CharacterTemplateManager	CharMgr;
var private CharacterPoolManager_AM		PoolMgr;
var private XComContentManager			ContentMgr;
var private XComGameStateHistory		History;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	CharMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	PoolMgr = `CHARACTERPOOLMGRAM;
	History = `XCOMHISTORY;
	ContentMgr = `CONTENT;

	if (PoolMgr == none)
		CloseScreen();

	if (class'Help'.static.IsUnrestrictedCustomizationLoaded())
	{
		SetTimer(0.1f, false, nameof(FixScreenPosition), self);
	}
}

simulated private function FixScreenPosition()
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
	local X2CharacterTemplate	CharTemplate;
	local X2DataTemplate		DataTemplate;
	local UIMechaListItem		SpawnedItem;

	super.UpdateData();

	List.ClearItems();

	foreach CharMgr.IterateTemplates(DataTemplate)
	{
		CharTemplate = X2CharacterTemplate(DataTemplate);

		if (CharTemplate == none || 
			CharTemplate.bIsSoldier || 
			CharTemplate.bIsCosmetic || 
			CharTemplate.bNeverSelectable ||
			//CharTemplate.IsTemplateAvailableToAnyArea(CharTemplate.BITFIELD_GAMEAREA_Multiplayer) || // Excludes Bradford, for example.
			CharTemplate.bIsAlien ||
			CharTemplate.UnitSize != 1 || 
			CharTemplate.UnitHeight != 2 || 
			CharTemplate.CharacterGroupName == 'Speaker' ||
			CharTemplate.CharacterGroupName == 'PsiZombie' ||
			!CharTemplateIsHumanPawn(CharTemplate, EGender(Unit.kAppearance.iGender)))
			continue;

		SpawnedItem = Spawn(class'UIMechaListItem', List.itemContainer);
		SpawnedItem.InitListItem(CharTemplate.DataName).bAnimateOnInit = false;
		SpawnedItem.UpdateDataCheckbox(string(CharTemplate.DataName), "", GetCheckboxState(CharTemplate.DataName), OnCheckboxChanged); // TODO: Localize character template name
	}
}

private function OnCheckboxChanged(UICheckbox CheckBox)
{
	local UIPanel ListItem;

	ListItem = CheckBox.GetParent(class'UIMechaListItem');

	if (CheckBox.bChecked)
	{
		`AMLOG("Adding non-soldier uniform for unit:" @ Unit.GetFullName() @ ListItem.MCName);
		PoolMgr.AddUnitNonSoldierUniformForCharTemplate(Unit, ListItem.MCName);
	}
	else 
	{
		`AMLOG("Removing non-soldier uniform for unit:" @ Unit.GetFullName() @ ListItem.MCName);
		PoolMgr.RemoveUnitNonSoldierUniformForCharTemplate(Unit, ListItem.MCName);
	}
}

private function bool GetCheckboxState(const name CharTemplateName)
{
	return PoolMgr.IsUnitNonSoldierUniformForCharTemplate(Unit, CharTemplateName);
}

private function bool CharTemplateIsHumanPawn(const X2CharacterTemplate CharTemplate, const EGender ForceGender)
{
	local XComGameState_Unit	FakeUnit;
	local string				ArchetypeString;

	FakeUnit = CreateFakeUnit(CharTemplate, ForceGender);
	if (FakeUnit == none)
		return false;

	ArchetypeString = CharTemplate.GetPawnArchetypeString(FakeUnit);

	`AMLOG(`showvar(ArchetypeString) @ CharTemplate.DataName @ "Is human pawn:" @ XComHumanPawn(ContentMgr.RequestGameArchetype(ArchetypeString)) != none);

	return XComHumanPawn(ContentMgr.RequestGameArchetype(ArchetypeString)) != none;
}

private function XComGameState_Unit CreateFakeUnit(const X2CharacterTemplate CharacterTemplate, const EGender ForceGender)
{
	local XComGameState							SoldierContainerState;
	local XComGameState_Unit					NewSoldierState;	
	local TSoldier								CharacterGeneratorResult;
	local XGCharacterGenerator					CharacterGenerator;
	local XComGameStateContext_ChangeContainer	ChangeContainer;
	
	//Create a game state to use for creating a unit
	ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Character Pool Manager");
	SoldierContainerState = History.CreateNewGameState(true, ChangeContainer);

	NewSoldierState = CharacterTemplate.CreateInstanceFromTemplate(SoldierContainerState);

	CharacterGenerator = `XCOMGAME.Spawn(CharacterTemplate.CharacterGeneratorClass);
	if (CharacterGenerator != none)
	{
		CharacterGeneratorResult = CharacterGenerator.CreateTSoldier(CharacterTemplate.DataName, ForceGender); // It's highly unlikely that pawns are different types between genders, but let's be extra anal.
		NewSoldierState.SetTAppearance(CharacterGeneratorResult.kAppearance);
	}
	else `AMLOG("ERROR :: Failed to spawn CharacterGeneratorClass:" @ CharacterTemplate.CharacterGeneratorClass.Name @ "for Character Template:" @ CharacterTemplate.DataName);
	
	//Tell the history that we don't actually want this game state
	History.CleanupPendingGameState(SoldierContainerState);

	return NewSoldierState;
}
