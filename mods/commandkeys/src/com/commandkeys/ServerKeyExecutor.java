/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.command.CommandSource
 *  net.minecraft.entity.player.ServerPlayerEntity
 *  net.minecraft.server.MinecraftServer
 *  net.minecraft.util.text.ITextComponent
 *  net.minecraft.util.text.TranslationTextComponent
 */
package com.commandkeys;

import com.commandkeys.CommandConfig;
import com.commandkeys.CommandKeys;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import net.minecraft.command.CommandSource;
import net.minecraft.entity.player.ServerPlayerEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.util.text.ITextComponent;
import net.minecraft.util.text.TranslationTextComponent;

public final class ServerKeyExecutor {
    private static final Map<UUID, Long> LAST_TRIGGER = new HashMap<UUID, Long>();

    private ServerKeyExecutor() {
    }

    public static void trigger(ServerPlayerEntity serverPlayerEntity, int n) {
        if (serverPlayerEntity == null || !CommandConfig.isValidSlot(n)) {
            return;
        }
        CommandConfig commandConfig = CommandConfig.CONFIG;
        MinecraftServer minecraftServer = serverPlayerEntity.field_71133_b;
        if (minecraftServer == null) {
            return;
        }
        CommandSource commandSource = serverPlayerEntity.func_195051_bN();
        if (((Boolean)commandConfig.requireOp.get()).booleanValue() && !commandSource.func_197034_c(2)) {
            CommandKeys.LOGGER.debug("Ignored key {} from {} (require_op is on)", (Object)n, (Object)serverPlayerEntity.func_145748_c_().getString());
            return;
        }
        long l = System.currentTimeMillis();
        long l2 = ((Integer)commandConfig.cooldownTicks.get()).longValue() * 50L;
        UUID uUID = serverPlayerEntity.func_110124_au();
        Long l3 = LAST_TRIGGER.get(uUID);
        if (l3 != null && l - l3 < l2) {
            return;
        }
        LAST_TRIGGER.put(uUID, l);
        List<? extends String> list = commandConfig.commandsFor(n);
        if (list.isEmpty()) {
            return;
        }
        int n2 = (Integer)commandConfig.maxCommandsPerKey.get();
        CommandSource commandSource2 = commandSource.func_197033_a(4);
        boolean bl = (Boolean)commandConfig.notifyPlayer.get();
        int n3 = 0;
        for (String string : list) {
            String string2;
            if (n3 >= n2) {
                CommandKeys.LOGGER.warn("Key {} has more than {} commands; the rest were skipped", (Object)n, (Object)n2);
                break;
            }
            if (string == null || (string2 = string.trim()).isEmpty()) continue;
            if (string2.startsWith("/")) {
                string2 = string2.substring(1);
            }
            try {
                minecraftServer.func_195571_aL().func_197059_a(commandSource2, string2);
                ++n3;
            }
            catch (Exception exception) {
                CommandKeys.LOGGER.warn("Key {} command failed: /{}", (Object)n, (Object)string2, (Object)exception);
                if (!bl) continue;
                serverPlayerEntity.func_146105_b((ITextComponent)new TranslationTextComponent("commandkeys.message.failed", new Object[]{string2, String.valueOf(exception.getMessage())}), false);
            }
        }
        if (n3 > 0) {
            CommandKeys.LOGGER.debug("Key {} ran {} command(s) for {}", (Object)n, (Object)n3, (Object)serverPlayerEntity.func_145748_c_().getString());
        }
    }
}

