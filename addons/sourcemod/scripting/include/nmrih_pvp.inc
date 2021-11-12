enum TeamType {
    T, CT
}

enum struct PlayerProps {
    TeamType m_Team;
    bool m_bCanBuy;
    int m_aOwnedItem[20];
    int m_iMoney;
}

enum struct WeaponProps {
    char m_szDisplayName[20];
    char m_szClassName[20];
    int m_iCost;
}

public bool IsAliveClient(int client)
{
    if (client >= 1 && client <= MaxClients)
        if(IsClientInGame(client))
            if(!IsClientSourceTV(client))
                return IsPlayerAlive(client);
    return false;
}