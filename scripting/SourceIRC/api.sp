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

/* All the natives and code to call the callbacks are in here */

InitApi()
{
    RegPluginLibrary("sourceirc");
    g_hEvents = CreateArray(ircEvent);
    g_hCmds = CreateArray(ircCmd);
    g_hArgs = CreateArray(IRC_MAXLEN);
    g_hConnected = CreateGlobalForward("IRC_Connected", ET_Ignore);
    g_hUserCreated = CreateGlobalForward("IRC_UserCreated", ET_Ignore, Param_String);
}

HandleLine(String:nick[])
{
    decl String:szCmd[IRC_MAXLEN];
    GetArrayString(g_hArgs, 0, szCmd, sizeof(szCmd));
    if (StrEqual(szCmd, "PRIVMSG")) // Is it a privmsg? check if it's a command.
    {
        decl String:szMessage[IRC_MAXLEN], String:szChannel[IRC_CHANNEL_MAXLEN];
        GetArrayString(g_hArgs, 1, szChannel, sizeof(szChannel));
        GetArrayString(g_hArgs, 2, szMessage, sizeof(szMessage));
        new iArgPos = IsTrigger(szChannel, szMessage);
        if (iArgPos != -1)
        {
            RunCmd(nick, szMessage[iArgPos]);
        }
    }
    
    new iArraySize = GetArraySize(g_hEvents);
    decl event[ircEvent];
    for (new i = 0; i < iArraySize; i++)
    {
        GetArrayArray(g_hEvents, i, event[0]);
        if (StrEqual(event[eventName], szCmd, false))
        {
            Call_StartForward(event[eventForward]);
            Call_PushString(nick);
            Call_PushCell(GetArraySize(g_hArgs)-1);
            Call_Finish();
        }
    }
}

IsTrigger(const String:channel[], const String:message[])
{
    decl String:szArg1[IRC_MAXLEN], String:szChannelCmdPrefix[32];

    new Handle:hChannel;
    new Handle:hSettings;
    if (!GetTrieValue(g_hChannelsTrie, channel, hChannel) || !GetTrieValue(hChannel, "settings", hSettings) || !GetTrieString(hSettings, "cmd_prefix", szChannelCmdPrefix, sizeof(szChannelCmdPrefix)))
        szChannelCmdPrefix[0] = '\x00';

    // Strip off the first word in the message
    for (new i = 0; i <= strlen(message); i++)
    {
        if (message[i] == ' ')
        {
            szArg1[i] = '\x00';
            break;
        }
        szArg1[i] = message[i];
    }
    
    new iStartPos = -1;
    if (StrEqual(channel, g_szNick, false)) // If it's a query with us, it's obviously a trigger.
        iStartPos = 0;
    else if (!strncmp(szArg1, g_szNick, strlen(g_szNick), false) && !(strlen(szArg1)-strlen(g_szNick) > 1)) // If arg1 is our nickname and optionally one more character, it's a trigger (Accounts for tab complete putting a symbol after the nick)
        iStartPos = strlen(szArg1);
    else if (!StrEqual(g_szCmdPrefix, "") && !strncmp(szArg1, g_szCmdPrefix, strlen(g_szCmdPrefix))) // Is it using the global command prefix?
        iStartPos = strlen(g_szCmdPrefix);
    else if (!StrEqual(szChannelCmdPrefix, "") && !strncmp(szArg1, szChannelCmdPrefix, strlen(szChannelCmdPrefix))) // Is it using the channel command prefix?
        iStartPos = strlen(szChannelCmdPrefix);
    else // Is the first word a command with the no prefix flag
    {
        decl cmd[ircCmd];
        new iArraySize = GetArraySize(g_hCmds);
        for (new i = 0; i < iArraySize; i++)
        {
            GetArrayArray(g_hCmds, i, cmd[0]);
            if (cmd[cmdFlag] & IRC_CMDFLAG_NOPREFIX)
            {
                if (StrEqual(szArg1, cmd[cmdName], false))
                {
                    iStartPos = 0;
                    break;
                }
            }
        }
    }
    
    if (iStartPos != -1) // If it's a command, find where the first argument starts
    {
        for (new i = iStartPos; i <= strlen(message); i++)
        {
            if (message[i] != ' ')
                break;
            iStartPos++;
        }
    }
    return iStartPos; // Now we should be returning where the first argument starts, or -1 if it's not a trigger.
}

