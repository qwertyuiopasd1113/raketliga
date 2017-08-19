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

///*****************************************************************
/// SPAWNED ENTITIES
///*****************************************************************


///*****************************************************************
/// NEW MAP ENTITY DEFINITIONS
///*****************************************************************

void team_CTF_teamflag( Entity @ent, int team )
{
}

void team_CTF_betaflag( Entity @ent )
{
    team_CTF_teamflag( ent, TEAM_BETA );
}

void team_CTF_alphaflag( Entity @ent )
{
    team_CTF_teamflag( ent, TEAM_ALPHA );
}

void team_CTF_genericSpawnpoint( Entity @ent, int team )
{
    ent.team = team;

    // drop to floor

    Trace tr;
    Vec3 start, end, mins( -16.0f, -16.0f, -24.0f ), maxs( 16.0f, 16.0f, 40.0f );

    end = start = ent.origin;
    end.z -= 1024;
    start.z += 16;

    // check for starting inside solid
    tr.doTrace( start, mins, maxs, start, ent.entNum, MASK_DEADSOLID );
    if ( tr.startSolid || tr.allSolid )
    {
        G_Print( ent.classname + " starts inside solid. Inhibited\n" );
        ent.freeEntity();
        return;
    }

    if ( ( ent.spawnFlags & 1 ) == 0 ) // do not drop if having the float flag
    {
        if ( tr.doTrace( start, mins, maxs, end, ent.entNum, MASK_DEADSOLID ) )
        {
            start = tr.endPos + tr.planeNormal;
            ent.origin = start;
            ent.origin2 = start;
        }
    }
}

void team_CTF_alphaspawn( Entity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_ALPHA );
}

void team_CTF_betaspawn( Entity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_BETA );
}

void team_CTF_alphaplayer( Entity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_ALPHA );
}

void team_CTF_betaplayer( Entity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_BETA );
}

Entity @FB_SelectBestRandomTeamSpawnPoint( Entity @self, int team )
{
    Entity @spawn;
    Entity @enemy;
    Client @client;
    int numSpawns;
    int dist;
    int closestRange;
    int numPickableSpawns;
    Team @enemyTeam;
    bool isDuel = ( gametype.maxPlayersPerTeam == 1 );

    String className;

    if ( team == TEAM_ALPHA )
        className = "team_CTF_alphaspawn";
    if ( team == TEAM_BETA )
        className = "team_CTF_betaspawn";

    array<Entity @> @spawnents = G_FindByClassname( className );
    numSpawns = spawnents.size();

    if ( numSpawns == 0 )
        return null;
    if ( numSpawns == 1 )
        return spawnents[0];

    cSpawnPoint[] spawns( numSpawns );
    
    // Get spawn points
    int pos = 0; // Current position
    for( uint i = 0; i < spawns.size(); i++ )
    {
        @spawn = spawnents[i];
        
        // only accept those of the same team
        /*if ( onlyTeam && ( self.team != TEAM_SPECTATOR ) )
        {
            if ( spawn.team != self.team )
            {
                continue;
            }
        }*/

        closestRange = 9999999;
    
        // find the distance to the closer enemy player from this spawn
        for ( int j = 0; j < maxClients; j++ )
        {
            @client = @G_GetClient( j );
            if ( @client == null )
                continue;

            @enemy = @client.getEnt();

            if ( enemy.isGhosting() || @enemy == @self )
                continue;

            // Get closer distance from the enemies
            dist = int( spawn.origin.distance( enemy.origin ) );
            if ( isDuel ) {
                if( !G_InPVS( enemy.origin, spawn.origin ) ) {
                    dist *= 2;
                }
            }

            if ( dist < closestRange ) {
               closestRange = dist;
            }
        }

        // Save current spawn point
        @spawns[pos].ent = @spawn;
        spawns[pos].range = closestRange;
        
        // Go forward reading next respawn point
        pos++;
    }
    
    // Get spawn points in descending order by range
    // Used algorithm: insertion sort
    // Dont use it over 30 respawn points
    for( int i = 0; i < numSpawns; i++ )
    {
        int j = i;
        cSpawnPoint save;
        @save.ent = @spawns[j].ent;
        save.range = spawns[j].range;
        while( ( j > 0 ) && ( spawns[ j-1 ].range < save.range ) )
        {   
            @spawns[j].ent = @spawns[j-1].ent;
            spawns[j].range = spawns[j-1].range;
            
            j--;
        }
        @spawns[j].ent = @save.ent;
        spawns[j].range = save.range;
    }

    if ( numSpawns < 5 ) // always choose the clearest one
        return spawns[0].ent;
    numSpawns -= 3; // ignore the closest 3 points
    
    if( !isDuel ) {
        return spawns[int( brandom( 0, numSpawns ) )].ent;
    }
    
    // calculate denormalized range sum
    int rangeSum = 0;
    for( int i = 0; i < numSpawns; i++ )
        rangeSum += spawns[i].range;

    // pick random denormalized range
    int testRange = 0;
    int weightedRange = int( brandom( 0.0, rangeSum ) );    
    
    // find spot for the weighted range. distant spawn points are more probable
    for( int i = numSpawns - 1; i >= 0; i-- ) {
        testRange += spawns[i].range;
        if( testRange >= weightedRange ) {
            return spawns[i].ent;
        }
    }

    return spawns[0].ent;
}