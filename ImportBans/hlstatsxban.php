<?php
/***************
** Deactivate HLstatsX ranking for banned players
** and reactivate them if unbanned
** Supports SourceBans, AMXBans, Beetlesmod, Globalban, MySQL Banning*
** by Jannik 'Peace-Maker' Hartung
** http://www.sourcebans.net/, http://www.wcfan.de/

** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
**
**
** Version 1.3: Added MySQL Banning support
** Version 1.2: Added more error handling
** Version 1.1: Fixed banned players not marked as banned, if a previous ban was unbanned
** Version 1.0: Initial Release
***************/

//** SOURCEBANS MYSQL INFO ----------------------------
// http://www.sourcebans.net/
define('SB_HOST', 'localhost');      // MySQL host
define('SB_PORT', 3306);             // MySQL port (Default 3306)
define('SB_USER', '');               // MySQL user
define('SB_PASS', '');               // MySQL password
define('SB_NAME', '');               // MySQL database name
define('SB_PREFIX', 'sb');           // MySQL table prefix
//** END SOURCEBANS MYSQL INFO ------------------------

//** AMXBANS MYSQL INFO -------------------------------
// http://www.amxbans.net/
define('AMX_HOST', 'localhost');      // MySQL host
define('AMX_PORT', 3306);             // MySQL port (Default 3306)
define('AMX_USER', '');               // MySQL user
define('AMX_PASS', '');               // MySQL password
define('AMX_NAME', '');               // MySQL database name
define('AMX_PREFIX', 'amx');          // MySQL table prefix
//** END AMXBANS MYSQL INFO ---------------------------

//** BEETLESMOD MYSQL INFO ----------------------------
// http://www.beetlesmod.com/
define('BM_HOST', 'localhost');       // MySQL host
define('BM_PORT', 3306);              // MySQL port (Default 3306)
define('BM_USER', '');                // MySQL user
define('BM_PASS', '');                // MySQL password
define('BM_NAME', '');                // MySQL database name
define('BM_PREFIX', 'bm');            // MySQL table prefix
//** END BEETLESMOD MYSQL INFO ------------------------

//** GLOBALBAN MYSQL INFO -----------------------------
// http://addons.eventscripts.com/addons/view/GlobalBan
// http://forums.eventscripts.com/viewtopic.php?t=14384
define('GB_HOST', 'localhost');       // MySQL host
define('GB_PORT', 3306);              // MySQL port (Default 3306)
define('GB_USER', '');                // MySQL user
define('GB_PASS', '');                // MySQL password
define('GB_NAME', 'global_ban');      // MySQL database name
define('GB_PREFIX', 'gban');          // MySQL table prefix
//** END GLOBALBAN MYSQL INFO -------------------------

//** MySQL Banning - MYSQL INFO -----------------------
// http://forums.alliedmods.net/showthread.php?t=65822
define('MB_HOST', 'localhost');       // MySQL host
define('MB_PORT', 3306);              // MySQL port (Default 3306)
define('MB_USER', '');                // MySQL user
define('MB_PASS', '');                // MySQL password
define('MB_NAME', '');                // MySQL database name
define('MB_PREFIX', 'mysql');         // MySQL table prefix
//** END MySQL Banning - MYSQL INFO -------------------

//** HLSTATSX MYSQL INFO ------------------------------
// http://www.hlxcommunity.com/
define('HLX_HOST', 'localhost');      // MySQL host
define('HLX_PORT', 3306);             // MySQL port (Default 3306)
define('HLX_USER', '');               // MySQL user
define('HLX_PASS', '');               // MySQL password
define('HLX_PREFIX', 'hlstats');      // MySQL table prefix

/*************************************************
/* We're using different databases for each of our server to isolate each ranking
/* Type the HLstatsX database name here like
/* $hlxdbs[] = "databasename";
/* It's fine to just type one database.
**************************************************/
$hlxdbs = array();
$hlxdbs[] = "hlstatsx";
//** END HLSTATSX MYSQL INFO --------------------------









/*****************************
/***** DON'T EDIT BELOW ******
/*****************************/

