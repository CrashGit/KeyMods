/**
 * GetSystemTime used in script is from skan
* @GetSystemTime
* @author @skan
* @source https://www.autohotkey.com/boards/viewtopic.php?t=3401
* System Time in MS / STMS() returns milliseconds elapsed since 16010101000000 UT
* Used similarly to A_TickCount, i.e. save current time, do something, get current time and compare to saved time
*/



/**
 * @param {string/func} on_hold      the key to be logically held down or function to call when physically holding the hotkey
 * @param {string}      tap_key      the key to be sent if ThisHotkey is only tapped
 * @param {string/func} on_release   the key to be logically released or function to call when releasing the hotkey
 * @param {integer}     tapping_term the duration between the hotkey pressed and release for the key to be considered a tap
 * Wrap the hotkey in a #HotIf ModTap.enabled directive and Call DualFunction.Toggle() if ever want to toggle DualFunction on/off for any reason
 * function is intended to be a layer (i.e. variable to toggle for #HotIf hotkey setups)
 */
class DualFunction {
    static enabled := true
    static Toggle() => this.enabled := !this.enabled

    static current_time => (DllCall(this.GetSystemTime, 'Int64*', &T1601 := 0), T1601 // 10000)
    static __New() => this.GetSystemTime := DllCall('GetProcAddress', 'UInt', DllCall('GetModuleHandle', 'Str', 'Kernel32.dll', 'Ptr'), 'AStr', 'GetSystemTimeAsFileTime', 'Ptr')


    __New(on_hold, tap_key?, on_release?, tapping_term := 300) {
        ThisHotkey := RegExReplace(A_ThisHotkey, '[~*$!^+#<>]')                     ; get hotkey pressed
        tapping_term += DualFunction.current_time                                   ; save start time
        key := Format('vk{:x}sc{:x}', GetKeyVK(ThisHotkey), GetKeySC(ThisHotkey))   ; get key name for key pressed


        if on_hold is String {
            switch {                                                                ; check what modifier press is requested
                case InStr(on_hold, 'Shift'): mod := 'Shift'                        ; get modifier requested
                case InStr(on_hold, 'Ctrl'):  mod := 'Ctrl'                         ; get modifier requested
                case InStr(on_hold, 'Alt'):   mod := 'Alt'                          ; get modifier requested
                case InStr(on_hold, 'Win'):   mod := 'Win'                          ; get modifier requested
                default: return MsgBox('Improper modifier key.')                    ; return with error message
            }
            on_release := Send.Bind('{Blind}{' on_hold ' up}')                      ; send modifier up
            on_hold := Send.Bind('{Blind}{' on_hold ' downR}')                      ; send modifier down, DownR prevents modifier being sent with other Send functions that don't use {Blind}
            if GetKeyState(mod) {                                                   ; if modifier is already down
                return Send('{Blind}{' key '}')                                     ; send key and return
            }
        } else if not IsSet(on_release) {
            on_release := () => 0
        }

        on_hold()
        KeyWait(ThisHotkey)                                                         ; wait for hotkey to be released
        on_release()

        if DualFunction.current_time <= tapping_term and A_PriorKey = ThisHotkey {  ; if hotkey was released within the tapping term and no other key was pressed
            tap_key := tap_key ?? key
            (tap_key is String) ? Send('{Blind}{' tap_key '}') : tap_key() ; send the tap key
        }
    }
}



/**
 * @param {string}  modifier     the modifier to be logically held down when physically holding ThisHotkey
 * @param {string}  tap_key      the key to be sent if hotkey is only tapped
 * @param {integer} tapping_term the duration between the hotkey pressed and release for the key to be considered a tap
 * Wrap the hotkey in a #HotIf ModTap.enabled directive and Call ModTap.Toggle() if ever want to toggle ModTap on/off for any reason
 */
class ModTap {
    static enabled := true
    static Toggle() => this.enabled := !this.enabled

