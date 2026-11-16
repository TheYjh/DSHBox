/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.entity.player.ServerPlayerEntity
 *  net.minecraft.network.PacketBuffer
 *  net.minecraftforge.fml.network.NetworkEvent$Context
 */
package com.commandkeys;

import com.commandkeys.ServerKeyExecutor;
import java.util.function.Supplier;
import net.minecraft.entity.player.ServerPlayerEntity;
import net.minecraft.network.PacketBuffer;
import net.minecraftforge.fml.network.NetworkEvent;

public final class ExecuteKeyPacket {
    private final int slot;

    public ExecuteKeyPacket(int n) {
        this.slot = n;
    }

    public static void encode(ExecuteKeyPacket executeKeyPacket, PacketBuffer packetBuffer) {
        packetBuffer.func_150787_b(executeKeyPacket.slot);
    }

    public static ExecuteKeyPacket decode(PacketBuffer packetBuffer) {
        return new ExecuteKeyPacket(packetBuffer.func_150792_a());
    }

    public static void handle(ExecuteKeyPacket executeKeyPacket, Supplier<NetworkEvent.Context> supplier) {
        NetworkEvent.Context context = supplier.get();
        final ServerPlayerEntity serverPlayerEntity = context.getSender();
        final int n = executeKeyPacket.slot;
        if (serverPlayerEntity != null) {
            context.enqueueWork(new Runnable(){

                @Override
                public void run() {
                    ServerKeyExecutor.trigger(serverPlayerEntity, n);
                }
            });
        }
        context.setPacketHandled(true);
    }

    public int slot() {
        return this.slot;
    }
}

