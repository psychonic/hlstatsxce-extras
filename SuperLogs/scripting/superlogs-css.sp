/**
 * HLstatsX Community Edition - SourceMod plugin to generate advanced weapon logging
 * http://www.hlxcommunity.com
 * Copyright (C) 2009 Nicholas Hastings (psychonic)
 * Copyright (C) 2007-2008 TTS Oetzel & Goerz GmbH
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

#define NAME "SuperLogs: CSS"
#define VERSION "1.0.2"

#define MAX_LOG_WEAPONS 28
#define IGNORE_SHOTS_START 25
#define MAX_WEAPON_LEN 13


new g_weapon_stats[MAXPLAYERS+1][MAX_LOG_WEAPONS][15];
new const String:g_weapon_list[MAX_LOG_WEAPONS][MAX_WEAPON_LEN] = {
									"ak47", 
									"m4a1",
									"awp", 
									"deagle",
									"mp5navy",
									"aug", 
									"p90",
									"famas",
									"galil",
									"scout",
									"g3sg1",
									"usp",
									"glock",
									"m249",
									"m3",
									"elite",
									"fiveseven",
									"mac10",
									"p228",
									"sg550",
									"sg552",
									"tmp",
									"ump45",
									"xm1014",
									"knife",
									"hegrenade",
									"smokegrenade",
									"flashbang"
								};
								
new g_weapon_hashes[MAX_LOG_WEAPONS];

new Handle:g_cvar_wstats = INVALID_HANDLE;
new Handle:g_cvar_headshots = INVALID_HANDLE;
new Handle:g_cvar_locations = INVALID_HANDLE;

new bool:g_logwstats = true;
new bool:g_logheadshots = true;
new bool:g_loglocations = true;

#include <loghelper>
#include <wstatshelper>


public Plugin:myinfo = {
	name = NAME,
	author = "psychonic",
	description = "Advanced logging for CSS. Generates auxilary logging for use with log parsers such as HLstatsX and Psychostats",
	version = VERSION,
	url = "http://www.hlxcommunity.com"
};


public OnPluginStart()
{
	CalcInitialHashes();
	
	g_cvar_wstats = CreateConVar("superlogs_wstats", "1", "Enable logging of weapon stats (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_headshots = CreateConVar("superlogs_headshots", "1", "Enable logging of headshot player action (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_locations = CreateConVar("superlogs_locations", "1", "Enable logging of location on player death (default on)", 0, true, 0.0, true, 1.0);
	HookConVarChange(g_cvar_wstats, OnCvarWstatsChange);
	HookConVarChange(g_cvar_headshots, OnCvarHeadshotsChange);
	HookConVarChange(g_cvar_locations, OnCvarLocationsChange);
	CreateConVar("superlogs_css_version", VERSION, NAME, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
		
	hook_wstats();
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		
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
	HookEvent("weapon_fire", Event_PlayerShoot);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

unhook_wstats()
{
	UnhookEvent("player_death", Event_PlayerDeath);
	UnhookEvent("weapon_fire", Event_PlayerShoot);
	UnhookEvent("player_hurt", Event_PlayerHurt);
	UnhookEvent("player_spawn", Event_PlayerSpawn);
	UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}


public Event_PlayerShoot(Handle:event, const String:name[], bool:dontBroadcast)
{
	// "userid"        "short"
	// "weapon"        "string"        // weapon name used

	new attacker   = GetClientOfUserId(GetEventInt(event, "userid"));
	if (attacker > 0)
	{
		decl String: weapon[MAX_WEAPON_LEN];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		new weapon_index = get_weapon_index(weapon);
		if (weapon_index > -1 && weapon_index < IGNORE_SHOTS_START)
		{
			g_weapon_stats[attacker][weapon_index][LOG_HIT_SHOTS]++;
		}
	}
}


public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	//	"userid"        "short"         // player index who was hurt
	//	"attacker"      "short"         // player index who attacked
	//	"health"        "byte"          // remaining health points
	//	"armor"         "byte"          // remaining armor points
	//	"weapon"        "string"        // weapon name attacker used, if not the world
	//	"dmg_health"    "byte"  		// damage done to health
	//	"dmg_armor"     "byte"          // damage done to armor
	//	"hitgroup"      "byte"          // hitgroup that was damaged

	new attacker  = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (attacker > 0) {
		decl String: weapon[MAX_WEAPON_LEN];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		new weapon_index = get_weapon_index(weapon);
		if (weapon_index > -1)
		{
			g_weapon_stats[attacker][weapon_index][LOG_HIT_HITS]++;
			g_weapon_stats[attacker][weapon_index][LOG_HIT_DAMAGE] += GetEventInt(event, "dmg_health");
			new hitgroup  = GetEventInt(event, "hitgroup");
			if (hitgroup < 8)
			{
				g_weapon_stats[attacker][weapon_index][hitgroup + LOG_HIT_OFFSET]++;
			}
		}
	}
}


public Action:Event_PlayerDeathPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	// "userid"        "short"         // user ID who died                             
	// "attacker"      "short"         // user ID who killed
	// "weapon"        "string"        // weapon name killer used 
	// "headshot"      "bool"          // signals a headshot
	
	new attacker = GetEventInt(event, "attacker");
	if (g_loglocations)
	{
		LogKillLoc(GetClientOfUserId(attacker), GetClientOfUserId(GetEventInt(event, "userid")));
	}

	if (g_logheadshots && GetEventBool(event, "headshot"))
	{
		LogPlayerEvent(GetClientOfUserId(attacker), "triggered", "headshot");
	}
	
	return Plugin_Continue;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// this extents the original player_death by a new fields
	// "userid"        "short"         // user ID who died                             
	// "attacker"      "short"         // user ID who killed
	// "weapon"        "string"        // weapon name killer used 
	// "headshot"      "bool"          // signals a headshot
	
	new victim   = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (g_logwstats && victim > 0 && attacker > 0)
	{
		decl String: weapon[MAX_WEAPON_LEN];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		new weapon_index = get_weapon_index(weapon);
		if (weapon_index > -1)
		{
			g_weapon_stats[attacker][weapon_index][LOG_HIT_KILLS]++;
			if (GetEventBool(event, "headshot"))
			{
				g_weapon_stats[attacker][weapon_index][LOG_HIT_HEADSHOTS]++;
			}
			g_weapon_stats[victim][weapon_index][LOG_HIT_DEATHS]++;
			if (GetClientTeam(attacker) == GetClientTeam(victim))
			{
				g_weapon_stats[attacker][weapon_index][LOG_HIT_TEAMKILLS]++;
			}
			dump_player_stats(victim);
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
	WstatsDumpAll();
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
		}
		else
		{
			unhook_wstats();
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
