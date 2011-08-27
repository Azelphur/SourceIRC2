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

#define IRC_VERSION "0.9.0"

#define IRC_CMD_MAXLEN 64 // The maximum length of a command
#define IRC_NICK_MAXLEN 64 // The maximum length of a nickname
#define IRC_USER_MAXLEN 64 // The maximum length of a username
#define IRC_HOST_MAXLEN 256 // The maximum length of a host
#define IRC_CHANNEL_MAXLEN 64 // The maximum length of a channel  name
#define IRC_MAX_MODES 64 // The maximum amount of modes
#define IRC_MAXLEN 512 // The maximum length of a line from the server. IRC RFC says maximum line length is 512, there again it also says a nicknames max length is 9. This might not be right.

#define IRC_CMDFLAG_NOPREFIX 1<<0 // Allow command to be triggered even without a prefix. For example instead of typing "SourceIRC: command args" you could just type "command args"

public SharedPlugin:__pl_sourceirc = 
{
	name = "sourceirc",
	file = "sourceirc.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_sourceirc_SetNTVOptional()
{
	MarkNativeAsOptional("IRC_ChannelHasFlag");
	MarkNativeAsOptional("IRC_CheckCommandAccess");
	MarkNativeAsOptional("IRC_GetEventArg");
	MarkNativeAsOptional("IRC_GetEventHostMask");
	MarkNativeAsOptional("IRC_GetHostMask");
	MarkNativeAsOptional("IRC_GetUserFlagBits");
	MarkNativeAsOptional("IRC_HookEvent");
	MarkNativeAsOptional("IRC_ReplyToCommand");
	MarkNativeAsOptional("IRC_RegCmd");
	MarkNativeAsOptional("IRC_Send");
}

/**
 * Called when an IRC command is invoked.
 *
 * @param client		An irc client index
 * @param args			Number of arguments that were in the argument string
 * @return				An Action value
 */
functag IRCCmd Action:public(const String:nick[], args);

/**
 * Called when an IRC event is fired.
 *
 * @param prefix		If the event is fired by a user, this will contain their
 *                      nickname. If it was fired by the server it will contain 
 *                      the servers name.
 * @param args			The number of arguments that are in the event
 * @noreturn			
 */

functag IRCEvent Action:public(const String:nick[], args);

/**
 * Checks if a channel has a flag.
 * 
 * @param channel		Channel to check.
 * @param flag			Flag to check.
 * @return				True if channel has flag, otherwise false.
 */

native bool:IRC_ChannelHasFlag(const String:channel[], const String:flag[]);

/**
 * Returns whether a client has access to a given command string.  The string 
 * can also be any override string, as overrides can be independent of 
 * commands.  This important feature essentially allows you to create custom 
 * flags using the override system.
 *
 * @param nick			Nickname
 * @param command		Command name.  If the command is not found, the default 
 *						flags are used.
 * @param flags			Flag string to use as a default, if the command or override 
 *						is not found.
 * @param override_only	If true, SourceIRC will not attempt to find a matching 
 *						command, and it will only use the default flags specified.
 *						Otherwise, SourceIRC will ignore the default flags if 
 *						there is a matching admin command.
 * @return				True if the client has access, false otherwise.
 */
native bool:IRC_CheckCommandAccess(const String:nick[], 
							   const String:command[],
							   flags,
							   bool:override_only=false);


/**
 * Retrieves the entire command argument string in one lump from the current 
 * IRC command.
 *
 * @param buffer		Buffer to use for storing the string.
 * @param maxlength		Maximum length of the buffer.
 * @return				Length of string written to buffer.
 */

native IRC_GetCmdArgString(String:buffer[], maxlength);
							   
/**
 * Retrieves a command argument given its index, from the current IRC command callback.
 * @note Argument indexes start at 1; 0 retrieves the command name.
 *
 * @param argnum		Argument number to retrieve.
 * @param buffer		Buffer to use for storing the string.
 * @param maxlength		Maximum length of the buffer.
 * @return				Length of string written to buffer.
 */

native IRC_GetCmdArg(arg, String:buffer[], maxlength);							   
/**
 * Retrieves a event argument given its index, from the current IRC Event.
 * @note Argument indexes start at 1; 0 retrieves the event name.
 *
 * @param argnum		Argument number to retrieve.
 * @param buffer		Buffer to use for storing the string.
 * @param maxlength		Maximum length of the buffer.
 * @return				Length of string written to buffer.
 */

native IRC_GetEventArg(arg, String:buffer[], maxlength);

/**
 * Retrieves the hostmask of the person firing an event.
 *
 * @param buffer		Buffer to use for storing the hostmask.
 * @param maxlength		Maximum length of the buffer.
 * @return				Length of string written to buffer.
 */

native IRC_GetEventHostMask(String:buffer[], maxlength);

/**
 * Retrieves the hostmask of nick
 * @note this will fail if SourceIRC hasn't had any interaction with the nick (common channels, pm)
 * 
 * @param nick			nickname to get the hostmask for
 * @param buffer		Buffer to use for storing the hostmask.
 * @param maxlength		Maximum length of the buffer.
 * @return				True on success, false on failure
 */

native bool:IRC_GetHostMask(const String:nick[], String:buffer[], maxlength);

/**
 * Returns client access flags. If the client is not an admin, the result is always 0.
 * @note this will fail if SourceIRC hasn't had any interaction with the nick (common channels, pm)
 * 
 * @param nick			nickname to get the hostmask for
 * @return				True on success, false on failure
 */

native IRC_GetUserFlagBits(const String:nick[]);

/**
 * Creates a hook for when an IRC event is fired.
 *
 * @param name			Name of event.
 * @param callback		An IRCEvent function pointer.
 * @noreturn
 */

native IRC_HookEvent(const String:event[], IRCEvent:callback);
	
/**
 * Sends a message to all channels with the given flag.
 *
 * @param flag			The flag channels must have to recieve this message.
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */

native IRC_MsgFlaggedChannels(const String:flag[], const String:format[], any:...);

/**
 * Replies to a command. Can only be used in an IRC_RegCmd or IRC_RegAdminCmd callback
 * 
 * @param nick			Nickname of the user to message
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */

native IRC_ReplyToCommand(const String:nick[], const String:format[], any:...);

/**
 * Registers a command people can use in IRC
 *
 * @param cmd			String containing command to register
 * @param callback		A Function to use as a callback for when the command is invoked
 * @param description	Optional description to use for help.
 * @param flags			Optional command flags.
 * @noreturn
 */

native IRC_RegCmd(const String:cmd[], IRCCmd:callback, const String:description[]="", flags=0);

/**
 * Registers admin command people can use in IRC
 *
 * @param cmd			String containing command to register
 * @param callback		A Function to use as a callback for when the command is invoked
 * @param adminflags	Administrative flags (bitstring) to use for permissions.
 * @param description	Optional description to use for help.
 * @param group			String containing the command group to use.  If empty,
 * 						the plugin's filename will be used instead.
 * @param flags			Optional command flags.
 * @noreturn
 */

native IRC_RegAdminCmd(const String:cmd[], IRCCmd:callback, adminflags, const String:description[]="", const String:group[]="", flags=0)

/**
 * Sends a command to the IRC Server. \r\n is automatically appended for you.
 * 
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 * @error				String contains  invalid characters (\r or \n).
 */

native IRC_Send(const String:format[], any:...);

/**
 * Replies to a command. Can only be used in an IRC_RegCmd or IRC_RegAdminCmd callback
 * 
 * @param nick			Nickname of the user to change admin flags for
 * @param flagbits		Admin flagbits
 * @noreturn
 */

native IRC_SetUserFlagBits(const String:nick[], flagbits);

/**
 * Called as we connect to the IRC server after recieving 004 or 376. Before we join any channels.
 */
 
forward IRC_Connected();

/**
 * Called when SourceIRC starts tracking a new user
 * 
 * @param nick				The nick of the created user.
 */
 
forward IRC_UserCreated(const String:nick[]);

/**
 * Breaks a string into pieces and stores each piece into an adt_array of buffers.
 *
 * @param text				The string to split.
 * @param split				The string to use as a split delimiter.
 * @param adt_array			An adt_array of string buffers.
 * @param maxlength			Maximum length of each string buffer.
 * @return					Number of strings retrieved.
 */
 
stock ExplodeString_Array(const String:source[], const String:split[], Handle:adt_array, maxlength) {
	ClearArray(adt_array);
	decl String:szArg[maxlength];
	new iStrPos = 0;
	for (new i = 0; i <= strlen(source); i++) {
		if (!strncmp(source[i], split, strlen(split))) {
			szArg[iStrPos] = '\x00';
			PushArrayString(adt_array, szArg);

			iStrPos = 0;
			i += strlen(split);
		}
		if (iStrPos < maxlength)
			szArg[iStrPos] = source[i];
		iStrPos++;
	}
	szArg[iStrPos] = '\x00';
	PushArrayString(adt_array, szArg);
	return GetArraySize(adt_array);
}

/**
 * Extracts a nickname from a hostmask.
 *
 * @param hostmask			Hostmask to get the nickname from.
 * @param nick				String to store the nickname in.
 * @param maxlength			Maximum length of the nickname.
 * @noreturn
 */

stock IRC_GetNickFromHostMask(const String:hostmask[], String:nick[], maxlength)
{
	for (new i = 0; i <= maxlength; i++) {
		if (hostmask[i] == '!') {
			nick[i] = '\x00';
			break;
		}
		nick[i] = hostmask[i];
	}
}

/**
 * Strips IRC Color codes from a string
 *
 * @param str				String to strip
 * @param maxlength			maximum length of str
 * @noreturn
 */

stock IRC_Strip(String:str[], maxlength)
{
	for (new i = 0; i <= strlen(str); i++)
	{
		//  Underline           Reverse             Color codes off     Bold
		if (str[i] == '\x1F' || str[i] == '\x16' || str[i] == '\x0f' || str[i] == '\x02')
			RemoveChar(str, maxlength, i);
		// Strip color codes
		if (str[i] == '\x03')
		{
			RemoveChar(str, maxlength, i);
			new ignorelast = false;

			if (str[i] > 47 && str[i] < 58)
			{
				RemoveChar(str, maxlength, i);
				if ((str[i] > 47 && str[i] < 58) || str[i] == ',')
				{
					if (str[i] == ',')
						ignorelast = true;
					RemoveChar(str, maxlength, i);
					if ((str[i] > 47 && str[i] < 58) || str[i] == ',')
					{
						RemoveChar(str, maxlength, i);
						if (str[i] > 47 && str[i] < 58)
						{
							RemoveChar(str, maxlength, i);
							if (str[i] > 47 && str[i] < 58 && !ignorelast) 
								RemoveChar(str, maxlength, i);
						}
					}
				}
			}
			i--;
		}
	}
}

/**
 * Removes a character from a string.
 *
 * @param str				String to strip.
 * @param maxlength			maximum length of str.
 * @param c					character index to remove.
 * @noreturn
 */

stock RemoveChar(String:str[], maxlen, c) {
	for (new i = c; i < maxlen-1; i++) {
		str[i] = str[i+1];
	}
	str[maxlen-1] = '\0';
}

/**
 * Strips Game Color codes from a string
 *
 * @param str				String to strip
 * @param maxlength			maximum length of str
 * @noreturn
 */

stock IRC_StripGame(String:str[], maxlen) {
	for (new i = 0; i <= strlen(str); i++) {
		//  Default             Team/LightGreen     Green               Olive
		if (str[i] == '\x01' || str[i] == '\x03' || str[i] == '\x04' || str[i] == '\x05')
			RemoveChar(str, maxlen, i);
	}
}

/**
 * Performs a standard IRC Like wildcard match, useful for hostmasks.
 *
 * @param str			String to check
 * @param wildcard		Wildcard to check against string
 * @return				true if match, false otherwise.
 */

stock bool:IRC_IsWildCardMatch(const String:str[], const String:wildcard[]) {
	new wildpos = 0;
	for (new a = 0; a <= strlen(str); a++) { 		
		if (wildcard[wildpos] == '*') {
			if (wildpos == strlen(wildcard))
				return true;
			if (CharToLower(str[a]) == CharToLower(wildcard[wildpos+1]))
				wildpos += 2;
		}
		else if (wildcard[wildpos] == '?') {
			wildpos++;
		}
		else if (CharToLower(str[a]) == CharToLower(wildcard[wildpos])) {
			wildpos++;
		}
		else {
			return false;
		}
	}
	if (wildpos == strlen(wildcard))
		return false;
	return true;
}
