/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  net.minecraft.entity.player.PlayerEntity
 *  net.minecraft.inventory.IInventory
 *  net.minecraft.inventory.container.Container
 *  net.minecraft.inventory.container.Slot
 *  net.minecraft.item.Item
 *  net.minecraft.item.ItemStack
 *  net.minecraft.nbt.CompoundNBT
 *  net.minecraft.util.IItemProvider
 *  net.minecraft.util.ResourceLocation
 *  net.minecraftforge.registries.ForgeRegistries
 *  net.minecraftforge.registries.IForgeRegistryEntry
 */
package com.ipnbackpacksort;

import com.ipnbackpacksort.IpnBackpackSort;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.TreeMap;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.inventory.IInventory;
import net.minecraft.inventory.container.Container;
import net.minecraft.inventory.container.Slot;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.nbt.CompoundNBT;
import net.minecraft.util.IItemProvider;
import net.minecraft.util.ResourceLocation;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.IForgeRegistryEntry;

public final class Sorter {
    private static final int PITCH = 18;
    private static final int MIN_ROW = 3;
    private static final String[] SKIPPED_INVENTORIES = new String[]{"net.minecraft.inventory.CraftingInventory"};
    private static final String[] SKIPPED_CONTAINERS = new String[]{"net.minecraft.inventory.container.ContainerCreative"};
    private static final String BACKPACK_CONTENT_SLOT = "net.p3pp3rf1y.sophisticatedbackpacks.common.gui.BackpackInventorySlot";
    private static ItemStack probe64;
    private static ItemStack probe1;
    private static boolean probesReady;
    private static boolean probesMissing;
    private static final Comparator<Entry> ORDER;

    private Sorter() {
    }

    public static int sort(PlayerEntity playerEntity, Container container) {
        if (playerEntity == null || container == null) {
            return 0;
        }
        String string = container.getClass().getName();
        for (String string2 : SKIPPED_CONTAINERS) {
            if (!string2.equals(string)) continue;
            return 0;
        }
        if (!container.func_75145_c(playerEntity)) {
            return 0;
        }
        int n = 0;
        for (List<Slot> list : Sorter.findRegions(playerEntity, container)) {
            n += Sorter.sortRegion(list);
        }
        return n;
    }

    private static List<List<Slot>> findRegions(PlayerEntity playerEntity, Container container) {
        TreeMap<Integer, List<Slot>> treeMap = new TreeMap<Integer, List<Slot>>();
        for (Slot slot : container.field_75151_b) {
            if (slot == null || !Sorter.isBackpackContentSlot(slot) || !Sorter.isUsable(slot, playerEntity)) continue;
            List<Slot> list = treeMap.get(slot.field_75221_f);
            if (list == null) {
                list = new ArrayList<Slot>();
                treeMap.put(slot.field_75221_f, list);
            }
            list.add(slot);
        }
        ArrayList<Row> rows = new ArrayList<Row>();
        for (Map.Entry<Integer, List<Slot>> entry : treeMap.entrySet()) {
            List<Slot> row = entry.getValue();
            row.sort(new Comparator<Slot>(){

                @Override
                public int compare(Slot slot, Slot slot2) {
                    return Integer.compare(slot.field_75223_e, slot2.field_75223_e);
                }
            });
            int n = 0;
            for (int i = 1; i <= row.size(); ++i) {
                boolean bl = i == row.size() || row.get(i).field_75223_e - row.get(i - 1).field_75223_e != 18;
                if (!bl) continue;
                if (i - n >= 3) {
                    rows.add(new Row(entry.getKey(), row.get(n).field_75223_e, new ArrayList<Slot>(row.subList(n, i))));
                }
                n = i;
            }
        }
        ArrayList<Region> regions = new ArrayList<Region>();
        for (Row row : rows) {
            IInventory iInventory = row.slots.get(0).field_75224_c;
            Region region = null;
            for (Region region2 : regions) {
                if (region2.x != row.x || region2.width != row.slots.size() || row.y - region2.lastY != 18 || region2.inventory != iInventory) continue;
                region = region2;
                break;
            }
            if (region == null) {
                region = new Region(row.x, row.slots.size(), iInventory);
                regions.add(region);
            }
            region.slots.addAll(row.slots);
            region.lastY = row.y;
        }
        ArrayList<List<Slot>> arrayList2 = new ArrayList<List<Slot>>(regions.size());
        for (Region region : regions) {
            arrayList2.add(region.slots);
        }
        return arrayList2;
    }

