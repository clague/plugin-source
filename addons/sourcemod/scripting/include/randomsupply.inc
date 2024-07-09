public SharedPlugin __pl_randomsupply = 
{
    name = "randomsupply",
    file = "randomsupply.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
 
#if !defined REQUIRE_PLUGIN
public void __pl_randomsupply_SetNTVOptional()
{
    MarkNativeAsOptional("SetGived");
}
#endif

native any SetGived(int client, bool gived);