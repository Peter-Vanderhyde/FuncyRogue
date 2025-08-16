# entities.fy — game entities and abilities

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
