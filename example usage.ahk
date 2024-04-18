#Requires AutoHotkey v2.0
#SingleInstance

#Include KeyMods.ahk



/**
 * @CapsWord
 */
>+LShift::CapsWord(1)   ; pressing both shifts together enters CapsWord with a 1 second timeout
<+RShift::CapsWord(1)   ; see above


/**
 * @AutoShift
 */
+F1::AutoShift()


/**
 * @KeyLock
 */
$]::KeyLock()


/**
 * @ModTap
*/
+^F1::ModTap.Toggle()

#HotIf ModTap.enabled
*F19::ModTap('Ctrl', 'Escape')  ; holds control when pressed, sends escape when tapped (F19 is where CapsLock usually is on my keyboard)
*z::ModTap('LShift')            ; Left Shift when held, z when tapped
*/::ModTap('RShift')            ; Right Shift when held, / when tapped
#HotIf


/**
 * @DualFunction
 * similar to @ModTap except you can optionally call a function on press and release instead of holding/releasing a modifier
 * maybe DualFunction should be something else/do something more?
 */
*F22::DualFunction('Ctrl', 'Esc')   ; showing it works like ModTap in this example
$8::DualFunction(ToolTip.Bind('key was pressed'),, () => (ToolTip('key was released'), SetTimer(ToolTip, -2000)))


/**
 * @Repeat
 */
*F20::Repeat()
*F21::RepeatAlt()


/**
 * @TapDance
 * more examples here: https://pastebin.com/kr4NzmV4
 * but beware, the version of TapDance in the link is a little different,
 * possible those examples don't work with this version but should still give you some ideas
 */
^F1::TapDance.Toggle()

#HotIf TapDance.enabled
$[::TapDance(['[', '{'], [']', '}'],, 180)  ; tap for [, double-tap for {, hold for ], double-tap hold for }
$;::TapDance(, [':= '],, 180)               ; hold ; to send :=
$.::TapDance(, ['=> '],, 180)               ; hold . to send =>
#HotIf


/**
 * @leader
 * $ keyboard hook is important so the hotkey doesn't send itself in the first map key-value pair
 * keyboard hook also prevents all same InputLevel Sends from triggering Leader
 */
; you can use map directly
; $\::Leader(Map(
;    'play',     '${Media_Play_Pause}',                                          ; play/pause media
;    'c',        '${End}+{Home}^c{Esc}',                                         ; copy line
; ), 300, 0)
$\::Leader(leader_map, 300, 0)

leader_map := Map(
    '\',        '\',                                                            ; send leader key
    'play',     '${Media_Play_Pause}',                                          ; play/pause media

    '{BS}',     '${Backspace}',                                                 ; can be used with number prefix to backspace x times
    '{Delete}', '${Delete}',                                                    ; can be used with number prefix to delete x times
    'bb',       '$+{Home}{Backspace}',                                          ; backspace to beginning of line
    'bw',       '$^{Backspace}',                                                ; backspace word
    'dw',       '$^{Delete}',                                                   ; delete word
    'de',       '$+{End}{Backspace}',                                           ; delete to end of line
    'xl',       '${End}+{Home}{Backspace}',                                     ; delete all text on line
    'xx',       '${End}+{Home 2}{Backspace 2}{Home}',                           ; delete line, used with VSCode
    'il',       '${End}{Enter}',                                                ; insert line
    'al',       '${End}{Enter}',                                                ; add line
    'il',       '${Home}{Enter}{Left}',                                         ; add line

    'u',        '$^z',                                                          ; undo
    'r',        '$^y',                                                          ; redo
    'tt',       '$^]',                                                          ; shift line right {Tab} (VSCode)
    't',        '$^[',                                                          ; shift line left {Tab} (VSCode)
    'dl',       '$+!{Down}',                                                    ; duplicate line (VSCode)
    'yu',       (count) => Send('{End}+{Home}+{Up ' count '}+{Home}^c'),        ; copy x lines up
    'yy',       (count) => Send('{Home}+{End}+{Down ' count '}+{End}^c'),       ; copy x lines down
    'ya',       '$^a^c{Esc}',                                                   ; select all, copy (copy all)
    'c',        '${End}+{Home}^c{Esc}',                                         ; copy line
    'xu',       (count) => Send('{End}+{Home}+{Up ' count '}+{Home}^x'),        ; copy x lines up
    'xd',       (count) => Send('{Home}+{End}+{Down ' count '}+{End}^x'),       ; copy x lines down
    'x{Down}',  (count) => Send('{Home}+{End}+{Down ' count '}+{End}^x'),       ; copy x lines down, alternative
    'cx',       '${End}+{Home}^c+{Home}{Delete}',                               ; copy text on line, delete text

    'print',    'std::cout << ',                                                ; C++ character output
    '/c',       '$[c][/c]{Left 4}',                                             ; AHK forums inline code format
    'kbd',      '$[kbd][/kbd]{Left 6}',                                         ; AHK forums inline keyboard key format
    'nb',       '&nbsp;',                                                       ; new blank space (used with reddit usually)
    '``',       '$````{Left}',                                                  ; inline code on reddit

    'a',        'ä',                                                            ; swedish letters
    'aa',       'å',                                                            ; swedish letters
    '+a',       'Ä',                                                            ; swedish letters
    '+a+a',     'Å',                                                            ; swedish letters

    'task',     '$^+{Esc}',                                                     ; open task manager
    'snip',     '$#+s',                                                         ; snipping tool
    'fs',       '${F11}',                                                       ; fullscreen for some apps
    'gm',       'email@gmail.com',                                              ; type gmail email address
    'pe',       'personalemail@icloud.com',                                     ; type some other personal email address
    'e',        '${Up}',                                                        ; used so I can type numbers first and go that direction that many times
    's',        '${Left}',                                                      ; see above
    'f',        '${Right}',                                                     ; see above
    'd',        '${Down}',                                                      ; see above
    ; 'd',        (count) => Send('{Down ' count '}'),                            ; alternative to above

    'doc',      Run.Bind('https://www.autohotkey.com/docs/v2/misc/Remap.htm'),  ; AHK documentation
    'red',      Run.Bind('https://old.reddit.com'),                             ; reddit
    'file',     () => Run('explorer.exe'),                                      ; open file explorer

    'reload',   Reload,                                                         ; reload script
    'beep',     SoundBeep,                                          ; beep noise

    'max',      () => WinGetMinMax('A') ? WinRestore('A') : WinMaximize('A'),   ; maximize or unmaximize active window
    'min',      () => WinMinimize('A'),                                         ; minimize active window
    'help me',  MsgBox.Bind('help'),                                            ; testing space
    '{Tab}e',   MsgBox.Bind('Tab and e pressed'),                               ; testing braced keys
    '+{Tab}e',  MsgBox.Bind('Tab and e pressed part 2'),                        ; testing shift
    '^+e',      MsgBox.Bind('^+e'),                                             ; testing combinations of modifiers
    '!+f',      MsgBox.Bind('+^f'),                                             ; testing combinations of modifiers
    'test',     () => (                                                         ; multi-line function that doesn't require a separate declaration
                    temp := 'This is a multi-line fat arrow function.',
                    MsgBox(temp)
                ),
    ; 'cool',     () {                                                          ; function expression valid only in v2.1
    ;                 MsgBox('hi')
    ;             }
)