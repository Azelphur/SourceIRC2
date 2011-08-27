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

public Plugin:myinfo =
{
	name = "SourceIRC -> WhoAmI",
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
	IRC_RegCmd("whoami", Command_WhoAmI, "Shows information about you and your permissions.");
}

public Action:Command_WhoAmI(const String:nick[], args)
{
	decl String:szHostMask[IRC_MAXLEN];
	IRC_GetHostMask(nick, szHostMask, sizeof(szHostMask));
	IRC_ReplyToCommand(nick, "Your hostmask is: %s", szHostMask);
	IRC_ReplyToCommand(nick, "Your flagbits are: %d", IRC_GetUserFlagBits(nick));
	return Plugin_Handled;
}
