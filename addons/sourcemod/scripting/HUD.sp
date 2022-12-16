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

const float fPrintTime = 0.5;
const float fPrintRepeatTimeDefault = 0.25;
const float fPrintRepeatTimeOften = 0.02;
float fPrint_Repeat_time = 0.25;

float fPrint_x = 0.02;
float fPrint_y = 0.86;

bool g_aChannelEnable[6], g_aChannelUsed[6], g_aSpeedMetterEnabled[MAXPLAYERS + 1], g_bSpeedMeter;
bool g_bLateLoad;
int iHealthChannel = 0, iSpeedChannel = 0;
int g_aObserveTarget[16];
ArrayList g_aObserveAudience[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = late;
    CreateNative("NativeSetChannelDisabled", NativeSetChannelDisabled);
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("HUD.phrases");

    (g_hSpeedMeter = CreateConVar("sm_speedmeter", "0", "1 - Active the speedmeter, 0 dezactiveaza", FCVAR_NOTIFY)).AddChangeHook(OnConVarChange);
    g_bSpeedMeter = g_hSpeedMeter.BoolValue;

    if (g_bSpeedMeter) {
        fPrint_Repeat_time = fPrintRepeatTimeOften;
    }
    else {
        fPrint_Repeat_time = fPrintRepeatTimeDefault;
    }
    g_hTimer = CreateTimer(fPrint_Repeat_time, Repeat_Print, _, TIMER_REPEAT);
    CreateTimer(0.25, SendExtraMsg, _, TIMER_REPEAT);

    for (int i = 0; i < 6; i++) {
        g_aChannelEnable[i] = true;
        g_aChannelUsed[i] = false;
    }

    iHealthChannel = 0;
    iSpeedChannel = 5;

    RegConsoleCmd("sm_speed", CommandSpeed);
    //PrintToServer("%d %d", iHealthChannel, iSpeedChannel);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i)) {
                OnClientPutInServer(i);
            }
        }
    }
}

public Action CommandSpeed(int iClient, int args) {
    if(g_aSpeedMetterEnabled[iClient]) {
        g_aSpeedMetterEnabled[iClient] = false;
        PrintToChat(iClient, " \x04[SpeedMetter]\x09 已经\x02 关闭");
    }
    else {
        g_aSpeedMetterEnabled[iClient] = true;
        PrintToChat(iClient, " \x04[SpeedMetter]\x09 已经\x06 开启");
    }
    return Plugin_Handled;
}

void OnConVarChange(ConVar CVar, const char[] oldValue, const char[] newValue) {
    if (CVar == g_hSpeedMeter) {
        if (StringToInt(newValue) > 0) {
            fPrint_Repeat_time = fPrintRepeatTimeOften;
            CloseHandle(g_hTimer);
            g_hTimer = CreateTimer(fPrint_Repeat_time, Repeat_Print, _, TIMER_REPEAT);

            g_bSpeedMeter = true;
        }
        else{
            fPrint_Repeat_time = fPrintRepeatTimeDefault;
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

public void OnClientPutInServer(int iClient) {
    if (g_bSpeedMeter) {
        g_aSpeedMetterEnabled[iClient] = true;
    }
    else {
        g_aSpeedMetterEnabled[iClient] = false;
    }

    g_aObserveTarget[iClient] = 0;
    if (IsValidHandle(g_aObserveAudience[iClient])) {
        g_aObserveAudience[iClient].Clear();
    }
    else {
        g_aObserveAudience[iClient] = new ArrayList();
    }
}

public void OnClientDisconnect(int iClient) {
    int iTemp;
    if (g_aObserveTarget[iClient] > 0 && (iTemp = g_aObserveAudience[g_aObserveTarget[iClient]].FindValue(iClient)) != -1) {
        g_aObserveAudience[g_aObserveTarget[iClient]].Erase(iTemp);
    }
}

Action Repeat_Print(Handle hTimer)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            GetHUDTarget(i);
        }
    }
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && !IsClientTimingOut(i) && IsPlayerAlive(i))
        {
            static int aClients[MAXPLAYERS + 1], nClients;
            nClients = 0;
            for (int j = 0; j < g_aObserveAudience[i].Length; j++) {
                aClients[nClients++] = g_aObserveAudience[i].Get(j);
            }
            aClients[nClients++] = i;
            SendHealthMessage(i, aClients, nClients);
            if (g_aSpeedMetterEnabled[i]) {
                SendSpeedMessage(i, aClients, nClients);
            }
        }
    }
    return Plugin_Continue;
}

