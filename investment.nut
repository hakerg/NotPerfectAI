class Investment
{
	monthlyIncome = null;
	cost = null;
	score = null;
}

function Investment::GetReimbursementMonths()
{
	return (1000.0 / score).tointeger();
}