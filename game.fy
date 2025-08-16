# game.fy — gameplay systems and loop logic (optimized + color + memory + XP/Level + shops + trader)
import "config.fy";
import "map.fy";
import "entities.fy";

# Busy-wait delay using built-in time() which returns ms.
func delayMs(ms) {
    start = time();
    while time() - start < ms { }   # simple, portable
}

# Utility function to choose a random element from a list
func randChoice(list) {
    if length(list) == 0 { return Null; }
    return list[randInt(0, length(list) - 1)];
}

class Game {
    func &Game() {
        &grid = [];
        &rooms = [];
        &monsters = [];      # list of Monster
        &items = [];         # list of dicts: { "x": int, "y": int, "glyph": string, "it": Item }
        &player = Player(0, 0);
        &message = "";
        &dead = false;

        &fov_enabled = FOV_ENABLED;
        &color_enabled = COLOR_ENABLED;

        &seen = [];          # map memory (bool[y][x])
        &exit = [0,0];       # [x, y]
        &trader = Null;      # { "x":int, "y":int, "stock":[{ "it":Item, "price":int }] } or Null
        &theme = "catacombs"; # current level theme
        &first_render = true; # Track if this is the first render

        &buildLevel(1);
    }

    # ------------ UTILITIES ------------

    # Render with torch lighting effect for first reveal
    func &renderWithTorchLighting() {
        # First, just show the player in darkness
        &renderPlayerOnly();
        
        # Gradually light up the area, increasing radius each time
        for radius = 2, radius <= FOV_RADIUS, radius += 2 {
            &renderWithRadius(radius);
            delayMs(300);  # Brief pause between each radius increase
        }
        
        # Final render with full FOV
        &render();
        &first_render = false;  # Mark that first render is complete
    }
    
    # Render only the player tile (everything else is dark)
    func &renderPlayerOnly() {
        lines = [];
        header = "== Funcy Roguelike :: " + &player.statsStr() + " ==";
        lines.append(header);
        lines.append(" ");  # Empty message line
        
        for y = 0, y < MAP_H, y += 1 {
            row_chars = [];
            for x = 0, x < MAP_W, x += 1 {
                ch = " ";  # Default to dark
                if x == &player.x and y == &player.y {
                    # Only show the player
                    ch = &applyColorVisibleTile(&player.glyph);
                }
                row_chars.append(ch);
            }
            lines.append("".join(row_chars));
        }
        
        print("\e[H\e[J" + "\n".join(lines));
    }
    
    # Render with specific visibility radius
    func &renderWithRadius(radius) {
        # Precompute quick lookup maps (O(entities))
        items_map = {};        # key: "x,y" -> glyph
        for i = 0, i < length(&items), i += 1 {
            rec = &items[i];
            key = str(rec["x"]) + "," + str(rec["y"]);
            items_map[key] = rec["glyph"];
        }
        monsters_map = {};     # key: "x,y" -> glyph
        for i = 0, i < length(&monsters), i += 1 {
            m = &monsters[i];
            key = str(m.x) + "," + str(m.y);
            monsters_map[key] = m.glyph;
        }

        # Compute visibility with specific radius
        vis = [];
        for y = 0, y < MAP_H, y += 1 {
            row = [];
            for x = 0, x < MAP_W, x += 1 { row.append(false); }
            vis.append(row);
        }
        px = &player.x; py = &player.y;
        R2 = radius * radius;

        miny = py - radius; if miny < 0 { miny = 0; }
        maxy = py + radius; if maxy >= MAP_H { maxy = MAP_H - 1; }
        minx = px - radius; if minx < 0 { minx = 0; }
        maxx = px + radius; if maxx >= MAP_W { maxx = MAP_W - 1; }

        for y = miny, y <= maxy, y += 1 {
            for x = minx, x <= maxx, x += 1 {
                dx = x - px; dy = y - py;
                if dx*dx + dy*dy <= R2 { vis[y][x] = true; }
            }
        }

        # Cache exit coords for cheap compare
        ex = &exit[0]; ey = &exit[1];

        lines = [];
        header = "== Funcy Roguelike :: " + &player.statsStr() + " ==";
        lines.append(header);
        lines.append(" ");  # Empty message line

        for y = 0, y < MAP_H, y += 1 {
            row_chars = [];
            for x = 0, x < MAP_W, x += 1 {
                visible = vis[y][x];
                ch = " ";

                if visible {
                    &seen[y][x] = true;

                    # base tile
                    base = &grid[y][x];
                    ch = base;

                    key = str(x) + "," + str(y);
                    if key in items_map { ch = items_map[key]; }
                    if key in monsters_map { ch = monsters_map[key]; }

                    # trader overlay
                    if &trader {
                        if x == &trader["x"] and y == &trader["y"] { ch = "T"; }
                    }

                    # player on top
                    if x == &player.x and y == &player.y { ch = &player.glyph; }

                    # visible tinting / colors
                    ch = &applyColorVisibleTile(ch);
                } else {
                    if &seen[y][x] {
                        if &grid[y][x] == "#" {
                            ch = "#";
                            if &color_enabled { 
                                # Remembered walls use dimmed gray, not theme colors
                                ch = C_WALL_DIM + ch + C_RESET;
                            }
                        } elif x == ex and y == ey {
                            ch = ">";
                            if &color_enabled { ch = C_EXIT + ch + C_RESET; }
                        } else {
                            ch = " ";
                        }
                    } else {
                        ch = " ";
                    }
                }
                row_chars.append(ch);
            }
            lines.append("".join(row_chars));
        }

        print("\e[H\e[J" + "\n".join(lines));
    }

    func &buildLineFromRow(row) {
        s = "";
        for i = 0, i < length(row), i += 1 { s = s + row[i]; }
        return s;
    }

