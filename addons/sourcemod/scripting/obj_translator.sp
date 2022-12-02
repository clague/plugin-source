#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
    name = "Obj Translator",
    author = "clagura",
    description = "NMRiH Objective Translate",
    version = "1.0",
    url = "https://steamcommunity.com/id/wwwttthhh/"
};

StringMap objectives_translate;
KeyValues objectives_original;
ConVar lang;

char config_path[] = "configs/ObjectiveT";
char lang_list[64][10];
int lang_count = 0;

char client_lang[MAXPLAYERS][10];
char current_obj_id[64];
char current_map_name[128];

public void OnPluginStart() {
    LoadTranslations("obj.translator.phrases");
    
    objectives_translate = new StringMap();
    objectives_original = new KeyValues("Original");

    lang = CreateConVar("obj_translate_lang", "chi zho ko jp", "Space-separated list of language entries to include in auto generated translation files");
    HookConVarChange(lang, OnConVarChange);

    char lang_str[256];
    lang.GetString(lang_str, sizeof(lang_str));

    lang_count = ExplodeString(lang_str, " ", lang_list, 64, 10);

    RegAdminCmd("sm_reloadtrans", CommandReloadTrans, ADMFLAG_GENERIC);
    RegAdminCmd("sm_trans", CommandTranslate, ADMFLAG_GENERIC);
    HookEvent("state_change", OnStateChange, EventHookMode_Pre);
}

public void OnPluginEnd() {
    delete objectives_translate;
    delete objectives_original;
}

public void OnConVarChange(Handle cvar, const char[] oldValue, const char[] newValue) {
    if (cvar == lang)
    {
        char lang_str[256];
        lang.GetString(lang_str, sizeof(lang_str));

        lang_count = ExplodeString(lang_str, " ", lang_list, 64, 10);
    }
}

public void OnClientConnected(int client) {
    GetLanguageInfo(GetClientLanguage(client), client_lang[client], sizeof(client_lang[]));

    for (int i = 0; i < lang_count; i++)
    {
        if (StrEqual(client_lang[client], lang_list[i], false))
            return ;
    }

    FormatEx(client_lang[client], sizeof(client_lang[]), "Original");
}

public void OnConfigsExecuted() { // we need wait for obj_translate_lang to be set
    GetCurrentMap(current_map_name, sizeof(current_map_name));
    GetMapDisplayName(current_map_name, current_map_name, sizeof(current_map_name));

    delete objectives_original;
    delete objectives_translate;
    objectives_translate = new StringMap();
    objectives_original = new KeyValues("Original");

    ReadFromNmo(current_map_name);
    SetGameText();
    ReadFromConfigs(current_map_name);

    HookUserMessage(GetUserMessageId("HudMsg"), GameTextHook, true);
}

public void OnMapEnd() {
    UnhookUserMessage(GetUserMessageId("HudMsg"), GameTextHook, true);
}

public Action OnStateChange(Handle event, const char[] name, bool dontBroadcast) {
    int state = GetEventInt(event, "state");
    if (state == 0) {
    }
    else if (state == 2 || state == 3) { // 2 - practice freeze end ;;; 3 - round start
        SetGameText();
    }
    else if (state == 5) { //All extracted
        PrintToChatAll("\x04%t\x01：%t","Mission", "OnAllPlayersExtracted");
    }
    else if (state == 6) { //Extraction expired
        PrintToChatAll("\x04%t\x01：%t","Mission", "OnExtractionExpired");
    }
    PrintToServer("State: %d", state);
    return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname){
    if(StrContains(classname, "nmrih_objective_boundary", false) != -1) {
        HookSingleEntityOutput(entity, "OnObjectiveBegin", OnObjectiveBegin);
    }
}

public void OnObjectiveBegin(const char[] output, int caller, int activator, float delay) {
    char name[64];
    GetEntPropString(activator, Prop_Data, "m_iName", name, sizeof(name));
    FormatEx(current_obj_id, sizeof(current_obj_id), name);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i)) continue;
        char message[256];
        bool is_translated = GetTranslatedMessage(i, name, message, sizeof(message));
        if (is_translated)
            PrintCenterText(i, message);
        PrintToChat(i, "\x04%t\x01：%s","Mission", message);
    }
}

#define IN_Compass		(1 << 28)
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2]) {
    if(buttons & IN_Compass) {
        if (!IsClientInGame(client)) return Plugin_Continue;
        char message[256];
        bool is_translated = GetTranslatedMessage(client, current_obj_id, message, sizeof(message));
        if (is_translated)
            PrintCenterText(client, message);
    }
    return Plugin_Continue;
}

public bool GetTranslatedMessage(int client, char[] obj_id,  char[] translated, int maxlen) {
    char obj_id_lang[80];
    FormatEx(obj_id_lang, sizeof(obj_id_lang), "%s-%s", client_lang[client], obj_id);
    if (!objectives_translate.GetString(obj_id_lang, translated, maxlen) || StrEqual(translated, "NoData", false)) {
        objectives_original.GetString(obj_id, translated, maxlen, "NoData");
        return false;
    }
    return true;
}

