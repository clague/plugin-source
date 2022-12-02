#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <globalvariables>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define DIRECTION_COUNT 26

public Plugin myinfo = {
    name = "Anti-Stuck",
    author = "clagura",
    description = "Unstuck stucker",
    version = PLUGIN_VERSION
};

int		g_iCounter[MAXPLAYERS + 1];
int		g_iStuckStatus[MAXPLAYERS + 1];
int		g_aLooseDist[MAXPLAYERS + 1][DIRECTION_COUNT];
float 	g_fTime[MAXPLAYERS + 1];
float 	g_fOriginalPos[MAXPLAYERS + 1][3];
float 	g_fOriginalVel[MAXPLAYERS + 1][3];

ConVar	sm_stuck_limit;
ConVar	sm_stuck_countdown;
ConVar	sm_stuck_radius;
ConVar	sm_stuck_step;
ConVar	sm_stuck_max_steps;
ConVar	sm_stuck_roundtime;
ConVar	sm_stuck_spawncheck;
Handle	g_hDelayTimer[MAXPLAYERS + 1];
Handle	g_hRoundTimer = null;

enum Direction {
	Forward,
	Back,
	Left,
	Right,
	Up,
	Down,
	ForwardLeft,
	ForwardRight,
	ForwardUp,
	ForwardDown,
	BackLeft,
	BackRight,
	BackUp,
	BackDown,
	LeftUp,
	LeftDown,
	RightUp,
	RightDown,
	ForwardLeftUp,
	ForwardLeftDown,
	ForwardRightUp,
	ForwardRightDown,
	BackLeftUp,
	BackLeftDown,
	BackRightUp,
	BackRightDown,
}

stock void GetDirectionVec(Direction dir, float vecDir[3]) {
	switch(dir) {
		case Forward: 
			vecDir = {1.0, 0.0, 0.0};
		case Back: 
			vecDir = {-1.0, 0.0, 0.0};
		case Left: 
			vecDir = {0.0, 1.0, 0.0};
		case Right: 
			vecDir = {0.0, -1.0, 0.0};
		case Up: 
			vecDir = {0.0, 0.0, 1.0};
		case Down: 
			vecDir = {0.0, 0.0, -1.0};
		case ForwardLeft: 
			vecDir = {1.0, 1.0, 0.0};
		case ForwardRight: 
			vecDir = {1.0, -1.0, 0.0};
		case ForwardUp: 
			vecDir = {1.0, 0.0, 1.0};
		case ForwardDown: 
			vecDir = {1.0, 0.0, -1.0};
		case BackLeft: 
			vecDir = {-1.0, 1.0, 0.0};
		case BackRight: 
			vecDir = {-1.0, -1.0, 0.0};
		case BackUp: 
			vecDir = {-1.0, 0.0, 1.0};
		case BackDown: 
			vecDir = {-1.0, 0.0, -1.0};
		case LeftUp: 
			vecDir = {0.0, 1.0, 1.0};
		case LeftDown: 
			vecDir = {0.0, 1.0, -1.0};
		case RightUp: 
			vecDir = {0.0, 0.0, 1.0};
		case RightDown: 
			vecDir = {0.0, 0.0, -1.0};
		case ForwardLeftUp: 
			vecDir = {1.0, 1.0, 1.0};
		case ForwardLeftDown: 
			vecDir = {1.0, 1.0, -1.0};
		case ForwardRightUp: 
			vecDir = {1.0, -1.0, 1.0};
		case ForwardRightDown: 
			vecDir = {1.0, -1.0, -1.0};
		case BackLeftUp: 
			vecDir = {-1.0, 1.0, 1.0};
		case BackLeftDown: 
			vecDir = {-1.0, 1.0, -1.0};
		case BackRightUp: 
			vecDir = {-1.0, -1.0, 1.0};
		case BackRightDown: 
			vecDir = {-1.0, -1.0, -1.0};
	}
}