    static current_time => (DllCall(this.GetSystemTime, 'Int64*', &T1601 := 0), T1601 // 10000)
    static __New() => this.GetSystemTime := DllCall('GetProcAddress', 'UInt', DllCall('GetModuleHandle', 'Str', 'Kernel32.dll', 'Ptr'), 'AStr', 'GetSystemTimeAsFileTime', 'Ptr')


    __New(modifier, tap_key?, tapping_term := 300) {
        ThisHotkey := RegExReplace(A_ThisHotkey, '[~*$!^+#<>]')                     ; get hotkey pressed
        tapping_term += ModTap.current_time                                         ; save start time
        key := Format('vk{:x}sc{:x}', GetKeyVK(ThisHotkey), GetKeySC(ThisHotkey))   ; get key name for key pressed

        switch {                                                                    ; check what modifier press is requested
            case InStr(modifier, 'Shift'): mod := 'Shift'                           ; get modifier requested
            case InStr(modifier, 'Ctrl'):  mod := 'Ctrl'                            ; get modifier requested
            case InStr(modifier, 'Alt'):   mod := 'Alt'                             ; get modifier requested
            case InStr(modifier, 'Win'):   mod := 'Win'                             ; get modifier requested
            default: return MsgBox('Improper modifier key.')                        ; return with error message
        }

        if GetKeyState(mod) {                                                       ; if modifier is already down
            return Send('{Blind}{' key '}')                                         ; send key and return
        }

        Send('{Blind}{' modifier ' downR}')                                         ; send modifier down, DownR prevents modifier being sent with other Send functions that don't use {Blind}
        KeyWait(ThisHotkey)                                                         ; wait for hotkey to be released
        Send('{Blind}{' modifier ' up}')                                            ; send modifier up

        if ModTap.current_time <= tapping_term and A_PriorKey = ThisHotkey {        ; if hotkey was released within the tapping term and no other key was pressed
            Send('{Blind}{' (tap_key ?? key) '}')                                   ; send the tap key
        }
    }
}



/**
 * @param {array}   tapCallbacks  callbacks to invoke when key is tapped a certain amount of times
 * @param {array}   holdCallbacks callbacks to invoke when key is tapped and held certain amount of times
 * @param {integer} tappingTerm   how long between taps before TapDance times out
 * @param {integer} holdingTerm   how long a key needs to be held before the hold callback is invoked
 * @param {bool}    tapout        whether the last tap callback is always invoked if holdCallbacks > tapCallbacks and last tap fails to be held
 */
class TapDance {
    static Call(tap_callbacks := [], hold_callbacks := [], tapping_term := 250, holding_term := tapping_term, tapout := false) {
        static dance := FirstTimeSetup(), tap_funcs := [], hold_funcs := []

        if not dance.InProgress {                                                       ; if TapDance is not in progress
            FirstTap()                                                                  ; setup TapDance and start TapDance
        } else if OtherTapDanceKeyPressed() {                                           ; if TapDance is in progress and if first tap hotkey is different than this one
            return                                                                      ; exit early
        }

        ResetTimeoutAndCheckTaps()                                                      ; start/reset timer and check tap progress


        ;-----------------------
        ; encapsulated functions
        ResetTimeoutAndCheckTaps() {
            SetTimer(dance.check_if_done, -tapping_term)                                ; start/reset timer to check if done tapping/holding
            dance.timer := true                                                         ; set timer state to true
            dance.taps++                                                                ; increase taps by one

            if dance.taps = dance.limit {                                               ; if at the last tap
                if tap_funcs.Length > hold_funcs.Length {                               ; if more taps than holds are supplied
                    FinishAndCall(tap_funcs)                                            ; immediately invoke callback
                } else if KeyIsHeld() {                                                 ; if key is held for hold duration
                    FinishAndCall(hold_funcs)                                           ; invoke hold callback
                } else {                                                                ; if last press wasn't held
                    FinishAndCall(tap_funcs)                                            ; invoke tap callback
                }
            }
            else if KeyIsHeld() {                                                       ; if key is held for hold duration
                FinishAndCall(hold_funcs)                                               ; invoke hold callback
            }
            else if holding_term > tapping_term and not dance.timer {                   ; if key can be held longer than timer accounts for and timer stopped
                FinishAndCall(tap_funcs)                                                ; invoke tap callback
            }

            KeyWait(dance.hotkey)                                                       ; prevents extra calls when holding key down
        }


        TimerFinished() {
            dance.timer := false                                                        ; set timer state to false
            if not dance.InProgress {                                                   ; guard clause if TapDance has ended
                return                                                                  ; return
            }
            if not GetKeyState(dance.hotkey, 'P') {                                     ; if key isn't held when timed out
                FinishAndCall(tap_funcs)                                                ; invoke tap callback
            }
        }


        KeyIsHeld() => !KeyWait(dance.hotkey, 'T' holding_term/1000)                    ; returns if key was held for holdingTerm


        OtherTapDanceKeyPressed() {                                                     ; this code block is meant to treat other TapDance keys that didn't start it as normal keys
            key := this.hotkey                                                          ; get key that triggered TapDance
            if key != dance.hotkey {                                                    ; if it's not the same as the key that started TapDance
                OtherKeyPressed(key)                                                    ; pass key to send after callback and exit
                return true                                                             ; return true
            }
        }


        OtherKeyPressed(key) {
            vksc := this.GetVKSC(key)                                                   ; get key vksc
            FinishAndCall(tap_funcs)                                                    ; invoke tap callback
            Send('{Blind}' vksc)                                                        ; send key that was pressed
        }


        FinishAndCall(tapOrHold) {
            if not dance.InProgress {                                                   ; if callback is invoked while TapDance has stopped (happens when releasing key at the same time as tapping_term)
                return                                                                  ; prevent extra calls
            }

            if tapout {                                                                 ; if tapout is true
                max := tapOrHold = tap_funcs ? tap_funcs.Length : hold_funcs.Length     ; get max taps or holds
                dance.taps := Min(dance.taps, max)                                      ; don't let taps go past the max
            }

            if not tapOrHold.Has(dance.taps) {                                          ; if index doesn't exist
                return dance.Stop()                                                     ; stop TapDance and return
            }

            action := tapOrHold[dance.taps]                                             ; save value at index
            dance.Stop()                                                                ; stop TapDance

            if action is String {                                                       ; if value at index is a string
                switch SubStr(action, 1, 1) {
                    case '$': action := SendInput.Bind(SubStr(action, 2))               ; if string starts with $, bind to SendInput
                    case '@': action := SendEvent.Bind(SubStr(action, 2))               ; if string starts with @, bind to SendEvent
                    default:  action := SendText.Bind(action)                           ; default to bind to SendText
                }
            }
            action()                                                                    ; invoke callback
        }


        FirstTap() {
            dance.hotkey := this.hotkey                                                 ; get key that triggered this
            tap_funcs    := tap_callbacks                                               ; save tap callbacks
            hold_funcs   := hold_callbacks                                              ; save hold callbacks
            dance.limit  := Max(tap_funcs.Length, hold_funcs.Length)                    ; get tap limit
            dance.timer  := false                                                       ; timer state is for holdingTerm > tappingTerm condition
            dance.taps   := 0                                                           ; initialize taps to 0

            if not tap_funcs.Has(1) {                                                   ; is first index has no value
                held_mods := this.GetModifiers()                                        ; get modifiers being held down
                vksc := this.GetVKSC(dance.hotkey)                                      ; get vksc of key
                x := Send.Bind(held_mods vksc)                                          ; bind modifiers and key to Send
                (tap_funcs.Length ? tap_funcs[1] := x : tap_funcs.Push(x))              ; assign func object to first tap
            }

            dance.Start()                                                               ; start TapDance
        }


        FirstTimeSetup() {
            ih := InputHook('L0 I')
            modifiers := '{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}'       ; list of modifier keys for inputhook
            ih.KeyOpt(modifiers, 'V')                                                   ; modifiers and other custom keys can still work
            ih.KeyOpt('{All}', 'N')                                                     ; all keys notify
            ih.KeyOpt(modifiers, '-N')                                                  ; except modifiers
            ih.OnKeyDown := (ih, vk, sc) => OtherKeyPressed(Format('vk{:x}', vk))       ; when another key is pressed, pass key to function
            ih.OnEnd := (*) => SetTimer(dance.check_if_done, 0)                         ; on end, stop timer
            ih.check_if_done := TimerFinished                                           ; reference for timer
            return ih                                                                   ; return inputhook
        }
    }