if (!extension_loaded('mysqli')) {
	die("This script requires the MySQLi extension to be enabled.  Consult your administrator, or edit your php.ini file, to enable this extension.");
}

$usesb = (SB_HOST == ""||SB_PORT == ""||SB_USER == ""||SB_PASS == ""||SB_NAME == ""||SB_PREFIX == ""?false:true);
$useamx = (AMX_HOST == ""||AMX_PORT == ""||AMX_USER == ""||AMX_PASS == ""||AMX_NAME == ""||AMX_PREFIX == ""?false:true);
$usebm = (BM_HOST == ""||BM_PORT == ""||BM_USER == ""||BM_PASS == ""||BM_NAME == ""||BM_PREFIX == ""?false:true);
$usegb = (GB_HOST == ""||GB_PORT == ""||GB_USER == ""||GB_PASS == ""||GB_NAME == ""||GB_PREFIX == ""?false:true);
$usemb = (MB_HOST == ""||MB_PORT == ""||MB_USER == ""||MB_PASS == ""||MB_NAME == ""||MB_PREFIX == ""?false:true);
$hlxready = (HLX_HOST == ""||HLX_PORT == ""||HLX_USER == ""||HLX_PASS == ""||empty($hlxdbs)||HLX_PREFIX == ""?false:true);

if (!$hlxready || (!$usesb && !$useamx && !$usebm && !$usegb && !$usemb))
    die('[-] Please type your database information for HLstatsX and at least for one other ban database.');

$bannedplayers = array();
$unbannedplayers = array();

//------------------------------
// SourceBans Part
//------------------------------
if ($usesb)
{
    // Connect to the SourceBans database.
    $con = new mysqli(SB_HOST, SB_USER, SB_PASS, SB_NAME, SB_PORT);
    if (mysqli_connect_error()) die('[-] Can\'t connect to SourceBans Database (' . mysqli_connect_errno() . ') ' . mysqli_connect_error());
    
    print("[+] Successfully connected to SourceBans database. Retrieving bans now.\n");
    
    // Get permanent banned players
    $bcnt = 0;
    if ($bans = $con->query("SELECT `authid` FROM `".SB_PREFIX."_bans` WHERE `RemoveType` IS NULL AND `length` = 0") == FALSE)
        die('[-] Error retrieving banned players: ' . $con->error);
        
    while ($banned = $bans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($banned["authid"], $bannedplayers))
        {
            $bannedplayers[] = $banned["authid"];
            ++$bcnt;
        }
    }
    // Read unbanned players
    $ubcnt = 0;
    if ($unbans = $con->query("SELECT `authid` FROM `".SB_PREFIX."_bans` WHERE `RemoveType` IS NOT NULL AND `length` = 0") == FALSE)
        die('[-] Error retrieving unbanned players: ' . $con->error);
    
    while ($unbanned = $unbans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($unbanned["authid"], $bannedplayers) && !in_array($unbanned["authid"], $unbannedplayers))
        {
            $unbannedplayers[] = $unbanned["authid"];
            ++$ubcnt;
        }
    }
    $con->close();
    print("[+] Retrieved ".$bcnt." banned and ".$ubcnt." unbanned players from SourceBans.\n");
}

//------------------------------
// AMXBans Part
//------------------------------
if ($useamx)
{
    // Connect to the AMXBans database.
    $con = new mysqli(AMX_HOST, AMX_USER, AMX_PASS, AMX_NAME, AMX_PORT);
    if (mysqli_connect_error()) die('[-] Can\'t connect to AMXBans Database (' . mysqli_connect_errno() . ') ' . mysqli_connect_error());

    print("[+] Successfully connected to AMXBans database. Retrieving bans now.\n");
    
    // Get permanent banned players
    $bcnt = 0;
    if ($bans = $con->query("SELECT `player_id` FROM `".AMX_PREFIX."_bans` WHERE `ban_length` = 0") == FALSE)
        die('[-] Error retrieving banned players: ' . $con->error);
        
    while ($banned = $bans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($banned["player_id"], $bannedplayers))
        {
            $bannedplayers[] = $banned["player_id"];
            ++$bcnt;
        }
    }
    // Read unbanned players
    $ubcnt = 0;
    if ($unbans = $con->query("SELECT `player_id` FROM `".AMX_PREFIX."_banhistory` WHERE `ban_length` = 0") == FALSE)
        die('[-] Error retrieving unbanned players: ' . $con->error);
    
    while ($unbanned = $unbans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($unbanned["player_id"], $bannedplayers) && !in_array($unbanned["player_id"], $unbannedplayers))
        {
            $unbannedplayers[] = $unbanned["player_id"];
            ++$ubcnt;
        }
    }
    $con->close();
    print("[+] Retrieved ".$bcnt." banned and ".$ubcnt." unbanned players from AMXBans.\n");
}

