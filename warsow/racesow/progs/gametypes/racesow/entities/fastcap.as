/*
 * Fastcap
 */
float CTF_UNLOCK_TIME = 2.0f;
float CTF_UNLOCK_RADIUS = 128.0f;
float CTF_CAPTURE_RADIUS = 40.0f;

float[] unlockTimes( maxClients );

cFlagBase @alphaFlagBase = null;
cFlagBase @betaFlagBase = null;

class cFlagBase
{
    cEntity @owner;
    cEntity @decal;

    void Initialize( cEntity @spawner )
    {
        @this.owner = @spawner;

        if ( @this.owner == null )
            return;

        if( this.owner.team == TEAM_ALPHA )
            @alphaFlagBase = @this;
        else if( this.owner.team == TEAM_BETA )
            @betaFlagBase = @this;
        
        cVec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );

        this.owner.type = ET_FLAG_BASE;
        this.owner.effects = EF_CARRIER|EF_FLAG_TRAIL;
        this.owner.setupModel( "models/objects/flag/flag_base.md3" );
        this.owner.setSize( mins, maxs );
        this.owner.solid = SOLID_TRIGGER;
        this.owner.svflags &= ~uint(SVF_NOCLIENT);
        this.owner.nextThink = levelTime + 1500;

        if ( ( this.owner.spawnFlags & 1 ) != 0 ) // float spawnFlag
            this.owner.moveType = MOVETYPE_NONE;
        else
            this.owner.moveType = MOVETYPE_TOSS;

        // drop to floor
        cTrace tr;
        tr.doTrace( spawner.getOrigin(), vec3Origin, vec3Origin, spawner.getOrigin() - cVec3( 0.0f, 0.0f, 128.0f ), 0, MASK_DEADSOLID );

        cEntity @decal = @G_SpawnEntity( "flag_indicator_decal" );
        @this.decal = @decal;
        decal.type = ET_DECAL;
        decal.solid = SOLID_NOT;
        decal.setOrigin( tr.getEndPos() + cVec3( 0.0f, 0.0f, 2.0f ) );
        decal.setOrigin2( cVec3( 0.0f, 0.0f, 1.0f ) );
        decal.modelindex = G_ImageIndex( "gfx/indicators/radar_decal" );
        decal.modelindex2 = 0; // rotation angle for ET_DECAL       
        decal.team = spawner.team;
        decal.frame = CTF_UNLOCK_RADIUS; // radius in case of ET_DECAL
        decal.svflags = spawner.svflags | (SVF_TRANSMITORIGIN2|SVF_NOCULLATORIGIN2);
        decal.linkEntity();
    }

    cFlagBase()
    {
        Initialize( null );
    }

    cFlagBase( cEntity @owner )
    {
        Initialize( owner );
    }

    ~cFlagBase()
    {
    }

    void setCarrier( cEntity @ent )
    {
        ent.effects &= ~uint( EF_CARRIER|EF_FLAG_TRAIL );
        ent.effects |= EF_CARRIER|EF_FLAG_TRAIL;
        unlockTimes[ent.client.playerNum()] = 0;
        ent.linkEntity();
    }

    void resetCarrier( cEntity @ent )
    {
        ent.effects &= ~uint( EF_CARRIER|EF_FLAG_TRAIL );
        unlockTimes[ent.client.playerNum()] = 0;
        ent.linkEntity();
    }
    
    void resetFlag()
    {
    }

    void touch( cEntity @activator )
    {
        if ( @this.owner == null )
            return;

        if ( match.getState() >= MATCH_STATE_POSTMATCH )
            return;

        if ( @activator == null || @activator.client == null )
            return;


        // activator is touching the flagbase bbox for picking up
        // unlocking is made at flag base thinking

        if ( !(( activator.effects & EF_CARRIER ) == 0) && this.owner.team == TEAM_BETA )
        {
            unlockTimes[activator.client.playerNum()] = 0;
            this.flagCaptured( activator );
            this.owner.linkEntity();

            return;
        }

        if ( (( activator.effects & EF_CARRIER ) == 0) && this.owner.team == TEAM_ALPHA )
        {
            if ( unlockTimes[activator.client.playerNum()] < int( CTF_UNLOCK_TIME * 1000 ) )
                return;
            this.flagStolen( activator );
            this.owner.linkEntity();

            return;
        }
    }

    void think()
    {
        this.owner.nextThink = levelTime + 1;

        if ( match.getState() >= MATCH_STATE_POSTMATCH )
            return;

        if( this.owner.team == TEAM_BETA )
            return;
        
        // find players around
        cTrace tr;
        cVec3 center, mins, maxs;
        cEntity @target = null;
        cEntity @stop = null;
        cVec3 origin = this.owner.getOrigin();

        bool[] unlockTimeUpdated( maxClients );
        @target = G_GetEntity( 0 );
        @stop = G_GetClient( maxClients - 1 ).getEnt(); // the last entity to be checked
        while ( true )
        {
            @target = @G_FindEntityInRadius( target, stop, origin, CTF_UNLOCK_RADIUS );
            if ( @target == null || @target.client == null )
                break;

            if ( target.client.state() < CS_SPAWNED )
                continue;

            if ( target.isGhosting() )
                continue;

            if ( target.team == this.owner.team )
                continue;

            if ( ( target.effects & EF_CARRIER ) != 0 )
                continue;
            
            // check if the player is visible from the base
            target.getSize( mins, maxs );
            center = target.getOrigin() + ( 0.5 * ( maxs + mins ) );
            mins = 0;
            maxs = 0;
            int clientNum = target.client.playerNum();
            if ( !tr.doTrace( origin, mins, maxs, center, target.entNum(), MASK_SOLID ) )
            {
                unlockTimes[clientNum] += frameTime;
                if ( unlockTimes[clientNum] > int( CTF_UNLOCK_TIME * 1000 ) )
                    unlockTimes[clientNum] = int( CTF_UNLOCK_TIME * 1000 );
                unlockTimeUpdated[clientNum] = true;
            }
        }
        for ( int i = 0; i < maxClients; i++ )
        {
            if( !unlockTimeUpdated[i] )
                unlockTimes[i] = 0;
        }

    
    }

    void flagCaptured( cEntity @player )
    {
        player.client.addAward( S_COLOR_GREEN + "Flag Capture!" );
        this.resetCarrier( player );
        Racesow_GetPlayerByClient( player.client ).touchStopTimer();
    }

    void flagStolen( cEntity @player )
    {    
        player.client.armor = 0;
        player.health = player.maxHealth;
        player.client.inventoryClear();
        player.client.inventorySetCount( WEAP_GUNBLADE, 1 );
        player.client.selectWeapon( WEAP_GUNBLADE );
        removeProjectiles( player );
        player.client.addAward( S_COLOR_GREEN + "Flag Steal!" );
        this.setCarrier( player );
        Racesow_GetPlayerByClient( player.client ).touchStartTimer();
    }
}

