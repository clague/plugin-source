#include <sourcemod>
#include <mapchooser>

#pragma newdecls required
#pragma semicolon 1

#include "advertisements/chatcolors.sp"
#include "advertisements/topcolors.sp"

#define PLUGIN_VERSION  "2.1.1"

public Plugin myinfo =
{
    name        = "Advertisements",
    author      = "Tsunami",
    description = "Display advertisements",
    version     = PLUGIN_VERSION,
    url         = "http://www.tsunami-productions.nl"
};


enum struct Advertisement
{
    char center[1024];
    char chat[2048];
    char hint[1024];
    char menu[1024];
    char top[1024];
}


/**
 * Globals
 */
bool g_bMapChooser;
bool g_bSayText2;
int g_iCurrentAd;
ArrayList g_hAdvertisements;
ConVar g_hEnabled;
ConVar g_hFile;
ConVar g_hInterval;
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
    g_hInterval = CreateConVar("sm_advertisements_interval", "30",                 "Number of seconds between advertisements.");
    g_hRandom   = CreateConVar("sm_advertisements_random",   "0",                  "Enable/disable random advertisements.");

    g_hFile.AddChangeHook(ConVarChanged_File);
    g_hInterval.AddChangeHook(ConVarChanged_Interval);

    g_bMapChooser = LibraryExists("mapchooser");
    g_bSayText2 = GetUserMessageId("SayText2") != INVALID_MESSAGE_ID;
    g_hAdvertisements = new ArrayList(sizeof(Advertisement));

    RegServerCmd("sm_advertisements_reload", Command_ReloadAds, "Reload the advertisements");

    AddChatColors();
    AddTopColors();
}

