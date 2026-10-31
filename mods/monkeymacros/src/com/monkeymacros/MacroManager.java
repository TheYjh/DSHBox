/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.client.Minecraft
 *  net.minecraft.util.text.ITextComponent
 *  net.minecraft.util.text.TranslationTextComponent
 *  org.apache.logging.log4j.LogManager
 *  org.apache.logging.log4j.Logger
 */
package com.monkeymacros;

import com.monkeymacros.MacroConfig;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.util.text.ITextComponent;
import net.minecraft.util.text.TranslationTextComponent;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public final class MacroManager {
    private static final Logger LOGGER = LogManager.getLogger((String)"monkeymacros");
    private static final Deque<String> PENDING = new ArrayDeque<String>();
    private static final int MAX_PENDING = 512;
    private static int delayTicks;

    private MacroManager() {
    }

    public static void trigger(int slot) {
        Minecraft minecraft = Minecraft.func_71410_x();
        if (minecraft.field_71439_g == null) {
            return;
        }
        List<String> commands = MacroManager.collectCommands(slot);
        if (commands.isEmpty()) {
            if (MacroConfig.showStatusMessages()) {
                MacroManager.show(minecraft, (ITextComponent)new TranslationTextComponent("monkeymacros.message.empty", new Object[]{slot}));
            }
            return;
        }
        int free = 512 - PENDING.size();
        if (free <= 0) {
            if (MacroConfig.showStatusMessages()) {
                MacroManager.show(minecraft, (ITextComponent)new TranslationTextComponent("monkeymacros.message.queue_full"));
            }
            return;
        }
        int added = 0;
        for (String command : commands) {
            if (added >= free) break;
            PENDING.addLast(command);
            ++added;
        }
        if (MacroConfig.showStatusMessages()) {
            if (added < commands.size()) {
                MacroManager.show(minecraft, (ITextComponent)new TranslationTextComponent("monkeymacros.message.partial", new Object[]{slot, added, commands.size()}));
            } else {
                MacroManager.show(minecraft, (ITextComponent)new TranslationTextComponent("monkeymacros.message.queued", new Object[]{slot, added}));
            }
        }
        LOGGER.debug("Queued {} command(s) from macro {} ({} waiting)", (Object)added, (Object)slot, (Object)PENDING.size());
    }

    public static void tick() {
        Minecraft minecraft = Minecraft.func_71410_x();
        if (minecraft.field_71439_g == null || minecraft.field_71441_e == null) {
            PENDING.clear();
            delayTicks = 0;
            return;
        }
        if (PENDING.isEmpty()) {
            delayTicks = 0;
            return;
        }
        if (delayTicks > 0) {
            --delayTicks;
            return;
        }
        String command = PENDING.pollFirst();
        if (command == null) {
            return;
        }
        try {
            minecraft.field_71439_g.func_71165_d(command);
            LOGGER.debug("Sent macro command: {}", (Object)command);
        }
        catch (RuntimeException exception) {
            LOGGER.error("Failed to send macro command: {}", (Object)command, (Object)exception);
        }
        delayTicks = Math.max(1, MacroConfig.commandIntervalTicks()) - 1;
    }

    public static int pendingCount() {
        return PENDING.size();
    }

    private static List<String> collectCommands(int slot) {
        ArrayList<String> result = new ArrayList<String>();
        for (String raw : MacroConfig.commands(slot)) {
            if (raw == null) continue;
            for (String part : raw.split("\\r?\\n")) {
                String command = part.trim();
                if (command.isEmpty() || command.startsWith("#")) continue;
                if (!command.startsWith("/")) {
                    command = "/" + command;
                }
                if (command.length() > 256 || command.equals("/")) {
                    LOGGER.warn("Skipping invalid or too long command in macro {}: {}", (Object)slot, (Object)command);
                    continue;
                }
                result.add(command);
            }
        }
        return result;
    }

    private static void show(Minecraft minecraft, ITextComponent message) {
        if (minecraft.field_71439_g != null) {
            minecraft.field_71439_g.func_146105_b(message, true);
        }
    }
}
