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

// Creating all the global variables.

// Are we connected?
new bool:g_bConnected = false;

// Handle to socket
new Handle:g_hSocket = INVALID_HANDLE;

new String:g_szServer[256];
new g_iPort = 6667;
new String:g_szPassword[IRC_MAXLEN];
new String:g_szNick[IRC_NICK_MAXLEN];
new String:g_szUser[IRC_NICK_MAXLEN];
new String:g_szRealName[IRC_MAXLEN];
new bool:g_bDebug = false;

// Keep track of what config section we are in for SMC
new g_iConfigSection = 0;

// Event registry for plugins using IRC_HookEvent
new Handle:g_hEvents;

enum ircEvent
{
	Handle:eventPlugin,
	Handle:eventCallback,
	Handle:eventForward,
	String:eventName[IRC_CMD_MAXLEN],
};

// Command registery for plugins using IRC_RegCmd or IRC_RegAdminCmd
new Handle:g_hCmds;

enum ircCmd
{
	Handle:cmdPlugin,
	Handle:cmdCallback,
	Handle:cmdForward,
	String:cmdName[IRC_CMD_MAXLEN],
	String:cmdDescription[256],
	cmdPermissions,
	cmdFlag,
	cmdGroup[IRC_CMD_MAXLEN]
};

// Storage for user information
new Handle:g_hUsers;

// Storage for channels
new Handle:g_hChannels;
new Handle:g_hChannelsTrie; // This is just a trie that points to the trie stored in g_hChannels for fast lookups.

// Temporary storage for command and event arguments
new Handle:g_hArgs;
new String:g_szArgString[IRC_MAXLEN];
new String:g_szHostmask[IRC_MAXLEN];

// Queue for rate limiting/excess flood mitigation
new Handle:g_hMessageQueue;
new Handle:g_hMessageTimer = INVALID_HANDLE;
new Float:g_fMessageRate;

// Handle for firing the IRC_Connected forward
new Handle:g_hConnected;

// Handle for firing the IRC_UserCreated forward
new Handle:g_hUserCreated;

// The current command being executed
new String:g_szCurrentCmd[IRC_CMD_MAXLEN];

// The full address of someone firing an event
new String:g_szHostMask[IRC_MAXLEN];

// Sometimes the IRC server will break a single response into multiple packets, so this is temporary storage for the first half of the response, until the other half comes along.
new String:g_szBrokenLine[IRC_MAXLEN];

new String:g_szPrefixChars[64]; // This stores a list of possible user modes in a channel by char, eg ov
new String:g_szPrefixSymbols[64]; // This stores a list of possible user modes in a channel by symbol, eg @+

// sourceirc_version cvar
new Handle:g_hcvarVersion;
