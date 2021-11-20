class UIManageAppearance_ListHeaderItem extends UIPanel;

var private UIBGBox BG;
var private UIDags Dags;

var private UIScrollingText Label;
var private UIImage VisibilityImage;

// Allow access to outside world so that it can manipulate the visuals
var privatewrite UIButton ActionButton;

var privatewrite bool bCollapseToggleEnabled;
var privatewrite bool bSectionVisible;

var bool bActionButtonEnabled;
var string ActionButtonLabel;

// Are we waiting on realize from flash?
var privatewrite bool bFlashRealizePending;

delegate OnCollapseToggled (UIManageAppearance_ListHeaderItem HeaderItem);
delegate OnActionInteracted (UIManageAppearance_ListHeaderItem HeaderItem);

const CONTENT_MARGIN = 5;
const BUTTON_MARGIN = 10;
const LABEL_MARGIN = 10;

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
	Label.SetAlpha(50);

	ActionButton = Spawn(class'UIButton', self);
	ActionButton.bAnimateOnInit = false;
	ActionButton.bIsNavigable = false;
	ActionButton.InitButton('ActionButton');
	ActionButton.OnClickedDelegate = OnActionButtonClicked;
	ActionButton.SetHeight(26);
	ActionButton.SetY(2);
	//ActionButton.OnSizeRealized = UpdateButtonX; TODO
	ActionButton.SetWidth(150); // TODO: it's gonna look like 150 regardless of what is set here

	VisibilityImage = Spawn(class'UIImage', self);
	VisibilityImage.bAnimateOnInit = false;
	VisibilityImage.InitImage('VisibilityImage');
	VisibilityImage.SetSize(30, 30);
	VisibilityImage.SetAlpha(50); // TODO
	VisibilityImage.ProcessMouseEvents(OnVisibilityImageMouseEvent);

	Dags = Spawn(class'UIDags', self);
	Dags.bAnimateOnInit = false;
	Dags.InitPanel('Dags');
	Dags.SetColor(class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR);
	Dags.SetAlpha(15);
	Dags.SetPosition(CONTENT_MARGIN, 32);
	Dags.SetSize(Width - CONTENT_MARGIN * 2, 15);
	Dags.SetDagsScaleX(50);

	RealizeLayoutAndNavigation();
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

simulated function EnableCollapseToggle (bool bInSectionVisible)
{
	bCollapseToggleEnabled = true;
	bSectionVisible = bInSectionVisible;

	SetVisibilityImage();
}

simulated function DisableCollapseToggle ()
{
	bCollapseToggleEnabled = false;
}

// Must be called after manipulating the collapse toggle and/or action button
simulated function RealizeLayoutAndNavigation ()
{
	FinalizeProperties();
	UpdateNavigation();
	DoRealizeLayout();
}

/////////////////////////
/// Internal workings ///
/////////////////////////

simulated private function FinalizeProperties ()
{
	VisibilityImage.SetVisible(bCollapseToggleEnabled);
	ActionButton.SetVisible(bActionButtonEnabled);
}

simulated private function UpdateNavigation ()
{
	// TODO (controller)
}

//simulated private function UpdatebFlashRealizePending ()
//{
//	bFlashRealizePending = ActionButton.bIsVisible && !ActionButton.SizeRealized;
//}
//
//simulated private function TryRealizeLayout ()
//{
//	UpdatebFlashRealizePending();
//	
//	if (!bFlashRealizePending)
//	{
//		DoRealizeLayout();
//	}
//}

simulated private function DoRealizeLayout ()
{
	local float WidthLeft;

	WidthLeft = Width - CONTENT_MARGIN * 2;

	// The visibility icon is the most right
	if (bCollapseToggleEnabled)
	{
		WidthLeft -= VisibilityImage.Width;
		VisibilityImage.SetX(WidthLeft);
	}

	// Then the action button
	if (bActionButtonEnabled)
	{
		if (bCollapseToggleEnabled) WidthLeft -= BUTTON_MARGIN;
		WidthLeft -= ActionButton.Width;
		ActionButton.SetX(WidthLeft);
	}

	// The label takes the rest
	if (bCollapseToggleEnabled || bActionButtonEnabled) WidthLeft -= LABEL_MARGIN;
	Label.SetWidth(WidthLeft);
}

simulated private function SetVisibilityImage ()
{
	VisibilityImage.LoadImage(
		bSectionVisible ? "img:///AM_UIManageAppearance.Visibility_Open" : "img:///AM_UIManageAppearance.Visibility_Closed"
	);
}

simulated private function OnActionButtonClicked (UIButton Button)
{
	if (OnActionInteracted != none)
	{
		OnActionInteracted(self);
	}
}

simulated private function OnVisibilityImageMouseEvent (UIPanel Panel, int Cmd)
{
	switch (cmd)
	{
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_UP:
			bSectionVisible = !bSectionVisible;
			SetVisibilityImage();

			if (OnCollapseToggled != none)
			{
				OnCollapseToggled(self);
			}
		break;
		
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OVER:
			VisibilityImage.SetAlpha(70);
		break;

		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OUT:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OUT:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_RELEASE_OUTSIDE:
			VisibilityImage.SetAlpha(50);
		break;
	}
}

defaultproperties
{
	bIsNavigable = false // TODO: Make this dynamic based on the buttons that we have enabled
	bCascadeFocus = false
	Height = 55
}
