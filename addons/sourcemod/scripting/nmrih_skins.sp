// Based on the code of the plugin "SM Skinchooser HL2DM" v2.3 by Andi67
#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <globalvariables>

#define PLUGIN_NAME	"[NMRiH] Skins"
#define PLUGIN_VERSION	"1.0.0c"
// Paths to configuration files
#define DOWNLOADS_LIST	"configs/nmrih_skins/downloads_list.ini"
#define FORCED_SKINS	"configs/nmrih_skins/forced_skins.ini"
#define SKINS_MENU		"configs/nmrih_skins/skins_menu.ini"

#define MAX_GROUPS 32
#define MAX_FORCEDSKINS 64

#define DEFAULT_FOV 90

bool g_bEnable,
	g_bAdminGroup,
	g_bAdminOnly,
	g_bSpawnTimer,
	g_bForceSkin,
	g_bUseTranslation;

Menu g_hMainMenu[MAXPLAYERS + 1], g_hModelMenu[MAX_GROUPS], g_hFovMenu;
KeyValues g_hMenuKv;
Cookie g_hCustomModel, g_hOriginalModel, g_hFov;
bool g_bLate,
	g_bListenClient[MAXPLAYERS + 1],
	g_bCookieLate[MAXPLAYERS + 1],
	g_bSelectedSkin[MAXPLAYERS + 1];
bool g_bInScoped[MAXPLAYERS + 1];
int g_nForcedSkins,
	g_nTotalSkins;
char g_szForcedSkins[MAX_FORCEDSKINS][PLATFORM_MAX_PATH];
StringMap g_hCategoryiIndex;

public Plugin myinfo = {
	name		= PLUGIN_NAME,
	author		= "Grey83 & clagura",
	description	= "Skins menu for NMRiH",
	version		= PLUGIN_VERSION,
	url			= ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("nmrih_skins_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);

	ConVar hCVar;
	(hCVar = CreateConVar("sm_skins_enable",		"1", _, FCVAR_NOTIFY, true, _, true, 1.0)).AddChangeHook(CVarChanged_Enable);
	g_bEnable = hCVar.BoolValue;

	(hCVar = CreateConVar("sm_skins_admingroup",	"1", "Adds the possebility to use the Groupsystem", _, true, _, true, 1.0)).AddChangeHook(CVarChanged_AdminGroup);
	g_bAdminGroup = hCVar.BoolValue;

	(hCVar = CreateConVar("sm_skins_adminonly",		"0", _, _, true, _, true, 1.0)).AddChangeHook(CVarChanged_AdminOnly);
	g_bAdminOnly = hCVar.BoolValue;

	(hCVar = CreateConVar("sm_skins_spawntimer",	"1", _, _, true, _, true, 1.0)).AddChangeHook(CVarChanged_SpawnTimer);
	g_bSpawnTimer = hCVar.BoolValue;

	(hCVar = CreateConVar("sm_skins_forceskin",		"0", "Players will apply a skin no matter if they didn´t choosed a model from the menu", _, true, _, true, 1.0)).AddChangeHook(CVarChanged_ForceSkin);
	g_bForceSkin = hCVar.BoolValue;

	(hCVar = CreateConVar("sm_skins_use_translations",	"0", "Use translation file", _, true, _, true, 1.0)).AddChangeHook(CVarChanged_UseTranslation);
	g_bUseTranslation = hCVar.BoolValue;

	AutoExecConfig(true, "nmrih_skins");

	RegConsoleCmd("sm_model", Cmd_Model);
	RegConsoleCmd("sm_models", Cmd_Model);
	RegConsoleCmd("sm_skin", Cmd_Model);
	RegConsoleCmd("sm_skins", Cmd_Model);

	RegConsoleCmd("sm_fov", Cmd_Fov);
	AddCommandListener(FovListener, "say");

	g_hCustomModel = FindClientCookie("custommodel");
	if (!IsValidHandle(g_hCustomModel)) {
		g_hCustomModel = RegClientCookie("custommodel", "Player's custom model", CookieAccess_Protected);
	}

	g_hOriginalModel = FindClientCookie("originalmodel");
	if (!IsValidHandle(g_hOriginalModel)) {
		g_hOriginalModel = RegClientCookie("originalmodel", "Player's original model", CookieAccess_Protected);
	}

	g_hFov = FindClientCookie("FOV");
	if (!IsValidHandle(g_hFov)) {
		g_hFov = RegClientCookie("FOV", "Player's FOV", CookieAccess_Public);
	}
	SetCookieMenuItem(CookieMenu_Fov, 0, "FOV");

	HookEvent("player_spawn", Event_PlayerSpawn);

	if(g_bLate) {
		for(int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i)) {
				OnClientConnected(i);
				if (AreClientCookiesCached(i)) {
					g_bCookieLate[i] = true;
					OnClientCookiesCached(i);
				}
			}
		}
		g_bLate = false;
	}

	g_hFovMenu = new Menu(Menu_Fov, MenuAction_Display | MenuAction_DisplayItem | MenuAction_DrawItem | MenuAction_Select);
	g_hFovMenu.SetTitle("选择你的FOV值："); // Set in handle
	g_hFovMenu.AddItem("0", "0（默认）");
	g_hFovMenu.AddItem("90", "90");
	g_hFovMenu.AddItem("100", "100");
	g_hFovMenu.AddItem("110", "110");
	g_hFovMenu.AddItem("120", "120");
	g_hFovMenu.AddItem("Custom", "自定义");
	g_hFovMenu.ExitButton = true;
}

