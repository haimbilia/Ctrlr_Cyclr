#NoEnv
#SingleInstance, Force
SetWinDelay, -1
SetBatchLines, -1
#Include gdip.ahk

;####################### button press ######################
class MyClass{
	__New(){
	
		fn := this._ProcessInput.Bind(this)
		this.hkhandler := new HkHandler(fn)
		;Gui, Add, ListView, w280 h190, Type|Code|Name|Event
		LV_ModifyCol(3, 100)
		;Gui, Show, w300 h200 x0 y0
		
	}
	
	; All Input events should flow through here
	_ProcessInput(obj){
	
		static mouse_lookup := ["Lbutton", "RButton", "MButton", "XButton1", "XButton2", "WheelU", "WheelD", "WheelL", "WheelR"]
		static pov_directions := ["U", "R", "D", "L"]
		static event_lookup := {0: "Release", 1: "Press"}
		

			key := obj.joyid "Joy" obj.Code
			if (event_lookup[obj.event] = "Press")
			{
				cycle()
			}
		LV_Add(,obj.Type, obj.code, key, event_lookup[obj.event])
		
		

		
		; Do not block input
		return 0
	}

	; Gui Closed
	Exit(){
		this.hkhandler.Exit()
	}
}

; The hotkey handler class
class HkHandler {
	#MaxThreadsPerHotkey 1000
	__New(callback){
		static WH_KEYBOARD_LL := 13, WH_MOUSE_LL := 14
		; Lookup table to accelerate finding which mouse button was pressed

		this._Callback := callback
		
		; Hook Input
		this._hHookKeybd := this._SetWindowsHookEx(WH_KEYBOARD_LL, RegisterCallback(this._ProcessKHook,"Fast",,&this))
		this._hHookMouse := this._SetWindowsHookEx(WH_MOUSE_LL, RegisterCallback(this._ProcessMHook,"Fast",,&this))
		
		this._JoysticksWithHats := []
		Loop 8 {
			joyid := A_Index
			joyinfo := GetKeyState(joyid "JoyInfo")
			if (joyinfo){
				; watch buttons
				Loop % 32 {
					fn := this._ProcessJHook.Bind(this, joyid, A_Index)
					hotkey, % joyid "Joy" A_Index, % fn
				}
				; Watch POVs
				if (instr(joyinfo, "p")){
					this._JoysticksWithHats.push(joyid)
				}
			}
		}
		fn := this._WatchJoystickPOV.Bind(this)
		SetTimer, % fn, 10
	}
	
	Exit(){
		; remove hooks
		this._UnhookWindowsHookEx(this._hHookKeybd)
		this._UnhookWindowsHookEx(this._hHookMouse)
	}

	; Process Joystick button down events
	_ProcessJHook(joyid, btn){
		;ToolTip % "Joy " joyid " Btn " btn
		this._Callback.({Type: "j", Code: btn, joyid: joyid, event: 1})
		fn := this._WaitForJoyUp.Bind(this, joyid, btn)
		SetTimer, % fn, -0
	}
	
	; Emulate up events for joystick buttons
	_WaitForJoyUp(joyid, btn){
		str := joyid "Joy" btn
		while (GetKeyState(str)){
			sleep 10
		}
		this._Callback.({Type: "j", Code: btn, joyid: joyid, event: 0})
	}
	
	; A constantly running timer to emulate "button events" for Joystick POV directions (eg 2JoyPOVU, 2JoyPOVD...)
	_WatchJoystickPOV(){
		static pov_states := [-1, -1, -1, -1, -1, -1, -1, -1]
		static pov_strings := ["1JoyPOV", "2JoyPOV", "3JoyPOV", "4JoyPOV", "5JoyPOV", "6JoyPOV" ,"7JoyPOV" ,"8JoyPOV"]
		static pov_direction_map := [[0,0,0,0], [1,0,0,0], [1,1,0,0] , [0,1,0,0], [0,1,1,0], [0,0,1,0], [0,0,1,1], [0,0,0,1], [1,0,0,1]]
		static pov_direction_states := [[0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0]]
		Loop % this._JoysticksWithHats.length() {
			joyid := this._JoysticksWithHats[A_Index]
			pov := GetKeyState(pov_strings[joyid])
			if (pov = pov_states[joyid]){
				; do not process stick if nothing changed
				continue
			}
			if (pov = -1){
				state := 1
			} else {
				state := round(pov / 4500) + 2
			}
			
			Loop 4 {
				if (pov_direction_states[joyid, A_Index] != pov_direction_map[state, A_Index]){
					this._Callback.({Type: "h", Code: A_Index, joyid: joyid, event: pov_direction_map[state, A_Index]})
				}
			}
			pov_states[joyid] := pov
			pov_direction_states[joyid] := pov_direction_map[state]
		}
	}
	
