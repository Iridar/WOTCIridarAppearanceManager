class UIAppearanceStore extends UICustomize;

// This screen lists unit's AppearanceStore elements, allows to preview and delete them.

// TODO: This screen suffers from being darkened by MouseGuard as well.

var private X2ItemTemplateManager	ItemMgr;
var private XComGameState_Unit		UnitState;
var private TAppearance				OriginalAppearance;
var private TAppearance				SelectedAppearance;
var private XComHumanPawn			ArmoryPawn;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	UnitState = CustomizeManager.UpdatedUnitState;
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	OriginalAppearance = ArmoryPawn.m_kAppearance;
	List.OnSelectionChanged = OnListItemSelected;

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
	local AppearanceInfo	StoredAppearance;
	local X2ItemTemplate	ArmorTemplate;
	local EGender			Gender;
	local name				ArmorTemplateName;
	local string			DisplayName;
	local int i;

	super.UpdateData();
	if (UnitState == none)
		return;

	foreach UnitState.AppearanceStore(StoredAppearance)
	{
		Gender = EGender(int(Right(StoredAppearance.GenderArmorTemplate, 1)));
		ArmorTemplateName = name(Left(StoredAppearance.GenderArmorTemplate, Len(StoredAppearance.GenderArmorTemplate) - 1));
		ArmorTemplate = ItemMgr.FindItemTemplate(ArmorTemplateName);

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayName = ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayName = string(ArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}

		if (class'Help'.static.IsAppearanceCurrent(StoredAppearance.Appearance, OriginalAppearance))
		{
			DisplayName @= class'Help'.default.strCurrentAppearance;
			GetListItem(i++).UpdateDataDescription(DisplayName); // Deleting current appearance may not work as people expect it to.
		}
		else
		{
			GetListItem(i++).UpdateDataButton(DisplayName, class'UISaveLoadGameListItem'.default.m_sDeleteLabel, OnDeleteButtonClicked);
		}
	}
}

simulated private function OnListItemSelected(UIList ContainerList, int ItemIndex)
{
	local TAppearance StoredAppearance;

	if (UnitState == none || ItemIndex == INDEX_NONE)
		return;

	StoredAppearance = UnitState.AppearanceStore[ItemIndex].Appearance;
	SetPawnAppearance(StoredAppearance);
}

simulated private function SetPawnAppearance(TAppearance NewAppearance)
{
	// Have to update appearance in the unit state as well, since it will be used to recreate the pawn.
	UnitState.SetTAppearance(NewAppearance);
	ArmoryPawn.SetAppearance(NewAppearance);
		
	// Normally we'd refresh the pawn only in case of gender change, 
	// but here we need to refresh pawn every time to get rid of WAR Suit's exo attachments.
	CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);

	// Can't use an Event Listener in Shell, so using a timer (ugh)
	SetTimer(0.1f, false, nameof(OnRefreshPawn), self);
}

simulated final function OnRefreshPawn()
{
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn != none)
	{
		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizeManager.ActorPawn);
	}
	else
	{
		SetTimer(0.1f, false, nameof(OnRefreshPawn), self);
	}
}

simulated function CloseScreen()
{	
	SetPawnAppearance(OriginalAppearance);
	super.CloseScreen();
}

simulated private function OnDeleteButtonClicked(UIButton ButtonSource)
{
	local int Index;

	SetPawnAppearance(OriginalAppearance);
	Index = List.GetItemIndex(ButtonSource);
	UnitState.AppearanceStore.Remove(Index, 1);
	CustomizeManager.CommitChanges(); // This will submit a Game State with appearance store changes.
	List.ClearItems();
	UpdateData();
}
