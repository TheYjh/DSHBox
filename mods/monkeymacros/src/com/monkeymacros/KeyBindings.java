/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.client.settings.KeyBinding
 *  net.minecraft.client.util.InputMappings$Type
 *  net.minecraftforge.client.settings.IKeyConflictContext
 *  net.minecraftforge.client.settings.KeyConflictContext
 */
package com.monkeymacros;

import net.minecraft.client.settings.KeyBinding;
import net.minecraft.client.util.InputMappings;
import net.minecraftforge.client.settings.IKeyConflictContext;
import net.minecraftforge.client.settings.KeyConflictContext;

public final class KeyBindings {
    public static final String CATEGORY = "key.categories.monkeymacros";
    public static final KeyBinding[] MACROS = new KeyBinding[12];

    private KeyBindings() {
    }

    static {
        for (int slot = 0; slot < 12; ++slot) {
            KeyBindings.MACROS[slot] = new KeyBinding("key.monkeymacros.macro_" + (slot + 1), (IKeyConflictContext)KeyConflictContext.IN_GAME, InputMappings.Type.KEYSYM, -1, CATEGORY);
        }
    }
}
