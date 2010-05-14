/**
 * HLstatsX Community Edition - SourceMod plugin to generate advanced weapon logging
 * http://www.hlxcommunity.com
 * Copyright (C) 2008 Nicholas Hastings
 * Copyright (C) 2007-2008 TTS Oetzel & Goerz GmbH
 *
 * Code to support Fistful of Frags taken from FuraX49's wsl_fof plugin
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#pragma semicolon 1
 
#include <sourcemod>
#include <sdktools>

#define NAME "SuperLogs: FOF"
#define VERSION "1.1.0"

#define MAX_LOG_WEAPONS 18
#define MAX_WEAPON_LEN 16


new g_weapon_stats[MAXPLAYERS+1][MAX_LOG_WEAPONS][15];
new const String:g_weapon_list[MAX_LOG_WEAPONS][MAX_WEAPON_LEN] = {
									"peacemaker", 
									"carbine",
									"coltnavy",
									"henryrifle",
									"coachgun",
									"winchester",
									"henryrifle",
									"dualnavy",
									"dualpeacemaker", 
									"arrow",
									"bow",
									"sharps",
									"deringer",
									"explosive_arrow",
									"arrow_fiery",
									"coltnavy2",
									"deringer2",
									"peacemaker2"
								};
								
new Handle:g_cvar_wstats = INVALID_HANDLE;
new Handle:g_cvar_headshots = INVALID_HANDLE;
new Handle:g_cvar_locations = INVALID_HANDLE;
new Handle:g_cvar_actions = INVALID_HANDLE;

new bool:g_logwstats = true;
new bool:g_logheadshots = true;
new bool:g_loglocations = true;
new bool:g_logactions = true;

#include <loghelper>
#include <wstatshelper>


public Plugin:myinfo = {
	name = NAME,
	author = "psychonic",
	description = "Advanced logging for Fistful of Frags. Generates auxilary logging for use with log parsers such as HLstatsX and Psychostats",
	version = VERSION,
	url = "http://www.hlxcommunity.com"
};


public OnPluginStart()
{
	CreatePopulateWeaponTrie();
	
	g_cvar_wstats = CreateConVar("superlogs_wstats", "1", "Enable logging of weapon stats (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_headshots = CreateConVar("superlogs_headshots", "1", "Enable logging of headshot player action (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_locations = CreateConVar("superlogs_locations", "1", "Enable logging of location on player death if kill logging is enabled (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_actions = CreateConVar("superlogs_actions", "1", "Enable logging of actions, such as Round_Win (default on)", 0, true, 0.0, true, 1.0);
	HookConVarChange(g_cvar_wstats, OnCvarWstatsChange);
	HookConVarChange(g_cvar_headshots, OnCvarHeadshotsChange);
	HookConVarChange(g_cvar_locations, OnCvarLocationsChange);
	HookConVarChange(g_cvar_actions, OnCvarActionsChange);
				
	CreateConVar("superlogs_fof_version", VERSION, NAME, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd);
	hook_wstats();
	
	if (g_logwstats)
	{
		hook_wstats();
	}
		
	CreateTimer(1.0, LogMap);
	
	GetTeams();
}


public OnMapStart()
{
	GetTeams();
}

hook_wstats()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt",  Event_PlayerHurt);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_shoot",  Event_PlayerShoot);
}


unhook_wstats()
{
	HookEvent("player_death", Event_PlayerDeath);
	UnhookEvent("player_hurt",  Event_PlayerHurt);
	UnhookEvent("player_spawn", Event_PlayerSpawn);
	UnhookEvent("player_shoot",  Event_PlayerShoot);
}


public Event_PlayerShoot(Handle:event, const String:name[], bool:dontBroadcast)
{
	//	"userid" "local" // user ID on server
	//	"weapon" "local" // weapon name
	//	"mode" "local" // weapon mode 0 normal 1 ironsighted 2 fanning

	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (attacker > 0)
	{
		decl String: weapon[MAX_WEAPON_LEN];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		new weapon_index = get_weapon_index(weapon[7]);
		if (weapon_index > -1)
		{
			g_weapon_stats[attacker][weapon_index][LOG_HIT_SHOTS]++;
		}
	}
}


public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	//	"userid" "short" // user ID who was hurt
	//	"attacker" "short" // user ID who attacked
	//	"weapon" "string" // weapon name attacker used
	//	"health" "byte" // health remaining
	//	"damage" "byte" // how much damage in this attack
	//	"hitgroup" "byte" // what hitgroup was hit

	
	new attacker  = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (attacker > 0)
	{
		decl String: weapon[MAX_WEAPON_LEN];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		new weapon_index = get_weapon_index(weapon[7]);
		if (weapon_index > -1)
		{
			g_weapon_stats[attacker][weapon_index][LOG_HIT_HITS]++;
			g_weapon_stats[attacker][weapon_index][LOG_HIT_DAMAGE]  += GetEventInt(event, "damage");
			new hitgroup  = GetEventInt(event, "hitgroup");
			if (hitgroup < 8)
			{
				g_weapon_stats[attacker][weapon_index][hitgroup + LOG_HIT_OFFSET]++;
			}
			else
			{
				g_weapon_stats[attacker][weapon_index][hitgroup]++;
			}
		}
	}
}


public Action:Event_PlayerDeathPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (g_loglocations)
	{
		LogKillLoc(attacker, GetClientOfUserId(GetEventInt(event, "userid")));
	}
	
	if (g_logheadshots && GetEventBool(event, "headshot"))
	{
		LogPlayerEvent(attacker, "triggered", "headshot");
	}
	
	return Plugin_Continue;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	//	"userid"	"short"   	// user ID who died				
	//	"attacker"	"short"	 	// user ID who killed
	//	"weapon"	"string" 	// weapon name killed used 
	//	"headshot"      "bool" // player dies from a headshot?

	new victim   = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (g_logwstats && victim > 0 && attacker > 0)
	{
		decl String: weapon[MAX_WEAPON_LEN];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		if (g_logwstats)
		{
			new weapon_index = get_weapon_index(weapon[7]);
			if (weapon_index > -1)
			{
				g_weapon_stats[attacker][weapon_index][LOG_HIT_KILLS]++;
				if (GetEventBool(event, "headshot"))
				{
					g_weapon_stats[attacker][weapon_index][LOG_HIT_HEADSHOTS]++;
				}
				g_weapon_stats[victim][weapon_index][LOG_HIT_DEATHS]++;
				if ( GetClientTeam(attacker) == GetClientTeam(victim))
				{
					g_weapon_stats[attacker][weapon_index][LOG_HIT_TEAMKILLS]++;
				}
				dump_player_stats(victim);
			}
		}
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// "userid"        "short"         // user ID on server          

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		reset_player_stats(client);
	}
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_logwstats)
	{
		WstatsDumpAll();
	}
	if (g_logactions)
	{
		new team = GetEventInt(event, "TWinner");
		if (team == 2 || team == 3)
		{
			LogTeamEvent(team, "triggered", "Round_Win");
		}
	}
}

public Action:LogMap(Handle:timer)
{
	// Called 1 second after OnPluginStart since srcds does not log the first map loaded. Idea from Stormtrooper's "mapfix.sp" for psychostats
	LogMapLoad();
}


public OnCvarWstatsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_logwstats;
	g_logwstats = GetConVarBool(g_cvar_wstats);
	
	if (old_value != g_logwstats)
	{
		if (g_logwstats)
		{
			hook_wstats();
			if (!g_logactions)
			{
				HookEvent("round_end", Event_RoundEnd);
			}
		}
		else
		{
			unhook_wstats();
			if (!g_logactions)
			{
				UnhookEvent("round_end", Event_RoundEnd);
			}
		}
	}
}


public OnCvarHeadshotsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_logheadshots;
	g_logheadshots = GetConVarBool(g_cvar_headshots);
	
	if (old_value != g_logheadshots)
	{
		if (g_logheadshots && !g_loglocations)
		{
			HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		}
		else if (!g_loglocations)
		{
			UnhookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		}
	}
}


public OnCvarLocationsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_loglocations;
	g_loglocations = GetConVarBool(g_cvar_locations);
	
	if (old_value != g_loglocations)
	{
		if (g_loglocations && !g_logheadshots)
		{
			HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		}
		else if (!g_logheadshots)
		{
			UnhookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		}
	}
}

public OnCvarActionsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_logactions;
	g_logactions = GetConVarBool(g_cvar_actions);
	
	if (old_value != g_logactions)
	{
		if (g_logactions && !g_logwstats)
		{
			HookEvent("round_end", Event_RoundEnd);
		}
		else if (!g_logwstats)
		{
			UnhookEvent("round_end", Event_RoundEnd);
		}
	}
}
