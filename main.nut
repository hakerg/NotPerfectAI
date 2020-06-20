require("planlist.nut");

aiInstance <- null;

class NotPerfectAI extends AIController 
{
	servedPlansByID = {};
	failedPlansByID = {};
	aiIndexString = null;
	loaded = false;
	engineManager = EngineManager();
	clearCost = null;
	planIndex = 1;
	maxStationCount = 0;
	planList = null;
}

function NotPerfectAI::FindVehiclePlanIndex(vehicleID)
{
	foreach (s, servedPlans in servedPlansByID)
	{
		for (local i = 0; i < servedPlans.len(); i++)
		{
			for (local v = 0; v < servedPlans[i].runningVehicles.len(); v++)
			{
				if (servedPlans[i].runningVehicles[v] == vehicleID)
				{
					return [s, i, v];
				}
			}
		}
	}
	return null;
}

function NotPerfectAI::ProcessEvents()
{
	while (AIEventController.IsEventWaiting())
	{
		local event = AIEventController.GetNextEvent();
		switch (event.GetEventType())
		{
			case AIEvent.ET_ENGINE_PREVIEW:
			{
				event = AIEventEnginePreview.Convert(event);
				event.AcceptPreview();
				PrintInfo("Accept new engine preview: " + event.GetName());
				engineManager.outOfDate = true;
				break;
			}
			case AIEvent.ET_VEHICLE_UNPROFITABLE:
			{
				event = AIEventVehicleUnprofitable.Convert(event);
				PrintWarning(AIVehicle.GetName(event.GetVehicleID()) + " unprofitable, sending it to depot");
				AIVehicle.SendVehicleToDepot(event.GetVehicleID());
				break;
			}
			case AIEvent.ET_VEHICLE_WAITING_IN_DEPOT:
			{
				event = AIEventVehicleWaitingInDepot.Convert(event);
				PrintWarning("Selling " + AIVehicle.GetName(event.GetVehicleID()));
				local index = FindVehiclePlanIndex(event.GetVehicleID());
				servedPlansByID[index[0]][index[1]].runningVehicles.remove(index[2]);
				if (servedPlansByID[index[0]][index[1]].runningVehicles.len() == 0)
				{
					servedPlansByID[index[0]].remove(index[1]);
				}
				AIVehicle.SellVehicle(event.GetVehicleID());
				break;
			}
			case AIEvent.ET_ENGINE_AVAILABLE:
			{
				event = AIEventEngineAvailable.Convert(event);
				PrintInfo("New engine available: " + AIEngine.GetName(event.GetEngineID()));
				engineManager.outOfDate = true;
				break;
			}
			case AIEvent.ET_VEHICLE_CRASHED:
			{
				event = AIEventVehicleCrashed.Convert(event);
				switch (event.GetCrashReason())
				{
					case AIEventVehicleCrashed.CRASH_TRAIN:
						PrintError(AIVehicle.GetName(event.GetVehicleID()) + " fist-bumped another train too much.");
						break;
					case AIEventVehicleCrashed.CRASH_RV_LEVEL_CROSSING:
						PrintError(AIVehicle.GetName(event.GetVehicleID()) + " was sliced by a train.");
						break;
					case AIEventVehicleCrashed.CRASH_RV_UFO:
						PrintError(AIVehicle.GetName(event.GetVehicleID()) + " was kidnapped by UFO.");
						break;
					case AIEventVehicleCrashed.CRASH_PLANE_LANDING:
						PrintError("The pilot of " + AIVehicle.GetName(event.GetVehicleID()) + " forgot how to land a plane.");
						break;
					case AIEventVehicleCrashed.CRASH_AIRCRAFT_NO_AIRPORT:
						PrintError("The Cheater closed all airports for " + AIVehicle.GetName(event.GetVehicleID()) + ".");
						break;
					case AIEventVehicleCrashed.CRASH_FLOODED:
						PrintError(AIVehicle.GetName(event.GetVehicleID()) + " could not resist the tsunami wave.");
						break;
				}
				local index = FindVehiclePlanIndex(event.GetVehicleID());
				servedPlansByID[index[0]][index[1]].runningVehicles.remove(index[2]);
				if (servedPlansByID[index[0]][index[1]].BuyVehicle(index[2]))
				{
					PrintInfo("Replacement succeed");
				}
				else
				{
					PrintWarning("Replacement failed");
					if (servedPlansByID[index[0]][index[1]].runningVehicles.len() == 0)
					{
						servedPlansByID[index[0]].remove(index[1]);
					}
				}
				break;
			}
			case AIEvent.ET_VEHICLE_LOST:
			{
				event = AIEventVehicleLost.Convert(event);
				PrintWarning(AIVehicle.GetName(event.GetVehicleID()) + " lost, trying to fix this");
				local index = FindVehiclePlanIndex(event.GetVehicleID());
				if (!servedPlansByID[index[0]][index[1]].BuildPath())
				{
					PrintWarning("Sending the vehicle to depot");
					AIVehicle.SendVehicleToDepot(event.GetVehicleID());
				}
				else
				{
					PrintInfo("Path is fine");
				}
				break;
			}
		}
	}
	AIController.Sleep(1);
}

