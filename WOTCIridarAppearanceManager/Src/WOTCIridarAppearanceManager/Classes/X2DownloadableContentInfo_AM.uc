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

	class'UIArmory_Loadout_CharPool'.default.bXSkinLoaded = class'Help'.static.IsModActive(WOTCXSkin);
}
/*
static event OnLoadedSavedGame()
{
	class'UICustomize_CPExtended'.static.SetInitialSoldierListSettings();
}

static event InstallNewCampaign(XComGameState StartState)
{
	class'UICustomize_CPExtended'.static.SetInitialSoldierListSettings();

	`CPOLOG("Num extra datas:" @ `CHARACTERPOOLMGRXTD.CPExtraDatas.Length);
}*/