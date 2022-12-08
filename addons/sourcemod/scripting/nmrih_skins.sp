// Based on the code of the plugin "SM Skinchooser HL2DM" v2.3 by Andi67
#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <clientprefs>
#include <globalvariables>

#define PLUGIN_NAME	"[NMRiH] Skins"
#define PLUGIN_VERSION	"1.0.0c"
// Paths to configuration files
#define SKINS_DOWNLOADS	"configs/nmrih_skins/downloads_list.ini"
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
int g_nForcedSkins,
	g_nTotalSkins;
char g_szForcedSkins[MAX_FORCEDSKINS][PLATFORM_MAX_PATH];

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
	FileToKeyValues(g_hMenuKv, szFile);
	if(!KvGotoFirstSubKey(g_hMenuKv)) return;
	do {
		KvJumpToKey(g_hMenuKv, "List");
		KvGotoFirstSubKey(g_hMenuKv);
		do {
			KvGetString(g_hMenuKv, "path", szPath, sizeof(szPath), "");
			if(PrecacheModel(szPath, true)) {
				g_nTotalSkins++;
			}
		}
		while(KvGotoNextKey(g_hMenuKv));
		KvGoBack(g_hMenuKv);
		KvGoBack(g_hMenuKv);
	}
	while(KvGotoNextKey(g_hMenuKv));
	KvRewind(g_hMenuKv);

	ReadDownloads();
	LogMessage("Total: %i	Forced: %i", g_nTotalSkins, g_nForcedSkins);
}

