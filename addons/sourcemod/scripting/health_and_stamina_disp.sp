#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = {
    name = "No conflict Hud",
    author = "clagura",
    description = "Display health and stamina in no conflict",
    version = "1.0"
};

const float fPrint_Time = 0.3;
const float fPrint_Repeat_time = 0.25;

float fPrint_x = 0.02;
float fPrint_y = 0.86;

bool channel_enable[6];
int current_channel = 0;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("NativeSetChannelDisabled", NativeSetChannelDisabled);
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("health_and_stamina_disp.phrases");
    CreateTimer(fPrint_Repeat_time, Repeat_Print, _, TIMER_REPEAT);
}

public void OnMapStart()
{
    for (int i = 0; i < 6; i++) {
        channel_enable[i] = true;
    }
}

public Action Repeat_Print(Handle hTimer)
{
    if (MaxClients == 0) return Plugin_Continue;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            if (!IsClientTimingOut(client))
            {
                if(IsPlayerAlive(client))
                {
                    int iHealth = GetClientHealth(client);
                    int iStamina = RoundToZero(GetEntPropFloat(client, Prop_Send, "m_flStamina", 0));
                    char sHealth_Text[128];
                    char sStatus_Text[128];
                    FormatEx(sHealth_Text, sizeof(sHealth_Text), "%T", "Health", client, iHealth, iStamina);

                    if(GetEntProp(client, Prop_Send, "_bleedingOut") == 1)
                    {
                        Format(sStatus_Text, sizeof(sStatus_Text), "%T", "bleeding", client, sStatus_Text);
                    }

                    if(GetEntProp(client, Prop_Send, "_vaccinated") == 1)
                    {
                        Format(sStatus_Text, sizeof(sStatus_Text), "%T", "vaccinated", client, sStatus_Text);
                    }
                    else 
                    {
                        float fInfection_Death_Time = GetEntPropFloat(client, Prop_Send, "m_flInfectionDeathTime");
                        if(fInfection_Death_Time != -1.0)
                        {
                            Format(sStatus_Text, sizeof(sStatus_Text), "%T", "infected", client, sStatus_Text, RoundToCeil(fInfection_Death_Time - GetGameTime()));
                        }
                    }				

                    int iText_Color_r, iText_Color_g, iText_Color_b;
                    iText_Color_b = 0;
                    if (iHealth > 99)		// 100
                    {
                        iText_Color_r = 0;
                        iText_Color_g = 255;
                    }
                    else if (iHealth > 66)		// 99 - 67
                    {
                        iText_Color_r = RoundToNearest(((100.0 - float(iHealth)) / 34.0) * 255.0);
                        iText_Color_g = 255;
                    }
                    else if (iHealth > 33)		// 66 - 34
                    {
                        iText_Color_r = 255;
                        iText_Color_g = RoundToNearest((float(iHealth) - 33.0) / 33.0 * 255.0);
                    }
                    else		// 33 - 0
                    {
                        iText_Color_r = 255;
                        iText_Color_g = 0;
                    }
                    Format(sHealth_Text, sizeof(sHealth_Text), "%s\n%s", sHealth_Text, sStatus_Text);

                    Handle msg_new = StartMessageOne("HudMsg", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS); //Surely block hooks
                    BfWrite bf = UserMessageToBfWrite(msg_new);
                    bf.WriteByte(current_channel);
                    bf.WriteFloat(fPrint_x);
                    bf.WriteFloat(fPrint_y);
                    bf.WriteByte(iText_Color_r);
                    bf.WriteByte(iText_Color_g);
                    bf.WriteByte(iText_Color_b);
                    bf.WriteByte(255);
                    bf.WriteByte(iText_Color_r);
                    bf.WriteByte(iText_Color_g);
                    bf.WriteByte(iText_Color_b);
                    bf.WriteByte(255);
                    bf.WriteByte(1);
                    bf.WriteFloat(0.2);
                    bf.WriteFloat(0.3);
                    bf.WriteFloat(fPrint_Time);
                    bf.WriteFloat(0.0);
                    bf.WriteString(sHealth_Text);
                    EndMessage();
                }
            }
        }
    }
    return Plugin_Continue;
}

public int NativeSetChannelDisabled(Handle plugin, int num_params) {
    int n = GetNativeCell(1);
    channel_enable[n] = false;
    current_channel = ChooseChannel();
}

public int ChooseChannel() {
    for (int i = 2; i < 6; i++) { //channel 1 is much used for map text, so skip it
        if (channel_enable[i]) {
            return i;
        }
    }
    return 0;
}