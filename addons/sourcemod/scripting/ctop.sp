#include <sourcemod>
#include <globalvariables>
#include <ctop>

#pragma newdecls required
#pragma semicolon 1

// database handle
Database gH_SQL = null;

ConVar g_cvEnable, g_cvPKMode, g_cvEnableRT;
ConVar g_cvInfStamina, g_cvMachete, g_cvGameMode, g_cvDensity, g_cvDifficulty;
ConVar g_cvDensityMinReq;

bool gB_Connected = false;

bool g_bIgnoreInfStamina, g_bIgnoreMachete, g_bIgnoreGameMode, g_bIgnoreDensity, g_bIgnoreDifficulty;

// Current map's name
char gS_Map[160];

// total start time
float g_fStartTime = -1.0;
float g_fEndTime = -1.0;

// player timer variables
playertimer_t gA_Timers[MAXPLAYERS+1];

public Plugin myinfo = 
{
    name = "[NMRIH] ctop",
    author = "Ciallo & clagura",
    description = "record runtime to sql and print it to chat",
    version = "2.0",
    url = "https://steamcommunity.com/id/anie1337/"
};

public void OnPluginStart()
{
    LoadTranslations("ctop.phrases");
    
    (g_cvEnable = CreateConVar("sm_record_enable", "1", "on = 1 , off = 0")).AddChangeHook(OnConVarChange);
    (g_cvPKMode = CreateConVar("sm_pk_mode", "0", "Another method to record time, on = 1 , off = 0")).AddChangeHook(OnConVarChange);
    (g_cvEnableRT = CreateConVar("sm_record_enable_rt", "1", "on = 1 , off = 0")).AddChangeHook(OnConVarChange);
    g_cvDensityMinReq = CreateConVar("sm_density_min_req", "1.5", "When sv_spawn_density is lower than this value, record will be disable");

    HookEvent("nmrih_round_begin", OnRoundStart);
    if (g_cvPKMode.BoolValue)
        HookEvent("player_spawn", TIMER_START);
    else
        HookEvent("nmrih_round_begin", TIMER_START);
    HookEvent("player_extracted", TIMER_END);
    HookEvent("player_death", EVENT_DEATH);
    HookEvent("npc_killed", EVENT_NPC);
    
    RegConsoleCmd("sm_wr", Command_WR, "print wr in panel, sorted by time");
    RegConsoleCmd("sm_wrn", Command_WR, "print wr in panel, sorted by kills");
    //RegConsoleCmd("sm_top", Command_TOP, "print wr in chat");
    /* RegConsoleCmd("sm_test", Command_test, "test"); */
    
    SQL_DBConnect();
}

public void OnMapStart()
{
    if(!gB_Connected)
    {
        return;
    }
    g_cvEnable.IntValue = 1;
    g_cvEnableRT.BoolValue = true;
    // Get mapname
    GetCurrentMap(gS_Map, 160);

    // fuck workshop map
    GetMapDisplayName(gS_Map, gS_Map, 160);
}

public void OnConfigsExecuted() {
    g_cvInfStamina = FindConVar("sm_inf_stamina");
    g_cvMachete = FindConVar("sm_machete_enable");
    g_cvGameMode = FindConVar("sm_gamemode");
    g_cvDensity = FindConVar("sv_spawn_density");
    g_cvDifficulty = FindConVar("sv_difficulty");
    if (IsValidHandle(g_cvInfStamina)) {
        g_cvInfStamina.AddChangeHook(OnConVarChange);
        // When a convar is set cheat previously, ignore that convar in check (usually because map neeed)
        g_bIgnoreInfStamina = !CheckInfStamina();
    }
    else {
        g_bIgnoreInfStamina = true;
    }
    if (IsValidHandle(g_cvMachete)) {
        g_cvMachete.AddChangeHook(OnConVarChange);
        g_bIgnoreMachete = !CheckMachete();
    }
    else {
        g_bIgnoreMachete = true;
    }
    if (IsValidHandle(g_cvGameMode)) {
        g_cvGameMode.AddChangeHook(OnConVarChange);
        g_bIgnoreGameMode = !CheckGameMode();
    }
    else {
        g_bIgnoreGameMode = true;
    }
    if (IsValidHandle(g_cvDensity)) {
        g_cvDensity.AddChangeHook(OnConVarChange);
        g_bIgnoreDensity = !CheckDensity();
    }
    else {
        g_bIgnoreDensity = true;
    }
    if (IsValidHandle(g_cvDifficulty)) {
        g_cvDifficulty.AddChangeHook(OnConVarChange);
        g_bIgnoreDifficulty = !CheckDifficulty();
    }
    else {
        g_bIgnoreDifficulty = true;
    }
}

