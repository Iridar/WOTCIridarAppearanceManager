class AM_MCM_Defaults extends Object config(AppearanceManager_DEFAULT);

struct CheckboxPresetStruct
{
	var name Preset;
	var name OptionName;
	var bool bChecked;
};

var config int VERSION_CFG;

var config bool AUTOMATIC_UNIFORM_MANAGEMENT;
var config bool MANAGE_APPEARANCE_2D;
var config bool MULTIPLE_UNIT_CHANGE_REQUIRES_CONFIRMATION;
var config bool DISABLE_APPEARANCE_VALIDATION_REVIEW;
var config bool DISABLE_APPEARANCE_VALIDATION_DEBUG;
var config bool REMEMBER_SCROLLBAR_POSITION_IN_CHARACTER_POOL;
var config bool DEBUG_LOGGING;

// These are not exposed for MCM, they are for UIManageAppearance.
var config array<name> Presets;
var config array<CheckboxPresetStruct> CheckboxPresets;
var config bool bShowPresets;

var config bool bShowCharPoolSoldiers;
var config bool bShowUniformSoldiers;
var config bool bShowBarracksSoldiers;
var config bool bShowDeadSoldiers;
var config bool bShowAllCosmeticOptions;

//var config int FEMALE_CHANCE;
var config int CHAR_POOL_MIXED_CHANCE;