public void OnPluginEnd() {
	OnMapEnd();
	if (IsValidHandle(g_hFovMenu)) {
		delete g_hFovMenu;
	}
}

public void CVarChanged_Enable(ConVar hCVar, const char[] szOldValue, const char[] szNewValue) {
	g_bEnable = hCVar.BoolValue;
}

public void CVarChanged_AdminGroup(ConVar hCVar, const char[] szOldValue, const char[] szNewValue) {
	g_bAdminGroup = hCVar.BoolValue;
}

public void CVarChanged_AdminOnly(ConVar hCVar, const char[] szOldValue, const char[] szNewValue) {
	g_bAdminOnly = hCVar.BoolValue;
}

public void CVarChanged_SpawnTimer(ConVar hCVar, const char[] szOldValue, const char[] szNewValue) {
	g_bSpawnTimer = hCVar.BoolValue;
}

public void CVarChanged_ForceSkin(ConVar hCVar, const char[] szOldValue, const char[] szNewValue) {
	g_bForceSkin = hCVar.BoolValue;
}

public void CVarChanged_UseTranslation(ConVar hCVar, const char[] szOldValue, const char[] szNewValue) {
	g_bUseTranslation = hCVar.BoolValue;
	if (g_bUseTranslation) {
		LoadTranslations("nmrih.skins.phrases");
		ServerCommand("sm_reload_translations");
	}
}

public void OnConfigsExecuted() {
	if (g_bUseTranslation) {
		LoadTranslations("nmrih.skins.phrases");
	}
}

public void OnMapStart() {
	if (!g_bEnable) {
		return;
	}
	g_nTotalSkins = 0;
	LoadForcedSkins();

	static char szFile[256];
	static char szPath[100];

	g_hMenuKv = new KeyValues("Models");

	BuildPath(Path_SM, szFile, 255, SKINS_MENU);
	g_hMenuKv.ImportFromFile(szFile);
	if(!g_hMenuKv.GotoFirstSubKey()) return;
	do {
		g_hMenuKv.JumpToKey("List");
		g_hMenuKv.GotoFirstSubKey();
		do {
			g_hMenuKv.GetString("path", szPath, sizeof(szPath));
			if(PrecacheModel(szPath, true)) {
				g_nTotalSkins++;
			}
		}
		while (g_hMenuKv.GotoNextKey());
		g_hMenuKv.GoBack();
		g_hMenuKv.GoBack();
	}
	while (g_hMenuKv.GotoNextKey());
	g_hMenuKv.Rewind();

	ReadDownloads();
	LogMessage("Total: %i	Forced: %i", g_nTotalSkins, g_nForcedSkins);
}

