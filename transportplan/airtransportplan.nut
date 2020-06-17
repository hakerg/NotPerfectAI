require("transportplan.nut");

class AirTransportPlan extends TransportPlan
{
	airportsForSmall            = [                                                                         AIAirport.AT_SMALL, AIAirport.AT_COMMUTER, AIAirport.AT_LARGE, AIAirport.AT_METROPOLITAN, AIAirport.AT_INTERNATIONAL, AIAirport.AT_INTERCON];
	airportsForBig              = [                                                                                                                    AIAirport.AT_LARGE, AIAirport.AT_METROPOLITAN, AIAirport.AT_INTERNATIONAL, AIAirport.AT_INTERCON];
	airportsForSourceHelicopter = [                       AIAirport.AT_HELIDEPOT, AIAirport.AT_HELISTATION, AIAirport.AT_SMALL, AIAirport.AT_COMMUTER, AIAirport.AT_LARGE, AIAirport.AT_METROPOLITAN, AIAirport.AT_INTERNATIONAL, AIAirport.AT_INTERCON];
	airportsForTargetHelicopter = [AIAirport.AT_HELIPORT, AIAirport.AT_HELIDEPOT, AIAirport.AT_HELISTATION, AIAirport.AT_SMALL, AIAirport.AT_COMMUTER, AIAirport.AT_LARGE, AIAirport.AT_METROPOLITAN, AIAirport.AT_INTERNATIONAL, AIAirport.AT_INTERCON];
	runways                     = [                    0,                      0,                        0,                  1,                     1,                  1,                         2,                          2,                     4];
	helipads                    = [                    1,                      1,                        3,                  1,                     2,                  1,                         1,                          2,                     2];
	
	planeType = null;
	sourceAirportType = null;
	targetAirportType = null;
}

function AirTransportPlan::GetAirportType(industry, list)
{
	foreach (type in list)
	{
		if (AIAirport.IsValidAirportType(type))
		{
			return type;
		}
	}
	return null;
}

function AirTransportPlan::constructor(source, target, cargo, engine)
{
	this.source = source;
	this.target = target;
	this.cargo = cargo;
	this.distance = AIMap.DistanceManhattan(source.GetLocation(), target.GetLocation());
	this.routeLength = CalculateDiagonalDistance(source.GetLocation(), target.GetLocation());
	
	this.vehicleType = AIVehicle.VT_AIR;
	this.planeType = AIEngine.GetPlaneType(engine);
	this.useExistingSourceStation = false;
	this.useExistingTargetStation = false;
	switch (planeType)
	{
		case AIAirport.PT_HELICOPTER:
		{
			if (target.HasHeliport())
			{
				this.sourceAirportType = GetAirportType(source, airportsForSourceHelicopter);
				this.useExistingTargetStation = true;
				this.targetStationLocation = target.GetHeliportLocation();
			}
			else if (source.HasHeliport())
			{
				this.useExistingSourceStation = true;
				this.sourceStationLocation = source.GetHeliportLocation();
				this.targetAirportType = GetAirportType(target, airportsForSourceHelicopter);
			}
			else
			{
				this.sourceAirportType = GetAirportType(source, airportsForSourceHelicopter);
				this.targetAirportType = GetAirportType(target, airportsForTargetHelicopter);
			}
			break;
		}
		case AIAirport.PT_SMALL_PLANE:
		{
			this.sourceAirportType = GetAirportType(source, airportsForSmall);
			this.targetAirportType = GetAirportType(target, airportsForSmall);
			break;
		}
		case AIAirport.PT_BIG_PLANE:
		{
			this.sourceAirportType = GetAirportType(source, airportsForBig);
			this.targetAirportType = GetAirportType(target, airportsForBig);
			break;
		}
	}
	if ((!useExistingSourceStation && sourceAirportType == null) || (!useExistingTargetStation && targetAirportType == null))
	{
		this.score = 0;
		return;
	}
	this.infrastructureCost = 0;
	this.monthlyMaintenanceCost = 0;
	if (!useExistingSourceStation)
	{
		this.infrastructureCost += AIAirport.GetPrice(sourceAirportType) + AIAirport.GetAirportWidth(sourceAirportType) * AIAirport.GetAirportHeight(sourceAirportType) * aiInstance.clearCost;
		if (AIGameSettings.GetValue("economy.infrastructure_maintenance"))
		{
			this.monthlyMaintenanceCost += AIAirport.GetMonthlyMaintenanceCost(sourceAirportType);
		}
	}
	if (!useExistingTargetStation)
	{
		this.infrastructureCost += AIAirport.GetPrice(targetAirportType) + AIAirport.GetAirportWidth(targetAirportType) * AIAirport.GetAirportHeight(targetAirportType) * aiInstance.clearCost;
		if (AIGameSettings.GetValue("economy.infrastructure_maintenance"))
		{
			this.monthlyMaintenanceCost += AIAirport.GetMonthlyMaintenanceCost(targetAirportType);
		}
	}
	CalculateSupply();
	ChangeEngine(engine);
}

function AirTransportPlan::GetAvailableVehicleCount()
{
	return AIGameSettings.GetValue("vehicle.max_aircraft") - GetVehicleCount(AIVehicle.VT_AIR);
}

