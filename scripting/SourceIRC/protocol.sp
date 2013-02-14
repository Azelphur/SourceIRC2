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

// Protocol/socket stuff in here

InitProtocol()
{
    g_hMessageQueue = CreateArray(IRC_MAXLEN);
}

Connect()
{
    g_hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
    SocketConnect(g_hSocket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, g_szServer, g_iPort);
}

public OnSocketConnected(Handle:socket, any:arg)
{
    decl String:szHost[256], String:szServerIp[16];
    SocketGetHostName(szHost, sizeof(szHost));
    new iIp = GetConVarInt(FindConVar("hostip"));
    Format(szServerIp, sizeof(szServerIp), "%i.%i.%i.%i", (iIp >> 24) & 0x000000FF, (iIp >> 16) & 0x000000FF, (iIp >>  8) & 0x000000FF, iIp & 0x000000FF);
    
    if (!StrEqual(g_szPassword, ""))
        IRC_Send("PASS %s", g_szPassword);

    IRC_Send("NICK %s", g_szNick);
    IRC_Send("USER %s %s %s :%s", g_szUser, szHost, szServerIp, g_szRealName);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:hFile)
{
    new iStartPos = 0;
    new iPos;
    decl String:szLine[IRC_MAXLEN];
    decl String:szPrefix[IRC_MAXLEN];
    decl String:szTrailing[IRC_MAXLEN];
    while (iStartPos < dataSize) { // Loop through each line in the packet
        g_hArgs = CreateArray(IRC_MAXLEN);
        iStartPos += SplitString(receiveData[iStartPos], "\n", szLine, sizeof(szLine));
        if (receiveData[iStartPos-1] != '\n') // If this is the first half of a broken packet, save it until the other half arrives.
        {
            strcopy(g_szBrokenLine, sizeof(g_szBrokenLine), szLine);
            break;
        }
        if (!StrEqual(g_szBrokenLine, "")) // Is this the latter half of a "Broken" packet? Stick it back together again.
        {
            decl String:szOriginalLine[IRC_MAXLEN];
            strcopy(szOriginalLine, sizeof(szOriginalLine), szLine);
            strcopy(szLine, sizeof(szLine), g_szBrokenLine);
            StrCat(szLine, sizeof(szLine), szOriginalLine);
            g_szBrokenLine[0] = '\x00';
        }
        if (szLine[strlen(szLine)-1] == '\r') // Strip off the \r since we already stripped the \n. I do this seperately as although the RFC says that you should send \r\n, some clients don't.
            szLine[strlen(szLine)-1] = '\x00';
        if (g_bDebug)
            LogMessage("<< %s", szLine);
        if (szLine[0] == ':') // Did this event come from a user? seperate the prefix (full address)
        {
            iPos = SplitString(szLine[1], " ", szPrefix, sizeof(szPrefix));
            strcopy(g_szHostMask, sizeof(g_szHostMask), szPrefix);
            SplitString(szPrefix, "!", szPrefix, sizeof(szPrefix));
            strcopy(szLine, sizeof(szLine), szLine[iPos+1]);
        }
        if (StrContains(szLine, " :") != -1) // Is this a command? Separate the command and the args
        {
            iPos = SplitString(szLine, " :", szLine, sizeof(szLine));
            strcopy(szTrailing, sizeof(szTrailing), szLine[iPos]);

            ExplodeString_Array(szLine, " ", g_hArgs, IRC_MAXLEN);
            PushArrayString(g_hArgs, szTrailing);
            
            decl String:szBlah[512];
            GetArrayString(g_hArgs, 0, szBlah, sizeof(szBlah));
        }
        else
        { // It's not a command. So we just break up all the arguments.
            ExplodeString_Array(szLine, " ", g_hArgs, IRC_MAXLEN);
        }
        HandleLine(szPrefix); // packet has been parsed, time to send it off to HandleLine.
        ClearArray(g_hArgs);
    }
}

public OnSocketDisconnected(Handle:socket, any:hFile)
{
    g_bConnected = false;
    CreateTimer(5.0, ReConnect);
    CloseHandle(g_hSocket);
}

public Action:ReConnect(Handle:timer)
{
    Connect();
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:hFile)
{
    g_bConnected = false;
    CreateTimer(5.0, ReConnect);
    LogError("socket error %d (errno %d)", errorType, errorNum);
    CloseHandle(socket);
}

public Action:Event_PING(const String:server[], args)
{
    decl String:szReply[IRC_MAXLEN];
    IRC_GetEventArg(1, szReply, sizeof(szReply));
    IRC_Send("PONG :%s", szReply);
}
