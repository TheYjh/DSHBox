/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraftforge.fml.ModLoadingContext
 *  net.minecraftforge.fml.common.Mod
 *  net.minecraftforge.fml.config.ModConfig$Type
 *  org.apache.logging.log4j.LogManager
 *  org.apache.logging.log4j.Logger
 */
package com.commandkeys;

import com.commandkeys.CommandConfig;
import com.commandkeys.CommandKeysNetwork;
import net.minecraftforge.fml.ModLoadingContext;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

@Mod(value="commandkeys")
public final class CommandKeys {
    public static final String MOD_ID = "commandkeys";
    public static final String VERSION = "1.0.2";
    public static final Logger LOGGER = LogManager.getLogger();

    public CommandKeys() {
        CommandKeysNetwork.register();
        ModLoadingContext.get().registerConfig(ModConfig.Type.COMMON, CommandConfig.SPEC);
    }
}

