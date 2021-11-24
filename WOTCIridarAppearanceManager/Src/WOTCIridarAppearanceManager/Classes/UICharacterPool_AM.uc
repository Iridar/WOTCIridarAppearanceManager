class UICharacterPool_AM extends UICharacterPool;

var private UIButton SearchButton;
var private string SearchText;



simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local float RunningY;
	local float RunningYBottom;

	super(UIScreen).InitScreen(InitController, InitMovie, InitName);

	// ---------------------------------------------------------

	// Create Container
	Container = Spawn(class'UIPanel', self).InitPanel('').SetPosition(30, 70).SetSize(600, 850);

	// Create BG
	BG = Spawn(class'UIBGBox', Container).InitBG('', 0, 0, Container.width, Container.height);
	BG.SetAlpha( 80 );

	RunningY = 10;
	RunningYBottom = Container.Height - 10;

	// Create Title text
	TitleHeader = Spawn(class'UIX2PanelHeader', Container);
	TitleHeader.InitPanelHeader('', m_strTitle, m_strSubtitle);
	TitleHeader.SetHeaderWidth(Container.width - 20);
	TitleHeader.SetPosition(10, RunningY);
	RunningY += TitleHeader.Height;

	if(Movie.IsMouseActive())
	{
		//Create buttons
		CreateButton = Spawn(class'UIButton', Container);
		CreateButton.ResizeToText = true;
		CreateButton.InitButton('', m_strCreateCharacter, OnButtonCallback, eUIButtonStyle_NONE);
		CreateButton.SetPosition(10, RunningY);
		CreateButton.OnSizeRealized = OnCreateButtonSizeRealized;

		ImportButton = Spawn(class'UIButton', Container);
		ImportButton.InitButton('', m_strImportCharacter, OnButtonCallback, eUIButtonStyle_NONE);
		ImportButton.SetPosition(180, RunningY);

		RunningY += ImportButton.Height + 10;
	}

	//Create bottom buttons
	OptionsList = Spawn(class'UIList', Container);
	OptionsList.InitList('OptionsListMC', 10, RunningYBottom - class'UIMechaListItem'.default.Height, Container.Width - 20, 300, , false);

	RunningYBottom -= class'UIMechaListItem'.default.Height + 10;   

	if (Movie.IsMouseActive())
	{
		ExportButton = Spawn(class'UIButton', Container);
		ExportButton.ResizeToText = true;
		ExportButton.InitButton('', m_strExportSelection, OnButtonCallback, eUIButtonStyle_NONE);
		ExportButton.SetPosition(10, RunningYBottom - ExportButton.Height);
		ExportButton.DisableButton(m_strNothingSelected);
		ExportButton.OnSizeRealized = OnExportButtonSizeRealized;

		DeselectAllButton = Spawn(class'UIButton', Container);
		DeselectAllButton.InitButton('', m_strDeselectAll, OnButtonCallback, eUIButtonStyle_NONE);
		DeselectAllButton.SetPosition(180, RunningYBottom - DeselectAllButton.Height);
		DeselectAllButton.DisableButton(m_strNothingSelected);

		RunningYBottom -= ExportButton.Height + 10;

		DeleteButton = Spawn(class'UIButton', Container);
		DeleteButton.ResizeToText = true;
		DeleteButton.InitButton('', m_strDeleteSelection, OnButtonCallback, eUIButtonStyle_NONE);
		DeleteButton.SetPosition(10, RunningYBottom - DeleteButton.Height);
		DeleteButton.DisableButton(m_strNothingSelected);
		DeleteButton.OnSizeRealized = OnDeleteButtonSizeRealized;

		SelectAllButton = Spawn(class'UIButton', Container);
		SelectAllButton.InitButton('', m_strSelectAll, OnButtonCallback, eUIButtonStyle_NONE);
		SelectAllButton.SetPosition(180, RunningYBottom - SelectAllButton.Height);
		SelectAllButton.DisableButton(m_strNoCharacters);

		// ADDED
		SelectAllButton.OnSizeRealized = OnSelectAllButtonSizeRealized;

		SearchButton = Spawn(class'UIButton', Container);
		SearchButton.InitButton('', `CAPS(class'UIManageAppearance'.default.strSearchTitle), OnSearchButtonClicked, eUIButtonStyle_NONE);
		SearchButton.SetPosition(350, RunningYBottom - SearchButton.Height);
		// END OF ADDED

		RunningYBottom -= DeleteButton.Height + 10;
	}

	List = Spawn(class'UIList', Container);
	List.bAnimateOnInit = false;
	List.InitList('', 10, RunningY, TitleHeader.headerWidth - 20, RunningYBottom - RunningY);
	BG.ProcessMouseEvents(List.OnChildMouseEvent);
	List.bStickyHighlight = true;

	// --------------------------------------------------------

	NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();

	// ---------------------------------------------------------

	CharacterPoolMgr = CharacterPoolManager(`XENGINE.GetCharacterPoolManager());

	
	if( `ISCONTROLLERACTIVE )
	{
		m_iCurrentUsage = (`XPROFILESETTINGS.Data.m_eCharPoolUsage);
	}
	else
	{
		// Subtract one b/c NONE first option is skipped when generating the list
		m_iCurrentUsage = (`XPROFILESETTINGS.Data.m_eCharPoolUsage - 1);
	}
	

	// ---------------------------------------------------------
	
	CreateOptionsList();

	// ---------------------------------------------------------
	
	UpdateData();
	
	// ---------------------------------------------------------

	Hide();
	`XCOMGRI.DoRemoteEvent('StartCharacterPool'); // start a fade
	WorldInfo.RemoteEventListeners.AddItem(self);
	SetTimer(2.0, false, nameof(ForceShow));
	
	bAnimateOut = false;
}

// Sort the displayed list of soldiers and display more info.
// Not actually used.
simulated function array<string> GetCharacterNames()
{
	local array<string> CharacterNames; 
	local int i; 
	
	local XComGameState_Unit Soldier;
	local string soldierName;

	CharacterPoolManager_AM(CharacterPoolMgr).SortCharacterPoolByUniformStatus();
	CharacterPoolManager_AM(CharacterPoolMgr).SortCharacterPoolBySoldierName();
	CharacterPoolManager_AM(CharacterPoolMgr).SortCharacterPoolBySoldierClass();
	
	for (i = 0; i < CharacterPoolMgr.CharacterPool.Length; i++)
	{
		Soldier = CharacterPoolMgr.CharacterPool[i];

		soldierName = class'Help'.static.GetUnitDisplayString(Soldier);

		if (SearchText != "" && InStr(soldierName, SearchText,, true) == INDEX_NONE) // Ignore case
		{
			continue;
		}

		CharacterNames.AddItem(soldierName);
	}
	return CharacterNames; 
}

// Original Character Pool relies on the order of soldiers in the list.
// Since the SearchText functionality means not all soldiers may be displayed all the time,
// that functionality stops working reliably, so a new UIMechaList element is used to get
// the UnitState stored in that list element specifically.
simulated function UpdateDisplay()
{
	local XComGameState_Unit		UnitState;
	local string					strDisplayName;
	local UIMechaListItem_Soldier	SpawnedItem;
	local EUniformStatus			UniformStatus;

	CharacterPoolManager_AM(CharacterPoolMgr).SortCharacterPoolBySoldierName();
	CharacterPoolManager_AM(CharacterPoolMgr).SortCharacterPoolBySoldierClass();

	List.ClearItems();

	// Do two passes through Character Pool. First, make a list of non-uniforms.
	foreach CharacterPoolMgr.CharacterPool(UnitState)
	{	
		strDisplayName = class'Help'.static.GetUnitDisplayString(UnitState);

		if (SearchText != "" && InStr(strDisplayName, SearchText,, true) == INDEX_NONE) // Ignore case
		{
			continue;
		}

		UniformStatus = CharacterPoolManager_AM(CharacterPoolMgr).GetUniformStatus(UnitState);
		if (UniformStatus != EUS_NotUniform)
			continue;

		if (!UnitState.bAllowedTypeSoldier && !UnitState.bAllowedTypeVIP && !UnitState.bAllowedTypeDarkVIP)
					strDisplayName = class'Help'.static.GetHTMLColoredText(strDisplayName, class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR); // Grey	

		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UnitState = UnitState;
		SpawnedItem.UpdateDataCheckbox(strDisplayName, 
			"",
			SelectedCharacters.Find(UnitState) != INDEX_NONE, 
			SelectSoldier, 
			EditSoldier);
	}

	// Then handle the uniforms, so they're grouped at the bottom of the list.
	CharacterPoolManager_AM(CharacterPoolMgr).SortCharacterPoolByUniformStatus();

	foreach CharacterPoolMgr.CharacterPool(UnitState)
	{	
		strDisplayName = class'Help'.static.GetUnitDisplayString(UnitState);

		if (SearchText != "" && InStr(strDisplayName, SearchText,, true) == INDEX_NONE) // Ignore case
		{
			continue;
		}

		UniformStatus = CharacterPoolManager_AM(CharacterPoolMgr).GetUniformStatus(UnitState);
		if (UniformStatus == EUS_NotUniform)
			continue;  // Would love to do this in the Switch(), but compiler's not letting me.

		class'Help'.static.ApplySoldierNameColorBasedOnUniformStatus(strDisplayName, UniformStatus);

		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UnitState = UnitState;
		SpawnedItem.UpdateDataCheckbox(strDisplayName, 
			"",
			SelectedCharacters.Find(UnitState) != INDEX_NONE, 
			SelectSoldier, 
			EditSoldier);
	}

	UpdateNavHelp();
	if( !`ISCONTROLLERACTIVE )
		UpdateEnabledButtons();
}

simulated function EditSoldier()
{
	local UIMechaListItem_Soldier	SelectedPanel;
	local XComGameState_Unit		SelectedUnit;

	SelectedPanel = UIMechaListItem_Soldier(List.GetSelectedItem());
	SelectedUnit = SelectedPanel.UnitState;

	PC.Pres.UICustomize_Menu(SelectedUnit, none);
	CharacterPoolMgr.SaveCharacterPool();
}

simulated function SelectSoldier(UICheckbox CheckBox)
{
	local UIMechaListItem_Soldier	SelectedPanel;
	local XComGameState_Unit		SelectedUnit;

	SelectedPanel = UIMechaListItem_Soldier(List.GetSelectedItem());
	SelectedUnit = SelectedPanel.UnitState;

	if (CheckBox.bChecked)
		SelectedCharacters.AddItem(SelectedUnit);
	else
		SelectedCharacters.RemoveItem(SelectedUnit);
	
	if( `ISCONTROLLERACTIVE )
		UpdateNavHelp();
	else
		UpdateEnabledButtons();
}

function XComGameState_Unit GetSoldierInSlot( int iSlot )
{
	local UIMechaListItem_Soldier	SelectedPanel;
	local XComGameState_Unit		SelectedUnit;

	SelectedPanel = UIMechaListItem_Soldier(List.GetItem(iSlot));
	SelectedUnit = SelectedPanel.UnitState;

	return SelectedUnit;
}

simulated function OnSelectAllButtonSizeRealized()
{
	SearchButton.SetX(SelectAllButton.X + SelectAllButton.Width + 10);
}

private function OnSearchButtonClicked(UIButton ButtonSource)
{
	local TInputDialogData kData;

	if (SearchText != "")
	{
		SearchText = "";
		ButtonSource.SetText(`CAPS(class'UIManageAppearance'.default.strSearchTitle));
		UpdateData();
	}
	else
	{
		kData.strTitle = `CAPS(class'UIManageAppearance'.default.strSearchTitle);
		kData.iMaxChars = 99;
		kData.strInputBoxText = SearchText;
		kData.fnCallback = OnSearchInputBoxAccepted;

		Movie.Pres.UIInputDialog(kData);
	}
}

private function OnSearchInputBoxAccepted(string text)
{
	local string strShowText;

	SearchText = text;
	strShowText = `CAPS(class'UIManageAppearance'.default.strSearchTitle);

	if (SearchText != "")
	{
		strShowText $= ":" @ SearchText;
		// Truncate displayed text if it becomes too long.
		if (Len(strShowText) > 24)
		{
			strShowText = Left(strShowText, 24);
			strShowText $= "...";
		}
	}

	SearchButton.SetText(strShowText);
	UpdateData();
}
