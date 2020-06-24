require("transportplan.nut");
require("pathfinder.nut");

class WaterTransportPlan extends TransportPlan
{
	path = null;
	pathStart = null;
	pathEnd = null;
}

function WaterTransportPlan::constructor(source, target, cargo, engine)
{
	this.source = source;
	this.target = target;
	this.cargo = cargo;
	this.distance = AIMap.DistanceManhattan(source.GetLocation(), target.GetLocation());
	this.routeLength = distance;
	
	this.vehicleType = AIVehicle.VT_WATER;
	this.useExistingSourceStation = source.HasDock();
	if (useExistingSourceStation)
	{
		this.sourceStationLocation = source.GetDockLocation();
	}
	this.useExistingTargetStation = target.HasDock();
	if (useExistingTargetStation)
	{
		this.targetStationLocation = target.GetDockLocation();
	}
	this.monthlyMaintenanceCost = 0;
	this.infrastructureCost = (distance / 32 + 1) * AIMarine.GetBuildCost(AIMarine.BT_DEPOT);
	if (!useExistingSourceStation)
	{
		this.infrastructureCost += AIMarine.GetBuildCost(AIMarine.BT_DOCK);
	}
	if (!useExistingTargetStation)
	{
		this.infrastructureCost += AIMarine.GetBuildCost(AIMarine.BT_DOCK);
	}
	CalculateSupply();
	ChangeEngine(engine);
}

function WaterTransportPlan::GetStationRadius(isSource)
{
	return AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
}

function WaterTransportPlan::GetAvailableVehicleCount()
{
	return AIGameSettings.GetValue("vehicle.max_ships") - GetVehicleCount(AIVehicle.VT_WATER);
}

function WaterTransportPlan::GetStationCoveredTiles(stationLocation, isSource)
{
	if (isSource && source.HasDock())
	{
		return AITileList();
	}
	else if (!isSource && target.HasDock())
	{
		return AITileList();
	}
	return GetCoveredTiles(stationLocation, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
}

function WaterTransportPlan::GetDockLocation(isSource, useExisting)
{
	local testMode = AITestMode();
	local tileList = null;
	if (isSource)
	{
		tileList = source.GetProducingTiles(cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
	}
	else
	{
		tileList = target.GetAcceptingTiles(cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
	}
	foreach (tile, v in tileList)
	{
		if (useExisting)
		{
			if (AIMarine.IsDockTile(tile) && AICompany.IsMine(AITile.GetOwner(tile)) && AITile.GetSlope(tile) != AITile.SLOPE_FLAT)
			{
				return tile;
			}
		}
		else
		{
			if (BuildWrapper(AIMarine.BuildDock, [tile, AIStation.STATION_NEW], true))
			{
				return tile;
			}
		}
	}
	return null;
}

function WaterTransportPlan::GetDockingPoint(dockLocation)
{
	if (dockLocation == null)
	{
		return null;
	}
	local neighbor = null;
	switch (AITile.GetSlope(dockLocation))
	{
		case AITile.SLOPE_NW:
			neighbor = [0, 1];
			break;
		case AITile.SLOPE_SW:
			neighbor = [-1, 0];
			break;
		case AITile.SLOPE_SE:
			neighbor = [0, -1];
			break;
		case AITile.SLOPE_NE:
			neighbor = [1, 0];
			break;
		default:
			return null;
	}
	return GoToTile(GoToTile(dockLocation, neighbor), neighbor);
}

function WaterTransportPlan::BuildPath()
{
	path = FindWaterPath(pathStart, pathEnd, 4096);
	if (path != null)
	{
		routeLength = path.len() - 1;
		return true;
	}
	else
	{
		return false;
	}
}

function WaterTransportPlan::Realize()
{
	SetName();
	PrintInfo("Building:");
	Print();
	if (useExistingSourceStation)
	{
		PrintInfo("Use source industry's dock");
		pathStart = sourceStationLocation;
	}
	else
	{
		PrintInfo("Finding location for source dock");
		sourceStationLocation = GetDockLocation(true, true);
		if (sourceStationLocation != null)
		{
			PrintInfo("Found existing dock");
			useExistingSourceStation = true;
		}
		else
		{
			sourceStationLocation = GetDockLocation(true, false);
		}
		pathStart = GetDockingPoint(sourceStationLocation);
	}
	if (sourceStationLocation == null)
	{
		return false;
	}
	if (useExistingTargetStation)
	{
		PrintInfo("Use target industry's dock");
		pathEnd = targetStationLocation;
	}
	else
	{
		PrintInfo("Finding location for target dock");
		targetStationLocation = GetDockLocation(false, true);
		if (targetStationLocation != null)
		{
			PrintInfo("Found existing dock");
			useExistingTargetStation = true;
		}
		else
		{
			targetStationLocation = GetDockLocation(false, false);
		}
		pathEnd = GetDockingPoint(targetStationLocation);
	}
	if (targetStationLocation == null)
	{
		return false;
	}
	distance = AIMap.DistanceManhattan(sourceStationLocation, targetStationLocation);
	PrintInfo("Distance between docks: " + distance);
	if (!BuildPath())
	{
		return false;
	}
	if (!useExistingSourceStation)
	{
		PrintInfo("Building source dock");
		if (!BuildWrapper(AIMarine.BuildDock, [sourceStationLocation, AIStation.STATION_NEW], true))
		{
			return false;
		}
	}
	if (!useExistingTargetStation)
	{
		PrintInfo("Building target dock");
		if (!BuildWrapper(AIMarine.BuildDock, [targetStationLocation, AIStation.STATION_NEW], true))
		{
			return false;
		}
	}
	PrintInfo("Building water depots");
	midpoints = [];
	for (local i = 4; i < path.len() - 5;)
	{
		if (AITile.IsWaterTile(path[i - 2]) && AITile.IsWaterTile(path[i - 1]) && AITile.IsWaterTile(path[i + 1]) && AITile.IsWaterTile(path[i + 2])
			&& AreOnOneLine([path[i - 2], path[i - 1], path[i], path[i + 1], path[i + 2]])
			&& !AIMarine.IsWaterDepotTile(path[i - 2]) && !AIMarine.IsWaterDepotTile(path[i - 1]) && !AIMarine.IsWaterDepotTile(path[i + 1]) && !AIMarine.IsWaterDepotTile(path[i + 2]))
		{
			if ((AIMarine.IsWaterDepotTile(path[i]) && AICompany.IsMine(AITile.GetOwner(path[i]))) || BuildWrapper(AIMarine.BuildWaterDepot, [path[i], path[i + 1]], true))
			{
				if (depot == null)
				{
					depot = path[i];
				}
				midpoints.append(path[i]);
				i += 32;
				continue;
			}
		}
		i++;
	}
	if (depot == null)
	{
		return false;
	}
	availableEngines = aiInstance.engineManager.GetWaterEngines(cargo);
	BuyVehicles();
	if (runningVehicles.len() > 0)
	{
		FinalizeBuild();
		return true;
	}
	else
	{
		return false;
	}
}