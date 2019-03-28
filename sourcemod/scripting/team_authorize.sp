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

Handle g_hLocked = INVALID_HANDLE;
char ct_steamIDs[5][32];
char tt_steamIDs[5][32];
char all_steamIDs[10][32];
int all_clients[10];

public void OnPluginStart()
{
	AddCommandListener(Command_JoinTeam, "jointeam");
	g_hLocked = CreateConVar("sm_lock_teams", "1", "Enable or disable locking teams during match", FCVAR_NOTIFY);
	HookEvent("player_activate", PlayerActivate, EventHookMode_Post);
	GetAllowedTeamsSteamIDs();

	for(int i = 0; i < 10; i++) {
		all_clients[i] = -1;
	}
}

public void OnClientPutInServer(int client)
{
	char authId[32];
	GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));

	if(!IsClientAllowed(authId)) {
		KickClient(client, "You are not allowed to enter this server");
	} else {
		AssociateSteamIdWithClient(authId, client);
	}
}

public void OnClientDisconnect_Post(int client)
{
	char authId[32];
	GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
	DisassociateSteamIdWithClient(authId);
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason) 
{ 
	WriteScoreFile();
	return Plugin_Continue; 
}

public void AssociateSteamIdWithClient(char[] steamID, int client)
{
	for(int i = 0; i < 10; i++) {
		if(StrEqual(steamID, all_steamIDs[i])) {
			all_clients[i] = client;
			break;
		}
	}
}

public void DisassociateSteamIdWithClient(char[] steamID)
{
	for(int i = 0; i < 10; i++) {
		if(StrEqual(steamID, all_steamIDs[i])) {
			all_clients[i] = -1;
			break;
		}
	}
}

public void WriteScoreFile()
{
	char path[PLATFORM_MAX_PATH];
	char scoreString[256], ctTeam[256], tTeam[256];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "data/match_result.txt");
	DeleteFile(path, false, NULL_STRING);

	Handle fileHandle = OpenFile(path, "w");

	int ctScore = CS_GetTeamScore(CS_TEAM_CT);
	int tScore = CS_GetTeamScore(CS_TEAM_T);
	GetSteamIDsStringByCurrentTeam(CS_TEAM_CT, ctTeam, sizeof(ctTeam));
	GetSteamIDsStringByCurrentTeam(CS_TEAM_T, tTeam, sizeof(tTeam));
	Format(scoreString, 256, "CT=%d;T=%d;CT_TEAM=%s;T_TEAM=%s", ctScore, tScore, ctTeam, tTeam);
	
	WriteFileString(fileHandle, scoreString, true);
	CloseHandle(fileHandle);
}

public void GetSteamIDsStringByCurrentTeam(int team, char[] buffer, int bufferLength)
{
	char steamIDs[5][32];
	int numberClients = 0;

	for(int i = 0; i < 10; i++) {
		if(all_clients[i] > 0) {
			if(GetClientTeam(all_clients[i]) == team) {
				GetClientAuthId(all_clients[i], AuthId_Steam2, steamIDs[numberClients], 32);
				numberClients++;
			}
		}
	}

	ImplodeStrings(steamIDs, numberClients, ",", buffer, bufferLength);
}

public void GetAllowedTeamsSteamIDs()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "data/ct_steam_ids.txt");
	Handle fileHandle = OpenFile(path, "r");
	
	int i = 0;
	int j = 0;
	while(!IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, ct_steamIDs[i], 32) && i < 5) {
		TrimString(ct_steamIDs[i]);
		all_steamIDs[j] = ct_steamIDs[i];
		i++;
		j++;
	}

	CloseHandle(fileHandle);

	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "data/tt_steam_ids.txt");
	fileHandle = OpenFile(path, "r");

	i = 0;
	while(!IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, tt_steamIDs[i], 32) && i < 5) {
		TrimString(tt_steamIDs[i]);
		all_steamIDs[j] = ct_steamIDs[i];
		i++;
		j++;
	}

	CloseHandle(fileHandle);
}

public bool IsClientAllowed(char[] authId)
{
	if(strcmp(authId, "BOT") == 0) {
		return true;
	}

	for(int i = 0; i < 5; i++) {
		if(StrEqual(ct_steamIDs[i], authId)) {
			return true;
		}
	}

	for(int i = 0; i < 5; i++) {
		if(StrEqual(tt_steamIDs[i], authId)) {
			return true;
		}
	}

	return false;
}

public void SelectTeam(int client, char[] authId)
{
	for(int i = 0; i < 5; i++) {
		if(StrEqual(ct_steamIDs[i], authId)) {
			SwitchTeam(client, CS_TEAM_CT);
		} else if(StrEqual(tt_steamIDs[i], authId)) {
			SwitchTeam(client, CS_TEAM_T);
		}
	}
}

public void SwitchTeam(int client, int team)
{
	int currentTeam = GetClientTeam(client);
	if(currentTeam != team) {
		ChangeClientTeam(client, team);
	}
}

public Action PlayerActivate(Handle event, const char[] name, bool dontBroadcast)
{
	char authId[32];
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
	SelectTeam(client, authId);
}

public Action Command_JoinTeam(client, const String:command[], args)
{    
    if(client != 0) {
        if(IsClientInGame(client) && !IsFakeClient(client)) {
            if(GetClientTeam(client) > 1 && GetConVarBool(g_hLocked)) {
                PrintToChat(client, "\x01 \x07You cannot change your team during a match!");
                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue;
}  