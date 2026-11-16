/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraftforge.fml.common.Mod
 *  org.apache.logging.log4j.LogManager
 *  org.apache.logging.log4j.Logger
 */
package com.ipnbackpacksort;

import com.ipnbackpacksort.IpnBackpackSortNetwork;
import net.minecraftforge.fml.common.Mod;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

@Mod(value="ipnbackpacksort")
public final class IpnBackpackSort {
    public static final String MOD_ID = "ipnbackpacksort";
    public static final Logger LOGGER = LogManager.getLogger((String)"ipnbackpacksort");

    public IpnBackpackSort() {
        IpnBackpackSortNetwork.register();
    }
}