    static enabled := true                                                              ; enabled at start, use with #HotIf
    static Toggle() => this.enabled := !this.enabled                                    ; toggle TapDance on/off

    static hotkey => RegExReplace(A_ThisHotkey, '[~*$!^+#<>]')                          ; remove modifiers from hotkey
    static GetVKSC(key) => Format('{vk{:x}sc{:x}}', GetKeyVK(key), GetKeySC(key))       ; get vksc code


    static GetModifiers() {
        GetKeyState('Shift') ? mods .= '+' : 0                                          ; if shift is held, add to modifiers
        GetKeyState('Ctrl')  ? mods .= '^' : 0                                          ; if control is held, add to modifiers
        GetKeyState('Alt')   ? mods .= '!' : 0                                          ; if alt is held, add to modifiers
        (GetKeyState('LWin') or GetKeyState('RWin')) ? mods .= '#' : 0                  ; if Windows key is held, add to modifiers
        return mods ?? ''                                                               ; return modifiers held when TapDance started
    }
}



/**
 * @param {map} sequences a map of key sequences and funcs to call
 * @param {int} timeout the duration in ms until the leader operation times out
 * @param {int} initial_timeout the duration in ms until the leader operation times out before the first key press, excluding numbers
 * @notes
 * You can wrap your leader key in a '#HotIf Leader.enabled' directive and use another key to toggle the leader key on/off if it interferes with certain programs.
 * You can prefix keys with a modifier symbol (+!^#) to allow keys with modifiers to be pressed.
 * @ProTip Use an empty string '' as the key if you want something to happen when you don't press anything and it times out (initial_timeout can't be 0 (infinite))
 *
 * Almost all keys are supported:
 * Escape is reserved which ends the operation. Useful if you use infinite initial timeout (0) but want to cancel a leader key sequence.
 *      => The line associated with this can easily be altered/deleted.
 * Key sequences can't start with a number due to it being considered an iteration count (see below).
 *
 * Ways to use the leader key:
 * Press number(s) at the start of a leader sequence to repeat the action that many times.
 *
 * If the action of a key is just a string, it is sent as text (SendText). Unless that string begins with $ (SendInput) or @ (SendEvent).
 *
 * When using a function, there are two different ways to approach it:
 *      1. Use a func object with no parameters. When it finds a match, it will call that function x times based on the numbers pressed at the start.
 *      2. Use a func object with one parameter. The parameter will use the numbers pressed at the start.
 *
 */
class Leader {
    static enabled := true
    static Toggle() => this.enabled := !this.enabled

