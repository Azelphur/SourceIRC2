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

// Keep track of where all the users are, what channels we're in, what our own nick is, etc.

InitTracking()
{
	g_hChannels = CreateArray();
	g_hChannelsTrie = CreateTrie();
	g_hUsers = CreateTrie();
}

public Action:Event_JOIN(const String:nick[], args)
{
	decl String:szChannel[IRC_CHANNEL_MAXLEN], String:szHostMask[IRC_MAXLEN];
	IRC_GetEventArg(1, szChannel, sizeof(szChannel));
	IRC_GetEventHostMask(szHostMask, sizeof(szHostMask));

	if (StrEqual(nick, g_szNick, false))
		IRC_Send("WHO %s", szChannel);
	UserJoined(nick, szHostMask, szChannel);
}

public Action:Event_WHO(const String:prefix[], args)
{
	decl String:szChannel[IRC_MAXLEN], String:szNick[IRC_NICK_MAXLEN], String:szUser[IRC_USER_MAXLEN], String:szHost[IRC_HOST_MAXLEN], String:szHostMask[IRC_MAXLEN];
	IRC_GetEventArg(2, szChannel, sizeof(szChannel));
	IRC_GetEventArg(3, szUser, sizeof(szChannel));
	IRC_GetEventArg(4, szHost, sizeof(szHost));
	IRC_GetEventArg(6, szNick, sizeof(szNick));
	Format(szHostMask, sizeof(szHostMask), "%s!%s@%s", szNick, szUser, szHost);
	UserJoined(szNick, szHostMask, szChannel);
}

public Action:Event_VERSION(const String:nick[], args)
{
	// When we connect the server sends us a list of possible channel modes and their corrisponding symbols, eg ov == @+, we need these.
	decl String:szArg[IRC_MAXLEN];
	for (new i = 1; i <= args; i++)
	{
		IRC_GetEventArg(i, szArg, sizeof(szArg));
		if (!strncmp(szArg, "PREFIX=", 7, false))
		{
			new iPos = FindCharInString(szArg, ')');
			if (iPos != -1)
			{
				strcopy(g_szPrefixChars, sizeof(g_szPrefixChars), szArg[8]);
				g_szPrefixChars[iPos-8] = '\0';
				strcopy(g_szPrefixSymbols, sizeof(g_szPrefixSymbols), szArg[iPos+1]);
			}
			return;
		}
	}
}

Handle:AddChannel(const String:name[])
{
	new Handle:hTrie = CreateTrie()
	SetTrieString(hTrie, "channel", name);
	SetTrieValue(hTrie, "in_channel", false);
	SetTrieValue(hTrie, "flags", CreateTrie());
	SetTrieValue(hTrie, "settings", CreateTrie());
	SetTrieValue(hTrie, "users", CreateArray(IRC_MAXLEN));
	PushArrayCell(g_hChannels, hTrie);
	SetTrieValue(g_hChannelsTrie, name, hTrie);
	return hTrie;
}

Handle:UserJoined(const String:nick[], const String:hostmask[], const String:channel[])
{
	new Handle:hChannel;
	if (!GetTrieValue(g_hChannelsTrie, channel, hChannel)) // This scenario should only really be possible in weird circumstances like the IRC server forcing us to join a channel
		hChannel = AddChannel(channel);

	if (StrEqual(nick, g_szNick, false))
		SetTrieValue(hChannel, "in_channel", true);

	new Handle:hUsers;
	decl String:szChannel[IRC_CHANNEL_MAXLEN];
	GetTrieValue(hChannel, "users", hUsers);
	PushArrayString(hUsers, nick);
	new Handle:hUser;
	if (!GetTrieValue(g_hUsers, nick, hUser))
		hUser = CreateUser(nick);
	new Handle:hChannels;
	GetTrieValue(hUser, "channels", hChannels);
	PushArrayString(hChannels, szChannel);
	SetTrieString(hUser, "hostmask", hostmask);

	Call_StartForward(g_hUserCreated);
	Call_PushString(nick);
	Call_Finish();
}

Handle:CreateUser(const String:nick[])
{
	new Handle:hTrie = CreateTrie();
	SetTrieValue(hTrie, "channels", CreateArray(IRC_CHANNEL_MAXLEN));
	SetTrieValue(hTrie, "flags", 0);
	SetTrieValue(g_hUsers, nick, hTrie);
	return hTrie;
}
