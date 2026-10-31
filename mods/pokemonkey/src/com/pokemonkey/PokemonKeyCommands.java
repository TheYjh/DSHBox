/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  com.mojang.brigadier.CommandDispatcher
 *  com.mojang.brigadier.arguments.ArgumentType
 *  com.mojang.brigadier.arguments.IntegerArgumentType
 *  com.mojang.brigadier.arguments.StringArgumentType
 *  com.mojang.brigadier.builder.LiteralArgumentBuilder
 *  com.mojang.brigadier.context.CommandContext
 *  com.mojang.brigadier.exceptions.CommandSyntaxException
 *  com.mojang.brigadier.suggestion.SuggestionProvider
 *  com.mojang.brigadier.suggestion.SuggestionsBuilder
 *  com.pixelmonmod.pixelmon.api.pokemon.Pokemon
 *  com.pixelmonmod.pixelmon.api.pokemon.stats.BattleStatsType
 *  com.pixelmonmod.pixelmon.api.pokemon.stats.EVStore
 *  com.pixelmonmod.pixelmon.api.pokemon.stats.IVStore
 *  com.pixelmonmod.pixelmon.api.storage.PlayerPartyStorage
 *  com.pixelmonmod.pixelmon.api.storage.StorageProxy
 *  net.minecraft.command.CommandSource
 *  net.minecraft.command.Commands
 *  net.minecraft.command.ISuggestionProvider
 *  net.minecraft.command.arguments.EntityArgument
 *  net.minecraft.entity.player.ServerPlayerEntity
 *  net.minecraft.util.text.IFormattableTextComponent
 *  net.minecraft.util.text.ITextComponent
 *  net.minecraft.util.text.StringTextComponent
 *  net.minecraft.util.text.TextFormatting
 */
package com.pokemonkey;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.ArgumentType;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import com.mojang.brigadier.suggestion.SuggestionProvider;
import com.mojang.brigadier.suggestion.SuggestionsBuilder;
import com.pixelmonmod.pixelmon.api.pokemon.Pokemon;
import com.pixelmonmod.pixelmon.api.pokemon.stats.BattleStatsType;
import com.pixelmonmod.pixelmon.api.pokemon.stats.EVStore;
import com.pixelmonmod.pixelmon.api.pokemon.stats.IVStore;
import com.pixelmonmod.pixelmon.api.storage.PlayerPartyStorage;
import com.pixelmonmod.pixelmon.api.storage.StorageProxy;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import net.minecraft.command.CommandSource;
import net.minecraft.command.Commands;
import net.minecraft.command.ISuggestionProvider;
import net.minecraft.command.arguments.EntityArgument;
import net.minecraft.entity.player.ServerPlayerEntity;
import net.minecraft.util.text.IFormattableTextComponent;
import net.minecraft.util.text.ITextComponent;
import net.minecraft.util.text.StringTextComponent;
import net.minecraft.util.text.TextFormatting;

public final class PokemonKeyCommands {
    private static final String ALL = "all";
    private static final Map<String, BattleStatsType> STATS = new LinkedHashMap<String, BattleStatsType>();
    private static final Map<String, String> LABELS = new LinkedHashMap<String, String>();
    private static final List<String> KEYS;
    private static final SuggestionProvider<CommandSource> STAT_SUGGESTIONS;

    private static void add(String key, BattleStatsType type, String label) {
        STATS.put(key, type);
        LABELS.put(key, label);
    }

    private PokemonKeyCommands() {
    }

    public static void register(CommandDispatcher<CommandSource> dispatcher) {
        dispatcher.register(PokemonKeyCommands.build("pokemonkey", Mode.EV));
        dispatcher.register(PokemonKeyCommands.build("pokemonkey2", Mode.IV));
    }

