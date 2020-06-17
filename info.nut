class NotPerfectAI extends AIInfo {
	function GetAuthor()      { return "hakerg"; }
	function GetName()        { return "NotPerfectAI"; }
	function GetDescription() { return "Uses all kinds of transport to maximize income"; }
	function GetVersion()     { return 1; }
	function GetDate()        { return "2020-05-07"; }
	function CreateInstance() { return "NotPerfectAI"; }
	function GetShortName()   { return "NPAI"; }
	function GetAPIVersion()  { return "1.10"; }
	
	function GetSettings()
	{
		AddSetting(
		{
			name = "buildTownConnections",
			description = "Build town connections",
			easy_value = 1,
			medium_value = 1,
			hard_value = 1,
			custom_value = 1,
			flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
		});
		AddSetting(
		{
			name = "buildIndustryConnections",
			description = "Build industry connections",
			easy_value = 1,
			medium_value = 1,
			hard_value = 1,
			custom_value = 1,
			flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
		});
		AddSetting(
		{
			name = "renameStations",
			description = "Rename stations",
			easy_value = 1,
			medium_value = 1,
			hard_value = 1,
			custom_value = 1,
			flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
		});
		AddSetting(
		{
			name = "useRoad",
			description = "Use road / tram vehicles",
			easy_value = 1,
			medium_value = 1,
			hard_value = 1,
			custom_value = 1,
			flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
		});
		AddSetting(
		{
			name = "usePlanes",
			description = "Use planes",
			easy_value = 1,
			medium_value = 1,
			hard_value = 1,
			custom_value = 1,
			flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
		});
		AddSetting(
		{
			name = "useShips",
			description = "Use ships",
			easy_value = 1,
			medium_value = 1,
			hard_value = 1,
			custom_value = 1,
			flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
		});
		AddSetting(
		{
			name = "useTrains",
			description = "Use trains",
			easy_value = 1,
			medium_value = 1,
			hard_value = 1,
			custom_value = 1,
			flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
		});
	}
}

RegisterAI(NotPerfectAI());