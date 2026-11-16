/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.spongepowered.asm.mixin.Mixin
 *  org.spongepowered.asm.mixin.injection.At
 *  org.spongepowered.asm.mixin.injection.Inject
 *  org.spongepowered.asm.mixin.injection.callback.CallbackInfo
 */
package com.ipnbackpacksort.mixin;

import com.ipnbackpacksort.SortBridge;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets={"org.anti_ad.mc.ipnext.inventory.GeneralInventoryActions"}, remap=false)
public abstract class GeneralInventoryActionsMixin {
    @Inject(method={"doSort(Z)V"}, at={@At(value="HEAD")}, cancellable=true, remap=false)
    private void ipnBackpackSort$doSort(boolean bl, CallbackInfo callbackInfo) {
        if (SortBridge.interceptIpnSort()) {
            callbackInfo.cancel();
        }
    }

    @Inject(method={"doSortInColumns(Z)V"}, at={@At(value="HEAD")}, cancellable=true, remap=false)
    private void ipnBackpackSort$doSortInColumns(boolean bl, CallbackInfo callbackInfo) {
        if (SortBridge.interceptIpnSort()) {
            callbackInfo.cancel();
        }
    }

    @Inject(method={"doSortInRows(Z)V"}, at={@At(value="HEAD")}, cancellable=true, remap=false)
    private void ipnBackpackSort$doSortInRows(boolean bl, CallbackInfo callbackInfo) {
        if (SortBridge.interceptIpnSort()) {
            callbackInfo.cancel();
        }
    }
}