    func &applyColorVisibleTile(ch) {
        if not &color_enabled { return ch; }
        if ch == "#" { 
            # Apply theme-based wall colors
            if &theme == "caves" { return C_CAVES_WALL + "#" + C_RESET; }
            elif &theme == "catacombs" { return C_CATACOMBS_WALL + "#" + C_RESET; }
            elif &theme == "forge" { return C_FORGE_WALL + "#" + C_RESET; }
            else { return C_WALL + "#" + C_RESET; }  # fallback
        }
        if ch == "." { return C_FLOOR + "." + C_RESET; }
        if ch == ">" { return C_EXIT  + ">" + C_RESET; }
        if ch == "@" { return C_PLAYER+ "@" + C_RESET; }
        if ch == "!" { return C_POTION+ "!" + C_RESET; }
        if ch == ")" { return C_WEAPON+ ")" + C_RESET; }
        if ch == "[" { return C_WEAPON+ "[" + C_RESET; }  # reuse cyan for armor
        if ch == "=" { return C_POTION+ "=" + C_RESET; }  # reuse magenta for ring
        # Theme-specific terrain
        if ch == "~" { 
            # Water in caves, lava in forge
            if &theme == "forge" { return C_LAVA + "~" + C_RESET; }   # red ~ for lava
            else { return C_WATER + "~" + C_RESET; }                   # cyan ~ for water
        }
        if ch == "|" { return C_PILLAR + "|" + C_RESET; } # pillar
        # Monster letters (unique per type)
        if ch == "M" or ch == "R" or ch == "B" or ch == "s" or ch == "G" or ch == "S" {
            return C_MON + ch + C_RESET;
        }
        if ch == "T" { return C_TRADER + "T" + C_RESET; }
        if ch == "C" { return C_ITEM + "C" + C_RESET; } # Chests (including disguised mimics)
        return ch;
    }

    # Check if coordinates are within map bounds
    func &inBounds(x, y) {
        return x >= 0 and x < MAP_W and y >= 0 and y < MAP_H;
    }
    
    func &passable(x, y) {
        if not &inBounds(x, y) { return false; }
        tile = &grid[y][x];
        # Basic passable tiles
        if tile == "." or tile == ">" { return true; }
        # Theme-specific passable tiles
        if tile == "~" { 
            # Water is passable, lava is not
            if &theme == "forge" { return false; }  # Lava in forge is not passable
            else { return true; }                    # Water in other themes is passable
        }
        if tile == "|" { return false; } # Pillars are not passable
        return false;
    }
    
    # Check for special terrain effects when player is on them
    func &checkTerrainEffects(x, y) {
        tile = &grid[y][x];
        if tile == "~" {
            # Water vs lava based on theme
            if &theme == "forge" {
                # Lava: should not be passable, this is a safety check
                &message = "The lava burns you!";
            } else {
                # Water: passable but slows movement
                &message = "You wade through the water.";
            }
        } elif tile == "|" {
            # Pillar: blocking obstacle
            &message = "You cannot pass through the pillar.";
        }
    }

    func &monsterAt(x, y) {
        for i = 0, i < length(&monsters), i += 1 {
            m = &monsters[i];
            if m.x == x and m.y == y { return m; }
        }
        return Null;
    }

    func &itemIndexAt(x, y) {
        for i = 0, i < length(&items), i += 1 {
            rec = &items[i];
            if rec["x"] == x and rec["y"] == y { return i; }
        }
        return -1;
    }

    # ---- FAST FOV: radius only, no LOS occlusion ----
    func &computeVisibilityRadius() {
        vis = [];
        for y = 0, y < MAP_H, y += 1 {
            row = [];
            for x = 0, x < MAP_W, x += 1 { row.append(false); }
            vis.append(row);
        }
        R = FOV_RADIUS;
        px = &player.x; py = &player.y;
        R2 = R * R;

        miny = py - R; if miny < 0 { miny = 0; }
        maxy = py + R; if maxy >= MAP_H { maxy = MAP_H - 1; }
        minx = px - R; if minx < 0 { minx = 0; }
        maxx = px + R; if maxx >= MAP_W { maxx = MAP_W - 1; }

        for y = miny, y <= maxy, y += 1 {
            dy = y - py;
            for x = minx, x <= maxx, x += 1 {
                dx = x - px;
                if dx*dx + dy*dy <= R2 {
                    vis[y][x] = true;
                }
            }
        }
        return vis;
    }

