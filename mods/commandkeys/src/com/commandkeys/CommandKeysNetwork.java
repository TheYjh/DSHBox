/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.util.ResourceLocation
 *  net.minecraftforge.fml.network.NetworkRegistry
 *  net.minecraftforge.fml.network.simple.SimpleChannel
 */
package com.commandkeys;

import com.commandkeys.ExecuteKeyPacket;
import java.util.function.Predicate;
import java.util.function.Supplier;
import net.minecraft.util.ResourceLocation;
import net.minecraftforge.fml.network.NetworkRegistry;
import net.minecraftforge.fml.network.simple.SimpleChannel;

public final class CommandKeysNetwork {
    private static final String PROTOCOL = "1";
    public static final SimpleChannel CHANNEL = NetworkRegistry.newSimpleChannel((ResourceLocation)new ResourceLocation("commandkeys", "main"), (Supplier)new Supplier<String>(){

        @Override
        public String get() {
            return CommandKeysNetwork.PROTOCOL;
        }
    }, (Predicate)new Predicate<String>(){

        @Override
        public boolean test(String string) {
            return CommandKeysNetwork.PROTOCOL.equals(string);
        }
    }, (Predicate)new Predicate<String>(){

        @Override
        public boolean test(String string) {
            return CommandKeysNetwork.PROTOCOL.equals(string);
        }
    });

    private CommandKeysNetwork() {
    }

    public static void register() {
        CHANNEL.registerMessage(0, ExecuteKeyPacket.class, ExecuteKeyPacket::encode, ExecuteKeyPacket::decode, ExecuteKeyPacket::handle);
    }
}

