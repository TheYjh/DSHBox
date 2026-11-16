/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.util.ResourceLocation
 *  net.minecraftforge.fml.common.Mod
 *  net.minecraftforge.fml.network.NetworkRegistry
 */
package local.pixelmon.greninja;

import net.minecraft.util.ResourceLocation;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.network.NetworkRegistry;

@Mod(value="ohmygod_greninja")
public final class OhMyGodGreninja {
    public static final String MOD_ID = "ohmygod_greninja";
    private static final String PROTOCOL_VERSION = "1";

    public OhMyGodGreninja() {
        NetworkRegistry.newSimpleChannel((ResourceLocation)new ResourceLocation(MOD_ID, "mode"), () -> PROTOCOL_VERSION, PROTOCOL_VERSION::equals, PROTOCOL_VERSION::equals);
    }
}