RunCmd(const String:hostmask[], const String:message[])
{
    decl String:szCmd[IRC_CMD_MAXLEN], String:szArg[IRC_MAXLEN];
    new iNewPos = 0;
    new iPos = BreakString(message, szCmd, sizeof(szCmd));
    strcopy(g_szArgString, sizeof(g_szArgString), message[iPos]);
    strcopy(g_szHostmask, sizeof(g_szHostmask), hostmask);
    while (iPos != -1)
    {
        iPos = BreakString(message[iNewPos], szArg, sizeof(szArg));
        iNewPos += iPos;
        PushArrayString(g_hArgs, szArg);
    }
    decl String:szNick[IRC_NICK_MAXLEN];
    IRC_GetNickFromHostMask(hostmask, szNick, sizeof(szNick));
    new Action:aReturnValue = Plugin_Continue;
    new Action:aNewReturnValue = Plugin_Continue;
    new iArraySize = GetArraySize(g_hCmds);
    decl cmd[ircCmd];
    for (new i = 0; i < iArraySize; i++)
    {
        GetArrayArray(g_hCmds, i, cmd);
        if (StrEqual(szCmd, cmd[cmdName], false))
        {
            strcopy(g_szCurrentCmd, sizeof(g_szCurrentCmd), szCmd);
            if (IRC_CheckCommandAccess(szNick, szCmd, cmd[cmdPermissions]))
            {
                new Handle:f = CreateForward(ET_Event, Param_String, Param_Cell);
                AddToForward(f, cmd[cmdPlugin], Function:cmd[cmdCallback]);
                Call_StartForward(f);
                Call_PushString(szNick);
                Call_PushCell(GetArraySize(g_hArgs)-1);
                Call_Finish(_:aNewReturnValue);
                if (aNewReturnValue > aReturnValue)
                    aReturnValue = aNewReturnValue;
                CloseHandle(f);
            }
            else
            {
                IRC_ReplyToCommand(szNick, "%t", "Access Denied", szCmd);
                return;
            }
            g_szCurrentCmd[0] = '\0';
        }
    }
    
    if (aReturnValue == Plugin_Continue) 
        IRC_ReplyToCommand(szNick, "%t", "Unknown Command", szCmd);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    // Create all the magical natives
    CreateNative("IRC_ChannelHasFlag", N_IRC_ChannelHasFlag);
    CreateNative("IRC_CheckCommandAccess", N_IRC_CheckCommandAccess);
    CreateNative("IRC_GetCmdArgString", N_IRC_GetCmdArgString);
    CreateNative("IRC_GetEventArg", N_IRC_GetEventArg);
    CreateNative("IRC_GetCmdArg", N_IRC_GetCmdArg);
    CreateNative("IRC_GetEventHostMask", N_IRC_GetEventHostMask);
    CreateNative("IRC_GetHostMask", N_IRC_GetHostMask);
    CreateNative("IRC_GetUserFlagBits", N_IRC_GetUserFlagBits);
    CreateNative("IRC_HookEvent", N_IRC_HookEvent);
    CreateNative("IRC_MsgFlaggedChannels", N_IRC_MsgFlaggedChannels);
    CreateNative("IRC_ReplyToCommand", N_IRC_ReplyToCommand);
    CreateNative("IRC_RegAdminCmd", N_IRC_RegAdminCmd);
    CreateNative("IRC_RegCmd", N_IRC_RegCmd);
    CreateNative("IRC_Send", N_IRC_Send);
    CreateNative("IRC_SetUserFlagBits", N_IRC_SetUserFlagBits);
    return APLRes_Success;
}

