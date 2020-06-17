require("cargonode.nut");

class Industry extends CargoNode
{
}

function Industry::constructor(id)
{
	this.type = AIIndustry;
	this.id = id;
}

function Industry::IsCargoAccepted(cargo)
{
	return type.IsCargoAccepted(id, cargo);
}

function Industry::GetAmountOfStationsAround()
{
	return type.GetAmountOfStationsAround(id);
}

function Industry::HasHeliport()
{
	return type.HasHeliport(id);
}

function Industry::HasDock()
{
	return type.HasDock(id);
}

function Industry::GetProducingTiles(cargo, stationWidth, stationHeight, radius)
{
	local rawTileList = GetCoveredTiles(type.GetLocation(id), 1, 1, 8);
	rawTileList.Valuate(AIIndustry.GetIndustryID);
	rawTileList.KeepValue(id);
	rawTileList.Valuate(AITile.GetCargoProduction, cargo, 1, 1, 0);
	rawTileList.KeepAboveValue(0);
	local tileList = AITileList();
	foreach (tile, v in rawTileList)
	{
		tileList.AddList(GetLocationsToCoverTile(tile, stationWidth, stationHeight, radius));
	}
	tileList.Valuate(AITile.GetCargoProduction, cargo, stationWidth, stationHeight, radius);
	return tileList;
}

function Industry::GetAcceptingTiles(cargo, stationWidth, stationHeight, radius)
{
	local rawTileList = GetCoveredTiles(type.GetLocation(id), 1, 1, 8);
	rawTileList.Valuate(AIIndustry.GetIndustryID);
	rawTileList.KeepValue(id);
	rawTileList.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, 0);
	rawTileList.KeepAboveValue(7);
	local tileList = AITileList();
	foreach (tile, v in rawTileList)
	{
		tileList.AddList(GetLocationsToCoverTile(tile, stationWidth, stationHeight, radius));
	}
	tileList.Valuate(AITile.GetCargoAcceptance, cargo, stationWidth, stationHeight, radius);
	return tileList;
}