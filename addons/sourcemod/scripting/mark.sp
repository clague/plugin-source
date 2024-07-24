#pragma semicolon 1
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <globalvariables>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <getoverit>

public Plugin MyInfo = {
    name = "Mark",
    author = "clagura",
    description = "Mark anywhere",
    version = PLUGIN_VERSION
};

bool g_bGetOverItLoaded = false;
int g_iMarkItemEntRef[MAXPLAYERS + 1];
int g_iMarkMessageEnt[MAXPLAYERS + 1];
float g_fLastMarkTime[MAXPLAYERS + 1];
Handle g_hMarkTimer[MAXPLAYERS + 1];
Handle g_hUpdatePointMessageTimer[MAXPLAYERS + 1];

ConVar sm_mark_inactive_interval;
ConVar sm_mark_cooldown_interval;
ConVar sm_mark_hit_world_default;
ConVar sm_mark_max_distance;
ConVar sm_mark_hull_size;
ConVar sm_mark_message_radius;
ConVar sm_mark_message_rgb;
ConVar sm_mark_message_font;
ConVar sm_mark_message_fontproportional;
ConVar sm_mark_message_fontdropshadow;

Cookie g_cookieHitWorld;

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int nErrMax)
{
    MarkNativeAsOptional("FetchColoredName");
    return APLRes_Success;
}

public void OnAllPluginsLoaded() {
    g_bGetOverItLoaded = LibraryExists("getoverit");
}

public void OnLibraryAdded(const char[] szName) {
	if (StrEqual(szName, "getoverit")) {
		g_bGetOverItLoaded = true;
	}
}

public void OnLibraryRemoved(const char[] szName) {
	if (StrEqual(szName, "getoverit")) {
		g_bGetOverItLoaded = false;
	}
}

public void OnPluginStart() {
    g_bGetOverItLoaded = LibraryExists("getoverit");
    //LoadTranslations("mark.phrases");

    sm_mark_inactive_interval = CreateConVar("sm_mark_inactive_interval", "10.0", "Interval that a mark automatically disappear, in seconds.");
    sm_mark_cooldown_interval = CreateConVar("sm_mark_cooldown_interval", "1.0", "Interval between two mark action for a player, in seconds.");
    sm_mark_hit_world_default = CreateConVar("sm_mark_hit_world_default", "0", "Default setting whether the player's mark can hit world, 0 - Cannot hit world, 1 - Can hit world");
    sm_mark_max_distance = CreateConVar("sm_mark_max_distance", "2000.0", "Max distance that player can mark a item.");
    sm_mark_hull_size = CreateConVar("sm_mark_hull_size", "10.0", "Trace hull's size.");
    sm_mark_message_radius = CreateConVar("sm_mark_message_radius", "2048", "Message show radius.");

    sm_mark_message_rgb = CreateConVar("sm_mark_message_rgb", "105 105 105", "Point message's RGB color");
    sm_mark_message_font = CreateConVar("sm_mark_message_font", "PointMessageDefault", "Point message's font type");
    sm_mark_message_fontproportional = CreateConVar("sm_mark_message_fontproportional", "1", "Point message's font size style");
    sm_mark_message_fontdropshadow = CreateConVar("sm_mark_message_fontdropshadow", "1", "Point message's font shadow style");

    g_cookieHitWorld = Cookie.Find("MarkHitWorld");
    if (g_cookieHitWorld == INVALID_HANDLE) {
        g_cookieHitWorld = new Cookie("MarkHitWorld", "标记是否可以对准环境使用/If your mark can target the world", CookieAccess_Public);
        if (g_cookieHitWorld == INVALID_HANDLE) {
            LogError("Cannot create cookie MarkHitWorld");
        }
    }
    g_cookieHitWorld.SetPrefabMenu(CookieMenu_YesNo_Int, "标记是否可以对准环境使用/If your mark can target the world");

    RegConsoleCmd("sm_mark", CmdMark, "Mark anywhere");
    RegAdminCmd("sm_makemess", MakeMessage, ADMFLAG_GENERIC);
}

public void OnClientDisconnect(int iClient) {
    delete g_hUpdatePointMessageTimer[iClient];
}

