class UIManageAppearance_Uniform extends UIManageAppearance;

var localized string strGenderDisabled;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	bShowAllCosmeticOptions = true;

	// Dumb hack to circumvent the fact that this screen has its own config, which we really don't need.
	CheckboxPresets = class'UIManageAppearance'.default.CheckboxPresets;
	Presets = class'UIManageAppearance'.default.Presets;
	bShowPresets = class'UIManageAppearance'.default.bShowPresets;
	bShowCharPoolSoldiers = class'UIManageAppearance'.default.bShowCharPoolSoldiers;
	bShowUniformSoldiers = class'UIManageAppearance'.default.bShowUniformSoldiers;
	bShowBarracksSoldiers = class'UIManageAppearance'.default.bShowBarracksSoldiers;
	bShowDeadSoldiers = class'UIManageAppearance'.default.bShowDeadSoldiers;

	super.InitScreen(InitController, InitMovie, InitName);

	AppearanceListBG.Hide();
	AppearanceList.Hide();
	List.Hide();
	ListBG.Hide();
}

function UIMechaListItem_Button CreateOptionShowAll()
{
	local UIMechaListItem_Button SpawnedItem;

	SpawnedItem = super.CreateOptionShowAll();

	SpawnedItem.SetDisabled(true);

	return SpawnedItem;
}

function CreateFiltersList() {}
function UpdateAppearanceList() {}
function CreateApplyChangesButton() {}
function UpdateApplyChangesButtonVisibility() {}

simulated function UpdateOptionsList()
{
	super.UpdateOptionsList();
	
	SetCheckboxPositions();
	DisableGenderOption();
}

function OptionPresetCheckboxChanged(UICheckbox CheckBox)
{
	super.OptionPresetCheckboxChanged(CheckBox);

	DisableGenderOption();
}

simulated private function DisableGenderOption()
{
	local UIMechaListItem ListItem;

	// Uniforms are gender-specific by necessity. A female uniform will never be considered for a male soldier, and vice versa.
	// So uniforms that forcibly change unit's gender are not a possibility. 
	ListItem = UIMechaListItem(OptionsList.GetChildByName('iGender'));
	if (ListItem != none && ListItem.Checkbox != none)
	{
		ListItem.Checkbox.SetChecked(false, false);
		ListItem.SetDisabled(true, default.strGenderDisabled);
	}
}

simulated private function SetCheckboxPositions()
{
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local CosmeticOptionStruct			CosmeticOption;
	local CheckboxPresetStruct			CheckboxPreset;

	if (PoolMgr.GetUniformStatus(ArmoryUnit) == EUS_NonSoldier)
	{
		CosmeticOptions = PoolMgr.GetCosmeticOptionsForUnit(ArmoryUnit, string(PoolMgr.NonSoldierUniformSettings));
	}
	else
	{
		CosmeticOptions = PoolMgr.GetCosmeticOptionsForUnit(ArmoryUnit, GetGenderArmorTemplate());
	}
	if (CosmeticOptions.Length != 0)
	{
		`AMLOG("Loading CosmeticOptions for unit" @ CosmeticOptions.Length);
		foreach CosmeticOptions(CosmeticOption)
		{
			if (!IsCosmeticOption(CosmeticOption.OptionName))
				continue;

			`AMLOG(`showvar(CheckboxPreset.OptionName) @ `showvar(CheckboxPreset.bChecked));
			SetOptionsListCheckbox(CosmeticOption.OptionName, CosmeticOption.bChecked);
		}
	}
	else
	{
		`AMLOG("No cosmetic options for this unit, loading uniform defaults");
		foreach class'UIManageAppearance'.default.CheckboxPresets(CheckboxPreset)
		{
			if (CheckboxPreset.Preset == 'PresetUniform')
			{
				`AMLOG(`showvar(CheckboxPreset.OptionName) @ `showvar(CheckboxPreset.bChecked));
				SetOptionsListCheckbox(CheckboxPreset.OptionName, CheckboxPreset.bChecked);
			}
		}
	}
}

simulated function OnOptionCheckboxChanged(UICheckbox CheckBox)
{
	super.OnOptionCheckboxChanged(CheckBox);

	SaveCosmeticOptions();
}

simulated function CloseScreen()
{	
	SaveCosmeticOptions();
	super.CloseScreen();
}