public N_IRC_ChannelHasFlag(Handle:plugin, numParams)
{
    decl String:szFlag[64], String:szValue[512], String:szChannel[IRC_CHANNEL_MAXLEN];
    GetNativeString(1, szChannel, sizeof(szChannel));
    GetNativeString(2, szFlag, sizeof(szFlag));
    new Handle:hChannel;
    new Handle:hFlags;
    if (!GetTrieValue(g_hChannelsTrie, szChannel, hChannel) || !GetTrieValue(hChannel, "flags", hFlags) || !GetTrieString(hFlags, szFlag, szValue, sizeof(szValue)))
        return false;
    return true;
}

public N_IRC_CheckCommandAccess(Handle:plugin, numParams)
{
    decl String:szNick[IRC_NICK_MAXLEN];
    GetNativeString(1, szNick, sizeof(szNick));
    new flags = IRC_GetUserFlagBits(szNick);
    new cmdflags = GetNativeCell(3);
    if (cmdflags & flags || cmdflags == 0 || flags & ADMFLAG_ROOT)
        return true;
    return false;
}

public N_IRC_GetCmdArg(Handle:plugin, numParams)
{
    new iArgNum = GetNativeCell(1);
    if (iArgNum == 0)
    {
        SetNativeString(2, g_szCurrentCmd, GetNativeCell(3));
        return strlen(g_szCurrentCmd);
    }
    else
    {
        decl String:szCmdArg[IRC_MAXLEN];
        GetArrayString(g_hArgs, GetNativeCell(1), szCmdArg, sizeof(szCmdArg));
        SetNativeString(2, szCmdArg, GetNativeCell(3));
        return strlen(szCmdArg);
    }
}

public N_IRC_GetCmdArgString(Handle:plugin, numParams)
{
    SetNativeString(1, g_szArgString, GetNativeCell(2));
    return strlen(g_szArgString);
}

public N_IRC_GetEventArg(Handle:plugin, numParams)
{
    decl String:szCmdArg[IRC_MAXLEN];
    GetArrayString(g_hArgs, GetNativeCell(1), szCmdArg, sizeof(szCmdArg));
    SetNativeString(2, szCmdArg, GetNativeCell(3));
    return strlen(szCmdArg);
}

public N_IRC_GetEventHostMask(Handle:plugin, numParams)
{
    SetNativeString(1, g_szHostMask, GetNativeCell(2));
    return strlen(g_szHostMask);
}

public N_IRC_GetHostMask(Handle:plugin, numParams)
{
    decl String:szNick[IRC_NICK_MAXLEN], String:szHostMask[IRC_MAXLEN];
    GetNativeString(1, szNick, sizeof(szNick));
    new Handle:hUser;
    if (!GetTrieValue(g_hUsers, szNick, hUser))
         ThrowNativeError(SP_ERROR_NOT_FOUND, "No such user");
    if (!GetTrieString(hUser, "hostmask", szHostMask, sizeof(szHostMask)))
        return false;
    SetNativeString(2, szHostMask, GetNativeCell(3));
    return true;
}

public N_IRC_GetUserFlagBits(Handle:plugin, numParams)
{
    decl String:szNick[IRC_NICK_MAXLEN];
    GetNativeString(1, szNick, sizeof(szNick));
    new Handle:hUser;
    if (!GetTrieValue(g_hUsers, szNick, hUser))
        ThrowNativeError(SP_ERROR_NOT_FOUND, "No such user");
    new flags = 0;
    if (GetTrieValue(hUser, "flags", flags))
        return flags;
    return 0;
}

