/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.client.Minecraft
 *  net.minecraft.client.gui.screen.Screen
 *  net.minecraft.client.gui.screen.inventory.ContainerScreen
 *  net.minecraft.client.network.play.ClientPlayNetHandler
 *  net.minecraft.inventory.container.Container
 *  net.minecraft.inventory.container.Slot
 *  net.minecraft.network.NetworkManager
 */
package com.ipnbackpacksort;

import com.ipnbackpacksort.IpnBackpackSortNetwork;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.screen.inventory.ContainerScreen;
import net.minecraft.client.network.play.ClientPlayNetHandler;
import net.minecraft.inventory.container.Container;
import net.minecraft.inventory.container.Slot;
import net.minecraft.network.NetworkManager;

public final class SortBridge {
    private static final String BACKPACK_CONTENT_SLOT = "net.p3pp3rf1y.sophisticatedbackpacks.common.gui.BackpackInventorySlot";

    private SortBridge() {
    }

    public static boolean interceptIpnSort() {
        NetworkManager networkManager;
        Minecraft minecraft = Minecraft.func_71410_x();
        Screen screen = minecraft.field_71462_r;
        if (minecraft.field_71439_g == null || minecraft.field_71441_e == null || !(screen instanceof ContainerScreen) || !SortBridge.isBackpackScreen(screen)) {
            return false;
        }
        Container container = minecraft.field_71439_g.field_71070_bA;
        if (container == null) {
            return false;
        }
        Slot slot = ((ContainerScreen)screen).getSlotUnderMouse();
        if (slot != null && !BACKPACK_CONTENT_SLOT.equals(slot.getClass().getName())) {
            return true;
        }
        ClientPlayNetHandler clientPlayNetHandler = minecraft.func_147114_u();
        NetworkManager networkManager2 = networkManager = clientPlayNetHandler == null ? null : clientPlayNetHandler.func_147298_b();
        if (networkManager != null && IpnBackpackSortNetwork.CHANNEL.isRemotePresent(networkManager)) {
            IpnBackpackSortNetwork.CHANNEL.sendToServer((Object)new IpnBackpackSortNetwork.SortRequestPacket(container.field_75152_c));
        }
        return true;
    }

    private static boolean isBackpackScreen(Screen screen) {
        return "net.p3pp3rf1y.sophisticatedbackpacks.client.gui.BackpackScreen".equals(screen.getClass().getName());
    }
}

