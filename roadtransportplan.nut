require("transportplan.nut");
require("pathfinder.nut");

class RoadTransportPlan extends TransportPlan
{
	roadType = null;
	buildStopType = null;
	roadVehicleType = null;
	stationType = null;
	
	sourceStationData = null;
	targetStationData = null;
	path = null;
	targetDepot = null;
}

function RoadTransportPlan::constructor(source, target, cargo, engine, roadType)
{
	if (source == null)
	{
		return;
	}
	this.source = source;
	this.target = target;
	this.cargo = cargo;
	this.distance = AIMap.DistanceManhattan(source.GetLocation(), target.GetLocation());
	this.routeLength = distance;
	
	this.vehicleType = AIVehicle.VT_ROAD;
	this.roadType = roadType;
	if (AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS))
	{
		this.buildStopType = AIRoad.BT_BUS_STOP;
		this.roadVehicleType = AIRoad.ROADVEHTYPE_BUS;
		this.stationType = AIStation.STATION_BUS_STOP;
	}
	else
	{
		this.buildStopType = AIRoad.BT_TRUCK_STOP;
		this.roadVehicleType = AIRoad.ROADVEHTYPE_TRUCK;
		this.stationType = AIStation.STATION_TRUCK_STOP;
	}
	this.monthlyMaintenanceCost = 0;
	this.infrastructureCost = (AIRoad.GetBuildCost(roadType, AIRoad.BT_DEPOT) + AIRoad.GetBuildCost(roadType, AIRoad.BT_ROAD) + aiInstance.clearCost) * 2;
	this.infrastructureCost += (AIRoad.GetBuildCost(roadType, buildStopType) + aiInstance.clearCost) * 2;
	this.infrastructureCost += (distance + 4) * (AIRoad.GetBuildCost(roadType, AIRoad.BT_ROAD) * 2 + aiInstance.clearCost);
	CalculateSupply();
	ChangeEngine(engine);
}

function RoadTransportPlan::GetStationRadius(isSource)
{
	return AIStation.GetCoverageRadius(stationType);
}

function RoadTransportPlan::GetAvailableVehicleCount()
{
	return AIGameSettings.GetValue("vehicle.max_roadveh") - GetVehicleCount(AIVehicle.VT_ROAD);
}

function RoadTransportPlan::GetStationCoveredTiles(stationLocation, isSource)
{
	return GetCoveredTiles(stationLocation, 1, 1, AIStation.GetCoverageRadius(stationType));
}

function RoadTransportPlan::BuildStop(location, direction, roundabout)
{
	local nextTile = GoToTile(location, direction);
	if (!BuildWrapper(AIRoad.BuildDriveThroughRoadStation, [location, nextTile, roadVehicleType, AIStation.STATION_NEW], true))
	{
		return false;
	}
	if (!BuildWrapper(AIRoad.BuildRoad, [location, nextTile], true) || !PathNode.CanHaveCurve(AITile.GetSlope(nextTile)))
	{
		return false;
	}
	direction = Rotate(direction, 1);
	location = nextTile;
	nextTile = GoToTile(location, direction);
	if (!BuildWrapper(AIRoad.BuildRoad, [location, nextTile], true) || !PathNode.CanHaveCurve(AITile.GetSlope(nextTile)))
	{
		return !roundabout;
	}
	direction = Rotate(direction, 1);
	location = nextTile;
	nextTile = GoToTile(location, direction);
	if (!BuildWrapper(AIRoad.BuildRoad, [location, nextTile], true) || !PathNode.CanHaveCurve(AITile.GetSlope(nextTile)))
	{
		return !roundabout;
	}
	location = nextTile;
	nextTile = GoToTile(location, direction);
	if (!BuildWrapper(AIRoad.BuildRoad, [location, nextTile], true) || !PathNode.CanHaveCurve(AITile.GetSlope(nextTile)))
	{
		return !roundabout;
	}
	direction = Rotate(direction, 1);
	location = nextTile;
	nextTile = GoToTile(location, direction);
	if (!BuildWrapper(AIRoad.BuildRoad, [location, nextTile], true) || !PathNode.CanHaveCurve(AITile.GetSlope(nextTile)))
	{
		return !roundabout;
	}
	direction = Rotate(direction, 1);
	location = nextTile;
	nextTile = GoToTile(location, direction);
	if (!BuildWrapper(AIRoad.BuildRoad, [location, nextTile], true) || !PathNode.CanHaveCurve(AITile.GetSlope(nextTile)))
	{
		return !roundabout;
	}
	return true;
}