stock void LoadForcedSkins() {
	static char szBuffer[PLATFORM_MAX_PATH], szFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szFile, PLATFORM_MAX_PATH, FORCED_SKINS);

	//open precache szFile and add everything to download table
	Handle hFile = OpenFile(szFile, "r");
	while(ReadFileLine(hFile, szBuffer, sizeof(szBuffer))) {
		// Strip leading and trailing whitespace
		TrimString(szBuffer);

		// Skip non existing files(and Comments)
		if(FileExists(szBuffer, true)) {
			// Tell Clients to download files
			AddFileToDownloadsTable(szBuffer);
			// Tell Clients to cache szModel
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
	char szFile[256];
	BuildPath(Path_SM, szFile, 255, SKINS_DOWNLOADS);
	Handle hFile = OpenFile(szFile, "r");
	if(hFile == null) return;

	char szBuffer[256];
	int len;
	while(ReadFileLine(hFile, szBuffer, sizeof(szBuffer))) {
		if (StrContains(szBuffer, "//") == 0) {
			szBuffer[0] = 0;
		}
		len = strlen(szBuffer);
		if(len > 0 && szBuffer[len-1] == '\n') szBuffer[--len] = '\0';

		TrimString(szBuffer);

		if(szBuffer[0]) ReadFileFolder(szBuffer);

		if(IsEndOfFile(hFile)) break;
	}
	if(IsValidHandle(hFile)) CloseHandle(hFile);
}

stock void ReadFileFolder(char[] szPath) {
	static Handle dirh;
	static char szBuffer[256], tmp_path[256];
	static FileType type = FileType_Unknown;
	static int len;

	len = strlen(szPath);
	if(szPath[len-1] == '\n') {
		szPath[--len] = '\0';
	}

	TrimString(szPath);

	if(DirExists(szPath, true)) {
		dirh = OpenDirectory(szPath, true);
		while(ReadDirEntry(dirh, szBuffer, sizeof(szBuffer), type)) {
			len = strlen(szBuffer);
			if(szBuffer[len-1] == '\n') szBuffer[--len] = '\0';

			TrimString(szBuffer);

			if(!StrEqual(szBuffer, "", false) && !StrEqual(szBuffer, ".", false) && !StrEqual(szBuffer, "..", false)) {
				strcopy(tmp_path, 255, szPath);
				StrCat(tmp_path, 255, "/");
				StrCat(tmp_path, 255, szBuffer);
				if(type == FileType_File) ReadItem(tmp_path);
			}
		}
	} else {
		ReadItem(szPath);
	}
	if(IsValidHandle(dirh)) CloseHandle(dirh);
}

stock void ReadItem(char[] szBuffer) {
	int len = strlen(szBuffer);
	if(szBuffer[len-1] == '\n') szBuffer[--len] = '\0';

	TrimString(szBuffer);

	if(len >= 2 && szBuffer[0] == '/' && szBuffer[1] == '/') {
		ReplaceString(szBuffer, 255, "//", "");
	}
	else if(szBuffer[0] && FileExists(szBuffer, true)) {
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
}

public void OnClientConnected(int iClient) {
	g_bSelectedSkin[iClient] = false;
	g_bCookieLate[iClient] = false;
}

public void OnClientCookiesCached(int iClient) {
	if (g_bCookieLate[iClient]) {
		if (!g_bSelectedSkin[iClient]) {
			char szModel[PLATFORM_MAX_PATH];
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
		g_bCookieLate[iClient] = false;
	}
}

public void OnClientDisconnect_Post(int iClient) {
	if (IsValidHandle(g_hMainMenu[iClient])) {
		delete g_hMainMenu[iClient];
	}
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
			float fFov;
			if (GetCmdArgFloatEx(1, fFov)) {
				ApplyFov(iClient, RoundToNearest(fFov));
			} else {
				if (g_bUseTranslation) {
					CPrintToChat(iClient, 0, "{green}%t {white}%t", "ChatPrefix", "CurrentFov", GetEntProp(iClient, Prop_Send, "m_iFOV"), g_hFov.GetInt(iClient));
				} else {
					CPrintToChat(iClient, 0, "{green}[系统] {white}当前的{green}FOV{white}值：{orange}%d{white}，当前设置的{green}FOV{white}值：{red}%d{white}\n（死亡视角下两者不同是正常的）",
						GetEntProp(iClient, Prop_Send, "m_iFOV"), g_hFov.GetInt(iClient));
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
				CPrintToChat(iClient, 0, "{red}%t {white}%t", "ChatPrefix", "FovCustomHint");
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

stock Menu BuildMainMenu(int iClient) {
	KvRewind(g_hMenuKv);
	if(!KvGotoFirstSubKey(g_hMenuKv)) return null;

	Menu hMenu = CreateMenu(Menu_Main, MENU_ACTIONS_ALL);

	static char szBuffer[30];
	static AdminId iAdmin;
	if(g_bAdminGroup) {
		iAdmin = GetUserAdmin(iClient);
	}
	do {
		KvGetSectionName(g_hMenuKv, szBuffer, sizeof(szBuffer));
		if(g_bAdminGroup) {
			static int iCount;
			static GroupId iGroup;
			static char szGroup[30];
			// check if they have access
			KvGetString(g_hMenuKv, "Admin", szGroup, sizeof(szGroup));
			iGroup = FindAdmGroup(szGroup);
			if (!szGroup[0] || iGroup == INVALID_GROUP_ID) {
				hMenu.AddItem(szBuffer, szBuffer);
			}
			else {
				iCount= GetAdminGroupCount(iAdmin);
				for(int i = 0; i < iCount; i++) {
					if(iGroup == GetAdminGroup(iAdmin, i, "", 0)) {
						// Get the model group name and add it to the menu
						hMenu.AddItem(szBuffer, szBuffer);
						break;
					}
				}
			}
		}
		else {
			hMenu.AddItem(szBuffer, szBuffer);
		}
	}
	while(KvGotoNextKey(g_hMenuKv));
	KvRewind(g_hMenuKv);

	hMenu.AddItem("none", "None");
	hMenu.SetTitle("%s (%i categories):", PLUGIN_NAME, hMenu.ItemCount);

	return hMenu;
}

public int Menu_Main(Menu hMenu, MenuAction iAction, int iClient, int iParam) {
	switch(iAction) {
		case MenuAction_Display: {
			ToggleView(iClient, true);

			if (g_bUseTranslation) {
				char szBuffer[64];
				FormatEx(szBuffer, sizeof(szBuffer), "%s %T:", PLUGIN_NAME, "MainMenuTitleEx", iClient, hMenu.ItemCount);
			
				Panel panel = view_as<Panel>(iParam);
				panel.SetTitle(szBuffer);
			}
		}
		// User has selected a model group
		case MenuAction_Select: {
			char szInfo[32];

			if(!hMenu.GetItem(iParam, szInfo, sizeof(szInfo))) return 0;

			// Check if the user decide to coming back to the original model
			if(StrEqual(szInfo, "none")) {
				g_hCustomModel.Set(iClient, "");

				char szModel[PLATFORM_MAX_PATH];
				g_hOriginalModel.Get(iClient, szModel, sizeof(szModel));
				ApplyModel(iClient, szModel);

				g_hMainMenu[iClient].DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
				return 0;
			}

			// Create the model menu
			if (!IsValidHandle(g_hModelMenu[iParam])) {
				g_hModelMenu[iParam] = BuildModelMenu(szInfo);
			}
			g_hModelMenu[iParam].Display(iClient, MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem: {
			if (g_bUseTranslation) {
				char szBuffer[64], szDisplay[64];
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
	int nItems;
	char szBuffer[30], szPath[256];
	nItems = 0;

	KvRewind(g_hMenuKv);
	KvJumpToKey(g_hMenuKv, szInfo);
	KvJumpToKey(g_hMenuKv, "List");
	KvGotoFirstSubKey(g_hMenuKv);
	do {
		// Add the model to the menu
		KvGetSectionName(g_hMenuKv, szBuffer, sizeof(szBuffer));
		KvGetString(g_hMenuKv, "path", szPath, sizeof(szPath), "");
		hModelMenu.AddItem(szPath, szBuffer);
		nItems++;
	}
	while(KvGotoNextKey(g_hMenuKv));
	// Rewind the KVs
	KvRewind(g_hMenuKv);
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

			if (g_bUseTranslation) {
				char szBuffer[64];
				hMenu.GetTitle(szBuffer, sizeof(szBuffer));
				Format(szBuffer, sizeof(szBuffer), "%s\n %T %T:", PLUGIN_NAME, szBuffer, iClient, "ModelMenuTitleEx", iClient, hMenu.ItemCount);
			
				Panel panel = view_as<Panel>(iParam);
				panel.SetTitle(szBuffer);
			}
			else {
				char szBuffer[64];
				hMenu.GetTitle(szBuffer, sizeof(szBuffer));
				Format(szBuffer, sizeof(szBuffer), "%s\n %s (%i pcs):\n ", PLUGIN_NAME, szBuffer, hMenu.ItemCount);
			
				Panel panel = view_as<Panel>(iParam);
				panel.SetTitle(szBuffer);
			}
		}
		// User choose a szModel
		case MenuAction_Select: {
			char szModel[256];
			if(!hMenu.GetItem(iParam, szModel, sizeof(szModel))) return 0;

			ApplyModel(iClient, szModel);
			g_hCustomModel.Set(iClient, szModel);

			hMenu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem: {
			if (g_bUseTranslation) {
				char szBuffer[64], szDisplay[64];
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
			SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 0);
			SetEntProp(iClient, Prop_Send, "m_iFOV", 70);
		} else {
			SetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget", iClient);
			SetEntProp(iClient, Prop_Send, "m_iObserverMode", 0);
			SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 1);

			SetEntProp(iClient, Prop_Send, "m_iFOV", g_hFov.GetInt(iClient));
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

	ApplyFov(iClient, g_hFov.GetInt(iClient));
}

stock void ApplyModel(int iClient, const char[] szModel) {
	if(!szModel[0] || !IsModelPrecached(szModel)) return;

	SetEntityModel(iClient, szModel);
	SetEntityRenderColor(iClient);
	g_bSelectedSkin[iClient] = true;
}

stock void ApplyFov(int iClient, int iFov) {
	if (iFov == 0) {
		// No animation
		SetEntProp(iClient, Prop_Send, "m_iFOV", iFov);
		g_hFov.SetInt(iClient, iFov);
		return;
	}

	int m_iFov = GetEntProp(iClient, Prop_Send, "m_iFOV");
	if (m_iFov == 0) {
		m_iFov = DEFAULT_FOV;
	}
	SetEntProp(iClient, Prop_Send, "m_iFOVStart", m_iFov);
	SetEntPropFloat(iClient, Prop_Send, "m_flFOVTime", GetGameTime());
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFov);
	SetEntPropFloat(iClient, Prop_Send, "m_flFOVRate", 0.7);

	g_hFov.SetInt(iClient, iFov);
}

stock bool IsValidClient(int iClient) {
	return 0 < iClient <= MaxClients && IsClientInGame(iClient);
}