public void OnPluginStart() {
	LoadTranslations("stuck.phrases");

	CreateConVar("sm_stuck_version", PLUGIN_VERSION, "Stuck version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	sm_stuck_limit		= CreateConVar("sm_stuck_limit", 		"3", 	"How many times command can be used before cooldown (0 = no limit)", _, true, 0.0);
	sm_stuck_countdown	= CreateConVar("sm_stuck_countdown",	"30", 	"How long the command cooldown is in seconds", _, true, 0.0, true, 1000.0);
	sm_stuck_radius		= CreateConVar("sm_stuck_radius", 		"32", 	"Initial radius size to fix player position", _, true, 0.0);
	sm_stuck_step		= CreateConVar("sm_stuck_step", 		"0.3", 	"Step (multiply the radius) between each position tested", _, true, 0.0);
	sm_stuck_max_steps	= CreateConVar("sm_stuck_max_steps", 	"7.0", 	"Maxium of the steps count", _, true, 0.0);
	sm_stuck_roundtime	= CreateConVar("sm_stuck_roundtime",	"0", 	"How long after the round starts can players use !stuck (0 to disable)", _, true, 0.0, false, _);
	sm_stuck_spawncheck	= CreateConVar("sm_stuck_spawncheck",	"0", 	"Check if players are stuck after they spawn (1 to enable, 0 to disable)", _, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_jk", StuckCmd, "Are you stuck ?");
	RegConsoleCmd("sm_k", StuckCmd, "Are you stuck ?");
	RegConsoleCmd("sm_unstuck", StuckCmd, "Are you stuck ?");
	RegConsoleCmd("sm_stuck", StuckCmd, "Are you stuck ?");

	RegAdminCmd("sm_testray", TestRay, ADMFLAG_GENERIC);
	
	HookEvent("round_start",Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end",Event_RoundEnd, EventHookMode_PostNoCopy);
	
	if(!HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Post)) {
		SetFailState("Hook event \"player_spawn\" failed");
		return;
	}
	
	AutoExecConfig(true, "antistuck");
}

public Action TestRay(int iClient, any args) {
	float vecOrigin[3];
	GetClientEyePosition(iClient, vecOrigin);

	DataPack data = new DataPack();
	data.WriteCell(iClient);
	data.WriteFloatArray(vecOrigin, 3);
	CreateTimer(1.0, TimerTestRay, data, TIMER_DATA_HNDL_CLOSE);

	float vecDir1[3], vecDir2[3];
	GetDirectionVec(view_as<Direction>(26), vecDir1);

	PrintToChat(iClient, "26 view_as direction is %f %f %f", vecDir2[0], vecDir2[1], vecDir2[2]);
	PrintToChat(iClient, "Forward == 26 view_as direction: %d, Forward == 0: %d", Forward==view_as<Direction>(26), Forward==view_as<Direction>(0));

	GetDirectionVec(view_as<Direction>(GetRandomInt(26, 100)), vecDir1);
	PrintToChat(iClient, "random 26~100 is %f %f %f", vecDir1[0], vecDir1[1], vecDir1[2]);
	return Plugin_Stop;
}
public Action TimerTestRay(Handle hTimer, DataPack data) {
	int iClient;
	float vecOrigin[3], vecEnd[3], vecHit[3];

	data.Reset();
	iClient = data.ReadCell();
	data.ReadFloatArray(vecOrigin, 3);

	GetClientEyePosition(iClient, vecEnd);

	TR_TraceRayFilter(vecOrigin, vecEnd, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, TraceEntitiesAndWorld);
	TR_GetEndPosition(vecHit);
	PrintToChat(iClient, "Start pos: %f %f %f, end pos: %f %f %f", vecOrigin[0], vecOrigin[1], vecOrigin[2], vecEnd[0], vecEnd[1], vecEnd[2]);
	PrintToChat(iClient, "hit: %d, hit position: %f %f %f", TR_DidHit(), vecHit[0], vecHit[1], vecHit[2]); 
	PrintToChat(iClient, "start solid: %d, all solid: %d", TR_StartSolid(), TR_AllSolid());
	PrintToChat(iClient, "start ouside world: %d, end outside world: %d", TR_PointOutsideWorld(vecOrigin), TR_PointOutsideWorld(vecEnd));
	PrintToChat(iClient, "fraction: %f, left solid fraction: %f", TR_GetFraction(), TR_GetFractionLeftSolid());

	return Plugin_Stop;
}

public void OnMapStart() {
	for(int i = 1; i <= MaxClients; i++) {
		g_iCounter[i] = 0;
		g_iStuckStatus[i] = -1;
		g_fTime[i] = GetGameTime();
	}
}

public void OnMapEnd() {
	for (int i = 1; i <= MaxClients; i++) {
		if (g_hDelayTimer[i] != null) {
			delete g_hDelayTimer[i];
		}
	}
}

public void Event_PlayerSpawn(Event e, const char[] szName, bool bDontBroadcast) {
	int iClient = e.GetInt("userid");

	if (sm_stuck_spawncheck.BoolValue) {
		if (IsValidHandle(g_hDelayTimer[iClient])) {
			delete g_hDelayTimer[iClient];
		}
		g_hDelayTimer[iClient] = CreateTimer(GetRandomFloat(0.5, 3.0), TimerDelayDetect, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Event_RoundStart(Event e, const char[] szName, bool bDontBroadcast) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidHandle(g_hDelayTimer[i])) {
			delete g_hDelayTimer[i];
		}
	}
	if (sm_stuck_roundtime.FloatValue >= 1.0) {
		if (IsValidHandle(g_hRoundTimer)) {
			delete g_hRoundTimer;
		}
		g_hRoundTimer = CreateTimer(sm_stuck_roundtime.FloatValue, TimerRoundWait, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event e, const char[] szName, bool bDontBroadcast) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidHandle(g_hDelayTimer[i])) {
			delete g_hDelayTimer[i];
		}
	}
	return Plugin_Continue;
}

public Action TimerRoundWait(Handle hTimer) {
	g_hRoundTimer = null;
	return Plugin_Stop;
}

public void OnClientPutInServer(int iClient) {
	g_iCounter[iClient] = 0;
	g_iStuckStatus[iClient] = -1;
	g_fTime[iClient] = 0.0;
}

public void OnClientDisconnect(int iClient) {
	g_iStuckStatus[iClient] = -1;
	if (g_hDelayTimer[iClient] != null) {
		delete g_hDelayTimer[iClient];
	}
}

stock bool IsValidClient(int iClient) {
	return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient));
}

