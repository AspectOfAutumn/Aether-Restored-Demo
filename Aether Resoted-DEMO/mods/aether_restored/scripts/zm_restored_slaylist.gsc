#using script_0df8c162c8d4de02;
#using scripts\mp\common\utility\musicbank_utility;

autoexec zm_slaylist_times_init()
{
    level thread zm_slaylist_times_start();
    level thread zm_slaylist_times_guard();
}

zm_slaylist_times_lengths()
{
    return [291, 274, 420, 371, 426, 491, 375, 259, 440, 431, 420, 270, 387, 234, 465, 263, 262, 420, 260, 420, 427, 284, 268];
}

zm_slaylist_times_delays()
{
    return [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
}
zm_slaylist_times_priority()
{
    return 100000;
}

zm_slaylist_times_blocked_events()
{
    return [#"round_start_first", #"round_start", #"round_start_short", #"round_end", #"round_end_short", #"hash_638ae84b7500610c", #"specialround_loop", #"exfil"];
}

zm_slaylist_times_start()
{
    level endon(#"game_ended");
    for (tries = 0; tries < 120; tries++)
    {
        wait 0.5;
        changed = zm_slaylist_times_apply(#"default");
        changed = changed + zm_slaylist_times_apply(#"default_rbz");
        if (changed > 0)
        {
            iprintln("slaylist times applied to " + changed + " events");
            return;
        }
    }
}

zm_slaylist_times_apply(statekey)
{
    bank = audio_utility::function_72015cb5d5677cad("musicbank_bundles", statekey);
    if (!isdefined(bank) || !isarray(bank.musiceventdict))
    {
        return 0;
    }
    lengths = zm_slaylist_times_lengths();
    delays = zm_slaylist_times_delays();
    priority = zm_slaylist_times_priority();
    changed = 0;
    for (i = 0; i < lengths.size; i++)
    {
        number = i + 1;
        event = bank.musiceventdict[getxhash("bgb_slaylist_" + number)];
        if (!isdefined(event))
        {
            continue;
        }
        event.eventlength = lengths[i];
        event.eventpriority = priority;
        if (isdefined(delays[i]))
        {
            event.eventstartdelay = delays[i];
        }
        changed++;
    }
    return changed;
}

zm_slaylist_times_number(id)
{
    if (!isdefined(id))
    {
        return 0;
    }
    for (i = 1; i <= 23; i++)
    {
        name = "bgb_slaylist_" + i;
        if (id == name || id == getxhash(name))
        {
            return i;
        }
    }
    return 0;
}

zm_slaylist_times_guard()
{
    level endon(#"game_ended");
    while (true)
    {
        wait 0.1;
        any_active = 0;
        foreach (player in level.players)
        {
            if (!isplayer(player))
            {
                continue;
            }
            if (!isdefined(player.zm_slaylist_clear_watch))
            {
                player.zm_slaylist_clear_watch = 1;
                player thread zm_slaylist_times_clear_watch();
            }
            player zm_slaylist_times_apply_player_bank();
            if (player zm_slaylist_times_guard_player())
            {
                any_active = 1;
            }
        }
        zm_slaylist_times_block_events(any_active);
    }
}

zm_slaylist_times_apply_player_bank()
{
    if (!isdefined(self.musicbankparams))
    {
        return;
    }
    key = self.musicbankparams["musicbank"] ?? self.musicbankparams["musicbankdefault"];
    if (!isdefined(key))
    {
        return;
    }
    if (!isdefined(level.zm_slaylist_apply_tries))
    {
        level.zm_slaylist_apply_tries = [];
    }
    tries = level.zm_slaylist_apply_tries[key] ?? 0;
    if (tries < 0 || tries >= 30)
    {
        return;
    }
    if (zm_slaylist_times_apply(key) > 0)
    {
        level.zm_slaylist_apply_tries[key] = -1;
        return;
    }
    level.zm_slaylist_apply_tries[key] = tries + 1;
}

zm_slaylist_times_block_events(active)
{
    if (active && !istrue(level.zm_slaylist_blocked))
    {
        level.zm_slaylist_blocked = 1;
        level.zm_slaylist_added = [];
        foreach (event in zm_slaylist_times_blocked_events())
        {
            if (!arraycontains(level.var_122f0ec859569086.disabled_events, event))
            {
                musicbank_utility::function_683e33ddcb824d18(event);
                level.zm_slaylist_added[level.zm_slaylist_added.size] = event;
            }
        }
        return;
    }
    if (!active && istrue(level.zm_slaylist_blocked))
    {
        level.zm_slaylist_blocked = 0;
        foreach (event in level.zm_slaylist_added)
        {
            musicbank_utility::function_e146ca500a84f52f(event);
        }
        level.zm_slaylist_added = [];
        if (istrue(level.var_6c65aec37d0dcb9d))
        {
            musicbank_utility::function_5aca66c390aa347d(level.players, #"specialround_loop");
        }
    }
}

zm_slaylist_times_clear_watch()
{
    self endon(#"disconnect");
    while (true)
    {
        self waittill(#"hash_25bfa197e16df507");
        self.zm_slaylist_event = undefined;
    }
}

zm_slaylist_times_guard_player()
{
    if (!isdefined(self.musicbankparams))
    {
        return 0;
    }
    active = self.musicbankparams["activeEvent"];
    number = zm_slaylist_times_number(active);
    if (number > 0)
    {
        if (!isdefined(self.zm_slaylist_event) || self.zm_slaylist_event != active)
        {
            lengths = zm_slaylist_times_lengths();
            delays = zm_slaylist_times_delays();
            self.zm_slaylist_event = active;
            self.zm_slaylist_until = gettime() + int(((delays[number - 1] ?? 1) + lengths[number - 1] + 1) * 1000);
            self.musicbankparams["activeEventPriority"] = zm_slaylist_times_priority();
            return 1;
        }
        if (gettime() >= self.zm_slaylist_until)
        {
            self.musicbankparams["activeEvent"] = undefined;
            self.musicbankparams["activeEventPriority"] = undefined;
            self.zm_slaylist_event = undefined;
            return 0;
        }
        self.musicbankparams["activeEventPriority"] = zm_slaylist_times_priority();
        return 1;
    }
    if (!isdefined(self.zm_slaylist_event))
    {
        return 0;
    }
    if (gettime() >= self.zm_slaylist_until)
    {
        self.zm_slaylist_event = undefined;
        return 0;
    }
    if (!isdefined(active))
    {
        self.musicbankparams["activeEvent"] = self.zm_slaylist_event;
        self.musicbankparams["activeEventPriority"] = zm_slaylist_times_priority();
        return 1;
    }
    self.zm_slaylist_event = undefined;
    return 0;
}
