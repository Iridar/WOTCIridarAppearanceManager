class X2DownloadableContentInfo_AM extends X2DownloadableContentInfo;

static function OnPreCreateTemplates()
{	
	local XComEngine LocalEngine;

	LocalEngine = `XENGINE;
	LocalEngine.m_CharacterPoolManager = new class'CharacterPoolManager_AM';

	`AMLOG("Replacing CP manager. Num extra datas:" @ CharacterPoolManagerExtended(LocalEngine.m_CharacterPoolManager).CPExtraDatas.Length);
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