////////////////////
//Pragma
#pragma semicolon 1
#pragma newdecls required

////////////////////
//Defines
#define PLUGIN_NAME "Chat-Processor"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION "Replacement for Simple Chat Processor."
#define PLUGIN_VERSION "2.2.9"
#define PLUGIN_CONTACT "https://drixevel.dev/"

////////////////////
//Includes
#include <sourcemod>
#include <chat-processor>
#include <globalvariables>

////////////////////
//ConVars
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_ProcessColors;
ConVar convar_StripColors;
ConVar convar_ColorsFlags;
ConVar convar_DeadChat;
ConVar convar_AllChat;
ConVar convar_RestrictDeadChat;
ConVar convar_AddGOTV;

////////////////////
//Forwards
Handle g_Forward_OnChatMessageSendPre;
Handle g_Forward_OnChatMessage;
Handle g_Forward_OnChatMessagePost;

Handle g_Forward_OnAddClientTagPost;
Handle g_Forward_OnRemoveClientTagPost;
Handle g_Forward_OnSwapClientTagsPost;
Handle g_Forward_OnStripClientTagsPost;
Handle g_Forward_OnSetTagColorPost;
Handle g_Forward_OnSetNameColorPost;
Handle g_Forward_OnSetChatColorPost;
Handle g_Forward_OnReloadChatData;

////////////////////
//Globals
EngineVersion game;
bool g_Late;
StringMap g_MessageFormats;
bool g_Proto;

int g_iFlags;
bool g_bHaveMessage[MAXPLAYERS + 1];

//Tags
ArrayList g_Tags[MAXPLAYERS + 1];
char g_NameColor[MAXPLAYERS + 1][MAXLENGTH_NAME];
char g_ChatColor[MAXPLAYERS + 1][MAXLENGTH_MESSAGE];

////////////////////
// Plugin Info
public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = PLUGIN_CONTACT
};

