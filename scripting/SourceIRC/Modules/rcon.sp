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
	name = "SourceIRC -> rcon",
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
	IRC_RegAdminCmd("rcon", Command_Rcon, ADMFLAG_RCON, "Run an RCON command on the server");
	LoadConfigs();
}

public Action:Command_Rcon(const String:nick[], args)
{
	decl String:szCommand[IRC_MAXLEN];
	IRC_GetCmdArgString(szCommand, sizeof(szCommand));
	RunAndReply(nick, szCommand);
	return Plugin_Handled;
}

public Action:Command_Passthrough(const String:nick[], args)
{
	decl String:szCommand[IRC_CMD_MAXLEN], String:szArgs[IRC_MAXLEN];
	IRC_GetCmdArg(0, szCommand, sizeof(szCommand));
	IRC_GetCmdArgString(szArgs, sizeof(szArgs));
	new iNumQuotes = 0;
	for (new i = 0; i < strlen(szArgs); i++)
	{
		switch (szArgs[i])
		{
			case '"':
			{
				iNumQuotes += 1;
			}
			case ';':
			{
				if (iNumQuotes % 2 == 0)
				{
					IRC_ReplyToCommand(nick, "You cannot use a semicolon outside of quotes.");
					return Plugin_Handled;
				}
			}
		}
	}
	decl String:szRcon[IRC_MAXLEN];
	Format(szRcon, sizeof(szRcon), "%s %s", szCommand, szArgs);
	RunAndReply(nick, szRcon);
	return Plugin_Handled;
}

RunAndReply(const String:nick[], const String:command[])
{
	decl String:szResponse[IRC_MAXLEN], String:szBuffer[IRC_MAXLEN];
	szResponse[0] = '\0'
	ServerCommandEx(szResponse, sizeof(szResponse), "%s", command);
	new iBufferPos = 0;
	for (new i = 0; i < strlen(szResponse); i++)
	{
		if (szResponse[i] == '\n' || strlen(szBuffer) == sizeof(szBuffer)-4)
		{
			szBuffer[iBufferPos] = '\0';
			if (!StrEqual(szBuffer, ""))
				IRC_ReplyToCommand(nick, "%s", szBuffer);
			szBuffer[0] = '\0';
			iBufferPos = 0;
		}
		else
		{
			szBuffer[iBufferPos] = szResponse[i]
			iBufferPos += 1;
		}
	}
}

LoadConfigs()
{
	decl String:szFile[512];
	BuildPath(Path_SM, szFile, sizeof(szFile), "configs/SourceIRC/rcon.cfg");
	if (!FileExists(szFile))
		return;
	new Handle:smc = SMC_CreateParser();
	SMC_SetReaders(smc, SMC_NewSection, SMC_KeyValue, SMC_EndSection);
	SMC_ParseFile(smc, szFile);
}

public SMCResult:SMC_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	new AdminFlag:iFlag;
	new iFlags;
	for (new x = 0; x <= strlen(value); x++) { 
		if (FindFlagByChar(value[x], iFlag)) {
			iFlags |= 1<<_:iFlag;
		}
	}
	IRC_RegAdminCmd(key, Command_Passthrough, iFlags, "RCON Passthrough");
	return SMCParse_Continue;
}

public SMCResult:SMC_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
	return SMCParse_Continue;
}

public SMCResult:SMC_EndSection(Handle:smc)
{
	return SMCParse_Continue;
}
