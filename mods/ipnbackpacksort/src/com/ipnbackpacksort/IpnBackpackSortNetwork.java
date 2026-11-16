/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.entity.player.PlayerEntity
 *  net.minecraft.entity.player.ServerPlayerEntity
 *  net.minecraft.inventory.container.Container
 *  net.minecraft.network.PacketBuffer
 *  net.minecraft.util.ResourceLocation
 *  net.minecraftforge.fml.network.NetworkEvent$Context
 *  net.minecraftforge.fml.network.NetworkRegistry
 *  net.minecraftforge.fml.network.simple.SimpleChannel
 */
package com.ipnbackpacksort;

import com.ipnbackpacksort.SortBridgeServer;
import com.ipnbackpacksort.Sorter;
import java.util.function.Predicate;
import java.util.function.Supplier;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.entity.player.ServerPlayerEntity;
import net.minecraft.inventory.container.Container;
import net.minecraft.network.PacketBuffer;
import net.minecraft.util.ResourceLocation;
import net.minecraftforge.fml.network.NetworkEvent;
import net.minecraftforge.fml.network.NetworkRegistry;
import net.minecraftforge.fml.network.simple.SimpleChannel;

public final class IpnBackpackSortNetwork {
    private static final String PROTOCOL = "1";
    public static final SimpleChannel CHANNEL = NetworkRegistry.newSimpleChannel((ResourceLocation)new ResourceLocation("ipnbackpacksort", "main"), () -> "1", (Predicate)NetworkRegistry.acceptMissingOr((String)"1"), (Predicate)NetworkRegistry.acceptMissingOr((String)"1"));

    private IpnBackpackSortNetwork() {
    }

    public static void register() {
        CHANNEL.registerMessage(0, SortRequestPacket.class, SortRequestPacket::encode, SortRequestPacket::decode, SortRequestPacket::handle);
    }

    public static final class SortRequestPacket {
        private final int containerId;

        public SortRequestPacket(int n) {
            this.containerId = n;
        }

        public static void encode(SortRequestPacket sortRequestPacket, PacketBuffer packetBuffer) {
            packetBuffer.func_150787_b(sortRequestPacket.containerId);
        }

        public static SortRequestPacket decode(PacketBuffer packetBuffer) {
            return new SortRequestPacket(packetBuffer.func_150792_a());
        }

        public static void handle(SortRequestPacket sortRequestPacket, Supplier<NetworkEvent.Context> supplier) {
            NetworkEvent.Context context = supplier.get();
            ServerPlayerEntity serverPlayerEntity = context.getSender();
            if (serverPlayerEntity != null) {
                context.enqueueWork(() -> {
                    Container container = serverPlayerEntity.field_71070_bA;
                    if (container == null || container.field_75152_c != sortRequestPacket.containerId || !SortBridgeServer.isBackpackContainer(container)) {
                        return;
                    }
                    int n = Sorter.sort((PlayerEntity)serverPlayerEntity, container);
                    if (n <= 0) {
                        return;
                    }
                    container.func_75142_b();
                });
            }
            context.setPacketHandled(true);
        }
    }
}

