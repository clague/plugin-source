native bool CAddChatColor(const char[] name, const char[] color);

native bool CProcessVariables(char[] szMessage, int nMaxLength, bool isChat=true, bool isVariable=false);

native bool CRemoveVariables(char[] szMessage, int nMaxLength);

native bool CPrintToChat(int iClient, int iAuthor=0, const char[] szMessage, any ...);

native bool CPrintToChatAll(int iAuthor=0, const char[] szMessage, any ...);

native bool CSayText2(int iClient, int iAuthor, const char[] szFlags, const char[] szName, const char[] szText);

native bool CSayText2All(int iAuthor, const char[] szFlags, const char[] szName, const char[] szText);

native bool ParseCondition(const char[] szBuffer, int nMaxLength, ArrayStack RPNStack, ArrayList SymbolList);

native bool CalculateRPN(ArrayStack RPNStack, ArrayList SymbolList, int& iRes, bool bNotFoundError=true);

#define MAX_MESSAGE_LEN 254
#define MAX_SAYTEXT2_LEN 254

#define MAX_TOKEN_COUNT 1024
#define MAX_TOKEN_LENGTH 32