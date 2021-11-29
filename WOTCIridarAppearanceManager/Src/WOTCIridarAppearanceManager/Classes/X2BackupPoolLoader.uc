class X2BackupPoolLoader extends Object;

var private CharacterPoolManager_AM CharPool;
var private CharacterPoolManager_AM BackupPool;
var private UIScreen				ShellScreen;

var localized string strLoadBackupTitle;
var localized string strLoadBackupText;

final function InitLoader(CharacterPoolManager_AM _CharPool, CharacterPoolManager_AM _BackupPool, UIScreen _ShellScreen)
{
	CharPool = _CharPool;
	BackupPool = _BackupPool;
	ShellScreen = _ShellScreen;

	`AMLOG("Running");

	ShellScreen.SetTimer(3.0f, false, nameof(DisplayPopup), self);
}

private function DisplayPopup()
{
	local TDialogueBoxData kDialogData;
	local string strText;

	`AMLOG("Raising popup");

	strText = strLoadBackupText;
	strText = Repl(strText, "%CURRENT_SOLDIERS%", CharPool.CharacterPool.Length);
	strText = Repl(strText, "%BACKUP_SOLDIERS%", BackupPool.CharacterPool.Length);
	strText = Repl(strText, "%CURRENT_DATA%", CharPool.iNumExtraDataOnInit);
	strText = Repl(strText, "%BACKUP_DATA%", BackupPool.ExtraDatas.Length);

	kDialogData.strTitle = strLoadBackupTitle;
	kDialogData.eType = eDialog_Warning;
	kDialogData.strText = strText;
	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	kDialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNo;
	kDialogData.fnCallback = OnClickedCallback;
	ShellScreen.Movie.Pres.UIRaiseDialog(kDialogData);
}

private function OnClickedCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		CharPool.CharacterPool = BackupPool.CharacterPool;
		CharPool.ExtraDatas = BackupPool.ExtraDatas;
		CharPool.SaveCharacterPool();
	}
}