    private static boolean isUsable(Slot slot, PlayerEntity playerEntity) {
        IInventory iInventory;
        ItemStack itemStack = slot.func_75211_c();
        if (!itemStack.func_190926_b()) {
            if (!slot.func_82869_a(playerEntity)) {
                return false;
            }
            if (!slot.func_75214_a(itemStack)) {
                return false;
            }
        }
        if ((iInventory = slot.field_75224_c) == null) {
            return true;
        }
        String string = iInventory.getClass().getName();
        for (String string2 : SKIPPED_INVENTORIES) {
            if (!string2.equals(string)) continue;
            return false;
        }
        return true;
    }

    private static boolean isBackpackContentSlot(Slot slot) {
        return BACKPACK_CONTENT_SLOT.equals(slot.getClass().getName());
    }

    private static int sortRegion(List<Slot> list) {
        int n;
        ArrayList<ItemStack> arrayList = new ArrayList<ItemStack>(list.size());
        for (Slot slot : list) {
            arrayList.add(slot.func_75211_c().func_77946_l());
        }
        List<ItemStack> list2 = Sorter.plan(list, arrayList);
        if (list2 == null) {
            return 0;
        }
        int n2 = 0;
        for (n = 0; n < list.size(); ++n) {
            if (Sorter.same((ItemStack)list2.get(n), list.get(n).func_75211_c())) continue;
            ++n2;
        }
        if (n2 == 0) {
            return 0;
        }
        for (n = 0; n < list.size(); ++n) {
            if (Sorter.same((ItemStack)list2.get(n), list.get(n).func_75211_c())) continue;
            list.get(n).func_75215_d((ItemStack)list2.get(n));
        }
        ArrayList<ItemStack> arrayList2 = new ArrayList<ItemStack>(list.size());
        for (Slot slot : list) {
            arrayList2.add(slot.func_75211_c());
        }
        if (!Sorter.counts(arrayList).equals(Sorter.counts(arrayList2))) {
            for (int i = 0; i < list.size(); ++i) {
                if (Sorter.same((ItemStack)arrayList.get(i), list.get(i).func_75211_c())) continue;
                list.get(i).func_75215_d((ItemStack)arrayList.get(i));
            }
            IpnBackpackSort.LOGGER.error("ipnbackpacksort: \u6574\u7406 {} \u683c\u540e\u7269\u54c1\u603b\u6570\u5bf9\u4e0d\u4e0a\uff0c\u5df2\u56de\u6eda", (Object)list.size());
            return 0;
        }
        return n2;
    }

    private static List<ItemStack> plan(List<Slot> list, List<ItemStack> list2) {
        LinkedHashMap<String, Entry> linkedHashMap = new LinkedHashMap<String, Entry>();
        for (ItemStack itemStack : list2) {
            if (itemStack.func_190926_b()) continue;
            String string = Sorter.keyOf(itemStack);
            Entry entry = linkedHashMap.get(string);
            if (entry == null) {
                entry = new Entry(itemStack.func_77946_l(), Sorter.keyOfName(itemStack), itemStack.func_77952_i(), Sorter.nbtKey(itemStack.func_77978_p()));
                entry.count = 0;
                linkedHashMap.put(string, entry);
            }
            entry.count += itemStack.func_190916_E();
        }
        ArrayList<Entry> arrayList = new ArrayList<Entry>(linkedHashMap.values());
        arrayList.sort(ORDER);
        int[] counts = new int[arrayList.size()];
        for (int i = 0; i < arrayList.size(); ++i) {
            counts[i] = arrayList.get(i).count;
        }
        ArrayList<ItemStack> arrayList2 = new ArrayList<ItemStack>(list.size());
        for (Slot slot : list) {
            ItemStack itemStack = ItemStack.field_190927_a;
            for (int i = 0; i < arrayList.size(); ++i) {
                int n;
                ItemStack itemStack2;
                if (counts[i] <= 0 || !slot.func_75214_a(itemStack2 = arrayList.get(i).proto) || (n = Sorter.limitFor(slot, itemStack2)) <= 0) continue;
                int n2 = Math.min(counts[i], n);
                itemStack = itemStack2.func_77946_l();
                itemStack.func_190920_e(n2);
                counts[i] = counts[i] - n2;
                break;
            }
            arrayList2.add(itemStack);
        }
        for (int i = 0; i < arrayList.size(); ++i) {
            if (counts[i] <= 0) continue;
            return null;
        }
        return arrayList2;
    }

