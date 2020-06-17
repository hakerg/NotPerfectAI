require("transportplan/roadtransportplan.nut");
require("transportplan/airtransportplan.nut");
require("transportplan/watertransportplan.nut");
require("transportplan/railtransportplan.nut");

class PlanList
{
	engineManager = null;
	planArray = null;
	planList = null;
	expires = null;
}

function PlanList::AlreadyServed(source, cargo)
{
	if (!(source.id in aiInstance.servedPlansByID))
	{
		return false;
	}
	foreach (plan in aiInstance.servedPlansByID[source.id])
	{
		if ((plan.source.IsEqualTo(source) || (plan.bidirectional && plan.target.IsEqualTo(source))) && plan.cargo == cargo)
		{
			return true;
		}
	}
	return false;
}

function PlanList::IsFailed(source, target, vehicleType)
{
	if (!(source.id in aiInstance.failedPlansByID))
	{
		return false;
	}
	foreach (plan in aiInstance.failedPlansByID[source.id])
	{
		if (plan.vehicleType == vehicleType)
		{
			if (plan.source.IsEqualTo(source) && plan.sourceStationLocation == null)
			{
				return true;
			}
			if (plan.target.IsEqualTo(target) && plan.targetStationLocation == null)
			{
				return true;
			}
			if (plan.source.IsEqualTo(source) && plan.target.IsEqualTo(target))
			{
				return true;
			}
		}
	}
	return false;
}

function PlanList::IsFailedAir(source, target, planeType)
{
	if (!(source.id in aiInstance.failedPlansByID))
	{
		return false;
	}
	foreach (plan in aiInstance.failedPlansByID[source.id])
	{
		if (plan.vehicleType == AIVehicle.VT_AIR && plan.planeType == planeType)
		{
			if (plan.source.IsEqualTo(source) && plan.sourceStationLocation == null)
			{
				return true;
			}
			if (plan.target.IsEqualTo(target) && plan.targetStationLocation == null)
			{
				return true;
			}
			if (plan.source.IsEqualTo(source) && plan.target.IsEqualTo(target))
			{
				return true;
			}
		}
	}
	return false;
}

function PlanList::IsFailedPlan(plan)
{
	if (plan.vehicleType == AIVehicle.VT_AIR)
	{
		return IsFailedAir(plan.source, plan.target, plan.planeType);
	}
	else
	{
		return IsFailed(plan.source, plan.target, plan.vehicleType);
	}
}

function PlanList::IsValidSource(source, cargo)
{
	return source.GetLastMonthProduction(cargo) > 0
		&& source.GetLastMonthTransportedPercentage(cargo) <= 25
		&& !PlanList.AlreadyServed(source, cargo)
		&& source.GetAmountOfStationsAround() <= aiInstance.maxStationCount;
}

function PlanList::AddPlansForConnection(source, target, cargo)
{
	local sourceLocation = source.GetLocation();
	local targetLocation = target.GetLocation();
	foreach (roadEngineRoadType in engineManager.bestRoadEnginesWithRoadTypes[cargo])
	{
		local maxDistance = AIEngine.GetMaximumOrderDistance(roadEngineRoadType[0]);
		if (maxDistance != 0 && maxDistance < AIOrder.GetOrderDistance(AIVehicle.VT_ROAD, sourceLocation, targetLocation))
		{
			continue;
		}
		local plan = RoadTransportPlan(source, target, cargo, roadEngineRoadType[0], roadEngineRoadType[1]);
		if (plan.score <= 0)
		{
			continue;
		}
		planArray.append(plan);
	}
	foreach (airEngine in engineManager.bestAirEngines[cargo])
	{
		local maxDistance = AIEngine.GetMaximumOrderDistance(airEngine);
		if (maxDistance != 0 && maxDistance < AIOrder.GetOrderDistance(AIVehicle.VT_AIR, sourceLocation, targetLocation))
		{
			continue;
		}
		local plan = AirTransportPlan(source, target, cargo, airEngine);
		if (plan.score <= 0)
		{
			continue;
		}
		planArray.append(plan);
	}
	foreach (waterEngine in engineManager.bestWaterEngines[cargo])
	{
		local plan = WaterTransportPlan(source, target, cargo, waterEngine);
		if (plan.score <= 0)
		{
			continue;
		}
		planArray.append(plan);
	}
	foreach (railEngineAndWagonRailType in engineManager.bestRailEnginesAndWagonsWithRailTypes[cargo])
	{
		local railEngine = railEngineAndWagonRailType[0];
		local wagon = railEngineAndWagonRailType[1];
		local maxDistance = AIEngine.GetMaximumOrderDistance(railEngine);
		if (maxDistance != 0 && maxDistance < AIOrder.GetOrderDistance(AIVehicle.VT_RAIL, sourceLocation, targetLocation))
		{
			continue;
		}
		local plan = RailTransportPlan(source, target, cargo, railEngine, wagon, railEngineAndWagonRailType[2]);
		if (plan.score <= 0)
		{
			continue;
		}
		planArray.append(plan);
	}
}

function PlanList::SortByPriority()
{
	PrintInfo("Sorting");
	this.planList = AIList();
	foreach (index, plan in planArray)
	{
		this.planList.AddItem(index, (plan.score * 1000000).tointeger());
	}
}

