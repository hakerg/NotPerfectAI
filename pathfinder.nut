require("utils.nut");
require("largearray.nut");

class RailTrackData
{
	ne = [-1, 0];
	sw = [1, 0];
	nw = [0, -1];
	se = [0, 1];
	indexTrackArray =
	[
		AIRail.RAILTRACK_NE_SW,
		AIRail.RAILTRACK_NW_SE,
		AIRail.RAILTRACK_NW_NE,
		AIRail.RAILTRACK_SW_SE,
		AIRail.RAILTRACK_NW_SW,
		AIRail.RAILTRACK_NE_SE
	];
	trackIndexTable =
	{
		[AIRail.RAILTRACK_NE_SW] = 0,
		[AIRail.RAILTRACK_NW_SE] = 1,
		[AIRail.RAILTRACK_NW_NE] = 2,
		[AIRail.RAILTRACK_SW_SE] = 3,
		[AIRail.RAILTRACK_NW_SW] = 4,
		[AIRail.RAILTRACK_NE_SE] = 5
	};

	// FIFO - queue
	/*trackArray =
	[
		[
			[[-1, 0], [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_SW_SE, AIRail.RAILTRACK_NW_SW]],
			[[1, 0], [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_NW_NE, AIRail.RAILTRACK_NE_SE]]
		],
		[
			[[0, -1], [AIRail.RAILTRACK_NW_SE, AIRail.RAILTRACK_SW_SE, AIRail.RAILTRACK_NE_SE]],
			[[0, 1], [AIRail.RAILTRACK_NW_SE, AIRail.RAILTRACK_NW_NE, AIRail.RAILTRACK_NW_SW]]
		],
		[
			[[0, -1], [AIRail.RAILTRACK_SW_SE, AIRail.RAILTRACK_NW_SE]],
			[[-1, 0], [AIRail.RAILTRACK_SW_SE, AIRail.RAILTRACK_NE_SW]]
		],
		[
			[[1, 0], [AIRail.RAILTRACK_NW_NE, AIRail.RAILTRACK_NE_SW]],
			[[0, 1], [AIRail.RAILTRACK_NW_NE, AIRail.RAILTRACK_NW_SE]]
		],
		[
			[[0, -1], [AIRail.RAILTRACK_NE_SE, AIRail.RAILTRACK_NW_SE]],
			[[1, 0], [AIRail.RAILTRACK_NE_SE, AIRail.RAILTRACK_NE_SW]]
		],
		[
			[[-1, 0], [AIRail.RAILTRACK_NW_SW, AIRail.RAILTRACK_NE_SW]],
			[[0, 1], [AIRail.RAILTRACK_NW_SW, AIRail.RAILTRACK_NW_SE]]
		]
	];*/

	// FILO - stack
	trackArray =
	[
		[
			[[-1, 0], [AIRail.RAILTRACK_SW_SE, AIRail.RAILTRACK_NW_SW, AIRail.RAILTRACK_NE_SW]],
			[[1, 0], [AIRail.RAILTRACK_NW_NE, AIRail.RAILTRACK_NE_SE, AIRail.RAILTRACK_NE_SW]]
		],
		[
			[[0, -1], [AIRail.RAILTRACK_SW_SE, AIRail.RAILTRACK_NE_SE, AIRail.RAILTRACK_NW_SE]],
			[[0, 1], [AIRail.RAILTRACK_NW_NE, AIRail.RAILTRACK_NW_SW, AIRail.RAILTRACK_NW_SE]]
		],
		[
			[[0, -1], [AIRail.RAILTRACK_NW_SE, AIRail.RAILTRACK_SW_SE]],
			[[-1, 0], [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_SW_SE]]
		],
		[
			[[1, 0], [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_NW_NE]],
			[[0, 1], [AIRail.RAILTRACK_NW_SE, AIRail.RAILTRACK_NW_NE]]
		],
		[
			[[0, -1], [AIRail.RAILTRACK_NW_SE, AIRail.RAILTRACK_NE_SE]],
			[[1, 0], [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_NE_SE]]
		],
		[
			[[-1, 0], [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_NW_SW]],
			[[0, 1], [AIRail.RAILTRACK_NW_SE, AIRail.RAILTRACK_NW_SW]]
		]
	];
	linedTrackArray =
	[
		AIRail.RAILTRACK_NE_SW,
		AIRail.RAILTRACK_NW_SE,
		AIRail.RAILTRACK_SW_SE,
		AIRail.RAILTRACK_NW_NE,
		AIRail.RAILTRACK_NE_SE,
		AIRail.RAILTRACK_NW_SW
	];
}