void SendHealthMessage(int iClient, int[] aClients, int nClients) {

    static int iHealth;
    iHealth = GetClientHealth(iClient);
    static char szHealthText[128], szStatusText[128];

    FormatEx(szHealthText, sizeof(szHealthText), "%T", "Health", iClient, iHealth);

    if (!g_bSpeedMeter) {
        static int iStamina;
        iStamina = RoundToZero(GetEntPropFloat(iClient, Prop_Send, "m_flStamina", 0));

        Format(szHealthText, sizeof(szHealthText), "%s    %T", szHealthText, "Stamina", iClient, iStamina);

        szStatusText[0] = 0;
        if(GetEntProp(iClient, Prop_Send, "_bleedingOut") == 1)
        {
            Format(szStatusText, sizeof(szStatusText), "%s%T ", szStatusText, "bleeding", iClient);
        }

        if(GetEntProp(iClient, Prop_Send, "_vaccinated") == 1)
        {
            Format(szStatusText, sizeof(szStatusText), "%s%T ", szStatusText, "vaccinated", iClient);
        }
        else 
        {
            float fInfection_Death_Time = GetEntPropFloat(iClient, Prop_Send, "m_flInfectionDeathTime");
            if(fInfection_Death_Time != -1.0)
            {
                Format(szStatusText, sizeof(szStatusText), "%s%T ", szStatusText, "infected", iClient, RoundToCeil(fInfection_Death_Time - GetGameTime()));
            }
        }
    }

    static int iTextColor_r, iTextColor_g, iTextColor_b;
    iTextColor_b = 0;
    if (iHealth > 99)		// 100
    {
        iTextColor_r = 0;
        iTextColor_g = 255;
    }
    else if (iHealth > 66)		// 99 - 67
    {
        iTextColor_r = RoundToNearest(((100.0 - float(iHealth)) / 34.0) * 255.0);
        iTextColor_g = 255;
    }
    else if (iHealth > 33)		// 66 - 34
    {
        iTextColor_r = 255;
        iTextColor_g = RoundToNearest((float(iHealth) - 33.0) / 33.0 * 255.0);
    }
    else		// 33 - 0
    {
        iTextColor_r = 255;
        iTextColor_g = 0;
    }
    Format(szHealthText, sizeof(szHealthText), "%s\n%s", szHealthText, szStatusText);

    Handle hHealthMsg = StartMessage("HudMsg", aClients, nClients, USERMSG_BLOCKHOOKS); //Surely block hooks
    BfWrite bf = UserMessageToBfWrite(hHealthMsg);
    bf.WriteByte(iHealthChannel);
    bf.WriteFloat(fPrint_x);
    bf.WriteFloat(fPrint_y);
    bf.WriteByte(iTextColor_r);
    bf.WriteByte(iTextColor_g);
    bf.WriteByte(iTextColor_b);
    bf.WriteByte(255);
    bf.WriteByte(iTextColor_r);
    bf.WriteByte(iTextColor_g);
    bf.WriteByte(iTextColor_b);
    bf.WriteByte(255);
    bf.WriteByte(1);
    bf.WriteFloat(0.2);
    bf.WriteFloat(0.3);
    bf.WriteFloat(fPrintTime);
    bf.WriteFloat(0.0);
    bf.WriteString(szHealthText);
    EndMessage();
}