    static max_repeat := 100    ; change if need the possibility to repeat something more


    static Call(sequences, timeout := 250, initial_timeout := 1000) {
        static ldr := LeaderSetup()

        if not ldr.InProgress {                                                 ; if leader is not in progress
            Start()                                                             ; setup leader
            this.Display('Waiting For Input...', !ldr.Timeout)                  ; show gui that will display keys pressed
        } else {                                                                ; if leader is in progress
            key := RegExReplace(A_ThisHotkey, '[~*$!^+#<>]')                    ; remove modifiers from simple hotkey
            StrLen(key) > 1 ? key := '{' key '}' : 0                            ; if more than one char, add braces around it
            AddToBuffer(key)                                                    ; add leader key to buffer
        }


        AddToBuffer(key) {
            ldr.buffer .= key                                                   ; add key to buffer
            Leader.Display(ldr.buffer)                                            ; show keys that were pressed
            ldr.Timeout := ldr.tapping_term                                     ; reset timeout
            CheckInputIsMatch()                                                 ; checks if only one match is possible, if so and does match, ends early
        }


        CheckForNumbers(ih, vk, sc) {
            key := GetKeyName(Format('vk{:x}sc{:x}', vk, sc))                   ; get key name

            if not IsInteger(key) {                                             ; if key entered is not a number
                ldr.OnKeyDown := OnKeyDown                                      ; change callback
                OnKeyDown(ih, vk, sc)                                           ; send values to new callback to be added to the buffer
                return
            }

            if this.max_repeat = 0 or (ldr.repeat . key <= this.max_repeat) {   ; if no max repeat value or proposed repeat count is less than the max
                ldr.repeat .= key                                               ; add number to repeat property
                this.Display('Repeat: ' SubStr(ldr.repeat, 2))                  ; show how many times action will be repeated
            } else {                                                            ; if proposed repeat value is higher than the max value
                ldr.repeat := this.max_repeat                                   ; set repeat value to the max allowed
                this.Display('Repeat: ' ldr.repeat)                             ; show how many times action will be repeated
            }
        }


        OnKeyDown(ih, vk, sc) {
            key := GetKeyName(Format('vk{:x}sc{:x}', vk, sc))                   ; get key name
            switch {
                case key = 'Escape':  return Stop('Stopped')                    ; if escape is pressed, stop leader
                case key = 'Space':   key := ' '                                ; if spacebar, make it an empty space for the buffer
                case StrLen(key) > 1: key := '{' key '}'                        ; if not a single char, add braces around it
            }
            mods := GetModifiers()                                              ; get modifiers that are down
            AddToBuffer(mods key)                                               ; add char with any modifiers to buffer
        }


        GetModifiers() {                                                        ; !#+^ ordinal order
            GetKeyState('Alt')   ? mods .= '!' : 0                              ; if alt is held, add to modifiers
            (GetKeyState('LWin') or GetKeyState('RWin')) ? mods .= '#' : 0      ; if Windows key is held, add to modifiers
            GetKeyState('Shift') ? mods .= '+' : 0                              ; if shift is held, add to modifiers
            GetKeyState('Ctrl')  ? mods .= '^' : 0                              ; if control is held, add to modifiers
            return mods ?? ''                                                   ; return modifiers held when TapDance star
        }


        Stop(message := 'Timed out') {
            ldr.Stop()
            if not ldr.sequences.Has(ldr.buffer) {                              ; if typed sequence doesn't match one in saved leader sequences
                this.Display(message, false, 'ff9d00')                          ; display failed message
                return                                                          ; return
            }
            this.Display(message, false, '00c3ff')                              ; display that a match was found
            action := ldr.sequences.Get(ldr.buffer)                             ; get value associated with sequence
            MatchFound(action)                                                  ; perform action
        }


        CheckInputIsMatch() {
            keys := []
            buffer_length := StrLen(ldr.buffer)

            for key, value in ldr.sequences {
                if ldr.buffer != SubStr(key, 1, buffer_length) {                ; if partial match isn't found
                    keys.Push(key)                                              ; remember key to remove after loop
                }
            }
            for key in keys {
                ldr.sequences.Delete(key)                                       ; remove keys that can't be matches to make searching faster on subsequent key presses
            }
            switch ldr.sequences.Count {
                case 0: Stop('No matches found')                                ; if no values left, end leader operation
                case 1: ldr.sequences.Has(ldr.buffer) ? Stop(ldr.buffer) : 0    ; if one value left and it matches typed sequence; stop with Match Found message
            }
        }


        MatchFound(action) {
            if action is String {                                               ; if value is a string
                switch SubStr(action, 1, 1) {                                   ; check first value
                    case '$': action := SendInput.Bind(SubStr(action, 2))       ; if string starts with $, bind to SendInput
                    case '@': action := SendEvent.Bind(SubStr(action, 2))       ; if string starts with @, bind to SendEvent
                    default:  action := SendText.Bind(action)                   ; default to bind to SendText
                }
            }


            if action.MinParams {                                               ; if func accepts parameters
                action(ldr.repeat)                                              ; assumed to accept the iteration count
                return                                                          ; return
            }

            ; was before .MinParams condition, not sure what is a better default; this works better for the given examples I feel
            (ldr.repeat ? 0 : ldr.repeat := 1)                                  ; if repeat is not specified, defaults to one

            loop ldr.repeat {                                                   ; repeat action based on starting numbers
                action()
            }
        }


        SortMods(mods) {                                                        ; mods is a string
            local temp := '', length := StrLen(mods)                            ; initialize some vars
            for char in StrSplit(mods) {                                        ; loop each modifier
                temp .= Ord(char) (A_Index != length ? ',' : '')                ; add their ordinal value to temp
            }
            temp := Sort(temp, 'N D,'), mods := ''                              ; sort ordinal values
            for char in StrSplit(temp, ',') {                                   ; loop through ordinal values
                mods .= Chr(char)                                               ; add them back to mods
            }
            return mods                                                         ; return rearranged mods
        }


        Start() {
            if initial_timeout != 0 {                                           ; if first_key_timeout is not 0
                initial_timeout /= 1000                                         ; divide by 1000 because inputhook accepts seconds, not ms
            }
            ldr.tapping_term := timeout/1000                                    ; save timeout
            ldr.Timeout      := initial_timeout                                 ; set first timeout
            ldr.OnKeyDown    := CheckForNumbers                                 ; call this function on key press down
            ldr.repeat       := 0                                               ; how many times to repeat the action associated with the key sequence, defaults to one at loop
            ldr.buffer       := ''                                              ; initialize empty buffer
            ldr.Start()                                                         ; begin collecting input

            ; adds key sequences to leader.sequences with their modifiers ordered a certain way
            ; this allows you to assign the modifiers any way you choose in the leader map
            ldr.sequences := Map()                                              ; initialize key sequences and their actions
            for key, value in sequences {                                       ; loop through map passed to Leader
                p := 1                                                          ; initialize first person
                while p := RegExMatch(key, '[!#^+]{2,}', &mods, p) {            ; check for more than 1 modifier next to one another
                    mods_sorted := SortMods(mods[])                             ; sort modifiers in a particular order
                    key := StrReplace(key, mods[], mods_sorted,,, 1)            ; replace modifiers with ordered modifiers
                    p += mods.Len                                               ; update position to start from
                }
                ldr.sequences.Set(key, value)                                   ; add keys with ordered modifiers and their action to map
            }
        }


        LeaderSetup() {
            ih := InputHook()                                                   ; create inputhook
            ih.VisibleNonText := false                                          ; prevent modifier keys from unintentionally triggering
            ih.KeyOpt('{All}', 'N')                                             ; all keys notify
            mods :='{LShift}{RShift}{LCtrl}{RCtrl}{LAlt}{RAlt}{LWin}{RWin}'     ; modifiers
            ih.KeyOpt(mods, '-N')                                               ; remove modifiers from notifying callbacks
            ih.OnEnd := (ih) {                                                  ; when leader operation stops
                if ih.EndReason = 'Timeout' {                                   ; if input stopped because it timed out
                    ldr.sequences.Has(ldr.buffer) ? Stop(ldr.buffer) : Stop()   ; reset and show appropriate display message
                }
            }
            return ih                                                           ; return inputhook
        }
    }