	; Process Keyboard Hook messages
	_ProcessKHook(wParam, lParam){
		; KBDLLHOOKSTRUCT structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644967%28v=vs.85%29.aspx
		; KeyboardProc function: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644984(v=vs.85).aspx
		
		; ToDo:
		; Use Repeat count, transition state bits from lParam to filter keys
		
		static WM_KEYDOWN := 0x100, WM_KEYUP := 0x101, WM_SYSKEYDOWN := 0x104
		static last_sc := 0
		static last_event := 0
		
		Critical
		
		if (this<0){
			Return DllCall("CallNextHookEx", "Uint", Object(A_EventInfo)._hHookKeybd, "int", this, "Uint", wParam, "Uint", lParam)
		}
		this:=Object(A_EventInfo)
		
		vk := NumGet(lParam+0, "UInt")
		Extended := NumGet(lParam+0, 8, "UInt") & 1
		sc := (Extended<<8)|NumGet(lParam+0, 4, "UInt")
		sc := sc = 0x136 ? 0x36 : sc
        ;key:=GetKeyName(Format("vk{1:x}sc{2:x}", vk,sc))
		event := wParam = WM_SYSKEYDOWN || wParam = WM_KEYDOWN
		
        if ( ! (sc = 541 || (last_event = event && last_sc = sc) ) ){		; ignore non L/R Control. This key never happens except eg with RALT
			block := this._Callback.({ Type: "k", Code: sc, event: event})
			last_sc := sc
			last_event := event
			if (block){
				return 1
			}
		}
		Return DllCall("CallNextHookEx", "Uint", Object(A_EventInfo)._hHookKeybd, "int", this, "Uint", wParam, "Uint", lParam)

	}
	

}


;####################### GDIP images ######################

class ImageViewer
{
   __New() {
      static exStyles := "E" . (WS_EX_LAYERED := 0x80000) | (WS_EX_TRANSPARENT := 0x20)
      Gui, New, -Caption +%exStyles% +LastFound +AlwaysOnTop +ToolWindow +hwndhGui -DPIScale
      Gui, Show, NA
      this.hwnd := hGui
   }
   
   __Delete() {
      Gui, % this.hwnd . ": Destroy"
   }
   
