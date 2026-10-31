/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.client.Minecraft
 *  net.minecraft.client.settings.KeyBinding
 *  net.minecraftforge.api.distmarker.Dist
 *  net.minecraftforge.client.event.InputEvent$KeyInputEvent
 *  net.minecraftforge.event.TickEvent$ClientTickEvent
 *  net.minecraftforge.event.TickEvent$Phase
 *  net.minecraftforge.eventbus.api.SubscribeEvent
 *  net.minecraftforge.fml.common.Mod$EventBusSubscriber
 */
package com.monkeymacros;

import com.monkeymacros.KeyBindings;
import com.monkeymacros.MacroManager;
import net.minecraft.client.Minecraft;
import net.minecraft.client.settings.KeyBinding;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.InputEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid="monkeymacros", value={Dist.CLIENT})
public final class ClientEvents {
    private ClientEvents() {
    }

    @SubscribeEvent
    public static void onKeyInput(InputEvent.KeyInputEvent event) {
        if (event.getAction() != 1) {
            return;
        }
        Minecraft minecraft = Minecraft.func_71410_x();
        if (minecraft.field_71439_g == null || minecraft.field_71462_r != null) {
            return;
        }
        for (int slot = 0; slot < KeyBindings.MACROS.length; ++slot) {
            KeyBinding keyBinding = KeyBindings.MACROS[slot];
            while (keyBinding.func_151468_f()) {
                MacroManager.trigger(slot + 1);
            }
        }
    }

    @SubscribeEvent
    public static void onClientTick(TickEvent.ClientTickEvent event) {
        if (event.phase == TickEvent.Phase.END) {
            MacroManager.tick();
        }
    }
}
