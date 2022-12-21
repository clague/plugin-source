#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <globalvariables>
#include <getoverit>

#pragma newdecls required

ConVar cvarRocketMe;

int g_Explosion;

int g_Ent[MAXPLAYERS+1];
char GameName[64];

#define PLUGIN_VERSION "1.0.110"

// Functions
public Plugin myinfo = {
    name = "Evil Admin - Rocket",
    author = "<eVa>Dog",
    description = "Make a rocket with a player",
    version = PLUGIN_VERSION,
    url = "http://www.theville.org"
}

public void OnPluginStart() {
    CreateConVar("sm_evilrocket_version", PLUGIN_VERSION, " Evil Rocket Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    cvarRocketMe = CreateConVar("sm_rocketme_enabled", "1", " Allow players to suicide as a rocket", _);
    
    RegAdminCmd("sm_rocket", Command_EvilRocket, ADMFLAG_SLAY, "sm_evilrocket <#userid|name>");
    RegConsoleCmd("sm_rocketme", Command_RocketMe, " a fun way to suicide");
    RegConsoleCmd("sm_rm", Command_RocketMe, " a fun way to suicide");

    LoadTranslations("sm_evilrocket.phrases");
    LoadTranslations("common.phrases");
    
    GetGameFolderName(GameName, sizeof(GameName));
}

public void OnMapStart() {
    g_Explosion = PrecacheModel("sprites/sprite_fire01.vmt");
    
    PrecacheSound("ambient/explosions/exp2.wav", true);
    PrecacheSound("npc/env_headcrabcanister/launch.wav", true);
    PrecacheSound("weapons/rpg/rocketfire1.wav", true);
}

public Action Command_EvilRocket(int iClient, int nArgs) {
    char szTarget[64];
    char szTargetName[MAX_TARGET_LENGTH];
    int aTargets[MAXPLAYERS];
    int nTargets;
    bool bIsML;
    
    if (nArgs < 1) {
        ReplyToCommand(iClient, "[SM] Usage: sm_rocket <#userid|name>");
        return Plugin_Handled;
    }
    
    GetCmdArg(1, szTarget, sizeof(szTarget));
    
    if ((nTargets = ProcessTargetString(
            szTarget,
            iClient,
            aTargets,
            MAXPLAYERS,
            0,
            szTargetName,
            sizeof(szTargetName),
            bIsML
        )) <= 0) {
        ReplyToTargetError(iClient, nTargets);
        return Plugin_Handled;
    }
        
    for (int i = 0; i < nTargets; i++) {
        if (IsClientInGame(aTargets[i]) && IsPlayerAlive(aTargets[i])) {
            PerformEvilRocket(iClient, aTargets[i]);
        }
    }
    return Plugin_Handled;
}

void PerformEvilRocket(int iClient, int iTarget) {
    if (g_Ent[iTarget] == 0) {
        if (iClient != -1) {
            LogAction(iClient, iTarget, "\"%L\" sent \"%L\" into space", iClient, iTarget);
            ShowActivity(iClient, "launched %N into space", iTarget);
        }
        AttachFlame(iTarget);
        EmitSoundToAll("weapons/rpg/rocketfire1.wav", iTarget, _, _, _, 0.8);
        CreateTimer(2.0, Launch, GetClientUserId(iTarget), TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(3.5, Detonate, GetClientUserId(iTarget), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Launch(Handle hTimer, any iClient) {
    if ((iClient = GetClientOfUserId(iClient)) != 0 && IsClientInGame(iClient)) {
        float vVel[3];

        vVel[0] = 0.0;
        vVel[1] = 0.0;
        vVel[2] = 800.0;

        EmitSoundToAll("ambient/explosions/exp2.wav", iClient, _, _, _, 1.0);
        EmitSoundToAll("npc/env_headcrabcanister/launch.wav", iClient, _, _, _, 1.0);

        TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vVel);
        SetEntityGravity(iClient, 0.1);
    }

    return Plugin_Handled;
}

public Action Detonate(Handle hTimer, any iClient) {
    if ((iClient = GetClientOfUserId(iClient)) != 0 && IsClientInGame(iClient)) {
        float vPlayer[3];
        GetClientAbsOrigin(iClient, vPlayer);

        TE_SetupExplosion(vPlayer, g_Explosion, 10.0, 1, 0, 600, 5000, _, 'C');
        TE_SendToAll();

        ForcePlayerSuicide(iClient);

        SetEntityGravity(iClient, 1.0);
    }
    g_Ent[iClient] = 0;
    return Plugin_Handled;
}

public Action KillExplosion(Handle hTimer, any iEnt) {
    if (IsValidEntity(iEnt)) {
        char szClassname[256];
        GetEdictClassname(iEnt, szClassname, sizeof(szClassname));
        if (StrEqual(szClassname, "env_explosion", false)) {
            RemoveEdict(iEnt);
        }
    }

    return Plugin_Stop;
}

public void OnAdminMenuReady(Handle hMenu) {
    TopMenu hTopMenu = view_as<TopMenu>(hMenu);
    TopMenuObject playerCommands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

    if (playerCommands != INVALID_TOPMENUOBJECT) {
       hTopMenu.AddItem("sm_evilrocket", AdminMenu_Rocket, playerCommands, "sm_evilrocket", ADMFLAG_SLAY);
    }
}
 
public void AdminMenu_Rocket(TopMenu hTopMenu, TopMenuAction action, TopMenuObject obj, int iParam, char[] szBuffer, int nMaxLength) {
    if (action == TopMenuAction_DisplayOption) {
        FormatEx(szBuffer, nMaxLength, "%T", "EvilRocket", iParam);
    }
    else if (action == TopMenuAction_SelectOption) {
        DisplayPlayerMenu(iParam);
    }
}

void DisplayPlayerMenu(int iClient) {
    Menu hMenu = CreateMenu(MenuHandler_Players);
    
    char szTitle[64];
    FormatEx(szTitle, sizeof(szTitle), "%T", "ChoosePlayer", iClient);
    hMenu.SetTitle(szTitle);
    hMenu.ExitBackButton = true;
    
    AddTargetsToMenu(hMenu, iClient, true, true);
    
    hMenu.Display(iClient, 30);
}

public int MenuHandler_Players(Menu hMenu, MenuAction action, int iParam1, int iParam2) {
    if (action == MenuAction_End) {
        delete hMenu;
    }
    else if (action == MenuAction_Cancel) {
        if (iParam2 == MenuCancel_ExitBack)
        {
            TopMenu hTopMenu = GetAdminTopMenu();
            if (hTopMenu != INVALID_HANDLE) {
                hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
            }
        }
    }
    else if (action == MenuAction_Select) {
        char szInfo[32];
        int iUserId, iTarget;
        
        hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
        iUserId = StringToInt(szInfo);

        if ((iTarget = GetClientOfUserId(iUserId)) == 0) {
            PrintToChat(iParam1, "[SM] %t", "PlayerUnavailable");
        }
        else if (!CanUserTarget(iParam1, iTarget)) {
            PrintToChat(iParam1, "[SM] %t", "UnableToTarget");
        }
        else {
            PerformEvilRocket(iParam1, iTarget);
        }
        
        /* Re-draw the menu if they're still valid */
        if (IsClientInGame(iParam1) && !IsClientInKickQueue(iParam1) && !IsClientTimingOut(iParam1)) {
            DisplayPlayerMenu(iParam1);
        }
    }
    return 0;
}

void AttachFlame(int iEnt) {
    int iFlame = CreateEntityByName("env_steam");
    if (IsValidEdict(iFlame)) {
        float vPos[3];
        GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
        vPos[2] += 30;

        float vAngles[3];
        vAngles[0] = 90.0;
        vAngles[1] = 0.0;
        vAngles[2] = 0.0;

        DispatchKeyValue(iFlame, "spawnflags", "3"); 
        DispatchKeyValue(iFlame, "Type", "0");
        DispatchKeyValue(iFlame, "InitialState", "1");
        DispatchKeyValue(iFlame, "Spreadspeed", "100");
        DispatchKeyValue(iFlame, "Speed", "800");
        DispatchKeyValue(iFlame, "Startsize", "20");
        DispatchKeyValue(iFlame, "EndSize", "80");
        DispatchKeyValue(iFlame, "Rate", "50");
        DispatchKeyValue(iFlame, "JetLength", "400");
        char szTmp[16];
        FormatEx(szTmp, sizeof(szTmp), "%d %d %d", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
        DispatchKeyValue(iFlame, "rendercolor", szTmp);
        DispatchKeyValue(iFlame, "renderamt", "255");
        DispatchSpawn(iFlame);
        TeleportEntity(iFlame, vPos, vAngles, NULL_VECTOR);
        SetVariantString("!activator");
        AcceptEntityInput(iFlame, "SetParent", iEnt, iFlame, 0);

        CreateTimer(3.0, DeleteFlame, iFlame);

        g_Ent[iEnt] = iFlame;
    }
}

public Action DeleteFlame(Handle hTimer, any iEnt) {
    if (IsValidEntity(iEnt)) {
        char szClassName[256];
        GetEdictClassname(iEnt, szClassName, sizeof(szClassName));
        if (StrEqual(szClassName, "env_steam", false)) {
            AcceptEntityInput(iEnt, "Kill");
        }
    }

    return Plugin_Stop;
}

public Action Command_RocketMe(int iClient, int nArgs) {
    if (cvarRocketMe.BoolValue || CheckCommandAccess(iClient, "sm_evilrocket", ADMFLAG_SLAY)) {
        if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
        {
            PerformEvilRocket(-1, iClient);
            CreateTimer(3.0, MessageUs, iClient);
        }
    }
    else {
        PrintToChat(iClient, "{green}%t{white} %t", "ChatPrefix", "NotEnabled");
    }
    
    return Plugin_Handled;
}

public Action MessageUs(Handle hTimer, any iClient) {
    if (IsClientInGame(iClient)) {
        char szName[MAX_NAME_LENGTH];
        FetchColoredName(iClient, szName, sizeof(szName));
        CPrintToChatAll(iClient, "{green}%t{white} %t", "ChatPrefix", "RocketTip", szName);
    }

    return Plugin_Stop;
}
