#pragma semicolon 1
#define PLUGIN_VERSION "1.0"

#include <sdktools>
#include <sdkhooks>
#include <globalvariables>

public Plugin myInfo = {
    name = "Extraction Level",
    author = "clagura",
    description = "Rate players by extraction times and change their name color in chat",
    version = PLUGIN_VERSION,
    url = ""
}

#define MAX_COLOR_LEN 32
#define MAX_QUERY_LEN 512

Handle db = INVALID_HANDLE;
char g_user_name_color[MAXPLAYERS + 1][MAX_COLOR_LEN];
ConVar record_enable;
bool enable = true;

char g_rank_color[11][MAX_COLOR_LEN] = {
    "{white}",
    "{navajowhite}",
    "{yellow}",
    "{lawngreen}",
    "{aqua}",
    "{fuchsia}",
    "{darkviolet}",
    "{orange}",
    "{crimson}",
    "{darkred}",
    "rainbow"
};

char g_color_group[][][32] = {
    {"{red}", "{orangered}", "{crimson}", "{collectors}", "{darkred}"},
    {"{palegreen}", "{lawngreen}", "{green}", "{lime}", "{forestgreen}"},
    {"{aqua}", "{dodgerblue}", "{blue}", "{darkcyan}", "{teal}"},
    {"{fuchsia}", "{violet}", "{orchid}", "{legendary}", "{darkviolet}"},
    {"{lightpink}", "{pink}", "{hotpink}", "{deeppink}", "{palevioletred}"}
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("FetchColoredName", NativeGetColoredName);
    return APLRes_Success;
}

public void OnPluginStart() {
    //LoadTranslations("extraction_level");
    enable = true;
    InitializeDB();
    HookEvent("nmrih_round_begin", OnRoundStart);
    HookEvent("player_extracted", OnPlayerExtraction);
    RegConsoleCmd("sm_top", ShowTopRankToClient_p1);
}

public void OnConfigsExecuted() {
    (record_enable = FindConVar("sm_record_enable")).AddChangeHook(OnConVarChange);

    for (int i = 0; i < sizeof(g_color_group); i++) {
        for (int j = 0; j < sizeof(g_color_group[]); j++) {
            CProcessVariables(g_color_group[i][j], sizeof(g_color_group[][]));
        }
    }

    for (int i = 0; i < sizeof(g_rank_color); i++) {
        CProcessVariables(g_rank_color[i], sizeof(g_rank_color[]));
    }
}

public OnConVarChange(Handle CVar, const char[] oldValue, const char[] newValue)
{
    if (CVar == record_enable && !record_enable.BoolValue)
        enable = false;
}

public InitializeDB() {
    char error[MAX_SAYTEXT2_LEN];
    KeyValues kv = CreateKeyValues("");
    KvSetString(kv, "driver", "sqlite");
    KvSetString(kv, "database", "extraction_times");

    db = SQL_ConnectCustom(kv, error, sizeof(error), true);
    if(db == INVALID_HANDLE) {
        SetFailState(error);
    }
    SQL_LockDatabase(db);
    SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS extraction_times (steam_id TEXT, name TEXT, times INTEGER);");
    SQL_UnlockDatabase(db);
}

public void OnRoundStart(Event e, const char[] n, bool b) {
    if (record_enable.BoolValue)
        enable = true;
    else
        enable = false;
}

public void OnPlayerExtraction(Event e, const char[] n, bool b) {
    if (!enable)
        return;
    int client = e.GetInt("player_id");

    char steam_id[64] = {0};
    char buffer[MAX_QUERY_LEN] = {0};

    if(client && IsClientConnected(client) && !IsFakeClient(client)) {
        GetClientAuthId(client, AuthId_SteamID64, steam_id, sizeof(steam_id));

        Format(buffer, sizeof(buffer), "SELECT steam_id, name, times FROM extraction_times WHERE steam_id = '%s'", steam_id);
        SQL_TQuery(db, AfterQuery, buffer, client);
    }
}

