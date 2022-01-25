class X2DownloadableContentInfo_AM extends X2DownloadableContentInfo;

static function OnPreCreateTemplates()
{	
	local XComEngine LocalEngine;

	LocalEngine = `XENGINE;
	LocalEngine.m_CharacterPoolManager = new class'CharacterPoolManager_AM';

	`AMLOG("Replaced Character Pool manager.");
}

static event OnPostTemplatesCreated()
{
	class'UIManageAppearance'.static.SetInitialSoldierListSettings();
}

exec function SetArmorTemplateName(name NewName)
{
	UIManageAppearance(`SCREENSTACK.GetCurrentScreen()).ArmorTemplateName = NewName;
	`LOG("Set ArmorTemplateName to:" @ NewName,, 'IRITEST');
}

exec function CheckPawn()
{
	`LOG("Current Pawn's weapon tint:" @ XComHumanPawn(UICustomize(`SCREENSTACK.GetCurrentScreen()).CustomizeManager.ActorPawn).m_kAppearance.iWeaponTint @ XComHumanPawn(UICustomize(`SCREENSTACK.GetCurrentScreen()).CustomizeManager.ActorPawn).m_kAppearance.nmWeaponPattern);
	`LOG("Current Pawn's weapon tint:" @ UICustomize(`SCREENSTACK.GetCurrentScreen()).CustomizeManager.UpdatedUnitState.GetFullName() @ UICustomize(`SCREENSTACK.GetCurrentScreen()).CustomizeManager.UpdatedUnitState.kAppearance.iWeaponTint @ UICustomize(`SCREENSTACK.GetCurrentScreen()).CustomizeManager.UpdatedUnitState.kAppearance.nmWeaponPattern);
}

/*
static event OnLoadedSavedGame()
{
	class'UICustomize_CPExtended'.static.SetInitialSoldierListSettings();
}*/
/*
static event InstallNewCampaign(XComGameState StartState)
{
	local XComGameState_Unit		UnitState;
	local CharacterPoolManager_AM	CharacterPool;
	local TAppearance				NewAppearance;

	CharacterPool = `CHARACTERPOOLMGRAM;
	if (CharacterPool == none)
		return;

	foreach StartState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		`AMLOG(UnitState.GetFullName() @ UnitState.GetMyTemplateGroupName());
			
		NewAppearance = UnitState.kAppearance;
		if (CharacterPool.GetUniformAppearanceForNonSoldier(NewAppearance, UnitState))
		{
			`AMLOG("Aplying uniform appearance" @ NewAppearance.nmTorso);

			UnitState.SetTAppearance(NewAppearance);

			`AMLOG("New torso:" @ UnitState.kAppearance.nmTorso);
			UnitState.StoreAppearance();
		}
		else `AMLOG("Has no uniform");
	}
}*/
