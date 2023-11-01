#pragma semicolon 1
#define PLUGIN_VERSION "1.0"

#include <sdktools>
#include <sdkhooks>
#include <globalvariables>
#include <getoverit>

int nZombieCount = 0;
float g_pos[3];

public void OnPluginStart() {
    // HookUserMessage(GetUserMessageId("GameMessage"), OnUserMessage, true);
    // HookUserMessage(GetUserMessageId("BecameInfected"), OnUserMessage, true);
    // HookUserMessage(GetUserMessageId("InfectionCured"), OnUserMessage, true);
    // HookUserMessage(GetUserMessageId("Cure"), OnUserMessage, true);
    // if (!HookEventEx("entity_killed", Event_EntityKilled)) {
    //     LogError("hook entity_killed failed");
    // }
    LoadTranslations("delay_quit.phrases");
    
    RegConsoleCmd("sm_calc", Calc, "Calculate");
    RegAdminCmd("sm_tmi", TestMotdIndex, ADMFLAG_GENERIC);
    RegAdminCmd("sm_tarr", TestArrayAssign, ADMFLAG_GENERIC);
    RegAdminCmd("sm_count", CountZombies, ADMFLAG_GENERIC);
    RegAdminCmd("sm_make", MakeZombies, ADMFLAG_GENERIC);
    RegAdminCmd("sm_fakeclient", MakeFakeClient, ADMFLAG_GENERIC);
    RegServerCmd("sm_delay_quit", DelayQuit, "quit at a proper time");
}

public void Event_EntityKilled(Event hEvent, const char[] szName, bool bDontBroadcast) {

    int iEntKilled = hEvent.GetInt("entindex_killed", 0);
    int iEntAttacker = hEvent.GetInt("entindex_attacker", 0);
    int iEntInflictor = hEvent.GetInt("entindex_inflictor", 0);
    int iDamageBits = hEvent.GetInt("damagebits", 0);

    char szClassname[256];
    GetEntityClassname(iEntInflictor, szClassname, sizeof(szClassname));

    LogMessage("entindex_killed: %d, entindex_attacker: %d, entindex_inflictor: %d, damagebits: %d",
        iEntKilled, iEntAttacker, iEntInflictor, iDamageBits);
    LogMessage("inflictor: %s", szClassname);
}

public Action Calc(int iClient, int nArgs) {
    static char szBuffer[MAX_MESSAGE_LEN];
    GetCmdArgString(szBuffer, sizeof(szBuffer));

    ArrayStack RPNStack = new ArrayStack();
    ArrayList SymbolList = new ArrayList(ByteCountToCells(MAX_TOKEN_LENGTH));

    any iRes;
    if (ParseCondition(szBuffer, sizeof(szBuffer), RPNStack, SymbolList)) {
        if (CalculateRPN(RPNStack, SymbolList, iRes, false)) {
            ReplyToCommand(iClient, "%d", iRes);
            return Plugin_Handled;
        }
    }
    ReplyToCommand(iClient, "Failed");
    return Plugin_Handled;
}

public Action MakeFakeClient(int iClient, int nArgs) {
    CreateFakeClient("test");
    return Plugin_Continue;
}

public Action TestArrayAssign(int iClient, int nArgs)
{
    char szMsg[2][3];
    szMsg[0] = "12";
    szMsg[1] = "23";

    char szTest[3];
    szTest = szMsg[0];
    szTest[0] = '0';

    PrintToChat(iClient, "szMsg[0]: %s, szTest: %s", szMsg[0], szTest);
    return Plugin_Continue;
}

public Action OnUserMessage(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
    PrintToServer("msg %d: ", msg_id);
    for (int i = 0; bf.BytesLeft > 0; i++) {
        PrintToServer("%d", bf.ReadByte());
    }
    PrintToServer("Player: ");
    for (int i = 0; i < playersNum; i++) {
        PrintToServer("%d", players[i]);
    }
    return Plugin_Continue;
}

public void ShowHiddenMOTDPanel(int client, char[] url, int type)
{
    Handle setup = CreateKeyValues("data");
    KvSetString(setup, "title", "请点击播放按钮！");
    KvSetNum(setup, "type", type);
    KvSetString(setup, "msg", url);
    ShowVGUIPanel(client, "info", setup, false);
    delete setup;
}

