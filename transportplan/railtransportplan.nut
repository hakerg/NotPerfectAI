require("transportplan.nut");
require("../pathfinder.nut");

class RailTransportPlan extends TransportPlan
{
	railType = null;
	wagon = null;
	wagonAmount = null;
	maxWagonsPerTrain = null;
	cargoMass = null;
	maxStationLength = null;
	
	availableWagons = null;
	sourceStationData = null;
	targetStationData = null;
	path = null;
}

function RailTransportPlan::CalculatePowerSpeed(wagonCount, includeCargo, incline)
{
	local mass_t = AIEngine.GetWeight(engine) + AIEngine.GetWeight(wagon) * wagonCount;
	if (includeCargo)
	{
		local cargoMass_t = aiInstance.engineManager.GetCapacity(wagon, cargo) * wagonCount;
		if (AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS))
		{
			cargoMass_t = cargoMass_t * 0.05;
		}
		else if (AICargo.HasCargoClass(cargo, AICargo.CC_MAIL))
		{
			cargoMass_t = cargoMass_t * 0.25;
		}
		else
		{
			cargoMass_t *= AIGameSettings.GetValue("vehicle.freight_trains");
		}
		mass_t += cargoMass_t;
	}
	local force_N = mass_t * (100 + 100 * incline);
	if (AIEngine.GetMaxTractiveEffort(engine) * 1000 < force_N)
	{
		return 2;
	}
	else
	{
		local power_W = AIEngine.GetPower(engine) * 735.5;
		local speed_m_s = power_W / force_N;
		return speed_m_s * 3.6 / 1.00584;
	}
}

function RailTransportPlan::ChangeEngineAndWagon(engine, wagon)
{
	this.engine = engine;
	this.wagon = wagon;
	
	maxWagonsPerTrain = (maxStationLength * 16 - aiInstance.engineManager.GetLength(engine)) / aiInstance.engineManager.GetLength(wagon);
	if (maxWagonsPerTrain <= 0)
	{
		score = 0;
		return;
	}
	local speed = AIEngine.GetMaxSpeed(engine);
	local maxSpeed = CalculatePowerSpeed(maxWagonsPerTrain, true, AIGameSettings.GetValue("vehicle.train_slope_stepness") * 0.25);
	if (speed > maxSpeed)
	{
		speed = maxSpeed;
	}
	local wagonSpeed = AIEngine.GetMaxSpeed(wagon);
	if (wagonSpeed > 0 && wagonSpeed < speed)
	{
		speed = wagonSpeed;
	}
	local railSpeed = AIRail.GetMaxSpeed(railType);
	if (railSpeed > 0 && speed > railSpeed)
	{
		speed = railSpeed;
	}
	speed *= GetReliabilitySpeedFactor(engine);
	deliveryTimeDays = routeLength / GetTilesPerDay(speed) + 10.0;
	if (deliveryTimeDays > 182)
	{
		score = 0;
		return;
	}
	monthlyDeliveryPerUnit = aiInstance.engineManager.GetCapacity(wagon, cargo) * 15.0 / deliveryTimeDays;
	wagonAmount = (monthlySupply / monthlyDeliveryPerUnit).tointeger() + 1;
	if (wagonAmount <= 0)
	{
		score = 0;
		return;
	}
	if (wagonAmount > routeLength)
	{
		wagonAmount = routeLength;
	}
	
	/*amount = wagonAmount / maxWagonsPerTrain;
	if (amount * maxWagonsPerTrain < wagonAmount)
	{
		amount++;
	}*/
	
	amount = 1;
	if (wagonAmount > maxWagonsPerTrain)
	{
		wagonAmount = maxWagonsPerTrain;
	}
	
	if (sourceStationData == null)
	{
		if (amount > 1)
		{
			maxStationLength = (aiInstance.engineManager.GetLength(engine) + aiInstance.engineManager.GetLength(wagon) * maxWagonsPerTrain + 15) / 16;
		}
		else
		{
			maxStationLength = (aiInstance.engineManager.GetLength(engine) + aiInstance.engineManager.GetLength(wagon) * wagonAmount + 15) / 16;
		}
	}
	
	maxMonthlyDelivery = wagonAmount * monthlyDeliveryPerUnit;
	CalculateDelivery();
	monthlyIncome = AICargo.GetCargoIncome(cargo, distance, deliveryTimeDays.tointeger()) * monthlyDelivery;
	monthlyIncome -= monthlyMaintenanceCost + (amount * AIEngine.GetRunningCost(engine) + wagonAmount * AIEngine.GetRunningCost(wagon)) / 12.0;
	cost = infrastructureCost + (AIRail.GetBuildCost(railType, AIRail.BT_STATION) + aiInstance.clearCost) * maxStationLength * 2 + AIEngine.GetPrice(engine) * amount + AIEngine.GetPrice(wagon) * wagonAmount;
	score = monthlyIncome / cost;
}

