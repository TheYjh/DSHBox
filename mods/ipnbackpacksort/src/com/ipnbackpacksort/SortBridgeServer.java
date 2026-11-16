/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.inventory.container.Container
 */
package com.ipnbackpacksort;

import net.minecraft.inventory.container.Container;

final class SortBridgeServer {
    private SortBridgeServer() {
    }

    static boolean isBackpackContainer(Container container) {
        return "net.p3pp3rf1y.sophisticatedbackpacks.common.gui.BackpackContainer".equals(container.getClass().getName());
    }
}

