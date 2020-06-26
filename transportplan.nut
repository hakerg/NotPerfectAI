require("enginemanager.nut");
require("utils.nut");
require("investment.nut");
require("industry.nut");
require("town.nut");

class TransportPlan extends Investment
{
	vehicleType = null;
	source = null;
	target = null;
	cargo = null;
	distance = null;
	routeLength = null;
	monthlySupply = null;
	targetMonthlySupply = null;
	
	engine = null;
	amount = null;
	deliveryTimeDays = null;
	monthlyDeliveryPerUnit = null;
	maxMonthlyDelivery = null;
	monthlyDelivery = null;
	infrastructureCost = null;
	monthlyMaintenanceCost = null;
	bidirectional = null;
	
	name = null;
	useExistingSourceStation = null;
	useExistingTargetStation = null;
	sourceStationLocation = null;
	targetStationLocation = null;
	depot = null;
	runningVehicles = null;
	groupID = null;
	midpoints = null;
	availableEngines = null;
}

function TransportPlan::GetCoveredHouses(stationRadius)
{
	if (AIGameSettings.GetValue("station.distant_join_stations"))
	{
		stationRadius += AIGameSettings.GetValue("station.station_spread") - 1;
	}
	return stationRadius * stationRadius * 0.6;
}

function TransportPlan::GetNodeProduction(industry, isSource)
{
	if (industry.type == AIIndustry)
	{
		return industry.GetLastMonthProduction(cargo);
	}
	else
	{
		local houses = AITown.GetHouseCount(industry.id);
		local coveredHouses = GetCoveredHouses(GetStationRadius(isSource));
		if (coveredHouses >= houses)
		{
			return industry.GetLastMonthProduction(cargo);
		}
		else
		{
			return industry.GetLastMonthProduction(cargo) * coveredHouses / houses;
		}
	}
}

function TransportPlan::CalculateSupply()
{
	monthlySupply = GetNodeProduction(source, true) * 0.8;
	if (source.IsCargoAccepted(cargo) == AIIndustry.CAS_ACCEPTED && PlanList.IsValidSource(target, cargo))
	{
		bidirectional = true;
		targetMonthlySupply = GetNodeProduction(target, false) * 0.4;
	}
	else
	{
		bidirectional = false;
		targetMonthlySupply = 0;
	}
}

function TransportPlan::CalculateDelivery()
{
	if (maxMonthlyDelivery < monthlySupply)
	{
		monthlyDelivery = maxMonthlyDelivery;
	}
	else
	{
		monthlyDelivery = monthlySupply;
	}
	if (maxMonthlyDelivery < targetMonthlySupply)
	{
		monthlyDelivery += maxMonthlyDelivery;
	}
	else
	{
		monthlyDelivery += targetMonthlySupply;
	}
}

function TransportPlan::ChangeEngine(engine)
{
	this.engine = engine;
	
	local speed = AIEngine.GetMaxSpeed(engine);
	if (vehicleType == AIVehicle.VT_ROAD)
	{
		local maxSpeed = AIRoad.GetMaxSpeed(roadType) * 2;
		if (maxSpeed > 0 && speed > maxSpeed)
		{
			speed = maxSpeed;
		}
	}
	else if (vehicleType == AIVehicle.VT_AIR)
	{
		speed /= AIGameSettings.GetValue("vehicle.plane_speed");
	}
	speed *= GetReliabilitySpeedFactor(engine);
	deliveryTimeDays = routeLength / GetTilesPerDay(speed) + 10.0;
	if (deliveryTimeDays > 123)
	{
		score = 0;
		return;
	}
	monthlyDeliveryPerUnit = aiInstance.engineManager.GetCapacity(engine, cargo) * 15.0 / deliveryTimeDays;
	amount = (monthlySupply / monthlyDeliveryPerUnit).tointeger() + 1;
	local maxAmount = (routeLength / 2).tointeger();
	if (amount > maxAmount)
	{
		amount = maxAmount;
	}
	maxMonthlyDelivery = amount * monthlyDeliveryPerUnit;
	CalculateDelivery();
	monthlyIncome = AICargo.GetCargoIncome(cargo, distance, deliveryTimeDays.tointeger()) * monthlyDelivery;
	monthlyIncome -= AIEngine.GetRunningCost(engine) * amount / 12.0 + monthlyMaintenanceCost;
	cost = infrastructureCost + AIEngine.GetPrice(engine) * amount;
	score = monthlyIncome * 1000 / cost;
}

