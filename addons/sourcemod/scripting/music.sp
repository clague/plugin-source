#pragma semicolon 1
#include <sourcemod>
#include <SteamWorks>
#include <json>
#include <globalvariables>
#include <clientprefs>
#include <getoverit>

enum struct SongDetail {
    int id;
    char name[128];
    char author[128];
}

char sClientPlaying[MAXPLAYERS + 1][20];
Handle g_hBroadcastDefault = INVALID_HANDLE;
Handle g_hReceiveMusic = INVALID_HANDLE;
char g_sBroadcastDefault[MAXPLAYERS + 1][5];
char g_sReceiveMusic[MAXPLAYERS + 1][5];

public Plugin:myinfo =
{
    name 			=		"Netease Clound Music",				/* https://www.youtube.com/watch?v=Tq_0ht8HCcM */
    author			=		"clagura",
    description		=		"Music",
    version			=		"1.0",
    url				=		"https://www.autumnfish.cn/"
};

public OnPluginStart()
{
    RegConsoleCmd("sm_music", DoMusic);
    RegConsoleCmd("sm_m", DoMusic);
    RegConsoleCmd("sm_musicb", DoMusic);
    RegConsoleCmd("sm_mb", DoMusic);
    RegConsoleCmd("sm_stop", StopMusic);
    RegConsoleCmd("sm_nr", NoReceive);
    RegConsoleCmd("sm_noreceive", NoReceive);

    g_hBroadcastDefault = RegClientCookie("BroadcastMusicDefault", "分享点歌选项的默认值（Yes/No）", CookieAccess_Public);
    g_hReceiveMusic = RegClientCookie("ReceiveMusic", "是否接受别人的点歌（Yes/No）", CookieAccess_Public);
}

public void OnClientCookiesCached(int client) {
    GetClientCookie(client, g_hBroadcastDefault, g_sBroadcastDefault[client], 5);
    GetClientCookie(client, g_hReceiveMusic, g_sReceiveMusic[client], 5);
}

public OnMapEnd() {
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            OnClientDisconnect(i);
    }
}

public void OnClientDisconnect(int client) {
    SetClientCookie(client, g_hBroadcastDefault, g_sBroadcastDefault[client]);
    SetClientCookie(client, g_hReceiveMusic, g_sReceiveMusic[client]);
    if (IsClientInGame(client))
        ShowHiddenMOTDPanel(client, "http://music.163.com/", MOTDPANEL_TYPE_URL);
}

public Action DoMusic(int client, int args)
{
    char cmd[20];
    GetCmdArg(0, cmd, sizeof(cmd));

    int bIsBackground = 0;
    if (cmd[strlen(cmd) - 1] == 'b') {
        bIsBackground = 1;
    }

    char sArg[256], sRequest[512], sArgEncoded[256];
    GetCmdArgString(sArg, sizeof(sArg));
    urlencode(sArg, sArgEncoded, 256);
    Format(sRequest, sizeof(sRequest), "https://www.autumnfish.cn/search?keywords=%s&limit=5", sArgEncoded);
    
    new Handle:hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sRequest);
    SteamWorks_SetHTTPRequestContextValue(hRequest, client + 100 * bIsBackground);
    SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, 30);
    SteamWorks_SetHTTPCallbacks(hRequest, OnTransferComplete);
    SteamWorks_SendHTTPRequest(hRequest);

    return Plugin_Handled;
}

