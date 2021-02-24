require("cargonode.nut");

class Town extends CargoNode
{
}

function Town::constructor(id)
{
	this.type = AITown;
	this.id = id;
}

function Town::IsCargoAccepted(cargo)
{
	if (AICargo.GetTownEffect(cargo) == AICargo.TE_NONE)
	{
		return AIIndustry.CAS_NOT_ACCEPTED;
	}
	else
	{
		return AIIndustry.CAS_ACCEPTED;
	}
}

function Town::GetAmountOfStationsAround()
{
	local stationList = AIStationList(AIStation.STATION_ANY);
	stationList.Valuate(AIStation.IsWithinTownInfluence, id);
	stationList.KeepValue(1);
	return stationList.Count();
}

function Town::HasHeliport()
{
	return false;
}

function Town::HasDock()
{
	return false;
}

function Town::GetAuthorityTiles()
{
	local tileList = GetCoveredTiles(type.GetLocation(id), 1, 1, 64);
	tileList.Valuate(AITile.GetTownAuthority);
	tileList.KeepValue(id);
	return tileList;
}

function Town::GetProducingTiles(cargo, stationWidth, stationHeight, radius)
{
	local tileList = GetAuthorityTiles();
	tileList.Valuate(AITile.GetCargoProduction, cargo, stationWidth, stationHeight, radius);
	tileList.KeepAboveValue(0);
	return tileList;
}

function Town::GetAcceptingTiles(cargo, stationWidth, stationHeight, radius)
{
	local tileList = GetAuthorityTiles();
	tileList.Valuate(AITile.GetCargoAcceptance, cargo, stationWidth, stationHeight, radius);
	tileList.KeepAboveValue(7);
	return tileList;
}