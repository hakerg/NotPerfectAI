class Investment
{
	monthlyIncome = null;
	cost = null;
	score = null;
}

function Investment::GetReimbursementMonths()
{
	return (1.0 / score).tointeger();
}