public OnTransferComplete(Handle:hRequest, bool:bFailure, bool:bRequestSuccessful, EHTTPStatusCode:eStatusCode, int data)
{
    if (!bFailure && bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
    {
        SteamWorks_GetHTTPResponseBodyCallback(hRequest, APIWebResponse, data);
    }
}

public int APIWebResponse(const String:sData[], int data)
{
    int client = data % 100;
    bool bIsBackground = data >= 100;

    if (!IsClientInGame(client))
        return -1;

    JSON_Object obj = json_decode(sData);
    char code[10];
    obj.GetString("code", code, sizeof(code));

    if(!strcmp(code, "200"))
    {
        PrintToChat(client, "API查询失败！");
        return -1;
    }

    JSON_Array arr = view_as<JSON_Array>(obj.GetObject("result").GetObject("songs"));

    int iArrlength = min(arr.Length, 5), iSongID[5];
    char sSongName[5][128], sAuthorName[5][256];
    for (int i = 0; i < iArrlength; i++)
    {
        JSON_Object objSong = arr.GetObject(i);
        iSongID[i] = objSong.GetInt("id");
        objSong.GetString("name", sSongName[i], 128);

        JSON_Array arrArtists= view_as<JSON_Array>(objSong.GetObject("artists"));
        int iArtistsLength = min(arrArtists.Length, 2);
        for (int j = 0; j < iArtistsLength; j++)
        {
            char author[128];
            arrArtists.GetObject(j).GetString("name", author, 128);
            if (j == 0)
                Format(sAuthorName[i], 256, "%s", author);
            else
                Format(sAuthorName[i], 256, "%s & %s", sAuthorName[i], author);
        }

    }
    
    obj.Cleanup();
    delete obj;

    Menu menu;
    if (bIsBackground)
        menu = new Menu(MusicMenuHandlerB);
    else
        menu = new Menu(MusicMenuHandler);

    menu.SetTitle("歌曲列表");

    for (int i = 0; i < iArrlength; i++)
    {
        char temp[20], fullname[256];
        Format(temp, 20, "%d", iSongID[i]);
        Format(fullname, sizeof(fullname), "%s - %s", sSongName[i], sAuthorName[i]);
        menu.AddItem(temp, fullname);
    }
    menu.ExitButton = true;
    menu.Display(client, 50);

    return 0;
}

public int MusicMenuHandlerB(Menu menu, MenuAction action, int client, int slot)
{
    if (action == MenuAction_Select)
    {
        ClientCommand(client, "cl_motd_allow_remote_url 1");
        int style = 0;
        char info[20], sSongUrl[128], display[128];
        menu.GetItem(slot, info, sizeof(info), style, display, sizeof(display));
        Format(sSongUrl, sizeof(sSongUrl), "https://music.163.com/song/media/outer/url?id=%s.mp3", info);
        ShowHiddenMOTDPanel(client, sSongUrl, MOTDPANEL_TYPE_URL);
        
        MusicMessage(client, display);

        FormatEx(sClientPlaying[client], sizeof(sClientPlaying[]), info);
    }
    else if (action == MenuAction_End)
        delete menu;
    return 0;
}

public int MusicMenuHandler(Menu menu, MenuAction action, int client, int slot)
{
    if (action == MenuAction_Select)
    {
        char info[20], display[128];
        menu.GetItem(slot, info, sizeof(info), _, display, sizeof(display));
        
        Menu submenu = new Menu(ConfirmMenuHandler, MENU_ACTIONS_DEFAULT | MenuAction_DisplayItem);
        submenu.SetTitle(display);
        submenu.AddItem("front", "弹出播放面板");
        submenu.AddItem("back", "后台播放");
        submenu.AddItem("broadcast", "default");
        submenu.ExitButton = true;
        submenu.Display(client, 50);

        FormatEx(sClientPlaying[client], sizeof(sClientPlaying[]), info);
    }
    else if (action == MenuAction_End)
        delete menu;
    return 0;
}

public int ConfirmMenuHandler(Menu menu, MenuAction action, int client, int slot)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[20], sSongUrl[128], display[128];
            menu.GetItem(slot, info, sizeof(info));
            menu.GetTitle(display, sizeof(display));
            if (slot == 0) {
                ClientCommand(client, "cl_motd_allow_remote_url 1");
                Format(sSongUrl, sizeof(sSongUrl), "http://43.248.191.122:20247/player?id=%s", sClientPlaying[client]);
                ShowNotHiddenMOTDPanel(client, sSongUrl, MOTDPANEL_TYPE_URL);
                MusicMessage(client, display);
                if (menu.ItemCount > 2 && g_sBroadcastDefault[client][0] == 'Y')
                    BroadcastMusic(client, sClientPlaying[client], display);
                delete menu;
            }
            else if (slot == 1) {
                ClientCommand(client, "cl_motd_allow_remote_url 1");
                Format(sSongUrl, sizeof(sSongUrl), "https://music.163.com/song/media/outer/url?id=%s.mp3", sClientPlaying[client]);
                ShowHiddenMOTDPanel(client, sSongUrl, MOTDPANEL_TYPE_URL);
                MusicMessage(client, display);
                if (menu.ItemCount > 2 && g_sBroadcastDefault[client][0] == 'Y')
                    BroadcastMusic(client, sClientPlaying[client], display);
                delete menu;
            }
            else if (StrEqual(info, "broadcast")) {
                if (g_sBroadcastDefault[client][0] == 'Y') {
                    FormatEx(g_sBroadcastDefault[client], 5, "No");
                }
                else {
                    FormatEx(g_sBroadcastDefault[client], 5, "Yes");
                }
                DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), 20);
            }
        }
        case MenuAction_DisplayItem:
        {
            if (slot == 2) {
                if (g_sBroadcastDefault[client][0] == 'Y') 
                    return RedrawMenuItem("选项：是否广播本次点歌 - 是");
                else
                    return RedrawMenuItem("选项：是否广播本次点歌 - 否");
            }
        }
        case MenuAction_Cancel:
        {
            delete menu;
        }
    }

    return 0;
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