    static Display(text := '', show := true, color := 'cebebeb') {
        static sequence := FirstTimeSetup(), visible := true                    ; visible keeps track of display state so that if you try to use the leader
                                                                                ; key again before the display times out, it won't disappear on you
        sequence.buffer.SetFont('c' color)
        sequence.buffer.Value := text
        sequence.Show('AutoSize NoActivate')

        if not (visible := show) {
            SetTimer(() =>  visible ? 0 : sequence.Hide(), -500)
        }

        FirstTimeSetup() {  ; create gui, round corners, return gui
            myGui := Gui('+AlwaysOnTop -SysMenu +ToolWindow -Caption -Border')
            myGui.BackColor := '000000'
            myGui.MarginX := 0, myGui.MarginY := 12
            myGui.SetFont('s14 cebebeb')
            myGui.buffer := myGui.AddText('y6 w' A_ScreenWidth//4 ' Center')
            myGui.Show('y-10 h30 NoActivate NA Hide')

            curve := 15
            myGui.GetPos(,, &width, &height)
            WinSetRegion('0-0 w' width ' h' height ' r' curve '-' curve, myGui.Hwnd)
            return myGui
        }
    }
}



/**
 * When called, it waits for a single key press, then keeps that key down
 * until that key is pressed or KeyLock is called again
 */
class KeyLock {
    static Call() {
        static ih := FirstTimeSetup()                   ; initialize inputhook

        (not ih.InProgress ? ih.Start() : ih.Stop())    ; this allows you to press the KeyLock hotkey again to stop waiting

        OnEnd(ih) {
            if ih.EndReason != 'EndKey' {
                return
            }
            key_down := GetKeyState(ih.EndKey)          ; get keystate of key pressed

            if key_down {                               ; if key is already down
                Send('{' ih.EndKey ' up}')              ; release it
            } else {                                    ; if key is not down
                KeyWait(ih.EndKey)                      ; wait for key to be physically released
                Send('{' ih.EndKey ' down}')            ; send it down
            }
        }

        FirstTimeSetup() {
            ih := InputHook('L1 T3')                    ; create inputhook with 3 second timeout
            ih.KeyOpt('{All}', 'E')                     ; makes all keys end-keys
            ih.OnEnd := OnEnd                           ; when inputhook ends
            return ih                                   ; return inputhook
        }
    }
}


/**
 * @param {int} timeout the time, in seconds, CapsWord is disabled when not pressing the allowed keys
 * Useful when you need to type a single word in all caps.
 * By default it turns off when typing something not a-z, 0-9, modifiers (excl. shift), - (minus), backspace/delete
 * Look at the comments for the properties in static __New() to see what you can change.
 */
class CapsWord {
    static __New() {
        ; for reference:
        ; '-=[];```',./\'           ; symbols that don't require shift to access
        ; '!@#$%^&*()+_{}:"<>?|'    ; symbols that require shift to access

        ; Edit these if needed
        ; Keys here must be in the syntax accepted by InputHook. Same as Send but modifiers with left and right variants must be specified. e.g. {LCtrl} works but not {Ctrl}
        ; Keys must be a key in the first layer. e.g. '[' works but not '{' because '{' is shifted
        ; All keys not mentioned here are considered word-breaking and will stop CapsWord
        this.shifted_keys     := this.alphabet '-'                                      ; these keys are sent shifted and reset the timer for CapsWord
        this.not_shifted_keys := this.numbers this.modifiers '{Backspace}{Delete}'      ; these keys are not sent shifted but still reset the timer for CapsWord
        this.invert_on_shift  := false                                                  ; determines if shift is word-breaking or can be used for temporary un-shifted characters
        this.enabled          := true                                                   ; determines if enabled on script start-up
    }


