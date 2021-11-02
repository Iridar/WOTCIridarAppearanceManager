class AM_MCM_UISL extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local WOTCCharacterPoolExtended_MCMScreen MCMScreen;

	if (ScreenClass == none)
	{
		if (MCM_API(Screen) != none)
			ScreenClass = Screen.Class;
		else return;
	}

	MCMScreen = new class'AM_MCM_Screen';
	MCMScreen.OnInit(Screen);
}

defaultproperties
{
    ScreenClass = none;
}
