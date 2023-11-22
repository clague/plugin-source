#include <dhooks>
#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "0.1"

public Plugin info = {
    name = "Happy Slash",
    author = "clagura",
    description = "Make you slash happily😀",
    version = PLUGIN_VERSION
};

DynamicDetour g_fnDrainMeleeSwingStamina, g_fnSetStamina;
int g_offWeaponIdleTime;
//int g_offNextPrimaryAttack;
enum struct PlayerState {
    bool bInSlashing;
    int nSlashCount;
    float fStaminaCost;
    int iWeapon;

    void Default() {
        this.bInSlashing = false;
        this.nSlashCount = 0;
        this.fStaminaCost = 0.0;
        this.iWeapon = -1;
    }
}

PlayerState g_aStates[MAXPLAYERS + 1];

public void OnPluginStart() {

    for (int i = 0; i <= MAXPLAYERS; i++) {
        g_aStates[i].Default();
    }

    g_offWeaponIdleTime = FindSendPropInfo("CBaseCombatWeapon", "m_flTimeWeaponIdle");
    //g_offNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");

    GameData gamedata = new GameData("happyslash.games");
    if (gamedata == null) {
        SetFailState("Failed to load GameData");
    } else {
        LogMessage("Load gamedata success");
    }

    Address addrCheckHit = gamedata.GetMemSig("CNMRiH_MeleeBase::CheckMeleeHit");
    if (addrCheckHit == Address_Null) {
        // SetFailState("Failed to get memsig to CNMRiH_MeleeBase::CheckMeleeHit");
    }

    Address addrDrainStamina = gamedata.GetMemSig("CNMRiH_MeleeBase::DrainMeleeSwingStamina");
    if (addrDrainStamina == Address_Null) {
        SetFailState("Failed to get address of CNMRiH_MeleeBase::DrainMeleeSwingStamina");
    }

    g_fnDrainMeleeSwingStamina = new DynamicDetour(addrDrainStamina, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
    g_fnDrainMeleeSwingStamina.Enable(Hook_Pre, DHook_DrainMeleeSwingStamina);
    g_fnDrainMeleeSwingStamina.Enable(Hook_Post, DHook_DrainMeleeSwingStaminaPost);

    Address addrSetStamina = gamedata.GetMemSig("CSDKPlayerShared::SetStamina");
    if (addrSetStamina == Address_Null) {
        SetFailState("Failed to get address of CSDKPlayerShared::SetStamina");
    }

    g_fnSetStamina = new DynamicDetour(addrSetStamina, CallConv_THISCALL, ReturnType_Void, ThisPointer_Address);
    g_fnSetStamina.AddParam(HookParamType_Float)
    g_fnSetStamina.Enable(Hook_Pre, DHook_SetStamina);
}

public void OnClientPutInServer(int iClient) {
    g_aStates[iClient].Default();
}

bool g_bInDrainStamina = false;
int g_iDrainWeapon = 0;
MRESReturn DHook_DrainMeleeSwingStamina(int pThis) {
    // LogMessage("In DHook_DrainMeleeSwingStamina");
    g_iDrainWeapon = pThis;
    g_bInDrainStamina = true;
    return MRES_Ignored;
}

MRESReturn DHook_DrainMeleeSwingStaminaPost(int pThis) {
    // LogMessage("In DHook_DrainMeleeSwingStaminaPost");
    g_bInDrainStamina = false;
    g_iDrainWeapon = -1;
    return MRES_Ignored;
}

MRESReturn DHook_SetStamina(int pThis, DHookParam params) {
    // LogMessage("In DHook_SetStamina");
    if (g_bInDrainStamina) {
        if (!IsValidEntity(g_iDrainWeapon)) {
            return MRES_Ignored;
        }
        int iClient = GetEntPropEnt(g_iDrainWeapon, Prop_Send, "m_hOwnerEntity");
        g_aStates[iClient].iWeapon = g_iDrainWeapon;

        float fOldStamina = GetEntPropFloat(iClient, Prop_Send, "m_flStamina");
        float fNewStamina = params.Get(1);

        g_aStates[iClient].nSlashCount++;
        if (g_aStates[iClient].nSlashCount == 1) {
            g_aStates[iClient].fStaminaCost = fOldStamina - fNewStamina;
        } else if (fNewStamina < fOldStamina) {
            g_aStates[iClient].fStaminaCost /= 3.0;
            fNewStamina = fOldStamina - g_aStates[iClient].fStaminaCost;
            // LogMessage("New stamina: %f", fNewStamina);
            if (fNewStamina > 0.0) {
                params.Set(1, fNewStamina);
                return MRES_ChangedHandled;
            }
        }
        
    }
    return MRES_Ignored;
}

public void OnGameFrame() {
    for (int iClient = 1; iClient <= MaxClients; iClient++) {
        if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsValidEntity(g_aStates[iClient].iWeapon)) {
            continue;
        }
        float fRemainTime = GetEntDataFloat(g_aStates[iClient].iWeapon, g_offWeaponIdleTime) - GetGameTime();
        if (!g_aStates[iClient].bInSlashing && fRemainTime >= 0.1) {
            g_aStates[iClient].bInSlashing = true;
        } else if (g_aStates[iClient].bInSlashing && fRemainTime < 0.1) {
            // LogMessage("Complete a slash, count: %d, remain time: %f", g_aStates[iClient].nSlashCount, fRemainTime);
            g_aStates[iClient].Default();
        }
    }
}

bool IsValidClient(int iClient) {
    return IsClientInGame(iClient) && !IsClientTimingOut(iClient) && !IsClientInKickQueue(iClient) && !IsFakeClient(iClient);
}