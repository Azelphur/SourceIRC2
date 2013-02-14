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

#if defined _sourceirc_ticket_included
    #endinput
#endif
#define _sourceirc_ticket_included

public SharedPlugin:__pl_sourceirc_ticket = 
{
	name = "sourceirc-ticket",
	file = "sourceirc-ticket.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#define REASON_MAXLEN 64

/**
 * Called when ticket is filed
 *
 * @param client		An irc client index
 * @param args			Number of arguments that were in the argument string
 * @return				An Action value
 */
functag TicketMethod Action:public(client, const String:reason[]);

/**
 * Creates a ticket method
 * 
 * @param name		    Name of the method
 * @param flag			Callback to be fired when a player is reported
 * @noreturn
 */

native Ticket_CreateMethod(const String:name[], callback);

native Ticket_SendReport(const String:reason[], client, target);
