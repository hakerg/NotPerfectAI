require("utils.nut");

class CargoNode
{
	type = null;
	id = null;
}

function CargoNode::constructor(type, id)
{
	this.type = type;
	this.id = id;
}

function CargoNode::IsEqualTo(other)
{
	return id == other.id && type == other.type;
}

function CargoNode::GetName()
{
	return type.GetName(id);
}

function CargoNode::GetLocation()
{
	return type.GetLocation(id);
}

function CargoNode::GetLastMonthProduction(cargo)
{
	return type.GetLastMonthProduction(id, cargo);
}

function CargoNode::GetLastMonthTransportedPercentage(cargo)
{
	return type.GetLastMonthTransportedPercentage(id, cargo);
}

function CargoNode::GetHeliportLocation()
{
	return type.GetHeliportLocation(id);
}

function CargoNode::GetDockLocation()
{
	return type.GetDockLocation(id);
}