   Show(imageFilePath, x := "", y := "", w := "", h := "") {
      oGDIP := new GDIp
      if !pBitmap := oGDIP.BitmapFromFile(imageFilePath) {
         oGDIP := ""
         throw Exception("Failed to get bitmap from file")
      }
      oGDIP.GetImageDimensions(pBitmap, width, height)
    , ( w = -1 && w := width * h / height )
    , ( h = -1 && h := height * w / width )
    , ( w = "" && w := width)
    , ( h = "" && h := height )
    , ( x = "" && x := (A_ScreenWidth - w)//2 )
    , ( y = "" && y := (A_ScreenHeight - h)//2 )
    , oCDC := new this.CompatibleDC(0, w, h)
    , hDC := oCDC.hCDC
    , G := oGDIP.GraphicsFromHDC(hDC)
    , oGDIP.SetSmoothingMode(G, 4)
    , oGDIP.DrawImage(G, pBitmap, 0, 0, w, h, 0, 0, width, height)
    , oGDIP.UpdateLayeredWindow(this.hwnd, hDC, x, y, w, h)
    , oCDC := ""
    , oGDIP.DeleteGraphics(G)
    , oGDIP.DisposeImage(pBitmap)
   }
   
   class CompatibleDC
   {
      __New(hDC, w, h)  {
         this.hCDC := DllCall("CreateCompatibleDC", Ptr, hDC, Ptr)
       , this.hBM := this.CreateDibSection(w, h, this.hCDC)
       , this.oBM := DllCall("SelectObject", Ptr, this.hCDC, Ptr, this.hBM, Ptr)
      }
      
      __Delete()  {
         DllCall("SelectObject", Ptr, this.hCDC, Ptr, this.oBM, Ptr)
       , DllCall("DeleteDC", Ptr, this.hCDC)
       , DllCall("DeleteObject", Ptr, this.hBM)
      }
      
      CreateDibSection(w, h, hdc, bpp := 32, ByRef ppvBits := 0) {
         VarSetCapacity(bi, 40, 0)
       , NumPut(w, bi, 4, "UInt")
       , NumPut(h, bi, 8, "UInt")
       , NumPut(40, bi, 0, "UInt")
       , NumPut(1, bi, 12, "ushort")
       , NumPut(0, bi, 16, "uInt")
       , NumPut(bpp, bi, 14, "ushort")
         Return hbm := DllCall("CreateDIBSection", Ptr, hdc, Ptr, &bi, UInt, 0, PtrP, ppvBits, Ptr, 0, UInt, 0, Ptr)
      }
   }
}

class GDIp   {
   __New() {
      if !DllCall("GetModuleHandle", Str, "gdiplus", Ptr)
         DllCall("LoadLibrary", Str, "gdiplus")
      VarSetCapacity(si, A_PtrSize = 8 ? 24 : 16, 0), si := Chr(1)
    , DllCall("gdiplus\GdiplusStartup", UPtrP, pToken, Ptr, &si, Ptr, 0)
    , this.token := pToken
   }
   
   __Delete()  {
      DllCall("gdiplus\GdiplusShutdown", Ptr, this.token)
      if hModule := DllCall("GetModuleHandle", Str, "gdiplus", Ptr)
         DllCall("FreeLibrary", Ptr, hModule)
   }
   
   BitmapFromFile(sFile)  {
      DllCall("gdiplus\GdipCreateBitmapFromFile", WStr, sFile, PtrP, pBitmap)
      Return pBitmap
   }
   
   GraphicsFromHDC(hdc)  {
      DllCall("gdiplus\GdipCreateFromHDC", Ptr, hdc, PtrP, pGraphics)
      return pGraphics
   }
   
   SetSmoothingMode(pGraphics, SmoothingMode)  {
      return DllCall("gdiplus\GdipSetSmoothingMode", Ptr, pGraphics, Int, SmoothingMode)
   }
   
   DrawImage(pGraphics, pBitmap, dx, dy, dw, dh, sx, sy, sw, sh)  {
      DllCall("gdiplus\GdipDrawImageRectRect", Ptr, pGraphics, Ptr, pBitmap
                                             , Float, dx, Float, dy, Float, dw, Float, dh
                                             , Float, sx, Float, sy, Float, sw, Float, sh
                                             , Int, 2, Ptr, 0, Ptr, 0, Ptr, 0)
   }
   
   GetImageDimensions(pBitmap, ByRef Width, ByRef Height)  {
      DllCall("gdiplus\GdipGetImageWidth", Ptr, pBitmap, UIntP, Width)
    , DllCall("gdiplus\GdipGetImageHeight", Ptr, pBitmap, UIntP, Height)
   }
   
   UpdateLayeredWindow(hwnd, hdc, x, y, w, h, Alpha := 255) {
      VarSetCapacity(pt, 8)
    , NumPut(x, pt, 0, "UInt")
    , NumPut(y, pt, 4, "UInt")
      return DllCall("UpdateLayeredWindow", Ptr, hwnd, Ptr, 0, Ptr, &pt, Int64P, w|h<<32
                                          , Ptr, hdc, Int64P, 0, UInt, 0, UIntP, Alpha<<16|1<<24, UInt, 2)
   }
   
   DisposeImage(pBitmap)  {
      return DllCall("gdiplus\GdipDisposeImage", Ptr, pBitmap)
   }
   
   DeleteGraphics(pGraphics)  {
      return DllCall("gdiplus\GdipDeleteGraphics", Ptr, pGraphics)
   }
}

GetCommandLine( SkipParameters = 0 )
{
	AllCommandLine := SplitCommandString( DllCall( "GetCommandLineA", "Str" ), false, false )

	; Set the size beforehand to avoid multiple resizings while assembling it.
	VarSetCapacity( CommandLine, StrLen( AllCommandLine ) )

	;Scripts support command line parameters. The format is:
	;AutoHotkey.exe [Switches] [Script Filename] [Script Parameters]

	;And for compiled scripts, the format is:
	;CompiledScript.exe [Switches] [Script Parameters]

	InSwitches := true
	if ( !A_IsCompiled )
		SkipParameters++
	Loop, Parse, AllCommandLine, `n
	{
		if ( A_Index = 1 )
			continue
		StrippedCommand := StripWhitespace( A_LoopField )
		if ( InSwitches )
		{
			InSwitches := false
			if ( SubStr( StrippedCommand, 1, 1 ) = "/" )
			{
				; Just basing the switches on the slash is not enough.
				; The script might have its own slash parameters.
				; Ensure we only strip known AHK switches.
				if	(  StrippedCommand = "/f"
					|| StrippedCommand = "/r"
					|| StrippedCommand = "/force"
					|| StrippedCommand = "/restart"
					|| StrippedCommand = "/ErrorStdOut" )
				{
					InSwitches := true
					continue
				}
			}
		}
		if ( SkipParameters > 0 )
		{
			SkipParameters--
			continue
		}
		CommandLine .= A_LoopField
	}
	CommandLine := StripWhitespace( CommandLine, true, false )
	return CommandLine
}


SplitCommandString( String, StripQuotes = true, StripWhitespace = true )
{
	InQuotes := false
	NewLine := true

	; Set the probable/maximum size beforehand to avoid multiple resizings while assembling it.
	VarSetCapacity( OutString, StrLen( String ) )

	Loop, Parse, String
	{
		if ( !InQuotes )
		{
			if A_LoopField is space
			{
				if ( !NewLine )
				{
					NewLine := true
					OutString .= "`n"
				}
				if ( StripWhitespace )
					continue
			}
		}
		if A_LoopField is not space
			NewLine := false
		if ( A_LoopField = """" )
		{
			InQuotes := !InQuotes
			if ( StripQuotes )
				continue
		}
		OutString .= A_LoopField
	}
	return OutString
}

StripWhitespace( String, Front = true, Back = true )
{
	if String is space ; Those loops can't properly handle an entirely blank string.
		return ""

	if ( Front )
	{
		Loop, % StrLen( String ) ;%
		{
			Character := SubStr( String, A_Index, 1 )
			if Character is not space
			{
				StringTrimLeft, String, String, A_Index - 1
				break
			}
		}
	}
	if ( Back )
	{
		Length := StrLen( String )
		Loop, %Length%
		{
			Character := SubStr( String, Length - ( A_Index - 1 ), 1 )
			if Character is not space
			{
				StringTrimRight, String, String, A_Index - 1
				break
			}
		}
	}
	return String
}

	StrRepeat(string, times)
	{
	loop % times
	output .= string
	return output
	}
;######################## get command line parameters ###############################
	Ctrlr = %2%
	playernum = %1%
	if (Ctrlr)
	{
	Loop, Read, devreorder.ini
		{
			if (A_LoopReadLine !="")									 	;check if the line is not empty
			{
				line_array := A_LoopReadLine
				RegExMatch(line_array, "\[\K.*(?=\])", section)
				RegExMatch(line_array, """\K.*(?="")", NAME)
				if (section = "order")
				{
					orderline := A_INDEX
				}
				else if (section = "hidden")
				{
					hiddenline := A_INDEX
				}
				else if (section = "ALL")
				{
					allline := A_INDEX
				}
					if (NAME = Ctrlr)
				{
					RegExMatch(line_array, "\{\K.*(?=\})", SELGUID)
				}
				
			NAME = ""
			}

		}
	goto, TimeIdle	
	}
	if (playernum AND !Ctrlr)
	{
	goto, CmdCycle
	}
