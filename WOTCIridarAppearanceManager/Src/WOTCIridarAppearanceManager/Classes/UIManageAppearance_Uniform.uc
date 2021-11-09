class UIManageAppearance_Uniform extends UIManageAppearance;

var localized string strGenderDisabled;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	bShowAllCosmeticOptions = true;

	super.InitScreen(InitController, InitMovie, InitName);

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

	CosmeticOptions = PoolMgr.GetCosmeticOptionsForUnit(ArmoryUnit, GetGenderArmorTemplate());
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
