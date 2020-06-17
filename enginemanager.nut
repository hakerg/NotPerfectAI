class EngineManager
{
	rememberedCapacities = {};
	rememberedLengths = {};
	bestRoadEnginesWithRoadTypes = {};
	bestAirEngines = {};
	bestWaterEngines = {};
	bestRailEnginesAndWagonsWithRailTypes = {};
	outOfDate = true;
	invalidRailEngines = [];
}

function EngineManager::IsRegistered(engineID)
{
	return engineID in rememberedLengths;
}

function EngineManager::RegisterVehicleInDepot(vehicleID)
{
	local engineID = AIVehicle.GetEngineType(vehicleID);
	if (!IsRegistered(engineID))
	{
		aiInstance.planList = null;
		rememberedLengths[engineID] <- AIVehicle.GetLength(vehicleID);
		rememberedCapacities[engineID] <- {};
		local cargoList = AICargoList();
		foreach (cargo, v in cargoList)
		{
			rememberedCapacities[engineID][cargo] <- AIVehicle.GetRefitCapacity(vehicleID, cargo);
		}
	}
}

function EngineManager::GetCapacity(engineID, cargo)
{
	if (IsRegistered(engineID))
	{
		return rememberedCapacities[engineID][cargo];
	}
	else
	{
		return AIEngine.GetCapacity(engineID);
	}
}

function EngineManager::GetLength(engineID)
{
	if (IsRegistered(engineID))
	{
		return rememberedLengths[engineID];
	}
	else
	{
		return 8;
	}
}

function EngineManager::RoadEngineScore(engine, cargo, roadType)
{
	local speed = AIEngine.GetMaxSpeed(engine);
	local maxSpeed = AIRoad.GetMaxSpeed(roadType) * 2;
	if (maxSpeed > 0 && speed > maxSpeed)
	{
		speed = maxSpeed;
	}
	return (aiInstance.engineManager.GetCapacity(engine, cargo) * speed * GetReliabilitySpeedFactor(engine) * 1000 / AIEngine.GetPrice(engine)).tointeger();
}

function EngineManager::AirWaterEngineScore(engine, cargo)
{
	return (aiInstance.engineManager.GetCapacity(engine, cargo) * AIEngine.GetMaxSpeed(engine) * GetReliabilitySpeedFactor(engine) * 1000 / AIEngine.GetPrice(engine)).tointeger();
}

function EngineManager::RailEngineScore(engine)
{
	return (AIEngine.GetPower(engine) * GetReliabilitySpeedFactor(engine) * 10000 / AIEngine.GetPrice(engine)).tointeger();
}

function EngineManager::WagonScore(engine, cargo, maxAllowedSpeed)
{
	local wagonMaxSpeed = AIEngine.GetMaxSpeed(engine);
	if (wagonMaxSpeed > 0 && wagonMaxSpeed < maxAllowedSpeed)
	{
		maxAllowedSpeed = wagonMaxSpeed;
	}
	return aiInstance.engineManager.GetCapacity(engine, cargo) * maxAllowedSpeed * 1000 / AIEngine.GetPrice(engine);
}

function EngineManager::GetRoadEngines(roadType, cargo)
{
	local engineList = AIEngineList(AIVehicle.VT_ROAD);
	engineList.Valuate(AIEngine.IsBuildable);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.CanRefitCargo, cargo);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.HasPowerOnRoad, roadType);
	engineList.KeepValue(1);
	return engineList;
}

function EngineManager::GetAirEngines(planeType, cargo)
{
	local engineList = AIEngineList(AIVehicle.VT_AIR);
	engineList.Valuate(AIEngine.IsBuildable);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.CanRefitCargo, cargo);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.GetPlaneType);
	engineList.KeepValue(planeType);
	return engineList;
}

function EngineManager::GetWaterEngines(cargo)
{
	local engineList = AIEngineList(AIVehicle.VT_WATER);
	engineList.Valuate(AIEngine.IsBuildable);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.CanRefitCargo, cargo);
	engineList.KeepValue(1);
	return engineList;
}

function EngineManager::GetRailEngines(railType)
{
	local engineList = AIEngineList(AIVehicle.VT_RAIL);
	engineList.Valuate(AIEngine.IsBuildable);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.HasPowerOnRail, railType);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.IsWagon);
	engineList.KeepValue(0);
	engineList.Valuate(AIEngine.GetCapacity);
	engineList.KeepBelowValue(1);
	foreach (engine in invalidRailEngines)
	{
		engineList.RemoveItem(engine);
	}
	return engineList;
}

function EngineManager::GetWagons(railType, cargo)
{
	local engineList = AIEngineList(AIVehicle.VT_RAIL);
	engineList.Valuate(AIEngine.IsBuildable);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.CanRefitCargo, cargo);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.CanRunOnRail, railType);
	engineList.KeepValue(1);
	engineList.Valuate(AIEngine.IsWagon);
	engineList.KeepValue(1);
	return engineList;
}

