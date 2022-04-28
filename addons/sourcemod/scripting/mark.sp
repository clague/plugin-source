#pragma semicolon 1
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>
#include <colorvariables>
#include <getoverit>

public Plugin MyInfo = {
    name = "Mark",
    author = "clagura",
    description = "Mark anywhere",
    version = PLUGIN_VERSION
};

int g_iMarkedItemRef[MAXPLAYERS + 1];
int g_iMarkedMessageRef[MAXPLAYERS + 1];
float g_fLastMarkTime[MAXPLAYERS + 1];
Handle g_hMarkedTimer[MAXPLAYERS + 1];

ConVar sm_mark_inactive_interval;
ConVar sm_mark_cooldown_interval;
ConVar sm_mark_max_distance;
ConVar sm_mark_hull_size;

public void OnPluginStart() {
    LoadTranslations("mark.phrases");

    sm_mark_inactive_interval = CreateConVar("sm_mark_inactive_interval", "10.0", "Interval that a mark auto disappear, in seconds.");
    sm_mark_cooldown_interval = CreateConVar("sm_mark_cooldown_interval", "1.0", "Interval between two mark action for a player, in seconds.");
    sm_mark_max_distance = CreateConVar("sm_mark_max_distance", "2000.0", "Max distance that player can mark a item.");
    sm_mark_hull_size = CreateConVar("sm_mark_hull_size", "10.0", "Trace hull's size.");

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
        int iEntRef = EntIndexToEntRef(iHitEntity);

        //disglow last mark
        if (g_iMarkedItemRef[iClient] != 0) {
            UnmarkEntity(g_iMarkedItemRef[iClient], g_iMarkedMessageRef[iClient], iClient);

            if (EntRefToEntIndex(g_iMarkedItemRef[iClient]) == iHitEntity) {
                g_iMarkedItemRef[iClient] = 0;
                return Plugin_Handled;
            }
        }

        GetEntityClassname(iHitEntity, szHitClassname, 128);
        //PrintToChat(iClient, "Hit entity index: %d, classname: %s, position: %f,%f,%f",
        //    iHitEntity, szHitClassname, fHitPos[0], fHitPos[1], fHitPos[2]);

        //check if object glow entity
        bool bOtherMarked = false;
        for (int i = 1; i <= MaxClients; i++) {
            if (EntRefToEntIndex(g_iMarkedItemRef[i]) == iHitEntity) {
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
            name, szHitClassname, szDir, GetVectorDistance(fClientPos, fHitPos));
            }
        }
        
        g_iMarkedItemRef[iClient] = iEntRef;
    }

    return Plugin_Handled;
}

void MarkEntity(int iEntity, int iClient, float fHitPos[3])
{
    if (iEntity == -1) {
        return;
    }
    int iMessageEnt = CreateEntityByName("point_message");
    char szMessage[64];
    FormatEx(szMessage, 64, "%N 的标记", iClient);
    DispatchKeyValue(iMessageEnt, "message", szMessage);
    DispatchKeyValue(iMessageEnt, "radius", "8192");
    
    if (!DispatchSpawn(iMessageEnt)) {
        PrintToServer("Spawn message failed!");
    }
    else {
        TeleportEntity(iMessageEnt, fHitPos);
        //SetVariantString("!activator");
        //AcceptEntityInput(iMessageEnt, "SetParent", iEntity, iMessageEnt);
        int iMessEntRef = EntIndexToEntRef(iMessageEnt);
        RequestFrame(FrameEnableMessage, iMessEntRef);

        g_iMarkedMessageRef[iClient] = iMessEntRef;
    }
    
    DispatchKeyValue(iEntity, "glowable", "1");
    DispatchKeyValueFloat(iEntity, "glowdistance", 99999999999.0);
    DispatchKeyValue(iEntity, "glowcolor", /*isFull ? "255 0 0" :*/ "0 255 0"); // same as item pickup

    RequestFrame(FrameMarkEntity, EntIndexToEntRef(iEntity));
    
    if (IsValidHandle(g_hMarkedTimer[iClient])) {
        CloseHandle(g_hMarkedTimer[iClient]);
    }
    g_hMarkedTimer[iClient] = CreateTimer(sm_mark_inactive_interval.FloatValue, TimerUnMarkForClient, iClient);
}

void FrameEnableMessage(int iMessEntRef) {
    AcceptEntityInput(EntRefToEntIndex(iMessEntRef), "Enable");
}

void FrameMarkEntity(int iEntRef)
{
    int iEntity = EntRefToEntIndex(iEntRef);
    if (IsValidEntity(iEntity)) {
        AcceptEntityInput(iEntity, "enableglow"); 
    }
}

Action TimerUnMarkForClient(Handle hTimer, int iClient) {
    UnmarkEntity(g_iMarkedItemRef[iClient], g_iMarkedMessageRef[iClient], iClient);
    return Plugin_Stop;
}

void UnmarkEntity(int iEntRef, int iMessageRef, int iClient)
{
    int iEntity = EntRefToEntIndex(iEntRef);
    int iMessageEnt = EntRefToEntIndex(iMessageRef);
    if (IsValidEntity(iEntity)) {
        AcceptEntityInput(iEntity, "disableglow");
        g_iMarkedItemRef[iClient] = -1;
        //DispatchKeyValue(iEntity, "glowable", "0");
        //RequestFrame(FrameDisglowEntity, iEntRef);
    }
    if (IsValidEntity(iMessageEnt)) {
        AcceptEntityInput(iMessageEnt, "Kill");
        g_iMarkedMessageRef[iClient] = -1;
    }
}

void FrameUnmarkEntity(int iEntRef)
{
    int iEntity = EntRefToEntIndex(iEntRef);
    if (iEntity != -1) {
        AcceptEntityInput(iEntity, "disableglow");
    }
}

public bool TraceEntityFilterPlayer(int iHitEntity, int iContentsMask) 
{
    return iHitEntity > MaxClients;
} 

Action MakeMessage(int iClient, int nArgs) {
    float fPos[3];
    GetClientEyePosition(iClient, fPos);

    int iMessageEnt = CreateEntityByName("point_message");
    char szMessage[64];
    FormatEx(szMessage, 64, "%N 的标记", iClient);
    DispatchKeyValue(iMessageEnt, "message", szMessage);
    DispatchKeyValue(iMessageEnt, "radius", "8192");

    if (DispatchSpawn(iMessageEnt)) {
        TeleportEntity(iMessageEnt, fPos);

        int iMessEntRef = EntIndexToEntRef(iMessageEnt);
        RequestFrame(FrameEnableMessage, iMessEntRef);
    }
    else {
        PrintToServer("Spawn message failed!");
    }
    return Plugin_Handled;
}