void ctf_flag_die( cEntity @ent, cEntity @inflicter, cEntity @attacker )
{
    ctf_flag_think( ent );
}

void ctf_flag_touch( cEntity @ent, cEntity @other, const cVec3 @planeNormal, int surfFlags )
{
    if ( @other.client == null )
        return;
    
    cFlagBase @flagBase;
    if( ent.team == TEAM_ALPHA )
        @flagBase = @alphaFlagBase;
    else if( ent.team == TEAM_BETA )
        @flagBase = @betaFlagBase;
    flagBase.flagStolen( other );
}


void ctf_flag_think( cEntity @ent )
{
}

void CTF_ResetFlags()
{
    alphaFlagBase.resetFlag();
    betaFlagBase.resetFlag();
}

void team_CTF_betaflag_touch( cEntity @ent, cEntity @other, const cVec3 @planeNormal, int surfFlags )
{
    cFlagBase @flagBase = @betaFlagBase;
    if ( @flagBase != null )
        flagBase.touch( other );
}

void team_CTF_alphaflag_touch( cEntity @ent, cEntity @other, const cVec3 @planeNormal, int surfFlags )
{
    cFlagBase @flagBase = @alphaFlagBase;
    if ( @flagBase != null )
        flagBase.touch( other );
}

void team_CTF_betaflag_think( cEntity @ent )
{
    cFlagBase @flagBase = @betaFlagBase;

    if ( @flagBase != null )
        flagBase.think();
}

void team_CTF_alphaflag_think( cEntity @ent )
{
    cFlagBase @flagBase = null;
    if( ent.team == TEAM_ALPHA )
        @flagBase = @alphaFlagBase;
    else if( ent.team == TEAM_BETA )
        @flagBase = @betaFlagBase;
    if ( @flagBase != null )
        flagBase.think();
}

void team_CTF_teamflag( cEntity @ent, int team )
{
    ent.team = team;

    cVec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );

    // check for spawning inside solid, and try to avoid at least the case of shared leaf
    cTrace trace;
    trace.doTrace( ent.getOrigin(), mins, maxs, ent.getOrigin(), 0, MASK_DEADSOLID );
    if ( trace.startSolid || trace.allSolid )
    {
        // try to resolve the shared leaf case by moving it up by a little
        cVec3 start = ent.getOrigin();
        start.z += 16;
        trace.doTrace( start, mins, maxs, start, 0, MASK_DEADSOLID );
        if ( trace.startSolid || trace.allSolid )
        {
            G_Print( ent.getClassname() + " starts inside solid. Inhibited\n" );
            ent.freeEntity();
            return;
        }
    }

    ent.setOrigin( trace.getEndPos() );
    ent.setOrigin2( trace.getEndPos() );

    cFlagBase thisFlagBase( ent ); // spawn a local holder
}

