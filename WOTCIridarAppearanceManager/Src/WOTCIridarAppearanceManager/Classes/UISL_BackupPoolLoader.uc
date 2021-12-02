class UISL_BackupPoolLoader extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local CharacterPoolManager_AM	CharPool;
	local CharacterPoolManager_AM	BackupPool;
	local X2BackupPoolLoader		BackupPoolLoader;

	if (UIShell(Screen) != none)
	{
		CharPool = `CHARACTERPOOLMGRAM;
		`AMLOG("Check if restoring Character Pool from backup is required. Num characters:" @ CharPool.CharacterPool.Length @ "Extra Data on Init:" @ CharPool.iNumExtraDataOnInit);
		if (CharPool.CharacterPool.Length == 0 || CharPool.iNumExtraDataOnInit == 0)
		{
			BackupPool = new class'CharacterPoolManager_AM';
			BackupPool.PoolFileName = BackupPool.BackupCharacterPoolPath;
			BackupPool.LoadCharacterPool();

			`AMLOG("Backup pool loaded. Num characters:" @ BackupPool.CharacterPool.Length @ "Extra Data on Init:" @ BackupPool.iNumExtraDataOnInit);

			// Suggest restoring a backup if main pool doesn't have any characters, and backup pool does,
			// or if backup pool has characters, but no extra data, and backup pool has extra data.
			if (CharPool.CharacterPool.Length == 0 && BackupPool.CharacterPool.Length != 0 ||
			CharPool.CharacterPool.Length != 0 && CharPool.iNumExtraDataOnInit == 0 && BackupPool.iNumExtraDataOnInit != 0)
			{
				`AMLOG("Init backup loader");
				BackupPoolLoader = new class'X2BackupPoolLoader';
				BackupPoolLoader.InitLoader(CharPool, BackupPool, Screen);
			}
		}

		// Make sure this UISL runs only once.
		ScreenClass = class'UIScreen_Dummy';
	}
}
