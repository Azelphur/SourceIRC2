/*
       This file is part of SourceIRC.

    SourceIRC is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    SourceIRC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with SourceIRC.  If not, see <http://www.gnu.org/licenses/>.
*/

// This plugin provides the whoami command, useful for debugging permissions

#undef REQUIRE_PLUGIN
#include <sourceirc>
#include <sourceirc-ticket>

new g_iConfigSection;
new Handle:g_hTitles;
new Handle:g_hMethodNames;
new Handle:g_hMethods;
new Handle:g_hReportDisplay;

new String:g_szGameToIRCDisplay[IRC_MAXLEN];

enum ticketMethod
{
    Handle:ticketPlugin,
    Handle:ticketCallback,
    Handle:ticketForward,
    String:methodName[IRC_CMD_MAXLEN],
};

public Plugin:myinfo =
{
    name = "SourceIRC -> Ticket",
    author = "Azelphur",
    description = "Shows information about you, handy for debugging permissions.",
    version = IRC_VERSION,
    url = "http://Azelphur.com/project/sourceirc"
};

new bool:g_bSourceIRCLoaded = false;

public OnAllPluginsLoaded()
{
    if (!LibraryExists("sourceirc"))
    {
        return;
    }
    
    if (!g_bSourceIRCLoaded)
    {
        g_bSourceIRCLoaded = true;
        IRC_Loaded();
    }
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "sourceirc") && !g_bSourceIRCLoaded)
    {
        g_bSourceIRCLoaded = true;
        IRC_Loaded();
    }
}

public OnLibraryRemoved(const String:name[])
{
    if (StrEqual(name, "sourceirc"))
    {
        g_bSourceIRCLoaded = false;
    }
}

IRC_Loaded()
{
    LoadConfigs();
}

public OnPluginStart()
{
    RegPluginLibrary("sourceirc-ticket");
    g_hTitles = CreateArray(REASON_MAXLEN);
    g_hMethodNames = CreateArray(REASON_MAXLEN);
    g_hMethods = CreateArray(ticketMethod);
    g_hReportDisplay = CreateArray(IRC_MAXLEN);
}

LoadConfigs()
{
    decl String:szFile[512];
    BuildPath(Path_SM, szFile, sizeof(szFile), "configs/SourceIRC/ticket.cfg");
    if (!FileExists(szFile))
        SetFailState("Error in LoadConfigs(): ticket.cfg is missing from your configs/SourceIRC directory!");
    new Handle:smc = SMC_CreateParser();
    SMC_SetReaders(smc, SMC_NewSection, SMC_KeyValue, SMC_EndSection);
    g_iConfigSection = 0;
    SMC_ParseFile(smc, szFile);
}

public SMCResult:SMC_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
    switch (g_iConfigSection)
    {
        case 0:
        {
            if (StrEqual(key, "report_command"))
                RegConsoleCmd(value, Command_Report);
            else if (StrEqual(key, "ingame_reply_command"))
                RegConsoleCmd(value, Command_Reply);
            else if (StrEqual(key, "game_to_irc_display"))
                strcopy(g_szGameToIRCDisplay, sizeof(g_szGameToIRCDisplay), value);
            //else if (StrEqual(key, "report_irc_command"))
            //        IRC_RegCmd(value, Command_WhoAmI, "Shows information about you and your permissions.");
        }
        case 1:
        {
            PushArrayString(g_hMethodNames, key);
            PushArrayString(g_hTitles, value);
        }
        case 2:
        {
            PushArrayString(g_hReportDisplay, value);
        }
    }
    return SMCParse_Continue;
}

public SMCResult:SMC_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
    g_iConfigSection = 0;
    if (StrEqual(name, "menu", false))
        g_iConfigSection = 1;
    if (StrEqual(name, "report_display", false))
        g_iConfigSection = 2;
    return SMCParse_Continue;
}

public SMCResult:SMC_EndSection(Handle:smc)
{
    g_iConfigSection = 0;
    return SMCParse_Continue;
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("Ticket_CreateMethod", N_Ticket_CreateMethod);
    CreateNative("Ticket_SendReport", N_Ticket_SendReport);
    return APLRes_Success;
}

