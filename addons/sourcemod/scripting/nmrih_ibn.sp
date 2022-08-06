#pragma semicolon 1
#include <sdkhooks>
#include <getoverit>
#include <globalvariables>

#define PLUGIN_VERSION "2.0"

#define CHAT_COLOR_PRIMARY		3
#define CHAT_COLOR_SECONDARY	1

new bool:Infection[MAXPLAYERS+1];
new bool:Bleeding[MAXPLAYERS+1];

new Float:flLastTA = 0.0;

public Plugin:myinfo =
{
	name = "[NMRiH] Infection & Bleeding Notification",
	author = "ys24ys, Mr.Halt",
	description = "Infection & Bleeding Notification for NMRiH",
	version = PLUGIN_VERSION,
	url = "http://blog.naver.com/pine0113"
};

public OnPluginStart()
{
	decl String:game[16];
	GetGameFolderName(game, sizeof(game));
	if(strcmp(game, "nmrih", false) != 0)
	{
		SetFailState("Unsupported game!");
	}
	
	CreateConVar("sm_nmrih_ibn_version", PLUGIN_VERSION, "[NMRiH] Infection & Bleeding Notification version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	LoadTranslations("nmrih_ibn.phrases");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
}

public OnMapStart() {
	flLastTA = 0.0;
	OnStatusTimer();
}

public OnStatusTimer()
{
	for(new Client=1; Client<=MaxClients; Client++)
	{
		CreateTimer(0.2, Event_PlayerStatus, Client, TIMER_REPEAT);
	}
}

public Action:Event_PlayerStatus(Handle:timer, any:Client)
{
	if(IsClientConnected(Client) && IsClientInGame(Client) && IsPlayerAlive(Client))
	{
		if(IsClientInfected(Client) == false) Infection[Client] = false;
		
		if(IsClientInfected(Client) == true)
		{
			if(Infection[Client] == false)
			{
				Infection[Client] = true;
				char name[500];
				FetchColoredName(Client, name, sizeof(name));
				CPrintToChatAll(0, "%s \x04%t", name, "Notifi_Infection");
			}
		}
		
		if(IsClientBleeding(Client) == false) Bleeding[Client] = false;
		
		if(IsClientBleeding(Client))
		{
			if(Bleeding[Client] == false)
			{
				Bleeding[Client] = true;
				char name[500];
				FetchColoredName(Client, name, sizeof(name));
				CPrintToChatAll(0, "%s \x04%t", name, "Notifi_Bleeding");
			}
		}
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(Infection[Client] == true) Infection[Client] = false;
	if(Bleeding[Client] == true) Bleeding[Client] = false;
}

public Event_PlayerHurt( Handle:hEvent, const String:szEventName[], bool:bDontBroadcast )
{
	new Float:flCurTime = GetGameTime();
	new iVClient = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
	new iAClient = GetClientOfUserId( GetEventInt( hEvent, "attacker" ) );
	if( iVClient != iAClient && 0 < iVClient <= MaxClients && 0 < iAClient <= MaxClients && IsClientInGame( iAClient ) && ( flCurTime - flLastTA ) > 3.0 )
	{
		flLastTA = flCurTime;
		char victim_name[500], attack_name[500];
		FetchColoredName(iVClient, victim_name, sizeof(victim_name));
		FetchColoredName(iAClient, attack_name, sizeof(attack_name));
		PrintToServer("%N attacked a teammate", iAClient);
		CPrintToChatAll(0, " %s 痛击了队友 %s !", attack_name, victim_name);
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));
	new iAttacker = GetEventInt( event, "attacker" );
	new iAClient = GetClientOfUserId( iAttacker );
	new iVClient = GetClientOfUserId( GetEventInt( event, "userid" ) );
	new iNPCType = GetEventInt( event, "npctype" );
	char victim_name[500];

	new String:szWeapon[32];
	GetEventString( event, "weapon", szWeapon, sizeof( szWeapon ) );
	
	if( iVClient <= 0 || iVClient > MaxClients || !IsClientInGame( iVClient ) )
		return;
	FetchColoredName(iVClient, victim_name, sizeof(victim_name));
	if(iNPCType != 0 && !StrContains( szWeapon, "npc", false))
	{
		if(StrContains(szWeapon, "_turnedzombie", false ) > 0)
		{
			CPrintToChatAll(0, "幸存者 %s 死于尸变队友的偷袭.", victim_name);
		}
		else if(StrContains( szWeapon, "_kidzombie", false ) > 0)
		{
			CPrintToChatAll(0, "幸存者 %s 被小孩拍死.", victim_name);
		}
		else if(StrContains( szWeapon, "zombie", false ) > 0)
		{
			CPrintToChatAll(0, "幸存者 %s 被丧尸杀害.", victim_name);
		}
		else
		{
			CPrintToChatAll(0, "幸存者 %s 被残忍杀害.", victim_name);
		}
		PrintToServer("Death: '%N', NPC, '%s'", iVClient, szWeapon);
	}
	else if(iAClient == iVClient)
	{
		new Float:flInfDeathTime = GetEntPropFloat(iVClient, Prop_Send, "m_flInfectionDeathTime");
		if( GetEntProp(iVClient, Prop_Send, "m_bDiedWhileInfected") || flInfDeathTime >= 0.0 && (GetGameTime() - flInfDeathTime) >= 0.0)
		{
			CPrintToChatAll(0, "幸存者 %s 死于感染.", victim_name);
			PrintToServer("Death: '%N', infection, '%s'", iVClient, szWeapon);
		}
		else if(Bleeding[iVClient])
		{
			CPrintToChatAll(0, "幸存者 %s 失血过多而亡.", victim_name);
			PrintToServer("Death: '%N', blood loss, '%s'", iVClient, szWeapon);
		}
		else
		{
			CPrintToChatAll(0, "幸存者 %s 不堪重负，结束了自己的生命.", victim_name);
			PrintToServer("Death: '%N', suicide, '%s'", iVClient, szWeapon);
		}
	}
	else if(0 < iAClient <= MaxClients && IsClientInGame(iAClient))
	{
		char attack_name[500];
		FetchColoredName(iAClient, attack_name, sizeof(attack_name));
		CPrintToChatAll(0, "幸存者 %s 被队友 %s 反补.", victim_name, attack_name);
		PrintToServer("Death: '%N', '%N', '%s'", iVClient, iAClient, szWeapon);
	}
	else if(iAttacker == 0)
	{
		if(strcmp(szWeapon, "fall") == 0) 
			CPrintToChatAll(0, "幸存者 %s 摔死了.", victim_name);
		else
			CPrintToChatAll(0, "幸存者 %s 被这个世界杀害.", victim_name);
		PrintToServer("Death: '%N', world, '%s'", iVClient, szWeapon);
	}
	else
	{
		CPrintToChatAll(0, "幸存者 %s 挂了.", victim_name);
		PrintToServer("Death: '%N', #%d, '%s'", iVClient, iAttacker, szWeapon);
	}
	
	Bleeding[iVClient] = false;
	Infection[Client] = false;
}

stock bool:IsClientInfected(Client)
{
	if(GetEntPropFloat(Client, Prop_Send, "m_flInfectionTime") > 0 && GetEntPropFloat(Client, Prop_Send, "m_flInfectionDeathTime") > 0) return true;
	else return false;
}

stock bool:IsClientBleeding(Client)
{
	if(GetEntProp(Client, Prop_Send, "_bleedingOut") == 1) return true;
	else return false;
}

