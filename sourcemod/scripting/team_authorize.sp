#include <sourcemod>
#include <cstrike>

public Plugin myinfo =
{
	name = "Team Authorize",
	author = "David Mazzitelli",
	description = "Allows players to enter the server if they are included in a list of whitelisted Steam IDs and auto select teams",
	version = "0.1",
	url = ""
};

char ct_steamIDs[5][32];
char tt_steamIDs[5][32];
int player_teamSelected[10];

public void OnPluginStart()
{
	HookEvent("player_team", EventPlayerTeam, EventHookMode_Pre);  
	GetAllowedTeamsSteamIDs();
}

public void OnClientPutInServer(int client)
{
	char authId[32];

	GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));

	if(!IsClientAllowed(authId)) {
		KickClient(client, "You are not allowed to enter this server");
	}

	RemoveClientTeamSelected(client);
}

public void GetAllowedTeamsSteamIDs()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "data/ct_steam_ids.txt");
	Handle fileHandle = OpenFile(path, "r");
	
	int i = 0;
	while(!IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, ct_steamIDs[i], 32) && i < 5) {
		TrimString(ct_steamIDs[i]);
		i++;
	}

	CloseHandle(fileHandle);

	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "data/tt_steam_ids.txt");
	fileHandle = OpenFile(path, "r");

	i = 0;
	while(!IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, tt_steamIDs[i], 32) && i < 5) {
		TrimString(tt_steamIDs[i]);
		i++;
	}

	CloseHandle(fileHandle);

	for(int j = 0; j < 10; j++) {
		player_teamSelected[j] = -1;
	}
}

public bool IsClientAllowed(char[] authId)
{
	if(strcmp(authId, "BOT") == 0) {
		return true;
	}

	for(int i = 0; i < 5; i++) {
		if(strcmp(ct_steamIDs[i], authId) == 0) {
			return true;
		}
	}

	for(int i = 0; i < 5; i++) {
		if(strcmp(tt_steamIDs[i], authId) == 0) {
			return true;
		}
	}

	return false;
}

public void SelectTeam(int client, char[] authId)
{
	for(int i = 0; i < 5; i++) {
		if(strcmp(ct_steamIDs[i], authId) == 0) {
			SwitchTeam(client, CS_TEAM_CT);
		} else if(strcmp(tt_steamIDs[i], authId) == 0) {
			SwitchTeam(client, CS_TEAM_T);
		}
	}
}

public void SwitchTeam(int client, int team)
{
	if(PlayerTeamSelectedHasClient(client)) {
		return;
	}

	StoreClientTeamSelected(client);

	int currentTeam = GetClientTeam(client);
	PrintToServer("TEAM AUTHORIZE == CHANGE CLIENT: %d FROM TEAM: %d TO TEAM %d", client, currentTeam, team);
	if(currentTeam != team) {
		CS_SwitchTeam(client, team);
	}
}

public bool PlayerTeamSelectedHasClient(int client)
{
	for(int i = 0; i < 10; i++) {
		if(player_teamSelected[i] == client) {
			return true;
		}
	}

	return false;
}

public void RemoveClientTeamSelected(int client)
{
	for(int i = 0; i < 10; i++) {
		if(player_teamSelected[i] == client) {
			player_teamSelected[i] = -1;
			break;
		}
	}
}

public void StoreClientTeamSelected(int client)
{
	for(int i = 0; i < 10; i++) {
		if(player_teamSelected[i] == -1) {
			player_teamSelected[i] = client;
			break;
		}
	}
}

public EventPlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	char authId[32];
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
	SelectTeam(client, authId);
}