//------------------------------
// Beetlesmod Part
//------------------------------
if ($usebm)
{
    // Connect to the Beetlesmod database.
    $con = new mysqli(BM_HOST, BM_USER, BM_PASS, BM_NAME, BM_PORT);
    if (mysqli_connect_error()) die('[-] Can\'t connect to Beetlesmod Database (' . mysqli_connect_errno() . ') ' . mysqli_connect_error());

    print("[+] Successfully connected to Beetlesmod database. Retrieving bans now.\n");

    // Get permanent banned players
    $bcnt = 0;
    if ($bans = $con->query("SELECT `steamid` FROM `".BM_PREFIX."_bans` WHERE `Until` IS NULL") == FALSE)
        die('[-] Error retrieving banned players: ' . $con->error);
    
    while ($banned = $bans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($banned["steamid"], $bannedplayers))
        {
            $bannedplayers[] = $banned["steamid"];
            ++$bcnt;
        }
    }
    // Read unbanned players
    $ubcnt = 0;
    if ($unbans = $con->query("SELECT `steamid` FROM `".BM_PREFIX."_bans` WHERE `Until` IS NULL AND `Remove` = 0") == FALSE)
        die('[-] Error retrieving unbanned players: ' . $con->error);
    
    while ($unbanned = $unbans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($unbanned["steamid"], $bannedplayers) && !in_array($unbanned["steamid"], $unbannedplayers))
        {
            $unbannedplayers[] = $unbanned["steamid"];
            ++$ubcnt;
        }
    }
    $con->close();
    print("[+] Retrieved ".$bcnt." banned and ".$ubcnt." unbanned players from Beetlesmod.\n");
}

//------------------------------
// Globalban Part
//------------------------------
if ($usegb)
{
    // Connect to the Globalban database.
    $con = new mysqli(GB_HOST, GB_USER, GB_PASS, GB_NAME, GB_PORT);
    if (mysqli_connect_error()) die('[-] Can\'t connect to Globalban Database (' . mysqli_connect_errno() . ') ' . mysqli_connect_error());

    print("[+] Successfully connected to Globalban database. Retrieving bans now.\n");

    // Get permanent banned players
    $bcnt = 0;
    if ($bans = $con->query("SELECT `steam_id` FROM `".GB_PREFIX."_ban` WHERE `active` = 1 AND `pending` = 0 AND `length` = 0") == FALSE)
        die('[-] Error retrieving banned players: ' . $con->error);
    
    while ($banned = $bans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($banned["steam_id"], $bannedplayers))
        {
            $bannedplayers[] = $banned["steam_id"];
            ++$bcnt;
        }
    }
    // Read unbanned players
    $ubcnt = 0;
    if ($unbans = $con->query("SELECT `steam_id` FROM `".GB_PREFIX."_ban` WHERE `active` = 0 AND `pending` = 0 AND `length` = 0") == FALSE)
        die('[-] Error retrieving unbanned players: ' . $con->error);
    
    while ($unbanned = $unbans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($unbanned["steam_id"], $bannedplayers) && !in_array($unbanned["steam_id"], $unbannedplayers))
        {
            $unbannedplayers[] = $unbanned["steam_id"];
            ++$ubcnt;
        }
    }
    $con->close();
    print("[+] Retrieved ".$bcnt." banned and ".$ubcnt." unbanned players from Globalban.\n");
}

