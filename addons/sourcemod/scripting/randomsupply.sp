#pragma semicolon 1
#define PLUGIN_VERSION "1.0"

#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public Plugin myinfo = {
	name = "Respawn With Random Supply",
	author = "hsccc",
	description = "Respawn With Random Supply",
	version = PLUGIN_VERSION,
	url = ""
}

char melee_list[11][20] = {
    "me_axe_fire", 
    "me_bat_metal", 
    "me_fubar",
    "me_shovel",
    "me_sledge",
    "me_crowbar",
    "me_hatchet",
    "me_kitknife",
    "me_pipe_lead",
    "me_wrench",
    "me_machete",
};

char item_list[3][20] = {
    "item_bandages",
    "item_first_aid",
    "item_pills",
};

bool g_bGived[MAXPLAYERS + 1] = {false};
ConVar g_bEnable, g_bMacheteEnable;
bool g_bMacheteGived;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("SetGived", NativeSetGived);
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_bEnable = CreateConVar("sm_random_enable", "1", "on = 1 , off = 0");
    g_bMacheteEnable = CreateConVar("sm_machete_enable", "0", "on = 1 , off = 0");

    AutoExecConfig(true, "randomsupply");
    HookEvent("player_spawn", EventPlayerRespawn);
    HookEvent("player_death", EventPlayerDeath);
    HookEvent("player_extracted", EventPlayerExtracted);

    HookEvent("nmrih_reset_map", OnMapReset);
}

public void OnMapReset(Event e, const char[] n, bool b) {
    g_bMacheteGived = false;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bGived[i] = false;
    }
}

public void OnClientDisconnect(int iClient) {
    g_bGived[iClient] = false;
}

public void OnMapStart() {
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bGived[i] = false;
    }
}

public Action EventPlayerRespawn(Event e, const char[] szName, bool bDontBroadcast) 
{
    if (g_bEnable.BoolValue) {
        int iClient = GetClientOfUserId(e.GetInt("userid"));
        
        if(!g_bGived[iClient]) {
            CreateTimer(0.2, GivePlayerSupply, iClient);
            g_bGived[iClient] = true;
        }
        else {
            PrintToServer("Already gived, skip giving.");
        }
    }
    return Plugin_Continue;
}

public Action EventPlayerDeath(Event e, const char[] szName, bool bDontBroadcast) 
{
    if (g_bEnable.BoolValue) {
        int iClient = GetClientOfUserId(e.GetInt("userid"));
        g_bGived[iClient] = false;
    }
    return Plugin_Continue;
}

public Action EventPlayerExtracted(Event e, const char[] szName, bool bDontBroadcast) 
{
    if (g_bEnable.BoolValue) {
        int iClient = e.GetInt("player_id");
        g_bGived[iClient] = false;
    }
    return Plugin_Continue;
}

public Action GivePlayerSupply(Handle hTimer, any iClient)
{
    if(!IsPlayerAlive(iClient)) {
        PrintToServer("Not alive, skip giving.");
        g_bGived[iClient] = false;
        return Plugin_Stop;
    }
    if (g_bMacheteEnable.BoolValue)
    {
        GiveItemIntoPlayer(iClient, "me_machete");
    }
    else if (!g_bMacheteGived)
    {
        int r = GetRandomInt(5, 10);
        if (r == 10) {
            g_bMacheteGived = true;
        }
        GiveItemIntoPlayer(iClient, melee_list[r]);
    }
    else {
        GiveItemIntoPlayer(iClient, melee_list[GetRandomInt(5, 9)]);
    }
    if (g_bMacheteEnable.BoolValue)
    {
        GiveItemIntoPlayer(iClient, item_list[0]);
        GiveItemIntoPlayer(iClient, item_list[1]);
        GiveItemIntoPlayer(iClient, item_list[2]);
    }
    else {
        if(GetRandomInt(0, 1) == 0) {
            GiveItemIntoPlayer(iClient, item_list[0]);
        }
        if(GetRandomInt(0, 1) == 0) {
            GiveItemIntoPlayer(iClient, item_list[1]);
        }
        if(GetRandomInt(0, 1) == 0) {
            GiveItemIntoPlayer(iClient, item_list[2]);
        }
    }
    g_bGived[iClient] = false;

    return Plugin_Stop;
}

public void GiveItemIntoPlayer(int iClient, const char[] item_name)
{
    int item = GivePlayerItem(iClient, item_name); 
    if (-1 == item) PrintToServer("Can't give item '%s' to '%N'", item_name, iClient);
    else if(!AcceptEntityInput(item, "use", iClient, iClient)) LogError("Can't AcceptEntityInput 'use' for item '%s'", item_name);
}

public any NativeSetGived(Handle plugin, int num_params) {
    int iClient = GetNativeCell(1);
    bool m_gived = GetNativeCell(2);
    g_bGived[iClient] = m_gived;
    return 0;
}