#pragma semicolon 1
#define PLUGIN_VERSION "1.0"

#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
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

bool gived[MAXPLAYERS + 1] = {false};
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
    g_bMacheteEnable = CreateConVar("sm_machete_enable", "1", "on = 1 , off = 0");
    HookEvent("player_spawn", EventPlayerRespawn);
    HookEvent("player_death", EventPlayerDeath);
    HookEvent("player_extracted", EventPlayerExtracted);

    HookEvent("nmrih_reset_map", OnMapReset);
}

public void OnMapReset(Event e, const char[] n, bool b) {
    g_bMacheteGived = false;
}

public void OnClientDisconnect(int client) {
    gived[client] = false;
}

public void OnMapStart() {
    for (int i = 0;i <= MAXPLAYERS; i++)
    {
        gived[i] = false;
    }
}

public Action:EventPlayerRespawn(Handle:event, const String:name[], bool:dontBroadcast) 
{
    if (g_bEnable.IntValue != 1)
        return;
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if(!gived[client]) {
        PrintToServer("hook respawn!");
        CreateTimer(0.2, GivePlayerSupply, client);
        gived[client] = true;
    }
    else {
        PrintToServer("Already gived, skip giving.");
    }
}

public Action:EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
    if (g_bEnable.IntValue != 1)
        return;
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    gived[client] = false;
}

public Action:EventPlayerExtracted(Event:event, const String:name[], bool:dontBroadcast) 
{
    if (g_bEnable.IntValue != 1)
        return;
    int client = event.GetInt("player_id");
    gived[client] = false;
}

public Action:GivePlayerSupply(Handle:timer, any:client)
{
    if(!IsPlayerAlive(client)) {
        PrintToServer("Not alive, skip giving.");
        gived[client] = false;
        return;
    }
    if (g_bMacheteEnable.BoolValue)
    {
        GiveItemIntoPlayer(client, "me_machete");
    }
    else if (!g_bMacheteGived)
    {
        int r = GetRandomInt(5, 10);
        if (r == 10) {
            g_bMacheteGived = true;
        }
        GiveItemIntoPlayer(client, melee_list[r]);
    }
    else {
        GiveItemIntoPlayer(client, melee_list[GetRandomInt(5, 9)])
    }
    if (g_bMacheteEnable.BoolValue)
    {
        GiveItemIntoPlayer(client, item_list[0]);
        GiveItemIntoPlayer(client, item_list[1]);
        GiveItemIntoPlayer(client, item_list[2]);
    }
    else {
        if(GetRandomInt(0, 1) == 0) {
            GiveItemIntoPlayer(client, item_list[0]);
        }
        if(GetRandomInt(0, 1) == 0) {
            GiveItemIntoPlayer(client, item_list[1]);
        }
        if(GetRandomInt(0, 1) == 0) {
            GiveItemIntoPlayer(client, item_list[2]);
        }
    }
    gived[client] = false;
}

public GiveItemIntoPlayer(int client, char[] item_name)
{
    int item = GivePlayerItem(client, item_name); 
    if (-1 == item) PrintToServer("Can't give item '%s' to '%N'", item_name, client);
    else if(!AcceptEntityInput(item, "use", client, client)) LogError("Can't AcceptEntityInput 'use' for item '%s'", item_name);
}

public any NativeSetGived(Handle plugin, int num_params) {
    int client = GetNativeCell(1);
    bool m_gived = GetNativeCell(2);
    gived[client] = m_gived;
    return 0;
}