public void ShowNotHiddenMOTDPanel(int client, char[] url, int type)
{
    Handle setup = CreateKeyValues("data");
    KvSetString(setup, "title", "请点击播放按钮！");
    KvSetNum(setup, "type", type);
    KvSetString(setup, "msg", url);
    ShowVGUIPanel(client, "info", setup, true);
    delete setup;
}

public Action TestMotdIndex(int client, int args)
{
    char msg[128];
    GetCmdArgString(msg, sizeof(msg));
    SetLongMOTD("motd_text", msg);
    ShowNotHiddenMOTDPanel(client, "motd_text", MOTDPANEL_TYPE_INDEX);
    return Plugin_Handled;
}

bool SetLongMOTD(const String:panel[],const String:text[]) {
    int table = FindStringTable("InfoPanel");

    if(table != INVALID_STRING_TABLE) {
        int len = strlen(text);
        int str = FindStringIndex(table,panel);
        bool locked = LockStringTables(false);

        SetStringTableData(table,str,text,len);

        LockStringTables(locked);
        return true;
    }

    return false;
}

public Action CountZombies(int client, int args)
{
    int nBig = 0, nKid = 0, i = MaxClients + 1, max = GetMaxEntities();
    char classname[30];
    while (i < max) {
        if (IsValidEntity(i)) {
            GetEntityClassname(i, classname, 30);
            if (StrEqual(classname, "npc_nmrih_runnerzombie"))
                nBig += 1;
            else if (StrEqual(classname, "npc_nmrih_shamblerzombie"))
                nBig += 1;
            else if (StrEqual(classname, "npc_nmrih_kidzombie"))
                nKid += 1;
            else if (StrEqual(classname, "npc_nmrih_turnedzombie"))
                nBig += 1;
        }
        i += 1;
    }
    CPrintToChat(client, 0, "当前有 {red}%d {white}个大僵尸，{red} %d {white}个小孩", nBig, nKid);
    return Plugin_Handled;
}

public Action MakeZombies(int client, int args)
{
    float vAngles[3];
    float vOrigin[3];
    float vBuffer[3];
    float vStart[3];
    float Distance;
    
    GetClientEyePosition(client,vOrigin);
    GetClientEyeAngles(client, vAngles);
    
    //get endpoint for teleport
    Handle hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
        
    if(TR_DidHit(hTrace))
    {   
        TR_GetEndPosition(vStart, hTrace);
        GetVectorDistance(vOrigin, vStart, false);
        Distance = -35.0;
        GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
        g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
        g_pos[1] = vStart[1] + (vBuffer[1]*Distance);
        g_pos[2] = vStart[2] + (vBuffer[2]*Distance);
    }
    else
    {
        CloseHandle(hTrace);
        return Plugin_Handled;
    }

    char str[10];
    GetCmdArg(1, str, 10);
    nZombieCount = StringToInt(str);

    if (nZombieCount == 0) nZombieCount = 1;
    
    CreateTimer(0.1, DelayCreateZombie, _, TIMER_REPEAT);
    
    CloseHandle(hTrace);
    return Plugin_Handled;
}

public Action DelayCreateZombie(Handle timer) {
    if (--nZombieCount >= 0) {
        int zombie = CreateEntityByName("npc_nmrih_runnerzombie");
        if(!IsValidEntity(zombie)) return Plugin_Continue;
        if(DispatchSpawn(zombie)) TeleportEntity(zombie, g_pos, NULL_VECTOR, NULL_VECTOR);
    }
    else return Plugin_Stop;
    return Plugin_Continue;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) 
{
    return entity > MaxClients;
}  

public Action DelayQuit(int args) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (IsPlayerAlive(i)) {
                PrintToChatAll("\x04%t\x01：%t", "Prefix", "DelayQuitSet");
                HookEvent("state_change", OnStateChange, EventHookMode_Post);
                return Plugin_Handled;
            }
        }
    }
    PrintToChatAll("\x04%t\x01：%t","Prefix", "ServerQuit");
    CreateTimer(3.0, TimerQuit, _);
    return Plugin_Handled;
}

public Action OnStateChange(Event event, const char[] name, bool dontBroadcast) {
    int state = event.GetInt("state");
    if (state == 6 || state == 1) { //Extraction expired
        UnhookEvent("state_change", OnStateChange, EventHookMode_Post);
        PrintToChatAll("\x04%t\x01：%t","Prefix", "ServerQuit");
        CreateTimer(3.0, TimerQuit, _);
    }
    return Plugin_Handled;
}

public Action TimerQuit(Handle timer) {
    ServerCommand("quit");
    return Plugin_Handled;
}