//------------------------------
// MySQL Banning Part
//------------------------------
if ($usemb)
{
    // Connect to the MySQL Banning database.
    $con = new mysqli(MB_HOST, MB_USER, MB_PASS, MB_NAME, MB_PORT);
    if (mysqli_connect_error()) die('[-] Can\'t connect to MySQL Banning Database (' . mysqli_connect_errno() . ') ' . mysqli_connect_error());

    print("[+] Successfully connected to MySQL Banning database. Retrieving bans now.\n");

    // Get permanent banned players
    $bcnt = 0;
    if ($bans = $con->query("SELECT `steam_id` FROM `".MB_PREFIX."_bans` WHERE `ban_length` = 0") == FALSE)
        die('[-] Error retrieving banned players: ' . $con->error);
    
    while ($banned = $bans->fetch_array(MYSQL_ASSOC)) {
        if(!in_array($banned["steam_id"], $bannedplayers))
        {
            $bannedplayers[] = $banned["steam_id"];
            ++$bcnt;
        }
    }
    /****** SM MySQL Banning doesn't provide a ban history AFAIK ******/
    
    // Read unbanned players
    // $ubcnt = 0;
    // if ($unbans = $con->query("SELECT `steam_id` FROM `".MB_PREFIX."_bans` WHERE `ban_length` = 0") !== TRUE)
        // die('[-] Error retrieving unbanned players: ' . $con->error);
    
    // while ($unbanned = $unbans->fetch_array(MYSQL_ASSOC)) {
        // if(!in_array($unbanned["steam_id"], $bannedplayers) && !in_array($unbanned["steam_id"], $unbannedplayers))
        // {
            // $unbannedplayers[] = $unbanned["steam_id"];
            // ++$ubcnt;
        // }
    // }
    $con->close();
    //print("[+] Retrieved ".$bcnt." banned and ".$ubcnt." unbanned players from MySQL Banning.\n");
    print("[+] Retrieved ".$bcnt." banned players from MySQL Banning.\n");
}

//------------------------------
// HLstatsX Part
//------------------------------

if(empty($bannedplayers) && empty($unbannedplayers))
    die('[-] Nothing to change. Exiting.');

// Implode data
$bannedsteamids = implode(",", $bannedplayers);
$unbannedsteamids = implode(",", $unbannedplayers);

// Connection to DB
$hlxcon = new mysqli(HLX_HOST, HLX_USER, HLX_PASS, '', HLX_PORT);
if (mysqli_connect_error()) die('[-] Can\'t connect to HLstatsX Database (' . mysqli_connect_errno() . ') ' . mysqli_connect_error());

print("[+] Successfully connected to HLstatsX database server. Updating players...\n");

// Loop through all hlstatsx databases
foreach ($hlxdbs as $hlxdb)
{
    $unbancnt = $bancnt = 0;
    $hlxcon->select_db($hlxdb);
    // Hide all banned players
    if ($hlxban = $hlxcon->query("UPDATE `".HLX_PREFIX."_Players` SET `hideranking` = 2 WHERE `hideranking` < 2 AND `playerId` IN (SELECT `playerId` FROM `".HLX_PREFIX."_PlayerUniqueIds` WHERE `uniqueId` IN (".$bannedsteamids."));") == FALSE)
        die('[-] Error hiding banned players: ' . $hlxcon->error);
    
    $bancnt = ($hlxban->num_rows?$hlxban->num_rows:0);
    // Show all unbanned players
    if ($hlxunban = $hlxcon->query("UPDATE `".HLX_PREFIX."_Players` SET `hideranking` = 0 WHERE `hideranking` = 2 AND `playerId` IN (SELECT `playerId` FROM `".HLX_PREFIX."_PlayerUniqueIds` WHERE `uniqueId` IN (".$unbannedsteamids."));") == FALSE)
        die('[-] Error showing unbanned players: ' . $hlxcon->error);
    
    $unbancnt = ($hlxunban->num_rows?$hlxunban->num_rows:0);
    if ($bancnt>0||$unbancnt>0)
        print("[+] ".$hlxdb.": ".$bancnt." players were marked as banned, ".$unbancnt." players were reenabled again.");
    else
        print("[-] ".$hlxdb.": No player changed.");
}
$hlxcon->close();
?>