function RailTransportPlan::constructor(source, target, cargo, engine, wagon, railType)
{
	this.source = source;
	this.target = target;
	this.cargo = cargo;
	this.distance = AIMap.DistanceManhattan(source.GetLocation(), target.GetLocation());
	this.routeLength = CalculateDiagonalDistance(source.GetLocation(), target.GetLocation()) * 1.25;
	
	this.maxStationLength = AIGameSettings.GetValue("vehicle.max_train_length");
	if (AIGameSettings.GetValue("station.station_spread") < maxStationLength)
	{
		this.maxStationLength = AIGameSettings.GetValue("station.station_spread");
	}
	
	this.useExistingSourceStation = false;
	this.useExistingTargetStation = false;
	this.vehicleType = AIVehicle.VT_RAIL;
	this.railType = railType;
	this.monthlyMaintenanceCost = 0;
	this.infrastructureCost = (AIRail.GetBuildCost(railType, AIRail.BT_DEPOT) + aiInstance.clearCost) * 2;
	this.infrastructureCost += distance * (AIRail.GetBuildCost(railType, AIRail.BT_TRACK) + aiInstance.clearCost);
	CalculateSupply();
	ChangeEngineAndWagon(engine, wagon);
}

function RailTransportPlan::GetStationRadius(isSource)
{
	return AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
}

function RailTransportPlan::GetAvailableVehicleCount()
{
	return AIGameSettings.GetValue("vehicle.max_trains") - GetVehicleCount(AIVehicle.VT_RAIL);
}

