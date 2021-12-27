class UICharacterPool_ListPools_AM extends UICharacterPool_ListPools;

// Make importing and exporting CP units also import and export their extra data.

simulated function DoImportCharacter(string FilenameForImport, int IndexOfCharacter)
{
	local CharacterPoolManager		ImportPool;
	local XComGameState_Unit		ImportUnit;
	local CharacterPoolExtraData	ImportExtraData;

	//Find the character pool we want to import from
	foreach ImportablePoolsLoaded(ImportPool)
	{
		if (ImportPool.PoolFileName == FilenameForImport)
			break;
	}
	//`assert(ImportPool.PoolFileName != FilenameForImport);
	if (ImportPool.PoolFileName != FilenameForImport)
	{
		`redscreen(GetFuncName() @ "WARNING :: Incorrect ImportPool filename:" @ ImportPool.PoolFileName @ "expected:" @ FilenameForImport);
	}

	//Grab the unit (we already know the index)
	ImportUnit = ImportPool.CharacterPool[IndexOfCharacter];

	//Put the unit in the default character pool
	if (ImportUnit != None)
	{
		ImportExtraData = CharacterPoolManager_AM(ImportPool).GetExtraDataForUnit(ImportUnit);

		CharacterPoolManager_AM(CharacterPoolMgr).AddUnitToCharacterPool(ImportUnit, ImportExtraData);

		`AMLOG("ImportPool class:" @ ImportPool.Class.Name @ "CharacterPoolMgr class:" @ CharacterPoolMgr.Class.Name);
	}

	// Exporting a unit from character pool is destricture to unit's connection to its extra data, so once we're done importing, we nuke all previously opened pools to make sure the descruction is not saved.
	ImportablePoolsLoaded.Length = 0;
	//Save the default character pool
	CharacterPoolMgr.SaveCharacterPool();

	`log("Imported character" @ FilenameForImport @ `showvar(IndexOfCharacter) @ ":" @ ImportUnit.GetFullName());
}

simulated function DoImportAllCharacters(string FilenameForImport)
{
	local CharacterPoolManager		ImportPool;
	local XComGameState_Unit		ImportUnit;
	local CharacterPoolExtraData	ImportExtraData;

	if(ImportablePoolsLoaded.Length > 0)
	{
		//Find the character pool we want to import from
		foreach ImportablePoolsLoaded(ImportPool)
		{
			if(ImportPool.PoolFileName == FilenameForImport)
				break;
		}

		if(ImportPool == none)
		{
			ImportPool = ImportablePoolsLoaded[0];
		}
		//`assert(ImportPool.PoolFileName == FilenameForImport);
		if (ImportPool.PoolFileName != FilenameForImport)
		{
			`redscreen(GetFuncName() @ "WARNING :: Incorrect ImportPool filename:" @ ImportPool.PoolFileName @ "expected:" @ FilenameForImport);
		}

		//Grab each unit and put it in the default pool
		foreach ImportPool.CharacterPool(ImportUnit)
		{
			if(ImportUnit != None)
			{
				`AMLOG("ImportPool class:" @ ImportPool.Class.Name @ "CharacterPoolMgr class:" @ CharacterPoolMgr.Class.Name);
				ImportExtraData = CharacterPoolManager_AM(ImportPool).GetExtraDataForUnit(ImportUnit);

				CharacterPoolManager_AM(CharacterPoolMgr).AddUnitToCharacterPool(ImportUnit, ImportExtraData);
			}
		}

		ImportablePoolsLoaded.Length = 0;
		//Save the default character pool
		CharacterPoolMgr.SaveCharacterPool();

		`log("Imported characters" @ FilenameForImport);
	}
}

simulated function DoExportCharacters(string FilenameForExport)
{
	local int i;
	local XComGameState_Unit		ExportUnit;
	local CharacterPoolManager_AM	ExportPool;
	local CharacterPoolExtraData	ExportExtraData;

	local array<XComGameState_Unit>		ExportedUnits;
	local array<CharacterPoolExtraData> ExportedExtraData;

	//Just to be sure we don't have stale data, kill all cached pools and re-open the one we want
	ImportablePoolsLoaded.Length = 0;
	ExportPool = new class'CharacterPoolManager_AM';
	ExportPool.PoolFileName = FilenameForExport;
	ExportPool.LoadCharacterPool();

	//Copy out each character
	foreach UnitsToExport(ExportUnit)
	{
		// Exporting a unit from character pool is destructive to the unit's connection to their Extra Data,
		ExportExtraData = CharacterPoolManager_AM(CharacterPoolMgr).GetExtraDataForUnit(ExportUnit);
		ExportPool.AddUnitToCharacterPool(ExportUnit, ExportExtraData);

		// so we build an array of exported units and their extra datas
		ExportedUnits.AddItem(ExportUnit);
		ExportedExtraData.AddItem(ExportExtraData);

		// Vanilla log line
		`log("Exported character" @ ExportUnit.GetFullName() @ "to pool" @ FilenameForExport);
	}

	// Then save the export pool with new connections in place
	ExportPool.SaveCharacterPool();

	// Then restore the connection between extra data and unit
	foreach ExportedUnits(ExportUnit, i)
	{
		ExportExtraData = ExportedExtraData[i];

		CharacterPoolManager_AM(CharacterPoolMgr).AddUnitToCharacterPool(ExportUnit, ExportExtraData);
	}

	// And save the pool, which will get rid of the leftover previous copies of extra data.
	CharacterPoolMgr.SaveCharacterPool();

	ExportSuccessDialogue();
}

