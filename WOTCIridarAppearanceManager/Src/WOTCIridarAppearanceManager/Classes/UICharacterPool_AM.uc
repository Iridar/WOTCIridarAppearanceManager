class UICharacterPool_AM extends UICharacterPool;

// Sort the displayed list of soldiers and display more info.
simulated function array<string> GetCharacterNames()
{
	local array<string> CharacterNames; 
	local int i; 
	
	local XComGameState_Unit Soldier;
	local string soldierName;

	CharacterPoolManager_AM(CharacterPoolMgr).SortCharacterPoolBySoldierName();
	CharacterPoolManager_AM(CharacterPoolMgr).SortCharacterPoolBySoldierClass();
	
	for (i = 0; i < CharacterPoolMgr.CharacterPool.Length; i++)
	{
		Soldier = CharacterPoolMgr.CharacterPool[i];

		soldierName = class'Help'.static.GetUnitDisplayString(Soldier);

		CharacterNames.AddItem(soldierName);
	}
	return CharacterNames; 
}
