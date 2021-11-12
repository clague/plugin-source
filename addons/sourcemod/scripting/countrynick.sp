/*
SourceMod Country Nick Plugin
Add country of the player near his nick
 
Country Nick Plugin (C)2009-2010 A-L. All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

$Id: countrynick.sp 29 2009-02-23 23:45:22Z aen0 $
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <colorvariables>
#include <getoverit>
 
#define VERSION "1.1.1"

char code2[MAXPLAYERS + 1][3];
bool extracted[MAXPLAYERS + 1];

public Plugin:myinfo =
{
	name = "Solve Name Color",
	author = "Antoine LIBERT aka AeN0",
	description = "Hook User Message And Change Name Color",
	version = VERSION,
	url = "http://www.a-l.fr/"
};

public OnPluginStart()
{
	LoadTranslations("countrynick.phrases");
	CreateConVar("countrynick_version", VERSION, "Country Nick Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	HookEvent("player_extracted", OnPlayerExtraction);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
}

public OnClientPostAdminCheck(client)
{
	extracted[client] = false;
	PrintToServer("country");
	CreateTimer(0.3, PrintCountryInfo, client);
}
public Action:PrintCountryInfo(Handle:timer, any:client)
{
	decl String:ip[16];
	decl String:country[46];
	decl String:code[3];
	decl String:name[500];
	
	if(!IsFakeClient(client) && client != 0)
	{
		GetClientIP(client, ip, 16);
		if (!GeoipCode2(ip, code))
			Format(code, sizeof(code), "--");
		strcopy(code2[client], 3, code);
		FetchColoredName(client, name, sizeof(name));
		if(GeoipCountry(ip, country, 45))
		{
			CPrintToChatAll("%t", "Announcer country found", name, country);
		}
		else
		{
			CPrintToChatAll("%t", "Announcer country not found", name);
			LogError("[Country Nick] Warning : %N uses %s that is not listed in GEOIP database", client, ip);
		}
	}
}

public void OnPlayerExtraction(Event e, const char[] n, bool b)
{
	int client = e.GetInt("player_id");
	extracted[client] = true;
}
public void OnPlayerSpawn(Event e, const char[] n, bool b)
{
	int client = e.GetInt("player_id");
	extracted[client] = false;
}
public void OnClientDisconnect(int client)
{
	extracted[client] = false;
}

public void OnPlayerDeath(Event e, const char[] n, bool b)
{
	int client = e.GetInt("player_id");
	extracted[client] = false;
}

public Action CP_OnChatMessage(int& client, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool &processcolors, bool &removecolors) 
{
	FetchColoredName(client, name, 500);
	Format(name, 500, "{white}[%s]%s", code2[client], name);
	if(!IsPlayerAlive(client)) {
		if(extracted[client])
			Format(name, 500, "*撤离* %s", name);
		else
			Format(name, 500, "*死亡* %s", name);
	}
	return Plugin_Changed;
}