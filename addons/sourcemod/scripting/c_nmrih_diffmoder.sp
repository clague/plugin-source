#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sdkhooks>
#include <colorvariables>

enum GameMod{
	GameModDefault,
	GameModRunner,
	GameModKid
};

ConVar sv_max_runner_chance,
	ov_runner_chance,
	ov_runner_kid_chance,
	g_cfg_diffmoder,
	g_cfg_gamemode,
	g_cfg_gamemode_default;

bool g_enable;
bool g_configged = false;
float g_max_runner_chance_default,
	g_runner_chance_default,
	g_runner_kid_chance_default;

GameMod g_game_mode = GameModDefault;

public Plugin myinfo =
{
	name		= "[NMRiH] Difficult Moder",
	author		= "Mostten",
	description	= "Allow player to enable the change difficult and mode by ballot.",
	version		= "1.0.3",
	url			= "https://forums.alliedmods.net/showthread.php?t=301322"
}

public void OnPluginStart()
{
	//LoadTranslations("nmrih.diffmoder.phrases");
	(sv_max_runner_chance = FindConVar("sv_max_runner_chance")).AddChangeHook(OnConVarChange);
	(ov_runner_chance = FindConVar("ov_runner_chance")).AddChangeHook(OnConVarChange);
	(ov_runner_kid_chance = FindConVar("ov_runner_kid_chance")).AddChangeHook(OnConVarChange);
	
	(g_cfg_diffmoder = CreateConVar("nmrih_diffmoder", "1", "Enable/Disable plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
	g_enable = g_cfg_diffmoder.BoolValue;
	(g_cfg_gamemode_default = CreateConVar("nmrih_diffmoder_gamemode_default", "1", "0 - default gamemode, 1 - All runners, 2 - All kids", 0, true, 0.0, true, 2.0)).AddChangeHook(OnConVarChange);
	(g_cfg_gamemode = CreateConVar("nmrih_diffmoder_gamemode", "1", "0 - default gamemode, 1 - All runners, 2 - All kids", 0, true, 0.0, true, 2.0)).AddChangeHook(OnConVarChange);

	g_game_mode = view_as<GameMod>(g_cfg_gamemode.IntValue);

	AutoExecConfig();
	
	//Reg Cmd
	//RegConsoleCmd("sm_dif", Cmd_MenuTop);
	//RegConsoleCmd("sm_difshow", Cmd_InfoShow);
}

public void OnConfigsExecuted()
{
	g_max_runner_chance_default = sv_max_runner_chance.FloatValue;
	g_runner_chance_default = ov_runner_chance.FloatValue;
	g_runner_kid_chance_default = ov_runner_kid_chance.FloatValue;
	g_configged = true;

	g_cfg_gamemode.FloatValue = g_cfg_gamemode_default.FloatValue;
	GameModeInit();
}

public void OnMapStart()
{
	g_configged = false;
}

public void OnConVarChange(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	if (!g_configged) return;
	if(CVar == sv_max_runner_chance) {
		GameModeEnable(g_game_mode);
	}
	else if(CVar == ov_runner_chance) {
		GameModeEnable(g_game_mode);
	}
	else if(CVar == ov_runner_kid_chance) {
		GameModeEnable(g_game_mode);
	}
	else if(CVar == g_cfg_diffmoder)
	{
		g_enable = StringToInt(newValue) > 0;
	}
	else if(CVar == g_cfg_gamemode)
	{
		g_game_mode = view_as<GameMod>(g_cfg_gamemode.IntValue);
		GameModeEnable(g_game_mode);
		GameShamblerConvertToRunner(g_game_mode);
	}
}

public void OnPluginEnd()
{
	GameModeInit();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!g_enable) return;

	if((entity > MaxClients) && IsValidEntity(entity)
	&& StrEqual(classname, "npc_nmrih_shamblerzombie", false))
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCBZombieSpawnPost);
}

public void OnEntityDestroyed(int entity)
{
	if(g_enable && IsValidShamblerZombie(entity)) SDKUnhook(entity, SDKHook_SpawnPost, SDKHookCBZombieSpawnPost);
}

