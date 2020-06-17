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

function RailPiece::Build()
{
	if (AIRail.IsRailStationTile(tile) && AIRail.GetRailType(tile) == AIRail.GetCurrentRailType() && AICompany.IsMine(AITile.GetOwner(tile)) && AIRail.GetRailStationDirection(tile) == orientation)
	{
		return true;
	}
	return BuildWrapper(AIRail.BuildRailTrack, [tile, orientation], true);
}

function RailPiece::IsAlongAxis()
{
	return orientation == AIRail.RAILTRACK_NE_SW || orientation == AIRail.RAILTRACK_NW_SE;
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
	tableCostNode = null;
	arrayTileCostIndex = null;
	minAllocatedCost = null;
	maxAllocatedCost = null;
	bestCost = null;
}

function PathOpenList::constructor(indexCount, root)
{
	this.arrayTileCostIndex = LargeArray(indexCount);
	this.minAllocatedCost = root.totalCost;
	this.maxAllocatedCost = root.totalCost;
	this.bestCost = root.totalCost;
	this.tableCostNode = {};
	this.tableCostNode[root.totalCost] <- [root];
	this.arrayTileCostIndex.Set(root.index, [root.totalCost, 0]);
}

function PathOpenList::PopBest()
{
	while (tableCostNode[bestCost].len() == 0)
	{
		bestCost++;
		if (bestCost > maxAllocatedCost)
		{
			return null;
		}
	}
	local node = tableCostNode[bestCost].pop();
	arrayTileCostIndex.Set(node.index, null);
	return node;
}

function PathOpenList::RemoveNode(costIndex)
{
	local node = tableCostNode[costIndex[0]][costIndex[1]];
	arrayTileCostIndex.Set(node.index, null);
	for (local i = costIndex[1] + 1; i < tableCostNode[costIndex[0]].len(); i++)
	{
		local nodeAfter = tableCostNode[costIndex[0]][i];
		arrayTileCostIndex.Get(nodeAfter.index)[1]--;
	}
	tableCostNode[costIndex[0]].remove(costIndex[1]);
}

function PathOpenList::ReplaceIfBetter(node)
{
	local costIndex = arrayTileCostIndex.Get(node.index);
	if (costIndex == null || (costIndex[0] > node.totalCost))
	{
		if (costIndex != null)
		{
			RemoveNode(costIndex);
		}
		if (node.totalCost < bestCost)
		{
			bestCost = node.totalCost;
		}
		while (minAllocatedCost > node.totalCost)
		{
			minAllocatedCost--;
			tableCostNode[minAllocatedCost] <- [];
		}
		while (maxAllocatedCost < node.totalCost)
		{
			maxAllocatedCost++;
			tableCostNode[maxAllocatedCost] <- [];
		}
		arrayTileCostIndex.Set(node.index, [node.totalCost, tableCostNode[node.totalCost].len()]);
		tableCostNode[node.totalCost].append(node);
	}
}

function PathNode::GetScopeCost(slope)
{
	if ((slope == AITile.SLOPE_NWS) || (slope == AITile.SLOPE_WSE) || (slope == AITile.SLOPE_SEN) || (slope == AITile.SLOPE_ENW))
	{
		return 1;
	}
	else if ((slope == AITile.SLOPE_NS) || (slope == AITile.SLOPE_EW))
	{
		return 1;
	}
	else if ((slope == AITile.SLOPE_NW) || (slope == AITile.SLOPE_SW) || (slope == AITile.SLOPE_SE) || (slope == AITile.SLOPE_NE))
	{
		return 9;
	}
	else if ((slope == AITile.SLOPE_W) || (slope == AITile.SLOPE_S) || (slope == AITile.SLOPE_E) || (slope == AITile.SLOPE_N))
	{
		return 10;
	}
	else if (AITile.IsSteepSlope(slope))
	{
		return 10;
	}
	return 0;
}