public void OnClientPutInServer(int client)
{
    gA_Timers[client].fStartTime = 0.0;
    gA_Timers[client].iDeaths = 0;
    gA_Timers[client].iKills = 0;
}

public void OnConVarChange(Handle CVar, const char[] oldValue, const char[] newValue)
{
    if (CVar == g_cvPKMode)
    {
        if (g_cvPKMode.BoolValue)
        {
            UnhookEvent("nmrih_round_begin", TIMER_START);
            HookEvent("player_spawn", TIMER_START);
        }
        else
        {
            UnhookEvent("player_spawn", TIMER_START);
            HookEvent("nmrih_round_begin", TIMER_START);
        }
    }
    else if (CVar == g_cvDensity || 
        CVar == g_cvGameMode || 
        CVar == g_cvInfStamina || 
        CVar == g_cvMachete || 
        CVar == g_cvDifficulty) {
        
        if ( (g_bIgnoreDensity       ||  CheckDensity()) && 
             (g_bIgnoreGameMode      ||  CheckGameMode()) &&
             (g_bIgnoreInfStamina    ||  CheckInfStamina()) && 
             (g_bIgnoreMachete       ||  CheckMachete()) && 
             (g_bIgnoreDifficulty    ||  CheckDifficulty()) ) {

            if (!g_cvEnableRT.BoolValue) {
                if (!g_cvEnable.BoolValue) {
                    CPrintToChatAll(0, "{green}[系统] {default}下回合开始时将会启用通关记录！");
                }
            }
            g_cvEnable.BoolValue = true;
        }
        else {
            if (g_cvEnableRT.BoolValue || g_cvEnable.BoolValue) {
                CPrintToChatAll(0, "{green}[系统] {default}停止记录通关！");
                g_cvEnable.BoolValue = false;
                g_cvEnableRT.BoolValue = false;
            }
        }
    }
}

static bool CheckDensity() {
    return FloatCompare(g_cvDensity.FloatValue, g_cvDensityMinReq.FloatValue) >= 0;
}

static bool CheckGameMode() {
    return g_cvGameMode.IntValue == 1;  // 1 - all runner, 0 - default, 2 - all kids
}

static bool CheckInfStamina() {
    return !g_cvInfStamina.BoolValue;
}

static bool CheckMachete() {
    return !g_cvMachete.BoolValue;
}

static bool CheckDifficulty() {
    char szDifficulty[16];
    g_cvDifficulty.GetString(szDifficulty, sizeof(szDifficulty));
    return strcmp(szDifficulty, "classic") == 0 || strcmp(szDifficulty, "nightmare") == 0;
}

public void OnRoundStart(Event e, const char[] n, bool b) {
    if (g_cvEnable.BoolValue)
        g_cvEnableRT.BoolValue = true;
    else
        g_cvEnableRT.BoolValue = false;
}

public Action TIMER_START(Event e, const char[] n, bool b)
{
    if (!g_cvEnable.BoolValue)
        return Plugin_Continue;
    if (g_cvPKMode.BoolValue)
    {
        int client = GetClientOfUserId(GetEventInt(e, "userid"));
        gA_Timers[client].fStartTime = GetGameTime();
        gA_Timers[client].iDeaths = 0;
        gA_Timers[client].iKills = 0;
    }
    else
    {
        g_fStartTime = GetGameTime();
        g_fEndTime = -1.0;
        for(int i = 1; i <= MaxClients; i++)
        {
            gA_Timers[i].fStartTime = 0.0;
            gA_Timers[i].iDeaths = 0;
            gA_Timers[i].iKills = 0;
        }
    }
    return Plugin_Continue;
}

