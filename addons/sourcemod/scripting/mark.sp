#pragma semicolon 1
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colorvariables>
#include <getoverit>

public Plugin MyInfo = {
    name = "Mark",
    author = "clagura",
    description = "Mark anywhere",
    version = PLUGIN_VERSION
};

int g_iMarkItemEntRef[MAXPLAYERS + 1];
float g_fHitposRelative[MAXPLAYERS + 1][3];
float g_fLastMarkTime[MAXPLAYERS + 1];
Handle g_hMarkTimer[MAXPLAYERS + 1];
Handle g_hUpdatePointMessageTimer[MAXPLAYERS + 1];

ConVar sm_mark_inactive_interval;
ConVar sm_mark_cooldown_interval;
ConVar sm_mark_max_distance;
ConVar sm_mark_hull_size;
ConVar sm_mark_message_radius;

public void OnPluginStart() {
    LoadTranslations("mark.phrases");

    sm_mark_inactive_interval = CreateConVar("sm_mark_inactive_interval", "10.0", "Interval that a mark automatically disappear, in seconds.");
    sm_mark_cooldown_interval = CreateConVar("sm_mark_cooldown_interval", "1.0", "Interval between two mark action for a player, in seconds.");
    sm_mark_max_distance = CreateConVar("sm_mark_max_distance", "2000.0", "Max distance that player can mark a item.");
    sm_mark_hull_size = CreateConVar("sm_mark_hull_size", "10.0", "Trace hull's size.");
    sm_mark_message_radius = CreateConVar("sm_mark_message_radius", "2048", "Message show radius.");

    RegConsoleCmd("sm_mark", CmdMark, "Mark anywhere");
    RegAdminCmd("sm_makemess", MakeMessage, ADMFLAG_GENERIC);
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
    // PrintToChat(iClient, "Mins: %f, %f, %f", fMinHull[0], fMinHull[1], fMinHull[2]);

    TR_TraceHullFilter(fEyePos, fEndPos, fMinHull, fMaxHull, MASK_VISIBLE, TraceEntityFilterPlayer);
    if (TR_DidHit(INVALID_HANDLE)) {
        TR_GetEndPosition(fHitPos);
        iHitEntity = TR_GetEntityIndex(INVALID_HANDLE);
        if (iHitEntity == 0) {
            return Plugin_Handled;
        }

        //disglow last mark
        if (g_iMarkItemEntRef[iClient] != 0) {
            UnmarkEntity(g_iMarkItemEntRef[iClient], iClient);

            if (EntRefToEntIndex(g_iMarkItemEntRef[iClient]) == iHitEntity) {
                g_iMarkItemEntRef[iClient] = 0;
                return Plugin_Handled;
            }
        }

        GetEntityClassname(iHitEntity, szHitClassname, 128);
        //PrintToChat(iClient, "Hit entity index: %d, classname: %s, position: %f,%f,%f",
        //    iHitEntity, szHitClassname, fHitPos[0], fHitPos[1], fHitPos[2]);

        //check if object glow entity
        bool bOtherMarked = false;
        for (int i = 1; i <= MaxClients; i++) {
            if (EntRefToEntIndex(g_iMarkItemEntRef[i]) == iHitEntity) {
                bOtherMarked = true;
            }
        }
        if (!bOtherMarked) {
            if ((FindSendPropInfo(szHitClassname, "m_bGlowBlip")) != -1) {
                if (GetEntProp(iHitEntity, Prop_Data, "m_bGlowBlip") == 1) {
                    return Plugin_Handled;
                }
            }
        }

        //cooldown
        if (GetEngineTime() - g_fLastMarkTime[iClient] > sm_mark_cooldown_interval.FloatValue) {
            g_fLastMarkTime[iClient] = GetEngineTime();
        }
        else {
            CPrintToChat(iClient, "{green}[Mark] {white}You need wait for {red}%1.1f {white}seconds for your next action.",
                sm_mark_cooldown_interval.FloatValue - GetEngineTime() + g_fLastMarkTime[iClient]);
            return Plugin_Handled;
        }
        MarkEntity(iHitEntity, iClient, fHitPos);

        char name[256];
        FetchColoredName(iClient, name, 256);

        for (int i = 1; i <= MaxClients; i++) {
            float fClientPos[3];
            char szDir[10];
            if (IsClientInGame(i)) {
                GetClientAbsOrigin(i, fClientPos);
                float dis = GetVectorDistance(fClientPos, fHitPos);
                if (dis <= 2000) {
                    CPrintToChat(i, "{green}[Mark] %s 标记了 {green}%s", name, szHitClassname);
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
                
                CPrintToChat(i, "{green}[Mark] %s {white}标记了 {green}%s{white}, 在{aqua}%s{white}方向, 距离你{red}%.1f{white}远",
            name, szHitClassname, szDir, dis);
            }
        }
    }
    return Plugin_Handled;
}

void MarkEntity(int iEntity, int iClient, float fHitPos[3])
{
    if (iEntity == -1) {
        return;
    }
    g_iMarkItemEntRef[iClient] = EntIndexToEntRef(iEntity);

    g_hUpdatePointMessageTimer[iClient] = CreateTimer(0.25, Timer_UpdatePointMessage, iClient, TIMER_REPEAT);

    float fEntOrigin[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fEntOrigin);
    g_fHitposRelative[iClient][0] = fHitPos[0] - fEntOrigin[0];
    g_fHitposRelative[iClient][1] = fHitPos[1] - fEntOrigin[1];
    g_fHitposRelative[iClient][2] = fHitPos[2] - fEntOrigin[2];

    Timer_UpdatePointMessage(INVALID_HANDLE, iClient);
    
    DispatchKeyValue(iEntity, "glowable", "1");
    DispatchKeyValueFloat(iEntity, "glowdistance", 99999999999.0);
    DispatchKeyValue(iEntity, "glowcolor", /*isFull ? "255 0 0" :*/ "0 255 0"); // same as item pickup

    RequestFrame(FrameMarkEntity, iClient);
    
    if (IsValidHandle(g_hMarkTimer[iClient])) {
        CloseHandle(g_hMarkTimer[iClient]);
    }
    g_hMarkTimer[iClient] = CreateTimer(sm_mark_inactive_interval.FloatValue, TimerUnmarkForClient, iClient);
}
Action Timer_UpdatePointMessage(Handle timer, int iClient) {
    int iEntity = EntRefToEntIndex(g_iMarkItemEntRef[iClient]);
    if (!IsValidEntity(iEntity)) {
        StopPointMessage(iClient);
        return Plugin_Stop;
    }
    char szMessage[64];
    if (IsClientInGame(iClient)) {
        FormatEx(szMessage, 128, "%N 的标记", iClient);
    }
    else {
        FormatEx(szMessage, 128, "某离开服务器玩家的标记");
    }

    float fEntOrigin[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fEntOrigin);
    fEntOrigin[0] += g_fHitposRelative[iClient][0];
    fEntOrigin[1] += g_fHitposRelative[iClient][1];
    fEntOrigin[2] += g_fHitposRelative[iClient][2];

    SendPointMessage(szMessage, iClient, fEntOrigin);
    return Plugin_Continue;
}

void FrameMarkEntity(int iClient) {
    int iEntity = EntRefToEntIndex(g_iMarkItemEntRef[iClient]);
    if (IsValidEntity(iEntity)) {
        AcceptEntityInput(iEntity, "enableglow");
    }
}

Action TimerUnmarkForClient(Handle hTimer, int iClient) {
    UnmarkEntity(g_iMarkItemEntRef[iClient], iClient);
    return Plugin_Stop;
}

void UnmarkEntity(int iEntRef, int iClient)
{
    int iEntity = EntRefToEntIndex(iEntRef);
    if (IsValidEntity(iEntity)) {
        AcceptEntityInput(iEntity, "disableglow");
        g_iMarkItemEntRef[iClient] = -1;
        //DispatchKeyValue(iEntity, "glowable", "0");
        //RequestFrame(FrameDisglowEntity, iEntRef);
    }
    if (IsValidHandle(g_hUpdatePointMessageTimer[iClient])) {
        delete g_hUpdatePointMessageTimer[iClient];
        StopPointMessage(iClient);
    }
}

public bool TraceEntityFilterPlayer(int iHitEntity, int iContentsMask) 
{
    return iHitEntity > MaxClients;
}

public int SendPointMessage(char szMessage[64], int iEntity, float pos[3]) {
    Handle msg = StartMessageAll("PointMessage", USERMSG_BLOCKHOOKS);
    BfWrite bf = UserMessageToBfWrite(msg);
    
    if (!IsValidEntity(iEntity)) {
        return -1;
    }
    bf.WriteString(szMessage); //message
    bf.WriteShort(iEntity); //entity
    bf.WriteShort(2);  //flags
    bf.WriteVecCoord(pos); //coord
    bf.WriteFloat(sm_mark_message_radius.FloatValue); //radius
    bf.WriteString("DebugFixedSmall"); //font
    bf.WriteByte(0); //r
    bf.WriteByte(255); //g
    bf.WriteByte(255); //b
    
    EndMessage();
    return 0;
}

public int StopPointMessage(int iEntity) {
    Handle msg = StartMessageAll("PointMessage", USERMSG_BLOCKHOOKS);
    BfWrite bf = UserMessageToBfWrite(msg);
    
    if (!IsValidEntity(iEntity)) {
        return -1;
    }
    bf.WriteString(""); //message
    bf.WriteShort(iEntity); //entity
    bf.WriteShort(0);  //flags
    bf.WriteVecCoord(NULL_VECTOR); //coord
    bf.WriteFloat(0.0); //radius
    bf.WriteString(""); //font
    bf.WriteByte(0); //r
    bf.WriteByte(0); //g
    bf.WriteByte(0); //b
    
    EndMessage();
    return 0;
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
        //SetVariantString("!activator");
        //AcceptEntityInput(iMessageEnt, "SetParent", iClient);
    }
    else {
        PrintToServer("Spawn message failed!");
    }
    return Plugin_Handled;
}
