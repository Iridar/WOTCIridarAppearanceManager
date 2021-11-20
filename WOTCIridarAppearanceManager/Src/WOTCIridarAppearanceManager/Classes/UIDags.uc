// Originally developed for Covert Infiltration under the MIT license

class UIDags extends UIPanel;

var protected GFxObject DagsMask;
var protected GFxObject Dags;

var protectedwrite float DagsScaleX;

const DAGS_MC_NAME = "dages";
const DAGS_MASK_MC_NAME = "dagMask";

const DAGS_X_OFFSET = -30;

//////////////////////
/// Initialization /// 
//////////////////////

simulated function OnInit()
{
	// Spawn them before super.OnInit() as that flashes comamnd queue and calls on init delgates
	// and for both we want the dags to exist on the flash side
	SpawnDags();

	super.OnInit();
}

simulated protected function SpawnDags ()
{
	local GFxObject gfxSelf;

	gfxSelf = Movie.GetVariableObject(string(MCPath));

	DagsMask = gfxSelf.AttachMovie("dagMask", DAGS_MASK_MC_NAME, 100);
	Dags = gfxSelf.AttachMovie("dags", DAGS_MC_NAME, 101);
	DagsSetMask(DagsMask);
	
	// Prevents empty spot top-left
	Dags.SetPosition(DAGS_X_OFFSET, 0);

	// Positioning - x is is left offset, y is the center (from origin to height/2)
}

simulated protected function DagsSetMask (GFxObject Mask)
{
	Dags.ActionScriptVoid("setMask");
}

////////////////////
/// Manipulation ///
////////////////////

simulated function UIPanel SetSize (float NewWidth, float NewHeight)
{
	SetWidth(NewWidth);
	SetHeight(NewHeight);

	return self;
}

simulated function SetWidth (float NewWidth)
{
	if( Width != NewWidth )
	{
		Width = NewWidth;

		MC.ChildSetNum(DAGS_MASK_MC_NAME, "_width", Width);
		// No need to size dags themselves as they are super long
	}
}

simulated function SetHeight (float NewHeight)
{
	if( Height != NewHeight )
	{
		Height = NewHeight;

		MC.ChildSetNum(DAGS_MASK_MC_NAME, "_height", Height);
		MC.ChildSetNum(DAGS_MASK_MC_NAME, "_y", Height / 2);

		MC.ChildSetNum(DAGS_MC_NAME, "_height", Height);
		MC.ChildSetNum(DAGS_MC_NAME, "_y", Height / 2);
	}
}

simulated function SetDagsScaleX (float NewScale)
{
	if (DagsScaleX != NewScale)
	{
		DagsScaleX = NewScale;
		MC.ChildSetNum(DAGS_MC_NAME, "_xscale", DagsScaleX);
	}
}

defaultproperties
{
	DagsScaleX = 100;
}