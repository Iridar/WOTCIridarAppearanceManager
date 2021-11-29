class UISL_BackupPoolLoader extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local CharacterPoolManager_AM	CharPool;
	local CharacterPoolManager_AM	BackupPool;
	local X2BackupPoolLoader		BackupPoolLoader;

	if (UIShell(Screen) != none)
	{
		CharPool = `CHARACTERPOOLMGRAM;
		if (CharPool.CharacterPool.Length == 0 || CharPool.iNumExtraDataOnInit == 0)
		{
			BackupPool = new class'CharacterPoolManager_AM';
			BackupPool.PoolFileName = BackupPool.BackupCharacterPoolPath;
			BackupPool.LoadCharacterPool();

			if (BackupPool.CharacterPool.Length != 0 || BackupPool.ExtraDatas.Length != 0)
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