stock void LoadForcedSkins() {
	static char szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, PLATFORM_MAX_PATH, FORCED_SKINS);

	//open precache file and add everything to download table
	File hFile = OpenFile(szBuffer, "r");
	while(hFile.ReadLine(szBuffer, sizeof(szBuffer))) {
		// Strip leading and trailing whitespace
		TrimString(szBuffer);

		// Skip non existing files(and Comments)
		if(FileExists(szBuffer, true)) {
			// Tell Clients to download files
			AddFileToDownloadsTable(szBuffer);
			// Tell Clients to cache model
			if(StrEqual(szBuffer[strlen(szBuffer)-4], ".mdl", false) && g_nForcedSkins < MAX_FORCEDSKINS) {
				strcopy(g_szForcedSkins[g_nForcedSkins++], strlen(szBuffer)+1, szBuffer);
				PrecacheModel(szBuffer, true);
			}
		}
	}
	if(IsValidHandle(hFile)) {
		delete hFile;
	}
}

stock void ReadDownloads() {
	static char szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, 255, DOWNLOADS_LIST);
	File hFile = OpenFile(szBuffer, "r");

	static int iPos;
	static bool bUseVfs;
	bUseVfs = false;
	while (hFile.ReadLine(szBuffer, sizeof(szBuffer))) {
		if ((iPos = StrContains(szBuffer, "//")) != -1) {
			szBuffer[iPos] = 0;
		}
		TrimString(szBuffer);
		if (szBuffer[0] == '[') {
			static char szOption[PLATFORM_MAX_PATH];
			if ((iPos = FindCharInString(szBuffer, ']')) != -1) {
				strcopy(szOption, iPos, szBuffer[1]);
				if (StrContains(szOption, "default", false) != -1) {
					bUseVfs = false;
				}
				else if (StrContains(szOption, "valvefs", false) != -1) {
					bUseVfs = true;
				}
			}
		}
		else if(szBuffer[0]) {
			ReadFileFolder(szBuffer, bUseVfs);
		}
	}
	if (IsValidHandle(hFile)) {
		delete hFile;
	}
}

stock void ReadFileFolder(char[] szPath, bool bUseVfs) {
	DirectoryListing hDir;
	char szBuffer[PLATFORM_MAX_PATH];
	FileType iType = FileType_Unknown;

	TrimString(szPath);
	if (szPath[strlen(szPath) - 1] == '/') {
		szPath[strlen(szPath) - 1] = 0;
	}

	if(DirExists(szPath, bUseVfs)) {
		hDir = OpenDirectory(szPath, bUseVfs);
		while (hDir.GetNext(szBuffer, sizeof(szBuffer), iType)) {
			TrimString(szBuffer);

			if(!StrEqual(szBuffer, "", false) && !StrEqual(szBuffer, ".", false) && !StrEqual(szBuffer, "..", false)) {
				Format(szBuffer, sizeof(szBuffer), "%s/%s", szPath, szBuffer);
				if (iType == FileType_File) { 
					ReadItem(szBuffer, bUseVfs);
				}
				else if (iType == FileType_Directory) {
					ReadFileFolder(szBuffer, bUseVfs);
				}
			}
		}
	} else {
		ReadItem(szPath, bUseVfs);
	}
	if(IsValidHandle(hDir)) {
		delete hDir;
	}
}

stock void ReadItem(char[] szBuffer, bool bUseVfs) {
	TrimString(szBuffer);
	if(szBuffer[0] && FileExists(szBuffer, bUseVfs)) {
		AddFileToDownloadsTable(szBuffer);
		//LogMessage("Add %s to download list", szBuffer);
	}
}

public void OnMapEnd() {
	if (IsValidHandle(g_hMenuKv)) {
		delete g_hMenuKv;
	}
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidHandle(g_hMainMenu[i])) {
			delete g_hMainMenu[i];
		}
	}
	for (int i = 0; i < MAX_GROUPS; i++) {
		if (IsValidHandle(g_hModelMenu[i])) {
			delete g_hModelMenu[i];
		}
	}
	if (IsValidHandle(g_hCategoryiIndex)) {
		delete g_hCategoryiIndex;
	}
}

public void OnClientConnected(int iClient) {
	g_bSelectedSkin[iClient] = false;
	g_bCookieLate[iClient] = false;
	g_bInScoped[iClient] = false;
}