function PlanList::constructor(iterations)
{
	this.engineManager = aiInstance.engineManager;
	this.planArray = [];
	local cargoList = AICargoList();
	local iterationsPerCargo = iterations / cargoList.Count() + 1;
	PrintInfo("Creating plan list, iterations per cargo: " + iterationsPerCargo + ", max source stations: " + aiInstance.maxStationCount);
	engineManager.ValidateBestEngines();
	local townList = AITownList();
	townList.Valuate(AITown.GetPopulation);
	foreach (cargo, income in cargoList)
	{
		local sources = [];
		local targets = [];
		if (AIController.GetSetting("buildIndustryConnections"))
		{
			local sourceList = AIIndustryList_CargoProducing(cargo);
			sourceList.Valuate(AIIndustry.GetLastMonthProduction, cargo);
			sourceList.KeepAboveValue(0);
			foreach (source, v in sourceList)
			{
				if (sources.len() >= iterationsPerCargo)
				{
					break;
				}
				local node = Industry(source);
				if (IsValidSource(node, cargo))
				{
					sources.append(node);
				}
			}
		}
		if (AIController.GetSetting("buildTownConnections") && AICargo.GetTownEffect(cargo) == AICargo.TE_PASSENGERS || AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL)
		{
			local addedTowns = 0;
			foreach (town, v in townList)
			{
				if (addedTowns >= iterationsPerCargo)
				{
					break;
				}
				local node = Town(town);
				if (IsValidSource(node, cargo))
				{
					sources.append(node);
					addedTowns++;
				}
			}
		}
		if (sources.len() == 0)
		{
			//PrintInfo(AICargo.GetCargoLabel(cargo) + ": no more sources");
			continue;
		}
		if (AIController.GetSetting("buildIndustryConnections"))
		{
			local targetList = AIIndustryList_CargoAccepting(cargo);
			foreach (target, v in targetList)
			{
				//if (targets.len() >= iterationsPerCargo)
				//{
				//	break;
				//}
				targets.append(Industry(target));
			}
		}
		if (AIController.GetSetting("buildTownConnections") && AICargo.GetTownEffect(cargo) != AICargo.TE_NONE)
		{
			local addedTowns = 0;
			foreach (town, v in townList)
			{
				//if (addedTowns >= iterationsPerCargo)
				//{
				//	break;
				//}
				targets.append(Town(town));
				addedTowns++;
			}
		}
		if (targets.len() == 0)
		{
			//PrintInfo(AICargo.GetCargoLabel(cargo) + ": no more targets");
			continue;
		}
		if (engineManager.bestRoadEnginesWithRoadTypes[cargo].len() == 0 &&
			engineManager.bestAirEngines[cargo].len() == 0 &&
			engineManager.bestWaterEngines[cargo].len() == 0 &&
			engineManager.bestRailEnginesAndWagonsWithRailTypes[cargo].len() == 0)
		{
			//PrintInfo(AICargo.GetCargoLabel(cargo) + ": no engine can transport this cargo");
			continue;
		}
		local connectionAmount = sources.len() * targets.len();
		if (connectionAmount > iterationsPerCargo)
		{
			//PrintInfo(AICargo.GetCargoLabel(cargo) + ": checking random connections");
			for (local i = 0; i < iterationsPerCargo; i++)
			{
				local source = sources[AIBase.RandRange(sources.len())];
				local target = targets[AIBase.RandRange(targets.len())];
				if (source.IsEqualTo(target))
				{
					continue;
				}
				AddPlansForConnection(source, target, cargo);
			}
		}
		else
		{
			//PrintInfo(AICargo.GetCargoLabel(cargo) + ": checking all " + connectionAmount + " possible connections");
			foreach (source in sources)
			{
				foreach (target in targets)
				{
					if (source.IsEqualTo(target))
					{
						continue;
					}
					AddPlansForConnection(source, target, cargo);
				}
			}
		}
	}
	PrintInfo("Found " + planArray.len() + " plans");
	SortByPriority();
	PrintInfo("Finding finished");
	this.expires = AIDate.GetCurrentDate() + 90;
}

function PlanList::PopBest()
{
	if (planList.Count() == 0)
	{
		return null;
	}
	local availableMoney = GetAvailableMoney();
	if (availableMoney < 0)
	{
		PrintInfo("No money");
		return null;
	}
	local hasIncome = (AIVehicleList().Count() > 0);
	local item = planList.Begin();
	local minScore = null;
	PrintInfo("Picking best affordable plan");
	while (!planList.IsEnd())
	{
		local plan = planArray[item];
		if (hasIncome && minScore != null && plan.score < minScore)
		{
			break;
		}
		if (!IsValidSource(plan.source, plan.cargo) || IsFailedPlan(plan) || plan.GetAvailableVehicleCount() == 0)
		{
			item = planList.Next();
			planList.RemoveItem(item);
			continue;
		}
		if (minScore == null)
		{
			minScore = plan.score * 0.5;
		}
		if (plan.cost >= availableMoney || (!hasIncome && plan.deliveryTimeDays > 60))
		{
			item = planList.Next();
		}
		else
		{
			return plan;
		}
	}
	return null;
}