#include <sourcemod>
#include <mapchooser>
#include <globalvariables>

#pragma newdecls required
#pragma semicolon 1

#include "advertisements/topcolors.sp"

#define PLUGIN_VERSION  "2.1.1c"

#define MAX_MESSAGE_LEN 1024

public Plugin myinfo =
{
    name        = "Advertisements Custom",
    author      = "Tsunami & clagura",
    description = "Display advertisements",
    version     = PLUGIN_VERSION,
    url         = "http://www.tsunami-productions.nl"
};

enum MessageType {
    Center,
    Chat,
    Hint,
    MenuMess,
    Top,
}

enum struct Advertisement
{
    MessageType type;
    char szMessage[1024];
    float intervals;
}

/**
 * Globals
 */
int g_iCurrentAd;
ArrayList g_hAdvertisements;
ConVar g_hEnabled;
ConVar g_hFile;
ConVar g_hDefaultInterval;
ConVar g_hRandom;
Handle g_hTimer;

char g_szCenterAdText[1024];

/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    CreateConVar("sm_advertisements_version", PLUGIN_VERSION, "Display advertisements", FCVAR_NOTIFY);
    g_hEnabled  = CreateConVar("sm_advertisements_enabled",  "1",                  "Enable/disable displaying advertisements.");
    g_hFile     = CreateConVar("sm_advertisements_file",     "advertisements.txt", "File to read the advertisements from.");
    g_hDefaultInterval = CreateConVar("sm_advertisements_interval_default", "30",                 "Default number of seconds between advertisements.");
    g_hRandom   = CreateConVar("sm_advertisements_random",   "0",                  "Enable/disable random advertisements.");

    g_hEnabled.AddChangeHook(OnConVarChanged);
    g_hFile.AddChangeHook(OnConVarChanged);
    g_hDefaultInterval.AddChangeHook(OnConVarChanged);
    g_hRandom.AddChangeHook(OnConVarChanged);

    g_hAdvertisements = new ArrayList(sizeof(Advertisement));

    RegServerCmd("sm_advertisements_reload", Command_ReloadAds, "Reload the advertisements");

    delete g_hTopColors;
    AddTopColors();
}

public void OnConfigsExecuted()
{
    ParseAds();
    RestartTimer();
}

public void OnConVarChanged(ConVar hConVar, const char[] szOld, const char[] szNew) {
    if (hConVar == g_hEnabled && g_hEnabled.BoolValue) {
        RestartTimer();
    }
    else {
        ParseAds();
        if (hConVar == g_hDefaultInterval) {
            RestartTimer();
        }
    }
}

/**
 * ConVar Changes
 */
public void ConVarChanged_File(ConVar convar, const char[] oldValue, const char[] newValue)
{
    ParseAds();
}

public void ConVarChanged_Interval(ConVar convar, const char[] oldValue, const char[] newValue)
{
    RestartTimer();
}


/**
 * Commands
 */
public Action Command_ReloadAds(int args)
{
    ParseAds();
    return Plugin_Handled;
}


/**
 * Menu Handlers
 */
public int MenuHandler_DoNothing(Menu menu, MenuAction action, int param1, int param2) { return 0; }


/**
 * Timers
 */
