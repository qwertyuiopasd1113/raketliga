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
