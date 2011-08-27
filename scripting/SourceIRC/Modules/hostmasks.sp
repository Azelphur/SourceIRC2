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

// This plugin provides the hostmask authentication method

#undef REQUIRE_PLUGIN
#include <sourceirc>


#define MAX_FLAGS 32

new Handle:g_hHostMasks;
new Handle:g_hFlags;

public Plugin:myinfo =
{
	name = "SourceIRC -> Hostmasks",
	author = "Azelphur",
	description = "Hostmask authentication backend",
	version = IRC_VERSION,
	url = "http://Azelphur.com/project/sourceirc"
};

public OnPluginStart()
{
	g_hHostMasks = CreateArray(IRC_HOST_MAXLEN);
	g_hFlags = CreateArray(MAX_FLAGS);
	LoadConfigs();
}

LoadConfigs()
{
	decl String:szFile[512];
	BuildPath(Path_SM, szFile, sizeof(szFile), "configs/SourceIRC/hostmasks.cfg");
	if (!FileExists(szFile))
		SetFailState("Error in LoadConfigs(): hostmasks.cfg is missing from your sourcemod/configs directory!");
	new Handle:smc = SMC_CreateParser();
	SMC_SetReaders(smc, SMC_NewSection, SMC_KeyValue, SMC_EndSection);
	SMC_ParseFile(smc, szFile);
}

public SMCResult:SMC_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	PushArrayString(g_hHostMasks, key);
	PushArrayString(g_hFlags, value);
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

public IRC_UserCreated(const String:nick[])
{
	decl String:szHostMask[IRC_HOST_MAXLEN], String:szStoredHostMask[IRC_HOST_MAXLEN], String:szFlags[MAX_FLAGS];
	new AdminFlag:iFlag; // Single flag from FindFlagByChar
	new iFlags; // All flags added together ready to set the admin flags on the person.
	IRC_GetHostMask(nick, szHostMask, sizeof(szHostMask));
	for (new i = 0; i < GetArraySize(g_hHostMasks); i++)
	{
		GetArrayString(g_hHostMasks, i, szStoredHostMask, sizeof(szStoredHostMask));
		if (IRC_IsWildCardMatch(szHostMask, szStoredHostMask))
		{
			iFlag = AdminFlag:0;
			GetArrayString(g_hFlags, i, szFlags, sizeof(szFlags));
			for (new x = 0; x <= strlen(szFlags); x++) { 
				if (FindFlagByChar(szFlags[x], iFlag)) {
					iFlags |= 1<<_:iFlag;
				}
			}
			IRC_SetUserFlagBits(nick, iFlags);
		}
	}
}