    private static LiteralArgumentBuilder<CommandSource> build(String name, Mode mode) {
        return (LiteralArgumentBuilder)((LiteralArgumentBuilder)((LiteralArgumentBuilder)Commands.func_197057_a((String)name).requires(src -> src.func_197034_c(2))).then(Commands.func_197056_a((String)"player", (ArgumentType)EntityArgument.func_197096_c()).then(Commands.func_197056_a((String)"slot", (ArgumentType)IntegerArgumentType.integer((int)1, (int)6)).then(Commands.func_197056_a((String)"stat", (ArgumentType)StringArgumentType.word()).suggests(STAT_SUGGESTIONS).then(Commands.func_197056_a((String)"value", (ArgumentType)IntegerArgumentType.integer((int)0, (int)mode.max)).executes(ctx -> PokemonKeyCommands.run((CommandContext<CommandSource>)ctx, mode))))))).executes(ctx -> {
            PokemonKeyCommands.reply((CommandContext<CommandSource>)ctx, TextFormatting.YELLOW, "\u7528\u6cd5: /" + name + " <\u73a9\u5bb6> <1-6> <hp|wg|wf|tg|tf|speed|all> <0-" + mode.max + ">");
            PokemonKeyCommands.reply((CommandContext<CommandSource>)ctx, TextFormatting.GRAY, "\u5c5e\u6027: hp=\u8840\u91cf wg=\u7269\u653b wf=\u7269\u9632 tg=\u7279\u653b tf=\u7279\u9632 speed=\u901f\u5ea6 all=\u5168\u90e8\u516d\u9879");
            PokemonKeyCommands.reply((CommandContext<CommandSource>)ctx, TextFormatting.GRAY, "\u4f5c\u7528: \u4fee\u6539\u5b9d\u53ef\u68a6\u7684" + mode.label + "\uff08" + mode.max + " \u4e3a\u5355\u9879\u4e0a\u9650\uff09");
            return 1;
        });
    }