Action CmdMark(int iClient, int nArgs) {
    float fEyePos[3], fEyeAngle[3], fDir[3], fEndPos[3], fMaxHull[3], fMinHull[3], fHitPos[3];
    int iHitEntity;
    char szHitClassname[128];

    GetClientEyePosition(iClient, fEyePos);
    GetClientEyeAngles(iClient, fEyeAngle);

    //TR_TraceRayFilter(fEyePos, fEyeAngle, MASK_VISIBLE, RayType_Infinite, TraceEntityFilterPlayer);

    GetAngleVectors(fEyeAngle, fDir, NULL_VECTOR, NULL_VECTOR);

    fEndPos[0] = fEyePos[0] + sm_mark_max_distance.FloatValue * fDir[0];
    fEndPos[1] = fEyePos[1] + sm_mark_max_distance.FloatValue * fDir[1];
    fEndPos[2] = fEyePos[2] + sm_mark_max_distance.FloatValue * fDir[2];

    fMinHull[0] = -sm_mark_hull_size.FloatValue;
    fMinHull[1] = -sm_mark_hull_size.FloatValue;
    fMinHull[2] = -sm_mark_hull_size.FloatValue;

    fMaxHull[0] = sm_mark_hull_size.FloatValue;
    fMaxHull[1] = sm_mark_hull_size.FloatValue;
    fMaxHull[2] = sm_mark_hull_size.FloatValue;

    // GetClientMaxs(iClient, fMinHull);
    // LogMessage("Mins: %f, %f, %f", fMinHull[0], fMinHull[1], fMinHull[2]);

    TR_TraceHullFilter(fEyePos, fEndPos, fMinHull, fMaxHull, MASK_VISIBLE, TraceEntityFilterPlayer);
    if (TR_DidHit(INVALID_HANDLE)) {
        TR_GetEndPosition(fHitPos);
        iHitEntity = TR_GetEntityIndex(INVALID_HANDLE);
        if (iHitEntity == 0) {
            if (g_cookieHitWorld == INVALID_HANDLE || g_cookieHitWorld.GetInt(iClient, sm_mark_hit_world_default.IntValue) == 0) {
                return Plugin_Handled;
            }
        }

        //disglow last mark
        if (g_iMarkItemEntRef[iClient] != 0) {
            UnmarkEntity(iClient);

            if (EntRefToEntIndex(g_iMarkItemEntRef[iClient]) == iHitEntity) {
                g_iMarkItemEntRef[iClient] = 0;
                return Plugin_Handled;
            }
        }

        if (iHitEntity != 0) {
            GetEntityClassname(iHitEntity, szHitClassname, 128);
        } else {
            szHitClassname = "一处地点";
        }
        // LogMessage("Hit entity index: %d, classname: %s, position: %f,%f,%f",
        //    iHitEntity, szHitClassname, fHitPos[0], fHitPos[1], fHitPos[2]);

        //check if object glow entity
        bool bOtherMarked = false;
        for (int i = 1; i <= MaxClients; i++) {
            if (EntRefToEntIndex(g_iMarkItemEntRef[i]) == iHitEntity) {
                bOtherMarked = true;
                break;
            }
        }
        if (!bOtherMarked) {
            if (iHitEntity != 0 && FindSendPropInfo(szHitClassname, "m_bGlowBlip") != -1) {
                if (GetEntProp(iHitEntity, Prop_Data, "m_bGlowBlip") == 1) {
                    // LogMessage("任务物品，跳过");
                    return Plugin_Handled;
                }
            }
        }

        //cooldown
        if (GetEngineTime() - g_fLastMarkTime[iClient] > sm_mark_cooldown_interval.FloatValue) {
            g_fLastMarkTime[iClient] = GetEngineTime();
        }
        else {
            CPrintToChat(iClient, 0, "{green}[Mark] {white}操作过快，下次标记前你需要等待{red}%1.1f {white}秒！",
                sm_mark_cooldown_interval.FloatValue - GetEngineTime() + g_fLastMarkTime[iClient]);
            return Plugin_Handled;
        }
        MarkEntity(iHitEntity, iClient, fHitPos);

        char szName[256];
        if (g_bGetOverItLoaded) {
            FetchColoredName(iClient, szName, sizeof(szName));
        } else {
            GetClientName(iClient, szName, sizeof(szName));
        }

        for (int i = 1; i <= MaxClients; i++) {
            float fClientPos[3];
            char szDir[10];
            if (IsClientInGame(i)) {
                GetClientAbsOrigin(i, fClientPos);
                float dis = GetVectorDistance(fClientPos, fHitPos);
                if (dis <= 2000) {
                    CPrintToChat(i, 0, "{green}[Mark] %s 标记了 {green}%s", szName, szHitClassname);
                    continue;
                }

                if (fHitPos[0] - fClientPos[0] > 0) {
                    FormatEx(szDir, 10, "东");
                }
                else {
                    FormatEx(szDir, 10, "西");
                }
                if (fHitPos[1] - fClientPos[1] > 0) {
                    Format(szDir, 10, "%s北", szDir);
                }
                else {
                    Format(szDir, 10, "%s南", szDir);
                }
                
                CPrintToChat(i, 0, "{green}[Mark] %s 标记了 {green}%s{white}, 在{aqua}%s{white}方向, 距离你{red}%.1f{white}远", szName, szHitClassname, szDir, dis);
            }
        }
    }
    return Plugin_Handled;
}