railTrackData <- RailTrackData();

class RailPiece
{
	tile = null;
	orientation = null;
}

function RailPiece::constructor(tile, orientation)
{
	this.tile = tile;
	this.orientation = orientation;
}

function RailPiece::IsEqualTo(other)
{
	return tile == other.tile && orientation == other.orientation;
}

function RailPiece::GetIndex()
{
	return railTrackData.trackIndexTable[orientation] + tile * 6;
}

function RailPiece::CreateFromIndex(index)
{
	return RailPiece(index / 6, railTrackData.indexTrackArray[index % 6]);
}

function RailPiece::GetNextPieces(tileBefore)
{
	local pieces = [];
	foreach (direction in railTrackData.trackArray[railTrackData.trackIndexTable[orientation]])
	{
		local nextTile = GoToTile(tile, direction[0]);
		if (nextTile == tileBefore)
		{
			continue;
		}
		foreach (nextOrientation in direction[1])
		{
			pieces.append(RailPiece(nextTile, nextOrientation));
		}
	}
	return pieces;
}

function RailPiece::IsInLine(nextPiece)
{
	return railTrackData.linedTrackArray[railTrackData.trackIndexTable[orientation]] == nextPiece.orientation;
}

function RailPiece::IsStationAlong()
{
	return AIRail.IsRailStationTile(tile) && AIRail.GetRailType(tile) == AIRail.GetCurrentRailType() && AICompany.IsMine(AITile.GetOwner(tile)) && AIRail.GetRailStationDirection(tile) == orientation;
}

function RailPiece::Build()
{
	return (IsStationAlong() || BuildWrapper(AIRail.BuildRailTrack, [tile, orientation], true)) && !AIRoad.IsRoadTile(tile);
}

function RailPiece::IsAlongAxis()
{
	return orientation == AIRail.RAILTRACK_NE_SW || orientation == AIRail.RAILTRACK_NW_SE;
}

function RailPiece::CrossesRail()
{
	return AIRail.GetRailTracks(tile) != 0 && (AIRail.GetRailTracks(tile) & orientation) == 0;
}

class PathNode
{
	mother = null;
	cost = null;
	totalCost = null;
	index = null;
	directionID = null;
	bridge = null;
}

function PathNode::CreateRoot(start, directionID, totalCost)
{
	local node = PathNode();
	node.cost = 0;
	node.totalCost = totalCost;
	node.index = start;
	node.directionID = directionID;
	node.bridge = false;
	return node;
}

function PathNode::CreateNode(mother, index, cost, directionID, bridge, remainingCost)
{
	local node = PathNode();
	node.mother = mother;
	node.cost = mother.cost + cost;
	node.totalCost = node.cost + remainingCost;
	node.index = index;
	node.directionID = directionID;
	node.bridge = bridge;
	return node;
}

function PathNode::ReconstructPath()
{
	local path = [index];
	local node = this;
	while (node.mother != null)
	{
		node = node.mother;
		path.insert(0, node.index);
	}
	PrintInfo("Node count: " + path.len());
	return path;
}

function PathNode::ReconstructRailPath()
{
	local path = [RailPiece.CreateFromIndex(index)];
	local node = this;
	while (node.mother != null)
	{
		node = node.mother;
		path.insert(0, RailPiece.CreateFromIndex(node.index));
	}
	PrintInfo("Node count: " + path.len());
	return path;
}

class PathOpenList
{
	listIndexCost = null;
	tableIndexNode = null;
	orderingCost = null;
}

function PathOpenList::constructor()
{
	listIndexCost = AIList();
	tableIndexNode = {};
	orderingCost = 10000;
	listIndexCost.Sort(AIList.SORT_BY_VALUE, true);
}

function PathOpenList::PopBest()
{
	if (listIndexCost.IsEmpty())
	{
		return null;
	}
	else
	{
		local index = listIndexCost.Begin();
		listIndexCost.RemoveItem(index);
		return delete tableIndexNode[index];
	}
}

