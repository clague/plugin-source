#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#pragma newdecls required

ConVar sv_mincmdrate;
ConVar sv_maxcmdrate;
ConVar sv_minupdaterate;
ConVar sv_maxupdaterate;
ConVar sv_minrate;
ConVar sv_maxrate;

public Plugin myinfo =
{
    name = "Networking",
    description = "Auto change network settings",
    author = "clagura",
    version = "1.0",
    url = "https://steamcommunity.com/id/wwwttthhh/"
};

public void OnPluginStart()
{
    sv_mincmdrate = FindConVar("sv_mincmdrate");
    sv_maxcmdrate = FindConVar("sv_maxcmdrate");
    sv_minupdaterate = FindConVar("sv_minupdaterate");
    sv_maxupdaterate = FindConVar("sv_maxupdaterate");
    sv_minrate = FindConVar("sv_minrate");
    sv_maxrate = FindConVar("sv_maxrate");

    HookEvent("player_spawn", EventPlayerSpawn);
    HookEvent("player_death", EventPlayerDeath);
    HookEvent("player_extracted", EventPlayerExtracted);
}

public Action EventPlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    CheckNetSettings();
    ResetRates(client);

    return Plugin_Continue;
}

public Action EventPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    CheckNetSettings();
    SetSpectatorRates(client);

    return Plugin_Continue;
}

public Action EventPlayerExtracted(Event event, const char[] name, bool dontBroadcast) {
    int client = event.GetInt("player_id");
    CheckNetSettings();
    SetSpectatorRates(client);

    return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client) {
    CreateTimer(3.0, CheckAlive, client);
}

public Action CheckAlive(Handle timer, int client) 
{
    if(IsClientInGame(client)) {
        if(!IsPlayerAlive(client))
            SetSpectatorRates(client);
    }
    CheckNetSettings();

    return Plugin_Handled;
}

public void CheckNetSettings()
{
    
    int alive_count = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i)) {
            if(IsPlayerAlive(i))
                alive_count++;
        }
    }
    if (GetClientCount()> 4) {
        ServerCommand("net_maxcleartime 0.1");
    }
    else {
        ServerCommand("net_maxcleartime 0.001");
    }
}


void SetSpectatorRates(int client)
{
    SendConVarValue(client, sv_mincmdrate, "15");
    SendConVarValue(client, sv_maxcmdrate, "16");
    SendConVarValue(client, sv_minupdaterate, "15");
    SendConVarValue(client, sv_maxupdaterate, "16");
    SendConVarValue(client, sv_minrate, "15000");
    SendConVarValue(client, sv_maxrate, "20000");
    ClientCommand(client, "cl_updaterate 15");
    ClientCommand(client, "cl_cmdrate 15");
    ClientCommand(client, "rate 16000");
}

void ResetRates(int client)
{
    char temp[32];

    sv_mincmdrate.GetString(temp, sizeof(temp));
    SendConVarValue(client, sv_mincmdrate, temp);

    sv_maxcmdrate.GetString(temp, sizeof(temp));
    SendConVarValue(client, sv_maxcmdrate, temp);

    sv_minupdaterate.GetString(temp, sizeof(temp));
    SendConVarValue(client, sv_minupdaterate, temp);

    sv_maxupdaterate.GetString(temp, sizeof(temp));
    SendConVarValue(client, sv_maxupdaterate, temp);

    sv_minrate.GetString(temp, sizeof(temp));
    SendConVarValue(client, sv_minrate, temp);

    sv_maxrate.GetString(temp, sizeof(temp));
    SendConVarValue(client, sv_maxrate, temp);
}