function EngineManager::SetBestRoadEngines(cargo)
{
	bestRoadEnginesWithRoadTypes[cargo] <- [];
	if (AIController.GetSetting("useRoad") && !AIGameSettings.GetValue("ai.ai_disable_veh_roadveh"))
	{
		local roadTypeList = AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD);
		roadTypeList.AddList(AIRoadTypeList(AIRoad.ROADTRAMTYPES_TRAM));
		foreach (roadType, v in roadTypeList)
		{
			local engineList = GetRoadEngines(roadType, cargo);
			if (engineList.Count() == 0)
			{
				continue;
			}
			engineList.Valuate(RoadEngineScore, cargo, roadType);
			bestRoadEnginesWithRoadTypes[cargo].append([engineList.Begin(), roadType]);
		}
	}
}

function EngineManager::SetBestAirEngines(cargo)
{
	bestAirEngines[cargo] <- [];
	if (AIController.GetSetting("usePlanes") && !AIGameSettings.GetValue("ai.ai_disable_veh_aircraft"))
	{
		local planeTypeList = [AIAirport.PT_HELICOPTER, AIAirport.PT_SMALL_PLANE, AIAirport.PT_BIG_PLANE];
		foreach (planeType in planeTypeList)
		{
			local engineList = GetAirEngines(planeType, cargo);
			if (engineList.Count() == 0)
			{
				continue;
			}
			engineList.Valuate(AirWaterEngineScore, cargo);
			bestAirEngines[cargo].append(engineList.Begin());
		}
	}
}

function EngineManager::SetBestWaterEngines(cargo)
{
	bestWaterEngines[cargo] <- [];
	if (AIController.GetSetting("useShips") && !AIGameSettings.GetValue("ai.ai_disable_veh_ship"))
	{
		local engineList = GetWaterEngines(cargo);
		if (engineList.Count() == 0)
		{
			return;
		}
		engineList.Valuate(AirWaterEngineScore, cargo);
		bestWaterEngines[cargo].append(engineList.Begin());
	}
}

function EngineManager::SetBestRailEnginesAndWagons(cargo)
{
	bestRailEnginesAndWagonsWithRailTypes[cargo] <- [];
	if (AIController.GetSetting("useTrains") && !AIGameSettings.GetValue("ai.ai_disable_veh_train"))
	{
		local railTypeList = AIRailTypeList();
		foreach (railType, v in railTypeList)
		{
			local engineList = GetRailEngines(railType);
			if (engineList.Count() == 0)
			{
				continue;
			}
			local wagonList = GetWagons(railType, cargo);
			if (wagonList.Count() == 0)
			{
				continue;
			}
			engineList.Valuate(RailEngineScore);
			local maxSpeed = AIEngine.GetMaxSpeed(engineList.Begin());
			local railSpeed = AIRail.GetMaxSpeed(railType);
			if (railSpeed > 0 && maxSpeed > railSpeed)
			{
				maxSpeed = railSpeed;
			}
			wagonList.Valuate(WagonScore, cargo, maxSpeed);
			bestRailEnginesAndWagonsWithRailTypes[cargo].append([engineList.Begin(), wagonList.Begin(), railType]);
		}
	}
}

function EngineManager::SetBestEngines()
{
	PrintInfo("Creating list of best engines");
	local cargoList = AICargoList();
	foreach (cargo, v in cargoList)
	{
		SetBestRoadEngines(cargo);
		SetBestAirEngines(cargo);
		SetBestWaterEngines(cargo);
		SetBestRailEnginesAndWagons(cargo);
	}
	outOfDate = false;
}

function EngineManager::ValidateBestEngines()
{
	PrintInfo("Validating list of best engines");
	if (outOfDate)
	{
		PrintInfo("Engine list is out-of-date");
		SetBestEngines();
		return;
	}
	local cargoList = AICargoList();
	foreach (cargo, v in cargoList)
	{
		foreach (engineRoadType in bestRoadEnginesWithRoadTypes[cargo])
		{
			if (!AIEngine.IsBuildable(engineRoadType[0]))
			{
				SetBestRoadEngines(cargo);
				break;
			}
		}
		foreach (engine in bestAirEngines[cargo])
		{
			if (!AIEngine.IsBuildable(engine))
			{
				SetBestAirEngines(cargo);
				break;
			}
		}
		foreach (engine in bestWaterEngines[cargo])
		{
			if (!AIEngine.IsBuildable(engine))
			{
				SetBestWaterEngines(cargo);
				break;
			}
		}
		foreach (engineAndWagonRailType in bestRailEnginesAndWagonsWithRailTypes[cargo])
		{
			if (!AIEngine.IsBuildable(engineAndWagonRailType[0]))
			{
				SetBestRailEnginesAndWagons(cargo);
				break;
			}
			if (!AIEngine.IsBuildable(engineAndWagonRailType[1]))
			{
				SetBestRailEnginesAndWagons(cargo);
				break;
			}
		}
	}
}