public N_Ticket_SendReport(Handle:plugin, numParams)
{
    decl String:szReason[REASON_MAXLEN];
    GetNativeString(1, szReason, sizeof(szReason));
    new client = GetNativeCell(2);
    new target = GetNativeCell(3);
    decl String:szLine[IRC_MAXLEN];
    new iArraySize = GetArraySize(g_hReportDisplay);
    for (new i = 0; i < iArraySize; i++)
    {
        GetArrayString(g_hReportDisplay, i, szLine, sizeof(szLine));
        FormatString(szLine, sizeof(szLine), client, target);
        ReplaceString(szLine, sizeof(szLine), "{REASON}", szReason);
        IRC_MsgFlaggedChannels("ticket", "%s", szLine);
    }
}
public N_Ticket_CreateMethod(Handle:plugin, numParams)
{
    decl method[ticketMethod];
    GetNativeString(1, method[methodName], sizeof(method[methodName]));
    
    method[ticketPlugin] = plugin;
    method[ticketCallback] = GetNativeCell(2);
    new Handle:hForward = CreateForward(ET_Event, Param_Cell, Param_String);
    AddToForward(hForward, plugin, Function:method[ticketCallback]);
    method[ticketForward] = hForward;
    PushArrayArray(g_hMethods, method[0]);
}

public Action:Command_Report(client, args)
{
    new iArraySize = GetArraySize(g_hMethodNames);
    if (GetArraySize(g_hMethodNames) == 0)
        return Plugin_Continue;
    decl String:szInfo[256], String:szDisp[256];
    new Handle:hMenu = CreateMenu(MenuHandler_Report);
    SetMenuTitle(hMenu, "Report a player");
    for (new i = 0; i < iArraySize; i++) 
    {
        GetArrayString(g_hMethodNames, i, szInfo, sizeof(szInfo));
        GetArrayString(g_hTitles, i, szDisp, sizeof(szDisp));
        AddMenuItem(hMenu, szInfo, szDisp);
    }
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public MenuHandler_Report(Handle:hMenu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        decl String:szInfo[256], String:szDisp[256];
        decl method[ticketMethod];
        GetMenuItem(hMenu, param2, szInfo, sizeof(szInfo), _, szDisp, sizeof(szDisp));
        for (new i = 0; i < GetArraySize(g_hMethods); i++)
        {
            GetArrayArray(g_hMethods, i, method[0]);
            if (StrEqual(method[methodName], szInfo))
            {
                Call_StartForward(method[ticketForward]);
                Call_PushCell(param1);
                Call_PushString(szDisp);
                Call_Finish();
            }
        }
    }
}

FormatString(String:line[], maxlen, client, target=0)
{
    decl String:szName[64];
    GetClientName(client, szName, sizeof(szName));
    decl String:szAuth[64];
    GetClientAuthString(client, szAuth, sizeof(szAuth));
    decl String:szUserID[8];
    IntToString(GetClientUserId(client), szUserID, sizeof(szUserID));
    ReplaceString(line, maxlen, "{NAME}", szName);
    ReplaceString(line, maxlen, "{STEAMID}", szAuth);
    ReplaceString(line, maxlen, "{USERID}", szUserID);
    if (target)
    {
        decl String:szTName[64];
        GetClientName(target, szTName, sizeof(szTName));
        decl String:szTAuth[64];
        GetClientAuthString(target, szTAuth, sizeof(szTAuth));
        decl String:szTUserID[8];
        IntToString(GetClientUserId(target), szTUserID, sizeof(szTUserID));
        ReplaceString(line, maxlen, "{TNAME}", szTName);
        ReplaceString(line, maxlen, "{TSTEAMID}", szTAuth);
        ReplaceString(line, maxlen, "{TUSERID}", szUserID);
    }
}


public Action:Command_Reply(client, args) {
    decl String:szText[256];
    GetCmdArgString(szText, sizeof(szText));
    if (StrEqual(szText, ""))
    {
        ReplyToCommand(client, "Usage: sm_to <text>");
        return Plugin_Handled;
    }
    decl String:szMessage[IRC_MAXLEN];
    strcopy(szMessage, sizeof(szMessage), g_szGameToIRCDisplay);
    FormatString(szMessage, sizeof(szMessage), client);
    ReplaceString(szMessage, sizeof(szMessage), "{TEXT}", szText);
    IRC_MsgFlaggedChannels("ticket", szMessage);
    ReplyToCommand(client, "To ADMIN :  %s", szText);
    return Plugin_Handled;
}