function RoadTransportPlan::GetStopDirection(location, roundabout)
{
	local testMode = AITestMode();
	foreach (neighbor in neighbors)
	{
		if (BuildStop(location, neighbor, roundabout))
		{
			return neighbor;
		}
	}
	return null;
}

function RoadTransportPlan::GetStopDataRoundabout(isSource, roundabout)
{
	local tileList = null;
	if (isSource)
	{
		tileList = source.GetProducingTiles(cargo, 1, 1, AIStation.GetCoverageRadius(stationType));
	}
	else
	{
		tileList = target.GetAcceptingTiles(cargo, 1, 1, AIStation.GetCoverageRadius(stationType));
	}
	foreach (tile, v in tileList)
	{
		local direction = GetStopDirection(tile, roundabout);
		if (direction != null)
		{
			return [tile, direction, roundabout];
		}
	}
	return null;
}

function RoadTransportPlan::GetStopData(isSource, tryRoundabout)
{
	local node = null;
	if (isSource)
	{
		node = source;
	}
	else
	{
		node = target;
	}
	if (node.type == AIIndustry && tryRoundabout)
	{
		local data = GetStopDataRoundabout(isSource, true);
		if (data != null)
		{
			return data;
		}
		PrintInfo("Trying without roundabout");
	}
	local data = GetStopDataRoundabout(isSource, false);
	if (data != null)
	{
		return data;
	}
	PrintWarning("No suitable station location");
	return null;
}

function RoadTransportPlan::BuildDepot(location, front)
{
	local testMode = AITestMode();
	if (!BuildWrapper(AIRoad.BuildRoadDepot, [location, front], true))
	{
		return false;
	}
	if (!BuildWrapper(AIRoad.BuildRoad, [location, front], true))
	{
		return false;
	}
	local execMode = AIExecMode();
	if (!BuildWrapper(AIRoad.BuildRoadDepot, [location, front], true))
	{
		return false;
	}
	if (!BuildWrapper(AIRoad.BuildRoad, [location, front], true))
	{
		return false;
	}
	return true;
}