public N_IRC_HookEvent(Handle:plugin, numParams)
{
    decl event[ircEvent];
    GetNativeString(1, event[eventName], sizeof(event[eventName]));
    
    event[eventPlugin] = plugin;
    event[eventCallback] = GetNativeCell(2);
    new Handle:hForward = CreateForward(ET_Event, Param_String, Param_Cell);
    AddToForward(hForward, plugin, Function:event[eventCallback]);
    event[eventForward] = hForward;
    PushArrayArray(g_hEvents, event[0]);
}

public N_IRC_MsgFlaggedChannels(Handle:plugin, numParams)
{
    if (!g_bConnected)
        return false;
    decl String:szText[IRC_MAXLEN];
    new iWritten;
    FormatNativeString(0, 2, 3, sizeof(szText), iWritten, szText);
    if (StrContains(szText, "\r", false) != -1 || StrContains(szText, "\n", false) != -1)
    {
        LogMessage("%s", szText);
        ThrowNativeError(SP_ERROR_PARAM, "IRC_MsgFlaggedChannels: Line contains carriage return (\\r) or line feed (\\n).");
    }
    decl String:szFlag[64], String:szValue[64], String:szChannel[IRC_CHANNEL_MAXLEN];
    GetNativeString(1, szFlag, sizeof(szFlag));
    new Handle:hChannel;
    new Handle:hFlags;
    for (new i = 0; i < GetArraySize(g_hChannels); i++)
    {
        hChannel = GetArrayCell(g_hChannels, i);
        if (GetTrieValue(hChannel, "flags", hFlags) && GetTrieString(hFlags, szFlag, szValue, sizeof(szValue)) && !StrEqual(szValue, ""))
        {
            GetTrieString(hChannel, "channel", szChannel, sizeof(szChannel));
            IRC_Send("PRIVMSG %s :%s", szChannel, szText);
        }
    }
    return true;
}

public N_IRC_RegAdminCmd(Handle:plugin, numParams)
{
    decl cmd[ircCmd];
    GetNativeString(1, cmd[cmdName], sizeof(cmd[cmdName]));
    GetNativeString(4, cmd[cmdDescription], sizeof(cmd[cmdDescription]));
    
    cmd[cmdPlugin] = plugin;
    cmd[cmdCallback] = GetNativeCell(2);

    new Handle:hForward = CreateForward(ET_Event, Param_Cell, Param_Cell);
    AddToForward(hForward, plugin, Function:cmd[cmdCallback]);
    cmd[cmdForward] = hForward;
    
    cmd[cmdPermissions] = GetNativeCell(3);
    cmd[cmdFlag] = GetNativeCell(4);
    PushArrayArray(g_hCmds, cmd);
    // TODO: Command group support
}

public N_IRC_RegCmd(Handle:plugin, numParams)
{
    decl cmd[ircCmd];
    GetNativeString(1, cmd[cmdName], sizeof(cmd[cmdName]));
    GetNativeString(3, cmd[cmdDescription], sizeof(cmd[cmdDescription]));
    
    cmd[cmdPlugin] = plugin;
    cmd[cmdCallback] = GetNativeCell(2);

    new Handle:hForward = CreateForward(ET_Event, Param_Cell, Param_Cell);
    AddToForward(hForward, plugin, Function:cmd[cmdCallback]);
    cmd[cmdForward] = hForward;
    
    cmd[cmdPermissions] = 0;
    cmd[cmdFlag] = GetNativeCell(4);
    PushArrayArray(g_hCmds, cmd);
    // TODO: Command group support
}

public N_IRC_ReplyToCommand(Handle:plugin, numParams)
{
    decl String:szBuffer[512], String:szNick[IRC_NICK_MAXLEN], iWritten;
    GetNativeString(1, szNick, sizeof(szNick));
    FormatNativeString(0, 2, 3, sizeof(szBuffer), iWritten, szBuffer);
    IRC_Send("NOTICE %s :%s", szNick, szBuffer);
}