    # ---------- Leveling helpers ----------
    func &xpGainFromMonster(m) {
        # Simple: base + monster attack, lightly scaled by depth
        val = XP_PER_KILL_BASE + m.atk + (&player.depth // 3);
        return val;
    }

    func &gainXP(n) {
        &player.xp = &player.xp + n;
        # Handle multiple level-ups if accrued XP is large
        while &player.xp >= &player.xpThresholdFor(&player.level) {
            &player.xp = &player.xp - &player.xpThresholdFor(&player.level);
            &player.level = &player.level + 1;
            &onLevelUp();
        }
    }

    func &onLevelUp() {
        print("\n== Level Up! You are now level " + str(&player.level) + " ==");
        options = [
            "Vitality (+2 Max HP, heal 2)",
            "Power (+1 Base ATK)",
            "Guard (+1 DEF)"
        ];
        for i = 0, i < length(options), i += 1 {
            print("  [" + str(i + 1) + "] " + options[i]);
        }
        choice = -1;
        while true {
            inp = input("Choose a perk (1-3): ").strip();
            if not inp.isDigit() { print("Please enter 1, 2, or 3."); continue; }
            choice1 = int(inp);
            if choice1 >= 1 and choice1 <= 3 { choice = choice1 - 1; break; }
            print("Invalid choice.");
        }

        if choice == 0 {
            &player.hp_max = &player.hp_max + 2;
            &player.hp = &player.hp + 2;
            if &player.hp > &player.hp_max { &player.hp = &player.hp_max; }
            print("You feel heartier. Max HP +2.");
        } elif choice == 1 {
            &player.atk = &player.atk + 1;
            print("Your strikes hit harder. Base ATK +1.");
        } else {
            &player.perk_def_bonus = &player.perk_def_bonus + 1;
            print("You brace yourself better. DEF +1.");
        }
        _ = input("(press Enter) ");
    }

    # ---------- Shops / Trader ----------
    func &priceFor(it) {
        if it.kind == "potion" { return PRICE_POTION_BASE + (it.stats - 5); }
        elif it.kind == "weapon" { return it.stats * PRICE_WEAPON_PER_ATK; }
        elif it.kind == "armor"  { return it.stats * PRICE_ARMOR_PER_DEF; }
        elif it.kind == "ring"   { return PRICE_RING_BASE; }
        return 10;
    }

    func &generateShopStock() {
        stock = [];  # list of { "it":Item, "price":int }
        for i = 0, i < SHOP_OFFER_COUNT, i += 1 {
            roll = randInt(0, 9);
            itm = Null;
            if roll < 3 {
                heal = randInt(5, 10) + (&player.depth // 3);   # tiny depth bump
                itm = &applyLuckRingBonus(Item("Red Potion", "potion", heal));
            } elif roll < 6 {
                pwr = randInt(1, 3) + (&player.depth // 3);
                
                wnames = ["Dagger", "Shortsword", "Club"];
                itm = &applyLuckRingBonus(Item(randChoice(wnames), "weapon", pwr));
            } elif roll < 8 {
                defv = randInt(1, 2) + (&player.depth // 4);
                
                anames = ["Cloth Armor", "Leather Armor", "Chain Shirt"];
                itm = &applyLuckRingBonus(Item(randChoice(anames), "armor", defv));
            } else {
                # Randomly choose power or defense ring with unique names
                if randInt(1, 2) == 1 { # Power ring
                    power_names = ["Ring of the Iron Blade", "Ring of the Burning Flame", "Ring of the Sharp Edge"];
                    itm = Item(randChoice(power_names), "ring", 0);
                    itm.subkind = "power";
                    itm.stats = randInt(1, 3); # +1 to +3 ATK in shops
                } else { # Defense ring
                    defense_names = ["Ring of the Copper Guard", "Ring of the Stone Wall", "Ring of the Iron Defense"];
                    itm = Item(randChoice(defense_names), "ring", 0);
                    itm.subkind = "defense";
                    itm.stats = randInt(1, 3); # +1 to +3 DEF in shops
                }
            }
            price = &priceFor(itm);
            stock.append({ "it": itm, "price": price });
        }
        return stock;
    }

    func &shopMenu(stock, title) {
        while true {
            print("\e[H\e[J");
            print("== " + title + " ==");
            print(C_YELLOW + "Gold: " + str(&player.gold) + C_RESET);
            print("Items (choose 1.." + str(length(stock)) + ", or blank to leave):");
            for i = 0, i < length(stock), i += 1 {
                rec = stock[i];
                line = "  [" + str(i + 1) + "] " + rec["it"].toString() + "  - " + C_YELLOW + str(rec["price"]) + "g" + C_RESET;
                print(line);
            }
            choice = input("> ").strip();
            if choice == "" { 
                # Set first_render to true so view animation plays when leaving shop
                &first_render = true;
                break; 
            }
            if not choice.isDigit() { print("Please enter a number."); _ = input("(Enter) "); continue; }
            idx1 = int(choice);
            if idx1 < 1 or idx1 > length(stock) { print("Out of range."); _ = input("(Enter) "); continue; }
            idx = idx1 - 1;
            rec2 = stock[idx];
            cost = rec2["price"];
            if &player.gold < cost { print("Not enough gold."); _ = input("(Enter) "); continue; }
            &player.gold = &player.gold - cost;
            &player.inventory.append(rec2["it"]);
            print("Bought: " + rec2["it"].toString() + " for " + str(cost) + "g.");
            _ = input("(Enter) ");
        }
    }

    func &spawnTraderMaybe() {
        &trader = Null;
        roll = randInt(1, 100);
        if roll > TRADER_SPAWN_CHANCE { return; }

        # try a few random floors
        for tries = 0, tries < 200, tries += 1 {
            r = randChoice(&rooms);
            rx = randInt(r["x"], r["x"] + r["w"] - 1);
            ry = randInt(r["y"], r["y"] + r["h"] - 1);
            if &grid[ry][rx] == "."
               and not (&player.x == rx and &player.y == ry)
               and (&itemIndexAt(rx, ry) == -1)
               and not &monsterAt(rx, ry) {
                stock = &generateShopStock();
                &trader = { "x": rx, "y": ry, "stock": stock };
                break;
            }
        }
    }

    func &playerAdjacentToTrader() {
        if not &trader { return false; }
        dx = &player.x - &trader["x"]; if dx < 0 { dx = -dx; }
        dy = &player.y - &trader["y"]; if dy < 0 { dy = -dy; }
        return (dx + dy) == 1 or (dx == 0 and dy == 0);
    }

    func &talkToTrader() {
        if not &playerAdjacentToTrader() {
            &message = "No trader nearby.";
            return;
        }
        &shopMenu(&trader["stock"], "Trader");
    }

    # ---------- LEVEL BUILD / LOOP ----------

    func &buildLevel(depth) {
        &player.depth = depth;

        gen = generateMap(depth);
        &grid  = gen["grid"];
        &rooms = gen["rooms"];
        &exit  = gen["exit"];                # [x, y]
        &player.x = gen["player_start"][0];
        &player.y = gen["player_start"][1];
        &theme = gen["theme"]; # Store the theme

        # clear entities
        &monsters = [];
        &items = [];

        # reset map memory
        &seen = [];
        for y = 0, y < MAP_H, y += 1 {
            row = [];
            for x = 0, x < MAP_W, x += 1 { row.append(false); }
            &seen.append(row);
        }

        exitX = &exit[0];
        exitY = &exit[1];

        # spawn monsters — ONLY on floor ".", never on exit ">"
        mcount = MONSTERS_PER_FLOOR + (&player.depth - 1);
        for i = 0, i < mcount, i += 1 {
            r = randChoice(&rooms);
            rx = randInt(r["x"], r["x"] + r["w"] - 1);
            ry = randInt(r["y"], r["y"] + r["h"] - 1);
            if (&grid[ry][rx] == ".")
               and not (&player.x == rx and &player.y == ry)
               and not (rx == exitX and ry == exitY)
               and not &monsterAt(rx, ry) {
                base = 3 + (&player.depth - 1);
                hp = randInt(base, base + 4);
                atk = randInt(1 + (&player.depth // 2), 2 + (&player.depth // 2));
                names = ["Rat", "Bat", "Slime", "Goblin", "Spider"];
                m = Monster(randChoice(names), rx, ry, hp, atk);
                &monsters.append(m);
            }
        }

        # spawn items — floor only, never on exit; include armor/rings sometimes
        for i = 0, i < ITEMS_PER_FLOOR, i += 1 {
            r = randChoice(&rooms);
            rx = randInt(r["x"], r["x"] + r["w"] - 1);
            ry = randInt(r["y"], r["y"] + r["h"] - 1);
            if (&grid[ry][rx] == ".")
               and not (&player.x == rx and &player.y == ry)
               and not (rx == exitX and ry == exitY)
               and (&itemIndexAt(rx, ry) == -1)
               and not &monsterAt(rx, ry) {

                roll = randInt(0, 9);  # 0..9
                itm = Null;
                glyph = "!";

                if roll < 3 {
                    heal = randInt(5, 10);
                    
                    # Fortune ring bonus: chance to improve potion healing
                    itm = &applyLuckRingBonus(Item("Red Potion", "potion", heal));
                    glyph = "!";
                } elif roll < 6 {
                    pwr = randInt(1, 3);
                    
                    wnames = ["Dagger", "Shortsword", "Club"];
                    itm = &applyLuckRingBonus(Item(randChoice(wnames), "weapon", pwr));
                    glyph = ")";
                } elif roll < 8 {
                    defv = randInt(1, 2);
                    
                    anames = ["Cloth Armor", "Leather Armor", "Chain Shirt"];
                    itm = &applyLuckRingBonus(Item(randChoice(anames), "armor", defv));
                    glyph = "[";
                } else {
                    # Randomly choose power or defense ring with unique names
                    if randInt(1, 2) == 1 { # Power ring
                        power_names = ["Ring of the Iron Blade", "Ring of the Burning Flame", "Ring of the Sharp Edge"];
                        itm = Item(randChoice(power_names), "ring", 0);
                        itm.subkind = "power";
                        itm.stats = randInt(1, 2); # +1 or +2 ATK
                    } else { # Defense ring
                        defense_names = ["Ring of the Copper Guard", "Ring of the Stone Wall", "Ring of the Iron Defense"];
                        itm = Item(randChoice(defense_names), "ring", 0);
                        itm.subkind = "defense";
                        itm.stats = randInt(1, 2); # +1 or +2 DEF
                    }
                    glyph = "=";
                }

                &items.append({ "x": rx, "y": ry, "glyph": glyph, "it": itm });
            }
        }
        
        # Spawn chests with chance to be mimics
        for i = 0, i < 2, i += 1 { # Spawn 2 chests per level
            r = randChoice(&rooms);
            if r["w"] > 1 and r["h"] > 1 {
                rx = randInt(r["x"], r["x"] + r["w"] - 1);
                ry = randInt(r["y"], r["y"] + r["h"] - 1);
                if (&grid[ry][rx] == ".")
                   and not (&player.x == rx and &player.y == ry)
                   and not (rx == exitX and ry == exitY)
                   and (&itemIndexAt(rx, ry) == -1)
                   and not &monsterAt(rx, ry) {
                    
                    # 20% chance to be a mimic
                    if randInt(1, 5) == 1 {
                        mimic_hp = 8 + (&player.depth - 1);
                        mimic_atk = 2 + (&player.depth // 2);
                        mimic = Monster("Mimic", rx, ry, mimic_hp, mimic_atk);
                        disguise_ability = DisguiseAbility("chest");
                        mimic.addAbility(disguise_ability);
                        &monsters.append(mimic);
                    } else {
                        # Regular chest with multiple items
                        chest_items = [];
                        item_count = randInt(2, 4); # 2-4 items per chest
                        
                        # Get luck bonus for chest quality and item improvements
                        luck_bonus = &player.ringLuck();
                        
                        for j = 0, j < item_count, j += 1 {
                            # First: Determine if this item should be high quality
                            # Base 25% + 25% per luck point, capped at 90%
                            quality_chance = 25 + (luck_bonus * 25);
                            if quality_chance > 90 { quality_chance = 90; }
                            is_high_quality = randInt(1, 100) <= quality_chance;
                            
                            # Second: Determine item type
                            # 40% potion, 30% weapon, 20% armor, 10% ring
                            item_type_roll = randInt(1, 100);
                            
                            if item_type_roll <= 40 { # Potion (40%)
                                heal = 0;
                                potion_name = "Health Potion";
                                
                                if is_high_quality {
                                    heal = randInt(12, 20); # High quality: better base stats
                                    potion_name = "Greater Potion";
                                } else {
                                    heal = randInt(8, 15);  # Normal quality: standard stats    
                                }
                                
                                # Apply luck bonus to improve stats
                                if luck_bonus > 0 {
                                    heal = heal + (luck_bonus * 2);
                                }
                                
                                chest_items.append(&applyLuckRingBonus(Item(potion_name, "potion", heal)));
                                
                            } elif item_type_roll <= 70 { # Weapon (30%)
                                pwr = 0;
                                weapon_name = "Iron Sword";
                                
                                if is_high_quality {
                                    pwr = randInt(3, 6); # High quality: better base stats
                                    weapon_name = "Steel Sword";
                                } else {
                                    pwr = randInt(2, 5);  # Normal quality: standard stats    
                                }
                                
                                # Apply luck bonus to improve stats
                                if luck_bonus > 0 {
                                    pwr = pwr + luck_bonus;
                                }
                                
                                chest_items.append(&applyLuckRingBonus(Item(weapon_name, "weapon", pwr)));
                                
                            } elif item_type_roll <= 90 { # Armor (20%)
                                defv = 0;
                                armor_name = "Leather Armor";
                                if is_high_quality {
                                    defv = randInt(3, 5); # High quality: better base stats
                                    armor_name = "Chain Mail";
                                } else {
                                    defv = randInt(2, 4);  # Normal quality: standard stats    
                                }
                                
                                # Apply luck bonus to improve stats
                                if luck_bonus > 0 {
                                    defv = defv + luck_bonus;
                                }
                                
                                chest_items.append(&applyLuckRingBonus(Item(armor_name, "armor", defv)));
                                
                            } else { # Ring (10%)
                                # Ring of Luck chance: 20% + 20% per luck point, capped at 80%
                                luck_ring_chance = 20 + (luck_bonus * 20);
                                if luck_ring_chance > 80 { luck_ring_chance = 80; }
                                
                                if randInt(1, 100) <= luck_ring_chance { # Ring of Luck
                                    # Choose a unique luck ring name
                                    luck_names = ["Ring of the Lucky Star", "Ring of Fortune's Favor", "Ring of the Charmed Fate", "Ring of Destiny's Call"];
                                    luck_ring = Item(randChoice(luck_names), "ring", 0);
                                    luck_ring.subkind = "luck";
                                    
                                    # Base stats: 75% +1, 20% +2, 5% +3
                                    roll = randInt(1, 100);
                                    if roll <= 75 { luck_ring.stats = 1; }
                                    elif roll <= 95 { luck_ring.stats = 2; }
                                    else { luck_ring.stats = 3; }
                                    
                                    # Luck rings can improve the Ring of Luck you find!
                                    if luck_bonus > 0 {
                                        # Apply luck ring bonus to the new Ring of Luck
                                        luck_ring = &applyLuckRingBonus(luck_ring);
                                    }
                                    
                                    chest_items.append(luck_ring);
                                    
                                } else { # Enhanced Power/Defense ring
                                    # Define ring names based on quality
                                    power_names = [];
                                    defense_names = [];
                                    if is_high_quality {
                                        # High quality ring names
                                        power_names = ["Ring of the Dragon's Fury", "Ring of Thunder's Wrath", "Ring of the Phoenix Flame"];
                                        defense_names = ["Ring of the Guardian's Shield", "Ring of the Crystal Barrier", "Ring of the Ancient Protector"];
                                    } else {
                                        # Normal quality ring names
                                        power_names = ["Ring of the Iron Blade", "Ring of the Burning Flame", "Ring of the Sharp Edge"];
                                        defense_names = ["Ring of the Copper Guard", "Ring of the Stone Wall", "Ring of the Iron Defense"];
                                    }
                                    
                                    # Declare enhanced_ring variable at the beginning of the block
                                    enhanced_ring = Null;
                                    
                                    # Randomly choose power or defense
                                    if randInt(1, 2) == 1 { # Power ring
                                        enhanced_ring = Item(randChoice(power_names), "ring", 0);
                                        enhanced_ring.subkind = "power";
                                        if is_high_quality {
                                            enhanced_ring.stats = randInt(3, 5); # High quality: +3 to +5 ATK
                                        } else {
                                            enhanced_ring.stats = randInt(2, 4); # Normal quality: +2 to +4 ATK
                                        }
                                    } else { # Defense ring
                                        enhanced_ring = Item(randChoice(defense_names), "ring", 0);
                                        enhanced_ring.subkind = "defense";
                                        if is_high_quality {
                                            enhanced_ring.stats = randInt(3, 5); # High quality: +3 to +5 DEF
                                        } else {
                                            enhanced_ring.stats = randInt(2, 4); # Normal quality: +2 to +4 DEF
                                        }
                                    }
                                    
                                    # Apply luck bonus to improve stats
                                    if luck_bonus > 0 {
                                        enhanced_ring.stats = enhanced_ring.stats + luck_bonus;
                                    }
                                    
                                    chest_items.append(enhanced_ring);
                                }
                            }
                        }
                        
                        &items.append({ "x": rx, "y": ry, "glyph": "C", "it": chest_items, "is_chest": true });
                    }
                }
            }
        }

        # maybe spawn a trader in this level
        &spawnTraderMaybe();

        # Create theme description
        theme_desc = "";
        if &theme == "caves" { theme_desc = " (Caves)"; }
        elif &theme == "catacombs" { theme_desc = " (Catacombs)"; }
        elif &theme == "forge" { theme_desc = " (Forge)"; }
        
        &message = "You descend to depth " + str(&player.depth) + theme_desc + ".";
        &dead = false;
        
        # Mark that this level needs torch lighting effect
        &first_render = true;
    }

    func &attackMonster(m) {
        dmg = &player.totalAtk();
        m.hp = m.hp - dmg;
        if m.hp <= 0 {
            gain = &xpGainFromMonster(m);
            
            # Luck ring bonus: increase XP gains
            luck_bonus = &player.ringLuck();
            if luck_bonus > 0 {
                gain = gain + (luck_bonus * 1); # +1 XP per luck point
            }
            
            &gainXP(gain);

            gold_gain = randInt(1, 3) + (&player.depth // 2);
            
            # Luck ring bonus: increase gold drops
            luck_bonus = &player.ringLuck();
            if luck_bonus > 0 {
                gold_gain = gold_gain + (luck_bonus * 2); # +2 gold per luck point
            }
            
            &player.gold = &player.gold + gold_gain;

            # remove monster by position (robust)
            idx = -1;
            for i = 0, i < length(&monsters), i += 1 {
                if &monsters[i].x == m.x and &monsters[i].y == m.y { idx = i; break; }
            }
            if idx != -1 { &monsters.pop(idx); }

            &message = "You slay the " + m.name + "! (+" + C_GREEN + str(gain) + " XP" + C_WHITE + ", +" + C_YELLOW + str(gold_gain) + "g" + C_WHITE + ")";
        } else {
            &message = "You hit the " + m.name + " for " + C_RED + str(dmg) + C_WHITE + ".";
            &monsterTurn();
            # The monster's attack message will now be added to the existing message
        }
    }

    func &pickup() {
        idx = &itemIndexAt(&player.x, &player.y);
        if idx == -1 { &message = "Nothing to pick up."; return; }
        rec = &items[idx];
        
        # Check if this is a chest (with proper safety check)
        is_chest = false;
        if "is_chest" in rec { is_chest = rec["is_chest"]; }
        
        if is_chest {
            &message = "You open the chest and find:";
            # Add all chest items to inventory
            for i = 0, i < length(rec["it"]), i += 1 {
                item = rec["it"][i];
                &player.inventory.append(item);
                &message = &message + " " + item.toString();
            }
            &items.pop(idx);
        } else {
            # Regular single item
            &items.pop(idx);
            &player.inventory.append(rec["it"]);
            &message = "Picked up " + rec["it"].toString() + ".";
        }
    }

    # --- Equipment helpers ---
    func &equipWeapon(it) {
        old = &player.weapon;
        &player.weapon = it;
        if old { &player.inventory.append(old); }
        &message = "Equipped weapon: " + it.name + ".";
    }

    func &equipArmor(it) {
        old = &player.armor;
        &player.armor = it;
        if old { &player.inventory.append(old); }
        &message = "Equipped armor: " + it.name + ".";
    }

    func &equipRing(it) {
        # Ensure rings list has MAX_RING_SLOTS entries using a temp
        rings_tmp = &player.rings;
        while length(rings_tmp) < MAX_RING_SLOTS { rings_tmp.append(Null); }
        &player.rings = rings_tmp;

        # Try to fill the first empty slot
        for i = 0, i < MAX_RING_SLOTS, i += 1 {
            if not &player.rings[i] {
                rings_tmp2 = &player.rings;
                rings_tmp2[i] = it;         # modify temp
                &player.rings = rings_tmp2; # write back
                &message = "Equipped ring: " + it.name + ".";
                return;
            }
        }

        # Both occupied: ask which to replace (1-based)
        print("Replace which ring? [1 or 2, blank cancels]");
        inp = input("> ").strip();
        if inp == "" { &message = "Equip canceled."; return; }
        if not inp.isDigit() { &message = "Please enter 1 or 2."; return; }
        idx1 = int(inp);
        if idx1 < 1 or idx1 > MAX_RING_SLOTS { &message = "Invalid slot."; return; }
        idx = idx1 - 1;

        old = &player.rings[idx];
        if old { &player.inventory.append(old); }

        rings_tmp3 = &player.rings;
        rings_tmp3[idx] = it;
        &player.rings = rings_tmp3;

        &message = "Equipped ring in slot " + str(idx1) + ": " + it.name + ".";
    }

    func &useInventory() {
        # Check if there are any equipped items or if inventory has items
        has_equipped = &player.weapon or &player.armor;
        for i = 0, i < MAX_RING_SLOTS, i += 1 {
            if i < length(&player.rings) and &player.rings[i] { 
                has_equipped = true; 
                break; 
            }
        }
        
        # Only return early if no equipped items AND no inventory items
        if length(&player.inventory) == 0 and not has_equipped {
            print("Inventory is empty."); return;
        }
        
        # Show equipped items first
        print("=== EQUIPPED ITEMS ===");
        if &player.weapon { 
            print(C_RESET + "  Weapon: " + &player.weapon.toString()); 
        } else { 
            print(C_RESET + "  Weapon: none"); 
        }
        if &player.armor { 
            print(C_RESET + "  Armor: " + &player.armor.toString()); 
        } else { 
            print(C_RESET + "  Armor: none"); 
        }
        
        # Show rings
        for i = 0, i < MAX_RING_SLOTS, i += 1 {
            if i < length(&player.rings) and &player.rings[i] { 
                print(C_RESET + "  Ring[" + str(i + 1) + "]: " + &player.rings[i].toString()); 
            } else { 
                print(C_RESET + "  Ring[" + str(i + 1) + "]: none"); 
            }
        }
        
        print("\n=== INVENTORY ===");
        which = "";
        if length(&player.inventory) == 0 {
            print(C_RESET + "  (No items in inventory)");
            _ = input("Press Enter to return: ");
            return;
        } else {
            for i = 0, i < length(&player.inventory), i += 1 {
                it = &player.inventory[i];
                # show indices starting at 1
                print(C_RESET + "  [" + str(i + 1) + "] " + it.toString() + "  {" + it.kind + "}");
            }
            which = input("Use/equip which index (1.." + str(length(&player.inventory)) + ", blank cancels)? ").strip();
        }
        if which == "" { return; }
        if not which.isDigit() { print("Please enter a number."); return; }

        idx1 = int(which);
        if idx1 < 1 or idx1 > length(&player.inventory) { print("Invalid index."); return; }
        idx = idx1 - 1;  # convert to 0-based

        it2 = &player.inventory[idx];

        if it2.kind == "potion" {
            heal = it2.stats;
            &player.hp = &player.hp + heal;
            if &player.hp > &player.hp_max { &player.hp = &player.hp_max; }
            print("You drink the potion and heal " + str(heal) + ".");
            _ = input("(press Enter) ");
            &player.inventory.pop(idx);
            # Re-render and show inventory again
            &render();
            &useInventory();
            return;
        } elif it2.kind == "weapon" {
            &player.inventory.pop(idx);
            &equipWeapon(it2);
            # Re-render and show inventory again
            &render();
            &useInventory();
            return;
        } elif it2.kind == "armor" {
            &player.inventory.pop(idx);
            &equipArmor(it2);
            # Re-render and show inventory again
            &render();
            &useInventory();
            return;
        } elif it2.kind == "ring" {
            &player.inventory.pop(idx);
            &equipRing(it2);
            # Re-render and show inventory again
            &render();
            &useInventory();
            return;
        } else {
            print("You can't use that.");
            _ = input("(press Enter) ");
        }
    }

    func &showStats() {
        print("=== Player Stats ===");
        print(&player.statsStr());
        if &player.weapon { print("  Weapon: " + &player.weapon.toString()); }
        else { print("  Weapon: none"); }
        if &player.armor { print("  Armor: " + &player.armor.toString()); }
        else { print("  Armor: none"); }

        # ring slots — pad via temp (Funcy-safe)
        rings_tmp = &player.rings;
        while length(rings_tmp) < MAX_RING_SLOTS { rings_tmp.append(Null); }
        &player.rings = rings_tmp;
        for i = 0, i < MAX_RING_SLOTS, i += 1 {
            label = "none";
            if &player.rings[i] { label = &player.rings[i].toString(); }
            print("  Ring[" + str(i + 1) + "]: " + label);
        }

        # XP to next
        print("XP to next level: " + str(&player.xpToNext()));
        _ = input("\n(press Enter to return) ");
    }

    # ---------- RENDER ----------

    func &render() {
        # Precompute quick lookup maps (O(entities))
        items_map = {};        # key: "x,y" -> glyph
        for i = 0, i < length(&items), i += 1 {
            rec = &items[i];
            key = str(rec["x"]) + "," + str(rec["y"]);
            items_map[key] = rec["glyph"];
        }
        monsters_map = {};     # key: "x,y" -> glyph
        for i = 0, i < length(&monsters), i += 1 {
            m = &monsters[i];
            key = str(m.x) + "," + str(m.y);
            monsters_map[key] = m.glyph;
        }

        # Visibility: full if disabled; radius-only if enabled
        vis = Null;
        if &fov_enabled { vis = &computeVisibilityRadius(); }

        # Cache exit coords for cheap compare
        ex = &exit[0]; ey = &exit[1];

        lines = [];
        header = "== Funcy Roguelike :: " + &player.statsStr() + " ==";
        lines.append(header);
        if &message != "" { lines.append(C_WHITE + &message + C_RESET); }
        else { lines.append(" "); }  # keep board from shifting

        for y = 0, y < MAP_H, y += 1 {
            row_chars = [];
            for x = 0, x < MAP_W, x += 1 {
                visible = true;
                if &fov_enabled { visible = vis[y][x]; }
                ch = " ";

                if visible {
                    &seen[y][x] = true;

                    # base tile
                    base = &grid[y][x];
                    ch = base;

                    key = str(x) + "," + str(y);
                    if key in items_map { ch = items_map[key]; }
                    if key in monsters_map { ch = monsters_map[key]; }

                    # trader overlay
                    if &trader {
                        if x == &trader["x"] and y == &trader["y"] { ch = "T"; }
                    }

                    # player on top
                    if x == &player.x and y == &player.y { ch = &player.glyph; }

                    # visible tinting / colors
                    ch = &applyColorVisibleTile(ch);
                } else {
                    if &seen[y][x] {
                        if &grid[y][x] == "#" {
                            ch = "#";
                            if &color_enabled { 
                                # Remembered walls use dimmed gray, not theme colors
                                ch = C_WALL_DIM + ch + C_RESET;
                            }
                        } elif x == ex and y == ey {
                            ch = ">";
                            if &color_enabled { ch = C_EXIT + ch + C_RESET; }
                        } else {
                            ch = " ";
                        }
                    } else {
                        ch = " ";
                    }
                }
                row_chars.append(ch);
            }
            lines.append("".join(row_chars));
        }

        print("\e[H\e[J" + "\n".join(lines));
    }

    # ---------- MONSTER AI ----------

    
    func &monsterTurn() {
        # Build an occupancy map once (O(M))
        occ = {};  # "x,y" -> true
        for j = 0, j < length(&monsters), j += 1 {
            mm = &monsters[j];
            if mm.hp > 0 {
                occ[str(mm.x) + "," + str(mm.y)] = true;
            }
        }

        for i = 0, i < length(&monsters), i += 1 {
            m = &monsters[i];
            if m.hp <= 0 { continue; }

            dx = &player.x - m.x;
            dy = &player.y - m.y;

            adx = dx; if adx < 0 { adx = -adx; }
            ady = dy; if ady < 0 { ady = -ady; }

            if (adx + ady) == 1 {
                # Reveal disguise if monster attacks (mimics can't stay hidden when attacking!)
                if m.hasAbility("disguise") and m.disguised_as != "" {
                    m.revealDisguise();
                }
                
                dmg = m.atk;
                red = &player.totalDef();
                dmg = dmg - red;
                if dmg < 1 { dmg = 1; }

                &player.hp = &player.hp - dmg;
                # Append monster attack to existing message instead of overwriting
                if &message == "" {
                    &message = "The " + m.name + " hits you for " + C_RED + str(dmg) + C_WHITE + "!";
                } else {
                    &message = &message + " The " + m.name + " hits you for " + C_RED + str(dmg) + C_WHITE + "!";
                }
                if &player.hp <= 0 {
                    &dead = true;
                    return;
                }
                continue;
            }

            # Check if monster is in player's view radius
            in_view = (adx + ady) <= 6;
            
            # Handle disguised mimics: they don't move when in view, but can sneak around when hidden
            if m.hasAbility("disguise") and m.disguised_as != "" {
                if in_view {
                    # In view: stay still like a real chest
                    continue;
                } else {
                    # Out of view: small chance to sneak around (15%)
                    if randInt(1, 7) != 1 { continue; }
                    # When sneaking, mimics prefer to move towards the player's general direction
                    if randInt(1, 3) == 1 { # 33% chance to be smart about it
                        if adx >= ady {
                            if dx > 0 { stepX = 1; } elif dx < 0 { stepX = -1; }
                        } else {
                            if dy > 0 { stepY = 1; } elif dy < 0 { stepY = -1; }
                        }
                    }
                    # Otherwise, they'll just wander randomly (handled by the normal movement logic below)
                }
            }
            # Note: Revealed mimics (disguised_as == "") move normally through the standard movement logic below

            stepX = 0; stepY = 0;
            if in_view and randInt(0,1) == 1 {
                if adx >= ady {
                    if dx > 0 { stepX = 1; } elif dx < 0 { stepX = -1; }
                } else {
                    if dy > 0 { stepY = 1; } elif dy < 0 { stepY = -1; }
                }
            } else {
                dirs = [[1,0],[-1,0],[0,1],[0,-1],[0,0]];
                d = randChoice(dirs);
                stepX = d[0]; stepY = d[1];
            }

            nx = m.x + stepX; ny = m.y + stepY;
            k_old = str(m.x) + "," + str(m.y);
            k_new = str(nx) + "," + str(ny);

            if &passable(nx, ny) and not (nx == &player.x and ny == &player.y) and not (k_new in occ) {
                # update occupancy
                occ.pop(k_old);
                occ[k_new] = true;
                m.x = nx; m.y = ny;
            }
        }
    }


    # ---------- LUCK RING & ENHANCED RING SYSTEM ----------
    
    func &applyLuckRingBonus(item) {
        luck_bonus = &player.ringLuck();
        if luck_bonus == 0 { return item; }
        
        # Each luck point gives a 50% chance to improve the item
        # Each successful improvement halves the chance for the next one
        improvements = 0;
        chance = 50 * luck_bonus; # 50% base chance per luck point
        upgraded = true;
        
        while upgraded {
            upgraded = false;
            if randInt(1, 100) <= chance {
                # Successfully improve the item
                if item.kind == "potion" { 
                    item.stats = item.stats + 2; # +2 healing
                } elif item.kind == "weapon" {
                    item.stats = item.stats + 1; # +1 ATK
                } elif item.kind == "armor" {
                    item.stats = item.stats + 1; # +1 DEF
                }
                improvements = improvements + 1;
                upgraded = true;
                chance = chance // 2; # Halve the chance for next improvement
            }
        }
        
        return item;
    }
    
    # ---------- INPUT-ACTION HELPERS ----------

    func &tryMove(dx, dy) {
        nx = &player.x + dx; ny = &player.y + dy;
        if not inBounds(nx, ny) { &message = "You bump the edge."; return; }

        m = &monsterAt(nx, ny);
        if m { &attackMonster(m); return; }

        if &passable(nx, ny) {
            &player.x = nx; &player.y = ny;
            if &grid[ny][nx] == ">" {
                &depthTransition(&player.depth + 1);

                # Rest-shop chance
                r = randInt(1, 100);
                if r <= REST_SHOP_CHANCE {
                    stock = &generateShopStock();
                    &shopMenu(stock, "Rest Shop");
                }

                &buildLevel(&player.depth + 1);   # no healing between levels
                return;
            }
            &monsterTurn();
            # Check terrain effects after monster turn (so they don't get overwritten)
            &checkTerrainEffects(&player.x, &player.y);
            return;
        } else {
            # Give specific messages for different terrain types
            tile = &grid[ny][nx];
            if tile == "~" {
                # Water vs lava based on theme
                if &theme == "forge" {
                    &message = "The lava blocks your way.";
                } else {
                    &message = "The water blocks your way.";
                }
            } elif tile == "|" {
                &message = "A pillar blocks your way.";
            } elif tile == "#" {
                &message = "A wall blocks your way.";
            } else {
                &message = "Something blocks your way.";
            }
        }
    }

    # ---------- TRANSITION FX ----------

    func &depthTransition(newDepth) {
        # Go to top-left and clear screen
        print("\e[H");

        # Build one full-width blank line
        blank = "";
        for i = 0, i < MAP_W, i += 1 { blank = blank + " "; }

        # Print enough rows to "wipe" downward
        total = MAP_H + 1;   # a little extra for effect
        for n = 0, n < total, n += 1 {
            print(blank);
            delayMs(50);
        }
    }
}
