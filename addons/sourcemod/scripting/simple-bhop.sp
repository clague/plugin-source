#pragma semicolon 1

// ====[ INCLUDES ]============================================================
#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <globalvariables>

// ====[ DEFINES ]=============================================================
#define PLUGIN_VERSION	"1.0.0"

// ====[ CVARS | HANDLES ]=====================================================
ConVar cvarEnabled;
ConVar cvarFallDamage;
ConVar cvarInform;

Cookie g_hBHop;

// ====[ VARIABLES ]===========================================================
bool g_bInformed	[MAXPLAYERS + 1];
bool g_bHopping		[MAXPLAYERS + 1];

// ====[ PLUGIN ]==============================================================
public Plugin:myinfo = {
	name = "Simple Bunny Hop",
	author = "ReFlexPoison",
	description = "Let users Bunny Hop with simplicity",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
}

// ====[ FUNCTIONS ]===========================================================
public OnPluginStart() {
	CreateConVar("sm_bhop_version", PLUGIN_VERSION, "Simple Bunny Hop Version", FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);

	cvarEnabled	= CreateConVar("sm_bhop_enabled", "1", "Enable Simple Bunny Hop\n0 = Disabled\n1 = Enabled", _, true, 0.0, true, 1.0);

	cvarFallDamage = CreateConVar("sm_bhop_falldamage", "0", "Disable fall damage for bhoppers\n0 = Disabled\n1 = Enabled", _, true, 0.0, true, 1.0);

	cvarInform = CreateConVar("sm_bhop_inform", "1", "Enable information notification\n0 = Disabled\n1 = Enabled", _, true, 0.0, true, 1.0);

	HookEvent("player_spawn", OnPlayerSpawn);

	RegAdminCmd("sm_bhop", BHopCmd, 0, "Enable/Disable Bunny Hopping");
	RegAdminCmd("sm_auto", BHopCmd, 0, "Enable/Disable Bunny Hopping");

	g_hBHop = FindClientCookie("bhop");
	if (!IsValidHandle(g_hBHop)) {
		g_hBHop = RegClientCookie("bhop", "BHop Enable/Disable", CookieAccess_Public);
	}

	LoadTranslations("simple-bhop.phrases");

	AutoExecConfig(true, "plugin.simple-bhop");
}

// ====[ EVENTS ]==============================================================
public void OnClientConnected(iClient) {
	g_bHopping[iClient] = false;
	g_bInformed[iClient] = false;
}

public void OnClientPutInServer(int iClient) {
	if (cvarFallDamage.BoolValue) {
		SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnClientCookiesCached(int iClient) {
	g_bHopping[iClient] = g_hBHop.GetInt(iClient) >= 1;
}

public Action OnPlayerSpawn(Event hEvent, char[] szName, bool bDontBroadcast) {
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!IsValidClient(iClient) || !cvarEnabled.BoolValue)
		return Plugin_Continue;

	if(cvarInform.BoolValue && !g_bInformed[iClient] && CheckCommandAccess(iClient, "sm_bhop", 0)) {
		if (g_bHopping[iClient]) {
			CPrintToChat(iClient, 0, "%t", "InformBHopEnable");
		} else {
			CPrintToChat(iClient, 0, "%t", "InformBHopDisable");
		}
		g_bInformed[iClient] = true;
	}
	return Plugin_Continue;
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iType, int &iWeapon, float fForce[3], float fPosition[3], int iCustom) {
	if(!IsValidClient(iVictim) || !cvarFallDamage.BoolValue)
		return Plugin_Continue;

	if(g_bHopping[iVictim] && GetClientButtons(iVictim) & IN_JUMP && iType == DMG_FALL) {
		fDamage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAngles[3], int &iWeapon) {
	if(!cvarEnabled.BoolValue || !IsValidClient(iClient) || !g_bHopping[iClient])
		return Plugin_Continue;

	if(IsPlayerAlive(iClient) && !(GetEntityFlags(iClient) & FL_ONGROUND) && iButtons & IN_JUMP) {
		if (!(GetEntityMoveType(iClient) & MOVETYPE_LADDER)) {
			iButtons &= ~IN_JUMP;
		}	
	}
	return Plugin_Continue;
}

// ====[ COMMANDS ]============================================================
public Action BHopCmd(int iClient, int nArgs) {
	if(!cvarEnabled.BoolValue || !IsValidClient(iClient))
		return Plugin_Continue;
	if (AreClientCookiesCached(iClient)) {
		if(g_bHopping[iClient]) {
			g_bHopping[iClient] = false;
			CPrintToChat(iClient, 0, "%t", "DisableBHop");
			g_hBHop.SetInt(iClient, 0);
		} else {
			g_bHopping[iClient] = true;
			CPrintToChat(iClient, 0, "%t", "EnableBHop");
			g_hBHop.SetInt(iClient, 1);
		}
	}
	else {
		CPrintToChat(iClient, 0, "%t", "NotAuthorized");
	}
	
	return Plugin_Handled;
}

// ====[ STOCKS ]==============================================================
stock bool IsValidClient(int iClient, bool bReplay=false) {
	if(iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;
	if(bReplay && (IsClientSourceTV(iClient) || IsClientReplay(iClient)))
		return false;
	return true;
}