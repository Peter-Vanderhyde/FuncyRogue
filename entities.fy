# entities.fy — game entities and abilities

# Utility function to choose a random element from a list
func randChoice(list) {
    if length(list) == 0 { return Null; }
    return list[randInt(0, length(list) - 1)];
}

class Player {
    func &Player(x, y) {
        &x = x; &y = y;
        &hp = 20;
        &hp_max = 20;
        &atk = 3;                # base attack (no weapon/rings/perks)
        &depth = 1;

        # Leveling
        &xp = 0;
        &level = 1;

        # Inventory + equipment
        &inventory = [];
        &weapon = Null;          # Item(kind="weapon")
        &armor  = Null;          # Item(kind="armor")
        &rings  = [];            # up to MAX_RING_SLOTS Items(kind="ring")

        # Simple permanent perks
        &perk_atk_bonus = 0;
        &perk_def_bonus = 0;

        # Economy
        &gold = GOLD_START;

        &glyph = "@";
    }

    func &baseAtk() { return &atk; }

    func &weaponAtk() {
        if &weapon { return &weapon.stats; }
        return 0;
    }

    func &ringAtk() {
        total = 0;
        for i = 0, i < length(&rings), i += 1 {
            r = &rings[i];
            if r and r.subkind == "power" { total = total + r.stats; }
        }
        return total;
    }
    
    func &ringLuck() {
        total = 0;
        for i = 0, i < length(&rings), i += 1 {
            r = &rings[i];
            if r and r.subkind == "luck" { total = total + r.stats; }
        }
        return total;
    }

    func &totalAtk() {
        return &baseAtk() + &weaponAtk() + &ringAtk() + &perk_atk_bonus;
    }

    func &armorDef() {
        if &armor { return &armor.stats; }
        return 0;
    }

    func &ringDef() {
        total = 0;
        for i = 0, i < length(&rings), i += 1 {
            r = &rings[i];
            if r and r.subkind == "defense" { total = total + r.stats; }
        }
        return total;
    }

    func &totalDef() {
        return ARMOR_BASE_REDUCTION + &armorDef() + &ringDef() + &perk_def_bonus;
    }
    


    func &xpThresholdFor(lv) {
        return LEVEL_XP_BASE + (lv - 1) * LEVEL_XP_SCALE;
    }

    func &xpToNext() {
        need = &xpThresholdFor(&level);
        rem = need - &xp;
        if rem < 0 { rem = 0; }
        return rem;
    }

    func &statsStr() {
        atk_total = &totalAtk();
        def_total = &totalDef();
        w = "none"; if &weapon { w = "ATK +" + str(&weapon.stats); }
        a = "none"; if &armor  { a = "DEF +" + str(&armor.stats); }
        
        # Show individual ring slots like before
        r0 = "none";
        if length(&rings) > 0 and &rings[0] { r0 = &rings[0].statsStr(); }
        r1 = "none";
        if length(&rings) > 1 and &rings[1] { r1 = &rings[1].statsStr(); }
        
        return "Lvl " + str(&level) + C_LIGHT_BLUE + "  XP " + str(&xp) + "/" + str(&xpThresholdFor(&level))
             + C_RED + "  HP " + str(&hp) + "/" + str(&hp_max)
             + C_GREEN + "  ATK " + str(atk_total)
             + "  DEF " + str(def_total)

             + C_YELLOW + "  GOLD " + str(&gold)
             + C_GREEN + "  Wpn:[" + w + "] Arm:[" + a + "] Rings:[" + r0 + C_GREEN + "," + r1 + C_GREEN + "]  Depth " + str(&depth);
    }
}

class Item {
    func &Item(name, kind, stats) {
        &name = name;
        &kind = kind;       # "potion" | "weapon" | "armor" | "ring"
        &stats = stats;     # heal amount OR atk bonus OR def bonus
        &subkind = "";      # used for rings: "power"/"defense"
    }

    func &toString() {
        if &kind == "potion" { return &name + " (+" + C_RED + str(&stats) + " HP" + C_RESET + ")"; }
        elif &kind == "weapon" { return &name + " (+" + C_GREEN + str(&stats) + " ATK" + C_RESET + ")"; }
        elif &kind == "armor"  { return &name + " (+" + C_GREEN + str(&stats) + " DEF" + C_RESET + ")"; }
        elif &kind == "ring"   { 
            if &subkind == "power" { return &name + " (+" + C_GREEN + str(&stats) + " ATK" + C_RESET + ")"; }
            elif &subkind == "defense" { return &name + " (+" + C_GREEN + str(&stats) + " DEF" + C_RESET + ")"; }
            elif &subkind == "luck" { return &name + " (+" + C_YELLOW + str(&stats) + " LCK" + C_RESET + ")"; }
            else { return &name; }
        }
        return &name;
    }
    