function TransportPlan::Print()
{
	PrintInfo("");
	PrintInfo("Transport plan " + name + ":");
	switch (vehicleType)
	{
		case AIVehicle.VT_RAIL:
			PrintInfo("Rail");
			break;
		case AIVehicle.VT_ROAD:
			PrintInfo("Road");
			break;
		case AIVehicle.VT_WATER:
			PrintInfo("Water");
			break;
		case AIVehicle.VT_AIR:
			PrintInfo("Air");
			break;
	}
	PrintInfo("Source: " + source.GetName());
	PrintInfo("Target: " + target.GetName());
	PrintInfo("Cargo: " + AICargo.GetCargoLabel(cargo));
	if (bidirectional)
	{
		PrintInfo("Bidirectional");
		PrintInfo("Target monthly supply: " + targetMonthlySupply.tointeger());
	}
	PrintInfo("Monthly supply: " + monthlySupply.tointeger());
	PrintInfo("Engine: " + AIEngine.GetName(engine));
	PrintInfo("Amount: " + amount);
	PrintInfo("Delivery time: " + deliveryTimeDays.tointeger() + " days");
	PrintInfo("Monthly income: " + monthlyIncome.tointeger());
	PrintInfo("Total cost: " + cost);
	PrintInfo("The cost will be reimbursed after: " + GetReimbursementMonths() + " months");
	PrintInfo("");
}

function TransportPlan::SetName()
{
	name = "AI" + aiInstance.aiIndexString + " - " + aiInstance.planIndex + " " + AICargo.GetCargoLabel(cargo);
}

function TransportPlan::FinalizeBuild()
{
	if (!(source.id in aiInstance.cargoLocksByID))
	{
		aiInstance.cargoLocksByID[source.id] <- [];
	}
	aiInstance.cargoLocksByID[source.id].append([cargo, AIDate.GetCurrentDate() + 90]);
	aiInstance.planIndex++;
	if (AIController.GetSetting("renameStations"))
	{
		PrintInfo("Renaming stations");
		if (bidirectional)
		{
			if (!useExistingSourceStation)
			{
				RenameWrapper(AIBaseStation.SetName, [AIStation.GetStationID(sourceStationLocation), name + " major"]);
			}
			if (!useExistingTargetStation)
			{
				RenameWrapper(AIBaseStation.SetName, [AIStation.GetStationID(targetStationLocation), name + " minor"]);
			}
		}
		else
		{
			if (!useExistingSourceStation)
			{
				RenameWrapper(AIBaseStation.SetName, [AIStation.GetStationID(sourceStationLocation), name + " source"]);
			}
			if (!useExistingTargetStation)
			{
				RenameWrapper(AIBaseStation.SetName, [AIStation.GetStationID(targetStationLocation), name + " target"]);
			}
		}
	}
	ExtendRangeForStations();
}

function TransportPlan::CheckDistance()
{
	local maxDistance = AIEngine.GetMaximumOrderDistance(engine);
	if (maxDistance != 0 && maxDistance < AIOrder.GetOrderDistance(vehicleType, sourceStationLocation, targetStationLocation))
	{
		PrintWarning("Stations too far apart");
		return false;
	}
	return true;
}

function TransportPlan::BuyAndRegisterEngines()
{
	local engines = AIEngineList(vehicleType);
	foreach (engine, v in engines)
	{
		if (!aiInstance.engineManager.IsRegistered(engine))
		{
			local vehicleID = VehicleBuildWrapper(AIVehicle.BuildVehicle, [depot, engine], false);
			if (vehicleID == null)
			{
				continue;
			}
			aiInstance.engineManager.RegisterVehicleInDepot(vehicleID);
			AIVehicle.SellVehicle(vehicleID);
		}
	}
}

function TransportPlan::SetBestEngine()
{
	PrintInfo("Finding best engine");
	BuyAndRegisterEngines();
	PrintInfo("Checking " + availableEngines.Count() + " engines");
	local bestEngine = null;
	local bestScore = null;
	foreach (testedEngine, v in availableEngines)
	{
		ChangeEngine(testedEngine);
		if (!CheckDistance())
		{
			continue;
		}
		if (bestEngine == null || score > bestScore)
		{
			bestEngine = engine;
			bestScore = score;
		}
	}
	if (bestEngine == null)
	{
		score = 0;
		return;
	}
	ChangeEngine(bestEngine);
	PrintInfo("Selected:");
	PrintInfo("Engine: " + AIEngine.GetName(engine));
	PrintInfo("Amount: " + amount);
	PrintInfo("Engine cost: " + AIEngine.GetPrice(engine));
	PrintInfo("Reimbursement: " + GetReimbursementMonths() + " months");
}

