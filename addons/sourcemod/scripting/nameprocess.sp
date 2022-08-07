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
#include <geoip>
#include <globalvariables>
#include <getoverit>
 
#define VERSION "1.1.1"

#define MAX_NAME_LEN 256

char g_aszCode2[MAXPLAYERS + 1][3];

public Plugin myInfo = {
    name = "Solve Name Color",
    author = "Antoine LIBERT aka AeN0",
    description = "Hook User Message And Change Name Color",
    version = VERSION,
    url = "http://www.a-l.fr/"
};

public OnPluginStart() {
    LoadTranslations("countrynick.phrases");
    CreateConVar("countrynick_version", VERSION, "Country Nick Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
}

public OnClientPostAdminCheck(iClient) {
    PrintToServer("country");
    CreateTimer(0.3, PrintCountryInfo, iClient, TIMER_FLAG_NO_MAPCHANGE);
}
public Action PrintCountryInfo(Handle hTimer, any iClient) {
    char szIp[16];
    char szRegion[46];
    char szName[MAX_NAME_LEN];
    
    if (!IsFakeClient(iClient) && iClient != 0) {

        GetClientIP(iClient, szIp, sizeof(szIp));
        if (!GeoipCode2(szIp, g_aszCode2[iClient])) {
            strcopy(g_aszCode2[iClient], sizeof(g_aszCode2[]), "??");
        }
        FetchColoredName(iClient, szName, sizeof(szName));
        if(GeoipCountryEx(szIp, szRegion, sizeof(szRegion), iClient))
        {
            CPrintToChatAll(0, "%t", "Announcer country found", szName, szRegion);
        }
        else
        {
            CPrintToChatAll(0, "%t", "Announcer country not found", szName);
            LogError("[Country Nick] Warning : %N uses %s that is not listed in GEOIP database", iClient, szIp);
        }
    }

    return Plugin_Handled;
}

public Action CP_OnChatMessage(int& iAuthor, ArrayList recipients, char[] szFlags, char[] szName, char[] szText, bool &bProcessColors) {

    FetchColoredName(iAuthor, szName, MAX_NAME_LEN);
    if(!IsPlayerAlive(iAuthor)) {
        if (GetEntProp(iAuthor, Prop_Send, "m_bIsExtracted"))
            Format(szName, MAX_NAME_LEN, "*撤离* [%s]%s", g_aszCode2[iAuthor], szName);
        else
            Format(szName, MAX_NAME_LEN, "*死亡* [%s]%s", g_aszCode2[iAuthor], szName);
    }
    else {
        Format(szName, MAX_NAME_LEN, "[%s]%s", g_aszCode2[iAuthor], szName);
    }
    return Plugin_Changed;
}