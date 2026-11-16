/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.client.Minecraft
 *  net.minecraft.client.settings.KeyBinding
 *  net.minecraftforge.api.distmarker.Dist
 *  net.minecraftforge.client.event.InputEvent$KeyInputEvent
 *  net.minecraftforge.eventbus.api.SubscribeEvent
 *  net.minecraftforge.fml.common.Mod$EventBusSubscriber
 */
package com.commandkeys;

import com.commandkeys.CommandKeysNetwork;
import com.commandkeys.ExecuteKeyPacket;
import com.commandkeys.KeyBindings;
import net.minecraft.client.Minecraft;
import net.minecraft.client.settings.KeyBinding;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.InputEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid="commandkeys", value={Dist.CLIENT})
public final class ClientEvents {
    private ClientEvents() {
    }

    @SubscribeEvent
    public static void onKeyInput(InputEvent.KeyInputEvent keyInputEvent) {
        if (keyInputEvent.getAction() != 1) {
            return;
        }
        Minecraft minecraft = Minecraft.func_71410_x();
        if (minecraft.field_71439_g == null || minecraft.field_71441_e == null || minecraft.field_71462_r != null) {
            return;
        }
        for (int i = 1; i <= KeyBindings.count(); ++i) {
            KeyBinding keyBinding = KeyBindings.get(i);
            if (keyBinding == null || !keyBinding.func_151468_f()) continue;
            CommandKeysNetwork.CHANNEL.sendToServer((Object)new ExecuteKeyPacket(i));
        }
    }
}