public N_IRC_Send(Handle:plugin, numParams)
{
    decl String:szBuffer[IRC_MAXLEN];
    new iWritten;
    FormatNativeString(0, 1, 2, sizeof(szBuffer), iWritten, szBuffer);
    if (StrContains(szBuffer, "\n") != -1 || StrContains(szBuffer, "\r") != -1)
    {
        ThrowNativeError(SP_ERROR_PARAM, "IRC_MsgFlaggedChannels: Line contains carriage return or line feed. These can't be relayed.");
    }
    
    if ((g_bConnected) && (g_fMessageRate != 0.0))
    {
        if (g_hMessageTimer != INVALID_HANDLE)
        {
            PushArrayString(g_hMessageQueue, szBuffer);
            return;
        }
        else
            g_hMessageTimer = CreateTimer(g_fMessageRate, MessageTimerCB);
    }
    if (g_bDebug)
        LogMessage(">> %s", szBuffer);
    Format(szBuffer, sizeof(szBuffer), "%s\r\n", szBuffer);
    SocketSend(g_hSocket, szBuffer);
}

public N_IRC_SetUserFlagBits(Handle:plugin, numParams)
{
    decl String:szNick[IRC_NICK_MAXLEN];
    GetNativeString(1, szNick, sizeof(szNick));
    new AdminFlag:iFlags = GetNativeCell(2);
    new Handle:hUser;
    if (!GetTrieValue(g_hUsers, szNick, hUser))
        ThrowNativeError(SP_ERROR_NOT_FOUND, "No Such user");
    SetTrieValue(hUser, "flags", iFlags);
}

public Action:MessageTimerCB(Handle:timer)
{
    if (!g_bConnected)
        ClearArray(g_hMessageQueue);
    g_hMessageTimer = INVALID_HANDLE;
    if (GetArraySize(g_hMessageQueue) > 0)
    {
        decl String:szBuffer[IRC_MAXLEN];
        GetArrayString(g_hMessageQueue, 0, szBuffer, sizeof(szBuffer));
        IRC_Send(szBuffer);
        RemoveFromArray(g_hMessageQueue, 0);
        if (GetArraySize(g_hMessageQueue) > 0)
            g_hMessageTimer = CreateTimer(g_fMessageRate, MessageTimerCB);
    }
}

public Action:Event_Connected(const String:nick[], args)
{
    // Recieved RAW 004 or RAW 376? We're connected. Yay!
    if (g_bConnected)
        return;
    g_bConnected = true;
    Call_StartForward(g_hConnected);
    Call_Finish();

    decl String:szPassword[IRC_MAXLEN];
    decl String:szChannel[IRC_CHANNEL_MAXLEN];
    for (new i = 0; i < GetArraySize(g_hChannels); i++)
    {
        new Handle:hChannel = GetArrayCell(g_hChannels, i);
        new Handle:hSettings;
        GetTrieString(hChannel, "channel", szChannel, sizeof(szChannel));
        GetTrieValue(hChannel, "settings", hSettings)
        new bool:bInChannel;
        if (GetTrieValue(hChannel, "in_channel", bInChannel) && !bInChannel)
        {
            if (GetTrieString(hSettings, "password", szPassword, sizeof(szPassword)) && !StrEqual(szPassword, ""))
                IRC_Send("JOIN %s %s", szChannel, szPassword);
            else
                IRC_Send("JOIN %s", szChannel);
        }
    }
}


public OnAllPluginsLoaded()
{
    //IRC_RegCmd("help", Command_Help, "help - Shows a list of commands available to you");
    IRC_HookEvent("004", Event_Connected);
    IRC_HookEvent("376", Event_Connected);
    IRC_HookEvent("352", Event_WHO);
    IRC_HookEvent("005", Event_VERSION);
    IRC_HookEvent("PING", Event_PING);
    IRC_HookEvent("JOIN", Event_JOIN);
}
