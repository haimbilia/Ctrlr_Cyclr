# Ctrl-Cyclr - a gui for devreorder
what it does:
it basically lets you pull up a menu before you launch the game that lets you choose which controllers you like to use and in which order.

how it does it:
briankendall made a dinput8.dll file that reads a .ini to know the order of the controllers, 
my script simply read and writes to that .ini file.
i changed the devicelister to instead of opening a gui to just list the controllers in the ini, under [ALL].
if you want to open the gui, run from command line with any argument, for example:

start dir\devicelister.exe "1"
  
installation:
basically you put everything from the release in the same folder as the emulator's .exe
you can also install it for entire system, read how to do it in the devreorder page.
it works best with Retroarch because of the autoconfig feature, allowing you to have config load up with the controller chosen.

also in devreorder.ini under [Settings] you can change the hotkeys to scroll the controllers and which player you choose.
Cycle_Players is also the hotkey that loads the gui, so basically everytime you load the gui it changes the player number.
you can change the player number by deleting the {GUID} lines under [order], so if you have 4 lines you will cycle through 4 players, if you have 2 lines you will cycle through 2 players.
you can change your controller name if you like, it will only affect which image is selected, you can also name your images by the {GUID},
so if you have 2 xbox controllers one in white and one in red you can have separate images for each.

Usage:
run Ctrlr_Cyclr.exe and press your Cycle_Players Hotkey (7 by default) then press your Cycle_Controllers (8 by default) to choose a controller,
you can also cycle the controllers by pressing any controllers buttons, but currently it doesn't work perfectly.
pressing 7 again will change the player number.
Leave it for 2 seconds, the gui will close and your selection will be saved (cycling the player again will cancel the selection).
you may have problems opening the gui on top of a full screen program, running it as administrator should fix it.
if you can't, try calling it from command line (can be done with joytokey).
running it from command line you can load the menu in the player number you want, for example:

start dir\ctrlr_cyclr.exe "2"

will load the gui selecting player 2 controllers.

you can also apply a controller to a player by name without loading the gui, for example:

start dir\ctrlr_cyclr.exe "1" "DualShock 4"

will apply DualShock 4 to player 1.

C+F4 kills app process