simulated function SaveCosmeticOptions()
{
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local CosmeticOptionStruct			CosmeticOption;
	local UIMechaListItem				ListItem;
	local int i;

	for (i = 1; i < OptionsList.ItemCount; i++) // Skip 0th member that is for sure "ShowAllCosmetics"
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none || !IsCosmeticOption(ListItem.MCName))
			continue;

		`AMLOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked);

		CosmeticOption.OptionName = ListItem.MCName;
		CosmeticOption.bChecked = ListItem.Checkbox.bChecked;
		CosmeticOptions.AddItem(CosmeticOption);
	}
	
	if (PoolMgr.GetUniformStatus(ArmoryUnit) == EUS_NonSoldier)
	{
		PoolMgr.SaveCosmeticOptionsForUnit(CosmeticOptions, ArmoryUnit, string(PoolMgr.NonSoldierUniformSettings));
	}
	else
	{
		PoolMgr.SaveCosmeticOptionsForUnit(CosmeticOptions, ArmoryUnit, GetGenderArmorTemplate());
	}
}


function OnCreatePresetInputBoxAccepted(string text)
{
	local CheckboxPresetStruct	NewPresetStruct;
	local name					NewPresetName;
	local int i;

	if (text == "")
	{
		// No empty preset names
		ShowInfoPopup(strDuplicatePresetDisallowedTitle, strInvalidPresetNameText, eDialog_Warning);
		return;
	}

	text = Repl(text, " ", "_"); // Oh, you want to break this preset by putting spaces into a 'name'? I'm afraid I can't let you do that, Dave..

	NewPresetName = name(text);

	if (Presets.Find(NewPresetName) != INDEX_NONE)
	{
		// Not letting you create duplicates either.
		ShowInfoPopup(strDuplicatePresetDisallowedTitle, strDuplicatePresetDisallowedText, eDialog_Warning);
		return;
	}

	Presets.AddItem(NewPresetName);

	// Copy settings from current preset to the new preset
	for (i = CheckboxPresets.Length - 1; i >= 0; i--)
	{
		if (CheckboxPresets[i].Preset == CurrentPreset)
		{
			NewPresetStruct = CheckboxPresets[i];
			NewPresetStruct.Preset = NewPresetName;
			CheckboxPresets.AddItem(NewPresetStruct);

			`AMLOG("Copied:" @ i @ CurrentPreset @ NewPresetStruct.Preset @ NewPresetStruct.OptionName @ NewPresetStruct.bChecked);
		}
	}

	default.CheckboxPresets = CheckboxPresets;
	default.Presets = Presets;

	// --------------------
	// Update main screen's config to make sure presets created on the Configure Uniform screen are properly saved.
	class'UIManageAppearance'.default.Presets = Presets;
	class'UIManageAppearance'.default.CheckboxPresets = CheckboxPresets;
	class'UIManageAppearance'.static.StaticSaveConfig();
	// --------------------

	CurrentPreset = NewPresetName;
	//ApplyCheckboxPresetPositions(); // No need, settings would be identical.
	UpdateOptionsList();
}

function OnDeletePresetButtonClicked(UIButton ButtonSource)
{
	//local name DeletePreset;
	local int i;

	//DeletePreset = ButtonSource.GetParent(class'UIMechaListItem_Button').MCName;

	`AMLOG("Deleting preset:" @ CurrentPreset @ "This preset exists:" @ Presets.Find(CurrentPreset) != INDEX_NONE);

	Presets.RemoveItem(CurrentPreset);

	// Wipe preset settings for the preset we're deleting.
	for (i = CheckboxPresets.Length - 1; i >= 0; i--)
	{
		if (CheckboxPresets[i].Preset == CurrentPreset)
		{
			CheckboxPresets.Remove(i, 1);
		}
	}

	default.Presets = Presets;
	default.CheckboxPresets = CheckboxPresets;
	
	// --------------------
	// Update main screen's config to make sure presets deleted on the Configure Uniform screen are properly saved.
	class'UIManageAppearance'.default.Presets = Presets;
	class'UIManageAppearance'.default.CheckboxPresets = CheckboxPresets;
	class'UIManageAppearance'.static.StaticSaveConfig();
	// --------------------

	CurrentPreset = 'PresetDefault';
	UpdateOptionsList();
	ApplyCheckboxPresetPositions();
	UpdateUnitAppearance();
}