////////////////////
// Ask Plugin Load 2
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("chat-processor");
    
    CreateNative("ChatProcessor_GetFlagFormatString", Native_GetFlagFormatString);
    
    CreateNative("ChatProcessor_AddClientTag", Native_AddClientTag);
    CreateNative("ChatProcessor_RemoveClientTag", Native_RemoveClientTag);
    CreateNative("ChatProcessor_SwapClientTags", Native_SwapClientTags);
    CreateNative("ChatProcessor_StripClientTags", Native_StripClientTags);
    CreateNative("ChatProcessor_SetTagColor", Native_SetTagColor);
    CreateNative("ChatProcessor_SetNameColor", Native_SetNameColor);
    CreateNative("ChatProcessor_SetChatColor", Native_SetChatColor);

    g_Forward_OnChatMessageSendPre = CreateGlobalForward("CP_OnChatMessageSendPre", ET_Hook, Param_CellByRef, Param_CellByRef, Param_String, Param_String);
    g_Forward_OnChatMessage = CreateGlobalForward("CP_OnChatMessage", ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String, Param_String, Param_CellByRef);
    g_Forward_OnChatMessagePost = CreateGlobalForward("CP_OnChatMessagePost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String);
    
    g_Forward_OnAddClientTagPost = CreateGlobalForward("CP_OnAddClientTagPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
    g_Forward_OnRemoveClientTagPost = CreateGlobalForward("CP_OnRemoveClientTagPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
    g_Forward_OnSwapClientTagsPost = CreateGlobalForward("CP_OnSwapClientTagsPost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
    g_Forward_OnStripClientTagsPost = CreateGlobalForward("CP_OnStripClientTagsPost", ET_Ignore, Param_Cell);
    g_Forward_OnSetTagColorPost = CreateGlobalForward("CP_OnSetTagColorPost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
    g_Forward_OnSetNameColorPost = CreateGlobalForward("CP_OnSetNameColorPost", ET_Ignore, Param_Cell, Param_String);
    g_Forward_OnSetChatColorPost = CreateGlobalForward("CP_OnSetChatColorPost", ET_Ignore, Param_Cell, Param_String);
    g_Forward_OnReloadChatData = CreateGlobalForward("CP_OnReloadChatData", ET_Ignore);

    game = GetEngineVersion();
    g_Late = late;
    
    return APLRes_Success;
}

////////////////////
// On Plugin Start
public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    
    CreateConVar("sm_chatprocessor_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

    convar_Status = CreateConVar("sm_chatprocessor_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    convar_Config = CreateConVar("sm_chatprocessor_config", "configs/chat_processor.cfg", "Name of the message formats config.", FCVAR_NOTIFY);
    convar_ProcessColors = CreateConVar("sm_chatprocessor_process_colors_default", "1", "Default setting to give forwards to process colors.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    convar_StripColors = CreateConVar("sm_chatprocessor_strip_colors", "0", "Remove color tags from the name and the message before processing the output.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    convar_ColorsFlags = CreateConVar("sm_chatprocessor_colors_flag", "b", "Flags required to use the color name and message. Needs sm_chatprocessor_strip_colors 1", FCVAR_NOTIFY);
    convar_DeadChat = CreateConVar("sm_chatprocessor_deadchat", "1", "Controls how dead communicate.\n(0 = off, 1 = on)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    convar_AllChat = CreateConVar("sm_chatprocessor_allchat", "1", "Allows both teams to communicate with each other through team chat.\n(0 = off, 1 = on)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    convar_RestrictDeadChat = CreateConVar("sm_chatprocessor_restrictdeadchat", "0", "Restricts all chat for the dead entirely.\n(0 = off, 1 = on)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    convar_AddGOTV = CreateConVar("sm_chatprocessor_addgotv", "1", "Add GOTV client to recipients list. (Only effects games with GOTV or SourceTV)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    convar_ColorsFlags.AddChangeHook(OnFlagsChanged);
    OnFlagsChanged(convar_ColorsFlags, "", "");

    AutoExecConfig(true, "chat-processor");

    g_MessageFormats = new StringMap();
}

////////////////////
// On Configs Executed
public void OnConfigsExecuted()
{
    if (!convar_Status.BoolValue)
        return;
    
    GenerateMessageFormats();

    g_Proto = CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf;

    UserMsg SayText2 = GetUserMessageId("SayText2");

    if (SayText2 != INVALID_MESSAGE_ID)
    {
        HookUserMessage(SayText2, OnSayText2, true);
        LogMessage("Successfully hooked a SayText2 chat hook.");
    }
    else
        SetFailState("Error loading the plugin, SayText2 is unavailable.");
    
    if (g_Late)
    {
        g_Late = false;
        
        for (int i = 1; i <= MaxClients; i++)
            if (IsClientConnected(i))
                OnClientConnected(i);
        
        Call_StartForward(g_Forward_OnReloadChatData);
        Call_Finish();
    }

    char szFlags[32];
    convar_ColorsFlags.GetString(szFlags, sizeof(szFlags));
    g_iFlags = ReadFlagString(szFlags);
}

public void OnFlagsChanged(ConVar hConVar, const char[] szOld, const char[] szNew) {
    char szFlags[32];
    convar_ColorsFlags.GetString(szFlags, sizeof(szFlags));
    g_iFlags = ReadFlagString(szFlags);
}

////////////////////
//SayText2
public Action OnSayText2(UserMsg msg_id, BfRead hMsg, const int[] players, int playersNum, bool reliable, bool init)
{
    //Check if the plugin is disabled.
    if (!convar_Status.BoolValue)
        return Plugin_Continue;

    int iAuthor;
    char szFlags[MAXLENGTH_FLAG], szFormat[MAXLENGTH_BUFFER], szName[MAXLENGTH_NAME], szText[MAXLENGTH_MESSAGE];
    //Retrieve the client sending the message to other clients.
    if (g_Proto) {
        iAuthor = PbReadInt(hMsg, "ent_idx");
        PbReadString(hMsg, "msg_name", szFlags, sizeof(szFlags)); //Retrieve the name of template name to use when getting the format.
        PbReadString(hMsg, "params", szName, sizeof(szName), 0); //Get the name string of the client.
        PbReadString(hMsg, "params", szText, sizeof(szText), 1); //Get the message string that the client is wanting to send.
        PbReadString(hMsg, "params", "", 0, 2);
        PbReadString(hMsg, "params", "", 0, 3);
    }
    else {
        iAuthor = BfReadByte(hMsg);
        BfReadByte(hMsg);
        BfReadString(hMsg, szFlags, sizeof(szFlags)); //Retrieve the name of template name to use when getting the format.
        if (BfGetNumBytesLeft(hMsg)) {
            BfReadString(hMsg, szName, sizeof(szName)); //Get the name string of the client.
        }
        if (BfGetNumBytesLeft(hMsg)) {
            BfReadString(hMsg, szText, sizeof(szText)); //Get the message string that the client is wanting to send.
        }
    }
    //LogMessage("SayText2 message received, %s, %s, %s", szFlags, szName, szText);

    // When client say text, the SayText2 message will fire multiple times when it's sent to every client.
    // But we only need to deal with one of them.
    if (g_bHaveMessage[iAuthor])
        return Plugin_Stop;

    if (iAuthor <= 0)
        return Plugin_Continue;

    if (convar_RestrictDeadChat.BoolValue && !IsPlayerAlive(iAuthor)) {
        PrintToChat(iAuthor, "Dead chat is currently restricted.");
        return Plugin_Stop;
    }
    
    //Trim the tag so there's no potential issues with retrieving the specified format rules.
    TrimString(szFlags);

    //It's easier just to use a handle here for an array instead of passing 2 arguments through both forwards with static arrays.
    ArrayList aRecipients = new ArrayList();

    int iTeam = GetClientTeam(iAuthor);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i)) {
            if (convar_AddGOTV.BoolValue && IsClientSourceTV(i)) {
                aRecipients.Push(GetClientUserId(i));
            }
            continue;
        }

        if (!IsPlayerAlive(iAuthor) && !convar_DeadChat.BoolValue && IsPlayerAlive(i))
            continue;

        if (!convar_AllChat.BoolValue && StrContains(szFlags, "_All") == -1 && iTeam != GetClientTeam(i))
            continue;
        
        aRecipients.Push(GetClientUserId(i));
    }

    //Retrieve the default values for coloring and use these as a base for developers to change later.
    bool bProcessColors = convar_ProcessColors.BoolValue;

    //Clients have the ability to color their chat if they manually type in color tags, this allows server operators to choose if they want their players the ability to do so.
    //Example: {red}This {white}is {green}a {blue}random {yellow}message.
    //Goes for both the name and the message.
    if ((convar_StripColors.BoolValue && !CheckCommandAccess(iAuthor, "", g_iFlags, true))) {
        LogMessage("Strip color for %d, need flag: %d", iAuthor, g_iFlags);
        CRemoveVariables(szName, sizeof(szName));
        CRemoveVariables(szText, sizeof(szText));
    }
    
    //Fire the pre-forward. https://i.ytimg.com/vi/A2a0Ht01qA8/maxresdefault.jpg
    Call_StartForward(g_Forward_OnChatMessage);
    Call_PushCellRef(iAuthor);
    Call_PushCell(aRecipients);
    Call_PushStringEx(szFlags, sizeof(szFlags), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushStringEx(szName, sizeof(szName), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushStringEx(szText, sizeof(szText), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCellRef(bProcessColors);

    //Retrieve the results here and use manage it.
    Action iResults;
    int error = Call_Finish(iResults);

    //We ran into a native error, gotta report it.
    if (error != SP_ERROR_NONE) {
        delete aRecipients;
        ThrowNativeError(error, "Global Forward 'CP_OnChatMessage' has failed to fire. [Error code: %i]", error);
        return Plugin_Continue;
    }
    if (iResults == Plugin_Stop) {
        delete aRecipients;
        return Plugin_Stop;
    }

    //Process colors based on the final results we have.
    if (bProcessColors) {
        Format(szText, sizeof(szText), "\x01%s\x01", szText);
        Format(szName, sizeof(szName), "\x03%s\x01", szName);
        CProcessVariables(szName, sizeof(szName), true, true);
        CProcessVariables(szText, sizeof(szText), true, true);

        //CSGO quirk where the 1st color in the line won't work..
        if (game == Engine_CSGO)
            Format(szText, sizeof(szText), " %s", szText);
    }

    //Retrieve the format template based on the flag name above we retrieved.
    if (!g_MessageFormats.GetString(szFlags, szFormat, sizeof(szFormat))) {
        strcopy(szFormat, sizeof(szFormat), "%s1: %s2");
    }

    ReplaceString(szFormat, sizeof(szFormat), "%s1", szName);
    ReplaceString(szFormat, sizeof(szFormat), "%s2", szText);

    DataPack pack = new DataPack();
    pack.WriteCell(iAuthor);
    pack.WriteCell(aRecipients);
    pack.WriteString(szFlags);
    pack.WriteString(szFormat);
    pack.WriteCell(iResults);
    
    RequestFrame(Frame_OnChatMessage, pack);

    // We need set this flag to true here and set false in the RequestFrame function
    // to ensure that only one of SayText2 can be processed.
    // Lately setting true is to avoid error causing client won't be able to say text
    if (!g_bHaveMessage[iAuthor]) {
        g_bHaveMessage[iAuthor] = true;
    }

    return Plugin_Stop;
}

public void Frame_OnChatMessage(DataPack pack)
{
    //Retrieve pack contents and what not, this part is obvious.
    pack.Reset();

    int iAuthor = pack.ReadCell();
    ArrayList aRecipients = pack.ReadCell();

    char szFlags[MAXLENGTH_FLAG];
    pack.ReadString(szFlags, sizeof(szFlags));

    char szFormat[MAXLENGTH_BUFFER];
    pack.ReadString(szFormat, sizeof(szFormat));
    
    Action iResults = pack.ReadCell();
    delete pack;

    //Send the message to clients.
    int iClient;
    for (int i = 0; i < aRecipients.Length; i++) {
        if ((iClient = GetClientOfUserId(aRecipients.Get(i))) > 0 && IsClientInGame(iClient)) {

            Call_StartForward(g_Forward_OnChatMessageSendPre);
            Call_PushCellRef(iAuthor);
            Call_PushCellRef(iClient);
            Call_PushString(szFlags);
            Call_PushStringEx(szFormat, sizeof(szFormat), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
            
            int error = Call_Finish(iResults);
            
            if (error != SP_ERROR_NONE) {
                delete aRecipients;
                ThrowNativeError(error, "Global Forward 'CP_OnChatMessageSendPre' has failed to fire. [Error code: %i]", error);
                g_bHaveMessage[iAuthor] = false;
                return;
            }
        
            if (iResults == Plugin_Handled)
                continue;
            //PrintToChat(iClient, szText);
            CSayText2(iClient, iAuthor, szFormat, "", "");
        }
    }

    //Finally... fire the post-forward after the message has been sent and processed. https://s-media-cache-ak0.pinimg.com/564x/a5/bb/3c/a5bb3c3e05089a40ef01ea082ac39e24.jpg
    Call_StartForward(g_Forward_OnChatMessagePost);
    Call_PushCell(iAuthor);
    Call_PushCell(aRecipients);
    Call_PushString(szFlags);
    Call_PushString(szFormat);
    Call_Finish();

    // We have done all the things, now client don't have message in progress.
    g_bHaveMessage[iAuthor] = false;

    //Close the recipients handle.
    delete aRecipients;
}

////////////////////
//Parse message formats for flags.
void GenerateMessageFormats()
{
    char sGame[64];
    GetGameFolderName(sGame, sizeof(sGame));

    char sConfig[PLATFORM_MAX_PATH];
    convar_Config.GetString(sConfig, sizeof(sConfig));
    
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);
    
    KeyValues kv = new KeyValues("chat-processor");

    if (kv.ImportFromFile(sPath) && kv.JumpToKey(sGame) && kv.GotoFirstSubKey(false))
    {
        g_MessageFormats.Clear();
        
        char sName[256]; char sValue[256];
        do
        {
            kv.GetSectionName(sName, sizeof(sName));
            kv.GetString(NULL_STRING, sValue, sizeof(sValue));
            
            TrimString(sName);
            g_MessageFormats.SetString(sName, sValue);
        }
        while (kv.GotoNextKey(false));

        LogMessage("Message formats generated for game '%s'.", sGame);
    }
    else
        LogError("Error parsing the flag message formatting config for game '%s', please verify its integrity.", sGame);
    
    delete kv;
}

////////////////////
//Flag format string native
public any Native_GetFlagFormatString(Handle plugin, int numParams)
{
    int iSize;
    GetNativeStringLength(1, iSize);

    char[] sFlag = new char[iSize + 1];
    GetNativeString(1, sFlag, iSize + 1);

    char sFormat[MAXLENGTH_BUFFER];
    g_MessageFormats.GetString(sFlag, sFormat, sizeof(sFormat));

    SetNativeString(2, sFormat, GetNativeCell(3));

    return 0;
}

////////////////////
//Tags

public void OnClientConnected(int client)
{
    delete g_Tags[client];
    g_Tags[client] = new ArrayList(ByteCountToCells(MAXLENGTH_NAME));

    g_bHaveMessage[client] = false;
}

public void OnClientDisconnect_Post(int client)
{
    delete g_Tags[client];
    g_NameColor[client][0] = '\0';
    g_ChatColor[client][0] = '\0';
}

public int Native_AddClientTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    int size;
    GetNativeStringLength(2, size); size++;
    
    char[] sTag = new char[size];
    GetNativeString(2, sTag, size);
    
    return AddClientTag(client, sTag);
}

bool AddClientTag(int client, const char[] tag)
{
    if (client == 0 || client > MaxClients || IsFakeClient(client))
        return false;
    
    int index = g_Tags[client].PushString(tag);
    
    Call_StartForward(g_Forward_OnAddClientTagPost);
    Call_PushCell(client);
    Call_PushCell(index);
    Call_PushString(tag);
    Call_Finish();
    
    return true;
}

public int Native_RemoveClientTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    int size;
    GetNativeStringLength(2, size); size++;
    
    char[] sTag = new char[size];
    GetNativeString(2, sTag, size);
    
    return RemoveClientTag(client, sTag);
}

bool RemoveClientTag(int client, const char[] tag)
{
    if (client == 0 || client > MaxClients || IsFakeClient(client))
        return false;
    
    bool found; char sTag[MAXLENGTH_NAME];
    for (int i = 0; i < g_Tags[client].Length; i++)
    {
        g_Tags[client].GetString(i, sTag, sizeof(sTag));
        
        if (StrContains(sTag, tag, false) == -1)
            continue;
            
        g_Tags[client].Erase(i);
        
        Call_StartForward(g_Forward_OnRemoveClientTagPost);
        Call_PushCell(client);
        Call_PushCell(i);
        Call_PushString(tag);
        Call_Finish();
        
        found = true;
    }
    
    return found;
}

public int Native_SwapClientTags(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    int size;
    
    GetNativeStringLength(2, size); size++;
    char[] sTag1 = new char[size];
    GetNativeString(2, sTag1, size);
    
    GetNativeStringLength(3, size); size++;
    char[] sTag2 = new char[size];
    GetNativeString(3, sTag2, size);
    
    return SwapClientTags(client, sTag1, sTag2);
}

bool SwapClientTags(int client, const char[] tag1, const char[] tag2)
{
    if (client == 0 || client > MaxClients || IsFakeClient(client))
        return false;
    
    int index1 = -1;
    if ((index1 = g_Tags[client].FindString(tag1)) == -1)
        return false;
    
    int index2 = -1;
    if ((index2 = g_Tags[client].FindString(tag2)) == -1)
        return false;
    
    g_Tags[client].SwapAt(index1, index2);
    
    Call_StartForward(g_Forward_OnSwapClientTagsPost);
    Call_PushCell(client);
    Call_PushCell(index1);
    Call_PushString(tag1);
    Call_PushCell(index2);
    Call_PushString(tag2);
    Call_Finish();
    
    return true;
}

public int Native_StripClientTags(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return StripClientTags(client);
}

bool StripClientTags(int client)
{
    if (g_Tags[client].Length == 0)
        return false;
    
    g_Tags[client].Clear();
    
    Call_StartForward(g_Forward_OnStripClientTagsPost);
    Call_PushCell(client);
    Call_Finish();
    
    return true;
}

public int Native_SetTagColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    int size;
    
    GetNativeStringLength(2, size); size++;
    char[] sTag = new char[size];
    GetNativeString(2, sTag, size);
    
    GetNativeStringLength(3, size); size++;
    char[] sColor = new char[size];
    GetNativeString(3, sColor, size);
    
    return SetTagColor(client, sTag, sColor);
}

bool SetTagColor(int client, const char[] tag, const char[] color)
{
    if (client <= 0 || client > MaxClients || IsFakeClient(client))
        return false;
    
    bool found; char sTag[MAXLENGTH_NAME];
    for (int i = 0; i < g_Tags[client].Length; i++)
    {
        g_Tags[client].GetString(i, sTag, sizeof(sTag));
        
        if (StrContains(sTag, tag, false) == -1)
            continue;
            
        CRemoveVariables(sTag, sizeof(sTag));
        Format(sTag, sizeof(sTag), "%s%s", color, sTag);
        
        g_Tags[client].SetString(i, sTag);
        
        Call_StartForward(g_Forward_OnSetTagColorPost);
        Call_PushCell(client);
        Call_PushCell(i);
        Call_PushString(tag);
        Call_PushString(color);
        Call_Finish();
        
        found = true;
    }
    
    return found;
}

public int Native_SetNameColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    int size;
    GetNativeStringLength(2, size); size++;
    
    char[] sColor = new char[size];
    GetNativeString(2, sColor, size);
    
    return SetNameColor(client, sColor);
}

bool SetNameColor(int client, const char[] color)
{
    if (client == 0 || client > MaxClients || IsFakeClient(client))
        return false;
    
    strcopy(g_NameColor[client], MAXLENGTH_NAME, color);
    
    Call_StartForward(g_Forward_OnSetNameColorPost);
    Call_PushCell(client);
    Call_PushString(color);
    Call_Finish();
    
    return true;
}

public int Native_SetChatColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    int size;
    GetNativeStringLength(2, size); size++;
    
    char[] sColor = new char[size];
    GetNativeString(2, sColor, size);
    
    return SetChatColor(client, sColor);
}

bool SetChatColor(int client, const char[] color)
{
    if (client == 0 || client > MaxClients || IsFakeClient(client))
        return false;
    
    strcopy(g_ChatColor[client], MAXLENGTH_MESSAGE, color);
     
    Call_StartForward(g_Forward_OnSetChatColorPost);
    Call_PushCell(client);
    Call_PushString(color);
    Call_Finish();
    
    return true;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors)
{
    bool changed;
    int size = g_Tags[author].Length;
    
    if (size > 0)
    {
        Format(name, MAXLENGTH_NAME, "%s%s", strlen(g_NameColor[author]) > 0 ? g_NameColor[author] : "{teamcolor}", name);
        
        char sTag[MAXLENGTH_NAME];
        for (int i = 0; i < size; i++)
        {
            g_Tags[author].GetString(i, sTag, sizeof(sTag));
            Format(name, MAXLENGTH_NAME, "%s%s", sTag, name);
        }
        
        changed = true;
    }
    else if (strlen(g_NameColor[author]) > 0)
    {
        Format(name, MAXLENGTH_NAME, "%s%s", g_NameColor[author], name);
        changed = true;
    }
    
    if (strlen(g_ChatColor[author]) > 0)
    {
        Format(message, MAXLENGTH_MESSAGE, "%s%s", g_ChatColor[author], message);
        changed = true;
    }
    
    return changed ? Plugin_Changed : Plugin_Continue;
}