public void OnConfigsExecuted()
{
    ParseAds();
    RestartTimer();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "mapchooser")) {
        g_bMapChooser = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "mapchooser")) {
        g_bMapChooser = false;
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

    Advertisement ad;
    g_hAdvertisements.GetArray(g_iCurrentAd, ad);
    char message[1024];

    if (ad.center[0]) {
        ProcessVariables(ad.center, g_szCenterAdText, sizeof(message));
        PrintCenterTextAll(g_szCenterAdText);

        CreateTimer(1.0, Timer_CenterAd, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    }
    if (ad.chat[0]) {
        bool teamColor[10];
        char messages[10][256];
        int messageCount = ExplodeString(ad.chat, "\n", messages, sizeof(messages), sizeof(messages[]));

        for (int idx = 0; idx < messageCount; idx++) {
            teamColor[idx] = StrContains(messages[idx], "{teamcolor}", false) != -1;
            if (teamColor[idx] && !g_bSayText2) {
                SetFailState("This game does not support {teamcolor}");
            }

            ProcessVariables(messages[idx], message, sizeof(message), true);
            strcopy(messages[idx], sizeof(messages[]), message);
        }

        for (int idx; idx < messageCount; idx++) {
            if (teamColor[idx]) {
                for (int i = 1; i <= MaxClients; i++) {
                    if (IsValidClient(i)) {
                        SayText2(i, messages[idx]);
                    }
                }
            } else {
                PrintToChatAll(messages[idx]);
            }
        }
    }
    if (ad.hint[0]) {
        ProcessVariables(ad.hint, message, sizeof(message));

        PrintHintTextToAll(message);
    }
    if (ad.menu[0]) {
        ProcessVariables(ad.menu, message, sizeof(message));

        Panel hPl = new Panel();
        hPl.DrawText(message);
        hPl.CurrentKey = 10;

        for (int i = 1; i <= MaxClients; i++) {
            if (IsValidClient(i)) {
                hPl.Send(i, MenuHandler_DoNothing, 10);
            }
        }

        delete hPl;
    }
    if (ad.top[0]) {
        int iStart    = 0,
            aColor[4] = {255, 255, 255, 255};

        ParseTopColor(ad.top, iStart, aColor);
        ProcessVariables(ad.top[iStart], message, sizeof(message));

        KeyValues hKv = new KeyValues("Stuff", "title", message);
        hKv.SetColor4("color", aColor);
        hKv.SetNum("level",    1);
        hKv.SetNum("time",     10);

        for (int i = 1; i <= MaxClients; i++) {
            if (IsValidClient(i)) {
                CreateDialog(i, hKv, DialogType_Msg);
            }
        }

        delete hKv;
    }

    if (++g_iCurrentAd >= g_hAdvertisements.Length) {
        g_iCurrentAd = 0;
    }

    return Plugin_Continue;
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


/**
 * Functions
 */
bool IsValidClient(int client)
{
    if (IsClientInGame(client)) {
        return !IsFakeClient(client);
    }
    return false;
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
    char flags[22];
    do {
        hConfig.GetString("center", ad.center, sizeof(Advertisement::center));
        hConfig.GetString("chat",   ad.chat,   sizeof(Advertisement::chat));
        hConfig.GetString("hint",   ad.hint,   sizeof(Advertisement::hint));
        hConfig.GetString("menu",   ad.menu,   sizeof(Advertisement::menu));
        hConfig.GetString("top",    ad.top,    sizeof(Advertisement::top));
        hConfig.GetString("flags",  flags,     sizeof(flags));

        g_hAdvertisements.PushArray(ad);
    } while (hConfig.GotoNextKey());

    if (g_hRandom.BoolValue) {
        g_hAdvertisements.Sort(Sort_Random, Sort_Integer);
    }

    delete hConfig;
}

void ProcessVariables(const char[] message, char[] buffer, int maxlength, bool chat=false)
{
    char name[32], value[256];
    int buf_idx, i, name_len;
    ConVar hConVar;

    while (message[i] && buf_idx < maxlength - 1) {
        if (message[i] != '{' || (name_len = FindCharInString(message[i + 1], '}')) == -1) {
            buffer[buf_idx++] = message[i++];
            continue;
        }

        strcopy(name, name_len + 1, message[i + 1]);

        if (StrEqual(name, "currentmap", false)) {
            GetCurrentMap(value, sizeof(value));
            GetMapDisplayName(value, value, sizeof(value));
            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);
        }
        else if (StrEqual(name, "nextmap", false)) {
            if (g_bMapChooser && EndOfMapVoteEnabled() && !HasEndOfMapVoteFinished()) {
                buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, "Pending Vote");
            } else {
                GetNextMap(value, sizeof(value));
                GetMapDisplayName(value, value, sizeof(value));
                buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);
            }
        }
        else if (StrEqual(name, "date", false)) {
            FormatTime(value, sizeof(value), "%Y/%m/%d");
            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);
        }
        else if (StrEqual(name, "time", false)) {
            FormatTime(value, sizeof(value), "%I:%M:%S%p");
            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);
        }
        else if (StrEqual(name, "time24", false)) {
            FormatTime(value, sizeof(value), "%H:%M:%S");
            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);
        }
        else if (StrEqual(name, "timeleft", false)) {
            int mins, secs, timeleft;
            if (GetMapTimeLeft(timeleft) && timeleft > 0) {
                mins = timeleft / 60;
                secs = timeleft % 60;
            }

            buf_idx += FormatEx(buffer[buf_idx], maxlength - buf_idx, "%d:%02d", mins, secs);
        }
        else if (chat) {
            char color[10];
            if (name[0] == '#') {
                buf_idx += FormatEx(buffer[buf_idx], maxlength - buf_idx, "%c%s", (name_len == 9) ? 8 : 7, name[1]);
            }
            else if (g_hChatColors.GetString(name, color, sizeof(color))) {
                buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, color);
            }
        }
        else if ((hConVar = FindConVar(name))) {
            hConVar.GetString(value, sizeof(value));
            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);
        }
        else {
            buf_idx += FormatEx(buffer[buf_idx], maxlength - buf_idx, "{%s}", name);
        }

        i += name_len + 2;
    }

    buffer[buf_idx] = '\0';
}

void RestartTimer()
{
    delete g_hTimer;
    g_hTimer = CreateTimer(float(g_hInterval.IntValue), Timer_DisplayAd, _, TIMER_REPEAT);
}