#pragma semicolon 1
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>
#include <globalvariables>
#include <randomsupply>
#include <dhooks>

public Plugin MyInfo = {
    name = "Reconnect",
    author = "clagura",
    description = "Restore player's state when reconnect after an unexpected disconnect",
    version = PLUGIN_VERSION
};

#define PLAYER_STATE_LEN 15

ConVar sm_reconnect_max_interval;
ConVar sm_reconnect_choose_time;

StringMap g_hRestoredState;

Handle g_hSpawnPlayer, g_hStateTrans;
DynamicHook g_fnGetPlayerSpawnSpot;

Menu g_hChooseMenu;

int g_iSpawningPlayer;
float g_aPlayerState[MAXPLAYERS + 1][PLAYER_STATE_LEN];
char g_szPlayerAuth[MAXPLAYERS + 1][64];

public void OnPluginStart() {
    LoadTranslations("reconnect.phrases");
    sm_reconnect_max_interval = CreateConVar("sm_reconnect_max_interval", "300", "Player need reconnect in this time , in seconds.");
    sm_reconnect_choose_time = CreateConVar("sm_reconnect_choose_time", "30", "Player need choose whether to restore state in this time.");

    GameData gamedata = new GameData("reconnect.games");
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CNMRiH_Player::Spawn");
    g_hSpawnPlayer = EndPrepSDKCall();
    if (!IsValidHandle(g_hSpawnPlayer))
    {
        SetFailState("Failed to set up SDKCall for CNMRiH_Player::Spawn");
    }

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CSDKPlayer::State_Transition");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    g_hStateTrans = EndPrepSDKCall();
    if (!g_hStateTrans) {
        SetFailState("Failed to set up SDKCall for CSDKPlayer::State_Transition");
    }

    g_hRestoredState = new StringMap();

    int iGetPlayerSpawnSpotOffset = gamedata.GetOffset("CGameRules::GetPlayerSpawnSpot");
    if (iGetPlayerSpawnSpotOffset == -1) 
    {
        SetFailState("Failed to get offset to CGameRules::GetPlayerSpawnSpot");
    }
    g_fnGetPlayerSpawnSpot = new DynamicHook(iGetPlayerSpawnSpotOffset, HookType_GameRules, ReturnType_CBaseEntity, ThisPointer_Ignore);
    g_fnGetPlayerSpawnSpot.AddParam(HookParamType_CBaseEntity);   // CBasePlayer *

    g_hChooseMenu = new Menu(ChooseMenuHandler, MenuAction_Display|MenuAction_Select|MenuAction_DisplayItem|MenuAction_Cancel);
    g_hChooseMenu.SetTitle("Do you want to spawn?");
    g_hChooseMenu.AddItem("Yes", "Yes");
    g_hChooseMenu.AddItem("No", "No");

    delete gamedata;

    HookEvent("nmrih_reset_map", OnMapReset);
    HookEvent("player_disconnect", OnUserDisconnect, EventHookMode_Post);
    RegConsoleCmd("sm_rspawn", CmdRSpawn);
    RegAdminCmd("sm_fspawn", CmdFSpawn, ADMFLAG_CHEATS);
    
}

public void OnMapStart() {
    g_fnGetPlayerSpawnSpot.HookGamerules(Hook_Pre, DHook_GetPlayerSpawnSpot);
    g_hRestoredState.Clear();
}

