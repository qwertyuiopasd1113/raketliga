const int FB_ROUND_NONE = 0;
const int FB_ROUND_PREROUND = 1;
const int FB_ROUND_ROUND = 2;
const int FB_ROUND_ROUNDFINISHED = 3;
const int FB_ROUND_POSTROUND = 4;


Futsball futsball;

class Futsball
{
    int state;
    int numRounds;
    uint roundStateStartTime;
    uint roundStateEndTime;
    int countDown;

    Futsball()
    {
        this.state = FB_ROUND_NONE;
        this.numRounds = 0;
        this.roundStateStartTime = 0;
        this.countDown = 0;
    }
    ~Futsball(){}

    void newGame()
    {
        this.numRounds = 0;
        this.newRound();

        gametype.readyAnnouncementEnabled = false;
        gametype.scoreAnnouncementEnabled = false;
        gametype.countdownEnabled = false;

        for ( uint i = 0; i < uint(maxClients); i++ )
        {
            goals[i] = 0;
            owngoals[i] = 0;
        }
        FB_Ball.resetPos(0.0);
    }

    void endGame()
    {
        this.newRoundState( FB_ROUND_NONE );
        GENERIC_SetUpEndMatch();
    }


    void newRound()
    {
        this.newRoundState( FB_ROUND_PREROUND );
        this.numRounds++;
    }

    void newRoundState( int newState )
    {
        if ( newState > FB_ROUND_POSTROUND )
        {
            this.newRound();
            return;
        }

        this.state = newState;
        this.roundStateStartTime = levelTime;

        switch ( this.state )
        {
            case FB_ROUND_NONE:
            {
                this.roundStateEndTime = 0;
                this.countDown = 0;
            }
            break;
            case FB_ROUND_PREROUND:
            {
                this.roundStateEndTime = levelTime + 4000;
                this.countDown = 4;

                gametype.shootingDisabled = true;
                gametype.removeInactivePlayers = false;

                // respawn players
                Entity@ ent;
                Team@ team;
                for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
                {
                    @team = @G_GetTeam( i );
                    for ( int j = 0; @team.ent(j) != null; j++ )
                    {
                        @ent = @team.ent(j);
                        ent.client.respawn(false);
                        ent.client.pmoveMaxSpeed = 0;
                        ent.client.pmoveDashSpeed = 0;
                        ent.client.pmoveFeatures = ent.client.pmoveFeatures
                            & ~( PMFEAT_WALK | PMFEAT_JUMP | PMFEAT_DASH | PMFEAT_WALLJUMP );
                    }
                }
                FB_Ball.hover = true;
                FB_Ball.particles.svflags |= SVF_NOCLIENT;
                FB_Ball.resetPos(0.0);
            }
            break;
            case FB_ROUND_ROUND:
            {
                this.countDown = 0;
                this.roundStateEndTime = 0;

                gametype.shootingDisabled = false;
                gametype.removeInactivePlayers = true;

                int soundIndex = G_SoundIndex( "sounds/futsball/announcer_siren_1.ogg" );
                G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                G_CenterPrintMsg( null, 'Go!');

                Entity@ ent;
                Team@ team;
                for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
                {
                    @team = @G_GetTeam( i );
                    for ( int j = 0; @team.ent(j) != null; j++ )
                    {
                        @ent = @team.ent(j);
                        ent.client.pmoveMaxSpeed = -1;
                        ent.client.pmoveDashSpeed = 1000;
                        ent.client.pmoveFeatures = ent.client.pmoveFeatures
                            | ( PMFEAT_WALK | PMFEAT_JUMP | PMFEAT_DASH | PMFEAT_WALLJUMP );
                    }
                }
                FB_Ball.hover = false;
                FB_Ball.scored = false;
                FB_Ball.particles.svflags &= ~SVF_NOCLIENT;
            }
            break;
            case FB_ROUND_ROUNDFINISHED:
            {
                this.roundStateEndTime = levelTime + 1500;
                this.countDown = 0;

                gametype.shootingDisabled = false;
            }
            break;
            case FB_ROUND_POSTROUND:
            {
                this.roundStateEndTime = levelTime + 1000;
            }
            break;
            default:
                break;
        }
    }

    void think()
    {
        for ( int i = 0; i < maxClients; i++ )
        {
            if ( !G_GetClient(i).getEnt().isGhosting() )
            {
                jetpacks[i].Update();
            } else {
                chaseCams[i].Update();
            }
        }

        FB_Ball.Update();

        if ( this.state == FB_ROUND_NONE )
            return;

        if ( this.roundStateEndTime != 0 )
        {
            if ( this.roundStateEndTime < levelTime )
            {
                this.newRoundState( this.state + 1 );
                return;
            }

            if ( this.countDown > 0 )
            {
                int remaining = int( (this.roundStateEndTime - levelTime) * 0.001f ) + 1;
                if ( remaining < 0 )
                    remaining = 0;

                if ( remaining < this.countDown )
                {
                    this.countDown = remaining;
                    if ( this.countDown <= 3 )
                    {
                        int soundIndex = G_SoundIndex( "sounds/futsball/announcer_siren_0" );
                        G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                    }
                    G_CenterPrintMsg( null, String( this.countDown ) );
                }
            }
        }

        if ( this.state == FB_ROUND_ROUND )
        {
            // do stuff?
        }
    }

    void SetUpWarmup()
    {
        int j;
        Team @team;

        gametype.shootingDisabled = false;
        gametype.readyAnnouncementEnabled = true;
        gametype.scoreAnnouncementEnabled = false;
        gametype.countdownEnabled = false;

        if ( gametype.isTeamBased )
        {
            bool anyone = false;
            int t;

            for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
            {
                @team = @G_GetTeam( t );
                team.clearInvites();

                for ( j = 0; @team.ent( j ) != null; j++ )
                    GENERIC_ClearQuickMenu( @team.ent( j ).client );
            
                if ( team.unlock() )
                    anyone = true;
            }

            if ( anyone )
                G_PrintMsg( null, "Teams unlocked.\n" );
        }
        else
        {
            @team = @G_GetTeam( TEAM_PLAYERS );
            team.clearInvites();

            for ( j = 0; @team.ent( j ) != null; j++ )
                GENERIC_ClearQuickMenu( @team.ent( j ).client );
            
            if ( team.unlock() )
                G_PrintMsg( null, "Teams unlocked.\n" );
        }

        match.name = "";
    }

    void SetUpCountdown()
    {
        gametype.shootingDisabled = true;
        gametype.readyAnnouncementEnabled = false;
        gametype.scoreAnnouncementEnabled = false;
        gametype.countdownEnabled = false;
        G_RemoveAllProjectiles();

        // lock teams
        bool anyone = false;
        if ( gametype.isTeamBased )
        {
            for ( int team = TEAM_ALPHA; team < GS_MAX_TEAMS; team++ )
            {
                if ( G_GetTeam( team ).lock() )
                    anyone = true;
            }
        }
        else
        {
            if ( G_GetTeam( TEAM_PLAYERS ).lock() )
                anyone = true;
        }

        if ( anyone )
            G_PrintMsg( null, "Teams locked.\n" );

        // Countdowns should be made entirely client side, because we now can

        int soundIndex = G_SoundIndex( "sounds/gladiator/let_the_games_begin" );
        G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
    }
}