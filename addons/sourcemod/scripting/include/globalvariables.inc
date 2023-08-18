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

#if !defined REQUIRE_PLUGIN
public void __pl_globalvariables_SetNTVOptional()
{
	MarkNativeAsOptional("CAddChatColor");
	MarkNativeAsOptional("CProcessVariables");
	MarkNativeAsOptional("CRemoveVariables");
	MarkNativeAsOptional("CPrintToChat");
	MarkNativeAsOptional("CPrintToChatAll");
	MarkNativeAsOptional("CSayText2");
	MarkNativeAsOptional("CSayText2All");
	MarkNativeAsOptional("ParseCondition");
    MarkNativeAsOptional("CalculateRPN");
}
#endif

public SharedPlugin __pl_globalvariables =
{
	name = "globalvariables",
	file = "globalvariables.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
}; 