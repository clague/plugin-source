#include <sourcemod>
#include <colorvariables>
#include <ctop>

#pragma newdecls required
#pragma semicolon 1

// database handle
Database gH_SQL = null;
ConVar g_bEnable, g_bPKMode;
bool gB_Connected = false;

// Current map's name
char gS_Map[160];

// total start time
float g_fStartTime = -1.0;
float g_fEndTime = -1.0;

ConVar sm_record_enable_rt;
bool enable = true;

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
    
    (g_bEnable = CreateConVar("sm_record_enable", "1", "on = 1 , off = 0")).AddChangeHook(OnConVarChange);
    (g_bPKMode = CreateConVar("sm_pk_mode", "0", "on = 1 , off = 0")).AddChangeHook(OnConVarChange);
    (sm_record_enable_rt = CreateConVar("sm_record_enable_rt", "1", "on = 1 , off = 0")).AddChangeHook(OnConVarChange);
    enable = true;

    HookEvent("nmrih_round_begin", OnRoundStart);
    if (g_bPKMode.BoolValue)
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
    g_bEnable.IntValue = 1;
    sm_record_enable_rt.BoolValue = true;
    // Get mapname
    GetCurrentMap(gS_Map, 160);

    // fuck workshop map
    GetMapDisplayName(gS_Map, gS_Map, 160);
}

public void OnClientPutInServer(int client)
{
    gA_Timers[client].fStartTime = 0.0;
    gA_Timers[client].iDeaths = 0;
    gA_Timers[client].iKills = 0;
}

public void OnConVarChange(Handle CVar, const char[] oldValue, const char[] newValue)
{
    if (CVar == g_bEnable && !g_bEnable.BoolValue)
        sm_record_enable_rt.BoolValue = false;
    else if (CVar == g_bPKMode)
    {
        if (g_bPKMode.BoolValue)
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
    else if (CVar == sm_record_enable_rt) {
        enable = sm_record_enable_rt.BoolValue;
    }
}

public void OnRoundStart(Event e, const char[] n, bool b) {
    if (g_bEnable.BoolValue)
        sm_record_enable_rt.BoolValue = true;
    else
        sm_record_enable_rt.BoolValue = false;
}

public Action TIMER_START(Event e, const char[] n, bool b)
{
    if (!g_bEnable.BoolValue)
        return Plugin_Continue;
    if (g_bPKMode.BoolValue)
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
    if (!enable)
        return Plugin_Continue;
    int client = e.GetInt("player_id");

    // Get client name
    GetClientName(client, gA_Timers[client].sName, 128);
    
    // Get SteamID
    gA_Timers[client].iSteamid = GetSteamAccountID(client);
    
    if (g_bPKMode.BoolValue)
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
    CPrintToChatAll("%t", "Complete", gA_Timers[client].sName, gA_Timers[client].sFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iKills, ++gA_Timers[client].iCounts);
}

public Action EVENT_DEATH(Event e, const char[] n, bool b)
{
    if (!enable)
        return Plugin_Continue;
    int client = GetClientOfUserId(e.GetInt("userid"));

    gA_Timers[client].iDeaths++;
    return Plugin_Continue;
}

public Action EVENT_NPC(Event e, const char[] n, bool b)
{
    if (!enable)
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
            FormatEx(sDisplay, 128, "%t", "Top", sName, sTime, deaths, kills, counts, client);
            hMenu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
        }
    }

    char sFormattedTitle[256];

    if(hMenu.ItemCount == 0)
    {
        hMenu.SetTitle("%T", "Map", client, sMap);
        char sNoRecords[64];
        FormatEx(sNoRecords, 64, "%t", "NoRecords", client);

        hMenu.AddItem("-1", sNoRecords, ITEMDRAW_DISABLED);
    }

    else
    {
        FormatEx(sFormattedTitle, 192, "%t", "Map", sMap, client);
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
