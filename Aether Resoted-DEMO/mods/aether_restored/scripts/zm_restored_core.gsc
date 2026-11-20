#using script_aa3bac81ad4fc8e;
#using scripts\common\ai\aitypes\shared\zombie\zombie_utils;
#using scripts\common\callbacks;
#using scripts\mp\augments\z_mod_augments;
#using scripts\common\status_effects\status_effects;
#using scripts\common\utility;
#using scripts\common\values;
#using scripts\mp\armor;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\common\utility\game_utility;
#using scripts\mp\common\utility\lower_message;
#using scripts\mp\common\utility\player;
#using scripts\mp\damage;
#using scripts\mp\loot\common_cache;
#using scripts\mp\loot\common_item;
#using scripts\mp\playerhealth;
#using scripts\mp\playerlogic;
#using scripts\mp\scripted_weapons;
#using scripts\mp\weapons;
#using scripts\mp\zm\zm_utility;
#using scripts\common\killstreaks\killstreak_shared;
#using scripts\common\powerups;
#using scripts\common\weapon;
#using scripts\mp\common\killstreaks\killstreaks;
#using scripts\mp\common\utility\outline;
#using scripts\mp\common\utility\weapon_utility;
#using scripts\mp\crafting_table;
#using scripts\mp\destructibles\destructibles;
#using scripts\mp\destructibles\destructibles_actions;
#using scripts\mp\currency;
#using scripts\mp\equipment;
#using scripts\mp\interaction;
#using scripts\mp\laststand;
#using scripts\mp\loot\common_item_killstreak;
#using scripts\mp\loot\common_item_weapon;
#using scripts\mp\magicbox;
#using scripts\mp\ammomods\ammo_mod;
#using scripts\mp\purchasemenu;
#using scripts\mp\wallbuy;
#using scripts\mp\arsenal;
#using scripts\mp\zm\points;
#using scripts\mp\zm\systems\zm_milestones;
#using scripts\mp\zm\systems\zm_quest;
#using scripts\mp\zm\systems\zm_interaction;
#using script_4c770a9a4ad7659c;
#using script_692b19b8e5f8f9e8;
#using script_3b64eb40368c1450;
#using script_25a8fa2ac8997425;
#using script_3a9d7a7cfee99885;

autoexec zm_armor_health_rework_init()
{
    level thread zm_armor_health_rework_start();
    level thread zm_turtle_shell_armor_start();
    level thread zm_armormatic_always_on_start();
    level thread zm_plate_heal_start();
    level thread zm_armor_wallbuy_start();
    level thread zm_armor_wallbuys_disable_start();
    level thread zm_armor_t3_block_start();
    level thread zm_golden_armor_block_start();
    level thread zm_armor_cap_start();
    level thread zm_special_damage_start();
    level thread zm_augment_heal_start();
    level thread zm_juggernog_augments_start();
    level thread zm_multipack_odds_start();
    level thread zm_perk_limit_start();
    level thread zm_dying_wish_start();
    level thread zm_plate_drop_start();
    level thread zm_durable_plates_start();
    level thread zm_last_chance_start();
}

autoexec bo3_health_init()
{
    setdvar( "zombie_melee_damage_override", "50" );
    setdvar( "zombie_melee_damage_multiplier", "1.0" );
}