public void AfterQuery(Handle owner, Handle hndl, const char[] error, any data) {
    if(!IsClientInGame(data))
        return;

    char steam_id[64], name[MAX_NAME_LEN], buffer[MAX_QUERY_LEN];
    int times = 0;
    bool need_insert = false;

    GetClientName(data, name, sizeof(name));
    GetClientAuthId(data, AuthId_SteamID64, steam_id, sizeof(steam_id));

    if(hndl == INVALID_HANDLE) {
        PrintToServer("Error when query %s!", name);
        return;
    }
    else if(SQL_FetchRow(hndl)) 
        times = SQL_FetchInt(hndl, 2);
    else need_insert = true;
    times++;
    strcopy(g_user_name_color[data], sizeof(g_user_name_color[]), g_rank_color[GetColorIndexFromTimes(times)]);

    //GetColoredName(data, colored_name, sizeof(colored_name));
    //Format(buffer, sizeof(buffer), "{white}幸存者** %s {white}**已经撤离！", colored_name);
    //CPrintToChatAll(buffer);

    if(need_insert)
        Format(buffer, sizeof(buffer), "INSERT INTO extraction_times VALUES ('%s', '%s', %i)", steam_id, name, times);
    else
        Format(buffer, sizeof(buffer), "UPDATE extraction_times SET name = '%s', times = %i WHERE steam_id = '%s'", name, times, steam_id);
    SQL_TQuery(db, AfterReplace, buffer, data);
}

public void AfterReplace(Handle owner, Handle hndl, const char[] error, any data) {
    if(!StrEqual("", error))
        PrintToServer("Last Connect SQL Error: %s", error);
}

public Action OnClientPreAdminCheck(int client) {
    char steam_id[64] = {0};
    char buffer[MAX_QUERY_LEN] = {0};
    if(client && IsClientConnected(client) && !IsFakeClient(client)) {
        GetClientAuthId(client, AuthId_SteamID64, steam_id, sizeof(steam_id));

        Format(buffer, sizeof(buffer), "SELECT steam_id, name, times FROM extraction_times WHERE steam_id = '%s'", steam_id);
        PrintToServer(steam_id);
        SQL_TQuery(db, ApplyNameColor, buffer, client);
    }
    return Plugin_Continue;
}

public void ApplyNameColor(Handle owner, Handle hndl, const char[] error, any data) {
    int times = 0;
    char name[MAX_NAME_LEN], name_1[MAX_NAME_LEN], buffer[MAX_QUERY_LEN];
    GetClientName(data, name_1, 128);
    if(hndl == INVALID_HANDLE) {
        PrintToServer("Error when query %s!", name);
        strcopy(g_user_name_color[data], sizeof(g_user_name_color[]), g_rank_color[0]);
        return ;
    }
    else if(SQL_FetchRow(hndl)) {
        SQL_FetchString(hndl, 1, name, sizeof(name));
        times = SQL_FetchInt(hndl, 2);
        if (times >= 100) strcopy(g_user_name_color[data], sizeof(g_user_name_color[]), "rainbow");
        else strcopy(g_user_name_color[data], sizeof(g_user_name_color[]), g_rank_color[GetColorIndexFromTimes(times)]);
        if(strcmp(name, name_1) != 0) {
            Format(buffer, sizeof(buffer), "UPDATE extraction_times SET name = '%s' WHERE name = '%s'", name_1, name);
            SQL_TQuery(db, AfterNameUpdate, buffer, data);
        }
    }
    else strcopy(g_user_name_color[data], sizeof(g_user_name_color[]), g_rank_color[0]);
    GetColoredName(data, name, sizeof(name));
    Format(buffer, MAX_SAYTEXT2_LEN, "幸存者 %s {white}总撤离次数为 %i！", name, times);
    CPrintToChatAll(0, buffer);
}

public void AfterNameUpdate(Handle owner, Handle hndl, const char[] error, any data) {
    if(!StrEqual("", error))
        PrintToServer("Last Connect SQL Error: %s", error);
}

public void OnClientDisconnect(int client) {
    g_user_name_color[client][0] = '\0';
}

void StringRainbow(const char[] input, char[] output, int maxLen) {
    int bytes = 0, buffs = 0;
    int size = strlen(input), color_index = GetRandomInt(0, 4);
    int char_len = 0, chars_width[MAX_SAYTEXT2_LEN];
    output[0] = '\0';

    for (int x = 0; x < size; ++x) {
        if (0 <= input[x] < 128) {
            chars_width[char_len++] = 1;
        }
        else if (input[x] >= 192) {
            buffs = 0;
            for (int i = 7; i >= 0; i--) {
                if (input[x] & (1 << i)) {
                    buffs++;
                }
                else {
                    break;
                }
            }
            chars_width[char_len++] = buffs;
            x += (buffs - 1);
        }
    }

    bytes += strcopy(output, maxLen, g_color_group[color_index][0]);
    int last = 0, index = 0, insert_point, len = 0;
    for (int i = 1; i < 5 && maxLen > bytes; ++i) {
        insert_point = RoundToNearest(float(char_len) / 5.0 * i);
        if (insert_point != last) {
            len = 0;
            for (int j = last; j < insert_point; j++) {
                len += chars_width[j];
                if (len > maxLen - bytes - 1) {
                    len = maxLen - bytes - 1;
                    break;
                }
            }
            len = strcopy(output[bytes], len + 1, input[index]);
            index += len;
            bytes += len;

            bytes += strcopy(output[bytes], maxLen-bytes, g_color_group[color_index][i]);
            last = insert_point;
        }
    }
    bytes += strcopy(output[bytes], maxLen-bytes, input[index]);
    bytes += strcopy(output[bytes], maxLen-bytes, "\x01");

    output[bytes] = '\0';
    //PrintToServer(output);
}