public Action TIMER_END(Event e, const char[] n, bool b)
{
    if (!g_cvEnableRT.BoolValue)
        return Plugin_Continue;
    int client = e.GetInt("player_id");

    // Get client name
    GetClientName(client, gA_Timers[client].sName, 128);
    
    // Get SteamID
    gA_Timers[client].iSteamid = GetSteamAccountID(client);
    
    if (g_cvPKMode.BoolValue)
        gA_Timers[client].fFinalTime = GetGameTime() - gA_Timers[client].fStartTime;
    else
    {
        if (g_fEndTime < 0)
            g_fEndTime = GetGameTime();
        gA_Timers[client].fFinalTime = g_fEndTime - g_fStartTime;
    }

    // Get runtime and format it to a string
    FormatTimeFloat(1, gA_Timers[client].fFinalTime, 3, gA_Timers[client].sFinalTime, 32);

    char sQuery[512];

    FormatEx(sQuery, 512, "SELECT time, counts FROM playertimes WHERE map = '%s' AND auth = %d ORDER BY time ASC;", gS_Map, gA_Timers[client].iSteamid);

    gH_SQL.Query(SQL_OnFinishCheck_Callback, sQuery, client, DBPrio_High);
    return Plugin_Continue;
}

public void SQL_OnFinishCheck_Callback(Database db, DBResultSet results, const char[] error, any client)
{
    if(results == null)
    {
        LogError("Timer SQL query failed. Reason: %s", error);
        return;
    }
    if(client == 0)
    {
        return;
    }

    char sQuery[512];

    if(results.FetchRow() && results.HasResults)
    {
        gA_Timers[client].iCounts = results.FetchInt(1);
        
        if(gA_Timers[client].fFinalTime < results.FetchFloat(0))
        {
            FormatEx(sQuery, 512,
            "UPDATE playertimes SET time = %f, deaths = %d, counts = counts + 1, kills = %d WHERE map = '%s' AND auth = %d;", 
            gA_Timers[client].fFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iKills, gS_Map, gA_Timers[client].iSteamid);
        }
        else if(gA_Timers[client].iKills > results.FetchFloat(0))
        {
            FormatEx(sQuery, 512,
            "INSERT INTO playertimes (auth, name, map, time, deaths, counts, kills) VALUES (%d, '%s', '%s', %f, %d, 1, %d);", 
             gA_Timers[client].iSteamid, gA_Timers[client].sName, gS_Map, gA_Timers[client].fFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iKills);
        }
        else
        {
            FormatEx(sQuery, 512,
            "UPDATE playertimes SET counts = counts + 1 WHERE map = '%s' AND auth = %d;",
            gS_Map, gA_Timers[client].iSteamid);
        }
    }
    else
    {
        FormatEx(sQuery, 512,
        "INSERT INTO playertimes (auth, name, map, time, deaths, counts, kills) VALUES (%d, '%s', '%s', %f, %d, 1, %d);",
        gA_Timers[client].iSteamid, gA_Timers[client].sName, gS_Map, gA_Timers[client].fFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iKills);
    }

    gH_SQL.Query(SQL_OnFinish_Callback, sQuery, client, DBPrio_High);
}

public void SQL_OnFinish_Callback(Database db, DBResultSet results, const char[] error, any client)
{
    if(results == null)
    {
        LogError("Timer SQL query(onfinish) failed. Reason: %s", error);
        return;
    }
    if(client == 0)
    {
        return;
    }
    CPrintToChatAll(0, "%t", "Complete", gA_Timers[client].sName, gA_Timers[client].sFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iKills, ++gA_Timers[client].iCounts);
}

public Action EVENT_DEATH(Event e, const char[] n, bool b)
{
    if (!g_cvEnableRT.BoolValue)
        return Plugin_Continue;
    int client = GetClientOfUserId(e.GetInt("userid"));

    gA_Timers[client].iDeaths++;
    return Plugin_Continue;
}

public Action EVENT_NPC(Event e, const char[] n, bool b)
{
    if (!g_cvEnableRT.BoolValue)
        return Plugin_Continue;
    int client = e.GetInt("killeridx");

    if(client <= MaxClients && client > 0)
        if(IsClientInGame(client))
            gA_Timers[client].iKills++;
    return Plugin_Continue;
}

