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

ConVar g_hSpeedMeter;
Handle g_hTimer;

const float fPrint_Time = 0.5;
const float fPrint_Repeat_time_Default = 0.25;
const float fPrint_Repeat_time_Often = 0.02;
float fPrint_Repeat_time = 0.25;

float fPrint_x = 0.02;
float fPrint_y = 0.86;

bool g_aChannelEnable[6], g_aChannelUsed[6], g_aSpeedMetterEnabled[MAXPLAYERS + 1], g_bSpeedMeter;
int health_channel = 0, speed_channel = 0;
int g_aObserveTarget[16];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("NativeSetChannelDisabled", NativeSetChannelDisabled);
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("HUD.phrases");

    (g_hSpeedMeter = CreateConVar("sm_speedmeter", "0", "1 - Active the speedmeter, 0 dezactiveaza", FCVAR_NOTIFY)).AddChangeHook(OnConVarChange);
    g_bSpeedMeter = g_hSpeedMeter.BoolValue;

    if (g_bSpeedMeter) {
        fPrint_Repeat_time = fPrint_Repeat_time_Often;
    }
    else {
        fPrint_Repeat_time = fPrint_Repeat_time_Default;
    }
    g_hTimer = CreateTimer(fPrint_Repeat_time, Repeat_Print, _, TIMER_REPEAT);
    CreateTimer(0.25, SendExtraMsg, _, TIMER_REPEAT);

    for (int i = 0; i < 6; i++) {
        g_aChannelEnable[i] = true;
        g_aChannelUsed[i] = false;
    }

    health_channel = 0;
    speed_channel = 5;

    RegConsoleCmd("sm_speed", CommandSpeed);
    //PrintToServer("%d %d", health_channel, speed_channel);
}

public Action CommandSpeed(int client, int args) {
    if(g_aSpeedMetterEnabled[client]) {
        g_aSpeedMetterEnabled[client] = false;
        PrintToChat(client, " \x04[SpeedMetter]\x09 已经\x02 关闭");
    }
    else {
        g_aSpeedMetterEnabled[client] = true;
        PrintToChat(client, " \x04[SpeedMetter]\x09 已经\x06 开启");
    }
    return Plugin_Handled;
}

void OnConVarChange(ConVar CVar, const char[] oldValue, const char[] newValue) {
    if (CVar == g_hSpeedMeter) {
        if (StringToInt(newValue) > 0) {
            fPrint_Repeat_time = fPrint_Repeat_time_Often;
            CloseHandle(g_hTimer);
            g_hTimer = CreateTimer(fPrint_Repeat_time, Repeat_Print, _, TIMER_REPEAT);

            g_bSpeedMeter = true;
        }
        else{
            fPrint_Repeat_time = fPrint_Repeat_time_Default;
            CloseHandle(g_hTimer);
            g_hTimer = CreateTimer(fPrint_Repeat_time, Repeat_Print, _, TIMER_REPEAT);

            g_bSpeedMeter = false;
        }
    }
}

public void OnMapStart()
{
    for (int i = 0; i < 6; i++) {
        g_aChannelEnable[i] = true;
    } 
}

public void OnClientPutInServer(int client) {
    if (g_bSpeedMeter) {
        g_aSpeedMetterEnabled[client] = true;
    }
    else {
        g_aSpeedMetterEnabled[client] = false;
    }
}

Action Repeat_Print(Handle hTimer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            if (!IsClientTimingOut(client))
            {
                int iTarget = GetHUDTarget(client);
                if (IsPlayerAlive(iTarget))
                {
                    SendHealthMessage(client, iTarget);
                    if (g_aSpeedMetterEnabled[client])
                        SendSpeedMessage(client, iTarget);
                }
            }
        }
    }
    return Plugin_Continue;
}

