enum HLXCE_PlayerData
{
	PData_Skill,
	PData_Kills,
	PData_Deaths,
	PData_Headshots,
	PData_ConnTime,
	PData_Shots,
	PData_Hits,
	PData_Rank
}

/**
 * @brief Are we ready to lookup HLX data for client
 *
 * @param		client		Client index
 * @return		bool
 */
native bool:HLXCE_IsClientReady(client);

/**
 * @brief Gets HLX player data for client
 *
 * @param		client		Client index
 * @noreturn
 */
native HLXCE_GetPlayerData(client);

/**
 * @brief When we have an HLX playerId for client
 *
 * @param		client		Client index
 * @noreturn
 */
forward HLXCE_OnClientReady(client);

/**
 * @brief When we receive requested player data for client
 *
 * @param		client		Client index
 * @noreturn
 */
forward HLXCE_OnGotPlayerData(client, const HLXCE_PlayerData:PData[]);


stock Float:HLXCE_kpd(kills, deaths)
{
	return FloatDiv(Float:kills/Float:((deaths==0),1,deaths));
}


stock Float:HLXCE_accuracy(shots, hits)
{
	return FloatDiv(Float:shots/Float:((hits==0),1,hits));
}