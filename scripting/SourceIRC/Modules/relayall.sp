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

#undef REQUIRE_PLUGIN
#include <sourceirc>

public Plugin:myinfo = {
    name = "SourceIRC -> Relay All",
    author = "Azelphur",
    description = "Relays various game events",
    version = IRC_VERSION,
    url = "http://azelphur.com/project/sourceirc"
};

#define TAG_STRING -1
#define TAG_EVENT_STRING 0
#define TAG_NAME 1

#define IRCTAG_STRING -1
#define IRCTAG_EVENT 0
#define IRCTAG_NICK 1

new String:g_szGameTagToNumber[2][16] = { "event_string", "name" }
new String:g_szIRCTagToNumber[2][16] = { "event", "nick" }

new bool:g_bSourceIRCLoaded = false;

new g_iConfigSection;

new Handle:g_hGameFormatTrie;
new Handle:g_hIRCFormatTrie;

enum Skin {
    type,
    String:skin_text[IRC_MAXLEN],
};

public OnPluginStart()
{
    g_hGameFormatTrie = CreateTrie();
    g_hIRCFormatTrie = CreateTrie();
}

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

LoadConfigs()
{
    decl String:szFile[512];
    BuildPath(Path_SM, szFile, sizeof(szFile), "configs/SourceIRC/relayall.cfg");
    if (!FileExists(szFile))
        SetFailState("Error in LoadConfigs(): relayall.cfg is missing from your sourcemod/configs/SourceIRC directory!");
    new Handle:smc = SMC_CreateParser();
    SMC_SetReaders(smc, SMC_NewSection, SMC_KeyValue, SMC_EndSection);
    SMC_ParseFile(smc, szFile);
}

public SMCResult:SMC_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
    switch (g_iConfigSection)
    {
        case 1:
        {
            HookEvent(key, EventCB);
            GameParseSkin(key, value);
        }
        case 2:
        {

            IRC_HookEvent(key, IRC_EventCB);
            IRCParseSkin(key, value);
        }
    }
    return SMCParse_Continue;
}

public SMCResult:SMC_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
    if (StrEqual(name, "GameToIRC", false))
        g_iConfigSection = 1;
    else if (StrEqual(name, "IRCToGame", false))
        g_iConfigSection = 2;
    return SMCParse_Continue;
}

public SMCResult:SMC_EndSection(Handle:smc)
{
    g_iConfigSection = 0;
    return SMCParse_Continue;
}

IRCParseSkin(const String:name[], const String:format[]="")
{
    new Handle:hArray = CreateArray(IRC_MAXLEN+1);
    SetTrieValue(g_hIRCFormatTrie, name, hArray);
    decl eSkin[Skin];
    decl String:szBuffer[IRC_MAXLEN], String:szArgs[IRC_MAXLEN];
    szBuffer[0] = '\0';
    new bool:bInTag = false;
    new iBufferPos = 0;
    new iArgPos = 0;
    for (new i = 0; i < strlen(format); i++)
    {
        if (format[i] == '{' && format[i+1] == '$')
        {
            if (!StrEqual(szBuffer, ""))
            {
                szBuffer[iBufferPos] = '\0';
                eSkin[type] = TAG_STRING;
                strcopy(eSkin[skin_text], sizeof(eSkin[skin_text]), szBuffer);
                PushArrayArray(hArray, eSkin[0]);
                szBuffer[0] = '\0';
                iBufferPos = 0;
            }
                
            i += 2;
            bInTag = true;
        }
        if (bInTag && format[i] == '}')
        {
            szBuffer[iBufferPos] = '\0';
            szArgs[0] = '\0';
            iArgPos = StrContains(szBuffer, " ")
            if (iArgPos != -1)
            {
                strcopy(szArgs, sizeof(szArgs), szBuffer[iArgPos+1]);
                szBuffer[iArgPos] = '\0';
            }
            for (new ii = 0; ii < sizeof(g_szIRCTagToNumber); ii++)
            {
                if (StrEqual(g_szIRCTagToNumber[ii], szBuffer, false))
                {
                    eSkin[type] = ii;
                    strcopy(eSkin[skin_text], sizeof(eSkin[skin_text]), szArgs);
                    PushArrayArray(hArray, eSkin[0]);
                }
            }
            szBuffer[0] = '\0';
            iBufferPos = 0;
            bInTag = false;
        }
        else
        {
            szBuffer[iBufferPos] = format[i];
            iBufferPos += 1;
        }
    }
    
    if (iBufferPos != 0)
    {
        szBuffer[iBufferPos] = '\0';
        eSkin[type] = TAG_STRING;
        strcopy(eSkin[skin_text], sizeof(eSkin[skin_text]), szBuffer);
        PushArrayArray(hArray, eSkin[0]);
    }
}


