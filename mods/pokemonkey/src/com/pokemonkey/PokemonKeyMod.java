/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  com.mojang.brigadier.CommandDispatcher
 *  net.minecraft.command.CommandSource
 *  net.minecraftforge.common.MinecraftForge
 *  net.minecraftforge.event.RegisterCommandsEvent
 *  net.minecraftforge.eventbus.api.SubscribeEvent
 *  net.minecraftforge.fml.common.Mod
 */
package com.pokemonkey;

import com.mojang.brigadier.CommandDispatcher;
import com.pokemonkey.PokemonKeyCommands;
import net.minecraft.command.CommandSource;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod(value="pokemonkey")
public class PokemonKeyMod {
    public static final String MODID = "pokemonkey";

    public PokemonKeyMod() {
        MinecraftForge.EVENT_BUS.register((Object)this);
    }

    @SubscribeEvent
    public void onRegisterCommands(RegisterCommandsEvent event) {
        PokemonKeyCommands.register((CommandDispatcher<CommandSource>)event.getDispatcher());
    }
}