MRESReturn DHook_GetPlayerSpawnSpot(DHookReturn ret)
{
	if (g_iSpawningPlayer > 0)
	{	
		ret.Value = g_iSpawningPlayer;
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

public void OnPluginEnd() {
    delete g_hRestoredState;
}

public void OnMapReset(Event e, const char[] n, bool b) {
    g_hRestoredState.Clear();
}

int ChooseMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Display) {
        char buffer[64];
        FormatEx(buffer, 64, "%T", "MenuTitle", param1);
    
        Panel panel = view_as<Panel>(param2);
        panel.SetTitle(buffer);
    }
    if (action == MenuAction_Select) {
        switch(param2) {
            case 0: {
                if (IsPlayerAlive(param1) && GetEntProp(param1, Prop_Send, "m_iPlayerState") == 0) {
                    g_hRestoredState.Remove(g_szPlayerAuth[param1]);
                    CPrintToChat(param1, 0, "{green}%t {white}%t", "Prefix", "AlreadyAlive");
                    return 0;
                }
                SetGived(param1, true);
                ForceSpawn(param1);
                RequestFrame(SetPlayerState, param1);
                g_hRestoredState.Remove(g_szPlayerAuth[param1]);
            }
            case 1: {
                g_hRestoredState.Remove(g_szPlayerAuth[param1]);
            }
        }
    }
    else if (action == MenuAction_DisplayItem) {
        char buffer[64], display[64];
        menu.GetItem(param2, buffer, 64, _, _, _, param1);
        Format(display, 64, "%T", buffer, param1);
        return RedrawMenuItem(display);
    }
    else if (action == MenuAction_Cancel) {
        g_hRestoredState.Remove(g_szPlayerAuth[param1]);
    }
    return 0;
}

public void OnClientPostAdminCheck(int iClient) {
    GetClientAuthId(iClient, AuthId_SteamID64, g_szPlayerAuth[iClient], 64);

    if (g_hRestoredState.GetArray(g_szPlayerAuth[iClient], g_aPlayerState[iClient], PLAYER_STATE_LEN)) {
        CPrintToChat(iClient, 0, "{green}%t {white}%t", "Prefix", "Notifi");
        g_hChooseMenu.Display(iClient, sm_reconnect_choose_time.IntValue);
    }
    // else {
    //     PrintToServer("%d not reconnect", iClient);
    // }
}

public Action OnUserDisconnect(Event event, const char[] name, bool dontBroadcast) {
    char szReason[128];
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    bool bStore = false;

    if (iClient != 0) {
        if (IsClientInGame(iClient)) {
            if (IsPlayerAlive(iClient) && GetEntProp(iClient, Prop_Send, "m_iPlayerState") == 0) {
                bStore = true;
            }
        }
    }

    if (!bStore) {
        return Plugin_Continue;
    }

    GetEventString(event, "reason", szReason, 128);

    if (StrContains(szReason, "Client not connected to Steam") != -1) {
        bStore = true;
    }
    else if (StrContains(szReason, "timed out") != -1) {
        bStore = true;
    }
    else if (StrContains(szReason, "Steam auth ticket has been canceled") != -1) {
        bStore = true;
    }
    else if (StrContains(szReason, "Lost connection") != -1) {
        bStore = true;
    }
    else {
        bStore = false;
    }

    if (bStore) {
        char szAuth[64];
        float aPlayerState[PLAYER_STATE_LEN];
        float vOrigin[3], vAngle[3];
        GetClientAuthId(iClient, AuthId_SteamID64, szAuth, 64);

        GetClientAbsOrigin(iClient, vOrigin);
        GetClientAbsAngles(iClient, vAngle);

        aPlayerState[0] = vOrigin[0];
        aPlayerState[1] = vOrigin[1];
        aPlayerState[2] = vOrigin[2];
        aPlayerState[3] = vAngle[0];
        aPlayerState[4] = vAngle[1];
        aPlayerState[5] = vAngle[2];
        aPlayerState[6] = float(GetEntProp(iClient, Prop_Send, "m_iHealth"));
        aPlayerState[7] = GetEntPropFloat(iClient, Prop_Send, "m_flStamina");
        aPlayerState[8] = GetEntPropFloat(iClient, Prop_Send, "m_flInfectionTime");
        aPlayerState[9] = GetEntPropFloat(iClient, Prop_Send, "m_flInfectionDeathTime");
        aPlayerState[10] = float(GetEntProp(iClient, Prop_Send, "_bleedingOut"));
        aPlayerState[11] = float(GetEntProp(iClient, Prop_Send, "_vaccinated"));
        aPlayerState[12] = float(GetEntProp(iClient, Prop_Data, "m_iFrags"));
        aPlayerState[13] = float(GetEntProp(iClient, Prop_Data, "m_iDeaths"));
        aPlayerState[14] = GetEngineTime();

        g_hRestoredState.SetArray(szAuth, aPlayerState, PLAYER_STATE_LEN);
    }

    return Plugin_Continue;
}