// ------------------------------------------------------------------------------------------------------------------
// Replace Character Pool file class with extended one.

simulated function array<string> GetImportList()
{
	local array<string> Items; 
	local CharacterPoolManager SelectedPool;
	local bool PoolAlreadyLoaded;
	local XComGameState_Unit PoolUnit;

	//Top item should let user grab all characters from the pool
	Items.AddItem(m_strImportAll);

	//Check if we've already deserialized the desired pool
	PoolAlreadyLoaded = false;
	foreach ImportablePoolsLoaded(SelectedPool)
	{
		if (SelectedPool.PoolFileName == SelectedFilename)
		{
			PoolAlreadyLoaded = true;
			break;
		}
	}

	//Instantiate a new pool with data from the file, if we haven't already
	if (!PoolAlreadyLoaded)
	{
		SelectedPool = new class'CharacterPoolManager_AM'; // Changed
		SelectedPool.PoolFileName = SelectedFilename;
		SelectedPool.LoadCharacterPool();
		ImportablePoolsLoaded.AddItem(SelectedPool);
	}

	foreach SelectedPool.CharacterPool(PoolUnit)
	{
		if (PoolUnit.GetNickName() != "")
			Items.AddItem(PoolUnit.GetFirstName() @ PoolUnit.GetNickName() @ PoolUnit.GetLastName());
		else
			Items.AddItem(PoolUnit.GetFirstName() @ PoolUnit.GetLastName());		
	}

	//If we didn't actually have valid characters to import, don't even show the "all" option
	if (Items.Length == 1)
		Items.Length = 0;

	return Items; 
}

//Returns false if pool already exists
simulated function bool DoMakeEmptyPool(string NewFriendlyName)
{
	local CharacterPoolManager ExportPool;
	local string FullFileName;
	FullFileName = CharacterPoolMgr.ImportDirectoryName $ "\\" $ NewFriendlyName $ ".bin";

	if(EnumeratedFilenames.Find(FullFileName) != INDEX_NONE)
		return false;

	ExportPool = new class'CharacterPoolManager_AM'; // Changed
	ExportPool.PoolFileName = FullFileName;
	ExportPool.SaveCharacterPool();
	return true;
}


simulated public function OnConfirmDeletePoolCallback(Name eAction)
{
	local CharacterPoolManager PoolToDelete;

	if( eAction == 'eUIAction_Accept' )
	{
		PoolToDelete = new class'CharacterPoolManager_AM'; // Changed
		PoolToDelete.PoolFileName = EnumeratedFilenames[PoolToBeDeleted - (bIsExporting ? 1 : 0)]; // -1 to account for new pool button
		PoolToDelete.DeleteCharacterPool();
		UpdateData(bIsExporting);
	}
}