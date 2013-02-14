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

/* This file contains very little, just the config loading code, version cvar, and a little other misc stuff. */
#include <socket>
#include <sourceirc>

public Plugin:myinfo =
{
    name = "SourceIRC",
    author = "Azelphur",
    description = "An easy to use API to the IRC protocol",
    version = IRC_VERSION,
    url = "http://Azelphur.com/project/sourceirc"
};

#include variables.sp
#include api.sp
#include tracking.sp
#include protocol.sp

public OnPluginStart()
{
    InitApi();
    InitProtocol();
    InitTracking();
    
    g_hcvarVersion = CreateConVar("sourceirc_version", IRC_VERSION, "Current version of SourceIRC", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_NOTIFY);
    LoadTranslations("sourceirc.phrases");
}

public OnConfigsExecuted()
{
    // hax for busted a2s_rules response on linux (Ninja'd from hlstats, thanks psychonic)
    if (GuessSDKVersion() != SOURCE_SDK_EPISODE2VALVE)
        return;
    decl String:szBuffer[128];
    GetConVarString(g_hcvarVersion, szBuffer, sizeof(szBuffer));
    SetConVarString(g_hcvarVersion, szBuffer);
    //

    if (g_hSocket == INVALID_HANDLE)
    {
        LoadConfigs();
        Connect();
    }
}

LoadConfigs()
{
    decl String:szFile[512];
    BuildPath(Path_SM, szFile, sizeof(szFile), "configs/SourceIRC/sourceirc.cfg");
    if (!FileExists(szFile))
        SetFailState("Error in LoadConfigs(): sourceirc.cfg is missing from your sourcemod/configs directory!");
    new Handle:smc = SMC_CreateParser();
    SMC_SetReaders(smc, SMC_NewSection, SMC_KeyValue, SMC_EndSection);
    g_iConfigSection = 0;
    SMC_ParseFile(smc, szFile);
}

public SMCResult:SMC_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
    switch (g_iConfigSection)
    {
        case 1:
        {
            if (StrEqual(key, "server"))
                strcopy(g_szServer, sizeof(g_szServer), value);
            else if (StrEqual(key, "port"))
                g_iPort = StringToInt(value);
            else if (StrEqual(key, "nickname"))
                strcopy(g_szNick, sizeof(g_szNick), value);
            else if (StrEqual(key, "username"))
                strcopy(g_szUser, sizeof(g_szUser), value);
            else if (StrEqual(key, "realname"))
                strcopy(g_szRealName, sizeof(g_szRealName), value);
            else if (StrEqual(key, "password"))
                strcopy(g_szPassword, sizeof(g_szPassword), value);
            else if (StrEqual(key, "msg_rate"))
                g_fMessageRate = StringToFloat(value);
            else if (StrEqual(key, "cmd_prefix"))
                strcopy(g_szCmdPrefix, sizeof(g_szCmdPrefix), value);
            else if (StrEqual(key, "debug"))
                g_bDebug = bool:StringToInt(value);
            return SMCParse_Continue;
        }
        case 4:
        {
            new Handle:hChannel = GetArrayCell(g_hChannels, GetArraySize(g_hChannels)-1);
            new Handle:hSettings;
            GetTrieValue(hChannel, "settings", hSettings)
            SetTrieString(hSettings, key, value);
        }
        case 5:
        {
            new Handle:hChannel = GetArrayCell(g_hChannels, GetArraySize(g_hChannels)-1);
            new Handle:hFlags;
            GetTrieValue(hChannel, "flags", hFlags)
            SetTrieString(hFlags, key, value);
        }
    }
    return SMCParse_Continue;
}

public SMCResult:SMC_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
    if (StrEqual(name, "server", false))
        g_iConfigSection = 1;
    else if (StrEqual(name, "channels", false) && g_iConfigSection == 1)
        g_iConfigSection = 2;
    else if (g_iConfigSection == 2)
    {
        g_iConfigSection = 3;
        AddChannel(name);
    }
    else if (StrEqual(name, "settings", false) && g_iConfigSection >= 3)
        g_iConfigSection = 4;
    else if (StrEqual(name, "flags", false) && g_iConfigSection >= 3)
        g_iConfigSection = 5;
    return SMCParse_Continue;
}

public SMCResult:SMC_EndSection(Handle:smc)
{
    if (g_iConfigSection >= 4)
        g_iConfigSection = 3;
    else
        g_iConfigSection -= 1;
    return SMCParse_Continue;
}