function PathOpenList::ReplaceIfBetter(node)
{
	if (!listIndexCost.HasItem(node.index) || listIndexCost.GetValue(node.index) / 10000 > node.totalCost)
	{
		listIndexCost.RemoveItem(node.index);
		orderingCost--;
		local itemCost = node.totalCost * 10000 + orderingCost;
		if (itemCost < 0)
		{
			itemCost = 0;
		}
		listIndexCost.AddItem(node.index, itemCost);
		tableIndexNode[node.index] <- node;
	}
}

function PathNode::GetScopeCost(slope)
{
	if ((slope == AITile.SLOPE_NWS) || (slope == AITile.SLOPE_WSE) || (slope == AITile.SLOPE_SEN) || (slope == AITile.SLOPE_ENW))
	{
		return 2;
	}
	else if ((slope == AITile.SLOPE_NS) || (slope == AITile.SLOPE_EW))
	{
		return 4;
	}
	else if ((slope == AITile.SLOPE_NW) || (slope == AITile.SLOPE_SW) || (slope == AITile.SLOPE_SE) || (slope == AITile.SLOPE_NE))
	{
		return 21;
	}
	else if ((slope == AITile.SLOPE_W) || (slope == AITile.SLOPE_S) || (slope == AITile.SLOPE_E) || (slope == AITile.SLOPE_N))
	{
		return 22;
	}
	else if (AITile.IsSteepSlope(slope))
	{
		return 24;
	}
	return 0;
}

function PathNode::GetExistingScopeCost(slope)
{
	if ((slope == AITile.SLOPE_NW) || (slope == AITile.SLOPE_SW) || (slope == AITile.SLOPE_SE) || (slope == AITile.SLOPE_NE)
		|| (slope == AITile.SLOPE_W) || (slope == AITile.SLOPE_S) || (slope == AITile.SLOPE_E) || (slope == AITile.SLOPE_N)
		|| AITile.IsSteepSlope(slope))
	{
		return 20;
	}
	return 0;
}

function PathNode::CanHaveCurve(slope)
{
	return (slope == AITile.SLOPE_FLAT)
		|| (slope == AITile.SLOPE_NWS) || (slope == AITile.SLOPE_WSE) || (slope == AITile.SLOPE_SEN) || (slope == AITile.SLOPE_ENW)
		|| (slope == AITile.SLOPE_NS) || (slope == AITile.SLOPE_EW);
}

function PathNode::FindFastestBridge(length)
{
	local bridgeList = AIBridgeList_Length(length);
	bridgeList.Valuate(AIBridge.GetMaxSpeed);
	return bridgeList.Begin();
}

function PathNode::GetTerrainCost(tile)
{
	local newCost = null;
	if (AITile.IsFarmTile(tile))
	{
		newCost = 20;
	}
	else if (AITile.IsCoastTile(tile))
	{
		newCost = 15;
	}
	else if (AITile.IsRockTile(tile) || AITile.IsRoughTile(tile))
	{
		newCost = 12;
	}
	else
	{
		newCost = 10;
	}
	return newCost + PathNode.GetScopeCost(AITile.GetSlope(tile));
}

function PathNode::GetNextTileCost(tile, alreadyBuilt, sourceTile, targetTile, changeDirectionPunishment)
{
	local cost = null;
	if (alreadyBuilt)
	{
		cost = 1;
	}
	else
	{
		cost = PathNode.GetTerrainCost(tile) + changeDirectionPunishment;
	}
	if (AITile.IsStationTile(tile))
	{
		local stationID = AIStation.GetStationID(tile);
		if (stationID != AIStation.GetStationID(sourceTile) && stationID != AIStation.GetStationID(targetTile))
		{
			cost += 50;
		}
	}
	return cost;
}

function GetRemainingRoadCost(tile, target)
{
	return AIMap.DistanceManhattan(tile, target) * 15;
}

function GetRemainingRailCost(tile, targetPieces)
{
	local distance = CalculateDiagonalDistance(tile, targetPieces[0].tile);
	for (local i = 1; i < targetPieces.len(); i++)
	{
		local newDistance = CalculateDiagonalDistance(tile, targetPieces[i].tile);
		if (newDistance < distance)
		{
			distance = newDistance;
		}
	}
	return (distance * 20).tointeger();
}