    # Method to show just the stats for rings (used in stats bar)
    func &statsStr() {
        if &kind == "ring" {
            if &subkind == "power" { return "+" + C_GREEN + str(&stats) + " ATK" + C_RESET; }
            elif &subkind == "defense" { return "+" + C_GREEN + str(&stats) + " DEF" + C_RESET; }
            elif &subkind == "luck" { return "+" + C_YELLOW + str(&stats) + " LCK" + C_RESET; }
            else { return "+" + C_WHITE + str(&stats) + " RING" + C_RESET; }
        }
        return &name;
    }
}

# Base Monster class with component-based abilities
class Monster {
    func &Monster(name, x, y, hp, atk) {
        &name = name;
        &x = x; &y = y;
        &hp = hp; &atk = atk;
        # glyph used for rendering on the map
        g = name[0];
        &glyph = g;
        &abilities = []; # List of ability objects
        &disguised_as = ""; # What this monster is disguised as
    }

    func &isAlive() { return &hp > 0; }

    func &takeDamage(n) {
        &hp = &hp - n;
        if &hp < 0 { &hp = 0; }
        
        # Check if any abilities trigger on damage
        for i = 0, i < length(&abilities), i += 1 {
            ability = &abilities[i];
            if ability.type == "disguise" {
                &revealDisguise();
            }
        }
    }
    
    func &addAbility(ability) {
        &abilities.append(ability);
        # Apply ability effects
        if ability.type == "disguise" {
            &applyDisguise(ability.disguise_as);
        }
    }
    
    func &applyDisguise(disguise_type) {
        &disguised_as = disguise_type;
        if disguise_type == "chest" {
            &glyph = "C";
            # can_move is no longer used - movement is controlled in monsterTurn()
        }
    }
    
    func &revealDisguise() {
        if &disguised_as != "" {
            &glyph = "M"; # M for mimic
            &disguised_as = "";
        }
    }
    
    func &hasAbility(ability_type) {
        for i = 0, i < length(&abilities), i += 1 {
            if &abilities[i].type == ability_type { return true; }
        }
        return false;
    }
    
    func &getAbility(ability_type) {
        for i = 0, i < length(&abilities), i += 1 {
            if &abilities[i].type == ability_type { return &abilities[i]; }
        }
        return Null;
    }

    func &toString() {
        ability_desc = "";
        for i = 0, i < length(&abilities), i += 1 {
            if i > 0 { ability_desc = ability_desc + ", "; }
            ability_desc = ability_desc + &abilities[i].name;
        }
        if &disguised_as != "" {
            return &disguised_as + " (disguised " + &name + ")";
        } else {
            return &name + " (HP " + str(&hp) + ", ATK " + str(&atk) + ", Abilities: " + ability_desc + ")";
        }
    }
}

# Ability system - monsters can have multiple abilities
class Ability {
    func &Ability(type, name, description) {
        &type = type; # "ranged", "split", "disguise", etc.
        &name = name; # Human-readable name
        &description = description; # What the ability does
    }
}

# Ranged attack ability
class RangedAbility {
    func &RangedAbility(range) {
        &type = "ranged";
        &name = "Ranged Attack";
        &description = "Can attack from " + str(range) + " tiles away";
        &range = range;
    }
}

# Split ability for slimes
class SplitAbility {
    func &SplitAbility(max_splits) {
        &type = "split";
        &name = "Split";
        &description = "Splits into smaller pieces when killed (max " + str(max_splits) + ")";
        &max_splits = max_splits;
        &split_count = 0;
    }
    
    func &canSplit() { return &split_count < &max_splits; }
    
    func &incrementSplit() { &split_count = &split_count + 1; }
}

# Disguise ability for mimics
class DisguiseAbility {
    func &DisguiseAbility(disguise_as) {
        &type = "disguise";
        &name = "Disguise";
        &description = "Disguises as " + disguise_as;
        &disguise_as = disguise_as;
    }
}

