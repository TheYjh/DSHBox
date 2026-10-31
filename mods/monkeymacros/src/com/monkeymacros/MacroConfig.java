/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraftforge.common.ForgeConfigSpec
 *  net.minecraftforge.common.ForgeConfigSpec$BooleanValue
 *  net.minecraftforge.common.ForgeConfigSpec$Builder
 *  net.minecraftforge.common.ForgeConfigSpec$ConfigValue
 *  net.minecraftforge.common.ForgeConfigSpec$IntValue
 */
package com.monkeymacros;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import net.minecraftforge.common.ForgeConfigSpec;

public final class MacroConfig {
    public static final int MACRO_COUNT = 12;
    private static final List<ForgeConfigSpec.ConfigValue<List<? extends String>>> MACROS = new ArrayList<ForgeConfigSpec.ConfigValue<List<? extends String>>>();
    public static final ForgeConfigSpec.IntValue COMMAND_INTERVAL_TICKS;
    public static final ForgeConfigSpec.BooleanValue SHOW_STATUS_MESSAGES;
    public static final ForgeConfigSpec SPEC;

    private MacroConfig() {
    }

    public static List<String> commands(int slot) {
        if (slot < 1 || slot > 12) {
            return Collections.emptyList();
        }
        ForgeConfigSpec.ConfigValue<List<? extends String>> value = MACROS.get(slot - 1);
        value.clearCache();
        List raw = (List)value.get();
        if (raw == null || raw.isEmpty()) {
            return Collections.emptyList();
        }
        ArrayList<String> commands = new ArrayList<String>(raw.size());
        for (Object entry : raw) {
            if (!(entry instanceof String)) continue;
            commands.add((String)entry);
        }
        return commands;
    }

    public static int commandIntervalTicks() {
        COMMAND_INTERVAL_TICKS.clearCache();
        return (Integer)COMMAND_INTERVAL_TICKS.get();
    }

    public static boolean showStatusMessages() {
        SHOW_STATUS_MESSAGES.clearCache();
        return (Boolean)SHOW_STATUS_MESSAGES.get();
    }

    static {
        ForgeConfigSpec.Builder builder = new ForgeConfigSpec.Builder();
        builder.comment(new String[]{"General settings for Monkey Macros.", "Monkey Macros \u7684\u901a\u7528\u8bbe\u7f6e\u3002"}).push("general");
        COMMAND_INTERVAL_TICKS = builder.comment(new String[]{"Ticks between two commands from the same macro. 1 tick = 0.05 seconds.", "\u540c\u4e00\u6761\u5b8f\u4e2d\u4e24\u6761\u6307\u4ee4\u4e4b\u95f4\u7684\u95f4\u9694\uff08\u6e38\u620f\u523b\uff09\u30021 \u523b = 0.05 \u79d2\u3002", "Increase this if a server kicks you for sending commands too quickly.", "\u5982\u679c\u670d\u52a1\u5668\u56e0\u4e3a\u53d1\u5305\u8fc7\u5feb\u800c\u8e22\u4eba\uff0c\u53ef\u4ee5\u8c03\u5927\u8fd9\u4e2a\u503c\u3002"}).translation("monkeymacros.config.command_interval_ticks").defineInRange("command_interval_ticks", 2, 1, 20);
        SHOW_STATUS_MESSAGES = builder.comment(new String[]{"Show a short message above the hotbar when a macro is triggered.", "\u89e6\u53d1\u5b8f\u65f6\u5728\u5feb\u6377\u680f\u4e0a\u65b9\u663e\u793a\u4e00\u6761\u63d0\u793a\u3002"}).translation("monkeymacros.config.show_status_messages").define("show_status_messages", true);
        builder.pop();
        builder.comment(new String[]{"Macro command lists. Each list is one macro.", "\u5b8f\u6307\u4ee4\u5217\u8868\u3002\u6bcf\u4e2a\u5217\u8868\u5c31\u662f\u4e00\u4e2a\u5b8f\u3002"}).push("macros");
        int slot = 1;
        while (slot <= 12) {
            int displayedSlot = slot++;
            MACROS.add((ForgeConfigSpec.ConfigValue<List<? extends String>>)builder.comment(new String[]{"Commands for macro " + displayedSlot + ". One entry = one command.", "\u5b8f " + displayedSlot + " \u7684\u6307\u4ee4\u96c6\u5408\u3002\u4e00\u6761\u8bb0\u5f55\u5c31\u662f\u4e00\u6761\u6307\u4ee4\u3002", "Commands run in order when the matching key is pressed.", "\u6309\u4e0b\u5bf9\u5e94\u6309\u952e\u540e\uff0c\u8fd9\u4e9b\u6307\u4ee4\u4f1a\u6309\u987a\u5e8f\u6267\u884c\u3002", "Do not type the leading slash. Lines beginning with # are ignored.", "\u4e0d\u9700\u8981\u8f93\u5165\u5f00\u5934\u7684\u659c\u6760\uff1b\u4ee5 # \u5f00\u5934\u7684\u8bb0\u5f55\u4f1a\u88ab\u5ffd\u7565\u3002", "Set the key in Options > Controls > Key Binds > Monkey Macros.", "\u6309\u952e\u5728\u300c\u9009\u9879 > \u63a7\u5236 > \u6309\u952e\u7ed1\u5b9a > Monkey Macros\u300d\u4e2d\u8bbe\u7f6e\u3002"}).translation("monkeymacros.config.macro_" + displayedSlot + "_commands").defineList("macro_" + displayedSlot + "_commands", Collections.emptyList(), value -> value instanceof String && ((String)value).length() <= 256));
        }
        builder.pop();
        SPEC = builder.build();
    }
}
