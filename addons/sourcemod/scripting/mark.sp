#pragma semicolon 1
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
    name = "Mark",
    author = "clagura",
    description = "Mark anywhere",
    version = PLUGIN_VERSION
};

public void OnPluginStart() {
    RegConsoleCmd("sm_mark", Mark, "Mark anywhere");
}

Action Mark(int client, int args) {
    float eye_pos[3], eye_angle[3], hit_pos[3];
    int hit_entity;
    char hit_classname[128];

    GetClientEyePosition(client, eye_pos);
    GetClientEyeAngles(client, eye_angle);

    TR_TraceRayFilter(eye_pos, eye_angle, MASK_VISIBLE, RayType_Infinite, TraceEntityFilterPlayer);
    if (TR_DidHit(INVALID_HANDLE)) {
        TR_GetEndPosition(hit_pos);
        hit_entity = TR_GetEntityIndex(INVALID_HANDLE);

        GetEntityClassname(hit_entity, hit_classname, 128);
        PrintToChat(client, "Hit %s, position: %f,%f,%f", hit_classname, hit_pos[0], hit_pos[1], hit_pos[2]);

        DispatchKeyValue(hit_entity, "glowable", "1");
        DispatchKeyValue(hit_entity, "glowblip", "1");
        DispatchKeyValueFloat(hit_entity, "glowdistance", 9999999.0);
        DispatchKeyValue(hit_entity, "glowcolor", /*isFull ? "255 0 0" :*/ "0 255 0"); // same as item pickup
        RequestFrame(Frame_GlowEntity, hit_entity);
    }

    return Plugin_Handled;
}

void Frame_GlowEntity(int entity)
{
	if (entity != -1) {
		AcceptEntityInput(entity, "enableglow"); 
	}
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) 
{
    return entity > MaxClients;
} 

