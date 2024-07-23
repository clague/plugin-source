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

Handle g_hDB = INVALID_HANDLE;
char g_arrszUserNameColor[MAXPLAYERS + 1][MAX_COLOR_LEN];
ConVar sm_record_enable_rt;
bool g_bEnable = true;

char g_arrszRankColor[][MAX_COLOR_LEN] = {
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

char g_arrszColorGroup[][][32] = {
    {"{red}", "{orangered}", "{crimson}", "{collectors}", "{darkred}"},
    {"{palegreen}", "{lawngreen}", "{green}", "{lime}", "{forestgreen}"},
    {"{aqua}", "{dodgerblue}", "{blue}", "{darkcyan}", "{teal}"},
    {"{fuchsia}", "{violet}", "{orchid}", "{legendary}", "{darkviolet}"},
    {"{lightpink}", "{pink}", "{hotpink}", "{deeppink}", "{palevioletred}"}
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int nErrMax)
{
    CreateNative("FetchColoredName", NativeGetColoredName);
    return APLRes_Success;
}

public void OnPluginStart() {
    //LoadTranslations("extraction_level");
    g_bEnable = true;
    InitializeDB();
    HookEvent("player_extracted", OnPlayerExtraction);
    RegConsoleCmd("sm_top", ShowTopRankToClientP1);
}


public Action OnClientPreAdminCheck(int iClient) {
    char szSteamId[64] = {0};
    char szBuffer[MAX_QUERY_LEN] = {0};
    if (iClient && IsClientConnected(iClient) && !IsFakeClient(iClient)) {
        GetClientAuthId(iClient, AuthId_SteamID64, szSteamId, sizeof(szSteamId));

        Format(szBuffer, sizeof(szBuffer), "SELECT steam_id, name, times FROM extraction_times WHERE steam_id = '%s'", szSteamId);
        PrintToServer("client%d's steamid: %s", iClient, szSteamId);
        SQL_TQuery(g_hDB, ApplyNameColor, szBuffer, iClient);
    }
    return Plugin_Continue;
}

public void OnConfigsExecuted() {
    sm_record_enable_rt = FindConVar("sm_record_enable_rt");
    if (sm_record_enable_rt != INVALID_HANDLE) {
        g_bEnable = sm_record_enable_rt.BoolValue;
        sm_record_enable_rt.AddChangeHook(OnConVarChange);
    }

    for (int i = 0; i < sizeof(g_arrszColorGroup); i++) {
        for (int j = 0; j < sizeof(g_arrszColorGroup[]); j++) {
            CProcessVariables(g_arrszColorGroup[i][j], sizeof(g_arrszColorGroup[][]));
        }
    }

    for (int i = 0; i < sizeof(g_arrszRankColor); i++) {
        CProcessVariables(g_arrszRankColor[i], sizeof(g_arrszRankColor[]));
    }
}

public OnConVarChange(ConVar cvar, const char[] szOldValue, const char[] szNewValue)
{
    if (cvar == sm_record_enable_rt) {
        g_bEnable = sm_record_enable_rt.BoolValue;
    }
}

public InitializeDB() {
    char szError[MAX_SAYTEXT2_LEN];
    KeyValues kv = CreateKeyValues("");
    KvSetString(kv, "driver", "sqlite");
    KvSetString(kv, "database", "extraction_times");

    g_hDB = SQL_ConnectCustom(kv, szError, sizeof(szError), true);
    if(g_hDB == INVALID_HANDLE) {
        SetFailState(szError);
    }
    SQL_LockDatabase(g_hDB);
    SQL_FastQuery(g_hDB, "CREATE TABLE IF NOT EXISTS extraction_times (steam_id TEXT, name TEXT, times INTEGER);");
    SQL_UnlockDatabase(g_hDB);
}

public void OnPlayerExtraction(Event e, const char[] sz, bool b) {
    if (!g_bEnable)
        return;
    int iClient = e.GetInt("player_id");

    char szSteamId[64] = {0};
    char szBuffer[MAX_QUERY_LEN] = {0};

    if(iClient && IsClientConnected(iClient) && !IsFakeClient(iClient)) {
        GetClientAuthId(iClient, AuthId_SteamID64, szSteamId, sizeof(szSteamId));

        Format(szBuffer, sizeof(szBuffer), "SELECT steam_id, name, times FROM extraction_times WHERE steam_id = '%s'", szSteamId);
        SQL_TQuery(g_hDB, AfterQuery, szBuffer, iClient);
    }
}

public void AfterQuery(Handle hOwner, Handle hChild, const char[] szError, any iClient) {
    if(!IsClientInGame(iClient))
        return;

    char szSteamId[64], szName[MAX_NAME_LENGTH], szBuffer[MAX_QUERY_LEN];
    int nTimes = 0;
    bool bNeedInsert = false;

    GetClientName(iClient, szName, sizeof(szName));
    GetClientAuthId(iClient, AuthId_SteamID64, szSteamId, sizeof(szSteamId));

    if (hChild == INVALID_HANDLE) {
        PrintToServer("Error when query %s!", szName);
        return;
    } else if (SQL_FetchRow(hChild)) {
        nTimes = SQL_FetchInt(hChild, 2);
    } else {
        bNeedInsert = true;
    }
    nTimes++;
    strcopy(g_arrszUserNameColor[iClient], sizeof(g_arrszUserNameColor[]), g_arrszRankColor[GetColorIndexFromTimes(nTimes)]);

    //GetColoredName(data, colored_name, sizeof(colored_name));
    //Format(buffer, sizeof(buffer), "{white}幸存者** %s {white}**已经撤离！", colored_name);
    //CPrintToChatAll(buffer);

    if (bNeedInsert) {
        Format(szBuffer, sizeof(szBuffer), "INSERT INTO extraction_times VALUES ('%s', '%s', %i)", szSteamId, szName, nTimes);
    } else {
        Format(szBuffer, sizeof(szBuffer), "UPDATE extraction_times SET name = '%s', times = %i WHERE steam_id = '%s'", szName, nTimes, szSteamId);
    }
    SQL_TQuery(g_hDB, AfterReplace, szBuffer, iClient);
}

public void AfterReplace(Handle hOwner, Handle hChild, const char[] szError, any iClient) {
    if (szError[0] != '\0') {
        PrintToServer("Last Connect SQL Error: %s", szError);
    }
}

public void ApplyNameColor(Handle hOwner, Handle hChild, const char[] szError, any iClient) {
    int nTimes = 0;
    char szName[MAX_NAME_LENGTH], szOriginalName[MAX_NAME_LENGTH], szBuffer[MAX_QUERY_LEN];
    GetClientName(iClient, szOriginalName, MAX_NAME_LENGTH);
    if (hChild == INVALID_HANDLE) {
        PrintToServer("Error when query %s!", szName);
        strcopy(g_arrszUserNameColor[iClient], sizeof(g_arrszUserNameColor[]), g_arrszRankColor[0]);
        return ;
    }
    else if(SQL_FetchRow(hChild)) {
        SQL_FetchString(hChild, 1, szName, sizeof(szName));
        nTimes = SQL_FetchInt(hChild, 2);
        if (nTimes >= 100) {
            strcopy(g_arrszUserNameColor[iClient], sizeof(g_arrszUserNameColor[]), "rainbow");
        }
        else {
            strcopy(g_arrszUserNameColor[iClient], sizeof(g_arrszUserNameColor[]), g_arrszRankColor[GetColorIndexFromTimes(nTimes)]);
        }
        if (strcmp(szName, szOriginalName) != 0) {
            Format(szBuffer, sizeof(szBuffer), "UPDATE extraction_times SET name = '%s' WHERE name = '%s'", szOriginalName, szName);
            SQL_TQuery(g_hDB, AfterNameUpdate, szBuffer, iClient);
        }
    }
    else strcopy(g_arrszUserNameColor[iClient], sizeof(g_arrszUserNameColor[]), g_arrszRankColor[0]);
    GetColoredName(iClient, szName, sizeof(szName));
    Format(szBuffer, MAX_SAYTEXT2_LEN, "幸存者 %s {white}总撤离次数为 %i！", szName, nTimes);
    CPrintToChatAll(0, szBuffer);
}

public void AfterNameUpdate(Handle hOwner, Handle hChild, const char[] szError, any iClient) {
    if (szError[0] != '\0') {
        PrintToServer("Last Connect SQL Error: %s", szError);
    }
}

public void OnClientDisconnect(int iClient) {
    g_arrszUserNameColor[iClient][0] = '\0';
}

int StringRainbow(const char[] szInput, char[] szOutput, int nMaxLen) {
    int nBytes = 0, nBuffs = 0;
    int nSize = strlen(szInput), nColorIndex = GetRandomInt(0, sizeof(g_arrszColorGroup) - 1);
    // LogMessage("Test output: %d, %d, %d", sizeof(g_arrszColorGroup), sizeof(g_arrszColorGroup[]), sizeof(g_arrszColorGroup[][]));
    int nCharLen = 0, arrnCharsWidth[MAX_SAYTEXT2_LEN];
    szOutput[0] = '\0';

    for (int x = 0; x < nSize; x += nBuffs) {
        if (szInput[x] < 128) {
            nBuffs = 1;
        }
        else if (szInput[x] >= 192) {
            nBuffs = 2;
            for (int i = 5; i >= 0; i--) {
                if (szInput[x] & (1 << i)) {
                    nBuffs++;
                } else {
                    break;
                }
            }
        } else {
            char szBuffer[4096];
            FormatEx(szBuffer, sizeof(szBuffer), "Invalid utf8 string, please check: %s\n", szInput);
            for (int i = 0; i < nSize; i++) {
                FormatEx(szBuffer, sizeof(szBuffer), "%s%d ", szBuffer, szInput[i]);
            }
            LogError(szBuffer);
            return -1;
        }
        arrnCharsWidth[nCharLen++] = nBuffs;
    }

    nBytes += strcopy(szOutput, nMaxLen, g_arrszColorGroup[nColorIndex][0]);
    int nLast = 0, nIndex = 0, nInsertPoint, nLen = 0;
    for (int i = 1; i < sizeof(g_arrszColorGroup[]) && nMaxLen > nBytes; i++) {
        nInsertPoint = RoundToNearest(float(nCharLen) / float(sizeof(g_arrszColorGroup[])) * i);
        if (nInsertPoint != nLast) {
            nLen = 0;
            for (int j = nLast; j < nInsertPoint; j++) {
                nLen += arrnCharsWidth[j];
                if (nLen > nMaxLen - nBytes - 1) {
                    nLen = nMaxLen - nBytes - 1;
                    break;
                }
            }
            nLen = strcopy(szOutput[nBytes], nLen + 1, szInput[nIndex]);
            nIndex += nLen;
            nBytes += nLen;

            nBytes += strcopy(szOutput[nBytes], nMaxLen - nBytes, g_arrszColorGroup[nColorIndex][i]);
            nLast = nInsertPoint;
        }
    }
    nBytes += strcopy(szOutput[nBytes], nMaxLen - nBytes, szInput[nIndex]);
    nBytes += strcopy(szOutput[nBytes], nMaxLen - nBytes, "\x01");

    szOutput[nBytes] = '\0';
    return nBytes;
    //PrintToServer(output);
}

public Action ShowTopRankToClientP1(int iClient, int nArgs) {
    char szBuffer[MAX_QUERY_LEN];
    Format(szBuffer, sizeof(szBuffer), "SELECT name, times FROM extraction_times ORDER BY times DESC LIMIT 10");
    SQL_TQuery(g_hDB, ShowTopRankToClientP2, szBuffer, iClient);
    return Plugin_Continue;
}

public void ShowTopRankToClientP2(Handle hOwner, Handle hChild, const char[] szError, any iClient) {
    if (hOwner == INVALID_HANDLE) {
        PrintToServer("Last Connect SQL Error: %s", szError);
    }
    int nTop = 0, nTimes = 0;
    static char szBuffer[10][MAX_SAYTEXT2_LEN], szName[MAX_NAME_LENGTH] = {0};
    while (SQL_FetchRow(hChild) && nTop < 10) {
        SQL_FetchString(hChild, 0, szName, sizeof(szName));
        nTimes = SQL_FetchInt(hChild, 1);
        nTop++;
        if (nTimes >= 100) {
            char szNewName[MAX_NAME_LENGTH];
            StringRainbow(szName, szNewName, sizeof(szNewName));
            FormatEx(szBuffer[nTop-1], sizeof(szBuffer[]), "TOP %i：幸存者 %s 总共撤离 {red}%i {white}次", 
                    nTop, szNewName, nTimes);
        }
        else {
            FormatEx(szBuffer[nTop-1], sizeof(szBuffer[]), "TOP %i：幸存者 %s%s {white}总共撤离 {red}%i {white}次", nTop, g_arrszRankColor[GetColorIndexFromTimes(nTimes)], szName, nTimes);
        }
    }
    if (szBuffer[0][0] == '\0') {
        strcopy(szBuffer[0], sizeof(szBuffer[]), "{red}当前没有任何记录！");
        nTop = 1;
    }
    if (iClient == 0) {
        for (int i = nTop - 1; i >= 0; i--) {
            CPrintToChatAll(0, szBuffer[i]);
        }
    } else if (IsClientInGame(iClient) && IsClientConnected(iClient) && !IsFakeClient(iClient) && !IsClientSourceTV(iClient)) {
        for (int i = nTop - 1; i >= 0; i--) {
            CPrintToChat(iClient, 0, szBuffer[i]);
        }
    }
}

public int NativeGetColoredName(Handle hPlugin, int nParams) {
    int iClient = GetNativeCell(1);
    int nMaxLen = GetNativeCell(3);
    char szName[MAX_NAME_LENGTH] = {0};
    int nWriten = GetColoredName(iClient, szName, nMaxLen > MAX_NAME_LENGTH ? nMaxLen: MAX_NAME_LENGTH);
    int nErr = SetNativeString(2, szName, nMaxLen);
    if (nErr != SP_ERROR_NONE) {
        LogError("Error on SetNativeString: %d", nErr);
        return -1;
    }
    return nWriten;
}

public int GetColoredName(int iClient, char[] szName, int nMaxLen) {
    if (!GetClientName(iClient, szName, nMaxLen)) {
        return -1;
    }
    if (g_arrszUserNameColor[iClient][0] == '\0') {
        return Format(szName, nMaxLen, "%s%s\x01", g_arrszRankColor[0], szName);
    }
    else if (strcmp(g_arrszUserNameColor[iClient], "rainbow") != 0) {
        return Format(szName, nMaxLen, "%s%s\x01", g_arrszUserNameColor[iClient], szName);
    }
    else {
        static char szBuffer[MAX_NAME_LENGTH];
        strcopy(szBuffer, nMaxLen, szName);
        return StringRainbow(szBuffer, szName, nMaxLen);
    }
}

public int GetColorIndexFromTimes(int nTimes) {
//1 5 10 20 30 40 50 60 80 100
    if (nTimes >=0 && nTimes < 1)
        return 0;
    else if (nTimes < 5)
        return 1;
    else if (nTimes < 10)
        return 2;
    else if (nTimes < 20)
        return 3;
    else if (nTimes < 30)
        return 4;
    else if (nTimes < 40)
        return 5;
    else if (nTimes < 50)
        return 6;
    else if (nTimes < 60)
        return 7;
    else if (nTimes < 80)
        return 8;
    else if (nTimes < 100)
        return 9;
    else
        return 10;
}