void SendHealthMessage(int client, int iTarget) {

    int iHealth = GetClientHealth(iTarget);
    char sHealth_Text[128];
    char sStatus_Text[128];

    FormatEx(sHealth_Text, sizeof(sHealth_Text), "%T", "Health", client, iHealth);

    if (!g_bSpeedMeter) {
        int iStamina = RoundToZero(GetEntPropFloat(iTarget, Prop_Send, "m_flStamina", 0));

        Format(sHealth_Text, sizeof(sHealth_Text), "%s    %T", sHealth_Text, "Stamina", client, iStamina);

        if(GetEntProp(iTarget, Prop_Send, "_bleedingOut") == 1)
        {
            Format(sStatus_Text, sizeof(sStatus_Text), "%T", "bleeding", client, sStatus_Text);
        }

        if(GetEntProp(iTarget, Prop_Send, "_vaccinated") == 1)
        {
            Format(sStatus_Text, sizeof(sStatus_Text), "%T", "vaccinated", client, sStatus_Text);
        }
        else 
        {
            float fInfection_Death_Time = GetEntPropFloat(iTarget, Prop_Send, "m_flInfectionDeathTime");
            if(fInfection_Death_Time != -1.0)
            {
                Format(sStatus_Text, sizeof(sStatus_Text), "%T", "infected", client, sStatus_Text, RoundToCeil(fInfection_Death_Time - GetGameTime()));
            }
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

    Handle health_msg = StartMessageOne("HudMsg", client, USERMSG_BLOCKHOOKS); //Surely block hooks
    BfWrite bf = UserMessageToBfWrite(health_msg);
    bf.WriteByte(health_channel);
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

void SendSpeedMessage(int client, int iTarget) {

    float vecVelocity[3], fSpeed;
    GetEntPropVector(iTarget, Prop_Data, "m_vecVelocity", vecVelocity);
    
    vecVelocity[0] *= vecVelocity[0];
    vecVelocity[1] *= vecVelocity[1];
    vecVelocity[2] *= vecVelocity[2];
    
    fSpeed = SquareRoot(vecVelocity[0] + vecVelocity[1] + vecVelocity[2]);

    char szSpeedText[100];
    FormatEx(szSpeedText, 100, "%.1f m/s", fSpeed);

    Handle speed_msg = StartMessageOne("HudMsg", client, USERMSG_BLOCKHOOKS); //Surely block hooks
    BfWrite bf = UserMessageToBfWrite(speed_msg);
    bf.WriteByte(speed_channel);
    bf.WriteFloat(-1.0);
    bf.WriteFloat(0.85);
    bf.WriteByte(255);
    bf.WriteByte(255);
    bf.WriteByte(255);
    bf.WriteByte(255);
    bf.WriteByte(255);
    bf.WriteByte(255);
    bf.WriteByte(255);
    bf.WriteByte(255);
    bf.WriteByte(0);
    bf.WriteFloat(0.0);
    bf.WriteFloat(0.0);
    bf.WriteFloat(0.5);
    bf.WriteFloat(0.0);
    bf.WriteString(szSpeedText);
    EndMessage();
}

public int NativeSetChannelDisabled(Handle plugin, int num_params) {
    int n = GetNativeCell(1);
    g_aChannelEnable[n] = false;

    if (health_channel == n) {
        g_aChannelUsed[health_channel] = false;
        health_channel = ChooseChannel();
        g_aChannelUsed[health_channel] = true;
    }
    if (speed_channel == n) {
        g_aChannelUsed[speed_channel] = false;
        speed_channel = ChooseChannel();
        g_aChannelUsed[speed_channel] = true;
    }
    return 0;
}

int ChooseChannel() {
    for (int i = 2; i < 6; i++) { //channel 1 is much used for map text, so skip it
        if (g_aChannelEnable[i] && !g_aChannelUsed[i]) {
            return i;
        }
    }
    return 0;
}

int GetHUDTarget(int client)
{
    if (IsClientObserver(client))
    {
        int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
        if(iObserverMode >= 3 && iObserverMode <= 5)
        {
            int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
            if (iTarget > 0 && iTarget <= MaxClients) {
                if (IsClientInGame(iTarget)) {
                    if (!IsClientSourceTV(iTarget)) {
                        g_aObserveTarget[client] = iTarget;
                        return iTarget;
                    }
                }
            }
        }
        g_aObserveTarget[client] = 0;
    }
    return client;
}

Action SendExtraMsg(Handle timer) {
    int aObserved[16][16];
    int len[16] = { 0 };
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (IsClientObserver(i)) {
                int target = g_aObserveTarget[i];
                aObserved[target][len[target]] = i;
                len[target]++;
            }
        }
    }
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (IsPlayerAlive(i) && len[i] > 0) {
                Handle msg = StartMessage("KeyHintText", aObserved[i], len[i], USERMSG_BLOCKHOOKS);
                BfWrite bf = UserMessageToBfWrite(msg);
                bf.WriteByte(1); // number of strings, only 1 is accepted

                char buffer[256];
                FormatEx(buffer, 256, "正在观看 %N 的玩家：\n", i);
                for (int j = 0; j < len[i]; j++) {
                    Format(buffer, 256, "%s%N\n", buffer, aObserved[i][j]);
                }
                bf.WriteString(buffer);
                EndMessage();
            }
        }
    }

    return Plugin_Continue;
}