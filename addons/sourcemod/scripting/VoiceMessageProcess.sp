#pragma semicolon 1
#define PLUGIN_VERSION "1.0"

#include <sdktools>
#include <sdkhooks>
#include <globalvariables>
#include <getoverit>

public void OnPluginStart() {
    HookUserMessage(GetUserMessageId("VoiceSubtitle"), OnVoiceSubtitle, true);
}

char g_aszVoiceText[][32] = {
    "需要子弹",
    "跟我来",
    "{red}救命!",
    "不",
    "停在这",
    "谢了",
    "好",
    "{red}它们来了",
    "{red}我受伤了",
};

public Action OnVoiceSubtitle(UserMsg hMsg, Handle bf, const int[] aPlayers, int nPlayersNum, bool bReliable, bool bInit)
{
    int iClient = BfReadByte(bf);
    int iVoiceIndex = BfReadByte(bf);

    if(IsPlayerAlive(iClient) && IsClientInGame(iClient))
    {
        RequestFrame(ShowVoiceSubtitle, iVoiceIndex * 16 + iClient);
    }
    return Plugin_Handled;
}

public void ShowVoiceSubtitle(any data)
{
    int iClient = data % 16, iVoice = data / 16;
    char szName[MAX_SAYTEXT2_LEN];
    FetchColoredName(iClient, szName, sizeof(szName));
    CPrintToChatAll(iClient, "(语音) %s: %s", szName, g_aszVoiceText[iVoice]);
}