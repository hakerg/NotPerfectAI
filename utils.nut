function GetTilesPerDay(inGameSpeed)
{
	// speed [km/h] =  1.00584 * inGameSpeed
	// 1 tile = 664.(216) km
	// return 1.00584 * inGameSpeed * 24 / 664.216;
	return inGameSpeed * 0.03634384;
}

function GetReliabilitySpeedFactor(engine)
{
	return 0.5 + AIEngine.GetReliability(engine) * 0.005;
}

function GetAvailableMoney()
{
	return AICompany.GetBankBalance(AICompany.COMPANY_SELF) + AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount();
}

function GetQuarterlyIncome()
{
	if (AICompany.CURRENT_QUARTER == AICompany.EARLIEST_QUARTER)
	{
		return AICompany.GetQuarterlyIncome(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER) - AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER);
	}
	else
	{
		return AICompany.GetQuarterlyIncome(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER - 1) - AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER - 1);
	}
}

function PrintInfo(string)
{
	local date = AIDate.GetCurrentDate();
	AILog.Info(AIDate.GetYear(date) + "." + AIDate.GetMonth(date) + "." + AIDate.GetDayOfMonth(date) + " " + string);
}

function PrintWarning(string)
{
	local date = AIDate.GetCurrentDate();
	AILog.Warning(AIDate.GetYear(date) + "." + AIDate.GetMonth(date) + "." + AIDate.GetDayOfMonth(date) + " " + string);
}

function PrintError(string)
{
	local date = AIDate.GetCurrentDate();
	AILog.Error(AIDate.GetYear(date) + "." + AIDate.GetMonth(date) + "." + AIDate.GetDayOfMonth(date) + " " + string);
}

function PrintList(list)
{
	PrintInfo(list.Count() + " items:");
	PrintInfo("{");
	foreach (item, value in list)
	{
		PrintInfo("    [" + item + "]: " + value);
	}
	PrintInfo("}");
}

function SleepDays(days)
{
	local timeout = AIDate.GetCurrentDate() + days;
	while (AIDate.GetCurrentDate() < timeout)
	{
		AIController.Sleep(10);
	}
}

function DrawProgressBar(progress, max)
{
	progress *= 4;
	max *= 4;
	local string = "|";
	for (local i = 0; i < progress; i++)
	{
		string += "-";
	}
	for (local i = progress; i < max; i++)
	{
		string += " ";
	}
	string += "|";
	PrintInfo(string);
}

function DrawProgress(progress, max)
{
	local period = max / 8;
	if (period < 1)
	{
		period = 1;
	}
	local drawMax = max / period;
	if (progress % period == 0)
	{
		DrawProgressBar(progress / period, drawMax);
		return true;
	}
	return false;
}

function BuildSign(location, text)
{
	local execMode = AIExecMode();
	AISign.BuildSign(location, text);
}

function ClearSigns()
{
	local execMode = AIExecMode();
	local signList = AISignList();
	foreach (sign, v in signList)
	{
		AISign.RemoveSign(sign);
	}
}

function GetTileCoords(tile)
{
	return [AIMap.GetTileX(tile), AIMap.GetTileY(tile)];
}

function TileToString(tile)
{
	return AIMap.GetTileX(tile) + "x" + AIMap.GetTileY(tile);
}

function GoToTile(tile, direction)
{
	return AIMap.GetTileIndex(AIMap.GetTileX(tile) + direction[0], AIMap.GetTileY(tile) + direction[1]);
}

function Rotate(direction, counterclockwiseSign)
{
	return [-direction[1] * counterclockwiseSign, direction[0] * counterclockwiseSign];
}

function GetRectangle(x1, y1, x2, y2)
{
	if (x1 < 1)
	{
		x1 = 1;
	}
	if (y1 < 1)
	{
		y1 = 1;
	}
	if (x2 > AIMap.GetMapSizeX() - 2)
	{
		x2 = AIMap.GetMapSizeX() - 2;
	}
	if (y2 > AIMap.GetMapSizeY() - 2)
	{
		y2 = AIMap.GetMapSizeY() - 2;
	}
	local tileList = AITileList();
	tileList.AddRectangle(AIMap.GetTileIndex(x1, y1), AIMap.GetTileIndex(x2, y2));
	return tileList;
}

function GetCoveredTiles(tile, width, height, radius)
{
	local x = AIMap.GetTileX(tile);
	local y = AIMap.GetTileY(tile);
	return GetRectangle(x - radius, y - radius, x + width - 1 + radius, y + height - 1 + radius);
}

function GetLocationsToCoverTile(tile, width, height, radius)
{
	local x = AIMap.GetTileX(tile);
	local y = AIMap.GetTileY(tile);
	return GetRectangle(x - radius - width + 1, y - radius - height + 1, x + radius, y + radius);
}

function AreOnOneLine(tiles)
{
	local line = true;
	for (local i = 1; i < tiles.len(); i++)
	{
		if (AIMap.GetTileX(tiles[i - 1]) != AIMap.GetTileX(tiles[i]))
		{
			line = false;
			break;
		}
	}
	if (line)
	{
		return true;
	}
	for (local i = 1; i < tiles.len(); i++)
	{
		if (AIMap.GetTileY(tiles[i - 1]) != AIMap.GetTileY(tiles[i]))
		{
			return false;
		}
	}
	return true;
}

