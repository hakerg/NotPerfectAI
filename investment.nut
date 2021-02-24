class Investment
{
	monthlyIncome = null;
	cost = null;
	score = null;
}

function Investment::GetReimbursementMonths()
{
	return (cost / monthlyIncome).tointeger();
}