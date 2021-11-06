class UIMechaListItem_Soldier extends UIMechaListItem_Button;

// Used in UIManageAppearance to list soldier appearances. Simply convenience.

var AppearanceInfo					StoredAppearance;
var X2SoldierPersonalityTemplate	PersonalityTemplate;
var bool							bOriginalAppearance;
var XComGameState_Unit				UnitState;

simulated final function SetPersonalityTemplate()
{
	local array<X2StrategyElementTemplate> PersonalityTemplates;

	PersonalityTemplates = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().GetAllTemplatesOfClass(class'X2SoldierPersonalityTemplate');
	PersonalityTemplate = X2SoldierPersonalityTemplate(PersonalityTemplates[StoredAppearance.Appearance.iAttitude]);
}