function FindRoadPath(source, target, iterations, initDirection)
{
	local testMode = AITestMode();
	PrintInfo("Find road path from " + TileToString(source) + " to " + TileToString(target) + ", iterations: " + iterations);
	local totalDistance = AIMap.DistanceManhattan(source, target);
	PrintInfo("Distance: " + totalDistance);
	if (source == target)
	{
		return [target];
	}
	local mapSize = AIMap.GetMapSizeX() * AIMap.GetMapSizeY();
	local closedNodes = LargeArray(mapSize);
	local openNodes = PathOpenList();
	openNodes.ReplaceIfBetter(PathNode.CreateRoot(source, GetDirectionID(initDirection), GetRemainingRoadCost(source, target)));
	local maxBridgeLength = AIGameSettings.GetValue("construction.max_bridge_length");
	local bridgeTable = {};
	for (local length = 1; length <= maxBridgeLength; length++)
	{
		bridgeTable[length] <- PathNode.FindFastestBridge(length);
	}
	local reverseDirectionsID = [1, 0, 3, 2];
	for (local i = 0; i < iterations; i++)
	{
		local node = openNodes.PopBest();
		if (node == null)
		{
			PrintWarning("Path cannot be found");
			return null;
		}
		if (node.index == target)
		{
			PrintInfo("Path found in " + i + " iterations");
			return node.ReconstructPath();
		}
		closedNodes.Set(node.index, node);
		if (AIController.GetSetting("pathfinderSigns"))
		{
			BuildSign(node.index, i + " / " + iterations);
			ClearSigns();
		}
		local directionsToCheck = neighbors;
		if (node.bridge || !PathNode.CanHaveCurve(AITile.GetSlope(node.index)))
		{
			directionsToCheck = {};
			directionsToCheck[node.directionID] <- neighbors[node.directionID];
			directionsToCheck[reverseDirectionsID[node.directionID]] <- neighbors[reverseDirectionsID[node.directionID]];
		}
		foreach (neighborID, neighbor in directionsToCheck)
		{
			local nextTile = GoToTile(node.index, neighbor);
			if (!AIMap.IsValidTile(nextTile) || closedNodes.Get(nextTile) != null || !BuildWrapper(AIRoad.BuildRoad, [node.index, nextTile], true) || AIRail.IsRailTile(nextTile))
			{
				continue;
			}
			//                       initRoadCost
			//         node.index    nextTile                     bridgeEnd     afterBridge
			// ROAD -> ROAD       -> BRIDGE START -> BRIDGE    -> BRIDGE END -> ROAD        -> ROAD
			//                                       obstackle
			local initRoadCost = PathNode.GetNextTileCost(nextTile, (AIError.GetLastError() == AIError.ERR_ALREADY_BUILT), source, target, neighborID != node.directionID ? 10 : 0);
			local bridgeEnd = GoToTile(nextTile, neighbor);
			if (!BuildWrapper(AIBridge.BuildBridge, [AIVehicle.VT_ROAD, bridgeTable[1], nextTile, bridgeEnd], true))
			{
				for (local length = 2; length <= maxBridgeLength; length++)
				{
					bridgeEnd = GoToTile(bridgeEnd, neighbor);
					if (BuildWrapper(AIBridge.BuildBridge, [AIVehicle.VT_ROAD, bridgeTable[length], nextTile, bridgeEnd], false))
					{
						local bridgeBuilt = (AIError.GetLastError() == AIError.ERR_ALREADY_BUILT);
						local afterBridge = GoToTile(bridgeEnd, neighbor);
						if (BuildWrapper(AIRoad.BuildRoad, [bridgeEnd, afterBridge], true) && !AIRail.IsRailTile(afterBridge))
						{
							local bridgeCost = PathNode.GetNextTileCost(bridgeEnd, bridgeBuilt, source, target, 0);
							if (!bridgeBuilt)
							{
								bridgeCost += (length + 1) * 25;
							}
							openNodes.ReplaceIfBetter(PathNode.CreateNode(node, bridgeEnd, initRoadCost + bridgeCost, neighborID, true, GetRemainingRoadCost(bridgeEnd, target)));
							break;
						}
					}
				}
			}
			openNodes.ReplaceIfBetter(PathNode.CreateNode(node, nextTile, initRoadCost, neighborID, false, GetRemainingRoadCost(nextTile, target)));
		}
	}
	PrintWarning("Too little iterations; path not found");
	return null;
}