function AirTransportPlan::GetStationCoveredTiles(stationLocation, isSource)
{
	local airportType = null;
	if (isSource)
	{
		if (source.HasHeliport())
		{
			return AITileList();
		}
		airportType = sourceAirportType;
	}
	else
	{
		if (target.HasHeliport())
		{
			return AITileList();
		}
		airportType = targetAirportType;
	}
	return GetCoveredTiles(stationLocation, AIAirport.GetAirportWidth(airportType), AIAirport.GetAirportHeight(airportType), AIAirport.GetAirportCoverageRadius(airportType));
}

function AirTransportPlan::GetAirportLocation(isSource, useExisting)
{
	local testMode = AITestMode();
	local tileList = null;
	local checkCargoFunction = null;
	local minCheckValue = null;
	local airportType = null;
	if (isSource)
	{
		airportType = sourceAirportType;
		tileList = source.GetProducingTiles(cargo, AIAirport.GetAirportWidth(airportType), AIAirport.GetAirportHeight(airportType), AIAirport.GetAirportCoverageRadius(airportType));
		checkCargoFunction = AITile.GetCargoProduction;
		minCheckValue = 1;
	}
	else
	{
		airportType = targetAirportType;
		tileList = target.GetAcceptingTiles(cargo, AIAirport.GetAirportWidth(airportType), AIAirport.GetAirportHeight(airportType), AIAirport.GetAirportCoverageRadius(airportType));
		checkCargoFunction = AITile.GetCargoAcceptance;
		minCheckValue = 8;
	}
	local airportIndex = null;
	for (local i = 0; i < airportsForTargetHelicopter.len(); i++)
	{
		if (airportType == airportsForTargetHelicopter[i])
		{
			airportIndex = i;
			break;
		}
	}
	foreach (tile, v in tileList)
	{
		if (useExisting)
		{
			if (AIAirport.IsAirportTile(tile) && AICompany.IsMine(AITile.GetOwner(tile)))
			{
				for (local i = airportIndex; i < airportsForTargetHelicopter.len(); i++)
				{
					local tp = airportsForTargetHelicopter[i];
					if (AIAirport.GetAirportType(tile) == tp)
					{
						local airportLocation = AIBaseStation.GetLocation(AIStation.GetStationID(tile));
						if (checkCargoFunction(airportLocation, cargo, AIAirport.GetAirportWidth(tp), AIAirport.GetAirportHeight(tp), AIAirport.GetAirportCoverageRadius(tp)) >= minCheckValue)
						{
							if (isSource)
							{
								sourceAirportType = tp;
							}
							else
							{
								targetAirportType = tp;
							}
							return airportLocation;
						}
					}
				}
			}
		}
		else
		{
			if (BuildWrapper(AIAirport.BuildAirport, [tile, airportType, AIStation.STATION_NEW], true))
			{
				return tile;
			}
		}
	}
	return null;
}

function AirTransportPlan::Realize()
{
	SetName();
	PrintInfo("Building:");
	Print();
	if (useExistingSourceStation)
	{
		PrintInfo("Use source industry's heliport");
	}
	else
	{
		PrintInfo("Finding location for source airport");
		sourceStationLocation = GetAirportLocation(true, true);
		if (sourceStationLocation != null)
		{
			PrintInfo("Found existing airport");
			useExistingSourceStation = true;
		}
		else
		{
			sourceStationLocation = GetAirportLocation(true, false);
		}
	}
	if (sourceStationLocation == null)
	{
		return false;
	}
	if (useExistingTargetStation)
	{
		PrintInfo("Use target industry's heliport");
	}
	else
	{
		PrintInfo("Finding location for target airport");
		targetStationLocation = GetAirportLocation(false, true);
		if (targetStationLocation != null)
		{
			PrintInfo("Found existing airport");
			useExistingTargetStation = true;
		}
		else
		{
			targetStationLocation = GetAirportLocation(false, false);
		}
	}
	if (targetStationLocation == null)
	{
		return false;
	}
	distance = AIMap.DistanceManhattan(sourceStationLocation, targetStationLocation);
	routeLength = CalculateDiagonalDistance(sourceStationLocation, targetStationLocation);
	PrintInfo("Distance between stations: " + distance);
	if (!CheckDistance())
	{
		return false;
	}
	if (!useExistingSourceStation)
	{
		PrintInfo("Building source airport");
		if (!BuildWrapper(AIAirport.BuildAirport, [sourceStationLocation, sourceAirportType, AIStation.STATION_NEW], true))
		{
			return false;
		}
	}
	if (!useExistingTargetStation)
	{
		PrintInfo("Building target airport");
		if (!BuildWrapper(AIAirport.BuildAirport, [targetStationLocation, targetAirportType, AIStation.STATION_NEW], true))
		{
			return false;
		}
	}
	if (AIAirport.GetNumHangars(sourceStationLocation) > 0)
	{
		depot = AIAirport.GetHangarOfAirport(sourceStationLocation);
	}
	else
	{
		depot = AIAirport.GetHangarOfAirport(targetStationLocation);
	}
	midpoints = [];
	availableEngines = aiInstance.engineManager.GetAirEngines(planeType, cargo);
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

function AirTransportPlan::BuildPath()
{
	return true;
}