function TransportPlan::BuyVehicle(index)
{
	if (engine == null)
	{
		PrintWarning("Invalid engine");
		return false;
	}
	local vehicleID = null;
	if (runningVehicles.len() == 0)
	{
		vehicleID = VehicleBuildWrapper(AIVehicle.BuildVehicleWithRefit, [depot, engine, cargo], true);
		if (vehicleID == null)
		{
			PrintWarning(AIError.GetLastErrorString());
			return false;
		}
		local capacityBefore = aiInstance.engineManager.GetCapacity(engine, cargo);
		aiInstance.engineManager.RegisterVehicleInDepot(vehicleID);
		local capacityAfter = aiInstance.engineManager.GetCapacity(engine, cargo);
		if (capacityBefore != capacityAfter)
		{
			PrintInfo("Updated capacity of the engine from " + capacityBefore + " to " + capacityAfter);
			PrintInfo("Selling and looking for best engine again");
			AIVehicle.SellVehicle(vehicleID);
			SetBestEngine();
			return BuyVehicle(index);
		}
		else
		{
			if (score <= 0)
			{
				PrintWarning("Calculated negative income");
				AIVehicle.SellVehicle(vehicleID);
				return false;
			}
		}
		AIGroup.MoveVehicle(groupID, vehicleID);
		local targetFlags = null;
		local midpointFlags = null;
		if (vehicleType == AIVehicle.VT_ROAD || vehicleType == AIVehicle.VT_RAIL)
		{
			targetFlags = AIOrder.OF_UNLOAD | AIOrder.OF_NON_STOP_INTERMEDIATE;
			midpointFlags = AIOrder.OF_NON_STOP_INTERMEDIATE | AIOrder.OF_NON_STOP_DESTINATION;
		}
		else
		{
			targetFlags = AIOrder.OF_UNLOAD;
			midpointFlags = 0;
		}
		local sourceFlags = targetFlags | AIOrder.OF_FULL_LOAD_ANY;
		if (vehicleType == AIVehicle.VT_AIR && planeType == AIAirport.PT_HELICOPTER && source.HasHeliport())
		{
			sourceFlags = targetFlags;
		}
		if (!AIOrder.AppendOrder(vehicleID, sourceStationLocation, sourceFlags))
		{
			PrintWarning(AIError.GetLastErrorString());
			PrintWarning("Invalid source station, selling");
			AIVehicle.SellVehicle(vehicleID);
			return false;
		}
		for (local i = 0; i < midpoints.len(); i++)
		{
			AIOrder.AppendOrder(vehicleID, midpoints[i], midpointFlags);
		}
		if (!AIOrder.AppendOrder(vehicleID, targetStationLocation, targetFlags))
		{
			PrintWarning(AIError.GetLastErrorString());
			PrintWarning("Invalid target station, selling");
			AIVehicle.SellVehicle(vehicleID);
			return false;
		}
		for (local i = midpoints.len() - 1; i >= 0; i--)
		{
			AIOrder.AppendOrder(vehicleID, midpoints[i], midpointFlags);
		}
	}
	else
	{
		vehicleID = VehicleBuildWrapper(AIVehicle.CloneVehicle, [depot, runningVehicles[0], true], true);
		if (vehicleID == null)
		{
			PrintWarning(AIError.GetLastErrorString());
			return false;
		}
	}
	if (!AIVehicle.StartStopVehicle(vehicleID))
	{
		PrintWarning("Vehicle cannot start, selling");
		AIVehicle.SellVehicle(vehicleID);
		return false;
	}
	else
	{
		RenameWrapper(AIVehicle.SetName, [vehicleID, name + ": " + (index + 1) + " / " + amount]);
		runningVehicles.append(vehicleID);
		return true;
	}
}

function TransportPlan::BuyVehicles()
{
	PrintInfo("Create vehicle group");
	groupID = AIGroup.CreateGroup(vehicleType, AIGroup.GROUP_INVALID);
	RenameWrapper(AIGroup.SetName, [groupID, name]);
	PrintInfo("Building vehicles");
	SetBestEngine();
	runningVehicles = [];
	local motherVehicle = null;
	for (local i = 0; i < amount; i++)
	{
		if (!BuyVehicle(i))
		{
			break;
		}
	}
	PrintInfo("Running vehicles: " + runningVehicles.len() + " / " + amount);
}