GameParseSkin(const String:name[], const String:format[]="")
{
    new Handle:hArray = CreateArray(IRC_MAXLEN+1);
    SetTrieValue(g_hGameFormatTrie, name, hArray);
    decl eSkin[Skin];
    decl String:szBuffer[IRC_MAXLEN], String:szArgs[IRC_MAXLEN];
    szBuffer[0] = '\0';
    new bool:bInTag = false;
    new iBufferPos = 0;
    new iArgPos = 0;
    for (new i = 0; i < strlen(format); i++)
    {
        if (format[i] == '{' && format[i+1] == '$')
        {
            if (!StrEqual(szBuffer, ""))
            {
                szBuffer[iBufferPos] = '\0';
                eSkin[type] = TAG_STRING;
                strcopy(eSkin[skin_text], sizeof(eSkin[skin_text]), szBuffer);
                PushArrayArray(hArray, eSkin[0]);
                szBuffer[0] = '\0';
                iBufferPos = 0;
            }
                
            i += 2;
            bInTag = true;
        }
        if (bInTag && format[i] == '}')
        {
            szBuffer[iBufferPos] = '\0';
            szArgs[0] = '\0';
            iArgPos = StrContains(szBuffer, " ")
            if (iArgPos != -1)
            {
                strcopy(szArgs, sizeof(szArgs), szBuffer[iArgPos+1]);
                szBuffer[iArgPos] = '\0';
            }
            for (new ii = 0; ii < sizeof(g_szGameTagToNumber); ii++)
            {
                if (StrEqual(g_szGameTagToNumber[ii], szBuffer, false))
                {
                    eSkin[type] = ii;
                    strcopy(eSkin[skin_text], sizeof(eSkin[skin_text]), szArgs);
                    PushArrayArray(hArray, eSkin[0]);
                }
            }
            szBuffer[0] = '\0';
            iBufferPos = 0;
            bInTag = false;
        }
        else
        {
            szBuffer[iBufferPos] = format[i];
            iBufferPos += 1;
        }
    }
    
    if (iBufferPos != 0)
    {
        szBuffer[iBufferPos] = '\0';
        eSkin[type] = TAG_STRING;
        strcopy(eSkin[skin_text], sizeof(eSkin[skin_text]), szBuffer);
        PushArrayArray(hArray, eSkin[0]);
    }
}

public Action:EventCB(Handle:event, const String:name[], bool:dontBroadcast)
{
    new Handle:hArray;
    if (!GetTrieValue(g_hGameFormatTrie, name, hArray))
        return Plugin_Continue;
    if (GetArraySize(hArray) == 0)
        return Plugin_Continue;
    decl eSkin[Skin], String:szBuffer[IRC_MAXLEN], String:szText[IRC_MAXLEN];
    szText[0] = '\0';
    for (new i = 0; i < GetArraySize(hArray); i++)
    {
        GetArrayArray(hArray, i, eSkin[0])
        switch (eSkin[type])
        {
            case TAG_STRING:
            {
                StrCat(szText, sizeof(szText), eSkin[skin_text]);
            }
            case TAG_NAME:
            {
                GetClientName(GetClientOfUserId(GetEventInt(event, eSkin[skin_text])), szBuffer, sizeof(szBuffer));
                StrCat(szText, sizeof(szText), szBuffer);
            }
            case TAG_EVENT_STRING:
            {
                GetEventString(event, eSkin[skin_text], szBuffer, sizeof(szBuffer));
                StrCat(szText, sizeof(szText), szBuffer);
            }
        }
    }
    IRC_MsgFlaggedChannels("relayall", "%s", szText);
    return Plugin_Continue;
}

// IRC Events

public Action:IRC_EventCB(const String:nick[], args)
{
    new Handle:hArray;
    decl String:szName[IRC_CMD_MAXLEN];
    IRC_GetEventArg(0, szName, sizeof(szName));
    if (!GetTrieValue(g_hIRCFormatTrie, szName, hArray))
        return Plugin_Continue;
    if (GetArraySize(hArray) == 0)
        return Plugin_Continue;
    decl eSkin[Skin], String:szBuffer[IRC_MAXLEN], String:szText[IRC_MAXLEN];
    szText[0] = '\0';
    for (new i = 0; i < GetArraySize(hArray); i++)
    {
        GetArrayArray(hArray, i, eSkin[0])

        switch (eSkin[type])
        {
            case IRCTAG_STRING:
            {
                StrCat(szText, sizeof(szText), eSkin[skin_text]);
            }
            case IRCTAG_EVENT:
            {
                IRC_GetEventArg(StringToInt(eSkin[skin_text]), szBuffer, sizeof(szBuffer));
                StrCat(szText, sizeof(szText), szBuffer);
            }
            case IRCTAG_NICK:
            {
                StrCat(szText, sizeof(szText), nick);
            }
        }
    }
    PrintToChatAll("%s", szText);
    return Plugin_Continue;
}
