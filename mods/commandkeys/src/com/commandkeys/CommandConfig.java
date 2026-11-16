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
package com.commandkeys;

import java.util.Collections;
import java.util.List;
import net.minecraftforge.common.ForgeConfigSpec;

public final class CommandConfig {
    public static final int KEY_COUNT = 15;
    public static final ForgeConfigSpec SPEC;
    public static final CommandConfig CONFIG;
    private final ForgeConfigSpec.ConfigValue<List<? extends String>>[] commands = new ForgeConfigSpec.ConfigValue[15];
    public final ForgeConfigSpec.BooleanValue requireOp;
    public final ForgeConfigSpec.IntValue cooldownTicks;
    public final ForgeConfigSpec.BooleanValue notifyPlayer;
    public final ForgeConfigSpec.IntValue maxCommandsPerKey;

    private CommandConfig(ForgeConfigSpec.Builder builder) {
        builder.comment(new String[]{"\u6bcf\u4e2a\u6309\u952e\u6309\u4e0b\u65f6\u8981\u6267\u884c\u7684\u6307\u4ee4\u3002\u4e00\u6761\u4e00\u884c\uff0c\u5f00\u5934\u7684 / \u53ef\u5199\u53ef\u4e0d\u5199\u3002", "\u6307\u4ee4\u5728\u670d\u52a1\u7aef\u6267\u884c\uff08\u6743\u9650\u7b49\u7ea7 4\uff09\uff0c\u6240\u4ee5\u4e0d\u9700\u8981\u5f00\u4f5c\u5f0a\uff0c\u4e5f\u4e0d\u9700\u8981 OP\u3002", "Commands executed when the key is pressed. One command per line, leading '/' optional."}).push("keys");
        for (int i = 0; i < 15; ++i) {
            int n = i + 1;
            this.commands[i] = builder.comment("\u6309\u952e " + n + "\uff08Key " + n + "\uff09").defineList("key" + n + "_commands", Collections.emptyList(), object -> object instanceof String);
        }
        builder.pop();
        builder.comment("\u670d\u52a1\u7aef\u6267\u884c\u76f8\u5173 / Server-side execution").push("server");
        this.requireOp = builder.comment(new String[]{"true \u65f6\u53ea\u6709\u6743\u9650\u7b49\u7ea7 >= 2\uff08OP\uff09\u7684\u73a9\u5bb6\u80fd\u89e6\u53d1\u6309\u952e", "If true, only players with permission level >= 2 may trigger keys."}).define("require_op", false);
        this.cooldownTicks = builder.comment(new String[]{"\u4e24\u6b21\u89e6\u53d1\u4e4b\u95f4\u7684\u6700\u77ed\u95f4\u9694\uff08tick\uff0c20 tick = 1 \u79d2\uff09\uff0c\u7528\u6765\u6321\u8fde\u70b9/\u53d1\u5305\u5237\u6307\u4ee4", "Minimum ticks between two triggers (20 ticks = 1 second)."}).defineInRange("cooldown_ticks", 4, 0, 200);
        this.maxCommandsPerKey = builder.comment(new String[]{"\u5355\u4e2a\u6309\u952e\u4e00\u6b21\u6700\u591a\u6267\u884c\u51e0\u6761\u6307\u4ee4\uff0c\u8d85\u51fa\u7684\u4f1a\u88ab\u5ffd\u7565", "Hard cap on how many commands one key may run at a time."}).defineInRange("max_commands_per_key", 16, 1, 256);
        this.notifyPlayer = builder.comment(new String[]{"\u6267\u884c\u5931\u8d25\u65f6\u662f\u5426\u5728\u804a\u5929\u680f\u544a\u8bc9\u73a9\u5bb6", "Whether to tell the player in chat when a command fails."}).define("notify_player", true);
        builder.pop();
    }

    public List<? extends String> commandsFor(int n) {
        if (n < 1 || n > 15) {
            return Collections.emptyList();
        }
        List list = (List)this.commands[n - 1].get();
        return list == null ? Collections.emptyList() : list;
    }

    public static boolean isValidSlot(int n) {
        return n >= 1 && n <= 15;
    }

    static {
        ForgeConfigSpec.Builder builder = new ForgeConfigSpec.Builder();
        CONFIG = new CommandConfig(builder);
        SPEC = builder.build();
    }
}

