#if defined _getoverit_included
	#endinput
#endif
#define _getoverit_included

/**
 * Fetch colored name of the client based on his extraction times.
 *
 * @param iClient           Client index.
 * @param szColoredName     Colored name of the client.
 * @param nMaxLen           Max length of the receive buffer.
 * @return                  Writen bytes count on success, nagetive value on failure.
 */
native int FetchColoredName(int iClient, char[] szColoredName, int nMaxLen);

public SharedPlugin __pl_getoverit =
{
	name = "getoverit",
	file = "getoverit.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_getoverit_SetNTVOptional()
{
	MarkNativeAsOptional("FetchColoredName");
}
#endif