public Action StuckCmd(int iClient, any args) {
	if(!IsValidClient(iClient)) {
		return Plugin_Stop;
	}
	
	if(!IsPlayerAlive(iClient)) {
		CPrintToChat(iClient, 0, "{green}%t {white}%t", "Prefix", "MustAlive");
		return Plugin_Stop;
	}

	if (g_iStuckStatus[iClient] != -1 || g_hDelayTimer[iClient] != null ) {
		CPrintToChat(iClient, 0, "{green}%t {white}%t", "Prefix", "InProgress", g_iStuckStatus[iClient]);
		return Plugin_Stop;
	}
	
	//Check if g_iCounter is enabled
	if (sm_stuck_limit.IntValue > 0) {
		//If g_iCounter is more than 0
		if(g_iCounter[iClient] > 0) {
			//If cooldown has past, reset the g_iCounter
			if(g_fTime[iClient] < GetGameTime()) {
				g_iCounter[iClient] = 0;
			}
		}
		
		//First g_iCounter set the delay to current time + delay
		if (g_iCounter[iClient] == 0) {
			g_fTime[iClient] = GetGameTime() + sm_stuck_countdown.FloatValue;
		}
		
		//Player g_iCounter is over the limit, block command
		if (g_iCounter[iClient] >= sm_stuck_limit.IntValue) {
			CPrintToChat(iClient, 0, "{green}%t {white}%t", "Prefix", "WaitFor", RoundFloat(g_fTime[iClient] - GetGameTime()));
			return Plugin_Stop;
		}
		
		//g_iCounter not yet reached limit, add to g_iCounter
		g_iCounter[iClient]++;
	}

	StartStuckDetection(iClient);

	return Plugin_Continue;
}


public Action TimerDelayDetect(Handle hTimer, any iClient) {
	g_hDelayTimer[iClient] = null;
	StartStuckDetection(iClient);

	return Plugin_Stop;
}