public Action CommandReloadTrans(int client, int args) {
    UnhookUserMessage(GetUserMessageId("HudMsg"), GameTextHook, true);
    OnConfigsExecuted();
    return Plugin_Handled;
}

public Action CommandTranslate(int client, int n_args) {
    char s_arg[256], lang_code[10];
    int flag = 1;
    GetCmdArgString(s_arg, sizeof(s_arg));

    for (int i = 0; i < lang_count; i++) {
        if (StrContains(s_arg, lang_list[i], false) == 0) {
            FormatEx(lang_code, sizeof(lang_code), lang_list[i]);
            ReplaceStringEx(s_arg, sizeof(s_arg), lang_code, "");
            flag = 0;
            break;
        }
    }

    if (flag == 1) 
        FormatEx(lang_code, sizeof(lang_code), client_lang[client]);

    if (StrEqual(lang_code, "Original", false)) {
        PrintToChat(client, "Your language isn't in language list");
        return Plugin_Handled;
    }
    TrimString(s_arg);

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "%s/%s.ini", config_path, current_map_name);

    KeyValues kv = CreateKeyValues("Objective");
    kv.ImportFromFile(path);

    kv.JumpToKey(lang_code, true);

    char obj_id_lang[80];
    FormatEx(obj_id_lang, sizeof(obj_id_lang), "%s-%s", lang_code, current_obj_id);
    kv.SetString(current_obj_id, s_arg);
    objectives_translate.SetString(obj_id_lang, s_arg);

    kv.Rewind();
    kv.ExportToFile(path);
    delete kv;

    return Plugin_Handled;
}

int ReadFromConfigs(const char map_name[128]) {
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "%s/%s.ini", config_path, map_name);

    KeyValues kv = CreateKeyValues("Objective");
    kv.ImportFromFile(path);

    kv.DeleteKey("Original");
    kv.JumpToKey("Original", true);
    kv.Import(objectives_original);

    kv.Rewind();
    if (!kv.JumpToKey("chi")) {
        if (kv.JumpToKey("zho")) {
            KeyValues kv2 = CreateKeyValues("zho");
            KvCopySubkeys(kv, kv2);
            
            kv.SetSectionName("chi");
            kv.GoBack();
            kv.JumpToKey("zho", true);
            kv.Import(kv2);

            kv.Rewind();
            delete kv2;
        }
    }
    kv.Rewind();

    for (int i = 0; i < lang_count; i++) {
        char cur_section[64];
        if (!kv.JumpToKey(lang_list[i])) {
            kv.JumpToKey(lang_list[i], true);
            if (!objectives_original.GotoFirstSubKey(false))
            {
                LogError("No objective! Please check nmo file.");
                return -1;
            }
            do {
                objectives_original.GetSectionName(cur_section, sizeof(cur_section));
                kv.SetString(cur_section, "NoData");

                char obj_id_lang[80];
                FormatEx(obj_id_lang, sizeof(obj_id_lang), "%s-%s", lang_list[i], cur_section);
                objectives_translate.SetString(obj_id_lang, "NoData");
            } while(objectives_original.GotoNextKey(false));
        }
        else {
            if (!kv.GotoFirstSubKey(false))
                continue;
            do {
                char translate[256];
                kv.GetSectionName(cur_section, sizeof(cur_section));
                kv.GetString(NULL_STRING, translate, sizeof(translate));

                char obj_id_lang[80];
                FormatEx(obj_id_lang, sizeof(obj_id_lang), "%s-%s", lang_list[i], cur_section);
                objectives_translate.SetString(obj_id_lang, translate);
            } while(kv.GotoNextKey(false));
        }
        objectives_original.Rewind();
        kv.Rewind();
    }
    kv.ExportToFile(path);
    delete kv;
    return 0;
}

int ReadFromNmo(const char map_name[128]) {
    char path[PLATFORM_MAX_PATH];
    FormatEx(path, sizeof(path), "maps/%s.nmo", map_name);

    File f = OpenFile(path, "rb", true,  NULL_STRING);

    if (!f) {
        LogError("Can't load %s.nmo", map_name);
        return -1;
    }

    int head, version;
    f.ReadInt8(head);
    f.ReadInt32(version);

    if (head != 'v' || version != 1)
    {
        CloseHandle(f);
        LogError("Invalid nmo file! Plugin outdate?");
        return -1;
    }

    int obj_count, antiobj_count, extraction_count;
    f.ReadInt32(obj_count);
    f.ReadInt32(antiobj_count);
    f.ReadInt32(extraction_count);

    for (int i = 0; i < obj_count; i++) {
        f.Seek(4, SEEK_CUR); // Skip objective ID

        SeekFileTillChar(f, '\0');
        
        char description[256];
        f.ReadString(description, sizeof(description));

        char obj_id[64];
        f.ReadString(obj_id, sizeof(obj_id));

        if (obj_id[0]) {
            objectives_original.SetString(obj_id, description);
        }

        // Skip item names
        int itemCount;
        f.ReadInt32(itemCount);
        if (itemCount > 0)
            while (itemCount--)
                SeekFileTillChar(f, '\0');		

        // Skip objective links
        int linksCount;
        f.ReadInt32(linksCount);
        if (linksCount > 0) 
            f.Seek(linksCount * 4, SEEK_CUR);
    }
    return 0;
}