void SendSpeedMessage(int iClient, int[] aClients, int nClients) {

    static float vecVelocity[3], fSpeed;
    GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vecVelocity);
    
    vecVelocity[0] *= vecVelocity[0];
    vecVelocity[1] *= vecVelocity[1];
    vecVelocity[2] *= vecVelocity[2];
    
    fSpeed = SquareRoot(vecVelocity[0] + vecVelocity[1] + vecVelocity[2]);

    static char szSpeedText[100];
    FormatEx(szSpeedText, sizeof(szSpeedText), "%.1f m/s", fSpeed);

    Handle hSpeedMsg = StartMessage("HudMsg", aClients, nClients, USERMSG_BLOCKHOOKS); //Surely block hooks
    BfWrite bf = UserMessageToBfWrite(hSpeedMsg);
    bf.WriteByte(iSpeedChannel);
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

    if (iHealthChannel == n) {
        g_aChannelUsed[iHealthChannel] = false;
        iHealthChannel = ChooseChannel();
        g_aChannelUsed[iHealthChannel] = true;
    }
    if (iSpeedChannel == n) {
        g_aChannelUsed[iSpeedChannel] = false;
        iSpeedChannel = ChooseChannel();
        g_aChannelUsed[iSpeedChannel] = true;
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

int GetHUDTarget(int iClient)
{
    if (IsClientObserver(iClient))
    {
        int iObserverMode = GetEntProp(iClient, Prop_Send, "m_iObserverMode");
        if (iObserverMode >= 3 && iObserverMode <= 5)
        {
            int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
            if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && !IsClientSourceTV(iTarget)) {
                if (iTarget != g_aObserveTarget[iClient]) {
                    int iTemp;
                    if (g_aObserveTarget[iClient] != 0 && (iTemp = g_aObserveAudience[g_aObserveTarget[iClient]].FindValue(iClient)) != -1) {
                        g_aObserveAudience[g_aObserveTarget[iClient]].Erase(iTemp);
                    }
                    g_aObserveTarget[iClient] = iTarget;
                    if (g_aObserveAudience[iTarget].FindValue(iClient) == -1) {
                        g_aObserveAudience[iTarget].Push(iClient);
                    }
                }
                return iTarget;
            }
        }
    }
    int iTemp;
    if (g_aObserveTarget[iClient] != 0 && (iTemp = g_aObserveAudience[g_aObserveTarget[iClient]].FindValue(iClient)) != -1) {
        g_aObserveAudience[g_aObserveTarget[iClient]].Erase(iTemp);
    }
    g_aObserveTarget[iClient] = 0;
    return iClient;
}

Action SendExtraMsg(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && g_aObserveAudience[i].Length > 0) {
            static int aClients[MAXPLAYERS + 1], nClients;
            nClients = 0;
            for (int j = 0; j < g_aObserveAudience[i].Length; j++) {
                aClients[nClients++] = g_aObserveAudience[i].Get(j);
                //PrintToServer("%N's audience: %d", i, g_aObserveAudience[i].Get(j));
            }
            Handle hMsg = StartMessage("KeyHintText", aClients, nClients, USERMSG_BLOCKHOOKS);
            BfWrite bf = UserMessageToBfWrite(hMsg);
            bf.WriteByte(1); // number of strings, only 1 is accepted

            char szBuffer[256];
            FormatEx(szBuffer, sizeof(szBuffer), "正在观看 %N 的玩家：\n", i);
            for (int j = 0; j < g_aObserveAudience[i].Length; j++) {
                Format(szBuffer, sizeof(szBuffer), "%s%N\n", szBuffer, g_aObserveAudience[i].Get(j));
            }
            bf.WriteString(szBuffer);
            EndMessage();
        }
    }

    return Plugin_Continue;
}