function GetDirectionID(direction)
{
	if (direction != null)
	{
		foreach (id, neighbor in neighbors)
		{
			if (direction[0] == neighbor[0] && direction[1] == neighbor[1])
			{
				return id;
			}
		}
	}
	return null;
}

function GetDirection(sourceTile, targetTile)
{
	return [Sign(AIMap.GetTileX(targetTile) - AIMap.GetTileX(sourceTile)), Sign(AIMap.GetTileY(targetTile) - AIMap.GetTileY(sourceTile))];
}

function CalculateDiagonalDistance(tile1, tile2)
{
	local absDeltaX = abs(AIMap.GetTileX(tile2) - AIMap.GetTileX(tile1));
	local absDeltaY = abs(AIMap.GetTileY(tile2) - AIMap.GetTileY(tile1));
	local diagonal = absDeltaX;
	if (absDeltaY < diagonal)
	{
		diagonal = absDeltaY;
	}
	return diagonal * 1.4 + abs(absDeltaX - absDeltaY);
}

function GetVehicleCount(vehicleType)
{
	local vehicleList = AIVehicleList();
	vehicleList.Valuate(AIVehicle.GetVehicleType);
	vehicleList.KeepValue(vehicleType);
	return vehicleList.Count();
}

function Call0Param(functionToCall, params)
{
	return functionToCall();
}

function Call1Param(functionToCall, params)
{
	return functionToCall(params[0]);
}

function Call2Param(functionToCall, params)
{
	return functionToCall(params[0], params[1]);
}

function Call3Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2]);
}

function Call4Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3]);
}

function Call5Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3], params[4]);
}

function Call6Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3], params[4], params[5]);
}

function Call7Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3], params[4], params[5], params[6]);
}

function Call8Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7]);
}

function Call9Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8]);
}

function Call10Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9]);
}

function Call11Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10]);
}

function Call12Param(functionToCall, params)
{
	return functionToCall(params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10], params[11]);
}

callParam <- [Call0Param, Call1Param, Call2Param, Call3Param, Call4Param, Call5Param, Call6Param, Call7Param, Call8Param, Call9Param, Call10Param, Call11Param, Call12Param];

neighbors <- [[0, 1], [0, -1], [-1, 0], [1, 0]];

function Sign(value)
{
	if (value > 0)
	{
		return 1;
	}
	else if (value < 0)
	{
		return -1;
	}
	return 0;
}

function BuildWrapper(buildFunction, params, waitForMoney, moneyInfo = true)
{
	if (callParam[params.len()](buildFunction, params))
	{
		return true;
	}
	else
	{
		switch (AIError.GetLastError())
		{
			case AIError.ERR_ALREADY_BUILT:
			{
				return true;
			}
			case AIError.ERR_NOT_ENOUGH_CASH:
			{
				if (AICompany.GetLoanAmount() >= AICompany.GetMaxLoanAmount())
				{
					if (waitForMoney && !AIVehicleList().IsEmpty())
					{
						if (moneyInfo)
						{
							PrintInfo("Waiting for money");
						}
						aiInstance.ProcessEvents();
						SleepDays(1);
						return BuildWrapper(buildFunction, params, waitForMoney, false);
					}
				}
				else
				{
					PrintInfo("Set loan amount to " + AICompany.GetMaxLoanAmount());
					AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
					return BuildWrapper(buildFunction, params, waitForMoney);
				}
			}
		}
		return false;
	}
}

function VehicleBuildWrapper(buildFunction, params, waitForMoney, moneyInfo = true)
{
	local vehicleID = callParam[params.len()](buildFunction, params);
	if (AIVehicle.IsValidVehicle(vehicleID))
	{
		return vehicleID;
	}
	else
	{
		switch (AIError.GetLastError())
		{
			case AIError.ERR_NOT_ENOUGH_CASH:
			{
				if (AICompany.GetLoanAmount() >= AICompany.GetMaxLoanAmount())
				{
					if (waitForMoney && !AIVehicleList().IsEmpty())
					{
						if (moneyInfo)
						{
							PrintInfo("Waiting for money");
						}
						aiInstance.ProcessEvents();
						SleepDays(1);
						return VehicleBuildWrapper(buildFunction, params, waitForMoney, false);
					}
				}
				else
				{
					PrintInfo("Set loan amount to " + AICompany.GetMaxLoanAmount());
					AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
					return VehicleBuildWrapper(buildFunction, params, waitForMoney);
				}
			}
		}
		return null;
	}
}

function RenameWrapper(renameFunction, params)
{
	if (!callParam[params.len()](renameFunction, params))
	{
		local string = params[params.len() - 1];
		for (local i = 2; i < 65536; i++)
		{
			params[params.len() - 1] = string + " #" + i;
			if (callParam[params.len()](renameFunction, params))
			{
				return " #" + i;
			}
		}
	}
	else
	{
		return "";
	}
	return null;
}

function GetSaveableObject(object)
{
	if ((typeof object) == "float")
	{
		return object.tointeger();
	}
	else if ((typeof object) == "instance")
	{
		return GetSaveableObject(object.GetTable());
	}
	else if ((typeof object) == "table")
	{
		local saveable = {};
		foreach (index, value in object)
		{
			saveable[index] <- GetSaveableObject(value);
		}
		return saveable;
	}
	else if ((typeof object) == "array")
	{
		local saveable = [];
		foreach (value in object)
		{
			saveable.append(GetSaveableObject(value));
		}
		return saveable;
	}
	else
	{
		return object;
	}
}