    ; Don't edit this section directly below
    static alphabet        := 'abcdefghijklmnopqrstuvwxyz'
    static numbers         := '0123456789'
    static modifiers       := '{LCtrl}{RCtrl}{LAlt}{RAlt}{LWin}{RWin}'
    static shifted_map     := Map()
    static not_shifted_map := Map()


    static Call(timeout := 5) {
        static caps := FirstTimeSetup()

        (not caps.InProgress ? caps.Start() : caps.Stop())

        OnKeyDown(ih, vk, sc) {
            caps.Timeout := timeout                                             ; reset timeout
            vksc := Format('vk{:x}sc{:x}', vk, sc)                              ; get vksc
            key  := GetKeyName(vksc)                                            ; get key name
            if_shift := this.invert_on_shift and GetKeyState('Shift', 'P')      ; check if invert on shift is true and shift is being pressed

            if this.shifted_map.Has(key) {                                      ; if key is supposed to be shifted
                if_shift ? Send('{' vksc '}') : Send('{Blind}+' '{' vksc '}')   ; check if key is supposed to send lowercase when shift is held
            } else if this.not_shifted_map.Has(key) {                           ; if key is not supposed to be shifted
                Send('{Blind}' '{' vksc '}')                                    ; send key
            }
        }


        FirstTimeSetup() {
            allowed_keys := this.shifted_keys this.not_shifted_keys

            ; separate single chars from keys with braces around them
            ; was unsure how to do this with a single RegEx in OnKeyDown
            while RegExMatch(this.shifted_keys, '\{.*?}', &match) {
                this.shifted_map.Set(SubStr(match[], 2, match.Len-2), 0)
                this.shifted_keys := StrReplace(this.shifted_keys, match[],,,, 1)
            }
            for char in StrSplit(this.shifted_keys) {
                this.shifted_map.Set(char, 0)
            }

            this.not_shifted_keys := StrReplace(this.not_shifted_keys, 'LCtrl', 'LControl')
            this.not_shifted_keys := StrReplace(this.not_shifted_keys, 'RCtrl', 'RControl')

            while RegExMatch(this.not_shifted_keys, '\{.*?}', &match) {
                this.not_shifted_map.Set(SubStr(match[], 2, match.Len-2), 0)
                this.not_shifted_keys := StrReplace(this.not_shifted_keys, match[],,,, 1)
            }
            for char in StrSplit(this.not_shifted_keys) {
                this.not_shifted_map.Set(char, 0)
            }

            ; InputHook
            ih := InputHook('L0 I')
            ih.KeyOpt('{All}', 'E V')

            if this.invert_on_shift {
                ih.KeyOpt('{LShift}{RShift}', '-E')
            }

            ih.KeyOpt(allowed_keys, '-E -V')    ; prevent allowed keys from immediately ending CapsWord
            ih.KeyOpt(allowed_keys, 'N')        ; allowed keys will call OnKeyDown
            ih.OnKeyDown := OnKeyDown           ; function to call when allowed keys are pressed
            return ih                           ; return inputhook
        }
    }
}



class AutoShift {
    static tab           := true        ; true enables shift on tab
    static symbols       := true        ; true enables shift on symbols
    static numeric       := true        ; true enables shift on numbers
    static alphabet      := true        ; true enables shift on letters
    static enter         := true        ; true enables shift on enter
    static custom_keys   := ''          ; add any custom keys you want shifted