public Action ShowTopRankToClient_p1(int client, int args) {
    char buffer[MAX_QUERY_LEN];
    Format(buffer, sizeof(buffer), "SELECT name, times FROM extraction_times ORDER BY times DESC LIMIT 10");
    SQL_TQuery(db, ShowTopRankToClient_p2, buffer, client);
    return Plugin_Continue;
}

public void ShowTopRankToClient_p2(Handle:owner, Handle:hndl, const String:error[], any:data) {
    if(hndl == INVALID_HANDLE) {
        PrintToServer("Last Connect SQL Error: %s", error);
    }
    int top = 0, times = 0;
    char buffer[10][MAX_SAYTEXT2_LEN], name[MAX_NAME_LEN] = {0}, color[MAX_COLOR_LEN];
    while(SQL_FetchRow(hndl) && top < 10) {
        strcopy(color, sizeof(color), g_rank_color[0]);
        SQL_FetchString(hndl, 0, name, sizeof(name));
        times = SQL_FetchInt(hndl, 1);
        top++;
        if (times >= 100) {
            char newname[MAX_NAME_LEN];
            StringRainbow(name, newname, sizeof(newname));
            FormatEx(buffer[top-1], sizeof(buffer[]), "TOP %i：幸存者 %s {white}总共撤离 {red}%i {white}次", 
                    top, newname, times);
        }
        else {
            strcopy(color, sizeof(g_rank_color[]), g_rank_color[GetColorIndexFromTimes(times)]);
            FormatEx(buffer[top-1], sizeof(buffer[]), "TOP %i：幸存者 %s%s {white}总共撤离 {red}%i {white}次", 
                    top, color, name, times);
        }
    }
    if (buffer[0][0] == '\0') {
        strcopy(buffer[0], sizeof(buffer[]), "{red}当前没有任何记录！");
        top = 1;
    }
    if (data == 0) {
        for(int i = top - 1; i >= 0; i--)
            CPrintToChatAll(0, buffer[i]);
    }
    else if (IsClientInGame(data) && IsClientConnected(data) && !IsFakeClient(data) && !IsClientSourceTV(data)) {
        for(int i = top - 1; i >= 0; i--)
            CPrintToChat(data, 0, buffer[i]);
    }
}

public any NativeGetColoredName(Handle plugin, int num_params) {
    int client = GetNativeCell(1);
    int max_len = GetNativeCell(3);
    char[] new_name = new char[max_len];
    GetColoredName(client, new_name, max_len);
    SetNativeString(2, new_name, max_len);
    return 0;
}

public void GetColoredName(int client, char[] new_name, int max_len) {
    char[] name = new char[max_len];
    GetClientName(client, name, max_len);
    if (g_user_name_color[client][0] == '\0') {
        Format(new_name, max_len, "%s%s\x01", g_rank_color[0], name);
    }
    else if (strcmp(g_user_name_color[client], "rainbow") != 0) {
        Format(new_name, max_len, "%s%s\x01", g_user_name_color[client], name);
    }
    else {
        StringRainbow(name, new_name, max_len);
    }
}

public int GetColorIndexFromTimes(int times) {
//1 5 10 20 30 40 50 60 80 100
    if (times >=0 && times < 1)
        return 0;
    else if (times < 5)
        return 1;
    else if (times < 10)
        return 2;
    else if (times < 20)
        return 3;
    else if (times < 30)
        return 4;
    else if (times < 40)
        return 5;
    else if (times < 50)
        return 6;
    else if (times < 60)
        return 7;
    else if (times < 80)
        return 8;
    else if (times < 100)
        return 9;
    else
        return 10;
}