;######################## Load Settings ###############################	
IniRead, Cycle_Players, devreorder.ini, Settings, Cycle_Players
Hotkey,%Cycle_Players%,Cycle_Players

IniRead, Cycle_Controllers, devreorder.ini, Settings, Cycle_Controllers
Hotkey,%Cycle_Controllers%,Cycle_Controllers

IniRead, Minimize, devreorder.ini, Settings, Minimize_Gui
Hotkey,%Minimize%,Minimize
rundevicelister := 1
Return
;######################## Load/Reload Gui ###############################

Cycle_Players:
			Hotkey,%Cycle_Controllers%,Cycle_Controllers, ON
			Joystick_input := 1
			if (rundevicelister = 1)
			{
				run, devicelister.exe
				rundevicelister := 0
				
			}
			Gui, Destroy
			Gui, top:Destroy
			Gui, bg:Destroy
			Gui, bbg:Destroy
			for index, menu in MenuArray
			{
			ctrlr%A_Index% := delete ImageViewer
			ctrlr%A_Index%.delete()
			Shadow%A_Index% := delete ImageViewer
			Shadow%A_Index%.delete()
			}
			SetTimer, Minimize, 5000
			SetTimer, TimeIdle, OFF
			If (playernum >= maxplayer || !playernum || !maxplayer)
			{
				playernum :=1
			}
			else
			{
				playernum++
			}

		CmdCycle:
		Gui, bg:Destroy
		Gui, bg: +AlwaysOnTop +LastFound +Owner -Caption -0xC00000
		Gui, bg: Color, 171717
		Gui, bg: add, text, w%A_ScreenWidth%
		Gui, bg: Show, x0 y0 w%A_ScreenWidth% h%A_Screenheight%,Maximize
		WinSet, TransColor, 000000 0
		
	section := ""
	numctrlr := 0
	maxplayer := 0
	hiddenline := 0
	orderline := 0
	allline := 0
	Array := []
		Loop, Read, devreorder.ini
		{
			if (A_LoopReadLine !="")									 	
			{
				line_array := A_LoopReadLine
				RegExMatch(line_array, "\[\K.*(?=\])", section)
				if (section = "order")
				{
					orderline := A_INDEX
				}
				else if (section = "hidden")
				{
					hiddenline := A_INDEX
					
				}
				else if (section = "ALL")
				{
					allline := A_INDEX
				}
				
				if (A_INDEX > orderline)   	;check if the current line is after [ORDER]
				{	
					ORDER:=""
					RegExMatch(line_array, "\{", ORDER)
					if (ORDER and hiddenline = 0)
					{
						maxplayer ++
					}
				}
				
				if (A_INDEX = playernum + orderline)   						;check if the current line is after [ORDER] and is the selected player number
				{
					RegExMatch(line_array, "\{\K.*(?=\})", GUID)
					lastctrlr = %GUID%
					
				}
				else if (allline > 0 and A_INDEX > allline)   				;check if the current line is after [ALL]
				{
					RegExMatch(line_array, """\K.*(?="")", NAME)
					if (NAME)
					{
						numctrlr ++
						Array.Push(A_LoopReadLine)
						
					}
				}
			NAME = ""
			}

		}
	


		xMidScrn :=  A_ScreenWidth/2
		yMidScrn :=  A_ScreenHeight/2
	

		selctrlrnum := 0
		FirstCtrlrName := "No Controller"
		
		for index, plyrctrlr in Array
		{
			RegExMatch(plyrctrlr, "\{\K.*(?=\})", GUID)
			RegExMatch(plyrctrlr, """\K.*(?="")", NAME)
			RegExMatch(plyrctrlr, "\(\K.*(?=\))", ENUM)
			if (ENUM)
				{
				NAME := % NAME " (" ENUM ")"
				}
			if (A_INDEX = 1)
				{
				FirstCtrlrName := NAME
				}
				
				if (GUID = lastctrlr)
				{
					
					selctrlrnum := A_INDEX
					selctrlrname := NAME
				}	
		}
		
		if (selctrlrnum = 0)
		{
					selctrlrnum := 1
					selctrlrname := FirstCtrlrName
		}
		ybg := A_Screenheight
		Gui, bbg:Destroy
		Gui, bbg: +AlwaysOnTop +LastFound +Owner -Caption -0xC00000
		Gui, bbg: Color, 171717
		Gui, bbg: add, text, w%A_ScreenWidth%
		Gui, bbg: Show, x0 y%ybg% w%A_ScreenWidth% h%A_Screenheight%,Maximize
		loop 20
		{
		ybg := ybg-20
		Gui, bbg: Show, x0 y%ybg% w%A_ScreenWidth% h%A_Screenheight%,Maximize
		sleep 2
		}
		WinSet, TransColor, 000000 220
		
		SelPlayer := "Select Player "playernum
		sleep 100
		Gui, Destroy
		Gui, +AlwaysOnTop +LastFound +Owner -Caption -0xC00000
		Gui, Color, 000000
		Gui, Font, s26
		Gui, Show, x0 y%ybg% w%A_ScreenWidth% h%A_Screenheight%
		Gui, add, text, cffffef w%A_ScreenWidth% y50 vTitle, %selctrlrname%
		WinSet, TransColor, 000000 255

		menuline := 0
		MenuArray := []
				
		
	Loop {	
	
		for index, ctrlrline in Array
		{
		   	
			if (A_INDEX = selctrlrnum and menuline = 0)
			{
				menuline := 1
				MenuArray.Push(ctrlrline)
			}
			else if (A_INDEX > selctrlrnum and menuline >= 1)
			{
				menuline++
				MenuArray.Push(ctrlrline)
			}
			else if (A_INDEX < selctrlrnum and menuline >= selctrlrnum)
			{
				menuline++
				MenuArray.Push(ctrlrline)
			}
			else if (A_INDEX < selctrlrnum and menuline < selctrlrnum and menuline > 0)
			{
				menuline++
				MenuArray.Push(ctrlrline)
			}
			
		}until menuline = numctrlr
	 
	} until menuline = numctrlr


		x := A_ScreenWidth/2-100
		y := ybg+200
		MaxCtrlrView := floor((A_ScreenWidth-50)/200)
		yshadow := y+100
		Gui, top:Destroy
		Gui, top: +AlwaysOnTop +LastFound +Owner -Caption -0xC00000
		Gui, top: Color, Black
		Gui, top: Font, s26
		Gui, top: add, text,center cfffeff w%A_ScreenWidth% x-200 y0, %SelPlayer%
		Gui, top: Show, x0 y%ybg% w%A_ScreenWidth% h%A_Screenheight%
		WinSet, TransColor, 000000 255
		
		for index, ctrlrmenu in MenuArray
		{
			
			RegExMatch(ctrlrmenu, """\K.*(?="")", NAME)
			RegExMatch(ctrlrmenu, "\{\K.*(?=\})", GUID)
			
					GUIDimg%A_Index% = %A_ScriptDir%\ctrlr-img\{%GUID%}.png
					NAMEimg%A_Index% = %A_ScriptDir%\ctrlr-img\%NAME%.png
					
					Shadow = %A_ScriptDir%\ctrlr-img\Shadow.png
					
					if FileExist(GUIDimg%A_Index%)
					{
						img%A_Index% = %A_ScriptDir%\ctrlr-img\{%GUID%}.png
					}
					else if FileExist(NAMEimg%A_Index%)
					{
						img%A_Index% = %A_ScriptDir%\ctrlr-img\%NAME%.png
					}
					else
					{
						img%A_Index% = %A_ScriptDir%\ctrlr-img\no-img.png
					}
					

				if (A_INDEX = 1)
				{
					selctrlrname := NAME
					
					
					x%A_Index% := 40
					ys := y-50
					Shadow%A_Index% := new ImageViewer
					Shadow%A_Index%.Show(Shadow, 15, yshadow, 220, -1)
					ctrlr%A_Index% := new ImageViewer
					ctrlr%A_Index%.Show(img%A_Index%, x%A_Index%, ys, 170, -1)

				}
				else
				{
					x%A_Index% := (200*A_Index-200)+50
										if (A_Index <= MaxCtrlrView)
					{
					Shadow%A_Index% := new ImageViewer
					xs := x%A_Index% -10
					Shadow%A_Index%.Show(Shadow, xs, yshadow, 170, -1)
					}
					ctrlr%A_Index% := new ImageViewer
					ctrlr%A_Index%.Show(img%A_Index%, x%A_Index%, y, 150, -1)

					
				}

		}

		
		selctrlr := 1
			ybump := y-50
			Loop 5
			{
			ybump := ybump+10
				for index, ctrlrmenu in MenuArray
				{				
					if (A_INDEX = 1)
					{
						ctrlr%A_Index%.Show(img%A_Index%, x%A_Index%, ybump-50, 150, -1)
					}
					else
					{
						ctrlr%A_Index%.Show(img%A_Index%, x%A_Index%, ybump, 150, -1)
					}
				}
			}
			

		
;		#######joystick input recognition########

		mc := new MyClass()	

return


;		#######################################

cycle()
{
SetTimer, cycle, 100
}
		cycle:
		if (Joystick_input = 1)
		{
		SetTimer, cycle, OFF
		goto, Move
		}	
		return
		
			
			Move:
			Cycle_Controllers:
			ys := y
			selctrlr++
					DeselCntrlr := selctrlr-1
					if (selctrlr = numctrlr+1)
					{
						selctrlr := 1
						for index, menu in MenuArray
						{
								x%A_Index% := (200*A_Index-200)+50
								ctrlr%A_Index%.Show(img%A_Index%, x%A_Index%, y, 150, -1)
								
						}
						
						Shadow%MaxCtrlrView%.Show(Shadow, x%MaxCtrlrView%, yshadow, 150, -1)
						
					}
					SelectedLine := MenuArray[selctrlr]
					RegExMatch(SelectedLine, "\{\K.*(?=\})", SELGUID)
					RegExMatch(SelectedLine, """\K.*(?="")", NAME)
					RegExMatch(SelectedLine, "\(\K.*(?=\))", ENUM)
					if (ENUM)
						{
						NAME := % NAME " (" ENUM ")"
						}
					GuiControl,, Title, %NAME%
					

					SelShadow := selctrlr
					if (selctrlr > MaxCtrlrView)
					{
							for index, menu in MenuArray
							{
									x%A_Index% := x%A_Index%-200
									ctrlr%A_Index%.Show(img%A_Index%, x%A_Index%, y, 150, -1)
									
									
							}
							SelShadow := MaxCtrlrView+1
					}
					else
					{
					Shadow%DeselCntrlr%.Show(Shadow, x%DeselCntrlr%, yshadow, 150, -1)
					}
					xss := x%SelShadow%-35
					Shadow%SelShadow%.Show(Shadow, xss, yshadow, 220, -1)

					ctrlr%DeselCntrlr%.Show(img%DeselCntrlr%, x%DeselCntrlr%, y, 150, -1)
			loop 5{

					ys := ys-10
					xs := x%selctrlr%-10
					ctrlr%selctrlr%.Show(img%selctrlr%, xs, yS, 170, -1)
					
			}
			SetTimer, Minimize, OFF
			SetTimer, TimeIdle, 2000
			return
			view := ""
		

	TimeIdle:
			FileDelete, devtemp.ini	
			playerline := playernum + orderline
			Loop, Read, devreorder.ini, devtemp.ini
			{	
				if (A_LoopReadLine !="")
				{	
					if (A_INDEX = hiddenline AND playerline >= hiddenline)
					{
					
						lines := playerline-hiddenline
						if (lines > 0)
						{
						linespaces := StrRepeat("{}`n", lines)
						}
						FileAppend, %linespaces%{%SELGUID%}`n[hidden]`n
					}
					else if (A_INDEX = playerline AND playerline < hiddenline)
					{
						FileAppend, {%SELGUID%}`n
					}
					else
					{
						FileAppend, %A_LoopReadLine%`n
					}
				}
			}
	FileDelete, devreorder.ini
	FileMove, devtemp.ini, devreorder.ini
	goto, Minimize
	Exit:

	Minimize:
			Gui, top:Destroy
			Gui, bg:Destroy
			Gui, bbg:Destroy
			Gui, Destroy
			for index, menu in MenuArray
			{
			ctrlr%A_Index% := delete ImageViewer
			ctrlr%A_Index%.delete()
			Shadow%A_Index% := delete ImageViewer
			Shadow%A_Index%.delete()
			}
	Hotkey,%Cycle_Controllers%,Cycle_Controllers, OFF
	numctrlr := 0
	Joystick_input := 0
	rundevicelister := 1
	SetTimer, TimeIdle, OFF	
	SetTimer, Minimize, OFF	
	return
~c & f4::ExitApp





	