    ; at least one of the repeat options has to be true for a shifted character to be sent
    static repeat_normal := true        ; tap and hold to repeat un-shifted keys
    static repeat_shift  := true        ; hold key down to continue sending shifted key
    static tapping_term  := 300         ; duration (in ms) key has to be held to send shifted variant


    static current_time => (DllCall(this.GetSystemTime, 'Int64*', &T1601 := 0), T1601 // 10000)
    static __New() => this.GetSystemTime := DllCall('GetProcAddress', 'UInt', DllCall('GetModuleHandle', 'Str', 'Kernel32.dll', 'Ptr'), 'AStr', 'GetSystemTimeAsFileTime', 'Ptr')


    static Call() {
        static auto := FirstTimeSetup()

        (not auto.InProgress ? auto.Start() : auto.Stop())      ; toggle AutoShift

        OnKeyDown(ih, vk, sc) {
            static running := false, input := '', key := ''

            ; this prevents weird spam when key is held due to key repeat
            ; it also queues keys pressed during progress to send after
            if running {
                new_vksc := Format('vk{:x}sc{:x}', vk, sc)
                new_key := GetKeyName(new_vksc)
                if new_key != key {
                    input .= '{' new_key '}'
                }
                return
            }

            running     := true                                     ; tell function that it is busy
            finish_time := this.current_time + this.tapping_term    ; get deadline for tapping term
            vksc        := Format('vk{:x}sc{:x}', vk, sc)           ; get vksc
            key         := GetKeyName(vksc)                         ; key name
            SendDefault := Send.Bind('{Blind}{' vksc '}')           ; default when holding/tap-hold fails
            SendKey     := (this.repeat_normal ? Repeat.Bind(key, '{' vksc '}')  : Send.Bind('{Blind}{' vksc '}'))
            SendShift   := (this.repeat_shift  ? Repeat.Bind(key, '+{' vksc '}') : Send.Bind('{Blind}+{' vksc '}'))

            if not KeyWait(key, 'T' this.tapping_term/1000) {
                SendShift()
            }
            else {
                remaining_time := (this.repeat_normal ? (finish_time - this.current_time)/1000 : 0)
                (KeyWait(key, 'D T' Max(remaining_time, 0)) ? SendKey() : SendDefault())
            }

            KeyWait(key)                                        ; wait for hotkey to be released
            Send(input)                                         ; send any keys pressed during progress
            input := ''                                         ; reset input
            running := false                                    ; tell function that it is no longer busy

            Repeat(key, vksc) {
                if GetKeyState(key, 'P') {                      ; if key is not physically pressed
                    Send('{Blind}' vksc )                       ; send key
                    SetTimer(Repeat.Bind(key, vksc), -65)       ; start function over
                }
            }
        }


        FirstTimeSetup() {
            keys    := ''
            symbols := '-=[];```',./\'
            tab     := '{Tab}'
            enter   := '{Enter}'
            alpha   := 'abcdefghijklmnopqrstuvwxyz'
            numbers := '0123456789'

            (this.symbols  ? keys .= symbols : 0)
            (this.tab      ? keys .= tab     : 0)
            (this.enter    ? keys .= enter   : 0)
            (this.alphabet ? keys .= alpha   : 0)
            (this.numeric  ? keys .= numbers : 0)
            keys .= this.custom_keys
            keys .= '{Space}'   ; this helps with regular typing while inputhook is in progress

            ih := InputHook('L0 V I')                           ; initialize inputhook
            ih.KeyOpt(keys, 'NS')                               ; these keys notify OnKeyDown callback
            ih.OnKeyDown := OnKeyDown                           ; when key is pressed, call this function
            return ih                                           ; return the inputhook
        }
    }
}


/**
 * @WIP
 * @notes
 * InputLevel/SendLevel for triggering hotkeys option?
 * additional repeat/alt repeats keys for an option to do something if key/alt key is repeated more than once
 * filtering remembered mods
 * repeat key needs wildcard modifier
 * maybe? function in OnKeyDown that checks other conditions if someone doesn't want them being picked up
 */
class Repeat {
    ; static alphabet     := 'abcdefghijklmnopqrstuvwxyz'
    ; static numbers      := '0123456789'
    ; static symbols      := '-=[];```',./\'
    static ignored_keys := ''

    static key_count := 0
    static repeat_key_count := 0
    static last_key := Map(
        'name', '',
        'vksc', '',
        'mods', ''
    )

    static __New() {
        modifiers := '{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}'
        ih := InputHook('V L0 I')
        ih.KeyOpt('{All}', 'N')
        ih.KeyOpt(modifiers this.ignored_keys, '-N')
        ih.OnKeyDown := ObjBindMethod(this, 'OnKeyDown')
        this.ih := ih
        this.ih.Start()
    }