void team_CTF_betaflag( cEntity @ent )
{
    team_CTF_teamflag( ent, TEAM_BETA );
}

void team_CTF_alphaflag( cEntity @ent )
{
    team_CTF_teamflag( ent, TEAM_ALPHA );
}

void team_CTF_genericSpawnpoint( cEntity @ent, int team )
{
    ent.team = team;

    // drop to floor
    cTrace tr;
    cVec3 start, end, mins( -16.0f, -16.0f, -24.0f ), maxs( 16.0f, 16.0f, 40.0f );

    end = start = ent.getOrigin();
    end.z -= 1024;
    start.z += 16;

    // check for starting inside solid
    tr.doTrace( start, mins, maxs, start, ent.entNum(), MASK_DEADSOLID );
    if ( tr.startSolid || tr.allSolid )
    {
        G_Print( ent.getClassname() + " starts inside solid. Inhibited\n" );
        ent.freeEntity();
        return;
    }

    if ( ( ent.spawnFlags & 1 ) == 0 ) // do not drop if having the float flag
    {
        if ( tr.doTrace( start, mins, maxs, end, ent.entNum(), MASK_DEADSOLID ) )
        {
            start = tr.getEndPos() + tr.getPlaneNormal();
            ent.setOrigin( start );
            ent.setOrigin2( start );
        }
    }
}

void team_CTF_alphaspawn( cEntity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_ALPHA );
}

void team_CTF_betaspawn( cEntity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_BETA );
}

void team_CTF_alphaplayer( cEntity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_ALPHA );
}

void team_CTF_betaplayer( cEntity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_BETA );
}

cEntity @bestFastcapSpawnpoint()
{
    cEntity @closestSpawn = null;
    float closestDistance = 1024;
    
    cEntity @currentSpawnpoint = @G_FindEntityWithClassname( null, "team_CTF_alphaspawn" );
    if( @currentSpawnpoint == null )
        return closestSpawn;
    do
    {
        float currentDistance = currentSpawnpoint.getOrigin().distance( alphaFlagBase.owner.getOrigin() );
        if( currentDistance < closestDistance && currentDistance > ( CTF_UNLOCK_RADIUS + 1 ) )
        {
            @closestSpawn = @currentSpawnpoint;
            closestDistance = currentDistance;
        }
        @currentSpawnpoint = @G_FindEntityWithClassname( @currentSpawnpoint, "team_CTF_alphaspawn" );
    } while( @currentSpawnpoint != null );
    
    @currentSpawnpoint = @G_FindEntityWithClassname( null, "team_CTF_alphaplayer" );
    if( @currentSpawnpoint == null )
        return closestSpawn;
    do
    {
        float currentDistance = currentSpawnpoint.getOrigin().distance( alphaFlagBase.owner.getOrigin() );
        if( currentDistance < closestDistance && currentDistance > ( CTF_UNLOCK_RADIUS + 2 ) )
        {
            @closestSpawn = @currentSpawnpoint;
            closestDistance = currentDistance;
        }
        @currentSpawnpoint = @G_FindEntityWithClassname( @currentSpawnpoint, "team_CTF_alphaplayer" );
    } while( @currentSpawnpoint != null );
    
    @currentSpawnpoint = @G_FindEntityWithClassname( null, "info_player_start" );
    if( @currentSpawnpoint == null )
        return closestSpawn;
    do
    {
        float currentDistance = currentSpawnpoint.getOrigin().distance( alphaFlagBase.owner.getOrigin() );
        if( currentDistance < closestDistance && currentDistance > ( CTF_UNLOCK_RADIUS + 2 ) )
        {
            @closestSpawn = @currentSpawnpoint;
            closestDistance = currentDistance;
        }
        @currentSpawnpoint = @G_FindEntityWithClassname( @currentSpawnpoint, "info_player_start" );
    } while( @currentSpawnpoint != null );
    return closestSpawn;    
}

void addFastcapHUDStats( cClient @client )
{
    if( ( client.getEnt().effects & EF_FLAG_TRAIL ) != 0 )
        client.setHUDStat( STAT_IMAGE_SELF, prcFlagIconStolen );
    if( unlockTimes[client.playerNum()] > 0 )
        client.setHUDStat( STAT_PROGRESS_OTHER, ( unlockTimes[client.playerNum()]  / ( CTF_UNLOCK_TIME * 10 ) ) );//*10 because of 1000/100
}