public void OnClientCookiesCached(int iClient) {
	if (g_bCookieLate[iClient]) {
		if (!g_bSelectedSkin[iClient]) {
			static char szModel[PLATFORM_MAX_PATH];
			GetEntPropString(iClient, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
			g_hOriginalModel.Set(iClient, szModel);
		}
		if (IsPlayerAlive(iClient)) {
			if(g_bSpawnTimer) {
				CreateTimer(1.0, Timer_Spawn, GetClientUserId(iClient));
			} else {
				ApplyFromCookie(iClient);
			}
		}
		SDKHook(iClient, SDKHook_PostThinkPost, DetectScope);
		g_bCookieLate[iClient] = false;
	}
}

public void OnClientPutInServer(int iClient) {
	if (AreClientCookiesCached(iClient)) {
		SDKHook(iClient, SDKHook_PostThinkPost, DetectScope);
	} else {
		g_bCookieLate[iClient] = true;
	}
}

public void OnClientDisconnect_Post(int iClient) {
	if (IsValidHandle(g_hMainMenu[iClient])) {
		delete g_hMainMenu[iClient];
	}
	SDKUnhook(iClient, SDKHook_PostThinkPost, DetectScope);
}

public void Event_PlayerSpawn(Event hEvent, const char[] szName, bool bDontBroadcast) {
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!g_bEnable || !IsPlayerAlive(iClient)) {
		return;
	}

	if (GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 1) {
		ToggleView(iClient, false);
	}

	if (!AreClientCookiesCached(iClient)) {
		g_bCookieLate[iClient] = true;
		return;
	}

	if (!g_bSelectedSkin[iClient]) {
		char szModel[PLATFORM_MAX_PATH];
		GetEntPropString(iClient, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
		g_hOriginalModel.Set(iClient, szModel);
	}
	
	if(g_bSpawnTimer) {
		CreateTimer(1.0, Timer_Spawn, GetClientUserId(iClient));
	} else {
		ApplyFromCookie(iClient);
	}
}

public Action Timer_Spawn(Handle timer, any iUserId) {
	if (GetClientOfUserId(iUserId) != 0) {
		ApplyFromCookie(GetClientOfUserId(iUserId));
	}
	return Plugin_Stop;
}

public Action Cmd_Model(int iClient, int nArgs) {
	if(	g_bEnable &&
		IsValidClient(iClient) &&
		IsClientAuthorized(iClient) &&
		(g_bAdminOnly && GetUserAdmin(iClient) != INVALID_ADMIN_ID) || !g_bAdminOnly
	) {
		if (AreClientCookiesCached(iClient)) {
			if (!IsValidHandle(g_hMainMenu[iClient])) {
				g_hMainMenu[iClient] = BuildMainMenu(iClient);
			}
			g_hMainMenu[iClient].Display(iClient, MENU_TIME_FOREVER);
		} else {
			if (g_bUseTranslation) {
				CPrintToChat(iClient, 0, "{green}%t {white}%t", "ChatPrefix", "NotAuthorized");
			}
			else {
				CPrintToChat(iClient, 0, "{green}[系统] {white}尚未验证你的身份，请稍后再试");
			}
		}
	}
	return Plugin_Handled;
}

public Action Cmd_Fov(int iClient, int nArgs) {
	if(g_bEnable && IsValidClient(iClient)) {
		if (AreClientCookiesCached(iClient)) {
			static float fFov;
			if (GetCmdArgFloatEx(1, fFov)) {
				ApplyFov(iClient, RoundToNearest(fFov));
			} else {
				char buffer[256];
				g_hFov.Get(iClient, buffer, sizeof(buffer));
				int iFov = StringToInt(buffer);
				if (g_bUseTranslation) {
					CPrintToChat(iClient, 0, "{green}%t {white}%t", "ChatPrefix", "CurrentFov", GetEntProp(iClient, Prop_Send, "m_iFOV"), iFov);
					PrintToConsole(iClient, "default fov: %d", GetEntProp(iClient, Prop_Send, "m_iDefaultFOV"));
				} else {
					CPrintToChat(iClient, 0, "{green}[系统] {white}当前的{green}FOV{white}值：{orange}%d{white}，当前设置的{green}FOV{white}值：{red}%d{white}\n（死亡视角下两者不同是正常的）",
						GetEntProp(iClient, Prop_Send, "m_iFOV"), iFov);
				}
				g_hFovMenu.Display(iClient, MENU_TIME_FOREVER);
			}
		} else {
			if (g_bUseTranslation) {
				CPrintToChat(iClient, 0, "{green}%t {white}%t", "ChatPrefix", "NotAuthorized");
			} else {
				CPrintToChat(iClient, 0, "{green}[系统] {white}尚未验证你的身份，请稍后再试");
			}
		}
	}
	return Plugin_Handled;
}

public int Menu_Fov(Menu hMenu, MenuAction iAction, int iClient, int iParam) {
	switch(iAction) {
		case MenuAction_Display: {
			if (g_bUseTranslation) {
				static char szBuffer[64];
				FormatEx(szBuffer, sizeof(szBuffer), "%T", "FovMenuTitle", iClient);
			
				Panel panel = view_as<Panel>(iParam);
				panel.SetTitle(szBuffer);
			}
		}
		case MenuAction_DisplayItem: {
			if (g_bUseTranslation) {
				static char szBuffer[64];
				static int iFov = 0;
				hMenu.GetItem(iParam, szBuffer, sizeof(szBuffer), _, _, _, iClient);
				if (StringToIntEx(szBuffer, iFov) > 0) {
					if (iFov == 0) {
						FormatEx(szBuffer, sizeof(szBuffer), "%T", "DefaultFov", iClient, iFov);
						return RedrawMenuItem(szBuffer);
					}
				}
				else {
					Format(szBuffer, sizeof(szBuffer), "%T", szBuffer, iClient);
					return RedrawMenuItem(szBuffer);
				}
			}
		}
		case MenuAction_DrawItem: {
			static char szBuffer[64];
			static int m_iFov, iFov;

			m_iFov = GetEntProp(iClient, Prop_Send, "m_iFOV");
			hMenu.GetItem(iParam, szBuffer, sizeof(szBuffer), _, _, _, iClient);
			if ((StringToIntEx(szBuffer, iFov)) > 0) {
				if (iFov == m_iFov) {
					return ITEMDRAW_DISABLED;
				}
			}
		}
		case MenuAction_Select: {
			static int iFov = 0;
			static char szBuffer[64];
			hMenu.GetItem(iParam, szBuffer, sizeof(szBuffer), _, _, _, iClient);
			if ((StringToIntEx(szBuffer, iFov)) > 0) {
				ApplyFov(iClient, iFov);
				hMenu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
			}
			else if (strcmp(szBuffer, "Custom") == 0) {
				g_bListenClient[iClient] = true;
				if (g_bUseTranslation) {
					CPrintToChat(iClient, 0, "{red}%t {white}%t", "ChatPrefix", "FovCustomHint");
				} else {
					CPrintToChat(iClient, 0, "{red}[系统] {white}请在聊天框发送你的自定FOV（0~180）");
				}
			}
		}
	}
	return 0;
}

public Action FovListener(int iClient, const char[] szCommand, int nArgs) {
	if (g_bListenClient[iClient]) {
		g_bListenClient[iClient] = false;

		static char szBuffer[64];
		GetCmdArgString(szBuffer, sizeof(szBuffer));
		ReplaceString(szBuffer, sizeof(szBuffer), "\"", "");

		static float fFov;
		if (StringToFloatEx(szBuffer, fFov) > 0) {
			ApplyFov(iClient, RoundToNearest(fFov));

			if (g_bUseTranslation) {
				CPrintToChat(iClient, 0, "{green}%t {white}%t", "ChatPrefix", "Success");
			} else {
				CPrintToChat(iClient, 0, "{green}[系统] {white}修改成功！");
			}
			g_hFovMenu.Display(iClient, MENU_TIME_FOREVER);
		}
		else {
			if (g_bUseTranslation) {
				CPrintToChat(iClient, 0, "{green}%t {white}%t", "ChatPrefix", "Fail");
			} else {
				CPrintToChat(iClient, 0, "{green}[系统] {white}修改失败！");
			}
			g_hFovMenu.Display(iClient, MENU_TIME_FOREVER);
		}
		return Plugin_Handled;
	}
	else {
		return Plugin_Continue;
	}
}

public void CookieMenu_Fov(int iClient, CookieMenuAction action, any info, char[] szBuffer, int nMaxLen) {
	if (action == CookieMenuAction_DisplayOption) {
		strcopy(szBuffer, nMaxLen, "FOV");
	}
	else if (action == CookieMenuAction_SelectOption) {
		g_hFovMenu.Display(iClient, 0);
	}
}

stock Menu BuildMainMenu(int iClient) {
	g_hMenuKv.Rewind();
	if(!g_hMenuKv.GotoFirstSubKey()) {
		return null;
	}

	Menu hMenu = CreateMenu(Menu_Main, MENU_ACTIONS_ALL);

	static char szBuffer[30];
	static AdminId iAdmin;
	if(g_bAdminGroup) {
		iAdmin = GetUserAdmin(iClient);
	}

	static bool bWriteCategoryiIndex;
	static int iIndex;
	if (!IsValidHandle(g_hCategoryiIndex)) {
		g_hCategoryiIndex = new StringMap();
		bWriteCategoryiIndex = true;
	}
	else {
		bWriteCategoryiIndex = false;
	}

	iIndex = 0;
	do {
		g_hMenuKv.GetSectionName(szBuffer, sizeof(szBuffer));
		if (bWriteCategoryiIndex) {
			g_hCategoryiIndex.SetValue(szBuffer, iIndex);
			iIndex++;
		}
		if(g_bAdminGroup) {
			static char szGroup[30];
			g_hMenuKv.GetString("Admin", szGroup, sizeof(szGroup));
			if (!szGroup[0]) {
				hMenu.AddItem(szBuffer, szBuffer);
			}
			else {
				static GroupId iGroup;
				iGroup = FindAdmGroup(szGroup);
				if (iGroup == INVALID_GROUP_ID) {
					static AdminFlag iFlag;
					static int nLen;
					static bool bTemp;
					bTemp = true;
					nLen = strlen(szGroup);
					for (int i = 0; i < nLen; i++) {
						if (FindFlagByChar(szGroup[i], iFlag) && !iAdmin.HasFlag(iFlag)) {
							bTemp = false;
							break;
						}
					}
					if (bTemp) {
						hMenu.AddItem(szBuffer, szBuffer);
					}
				}
				else {
					static int iCount;
					iCount= GetAdminGroupCount(iAdmin);
					for(int i = 0; i < iCount; i++) {
						if(iGroup == GetAdminGroup(iAdmin, i, "", 0)) {
							hMenu.AddItem(szBuffer, szBuffer);
							break;
						}
					}
				}
			}
		}
		else {
			hMenu.AddItem(szBuffer, szBuffer);
		}
	}
	while(g_hMenuKv.GotoNextKey());
	g_hMenuKv.Rewind();

	hMenu.AddItem("none", "None");
	hMenu.SetTitle("%s (%i categories):", PLUGIN_NAME, hMenu.ItemCount);

	return hMenu;
}

public int Menu_Main(Menu hMenu, MenuAction iAction, int iClient, int iParam) {
	switch(iAction) {
		case MenuAction_Display: {
			ToggleView(iClient, true);

			if (g_bUseTranslation) {
				static char szBuffer[64];
				FormatEx(szBuffer, sizeof(szBuffer), "%s %T:", PLUGIN_NAME, "MainMenuTitleEx", iClient, hMenu.ItemCount);
			
				Panel panel = view_as<Panel>(iParam);
				panel.SetTitle(szBuffer);
			}
		}
		// User has selected a model group
		case MenuAction_Select: {
			static char szInfo[32];

			if(!hMenu.GetItem(iParam, szInfo, sizeof(szInfo))) return 0;

			// Check if the user decide to coming back to the original model
			if(StrEqual(szInfo, "none")) {
				g_hCustomModel.Set(iClient, "");

				static char szModel[PLATFORM_MAX_PATH];
				g_hOriginalModel.Get(iClient, szModel, sizeof(szModel));
				ApplyModel(iClient, szModel);

				g_hMainMenu[iClient].DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
				return 0;
			}

			// Create the model menu
			static int iIndex;
			if (g_hCategoryiIndex.GetValue(szInfo, iIndex)) {
				if (!IsValidHandle(g_hModelMenu[iIndex])) {
					g_hModelMenu[iIndex] = BuildModelMenu(szInfo);
				}
				g_hModelMenu[iIndex].Display(iClient, MENU_TIME_FOREVER);
			}
			else {
				CPrintToChat(iClient, 0, "{green}%t {white}%t", "ChatPrefix", "Fail");
			}
		}
		case MenuAction_DisplayItem: {
			if (g_bUseTranslation) {
				static char szBuffer[64], szDisplay[64];
				hMenu.GetItem(iParam, "", 0, _, szBuffer, sizeof(szBuffer), iClient);
				FormatEx(szDisplay, sizeof(szDisplay), "%T", szBuffer, iClient);
				return RedrawMenuItem(szDisplay);
			}
		}
		case MenuAction_Cancel: {
			if (iParam != MenuCancel_Disconnected) {
				ToggleView(iClient, false);
			}
		}
	}
	return 0;
}

stock Menu BuildModelMenu(const char[] szInfo) {
	Menu hModelMenu = CreateMenu(Menu_Model, MENU_ACTIONS_ALL);

	// Add the models to the menu
	static int nItems;
	static char szBuffer[30], szPath[256];
	nItems = 0;

	g_hMenuKv.Rewind();
	g_hMenuKv.JumpToKey(szInfo);
	g_hMenuKv.JumpToKey("List");
	g_hMenuKv.GotoFirstSubKey();
	do {
		// Add the model to the menu
		g_hMenuKv.GetSectionName(szBuffer, sizeof(szBuffer));
		g_hMenuKv.GetString("path", szPath, sizeof(szPath), "");
		hModelMenu.AddItem(szPath, szBuffer);
		nItems++;
	}
	while(g_hMenuKv.GotoNextKey());
	// Rewind the KVs
	g_hMenuKv.Rewind();
	// Set the menu title to the model group name
	hModelMenu.SetTitle(szInfo);
	hModelMenu.ExitBackButton = true;
	hModelMenu.ExitButton = true;

	return hModelMenu;
}

public int Menu_Model(Menu hMenu, MenuAction iAction, int iClient, int iParam) {
	switch(iAction) {
		case MenuAction_Display: {
			ToggleView(iClient, true);
			static char szBuffer[64];
			if (g_bUseTranslation) {
				hMenu.GetTitle(szBuffer, sizeof(szBuffer));
				Format(szBuffer, sizeof(szBuffer), "%s\n %T %T:", PLUGIN_NAME, szBuffer, iClient, "ModelMenuTitleEx", iClient, hMenu.ItemCount);
			
				Panel panel = view_as<Panel>(iParam);
				panel.SetTitle(szBuffer);
			}
			else {
				hMenu.GetTitle(szBuffer, sizeof(szBuffer));
				Format(szBuffer, sizeof(szBuffer), "%s\n %s (%i pcs):\n ", PLUGIN_NAME, szBuffer, hMenu.ItemCount);
			
				Panel panel = view_as<Panel>(iParam);
				panel.SetTitle(szBuffer);
			}
		}
		// User choose a szModel
		case MenuAction_Select: {
			static char szModel[256];
			if(!hMenu.GetItem(iParam, szModel, sizeof(szModel))) return 0;

			ApplyModel(iClient, szModel);
			g_hCustomModel.Set(iClient, szModel);

			hMenu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem: {
			if (g_bUseTranslation) {
				static char szBuffer[64], szDisplay[64];
				hMenu.GetItem(iParam, "", 0, _, szBuffer, sizeof(szBuffer), iClient);
				FormatEx(szDisplay, sizeof(szDisplay), "%T", szBuffer, iClient);
				return RedrawMenuItem(szDisplay);
			}
		}
		case MenuAction_Cancel: {
			if(iParam == MenuCancel_ExitBack) {
				if (!IsValidHandle(g_hMainMenu[iClient])) {
					g_hMainMenu[iClient] = BuildMainMenu(iClient);
				}
				g_hMainMenu[iClient].Display(iClient, MENU_TIME_FOREVER);
			}
			else if (iParam != MenuCancel_Disconnected) {
				ToggleView(iClient, false);
			}
		}
	}
	return 0;
}

stock void ToggleView(int iClient, bool bTPView) {
	if(IsValidClient(iClient) && IsPlayerAlive(iClient)) {
		if(bTPView) {
			// Player will see their ragdoll even if they are alive, so we need to delete the ragdoll
			int iRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
			if (IsValidEntity(iRagdoll)) {
				AcceptEntityInput(iRagdoll, "Kill");
			}

			SetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget", 0); 
			SetEntProp(iClient, Prop_Send, "m_iObserverMode", 1);
			SetEntProp(iClient, Prop_Send, "m_iFOV", 70);
		} else {
			SetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget", iClient);
			SetEntProp(iClient, Prop_Send, "m_iObserverMode", 0);
			char buffer[256];
			g_hFov.Get(iClient, buffer, sizeof(buffer));
			int iFov = StringToInt(buffer);
			SetEntProp(iClient, Prop_Send, "m_iFOV", iFov);
		}
	}
}

stock void ApplyFromCookie(int iClient) {
	static char szModel[256];
	g_hCustomModel.Get(iClient, szModel, sizeof(szModel));
	
	if(!szModel[0] || !IsModelPrecached(szModel)) {
		if (g_bForceSkin) {
			ApplyModel(iClient, g_szForcedSkins[GetRandomInt(0, g_nForcedSkins - 1)]);
		}
	} else {
		ApplyModel(iClient, szModel);
	}
	char buffer[256];
	g_hFov.Get(iClient, buffer, sizeof(buffer));
	int iFov = StringToInt(buffer);
	ApplyFov(iClient, iFov, false);
}

stock void ApplyModel(int iClient, const char[] szModel) {
	if(!szModel[0] || !IsModelPrecached(szModel)) return;

	SetEntityModel(iClient, szModel);
	SetEntityRenderColor(iClient);
	g_bSelectedSkin[iClient] = true;
}

stock void ApplyFov(int iClient, int iFov, bool bSet=true) {
	int m_iFov = GetEntProp(iClient, Prop_Send, "m_iFOV");
	if (m_iFov == 0) {
		m_iFov = GetEntProp(iClient, Prop_Send, "m_iDefaultFOV");
	}
	// float fLastFov = GetEntPropFloat(iClient, Prop_Send, "m_flFOVTime");
	// float fTemp;
	// if ((fTemp = (GetGameTime() - fLastFov) / 0.7) < 0.7) {
	// 	int iFovStart = GetEntProp(iClient, Prop_Send, "m_iFOVStart");
	// 	m_iFov = RoundToNearest((fTemp + 1.0) * float(iFovStart) - fTemp * float(m_iFov));
	// }
	SetEntProp(iClient, Prop_Send, "m_iFOVStart", m_iFov);
	SetEntPropFloat(iClient, Prop_Send, "m_flFOVTime", GetGameTime());
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFov);
	SetEntPropFloat(iClient, Prop_Send, "m_flFOVRate", 0.7);

	if (bSet) {
		char buffer[256];
		IntToString(iFov, buffer, sizeof(buffer));
		g_hFov.Set(iClient, buffer);
	}
}

Handle g_hScopeTimer[MAXPLAYERS + 1];

public void DetectScope(int iClient) {
	if (IsPlayerAlive(iClient)) {
		static int iWeapon;
		static bool bInIronSight;
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(iWeapon)) {
			bInIronSight = GetEntProp(iWeapon, Prop_Send, "m_bIsInIronsights") != 0;
		} else {
			bInIronSight = false;
		}
		if (bInIronSight && !g_bInScoped[iClient]) {
			g_bInScoped[iClient] = true;
		}
		else if (!bInIronSight && g_bInScoped[iClient]) {
			char buffer[256];
			g_hFov.Get(iClient, buffer, sizeof(buffer));
			int iFov = StringToInt(buffer);
			SetEntProp(iClient, Prop_Send, "m_iFOV", iFov, false);
			if (!IsValidHandle(g_hScopeTimer[iClient])) {
				g_hScopeTimer[iClient] = CreateTimer(0.7, TimerUnScoped, iClient, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public Action TimerUnScoped(Handle hTimer, any iClient) {
	if (IsValidClient(iClient) && IsPlayerAlive(iClient)) {
		g_bInScoped[iClient] = false;
	}

	return Plugin_Stop;
}

stock bool IsValidClient(int iClient) {
	return 0 < iClient <= MaxClients && IsClientInGame(iClient);
}