# Summon ability for necromancers
class SummonAbility {
    func &SummonAbility(monster_type, max_summons) {
        &type = "summon";
        &name = "Summon";
        &description = "Summons " + monster_type + " (max " + str(max_summons) + ")";
        &monster_type = monster_type;
        &max_summons = max_summons;
        &summon_count = 0;
    }
    
    func &canSummon() { return &summon_count < &max_summons; }
    
    func &incrementSummon() { &summon_count = &summon_count + 1; }
}

# Armor ability for golems
class ArmorAbility {
    func &ArmorAbility(armor_value) {
        &type = "armor";
        &name = "Armor";
        &description = "Reduces incoming damage by " + str(armor_value);
        &armor_value = armor_value;
    }
}



# Theme-specific monster definitions
func createCatacombsMonster(x, y, depth) {
    monster_type = randInt(1, 4);
    if monster_type == 1 {
        # Skeleton - basic undead
        hp = 4 + depth;
        atk = 2 + (depth // 2);
        monster = Monster("Skeleton", x, y, hp, atk);
        monster.glyph = "S";
        return monster;
    } elif monster_type == 2 {
        # Zombie - slow but tough
        hp = 6 + depth;
        atk = 1 + (depth // 3);
        monster = Monster("Zombie", x, y, hp, atk);
        monster.glyph = "Z";
        return monster;
    } elif monster_type == 3 {
        # Necromancer - can summon skeletons
        hp = 3 + depth;
        atk = 2 + (depth // 2);
        monster = Monster("Necromancer", x, y, hp, atk);
        monster.glyph = "N";
        summon_ability = SummonAbility("Skeleton", 2);
        monster.addAbility(summon_ability);
        return monster;
    } else {
        # Wraith - fast but weak
        hp = 2 + depth;
        atk = 3 + (depth // 2);
        monster = Monster("Wraith", x, y, hp, atk);
        monster.glyph = "W";
        return monster;
    }
}

func createCavesMonster(x, y, depth) {
    monster_type = randInt(1, 4);
    if monster_type == 1 {
        # Slime - splits when killed
        hp = 3 + depth;
        atk = 1 + (depth // 3);
        monster = Monster("Slime", x, y, hp, atk);
        monster.glyph = "s";
        split_ability = SplitAbility(2);
        monster.addAbility(split_ability);
        return monster;
    } elif monster_type == 2 {
        # Bat - fast and ranged
        hp = 2 + depth;
        atk = 1 + (depth // 2);
        monster = Monster("Bat", x, y, hp, atk);
        monster.glyph = "B";
        ranged_ability = RangedAbility(3);
        monster.addAbility(ranged_ability);
        return monster;
    } elif monster_type == 3 {
        # Cave Spider - web ability
        hp = 4 + depth;
        atk = 2 + (depth // 2);
        monster = Monster("Cave Spider", x, y, hp, atk);
        monster.glyph = "S";
        return monster;
    } else {
        # Cave Dweller - basic
        hp = 3 + depth;
        atk = 2 + (depth // 2);
        monster = Monster("Cave Dweller", x, y, hp, atk);
        monster.glyph = "D";
        return monster;
    }
}

func createForgeMonster(x, y, depth) {
    monster_type = randInt(1, 4);
    if monster_type == 1 {
        # Golem - high armor, slow
        hp = 8 + depth;
        atk = 2 + (depth // 2);
        monster = Monster("Golem", x, y, hp, atk);
        monster.glyph = "G";
        armor_ability = ArmorAbility(2);
        monster.addAbility(armor_ability);
        return monster;
    } elif monster_type == 2 {
        # Fire Elemental - ranged fire attack
        hp = 3 + depth;
        atk = 3 + (depth // 2);
        monster = Monster("Fire Elemental", x, y, hp, atk);
        monster.glyph = "F";
        ranged_ability = RangedAbility(4);
        monster.addAbility(ranged_ability);
        return monster;
    } elif monster_type == 3 {
        # Forge Worker - basic but tough
        hp = 5 + depth;
        atk = 2 + (depth // 2);
        monster = Monster("Forge Worker", x, y, hp, atk);
        monster.glyph = "W";
        return monster;
    } else {
        # Lava Spawn - fire damage
        hp = 4 + depth;
        atk = 2 + (depth // 2);
        monster = Monster("Lava Spawn", x, y, hp, atk);
        monster.glyph = "L";
        return monster;
    }
}
