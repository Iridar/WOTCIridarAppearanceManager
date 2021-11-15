class UIManageAppearance_ListHeaderItem extends UIPanel;

var private UIBGBox BG;
var private UIDags Dags;

var private UIScrollingText Label;
var private UIButton AdditionalButton;
var private UIImage VisibilityImage;

const CONTENT_MARGIN = 5;
const LABEL_MARGIN = 3;

////////////
/// Init ///
////////////

simulated function InitHeader (optional name InitName)
{
	InitPanel(InitName);
	Width = GetParent(class'UIList', true).Width;

	BG = Spawn(class'UIBGBox', self);
	BG.bAnimateOnInit = false;
	BG.InitBG('BG');
	BG.SetSize(Width, Height - 5);
	BG.SetOutline(false, class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR);
	BG.SetAlpha(30);

	Label = Spawn(class'UIScrollingText', self);
	Label.bAnimateOnInit = false;
	Label.InitScrollingText('Label');
	Label.SetPosition(CONTENT_MARGIN, 0);
	Label.SetWidth(Width - CONTENT_MARGIN * 2); // TODO
	Label.SetAlpha(50);

	Dags = Spawn(class'UIDags', self);
	Dags.bAnimateOnInit = false;
	Dags.InitPanel('Dags');
	Dags.SetColor(class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR);
	Dags.SetAlpha(15);
	Dags.SetPosition(CONTENT_MARGIN, 32);
	Dags.SetSize(Width - CONTENT_MARGIN * 2, 15);
	Dags.SetDagsScaleX(50);
}

////////////////////
/// Manipulation ///
////////////////////

simulated function SetLabel (string strValue)
{
	Label.SetHTMLText(
		class'UIUtilities_Text'.static.AddFontInfo(
			class'Help'.static.ColourText(
				strValue,
				class'UIUtilities_Colors'.const.PERK_HTML_COLOR
			),
			Screen.bIsIn3D, true,, 24
		)
	);
}

defaultproperties
{
	bIsNavigable = false // TODO: Make this dynamic based on the buttons that we have enabled
	Height = 55
}
