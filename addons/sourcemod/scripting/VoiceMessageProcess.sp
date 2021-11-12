#pragma semicolon 1
#define PLUGIN_VERSION "1.0"

#include <sdktools>
#include <sdkhooks>
#include <colorvariables>
#include <getoverit>

public void OnPluginStart() {
    HookUserMessage(GetUserMessageId("VoiceSubtitle"), OnVoiceSubtitle, true);
}

char voice_text[][100] = {
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

public Action OnVoiceSubtitle(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool reliable, bool init)
{
    int client = BfReadByte(bf);
    int voice_index = BfReadByte(bf);

    if(IsPlayerAlive(client) && IsClientInGame(client))
    {
        CreateTimer(0.1, ShowVoiceSubtitle, voice_index * 16 + client);
    }
    return Plugin_Handled;
}

public Action:ShowVoiceSubtitle(Handle:timer, any:data)
{
    int client = data % 16, voice_index = data / 16;
    char str[500], name[500];
    FetchColoredName(client, name, sizeof(name));
    Format(str, sizeof(str), "(语音) %s{white}: %s", name, voice_text[voice_index]);
    CPrintToChatAll(str);
}