    static Call() => Send('{Blind}' this.last_key['mods'] this.last_key['vksc'])


    static OnKeyDown(ih, vk, sc) {
        if this.ExceptionIsPresent() {
            return
        }
        mods := this.GetModifiers()
        vksc := Format('vk{:x}sc{:x}', vk, sc)                              ; get vksc
        key  := GetKeyName(vksc)                                            ; get key name
        new_key := this.last_key['name']
        this.repeat_key_count := 0

        if mods new_key = this.last_key['mods'] key {
            this.key_count++
        } else {
            this.last_key['mods'] := mods
            this.last_key['name'] := key
            this.last_key['vksc'] := '{' vksc '}'
            this.key_count := 1
        }
    }


    static GetModifiers() {                                             ; !#+^ ordinal order
        GetKeyState('Alt')   ? mods .= '!' : 0                          ; if alt is held, add to modifiers
        (GetKeyState('LWin') or GetKeyState('RWin')) ? mods .= '#' : 0  ; if Windows key is held, add to modifiers
        GetKeyState('Shift') ? mods .= '+' : 0                          ; if shift is held, add to modifiers
        GetKeyState('Ctrl')  ? mods .= '^' : 0                          ; if control is held, add to modifiers
        return mods ?? ''                                               ; return modifiers held when TapDance star
    }


    static ExceptionIsPresent() {
        switch {
            ; case WinActive('ahk_exe Explorer.exe'): return true             ; example
            default: return false
        }
    }
}

/**
 * values of alternate_keys can also be a callable func object
 */
class RepeatAlt {
    static alternate_keys := Map(
        'Up',           'Down',             'Down',             'Up',
        'Right',        'Left',             'Left',             'Right',
        'Home',         'End',              'End',              'Home',
        'PgUp',         'PgDn',             'PgDn',             'PgUp',
        'Backspace',    'Delete',           'Delete',           'Backspace',
        '[',            ']',                '{',                '}',            ; on char? {}
        'Browser_Back', 'Browser_Forward',  'Browser_Forward',  'Browser_Back',
        'Volume_Up',    'Volume_Down',      'Volume_Down',      'Volume_Up',
        'Media_Next',   'Media_Prev',       'Media_Prev',       'Media_Next',
        'z',            'y',                'y',                'z',            ; undo-redo
        'Tab',          '+Tab',             '+Tab',             'Tab',
        'e', 'd',               ; common bigram, typing 'picke [repeat key]' outputs picked
        '.', './',              ; outputs ../
        'k', 'eyboard',
        'a', () => (            ; manually typing a three times in a row and pressing RepeatAlt key displays message box
                Repeat.key_count > 3 ? MsgBox('more than 3 pressed') : Send('a')
            ),
    )


    static __New() {
        temp := Map()
        temp.CaseSense := 'Off'
        for key, value in this.alternate_keys {
            while p := RegExMatch(key, '$[\^!#+]{2,}', &mods, p?) { ; look for modifiers in alternate keys
                sorted := this.SortMods(mods[])                     ; sort modifiers if more than 1 in a row
                key := StrReplace(key, mods[], sorted)              ; replace modifiers in typed keys with sorted modifiers
                p += mods.Len                                       ; start search at previous place left off
            }
            temp.Set(key, value)
        }
        this.alternate_keys := temp
    }


    static Call() {
        last_key := Repeat.last_key
        last_key_mods := last_key['mods']
        last_key_name := last_key['name']
        key_with_mods := last_key_mods last_key_name
        Repeat.repeat_key_count++

        if not (last_key_mods and this.alternate_keys.Has(key := key_with_mods))
           and not this.alternate_keys.Has(key := last_key_name) {
            return
        }

        action := this.alternate_keys.Get(key)
        if action is Func {
            return action()
        }
        mods_on_key    := RegExReplace(key, '[^\^\+!#]*')                       ; get mods on key
        mods_on_action := RegExReplace(action, '[^\^\+!#]*')                    ; get mods on action
        action := StrReplace(action, mods_on_action)                            ; remove mods from action
        vksc   := Format('{vk{:x}sc{:x}}', GetKeyVK(action), GetKeySC(action))
        Send((mods_on_action or mods_on_key ? mods_on_action : last_key_mods) vksc)
    }


    static SortMods(mods) {                                             ; !#+^ ordinal order
        local temp := '', length := StrLen(mods)                        ; initialize some vars
        for char in StrSplit(mods) {                                    ; loop each modifier
            temp .= Ord(char) (A_Index != length ? ',' : '')            ; add their ordinal value to temp
        }
        temp := Sort(temp, 'N D,'), mods := ''                          ; sort ordinal values
        for char in StrSplit(temp, ',') {                               ; loop through ordinal values
            mods .= Chr(char)                                           ; add them back to mods
        }
        return mods                                                     ; return rearranged mods
    }
}