stock void StartStuckDetection(int iClient) {
	g_iStuckStatus[iClient] = 0;

	//Save original position & velocity
	GetClientAbsOrigin(iClient, g_fOriginalPos[iClient]);
	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", g_fOriginalVel[iClient]);
	
	//Disable player controls to prevent abuse / exploits
	int flags = GetEntityFlags(iClient) | FL_ATCONTROLS;
	SetEntityFlags(iClient, flags);
	
	CheckIfPlayerCanMove(iClient, 0);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									More Stuck Detection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

stock void GetVeloFromTestID(int iTestID, float[] vecVelo) {
	switch (iTestID) {
		case 0: {
			vecVelo[0] = 500.0;
			vecVelo[1] = 0.0;
			vecVelo[2] = 0.0;
		}
		case 1: {
			vecVelo[0] = -500.0;
			vecVelo[1] = 0.0;
			vecVelo[2] = 0.0;
		}
		case 2: {
			vecVelo[0] = 0.0;
			vecVelo[1] = 500.0;
			vecVelo[2] = 0.0;
		}
		case 3: {
			vecVelo[0] = 0.0;
			vecVelo[1] = -500.0;
			vecVelo[2] = 0.0;
		}
		case 4: {
			vecVelo[0] = 0.0;
			vecVelo[1] = 0.0;
			vecVelo[2] = 500.0;
		}
		case 5: {
			vecVelo[0] = 0.0;
			vecVelo[1] = 0.0;
			vecVelo[2] = -500.0;
		}
	}
}

stock void CheckIfPlayerCanMove(int iClient, int iTestID, int iTestCount = 0, float fStep=1.0, bool bInFix=false, Direction currentDir=Forward) {
	// In few case there are issues with IsPlayerStuck() like clip
	float vecVelo[3];
	float vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetVeloFromTestID(iTestID, vecVelo);
	
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", vecVelo);
	
	DataPack hTimerDataPack;
	CreateDataTimer(0.02, TimerCheckMovePost, hTimerDataPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
	hTimerDataPack.WriteCell(iClient);
	hTimerDataPack.WriteCell(iTestID);
	hTimerDataPack.WriteCell(iTestCount);
	hTimerDataPack.WriteFloat(vecOrigin[0]);
	hTimerDataPack.WriteFloat(vecOrigin[1]);
	hTimerDataPack.WriteFloat(vecOrigin[2]);
	hTimerDataPack.WriteCell(bInFix);
	hTimerDataPack.WriteCell(currentDir);
	hTimerDataPack.WriteFloat(fStep);
}

public Action TimerCheckMovePost(Handle hTimer, DataPack data) {
	float vecOrigin[3], vecOriginAfter[3], fStep;
	bool bInfix;
	Direction currentDir;
	
	data.Reset();
	int iClient		= data.ReadCell();
	int iTestID		= data.ReadCell();
	int iTestCount	= data.ReadCell();
	vecOrigin[0]	= data.ReadFloat();
	vecOrigin[1]	= data.ReadFloat();
	vecOrigin[2]	= data.ReadFloat();
	bInfix			= data.ReadCell();
	currentDir		= data.ReadCell();
	fStep			= data.ReadFloat();

	GetClientAbsOrigin(iClient, vecOriginAfter);
	
	if(GetVectorDistance(vecOrigin, vecOriginAfter, false) < 5.0) { // Can't move 
		iTestCount += 1;
		iTestID = (iTestID + 1) % 6;
		if(iTestCount < 6) {
			CheckIfPlayerCanMove(iClient, iTestID, iTestCount, fStep, bInfix, currentDir);
		} else if (fStep <= sm_stuck_max_steps.FloatValue){
			g_iStuckStatus[iClient]++;
			if (bInfix) {
				TeleportEntity(iClient, g_fOriginalPos[iClient]);
				//Continue where we left off
				TryFixPosition(iClient, sm_stuck_radius.FloatValue, fStep, false, view_as<Direction>((view_as<int>(currentDir)+1)%DIRECTION_COUNT));
			}
			else {
				TryFixPosition(iClient, sm_stuck_radius.FloatValue, fStep);
			}
		}
		else {
			CPrintToChat(iClient, 0, "{green}%t {white}%t", "Prefix", "NeedHelp");
			TeleportEntity(iClient, g_fOriginalPos[iClient], NULL_VECTOR, g_fOriginalVel[iClient]); //Reset to original pos / velocity

			//Enable controls
			int flags = GetEntityFlags(iClient) & ~FL_ATCONTROLS;
			SetEntityFlags(iClient, flags);
			g_iStuckStatus[iClient] = -1;
		}
	} else {
		if(g_iStuckStatus[iClient] < 1 && g_iStuckStatus[iClient] != -1) {
			CPrintToChat(iClient, 0, "{green}%t {white}%t", "Prefix", "NotStuck");
			TeleportEntity(iClient, g_fOriginalPos[iClient], NULL_VECTOR, g_fOriginalVel[iClient]); //Reset to original pos / velocity
		} else {
			CPrintToChat(iClient, 0, "{green}%t {white}%t", "Prefix", "Unstuck");
			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, g_fOriginalVel[iClient]);
		}

		//Enable controls
		int flags = GetEntityFlags(iClient) & ~FL_ATCONTROLS;
		SetEntityFlags(iClient, flags);
		g_iStuckStatus[iClient] = -1;
	}
	return Plugin_Stop;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Fix Position
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

stock void TryFixPosition(int iClient, float fRadius, float fStep, bool bFirst=true, Direction dir=Forward) {
	int aDist[DIRECTION_COUNT];
	float vecDir[3], vecDirScaled[3], vecOrigin[3], vecOut[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	vecOrigin[2] += 32.0;

	int endpoint = (view_as<int>(dir)-1);
	if (endpoint < 0) {
		endpoint += DIRECTION_COUNT;
	}

	if (bFirst) {
		for (int i = 0; i < DIRECTION_COUNT; i++) {
			GetDirectionVec(view_as<Direction>(i), vecDir);
			vecDirScaled = vecDir;
			ScaleVector(vecDirScaled, fRadius*fStep);
			AddVectors(vecOrigin, vecDirScaled, vecOut);

			if (TR_PointOutsideWorld(vecOut)) {
				aDist[i] = i;
				continue;
			}

			TR_TraceRayFilter(vecOut, vecOrigin, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, TraceEntitiesAndWorld);
			if (TR_StartSolid()) {
				aDist[i] = i;
				continue;
			}

			if (TR_DidHit()) {
				TR_GetEndPosition(vecOrigin);
			}

			aDist[i] = RoundFloat(GetVectorDistance(vecOrigin, vecOut, true)) * DIRECTION_COUNT + i;
		}
		SortIntegers(aDist, DIRECTION_COUNT, Sort_Descending);
		g_aLooseDist[iClient] = aDist;
	}
	else {
		aDist = g_aLooseDist[iClient];
	}

	if (dir != Forward || bFirst) {
		for (int i = view_as<int>(dir); i < DIRECTION_COUNT; i++)
		{
			float fDist = float(aDist[i] / DIRECTION_COUNT);
			int currentDir = aDist[i] % DIRECTION_COUNT;
			if (fDist > (Pow(vecDir[0]*16.0, 2.0) + Pow(vecDir[1]*16.0, 2.0) + Pow(vecDir[2]*36.0, 2.0))) {
				//LogMessage("A possible position find!");
				if (TryFixPositionFromDirection(iClient, view_as<Direction>(currentDir), fRadius, fStep)) {
					return;
				}
			}
		}
	}
	//LogMessage("fStep: %f", fStep + sm_stuck_step.FloatValue);
	CheckIfPlayerCanMove(iClient, 0, 0, fStep+sm_stuck_step.FloatValue);
}

public int SortDesc(int[] x, int[] y, int[][] array, Handle data) {
	float a = float(x[1]);
	float b = float(y[1]);
	if (a > b)
		return -1;
	else if (a < b)
		return 1;
	return 0;
}  

stock bool TryFixPositionFromDirection(int iClient, Direction dir, float fRadius, float fStep) {
	float vecTryUp[3], vecTryDown[3], vecOrigin[3], vecMins[3], vecMaxs[3], vecDir[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetDirectionVec(dir, vecDir);

	ScaleVector(vecDir, fStep*fRadius);
	AddVectors(vecDir, vecOrigin, vecTryDown);
	vecTryUp = vecTryDown;
	vecTryUp[2] += 70.0; // 最好检查蹲姿

	vecMins = {-8.0, -8.0, 0.0};
	vecMaxs = {8.0, 8.0, 2.0}; // 2.0+70.0=72.0 为人物身高
	if (!TR_PointOutsideWorld(vecTryUp) && !TR_PointOutsideWorld(vecTryDown)) {
		TR_TraceHullFilter(vecTryDown, vecTryUp, vecMins, vecMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceEntitiesAndWorld);

		if (!TR_DidHit() && !TR_StartSolid()) {
			float vecDown[3] = {0.0, 0.0, -1.0};
			TR_TraceRayFilter(vecTryDown, vecDown, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceEntitiesAndWorld);
			if (TR_DidHit()) {
				TR_GetEndPosition(vecOrigin);
				if (GetVectorDistance(vecOrigin, vecTryDown) < 250.0) {
					TeleportEntity(iClient, vecTryDown);
					CheckIfPlayerCanMove(iClient, 0, 0, fStep, true, dir); // 最好指定检测初始方向（第三个参数）
					return true;
				}
			}
		}
	}
	return false;
}

public bool TraceEntitiesAndWorld(int iEntity, int iContentsMask) {
	//Dont care about clients or physics props
	if (iEntity < 1 || iEntity > MaxClients) {
		if (IsValidEntity(iEntity)) {
			char szClass[128];
			if (GetEntityClassname(iEntity, szClass, sizeof(szClass))) {
				if (StrContains(szClass, "prop_physics") != -1)
					return false;
			}
			return true;
		}
	}
	return false;
}