require("planlist.nut");

aiInstance <- null;

class NotPerfectAI extends AIController 
{
	cargoLocksByID = {};
	failedPlansByID = {};
	aiIndexString = null;
	loaded = false;
	engineManager = EngineManager();
	clearCost = null;
	planIndex = 1;
	maxStationCount = 0;
	planList = null;
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
			}
		}
	}
}

function NotPerfectAI::BuildHQ()
{
	local townList = AITownList();
	townList.Valuate(AITown.GetPopulation);
	foreach (townID, v in townList)
	{
		local location = AITown.GetLocation(townID);
		local tileList = Town(townID).GetAuthorityTiles();
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

function NotPerfectAI::RemoveOutdatedCargoLocks()
{
	local date = AIDate.GetCurrentDate();
	foreach (sourceID, locks in cargoLocksByID)
	{
		local newLocks = [];
		foreach (lock in locks)
		{
			if (date < lock[1])
			{
				newLocks.append(lock);
			}
		}
		cargoLocksByID[sourceID] = newLocks;
	}
}

class RailDemolisher
{
	prevTile = null;
	tile = null;
	nextTile = null;
	isFilled = null;
};

function RailDemolisher::constructor()
{
	this.isFilled = false;
}

function RailDemolisher::Flush()
{
	if (isFilled)
	{
		this.isFilled = false;
		BuildWrapper(AIRail.RemoveRail, [prevTile, tile, nextTile], false);
	}
}

function RailDemolisher::RemoveRail(prevTile, tile, nextTile)
{
	if (!isFilled)
	{
		this.prevTile = prevTile;
		this.tile = tile;
		this.nextTile = nextTile;
		this.isFilled = true;
	}
	else
	{
		local testMode = AITestMode();
		if (BuildWrapper(AIRail.RemoveRail, [this.prevTile, this.tile, nextTile], false))
		{
			this.nextTile = nextTile;
		}
		else
		{
			local execMode = AIExecMode();
			Flush();
			RemoveRail(prevTile, tile, nextTile);
		}
	}
}

railDemolisher <- RailDemolisher();

function NotPerfectAI::RemoveRailRecursively(tile, prevTile)
{
	if (AIRail.IsRailDepotTile(tile))
	{
		railDemolisher.Flush();
		AITile.DemolishTile(tile);
		return;
	}
	if (AIBridge.IsBridgeTile(tile))
	{
		railDemolisher.Flush();
		local bridgeEnd = AIBridge.GetOtherBridgeEnd(tile);
		local afterBridge = GoToTile(bridgeEnd, GetDirection(tile, bridgeEnd));
		RemoveRailRecursively(afterBridge, bridgeEnd);
		return;
	}
	if (AIRail.IsRailStationTile(tile))
	{
		railDemolisher.Flush();
		RemoveRailRecursively(tile + tile - prevTile, tile);
		return;
	}
	local toCheck = [];
	foreach (neighbor in neighbors)
	{
		local nextTile = GoToTile(tile, neighbor);
		if (prevTile == nextTile) continue;
		if (AIRail.AreTilesConnected(prevTile, tile, nextTile))
		{
			railDemolisher.RemoveRail(prevTile, tile, nextTile);
			toCheck.append(nextTile);
		}
	}
	foreach (nextTile in toCheck)
	{
		RemoveRailRecursively(nextTile, tile);
	}
}

function NotPerfectAI::SellStation(stationID, stationType)
{
	PrintWarning("Destroying unused station: " + AIBaseStation.GetName(stationID));
	local location = AIBaseStation.GetLocation(stationID);
	if (stationType == AIStation.STATION_TRAIN)
	{
		if (AIRail.GetRailStationDirection(location) == AIRail.RAILTRACK_NE_SW)
		{
			RemoveRailRecursively(GoToTile(location, railTrackData.ne), location);
			RemoveRailRecursively(GoToTile(location, railTrackData.sw), location);
		}
		else
		{
			RemoveRailRecursively(GoToTile(location, railTrackData.nw), location);
			RemoveRailRecursively(GoToTile(location, railTrackData.se), location);
		}
	}
	railDemolisher.Flush();
	AITile.DemolishTile(location);
}

function NotPerfectAI::SellUnusedInfrastructure()
{
	PrintInfo("Looking for unused infrastructure");
	local stationTypeList = [AIStation.STATION_TRAIN, AIStation.STATION_AIRPORT];
	foreach (stationType in stationTypeList)
	{
		local stationList = AIStationList(stationType);
		foreach (stationID, v in stationList)
		{
			local vehicleList = AIVehicleList_Station(stationID);
			if (vehicleList.IsEmpty())
			{
				SellStation(stationID, stationType);
			}
		}
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
		SellUnusedInfrastructure();
		PayLoan();
		ProcessEvents();
		RemoveOutdatedCargoLocks();
		if (planList == null || AIDate.GetCurrentDate() > planList.expires)
		{
			planList = PlanList(4096);
		}
		local plan = planList.PopBest();
		if (plan != null)
		{
			if (plan.Realize())
			{
				PrintInfo("Realization successful");
				if (AIController.GetSetting("slowMode"))
				{
					PrintInfo("");
					PrintInfo("Waiting 365 days");
					PrintInfo("");
					SleepDays(365);
				}
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
			PrintInfo("No suitable plan!");
			if (maxStationCount == 255)
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
		SleepDays(1);
	}
}

function NotPerfectAI::Save()
{
	local table = {};
	table["cargoLocksByID"] <- cargoLocksByID;
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
	cargoLocksByID = table["cargoLocksByID"];
	aiIndexString = table["aiIndexString"];
	engineManager.rememberedCapacities = table["engineManager.rememberedCapacities"];
	engineManager.rememberedLengths = table["engineManager.rememberedLengths"];
	engineManager.invalidRailEngines = table["engineManager.invalidRailEngines"];
	planIndex = table["planIndex"];
	loaded = true;
	PrintInfo("Game loaded");
}