function RailTransportPlan::GetStationCoveredTiles(stationLocation, isSource)
{
	local width = null;
	local height = null;
	local stationData = null;
	if (isSource)
	{
		stationData = sourceStationData;
	}
	else
	{
		stationData = targetStationData;
	}
	local width = (stationData[1] == AIRail.RAILTRACK_NE_SW ? stationData[3] : stationData[2]);
	local height = (stationData[1] == AIRail.RAILTRACK_NW_SE ? stationData[3] : stationData[2]);
	return GetCoveredTiles(stationLocation, width, height, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
}

function RailTransportPlan::GetStationData(isSource)
{
	local testMode = AITestMode();
	local directions = [AIRail.RAILTRACK_NW_SE, AIRail.RAILTRACK_NE_SW];
	for (local length = maxStationLength; length >= 1; length--)
	{
		for (local perons = 1; perons >= 1; perons--)
		{
			local bestData = null;
			local bestValue = null;
			foreach (direction in directions)
			{
				local width = (direction == AIRail.RAILTRACK_NE_SW ? length : perons);
				local height = (direction == AIRail.RAILTRACK_NW_SE ? length : perons);
				local tileList = null;
				if (isSource)
				{
					tileList = source.GetProducingTiles(cargo, width, height, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
				}
				else
				{
					tileList = target.GetAcceptingTiles(cargo, width, height, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
				}
				foreach (tile, value in tileList)
				{
					local checkTile = null;
					if (direction == AIRail.RAILTRACK_NE_SW)
					{
						checkTile = GoToTile(tile, [-1, 0]);
					}
					else
					{
						checkTile = GoToTile(tile, [0, -1]);
					}
					if (!AIRail.IsRailTile(tile) && BuildWrapper(AIRail.BuildRailStation, [checkTile, direction, perons, length + 2, AIStation.STATION_NEW], true))
					{
						if (bestValue != null || value > bestValue)
						{
							bestData = [tile, direction, perons, length];
							bestValue = value;
						}
						break;
					}
				}
			}
			if (bestData != null)
			{
				return bestData;
			}
		}
	}
	return null;
}

function RailTransportPlan::SetBestEngine()
{
	PrintInfo("Finding best engine and wagon");
	BuyAndRegisterEngines();
	availableEngines = aiInstance.engineManager.GetRailEngines(railType);
	availableWagons = aiInstance.engineManager.GetWagons(railType, cargo);
	PrintInfo("Checking " + availableEngines.Count() * availableWagons.Count() + " engine-wagon pairs");
	local bestEngineAndWagon = null;
	local bestScore = null;
	foreach (testedEngine, v in availableEngines)
	{
		foreach (testedWagon, v in availableWagons)
		{
			ChangeEngineAndWagon(testedEngine, testedWagon);
			if (!CheckDistance())
			{
				continue;
			}
			if (bestEngineAndWagon == null || score > bestScore)
			{
				bestEngineAndWagon = [engine, wagon];
				bestScore = score;
			}
		}
	}
	if (bestEngineAndWagon == null)
	{
		score = 0;
		return;
	}
	ChangeEngineAndWagon(bestEngineAndWagon[0], bestEngineAndWagon[1]);
	PrintInfo("Selected:");
	PrintInfo("Engine: " + AIEngine.GetName(engine));
	PrintInfo("Amount: " + amount);
	PrintInfo("Engine cost: " + AIEngine.GetPrice(engine));
	PrintInfo("Wagon: " + AIEngine.GetName(wagon));
	PrintInfo("Amount: " + wagonAmount);
	PrintInfo("Wagon cost: " + AIEngine.GetPrice(wagon));
	PrintInfo("Reimbursement: " + GetReimbursementMonths() + " months")
}

function RailTransportPlan::BuyVehicle(index)
{
	if (engine == null)
	{
		PrintWarning("Invalid engine");
		return false;
	}
	local vehicleID = VehicleBuildWrapper(AIVehicle.BuildVehicle, [depot, engine], true);
	if (vehicleID == null)
	{
		PrintWarning(AIError.GetLastErrorString());
		return false;
	}
	local lengthBefore = aiInstance.engineManager.GetLength(engine);
	aiInstance.engineManager.RegisterVehicleInDepot(vehicleID);
	local lengthAfter = aiInstance.engineManager.GetLength(engine);
	if (lengthBefore != lengthAfter)
	{
		PrintInfo("Updated length of the engine from " + lengthBefore + " to " + lengthAfter);
		PrintInfo("Selling and looking for best engine and wagon again");
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
	local wagonBuildCount = maxWagonsPerTrain;
	if (index == amount - 1)
	{
		wagonBuildCount = wagonAmount - (amount - 1) * maxWagonsPerTrain;
	}
	for (local wagonIndex = 0; wagonIndex < wagonBuildCount; wagonIndex++)
	{
		local wagonID = VehicleBuildWrapper(AIVehicle.BuildVehicleWithRefit, [depot, wagon, cargo], true);
		if (wagonID == null)
		{
			PrintWarning(AIError.GetLastErrorString());
			AIVehicle.SellVehicle(vehicleID);
			return false;
		}
		local lengthBefore = aiInstance.engineManager.GetLength(wagon);
		local capacityBefore = aiInstance.engineManager.GetCapacity(wagon, cargo);
		aiInstance.engineManager.RegisterVehicleInDepot(wagonID);
		local lengthAfter = aiInstance.engineManager.GetLength(wagon);
		local capacityAfter = aiInstance.engineManager.GetCapacity(wagon, cargo);
		if (lengthBefore != lengthAfter || capacityBefore != capacityAfter)
		{
			PrintInfo("Updated wagon parameters");
			PrintInfo("Selling and looking for best engine and wagon again");
			AIVehicle.SellVehicle(wagonID);
			AIVehicle.SellVehicle(vehicleID);
			SetBestEngine();
			return BuyVehicle(index);
		}
		else
		{
			if (score <= 0)
			{
				PrintWarning("Calculated negative income");
				AIVehicle.SellVehicle(wagonID);
				AIVehicle.SellVehicle(vehicleID);
				return false;
			}
		}
		if (!AIVehicle.MoveWagon(wagonID, 0, vehicleID, 0))
		{
			PrintWarning("Cannot attach wagon");
			PrintWarning(AIError.GetLastErrorString());
			PrintInfo("Selling and looking for best engine and wagon again");
			aiInstance.engineManager.invalidRailEngines.append(engine);
			AIVehicle.SellVehicle(wagonID);
			AIVehicle.SellVehicle(vehicleID);
			SetBestEngine();
			return BuyVehicle(index);
		}
	}
	AIGroup.MoveVehicle(groupID, vehicleID);
	RenameWrapper(AIVehicle.SetName, [vehicleID, name + ": " + (index + 1) + " / " + amount]);
	if (runningVehicles.len() == 0)
	{
		local targetFlags = AIOrder.OF_UNLOAD | AIOrder.OF_NON_STOP_INTERMEDIATE;
		local serviceFlags = AIOrder.OF_NON_STOP_INTERMEDIATE;
		local sourceFlags = targetFlags | AIOrder.OF_FULL_LOAD_ANY;
		if (!AIOrder.AppendOrder(vehicleID, sourceStationLocation, sourceFlags))
		{
			PrintWarning(AIError.GetLastErrorString());
			PrintWarning("Invalid source station, selling");
			AIVehicle.SellVehicle(vehicleID);
			return false;
		}
		AIOrder.AppendOrder(vehicleID, depot, serviceFlags);
		if (!AIOrder.AppendOrder(vehicleID, targetStationLocation, targetFlags))
		{
			PrintWarning(AIError.GetLastErrorString());
			PrintWarning("Invalid target station, selling");
			AIVehicle.SellVehicle(vehicleID);
			return false;
		}
		for (local o = 0; o < AIOrder.GetOrderCount(vehicleID); o++)
		{
			AIOrder.SetStopLocation(vehicleID, o, AIOrder.STOPLOCATION_NEAR);
		}
	}
	else
	{
		AIOrder.ShareOrders(vehicleID, runningVehicles[0]);
	}
	if (!AIVehicle.StartStopVehicle(vehicleID))
	{
		PrintWarning("Vehicle cannot start, selling");
		AIVehicle.SellVehicle(vehicleID);
		return false;
	}
	else
	{
		runningVehicles.append(vehicleID);
		if (runningVehicles.len() == 1)
		{
			if (!(source.id in aiInstance.servedPlansByID))
			{
				aiInstance.servedPlansByID[source.id] <- [];
			}
			aiInstance.servedPlansByID[source.id].append(this);
		}
		return true;
	}
}

function RailTransportPlan::BuildTrack(fromTile, fromOrientation, toTiles, toOrientation)
{
	path = FindRailPath(fromTile, fromOrientation, toTiles, toOrientation, 32768, null);
	if (path == null)
	{
		return false;
	}
	PrintInfo("Building rail");
	local retries = 0;
	local indexBefore = 0;
	routeLength = sourceStationData[3];
	for (local i = 1; i < path.len(); i++)
	{
		local buildResult = null;
		local length = AIMap.DistanceManhattan(path[i - 1].tile, path[i].tile);
		if (path[i].IsAlongAxis())
		{
			routeLength += length;
		}
		else
		{
			routeLength = routeLength + length * 0.7;
		}
		if (length == 1)
		{
			if (AIRail.IsRailStationTile(path[i].tile))
			{
				buildResult = true;
				indexBefore = i;
			}
			else
			{
				if (i == path.len() - 1 || !path[i].IsInLine(path[i + 1]) || AIMap.DistanceManhattan(path[i].tile, path[i + 1].tile) > 1 || AIRail.IsRailStationTile(path[i + 1].tile))
				{
					buildResult = BuildWrapper(AIRail.BuildRail, [path[indexBefore].tile, path[indexBefore + 1].tile, path[i].GetNextPieces(path[i - 1].tile)[0].tile], true);
					indexBefore = i;
				}
				else
				{
					buildResult = true;
				}
			}
		}
		else
		{
			indexBefore = i;
			local bridgeStart = GoToTile(path[i - 1].tile, GetDirection(path[i - 1].tile, path[i].tile));
			local bridgeList = AIBridgeList_Length(length);
			bridgeList.Valuate(AIBridge.GetMaxSpeed);
			local bridgeID = bridgeList.Begin();
			buildResult = BuildWrapper(AIBridge.BuildBridge, [AIVehicle.VT_RAIL, bridgeID, bridgeStart, path[i].tile], true);
		}
		if (!buildResult)
		{
			PrintWarning(AIError.GetLastErrorString());
			if (retries < 8)
			{
				retries++;
				PrintInfo("Building failed from " + TileToString(path[i - 1].tile) + " to " + TileToString(path[i].tile) + ", finding new path");
				PrintInfo("Retries: " + retries + " / 8");
				path = FindRailPath(fromTile, fromOrientation, toTiles, toOrientation, 32768, null);
				if (path == null)
				{
					return false;
				}
				else
				{
					i = 0;
					indexBefore = 0;
					routeLength = sourceStationData[3];
				}
			}
			else
			{
				PrintWarning("Too many attempts");
				return false;
			}
		}
	}
	return true;
}

function RailTransportPlan::BuildPath()
{
	local oldRailType = AIRail.GetCurrentRailType();
	PrintInfo("Set rail type to " + AIRail.GetName(railType));
	AIRail.SetCurrentRailType(railType);
	local nextTarget = null;
	if (targetStationData[1] == AIRail.RAILTRACK_NE_SW)
	{
		nextTarget = GoToTile(targetStationData[0], [targetStationData[3] - 1, 0]);
	}
	else
	{
		nextTarget = GoToTile(targetStationData[0], [0, targetStationData[3] - 1]);
	}
	if (!BuildTrack(sourceStationData[0], sourceStationData[1], [targetStationData[0], nextTarget], targetStationData[1]))
	{
		PrintInfo("Revert rail type to " + AIRail.GetName(oldRailType));
		AIRail.SetCurrentRailType(oldRailType);
		return false;
	}
	PrintInfo("Revert rail type to " + AIRail.GetName(oldRailType));
	AIRail.SetCurrentRailType(oldRailType);
	return true;
}

function RailTransportPlan::Realize()
{
	SetName();
	PrintInfo("Building:");
	Print();
	PrintInfo("Wagon: " + AIEngine.GetName(wagon));
	PrintInfo("Wagon amount: " + wagonAmount);
	PrintInfo("");
	PrintInfo("Set rail type to " + AIRail.GetName(railType));
	AIRail.SetCurrentRailType(railType);
	PrintInfo("Finding location for source station");
	sourceStationData = GetStationData(true);
	if (sourceStationData == null)
	{
		return false;
	}
	sourceStationLocation = sourceStationData[0];
	if (sourceStationData[3] < maxStationLength)
	{
		maxStationLength = sourceStationData[3];
	}
	PrintInfo("Finding location for target station");
	targetStationData = GetStationData(false);
	if (targetStationData == null)
	{
		return false;
	}
	targetStationLocation = targetStationData[0];
	if (targetStationData[3] < maxStationLength)
	{
		maxStationLength = targetStationData[3];
	}
	distance = AIMap.DistanceManhattan(sourceStationLocation, targetStationLocation);
	PrintInfo("Distance between stations: " + distance);
	if (!CheckDistance())
	{
		return false;
	}
	local sourceIndustry = null;
	if (source.type == AIIndustry)
	{
		sourceIndustry = AIIndustry.GetIndustryType(source.id);
	}
	else
	{
		sourceIndustry = AIIndustryType.INDUSTRYTYPE_TOWN;
	}
	local targetIndustry = null;
	if (target.type == AIIndustry)
	{
		targetIndustry = AIIndustry.GetIndustryType(target.id);
	}
	else
	{
		targetIndustry = AIIndustryType.INDUSTRYTYPE_TOWN;
	}
	PrintInfo("Building source station");
	if (!BuildWrapper(AIRail.BuildNewGRFRailStation, [sourceStationData[0], sourceStationData[1], sourceStationData[2], sourceStationData[3], AIStation.STATION_NEW, cargo, sourceIndustry, targetIndustry, distance, true], true))
	{
		return false;
	}
	PrintInfo("Building target station");
	if (!BuildWrapper(AIRail.BuildNewGRFRailStation, [targetStationData[0], targetStationData[1], targetStationData[2], targetStationData[3], AIStation.STATION_NEW, cargo, sourceIndustry, targetIndustry, distance, false], true))
	{
		return false;
	}
	if (!BuildPath())
	{
		return false;
	}
	PrintInfo("Building depots");
	local possibleDepotLocations = [];
	if (sourceStationData[1] == AIRail.RAILTRACK_NE_SW)
	{
		possibleDepotLocations.append([GoToTile(sourceStationData[0], [-1, 0]), sourceStationData[0]]);
		possibleDepotLocations.append([GoToTile(sourceStationData[0], [sourceStationData[3], 0]), GoToTile(sourceStationData[0], [sourceStationData[3] - 1, 0])]);
	}
	else
	{
		possibleDepotLocations.append([GoToTile(sourceStationData[0], [0, -1]), sourceStationData[0]]);
		possibleDepotLocations.append([GoToTile(sourceStationData[0], [0, sourceStationData[3]]), GoToTile(sourceStationData[0], [0, sourceStationData[3] - 1])]);
	}
	if (targetStationData[1] == AIRail.RAILTRACK_NE_SW)
	{
		possibleDepotLocations.append([GoToTile(targetStationData[0], [-1, 0]), targetStationData[0]]);
		possibleDepotLocations.append([GoToTile(targetStationData[0], [targetStationData[3], 0]), GoToTile(targetStationData[0], [targetStationData[3] - 1, 0])]);
	}
	else
	{
		possibleDepotLocations.append([GoToTile(targetStationData[0], [0, -1]), targetStationData[0]]);
		possibleDepotLocations.append([GoToTile(targetStationData[0], [0, targetStationData[3]]), GoToTile(targetStationData[0], [0, targetStationData[3] - 1])]);
	}
	foreach (possibleDepotLocation in possibleDepotLocations)
	{
		if (BuildWrapper(AIRail.BuildRailDepot, possibleDepotLocation, true))
		{
			if (depot == null)
			{
				depot = possibleDepotLocation[0];
			}
		}
	}
	if (depot == null)
	{
		return false;
	}
	BuyVehicles();
	if (runningVehicles.len() > 0)
	{
		RenameStations();
		ExtendRangeForTowns();
		aiInstance.planIndex++;
		return true;
	}
	else
	{
		return false;
	}
}