public Action Command_WR(int client, int args)
{
    if(!(IsClientConnected(client) && IsClientInGame(client)))
        return Plugin_Handled;

    char sCommand[64], cmd[10];
    if (args == 0)
        FormatEx(sCommand, 64, "%s", gS_Map);
    else
        GetCmdArg(1, sCommand, 64);
    GetCmdArg(0, cmd, 10);

    if (cmd[strlen(cmd) - 1] == 'n')
        StartWRMenu(client, sCommand, true);
    else
        StartWRMenu(client, sCommand, false);
    return Plugin_Handled;
}


void StartWRMenu(int client, const char[] map, bool bIsSortedByKillCount=false)
{
    DataPack dp = new DataPack();
    dp.WriteCell(client);
    dp.WriteString(map);

    int iLength = 2 * strlen(map) + 1;
    char[] sEscapedMap = new char[iLength];
    gH_SQL.Escape(map, sEscapedMap, iLength);

    char sQuery[512];
    if (bIsSortedByKillCount)
        FormatEx(sQuery, 512, "SELECT name, time, deaths, counts, kills FROM playertimes WHERE map = '%s' ORDER BY kills DESC, time ASC;", sEscapedMap);
    else
        FormatEx(sQuery, 512, "SELECT name, time, deaths, counts, kills FROM playertimes WHERE map = '%s' ORDER BY time ASC, kills DESC;", sEscapedMap);
    gH_SQL.Query(SQL_WR_Callback2, sQuery, dp);
}

public void SQL_WR_Callback2(Database db, DBResultSet results, const char[] error, DataPack data)
{
    data.Reset();
    int client = data.ReadCell();
    char sMap[192];
    data.ReadString(sMap, 192);
    delete data;

    if(results == null)
    {
        LogError("Timer SQL query failed. Reason: %s", error);
        return;
    }

    if(client == 0)
    {
        return;
    }
    Menu hMenu = new Menu(WRMenu_Handler);

    int iCount = 0;

    while(results.FetchRow())
    {
        if(++iCount <= 100)
        {
            // 0 - player name
            char sName[MAX_NAME_LENGTH];
            results.FetchString(0, sName, MAX_NAME_LENGTH);

            // 1 - time
            float time = results.FetchFloat(1);
            char sTime[32];
            FormatTimeFloat(1, time, 3, sTime, sizeof(sTime));

            // 2 - deaths
            int deaths = results.FetchInt(2);

            // 3 - completions
            int counts = results.FetchInt(3);

            // 4 - kills
            int kills = results.FetchInt(4);

            char sDisplay[128];
            FormatEx(sDisplay, 128, "%T", "Top", client, sName, sTime, deaths, kills, counts);
            hMenu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
        }
    }

    char sFormattedTitle[256];

    if(hMenu.ItemCount == 0)
    {
        hMenu.SetTitle("%T", "Map", client, sMap);
        char sNoRecords[64];
        FormatEx(sNoRecords, 64, "%T", "NoRecords", client);

        hMenu.AddItem("-1", sNoRecords, ITEMDRAW_DISABLED);
    }

    else
    {
        FormatEx(sFormattedTitle, 192, "%T", "Map", client, sMap);
        hMenu.SetTitle(sFormattedTitle);
    }

    hMenu.Display(client, -1);
}

public int WRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select)
    {
        // char sInfo[16];
        // menu.GetItem(param2, sInfo, 16);
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void SQL_DBConnect()
{
    char error[255];
    KeyValues kv = CreateKeyValues("");
    KvSetString(kv, "driver", "sqlite");
    KvSetString(kv, "database", "extraction_times");

    gH_SQL = SQL_ConnectCustom(kv, error, sizeof(error), true);
    if(gH_SQL == INVALID_HANDLE)
    {
        SetFailState(error);
    }
    SQL_LockDatabase(gH_SQL);
    SQL_FastQuery(gH_SQL, "CREATE TABLE IF NOT EXISTS playertimes (auth INT, name VARCHAR(32), time FLOAT NOT NULL DEFAULT '-1.0', map VARCHAR(128), deaths INT, counts INT, kills INT);");
    SQL_UnlockDatabase(gH_SQL);

    gB_Connected = true;
    OnMapStart();
}