void ForceSpawn(int iClient)
{
    //SDKCall(sdkStateTrans, client, STATE_ACTIVE);
    g_iSpawningPlayer = iClient;
    SDKCall(g_hStateTrans, iClient, 0);
    SDKCall(g_hSpawnPlayer, iClient);
    g_iSpawningPlayer = -1;
}

Action CmdRSpawn(int iClient, int nArgs) {
    if (g_hRestoredState.GetArray(g_szPlayerAuth[iClient], g_aPlayerState[iClient], PLAYER_STATE_LEN)) {
        if (IsPlayerAlive(iClient) && GetEntProp(iClient, Prop_Send, "m_iPlayerState") == 0) {
            CPrintToChat(iClient, 0, "{green}%t {white}%t", "Prefix", "AlreadyAlive");
            return Plugin_Handled;
        }
        SetGived(iClient, true);
        ForceSpawn(iClient);
        RequestFrame(SetPlayerState, iClient);
        g_hRestoredState.Remove(g_szPlayerAuth[iClient]);
    }

    return Plugin_Handled;
}

Action CmdFSpawn(int iClient, int nArgs) {
    float vOrigin[3], vAngle[3];

    GetClientEyePosition(iClient,vOrigin);
    GetClientEyeAngles(iClient,vAngle);

    ForceSpawn(iClient);
    TeleportEntity(iClient, vOrigin, vAngle, NULL_VECTOR);

    return Plugin_Handled;
}

void SetPlayerState(int iClient) {
    float aPlayerState[PLAYER_STATE_LEN];
    aPlayerState = g_aPlayerState[iClient];

    float vOrigin[3], vAngle[3];
    vOrigin[0] = aPlayerState[0];
    vOrigin[1] = aPlayerState[1];
    vOrigin[2] = aPlayerState[2];
    vAngle[0] = aPlayerState[3];
    vAngle[1] = aPlayerState[4];
    vAngle[2] = aPlayerState[5];
    float fInterval = GetEngineTime() - aPlayerState[14];
    int iHealth = RoundFloat(aPlayerState[6]);

    SetEntPropFloat(iClient, Prop_Send, "m_flStamina", aPlayerState[7]);
    
    if (aPlayerState[9] != -1.0) {
        if (aPlayerState[9] - fInterval < 10.0) {
            SetEntPropFloat(iClient, Prop_Send, "m_flInfectionDeathTime", 10.0);
            SetEntPropFloat(iClient, Prop_Send, "m_flInfectionTime", aPlayerState[8] + aPlayerState[9] - 10.0);
        }
        else {
            SetEntPropFloat(iClient, Prop_Send, "m_flInfectionDeathTime", aPlayerState[9] - fInterval);
            SetEntPropFloat(iClient, Prop_Send, "m_flInfectionTime", aPlayerState[8] + fInterval);
        }
    }
    if (RoundFloat(aPlayerState[10]) == 1) {
        iHealth -=  RoundFloat(fInterval / 5.0);
        if (iHealth < 5) iHealth = 5;
        //SetEntProp(iClient, Prop_Send, "_bleedingOut", 1);
        SetCommandFlags("bleedout", GetCommandFlags("bleedout")^FCVAR_CHEAT);
        FakeClientCommand(iClient, "bleedout");
        SetCommandFlags("bleedout", GetCommandFlags("bleedout")|FCVAR_CHEAT);
    }
    if (RoundFloat(aPlayerState[11]) == 1) {
        SetEntProp(iClient, Prop_Send, "_vaccinated", 1);
    }
    SetEntProp(iClient, Prop_Data, "m_iFrags", RoundFloat(aPlayerState[12]));
    SetEntProp(iClient, Prop_Data, "m_iDeaths", RoundFloat(aPlayerState[13]));

    SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);

    TeleportEntity(iClient, vOrigin, vAngle, NULL_VECTOR);
}