bool IsValidShamblerZombie(int zombie)
{
	if((zombie <= MaxClients) || !IsValidEntity(zombie)) return false;

	char classname[32];
	GetEntityClassname(zombie, classname, sizeof(classname));
	return StrEqual(classname, "npc_nmrih_shamblerzombie", false);
}

public void SDKHookCBZombieSpawnPost(int zombie)
{
	if(!g_enable || !IsValidEntity(zombie) || !IsValidShamblerZombie(zombie))
		SDKUnhook(zombie, SDKHook_SpawnPost, SDKHookCBZombieSpawnPost);

	float orgin[3];
	GetEntPropVector(zombie, Prop_Send, "m_vecOrigin", orgin);
	switch(g_game_mode)
	{
		case GameModRunner:	ShamblerToRunnerFromPosion(zombie, orgin);
		case GameModKid:	ShamblerToRunnerFromPosion(zombie, orgin, true);
	}
	SDKUnhook(zombie, SDKHook_SpawnPost, SDKHookCBZombieSpawnPost);
}

int ShamblerToRunnerFromPosion(int shambler, float[3] pos, bool isKid = false)
{
	AcceptEntityInput(shambler, "kill");
	RemoveEdict(shambler);
	return FastZombieCreate(pos, isKid);
}

int FastZombieCreate(float orgin[3], bool isKid = false)
{
	int zombie = -1;
	if (isKid || GetRandomInt(0, 100) < 100 * ov_runner_kid_chance.FloatValue)
		zombie = CreateEntityByName("npc_nmrih_kidzombie");
	else
		zombie = CreateEntityByName("npc_nmrih_runnerzombie");
	if(!IsValidEntity(zombie)) return -1;

	if(DispatchSpawn(zombie)) TeleportEntity(zombie, orgin, NULL_VECTOR, NULL_VECTOR);

	return zombie;
}

void GameShamblerConvertToRunner(const GameMod mode)
{
	int MaxEnt = GetMaxEntities();
	for(int zombie = MaxClients + 1; zombie <= MaxEnt; zombie++)
	{
		if(!IsValidShamblerZombie(zombie)) continue;

		float orgin[3];
		GetEntPropVector(zombie, Prop_Send, "m_vecOrigin", orgin);
		switch(mode)
		{
			case GameModRunner:	ShamblerToRunnerFromPosion(zombie, orgin);
			case GameModKid:	ShamblerToRunnerFromPosion(zombie, orgin, true);
		}
	}
}

void GameModeEnable(GameMod mode)
{
	g_game_mode = mode;
	switch(mode)
	{
		case GameModRunner:
		{
			sv_max_runner_chance.FloatValue = ov_runner_chance.FloatValue = 3.0;
			ov_runner_kid_chance.FloatValue = g_runner_kid_chance_default;
		}
		case GameModKid:
		{
			ov_runner_kid_chance.FloatValue = 1.0;
		}
		case GameModDefault:
		{
			sv_max_runner_chance.FloatValue = g_max_runner_chance_default;
			ov_runner_chance.FloatValue = g_runner_chance_default;
			ov_runner_kid_chance.FloatValue = g_runner_kid_chance_default;
		}
	}
}

void GameModeInit()
{
	GameModeEnable(view_as<GameMod>(g_cfg_gamemode_default.IntValue));
}

// bool IsValidClient(int client)
// {
// 	return 0 < client <= MaxClients && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client) && !IsClientSourceTV(client);
// }

// void GameInfoShowToClient(const int client)
// {
// 	PrintToChat(client, "\x04%T \x01%T \x04%T \x01%T\n\x04%T \x01%T \x04%T \x01%T\n\x04%T \x01%T",
// 		"ModFlag", client,		sModItem[view_as<int>(GameGetMod())], client,
// 		"DifFlag", client,		sDifItem[view_as<int>(GameGetDif())], client,
// 		"RealismFlag", client,	sv_realism.BoolValue ? "On" : "Off", client,
// 		"HardcoreFlag", client,	sv_hardcore_survival.BoolValue ? "On" : "Off", client,
// 		"FriendlyFlag", client,	mp_friendlyfire.BoolValue ? "On" : "Off", client);
// }
