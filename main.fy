# main.fy — entry point and input loop
import "config.fy";
import "map.fy";
import "entities.fy";
import "game.fy";
import "intro.fy";


func main() {
    # Play the intro sequence first
    if INTRO_ENABLED {
        playIntro();
    }
    
    g = Game();
    
    # First render with torch lighting effect
    if g.first_render and INTRO_ENABLED {
        g.renderWithTorchLighting(2, FOV_RADIUS, 2, 100);
    }
    
    while true {
        # Check if this is the first render (e.g., after leaving shop)
        if g.first_render and INTRO_ENABLED {
            g.renderWithTorchLighting(2, FOV_RADIUS, 2, 1);
        } else {
            g.render();
        }
        cmd = input("[WASD]=move  f=pick  i=inv  r=stats  t=talk  v=toggle-fov  n=next  q=quit > ").strip();
        g.message = ""; # Clear message after each input
        key = "";
        if length(cmd) > 0 { key = cmd[0]; }

        if key == "q" or key == "Q" {
            print("");
            print("Do you wish to extinguish your torch? (y/n)");
            confirm = input("> ").strip().lower();
            if confirm == "y" or confirm == "yes" {
                if INTRO_ENABLED {
                    # Play the reverse torch lighting effect
                    g.renderWithTorchLighting(FOV_RADIUS, 2, -2, 1);
                    
                    # Show final dark state (just player)
                    g.renderPlayerOnly();
                    delayMs(500);
                    
                    # Wipe the map away
                    g.mapWipeEffect();
                    
                    # Final goodbye message
                    print("");
                    print("The shadows of the dungeon claim you once more...");
                    print("Your torch flickers and dies as you retreat to the surface.");
                    print("");
                    return;
                } else {
                    return;
                }
            }
            # If they don't confirm, continue the game
            continue;
        }
        if key == "i" or key == "I" { g.useInventory(); continue; }
        if key == "r" or key == "R" { g.showStats(); continue; }
        if key == "f" or key == "F" { g.pickup(); continue; }

        if key == "t" or key == "T" { g.talkToTrader(); continue; }
        if key == "v" or key == "V" {
            g.fov_enabled = not g.fov_enabled;
            state = "OFF";
            if g.fov_enabled { state = "ON"; }
            g.message = "Visibility: " + state;
            continue;
        }
        if key == "n" or key == "N" { 
            g.depthTransition(g.player.depth + 1);
            g.buildLevel(g.player.depth + 1);
            
            # Show torch lighting effect for new level
            if g.first_render {
                g.renderWithTorchLighting(2, FOV_RADIUS, 2, 1);
            }
            continue; 
        }

        dx = 0; dy = 0;
        if key == "w" or key == "W" { dy = -1; }
        elif key == "s" or key == "S" { dy = 1; }
        elif key == "a" or key == "A" { dx = -1; }
        elif key == "d" or key == "D" { dx = 1; }
        else { g.message = "Unknown command."; continue; }

        g.tryMove(dx, dy);

        if g.dead {
            g.render();
            print("");
            print("You died on depth " + str(g.player.depth) + ". Game Over!");
            return;
        }
    }
}

main();