void MarkEntity(int iEntity, int iClient, float fHitPos[3])
{
    if (!IsValidEntity(iEntity)) {
        return;
    }
    g_iMarkItemEntRef[iClient] = EntIndexToEntRef(iEntity);

    int iMessageEnt = CreateEntityByName("point_message_multiplayer");
    if (!IsValidEntity(iMessageEnt)) {
        // LogMessage("无法创建实体point_message_multiplayer！");
        return;
    }
    // LogMessage("创建实体point_message_multiplayer, index: %d！", iMessageEnt);

    char szMessage[64];
    if (IsClientInGame(iClient)) {
        FormatEx(szMessage, 128, "%N 的标记", iClient);
    }
    else {
        FormatEx(szMessage, 128, "某离开服务器玩家的标记");
    }

    DispatchKeyValue(iMessageEnt, "message", szMessage);
    char color[32], font[32];
    sm_mark_message_rgb.GetString(color, sizeof(color));
    sm_mark_message_font.GetString(font, sizeof(font));
    DispatchKeyValue(iMessageEnt, "color", color);
    DispatchKeyValue(iMessageEnt, "font", font);
    DispatchKeyValueInt(iMessageEnt, "fontproportional", sm_mark_message_fontproportional.IntValue);
    DispatchKeyValueInt(iMessageEnt, "fontdropshadow", sm_mark_message_fontdropshadow.IntValue);
    DispatchKeyValueFloat(iMessageEnt, "radius", sm_mark_message_radius.FloatValue);

    if (!DispatchSpawn(iMessageEnt)) {
        // LogMessage("无法生成实体point_message_multiplayer！");
        return;
    }

    TeleportEntity(iMessageEnt, fHitPos, NULL_VECTOR, NULL_VECTOR);

    SetVariantString("!activator");
    if (iEntity != 0) {
        AcceptEntityInput(iMessageEnt, "SetParent", iEntity);
    }

    g_iMarkMessageEnt[iClient] = iMessageEnt;

    if (iEntity != 0) {
        DispatchKeyValue(iEntity, "glowable", "1");
        DispatchKeyValueFloat(iEntity, "glowdistance", 99999999999.0);
        DispatchKeyValue(iEntity, "glowcolor", /*isFull ? "255 0 0" :*/ "0 255 0"); // same as item pickup
        AcceptEntityInput(iEntity, "enableglow");
    }
    
    if (IsValidHandle(g_hMarkTimer[iClient])) {
        CloseHandle(g_hMarkTimer[iClient]);
    }
    g_hMarkTimer[iClient] = CreateTimer(sm_mark_inactive_interval.FloatValue, TimerUnmarkForClient, iClient);
}

Action TimerUnmarkForClient(Handle hTimer, int iClient) {
    UnmarkEntity(iClient);
    return Plugin_Stop;
}

void UnmarkEntity(iClient)
{
    if (IsValidEntity(g_iMarkItemEntRef[iClient]) && g_iMarkItemEntRef[iClient] != 0) {
        AcceptEntityInput(g_iMarkItemEntRef[iClient], "disableglow");
        //DispatchKeyValue(iEntity, "glowable", "0");
        //RequestFrame(FrameDisglowEntity, iEntRef);
    }
    g_iMarkItemEntRef[iClient] = 0;
    if (IsValidEntity(g_iMarkMessageEnt[iClient]) && g_iMarkMessageEnt[iClient] != 0) {
        AcceptEntityInput(g_iMarkMessageEnt[iClient], "kill");
    }
    g_iMarkMessageEnt[iClient] = 0;
}

public bool TraceEntityFilterPlayer(int iHitEntity, int iContentsMask) 
{
    return iHitEntity > MaxClients;
}

Action MakeMessage(int iClient, int nArgs) {
    float fPos[3];
    GetClientEyePosition(iClient, fPos);

    int iMessageEnt = CreateEntityByName("point_message_multiplayer");
    char szMessage[64];
    FormatEx(szMessage, 64, "TESTTEST", iClient);
    DispatchKeyValue(iMessageEnt, "message", szMessage);
    DispatchKeyValue(iMessageEnt, "radius", "256");
    DispatchKeyValue(iMessageEnt, "font", "PointMessageDefault");
    DispatchKeyValue(iMessageEnt, "fontproportional", "1");
    DispatchKeyValue(iMessageEnt, "spawnflags", "0");
    DispatchKeyValue(iMessageEnt, "color", "0 0 255");

    if (DispatchSpawn(iMessageEnt)) {
        TeleportEntity(iMessageEnt, fPos);
        SetVariantString("!activator");
        AcceptEntityInput(iMessageEnt, "SetParent", iClient);
    }
    else {
        PrintToServer("Spawn message failed!");
    }
    return Plugin_Handled;
}