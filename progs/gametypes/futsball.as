/*
Copyright (C) 2009-2010 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

//Cvar fb_inventory( "fb_inventory", "gb mg rg gl rl pg lg eb ig cells shells grens rockets plasma lasers bullets instas", 0 );
//Cvar fb_ammo( "fb_ammo", "0 75 20 20 40 125 180 15 10", 0 ); // GB MG RG GL RL PG LG EB
Cvar fb_inventory( "fb_inventory", "", 0 );
Cvar fb_ammo( "fb_ammo", "0 0 0 0 0 0 0 0 0", 0 ); // GB MG RG GL RL PG LG EB IB

int prcYesIcon;

int futsballsound;
int futsballmodel;

Entity@ ball;
Entity@ ball_spawn;
int[] goals;
int[] owngoals;

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{
    for ( int i = 0; i < numEntities; i++ )
    {
        Entity@ ent = @G_GetEntity(i);
        if ( ent.classname == "trigger_multiple" &&
                (ent.target == "goal_alpha" || ent.target == "goal_beta" ) )
        {
            G_Print("spawn goal "+ent.target+"\n");
            Entity@ goal = @G_SpawnEntity("trigger_goal");
            goal.target = ent.target;
            goal.targetname = ent.targetname;
            Vec3 mins, maxs;
            ent.getSize(mins,maxs);
            goal.setSize(mins,maxs);
            goal.origin = ent.origin;
            goal.solid = SOLID_TRIGGER;
            @goal.touch = FB_Goal_Touch;
            @goal.think = FB_Goal_Think;
            goal.nextThink = levelTime + 1;
            goal.linkEntity();

            ent.unlinkEntity();
            ent.freeEntity();
        }
        if ( ent.classname == "func_object" && ent.targetname == "ball" )
        {
            G_Print("found ball\n");

            FB_SpawnBall(@ent);
        }
    }
}

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "cvarinfo" )
    {
        GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
        return true;
    }
    // example of registered command
    else if ( cmdString == "gametype" )
    {
        String response = "";
        Cvar fs_game( "fs_game", "", 0 );
        String manifest = gametype.manifest;

        response += "\n";
        response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
        response += "----------------\n";
        response += "Version: " + gametype.version + "\n";
        response += "Author: " + gametype.author + "\n";
        response += "Mod: " + fs_game.string + (!manifest.empty() ? " (manifest: " + manifest + ")" : "") + "\n";
        response += "----------------\n";

        G_PrintMsg( client.getEnt(), response );
        return true;
    }
    else if ( cmdString == "resetball" )
    {
        if ( argc == 0 )
            return false;
        FB_Ball.resetPos(argsString.getToken(0).toFloat());
        return true;
    }
    else if ( cmdString == "spawntest" )
    {
        Entity@ ent = @G_SpawnEntity("test");
        ent.origin = client.getEnt().origin;
        ent.setSize(Vec3(-16,-16,-16),Vec3(16,16,16));
        ent.solid = SOLID_YES;
        ent.clipMask = MASK_ALL;
        ent.svflags &= ~SVF_NOCLIENT;
        ent.moveType = MOVETYPE_TOSSSLIDE;
        ent.linkEntity();
        return true;
    }

    return false;
}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    if ( self.team == TEAM_ALPHA )
        return @FB_SelectBestRandomTeamSpawnPoint( self, TEAM_ALPHA );
    else
        return @FB_SelectBestRandomTeamSpawnPoint( self, TEAM_BETA );
}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
    int i, t, carrierIcon, readyIcon;

    for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );

        // &t = team tab, team tag, team score, team ping
        entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";
        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;

        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @ent = @team.ent( i );

            carrierIcon = 0;

            readyIcon = 0;

            int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

            // "Name Score Ping C R"
            entry = "&p " + playerID + " " + ent.client.clanName + " "
                    + goals[ent.playerNum] + " " + owngoals[ent.playerNum] + " "
                    + ent.client.ping + " " + ( ent.client.isReady() ? "1" : "0" ) + " ";

            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;
        }
    }

    return scoreboardMessage;
}

// Some game actions get reported to the script as score events.
// Warning: client can be null
void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {
        //G_Print(score_event+" : "+args+"\n");
        Client@ target = G_GetEntity(args.getToken(0).toInt()).client;
        if ( @target != null )
        {
            target.getEnt().health += args.getToken(1);
        }
    }
    else if ( score_event == "kill" )
    {
        Entity @attacker = null;

        if ( @client != null )
            @attacker = @client.getEnt();

        int arg1 = args.getToken( 0 ).toInt();
        int arg2 = args.getToken( 1 ).toInt();

        //CTF_playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "award" )
    {
    }
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
    if ( old_team != new_team )
    {
        // ** MISSING CLEAR SCORES **
        goals[ent.playerNum] = 0;
        owngoals[ent.playerNum] = 0;
    }

    if ( ent.isGhosting() )
        return;

    if ( gametype.isInstagib )
    {
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
        ent.client.inventorySetCount( AMMO_INSTAS, 1 );
        ent.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
    }
    else
    {
        // give the weapons and ammo as defined in cvars
        String token, weakammotoken, ammotoken;
        String itemList = fb_inventory.string;
        String ammoCounts = fb_ammo.string;

        ent.client.inventoryClear();

        for ( int i = 0; ;i++ )
        {
            token = itemList.getToken( i );
            if ( token.len() == 0 )
                break; // done

            Item @item = @G_GetItemByName( token );
            if ( @item == null )
                continue;

            ent.client.inventoryGiveItem( item.tag );

            // if it's ammo, set the ammo count as defined in the cvar
            if ( ( item.type & IT_AMMO ) != 0 )
            {
                token = ammoCounts.getToken( item.tag - AMMO_GUNBLADE );

                if ( token.len() > 0 )
                {
                    ent.client.inventorySetCount( item.tag, token.toInt() );
                }
            }
        }

        // select rocket launcher
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
    }

    // select rocket launcher if available
    if ( ent.client.canSelectWeapon( WEAP_ROCKETLAUNCHER ) )
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
    else
        ent.client.selectWeapon( -1 ); // auto-select best weapon in the inventory

    ent.client.pmoveDashSpeed = 1000;
    ent.client.pmoveFeatures = ent.client.pmoveFeatures | PMFEAT_GHOSTMOVE;

    // add a teleportation effect
    ent.respawnEffect();

    ent.takeDamage = DAMAGE_AIM;
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
    {
        if ( !match.checkExtendPlayTime() )
            match.launchState( match.getState() + 1 );
    }

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
        return;

    GENERIC_Think();

    futsball.think();
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP
            && incomingMatchState < MATCH_STATE_POSTMATCH )
        match.startAutorecord();

    if ( match.getState() == MATCH_STATE_POSTMATCH )
        match.stopAutorecord();

    // check maxHealth rule
    for ( int i = 0; i < maxClients; i++ )
    {
        Entity @ent = @G_GetClient( i ).getEnt();
        if ( ent.client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            if ( ent.health > ent.maxHealth )
                ent.health -= ( frameTime * 0.001f );
        }
    }

    return true;
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{
    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        futsball.SetUpWarmup();
        SpawnIndicators::Create( "team_CTF_alphaplayer", TEAM_ALPHA );
        SpawnIndicators::Create( "team_CTF_alphaspawn", TEAM_ALPHA );
        SpawnIndicators::Create( "team_CTF_betaplayer", TEAM_BETA );
        SpawnIndicators::Create( "team_CTF_betaspawn", TEAM_BETA ); 
        break;

    case MATCH_STATE_COUNTDOWN:
        futsball.SetUpCountdown();
		SpawnIndicators::Delete();	
        break;

    case MATCH_STATE_PLAYTIME:
        futsball.newGame();
        //GENERIC_SetUpMatch();
        break;

    case MATCH_STATE_POSTMATCH:
        futsball.endGame();
        //GENERIC_SetUpEndMatch();
        break;

    default:
        break;
    }
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{
    gametype.title = "FutsBall";
    gametype.version = "0.1";
    gametype.author = "Warsow Development Team";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"wctf1 wctf3 wctf4 wctf5 wctf6\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"1\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"0\"\n"
                 + "set g_timelimit \"20\"\n"
                 + "set g_warmup_timelimit \"1\"\n"
                 + "set g_match_extendedtime \"5\"\n"
                 + "set g_allow_falldamage \"1\"\n"
                 + "set g_allow_selfdamage \"1\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"1\"\n"
                 + "set g_teams_maxplayers \"5\"\n"
                 + "set g_teams_allow_uneven \"0\"\n"
                 + "set g_countdown_time \"5\"\n"
                 + "set g_maxtimeouts \"3\" // -1 = unlimited\n"
                 + "set g_challengers_queue \"0\"\n"
                 + "set ctf_powerupDrop \"0\"\n"
                 + "\necho \"" + gametype.name + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

    gametype.spawnableItemsMask = ( IT_WEAPON | IT_AMMO | IT_ARMOR | IT_POWERUP | IT_HEALTH );
    if ( gametype.isInstagib )
        gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);

    gametype.respawnableItemsMask = gametype.spawnableItemsMask ;
    gametype.dropableItemsMask = gametype.spawnableItemsMask ;
    gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );


    gametype.isTeamBased = true;
    gametype.isRace = false;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 20;
    gametype.armorRespawn = 25;
    gametype.weaponRespawn = 5;
    gametype.healthRespawn = 25;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 20;
    gametype.ultrahealthRespawn = 40;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = true;
    gametype.canForceModels = true;
    gametype.canShowMinimap = false;
    gametype.teamOnlyMinimap = true;

	gametype.mmCompatible = true;
	
    gametype.spawnpointRadius = 0;

    if ( gametype.isInstagib )
    {
        gametype.spawnpointRadius *= 2;
    }

    // set spawnsystem type
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 60 %l 48 %r l1" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Goals OwnGoals Ping R" );

    int bla = G_SoundIndex("sounds/futsball/ball_close_0.ogg", true);
    int bli = G_SoundIndex( "sounds/futsball/announcer_siren_0", true );

    // add commands
    //G_RegisterCommand( "drop" );
    G_RegisterCommand( "gametype" );
    //G_RegisterCommand( "resetball" );
    //G_RegisterCommand( "spawntest" );

    /*G_RegisterCallvote( "ctf_powerup_drop", "1 or 0", "Anables or disables the dropping of powerups at dying in ctf." );
    G_RegisterCallvote( "ctf_flag_instant", "1 or 0", "Anables or disables instant flag captures and unlocks in ctf." );*/

    goals.resize(maxClients);
    owngoals.resize(maxClients);
    for ( int i = 0; i < maxClients; i++ )
    {
        @Players[i].client = @G_GetClient(i);
        @Players[i].player = @G_GetClient(i).getEnt();
    }

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