function private wait_for_gametype()
{
    level endon( #"game_ended" );

    mode = undefined;
    while ( !isdefined( mode ) )
    {
        mode = level.gametype;

        if ( !isdefined( mode ) && isdefined( level.gametypebundle ) )
        {
            mode = game_utility::getgametype();
        }

        if ( !isdefined( mode ) )
        {
            waitframe();
        }
    }

    return mode;
}

function private zm_armor_health_rework_start()
{
    level endon( #"game_ended" );

    wait_for_gametype();

    if ( !supported_mode() )
    {
        return;
    }

    level callback::add( #"player_spawned", &on_player_spawned );
    level callback::add( "wallbuy_armor_purchased", &on_armor_purchased );
    level callback::add( #"player_damaged", &zm_armor_regen_on_damaged );
    level thread maintain_no_starting_armor();

    foreach ( player in level.players )
    {
        if ( isplayer( player ) && isalive( player ) )
        {
            player on_player_spawned( undefined );
        }
    }
}

function private supported_mode()
{
    mode = game_utility::getgametype();

    return mode == "zm_rb_r_mod" || mode == "zm_rb_r_mod_survival" || mode == "zm_rb_rh_mod" || mode == "zm_rb" || mode == "zm_rb_survival";
}

function private empty_starting_armor( player )
{
    return [ 0, 0 ];
}

function private maintain_no_starting_armor()
{
    level endon( #"game_ended" );
    while ( supported_mode() )
    {
        level.var_89173a04bb110bf3 = &empty_starting_armor;

        if ( isdefined( level.zm_mode_modifiers ) )
        {
            level.zm_mode_modifiers.var_2dc492758425fa76 = 0;
        }
        wait 0.10;
    }
}

function private on_player_spawned( params )
{
    if ( !supported_mode() || !isplayer( self ) )
    {
        return;
    }
    self.fresh_armor_bought_this_life = 0;

    if ( istrue( self.zm_adrenaline_had ) && isdefined( self.zm_adrenaline_saved ) )
    {
        self.zm_adrenaline_had = undefined;
        self.zm_adrenaline_pending = 1;
    }

    self thread clear_spawn_armor();
    self thread zm_armor_regen_loop();
    self thread zm_probiotic_delay_loop();
    self thread zm_adrenaline_save_loop();
    self thread zm_adrenaline_perk_loop();
    self thread zm_adrenaline_revive_watch();
    self thread zm_adrenaline_restore();
    self thread zm_recovery_loop();
    self thread zm_arsenal_slot_grey_loop();
}

function private zm_is_game_start()
{
    return ( level.round_number ?? 1 ) <= 1;
}

function private clear_spawn_armor()
{
    self endon( #"disconnect" );
    wait 0.20;

    if ( !zm_is_game_start() )
    {
        if ( ( self.platecarrierlevel ?? 1 ) >= 2 )
        {
            self.fresh_armor_bought_this_life = 1;
            return;
        }

        if ( !self.fresh_armor_bought_this_life )
        {
            self force_armor_zero();
        }
        wait 0.50;

        if ( ( self.platecarrierlevel ?? 1 ) >= 2 )
        {
            self.fresh_armor_bought_this_life = 1;
            return;
        }

        if ( !self.fresh_armor_bought_this_life )
        {
            self force_armor_zero();
        }
        return;
    }

    if ( !self.fresh_armor_bought_this_life )
    {
        self force_armor_zero();
    }
    wait 0.50;

    if ( !zm_is_game_start() )
    {
        if ( ( self.platecarrierlevel ?? 1 ) >= 2 )
        {
            self.fresh_armor_bought_this_life = 1;
            return;
        }

        if ( !self.fresh_armor_bought_this_life )
        {
            self force_armor_zero();
        }
        return;
    }

    if ( !self.fresh_armor_bought_this_life )
    {
        self force_armor_zero();
    }
}

function private force_armor_zero()
{
    self.platecarrierlevel = 1;
    self.maxarmorhealth = 0;
    self.var_a1faa64d8c07872e = 0;
    self setclientomnvar( "ui_armor_current_level", 0 );
    self armor::setarmorhealth( 0, 1, 1 );
    self armor::function_b359444c252374fc( 0 );
}

function private on_armor_purchased( params )
{
    if ( !isplayer( self ) )
    {
        return;
    }
    self.fresh_armor_bought_this_life = 1;

    if ( zm_juggernog_augment_active( #"juggernog_retaliation" ) )
    {
        self zm_armor_grant_t3();
        return;
    }

    if ( isdefined( params ) && isdefined( params.armor_level ) && params.armor_level >= 3 )
    {
        self zm_armor_keep_at_t2();
    }
}

function private zm_armor_keep_at_t2()
{
    t2_max = 100;
    if ( isdefined( level.var_1e9e024bcfca2274 ) && isdefined( level.var_1e9e024bcfca2274.var_ba2fc513d06dd9d5 ) )
    {
        t2_max = level.var_1e9e024bcfca2274.var_ba2fc513d06dd9d5;
    }

    self.platecarrierlevel = 2;
    self.maxarmorhealth = t2_max;
    self armor::setarmorhealth( t2_max );
    self setclientomnvar( "ui_armor_current_level", 2 );
}

function private zm_armor_grant_t3()
{
    t3_max = level.zm_armor_t3_max ?? 150;

    self.platecarrierlevel = 3;
    self.maxarmorhealth = t3_max;
    self armor::setarmorhealth( t3_max );
    self setclientomnvar( "ui_armor_current_level", 3 );
}

function private zm_any_player_has_t3_armor()
{
    foreach ( player in level.players )
    {
        if ( !isplayer( player ) )
        {
            continue;
        }

        if ( ( player.platecarrierlevel ?? 1 ) >= 3 || player zm_juggernog_augment_active( #"juggernog_retaliation" ) )
        {
            return 1;
        }
    }

    return 0;
}

function private zm_turtle_shell_armor_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( !isdefined( level.var_6f8b7a2e996178a8 ) || !isdefined( level.var_21038aca0aba3c4a ) )
    {
        waitframe();
    }

    if ( isdefined( level.zm_turtle_shell_wrapped ) )
    {
        return;
    }
    level.zm_turtle_shell_wrapped = 1;

    level.zm_turtle_shell_orig_absorbed = level.var_6f8b7a2e996178a8;
    level.zm_turtle_shell_orig_post = level.var_21038aca0aba3c4a;
    level.var_6f8b7a2e996178a8 = &turtle_shell_armor_absorbed;
    level.var_21038aca0aba3c4a = &turtle_shell_armor_post;
}

function private turtle_shell_native_active()
{
    return utility::callsharedfunc( #"hash_e7a7d049d5f06935", #"hash_81cf46be569bf3bb", "specialty_juggernog" ) && utility::callsharedfunc( #"zombie", #"player_has_augment", #"juggernog_turtle_shell" );
}

function private turtle_shell_armor_absorbed( damage, eattacker, einflictor, smeansofdeath )
{
    if ( zm_is_tick_damage( smeansofdeath ) || zm_is_explosive_damage( smeansofdeath ) )
    {
        return 0;
    }

    front_mitigation_scale = 0;
    ignore_shell = 0;

    if ( isdefined( eattacker ) && ( eattacker.ignore_turtle_shell || ( smeansofdeath == "MOD_BLEEDOUT" && eattacker.var_f968344e6801d0c1 ) ) )
    {
        ignore_shell = 1;
    }

    if ( isdefined( einflictor ) && einflictor.ignore_turtle_shell )
    {
        ignore_shell = 1;
    }

    native_active = turtle_shell_native_active();
    prior_ignore = undefined;

    if ( native_active && isdefined( eattacker ) )
    {
        prior_ignore = eattacker.ignore_turtle_shell;
        eattacker.ignore_turtle_shell = 1;
        eattacker.var_84f354484bf84831 = undefined;
    }

    absorbed_damage = self [[ level.zm_turtle_shell_orig_absorbed ]]( damage, eattacker, einflictor, smeansofdeath );

    if ( native_active && isdefined( eattacker ) )
    {
        eattacker.ignore_turtle_shell = prior_ignore;
    }

    if ( ignore_shell || !isdefined( eattacker ) )
    {
        return absorbed_damage;
    }

    attack_origin = eattacker.turtle_shell_attack_origin ?? eattacker.origin;

    if ( !isdefined( attack_origin ) || eattacker == self || attack_origin == self.origin )
    {
        return absorbed_damage;
    }

    to_attacker = vectornormalize( attack_origin - self.origin );
    playerforward = vectornormalize( anglestoforward( self.angles ) );
    dot = vectordot( playerforward, to_attacker );

    if ( dot <= 0 )
    {
        eattacker.var_84f354484bf84831 = 1;
        absorbed_damage = damage;

        self setentitysoundcontext( "zm_plr_impact_armored", "on" );
        self thread clear_armored_sound_context();
    }
    else
    {
        absorbed_damage *= front_mitigation_scale;
    }

    return absorbed_damage;
}

function private clear_armored_sound_context()
{
    self endon( #"disconnect" );
    wait 0.1;
    self setentitysoundcontext( "zm_plr_impact_armored", "" );
}

function private turtle_shell_armor_post( damageabsorbed, attacker, smeansofdeath )
{
    if ( isdefined( attacker ) && attacker.var_84f354484bf84831 )
    {
        attacker.var_84f354484bf84831 = undefined;
    }

    native_active = turtle_shell_native_active();
    prior_ignore = undefined;

    if ( native_active && isdefined( attacker ) )
    {
        prior_ignore = attacker.ignore_turtle_shell;
        attacker.ignore_turtle_shell = 1;
    }

    result = self [[ level.zm_turtle_shell_orig_post ]]( damageabsorbed, attacker, smeansofdeath );

    if ( native_active && isdefined( attacker ) )
    {
        attacker.ignore_turtle_shell = prior_ignore;
    }

    return self zm_armor_hit_cost( result, smeansofdeath );
}

function private zm_juggernog_augment_active( augmentname )
{
    return utility::callsharedfunc( #"hash_e7a7d049d5f06935", #"hash_81cf46be569bf3bb", "specialty_juggernog" ) && utility::callsharedfunc( #"zombie", #"player_has_augment", augmentname );
}

function private zm_is_explosive_damage( smeansofdeath )
{
    switch ( smeansofdeath )
    {
        case "MOD_EXPLOSIVE":
        case "MOD_GRENADE":
        case "MOD_GRENADE_SPLASH":
        case "MOD_PROJECTILE":
        case "MOD_PROJECTILE_SPLASH":
            return 1;
    }

    return 0;
}

function private zm_is_tick_damage( smeansofdeath )
{
    switch ( smeansofdeath )
    {
        case "MOD_BLEEDOUT":
        case "MOD_FIRE":
        case "MOD_ELEMENTAL_FIRE":
        case "MOD_BURNED":
        case "MOD_FIRE_DAMAGE":
        case "MOD_ELEMENTAL_TOXIC":
        case "MOD_RADIATION":
            return 1;
    }

    return 0;
}

function private zm_armor_hit_cost( damageabsorbed, smeansofdeath )
{
    if ( !isdefined( damageabsorbed ) || damageabsorbed <= 0 )
    {
        return damageabsorbed;
    }

    if ( zm_is_tick_damage( smeansofdeath ) )
    {
        return 0;
    }

    plate_size = level.armorplateamount ?? 50;

    if ( isdefined( self.platecarrierlevel ) && self.platecarrierlevel > 0 && ( self.maxarmorhealth ?? 0 ) > 0 )
    {
        plate_size = self.maxarmorhealth / self.platecarrierlevel;
    }

    hit_fraction = 0.25;

    if ( utility::callsharedfunc( #"zombie", #"hash_3930894d8d2f0ee6", "specialty_death_perception", #"deathperception_sixth_sense" ) )
    {
        hit_fraction *= 0.75;
    }

    cost = plate_size * hit_fraction;

    return min( cost, self.armorhealth ?? cost );
}

function private zm_armormatic_always_on_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( !utility::issharedfuncdefined( #"zombie", #"hash_3930894d8d2f0ee6" ) )
    {
        waitframe();
    }

    if ( isdefined( level.zm_armormatic_wrapped ) )
    {
        return;
    }
    level.zm_armormatic_wrapped = 1;

    level.zm_armormatic_orig_check = level.sharedfuncs[ #"zombie" ][ #"hash_3930894d8d2f0ee6" ];
    level.sharedfuncs[ #"zombie" ][ #"hash_3930894d8d2f0ee6" ] = &zm_armormatic_check;
}

function private zm_armormatic_check( perkname, augmentname )
{
    if ( perkname == "specialty_juggernog" && augmentname == #"juggernog_iron_core" )
    {
        return 0;
    }

    if ( perkname == "specialty_juggernog" && augmentname == #"juggernog_retaliation" )
    {
        return 0;
    }

    if ( perkname == "specialty_quickrevive" && augmentname == #"quick_revive_last_chance" )
    {
        return 0;
    }

    if ( perkname == "specialty_quickrevive" && ( augmentname == #"quick_revive_escape_plan" || augmentname == #"quick_revive_die_hard" ) )
    {
        return 0;
    }

    if ( perkname == "specialty_quickrevive" && augmentname == #"quick_revive_precision_surgery" )
    {
        return 0;
    }

    if ( perkname == "specialty_quickrevive" && augmentname == #"quick_revive_dying_wish" )
    {
        return 0;
    }

    return self [[ level.zm_armormatic_orig_check ]]( perkname, augmentname );
}

function private zm_plate_heal_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( !isdefined( level.var_6b5a5711823ede8c ) )
    {
        waitframe();
    }

    if ( isdefined( level.zm_plate_heal_wrapped ) )
    {
        return;
    }
    level.zm_plate_heal_wrapped = 1;

    level.zm_plate_heal_orig = level.var_6b5a5711823ede8c;
    level.var_6b5a5711823ede8c = &zm_plate_heal_repair;
}

function private zm_plate_heal_repair()
{
    heal_fraction = istrue( self.insertingarmorplate ) ? 0.70 : 1.0;

    old_health = self.armorhealth ?? 0;

    if ( self zm_juggernog_augment_active( #"juggernog_thicker_plates" ) && isalive( self ) && self.health < self.maxhealth )
    {
        self.health = int( min( self.health + 50, self.maxhealth ) );
    }

    stock_new_health = self [[ level.zm_plate_heal_orig ]]();

    if ( !isdefined( self.platecarrierlevel ) || self.platecarrierlevel <= 0 || !isdefined( self.maxarmorhealth ) )
    {
        return stock_new_health;
    }

    plate_size = self.maxarmorhealth / self.platecarrierlevel;

    return clamp( old_health + plate_size * heal_fraction, 0, self.maxarmorhealth );
}

function private zm_armor_regen_on_damaged( params )
{
    self.zm_armor_regen_last_hit = gettime();

    if ( isdefined( params ) && isdefined( params.eattacker ) && isai( params.eattacker ) && self zm_dying_wish_regen_active() && randomfloat( 100 ) < 30 )
    {
        self thread zm_dying_wish_regen_kick();
    }
}

function private zm_dying_wish_regen_active()
{
    if ( !isdefined( level.zm_armormatic_orig_check ) )
    {
        return 0;
    }

    return self [[ level.zm_armormatic_orig_check ]]( "specialty_quickrevive", #"quick_revive_dying_wish" );
}

function private zm_dying_wish_regen_kick()
{
    self endon( #"death_or_disconnect" );

    wait 0.1;

    if ( isalive( self ) && !player::isinlaststand( self ) )
    {
        playerhealth::forcehealthregen( self, 1 );
    }
}

function private zm_armor_regen_loop()
{
    self notify( #"zm_armor_regen_restart" );
    self endon( #"zm_armor_regen_restart" );
    self endon( #"disconnect" );
    self endon( #"death" );
    level endon( #"game_ended" );

    self.zm_armor_regen_last_hit = gettime();

    base_amount = 3;

    if ( isdefined( level.zombie_augments ) && isdefined( level.zombie_augments[ #"juggernog_shielded" ] ) )
    {
        base_amount = level.zombie_augments[ #"juggernog_shielded" ].var_840d64e41ac5801a ?? 3;
    }

    delay = 6500;
    amount = base_amount * 1.25;
    tick_time = 0.35;

    prev_health = self.armorhealth ?? 0;

    while ( 1 )
    {
        wait tick_time;

        if ( !isalive( self ) )
        {
            continue;
        }

        current = self.armorhealth ?? 0;

        if ( current < prev_health )
        {
            self.zm_armor_regen_last_hit = gettime();
        }

        prev_health = current;

        if ( !turtle_shell_native_active() )
        {
            continue;
        }

        if ( self.var_a1faa64d8c07872e )
        {
            continue;
        }

        if ( !isdefined( self.maxarmorhealth ) || self.maxarmorhealth <= 0 || current >= self.maxarmorhealth )
        {
            continue;
        }

        if ( gettime() - self.zm_armor_regen_last_hit < delay )
        {
            continue;
        }

        new_health = clamp( current + amount, 0, self.maxarmorhealth );
        self armor::setarmorhealth( new_health );

        prev_health = self.armorhealth ?? new_health;
    }
}

function private zm_armor_wallbuy_start()
{
    level endon( #"game_ended" );

    wait_for_gametype();

    if ( !supported_mode() )
    {
        return;
    }

    ns = hashcat( #"hash_98a94353ec1044cc", "armor" );

    while ( !utility::issharedfuncdefined( ns, #"hash_aabdea2170a670c7" ) || !utility::issharedfuncdefined( ns, #"hash_eb2053cea864e5ab" ) )
    {
        waitframe();
    }

    if ( isdefined( level.zm_armor_wallbuy_wrapped ) )
    {
        return;
    }
    level.zm_armor_wallbuy_wrapped = 1;

    level.zm_armor_wallbuy_orig_purchase = level.sharedfuncs[ ns ][ #"hash_aabdea2170a670c7" ];
    level.zm_armor_wallbuy_orig_hint = level.sharedfuncs[ ns ][ #"hash_eb2053cea864e5ab" ];
    level.sharedfuncs[ ns ][ #"hash_aabdea2170a670c7" ] = &zm_armor_wallbuy_purchase;
    level.sharedfuncs[ ns ][ #"hash_eb2053cea864e5ab" ] = &zm_armor_wallbuy_hint;
}

function private zm_armor_wallbuys_disable_start()
{
    level endon( #"game_ended" );

    wait_for_gametype();

    if ( !supported_mode() )
    {
        return;
    }

    while ( !isdefined( level.gametypebundle ) )
    {
        waitframe();
    }

    level.gametypebundle.disablearmorwallbuys = 1;
}

function private zm_armor_cap_start()
{
    level endon( #"game_ended" );

    wait_for_gametype();

    if ( !supported_mode() )
    {
        return;
    }

    while ( 1 )
    {
        foreach ( player in level.players )
        {
            if ( !isplayer( player ) || !isalive( player ) )
            {
                continue;
            }

            if ( ( player.platecarrierlevel ?? 1 ) >= 3 && !player zm_juggernog_augment_active( #"juggernog_retaliation" ) )
            {
                player zm_armor_keep_at_t2();
            }

            if ( ( player.maxarmorhealth ?? 0 ) > 0 && ( player.armorhealth ?? 0 ) > player.maxarmorhealth )
            {
                player armor::setarmorhealth( player.maxarmorhealth );
            }
        }

        wait 0.1;
    }
}

function private zm_golden_armor_noop()
{
}

function private zm_golden_armor_block_start()
{
    level endon( #"game_ended" );

    wait_for_gametype();

    if ( !supported_mode() )
    {
        return;
    }

    for ( i = 0; i < 600 && !utility::issharedfuncdefined( #"ob_armor", #"set_golden_armor" ); i++ )
    {
        waitframe();
    }

    if ( utility::issharedfuncdefined( #"ob_armor", #"set_golden_armor" ) )
    {
        level.sharedfuncs[ #"ob_armor" ][ #"set_golden_armor" ] = &zm_golden_armor_noop;
    }
}

function private zm_armor_t3_block_start()
{
    level endon( #"game_ended" );

    wait_for_gametype();

    if ( !supported_mode() )
    {
        return;
    }

    while ( 1 )
    {
        if ( isdefined( level.var_1e9e024bcfca2274 ) )
        {
            if ( !isdefined( level.zm_armor_t3_max ) )
            {
                level.zm_armor_t3_max = level.var_1e9e024bcfca2274.var_c02aad60bddb8f16 ?? 150;
            }

            if ( zm_any_player_has_t3_armor() )
            {
                level.var_1e9e024bcfca2274.var_c02aad60bddb8f16 = level.zm_armor_t3_max;
            }
            else
            {
                level.var_1e9e024bcfca2274.var_c02aad60bddb8f16 = level.var_1e9e024bcfca2274.var_ba2fc513d06dd9d5 ?? 100;
            }
        }

        if ( isdefined( level.var_139e91e252a2df0c ) && isdefined( level.var_139e91e252a2df0c[ 2 ] ) && isdefined( level.var_139e91e252a2df0c[ 3 ] ) && isdefined( level.var_139e91e252a2df0c[ 2 ].costrefill ) )
        {
            level.var_139e91e252a2df0c[ 3 ].costbase = level.var_139e91e252a2df0c[ 2 ].costrefill;
        }

        if ( isdefined( level.var_139e91e252a2df0c ) && isdefined( level.var_139e91e252a2df0c[ 2 ] ) )
        {
            level.var_139e91e252a2df0c[ 2 ].costbase = 5000;
        }

        wait 0.1;
    }
}

function private zm_armor_wallbuy_tier( player )
{
    if ( self.var_7ffbc1821f2b0602 == #"wallbuy_zm_t10_armor_epic" )
    {
        return 3;
    }

    return 2;
}

function private zm_player_has_armor_carrier()
{
    if ( self.fresh_armor_bought_this_life )
    {
        return 1;
    }

    if ( ( self.maxarmorhealth ?? 0 ) > 0 )
    {
        return 1;
    }

    if ( ( self.platecarrierlevel ?? 1 ) >= 2 )
    {
        return 1;
    }

    return 0;
}

function private zm_armor_wallbuy_t2_price( player, tier )
{
    if ( !isdefined( self.zm_armor_orig_cost ) )
    {
        self.zm_armor_orig_cost = self.cost;
    }

    if ( tier == 2 && !( player zm_player_has_armor_carrier() ) )
    {
        self.cost = 5000;
    }
    else if ( isdefined( self.zm_armor_orig_cost ) )
    {
        self.cost = self.zm_armor_orig_cost;
    }
}

function private zm_armor_wallbuy_purchase( player )
{
    if ( isplayer( player ) )
    {
        tier = self zm_armor_wallbuy_tier( player );

        if ( tier == 3 )
        {
            player playsoundtoplayer( #"ui_zm_core_purchase_deny", player );
            return;
        }

        self zm_armor_wallbuy_t2_price( player, tier );
    }

    self [[ level.zm_armor_wallbuy_orig_purchase ]]( player );
}

function private zm_armor_wallbuy_hint( usable, player )
{
    owns_carrier = 0;

    if ( isplayer( player ) )
    {
        tier = usable zm_armor_wallbuy_tier( player );

        if ( tier == 3 )
        {
            hint_data = self [[ level.zm_armor_wallbuy_orig_hint ]]( usable, player );

            if ( isdefined( hint_data ) )
            {
                hint_data.aux_text = &"cp_zmb/armor_full";
                hint_data.interactable = 0;
            }

            return hint_data;
        }

        usable zm_armor_wallbuy_t2_price( player, tier );
        owns_carrier = player zm_player_has_armor_carrier();
    }

    hint_data = self [[ level.zm_armor_wallbuy_orig_hint ]]( usable, player );

    if ( owns_carrier && isdefined( hint_data ) && hint_data.type == "HINT_BUTTON" )
    {
        hint_data.title = &"cp_zmb/armor_repair";
        hint_data.description = &"cp_zmb/armor_repair_desc";

        t2_max = 100;
        if ( isdefined( level.var_1e9e024bcfca2274 ) && isdefined( level.var_1e9e024bcfca2274.var_ba2fc513d06dd9d5 ) )
        {
            t2_max = level.var_1e9e024bcfca2274.var_ba2fc513d06dd9d5;
        }

        if ( ( player.armorhealth ?? 0 ) >= max( t2_max, player.maxarmorhealth ?? 0 ) )
        {
            hint_data.aux_text = &"cp_zmb/armor_full";
            hint_data.interactable = 0;
        }
    }

    return hint_data;
}

function private zm_special_damage_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    if ( utility::issharedfuncdefined( #"zm", #"hash_364bf98dfc68dd24" ) )
    {
        level.zm_special_damage_orig = level.sharedfuncs[ #"zm" ][ #"hash_364bf98dfc68dd24" ];
    }

    utility::registersharedfunc( #"zm", #"hash_364bf98dfc68dd24", &zm_special_damage_remap );
}

function private zm_is_fixed_damage_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_shade" ) || isstartstr( subclass, "zombie_methone" ) || isstartstr( subclass, "zombie_hellhound" );
}

function private zm_is_loom_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_loom" ) && !isstartstr( subclass, "zombie_loom_minion" );
}

function private zm_is_viper_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_viper" ) && !isstartstr( subclass, "zombie_viper_mini" );
}

function private zm_is_galileo_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_galileo" );
}

function private zm_has_galileo_source( dmg_struct )
{
    candidates = [ dmg_struct.eattacker, dmg_struct.einflictor ];

    foreach ( ent in candidates )
    {
        if ( !isdefined( ent ) || isplayer( ent ) )
        {
            continue;
        }

        if ( zm_is_galileo_enemy( ent ) )
        {
            return true;
        }

        if ( isdefined( ent.owner ) && !isplayer( ent.owner ) && zm_is_galileo_enemy( ent.owner ) )
        {
            return true;
        }
    }

    return false;
}

function private zm_get_viper_source( dmg_struct )
{
    candidates = [ dmg_struct.eattacker, dmg_struct.einflictor ];

    foreach ( ent in candidates )
    {
        if ( !isdefined( ent ) || isplayer( ent ) )
        {
            continue;
        }

        if ( isdefined( ent.gunner ) )
        {
            ent = ent.gunner;
        }

        if ( zm_is_viper_enemy( ent ) )
        {
            return ent;
        }

        if ( isdefined( ent.owner ) && !isplayer( ent.owner ) && zm_is_viper_enemy( ent.owner ) )
        {
            return ent.owner;
        }
    }

    return undefined;
}

function private zm_is_viper_shock_damage( viper, dmg_struct )
{
    if ( isdefined( viper.grenadeweapon ) && isdefined( dmg_struct.objweapon ) && dmg_struct.objweapon == viper.grenadeweapon )
    {
        return true;
    }

    if ( isdefined( dmg_struct.einflictor ) && dmg_struct.einflictor != viper )
    {
        return true;
    }

    means = dmg_struct.smeansofdeath;

    return means == "MOD_GRENADE_SPLASH" || means == "MOD_ELEMENTAL_ELEC" || means == "MOD_PROJECTILE" || means == "MOD_PROJECTILE_SPLASH" || means == "MOD_EXPLOSIVE";
}

function private zm_is_viper_mini_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_viper_mini" );
}

function private zm_is_zursa_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_callisto" );
}

function private zm_is_mimic_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_mimic" );
}

function private zm_is_necropincer_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_karkinos" );
}

function private zm_is_orion_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_orion" );
}

function private zm_is_ranged_attack_damage( dmg_struct )
{
    if ( isdefined( dmg_struct.einflictor ) && isvalidmissile( dmg_struct.einflictor ) )
    {
        return true;
    }

    means = dmg_struct.smeansofdeath;

    return means == "MOD_ELEMENTAL_ELEC" || means == "MOD_GRENADE_SPLASH" || means == "MOD_PROJECTILE" || means == "MOD_PROJECTILE_SPLASH" || means == "MOD_EXPLOSIVE";
}

function private zm_is_minion_damage_enemy( ai )
{
    subclass = ai.subclass;

    if ( !isdefined( subclass ) || !isstring( subclass ) )
    {
        return false;
    }

    return isstartstr( subclass, "zombie_viper_mini" ) || isstartstr( subclass, "zombie_loom_minion" );
}

function private zm_special_damage_remap( dmg_struct )
{
    damage = dmg_struct.idamage;

    if ( isdefined( level.zm_special_damage_orig ) )
    {
        damage = self [[ level.zm_special_damage_orig ]]( dmg_struct ) ?? damage;
    }

    early_attacker = dmg_struct.eattacker;
    if ( isdefined( early_attacker ) && isdefined( early_attacker.gunner ) )
    {
        early_attacker = early_attacker.gunner;
    }

    if ( isdefined( damage ) && damage > 0 && zm_has_galileo_source( dmg_struct ) )
    {
        return 35;
    }

    if ( isdefined( early_attacker ) && !isplayer( early_attacker ) && isdefined( damage ) && damage > 0 )
    {
        if ( zm_is_necropincer_enemy( early_attacker ) || zm_is_mimic_enemy( early_attacker ) )
        {
            return 50;
        }

        if ( zm_is_orion_enemy( early_attacker ) || zm_is_loom_enemy( early_attacker ) )
        {
            if ( zm_is_ranged_attack_damage( dmg_struct ) )
            {
                return 35;
            }

            return 50;
        }
    }

    if ( isdefined( damage ) && damage > 0 )
    {
        viper_source = zm_get_viper_source( dmg_struct );

        if ( isdefined( viper_source ) && zm_is_viper_shock_damage( viper_source, dmg_struct ) )
        {
            return 50;
        }
    }

    if ( isdefined( damage ) && damage > 0 && damage >= self.maxhealth + ( self.maxarmorhealth ?? 0 ) )
    {
        return damage;
    }

    if ( isdefined( damage ) && damage > 0 && zm_is_tick_damage( dmg_struct.smeansofdeath ) )
    {
        return 10;
    }

    attacker = dmg_struct.eattacker;
    if ( isdefined( attacker ) && isdefined( attacker.gunner ) )
    {
        attacker = attacker.gunner;
    }

    if ( !isdefined( attacker ) || isplayer( attacker ) || !isdefined( damage ) )
    {
        return damage;
    }

    if ( zm_is_loom_enemy( attacker ) )
    {
        return damage;
    }

    if ( zm_is_viper_mini_enemy( attacker ) && damage > 0 && dmg_struct.smeansofdeath == "MOD_EXPLOSIVE" )
    {
        return 50;
    }

    if ( zm_is_viper_enemy( attacker ) && damage > 0 )
    {
        return 50;
    }

    if ( zm_is_fixed_damage_enemy( attacker ) && damage > 0 && damage < self.maxhealth + ( self.maxarmorhealth ?? 0 ) )
    {
        return 42;
    }

    if ( zm_is_minion_damage_enemy( attacker ) && damage > 0 && damage < self.maxhealth + ( self.maxarmorhealth ?? 0 ) )
    {
        if ( dmg_struct.smeansofdeath == "MOD_MELEE" )
        {
            return 42;
        }

        return 35;
    }

    if ( zm_is_mimic_enemy( attacker ) )
    {
        if ( damage > 0 && damage < self.maxhealth + ( self.maxarmorhealth ?? 0 ) )
        {
            return 50;
        }
    }

    if ( zm_is_zursa_enemy( attacker ) )
    {
        if ( isdefined( dmg_struct.einflictor ) && isdefined( dmg_struct.einflictor.beesdps ) )
        {
            return 10;
        }

        if ( damage > 0 && damage < self.maxhealth + ( self.maxarmorhealth ?? 0 ) )
        {
            return 50;
        }
    }

    return damage;
}

function private zm_augment_heal_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    heal_amount = 25;
    mask_heal_amount = 100;
    vampirism_done = 0;
    mask_done = 0;

    while ( !vampirism_done || !mask_done )
    {
        if ( isarray( level.zombie_augments ) )
        {
            if ( !vampirism_done && isdefined( level.zombie_augments[ #"m_mod_vampirism" ] ) )
            {
                level.zombie_augments[ #"m_mod_vampirism" ].var_fe5ffdb3ae1b8b69 = heal_amount;
                vampirism_done = 1;
            }

            if ( !mask_done && isdefined( level.zombie_augments[ #"w_mod_pretty_mask" ] ) )
            {
                level.zombie_augments[ #"w_mod_pretty_mask" ].var_ae6fc800338f2f27 = mask_heal_amount;
                mask_done = 1;
            }
        }

        if ( !vampirism_done || !mask_done )
        {
            wait 0.5;
        }
    }
}

function private zm_multipack_odds_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( !isarray( level.zombie_augments ) || !isdefined( level.zombie_augments[ #"z_mod_multi_pack" ] ) )
    {
        wait 0.5;
    }

    level.zombie_augments[ #"z_mod_multi_pack" ].var_8c228a1f06f37e98 = 0.333;

    wait 1;

    level callback::remove( "zm_packed_weapon_non_augment", &z_mod_augments::on_packed_weapon );
    level callback::add( "zm_packed_weapon_non_augment", &zm_multipack_on_packed );
}

function private zm_multipack_on_packed( params )
{
    new_weapon = params.w_new;

    if ( !isdefined( new_weapon ) )
    {
        return;
    }

    if ( !utility::callsharedfunc( #"zombie", #"hash_3930894d8d2f0ee6", "specialty_z_mod", #"z_mod_multi_pack" ) )
    {
        return;
    }

    if ( isdefined( level.zm_mode_modifiers ) && istrue( level.zm_mode_modifiers.var_63da2ef147f344a4 ) )
    {
        return;
    }

    now = gettime();

    if ( isdefined( self.zm_multipack_until ) && now < self.zm_multipack_until )
    {
        return;
    }

    if ( isdefined( self.zm_multipack_stamp ) && now - self.zm_multipack_stamp < 1500 )
    {
        return;
    }

    self.zm_multipack_stamp = now;

    if ( randomfloat( 1 ) >= 0.333 )
    {
        return;
    }

    self.zm_multipack_until = now + 6000;
    self thread zm_multipack_apply( new_weapon );
}

function private zm_multipack_apply( new_weapon )
{
    self endon( #"death_or_disconnect" );

    for ( i = 0; i < 100 && ( !self hasweapon( new_weapon ) || self isswitchingweapon() ); i++ )
    {
        waitframe();
    }

    waitframe();

    candidates = [];

    foreach ( weapon in self getweaponslistprimaries() )
    {
        if ( weapon == new_weapon )
        {
            continue;
        }

        if ( utility::callsharedfunc( #"pack_a_punch", #"can_pap", weapon ) )
        {
            candidates[ candidates.size ] = weapon;
        }
    }

    if ( candidates.size > 0 )
    {
        weapon_to_pack = candidates[ randomint( candidates.size ) ];
        current_level = utility::callsharedfunc( #"zombie", #"get_pap_level", weapon_to_pack );
        utility::callsharedfunc( #"pack_a_punch", #"pap_weapon", weapon_to_pack, current_level, undefined, undefined, undefined, 0, 1 );
    }

    self.zm_multipack_until = undefined;
}

function private zm_perk_limit_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( !isdefined( level.gametypebundle ) )
    {
        waitframe();
    }

    level.gametypebundle.perklimit = 5;

    level callback::add( "zm_perk_obtained", &zm_perk_bonus_on_obtained );
    level callback::add( "zm_perk_purchased", &zm_perk_bonus_on_purchased );
    level callback::add( "zm_perk_lost", &zm_mulekick_bogo_on_lost );
    level callback::add( #"player_spawned", &zm_perk_bonus_return_window );
    level callback::add( #"player_laststand_revived", &zm_perk_bonus_return_window );
}

function private zm_perk_bonus_return_window( params )
{
    if ( isplayer( self ) )
    {
        self.zm_perk_return_until = gettime() + 8000;
    }
}

function private zm_mulekick_bogo_active()
{
    return utility::callsharedfunc( #"zombie", #"hash_3930894d8d2f0ee6", "specialty_z_mod", #"z_mod_buy_one_get_one" );
}

function private zm_mulekick_bogo_on_lost( params )
{
    if ( !isplayer( self ) || !isdefined( params ) || params.var_ffc1674def575bfa != "specialty_z_mod" )
    {
        return;
    }

    if ( !istrue( self.zm_mulekick_free ) )
    {
        return;
    }

    self.zm_mulekick_free = undefined;
    self.var_468836e5e67e15b4++;
}

function private zm_perk_bonus_on_obtained( params )
{
    if ( !isplayer( self ) || !isdefined( params ) || !isdefined( params.var_ffc1674def575bfa ) )
    {
        return;
    }

    if ( params.var_ffc1674def575bfa == "specialty_z_mod" && !istrue( self.zm_mulekick_free ) && self zm_mulekick_bogo_active() )
    {
        self.zm_mulekick_free = 1;
        self.var_468836e5e67e15b4--;
        return;
    }

    if ( istrue( self.zm_qr_skip_grant ) )
    {
        return;
    }

    perk = params.var_ffc1674def575bfa;
    now = gettime();

    if ( isdefined( self.zm_perk_buy_perk ) && self.zm_perk_buy_perk == perk && isdefined( self.zm_perk_buy_time ) && now - self.zm_perk_buy_time <= 250 )
    {
        self.zm_perk_buy_perk = undefined;
        return;
    }

    if ( isarray( self.perma_perks ) && arraycontains( self.perma_perks, perk ) )
    {
        return;
    }

    if ( now <= ( self.zm_perk_return_until ?? 0 ) && isarray( self.var_a0c63f8db21c605b ) && arraycontains( self.var_a0c63f8db21c605b, perk ) )
    {
        return;
    }

    self.var_468836e5e67e15b4--;
    self.zm_perk_bonus = ( self.zm_perk_bonus ?? 0 ) + 1;
    self.zm_perk_bonus_perk = perk;
    self.zm_perk_bonus_time = now;
}

function private zm_perk_bonus_on_purchased( params )
{
    if ( !isplayer( self ) || !isdefined( params ) || !isdefined( params.perkref ) )
    {
        return;
    }

    if ( params.perkref == "specialty_z_mod" && self zm_mulekick_bogo_active() )
    {
        return;
    }

    now = gettime();

    if ( isdefined( self.zm_perk_bonus_perk ) && self.zm_perk_bonus_perk == params.perkref && isdefined( self.zm_perk_bonus_time ) && now - self.zm_perk_bonus_time <= 250 )
    {
        self.var_468836e5e67e15b4++;
        self.zm_perk_bonus--;
        self.zm_perk_bonus_perk = undefined;
        return;
    }

    self.zm_perk_buy_perk = params.perkref;
    self.zm_perk_buy_time = now;
}

function private zm_juggernog_augments_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    probiotic_health = 350;
    shake_done = 0;
    probiotic_done = 0;
    plates_done = 0;
    durable_done = 0;

    playerhealth::function_d7d82c8b22e0a4fe( &zm_probiotic_regen_modifier );

    while ( !shake_done || !probiotic_done || !plates_done || !durable_done )
    {
        if ( isarray( level.zombie_augments ) )
        {
            if ( !durable_done && isdefined( level.zombie_augments[ #"juggernog_well_constructed" ] ) )
            {
                level.zombie_augments[ #"juggernog_well_constructed" ].var_855d075ee4c2b737 = 0;
                durable_done = 1;
            }

            if ( !plates_done && isdefined( level.zombie_augments[ #"juggernog_thicker_plates" ] ) )
            {
                level.zombie_augments[ #"juggernog_thicker_plates" ].var_fcd4c396ce615ccc = 0;
                plates_done = 1;
            }

            if ( !shake_done && isdefined( level.zombie_augments[ #"juggernog_perfect_counter" ] ) )
            {
                level.zombie_augments[ #"juggernog_perfect_counter" ].var_54b7d92dead9a8c9 = 0;
                shake_done = 1;
            }

            if ( !probiotic_done && isdefined( level.zombie_augments[ #"juggernog_juggernaut" ] ) && isdefined( level.perkbundles ) && isdefined( level.perkbundles[ "specialty_juggernog" ] ) )
            {
                base_health = int( getmatchrulesdata( "commonOption", "maxHealth" ) ) ?? 100;
                jugg_bonus = level.perkbundles[ "specialty_juggernog" ].var_f40eb2103401205e ?? 0;
                level.zombie_augments[ #"juggernog_juggernaut" ].var_bb0cb5f15169b37c = max( probiotic_health - ( base_health + jugg_bonus ), 0 );
                probiotic_done = 1;
            }
        }

        if ( !shake_done || !probiotic_done || !plates_done || !durable_done )
        {
            wait 0.5;
        }
    }
}

function private zm_durable_plates_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    level callback::add( "zombie_melee", &zm_durable_plates_on_melee );
}

function private zm_durable_plates_on_melee( params )
{
    if ( !isdefined( self ) || !isalive( self ) || !isdefined( params ) )
    {
        return;
    }

    target = params.var_2d2aab21299551f8;

    if ( !isplayer( target ) || !isdefined( self.maxhealth ) || self.maxhealth <= 0 )
    {
        return;
    }

    if ( self.health <= self.maxhealth * 0.20 || !target zm_juggernog_augment_active( #"juggernog_well_constructed" ) )
    {
        return;
    }

    self.health = int( max( 1, self.health - self.maxhealth * 0.04 ) );
}

function private zm_plate_drop_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    level callback::add( "on_zombie_ai_killed", &zm_plate_drop_on_killed );
}

function private zm_plate_drop_on_killed( params )
{
    if ( !isdefined( params ) || !isdefined( params.origin ) || istrue( params.b_in_spawn_closet ) )
    {
        return;
    }

    if ( randomfloat( 100 ) >= 3 )
    {
        return;
    }

    spawnoptions = common_item::function_bc5ff2958b71a708( params.origin, ( 0, 0, 0 ) );
    common_item::function_325e28c0fb65c36a( level.armorref ?? "equip_armorplate", 1, spawnoptions );
}

function private zm_probiotic_regen_modifier( healthperframe )
{
    scale = 1;

    if ( zm_juggernog_augment_active( #"juggernog_juggernaut" ) )
    {
        scale = 0.35;
    }

    if ( self zm_karmic_active() )
    {
        scale *= 1.05;
    }

    return scale;
}

function private zm_probiotic_delay_loop()
{
    self notify( #"zm_probiotic_delay_restart" );
    self endon( #"zm_probiotic_delay_restart" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    while ( 1 )
    {
        if ( zm_juggernog_augment_active( #"juggernog_juggernaut" ) )
        {
            self playerhealth::function_fd91e6d94cab77e7( #"zm_probiotic_regen_delay", -1.65 );
        }
        else
        {
            self playerhealth::function_b1fb4d148779580e( #"zm_probiotic_regen_delay" );
        }

        self zm_emt_overheal_tick();

        if ( zm_last_chance_active() )
        {
            self playerhealth::function_fd91e6d94cab77e7( #"zm_last_chance_regen_delay", 0.15 );
        }
        else
        {
            self playerhealth::function_b1fb4d148779580e( #"zm_last_chance_regen_delay" );
        }

        wait 0.25;
    }
}

function private zm_dying_wish_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( !utility::issharedfuncdefined( #"zombie", #"hash_555f057b4e2d44f8" ) )
    {
        waitframe();
    }

    if ( isdefined( level.zm_dying_wish_wrapped ) )
    {
        return;
    }
    level.zm_dying_wish_wrapped = 1;

    level.zm_dying_wish_orig_damage = level.sharedfuncs[ #"zombie" ][ #"hash_555f057b4e2d44f8" ];
    level.sharedfuncs[ #"zombie" ][ #"hash_555f057b4e2d44f8" ] = &zm_iron_core_dying_wish;
}

function private zm_iron_core_dying_wish( sparams )
{
    wish_flag = self.quick_revive_dying_wish;
    self.quick_revive_dying_wish = 1;
    idamage = self [[ level.zm_dying_wish_orig_damage ]]( sparams );
    self.quick_revive_dying_wish = wish_flag;

    if ( !isplayer( self ) || !isdefined( sparams ) || !isnumber( idamage ) )
    {
        return idamage;
    }

    if ( isdefined( sparams.eattacker ) && sparams.eattacker == self && zm_is_explosive_damage( sparams.smeansofdeath ) )
    {
        idamage = 50;
    }

    if ( self.quick_revive_dying_wish || gettime() < ( self.zm_iron_core_wish_ready ?? 0 ) )
    {
        return idamage;
    }

    if ( self.health - idamage > 0 || sparams.smeansofdeath == "MOD_SUICIDE" )
    {
        return idamage;
    }

    if ( !zm_juggernog_augment_active( #"juggernog_iron_core" ) || !val::get( "damage" ) )
    {
        return idamage;
    }

    if ( sparams.smeansofdeath == "MOD_FALLING" )
    {
        if ( damage::modifyfalldamage( self, idamage, sparams.idflags, sparams.smeansofdeath ) < idamage )
        {
            return idamage;
        }

        if ( self isdiving() && utility::callsharedfunc( #"zombie_perks", #"has_zombie_perk", "specialty_phd_flopper" ) )
        {
            return idamage;
        }

        if ( utility::callsharedfunc( #"zombie", #"hash_3930894d8d2f0ee6", "specialty_staminup", #"staminup_light_footed" ) )
        {
            return idamage;
        }
    }

    attacker = sparams.eattacker;

    if ( attacker.classname == "worldspawn" )
    {
        attacker = undefined;
    }

    if ( damage::filterdamage( sparams.einflictor, attacker, self, sparams.idamage, sparams.idflags, sparams.smeansofdeath, sparams.objweapon, sparams.shitloc ) )
    {
        return idamage;
    }

    [ healthdamage, lightarmordamage ] = armor::modifyarmordamage( sparams.eattacker, sparams.einflictor, self, sparams.idamage, sparams.objweapon, sparams.smeansofdeath, sparams.shitloc, sparams.idflags, sparams.unscaleddamage, sparams.unmodifieddamage, sparams.partname, 1 );

    if ( self.health - healthdamage > 0 )
    {
        return idamage;
    }

    remaininghealth = level.zombie_augments[ #"quick_revive_dying_wish" ].var_dfaa48935da75e60 ?? 1;
    duration = 5;

    self.var_6f9595e5de90c2aa = ( self.var_6f9595e5de90c2aa ?? 0 ) + 1;
    next_use = self.var_6f9595e5de90c2aa + 1;
    wait_minutes = 3;

    if ( next_use >= 8 )
    {
        wait_minutes = 7 + next_use;
    }
    else if ( next_use >= 5 )
    {
        wait_minutes = 7 + ( next_use - 2 );
    }
    else if ( next_use == 4 )
    {
        wait_minutes = 7;
    }
    else if ( next_use == 3 )
    {
        wait_minutes = 5;
    }
    self.zm_iron_core_wish_ready = gettime() + int( wait_minutes * 60000 );
    idamage = 1;
    self.health = remaininghealth + idamage;
    self.quick_revive_dying_wish = 1;
    self playsound( #"hash_502c7080fd3d0228" );
    self thread zm_iron_core_wish_end( duration );

    self thread zm_dying_wish_red( duration );

    return idamage;
}

function private zm_dying_wish_red( duration )
{
    self endon( #"disconnect" );

    pbgpostfxbundlestart( self, "cer_zm_aether_shroud" );

    wait duration;

    pbgpostfxbundleend( self, "cer_zm_aether_shroud" );
}

function private zm_iron_core_wish_end( duration )
{
    self endon( #"disconnect" );

    wait duration;

    self.quick_revive_dying_wish = undefined;

    if ( !isdefined( self ) || !isalive( self ) )
    {
        return;
    }

    if ( !status_effects::has_status_effect_type( "wound" ) )
    {
        playerhealth::forcehealthregen( self, 1 );
        return;
    }

    self endon( #"death" );
    self waittill( #"hash_d3073c1d39f5eb56" );
    playerhealth::forcehealthregen( self, 1 );
}

function private zm_last_chance_active()
{
    if ( !isdefined( level.zm_armormatic_orig_check ) )
    {
        return 0;
    }

    return self [[ level.zm_armormatic_orig_check ]]( "specialty_quickrevive", #"quick_revive_last_chance" );
}

function private zm_last_chance_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( !utility::issharedfuncdefined( #"zombie", #"player_has_augment" ) )
    {
        waitframe();
    }

    if ( !isdefined( level.zm_last_chance_wrapped ) )
    {
        level.zm_last_chance_wrapped = 1;
        level.zm_last_chance_orig_has = level.sharedfuncs[ #"zombie" ][ #"player_has_augment" ];
        level.sharedfuncs[ #"zombie" ][ #"player_has_augment" ] = &zm_last_chance_has_augment;
    }

    while ( !isdefined( level.var_92b9a0cbf749d8c6 ) )
    {
        waitframe();
    }

    base_radius = level.var_92b9a0cbf749d8c6;
    base_dist_sq = level.var_514a7139f92200 ?? 65536;

    while ( 1 )
    {
        any_active = 0;

        foreach ( player in level.players )
        {
            if ( isplayer( player ) && player zm_last_chance_active() )
            {
                any_active = 1;
                break;
            }
        }

        if ( any_active )
        {
            level.var_92b9a0cbf749d8c6 = base_radius * 1.25;
            level.var_514a7139f92200 = base_dist_sq * 1.5625;
        }
        else
        {
            level.var_92b9a0cbf749d8c6 = base_radius;
            level.var_514a7139f92200 = base_dist_sq;
        }

        wait 0.25;
    }
}

function private zm_last_chance_has_augment( augmentname )
{
    if ( augmentname == #"quick_revive_last_chance" || augmentname == #"quick_revive_precision_surgery" || augmentname == #"quick_revive_dying_wish" || augmentname == #"quick_revive_escape_plan" || augmentname == #"quick_revive_die_hard" )
    {
        return 0;
    }

    return self [[ level.zm_last_chance_orig_has ]]( augmentname );
}

function private zm_emt_active()
{
    if ( !isdefined( level.zm_armormatic_orig_check ) )
    {
        return 0;
    }

    return self [[ level.zm_armormatic_orig_check ]]( "specialty_quickrevive", #"quick_revive_precision_surgery" );
}

function private zm_emt_overheal_delay()
{
    return 30000;
}

function private zm_emt_overheal_bonus()
{
    return 50;
}

function private zm_emt_overheal_clear()
{
    self.zm_emt_base_max = undefined;
    self.zm_emt_expected_max = undefined;
}

// Equivalent Exchange: after going 30 seconds without taking damage, grant overhealth.
// The bonus is a buffer above normal max health. Once damaged, it can no longer regenerate
// and is gone as soon as health falls back to the normal maximum.
function private zm_emt_overheal_tick()
{
    if ( !isalive( self ) )
    {
        self.zm_emt_last_damage = undefined;
        self.zm_emt_prev_health = undefined;
        return;
    }

    now = gettime();

    if ( self zm_emt_active() )
    {
        if ( !isdefined( self.zm_emt_last_damage ) )
        {
            self.zm_emt_last_damage = now;
        }

        if ( isdefined( self.zm_emt_prev_health ) && self.health < self.zm_emt_prev_health )
        {
            self.zm_emt_last_damage = now;
        }

        if ( isdefined( self.zm_emt_expected_max ) )
        {
            if ( self.maxhealth != self.zm_emt_expected_max )
            {
                // Max health was reset elsewhere (respawn etc.); drop our bookkeeping and start the timer over.
                zm_emt_overheal_clear();
                self.zm_emt_last_damage = now;
            }
            else
            {
                base = self.zm_emt_base_max;
                capped = int( max( base, min( self.maxhealth, self.health ) ) );

                if ( capped != self.maxhealth )
                {
                    self.maxhealth = capped;
                    self.zm_emt_expected_max = capped;
                }

                if ( self.maxhealth <= base )
                {
                    self.maxhealth = base;
                    zm_emt_overheal_clear();
                }
            }
        }
        else if ( now - self.zm_emt_last_damage >= zm_emt_overheal_delay() && !player::isinlaststand( self ) )
        {
            self.zm_emt_base_max = self.maxhealth;
            self.maxhealth = self.zm_emt_base_max + zm_emt_overheal_bonus();
            self.zm_emt_expected_max = self.maxhealth;
            self.health = self.maxhealth;
        }

        self.zm_emt_prev_health = self.health;
        return;
    }

    self.zm_emt_last_damage = undefined;
    self.zm_emt_prev_health = undefined;

    if ( !isdefined( self.zm_emt_expected_max ) )
    {
        return;
    }

    if ( self.maxhealth == self.zm_emt_expected_max )
    {
        self.maxhealth = self.zm_emt_base_max;
    }

    self.health = int( min( self.health, self.maxhealth ) );
    zm_emt_overheal_clear();
}

function private zm_adrenaline_active()
{
    if ( !isdefined( level.zm_armormatic_orig_check ) )
    {
        return 0;
    }

    return self [[ level.zm_armormatic_orig_check ]]( "specialty_quickrevive", #"quick_revive_adrenaline_rush" );
}

function private zm_adrenaline_save_loop()
{
    self notify( #"zm_adrenaline_save_restart" );
    self endon( #"zm_adrenaline_save_restart" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    while ( 1 )
    {
        wait 1;

        if ( !isalive( self ) || self.sessionstate == "spectator" )
        {
            if ( istrue( self.zm_adrenaline_had ) && isdefined( self.zm_adrenaline_saved ) )
            {
                self.zm_adrenaline_had = undefined;
                self.zm_adrenaline_pending = 1;
            }

            return;
        }

        if ( !self zm_adrenaline_active() )
        {
            self.zm_adrenaline_had = undefined;
            continue;
        }

        self.zm_adrenaline_had = 1;

        if ( player::isinlaststand( self ) || gettime() < ( self.zm_adrenaline_block_until ?? 0 ) )
        {
            continue;
        }

        prior_saved = self.a_saved_weapons;
        prior_old = self.old_weapon_obj;
        self zm_utility::function_d47920bb0d5fa327( "zm_adrenaline_rush" );
        self.zm_adrenaline_saved = self.a_saved_weapons;
        self.zm_adrenaline_old = self.old_weapon_obj;
        self.a_saved_weapons = prior_saved;
        self.old_weapon_obj = prior_old;
    }
}

function private zm_adrenaline_restore()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    if ( !istrue( self.zm_adrenaline_pending ) )
    {
        return;
    }

    wait 0.5;

    if ( level.b_zm_game_over || !isalive( self ) || self.sessionstate == "spectator" )
    {
        return;
    }

    self.zm_adrenaline_pending = undefined;

    self.a_saved_weapons = self.zm_adrenaline_saved;
    self zm_utility::function_663d59490abc834f( self.zm_adrenaline_old );
    self.a_saved_weapons = undefined;
    self.zm_adrenaline_saved = undefined;

    foreach ( perk in ( self.zm_adrenaline_kept ?? [] ) )
    {
        if ( isalive( self ) && !( self zombie_perks::has_perk( perk ) ) )
        {
            zm_qr_give_perk_quiet( self, perk );
            waitframe();
        }
    }
}

function private zm_adrenaline_revive_watch()
{
    self notify( #"zm_adrenaline_revive_restart" );
    self endon( #"zm_adrenaline_revive_restart" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    while ( 1 )
    {
        self waittill( #"laststand_revived" );

        self.zm_adrenaline_block_until = gettime() + 4000;

        if ( !self zm_adrenaline_active() )
        {
            continue;
        }

        self.zm_adrenaline_tracking = 1;
        self.zm_adrenaline_grace = gettime() + 3000;

        wait 1.5;

        foreach ( perk in ( self.zm_adrenaline_kept ?? [] ) )
        {
            if ( isalive( self ) && !( self zombie_perks::has_perk( perk ) ) )
            {
                zm_qr_give_perk_quiet( self, perk );
                waitframe();
            }
        }
    }
}

function private zm_adrenaline_perk_loop()
{
    self notify( #"zm_adrenaline_perk_restart" );
    self endon( #"zm_adrenaline_perk_restart" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    if ( !istrue( self.zm_adrenaline_pending ) )
    {
        self.zm_adrenaline_kept = [];
    }

    self.zm_adrenaline_tracking = undefined;
    known = [];

    while ( 1 )
    {
        wait 0.25;

        if ( !isalive( self ) )
        {
            continue;
        }

        current = self zombie_perks::get_active_perks_str_array();

        if ( istrue( self.zm_adrenaline_tracking ) && gettime() >= ( self.zm_adrenaline_grace ?? 0 ) && self.zm_adrenaline_kept.size < 5 )
        {
            foreach ( perk in current )
            {
                if ( !arraycontains( known, perk ) && !arraycontains( self.zm_adrenaline_kept, perk ) && self.zm_adrenaline_kept.size < 5 )
                {
                    self.zm_adrenaline_kept[ self.zm_adrenaline_kept.size ] = perk;
                }
            }
        }

        known = current;
    }
}

function private zm_swift_active()
{
    if ( !isdefined( level.zm_armormatic_orig_check ) )
    {
        return 0;
    }

    return self [[ level.zm_armormatic_orig_check ]]( "specialty_quickrevive", #"quick_revive_escape_plan" );
}

function private zm_karmic_active()
{
    if ( !isdefined( level.zm_armormatic_orig_check ) )
    {
        return 0;
    }

    return self [[ level.zm_armormatic_orig_check ]]( "specialty_quickrevive", #"quick_revive_die_hard" );
}

function private zm_recovery_loop()
{
    self notify( #"zm_recovery_restart" );
    self endon( #"zm_recovery_restart" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    prev_health = self.health;
    regen_until = 0;
    speed_on = 0;
    revive_on = 0;

    while ( 1 )
    {
        wait 0.1;

        if ( !isalive( self ) )
        {
            prev_health = self.health;
            regen_until = 0;
            speed_on = 0;
            revive_on = 0;
            continue;
        }

        if ( self.health > prev_health && !player::isinlaststand( self ) )
        {
            regen_until = gettime() + 600;
        }

        prev_health = self.health;

        want_speed = gettime() < regen_until && self.health < self.maxhealth && self zm_swift_active();

        if ( want_speed && !speed_on )
        {
            self weapons::addextramovespeed( "zm_swift_recovery", 0.1 );
            self weapons::updatemovespeedscale();
            speed_on = 1;
        }
        else if ( !want_speed && speed_on )
        {
            self weapons::removeextramovespeed( "zm_swift_recovery" );
            self weapons::updatemovespeedscale();
            speed_on = 0;
        }

        want_revive = self zm_karmic_active();

        if ( want_revive && !revive_on )
        {
            self.var_3e398b71be70e3c6 = ( self.var_3e398b71be70e3c6 ?? 1 ) / 1.05;
            revive_on = 1;
        }
        else if ( !want_revive && revive_on )
        {
            self.var_3e398b71be70e3c6 = ( self.var_3e398b71be70e3c6 ?? 1 ) * 1.05;
            revive_on = 0;
        }
    }
}

autoexec zm_ae_master_init()
{
    level thread zm_disable_zombie_drops_start();
    level thread zm_remove_milestone_salvage();
    level thread zm_block_direct_salvage_currency();
    level thread zm_fix_maneki_neko_table();
    level thread zm_streak_drops_init();
    level thread zm_tu_box_init();
    level thread zm_unlock_map_wonder_weapons();
    level thread zm_rarity_cap_box_and_wallbuys();
    level thread zm_rarity_wallbuy_chalk();
    level thread zm_ww_semtex_init();
    level thread zm_arsenal_menu_hook_start();
    level thread zm_pap_rarity_init();
    level thread zm_pap_pricing_init();
    level thread zm_qr_self_revive_init();
    level thread zm_ammo_cache_prices_start();
    level thread zm_wallbuy_rarity_cap_start();
    level thread zm_box_rarity_cap_start();
    level thread zm_mannequin_wunderfizz_start();
    level thread zm_box_rarity_strict_start();
    level thread zm_film_reel_drops_init();
    level thread zm_crafting_table_disable_start();
    level thread zm_crafting_table_hook_start();
    level thread zm_firefly_free_tessie_repair_init();
    level thread zm_plate_hunter_ammo_start();
    level thread zm_mrp_rewards_start();
    level thread zm_crystal_pap_start();
    level thread zm_ruby_purple_salvage_start();
    level thread zm_firefly_purple_salvage_start();
    level thread zm_mantis_purple_salvage_start();
    level thread zm_mantis_tedd_start();
    level thread zm_death_machine_ammo_start();
    level thread zm_mantis_cyst_start();
    level thread zm_locust_purple_salvage_start();
    level thread zm_hornet_purple_salvage_start();
    level thread zm_scarab_purple_salvage_start();
    level thread zm_purple_salvage_pickup_hook();
}

function private zm_ammo_cache_prices_start()
{
    level endon( #"game_ended" );

    wait_for_gametype();

    if ( !supported_mode() )
    {
        return;
    }

    while ( true )
    {
        info = level._ammo_cache_info;

        if ( isdefined( info ) )
        {
            info.cost = 500;
            info.var_b73cf47f78dc7922 = 2500;
            info.var_b73cf37f78dc76ef = 4500;
            info.var_b73cf27f78dc74bc = 6500;
            info.var_b73cf17f78dc7289 = 6500;
            info.var_cecc0a1d213a5866 = 4500;
            info.var_89de21b8a22ba0e3 = 6500;
            info.var_89de22b8a22ba316 = 7500;
            info.var_89de23b8a22ba549 = 10000;
            info.var_89de24b8a22ba77c = 10000;
        }

        wait 0.5;
    }
}

function private zm_crafting_table_disable_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    level callback::add( #"player_spawned", &zm_crafting_table_disable_player );

    while ( true )
    {
        foreach ( player in level.players )
        {
            player zm_crafting_table_disable_player( undefined );
        }

        wait 0.25;
    }
}

function private zm_crafting_table_disable_player( params )
{
    if ( !isplayer( self ) )
    {
        return;
    }

    if ( !zm_crafting_armor_mode() )
    {
        self.crafting_table_disabled = 1;
        return;
    }

    if ( istrue( level.zm_ct_armor_ready ) || ( !zm_crafting_survival_mode() && self zm_crafting_table_salvage_ok() ) )
    {
        self.crafting_table_disabled = 0;
        return;
    }

    self.crafting_table_disabled = 1;
}

function private zm_crafting_survival_mode()
{
    mode = game_utility::getgametype();

    return mode == "zm_rb_survival" || mode == "zm_rb_r_mod_survival";
}

function private zm_crafting_armor_mode()
{
    mode = game_utility::getgametype();

    return mode == "zm_rb" || mode == "zm_rb_ruby" || isstartstr( mode, "zm_rb_r_mod" ) || isstartstr( mode, "zm_rb_rh_mod" ) || zm_crafting_survival_mode();
}

function private zm_crafting_armor_cost()
{
    return 5000;
}

function private zm_crafting_salvage_cost()
{
    return 1500;
}

function private zm_crafting_table_salvage_ok()
{
    return isplayer( self ) && self currency::can_afford( #"salvage", zm_crafting_salvage_cost() );
}

function private zm_crafting_table_interact( table )
{
    if ( !isdefined( table ) )
    {
        return undefined;
    }

    mdl = table.model_table ?? table.var_7fac639c5e7fd54;

    if ( !isdefined( mdl ) )
    {
        return undefined;
    }

    return mdl.interact;
}

function private zm_crafting_table_hook_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" || !zm_crafting_armor_mode() )
    {
        return;
    }

    while ( true )
    {
        if ( isarray( level.a_s_crafting_tables ) )
        {
            if ( zm_crafting_survival_mode() )
            {
                if ( !isarray( level.zm_ct_armor_props ) )
                {
                    level.zm_ct_armor_props = [];
                }

                level.zm_ct_armor_ready = 1;

                foreach ( table in level.a_s_crafting_tables )
                {
                    if ( isdefined( table ) && !isdefined( table.zm_ct_prop ) )
                    {
                        zm_crafting_table_spawn_prop( table, 0 );
                    }
                }
            }

            foreach ( table in level.a_s_crafting_tables )
            {
                usable = zm_crafting_table_interact( table );

                if ( !isdefined( usable ) )
                {
                    continue;
                }

                if ( istrue( usable.zm_ct_hooked ) )
                {
                    continue;
                }

                usable.zm_ct_hooked = 1;

                if ( istrue( level.zm_ct_armor_ready ) )
                {
                    usable zm_crafting_table_armor_convert();
                    continue;
                }

                usable interaction::set_interact_use_callback( &zm_crafting_table_use );
            }
        }

        wait 1;
    }
}

function private zm_crafting_table_take_salvage( player )
{
    foreach ( member in level.players )
    {
        if ( !isplayer( member ) )
        {
            continue;
        }

        have = member.currency[ #"salvage" ] ?? 0;
        cost = int( min( have, zm_crafting_salvage_cost() ) );

        if ( cost <= 0 )
        {
            continue;
        }

        member.zm_salvage_grant = 1;
        member currency::function_b5fe1e05c892a7f3( #"salvage", cost, #"itemuse" );
        member.zm_salvage_grant = undefined;

        member currency::function_794c6e82017f38c3( have - cost, #"salvage" );
        member.currency[ #"salvage" ] = have - cost;
    }
}

function private zm_crafting_table_fx( org, snd, fx )
{
    if ( isdefined( snd ) && snd != "" )
    {
        playsoundatpos( org + ( 0, 0, 20 ), snd );
    }

    if ( !isdefined( fx ) || fx == "" )
    {
        return;
    }

    id = undefined;

    if ( isdefined( level._effect ) && isdefined( level._effect[ fx ] ) )
    {
        id = level._effect[ fx ];
    }
    else
    {
        id = loadfxasset( fx );
    }

    if ( isdefined( id ) )
    {
        playfx( id, org + ( 0, 0, 20 ) );
    }
}

function private zm_crafting_table_use( player )
{
    if ( !isplayer( player ) || istrue( player.zm_ct_busy ) )
    {
        return;
    }

    if ( player.interactions_disabled || player.isdeploying || istrue( player.is_crafting ) )
    {
        return;
    }

    if ( !player zm_crafting_table_salvage_ok() )
    {
        return;
    }

    player thread zm_crafting_table_assemble( self );
}

function private zm_crafting_table_assemble( usable )
{
    self.zm_ct_busy = 1;
    ok = self zm_crafting_table_hold();

    if ( isplayer( self ) )
    {
        self.zm_ct_busy = undefined;
    }

    if ( !ok || !isplayer( self ) || !isalive( self ) || !self zm_crafting_table_salvage_ok() )
    {
        return;
    }

    zm_crafting_table_take_salvage( self );

    self.crafting_table_disabled = 1;

    zm_crafting_table_spawn_armor_props();

    self.crafting_table_disabled = 0;
    usable thread crafting_table::function_4c0d42b2cb94d589( self );
    self thread zm_crafting_table_force_close();

    if ( isplayer( self ) )
    {
        self zm_crafting_table_disable_player( undefined );
    }
}

function private zm_crafting_table_force_close()
{
    self endon( #"disconnect" );

    start = gettime();
    flagged = 0;

    while ( gettime() - start < 1800 )
    {
        self setclientomnvar( "ui_purchasemenu_id", 0 );

        if ( !flagged && gettime() - start >= 900 && isdefined( self.crafting_table_active ) )
        {
            self.var_fa38187d52ae7d76 = 1;
            flagged = 1;
        }

        if ( flagged && !isdefined( self.crafting_table_active ) )
        {
            break;
        }

        waitframe();
    }

    self setclientomnvar( "ui_purchasemenu_id", 0 );
}

function private zm_crafting_table_hold()
{
    self zm_interaction::function_307c21197e0798d4( &"shared_hintstrings/crafting_table" );
    self zm_quest::function_eb3a5a6c3f4f3ba6( { #craft_reason:"zm_ct" } );
    t0 = gettime();
    r = 0;
    waitframe();

    while ( isdefined( self ) && isalive( self ) && !istrue( self.inlaststand ) )
    {
        f = ( gettime() - t0 ) / 3000.0;

        if ( f >= 1 )
        {
            r = 1;
            break;
        }

        self zm_interaction::function_45e51da251cd5e3a( f );
        waitframe();
    }

    if ( isdefined( self ) )
    {
        self zm_quest::function_b94186b3fb991490( { #craft_reason:"zm_ct" } );
        self zm_interaction::function_7c7ed762cd4d0333();
    }

    if ( r && isdefined( self ) )
    {
        playsoundatpos( self.origin, "evt_zm_player_craft_success" );
        return 1;
    }

    return 0;
}

function private zm_crafting_table_spawn_prop( table, with_fx )
{
    if ( !isdefined( table ) || isdefined( table.zm_ct_prop ) )
    {
        return;
    }

    origin = table.origin;
    angles = table.angles;

    mdl = table.model_table ?? table.var_7fac639c5e7fd54;

    if ( isdefined( mdl ) )
    {
        origin = mdl.origin;
        angles = mdl.angles;
    }

    if ( !isdefined( origin ) )
    {
        return;
    }

    if ( !isdefined( angles ) )
    {
        angles = ( 0, 0, 0 );
    }

    if ( with_fx )
    {
        zm_crafting_table_fx( origin, "ui_zm_core_door_purchase_success", "vfx_sat_zm_chompy_equipment_cleaned" );
        zm_crafting_table_fx( origin - ( 0, 0, 20 ), undefined, "vfx_sat_levels_zm_firefly_phone_booth_spawn" );
    }

    prop = spawn( "script_model", origin + ( 0, 0, 60 ) );
    prop.angles = angles;
    prop setmodel( "t10_zm_power_up_armor_vest_01" );

    table.zm_ct_prop = prop;
    level.zm_ct_armor_props[ level.zm_ct_armor_props.size ] = prop;

    usable = zm_crafting_table_interact( table );

    if ( isdefined( usable ) )
    {
        usable zm_crafting_table_armor_convert();
    }
}

function private zm_crafting_table_spawn_armor_props()
{
    if ( !zm_crafting_armor_mode() || !isarray( level.a_s_crafting_tables ) || isdefined( level.zm_ct_armor_props ) )
    {
        return;
    }

    level.zm_ct_armor_props = [];
    level.zm_ct_armor_ready = 1;

    foreach ( table in level.a_s_crafting_tables )
    {
        zm_crafting_table_spawn_prop( table, 1 );
    }
}

function private zm_crafting_table_armor_convert()
{
    self.zm_ct_hooked = 1;
    self interaction::set_interact_use_callback( &zm_crafting_table_armor_use );
    self interaction::set_interact_hint_callback( &zm_crafting_table_armor_hint );
}

function private zm_crafting_table_armor_full()
{
    if ( !( self zm_player_has_armor_carrier() ) )
    {
        return 0;
    }

    t2_max = 100;

    if ( isdefined( level.var_1e9e024bcfca2274 ) && isdefined( level.var_1e9e024bcfca2274.var_ba2fc513d06dd9d5 ) )
    {
        t2_max = level.var_1e9e024bcfca2274.var_ba2fc513d06dd9d5;
    }

    target = max( t2_max, self.maxarmorhealth ?? 0 );

    if ( self zm_juggernog_augment_active( #"juggernog_retaliation" ) )
    {
        target = max( target, level.zm_armor_t3_max ?? 150 );
    }

    return ( self.armorhealth ?? 0 ) >= target;
}

function private zm_crafting_table_armor_hint( usable, player )
{
    if ( !isplayer( player ) || player.interactions_disabled )
    {
        return { #string:&"", #type:"HINT_NOBUTTON" };
    }

    hint_data = { #icon:"ui_icon_zm_ping_armor", #icon_text_value:&"", #icon_text:&"", #description:&"cp_zmb/armor2_desc", #title:&"shared_hintstrings/wallbuy_armor_hint_level_ii", #buttoncallout:&"shared_hintstrings/hint_buy", #params:[ 0, &"" ], #type:"HINT_BUTTON" };

    if ( zm_crafting_survival_mode() )
    {
        cost = zm_crafting_armor_cost();
        hint_data.icon_text_value = cost;
        hint_data.icon_text = &"shared_hintstrings/cost_essence";
        hint_data.params = [ cost, &"" ];
    }

    if ( player zm_crafting_table_armor_full() )
    {
        hint_data.aux_text = &"cp_zmb/armor_full";
        hint_data.interactable = 0;
    }
    else if ( zm_crafting_survival_mode() && !player currency::can_afford( #"essence", zm_crafting_armor_cost() ) )
    {
        hint_data.aux_text = &"shared_hintstrings/not_enough_essence";
        hint_data.icon_text = &"shared_hintstrings/cost_essence_not_enough";
        hint_data.interactable = 0;
    }

    return hint_data;
}

function private zm_crafting_table_armor_use( player )
{
    if ( !isplayer( player ) || !isalive( player ) || istrue( player.inlaststand ) )
    {
        return;
    }

    if ( player zm_crafting_table_armor_full() )
    {
        player playsoundtoplayer( #"ui_zm_core_purchase_deny", player );
        return;
    }

    if ( zm_crafting_survival_mode() && !player currency::attempt_purchase( #"essence", zm_crafting_armor_cost(), 1, 0, #"custom_crafting_armor" ) )
    {
        return;
    }

    player playsoundtoplayer( #"hash_6cd86061dc419bd0", player );
    player on_armor_purchased( { #armor_level:3 } );
}

function private zm_remove_milestone_salvage()
{
    level endon( #"game_ended" );

    while ( !level callback::exists( "on_round_end", &zm_milestones::function_ad7ad35d507f260 ) )
    {
        wait 0.5;
    }

    level callback::remove( "on_round_end", &zm_milestones::function_ad7ad35d507f260 );
}

function private zm_block_direct_salvage_currency()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.currency ) || !isdefined( level.currency[ #"salvage" ] ) )
    {
        waitframe();
    }

    level.currency[ #"salvage" ].addfunc = &zm_salvage_add_gate;
    level.currency[ #"salvage" ].setfunc = &zm_salvage_set_gate;
    level.currency[ #"salvage" ].getfunc = undefined;

    zm_block_salvage_entry( #"rare_salvage" );
}

function private zm_salvage_add_gate( amount )
{
    if ( !isplayer( self ) || !isdefined( amount ) )
    {
        return;
    }

    if ( amount > 0 && !istrue( self.zm_salvage_grant ) )
    {
        return;
    }

    self currency::function_9f4bd7c92079e530( amount, #"salvage" );
}

function private zm_salvage_set_gate( amount )
{
    if ( !isplayer( self ) || !isdefined( amount ) )
    {
        return;
    }

    current = self.currency[ #"salvage" ] ?? 0;

    if ( amount > current && !istrue( self.zm_salvage_grant ) )
    {
        return;
    }

    self currency::function_794c6e82017f38c3( amount, #"salvage" );
}

function private zm_grant_purple_salvage( amount )
{
    self.zm_salvage_grant = 1;
    self currency::add_currency_amount( #"salvage", amount, #"itemuse" );
    self.zm_salvage_grant = undefined;
}

function private zm_is_purple_salvage_item( item )
{
    if ( !isdefined( item ) )
    {
        return false;
    }

    if ( istrue( item.zm_purple_salvage ) )
    {
        return true;
    }

    if ( isent( item ) )
    {
        name = common_item::function_33a2c00e46263d99( item );

        return isdefined( name ) && name == %"itemspawnentry:zm_t10_item_salvage_purple";
    }

    return false;
}

function private zm_purple_salvage_currency_use( itembundle, item, autouse, var_981c264073bf1154 )
{
    if ( zm_is_purple_salvage_item( item ) )
    {
        if ( isdefined( item ) && istrue( item.zm_salvage_claimed ) )
        {
            return false;
        }

        if ( isdefined( item ) )
        {
            item.zm_salvage_claimed = 1;
        }

        foreach ( player in level.players )
        {
            if ( isplayer( player ) )
            {
                player zm_grant_purple_salvage( 500 );
            }
        }

        level thread zm_purple_salvage_despawn( item );

        return false;
    }

    if ( isplayer( self ) && isdefined( itembundle ) && zm_is_essence_currency_bundle( itembundle ) && isarray( level.zm_tedd_essence_pending ) )
    {
        lootid = common_item::function_779887309ec71dfe( itembundle );

        if ( isdefined( lootid ) && ( level.zm_tedd_essence_pending[ lootid ] ?? 0 ) > 0 )
        {
            before = self.currency[ #"essence" ] ?? 0;
            result = self [[ level.zm_currency_use_orig ]]( itembundle, item, autouse, var_981c264073bf1154 );
            gained = ( self.currency[ #"essence" ] ?? 0 ) - before;

            if ( gained > 0 )
            {
                level.zm_tedd_essence_pending[ lootid ]--;
                self currency::add_currency_amount( #"essence", gained * ( zm_tedd_essence_mult() - 1 ), #"itemuse" );
            }

            return result;
        }
    }

    return self [[ level.zm_currency_use_orig ]]( itembundle, item, autouse, var_981c264073bf1154 );
}

function private zm_tedd_essence_mult()
{
    return 3;
}

function private zm_purple_salvage_despawn( item )
{
    waitframe();
    waitframe();

    if ( !isdefined( item ) )
    {
        return;
    }

    item.cleanupdisabled = 0;
    common_item::function_869d7676e359a627( item );
}

function private zm_purple_salvage_pickup_hook()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    while ( !isdefined( level.commonitem.itemcallbacks ) || !isdefined( level.commonitem.itemcallbacks[ "currency" ] ) || !isdefined( level.commonitem.itemcallbacks[ "currency" ].funcs ) || !isdefined( level.commonitem.itemcallbacks[ "currency" ].funcs[ #"use" ] ) )
    {
        wait 0.25;
    }

    level.zm_currency_use_orig = level.commonitem.itemcallbacks[ "currency" ].funcs[ #"use" ];
    common_item::function_84174b793b5fe9a7( "currency", #"use", &zm_purple_salvage_currency_use );
}

function private zm_block_salvage_entry( currency_name )
{
    entry = level.currency[ currency_name ];

    if ( !isdefined( entry ) )
    {
        return;
    }

    entry.addfunc = &zm_salvage_zero_noop;
    entry.setfunc = &zm_salvage_zero_noop;
    entry.getfunc = &zm_salvage_get_zero;
}

function private zm_salvage_zero_noop( amount )
{
    if ( isplayer( self ) && isdefined( self.currency ) )
    {
        self.currency[ #"salvage" ] = 0;
    }
}

function private zm_salvage_get_zero()
{
    return 0;
}

function private zm_fix_maneki_neko_table()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.ww_neko ) || !isdefined( level.ww_neko.mdl_table ) || !isdefined( level.ww_neko.mdl_table.interact ) )
    {
        wait 0.5;
    }

    interact = level.ww_neko.mdl_table.interact;
    interact.zm_crafting_disabled = 1;
    interact interaction::set_interact_use_callback( &zm_maneki_table_use );
    interact interaction::set_interact_hint_callback( &zm_maneki_table_hint );
}

function private zm_maneki_table_hint( usable, player )
{
    if ( !isdefined( player ) || istrue( player.interactions_disabled ) )
    {
        return { #var_26bbd300351fde34:0, #string:&"", #type:"HINT_NOICON" };
    }

    if ( !level utility::flag( "collect_figurine" ) || !level utility::flag( "collect_karakuri" ) || !level utility::flag( "collect_furin" ) )
    {
        return { #var_26bbd300351fde34:0, #string:&"hash_41cd24dad1975b9", #type:"HINT_NOBUTTON" };
    }

    if ( !level utility::flag( "crafted_maneki" ) || level utility::flag( "nya_needs_crafting" ) )
    {
        return { #var_26bbd300351fde34:0, #string:&"hash_6d97d2f577562163", #type:"HINT_BUTTON" };
    }

    if ( player getweaponammostock( makeweapon( "sat_maneki_neko_zm" ) ) > 0 || player getweaponammoclip( makeweapon( "sat_maneki_neko_zm" ) ) > 0 )
    {
        return { #var_26bbd300351fde34:0, #string:&"hash_2c856b65c40a5af", #type:"HINT_NOBUTTON" };
    }

    if ( level utility::flag( "crafted_maneki" ) && level utility::flag( "maneki_acquired" ) )
    {
        cost = 1500;
        obj = { #icon:"sat_ui_icon_zm_support_beckoning_cat", #icon_text_value:cost, #var_776a268784e089af:&"shared_hintstrings/cost_essence", #description:&"hash_4352b716477963dc", #title:&"hash_756d9a67f7897446", #buttoncallout:&"shared_hintstrings/hint_buy", #type:"HINT_BUTTON" };

        if ( level utility::flag( "craft_cooldown" ) )
        {
            obj.description = &"shared_hintstrings/trap_cooldown_hint";
            obj.interactable = 0;
            return obj;
        }

        if ( player currency::can_afford( #"essence", cost ) )
        {
            return obj;
        }

        obj.description = &"shared_hintstrings/not_enough_essence";
        obj.var_776a268784e089af = &"shared_hintstrings/cost_essence_not_enough";
        obj.interactable = 0;
        return obj;
    }

    return { #var_26bbd300351fde34:0, #string:&"", #type:"HINT_NOICON" };
}

function private zm_maneki_table_use( player )
{
    if ( !isdefined( player ) || istrue( player.interactions_disabled ) || level utility::flag( "craft_cooldown" ) || istrue( self.b_interacted ) )
    {
        return;
    }

    if ( !level utility::flag( "collect_figurine" ) || !level utility::flag( "collect_karakuri" ) || !level utility::flag( "collect_furin" ) )
    {
        return;
    }

    if ( level utility::flag( "nya_needs_crafting" ) )
    {
        self.b_interacted = 1;
        params = { #save_progress:0, #saved_use_object:self, #hud_description:&"hash_13f1ab4a9bad547b", #var_b35caf93a1ae502d:self, #hold_time:5, #craft_reason:#"hash_7a4be9bbf8b8856b" };
        result = player zm_quest::function_e4eb2d1c1bd8fc4e( params );

        if ( istrue( result ) )
        {
            level utility::flag_set( "nya_crafted" );
            level utility::flag_clear( "nya_needs_crafting" );
            zm_maneki_craft_complete( player, 1 );
        }

        self.b_interacted = undefined;
        return;
    }

    if ( !level utility::flag( "crafted_maneki" ) )
    {
        self.b_interacted = 1;
        params = { #save_progress:1, #saved_use_object:self, #hud_description:&"hash_6cb466194462537b", #var_b35caf93a1ae502d:self, #hold_time:5, #craft_reason:#"ww_quest_key" };
        result = player zm_quest::function_e4eb2d1c1bd8fc4e( params );

        if ( istrue( result ) )
        {
            level utility::flag_set( "crafted_maneki" );
            zm_maneki_craft_complete( player, 0 );
        }

        self.b_interacted = undefined;
        return;
    }

    if ( level utility::flag( "maneki_acquired" ) )
    {
        cost = 1500;
        neko_weapon = makeweapon( "sat_maneki_neko_zm" );

        if ( player getweaponammostock( neko_weapon ) > 0 || player getweaponammoclip( neko_weapon ) > 0 )
        {
            return;
        }

        if ( player currency::attempt_purchase( #"essence", cost, 1, 0, #"custom_maneki_neko" ) )
        {
            player crafting_table::craft_give_equipment( "equip_attractor", "secondary" );
            level thread zm_maneki_cooldown();

            if ( utility::flag_exist( "completed_ww_step_2" ) && !level utility::flag( "completed_ww_step_2" ) )
            {
                level utility::flag_set( "completed_ww_step_2" );
            }
        }
    }
}

function private zm_maneki_craft_complete( player, b_glow )
{
    zm_spawn_crafted_maneki_item( b_glow );

    if ( isplayer( player ) && isalive( player ) )
    {
        neko_weapon = makeweapon( "sat_maneki_neko_zm" );

        if ( player getweaponammostock( neko_weapon ) <= 0 && player getweaponammoclip( neko_weapon ) <= 0 )
        {
            player crafting_table::craft_give_equipment( "equip_attractor", "secondary" );
        }
    }

    if ( utility::flag_exist( "completed_ww_step_2" ) && !level utility::flag( "completed_ww_step_2" ) )
    {
        level utility::flag_set( "completed_ww_step_2" );
    }

    if ( isplayer( player ) && getdvarint( @"zm_maneki_debug_ct", 1 ) )
    {
        player thread zm_maneki_debug_crafting_table();
    }
}

function private zm_maneki_debug_crafting_table()
{
    self endon( #"disconnect" );

    usable = undefined;

    if ( isarray( level.a_s_crafting_tables ) )
    {
        foreach ( table in level.a_s_crafting_tables )
        {
            usable = zm_crafting_table_interact( table );

            if ( isdefined( usable ) )
            {
                break;
            }
        }
    }

    if ( !isdefined( usable ) )
    {
        return;
    }

    wait 0.5;

    if ( !isalive( self ) )
    {
        return;
    }

    self.crafting_table_disabled = 0;
    usable thread crafting_table::function_4c0d42b2cb94d589( self );
    self thread zm_crafting_table_force_close();
    wait 2;
    self zm_crafting_table_disable_player( undefined );
}

function private zm_spawn_crafted_maneki_item( b_glow )
{
    level utility::flag_set( "maneki_acquired" );

    if ( isdefined( level.zm_maneki_prop ) )
    {
        return;
    }

    s_loc = utility::getstruct( "hornet_ww_crafted_item" );
    origin = undefined;
    angles = ( 0, 0, 0 );

    if ( isdefined( s_loc ) )
    {
        origin = s_loc.origin + ( 0, 0, 5 );
        angles = s_loc.angles ?? ( 0, 0, 0 );
    }
    else if ( isdefined( level.ww_neko ) && isdefined( level.ww_neko.mdl_table ) )
    {
        origin = level.ww_neko.mdl_table.origin + ( 0, 0, 60 );
        angles = level.ww_neko.mdl_table.angles;
    }

    if ( !isdefined( origin ) )
    {
        return;
    }

    zm_crafting_table_fx( origin, "ui_zm_core_door_purchase_success", "vfx_sat_zm_chompy_equipment_cleaned" );
    zm_crafting_table_fx( origin - ( 0, 0, 20 ), undefined, "vfx_sat_levels_zm_firefly_phone_booth_spawn" );

    prop = spawn( "script_model", origin );
    prop.angles = angles;
    prop setmodel( "offhand_sat_wm_zm_beckoning_cat" );
    prop scriptmodelplayanim( "sat_zm_beckoning_cat_wave_01" );
    level.zm_maneki_prop = prop;
}

function private zm_maneki_cooldown()
{
    level utility::flag_set( "craft_cooldown" );
    wait 30;
    level utility::flag_clear( "craft_cooldown" );
}

function private zm_is_locust_bernard_streak( itembundle, item )
{
    if ( isdefined( itembundle ) )
    {
        if ( isdefined( itembundle.ref ) && ( itembundle.ref == "zm_bernard_primary" || itembundle.ref == "zm_bernard_secondary" || itembundle.ref == #"zm_bernard_primary" || itembundle.ref == #"zm_bernard_secondary" ) )
        {
            return true;
        }
        if ( isdefined( itembundle.scriptable ) && ( itembundle.scriptable == %"zmloot_sat_killstreak_zm_bernard_primary" || itembundle.scriptable == %"zmloot_sat_killstreak_zm_bernard_secondary" ) )
        {
            return true;
        }
    }

    if ( isdefined( item ) && isdefined( item.type ) )
    {
        if ( item.type == "zmloot_sat_killstreak_zm_bernard_primary" || item.type == "zmloot_sat_killstreak_zm_bernard_secondary" || item.type == %"zmloot_sat_killstreak_zm_bernard_primary" || item.type == %"zmloot_sat_killstreak_zm_bernard_secondary" )
        {
            return true;
        }
        if ( isstring( item.type ) && issubstr( item.type, "bernard" ) )
        {
            return true;
        }
    }

    return false;
}

function private zm_streak_drops_init()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    mapname = getdvar( @"g_mapname" );

    if ( mapname != "zm_sat_locust" && mapname != "zm_sat_hornet" )
    {
        return;
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    if ( mapname == "zm_sat_locust" )
    {
        level.zm_glocke_picked_up_once = 0;
        level.zm_wb_picked_up_once = 0;

        level callback::add( #"player_item_pickup", &zm_locust_track_bernard_pickup );
        level callback::add( "quest_item_used", &zm_locust_track_bernard_quest_pickup );
        level callback::add( "killstreak_equipped", &zm_locust_track_bernard_equipped );
        level callback::add( "fergus_override_catch_item", &zm_locust_fishing_bernard_boost );
    }

    level callback::add( #"on_ai_killed", &zm_streak_drop_on_ai_killed );
}

function private zm_locust_track_bernard_pickup( params )
{
    if ( !isdefined( params ) || !isdefined( params.itembundle ) )
    {
        return;
    }
    ref = params.itembundle.ref;
    scr = params.itembundle.scriptable;
    if ( ref == "zm_bernard_primary" || ref == #"zm_bernard_primary" || scr == %"zmloot_sat_locust_quest_bernard_primary" )
    {
        level.zm_glocke_picked_up_once = 1;
    }
    if ( ref == "zm_bernard_secondary" || ref == #"zm_bernard_secondary" || scr == %"zmloot_sat_locust_quest_bernard_secondary" )
    {
        level.zm_wb_picked_up_once = 1;
    }
}

function private zm_locust_track_bernard_quest_pickup( params )
{
    if ( !isdefined( params ) || !isdefined( params.bundle ) )
    {
        return;
    }
    scr = params.bundle.scriptable;
    if ( scr == %"zmloot_sat_locust_quest_bernard_primary" )
    {
        level.zm_glocke_picked_up_once = 1;
    }
    if ( scr == %"zmloot_sat_locust_quest_bernard_secondary" )
    {
        level.zm_wb_picked_up_once = 1;
    }
}

function private zm_locust_track_bernard_equipped( params )
{
    if ( !isdefined( params ) || !isdefined( params.streakname ) )
    {
        return;
    }
    if ( params.streakname == "zm_bernard_primary" || params.streakname == #"zm_bernard_primary" )
    {
        level.zm_glocke_picked_up_once = 1;
    }
    if ( params.streakname == "zm_bernard_secondary" || params.streakname == #"zm_bernard_secondary" )
    {
        level.zm_wb_picked_up_once = 1;
    }
}

function private zm_is_glocke_unlocked()
{
    return istrue( level.zm_glocke_picked_up_once ) || ( utility::flag_exist( "pap_step_09" ) && utility::flag( "pap_step_09" ) ) || ( utility::flag_exist( "pap_step_12" ) && utility::flag( "pap_step_12" ) ) || ( isdefined( level.fishing_struct ) && istrue( level.fishing_struct.force_glocke ) );
}

function private zm_is_wb_unlocked()
{
    return istrue( level.zm_wb_picked_up_once ) || ( utility::flag_exist( "mq_rm_step_08" ) && utility::flag( "mq_rm_step_08" ) ) || ( isdefined( level.fishing_struct ) && istrue( level.fishing_struct.force_wb ) );
}

function private zm_get_unlocked_bernard_entries()
{
    entries = [];
    if ( zm_is_glocke_unlocked() )
    {
        entries[ entries.size ] = %"itemspawnentry:zm_sat_item_killstreak_zm_bernard_primary";
    }
    if ( zm_is_wb_unlocked() )
    {
        entries[ entries.size ] = %"itemspawnentry:zm_sat_item_killstreak_zm_bernard_secondary";
    }
    return entries;
}

function private zm_spawn_bernard_streak_at( drop_origin, drop_angles )
{
    entries = zm_get_unlocked_bernard_entries();
    if ( entries.size == 0 )
    {
        return undefined;
    }

    chosen = entries[ randomint( entries.size ) ];
    itembundle = getscriptbundle( chosen );
    if ( !isdefined( itembundle ) )
    {
        return undefined;
    }

    nav_pt = getclosestpointonnavmesh( drop_origin ) ?? drop_origin;
    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( nav_pt, drop_angles ?? ( 0, 0, 0 ) );
    item = common_item::function_61c2c0251e742ffd( itembundle, undefined, spawnoptions );
    if ( isdefined( item ) )
    {
        item.var_e78811eec0c27aa = 1;
    }
    return item;
}

function private zm_streak_drop_tier_chance( ai )
{
    category = ai.aicategory ?? "normal";

    switch ( category )
    {
        case "elite":
            return 35;
        case "special":
            return 13.5;
        case "hvt":
        case "boss":
            return 0;
    }

    return 0.35;
}

function private zm_streak_drop_cap_reached()
{
    round = level.round_number ?? 0;

    if ( ( level.zm_streak_drop_round ?? -1 ) != round )
    {
        level.zm_streak_drop_round = round;
        level.zm_streak_drops_this_round = 0;
    }

    limit = 0;

    foreach ( player in level.players )
    {
        if ( isplayer( player ) )
        {
            limit++;
        }
    }

    if ( limit < 1 )
    {
        limit = 1;
    }

    return ( level.zm_streak_drops_this_round ?? 0 ) >= limit;
}

function private zm_streak_drop_chance( drop, ai )
{
    mapname = getdvar( @"g_mapname" );

    if ( drop == "bernard" || drop == "bernard_fishing" )
    {
        if ( mapname != "zm_sat_locust" || zm_get_unlocked_bernard_entries().size == 0 )
        {
            return 0;
        }

        if ( drop == "bernard_fishing" )
        {
            if ( ( level.round_number ?? 0 ) <= 10 )
            {
                return 0;
            }

            return 20;
        }

        if ( ( level.round_number ?? 0 ) <= 15 || zm_streak_drop_cap_reached() )
        {
            return 0;
        }

        return zm_streak_drop_tier_chance( ai );
    }

    if ( drop == "bow" )
    {
        round = level.round_number ?? 0;

        if ( mapname != "zm_sat_hornet" || round <= 15 || zm_streak_drop_cap_reached() )
        {
            return 0;
        }

        return zm_streak_drop_tier_chance( ai );
    }

    return 0;
}

function private zm_streak_drop_on_ai_killed( params )
{
    if ( !isdefined( self ) || istrue( self.b_in_spawn_closet ) || ( isdefined( self.type ) && self.type != "zombie" ) )
    {
        return;
    }

    drop = "bernard";

    if ( getdvar( @"g_mapname" ) == "zm_sat_hornet" )
    {
        drop = "bow";
    }

    chance = zm_streak_drop_chance( drop, self );

    if ( chance <= 0 || !utility::percent_chance( chance ) )
    {
        return;
    }

    if ( drop == "bow" )
    {
        item = zm_spawn_bow_streak_at( self.origin, self.angles );

        if ( isdefined( item ) )
        {
            level.zm_streak_drops_this_round = ( level.zm_streak_drops_this_round ?? 0 ) + 1;
        }

        return;
    }

    item = zm_spawn_bernard_streak_at( self.origin, self.angles );

    if ( isdefined( item ) )
    {
        level.zm_streak_drops_this_round = ( level.zm_streak_drops_this_round ?? 0 ) + 1;
    }
}

function private zm_locust_fishing_bernard_boost( params )
{
    if ( !isdefined( params ) )
    {
        return 0;
    }

    chance = zm_streak_drop_chance( "bernard_fishing", undefined );

    if ( chance <= 0 || !utility::percent_chance( chance ) )
    {
        return 0;
    }

    entries = zm_get_unlocked_bernard_entries();

    if ( entries.size == 0 )
    {
        return 0;
    }

    chosen = entries[ randomint( entries.size ) ];
    itembundle = getscriptbundle( chosen );
    if ( !isdefined( itembundle ) )
    {
        return 0;
    }

    end_origin = params.var_333e3dd12305988e ?? self.origin;
    item = common_item::function_61c2c0251e742ffd( itembundle, undefined, common_item::function_f5dfaa3bbdf99a33( end_origin, params.from_origin ?? end_origin, params.angles ?? ( 0, 0, 0 ) ) );
    if ( isdefined( item ) )
    {
        item.var_e78811eec0c27aa = 1;
        return 1;
    }
    return 0;
}

function private zm_spawn_bow_streak_at( drop_origin, drop_angles )
{
    itembundle = getscriptbundle( %"itemspawnentry:zm_sat_item_killstreak_combat_bow" );

    if ( !isdefined( itembundle ) )
    {
        return undefined;
    }

    nav_pt = getclosestpointonnavmesh( drop_origin ) ?? drop_origin;
    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( nav_pt, drop_angles ?? ( 0, 0, 0 ) );
    item = common_item::function_61c2c0251e742ffd( itembundle, undefined, spawnoptions );

    if ( isdefined( item ) )
    {
        item.var_e78811eec0c27aa = 1;
    }

    return item;
}

function private zm_disable_zombie_drops_start()
{
    level endon( #"game_ended" );
    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    common_item::function_f77c7eedea4fc99f( %"itemspawnentry:zm_t10_item_salvage_green", %"none" );
    common_item::function_f77c7eedea4fc99f( %"itemspawnentry:zm_t10_item_trials_salvage_green_500", %"none" );
    common_item::function_f77c7eedea4fc99f( %"hash_6fcc2003910121a8", %"none" );
    common_item::function_f77c7eedea4fc99f( %"hash_76b88ec469fed206", %"none" );
    common_item::function_f77c7eedea4fc99f( %"itemspawnentry:zm_t10_item_aether_tool", %"none" );
    common_item::function_f77c7eedea4fc99f( %"itemspawnentry:zm_t10_item_aether_tool_2", %"none" );
    common_item::function_f77c7eedea4fc99f( %"itemspawnentry:zm_t10_item_aether_tool_3", %"none" );
    common_item::function_f77c7eedea4fc99f( %"itemspawnentry:zm_t10_item_aether_tool_4", %"none" );

    common_item::function_5734400f32ca9803( "salvage", &zm_on_salvage_item_spawned );
    common_item::function_e08da1075e1758ef( "killstreak", &zm_on_killstreak_item_spawned );
    level callback::add( #"hash_8e2728470d1fa87a", &zm_can_spawn_filtered_loot );

    level thread zm_keep_ai_loot_hook();

    wait 1;
    powerups::register_powerup( "free_perk", &zm_streak_powerup_grab, &zm_streak_powerup_should_drop );

    root = powerups::get_powerups_root();
    if ( isdefined( root ) && isarray( root.powerup_drop_array ) )
    {
        in_pool = 0;
        foreach ( entry in root.powerup_drop_array )
        {
            if ( entry == "free_perk" )
            {
                in_pool = 1;
            }
        }
        if ( !in_pool )
        {
            root.powerup_drop_array[ root.powerup_drop_array.size ] = "free_perk";
        }
    }
}

function private zm_keep_ai_loot_hook()
{
    level endon( #"game_ended" );
    while ( true )
    {
        if ( !isdefined( level.var_5681a2a9991ea212 ) || level.var_5681a2a9991ea212 != &zm_on_ai_loot_dropped )
        {
            if ( isdefined( level.var_5681a2a9991ea212 ) )
            {
                level.zm_orig_ai_loot_dropped = level.var_5681a2a9991ea212;
            }
            level.var_5681a2a9991ea212 = &zm_on_ai_loot_dropped;
        }
        wait 0.5;
    }
}

function private zm_film_reel_active()
{
    return isdefined( level.active_relic_challenge ) && isdefined( level.active_relic_challenge.relic_hash ) && level.active_relic_challenge.relic_hash == %"hash_6450e64abe7e170f";
}

function private zm_film_reel_drops_init()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    level callback::add( #"on_ai_killed", &zm_film_reel_on_ai_killed );
}

function private zm_film_reel_on_ai_killed( params )
{
    if ( !zm_film_reel_active() )
    {
        return;
    }

    if ( !isdefined( self ) || istrue( self.b_in_spawn_closet ) || ( isdefined( self.type ) && self.type != "zombie" ) )
    {
        return;
    }

    if ( !utility::percent_chance( 12 ) )
    {
        return;
    }

    streaks = [];

    foreach ( player in level.players )
    {
        if ( !isplayer( player ) || !isalive( player ) || !isdefined( player.streakdata ) )
        {
            continue;
        }

        held = player item_killstreak::get_current_killstreak();

        if ( isdefined( held ) && isdefined( held.ref ) && !arraycontains( streaks, held.ref ) )
        {
            streaks[ streaks.size ] = held.ref;
        }
    }

    if ( streaks.size == 0 )
    {
        return;
    }

    nav_pt = getclosestpointonnavmesh( self.origin ) ?? self.origin;
    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( nav_pt, self.angles ?? ( 0, 0, 0 ) );
    item = common_item::function_325e28c0fb65c36a( streaks[ randomint( streaks.size ) ], 1, spawnoptions );

    if ( isdefined( item ) )
    {
        item.var_e78811eec0c27aa = 1;
    }
}

function private zm_is_salvage_bundle( itembundle )
{
    return isdefined( itembundle ) && isdefined( itembundle.subtype ) && ( itembundle.subtype == "salvage" || itembundle.subtype == #"salvage" || isstring( itembundle.subtype ) && issubstr( itembundle.subtype, "salvage" ) );
}

function private zm_bundle_name_has( itembundle, needle )
{
    if ( isdefined( itembundle.ref ) && isstring( itembundle.ref ) && issubstr( tolower( itembundle.ref ), needle ) )
    {
        return true;
    }

    if ( isdefined( itembundle.scriptable ) && isstring( itembundle.scriptable ) && issubstr( tolower( itembundle.scriptable ), needle ) )
    {
        return true;
    }

    return false;
}

function private zm_is_aether_tool_bundle( itembundle )
{
    if ( zm_bundle_name_has( itembundle, "aether_tool" ) )
    {
        return true;
    }

    names = [ %"itemspawnentry:zm_t10_item_aether_tool", %"itemspawnentry:zm_t10_item_aether_tool_2", %"itemspawnentry:zm_t10_item_aether_tool_3", %"itemspawnentry:zm_t10_item_aether_tool_4" ];

    foreach ( name in names )
    {
        tool_bundle = getscriptbundle( name );

        if ( isdefined( tool_bundle ) && isdefined( tool_bundle.ref ) && isdefined( itembundle.ref ) && tool_bundle.ref == itembundle.ref )
        {
            return true;
        }
    }

    return false;
}

function private zm_is_bomb_tactical_bundle( itembundle )
{
    return zm_bundle_name_has( itembundle, "monkey_bomb" ) || zm_bundle_name_has( itembundle, "blackhole_bomb" ) || zm_bundle_name_has( itembundle, "black_hole_bomb" );
}

function private zm_is_mystery_perk_bundle( itembundle )
{
    return isdefined( itembundle ) && ( zm_bundle_name_has( itembundle, "mystery" ) || zm_bundle_name_has( itembundle, "perk" ) );
}

function private zm_is_tedd_chest()
{
    return isdefined( self ) && isdefined( self.caches ) && isdefined( self.var_8572c15d1a1510fb );
}

function private zm_can_spawn_filtered_loot( params )
{
    if ( isdefined( params ) && isdefined( params.itembundle ) && self zm_is_tedd_chest() )
    {
        if ( zm_is_aether_tool_bundle( params.itembundle ) )
        {
            return false;
        }

        if ( zm_is_bomb_tactical_bundle( params.itembundle ) && randomint( 2 ) == 0 )
        {
            return false;
        }

        if ( zm_is_mystery_perk_bundle( params.itembundle ) && randomint( 2 ) == 0 )
        {
            return false;
        }
    }

    if ( istrue( level.zm_tedd_loot_window ) && isdefined( params ) && isdefined( params.itembundle ) )
    {
        if ( zm_is_essence_currency_bundle( params.itembundle ) )
        {
            lootid = common_item::function_779887309ec71dfe( params.itembundle );

            if ( isdefined( lootid ) )
            {
                if ( !isarray( level.zm_tedd_essence_lootids ) )
                {
                    level.zm_tedd_essence_lootids = [];
                }

                level.zm_tedd_essence_lootids[ lootid ] = 1;
            }
        }

        if ( zm_is_self_revive_drop( undefined, params.itembundle ) || zm_bundle_name_has( params.itembundle, "selfrevive" ) )
        {
            return false;
        }

        if ( zm_is_mystery_perk_bundle( params.itembundle ) && randomint( 2 ) == 0 )
        {
            return false;
        }

        if ( istrue( level.zm_tedd_is_mantis ) && zm_is_dawg_streak_bundle( params.itembundle ) )
        {
            return true;
        }
    }

    if ( isdefined( params ) && isdefined( params.itembundle ) )
    {
        if ( zm_is_locust_bernard_streak( params.itembundle, undefined ) )
        {
            return true;
        }
        item_type = common_item::function_16e8c106491eeaca( params.itembundle );
        if ( item_type == "killstreak" && zm_film_reel_active() )
        {
            return true;
        }
        if ( item_type == "killstreak" || zm_is_salvage_bundle( params.itembundle ) )
        {
            return false;
        }
    }
    return true;
}

function private zm_on_salvage_item_spawned( params )
{
    waittillframeend();
    if ( isdefined( params ) && isdefined( params.item ) )
    {
        if ( istrue( params.item.var_e78811eec0c27aa ) || istrue( level.zm_allow_salvage_spawn ) )
        {
            return;
        }
        common_item::function_869d7676e359a627( params.item );
    }
}

function private zm_on_killstreak_item_spawned( params )
{
    waittillframeend();
    if ( isdefined( params ) && isdefined( params.item ) )
    {
        if ( istrue( params.item.var_e78811eec0c27aa ) || zm_film_reel_active() || zm_is_locust_bernard_streak( params.itembundle, params.item ) || ( isdefined( params.spawnoptions ) && isdefined( params.spawnoptions.spawningentity ) && isplayer( params.spawnoptions.spawningentity ) ) )
        {
            return;
        }
        common_item::function_869d7676e359a627( params.item );
    }
}

function private zm_is_self_revive_drop( item, itembundle )
{
    if ( isdefined( item ) && isdefined( item.type ) && isstring( item.type ) && issubstr( item.type, "self_revive" ) )
    {
        return true;
    }

    if ( isdefined( itembundle ) && isstring( itembundle.ref ) && issubstr( itembundle.ref, "self_revive" ) )
    {
        return true;
    }

    return false;
}

function private zm_on_ai_loot_dropped( spawned_items )
{
    if ( isdefined( level.zm_orig_ai_loot_dropped ) )
    {
        self [[ level.zm_orig_ai_loot_dropped ]]( spawned_items );
    }

    if ( !isarray( spawned_items ) )
    {
        return;
    }

    foreach ( item in spawned_items )
    {
        if ( !isdefined( item ) )
        {
            continue;
        }
        itembundle = common_item::function_6b8ff3d5f2688336( item );
        if ( zm_is_self_revive_drop( item, itembundle ) )
        {
            common_item::function_869d7676e359a627( item );
            continue;
        }
        if ( zm_is_locust_bernard_streak( itembundle, item ) )
        {
            continue;
        }
        if ( isdefined( itembundle ) )
        {
            item_type = common_item::function_16e8c106491eeaca( itembundle );
            if ( item_type == "killstreak" && zm_film_reel_active() )
            {
                continue;
            }
            if ( item_type == "killstreak" || item_type == "lethal" || item_type == "tactical" || zm_is_salvage_bundle( itembundle ) )
            {
                common_item::function_869d7676e359a627( item );
                continue;
            }
        }
        if ( isdefined( item.type ) && isstring( item.type ) && ( item.type == "zmloot_salvage_perplayer" || issubstr( item.type, "salvage" ) || issubstr( item.type, "aether_tool" ) || issubstr( item.type, "offhand" ) || issubstr( item.type, "lethal" ) || issubstr( item.type, "tactical" ) ) )
        {
            common_item::function_869d7676e359a627( item );
        }
    }
}

function private zm_streak_powerup_should_drop()
{
    return randomint( 4 ) == 0;
}

function private zm_streak_powerup_grab( str_powerup, ent_powerup )
{
    players = powerups::get_powerup_players( str_powerup );
    if ( !isarray( players ) || players.size == 0 )
    {
        players = level.players;
    }

    foreach ( player in players )
    {
        if ( isdefined( player ) && !player isspectatinganyone() )
        {
            player thread zm_give_powerup_streak();
        }
    }
}

function private zm_give_powerup_streak()
{
    self endon( #"disconnect" );

    if ( !isalive( self ) || player::isinlaststand( self ) || isdefined( self.triggeringstreak ) )
    {
        return;
    }

    if ( !isdefined( self.zm_powerup_streak_index ) )
    {
        self.zm_powerup_streak_index = 0;
    }
    else
    {
        self.zm_powerup_streak_index = 1 - self.zm_powerup_streak_index;
    }

    if ( self.zm_powerup_streak_index == 0 )
    {
        streakname = "death_machine_gun";

        if ( !isdefined( level.killstreaksetups ) || !isdefined( level.killstreaksetups[ streakname ] ) )
        {
            killstreak_shared::initializekillstreak( #"death_machine_gun" );
        }
    }
    else
    {
        streakname = "war_machine_launcher";

        if ( !isdefined( level.killstreaksetups ) || !isdefined( level.killstreaksetups[ streakname ] ) )
        {
            killstreak_shared::initializekillstreak( #"war_machine_launcher" );
        }
    }

    self thread killstreaks::forceactivatekillstreak( streakname );
}

function private zm_rarity_wallbuy_chalk()
{
    level endon( #"game_ended" );

    utility::flag_wait( "wallbuy_ready" );

    while ( true )
    {
        if ( isdefined( level.contentmanager ) && isdefined( level.contentmanager.spawnedinstances ) && isarray( level.contentmanager.spawnedinstances[ "wallbuy" ] ) )
        {
            foreach ( instance in level.contentmanager.spawnedinstances[ "wallbuy" ] )
            {
                if ( !isdefined( instance ) || !isdefined( instance.var_1d6cddfc47031bff ) || !isarray( instance.var_1d6cddfc47031bff[ "wallbuy_spawn" ] ) )
                {
                    continue;
                }

                foreach ( spawn_point in instance.var_1d6cddfc47031bff[ "wallbuy_spawn" ] )
                {
                    if ( isdefined( spawn_point ) && isdefined( spawn_point.wallbuy_scriptable ) )
                    {
                        spawn_point.wallbuy_scriptable zm_wallbuy_force_chalk();
                    }
                }
            }
        }

        if ( isarray( level.var_38f42d124c1fc599 ) )
        {
            foreach ( spawn_point in level.var_38f42d124c1fc599 )
            {
                if ( isdefined( spawn_point ) && isdefined( spawn_point.wallbuy_scriptable ) )
                {
                    spawn_point.wallbuy_scriptable zm_wallbuy_force_chalk();
                }
            }
        }

        wait 0.25;
    }
}

function private zm_wallbuy_hint( usable, player )
{
    if ( isdefined( usable ) )
    {
        usable zm_wallbuy_force_green();
    }

    if ( isdefined( usable ) && ( !isdefined( usable.cost ) || usable.cost <= 0 ) )
    {
        cost = wallbuy::get_wallbuy_cost( usable.weapon_root_name, usable.rarity ?? "green" );

        if ( isdefined( cost ) && cost > 0 )
        {
            usable.cost = cost;
        }
        else
        {
            usable.cost = 1000;
        }
    }

    obj = wallbuy::setup_wallbuy_hintstring( usable, player );

    if ( !isdefined( obj ) )
    {
        return { #string:&"", #type:"HINT_NOBUTTON" };
    }

    if ( isdefined( obj.loot_id ) )
    {
        obj.description = &"";
    }

    return obj;
}

function private zm_box_weapon_hint( usable, player )
{
    obj = magicbox::function_cda75531450aac03( usable, player );

    if ( !isdefined( obj ) )
    {
        return obj;
    }

    neutral = magicbox::get_rarity_hint_string( "none" );

    if ( isdefined( obj.string ) && obj.description == obj.string )
    {
        obj.description = neutral;
    }

    obj.string = neutral;
    return obj;
}

function private zm_wallbuy_capped_rarity( rarity )
{
    if ( rarity === "blue" || rarity === "purple" || rarity === "orange" )
    {
        return "green";
    }

    return rarity;
}

function private zm_wallbuy_rarity_hook( rarity )
{
    result = rarity;

    if ( isfunction( level.zm_wallbuy_rarity_orig ) )
    {
        override = [[ level.zm_wallbuy_rarity_orig ]]( rarity );

        if ( isdefined( override ) )
        {
            result = override;
        }
    }

    return zm_wallbuy_capped_rarity( result );
}

function private zm_wallbuy_rarity_cap_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    for ( i = 0; i < 100 && !utility::issharedfuncdefined( #"zombie", #"hash_e29bc9f93cc9ba4" ); i++ )
    {
        waitframe();
    }

    if ( isdefined( level.zm_wallbuy_rarity_wrapped ) )
    {
        return;
    }

    level.zm_wallbuy_rarity_wrapped = 1;

    if ( utility::issharedfuncdefined( #"zombie", #"hash_e29bc9f93cc9ba4" ) )
    {
        level.zm_wallbuy_rarity_orig = level.sharedfuncs[ #"zombie" ][ #"hash_e29bc9f93cc9ba4" ];
    }

    utility::registersharedfunc( #"zombie", #"hash_e29bc9f93cc9ba4", &zm_wallbuy_rarity_hook );
}

function private zm_box_aether_rarity_hook( n_roll, n_total, n_legendary, n_epic, n_rare, n_uncommon )
{
    result = undefined;

    if ( isfunction( level.zm_box_aether_orig ) )
    {
        result = [[ level.zm_box_aether_orig ]]( n_roll, n_total, n_legendary, n_epic, n_rare, n_uncommon );
    }

    return zm_wallbuy_capped_rarity( result );
}

function private zm_box_rarity_cap_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( true )
    {
        if ( utility::issharedfuncdefined( #"relics", #"hash_459bf078b969217d" ) )
        {
            current = level.sharedfuncs[ #"relics" ][ #"hash_459bf078b969217d" ];

            if ( current != &zm_box_aether_rarity_hook )
            {
                level.zm_box_aether_orig = current;
                level.sharedfuncs[ #"relics" ][ #"hash_459bf078b969217d" ] = &zm_box_aether_rarity_hook;
            }
        }

        wait 0.5;
    }
}

function private zm_wallbuy_is_weapon_wallbuy()
{
    return isdefined( self.weapon_root_name ) && isdefined( self.itementry ) && !isdefined( self.variant_type );
}

function private zm_wallbuy_is_wonder()
{
    foreach ( key in [ self.weapon_root_name, self.weapon_name ] )
    {
        if ( !isdefined( key ) )
        {
            continue;
        }

        meta = level.weaponmetadata[ getxhashasset( key ) ];

        if ( isdefined( meta ) && istrue( meta.ismapwonderweapon ) )
        {
            return true;
        }
    }

    return false;
}

function private zm_wallbuy_force_green()
{
    if ( !self zm_wallbuy_is_weapon_wallbuy() || self zm_wallbuy_is_wonder() )
    {
        self.rarity = zm_wallbuy_capped_rarity( self.rarity );
        return;
    }

    if ( self.rarity === "green" )
    {
        return;
    }

    self.rarity = "green";

    cost = wallbuy::get_wallbuy_cost( self.weapon_root_name, "green" );

    if ( isdefined( cost ) && cost > 0 )
    {
        self.cost = cost;
    }
}

function private zm_wallbuy_use( player )
{
    self zm_wallbuy_force_green();
    self wallbuy::function_c8c8a561d596b8f( player );
}

function private zm_box_rarity_override_green( player, str_notify )
{
    if ( !isarray( level.zm_box_rarity_override_orig ) )
    {
        return undefined;
    }

    return undefined;
}

function private zm_box_rarity_strict_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    level.zm_box_rarity_override_orig = [];

    while ( true )
    {
        if ( isdefined( level.s_magicbox_scaling ) )
        {
            foreach ( scale_list in [ level.s_magicbox_scaling.var_e706c54ff9d8cadc, level.s_magicbox_scaling.magicboxroundscale ] )
            {
                if ( !isarray( scale_list ) )
                {
                    continue;
                }

                foreach ( sc in scale_list )
                {
                    if ( !isdefined( sc ) )
                    {
                        continue;
                    }

                    sc.commonchance = 0;
                    sc.uncommonchance = 100;
                    sc.rarechance = 0;
                    sc.epicchance = 0;
                    sc.legendarychance = 0;
                    sc.legacyweaponchance = 0;
                    sc.ultrachance = 0;
                }
            }
        }

        if ( isarray( level.a_magicbox_rarity_override ) )
        {
            foreach ( func in level.a_magicbox_rarity_override )
            {
                if ( func != &zm_box_rarity_override_green )
                {
                    level.zm_box_rarity_override_orig[ level.zm_box_rarity_override_orig.size ] = func;
                }
            }

            if ( level.a_magicbox_rarity_override.size != 1 || level.a_magicbox_rarity_override[ 0 ] != &zm_box_rarity_override_green )
            {
                level.a_magicbox_rarity_override = [ &zm_box_rarity_override_green ];
            }
        }

        waitframe();
    }
}

function private zm_wallbuy_force_chalk()
{
    if ( !( isdefined( self.variant_type ) && self.variant_type == "armor" ) )
    {
        self.disable_upgrade = 1;
    }

    self zm_wallbuy_force_green();

    if ( self zm_wallbuy_is_weapon_wallbuy() )
    {
        self.disable_upgrade = 1;

        if ( !isarray( self.var_d8e3b07237845727 ) || self.var_d8e3b07237845727.size != 1 || self.var_d8e3b07237845727[ 0 ] != &zm_wallbuy_use )
        {
            self interaction::set_interact_use_callback( &zm_wallbuy_use );
        }

        if ( self.interact_hint_callback != &zm_wallbuy_hint )
        {
            self interaction::set_interact_hint_callback( &zm_wallbuy_hint );
        }
    }

    if ( isdefined( self.variant_type ) && self.variant_type == "armor" )
    {
        return;
    }

    if ( istrue( self.zm_chalk_state ) && ( self.rarity === "white" || self.rarity === "base" ) )
    {
        return;
    }

    if ( !( self zm_wallbuy_is_weapon_wallbuy() ) )
    {
        return;
    }

    if ( self getscriptablepartstate( "wallbuy" ) != "base" )
    {
        self setscriptablepartstate( "wallbuy", "base" );
    }

    self.zm_chalk_state = ( self.rarity === "white" || self.rarity === "base" );
}

function private zm_rarity_cap_box_and_wallbuys()
{
    level endon( #"game_ended" );

    tick = 0;

    while ( true )
    {
        tick++;

        if ( isdefined( level.s_magicbox_scaling ) )
        {
            foreach ( scale_list in [ level.s_magicbox_scaling.var_e706c54ff9d8cadc, level.s_magicbox_scaling.magicboxroundscale ] )
            {
                if ( !isarray( scale_list ) )
                {
                    continue;
                }

                foreach ( sc in scale_list )
                {
                    if ( !isdefined( sc ) )
                    {
                        continue;
                    }

                    sc.commonchance = 0;
                    sc.uncommonchance = 100;
                    sc.rarechance = 0;
                    sc.epicchance = 0;
                    sc.legendarychance = 0;
                    sc.ultrachance = 0;
                }
            }
        }

        foreach ( box_list in [ level.var_1bbb5557537e2c0c, level.a_s_magicboxes ] )
        {
            if ( !isarray( box_list ) )
            {
                continue;
            }

            foreach ( box in box_list )
            {
                if ( !isdefined( box ) || !isdefined( box.mdl_current_weapon ) )
                {
                    continue;
                }

                holder = box.mdl_current_weapon;

                if ( isdefined( holder.n_outline_id ) )
                {
                    outline::outlinedisable( holder.n_outline_id, holder );
                    holder.n_outline_id = undefined;
                    holder.zm_white_outline_id = undefined;
                }

                if ( isdefined( holder.interact ) && isfunction( holder.interact.interact_hint_callback ) && holder.interact.interact_hint_callback != &zm_box_weapon_hint )
                {
                    holder.interact interaction::set_interact_hint_callback( &zm_box_weapon_hint );
                }

                if ( isdefined( holder.str_weapon_rarity ) && ( holder.str_weapon_rarity == "ultra" || holder.str_weapon_rarity == #"ultra" ) )
                {
                    continue;
                }

                if ( isdefined( holder.str_weapon_rarity ) && ( holder.str_weapon_rarity == "rare" || holder.str_weapon_rarity == "epic" || holder.str_weapon_rarity == "legendary" || holder.str_weapon_rarity == "blue" || holder.str_weapon_rarity == "purple" || holder.str_weapon_rarity == "orange" ) )
                {
                    holder.str_weapon_rarity = "uncommon";
                }

                if ( isdefined( holder.n_rarity ) && isnumber( holder.n_rarity ) && holder.n_rarity > 1 && holder.n_rarity < 5 )
                {
                    holder.n_rarity = 1;
                }
                if ( isdefined( holder.rarity ) && isnumber( holder.rarity ) && holder.rarity > 1 && holder.rarity < 5 )
                {
                    holder.rarity = 1;
                }
            }
        }

        if ( tick % 5 == 0 && isdefined( level.contentmanager ) && isdefined( level.contentmanager.spawnedinstances ) && isdefined( level.contentmanager.spawnedinstances[ "wallbuy" ] ) )
        {
            foreach ( instance in level.contentmanager.spawnedinstances[ "wallbuy" ] )
            {
                if ( !isdefined( instance ) )
                {
                    continue;
                }

                if ( isdefined( instance.n_rarity ) && isnumber( instance.n_rarity ) && instance.n_rarity > 1 )
                {
                    instance.n_rarity = 1;
                }
                if ( isdefined( instance.rarity ) && isnumber( instance.rarity ) && instance.rarity > 1 )
                {
                    instance.rarity = 1;
                }
                if ( isdefined( instance.str_rarity ) && ( instance.str_rarity == "rare" || instance.str_rarity == "epic" || instance.str_rarity == "legendary" || instance.str_rarity == "blue" || instance.str_rarity == "purple" || instance.str_rarity == "orange" ) )
                {
                    instance.str_rarity = "green";
                }

                if ( isdefined( instance.var_1d6cddfc47031bff ) && isdefined( instance.var_1d6cddfc47031bff[ "wallbuy_spawn" ] ) )
                {
                    foreach ( wb in instance.var_1d6cddfc47031bff[ "wallbuy_spawn" ] )
                    {
                        if ( !isdefined( wb ) )
                        {
                            continue;
                        }
                        if ( isdefined( wb.n_rarity ) && isnumber( wb.n_rarity ) && wb.n_rarity > 1 )
                        {
                            wb.n_rarity = 1;
                        }
                        if ( isdefined( wb.rarity ) && isnumber( wb.rarity ) && wb.rarity > 1 )
                        {
                            wb.rarity = 1;
                        }
                        if ( isdefined( wb.str_rarity ) && ( wb.str_rarity == "rare" || wb.str_rarity == "epic" || wb.str_rarity == "legendary" || wb.str_rarity == "blue" || wb.str_rarity == "purple" || wb.str_rarity == "orange" ) )
                        {
                            wb.str_rarity = "green";
                        }
                    }
                }
            }
        }

        wait 0.1;
    }
}

function private zm_tu_box_init()
{
    level.zm_tu_box = 1;

    level callback::add( #"player_spawned", &zm_tu_box_on_player_spawned );
}

function private zm_tu_box_on_player_spawned( params )
{
    if ( !isdefined( level.zm_mode_modifiers ) )
    {
        return;
    }

    if ( !istrue( level.zm_tu_box_hooked ) && istrue( level.zm_tu_box ) )
    {
        level.zm_tu_box_hooked = 1;
        magicbox::function_1b154b89e87377fa( &zm_tu_box_roll );
        level thread zm_tu_unlock_and_equalize_wonder_weapons();
    }
}

function private zm_tu_get_map_wonder_weapon_entries()
{
    if ( isdefined( level.zm_unlocked_ww_entries ) && isarray( level.zm_unlocked_ww_entries ) && level.zm_unlocked_ww_entries.size > 0 )
    {
        return level.zm_unlocked_ww_entries;
    }

    ww_list = [];

    if ( isdefined( level.var_8b6bf63f61fe01f9 ) )
    {
        ww_bundle = getscriptbundle( level.var_8b6bf63f61fe01f9 );
        if ( isdefined( ww_bundle ) && isarray( ww_bundle.itementries ) )
        {
            foreach ( entry in ww_bundle.itementries )
            {
                if ( !isdefined( entry ) )
                {
                    continue;
                }

                entry.weight = 100;
                entry.var_482f1b4c8f2b12a1 = undefined;
                entry.b_quest_locked = 0;

                if ( isdefined( entry.item ) )
                {
                    ww_list[ ww_list.size ] = entry.item;
                }
                else if ( isdefined( entry.weapon ) )
                {
                    ww_list[ ww_list.size ] = entry.weapon;
                }
                else if ( isdefined( entry.ref ) )
                {
                    ww_list[ ww_list.size ] = entry.ref;
                }
            }
        }
    }

    if ( ww_list.size > 0 )
    {
        level.zm_unlocked_ww_entries = ww_list;
    }

    return ww_list;
}

function private zm_tu_unlock_and_equalize_wonder_weapons()
{
    level endon( #"game_ended" );

    while ( true )
    {
        zm_tu_get_map_wonder_weapon_entries();

        if ( isdefined( level.var_7894218a96200b31 ) && isarray( level.var_7894218a96200b31 ) )
        {
            foreach ( entry in level.var_7894218a96200b31 )
            {
                if ( isdefined( entry ) && isdefined( entry.rarity ) && ( entry.rarity == "ultra" || entry.rarity == #"ultra" || entry.rarity == 5 ) )
                {
                    entry.weight = 100;
                }
            }
        }

        wait 1.0;
    }
}

function private zm_unlock_map_wonder_weapons()
{
    level endon( #"game_ended" );

    while ( true )
    {
        level.var_20cf5eda0c956d52 = 0;
        wait 0.05;
    }
}

function private zm_tu_general_ww_list()
{
    mapname = tolower( getdvar( @"g_mapname" ) );

    if ( issubstr( mapname, "ruby" ) )
    {
        return %"hash_65f5dd4fd50f2587";
    }

    if ( issubstr( mapname, "mantis" ) )
    {
        return %"hash_5182a6ef5f3381bb";
    }

    if ( issubstr( mapname, "firefly" ) )
    {
        return %"hash_465c77a80595560";
    }

    if ( issubstr( mapname, "scarab" ) )
    {
        return %"hash_15d46b30662a6999";
    }

    if ( issubstr( mapname, "hornet" ) )
    {
        return %"hash_267dd636e87ba103";
    }

    if ( issubstr( mapname, "locust" ) )
    {
        return %"hash_67b3cb83aa6ed809";
    }

    return level.var_8b6bf63f61fe01f9;
}

function private zm_tu_unlock_ww_list( list )
{
    bundle = getscriptbundle( list );

    if ( !isdefined( bundle ) || !isarray( bundle.itementries ) )
    {
        return 0;
    }

    usable = 0;

    foreach ( entry in bundle.itementries )
    {
        if ( !isdefined( entry ) )
        {
            continue;
        }

        entry.var_482f1b4c8f2b12a1 = undefined;
        entry.b_quest_locked = 0;
        entry.weight = 100;

        if ( isdefined( entry.item ) || isdefined( entry.weapon ) || isdefined( entry.ref ) )
        {
            usable++;
        }
    }

    return usable;
}

function private zm_tu_map_box_active()
{
    mapname = tolower( getdvar( @"g_mapname" ) );

    if ( !issubstr( mapname, "firefly" ) && !issubstr( mapname, "ruby" ) )
    {
        return false;
    }

    mode = getdvar( @"zm_box_weapons", "" );

    return mode == "0" || mode == "1" || mode == "2";
}

function private zm_tu_box_roll( player, str_override_rarity, var_4b076b5c2a1741db )
{
    if ( zm_tu_map_box_active() )
    {
        return undefined;
    }

    if ( randomfloat( 100 ) >= 1 )
    {
        return undefined;
    }

    list = zm_tu_general_ww_list();

    if ( !isdefined( list ) )
    {
        return undefined;
    }
    if ( zm_tu_unlock_ww_list( list ) < 1 )
    {
        return undefined;
    }

    return list;
}

function private zm_ww_semtex_init()
{
    level endon( #"game_ended" );

    mode = undefined;
    while ( !isdefined( mode ) )
    {
        mode = level.gametype;

        if ( !isdefined( mode ) && isdefined( level.gametypebundle ) )
        {
            mode = game_utility::getgametype();
        }

        if ( !isdefined( mode ) )
        {
            wait 0.05;
        }
    }

    if ( mode != "zm_rb_r_mod" && mode != "zm_rb_r_mod_survival" && !isstartstr( mode, "zm_rb_rh_mod" ) )
    {
        return;
    }

    level callback::add( #"player_spawned", &zm_ww_semtex_on_player_spawned );

    foreach ( player in level.players )
    {
        if ( isdefined( player ) && isalive( player ) )
        {
            player thread zm_ww_semtex_watch();
        }
    }
}

function private zm_ww_semtex_on_player_spawned( params )
{
    self thread zm_ww_semtex_watch();
}

function private zm_ww_semtex_watch()
{
    self notify( #"zm_ww_semtex_restart" );
    self endon( #"zm_ww_semtex_restart" );
    self endon( #"disconnect" );
    self endon( #"death" );
    level endon( #"game_ended" );

    had_perk = undefined;

    while ( true )
    {
        wait 0.25;

        has_perk = self zombie_perks::has_perk( "specialty_y_mod" );
        current = equipment_mp::getcurrentequipment( "primary" );
        current_ref = "";

        if ( isdefined( current ) )
        {
            current_ref = "" + current;
        }

        if ( has_perk )
        {
            if ( isdefined( had_perk ) && !had_perk )
            {
                self zm_ww_grant_lethal( "equip_semtex", 4 );
            }
            else if ( current_ref == "equip_frag" )
            {
                self zm_ww_swap_lethal( "equip_semtex" );
            }
        }
        else if ( istrue( had_perk ) && current_ref == "equip_semtex" )
        {
            self zm_ww_swap_lethal( "equip_frag" );
        }

        had_perk = has_perk;
    }
}

function private zm_ww_grant_lethal( ref, amount )
{
    equipment_mp::giveequipment( ref, "primary" );
    equipment_mp::setequipmentammo( ref, amount );
}

function private zm_ww_swap_lethal( ref )
{
    have = equipment_mp::getequipmentslotammo( "primary" );

    if ( !isdefined( have ) )
    {
        have = 0;
    }

    max = equipment_mp::getequipmentmaxammo( ref );

    if ( isdefined( max ) && max > 0 && have > max )
    {
        have = max;
    }

    equipment_mp::giveequipment( ref, "primary" );
    equipment_mp::setequipmentammo( ref, have );
}

function private zm_arsenal_ammo_mod_cost()
{
    return 5000;
}

function private zm_arsenal_menu_hook_start()
{
    level endon( #"game_ended" );

    while ( true )
    {
        if ( isarray( level.var_9398dff023585316 ) && isarray( level.var_9398dff023585316[ "__all__" ] ) )
        {
            for ( i = 0; i < level.var_9398dff023585316[ "__all__" ].size; i++ )
            {
                if ( level.var_9398dff023585316[ "__all__" ][ i ] == &arsenal::arsenal_menu_purchase )
                {
                    level.var_9398dff023585316[ "__all__" ][ i ] = &zm_arsenal_menu_purchase;
                }
            }
        }

        wait 0.5;
    }
}

function private zm_arsenal_menu_purchase( channel, menuitemindex )
{
    if ( !supported_mode() || !isdefined( menuitemindex ) )
    {
        self arsenal::arsenal_menu_purchase( channel, menuitemindex );
        return;
    }

    if ( channel == "arsenal_tierupgrade_purchase" )
    {
        item = purchasemenu::create_item_struct( #"arsenal", menuitemindex );

        if ( !isdefined( item ) )
        {
            return;
        }

        response = self zm_arsenal_buy_perk_slot( item );

        if ( response == 1 )
        {
            if ( isdefined( item.soundpurchase ) )
            {
                self playsoundtoplayer( item.soundpurchase, self );
            }

            if ( isdefined( self.s_arsenal_machine ) && isdefined( self.s_arsenal_machine.mdl_arsenal ) )
            {
                self.s_arsenal_machine.mdl_arsenal setscriptablepartstate( "anim", "weapon_upgrade" );
                self.s_arsenal_machine.mdl_arsenal setscriptablepartstate( "audio_purchase", "weapon_rarity" );
            }
        }
        else if ( isdefined( item.soundpurchasedeny ) )
        {
            self playsoundtoplayer( item.soundpurchasedeny, self );
        }

        purchasemenu::function_93f934ea2f1c06f8( response );
        return;
    }

    if ( channel == "arsenal_ammomod_purchase" )
    {
        item = purchasemenu::create_item_struct( #"arsenal", menuitemindex );

        if ( !isdefined( item ) )
        {
            return;
        }

        response = self zm_arsenal_craft_ammo_mod( item );

        if ( response == 1 )
        {
            if ( isdefined( item.soundpurchase ) )
            {
                self playsoundtoplayer( item.soundpurchase, self );
            }

            if ( isdefined( self.s_arsenal_machine ) && isdefined( self.s_arsenal_machine.mdl_arsenal ) )
            {
                self.s_arsenal_machine.mdl_arsenal setscriptablepartstate( "anim", "weapon_upgrade" );
                self.s_arsenal_machine.mdl_arsenal setscriptablepartstate( "audio_purchase", "ammomod" );
            }
        }
        else if ( response == 3 )
        {
            if ( isdefined( item.soundpurchasedeny ) )
            {
                self playsoundtoplayer( item.soundpurchasedeny, self );
            }
        }

        purchasemenu::function_93f934ea2f1c06f8( response );
        return;
    }

    self arsenal::arsenal_menu_purchase( channel, menuitemindex );
}

function private zm_arsenal_perk_slot_step()
{
    return 5000;
}

function private zm_arsenal_perk_slot_max()
{
    return 4;
}

function private zm_arsenal_tier_rank( item )
{
    rank = 0;
    tier = item.tier ?? 0;

    tab_struct = purchasemenu::get_purchasemenu_tab( #"arsenal", item.var_b487b5b7ae379493 );

    if ( isdefined( tab_struct ) && isarray( tab_struct.items ) )
    {
        foreach ( tabitem in tab_struct.items )
        {
            other = purchasemenu::create_item_struct( #"arsenal", tabitem.globalindex );

            if ( isdefined( other ) && isdefined( other.tier ) && other.tier > 0 && other.tier <= tier )
            {
                rank++;
            }
        }
    }

    if ( rank < 1 )
    {
        rank = tier;
    }

    return rank;
}

function private zm_arsenal_buy_perk_slot( item )
{
    bought = self.zm_perk_slots_bought ?? 0;
    rank = zm_arsenal_tier_rank( item );

    if ( rank < 1 || rank > zm_arsenal_perk_slot_max() || rank != bought + 1 )
    {
        self playsoundtoplayer( #"ui_zm_core_purchase_deny", self );
        return 4;
    }

    cost = zm_arsenal_perk_slot_step() * rank;

    if ( !self currency::can_afford( #"essence", cost ) )
    {
        return 3;
    }

    self currency::sub_currency_amount( #"essence", cost );
    self.zm_perk_slots_bought = rank;
    self.zm_slot_tier = item.tier ?? rank;
    self.zm_perk_bonus = ( self.zm_perk_bonus ?? 0 ) + 1;
    self.var_468836e5e67e15b4--;
    return 1;
}

function private zm_arsenal_menu_open()
{
    return isdefined( self.s_arsenal_machine ) && self.s_arsenal_machine utility::ent_flag( "arsenal_in_use" );
}

function private zm_arsenal_real_weapon_tier()
{
    w = self getcurrentweapon();

    if ( !isdefined( w ) || isnullweapon( w ) || weapon::isfistweapon( w ) || w.basename == "iw8_gunless" )
    {
        return 0;
    }

    return item_weapon::function_fb81bd2fe070faa6( w ) ?? 0;
}

function private zm_arsenal_slot_grey_loop()
{
    self notify( #"zm_slot_grey_restart" );
    self endon( #"zm_slot_grey_restart" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    if ( !hasomnvar( "ui_current_weapon_tier" ) )
    {
        return;
    }

    applied = 0;

    while ( true )
    {
        wait 0.1;

        if ( ( self.zm_slot_tier ?? 0 ) > 0 && self zm_arsenal_menu_open() )
        {
            self setclientomnvar( "ui_current_weapon_tier", self.zm_slot_tier );
            applied = 1;
        }
        else if ( applied )
        {
            applied = 0;
            self setclientomnvar( "ui_current_weapon_tier", self zm_arsenal_real_weapon_tier() );
        }
    }
}

function private zm_arsenal_is_real_weapon( w )
{
    return isdefined( w ) && isweapon( w ) && !isnullweapon( w ) && !weapon::isfistweapon( w );
}

function private zm_arsenal_is_primary( w )
{
    if ( !isdefined( w ) )
    {
        return false;
    }

    foreach ( primary in self getweaponslistprimaries() )
    {
        if ( primary == w )
        {
            return true;
        }
    }

    return false;
}

function private zm_arsenal_target_weapon()
{
    w = self getcurrentweapon();

    if ( self zm_arsenal_is_real_weapon( w ) )
    {
        return w;
    }

    w = self getcurrentprimaryweapon();

    if ( self zm_arsenal_is_real_weapon( w ) )
    {
        return w;
    }

    if ( isdefined( self.lastweaponobj ) && self zm_arsenal_is_primary( self.lastweaponobj ) )
    {
        return self.lastweaponobj;
    }

    return undefined;
}

function private zm_arsenal_fail( msg )
{
    self playsoundtoplayer( #"ui_zm_core_purchase_deny", self );
    self iprintlnbold( msg );
    return 4;
}

function private zm_arsenal_craft_ammo_mod( item )
{
    cost = zm_arsenal_ammo_mod_cost();

    if ( !self currency::can_afford( #"essence", cost ) )
    {
        return 3;
    }

    weapon = self zm_arsenal_target_weapon();

    if ( !isdefined( weapon ) )
    {
        return self zm_arsenal_fail( "Arsenal: no weapon in hand" );
    }

    if ( !ammo_mod::can_get_ammo_mod( weapon ) )
    {
        return self zm_arsenal_fail( "Arsenal: this weapon cannot take Ammo Mods" );
    }

    mod = item.itemref;

    if ( self ammo_mod::get_ammo_mod_name( weapon ) === mod )
    {
        return self zm_arsenal_fail( "Arsenal: weapon already has this Ammo Mod" );
    }

    new_weapon = self ammo_mod::add_ammo_mod_to_weapon( weapon, mod );
    applied = 0;

    if ( isdefined( new_weapon ) && isweapon( new_weapon ) && self ammo_mod::has_ammo_mod_by_name( new_weapon, mod ) )
    {
        applied = 1;
    }
    else if ( self ammo_mod::get_ammo_mod_name( weapon ) === mod )
    {
        applied = 1;
    }

    if ( !applied )
    {
        return self zm_arsenal_fail( "Arsenal: Ammo Mod could not be applied (no charge)" );
    }

    params = spawnstruct();
    params.item = mod;
    params.currency = #"essence";
    params.cost = cost;
    self callback::callback( "arsenal_craft_ammo_mod", params );
    self currency::sub_currency_amount( #"essence", cost );

    return 1;
}

function private zm_pap_rarity_init()
{
    level endon( #"game_ended" );

    level callback::add( "zm_packed_weapon", &zm_pap_on_packed );

    while ( true )
    {
        wait 0.5;

        if ( !isarray( level.players ) )
        {
            continue;
        }

        foreach ( player in level.players )
        {
            if ( isdefined( player ) && isplayer( player ) && isalive( player ) )
            {
                player zm_pap_rarity_check();
            }
        }
    }
}

function private zm_pap_on_packed( params )
{
    if ( !isdefined( params ) || !isdefined( params.player ) || !isplayer( params.player ) || !isdefined( params.var_101633ed971732ba ) || !isnumber( params.var_951c89546ec50477 ) )
    {
        return;
    }

    params.player thread zm_pap_force_tier( params.var_101633ed971732ba, params.var_951c89546ec50477 );
}

function private zm_pap_force_tier( new_weapon, pap_level )
{
    self endon( #"disconnect" );

    if ( !isdefined( self.zm_pap_event_level ) )
    {
        self.zm_pap_event_level = [];
    }

    if ( isdefined( new_weapon.basename ) )
    {
        self.zm_pap_event_level[ new_weapon.basename ] = pap_level;
    }

    rarity = zm_pap_tier_for_level( pap_level );

    for ( i = 0; i < 50; i++ )
    {
        wait 0.2;

        if ( !isalive( self ) || !self hasweapon( new_weapon ) )
        {
            continue;
        }

        self zm_pap_apply_rarity( new_weapon, rarity );
    }
}

function private zm_pap_tier_for_level( pap_level )
{
    return int( min( pap_level, 4 ) ) + 1;
}

function private zm_pap_apply_rarity( w, rarity )
{
    before = item_weapon::function_fb81bd2fe070faa6( w );

    if ( before >= rarity )
    {
        return;
    }

    self arsenal::upgrade_rarity( w, rarity );

    params = spawnstruct();
    params.weapon = w;
    params.rarity = rarity;
    params.currency = #"salvage";
    params.cost = 0;
    self callback::callback( "arsenal_upgrade_weapon_rarity", params );

    if ( !isdefined( self.zm_tracked_weapon_rarity ) )
    {
        self.zm_tracked_weapon_rarity = [];
    }

    self.zm_tracked_weapon_rarity[ w ] = rarity;

    if ( isdefined( w.basename ) )
    {
        self.zm_tracked_weapon_rarity[ w.basename ] = rarity;
    }
}

function private zm_pap_rarity_check()
{
    if ( !isdefined( self.zm_pap_event_level ) )
    {
        self.zm_pap_event_level = [];
    }

    weapons = self getweaponslistprimaries();

    if ( !isarray( weapons ) )
    {
        return;
    }

    present = [];

    foreach ( w in weapons )
    {
        if ( !isdefined( w ) || !isweapon( w ) || isnullweapon( w ) || weapon::iswonderweapon( w ) || weapon::iskillstreakweapon( w ) || weapon::isfistweapon( w ) )
        {
            continue;
        }

        if ( isdefined( w.basename ) )
        {
            present[ w.basename ] = 1;
        }

        pap_level = 0;

        if ( utility::issharedfuncdefined( #"zombie", #"get_pap_level" ) )
        {
            level_a = self utility::callsharedfunc( #"zombie", #"get_pap_level", w );

            if ( isnumber( level_a ) && level_a > pap_level )
            {
                pap_level = level_a;
            }
        }

        weapondata = item_weapon::function_92b8514cdacab7f9( w );

        if ( isdefined( weapondata ) && isnumber( weapondata.paplevel ) && weapondata.paplevel > pap_level )
        {
            pap_level = weapondata.paplevel;
        }

        if ( isdefined( w.basename ) && isnumber( self.zm_pap_event_level[ w.basename ] ) && self.zm_pap_event_level[ w.basename ] > pap_level )
        {
            pap_level = self.zm_pap_event_level[ w.basename ];
        }

        if ( pap_level < 1 )
        {
            continue;
        }

        self zm_pap_apply_rarity( w, zm_pap_tier_for_level( pap_level ) );
    }

    foreach ( key, value in self.zm_pap_event_level )
    {
        if ( !isdefined( present[ key ] ) )
        {
            self.zm_pap_event_level[ key ] = undefined;
        }
    }
}

function private zm_get_custom_pap_cost_for_tier( tier )
{
    if ( !isnumber( tier ) )
    {
        return 5000;
    }

    if ( tier <= 1 )
    {
        return 5000;
    }
    if ( tier == 2 )
    {
        return 20000;
    }
    if ( tier == 3 )
    {
        return 35000;
    }

    return 50000;
}

function private zm_custom_get_pap_cost( arg1, arg2 )
{
    tier = 1;

    if ( isnumber( arg1 ) )
    {
        tier = arg1;
    }
    else if ( isnumber( arg2 ) )
    {
        tier = arg2;
    }
    else
    {
        w = undefined;
        player = isplayer( self ) ? self : ( isplayer( arg1 ) ? arg1 : undefined );

        if ( isdefined( arg1 ) && isweapon( arg1 ) )
        {
            w = arg1;
        }
        else if ( isdefined( arg2 ) && isweapon( arg2 ) )
        {
            w = arg2;
        }
        else if ( isdefined( player ) )
        {
            w = player getcurrentweapon();
        }

        if ( isdefined( w ) && utility::issharedfuncdefined( #"zombie", #"get_pap_level" ) )
        {
            cur_lvl = isdefined( player ) ? player utility::callsharedfunc( #"zombie", #"get_pap_level", w ) : utility::callsharedfunc( #"zombie", #"get_pap_level", w );
            if ( isnumber( cur_lvl ) )
            {
                tier = cur_lvl + 1;
            }
        }
    }

    return zm_get_custom_pap_cost_for_tier( tier );
}

function private zm_pap_cost_override( item )
{
    if ( !isnumber( item.cost ) )
    {
        return item.cost;
    }

    pap_level = 4;

    if ( item.cost <= 10000 )
    {
        pap_level = 1;
    }
    else if ( item.cost <= 25000 )
    {
        pap_level = 2;
    }
    else if ( item.cost <= 50000 )
    {
        pap_level = 3;
    }

    return zm_get_custom_pap_cost_for_tier( pap_level );
}

function private zm_apply_pap_costs_to_array( arr )
{
    if ( !isdefined( arr ) || !isarray( arr ) )
    {
        return;
    }

    if ( isdefined( arr[ 0 ] ) )
    {
        if ( isnumber( arr[ 0 ] ) && arr[ 0 ] > 0 )
        {
            arr[ 0 ] = 5000;
            if ( isdefined( arr[ 1 ] ) && isnumber( arr[ 1 ] ) )
            {
                arr[ 1 ] = 20000;
            }
            if ( isdefined( arr[ 2 ] ) && isnumber( arr[ 2 ] ) )
            {
                arr[ 2 ] = 35000;
            }
            if ( isdefined( arr[ 3 ] ) && isnumber( arr[ 3 ] ) )
            {
                arr[ 3 ] = 50000;
            }
        }
        else if ( isstruct( arr[ 0 ] ) )
        {
            for ( i = 0; i < arr.size; i++ )
            {
                if ( isdefined( arr[ i ] ) && isstruct( arr[ i ] ) )
                {
                    c = zm_get_custom_pap_cost_for_tier( i + 1 );
                    if ( isdefined( arr[ i ].cost ) )
                    {
                        arr[ i ].cost = c;
                    }
                    if ( isdefined( arr[ i ].n_cost ) )
                    {
                        arr[ i ].n_cost = c;
                    }
                    if ( isdefined( arr[ i ].price ) )
                    {
                        arr[ i ].price = c;
                    }
                }
            }
        }
    }

    if ( isdefined( arr[ 1 ] ) && isnumber( arr[ 1 ] ) && !isdefined( arr[ 0 ] ) )
    {
        arr[ 1 ] = 5000;
        if ( isdefined( arr[ 2 ] ) && isnumber( arr[ 2 ] ) )
        {
            arr[ 2 ] = 20000;
        }
        if ( isdefined( arr[ 3 ] ) && isnumber( arr[ 3 ] ) )
        {
            arr[ 3 ] = 35000;
        }
        if ( isdefined( arr[ 4 ] ) && isnumber( arr[ 4 ] ) )
        {
            arr[ 4 ] = 50000;
        }
    }
}

function private zm_pap_pricing_init()
{
    level endon( #"game_ended" );

    while ( true )
    {
        level.get_pap_cost_override = &zm_pap_cost_override;

        utility::registersharedfunc( #"zombie", #"get_pap_cost", &zm_custom_get_pap_cost );

        if ( isdefined( level.var_ef0de88635a0b38e ) && isarray( level.var_ef0de88635a0b38e ) )
        {
            zm_apply_pap_costs_to_array( level.var_ef0de88635a0b38e );
        }

        if ( isdefined( level.pap_costs ) && isarray( level.pap_costs ) )
        {
            zm_apply_pap_costs_to_array( level.pap_costs );
        }

        if ( isdefined( level.a_pap_costs ) && isarray( level.a_pap_costs ) )
        {
            zm_apply_pap_costs_to_array( level.a_pap_costs );
        }

        if ( isdefined( level.zm_mode_modifiers ) && isstruct( level.zm_mode_modifiers ) )
        {
            if ( isdefined( level.zm_mode_modifiers.pap_costs ) && isarray( level.zm_mode_modifiers.pap_costs ) )
            {
                zm_apply_pap_costs_to_array( level.zm_mode_modifiers.pap_costs );
            }
            if ( isdefined( level.zm_mode_modifiers.var_ef0de88635a0b38e ) && isarray( level.zm_mode_modifiers.var_ef0de88635a0b38e ) )
            {
                zm_apply_pap_costs_to_array( level.zm_mode_modifiers.var_ef0de88635a0b38e );
            }
        }

        wait 0.5;
    }
}

function private zm_qr_self_revive_init()
{
    level endon( #"game_ended" );

    level thread zm_qr_machine_watch();
    level callback::add( #"player_spawned", &zm_qr_on_player_spawned );
    level callback::add( "zm_perk_obtained", &zm_qr_on_perk_obtained );
    level callback::add( #"player_laststand_revived", &zm_qr_on_laststand_revived );
}

function private zm_qr_on_laststand_revived( params )
{
    if ( !isplayer( self ) || !supported_mode() || !isdefined( params ) || !istrue( params.selfrevive ) )
    {
        return;
    }

    self thread zm_qr_consume_perk();
}

function private zm_qr_consume_perk()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    kept = [];

    foreach ( perk in ( self.zm_adrenaline_kept ?? [] ) )
    {
        if ( perk != "specialty_quickrevive" )
        {
            kept[ kept.size ] = perk;
        }
    }

    self.zm_adrenaline_kept = kept;

    eternal = self zombie_perks::has_permanent_perk( "specialty_quickrevive" );

    waitframe();

    if ( isalive( self ) && zm_qr_player_has_perk( self ) )
    {
        self zombie_perks::take_perk( "specialty_quickrevive", 1 );
    }

    if ( !eternal )
    {
        return;
    }

    waitframe();

    if ( !isalive( self ) )
    {
        return;
    }

    if ( !zm_qr_player_has_perk( self ) )
    {
        zm_qr_give_perk_quiet( self, "specialty_quickrevive" );
    }

    if ( zm_qr_purchase_count( self ) < zm_qr_max_purchases( self ) )
    {
        zm_qr_grant_revive( self );
    }
}

function private zm_qr_on_perk_obtained( params )
{
    if ( !isplayer( self ) || !isdefined( params ) || !supported_mode() )
    {
        return;
    }

    if ( params.var_ffc1674def575bfa != "specialty_quickrevive" || istrue( self.zm_qr_skip_grant ) )
    {
        return;
    }

    if ( zm_qr_purchase_count( self ) >= zm_qr_max_purchases( self ) )
    {
        return;
    }

    zm_qr_grant_revive( self );
}

function private zm_qr_grant_revive( player )
{
    revives_before = player laststand::function_7072b516e6cffb7c();
    player laststand::function_a2e03a85015b1897();

    if ( player laststand::function_7072b516e6cffb7c() <= revives_before )
    {
        player laststand::function_39844c1e879cc048( revives_before + 1 );
    }

    if ( level.players.size == 1 )
    {
        player.b_solo_self_revive = ( player.var_4877be4da79014b0 ?? 0 ) > ( player.var_aecc486f34e4dd66 ?? 0 );
    }

    player.zm_qr_purchases = zm_qr_purchase_count( player ) + 1;
}

function private zm_qr_give_perk_quiet( player, perk )
{
    player.zm_qr_skip_grant = 1;
    player zombie_perks::give_perk( perk, 1 );
    player.zm_qr_skip_grant = undefined;
}

function private zm_qr_machine_watch()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.a_s_perk_machines ) )
    {
        wait 0.1;
    }

    while ( true )
    {
        if ( level.players.size != 1 )
        {
            wait 0.5;
            continue;
        }

        if ( isarray( level.a_s_perk_machines ) )
        {
            foreach ( s_machine in level.a_s_perk_machines )
            {
                if ( !isdefined( s_machine ) || !isdefined( s_machine.mdl_perk_machine ) )
                {
                    continue;
                }

                interact = s_machine.mdl_perk_machine.interact;

                if ( !isdefined( interact ) || !zm_qr_is_machine( s_machine, interact ) )
                {
                    continue;
                }

                if ( !istrue( interact.zm_qr_bound ) )
                {
                    if ( !isfunction( interact.interact_hint_callback ) )
                    {
                        continue;
                    }

                    if ( !isarray( interact.var_d8e3b07237845727 ) || interact.var_d8e3b07237845727.size == 0 || !isfunction( interact.var_d8e3b07237845727[ 0 ] ) )
                    {
                        continue;
                    }

                    interact.zm_qr_bound = 1;
                    interact.zm_qr_orig_hint = interact.interact_hint_callback;
                    interact.zm_qr_orig_use = interact.var_d8e3b07237845727[ 0 ];
                }

                if ( interact.interact_hint_callback != &zm_qr_machine_hint )
                {
                    interact interaction::set_interact_use_callback( &zm_qr_machine_use );
                    interact interaction::set_interact_hint_callback( &zm_qr_machine_hint );
                }
            }
        }

        wait 0.5;
    }
}

function private zm_qr_is_machine( s_machine, interact )
{
    perk = undefined;

    if ( isdefined( interact ) )
    {
        perk = interact.script_notify;

        if ( !isdefined( perk ) && isdefined( interact.s_perk_machine ) )
        {
            perk = interact.s_perk_machine.script_noteworthy;
        }
    }

    if ( !isdefined( perk ) && isdefined( s_machine ) )
    {
        perk = s_machine.script_noteworthy;
    }

    if ( !isstring( perk ) )
    {
        return false;
    }

    return perk == "specialty_quickrevive" || perk == "talent_quickrevive" || perk == "talent_quick_revive" || perk == "quickrevive" || perk == "quick_revive" || perk == "perk_quickrevive";
}

function private zm_qr_on_player_spawned( params )
{
    self thread zm_qr_solo_spawn_fix();
}

function private zm_qr_solo_spawn_fix()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );

    if ( isdefined( self.zm_qr_spawn_fix_done ) )
    {
        return;
    }

    if ( level.players.size != 1 )
    {
        self.zm_qr_spawn_fix_done = 1;
        return;
    }

    for ( i = 0; i < 400; i++ )
    {
        has_marker = isdefined( self.b_solo_self_revive );
        round_started = isdefined( level.flag ) && istrue( level.flag[ "begin_round_logic" ] );

        if ( has_marker && round_started )
        {
            break;
        }

        wait 0.05;
    }

    wait 0.5;

    if ( isdefined( self.zm_qr_spawn_fix_done ) )
    {
        return;
    }

    self.zm_qr_spawn_fix_done = 1;

    if ( level.players.size != 1 || zm_qr_purchase_count( self ) > 0 )
    {
        return;
    }

    self.b_solo_self_revive = 0;
    self.var_aecc486f34e4dd66 = 0;
    self.var_4877be4da79014b0 = 0;
    self.var_63cd4b355dddbeba = 0;
    self laststand::function_39844c1e879cc048( 0 );
}

function private zm_qr_purchase_count( player )
{
    if ( !isdefined( player ) )
    {
        return 0;
    }

    return player.zm_qr_purchases ?? 0;
}

function private zm_qr_max_purchases( player )
{
    base = level.players.size == 1 ? 3 : 1;

    if ( zm_qr_has_emergency_medical_kit( player ) )
    {
        return base + 1;
    }

    return base;
}

function private zm_qr_has_emergency_medical_kit( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( utility::issharedfuncdefined( #"zombie", #"hash_3930894d8d2f0ee6" ) )
    {
        return istrue( player utility::callsharedfunc( #"zombie", #"hash_3930894d8d2f0ee6", "specialty_quickrevive", #"quick_revive_emergency_medical_kit" ) );
    }

    if ( utility::issharedfuncdefined( #"zombie", #"player_has_augment" ) )
    {
        return istrue( player utility::callsharedfunc( #"zombie", #"player_has_augment", #"quick_revive_emergency_medical_kit" ) );
    }

    return false;
}

function private zm_qr_player_has_perk( player )
{
    if ( !isdefined( player ) || !isdefined( level._custom_perks ) )
    {
        return false;
    }

    info = level._custom_perks[ "specialty_quickrevive" ];

    if ( isdefined( info ) && isdefined( info.str_perk_root ) )
    {
        return player zombie_perks::has_perk( info.str_perk_root );
    }

    return player zombie_perks::has_perk( "specialty_quickrevive" );
}

function private zm_qr_at_perk_limit( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( level.gametypebundle.perklimit > 0 && isdefined( player.var_468836e5e67e15b4 ) && player.var_468836e5e67e15b4 >= level.gametypebundle.perklimit )
    {
        return true;
    }

    return false;
}

function private zm_qr_price( usable )
{
    if ( utility::issharedfuncdefined( #"perk_machine", #"hash_dfdcc3fdc88af90c" ) )
    {
        price = utility::callsharedfunc( #"perk_machine", #"hash_dfdcc3fdc88af90c", usable );

        if ( isdefined( price ) )
        {
            return price;
        }
    }

    if ( isdefined( level._custom_perks ) )
    {
        info = level._custom_perks[ "specialty_quickrevive" ];

        if ( isdefined( info ) && isdefined( info.cost ) )
        {
            return info.cost;
        }
    }

    return 1500;
}

function private zm_qr_currency( usable )
{
    if ( isdefined( usable ) && isdefined( usable.s_perk_machine ) && isdefined( usable.s_perk_machine.script_currency ) )
    {
        return usable.s_perk_machine.script_currency;
    }

    return #"essence";
}

function private zm_qr_machine_hint( usable, player )
{
    if ( !isdefined( usable ) || !isdefined( player ) )
    {
        return { #string:&"", #type:"HINT_NOBUTTON" };
    }

    if ( level.players.size != 1 )
    {
        orig = usable.zm_qr_orig_hint;

        if ( isfunction( orig ) )
        {
            return [[ orig ]]( usable, player );
        }

        return { #string:&"", #type:"HINT_NOBUTTON" };
    }

    if ( zm_qr_purchase_count( player ) >= zm_qr_max_purchases( player ) )
    {
        return { #string:&"", #type:"HINT_NOBUTTON" };
    }

    if ( usable isscriptableinstance() && usable getscriptablepartstate( "base" ) == "power_off" )
    {
        return { #string:&"", #type:"HINT_NOICON" };
    }

    if ( level.var_c139731c583cae6b || !player val::get( "allow_zm_perks" ) )
    {
        return { #string:&"", #type:"HINT_NOBUTTON" };
    }

    if ( istrue( player.interactions_disabled ) )
    {
        return { #string:&"", #type:"HINT_NOBUTTON" };
    }

    if ( !zm_qr_player_has_perk( player ) && zm_qr_at_perk_limit( player ) )
    {
        return { #string:&"", #type:"HINT_NOBUTTON" };
    }

    price = zm_qr_price( usable );
    currency = zm_qr_currency( usable );
    info = level._custom_perks[ "specialty_quickrevive" ];
    hint = { #icon_text_value:price, #var_776a268784e089af:&"shared_hintstrings/cost_essence", #buttoncallout:&"shared_hintstrings/perk_machine_buy", #type:"HINT_BUTTON" };

    if ( isdefined( info ) )
    {
        hint.icon = info.icon;
        hint.title = info.hint_name;
        hint.description = info.buy_description;
    }

    if ( !player currency::can_afford( currency, price ) )
    {
        hint.aux_text = &"shared_hintstrings/not_enough_essence";
        hint.var_776a268784e089af = &"shared_hintstrings/cost_essence_not_enough";
        hint.interactable = 0;
    }

    return hint;
}

function private zm_qr_machine_use( player )
{
    if ( !isdefined( player ) || !isplayer( player ) )
    {
        return;
    }

    if ( level.players.size != 1 )
    {
        orig = self.zm_qr_orig_use;

        if ( isfunction( orig ) )
        {
            self [[ orig ]]( player );
        }

        return;
    }

    if ( istrue( player.interactions_disabled ) )
    {
        return;
    }

    if ( zm_qr_purchase_count( player ) >= zm_qr_max_purchases( player ) )
    {
        player playsoundtoplayer( #"ui_zm_core_purchase_deny", player );
        return;
    }

    s_machine = self.s_perk_machine;
    mdl = undefined;

    if ( isdefined( s_machine ) )
    {
        mdl = s_machine.mdl_perk_machine;
    }

    if ( isdefined( mdl ) && mdl getscriptablehaspart( "base" ) && mdl getscriptablepartstate( "base" ) == "power_off" )
    {
        return;
    }

    if ( level.var_c139731c583cae6b || !player val::get( "allow_zm_perks" ) )
    {
        return;
    }
    
    if ( !zm_qr_player_has_perk( player ) && zm_qr_at_perk_limit( player ) )
    {
        return;
    }

    price = zm_qr_price( self );
    currency = zm_qr_currency( self );

    if ( !player currency::attempt_purchase( currency, price, 1, undefined, #"perk", "specialty_quickrevive" ) )
    {
        player playsoundtoplayer( #"ui_zm_core_purchase_deny", player );
        return;
    }

    if ( isdefined( mdl ) && mdl getscriptablehaspart( "use" ) && mdl getscriptablepartstate( "use" ) == "default" )
    {
        mdl setscriptablepartstate( "use", "purchase" );
    }

    if ( !zm_qr_player_has_perk( player ) )
    {
        info = level._custom_perks[ "specialty_quickrevive" ];
        gesture = undefined;

        if ( isdefined( info ) )
        {
            gesture = info.perk_bottle_weapon;
        }

        if ( isdefined( gesture ) )
        {
            player thread zombie_perks::function_13cc8b1c31dda8c4( gesture );
        }

        player.zm_qr_skip_grant = 1;
        player zombie_perks::give_perk( "specialty_quickrevive", 1, 1 );
        player.zm_qr_skip_grant = undefined;
    }

    zm_qr_grant_revive( player );

    params = spawnstruct();
    params.perk_machine = self;
    player callback::callback( "zm_perk_machine_used", params );

    bought = spawnstruct();
    bought.perkref = "specialty_quickrevive";
    bought.cost = price;
    bought.currency = currency;
    bought.source = #"perk_machine";
    player callback::callback( "zm_perk_purchased", bought );
}

function private zm_firefly_free_tessie_repair_init()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.mapname ) )
    {
        waitframe();
    }

    if ( level.mapname != "zm_sat_firefly" )
    {
        return;
    }

    while ( true )
    {
        level.var_8672fa96c3fb69e0 = 1;
        wait 0.05;
    }
}

autoexec zm_dead_drop_points_init()
{
    level thread zm_dead_drop_points_start();
}

function private zm_dead_drop_points_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( true )
    {
        foreach ( player in level.players )
        {
            if ( isplayer( player ) )
            {
                player zm_dead_drop_points_update();
            }
        }

        wait 0.25;
    }
}

function private zm_dead_drop_points_update()
{
    active = isdefined( self.bgb_enabled ) && self bgb::is_enabled( "dead_drop" );

    if ( active )
    {
        self.zm_dead_drop_points_on = 1;
        self points::set_point_scalar( 1.15, "zm_dead_drop_points" );
        return;
    }

    if ( istrue( self.zm_dead_drop_points_on ) )
    {
        self.zm_dead_drop_points_on = undefined;
        self points::set_point_scalar( 1, "zm_dead_drop_points" );
    }
}

function private zm_mannequin_wunderfizz_active()
{
    if ( istrue( level.zm_mt_relic_on ) )
    {
        return true;
    }

    relic = %"hash_2a3c31ac35b565e6";

    if ( isarray( level.active_relics ) && arraycontains( level.active_relics, relic ) )
    {
        return true;
    }

    if ( isdefined( level.active_relic_challenge ) && isdefined( level.active_relic_challenge.relic_hash ) && level.active_relic_challenge.relic_hash == relic )
    {
        return true;
    }

    return false;
}

function private zm_mannequin_relic_on()
{
    level.zm_mt_relic_on = 1;
    zm_mannequin_block_wunderfizz_spawn();
}

function private zm_mannequin_relic_off()
{
    level.zm_mt_relic_on = undefined;
}

function private zm_mannequin_effect_override()
{
    level endon( #"game_ended" );

    relic = %"hash_2a3c31ac35b565e6";

    while ( !isdefined( level.zm_relics ) || !isdefined( level.zm_relics[ relic ] ) )
    {
        waitframe();
    }

    modifier = level.zm_relics[ relic ].modifiertype;

    if ( !isdefined( modifier ) )
    {
        return;
    }

    on_hash = #"hash_3802c55cdf341a6b";
    off_hash = #"hash_eb4ac69bf458f466";

    while ( true )
    {
        if ( !utility::issharedfuncdefined( modifier, on_hash ) || level.sharedfuncs[ modifier ][ on_hash ] != &zm_mannequin_relic_on )
        {
            utility::registersharedfunc( modifier, on_hash, &zm_mannequin_relic_on );
        }

        if ( !utility::issharedfuncdefined( modifier, off_hash ) || level.sharedfuncs[ modifier ][ off_hash ] != &zm_mannequin_relic_off )
        {
            utility::registersharedfunc( modifier, off_hash, &zm_mannequin_relic_off );
        }

        if ( istrue( level.zm_mt_relic_on ) )
        {
            wait 1;
        }
        else
        {
            waitframe();
        }
    }
}

function private zm_mannequin_block_wunderfizz_spawn()
{
    if ( isdefined( level.gametypebundle ) )
    {
        level.gametypebundle.disablewunderfizz = 1;
    }

    if ( getdvarint( @"hash_74cacae425805743", 0 ) < 1 )
    {
        setdvar( @"hash_74cacae425805743", 1 );
    }
}

function private zm_mannequin_remove_machine( s_machine )
{
    mdl = s_machine.mdl_perk_machine;

    if ( !isdefined( mdl ) )
    {
        return;
    }

    if ( isdefined( mdl.interact ) )
    {
        mdl.interact delete();
    }

    if ( isent( mdl ) )
    {
        mdl delete();
    }
    else
    {
        mdl freescriptable();
    }

    s_machine.mdl_perk_machine = undefined;

    if ( isdefined( s_machine.clip ) )
    {
        s_machine.clip notsolid();
        s_machine.clip connectpaths();
    }
}

function private zm_mannequin_wunderfizz_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    level thread zm_mannequin_effect_override();

    while ( true )
    {
        if ( !zm_mannequin_wunderfizz_active() )
        {
            wait 0.25;
            continue;
        }

        zm_mannequin_block_wunderfizz_spawn();

        if ( isarray( level.a_s_perk_machines ) )
        {
            foreach ( s_machine in level.a_s_perk_machines )
            {
                if ( isdefined( s_machine ) && istrue( s_machine.is_wunderfizz ) )
                {
                    zm_mannequin_remove_machine( s_machine );
                }
            }
        }

        waitframe();
    }
}

autoexec zm_classic_perks_init()
{
    level thread zm_classic_perks_start();
    level thread zm_classic_perks_wunderfizz_always();
    level thread zm_classic_perks_order_tracker();
}

zm_classic_perks_wunderfizz_always()
{
    level endon(#"game_ended");

    level.var_865fa84b8f7cc220 = 1;

    while (!isdefined(level.gametypebundle))
    {
        waitframe();
    }

    level.gametypebundle.var_7910192e66e7774c = 0;
}

zm_classic_perks_order_tracker()
{
    level endon(#"game_ended");

    while (true)
    {
        if (isdefined(level.players) && isarray(level.players))
        {
            foreach (player in level.players)
            {
                if (isdefined(player) && !istrue(player.zm_cp_order_watching))
                {
                    player.zm_cp_order_watching = 1;
                    player thread zm_classic_perks_player_order_watch();
                }
            }
        }
        wait 0.25;
    }
}

zm_classic_perks_player_order_watch()
{
    self endon(#"disconnect");
    level endon(#"game_ended");

    self.zm_cp_perk_order = [];

    while (true)
    {
        waitframe();

        if (!isdefined(self.perks_active) || !isarray(self.perks_active))
        {
            self.zm_cp_perk_order = [];
            continue;
        }

        if (self.perks_active.size == 0)
        {
            self.zm_cp_perk_order = [];
            continue;
        }

        new_order = [];
        foreach (tracked_perk in self.zm_cp_perk_order)
        {
            if (zm_classic_perks_is_perk_in_list(self.perks_active, tracked_perk))
            {
                new_order[new_order.size] = tracked_perk;
            }
        }
        foreach (active_perk in self.perks_active)
        {
            if (!zm_classic_perks_is_perk_in_list(new_order, active_perk))
            {
                new_order[new_order.size] = active_perk;
            }
        }

        self.zm_cp_perk_order = new_order;

        needs_fix = false;
        if (self.perks_active.size == self.zm_cp_perk_order.size)
        {
            for (i = 0; i < self.perks_active.size; i++)
            {
                if (self.perks_active[i] != self.zm_cp_perk_order[i])
                {
                    needs_fix = true;
                    break;
                }
            }
        }

        if (needs_fix)
        {
            self.perks_active = self.zm_cp_perk_order;
            self zombie_perks::function_c11ba4bb3d0a676b();
        }
    }
}

zm_classic_perks_ids()
{
    if (!isdefined(level.zm_cp_perk_ids))
    {
        ids = [];
        ids[ids.size] = "specialty_juggernog";
        ids[ids.size] = "specialty_quickrevive";
        ids[ids.size] = "specialty_speedcola";
        ids[ids.size] = "specialty_staminup";
        ids[ids.size] = "specialty_deadshot";
        ids[ids.size] = "specialty_death_perception";
        ids[ids.size] = "specialty_phd_flopper";
        ids[ids.size] = "specialty_vulture_aid";
        ids[ids.size] = "specialty_elemental_pop";
        ids[ids.size] = "specialty_d_mod";
        ids[ids.size] = "specialty_m_mod";
        ids[ids.size] = "specialty_w_mod";
        ids[ids.size] = "specialty_y_mod";
        ids[ids.size] = "specialty_z_mod";
        level.zm_cp_perk_ids = ids;
    }
    return level.zm_cp_perk_ids;
}

zm_classic_perks_start()
{
    level endon(#"game_ended");

    while (!isdefined(level.perk_machine_func))
    {
        waitframe();
    }

    zm_classic_perks_price("specialty_juggernog");

    level utility::registersharedfunc(#"perk_machine", #"hash_dfdcc3fdc88af90c", &zm_classic_perks_machine_price);

    level.perk_machine_func["on_use_choice"] = &zm_classic_perks_wunderfizz_use;
    level.perk_machine_func["per_player_hint_choice"] = &zm_classic_perks_wunderfizz_hint;

    level thread zm_classic_perks_wunderfizz_watch();

    while (!isdefined(level._custom_perks) || !isdefined(level._custom_perks["specialty_choice"]))
    {
        waitframe();
    }

    mode = game_utility::getgametype();
    if (isdefined(mode) && (mode == "zm_rb_r_mod_survival" || mode == "zm_rb_survival"))
    {
        level._custom_perks["specialty_choice"].cost = 1500;
    }
    else
    {
        level._custom_perks["specialty_choice"].cost = 3500;
    }
}

zm_classic_perks_perk_from_hint(hint)
{
    if (!isstruct(hint) || !isarray(level._custom_perks))
    {
        return undefined;
    }

    ids = zm_classic_perks_ids();
    foreach (perk_id in ids)
    {
        info = level._custom_perks[perk_id];
        if (!isdefined(info))
        {
            continue;
        }
        if (isdefined(hint.title) && isdefined(info.hint_name) && hint.title == info.hint_name)
        {
            return perk_id;
        }
        if (isdefined(hint.description) && isdefined(info.buy_description) && hint.description == info.buy_description)
        {
            return perk_id;
        }
        if (isdefined(hint.icon) && isdefined(info.icon) && hint.icon == info.icon)
        {
            return perk_id;
        }
    }
    return undefined;
}

zm_classic_perks_machine_price(usable)
{
    perk = undefined;

    if (isdefined(usable))
    {
        if (isdefined(usable.zm_cp_perk))
        {
            perk = usable.zm_cp_perk;
        }

        if (!isdefined(zm_classic_perks_price(perk)))
        {
            candidate = zm_classic_perks_normalize_perk(usable.script_notify);
            if (isdefined(zm_classic_perks_price(candidate)))
            {
                perk = candidate;
            }
        }
        if (!isdefined(zm_classic_perks_price(perk)) && isdefined(usable.s_perk_machine))
        {
            candidate = zm_classic_perks_normalize_perk(usable.s_perk_machine.script_noteworthy);
            if (isdefined(zm_classic_perks_price(candidate)))
            {
                perk = candidate;
            }
        }
    }

    buyer = undefined;
    if (isdefined(usable))
    {
        buyer = usable.zm_cp_buyer;
    }

    return zm_classic_perks_discount(zm_classic_perks_price(perk), buyer);
}

zm_classic_perks_normalize_perk(perk)
{
    if (!isdefined(perk))
    {
        return undefined;
    }
    if (!isstring(perk))
    {
        return perk;
    }

    if (perk == "talent_juggernog" || perk == "specialty_juggernog" || perk == "juggernog" || perk == "perk_juggernog")
    {
        return "specialty_juggernog";
    }

    if (perk == "talent_quickrevive" || perk == "talent_quick_revive" || perk == "specialty_quickrevive" || perk == "quickrevive" || perk == "quick_revive" || perk == "perk_quickrevive")
    {
        return "specialty_quickrevive";
    }

    if (perk == "talent_speedcola" || perk == "talent_speed_cola" || perk == "specialty_speedcola" || perk == "speedcola" || perk == "speed_cola" || perk == "perk_speedcola")
    {
        return "specialty_speedcola";
    }

    if (perk == "talent_staminup" || perk == "talent_stamin_up" || perk == "specialty_staminup" || perk == "staminup" || perk == "stamin_up" || perk == "perk_staminup")
    {
        return "specialty_staminup";
    }

    if (perk == "talent_deadshot" || perk == "talent_dead_shot" || perk == "specialty_deadshot" || perk == "deadshot" || perk == "dead_shot" || perk == "perk_deadshot")
    {
        return "specialty_deadshot";
    }

    if (perk == "talent_death_perception" || perk == "specialty_death_perception" || perk == "death_perception" || perk == "perk_death_perception")
    {
        return "specialty_death_perception";
    }

    if (perk == "talent_phd_flopper" || perk == "talent_phdflopper" || perk == "specialty_phd_flopper" || perk == "phd_flopper" || perk == "phdflopper" || perk == "perk_phd_flopper")
    {
        return "specialty_phd_flopper";
    }

    if (perk == "talent_vulture_aid" || perk == "talent_vultureaid" || perk == "specialty_vulture_aid" || perk == "vulture_aid" || perk == "vultureaid" || perk == "perk_vulture_aid")
    {
        return "specialty_vulture_aid";
    }

    if (perk == "talent_elemental_pop" || perk == "talent_elementalpop" || perk == "specialty_elemental_pop" || perk == "elemental_pop" || perk == "elementalpop" || perk == "perk_elemental_pop")
    {
        return "specialty_elemental_pop";
    }

    if (perk == "talent_d_mod" || perk == "specialty_d_mod" || perk == "d_mod" || perk == "perk_d_mod")
    {
        return "specialty_d_mod";
    }
    if (perk == "talent_m_mod" || perk == "specialty_m_mod" || perk == "m_mod" || perk == "perk_m_mod")
    {
        return "specialty_m_mod";
    }
    if (perk == "talent_w_mod" || perk == "specialty_w_mod" || perk == "w_mod" || perk == "perk_w_mod")
    {
        return "specialty_w_mod";
    }
    if (perk == "talent_y_mod" || perk == "specialty_y_mod" || perk == "y_mod" || perk == "perk_y_mod")
    {
        return "specialty_y_mod";
    }
    if (perk == "talent_z_mod" || perk == "specialty_z_mod" || perk == "z_mod" || perk == "perk_z_mod")
    {
        return "specialty_z_mod";
    }

    return perk;
}

zm_classic_perks_price(perk)
{
    if (!isdefined(perk))
    {
        return undefined;
    }

    if (!isdefined(level.zm_classic_perk_prices))
    {
        level.zm_classic_perk_prices = [];
        level.zm_classic_perk_prices["specialty_juggernog"] = 2500;
        level.zm_classic_perk_prices["specialty_quickrevive"] = 1500;
        level.zm_classic_perk_prices["specialty_speedcola"] = 3000;
        level.zm_classic_perk_prices["specialty_staminup"] = 2000;
        level.zm_classic_perk_prices["specialty_deadshot"] = 1500;
        level.zm_classic_perk_prices["specialty_death_perception"] = 1500;
        level.zm_classic_perk_prices["specialty_phd_flopper"] = 2000;
        level.zm_classic_perk_prices["specialty_vulture_aid"] = 3000;
        level.zm_classic_perk_prices["specialty_elemental_pop"] = 3500;
        level.zm_classic_perk_prices["specialty_d_mod"] = 2000;
        level.zm_classic_perk_prices["specialty_m_mod"] = 2000;
        level.zm_classic_perk_prices["specialty_w_mod"] = 2000;
        level.zm_classic_perk_prices["specialty_y_mod"] = 4000;
        level.zm_classic_perk_prices["specialty_z_mod"] = 4000;

        mode = game_utility::getgametype();
        if (isdefined(mode) && (mode == "zm_rb_r_mod_survival" || mode == "zm_rb_survival"))
        {
            level.zm_classic_perk_prices["specialty_choice"] = 1500;
        }
        else
        {
            level.zm_classic_perk_prices["specialty_choice"] = 3500;
        }
    }

    if (!isstring(perk))
    {
        foreach (key, value in level.zm_classic_perk_prices)
        {
            hashed = key;
            if (isstring(key))
            {
                hashed = getxhash(key);
            }
            if (hashed == perk)
            {
                return value;
            }
        }
        return undefined;
    }

    return level.zm_classic_perk_prices[perk];
}

zm_classic_perks_discount(price, player)
{
    return price;
}

zm_classic_perks_at_limit(player)
{
    if (level.gametypebundle.perklimit > 0 && isdefined(player.var_468836e5e67e15b4) && player.var_468836e5e67e15b4 >= level.gametypebundle.perklimit)
    {
        return true;
    }
    return false;
}

zm_classic_perks_wunderfizz_watch()
{
    level endon(#"game_ended");
    while (!isdefined(level.a_s_perk_machines))
    {
        waitframe();
    }

    while (true)
    {
        foreach (s_machine in level.a_s_perk_machines)
        {
            if (!isdefined(s_machine) || !isdefined(s_machine.mdl_perk_machine))
            {
                continue;
            }

            interact = s_machine.mdl_perk_machine.interact;
            if (!isdefined(interact))
            {
                continue;
            }
            if (isdefined(interact.zm_classic_perks_bound) && interact.zm_classic_perks_bound)
            {
                continue;
            }

            if (isdefined(s_machine.is_wunderfizz) && s_machine.is_wunderfizz)
            {
                interact interaction::set_interact_use_callback(&zm_classic_perks_wunderfizz_use);
                interact interaction::set_interact_hint_callback(&zm_classic_perks_wunderfizz_hint);
            }
            else
            {
                if (isfunction(interact.interact_hint_callback))
                {
                    interact.zm_cp_orig_hint = interact.interact_hint_callback;
                    interact interaction::set_interact_hint_callback(&zm_classic_perks_hint_wrapper);
                }
                if (isarray(interact.var_d8e3b07237845727) && interact.var_d8e3b07237845727.size > 0 && isfunction(interact.var_d8e3b07237845727[0]))
                {
                    interact.zm_cp_orig_use = interact.var_d8e3b07237845727[0];
                    interact interaction::set_interact_use_callback(&zm_classic_perks_use_wrapper);
                }
            }
            interact.zm_classic_perks_bound = 1;
        }

        wait 0.1;
    }
}

zm_classic_perks_hint_wrapper(usable, player)
{
    orig = usable.zm_cp_orig_hint;
    if (!isfunction(orig))
    {
        return {#string:&"", #type:"HINT_NOBUTTON"};
    }

    hint = [[ orig ]](usable, player);

    if (!isstruct(hint))
    {
        return hint;
    }

    perk = usable.zm_cp_perk;
    if (!isdefined(perk))
    {
        perk = zm_classic_perks_perk_from_hint(hint);
        if (isdefined(perk))
        {
            usable.zm_cp_perk = perk;
        }
        else
        {
            return hint;
        }
    }

    price = zm_classic_perks_price(perk);
    if (!isdefined(price))
    {
        return hint;
    }
    price = zm_classic_perks_discount(price, player);

    if (!isdefined(hint.icon_text_value))
    {
        return hint;
    }
    hint.icon_text_value = price;

    if (isdefined(player) && (!isdefined(hint.interactable) || hint.interactable != 0))
    {
        if (!player currency::can_afford(currency::get_perk_machine_currency(perk), price))
        {
            hint.aux_text = &"shared_hintstrings/not_enough_essence";
            hint.var_776a268784e089af = &"shared_hintstrings/cost_essence_not_enough";
            hint.interactable = 0;
        }
    }
    else if (isdefined(player) && isdefined(hint.aux_text) && hint.aux_text == &"shared_hintstrings/not_enough_essence")
    {
        if (player currency::can_afford(currency::get_perk_machine_currency(perk), price))
        {
            hint.aux_text = undefined;
            hint.var_776a268784e089af = &"shared_hintstrings/cost_essence";
            hint.interactable = 1;
        }
    }

    return hint;
}

zm_classic_perks_use_wrapper(player)
{
    orig = self.zm_cp_orig_use;
    if (!isfunction(orig))
    {
        return;
    }

    if (isdefined(level.gametypebundle.var_5fca731c160ce025) && level.gametypebundle.var_5fca731c160ce025 && isdefined(player))
    {
        perk = self.script_notify;
        s_machine = self.s_perk_machine;
        price = zm_classic_perks_machine_price(self);
        price = zm_classic_perks_discount(price, player);

        if (isdefined(perk) && isdefined(price) && isdefined(s_machine) && isdefined(s_machine.script_currency) && isdefined(level._custom_perks[perk]))
        {
            if (self getscriptablepartstate("base") == "power_off")
            {
                return;
            }
            if (player zombie_perks::has_perk(level._custom_perks[perk].str_perk_root))
            {
                return;
            }
            if (level.var_c139731c583cae6b || !player val::get("allow_zm_perks") || player.interactions_disabled)
            {
                return;
            }
            if (zm_classic_perks_at_limit(player) || player zombie_perks::function_cda78d45986a51a0())
            {
                return;
            }
            if (!player currency::attempt_purchase(s_machine.script_currency, price, 1, undefined, #"perk", perk))
            {
                return;
            }
        }
    }

    self.zm_cp_buyer = player;
    self [[ orig ]](player);
    self.zm_cp_buyer = undefined;
}

zm_classic_perks_wunderfizz_use(player)
{
    if (!isdefined(player))
    {
        return;
    }
    if (zm_mannequin_wunderfizz_active())
    {
        return;
    }
    if (player.interactions_disabled)
    {
        return;
    }
    if (!isdefined(self.s_perk_machine) || !isdefined(self.s_perk_machine.mdl_perk_machine))
    {
        return;
    }
    if (zm_classic_perks_at_limit(player))
    {
        return;
    }

    mdl = self.s_perk_machine.mdl_perk_machine;
    if (mdl getscriptablepartstate("base") == "power_off")
    {
        return;
    }
    if (level.var_c139731c583cae6b || !player val::get("allow_zm_perks"))
    {
        return;
    }

    valid = zombie_perks::get_perks_str_array();
    active = player zombie_perks::get_active_perks_str_array();
    if (isarray(active))
    {
        valid = arrayremove(valid, active);
    }
    if (isdefined(player.disallow_zombie_perks) && player.disallow_zombie_perks.size > 0)
    {
        valid = arrayremove(valid, player.disallow_zombie_perks);
    }
    if (!isarray(valid) || valid.size == 0)
    {
        return;
    }

    perk = zombie_perks::get_random_perk_str(valid);
    if (!isdefined(perk))
    {
        return;
    }

    cost = zm_classic_perks_discount(zm_classic_perks_price("specialty_choice"), player);
    currency = self.s_perk_machine.script_currency;
    if (!isdefined(currency))
    {
        currency = #"essence";
    }
    if (!player currency::attempt_purchase(currency, cost, 1, undefined, #"perk"))
    {
        return;
    }
    if (mdl getscriptablehaspart("use") && mdl getscriptablepartstate("use") == "default")
    {
        mdl setscriptablepartstate("use", "purchase");
    }

    params = spawnstruct();
    params.perk_machine = self;
    player callback::callback("zm_perk_machine_used", params);

    playing = 0;
    gesture = undefined;
    if (isdefined(level._custom_perks[perk]))
    {
        gesture = level._custom_perks[perk].perk_bottle_weapon;
    }
    if (isdefined(gesture))
    {
        player thread zombie_perks::function_13cc8b1c31dda8c4(gesture);
        playing = 1;
    }
    player zombie_perks::give_perk(perk, 1, playing);
    bought = spawnstruct();
    bought.perkref = perk;
    bought.cost = cost;
    bought.currency = currency;
    bought.source = #"wunderfizz";
    player callback::callback("zm_perk_purchased", bought);
}

zm_classic_perks_wunderfizz_hint(usable, player)
{
    if (zm_mannequin_wunderfizz_active())
    {
        return {#string:&"", #type:"HINT_NOICON"};
    }

    if (!isdefined(player) || !isdefined(usable))
    {
        return {#string:&"", #type:"HINT_NOICON"};
    }

    info = level._custom_perks["specialty_choice"];
    if (!isdefined(info))
    {
        return {#string:&"", #type:"HINT_NOICON"};
    }

    cost = zm_classic_perks_discount(zm_classic_perks_price("specialty_choice"), player);
    hint = {#icon_text_value:cost, #var_776a268784e089af:&"shared_hintstrings/cost_essence", #buttoncallout:&"shared_hintstrings/perk_machine_buy", #icon:info.icon, #description:info.buy_description, #title:info.hint_name, #type:"HINT_BUTTON"};

    if (usable getscriptablepartstate("base") == "power_off")
    {
        hint.aux_text = usable.var_4256b14b47d5e763 ?? &"shared_hintstrings/need_power_red";
        hint.interactable = 0;
        return hint;
    }
    if (zm_classic_perks_at_limit(player))
    {
        return {#string:&"", #type:"HINT_NOBUTTON"};
    }
    if (player.interactions_disabled)
    {
        return {#string:&"", #type:"HINT_NOICON"};
    }
    if (!player currency::can_afford(currency::get_perk_machine_currency("specialty_choice"), cost))
    {
        hint.aux_text = &"shared_hintstrings/not_enough_essence";
        hint.var_776a268784e089af = &"shared_hintstrings/cost_essence_not_enough";
        hint.interactable = 0;
    }

    return hint;
}

zm_classic_perks_is_perk_in_list(list, perk)
{
    if (!isarray(list) || !isdefined(perk))
    {
        return false;
    }

    perk_hash = isstring(perk) ? getxhash(perk) : perk;

    foreach (item in list)
    {
        if (!isdefined(item))
        {
            continue;
        }
        if (item == perk)
        {
            return true;
        }
        item_hash = isstring(item) ? getxhash(item) : item;
        if (item_hash == perk_hash)
        {
            return true;
        }
    }
    return false;
}

function private zm_plate_hunter_ammo_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( getsubstr( mode, 0, 3 ) != "zm_" )
    {
        return;
    }

    while ( true )
    {
        if ( isarray( level.zombie_augments ) && isdefined( level.zombie_augments[ #"z_mod_plate_hunter" ] ) )
        {
            level.zombie_augments[ #"z_mod_plate_hunter" ].var_89ebc168e9215b9 = 0;
        }

        foreach ( player in level.players )
        {
            if ( isplayer( player ) && isalive( player ) )
            {
                player zm_plate_hunter_ammo_tick();
            }
        }

        wait 1;
    }
}

function private zm_plate_hunter_ammo_tick()
{
    active = istrue( utility::callsharedfunc( #"zombie", #"hash_3930894d8d2f0ee6", "specialty_z_mod", #"z_mod_plate_hunter" ) );
    pack_mule = istrue( utility::callsharedfunc( #"zombie", #"hash_3930894d8d2f0ee6", "specialty_z_mod", #"z_mod_pack_mule" ) );

    if ( !isdefined( self.zm_ph_last_stock ) )
    {
        self.zm_ph_last_stock = [];
        self.zm_ph_last_clip = [];
    }

    foreach ( w in self getweaponslistprimaries() )
    {
        if ( !isdefined( w ) || !isweapon( w ) || isnullweapon( w ) || w.ismelee || w.isdualwield || weapon::isfistweapon( w ) || weapon::iskillstreakweapon( w ) || weapon::iswonderweapon( w ) )
        {
            continue;
        }

        clip_size = weaponclipsize( w );

        if ( clip_size <= 0 || !isdefined( w.basename ) )
        {
            continue;
        }

        key = w.basename;
        stock = self getweaponammostock( w );
        clip = self getweaponammoclip( w );
        bonus = clip_size * 3;

        if ( issubstr( w.magazine, "beltfed" ) )
        {
            last_clip = self.zm_ph_last_clip[ key ];

            if ( active && clip == clip_size && isdefined( last_clip ) && last_clip < clip_size )
            {
                self setweaponammoclip( w, clip_size + bonus );
                clip = clip_size + bonus;
            }
            else if ( !active && clip > clip_size )
            {
                self setweaponammoclip( w, clip_size );
                clip = clip_size;
            }

            self.zm_ph_last_clip[ key ] = clip;
            self.zm_ph_last_stock[ key ] = stock;
            continue;
        }

        cap = utility::get_max_stock_ammo( w, pack_mule );

        if ( cap <= 0 )
        {
            continue;
        }

        last_stock = self.zm_ph_last_stock[ key ];
        last_clip = self.zm_ph_last_clip[ key ] ?? clip;

        if ( active )
        {
            refilled = stock == cap && ( !isdefined( last_stock ) || last_stock < cap || ( last_stock > cap && ( last_stock - stock ) != ( clip - last_clip ) ) );

            if ( refilled )
            {
                self setweaponammostock( w, cap + bonus );
                stock = cap + bonus;
            }
        }
        else if ( stock > cap )
        {
            self setweaponammostock( w, cap );
            stock = cap;
        }

        self.zm_ph_last_stock[ key ] = stock;
        self.zm_ph_last_clip[ key ] = clip;
    }
}

function private zm_mrp_rewards_start()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.var_966e7e1f42f9a195 ) )
    {
        wait 1;
    }

    level callback::add( #"player_used_item", &zm_mrp_on_item_used );
    level thread zm_mrp_reward_filter();
}

function private zm_mrp_on_item_used( params )
{
    if ( !isdefined( params ) || !isdefined( params.item ) || !params.item.var_ee6e77d4de743d14 )
    {
        return;
    }

    level.zm_mrp_reward_origin = params.item.origin;
    level.zm_mrp_reward_until = gettime() + 10000;
    level thread zm_mrp_bonus_rewards( params.item.origin );
}

function private zm_stun_grenade_item_name()
{
    foreach ( name in [ %"itemspawnentry:zm_sat_item_concussion_grenade", %"itemspawnentry:zm_sat_item_stun_grenade", %"itemspawnentry:zm_t10_item_concussion_grenade" ] )
    {
        if ( isdefined( getscriptbundle( name ) ) )
        {
            return name;
        }
    }

    return undefined;
}

function private zm_mrp_bonus_rewards( origin )
{
    level endon( #"game_ended" );

    mapname = tolower( getdvar( @"g_mapname" ) );
    names = [];

    if ( issubstr( mapname, "firefly" ) )
    {
        stun_name = zm_stun_grenade_item_name();

        if ( isdefined( stun_name ) )
        {
            names[ names.size ] = stun_name;
        }
    }

    if ( issubstr( mapname, "hornet" ) )
    {
        names[ names.size ] = %"itemspawnentry:zm_sat_item_decoy_grenade";
        names[ names.size ] = %"itemspawnentry:zm_sat_item_gas_grenade";
    }

    if ( issubstr( mapname, "ruby" ) )
    {
        names[ names.size ] = %"itemspawnentry:zm_sat_item_molotov";
    }

    if ( names.size == 0 )
    {
        return;
    }

    blocked_with = zm_salvage_unblock( names );

    foreach ( index, name in names )
    {
        bundle = getscriptbundle( name );

        if ( !isdefined( bundle ) )
        {
            continue;
        }

        spawn_origin = origin + ( index * 24, 0, 0 );
        item = undefined;

        for ( attempt = 1; attempt <= 3 && !isdefined( item ); attempt++ )
        {
            spawned = zm_mantis_salvage_spawn_one( name, bundle, spawn_origin );

            if ( isarray( spawned ) )
            {
                foreach ( entry in spawned )
                {
                    if ( isdefined( entry ) )
                    {
                        entry.var_e78811eec0c27aa = 1;
                        item = entry;
                    }
                }
            }
            else if ( isdefined( spawned ) )
            {
                spawned.var_e78811eec0c27aa = 1;
                item = spawned;
            }

            if ( !isdefined( item ) )
            {
                wait 0.5;
            }
        }
    }

    zm_salvage_reblock( names, blocked_with );
}

function private zm_mrp_reward_filter()
{
    level endon( #"game_ended" );

    while ( true )
    {
        level waittill( #"hash_19c9a695e7ebc5cc", spawned_items );

        if ( !isdefined( level.zm_mrp_reward_until ) || gettime() > level.zm_mrp_reward_until || !isarray( spawned_items ) )
        {
            continue;
        }

        foreach ( item in spawned_items )
        {
            if ( isdefined( item ) && distancesquared( item.origin, level.zm_mrp_reward_origin ) < 160000 && zm_mrp_item_blocked( item ) )
            {
                common_item::function_869d7676e359a627( item );
            }
        }
    }
}

function private zm_mrp_item_blocked( item )
{
    if ( isdefined( item.type ) && isstring( item.type ) && ( issubstr( item.type, "aether_tool" ) || issubstr( item.type, "self_revive" ) ) )
    {
        return true;
    }

    itembundle = common_item::function_6b8ff3d5f2688336( item );

    if ( !isdefined( itembundle ) )
    {
        return false;
    }

    if ( isstring( itembundle.ref ) && issubstr( itembundle.ref, "self_revive" ) )
    {
        return true;
    }

    if ( itembundle.subtype === "aethertool" )
    {
        return true;
    }

    if ( zm_bundle_name_has( itembundle, "raygun" ) )
    {
        return false;
    }

    if ( isdefined( itembundle.ref ) )
    {
        meta = level.weaponmetadata[ getxhashasset( itembundle.ref ) ];

        if ( isdefined( meta ) && istrue( meta.ismapwonderweapon ) )
        {
            return false;
        }
    }

    if ( isdefined( itembundle.baseweapon ) && isnumber( itembundle.rarity ) && itembundle.rarity >= 5 )
    {
        if ( isdefined( itembundle.ref ) && level.weaponmetadata[ getxhashasset( itembundle.ref ) ].var_3e8739d232e1b023 )
        {
            return false;
        }

        return true;
    }

    return false;
}

function private zm_crystal_pap_start()
{
    level endon( #"game_ended" );

    for ( i = 0; i < 600 && !utility::issharedfuncdefined( #"pack_a_punch", #"hash_340ee732d0e66af3" ); i++ )
    {
        waitframe();
    }

    if ( !utility::issharedfuncdefined( #"pack_a_punch", #"hash_340ee732d0e66af3" ) || isdefined( level.zm_crystal_pap_wrapped ) )
    {
        return;
    }

    level.zm_crystal_pap_wrapped = 1;
    level.zm_crystal_pap_orig = level.sharedfuncs[ #"pack_a_punch" ][ #"hash_340ee732d0e66af3" ];
    level.sharedfuncs[ #"pack_a_punch" ][ #"hash_340ee732d0e66af3" ] = &zm_crystal_pap_wrapper;
}

function private zm_crystal_pap_wrapper( weapon, pap_index )
{
    result = self [[ level.zm_crystal_pap_orig ]]( weapon, pap_index );

    if ( isplayer( self ) && isnumber( pap_index ) )
    {
        self thread zm_crystal_pap_rarity( pap_index + 1 );
    }

    return result;
}

function private zm_crystal_pap_rarity( pap_level )
{
    self endon( #"disconnect" );

    wait 0.5;

    w = self getcurrentweapon();

    if ( isdefined( w ) && isweapon( w ) && !isnullweapon( w ) )
    {
        self thread zm_pap_force_tier( w, pap_level );
    }
}

function private zm_salvage_bundle_names( count )
{
    b = getscriptbundle( level.gamemodebundle.var_3a97f7b452e7a88c );

    if ( !isdefined( b ) || !isdefined( b.currencyitemspawnlist ) )
    {
        return undefined;
    }

    return common_item::items_selectfromlist( b.currencyitemspawnlist, count );
}

function private zm_salvage_pick_origin( spots )
{
    return spots[ randomint( spots.size ) ];
}

function private zm_salvage_unblock( names )
{
    saved = [];

    foreach ( i, name in names )
    {
        saved[ i ] = level.commonitem.var_60b382bc384e5620[ name ];

        if ( isdefined( saved[ i ] ) )
        {
            common_item::function_6de05583881c7e60( name );
        }
    }

    return saved;
}

function private zm_salvage_reblock( names, saved )
{
    foreach ( i, name in names )
    {
        if ( isdefined( saved[ i ] ) )
        {
            common_item::function_f77c7eedea4fc99f( name, saved[ i ] );
        }
    }
}

function private zm_mantis_salvage_spawn_one( bundle_name, bundle, origin )
{
    saved = undefined;
    bypassed = 0;

    if ( isdefined( level.callbacks ) && isarray( level.callbacks[ #"item_spawn_allowed" ] ) )
    {
        handlers = level.callbacks[ #"item_spawn_allowed" ];
        kept = [];
        saved = handlers;

        foreach ( fields in handlers )
        {
            allowed = 1;

            if ( isarray( fields ) && isfunction( fields[ 0 ] ) )
            {
                if ( fields.size > 1 )
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle }, fields[ 1 ] );
                }
                else
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle } );
                }
            }

            if ( isdefined( allowed ) && !allowed )
            {
                bypassed++;
            }
            else
            {
                kept[ kept.size ] = fields;
            }
        }

        if ( bypassed > 0 )
        {
            level.callbacks[ #"item_spawn_allowed" ] = kept;
        }
    }

    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( origin, ( 0, 0, 0 ) );
    spawnoptions.timedcleanupdisabled = 1;
    spawnoptions.critical = 1;

    previous_skip = level.var_97db93a6b414090d;
    level.var_97db93a6b414090d = 1;

    spawned = common_item::function_61c2c0251e742ffd( bundle_name, 1, spawnoptions );

    level.var_97db93a6b414090d = previous_skip;

    if ( isdefined( saved ) && bypassed > 0 )
    {
        level.callbacks[ #"item_spawn_allowed" ] = saved;
    }

    return spawned;
}

function private zm_mantis_purple_salvage_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        wait 1;
    }

    wait 3;

    mapname = game_utility::getmapname() ?? ( level.script ?? "" );

    is_mantis = issubstr( mapname, "zm_sat_mantis" ) || issubstr( level.script ?? "", "zm_sat_mantis" );
    is_standard = mode == "zm_rb" || mode == "zm_rb_mantis" || mode == "zm_rb_r_mod" || mode == "zm_rb_r_mod_mantis" || mode == "zm_rb_rh_mod" || mode == "zm_rb_rh_mod_mantis" || mode == "zm_guided" || mode == "zm_guided_mantis";

    if ( !is_mantis || !is_standard )
    {
        return;
    }

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    if ( utility::flag_exist( "begin_round_logic" ) )
    {
        level utility::flag_wait( "begin_round_logic" );
    }

    names = zm_salvage_bundle_names( 3 );

    if ( !isarray( names ) || names.size == 0 )
    {
        return;
    }

    bundles = [];

    for ( n = 0; n < names.size; n++ )
    {
        bundles[ n ] = getscriptbundle( names[ n ] );
    }

    if ( !isdefined( bundles[ 0 ] ) && !isdefined( bundles[ 1 ] ) && !isdefined( bundles[ 2 ] ) )
    {
        return;
    }

    purple_origins = [ ( 53449, -32798, -123 ), ( 55222, -31965, -123 ), ( 54208, -32660, -83 ) ];
    blue_origins = [ ( 79449, -31840, -84 ), ( 78490, -31657, 15 ), ( 78611, -31366, -125 ) ];
    green_origins = [ ( 54637, -29352, -120 ), ( 55461, -30551, 15 ), ( 55379, -30920, -83 ) ];

    origins = [ zm_salvage_pick_origin( purple_origins ), zm_salvage_pick_origin( blue_origins ), zm_salvage_pick_origin( green_origins ) ];
    labels = [ "purple", "blue", "green" ];
    first_name = [ 0, 1, 2 ];
    items = [];

    blocked_with = zm_salvage_unblock( names );

    level.zm_allow_salvage_spawn = 1;

    for ( attempt = 1; attempt <= 3; attempt++ )
    {
        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                continue;
            }

            for ( n = first_name[ i ]; n < names.size && !isdefined( items[ i ] ); n++ )
            {
                if ( !isdefined( bundles[ n ] ) )
                {
                    continue;
                }

                spawned = zm_mantis_salvage_spawn_one( names[ n ], bundles[ n ], origins[ i ] );

                if ( isarray( spawned ) )
                {
                    foreach ( item in spawned )
                    {
                        if ( isdefined( item ) )
                        {
                            item.var_e78811eec0c27aa = 1;
                            item.zm_purple_salvage = 1;
                            items[ i ] = item;
                        }
                    }
                }
                else if ( isdefined( spawned ) )
                {
                    spawned.var_e78811eec0c27aa = 1;
                    spawned.zm_purple_salvage = 1;
                    items[ i ] = spawned;
                }
            }
        }

        count = 0;

        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                count++;
            }
        }

        if ( count == origins.size )
        {
            break;
        }

        wait 2;
    }

    zm_salvage_reblock( names, blocked_with );

    waittillframeend();
    waitframe();
    level.zm_allow_salvage_spawn = undefined;
}

function private zm_mantis_cyst_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    if ( !supported_mode() )
    {
        return;
    }

    mapname = game_utility::getmapname() ?? ( level.script ?? "" );

    if ( !issubstr( mapname, "zm_sat_mantis" ) && !issubstr( level.script ?? "", "zm_sat_mantis" ) )
    {
        return;
    }

    if ( utility::flag_exist( "destructibles_ready" ) )
    {
        level utility::flag_wait( "destructibles_ready" );
    }

    destructible::waittill_ready( "sat_destructible_souleater_cyst_01" );

    cysts = destructible::function_c28a5f35d1a84d43( "sat_destructible_souleater_cyst_01" );

    if ( !isarray( cysts ) )
    {
        return;
    }

    foreach ( cyst in cysts )
    {
        if ( !isdefined( cyst ) || cyst destructible::function_31ba46fce3c9ee93() )
        {
            continue;
        }

        cyst destructible::remove_action( "destructible_destruction", destructible_actions::function_ac2ba61b9f601475( #"hash_369d1e10810f20b7" ) );
        cyst destructible::function_12e4a9779677a8b8( "destructible_destruction", { #execute:&zm_cyst_destroyed } );
    }
}

function private zm_cyst_destroyed( params )
{
    if ( !isdefined( self ) || self getscriptablepartstate( "style" ) == "wwq" )
    {
        return;
    }

    player = zm_cyst_nearest_player( self.origin );

    if ( isdefined( player ) )
    {
        amount = ( 1 + randomint( 40 ) ) * 50;
        player points::zm_add_points( amount );
    }

    if ( utility::percent_chance( 4 ) )
    {
        zm_cyst_spawn_wonder_weapon( self.origin, self.angles );
    }

    if ( utility::percent_chance( 6 ) )
    {
        zm_cyst_spawn_perk_item( self.origin, self.angles );
    }
}

function private zm_cyst_nearest_player( origin )
{
    best = undefined;
    best_dist = 0;

    foreach ( player in level.players )
    {
        if ( !isplayer( player ) || !isalive( player ) || player isspectatinganyone() )
        {
            continue;
        }

        dist = distancesquared( player.origin, origin );

        if ( !isdefined( best ) || dist < best_dist )
        {
            best = player;
            best_dist = dist;
        }
    }

    return best;
}

function private zm_cyst_item_bundle( name )
{
    return getscriptbundle( hashcat( %"itemspawnentry:", name ) );
}

function private zm_cyst_wonder_candidates()
{
    return [
        [ "zm_sat_item_weapon_pi_raygun", "zm_t10_item_weapon_pi_raygun" ],
        [ "zm_sat_item_weapon_ww_raygunmark2", "zm_sat_item_weapon_pi_raygunmark2", "zm_sat_item_weapon_ww_raygun_mk2" ],
        [ "zm_sat_item_weapon_ww_firefly", "zm_sat_item_weapon_ww_firefly_zm" ],
        [ "zm_sat_item_weapon_me_ballisticknife", "zm_sat_item_weapon_ww_ballisticknife" ]
    ];
}

function private zm_cyst_spawn_item( name, origin, angles )
{
    bundle = zm_cyst_item_bundle( name );

    if ( !isdefined( bundle ) )
    {
        return undefined;
    }

    bundle_name = hashcat( %"itemspawnentry:", name );
    spawned = zm_ruby_salvage_spawn_one( bundle_name, bundle, getclosestpointonnavmesh( origin ) ?? origin );

    if ( isarray( spawned ) )
    {
        foreach ( item in spawned )
        {
            if ( isdefined( item ) )
            {
                item.var_e78811eec0c27aa = 1;
                item.cleanupdisabled = 1;
            }
        }

        return spawned[ 0 ];
    }

    if ( isdefined( spawned ) )
    {
        spawned.var_e78811eec0c27aa = 1;
        spawned.cleanupdisabled = 1;
    }

    return spawned;
}

function private zm_cyst_spawn_wonder_weapon( origin, angles )
{
    all_groups = zm_cyst_wonder_candidates();
    candidates = [ all_groups[ 0 ], all_groups[ 1 ] ];
    group = candidates[ randomint( candidates.size ) ];

    foreach ( name in group )
    {
        item = zm_cyst_spawn_item( name, origin, angles );

        if ( isdefined( item ) )
        {
            return item;
        }
    }

    return undefined;
}

function private zm_cyst_spawn_perk_item( origin, angles )
{
    perks = [ "zm_t10_item_perk_juggernog", "zm_t10_item_perk_speedcola", "zm_t10_item_perk_staminup", "zm_t10_item_perk_deadshot", "zm_t10_item_perk_death_perception", "zm_t10_item_perk_vulture_aid", "zm_t10_item_perk_elementalpop", "zm_t10_item_perk_d_mod", "zm_t10_item_perk_quickrevive" ];

    for ( i = 0; i < 3; i++ )
    {
        item = zm_cyst_spawn_item( perks[ randomint( perks.size ) ], origin, angles );

        if ( isdefined( item ) )
        {
            return item;
        }
    }

    return undefined;
}

function private zm_mantis_tedd_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        wait 1;
    }

    wait 3;

    mapname = game_utility::getmapname() ?? ( level.script ?? "" );

    is_mantis = issubstr( mapname, "zm_sat_mantis" ) || issubstr( level.script ?? "", "zm_sat_mantis" );
    is_standard = mode == "zm_rb_r_mod" || mode == "zm_rb_r_mod_mantis" || mode == "zm_rb_rh_mod" || mode == "zm_rb_rh_mod_mantis";

    is_ruby = issubstr( mapname, "zm_sat_ruby" ) || issubstr( level.script ?? "", "zm_sat_ruby" );
    is_hornet = issubstr( mapname, "zm_sat_hornet" ) || issubstr( level.script ?? "", "zm_sat_hornet" );

    level.zm_tedd_is_mantis = is_mantis && is_standard;
    level.zm_tedd_is_ruby = is_ruby;
    level.zm_tedd_is_firefly = issubstr( mapname, "firefly" ) || issubstr( level.script ?? "", "firefly" );
    level.zm_tedd_is_hornet = is_hornet;
    level callback::add( "teddtask_complete", &zm_tedd_task_complete );
}

function private zm_tedd_task_complete( params )
{
    task = level.var_a3eb428773fa9129;

    if ( !isdefined( task ) )
    {
        return;
    }

    level.zm_tedd_essence_pending = [];
    level.zm_tedd_loot_gen = ( level.zm_tedd_loot_gen ?? 0 ) + 1;
    level.zm_tedd_loot_window = 1;
    level thread zm_tedd_loot_watch( task, level.zm_tedd_loot_gen );
}

function private zm_tedd_loot_watch( task, gen )
{
    level endon( #"game_ended" );

    wait 0.25;

    chest = isdefined( task.cheststruct ) ? task.cheststruct.chest : undefined;
    waited = 0;

    while ( isdefined( task.cheststruct ) && waited < 180 )
    {
        wait 0.25;
        waited += 0.25;
    }

    if ( isdefined( chest ) && isarray( chest.caches ) )
    {
        foreach ( cache in chest.caches )
        {
            zm_tedd_boost_cache( cache );
        }
    }

    if ( level.zm_tedd_loot_gen === gen )
    {
        level.zm_tedd_loot_window = undefined;
    }
}

function private zm_tedd_boost_cache( cache )
{
    if ( !isdefined( cache ) || !isarray( cache.contents ) )
    {
        return;
    }

    if ( isarray( level.zm_tedd_essence_lootids ) )
    {
        foreach ( entry in cache.contents )
        {
            if ( isdefined( entry ) && isdefined( entry.lootid ) && istrue( level.zm_tedd_essence_lootids[ entry.lootid ] ) )
            {
                entry.quantity = entry.quantity * zm_tedd_essence_mult();

                if ( !isarray( level.zm_tedd_essence_pending ) )
                {
                    level.zm_tedd_essence_pending = [];
                }

                level.zm_tedd_essence_pending[ entry.lootid ] = ( level.zm_tedd_essence_pending[ entry.lootid ] ?? 0 ) + 1;
            }
        }
    }

    forced = [];

    if ( istrue( level.zm_tedd_is_mantis ) && ( level.round_number ?? 0 ) > 20 )
    {
        forced[ forced.size ] = %"itemspawnentry:zm_sat_item_killstreak_dawg";
    }

    if ( istrue( level.zm_tedd_is_hornet ) )
    {
        if ( utility::percent_chance( 40 ) )
        {
            forced[ forced.size ] = %"itemspawnentry:zm_sat_item_decoy_grenade";
        }

        if ( utility::percent_chance( 40 ) )
        {
            forced[ forced.size ] = %"itemspawnentry:zm_sat_item_gas_grenade";
        }
    }

    if ( istrue( level.zm_tedd_is_ruby ) && utility::percent_chance( 40 ) )
    {
        forced[ forced.size ] = %"itemspawnentry:zm_sat_item_molotov";
    }

    if ( istrue( level.zm_tedd_is_firefly ) && utility::percent_chance( 40 ) )
    {
        stun_name = zm_stun_grenade_item_name();

        if ( isdefined( stun_name ) )
        {
            forced[ forced.size ] = stun_name;
        }
    }

    kept = [];

    foreach ( name in forced )
    {
        lootid = zm_tedd_force_item( cache, name, kept );

        if ( isdefined( lootid ) )
        {
            kept[ lootid ] = 1;
        }
    }
}

function private zm_tedd_force_item( cache, name, kept )
{
    bundle = getscriptbundle( name );

    if ( !isdefined( bundle ) )
    {
        return undefined;
    }

    lootid = common_item::function_779887309ec71dfe( bundle );

    if ( !isdefined( lootid ) )
    {
        return undefined;
    }

    if ( common_cache::cache_additem( cache, name, 1, 1 ) )
    {
        return lootid;
    }

    foreach ( entry in cache.contents )
    {
        if ( isdefined( entry ) && isdefined( entry.lootid ) && entry.lootid != 0 && entry.quantity > 0 && !istrue( kept[ entry.lootid ] ) && !( isarray( level.zm_tedd_essence_lootids ) && istrue( level.zm_tedd_essence_lootids[ entry.lootid ] ) ) )
        {
            entry.item = undefined;
            entry.weapondata = undefined;
            entry.lootid = lootid;
            entry.quantity = 1;
            return lootid;
        }
    }

    return undefined;
}

function private zm_is_essence_currency_bundle( itembundle )
{
    return isdefined( itembundle.subtype ) && ( itembundle.subtype == #"essence" || itembundle.subtype == "essence" );
}

function private zm_is_dawg_streak_bundle( itembundle )
{
    if ( isdefined( itembundle.ref ) && ( itembundle.ref == "dawg" || itembundle.ref == #"dawg" ) )
    {
        return true;
    }

    return zm_bundle_name_has( itembundle, "dawg" );
}

function private zm_death_machine_ammo_start()
{
    level endon( #"game_ended" );

    while ( !utility::flag_exist( "death_machine_gun_initialized" ) )
    {
        wait 1;
    }

    level utility::flag_wait( "death_machine_gun_initialized" );

    weaponname = utility::get_scripted_weapon_name( #"death_machine_gun" );

    if ( !isdefined( weaponname ) )
    {
        return;
    }

    weapon = scripted_weapons::get_scripted_weapon_object( #"death_machine_gun" );

    if ( !isdefined( weapon ) || !isweapon( weapon ) || isnullweapon( weapon ) )
    {
        return;
    }

    while ( true )
    {
        foreach ( player in level.players )
        {
            if ( !isdefined( player ) || !isalive( player ) )
            {
                continue;
            }

            has_weapon = player hasweapon( weapon );

            if ( has_weapon && !istrue( player.zm_dm_ammo_buffed ) )
            {
                player.zm_dm_ammo_buffed = 1;
                player thread zm_death_machine_set_ammo( weapon );
            }
            else if ( !has_weapon )
            {
                player.zm_dm_ammo_buffed = undefined;
            }
        }

        wait 0.25;
    }
}

function private zm_death_machine_set_ammo( weapon )
{
    self endon( #"disconnect" );

    wait 0.25;

    if ( !self hasweapon( weapon ) )
    {
        return;
    }

    self setweaponammoclip( weapon, 600 );
    clip = self getweaponammoclip( weapon );
    self setweaponammostock( weapon, int( max( 0, 600 - clip ) ) );
}

function private zm_locust_salvage_spawn_one( bundle_name, bundle, origin )
{
    saved = undefined;
    bypassed = 0;

    if ( isdefined( level.callbacks ) && isarray( level.callbacks[ #"item_spawn_allowed" ] ) )
    {
        handlers = level.callbacks[ #"item_spawn_allowed" ];
        kept = [];
        saved = handlers;

        foreach ( fields in handlers )
        {
            allowed = 1;

            if ( isarray( fields ) && isfunction( fields[ 0 ] ) )
            {
                if ( fields.size > 1 )
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle }, fields[ 1 ] );
                }
                else
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle } );
                }
            }

            if ( isdefined( allowed ) && !allowed )
            {
                bypassed++;
            }
            else
            {
                kept[ kept.size ] = fields;
            }
        }

        if ( bypassed > 0 )
        {
            level.callbacks[ #"item_spawn_allowed" ] = kept;
        }
    }

    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( origin, ( 0, 0, 0 ) );
    spawnoptions.timedcleanupdisabled = 1;
    spawnoptions.critical = 1;

    previous_skip = level.var_97db93a6b414090d;
    level.var_97db93a6b414090d = 1;

    spawned = common_item::function_61c2c0251e742ffd( bundle_name, 1, spawnoptions );

    level.var_97db93a6b414090d = previous_skip;

    if ( isdefined( saved ) && bypassed > 0 )
    {
        level.callbacks[ #"item_spawn_allowed" ] = saved;
    }

    return spawned;
}

function private zm_locust_purple_salvage_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        wait 1;
    }

    wait 3;

    mapname = game_utility::getmapname() ?? ( level.script ?? "" );

    is_locust = issubstr( mapname, "zm_sat_locust" ) || issubstr( level.script ?? "", "zm_sat_locust" );
    is_standard = mode == "zm_rb" || mode == "zm_rb_locust" || mode == "zm_rb_r_mod" || mode == "zm_rb_r_mod_locust" || mode == "zm_rb_rh_mod" || mode == "zm_rb_rh_mod_locust" || mode == "zm_guided" || mode == "zm_guided_locust";

    if ( !is_locust || !is_standard )
    {
        return;
    }

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    if ( utility::flag_exist( "begin_round_logic" ) )
    {
        level utility::flag_wait( "begin_round_logic" );
    }

    names = zm_salvage_bundle_names( 3 );

    if ( !isarray( names ) || names.size == 0 )
    {
        return;
    }

    bundles = [];

    for ( n = 0; n < names.size; n++ )
    {
        bundles[ n ] = getscriptbundle( names[ n ] );
    }

    if ( !isdefined( bundles[ 0 ] ) && !isdefined( bundles[ 1 ] ) && !isdefined( bundles[ 2 ] ) )
    {
        return;
    }

    purple_origins = [ ( 6769, 2349, 96 ), ( 7323, 1373, 328 ), ( 5602, 1266, 104 )];
    blue_origins = [ ( 2363, 751, 218 ), ( -756, 2752, -151 ), ( 301, 2183, 171 ) ];
    green_origins = [ ( 4528, 4326, 89 ), ( 3502, 3276, 88 ), ( 4759, 3228, 212 )];

    origins = [ zm_salvage_pick_origin( purple_origins ), zm_salvage_pick_origin( blue_origins ), zm_salvage_pick_origin( green_origins ) ];
    labels = [ "purple", "blue", "green" ];
    first_name = [ 0, 1, 2 ];
    items = [];

    blocked_with = zm_salvage_unblock( names );

    level.zm_allow_salvage_spawn = 1;

    for ( attempt = 1; attempt <= 3; attempt++ )
    {
        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                continue;
            }

            for ( n = first_name[ i ]; n < names.size && !isdefined( items[ i ] ); n++ )
            {
                if ( !isdefined( bundles[ n ] ) )
                {
                    continue;
                }

                spawned = zm_locust_salvage_spawn_one( names[ n ], bundles[ n ], origins[ i ] );

                if ( isarray( spawned ) )
                {
                    foreach ( item in spawned )
                    {
                        if ( isdefined( item ) )
                        {
                            item.var_e78811eec0c27aa = 1;
                            item.zm_purple_salvage = 1;
                            items[ i ] = item;
                        }
                    }
                }
                else if ( isdefined( spawned ) )
                {
                    spawned.var_e78811eec0c27aa = 1;
                    spawned.zm_purple_salvage = 1;
                    items[ i ] = spawned;
                }
            }
        }

        count = 0;

        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                count++;
            }
        }

        if ( count == origins.size )
        {
            break;
        }

        wait 2;
    }

    zm_salvage_reblock( names, blocked_with );

    waittillframeend();
    waitframe();
    level.zm_allow_salvage_spawn = undefined;
}

function private zm_hornet_salvage_spawn_one( bundle_name, bundle, origin )
{
    saved = undefined;
    bypassed = 0;

    if ( isdefined( level.callbacks ) && isarray( level.callbacks[ #"item_spawn_allowed" ] ) )
    {
        handlers = level.callbacks[ #"item_spawn_allowed" ];
        kept = [];
        saved = handlers;

        foreach ( fields in handlers )
        {
            allowed = 1;

            if ( isarray( fields ) && isfunction( fields[ 0 ] ) )
            {
                if ( fields.size > 1 )
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle }, fields[ 1 ] );
                }
                else
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle } );
                }
            }

            if ( isdefined( allowed ) && !allowed )
            {
                bypassed++;
            }
            else
            {
                kept[ kept.size ] = fields;
            }
        }

        if ( bypassed > 0 )
        {
            level.callbacks[ #"item_spawn_allowed" ] = kept;
        }
    }

    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( origin, ( 0, 0, 0 ) );
    spawnoptions.timedcleanupdisabled = 1;
    spawnoptions.critical = 1;

    previous_skip = level.var_97db93a6b414090d;
    level.var_97db93a6b414090d = 1;

    spawned = common_item::function_61c2c0251e742ffd( bundle_name, 1, spawnoptions );

    level.var_97db93a6b414090d = previous_skip;

    if ( isdefined( saved ) && bypassed > 0 )
    {
        level.callbacks[ #"item_spawn_allowed" ] = saved;
    }

    return spawned;
}

function private zm_hornet_purple_salvage_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        wait 1;
    }

    wait 3;

    mapname = game_utility::getmapname() ?? ( level.script ?? "" );

    is_hornet = issubstr( mapname, "zm_sat_hornet" ) || issubstr( level.script ?? "", "zm_sat_hornet" );
    is_standard = mode == "zm_rb" || mode == "zm_rb_hornet" || mode == "zm_rb_r_mod" || mode == "zm_rb_r_mod_hornet" || mode == "zm_rb_rh_mod" || mode == "zm_rb_rh_mod_hornet" || mode == "zm_guided" || mode == "zm_guided_hornet";

    if ( !is_hornet || !is_standard )
    {
        return;
    }

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    if ( utility::flag_exist( "begin_round_logic" ) )
    {
        level utility::flag_wait( "begin_round_logic" );
    }

    names = zm_salvage_bundle_names( 3 );

    if ( !isarray( names ) || names.size == 0 )
    {
        return;
    }

    bundles = [];

    for ( n = 0; n < names.size; n++ )
    {
        bundles[ n ] = getscriptbundle( names[ n ] );
    }

    if ( !isdefined( bundles[ 0 ] ) && !isdefined( bundles[ 1 ] ) && !isdefined( bundles[ 2 ] ) )
    {
        return;
    }

    purple_origins = [ ( -136, -18296, 912 ), ( -1420, -17686, 1024 ), ( 89, -18756, 1184 ) ];
    blue_origins = [ ( -1641, -22174, 162 ), ( -479, -23277, 195 ), ( -1469, -21793, 263 ) ];
    green_origins = [ ( 3258, -22367, 284 ), ( 864, -22163, 144 ), ( 2882, -21498, 283 ) ];

    origins = [ zm_salvage_pick_origin( purple_origins ), zm_salvage_pick_origin( blue_origins ), zm_salvage_pick_origin( green_origins ) ];
    labels = [ "purple", "blue", "green" ];
    first_name = [ 0, 1, 2 ];
    items = [];

    blocked_with = zm_salvage_unblock( names );

    level.zm_allow_salvage_spawn = 1;

    for ( attempt = 1; attempt <= 3; attempt++ )
    {
        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                continue;
            }

            for ( n = first_name[ i ]; n < names.size && !isdefined( items[ i ] ); n++ )
            {
                if ( !isdefined( bundles[ n ] ) )
                {
                    continue;
                }

                spawned = zm_hornet_salvage_spawn_one( names[ n ], bundles[ n ], origins[ i ] );

                if ( isarray( spawned ) )
                {
                    foreach ( item in spawned )
                    {
                        if ( isdefined( item ) )
                        {
                            item.var_e78811eec0c27aa = 1;
                            item.zm_purple_salvage = 1;
                            items[ i ] = item;
                        }
                    }
                }
                else if ( isdefined( spawned ) )
                {
                    spawned.var_e78811eec0c27aa = 1;
                    spawned.zm_purple_salvage = 1;
                    items[ i ] = spawned;
                }
            }
        }

        count = 0;

        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                count++;
            }
        }

        if ( count == origins.size )
        {
            break;
        }

        wait 2;
    }

    zm_salvage_reblock( names, blocked_with );

    waittillframeend();
    waitframe();
    level.zm_allow_salvage_spawn = undefined;
}

function private zm_scarab_salvage_spawn_one( bundle_name, bundle, origin )
{
    saved = undefined;
    bypassed = 0;

    if ( isdefined( level.callbacks ) && isarray( level.callbacks[ #"item_spawn_allowed" ] ) )
    {
        handlers = level.callbacks[ #"item_spawn_allowed" ];
        kept = [];
        saved = handlers;

        foreach ( fields in handlers )
        {
            allowed = 1;

            if ( isarray( fields ) && isfunction( fields[ 0 ] ) )
            {
                if ( fields.size > 1 )
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle }, fields[ 1 ] );
                }
                else
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle } );
                }
            }

            if ( isdefined( allowed ) && !allowed )
            {
                bypassed++;
            }
            else
            {
                kept[ kept.size ] = fields;
            }
        }

        if ( bypassed > 0 )
        {
            level.callbacks[ #"item_spawn_allowed" ] = kept;
        }
    }

    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( origin, ( 0, 0, 0 ) );
    spawnoptions.timedcleanupdisabled = 1;
    spawnoptions.critical = 1;

    previous_skip = level.var_97db93a6b414090d;
    level.var_97db93a6b414090d = 1;

    spawned = common_item::function_61c2c0251e742ffd( bundle_name, 1, spawnoptions );

    level.var_97db93a6b414090d = previous_skip;

    if ( isdefined( saved ) && bypassed > 0 )
    {
        level.callbacks[ #"item_spawn_allowed" ] = saved;
    }

    return spawned;
}

function private zm_scarab_purple_salvage_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        wait 1;
    }

    wait 3;

    mapname = game_utility::getmapname() ?? ( level.script ?? "" );

    is_scarab = issubstr( mapname, "zm_sat_scarab" ) || issubstr( level.script ?? "", "zm_sat_scarab" );
       is_standard = mode == "zm_rb" || mode == "zm_rb_scarab" || mode == "zm_rb_r_mod" || mode == "zm_rb_r_mod_scarab" || mode == "zm_rb_rh_mod" || mode == "zm_rb_rh_mod_scarab" || mode == "zm_guided" || mode == "zm_guided_scarab";

    if ( !is_scarab || !is_standard )
    {
        return;
    }

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    if ( utility::flag_exist( "begin_round_logic" ) )
    {
        level utility::flag_wait( "begin_round_logic" );
    }

    names = zm_salvage_bundle_names( 3 );

    if ( !isarray( names ) || names.size == 0 )
    {
        return;
    }

    bundles = [];

    for ( n = 0; n < names.size; n++ )
    {
        bundles[ n ] = getscriptbundle( names[ n ] );
    }

    if ( !isdefined( bundles[ 0 ] ) && !isdefined( bundles[ 1 ] ) && !isdefined( bundles[ 2 ] ) )
    {
        return;
    }

    purple_origins = [ ( 3606, 2246, 1734 ), ( 2389, 2323, 1926 ), ( 3752, 272, 1575 ) ];
    blue_origins = [ ( -2655, 1956, 1519 ), ( -2798, 2711, 1539 ), ( -848, 3891, 1603 ) ];
    green_origins = [ ( -6827, -2275, 1520 ), ( -4492, -2495, 1484), ( -5555, 448, 1645 ) ];

    origins = [ zm_salvage_pick_origin( purple_origins ), zm_salvage_pick_origin( blue_origins ), zm_salvage_pick_origin( green_origins ) ];
    labels = [ "purple", "blue", "green" ];
    first_name = [ 0, 1, 2 ];
    items = [];

    blocked_with = zm_salvage_unblock( names );

    level.zm_allow_salvage_spawn = 1;

    for ( attempt = 1; attempt <= 3; attempt++ )
    {
        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                continue;
            }

            for ( n = first_name[ i ]; n < names.size && !isdefined( items[ i ] ); n++ )
            {
                if ( !isdefined( bundles[ n ] ) )
                {
                    continue;
                }

                spawned = zm_scarab_salvage_spawn_one( names[ n ], bundles[ n ], origins[ i ] );

                if ( isarray( spawned ) )
                {
                    foreach ( item in spawned )
                    {
                        if ( isdefined( item ) )
                        {
                            item.var_e78811eec0c27aa = 1;
                            item.zm_purple_salvage = 1;
                            items[ i ] = item;
                        }
                    }
                }
                else if ( isdefined( spawned ) )
                {
                    spawned.var_e78811eec0c27aa = 1;
                    spawned.zm_purple_salvage = 1;
                    items[ i ] = spawned;
                }
            }
        }

        count = 0;

        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                count++;
            }
        }

        if ( count == origins.size )
        {
            break;
        }

        wait 2;
    }

    zm_salvage_reblock( names, blocked_with );

    waittillframeend();
    waitframe();
    level.zm_allow_salvage_spawn = undefined;
}

function private zm_firefly_salvage_spawn_one( bundle_name, bundle, origin )
{
    saved = undefined;
    bypassed = 0;

    if ( isdefined( level.callbacks ) && isarray( level.callbacks[ #"item_spawn_allowed" ] ) )
    {
        handlers = level.callbacks[ #"item_spawn_allowed" ];
        kept = [];
        saved = handlers;

        foreach ( fields in handlers )
        {
            allowed = 1;

            if ( isarray( fields ) && isfunction( fields[ 0 ] ) )
            {
                if ( fields.size > 1 )
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle }, fields[ 1 ] );
                }
                else
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle } );
                }
            }

            if ( isdefined( allowed ) && !allowed )
            {
                bypassed++;
            }
            else
            {
                kept[ kept.size ] = fields;
            }
        }

        if ( bypassed > 0 )
        {
            level.callbacks[ #"item_spawn_allowed" ] = kept;
        }
    }

    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( origin, ( 0, 0, 0 ) );
    spawnoptions.timedcleanupdisabled = 1;
    spawnoptions.critical = 1;

    previous_skip = level.var_97db93a6b414090d;
    level.var_97db93a6b414090d = 1;

    spawned = common_item::function_61c2c0251e742ffd( bundle_name, 1, spawnoptions );

    level.var_97db93a6b414090d = previous_skip;

    if ( isdefined( saved ) && bypassed > 0 )
    {
        level.callbacks[ #"item_spawn_allowed" ] = saved;
    }

    return spawned;
}

function private zm_firefly_purple_salvage_start()
{

    level endon( #"game_ended" );

    mode = wait_for_gametype();

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        wait 1;
    }

    wait 3;

    mapname = game_utility::getmapname() ?? ( level.script ?? "" );

    is_firefly = issubstr( mapname, "zm_sat_firefly" ) || issubstr( level.script ?? "", "zm_sat_firefly" );
    is_standard = mode == "zm_rb" || mode == "zm_rb_firefly" || mode == "zm_rb_r_mod" || mode == "zm_rb_r_mod_firefly" || mode == "zm_rb_rh_mod" || mode == "zm_rb_rh_mod_firefly" || mode == "zm_guided" || mode == "zm_guided_firefly";

    if ( !is_firefly || !is_standard )
    {
        return;
    }

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    if ( utility::flag_exist( "begin_round_logic" ) )
    {
        level utility::flag_wait( "begin_round_logic" );
    }

    names = zm_salvage_bundle_names( 3 );

    if ( !isarray( names ) || names.size == 0 )
    {
        return;
    }

    bundles = [];

    for ( n = 0; n < names.size; n++ )
    {
        bundles[ n ] = getscriptbundle( names[ n ] );
    }

    if ( !isdefined( bundles[ 0 ] ) && !isdefined( bundles[ 1 ] ) && !isdefined( bundles[ 2 ] ) )
    {
        return;
    }

    purple_origins = [ ( 14699, -3178, 618 ), (13343, -2995, 828 ), ( 13126, -4729, 584 ) ];
    blue_origins = [ ( 3495, -2684, 391 ), ( 3649, -2010, -289 ), ( 3436, -14, 374 ) ];
    green_origins = [ ( -6972, -6207, 1576 ), ( -9365, -4751, 1576 ), ( -8712, -6788, 1304 ) ];

    origins = [ zm_salvage_pick_origin( purple_origins ), zm_salvage_pick_origin( blue_origins ), zm_salvage_pick_origin( green_origins ) ];
    labels = [ "purple", "blue", "green" ];
    first_name = [ 0, 1, 2 ];
    items = [];

    blocked_with = zm_salvage_unblock( names );

    level.zm_allow_salvage_spawn = 1;

    for ( attempt = 1; attempt <= 3; attempt++ )
    {
        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                continue;
            }

            for ( n = first_name[ i ]; n < names.size && !isdefined( items[ i ] ); n++ )
            {
                if ( !isdefined( bundles[ n ] ) )
                {
                    continue;
                }

                spawned = zm_ruby_salvage_spawn_one( names[ n ], bundles[ n ], origins[ i ] );

                if ( isarray( spawned ) )
                {
                    foreach ( item in spawned )
                    {
                        if ( isdefined( item ) )
                        {
                            item.var_e78811eec0c27aa = 1;
                            item.zm_purple_salvage = 1;
                            items[ i ] = item;
                        }
                    }
                }
                else if ( isdefined( spawned ) )
                {
                    spawned.var_e78811eec0c27aa = 1;
                    spawned.zm_purple_salvage = 1;
                    items[ i ] = spawned;
                }
            }
        }

        count = 0;

        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                count++;
            }
        }

        if ( count == origins.size )
        {
            break;
        }

        wait 2;
    }

    zm_salvage_reblock( names, blocked_with );

    waittillframeend();
    waitframe();
    level.zm_allow_salvage_spawn = undefined;
}


function private zm_ruby_salvage_spawn_one( bundle_name, bundle, origin )
{
    saved = undefined;
    bypassed = 0;

    if ( isdefined( level.callbacks ) && isarray( level.callbacks[ #"item_spawn_allowed" ] ) )
    {
        handlers = level.callbacks[ #"item_spawn_allowed" ];
        kept = [];
        saved = handlers;

        foreach ( fields in handlers )
        {
            allowed = 1;

            if ( isarray( fields ) && isfunction( fields[ 0 ] ) )
            {
                if ( fields.size > 1 )
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle }, fields[ 1 ] );
                }
                else
                {
                    allowed = level [[ fields[ 0 ] ]]( { #itembundle:bundle } );
                }
            }

            if ( isdefined( allowed ) && !allowed )
            {
                bypassed++;
            }
            else
            {
                kept[ kept.size ] = fields;
            }
        }

        if ( bypassed > 0 )
        {
            level.callbacks[ #"item_spawn_allowed" ] = kept;
        }
    }

    spawnoptions = common_item::items_initspawnoptions_spawnfromposition( origin, ( 0, 0, 0 ) );
    spawnoptions.timedcleanupdisabled = 1;
    spawnoptions.critical = 1;

    previous_skip = level.var_97db93a6b414090d;
    level.var_97db93a6b414090d = 1;

    spawned = common_item::function_61c2c0251e742ffd( bundle_name, 1, spawnoptions );

    level.var_97db93a6b414090d = previous_skip;

    if ( isdefined( saved ) && bypassed > 0 )
    {
        level.callbacks[ #"item_spawn_allowed" ] = saved;
    }

    return spawned;
}

function private zm_ruby_purple_salvage_start()
{
    level endon( #"game_ended" );

    mode = wait_for_gametype();

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        wait 1;
    }

    wait 3;

    mapname = game_utility::getmapname() ?? ( level.script ?? "" );

    is_ruby = issubstr( mapname, "zm_sat_ruby" ) || issubstr( level.script ?? "", "zm_sat_ruby" );
    is_standard = mode == "zm_rb" || mode == "zm_rb_ruby" || mode == "zm_rb_r_mod" || mode == "zm_rb_r_mod_ruby" || mode == "zm_rb_rh_mod" || mode == "zm_rb_rh_mod_ruby" || mode == "zm_guided" || mode == "zm_guided_ruby";

    if ( !is_ruby || !is_standard )
    {
        return;
    }

    while ( !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    if ( utility::flag_exist( "begin_round_logic" ) )
    {
        level utility::flag_wait( "begin_round_logic" );
    }

    names = zm_salvage_bundle_names( 3 );

    if ( !isarray( names ) || names.size == 0 )
    {
        return;
    }

    bundles = [];

    for ( n = 0; n < names.size; n++ )
    {
        bundles[ n ] = getscriptbundle( names[ n ] );
    }

    if ( !isdefined( bundles[ 0 ] ) && !isdefined( bundles[ 1 ] ) && !isdefined( bundles[ 2 ] ) )
    {
        return;
    }

    purple_origins = [ ( 3254, 885, -48 ), ( 1606, 1930, 252 ), ( -435, 1120, 324 ) ];
    blue_origins = [ ( 112, 448, 254 ), ( 203, -1444, 185 ), (245, -2341, 200 ) ];
    green_origins = [ ( 2664, -446, 47 ), ( 1014, -594, 145 ), ( 1259, -1649, 212 ) ];

    origins = [ zm_salvage_pick_origin( purple_origins ), zm_salvage_pick_origin( blue_origins ), zm_salvage_pick_origin( green_origins ) ];
    labels = [ "purple", "blue", "green" ];
    first_name = [ 0, 1, 2 ];
    items = [];

    blocked_with = zm_salvage_unblock( names );

    level.zm_allow_salvage_spawn = 1;

    for ( attempt = 1; attempt <= 3; attempt++ )
    {
        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                continue;
            }

            for ( n = first_name[ i ]; n < names.size && !isdefined( items[ i ] ); n++ )
            {
                if ( !isdefined( bundles[ n ] ) )
                {
                    continue;
                }

                spawned = zm_ruby_salvage_spawn_one( names[ n ], bundles[ n ], origins[ i ] );

                if ( isarray( spawned ) )
                {
                    foreach ( item in spawned )
                    {
                        if ( isdefined( item ) )
                        {
                            item.var_e78811eec0c27aa = 1;
                            item.zm_purple_salvage = 1;
                            items[ i ] = item;
                        }
                    }
                }
                else if ( isdefined( spawned ) )
                {
                    spawned.var_e78811eec0c27aa = 1;
                    spawned.zm_purple_salvage = 1;
                    items[ i ] = spawned;
                }
            }
        }

        count = 0;

        for ( i = 0; i < origins.size; i++ )
        {
            if ( isdefined( items[ i ] ) )
            {
                count++;
            }
        }

        if ( count == origins.size )
        {
            break;
        }

        wait 2;
    }

    zm_salvage_reblock( names, blocked_with );

    waittillframeend();
    waitframe();
    level.zm_allow_salvage_spawn = undefined;
}