    private static int run(CommandContext<CommandSource> ctx, Mode mode) throws CommandSyntaxException {
        BattleStatsType type;
        ServerPlayerEntity target = EntityArgument.func_197089_d(ctx, (String)"player");
        int slot = IntegerArgumentType.getInteger(ctx, (String)"slot");
        String key = StringArgumentType.getString(ctx, (String)"stat").toLowerCase(Locale.ROOT);
        int value = IntegerArgumentType.getInteger(ctx, (String)"value");
        boolean all = ALL.equals(key);
        BattleStatsType battleStatsType = type = all ? null : STATS.get(key);
        if (!all && type == null) {
            PokemonKeyCommands.reply(ctx, TextFormatting.RED, "\u672a\u77e5\u5c5e\u6027: " + key + "\uff08\u53ef\u7528: hp, wg, wf, tg, tf, speed, all\uff09");
            return 0;
        }
        PlayerPartyStorage party = StorageProxy.getParty((ServerPlayerEntity)target);
        Pokemon[] team = party.getAll();
        int index = slot - 1;
        if (index < 0 || index >= team.length || team[index] == null) {
            PokemonKeyCommands.reply(ctx, TextFormatting.RED, target.func_146103_bH().getName() + " \u7684\u961f\u4f0d\u7b2c " + slot + " \u4e2a\u4f4d\u7f6e\u6ca1\u6709\u5b9d\u53ef\u68a6");
            return 0;
        }
        Pokemon pokemon = team[index];
        String who = target.func_146103_bH().getName() + " \u7b2c " + slot + " \u53ea\u5b9d\u53ef\u68a6\u300c" + pokemon.getDisplayName() + "\u300d";
        if (mode == Mode.EV) {
            EVStore evs = pokemon.getEVs();
            if (all) {
                for (BattleStatsType t : BattleStatsType.EV_IV_STATS) {
                    evs.setStat(t, value);
                }
            } else {
                evs.setStat(type, value);
            }
            int total = 0;
            for (BattleStatsType t : BattleStatsType.EV_IV_STATS) {
                total += evs.getStat(t);
            }
            if (all) {
                PokemonKeyCommands.reply(ctx, TextFormatting.GREEN, "\u5df2\u5c06 " + who + " \u7684\u516d\u9879\u52aa\u529b\u503c\u5168\u90e8\u8bbe\u4e3a " + value + "\uff08\u516d\u9879\u5408\u8ba1 " + total + "\uff09");
            } else {
                PokemonKeyCommands.reply(ctx, TextFormatting.GREEN, "\u5df2\u5c06 " + who + " \u7684" + LABELS.get(key) + "\u52aa\u529b\u503c\u8bbe\u4e3a " + evs.getStat(type) + "\uff08\u516d\u9879\u5408\u8ba1 " + total + "\uff09");
            }
            if (total > 510) {
                PokemonKeyCommands.reply(ctx, TextFormatting.YELLOW, "\u63d0\u793a: \u516d\u9879\u5408\u8ba1 " + total + " \u5df2\u8d85\u8fc7\u5e38\u89c4\u4e0a\u9650 510\uff0c\u5c5e\u4e8e\u89c4\u5219\u5916\u6539\u6863\u3002");
            }
        } else {
            IVStore ivs = pokemon.getIVs();
            if (all) {
                for (BattleStatsType t : BattleStatsType.EV_IV_STATS) {
                    ivs.setStat(t, value);
                }
            } else {
                ivs.setStat(type, value);
            }
            int total = 0;
            for (BattleStatsType t : BattleStatsType.EV_IV_STATS) {
                total += ivs.getStat(t);
            }
            if (all) {
                PokemonKeyCommands.reply(ctx, TextFormatting.GREEN, "\u5df2\u5c06 " + who + " \u7684\u516d\u9879\u4e2a\u4f53\u503c\u5168\u90e8\u8bbe\u4e3a " + value + "\uff08\u516d\u9879\u5408\u8ba1 " + total + "\uff09");
            } else {
                PokemonKeyCommands.reply(ctx, TextFormatting.GREEN, "\u5df2\u5c06 " + who + " \u7684" + LABELS.get(key) + "\u4e2a\u4f53\u503c\u8bbe\u4e3a " + ivs.getStat(type) + "\uff08\u516d\u9879\u5408\u8ba1 " + total + "\uff09");
            }
        }
        return 1;
    }

    private static void reply(CommandContext<CommandSource> ctx, TextFormatting color, String text) {
        IFormattableTextComponent component = new StringTextComponent(text).func_240699_a_(color);
        ((CommandSource)ctx.getSource()).func_197030_a((ITextComponent)component, true);
    }

    static {
        PokemonKeyCommands.add("hp", BattleStatsType.HP, "\u8840\u91cf");
        PokemonKeyCommands.add("wg", BattleStatsType.ATTACK, "\u7269\u653b");
        PokemonKeyCommands.add("wf", BattleStatsType.DEFENSE, "\u7269\u9632");
        PokemonKeyCommands.add("tg", BattleStatsType.SPECIAL_ATTACK, "\u7279\u653b");
        PokemonKeyCommands.add("tf", BattleStatsType.SPECIAL_DEFENSE, "\u7279\u9632");
        PokemonKeyCommands.add("speed", BattleStatsType.SPEED, "\u901f\u5ea6");
        ArrayList<String> keys = new ArrayList<String>(STATS.keySet());
        keys.add(ALL);
        KEYS = Collections.unmodifiableList(keys);
        STAT_SUGGESTIONS = (ctx, builder) -> ISuggestionProvider.func_197005_b(KEYS, (SuggestionsBuilder)builder);
    }

    private static enum Mode {
        EV("\u52aa\u529b\u503c", 252),
        IV("\u4e2a\u4f53\u503c", 31);

        final String label;
        final int max;

        private Mode(String label, int max) {
            this.label = label;
            this.max = max;
        }
    }
}