public void SetGameText() {
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "game_text")) != -1) {
        char name[128], message[256];
        GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
        GetEntPropString(entity, Prop_Data, "m_iszMessage", message, sizeof(message));
        if (StrContains(message, "<GameText>", false)) {
            Format(name, sizeof(name), "<GameText>%d|%s", GetEntProp(entity, Prop_Data, "m_iHammerID"), name);
            objectives_original.SetString(name, message);
            DispatchKeyValue(entity, "message", name); //in GameTextHook, we can know the game text's id
        }
    }
}

public Action GameTextHook(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
    int channel = msg.ReadByte();
    float x = msg.ReadFloat();
    float y = msg.ReadFloat();
    int effect = msg.ReadByte();
    int r1 = msg.ReadByte();
    int g1 = msg.ReadByte();
    int b1 = msg.ReadByte();
    int a1 = msg.ReadByte();
    int r2 = msg.ReadByte();
    int g2 = msg.ReadByte();
    int b2 = msg.ReadByte();	
    int a2 = msg.ReadByte();
    float fadeIn = msg.ReadFloat();
    float fadeOut = msg.ReadFloat();
    float holdTime = msg.ReadFloat();
    float fxTime = msg.ReadFloat();

    static char text[256];
    if (msg.ReadString(text, sizeof(text)) <= 0) {
        return Plugin_Handled;
    }
    if (StrContains(text, "<GameText>", false) != 0) {
        return Plugin_Continue;
    }
        
    DataPack data = new DataPack();
    data.WriteCell(channel);
    data.WriteFloat(x);
    data.WriteFloat(y);
    data.WriteCell(effect);
    data.WriteCell(r1);
    data.WriteCell(g1);
    data.WriteCell(b1);
    data.WriteCell(a1);
    data.WriteCell(r2);
    data.WriteCell(g2);
    data.WriteCell(b2);
    data.WriteCell(a2);
    data.WriteFloat(fadeIn);
    data.WriteFloat(fadeOut);
    data.WriteFloat(holdTime);
    data.WriteFloat(fxTime);
    data.WriteString(text);

    data.WriteCell(playersNum);
    for(int i; i < playersNum; i++)
        data.WriteCell(GetClientSerial(players[i]));
    RequestFrame(SendHudMessage, data);

    return Plugin_Handled;
}

void SendHudMessage(DataPack data) {
    data.Reset();

    int channel = data.ReadCell();
    float x = data.ReadFloat();
    float y = data.ReadFloat();
    int r1 = data.ReadCell();
    int g1 = data.ReadCell();
    int b1 = data.ReadCell();
    int a1 = data.ReadCell();
    int r2 = data.ReadCell();
    int g2 = data.ReadCell();
    int b2 = data.ReadCell();
    int a2 = data.ReadCell();
    int effect = data.ReadCell();
    float fadeIn = data.ReadFloat();
    float fadeOut = data.ReadFloat();
    float holdTime = data.ReadFloat();
    float fxTime = data.ReadFloat();

    char text[256];
    data.ReadString(text, sizeof(text));

    int playersNum = data.ReadCell();
    for (int i = 0; i < playersNum; i++)
    {
        int client = GetClientFromSerial(data.ReadCell());  
        Handle msg_new = StartMessageOne("HudMsg", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

        char translated[256];
        GetTranslatedMessage(client, text, translated, sizeof(translated));
    
        BfWrite bf = UserMessageToBfWrite(msg_new);
        bf.WriteByte(channel);
        bf.WriteFloat(x);
        bf.WriteFloat(y);
        bf.WriteByte(r1);
        bf.WriteByte(g1);
        bf.WriteByte(b1);
        bf.WriteByte(a1);
        bf.WriteByte(r2);
        bf.WriteByte(g2);
        bf.WriteByte(b2);
        bf.WriteByte(a2);
        bf.WriteByte(effect);
        bf.WriteFloat(fadeIn);
        bf.WriteFloat(fadeOut);
        bf.WriteFloat(holdTime);
        bf.WriteFloat(fxTime);
        bf.WriteString(translated);
        EndMessage();
    }
}

void SeekFileTillChar(File file, char c)
{
    int i;
    do {
        file.ReadInt8(i);
    } while (i != c);	
}
