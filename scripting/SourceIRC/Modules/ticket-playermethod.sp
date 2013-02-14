#include <adminmenu>
#undef REQUIRE_PLUGIN
#include <sourceirc-ticket>
#include <sourceirc>

new String:g_szReasons[MAXPLAYERS+1][REASON_MAXLEN]

public OnAllPluginsLoaded()
{
    Ticket_CreateMethod("player", MenuCallback);
}

public MenuCallback(client, String:reason[])
{
    new Handle:hMenu = CreateMenu(MenuHandler_Player);
    decl String:szName[64], String:szUserID[8];
    for (new i = 1;i < MaxClients; i++)
    {
        if (IsClientConnected(i) && !IsFakeClient(i))
        {
            GetClientName(i, szName, sizeof(szName));
            IntToString(GetClientUserId(i), szUserID, sizeof(szUserID));
            AddMenuItem(hMenu, szUserID, szName);
        }
    }
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
    strcopy(g_szReasons[client], sizeof(g_szReasons[]), reason);
}

public MenuHandler_Player(Handle:hMenu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
        decl String:szInfo[256], String:szDisp[256];
        GetMenuItem(hMenu, param2, szInfo, sizeof(szInfo), _, szDisp, sizeof(szDisp));
        new userid = StringToInt(szInfo);
        new target = GetClientOfUserId(userid);
        if (!target)
            return;
        Ticket_SendReport(g_szReasons[param1], param1, target);
    }
}