public Action Timer_DisplayAd(Handle timer)
{
    if (!g_hEnabled.BoolValue) {
        return Plugin_Stop;
    }
    if (g_iCurrentAd >= g_hAdvertisements.Length) {
        g_iCurrentAd = 0;
    }

    Advertisement ad;
    g_hAdvertisements.GetArray(g_iCurrentAd, ad);
    char szBuffer[1024];
    strcopy(szBuffer, sizeof(szBuffer), ad.szMessage);

    switch (ad.type) {
        case Center: {
            CProcessVariables(szBuffer, sizeof(szBuffer), false, true);
            PrintCenterTextAll(g_szCenterAdText);
            CreateTimer(1.0 , Timer_CenterAd, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
        }
        case Chat: {
            CProcessVariables(szBuffer, sizeof(szBuffer), true, true);
            CPrintToChatAll(0, szBuffer);
        }
        case Hint: {
            CProcessVariables(szBuffer, sizeof(szBuffer), false, true);
            PrintHintTextToAll(szBuffer);
        }
        case MenuMess: {
            CProcessVariables(szBuffer, sizeof(szBuffer), false, true);

            Panel hPl = new Panel();
            hPl.DrawText(szBuffer);
            hPl.CurrentKey = 10;

            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && !IsFakeClient(i)) {
                    hPl.Send(i, MenuHandler_DoNothing, 10);
                }
            }

            delete hPl;
        }
        case Top: {
            int iStart = 0, aColor[4] = {255, 255, 255, 255};

            ParseTopColor(szBuffer, iStart, aColor);
            CProcessVariables(szBuffer[iStart], sizeof(szBuffer), false, true);

            KeyValues hKv = new KeyValues("Stuff", "title", szBuffer);
            hKv.SetColor4("color", aColor);
            hKv.SetNum("level", 1);
            hKv.SetNum("time", 10);

            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && !IsFakeClient(i)) {
                    CreateDialog(i, hKv, DialogType_Msg);
                }
            }

            delete hKv;
        }
    }
    
    g_iCurrentAd++;

    g_hTimer = CreateTimer(ad.intervals, Timer_DisplayAd, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Stop;
}

public Action Timer_CenterAd(Handle timer)
{
    static int iCount = 0;
    if (++iCount >= 5) {
        iCount = 0;
        return Plugin_Stop;
    }

    PrintCenterTextAll("%s", g_szCenterAdText);
    return Plugin_Continue;
}

void ParseAds()
{
    g_iCurrentAd = 0;
    g_hAdvertisements.Clear();

    char sFile[64], sPath[PLATFORM_MAX_PATH];
    g_hFile.GetString(sFile, sizeof(sFile));
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/%s", sFile);

    if (!FileExists(sPath)) {
        SetFailState("File Not Found: %s", sPath);
    }

    KeyValues hConfig = new KeyValues("Advertisements");
    hConfig.SetEscapeSequences(false);
    hConfig.ImportFromFile(sPath);
    hConfig.GotoFirstSubKey();

    Advertisement ad;
    char szType[16];
    do {
        hConfig.GetString("type", szType, sizeof(szType));

        if (strcmp(szType, "chat", false) == 0) {
            ad.type = Chat;
        }
        else if (strcmp(szType, "center", false) == 0) {
            ad.type = Center;
        }
        else if (strcmp(szType, "hint", false) == 0) {
            ad.type = Hint;
        }
        else if (strcmp(szType, "menu", false) == 0) {
            ad.type = MenuMess;
        }
        else if (strcmp(szType, "top", false) == 0) {
            ad.type = Top;
        }
        else {
            char szKey[128];
            hConfig.GetSectionName(szKey, sizeof(szKey));
            LogError("Unknown message type in key: %s", szKey);

            continue;
        }
        hConfig.GetString("message", ad.szMessage, sizeof(Advertisement::szMessage));
        ad.intervals = hConfig.GetFloat("intervals", g_hDefaultInterval.FloatValue);

        g_hAdvertisements.PushArray(ad);
    } while (hConfig.GotoNextKey());

    LogMessage("%d messages have been loaded", g_hAdvertisements.Length);

    if (g_hRandom.BoolValue) {
        g_hAdvertisements.Sort(Sort_Random, Sort_Integer);
    }

    delete hConfig;
}

void RestartTimer()
{
    if (IsValidHandle(g_hTimer)) {
        delete g_hTimer;
    }
    g_hTimer = CreateTimer(g_hDefaultInterval.FloatValue, Timer_DisplayAd, _, TIMER_FLAG_NO_MAPCHANGE);
}