function FindWaterPath(source, target, iterations)
{
	local testMode = AITestMode();
	PrintInfo("Find water path from " + TileToString(source) + " to " + TileToString(target) + ", iterations: " + iterations);
	local totalDistance = AIMap.DistanceManhattan(source, target);
	PrintInfo("Distance: " + totalDistance);
	if (source == target)
	{
		return [target];
	}
	local mapSize = AIMap.GetMapSizeX() * AIMap.GetMapSizeY();
	local closedNodes = LargeArray(mapSize);
	local openNodes = PathOpenList();
	openNodes.ReplaceIfBetter(PathNode.CreateRoot(source, null, totalDistance));
	for (local i = 0; i < iterations; i++)
	{
		local node = openNodes.PopBest();
		if (node == null)
		{
			PrintWarning("Path cannot be found");
			return null;
		}
		if (node.index == target)
		{
			PrintInfo("Path found in " + i + " iterations");
			return node.ReconstructPath();
		}
		closedNodes.Set(node.index, node);
		if (AIController.GetSetting("pathfinderSigns"))
		{
			BuildSign(node.index, "pop");
			ClearSigns();
		}
		foreach (neighborID, neighbor in neighbors)
		{
			local nextTile = GoToTile(node.index, neighbor);
			if (!AIMap.IsValidTile(nextTile) || closedNodes.Get(nextTile) != null || (node.index != source && nextTile != target && !AIMarine.AreWaterTilesConnected(node.index, nextTile)))
			{
				continue;
			}
			openNodes.ReplaceIfBetter(PathNode.CreateNode(node, nextTile, 1, neighborID, false, AIMap.DistanceManhattan(nextTile, target)));
		}
	}
	PrintWarning("Too little iterations; path not found");
	return null;
}