function TransportPlan::ExtendRange(stationType, roadVehicleType, stationLocation, isSource)
{
	local cargoNode = null;
	if (isSource)
	{
		cargoNode = source;
	}
	else
	{
		cargoNode = target;
	}
	local tilesToCover = GetCoveredTiles(stationLocation, 1, 1, AIGameSettings.GetValue("station.station_spread") - 1);
	tilesToCover.Valuate(AITile.GetCargoProduction, cargo, 1, 1, 0);
	tilesToCover.KeepAboveValue(0);
	if (cargoNode.type == AIIndustry)
	{
		tilesToCover.RemoveList(cargoNode.GetProducingTiles(cargo, 1, 1, 0));
	}
	local removeList = GetStationCoveredTiles(stationLocation, isSource);
	foreach (tile, v in removeList)
	{
		local industryID = AIIndustry.GetIndustryID(tile);
		if (AIIndustry.IsValidIndustry(industryID))
		{
			tilesToCover.RemoveList(Industry(industryID).GetProducingTiles(cargo, 1, 1, 0));
		}
	}
	tilesToCover.RemoveList(removeList);
	local radius = AIStation.GetCoverageRadius(stationType);
	while (!tilesToCover.IsEmpty())
	{
		local tileToCover = tilesToCover.Begin();
		tilesToCover.RemoveItem(tileToCover);
		local stationTiles = GetCoveredTiles(tileToCover, 1, 1, radius);
		stationTiles.Valuate(AITile.GetDistanceSquareToTile, tileToCover);
		stationTiles.Sort(AIList.SORT_BY_VALUE, true);
		foreach (stationTile, v in stationTiles)
		{
			if (BuildWrapper(AIRoad.BuildDriveThroughRoadStation, [stationTile, GoToTile(stationTile, [1, 0]), roadVehicleType, AIStation.GetStationID(stationLocation)], true) ||
				BuildWrapper(AIRoad.BuildDriveThroughRoadStation, [stationTile, GoToTile(stationTile, [0, 1]), roadVehicleType, AIStation.GetStationID(stationLocation)], true))
			{
				local removeList = GetCoveredTiles(stationTile, 1, 1, radius);
				foreach (tile, v in removeList)
				{
					local industryID = AIIndustry.GetIndustryID(tile);
					if (AIIndustry.IsValidIndustry(industryID))
					{
						tilesToCover.RemoveList(Industry(industryID).GetProducingTiles(cargo, 1, 1, 0));
					}
				}
				tilesToCover.RemoveList(removeList);
				break;
			}
		}
	}
}

function TransportPlan::ExtendRangeForStations()
{
	PrintInfo("Extending range for stations");
	local stationType = null;
	local buildType = null;
	local roadVehicleType = null;
	if (AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS))
	{
		stationType = AIStation.STATION_BUS_STOP;
		buildType = AIRoad.BT_BUS_STOP;
		roadVehicleType = AIRoad.ROADVEHTYPE_BUS;
	}
	else
	{
		stationType = AIStation.STATION_TRUCK_STOP;
		buildType = AIRoad.BT_TRUCK_STOP;
		roadVehicleType = AIRoad.ROADVEHTYPE_TRUCK;
	}
	local roadTypeList = AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD);
	roadTypeList.AddList(AIRoadTypeList(AIRoad.ROADTRAMTYPES_TRAM));
	local bestRoadType = null;
	local cost = null;
	foreach (roadType in roadTypeList)
	{
		local area = AIStation.GetCoverageRadius(stationType);
		area = (area * 2 + 1) * (area * 2 + 1) - 1;
		local newCost = AIRoad.GetBuildCost(roadType, buildType) * 1000 / area;
		if (cost == null || newCost < cost)
		{
			bestRoadType = roadType;
			cost = newCost;
		}
	}
	if (bestRoadType == null)
	{
		return;
	}
	PrintInfo("Set road type to " + AIRoad.GetName(bestRoadType));
	AIRoad.SetCurrentRoadType(bestRoadType);
	ExtendRange(stationType, roadVehicleType, sourceStationLocation, true);
	if (bidirectional)
	{
		ExtendRange(stationType, roadVehicleType, targetStationLocation, false);
	}
}