function PathNode::GetExistingScopeCost(slope)
{
	if ((slope == AITile.SLOPE_NW) || (slope == AITile.SLOPE_SW) || (slope == AITile.SLOPE_SE) || (slope == AITile.SLOPE_NE)
		|| (slope == AITile.SLOPE_W) || (slope == AITile.SLOPE_S) || (slope == AITile.SLOPE_E) || (slope == AITile.SLOPE_N)
		|| AITile.IsSteepSlope(slope))
	{
		return 8;
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
	if (AITile.IsCoastTile(tile))
	{
		newCost = 16;
	}
	else if (AITile.IsFarmTile(tile))
	{
		newCost = 8;
	}
	else if (AITile.IsRockTile(tile) || AITile.IsRoughTile(tile))
	{
		newCost = 5;
	}
	else
	{
		newCost = 4;
	}
	return newCost + PathNode.GetScopeCost(AITile.GetSlope(tile));
}

function PathNode::GetNextTileCost(tile, alreadyBuilt, sourceTile, targetTile, changeDirectionPunishment)
{
	local cost = null;
	if (alreadyBuilt)
	{
		//cost = PathNode.GetExistingScopeCost(AITile.GetSlope(tile));
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
			cost += 32;
		}
	}
	return cost;
}

function GetRemainingRailCost(tile, targets)
{
	local cost = (CalculateDiagonalDistance(tile, targets[0]) * 8).tointeger();
	for (local i = 1; i < targets.len(); i++)
	{
		local newCost = (CalculateDiagonalDistance(tile, targets[i]) * 8).tointeger();
		if (newCost < cost)
		{
			cost = newCost;
		}
	}
	return cost;
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
	local openNodes = PathOpenList(mapSize, PathNode.CreateRoot(source, GetDirectionID(initDirection), totalDistance * 6));
	local maxBridgeLength = AIGameSettings.GetValue("construction.max_bridge_length");
	local bridgeTable = {};
	for (local length = 2; length <= maxBridgeLength; length++)
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
			if (!AIMap.IsValidTile(nextTile) || closedNodes.Get(nextTile) != null || !BuildWrapper(AIRoad.BuildRoad, [node.index, nextTile], true))
			{
				continue;
			}
			local initRoadCost = PathNode.GetNextTileCost(nextTile, (AIError.GetLastError() == AIError.ERR_ALREADY_BUILT), source, target, neighborID != node.directionID ? 4 : 0);
			local bridgeEnd = GoToTile(nextTile, neighbor);
			if (!BuildWrapper(AIRoad.BuildRoad, [nextTile, bridgeEnd], true))
			{
				local noBridge = !AIBridge.IsBridgeTile(nextTile);
				for (local length = 2; length <= maxBridgeLength; length++)
				{
					bridgeEnd = GoToTile(bridgeEnd, neighbor);
					if (BuildWrapper(AIBridge.BuildBridge, [AIVehicle.VT_ROAD, bridgeTable[length], nextTile, bridgeEnd], false))
					{
						local bridgeBuilt = (AIError.GetLastError() == AIError.ERR_ALREADY_BUILT);
						if (BuildWrapper(AIRoad.BuildRoad, [bridgeEnd, GoToTile(bridgeEnd, neighbor)], true))
						{
							local bridgeCost = PathNode.GetNextTileCost(bridgeEnd, bridgeBuilt, source, target, 0);
							if (!bridgeBuilt)
							{
								bridgeCost += length * 16 - 16;
							}
							openNodes.ReplaceIfBetter(PathNode.CreateNode(node, bridgeEnd, initRoadCost + bridgeCost, neighborID, true, AIMap.DistanceManhattan(bridgeEnd, target) * 6));
							break;
						}
					}
					else if (noBridge && AIError.GetLastError() == AIError.ERR_AREA_NOT_CLEAR)
					{
						break;
					}
				}
			}
			openNodes.ReplaceIfBetter(PathNode.CreateNode(node, nextTile, initRoadCost, neighborID, false, AIMap.DistanceManhattan(nextTile, target) * 6));
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
	local openNodes = PathOpenList(mapSize, PathNode.CreateRoot(source, null, totalDistance));
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
		targetPieces.append(targetPiece);
	}
	local pieceCount = AIMap.GetMapSizeX() * AIMap.GetMapSizeY() * 6;
	local closedNodes = LargeArray(pieceCount);
	local openNodes = PathOpenList(pieceCount, PathNode.CreateRoot(sourcePiece.GetIndex(), null, GetRemainingRailCost(source, targets)));
	local maxBridgeLength = AIGameSettings.GetValue("construction.max_bridge_length");
	local bridgeTable = {};
	for (local length = 2; length <= maxBridgeLength; length++)
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
			if (AIRail.GetRailTracks(nextPiece.tile) != 0 && (AIRail.GetRailTracks(nextPiece.tile) & nextPiece.orientation) == 0)
			{
				continue;
			}
			local changesDirectionPunishment = 0;
			if (motherPiece != null)
			{
				if (nextPiece.IsAlongAxis() != nodePiece.IsAlongAxis() && nodePiece.IsAlongAxis() != motherPiece.IsAlongAxis())
				{
					changesDirectionPunishment = 8;
				}
				else
				{
					if (node.mother.mother != null)
					{
						local grandMotherPiece = RailPiece.CreateFromIndex(node.mother.mother.index);
						if (grandMotherPiece.IsAlongAxis() != motherPiece.IsAlongAxis() && motherPiece.IsAlongAxis() != nextPiece.IsAlongAxis())
						{
							changesDirectionPunishment = 3;
						}
						else if (grandMotherPiece.IsAlongAxis() != nodePiece.IsAlongAxis() && nodePiece.IsAlongAxis() != nextPiece.IsAlongAxis())
						{
							changesDirectionPunishment = 3;
						}
						else
						{
							if (node.mother.mother.mother != null)
							{
								local grandGrandMotherPiece = RailPiece.CreateFromIndex(node.mother.mother.mother.index);
								if (grandGrandMotherPiece.IsAlongAxis() != grandMotherPiece.IsAlongAxis() && grandMotherPiece.IsAlongAxis() != nextPiece.IsAlongAxis())
								{
									changesDirectionPunishment = 1;
								}
								else if (grandGrandMotherPiece.IsAlongAxis() != nodePiece.IsAlongAxis() && nodePiece.IsAlongAxis() != nextPiece.IsAlongAxis())
								{
									changesDirectionPunishment = 1;
								}
							}
						}
					}
				}
			}
			local initRailCost = PathNode.GetNextTileCost(nextPiece.tile, (AIError.GetLastError() == AIError.ERR_ALREADY_BUILT), source, targets[0], changesDirectionPunishment);
			if (nextPiece.IsAlongAxis())
			{
				local neighbor = GetDirection(nodePiece.tile, nextPiece.tile);
				local bridgeEnd = GoToTile(nextPiece.tile, neighbor);
				if (!BuildWrapper(AIRail.BuildRailTrack, [bridgeEnd, nextPiece.orientation], true) || (AIRail.GetRailTracks(bridgeEnd) != 0 && (AIRail.GetRailTracks(bridgeEnd) & nextPiece.orientation) == 0))
				{
					local noBridge = !AIBridge.IsBridgeTile(nextPiece.tile);
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
									bridgeCost += length * 16 - 16;
								}
								openNodes.ReplaceIfBetter(PathNode.CreateNode(node, RailPiece(bridgeEnd, nextPiece.orientation).GetIndex(), initRailCost + bridgeCost, null, true, GetRemainingRailCost(bridgeEnd, targets)));
								break;
							}
						}
						else if (noBridge && AIError.GetLastError() == AIError.ERR_AREA_NOT_CLEAR)
						{
							break;
						}
					}
				}
			}
			else
			{
				initRailCost--;
			}
			if (nextPiece.Build())
			{
				openNodes.ReplaceIfBetter(PathNode.CreateNode(node, nextPiece.GetIndex(), initRailCost, null, false, GetRemainingRailCost(nextPiece.tile, targets)));
			}
		}
	}
	PrintWarning("Too little iterations; path not found");
	return null;
}