function FindRailPath(source, sourceOrientation, targets, targetOrientation, iterations, prevTile)
{
	local testMode = AITestMode();
	PrintInfo("Find rail path from " + TileToString(source) + " to " + TileToString(targets[0]) + ", iterations: " + iterations);
	local sourcePiece = RailPiece(source, sourceOrientation);
	local targetPieces = [];
	foreach (target in targets)
	{
		local targetPiece = RailPiece(target, targetOrientation);
		if (sourcePiece.IsEqualTo(targetPiece))
		{
			return [targetPiece];
		}
		local nextPieces = targetPiece.GetNextPieces(null);
		foreach (nextPiece in nextPieces)
		{
			if (nextPiece.Build())
			{
				targetPieces.append(nextPiece);
			}
		}
	}
	local pieceCount = AIMap.GetMapSizeX() * AIMap.GetMapSizeY() * 6;
	local closedNodes = LargeArray(pieceCount);
	local openNodes = PathOpenList();
	openNodes.ReplaceIfBetter(PathNode.CreateRoot(sourcePiece.GetIndex(), null, GetRemainingRailCost(source, targetPieces)));
	local maxBridgeLength = AIGameSettings.GetValue("construction.max_bridge_length");
	local bridgeTable = {};
	for (local length = 1; length <= maxBridgeLength; length++)
	{
		bridgeTable[length] <- PathNode.FindFastestBridge(length);
	}
	for (local i = 0; i < iterations; i++)
	{
		local node = openNodes.PopBest();
		if (node == null)
		{
			PrintWarning("Path cannot be found");
			return null;
		}
		local nodePiece = RailPiece.CreateFromIndex(node.index);
		foreach (targetPiece in targetPieces)
		{
			if (nodePiece.IsEqualTo(targetPiece))
			{
				PrintInfo("Path found in " + i + " iterations");
				return node.ReconstructRailPath();
			}
		}
		closedNodes.Set(node.index, node);
		if (AIController.GetSetting("pathfinderSigns"))
		{
			BuildSign(nodePiece.tile, "pop");
			ClearSigns();
		}
		local motherTile = null;
		local motherPiece = null;
		if (node.mother != null)
		{
			motherPiece = RailPiece.CreateFromIndex(node.mother.index);
			motherTile = motherPiece.tile;
		}
		else
		{
			motherTile = prevTile;
		}
		local piecesToCheck = nodePiece.GetNextPieces(motherTile);
		foreach (nextPiece in piecesToCheck)
		{
			if (!AIMap.IsValidTile(nextPiece.tile) || closedNodes.Get(nextPiece.GetIndex()) != null)
			{
				continue;
			}
			if (nextPiece.CrossesRail())
			{
				continue;
			}
			local changesDirectionPunishment = 0;
			if (motherPiece != null)
			{
				if (nextPiece.IsAlongAxis() != nodePiece.IsAlongAxis() && nodePiece.IsAlongAxis() != motherPiece.IsAlongAxis())
				{
					changesDirectionPunishment = 20;
				}
				else
				{
					if (node.mother.mother != null)
					{
						local grandMotherPiece = RailPiece.CreateFromIndex(node.mother.mother.index);
						if (grandMotherPiece.IsAlongAxis() != motherPiece.IsAlongAxis() && motherPiece.IsAlongAxis() != nextPiece.IsAlongAxis())
						{
							changesDirectionPunishment = 15;
						}
						else if (grandMotherPiece.IsAlongAxis() != nodePiece.IsAlongAxis() && nodePiece.IsAlongAxis() != nextPiece.IsAlongAxis())
						{
							changesDirectionPunishment = 15;
						}
						else
						{
							if (node.mother.mother.mother != null)
							{
								local grandGrandMotherPiece = RailPiece.CreateFromIndex(node.mother.mother.mother.index);
								if (grandGrandMotherPiece.IsAlongAxis() != grandMotherPiece.IsAlongAxis() && grandMotherPiece.IsAlongAxis() != nextPiece.IsAlongAxis())
								{
									changesDirectionPunishment = 10;
								}
								else if (grandGrandMotherPiece.IsAlongAxis() != nodePiece.IsAlongAxis() && nodePiece.IsAlongAxis() != nextPiece.IsAlongAxis())
								{
									changesDirectionPunishment = 10;
								}
							}
						}
					}
				}
			}
			if (changesDirectionPunishment == 0 && nextPiece.IsAlongAxis() != nodePiece.IsAlongAxis())
			{
				changesDirectionPunishment = 5;
			}
			local canBeBuilt = nextPiece.Build();
			local alreadyBuilt = false;
			if (canBeBuilt)
			{
				if (AIError.GetLastError() == AIError.ERR_ALREADY_BUILT)
				{
					alreadyBuilt = true;
				}
			}
			//                           initRailCost
			//         nodePiece.tile    nextPiece.tile               bridgeEnd
			// RAIL -> RAIL           -> BRIDGE START -> BRIDGE    -> BRIDGE END -> RAIL
			//                                           obstackle
			local initRailCost = PathNode.GetNextTileCost(nextPiece.tile, alreadyBuilt, source, targets[0], changesDirectionPunishment);
			if (nextPiece.IsAlongAxis())
			{
				local neighbor = GetDirection(nodePiece.tile, nextPiece.tile);
				local bridgeEnd = GoToTile(nextPiece.tile, neighbor);
				if (!BuildWrapper(AIBridge.BuildBridge, [AIVehicle.VT_RAIL, bridgeTable[1], nextPiece.tile, bridgeEnd], true))
				{
					for (local length = 2; length <= maxBridgeLength; length++)
					{
						bridgeEnd = GoToTile(bridgeEnd, neighbor);
						if (BuildWrapper(AIBridge.BuildBridge, [AIVehicle.VT_RAIL, bridgeTable[length], nextPiece.tile, bridgeEnd], false))
						{
							local bridgeBuilt = (AIError.GetLastError() == AIError.ERR_ALREADY_BUILT);
							if (RailPiece(GoToTile(bridgeEnd, neighbor), nextPiece.orientation).Build())
							{
								local bridgeCost = PathNode.GetNextTileCost(bridgeEnd, bridgeBuilt, source, targets[0], 0);
								if (!bridgeBuilt)
								{
									bridgeCost += (length + 1) * 25;
								}
								openNodes.ReplaceIfBetter(PathNode.CreateNode(node, RailPiece(bridgeEnd, nextPiece.orientation).GetIndex(), initRailCost + bridgeCost, null, true, GetRemainingRailCost(bridgeEnd, targetPieces)));
								break;
							}
						}
					}
				}
			}
			else
			{
				initRailCost -= 3;
				if (initRailCost < 1)
				{
					initRailCost = 1;
				}
			}
			if (canBeBuilt)
			{
				openNodes.ReplaceIfBetter(PathNode.CreateNode(node, nextPiece.GetIndex(), initRailCost, null, false, GetRemainingRailCost(nextPiece.tile, targetPieces)));
			}
		}
	}
	PrintWarning("Too little iterations; path not found");
	return null;
}