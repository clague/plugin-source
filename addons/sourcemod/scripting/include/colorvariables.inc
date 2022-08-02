native bool CAddChatColor(const char[] name, const char[] color);

native bool CProcessVariables(char[] szMessage, int nMaxLength, bool isChat=true, bool isVariable=false);

native bool CPrintToChat(int iClient, int iAuthor=0, const char[] szMessage, any ...);

native bool CPrintToChatAll(int iAuthor=0, const char[] szMessage, any ...);