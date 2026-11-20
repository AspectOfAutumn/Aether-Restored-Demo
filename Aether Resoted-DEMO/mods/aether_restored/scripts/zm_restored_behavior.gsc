#using scripts\asm\asm;
#using scripts\asm\asm_bb;
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\zm\spawners\agent_spawner;
#using scripts\mp\zm\spawners\zone_spawner;
#using scripts\mp\zm\systems\zm_round_logic;
#using scripts\mp\zm\systems\zm_round_spawning;
#using scripts\mp\zm\systems\zmaispawnlists;

autoexec zm_zombie_speed_limit_init()
{
    level thread zm_zombie_speed_limit_start();
}

function private zm_zombie_speed_wait_for_gametype()
{
    level endon( #"game_ended" );

    mode = undefined;
    while ( !isdefined( mode ) )
    {
        mode = level.gametype;

        if ( !isdefined( mode ) && isdefined( level.var_a009ab14ee0d3223 ) )
        {
            mode = "zm_";
        }

        if ( !isdefined( mode ) )
        {
            waitframe();
        }
    }

    return mode;
}

function private zm_zombie_speed_limit_start()
{
    level endon( #"game_ended" );

    mode = zm_zombie_speed_wait_for_gametype();

    if ( isstring( mode ) && getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    if ( isdefined( level.zm_zombie_speed_limit_registered ) )
    {
        return;
    }
    level.zm_zombie_speed_limit_registered = 1;

    level callback::add( "on_move_speed_changed", &zm_zombie_speed_limit_apply );
    level thread zm_zombie_speed_rampage_monitor();
}

function private zm_zombie_speed_rampage_on()
{
    if ( isdefined( level.flag ) && istrue( level.flag[ "rampage_inducer_activated" ] ) )
    {
        return true;
    }

    return isdefined( level.s_rampage ) && istrue( level.s_rampage.var_e06b5c72f9591a0f );
}

function private zm_zombie_speed_rampage_monitor()
{
    level endon( #"game_ended" );

    was_on = false;

    while ( true )
    {
        wait 1;

        is_on = zm_zombie_speed_rampage_on();

        if ( !is_on && !was_on )
        {
            continue;
        }

        was_on = is_on;

        foreach ( zombie in getaiarray( "team_two_hundred" ) )
        {
            if ( !isalive( zombie ) || !isdefined( zombie._blackboard ) )
            {
                continue;
            }

            if ( is_on )
            {
                zombie setmovespeedscale( 1 );
                zombie.zm_zombie_speed_scaled = undefined;
                continue;
            }

            if ( zombie asm_bb::bb_movetyperequested( "super_sprint" ) )
            {
                zombie zm_zombie_speed_limit_apply( { #move_speed:"super_sprint" } );
            }
            else if ( zombie asm_bb::bb_movetyperequested( "sprint" ) )
            {
                zombie zm_zombie_speed_limit_apply( { #move_speed:"sprint" } );
            }
        }
    }
}

function private zm_zombie_speed_limit_apply( params )
{
    if ( !isdefined( self ) || !isdefined( params ) || !isdefined( params.move_speed ) )
    {
        return;
    }

    if ( zm_zombie_speed_rampage_on() )
    {
        if ( istrue( self.zm_zombie_speed_scaled ) )
        {
            self setmovespeedscale( 1 );
            self.zm_zombie_speed_scaled = undefined;
        }

        return;
    }

    wanted_speed = getanimspeedthreshold( self, params.move_speed );
    max_speed = zm_zombie_speed_limit_max();

    if ( !isdefined( wanted_speed ) || !isdefined( max_speed ) || wanted_speed <= 0 )
    {
        return;
    }

    if ( wanted_speed > max_speed )
    {
        self setmovespeedscale( max_speed / wanted_speed );
        self.zm_zombie_speed_scaled = 1;
    }
    else if ( istrue( self.zm_zombie_speed_scaled ) )
    {
        self setmovespeedscale( 1 );
        self.zm_zombie_speed_scaled = undefined;
    }
}

function private zm_zombie_speed_limit_max()
{
    top_speed_fraction = 0.925;

    top_speed = getanimspeedthreshold( self, "super_sprint" );

    if ( !isdefined( top_speed ) )
    {
        top_speed = getanimspeedthreshold( self, "sprint" );
    }

    if ( !isdefined( top_speed ) )
    {
        return undefined;
    }

    max_speed = top_speed * top_speed_fraction;

    return max_speed;
}

autoexec zm_melee_range_init()
{
    level thread zm_melee_range_start();
}

function private zm_melee_range_start()
{
    level endon( #"game_ended" );

    mode = zm_zombie_speed_wait_for_gametype();

    if ( isstring( mode ) && getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    level callback::add( "on_zombie_ai_spawned", &zm_melee_range_on_spawn );
}

function private zm_melee_range_on_spawn( params )
{
    if ( !isdefined( self ) || !isstring( self.subclass ) || getsubstr( self.subclass, 0, 11 ) != "zombie_base" )
    {
        return;
    }

    self.var_35bc94cfee6a37e6 = &zm_melee_range_allowed;
    self thread zm_melee_range_scale();
    self thread zm_melee_range_react();
}

function private zm_melee_range_factor()
{
    return 1.325;
}

function private zm_melee_range_lead()
{
    return 1.25;
}

function private zm_melee_range_height()
{
    return 64;
}

function private zm_melee_range_sync_blackboard()
{
    if ( isdefined( self._blackboard ) && isdefined( self.melee_range ) )
    {
        self._blackboard.var_5692974bb0dd3579 = self.melee_range;
    }
}

function private zm_melee_range_apply()
{
    if ( !isdefined( self.melee_range ) )
    {
        return;
    }

    if ( isdefined( self.zm_melee_range_value ) && self.melee_range == self.zm_melee_range_value )
    {
        self zm_melee_range_sync_blackboard();
        return;
    }

    self.melee_range = self.melee_range * zm_melee_range_factor();
    self.zm_melee_range_value = self.melee_range;
    self zm_melee_range_sync_blackboard();
}

function private zm_melee_range_scale()
{
    self endon( #"death" );

    for ( i = 0; i < 40 && !isdefined( self.melee_range ); i++ )
    {
        waitframe();
    }

    self zm_melee_range_apply();
}

function private zm_melee_range_allowed( target )
{
    if ( !isdefined( target ) || !isplayer( target ) )
    {
        return true;
    }

    self zm_melee_range_apply();

    if ( !isdefined( self.melee_range ) )
    {
        return true;
    }

    if ( abs( self.origin[ 2 ] - target.origin[ 2 ] ) > zm_melee_range_height() )
    {
        return false;
    }

    return distance2d( self.origin, target.origin ) <= self.melee_range * zm_melee_range_lead();
}

function private zm_melee_range_interval()
{
    return 0.235;
}

function private zm_melee_range_in_reach( player )
{
    if ( !isplayer( player ) || !isalive( player ) || istrue( player.inlaststand ) )
    {
        return false;
    }

    if ( abs( self.origin[ 2 ] - player.origin[ 2 ] ) > zm_melee_range_height() )
    {
        return false;
    }

    return distance2d( self.origin, player.origin ) <= self.melee_range * zm_melee_range_lead();
}

function private zm_melee_range_target()
{
    closest = undefined;
    closest_dist = undefined;

    foreach ( player in level.players )
    {
        if ( !self zm_melee_range_in_reach( player ) )
        {
            continue;
        }

        dist = distance2d( self.origin, player.origin );

        if ( !isdefined( closest ) || dist < closest_dist )
        {
            closest = player;
            closest_dist = dist;
        }
    }

    return closest;
}

function private zm_melee_range_busy()
{
    if ( !isdefined( self._blackboard ) )
    {
        return true;
    }

    if ( isdefined( self asm_bb::bb_getmeleetarget() ) )
    {
        return true;
    }

    return isdefined( self.asmname ) && asm::asm_getcurrentstatename( self.asmname ) == "melee";
}

function private zm_melee_range_react()
{
    self endon( #"death" );

    while ( !isdefined( self.melee_range ) || !isdefined( self.zm_melee_range_value ) )
    {
        wait zm_melee_range_interval();
    }

    while ( true )
    {
        wait zm_melee_range_interval();

        if ( self zm_melee_range_busy() )
        {
            continue;
        }

        target = self zm_melee_range_target();

        if ( isdefined( target ) )
        {
            self asm_bb::bb_requestmelee( target );
        }
    }
}

autoexec zm_los_spawn_init()
{
    level thread zm_los_spawn_start();
}

function private zm_los_spawn_start()
{
    level endon( #"game_ended" );

    mode = zm_zombie_speed_wait_for_gametype();

    if ( isstring( mode ) && getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    level.var_4e7a53b0367f50de = &zm_los_spawn_select;
    level callback::add( "on_round_start", &zm_los_spawn_round_started );
    level callback::add( "on_round_ai_spawn_started", &zm_los_spawn_round_started );
    level callback::add( "on_round_end", &zm_los_spawn_round_ended );
    level thread zm_los_spawn_track_views();

    while ( true )
    {
        if ( !isdefined( level.override_zombie_spawn_delay ) )
        {
            level.override_zombie_spawn_delay = &zm_los_spawn_delay;
        }

        wait 1;
    }
}

function private zm_los_spawn_round_started( params )
{
    level.zm_los_spawn_round_active = 1;
}

function private zm_los_spawn_round_ended( params )
{
    level.zm_los_spawn_round_active = undefined;
    level.zm_los_spawn_fail_since = undefined;
}

function private zm_los_spawn_delay( roundnumber, specialroundstruct )
{
    return zm_round_spawning::function_5f35aa2e209190da( roundnumber, specialroundstruct ) / 1.65;
}

function private zm_los_spawn_fail_ms()
{
    return 3000;
}


function private zm_los_spawn_behind_dot()
{
    return -0.25;
}

function private zm_los_spawn_view_window_ms()
{
    return 2000;
}

function private zm_los_spawn_track_views()
{
    level endon( #"game_ended" );

    while ( true )
    {
        now = gettime();
        window = zm_los_spawn_view_window_ms();

        foreach ( player in level.players )
        {
            if ( !isalive( player ) )
            {
                player.zm_los_view_times = undefined;
                player.zm_los_view_dirs = undefined;
                continue;
            }

            facing = anglestoforward( player getplayerangles() );
            facing = ( facing[ 0 ], facing[ 1 ], 0 );

            if ( lengthsquared( facing ) < 0.0001 )
            {
                continue;
            }

            times = [];
            dirs = [];

            if ( isarray( player.zm_los_view_times ) )
            {
                for ( i = 0; i < player.zm_los_view_times.size; i++ )
                {
                    if ( now - player.zm_los_view_times[ i ] <= window )
                    {
                        times[ times.size ] = player.zm_los_view_times[ i ];
                        dirs[ dirs.size ] = player.zm_los_view_dirs[ i ];
                    }
                }
            }

            times[ times.size ] = now;
            dirs[ dirs.size ] = vectornormalize( facing );
            player.zm_los_view_times = times;
            player.zm_los_view_dirs = dirs;
        }

        wait 0.1;
    }
}

function private zm_los_spawn_looked_recently( player, spawn_dir, max_dot )
{
    if ( !isarray( player.zm_los_view_times ) || !isarray( player.zm_los_view_dirs ) )
    {
        return false;
    }

    now = gettime();
    window = zm_los_spawn_view_window_ms();

    for ( i = 0; i < player.zm_los_view_times.size; i++ )
    {
        if ( now - player.zm_los_view_times[ i ] <= window && vectordot( player.zm_los_view_dirs[ i ], spawn_dir ) > max_dot )
        {
            return true;
        }
    }

    return false;
}

function private zm_los_spawn_behind_player( spawn_loc )
{
    max_dot = zm_los_spawn_behind_dot();

    foreach ( player in level.players )
    {
        if ( !isalive( player ) )
        {
            continue;
        }

        to_spawn = spawn_loc.origin - player.origin;
        to_spawn = ( to_spawn[ 0 ], to_spawn[ 1 ], 0 );

        if ( lengthsquared( to_spawn ) < 1 )
        {
            continue;
        }

        facing = anglestoforward( player getplayerangles() );
        facing = ( facing[ 0 ], facing[ 1 ], 0 );

        if ( lengthsquared( facing ) < 0.0001 )
        {
            continue;
        }

        spawn_dir = vectornormalize( to_spawn );

        if ( vectordot( vectornormalize( facing ), spawn_dir ) <= max_dot && !zm_los_spawn_looked_recently( player, spawn_dir, max_dot ) )
        {
            return true;
        }
    }

    return false;
}

function private zm_los_spawn_select( subclass )
{
    first_pick = undefined;
    behind_pick = undefined;

    for ( i = 0; i < 12; i++ )
    {
        spawn_loc = zone_spawner::select_spawn_loc( subclass, [] );

        if ( !isdefined( spawn_loc ) )
        {
            continue;
        }

        first_pick = first_pick ?? spawn_loc;

        if ( !zm_los_spawn_behind_player( spawn_loc ) )
        {
            level.zm_los_spawn_fail_since = undefined;
            return spawn_loc;
        }

        behind_pick = behind_pick ?? spawn_loc;
    }

    if ( !isdefined( first_pick ) )
    {
        return undefined;
    }

    if ( !istrue( level.zm_los_spawn_round_active ) )
    {
        return undefined;
    }

    level.zm_los_spawn_fail_since = level.zm_los_spawn_fail_since ?? gettime();

    if ( gettime() - level.zm_los_spawn_fail_since > zm_los_spawn_fail_ms() )
    {
        level.zm_los_spawn_fail_since = undefined;

        return behind_pick ?? first_pick;
    }

    return undefined;
}

function private zm_no_armored_armor_allowed()
{
    if ( issubstr( tolower( getdvar( @"g_mapname" ) ), "zm_sat_hornet" ) )
    {
        return true;
    }

    if ( issubstr( tolower( level.script ?? "" ), "zm_sat_hornet" ) )
    {
        return true;
    }

    if ( issubstr( tolower( getdvar( @"g_gametype" ) ), "hornet" ) )
    {
        return true;
    }

    return issubstr( tolower( level.gametype ?? "" ), "hornet" );
}

autoexec zm_no_armored_zombies_init()
{
    if ( zm_no_armored_armor_allowed() )
    {
        return;
    }

    zm_no_armored_set_replacements();
    zm_no_armored_hook_round_spawning();
    zm_no_armored_hook_agent();

    if ( isdefined( level.callbacks ) && isdefined( level.callbacks.on_zombie_ai_spawned ) )
    {
        level.callbacks.on_zombie_ai_spawned = undefined;
    }

    level thread zm_no_armored_zombies_run();
}

function zm_no_armored_is_base_subclass( name )
{
    if ( !isdefined( name ) )
    {
        return false;
    }

    return name == "zombie_base" || name == #"zombie_base";
}

function zm_no_armored_get_base_aitype()
{
    if ( isdefined( level.var_a009ab14ee0d3223 ) && isdefined( level.var_a009ab14ee0d3223.normalroundspawns ) && isdefined( level.var_a009ab14ee0d3223.normalroundspawns[ 1 ] ) && isdefined( level.var_a009ab14ee0d3223.normalroundspawns[ 1 ].ailist ) )
    {
        base_aitype = zmaispawnlists::function_d34f63bc9c24e432( level.var_a009ab14ee0d3223.normalroundspawns[ 1 ].ailist );

        if ( isdefined( base_aitype ) && !zm_no_armored_is_armored_name( base_aitype ) )
        {
            return base_aitype;
        }
    }

    if ( isdefined( level.aitype_to_subclass ) )
    {
        foreach ( k, v in level.aitype_to_subclass )
        {
            if ( zm_no_armored_is_base_subclass( v ) )
            {
                return k;
            }
        }
    }

    if ( isdefined( level.var_a706785ff83cb223 ) )
    {
        foreach ( k, v in level.var_a706785ff83cb223 )
        {
            if ( zm_no_armored_is_base_subclass( v ) )
            {
                return k;
            }
        }
    }

    return "zombie_base";
}

function zm_no_armored_add_override( fromtype, totype )
{
    if ( !isdefined( fromtype ) || !isdefined( totype ) || fromtype == totype )
    {
        return;
    }

    if ( !isdefined( level.var_a009ab14ee0d3223 ) )
    {
        return;
    }

    if ( !isdefined( level.var_a009ab14ee0d3223.aitypeoverridemap ) )
    {
        level.var_a009ab14ee0d3223.aitypeoverridemap = [];
    }

    current = level.var_a009ab14ee0d3223.aitypeoverridemap[ fromtype ];

    if ( !isdefined( current ) || current.size != 1 || current[ 0 ] != totype )
    {
        level.var_a009ab14ee0d3223.aitypeoverridemap[ fromtype ] = [ totype ];
    }
}

function zm_no_armored_sanitize_spawnlist( spawnlist, base_aitype, base_spawnlist )
{
    if ( !isdefined( spawnlist ) )
    {
        return false;
    }

    subclasses = zmaispawnlists::function_e0abfec4a095a04b( spawnlist );
    has_armored = 0;
    has_base = 0;
    only_base_or_armored = 1;

    if ( isdefined( subclasses ) && subclasses.size > 0 )
    {
        foreach ( sub in subclasses )
        {
            if ( zm_no_armored_is_armored_name( sub ) )
            {
                has_armored = 1;
                zm_no_armored_add_override( sub, base_aitype );
            }
            else if ( zm_no_armored_is_base_subclass( sub ) )
            {
                has_base = 1;
            }
            else
            {
                only_base_or_armored = 0;
            }
        }
    }
    else
    {
        only_base_or_armored = 0;
    }

    if ( has_armored )
    {
        for ( i = 0; i < 16; i++ )
        {
            sample = zmaispawnlists::function_d34f63bc9c24e432( spawnlist );

            if ( isdefined( sample ) && ( !has_base || zm_no_armored_is_armored( sample ) ) )
            {
                zm_no_armored_add_override( sample, base_aitype );
            }
        }
    }

    return has_armored && only_base_or_armored && isdefined( base_spawnlist );
}

function zm_no_armored_set_replacements()
{
    setdvar( "hash_5b9f8512308d472a", "zombie_base_armored_light->zombie_base|zombie_base_armored_heavy->zombie_base" );

    if ( !isdefined( level.var_a009ab14ee0d3223 ) )
    {
        return;
    }

    level.var_a009ab14ee0d3223.aitypeoverridemap = level.var_a009ab14ee0d3223.aitypeoverridemap ?? [];

    base_aitype = zm_no_armored_get_base_aitype();
    base_spawnlist = undefined;

    if ( isdefined( level.var_a009ab14ee0d3223.normalroundspawns ) && isdefined( level.var_a009ab14ee0d3223.normalroundspawns[ 1 ] ) )
    {
        base_spawnlist = level.var_a009ab14ee0d3223.normalroundspawns[ 1 ].ailist;
    }

    overrides = [
        "zombie_base_armored_light",
        "zombie_base_armored_heavy",
        "light_armored_zombie",
        "heavy_armored_zombie",
        #"zombie_base_armored_light",
        #"zombie_base_armored_heavy",
        #"light_armored_zombie",
        #"heavy_armored_zombie"
    ];

    foreach ( override in overrides )
    {
        zm_no_armored_add_override( override, base_aitype );
    }

    if ( isdefined( level.aitype_to_subclass ) )
    {
        foreach ( k, v in level.aitype_to_subclass )
        {
            if ( zm_no_armored_is_armored_name( k ) || zm_no_armored_is_armored_name( v ) )
            {
                zm_no_armored_add_override( k, base_aitype );
                zm_no_armored_add_override( v, base_aitype );
            }
        }
    }

    if ( isdefined( level.var_a706785ff83cb223 ) )
    {
        foreach ( k, v in level.var_a706785ff83cb223 )
        {
            if ( zm_no_armored_is_armored_name( k ) || zm_no_armored_is_armored_name( v ) )
            {
                zm_no_armored_add_override( k, base_aitype );
                zm_no_armored_add_override( v, base_aitype );
            }
        }
    }

    if ( isdefined( level.ai_subclass_to_category ) )
    {
        foreach ( sub, _ in level.ai_subclass_to_category )
        {
            if ( zm_no_armored_is_armored_name( sub ) )
            {
                zm_no_armored_add_override( sub, base_aitype );
            }
        }
    }

    if ( isdefined( level.var_a009ab14ee0d3223.aisubclassintroround ) )
    {
        foreach ( sub, _ in level.var_a009ab14ee0d3223.aisubclassintroround )
        {
            if ( zm_no_armored_is_armored_name( sub ) )
            {
                zm_no_armored_add_override( sub, base_aitype );
            }
        }
    }

    if ( isdefined( level.var_a009ab14ee0d3223.normalroundspawns ) )
    {
        foreach ( roundindex, roundinfo in level.var_a009ab14ee0d3223.normalroundspawns )
        {
            if ( roundindex != 1 && isdefined( roundinfo ) && isdefined( roundinfo.ailist ) )
            {
                if ( zm_no_armored_sanitize_spawnlist( roundinfo.ailist, base_aitype, base_spawnlist ) )
                {
                    roundinfo.ailist = base_spawnlist;
                }
            }
        }
    }

    if ( isdefined( level.var_a009ab14ee0d3223.var_48700cdf9eaa7f9 ) )
    {
        foreach ( entry in level.var_a009ab14ee0d3223.var_48700cdf9eaa7f9 )
        {
            if ( isdefined( entry ) && isdefined( entry.mixedaispawntype ) )
            {
                if ( zm_no_armored_sanitize_spawnlist( entry.mixedaispawntype, base_aitype, base_spawnlist ) )
                {
                    entry.mixedaispawntype = base_spawnlist;
                }
            }
        }
    }

    if ( isdefined( level.var_a009ab14ee0d3223.var_8eb34c1c71c1333f ) )
    {
        foreach ( entry in level.var_a009ab14ee0d3223.var_8eb34c1c71c1333f )
        {
            if ( isdefined( entry ) && isdefined( entry.mixedaispawntype ) )
            {
                if ( zm_no_armored_sanitize_spawnlist( entry.mixedaispawntype, base_aitype, base_spawnlist ) )
                {
                    entry.mixedaispawntype = base_spawnlist;
                }
            }
        }
    }

    if ( isdefined( level.var_a009ab14ee0d3223.var_9ae086885e903c0c ) )
    {
        foreach ( entry in level.var_a009ab14ee0d3223.var_9ae086885e903c0c )
        {
            if ( isdefined( entry ) && isdefined( entry.mixedaispawntype ) )
            {
                if ( zm_no_armored_sanitize_spawnlist( entry.mixedaispawntype, base_aitype, base_spawnlist ) )
                {
                    entry.mixedaispawntype = base_spawnlist;
                }
            }
        }
    }

    if ( isdefined( level.var_a009ab14ee0d3223.var_4fcb67d418d85735 ) )
    {
        foreach ( entry in level.var_a009ab14ee0d3223.var_4fcb67d418d85735 )
        {
            if ( isdefined( entry ) && isdefined( entry.mixedaispawntype ) )
            {
                if ( zm_no_armored_sanitize_spawnlist( entry.mixedaispawntype, base_aitype, base_spawnlist ) )
                {
                    entry.mixedaispawntype = base_spawnlist;
                }
            }
        }
    }

    if ( isdefined( level._szombiecleanupinfo ) && isdefined( level._szombiecleanupinfo.zombiependingrespawn ) )
    {
        foreach ( respawn_info in level._szombiecleanupinfo.zombiependingrespawn )
        {
            if ( isdefined( respawn_info ) && isdefined( respawn_info.aitype ) && zm_no_armored_is_armored( respawn_info.aitype ) )
            {
                respawn_info.aitype = base_aitype;
            }
        }
    }
}

function zm_no_armored_zombies_run()
{
    level endon( #"game_ended" );
    waitframe();

    while ( true )
    {
        zm_no_armored_set_replacements();
        zm_no_armored_hook_round_spawning();
        zm_no_armored_hook_agent();
        wait 0.05;
    }
}

function zm_no_armored_is_armored_name( name )
{
    if ( !isdefined( name ) )
    {
        return false;
    }

    if ( name == "zombie_base_armored_light" || name == "zombie_base_armored_heavy" || name == "light_armored_zombie" || name == "heavy_armored_zombie" )
    {
        return true;
    }

    if ( name == #"zombie_base_armored_light" || name == #"zombie_base_armored_heavy" || name == #"light_armored_zombie" || name == #"heavy_armored_zombie" )
    {
        return true;
    }

    if ( isstring( name ) )
    {
        return issubstr( name, "armored" ) && !issubstr( name, "agni" );
    }

    return false;
}

function zm_no_armored_resolve_aitype( aitype )
{
    if ( !isdefined( aitype ) )
    {
        return aitype;
    }

    if ( isdefined( level.var_a009ab14ee0d3223 ) && isdefined( level.var_a009ab14ee0d3223.aitypeoverridemap ) && isdefined( level.var_a009ab14ee0d3223.aitypeoverridemap[ aitype ] ) && level.var_a009ab14ee0d3223.aitypeoverridemap[ aitype ].size > 0 )
    {
        count = level.var_a009ab14ee0d3223.aitypeoverridemap[ aitype ].size;
        return level.var_a009ab14ee0d3223.aitypeoverridemap[ aitype ][ randomint( count ) ];
    }

    if ( zm_no_armored_is_armored( aitype ) )
    {
        return zm_no_armored_get_base_aitype();
    }

    return aitype;
}

function zm_no_armored_hook_round_spawning()
{
    current = level.zmmaproundspawningoverride;

    if ( isfunction( current ) && current == &zm_no_armored_round_spawning_override )
    {
        return;
    }

    level.zm_no_armored_original_round_spawning_override = undefined;

    if ( isfunction( current ) )
    {
        level.zm_no_armored_original_round_spawning_override = current;
    }

    level.zmmaproundspawningoverride = &zm_no_armored_round_spawning_override;
}

function zm_no_armored_round_spawning_override( aitype )
{
    aitype = zm_no_armored_resolve_aitype( aitype );

    if ( isfunction( level.zm_no_armored_original_round_spawning_override ) )
    {
        return [[ level.zm_no_armored_original_round_spawning_override ]]( aitype );
    }

    if ( isdefined( level.mapinfobundle ) && istrue( level.mapinfobundle.var_b7bdaf6a2a733aaa ) && isdefined( level.var_d24e66b3dd54be4a ) && arraycontains( level.var_d24e66b3dd54be4a, aitype ) )
    {
        return zone_spawner::spawn_single_dog( aitype );
    }

    return agent_spawner::spawn_agent( aitype, 1 );
}

function zm_no_armored_hook_agent()
{
    current = level.var_1e2c07e345d293d1;

    if ( isfunction( current ) && current == &zm_no_armored_agent_aitype )
    {
        return;
    }

    level.zm_no_armored_original_agent_hook = undefined;

    if ( isfunction( current ) )
    {
        level.zm_no_armored_original_agent_hook = current;
    }

    level.var_1e2c07e345d293d1 = &zm_no_armored_agent_aitype;
}

function zm_no_armored_agent_aitype( aitype )
{
    if ( isfunction( level.zm_no_armored_original_agent_hook ) )
    {
        aitype = [[ level.zm_no_armored_original_agent_hook ]]( aitype );
    }

    if ( !isdefined( aitype ) )
    {
        return aitype;
    }

    bare = aitype;
    has_actor_prefix = 0;

    if ( isstring( aitype ) && isstartstr( aitype, "actor_" ) )
    {
        bare = getsubstr( aitype, 6 );
        has_actor_prefix = 1;
    }

    if ( !zm_no_armored_is_armored_name( bare ) && !zm_no_armored_is_armored_name( aitype ) && !zm_no_armored_is_armored( bare ) && !zm_no_armored_is_armored( aitype ) )
    {
        return aitype;
    }

    replacement = zm_no_armored_get_base_aitype();

    if ( has_actor_prefix && isstring( replacement ) && !isstartstr( replacement, "actor_" ) )
    {
        replacement = "actor_" + replacement;
    }

    return replacement;
}

function zm_no_armored_is_armored( aitype )
{
    if ( !isdefined( aitype ) )
    {
        return false;
    }

    if ( zm_no_armored_is_armored_name( aitype ) )
    {
        return true;
    }

    if ( isdefined( level.var_a009ab14ee0d3223 ) && isdefined( level.var_a009ab14ee0d3223.aitypeoverridemap ) && isdefined( level.var_a009ab14ee0d3223.aitypeoverridemap[ aitype ] ) )
    {
        return true;
    }

    subclass = undefined;

    if ( isdefined( level.aitype_to_subclass ) )
    {
        subclass = level.aitype_to_subclass[ aitype ];
    }

    if ( !isdefined( subclass ) && isdefined( level.var_a706785ff83cb223 ) )
    {
        subclass = level.var_a706785ff83cb223[ aitype ];
    }

    return zm_no_armored_is_armored_name( subclass );
}

autoexec zm_spawn_caps_init()
{
    level thread zm_spawn_caps_start();
}

function private zm_spawn_caps_start()
{
    level endon( #"game_ended" );

    mode = zm_zombie_speed_wait_for_gametype();

    if ( isstring( mode ) && getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( !isdefined( level.var_a009ab14ee0d3223 ) )
    {
        waitframe();
    }

    while ( true )
    {
        zm_spawn_caps_apply();
        wait 1;
    }
}

function private zm_spawn_caps_players()
{
    count = level.players.size;

    if ( count < 1 )
    {
        count = 1;
    }

    return count;
}

function private zm_spawn_caps_elite_max( players )
{
    if ( players >= 3 )
    {
        return 2;
    }

    return 1;
}

function private zm_spawn_caps_special_max( players )
{
    if ( players >= 3 )
    {
        return 4;
    }

    if ( players == 2 )
    {
        return 3;
    }

    return 2;
}

function private zm_spawn_caps_elites_alive()
{
    alive = 0;
    list = level.var_a009ab14ee0d3223.activespecialzombies;

    if ( !isarray( list ) )
    {
        return 0;
    }

    foreach ( zombie in list )
    {
        if ( isalive( zombie ) && zombie.aicategory == "elite" )
        {
            alive++;
        }
    }

    return alive;
}

function private zm_spawn_caps_elite_alive_ok()
{
    if ( zm_spawn_caps_elites_alive() >= zm_spawn_caps_elite_max( zm_spawn_caps_players() ) )
    {
        return false;
    }

    if ( isfunction( level.zm_spawn_caps_elite_prev ) )
    {
        return [[ level.zm_spawn_caps_elite_prev ]]();
    }

    return true;
}

function private zm_spawn_caps_hook_elites()
{
    current = level.var_609a4c84665ec35;

    if ( isfunction( current ) && current == &zm_spawn_caps_elite_alive_ok )
    {
        return;
    }

    level.zm_spawn_caps_elite_prev = undefined;

    if ( isfunction( current ) )
    {
        level.zm_spawn_caps_elite_prev = current;
    }

    level.var_609a4c84665ec35 = &zm_spawn_caps_elite_alive_ok;
}

function private zm_spawn_caps_clamp_percent( base, count, total )
{
    if ( !isdefined( base ) || !isdefined( count ) || count <= 0 )
    {
        return base;
    }

    if ( int( count * base ) <= total )
    {
        return base;
    }

    return ( total + 0.5 ) / count;
}

function private zm_spawn_caps_special_totals( spawning, players )
{
    if ( !isdefined( spawning.zm_caps_pct_low ) )
    {
        spawning.zm_caps_pct_low = spawning.var_6b273737afad7ed8;
        spawning.zm_caps_pct_mid = spawning.var_6b2bbd37afb29b61;
        spawning.zm_caps_pct_high = spawning.var_ce0744f85c599e51;
    }

    count = zm_round_spawning::get_zombie_count_for_round( zm_round_logic::get_rb_round_number() );
    total = zm_spawn_caps_special_max( players ) + 1;

    spawning.var_6b273737afad7ed8 = zm_spawn_caps_clamp_percent( spawning.zm_caps_pct_low, count, total );
    spawning.var_6b2bbd37afb29b61 = zm_spawn_caps_clamp_percent( spawning.zm_caps_pct_mid, count, total );
    spawning.var_ce0744f85c599e51 = zm_spawn_caps_clamp_percent( spawning.zm_caps_pct_high, count, total );
}

function private zm_spawn_caps_max_active()
{
    if ( istrue( level.b_task_running ) || istrue( level.b_task_starting ) )
    {
        return 40;
    }

    return 32;
}

function private zm_spawn_caps_apply()
{
    spawning = level.var_a009ab14ee0d3223;
    players = zm_spawn_caps_players();
    elite_round_total = zm_spawn_caps_elite_max( players ) + 1;

    max_active = zm_spawn_caps_max_active();
    spawning.zombiemaxactive = max_active;
    spawning.var_63a0ca44b877a390 = max_active;

    spawning.var_f0837b0d2f437d8c = elite_round_total;
    spawning.var_8037eb378dce03e4 = elite_round_total;
    spawning.var_8a52ae780775b8b6 = elite_round_total;
    spawning.var_5b675df965b7d73c = elite_round_total;
    spawning.var_c68b71210be2bac1 = elite_round_total;

    zm_spawn_caps_hook_elites();
    zm_spawn_caps_special_totals( spawning, players );

    setdvar( @"hash_3c05d1d16d772c9e", zm_spawn_caps_special_max( players ) );
}
