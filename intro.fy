# intro.fy — animated title sequence for Funcy Roguelike
import "config.fy";

# Busy-wait delay using built-in time() which returns ms.
func delayMs(ms) {
    start = time();
    while time() - start < ms { }   # simple, portable
}

# Clear screen and move cursor to top-left
func clearScreen() {
    print("\e[H\e[J");
}

# Move cursor to specific position
func moveCursor(x, y) {
    print("\e[" + str(y) + ";" + str(x) + "H");
}

# Title text
func getTitle() {
    return "FUNCY ROGUELIKE";
}

# Subtitle text
func getSubtitle() {
    return "A Procedural Dungeon Crawler Adventure";
}

# Animated title sequence
func playIntro() {
    clearScreen();
    
    # Get title components
    title = getTitle();
    subtitle = getSubtitle();
    
    # Position title in center of screen
    title_x = 25;  # Center horizontally
    title_y = 8;   # Upper middle
    
    # Glitch effect - random characters appearing and disappearing
    for glitch_round = 0, glitch_round < 8, glitch_round += 1 {
        clearScreen();
        
        # Show glitched version
        glitched_title = "";
        for i = 0, i < length(title), i += 1 {
            if randInt(0, 3) == 0 {  # 25% chance to glitch
                # Random glitch character
                glitch_chars = ["@", "#", "$", "%", "&", "*", "!", "?"];
                glitched_title = glitched_title + "\e[91m" + randChoice(glitch_chars) + "\e[0m";  # Red glitch
            } else {
                glitched_title = glitched_title + title[i];
            }
        }
        
        moveCursor(title_x, title_y);
        print("\e[36m" + glitched_title + "\e[0m");  # Cyan title
        delayMs(150);
    }
    
    # Final clean title
    clearScreen();
    moveCursor(title_x, title_y);
    print("\e[36m" + title + "\e[0m");
    
    # Subtitle appears below title
    subtitle_x = 15;  # Center subtitle
    subtitle_y = title_y + 2;
    
    # Subtitle builds up character by character
    for i = 0, i < length(subtitle), i += 1 {
        clearScreen();
        
        # Show title
        moveCursor(title_x, title_y);
        print("\e[36m" + title + "\e[0m");
        
        # Build subtitle character by character
        current_subtitle = "";
        for j = 0, j <= i, j += 1 {
            current_subtitle = current_subtitle + subtitle[j];
        }
        
        moveCursor(subtitle_x, subtitle_y);
        print("\e[95m" + current_subtitle + "\e[0m");  # Magenta
        
        delayMs(100);
    }
    
    # Final display with both title and subtitle
    clearScreen();
    moveCursor(title_x, title_y);
    print("\e[36m" + title + "\e[0m");
    
    moveCursor(subtitle_x, subtitle_y);
    print("\e[95m" + subtitle + "\e[0m");
    
    # Pause briefly before loading game
    delayMs(1500);
    
    # Fade out
    clearScreen();
}