/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.client.settings.KeyBinding
 *  net.minecraft.client.util.InputMappings$Type
 *  net.minecraftforge.client.settings.IKeyConflictContext
 *  net.minecraftforge.client.settings.KeyConflictContext
 *  net.minecraftforge.fml.client.registry.ClientRegistry
 */
package com.commandkeys;

import com.commandkeys.CommandConfig;
import net.minecraft.client.settings.KeyBinding;
import net.minecraft.client.util.InputMappings;
import net.minecraftforge.client.settings.IKeyConflictContext;
import net.minecraftforge.client.settings.KeyConflictContext;
import net.minecraftforge.fml.client.registry.ClientRegistry;

public final class KeyBindings {
    private static final KeyBinding[] BINDINGS = new KeyBinding[15];

    private KeyBindings() {
    }

    public static void register() {
        for (int i = 0; i < 15; ++i) {
            int n = i + 1;
            KeyBindings.BINDINGS[i] = new KeyBinding("key.commandkeys.key" + n, (IKeyConflictContext)KeyConflictContext.IN_GAME, InputMappings.Type.KEYSYM, -1, "key.categories.commandkeys");
            ClientRegistry.registerKeyBinding((KeyBinding)BINDINGS[i]);
        }
    }

    public static int count() {
        return BINDINGS.length;
    }

    public static KeyBinding get(int n) {
        if (!CommandConfig.isValidSlot(n)) {
            return null;
        }
        return BINDINGS[n - 1];
    }
}

