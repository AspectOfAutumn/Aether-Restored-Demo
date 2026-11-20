#using scripts\common\callbacks;
#using scripts\common\killstreaks\killstreak_shared;
#using scripts\common\powerups;
#using scripts\common\utility;
#using scripts\mp\common\killstreaks\killstreaks;
#using scripts\mp\crafting_table;
#using scripts\mp\currency;
#using scripts\mp\interaction;
#using scripts\mp\loot\common_item;
#using scripts\mp\zm\systems\zm_milestones;
#using scripts\mp\zm\systems\zm_quest;

autoexec zm_disable_zombie_drops_init()
{
    level thread zm_disable_zombie_drops_start();
    level thread zm_remove_milestone_salvage();
    level thread zm_block_direct_salvage_currency();
    level thread zm_fix_maneki_neko_table();
    level thread zm_locust_bernard_drops_init();
}

function private zm_streak_debug( msg )
{
    if ( getdvarint( @"zm_ae_debug", 1 ) == 0 )
    {
        return;
    }

    if ( !isdefined( msg ) || !isstring( msg ) )
    {
        return;
    }

    iprintlnbold( "[AE v6] " + msg );
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

    zm_block_salvage_entry( #"salvage" );
    zm_block_salvage_entry( #"rare_salvage" );

    while ( true )
    {
        if ( isdefined( level.players ) )
        {
            foreach ( player in level.players )
            {
                if ( isdefined( player ) && isdefined( player.currency ) )
                {
                    player.currency[ #"salvage" ] = 0;
                }
            }
        }

        wait 0.25;
    }
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
        player playrumblelooponentity( "low_highfreq" );
        params = { #save_progress:0, #saved_use_object:self, #hud_description:&"hash_13f1ab4a9bad547b", #var_b35caf93a1ae502d:self, #hold_time:5, #craft_reason:#"hash_7a4be9bbf8b8856b" };
        result = player zm_quest::function_e4eb2d1c1bd8fc4e( params );

        if ( istrue( result ) )
        {
            level utility::flag_set( "nya_crafted" );
            level utility::flag_clear( "nya_needs_crafting" );
            zm_spawn_crafted_maneki_item( 1 );
        }

        self.b_interacted = undefined;
        if ( isalive( player ) )
        {
            player stoprumble( "low_highfreq" );
        }
        return;
    }

    if ( !level utility::flag( "crafted_maneki" ) )
    {
        self.b_interacted = 1;
        player playrumblelooponentity( "low_highfreq" );
        params = { #save_progress:1, #saved_use_object:self, #hud_description:&"hash_6cb466194462537b", #var_b35caf93a1ae502d:self, #hold_time:5, #craft_reason:#"ww_quest_key" };
        result = player zm_quest::function_e4eb2d1c1bd8fc4e( params );

        if ( istrue( result ) )
        {
            level utility::flag_set( "crafted_maneki" );
            zm_spawn_crafted_maneki_item( 0 );
        }

        self.b_interacted = undefined;
        if ( isalive( player ) )
        {
            player stoprumble( "low_highfreq" );
        }
        return;
    }

    if ( level utility::flag( "maneki_acquired" ) )
    {
        cost = 1500;
        if ( player currency::attempt_purchase( #"essence", cost, 1, 0, #"custom_maneki_neko" ) )
        {
            player crafting_table::craft_give_equipment( "equip_attractor", "secondary" );
        }
    }
}

function private zm_spawn_crafted_maneki_item( b_glow )
{
    s_loc = utility::getstruct( "hornet_ww_crafted_item" );
    if ( !isdefined( s_loc ) )
    {
        return;
    }

    bundle = getscriptbundle( "itemspawnentry:zm_sat_item_tactical_maneki_neko" );
    if ( !isdefined( bundle ) )
    {
        return;
    }

    spawnoptions = common_item::function_bc5ff2958b71a708( s_loc.origin, s_loc.angles );
    spawnoptions.var_fd47e835523b473f = 1;
    scr_spawn = spawnscriptable( "zm_sat_hornet_ww_vfx", s_loc.origin + ( 0, 0, 2.5 ), s_loc.angles );
    scr_spawn setscriptablepartstate( "visual", "maneki_spawn" );
    waitframe();
    spawned_item = common_item::items_spawnitemfromscriptable( bundle.scriptable, undefined, spawnoptions );

    if ( istrue( b_glow ) && isdefined( spawned_item ) )
    {
        spawned_item setscriptablepartstate( "zmloot_sat_offhand_maneki_neko", "glow" );
    }

    wait 0.5;
    if ( isdefined( scr_spawn ) )
    {
        scr_spawn freescriptable();
    }
}

function private zm_is_locust_bernard_streak( itembundle, item )
{
    if ( isdefined( itembundle ) )
    {
        if ( isdefined( itembundle.ref ) && ( itembundle.ref == "zm_bernard_primary" || itembundle.ref == "zm_bernard_secondary" || itembundle.ref == #"zm_bernard_primary" || itembundle.ref == #"zm_bernard_secondary" ) )
        {
            return true;
        }
        if ( isdefined( itembundle.scriptable ) && ( itembundle.scriptable == %"zmloot_sat_killstreak_zm_bernard_primary" || itembundle.scriptable == %"zmloot_sat_killstreak_zm_bernard_secondary" || itembundle.scriptable == "zmloot_sat_killstreak_zm_bernard_primary" || itembundle.scriptable == "zmloot_sat_killstreak_zm_bernard_secondary" ) )
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

function private zm_locust_bernard_drops_init()
{
    level endon( #"game_ended" );

    while ( !isdefined( level.mapname ) || !isdefined( level.commonitem ) )
    {
        waitframe();
    }

    if ( level.mapname != "zm_sat_locust" )
    {
        return;
    }

    if ( utility::flag_exist( "common_items_init" ) )
    {
        level utility::flag_wait( "common_items_init" );
    }

    level.zm_glocke_picked_up_once = 0;
    level.zm_wb_picked_up_once = 0;

    level callback::add( #"player_item_pickup", &zm_locust_track_bernard_pickup );
    level callback::add( "quest_item_used", &zm_locust_track_bernard_quest_pickup );
    level callback::add( "killstreak_equipped", &zm_locust_track_bernard_equipped );
    level callback::add( #"on_ai_killed", &zm_locust_on_ai_killed_bernard_drop );
    level callback::add( "fergus_override_catch_item", &zm_locust_fishing_bernard_boost );
}

function private zm_locust_track_bernard_pickup( params )
{
    if ( !isdefined( params ) || !isdefined( params.itembundle ) )
    {
        return;
    }

    ref = params.itembundle.ref;
    scr = params.itembundle.scriptable;

    if ( ref == "zm_bernard_primary" || ref == #"zm_bernard_primary" || scr == %"zmloot_sat_locust_quest_bernard_primary" || scr == %"zmloot_sat_killstreak_zm_bernard_primary" )
    {
        level.zm_glocke_picked_up_once = 1;
    }
    if ( ref == "zm_bernard_secondary" || ref == #"zm_bernard_secondary" || scr == %"zmloot_sat_locust_quest_bernard_secondary" || scr == %"zmloot_sat_killstreak_zm_bernard_secondary" )
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
    if ( scr == %"zmloot_sat_locust_quest_bernard_primary" || scr == %"zmloot_sat_killstreak_zm_bernard_primary" )
    {
        level.zm_glocke_picked_up_once = 1;
    }
    if ( scr == %"zmloot_sat_locust_quest_bernard_secondary" || scr == %"zmloot_sat_killstreak_zm_bernard_secondary" )
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
    if ( istrue( level.zm_glocke_picked_up_once ) )
    {
        return true;
    }
    if ( utility::flag_exist( "pap_step_09" ) && utility::flag( "pap_step_09" ) )
    {
        return true;
    }
    if ( utility::flag_exist( "pap_step_12" ) && utility::flag( "pap_step_12" ) )
    {
        return true;
    }
    if ( isdefined( level.fishing_struct ) && istrue( level.fishing_struct.force_glocke ) )
    {
        return true;
    }
    return false;
}

function private zm_is_wb_unlocked()
{
    if ( istrue( level.zm_wb_picked_up_once ) )
    {
        return true;
    }
    if ( utility::flag_exist( "mq_rm_step_08" ) && utility::flag( "mq_rm_step_08" ) )
    {
        return true;
    }
    if ( isdefined( level.fishing_struct ) && istrue( level.fishing_struct.force_wb ) )
    {
        return true;
    }
    return false;
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

function private zm_is_necropincer( ai )
{
    if ( !isdefined( ai ) )
    {
        return false;
    }

    fields = [];

    if ( isdefined( ai.subclass ) )
    {
        fields[ fields.size ] = ai.subclass;
    }

    if ( isdefined( ai.subarchetype ) )
    {
        fields[ fields.size ] = ai.subarchetype;
    }

    if ( isdefined( ai.archetype ) )
    {
        fields[ fields.size ] = ai.archetype;
    }

    if ( isdefined( ai.aitype ) )
    {
        fields[ fields.size ] = ai.aitype;
    }

    foreach ( val in fields )
    {
        if ( val == "zombie_karkinos" || val == "zombie_karkinos_hvt" || val == #"zombie_karkinos" || val == #"zombie_karkinos_hvt" || val == "necropincer" || val == #"necropincer" )
        {
            return true;
        }
        if ( isstring( val ) && ( issubstr( tolower( val ), "karkinos" ) || issubstr( tolower( val ), "necropincer" ) ) )
        {
            return true;
        }
    }

    return false;
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

function private zm_locust_on_ai_killed_bernard_drop( params )
{
    if ( !isdefined( self ) || istrue( self.b_in_spawn_closet ) )
    {
        return;
    }

    if ( isdefined( self.type ) && self.type != "zombie" )
    {
        return;
    }

    entries = zm_get_unlocked_bernard_entries();
    if ( entries.size == 0 )
    {
        return;
    }

    drop_chance = zm_is_necropincer( self ) ? 15 : 2;

    if ( !utility::percent_chance( drop_chance ) )
    {
        return;
    }

    zm_spawn_bernard_streak_at( self.origin, self.angles );
}

function private zm_locust_fishing_bernard_boost( params )
{
    if ( !isdefined( params ) )
    {
        return 0;
    }

    entries = zm_get_unlocked_bernard_entries();
    if ( entries.size == 0 || !utility::percent_chance( 20 ) )
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
    from_origin = params.from_origin ?? end_origin;
    angles = params.angles ?? ( 0, 0, 0 );

    spawn_options = common_item::function_f5dfaa3bbdf99a33( end_origin, from_origin, angles );
    item = common_item::function_61c2c0251e742ffd( itembundle, undefined, spawn_options );

    if ( isdefined( item ) )
    {
        item.var_e78811eec0c27aa = 1;
        return 1;
    }

    return 0;
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

    common_item::function_5734400f32ca9803( "salvage", &zm_on_salvage_item_spawned );
    common_item::function_e08da1075e1758ef( "killstreak", &zm_on_killstreak_item_spawned );
    common_item::function_e08da1075e1758ef( "lethal", &zm_on_equipment_item_spawned );
    common_item::function_e08da1075e1758ef( "tactical", &zm_on_equipment_item_spawned );
    level callback::add( #"hash_8e2728470d1fa87a", &zm_can_spawn_filtered_loot );

    level thread zm_keep_ai_loot_hook();

    wait 1;
    powerups::register_powerup( "free_perk", &zm_streak_powerup_grab, &zm_streak_powerup_should_drop );

    root = powerups::get_powerups_root();
    in_pool = 0;

    if ( isdefined( root ) && isarray( root.powerup_drop_array ) )
    {
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

function private zm_is_salvage_bundle( itembundle )
{
    if ( !isdefined( itembundle ) )
    {
        return false;
    }

    if ( isdefined( itembundle.subtype ) )
    {
        if ( itembundle.subtype == "salvage" || itembundle.subtype == #"salvage" )
        {
            return true;
        }

        if ( isstring( itembundle.subtype ) && issubstr( itembundle.subtype, "salvage" ) )
        {
            return true;
        }
    }

    return false;
}

function private zm_is_quest_equipment( itembundle, item, spawnoptions )
{
    if ( isdefined( spawnoptions ) )
    {
        if ( istrue( spawnoptions.var_fd47e835523b473f ) || istrue( spawnoptions.critical ) )
        {
            return true;
        }
        if ( isdefined( spawnoptions.spawningentity ) && isplayer( spawnoptions.spawningentity ) )
        {
            return true;
        }
    }

    if ( isdefined( item ) )
    {
        if ( istrue( item.var_e78811eec0c27aa ) || istrue( item.var_fd47e835523b473f ) || istrue( item.critical ) )
        {
            return true;
        }
        if ( isdefined( item.type ) && isstring( item.type ) && issubstr( item.type, "maneki" ) )
        {
            return true;
        }
    }

    if ( isdefined( itembundle ) )
    {
        if ( isdefined( itembundle.ref ) && ( itembundle.ref == "equip_attractor" || itembundle.ref == #"equip_attractor" ) )
        {
            return true;
        }
        if ( isdefined( itembundle.scriptable ) && itembundle.scriptable == %"zmloot_sat_offhand_maneki_neko" )
        {
            return true;
        }
    }

    return false;
}

function private zm_can_spawn_filtered_loot( params )
{
    if ( isdefined( params ) && isdefined( params.itembundle ) )
    {
        if ( zm_is_locust_bernard_streak( params.itembundle, undefined ) )
        {
            return true;
        }

        item_type = common_item::function_16e8c106491eeaca( params.itembundle );

        if ( item_type == "killstreak" )
        {
            return false;
        }

        if ( item_type == "lethal" || item_type == "tactical" )
        {
            if ( !zm_is_quest_equipment( params.itembundle, undefined, params.spawnoptions ) )
            {
                return false;
            }
        }

        if ( zm_is_salvage_bundle( params.itembundle ) )
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
        common_item::function_869d7676e359a627( params.item );
    }
}

function private zm_on_equipment_item_spawned( params )
{
    waittillframeend();

    if ( !isdefined( params ) || !isdefined( params.item ) )
    {
        return;
    }

    if ( zm_is_quest_equipment( params.itembundle, params.item, params.spawnoptions ) )
    {
        return;
    }

    common_item::function_869d7676e359a627( params.item );
}

function private zm_on_killstreak_item_spawned( params )
{
    waittillframeend();

    if ( !isdefined( params ) || !isdefined( params.item ) )
    {
        return;
    }

    if ( istrue( params.item.var_e78811eec0c27aa ) || zm_is_locust_bernard_streak( params.itembundle, params.item ) )
    {
        return;
    }

    if ( isdefined( params.spawnoptions ) && isdefined( params.spawnoptions.spawningentity ) && isplayer( params.spawnoptions.spawningentity ) )
    {
        return;
    }

    common_item::function_869d7676e359a627( params.item );
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
        if ( zm_is_locust_bernard_streak( itembundle, item ) )
        {
            continue;
        }

        if ( isdefined( itembundle ) )
        {
            item_type = common_item::function_16e8c106491eeaca( itembundle );
            if ( item_type == "killstreak" || item_type == "lethal" || item_type == "tactical" || zm_is_salvage_bundle( itembundle ) )
            {
                common_item::function_869d7676e359a627( item );
                continue;
            }
        }

        if ( isdefined( item.type ) && isstring( item.type ) && ( item.type == "zmloot_salvage_perplayer" || issubstr( item.type, "salvage" ) || issubstr( item.type, "offhand" ) || issubstr( item.type, "lethal" ) || issubstr( item.type, "tactical" ) ) )
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

function private zm_powerup_streaks()
{
    return [ "death_machine_gun", "war_machine_launcher" ];
}

function private zm_streak_label( streakname )
{
    if ( streakname == "death_machine_gun" )
    {
        return "DEATH_MACHINE";
    }

    return "WAR_MACHINE";
}

function private zm_clear_saved_streak_ammo()
{
    if ( !isdefined( self.pers ) )
    {
        return;
    }

    self.pers[ "held_killstreak_init_count" ] = undefined;

    keys = [ "t10_ks_warmachine", "sat_ks_warmachine", "t10_ks_deathmachine", "sat_ks_deathmachine", "sat_ks_mega_deathmachine_zm" ];
    refs = [ #"death_machine_gun", #"war_machine_launcher" ];

    foreach ( ref in refs )
    {
        weaponname = utility::get_scripted_weapon_name( ref );

        if ( isdefined( weaponname ) )
        {
            keys[ keys.size ] = weaponname;
        }
    }

    stores = [ "held_killstreak_clip_count", "held_killstreak_clip_count_left", "held_killstreak_ammo_count" ];

    foreach ( key in keys )
    {
        foreach ( store in stores )
        {
            if ( isdefined( self.pers[ store ] ) )
            {
                self.pers[ store ][ key ] = undefined;
            }
        }
    }
}

function private zm_award_powerup_streak( streakname )
{
    if ( !isdefined( level.killstreaksetups ) || !isdefined( level.killstreaksetups[ streakname ] ) )
    {
        killstreak_shared::initializekillstreak( getxhash( streakname ) );
    }

    if ( !isdefined( level.killstreaksetups ) || !isdefined( level.killstreaksetups[ streakname ] ) )
    {
        return false;
    }

    self zm_clear_saved_streak_ammo();
    self killstreaks::removekillstreak( 1 );

    streakitem = self killstreaks::awardkillstreak( streakname, "other", undefined, undefined, undefined, 1 );

    if ( !isdefined( streakitem ) )
    {
        return false;
    }

    waitframe();
    self thread killstreaks::triggerkillstreak( streakitem, 1 );

    return true;
}

function private zm_give_powerup_streak()
{
    self endon( #"disconnect" );

    streaks = zm_powerup_streaks();
    index = 0;

    if ( isdefined( self.zm_powerup_streak_index ) )
    {
        index = self.zm_powerup_streak_index + 1;

        if ( index >= streaks.size )
        {
            index = 0;
        }
    }

    self.zm_powerup_streak_index = index;

    streakname = streaks[ index ];
    label = zm_streak_label( streakname );

    if ( self zm_award_powerup_streak( streakname ) )
    {
        zm_streak_debug( label + " awarded" );
    }
    else
    {
        zm_streak_debug( label + " could not be awarded, killstreak is not set up in this mode" );
    }
}