public Action StopMusic(int client, int args)
{
    ShowHiddenMOTDPanel(client, "http://music.163.com/", MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}

int min(int a, int b)
{
    if (a < b)
        return a;
    else
        return b;
}

char sHexTable[] = "0123456789abcdef";

stock urlencode(const char[] sString, char[] sResult, int len)
{
    new from, c;
    new to;

    while(from < len)
    {
        c = sString[from++];
        if(c == 0)
        {
            sResult[to++] = c;
            break;
        }
        else if(c == ' ')
        {
            sResult[to++] = '+';
        }
        else if((c < '0' && c != '-' && c != '.') ||
                (c < 'A' && c > '9') ||
                (c > 'Z' && c < 'a' && c != '_') ||
                (c > 'z'))
        {
            if((to + 3) > len)
            {
                sResult[to] = 0;
                break;
            }
            sResult[to++] = '%';
            sResult[to++] = sHexTable[c >> 4];
            sResult[to++] = sHexTable[c & 15];
        }
        else
        {
            sResult[to++] = c;
        }
    }
}

public void MusicMessage(int client, char[] display) {
    char name[500];
    FetchColoredName(client, name, sizeof(name));
    CPrintToChatAll(0, "{green}[系统] %s 收听了 {red}%s {white}！", name, display);
    CPrintToChat(client, 0, "{green}[系统] {white}输入{green}!stop{white}暂停音乐！");
}

public void BroadcastMusic(int client, char[] sSongId, const char[] display) {
    for (int i = 1; i <= MaxClients; i++) {
        if (i != client && IsClientInGame(i)) {
            if (g_sReceiveMusic[i][0] != 'N')
            {
                FormatEx(sClientPlaying[i], sizeof(sClientPlaying[]), sSongId);

                Menu menu = new Menu(ConfirmMenuHandler);
                menu.SetTitle(display);
                menu.AddItem("front", "弹出播放面板");
                menu.AddItem("back", "后台播放");
                menu.ExitButton = true;

                menu.Display(i, 20);
                CPrintToChat(i, 0, "{red}[提示]：{white}如果想屏蔽别人的点歌，你可以输入{red}!nr");
            }
        }
    }
}

public Action NoReceive(int client, int args) {
    if (g_sReceiveMusic[client][0] != 'N') {
        FormatEx(g_sReceiveMusic[client], 5, "No");
        CPrintToChat(client, 0, "{green}[提示]：{white}将不再接受别人的点歌，你可以再次输入{green}!nr{white}解除屏蔽");
    }
    else if (g_sReceiveMusic[client][0] == 'N') {
        FormatEx(g_sReceiveMusic[client], 5, "Yes");
        CPrintToChat(client, 0, "{green}[提示]：{white}目前会接受别人的点歌，你可以再次输入{green}!nr{white}屏蔽");
    }

    return Plugin_Handled;
}