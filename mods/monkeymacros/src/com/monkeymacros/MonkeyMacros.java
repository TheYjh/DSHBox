/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraftforge.api.distmarker.Dist
 *  net.minecraftforge.fml.ModLoadingContext
 *  net.minecraftforge.fml.common.Mod
 *  net.minecraftforge.fml.config.ModConfig$Type
 *  net.minecraftforge.fml.loading.FMLEnvironment
 */
package com.monkeymacros;

import com.monkeymacros.MacroConfig;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.ModLoadingContext;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import net.minecraftforge.fml.loading.FMLEnvironment;

@Mod(value="monkeymacros")
public final class MonkeyMacros {
    public static final String MOD_ID = "monkeymacros";

    public MonkeyMacros() {
        if (FMLEnvironment.dist == Dist.CLIENT) {
            ModLoadingContext.get().registerConfig(ModConfig.Type.CLIENT, MacroConfig.SPEC);
        }
    }
}