    private static int limitFor(Slot slot, ItemStack itemStack) {
        int n = slot.func_178170_b(itemStack);
        if (n <= 0) {
            return 0;
        }
        if (Sorter.isItemAware(slot)) {
            return n;
        }
        return Math.min(n, itemStack.func_77976_d());
    }

    private static boolean isItemAware(Slot slot) {
        if (!probesReady && !probesMissing) {
            probe64 = Sorter.probe("minecraft:stone");
            probe1 = Sorter.probe("minecraft:diamond_sword");
            probesReady = !probe64.func_190926_b() && !probe1.func_190926_b() && probe64.func_77976_d() != probe1.func_77976_d();
            boolean bl = probesMissing = !probesReady;
        }
        if (!probesReady) {
            return true;
        }
        return slot.func_178170_b(probe64) != slot.func_178170_b(probe1);
    }

    private static ItemStack probe(String string) {
        Item item = (Item)ForgeRegistries.ITEMS.getValue(new ResourceLocation(string));
        return item == null ? ItemStack.field_190927_a : new ItemStack((IItemProvider)item);
    }

    private static boolean same(ItemStack itemStack, ItemStack itemStack2) {
        if (itemStack.func_190926_b() || itemStack2.func_190926_b()) {
            return itemStack.func_190926_b() && itemStack2.func_190926_b();
        }
        return itemStack.func_77973_b() == itemStack2.func_77973_b() && itemStack.func_77952_i() == itemStack2.func_77952_i() && itemStack.func_190916_E() == itemStack2.func_190916_E() && Objects.equals(itemStack.func_77978_p(), itemStack2.func_77978_p());
    }

    private static String keyOf(ItemStack itemStack) {
        return Sorter.keyOfName(itemStack) + '\u0001' + itemStack.func_77952_i() + '\u0001' + Sorter.nbtKey(itemStack.func_77978_p());
    }

    private static String keyOfName(ItemStack itemStack) {
        Item item = itemStack.func_77973_b();
        if (item == null) {
            return "";
        }
        ResourceLocation resourceLocation = ForgeRegistries.ITEMS.getKey(item);
        return resourceLocation == null ? "" : resourceLocation.toString();
    }

    private static String nbtKey(CompoundNBT compoundNBT) {
        return compoundNBT == null ? "" : compoundNBT.toString();
    }

    private static Map<String, Integer> counts(List<ItemStack> list) {
        TreeMap<String, Integer> treeMap = new TreeMap<String, Integer>();
        for (ItemStack itemStack : list) {
            String string;
            if (itemStack.func_190926_b()) continue;
            Integer n = (Integer)treeMap.get(string = Sorter.keyOf(itemStack));
            treeMap.put(string, (n == null ? 0 : n) + itemStack.func_190916_E());
        }
        return treeMap;
    }

    static {
        ORDER = new Comparator<Entry>(){

            @Override
            public int compare(Entry entry, Entry entry2) {
                int n = entry.name.compareTo(entry2.name);
                if (n != 0) {
                    return n;
                }
                n = Integer.compare(entry.damage, entry2.damage);
                if (n != 0) {
                    return n;
                }
                return entry.nbt.compareTo(entry2.nbt);
            }
        };
    }

    private static final class Row {
        private final int y;
        private final int x;
        private final List<Slot> slots;

        private Row(int n, int n2, List<Slot> list) {
            this.y = n;
            this.x = n2;
            this.slots = list;
        }
    }

    private static final class Region {
        private final int x;
        private final int width;
        private final IInventory inventory;
        private final List<Slot> slots = new ArrayList<Slot>();
        private int lastY;

        private Region(int n, int n2, IInventory iInventory) {
            this.x = n;
            this.width = n2;
            this.inventory = iInventory;
        }
    }

    private static final class Entry {
        private final ItemStack proto;
        private final String name;
        private final int damage;
        private final String nbt;
        private int count;

        private Entry(ItemStack itemStack, String string, int n, String string2) {
            this.proto = itemStack;
            this.name = string;
            this.damage = n;
            this.nbt = string2;
        }
    }
}