function RoadTransportPlan::BuildPath()
{
	local oldRoadType = AIRoad.GetCurrentRoadType();
	PrintInfo("Set road type to " + AIRoad.GetName(roadType));
	AIRoad.SetCurrentRoadType(roadType);
	path = FindRoadPath(sourceStationData[0], targetStationData[0], 16384, sourceStationData[1]);
	if (path == null)
	{
		PrintInfo("Revert road type to " + AIRoad.GetName(oldRoadType));
		AIRoad.SetCurrentRoadType(oldRoadType);
		return false;
	}
	PrintInfo("Building road");
	local retries = 0;
	local roadBegin = path[0];
	routeLength = 0;
	for (local i = 1; i < path.len(); i++)
	{
		local buildResult = null;
		local length = AIMap.DistanceManhattan(path[i - 1], path[i]);
		routeLength += length;
		if (length == 1)
		{
			if (i == path.len() - 1 || !AreOnOneLine([roadBegin, path[i + 1]]) || AIMap.DistanceManhattan(path[i], path[i + 1]) > 1)
			{
				buildResult = BuildWrapper(AIRoad.BuildRoad, [roadBegin, path[i]], true);
				roadBegin = path[i];
			}
			else
			{
				buildResult = true;
			}
		}
		else
		{
			roadBegin = path[i];
			local bridgeStart = GoToTile(path[i - 1], GetDirection(path[i - 1], path[i]));
			local bridgeList = AIBridgeList_Length(length);
			bridgeList.Valuate(AIBridge.GetMaxSpeed);
			local bridgeID = bridgeList.Begin();
			buildResult = BuildWrapper(AIBridge.BuildBridge, [AIVehicle.VT_ROAD, bridgeID, bridgeStart, path[i]], true);
			if (buildResult)
			{
				buildResult = BuildWrapper(AIRoad.BuildRoad, [path[i - 1], bridgeStart], true);
			}
		}
		if (!buildResult)
		{
			PrintWarning(AIError.GetLastErrorString());
			if (retries < 8)
			{
				retries++;
				PrintInfo("Building failed from " + TileToString(path[i - 1]) + " to " + TileToString(path[i]) + ", finding new path");
				PrintInfo("Retries: " + retries + " / 8");
				path = FindRoadPath(sourceStationData[0], targetStationData[0], 16384, sourceStationData[1]);
				if (path == null)
				{
					PrintInfo("Revert road type to " + AIRoad.GetName(oldRoadType));
					AIRoad.SetCurrentRoadType(oldRoadType);
					return false;
				}
				else
				{
					i = 0;
					roadBegin = path[0];
					routeLength = 0;
				}
			}
			else
			{
				PrintWarning("Too many attempts");
				PrintInfo("Revert road type to " + AIRoad.GetName(oldRoadType));
				AIRoad.SetCurrentRoadType(oldRoadType);
				return false;
			}
		}
	}
	PrintInfo("Revert road type to " + AIRoad.GetName(oldRoadType));
	AIRoad.SetCurrentRoadType(oldRoadType);
	return true;
}

function RoadTransportPlan::Realize()
{
	SetName();
	PrintInfo("Building:");
	Print();
	PrintInfo("Set road type to " + AIRoad.GetName(roadType));
	AIRoad.SetCurrentRoadType(roadType);
	PrintInfo("Finding location for source station");
	sourceStationData = GetStopData(true, true);
	if (sourceStationData == null)
	{
		return false;
	}
	sourceStationLocation = sourceStationData[0];
	PrintInfo("Finding location for target station");
	targetStationData = GetStopData(false, false);
	if (targetStationData == null)
	{
		return false;
	}
	targetStationLocation = targetStationData[0];
	distance = AIMap.DistanceManhattan(sourceStationLocation, targetStationLocation);
	PrintInfo("Distance between stations: " + distance);
	if (!CheckDistance())
	{
		return false;
	}
	PrintInfo("Building source station");
	if (!BuildStop(sourceStationData[0], sourceStationData[1], false))
	{
		PrintWarning(AIError.GetLastErrorString());
		return false;
	}
	PrintInfo("Building target station");
	if (!BuildWrapper(AIRoad.BuildDriveThroughRoadStation, [targetStationData[0], GoToTile(targetStationData[0], targetStationData[1]), roadVehicleType, AIStation.STATION_NEW], true))
	{
		PrintWarning(AIError.GetLastErrorString());
		return false;
	}
	if (!BuildPath())
	{
		return false;
	}
	PrintInfo("Building depots");
	for (local i = 0; i < path.len() && depot == null; i++)
	{
		foreach (neighbor in neighbors)
		{
			local depotTile = GoToTile(path[i], neighbor);
			if (BuildDepot(depotTile, path[i]))
			{
				depot = depotTile;
				break;
			}
		}
	}
	if (depot == null)
	{
		return false;
	}
	for (local i = path.len() - 1; i >= 0 && targetDepot == null; i--)
	{
		foreach (neighbor in neighbors)
		{
			local depotTile = GoToTile(path[i], neighbor);
			if (BuildDepot(depotTile, path[i]))
			{
				targetDepot = depotTile;
				break;
			}
		}
	}
	midpoints = [];
	availableEngines = aiInstance.engineManager.GetRoadEngines(roadType, cargo);
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