function NotPerfectAI::BuildHQ()
{
	local townList = AITownList();
	townList.Valuate(AITown.GetPopulation);
	foreach (townID, v in townList)
	{
		local location = AITown.GetLocation(townID);
		local tileList = AITileList();
		local x1 = AIMap.GetTileX(location) - 16;
		if (x1 < 1)
		{
			x1 = 1;
		}
		local y1 = AIMap.GetTileY(location) - 16;
		if (y1 < 1)
		{
			y1 = 1;
		}
		local x2 = AIMap.GetTileX(location) + 16;
		if (x2 > AIMap.GetMapSizeX() - 2)
		{
			x2 = AIMap.GetMapSizeX() - 2;
		}
		local y2 = AIMap.GetTileY(location) + 16;
		if (y2 > AIMap.GetMapSizeY() - 2)
		{
			y2 = AIMap.GetMapSizeY() - 2;
		}
		tileList.AddRectangle(AIMap.GetTileIndex(x1, y1), AIMap.GetTileIndex(x2, y2));
		tileList.Valuate(AITile.IsWithinTownInfluence, townID);
		tileList.KeepValue(1);
		tileList.Valuate(AITile.GetDistanceManhattanToTile, location);
		tileList.Sort(AIList.SORT_BY_VALUE, true);
		foreach (tile, v in tileList)
		{
			if (BuildWrapper(AICompany.BuildCompanyHQ, [tile], true))
			{
				PrintInfo("Build HQ");
				PrintInfo("Location: " + TileToString(tile));
				return true;
			}
		}
	}
	PrintInfo("I CAN'T BELIEVE YOU'VE DONE THIS");
	return false;
}

function NotPerfectAI::PayLoan()
{
	if (AICompany.GetLoanAmount() == 0)
	{
		return;
	}
	local payIntervals = AICompany.GetBankBalance(AICompany.COMPANY_SELF) / AICompany.GetLoanInterval();
	if (payIntervals > 0)
	{
		local loan = AICompany.GetLoanAmount() - AICompany.GetLoanInterval() * payIntervals;
		if (loan < 0)
		{
			loan = 0;
		}
		PrintInfo("Decrease loan amount to " + loan);
		AICompany.SetLoanAmount(loan);
	}
}

function NotPerfectAI::Start()
{
	PrintInfo("");
	PrintInfo("NotPerfectAI made by hakerg");
	PrintInfo("");
	PrintInfo("Time to own this map ;)");
	PrintInfo("");
	aiInstance = this;
	if (!loaded)
	{
		PrintInfo("Starting new game");
		aiIndexString = RenameWrapper(AICompany.SetName, ["NotPerfectAI"]);
		PrintInfo("Change president gender to female");
		AICompany.SetPresidentGender(AICompany.GENDER_FEMALE);
		RenameWrapper(AICompany.SetPresidentName, ["Bot made by hakerg"]);
		BuildHQ();
	}
	clearCost = AITile.GetBuildCost(AITile.BT_CLEAR_GRASS);
	if (AIGameSettings.GetValue("game_creation.landscape") == 2)
	{
		clearCost = AITile.GetBuildCost(AITile.BT_CLEAR_ROUGH);
	}
	while (true)
	{
		PrintInfo("");
		PrintInfo("========== ========== ========== ==========");
		PrintInfo("");
		PayLoan();
		ProcessEvents();
		if (planList == null || AIDate.GetCurrentDate() > planList.expires)
		{
			planList = PlanList(1024);
		}
		local plan = planList.PopBest();
		if (plan != null)
		{
			if (plan.Realize())
			{
				PrintInfo("Realization successful");
			}
			else
			{
				PrintWarning("Realization failed");
				if (!(plan.source.id in failedPlansByID))
				{
					failedPlansByID[plan.source.id] <- [];
				}
				failedPlansByID[plan.source.id].append(plan);
			}
			maxStationCount = 0;
		}
		else
		{
			planList = null;
			PrintInfo("No plan found!");
			if (maxStationCount == 15)
			{
				PrintInfo("Starting checking failed connections");
				failedPlansByID.clear();
				maxStationCount = 0;
			}
			else
			{
				maxStationCount++;
			}
		}
	}
}

function NotPerfectAI::Save()
{
	local table = {};
	table["aiIndexString"] <- aiIndexString;
	table["engineManager.rememberedCapacities"] <- engineManager.rememberedCapacities;
	table["engineManager.rememberedLengths"] <- engineManager.rememberedLengths;
	table["engineManager.invalidRailEngines"] <- engineManager.invalidRailEngines;
	table["planIndex"] <- planIndex;
	PrintInfo("Game saved");
	return table;
}

function NotPerfectAI::Load(version, table)
{
	aiIndexString = table["aiIndexString"];
	engineManager.rememberedCapacities = table["engineManager.rememberedCapacities"];
	engineManager.rememberedLengths = table["engineManager.rememberedLengths"];
	engineManager.invalidRailEngines = table["engineManager.invalidRailEngines"];
	planIndex = table["planIndex"];
	loaded = true;
	PrintInfo("Game loaded");
}