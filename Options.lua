local _, Addon = ...
local Options = {}
Addon.Options = Options

local text = ({
    plPL = {
        enabled = "Klasyczny interfejs",
        enabledTip = "Włącz ClassicConsoleGamepadUI, gdy aktywny jest tryb interfejsu pada. Zmiana podczas walki zostanie zastosowana po jej zakończeniu.",
        compact = "Kompaktowe paski (8 pól)",
        moveUnitFrames = "Klasyczne ramki gracza, celu i focusu",
        moveUnitFramesTip = "Ustawia te ramki w ich klasycznych miejscach. Przeciągnij je w trybie edycji i zapisz układ, a miejsce zostanie zapamiętane (/cgp resetframes cofa). Wyłącz, aby ramkami rządził wyłącznie tryb edycji pada.",
        compactTip = "Skróć trzy paski do 8 pól. L2 i R2 mają stałe sekcje u góry; L2+R2 pokazuje swoje akcje na dole. Wyłącz, aby użyć układu 12 pól, np. na Steam Decku. Zmiana podczas walki zostanie zastosowana po jej zakończeniu.",
        bindingsTip = "Zmień skróty klawiatury i przyciski pada w edytorze gry. Przypisania zapisuje gra, a podpowiedzi ClassicConsoleGamepadUI odświeżają się automatycznie.",
        bind = "Przypisz klawisze z pasków",
        bindTip = "Najedź na pole widocznego paska akcji, postaw lub zwierzaka i naciśnij klawisz albo przycisk pada. Escape kończy. Backspace usuwa główny skrót tego pola. Tryb startuje po zamknięciu ustawień.",
        bindActive = "Przypisywanie: najedź na pole i naciśnij klawisz lub przycisk pada. Escape kończy, Backspace usuwa.",
        bindNeed = "Najpierw najedź na pole.",
        bindOk = "Przypisano.",
        bindFail = "Nie udało się przypisać tego klawisza.",
        bindCleared = "Usunięto główny skrót.",
        actions = "Umiejętności na paskach pada",
        actionsTip = "Przenoś lub usuwaj umiejętności na stronach i warstwach LT/RT w natywnym edytorze. Wymaga trybu pada. Przycisk pokaże, jak otworzyć edytor bez blokowania sterowania; po jego zamknięciu wróci klasyczny pasek.",
        controlsTip = "Otwórz ustawienia trybu pada, kamery, modyfikatorów i celowania.",
        combat = "Zmiana przypisań jest dostępna poza walką.",
        gamepad = "Najpierw włącz tryb interfejsu pada w ustawieniach gry.",
    },
    deDE = {
        enabled = "Klassische Benutzeroberfläche",
        enabledTip = "ClassicConsoleGamepadUI verwenden, wenn der Gamepad-Modus aktiv ist. Änderungen im Kampf werden danach angewendet.",
        compact = "Kompakte Leisten (8 Plätze)",
        moveUnitFrames = "Klassische Spieler-, Ziel- und Fokusrahmen",
        moveUnitFramesTip = "Setzt diese Rahmen an ihre klassischen Plätze. Im Bearbeitungsmodus ziehen und das Layout speichern, dann merkt sich das Addon den Platz (/cgp resetframes setzt zurück). Deaktivieren, damit nur der Bearbeitungsmodus des Gamepads die Rahmen steuert.",
        compactTip = "Drei Leisten auf 8 Plätze verkürzen. L2 und R2 bleiben oben; L2+R2 zeigt seine Aktionen unten. Für 12 Plätze, z. B. auf dem Steam Deck, deaktivieren. Änderungen im Kampf werden danach angewendet.",
        bindingsTip = "Tastatur- und Controllerbelegungen im Spieleditor ändern. Das Spiel speichert die Belegungen; ClassicConsoleGamepadUI aktualisiert die Hinweise automatisch.",
        bind = "Tasten auf den Leisten zuweisen",
        bindTip = "Zeige auf ein Feld der sichtbaren Aktions-, Haltungs- oder Begleiterleiste und drücke eine Taste oder eine Controllertaste. Escape beendet den Modus. Rücktaste löscht die Hauptbelegung. Der Modus startet nach dem Schließen der Einstellungen.",
        bindActive = "Zuweisen: auf ein Feld zeigen und eine Taste oder Controllertaste drücken. Escape beendet, Rücktaste löscht.",
        bindNeed = "Zuerst auf ein Feld zeigen.",
        bindOk = "Zugewiesen.",
        bindFail = "Diese Taste konnte nicht zugewiesen werden.",
        bindCleared = "Hauptbelegung entfernt.",
        actions = "Aktionen auf Gamepad-Leisten",
        actionsTip = "Aktionen auf Seiten und LT/RT-Ebenen im nativen Editor verschieben oder entfernen. Erfordert den Gamepad-Modus. Die Schaltfläche zeigt, wie der Editor ohne Steuerungsblockade geöffnet wird; danach kehrt die klassische Leiste zurück.",
        controlsTip = "Einstellungen für Gamepad-Modus, Kamera, Modifikatoren und Zielerfassung öffnen.",
        combat = "Belegungen können nur außerhalb des Kampfes geändert werden.",
        gamepad = "Zuerst den Gamepad-Modus in den Spieleinstellungen aktivieren.",
    },
})[GetLocale()] or {
    enabled = "Classic interface",
    enabledTip = "Use ClassicConsoleGamepadUI while the game's Gamepad Mode is enabled. Changes during combat apply when combat ends.",
    compact = "Compact bars (8 slots)",
    moveUnitFrames = "Classic player, target and focus frames",
    moveUnitFramesTip = "Places these frames at their classic positions. Drag them in Edit Mode and save the layout and the new place is remembered (/cgp resetframes undoes it). Disable to let the gamepad layout's Edit Mode alone place the frames.",
    compactTip = "Shorten all three bars to 8 slots. L2 and R2 stay in fixed sections above; L2+R2 shows its actions below. Disable for 12 slots, for example on Steam Deck. Changes during combat apply when combat ends.",
    bindingsTip = "Change keyboard and controller bindings in the game's editor. The game saves bindings and ClassicConsoleGamepadUI refreshes its hints automatically.",
    bind = "Assign keys from the bars",
    bindTip = "Hover a visible action, stance or pet slot and press a keyboard key or a controller button. Escape finishes. Backspace clears that slot's primary binding. Starts when the settings close.",
    bindActive = "Assigning: hover a slot and press a key or controller button. Escape finishes, Backspace clears.",
    bindNeed = "Hover a slot first.",
    bindOk = "Assigned.",
    bindFail = "That key could not be assigned.",
    bindCleared = "Primary binding cleared.",
    actions = "Gamepad action assignments",
    actionsTip = "Move or remove actions across pages and LT/RT layers in the native editor. Requires Gamepad Mode. The button shows how to open the editor without blocking controller actions; the classic bar returns when it closes.",
    controlsTip = "Open gamepad mode, camera, modifier and targeting settings.",
    combat = "Bindings can only be changed outside combat.",
    gamepad = "Enable Gamepad Mode in the game's settings first.",
}

local extraText = ({
    plPL = {
        open = "Otwórz", layout = "Układ pasków", menu = "Panel menu", hints = "Podpowiedzi i podświetlenie",
        legend = "Legenda pada", chat = "Chat",
        contextGap = "Odstęp wskaźników od górnego rzędu",
        contextGapTip = "Odstęp nad paskiem dla L1/R1 i przycisków klasy. Lewy wskaźnik pozostaje po lewej, prawy po prawej.",
        menuRight = "Odstęp menu od prawej krawędzi", menuBottom = "Odstęp menu od dołu ekranu",
        menuTip = "Wartość 0 dosuwa panel do krawędzi ekranu. Zmiana nie przestawia plecaków.",
        promptScale = "Rozmiar symboli przycisków pada", promptScaleTip = "Zmień wielkość symboli X/Y/A/B i krzyża. Podpowiedzi LT/RT mają osobny suwak.",
        modifierScale = "Rozmiar podpowiedzi LT/RT", modifierScaleTip = "Skaluj symbole modyfikatorów (LT/RT, L2/R2) niezależnie od pozostałych przycisków pada.",
        showKeyboardHints = "Pokazuj skróty klawiatury", showKeyboardHintsTip = "Ukrycie napisów nie wyłącza przypisanych klawiszy.",
        showMenuHints = "Podpowiedzi pada w panelu menu", showMenuHintsTip = "Pokaż w tooltipie przycisk pada lub drogę przez menu kołowe.",
        highlightActive = "Podświetlaj aktywną warstwę pada", highlightActiveTip = "Zaznaczaj pasek używany przez L2, R2 i przyciski kontekstowe.",
        moveLegend = "Przenieś legendę pod ramkę gracza (eksperymentalne)", moveLegendTip = "Eksperymentalne: legenda może zasłaniać czat lub inne ramki. Wyłączone = natywna pozycja legendy pada.",
        legendX = "Pozycja legendy od lewej krawędzi", legendGap = "Odstęp legendy pod ramką gracza",
        legendPositionTip = "Pozycja legendy pada w punktach interfejsu.",
        anchorChat = "Pozycja chatu względem krawędzi ekranu", anchorChatTip = "Ustaw pozycję chatu suwakami poniżej, zachowując jego rozmiar. Wyłącz, aby wrócić do położenia z trybu edycji.",
        chatLeft = "Odstęp chatu od lewej krawędzi", chatBottom = "Odstęp chatu od dołu ekranu",
        chatPositionTip = "0 dosuwa chat do krawędzi, uwzględniając pole wpisywania i podpowiedzi pada. Aby dosunąć go do samego dołu także nad paskiem, wyłącz przesuwanie chatu nad pasek. Zmiany podczas walki czekają do jej zakończenia.",
        raiseChat = "Przesuwaj chat nad pasek", raiseChatTip = "Podnieś chat tylko tam, gdzie nachodzi na pasek. Uwzględnia tekst, pole wpisywania i podpowiedzi pada. Wyłącz, aby użyć dokładnej pozycji względem ekranu lub położenia z trybu edycji.",
        chatGap = "Odstęp chatu od paska", chatGapTip = "Minimalny odstęp między paskiem a dolną krawędzią chatu i jego podpowiedzi.",
        panelRoute = "W trybie pada otwórz ustawienia z menu gry: Opcje > Dodatki > ClassicConsoleGamepadUI. Otwieranie okien Blizzarda komendą blokuje później sterowanie padem.",
        keybindingsRoute = "Wybierz „%s” na liście ustawień po lewej.",
        gamepadRoute = "Wybierz „%s” na liście ustawień po lewej.",
        bindPending = "Zamknij ustawienia, aby rozpocząć przypisywanie.",
        editRouteKey = "Natywny edytor akcji otworzysz przyciskiem: %s",
        editRouteCommand = "Wpisz na czacie /click GamepadActionBarEditFrameEnterEditMode, aby otworzyć natywny edytor akcji.",
        keyboard = "Klawiatura ekranowa", autoKeyboard = "Klawiatura ekranowa przy pisaniu na chacie",
        autoKeyboardTip = "W trybie pada otwiera klawiaturę ekranową, gdy zaczynasz pisać na chacie. Klawiaturę otwierasz też komendą /cgp keyboard lub przyciskiem w Skróty klawiszowe.",
        keyboardTip = "Pokaż lub ukryj klawiaturę ekranową do pisania na chacie. Klikaj klawisze myszą; przeciągnij ją, aby zmienić miejsce.",
        keyboardLanguage = "Język klawiatury ekranowej",
        keyboardLanguageTip = "Układ klawiatury ekranowej i litery pod klawiszami T9: EN (QWERTY), DE (QWERTZ z ä ö ü ß), PL (QWERTY z polskimi literami). Wybór jest zapamiętywany.",
        keyboardInput = "Tryb T9 klawiatury ekranowej",
        keyboardInputTip = "Tap: naciskaj klawisz kilka razy, aby wybrać literę. Smart: naciskaj każdy klawisz raz i wybierz słowo z podpowiedzi. Hybrid: pisz literami jak w Tap, a podpowiedzi uzupełniają słowo (LB/RB wybierają, Y akceptuje).",
        inputTap = "Tap (wielokrotne naciśnięcia)", inputSmart = "Smart (podpowiedzi)", inputHybrid = "Hybrid (Tap + podpowiedzi)",
        tabGeneral = "Ogólne", tabHints = "Podpowiedzi", tabKeyboard = "Klawiatura", tabTools = "Narzędzia",
        padHint = "%s/%s: wybór  ·  %s/%s: zmiana  ·  %s: użyj  ·  %s: zamknij  ·  %s/%s: karty",
        forgetWords = "Zapomnij nauczone słowa",
        forgetWordsTip = "Czyści listę słów, których uczą się podpowiedzi klawiatury z czatu i tekstów zadań.",
        wordsForgotten = "Nauczone słowa zapomniane.",
        confirmAgain = "Kliknij ponownie, aby potwierdzić",
        openTip = "Otwórz okno ustawień. Możesz też wpisać /cgp.",
        items = "Przedmioty", easyDelete = "Łatwe usuwanie: X, X, A, A",
        easyDeleteTip = "W oknie usuwania wymagającym sekwencji przycisków użyj X, X, A, A. Czwarty przycisk zatwierdza usunięcie. B nadal anuluje, błędny przycisk zeruje sekwencję. Działa poza walką w trybie pada.",
    },
    deDE = {
        open = "Öffnen", layout = "Leistenanordnung", menu = "Mikromenü", hints = "Hinweise und Hervorhebung",
        legend = "Gamepad-Legende", chat = "Chat",
        contextGap = "Abstand der Anzeigen zur oberen Reihe",
        contextGapTip = "Abstand für L1/R1 und Klassenaktionen über der Leiste. Die linke Anzeige bleibt links, die rechte rechts.",
        menuRight = "Menüabstand zum rechten Bildschirmrand", menuBottom = "Menüabstand zum unteren Bildschirmrand",
        menuTip = "0 setzt das Menü direkt an den Bildschirmrand. Die Taschen bleiben an ihrer Position.",
        promptScale = "Größe der Gamepad-Tastensymbole", promptScaleTip = "Größe von X/Y/A/B und Steuerkreuz ändern. LT/RT-Hinweise haben einen eigenen Regler.",
        modifierScale = "Größe der LT/RT-Hinweise", modifierScaleTip = "Modifikatorsymbole (LT/RT, L2/R2) unabhängig von den anderen Gamepad-Tastensymbolen skalieren.",
        showKeyboardHints = "Tastaturbelegungen anzeigen", showKeyboardHintsTip = "Ausblenden der Beschriftung deaktiviert keine Tastaturbelegung.",
        showMenuHints = "Gamepad-Hinweise im Mikromenü", showMenuHintsTip = "Direkte Controllertaste oder Weg durch das Radialmenü im Tooltip anzeigen.",
        highlightActive = "Aktive Gamepad-Ebene hervorheben", highlightActiveTip = "Die durch L2, R2 oder Kontexttasten verwendete Leiste hervorheben.",
        moveLegend = "Legende unter den Spielerrahmen verschieben (experimentell)", moveLegendTip = "Experimentell: die Legende kann Chat oder andere Rahmen verdecken. Deaktiviert = ursprüngliche Position der Gamepad-Legende.",
        legendX = "Legendenabstand zum linken Bildschirmrand", legendGap = "Legendenabstand unter dem Spielerrahmen",
        legendPositionTip = "Position der Gamepad-Legende in Oberflächenpunkten.",
        anchorChat = "Chatposition vom Bildschirmrand aus", anchorChatTip = "Die Chatposition mit den Reglern unten einstellen; seine Größe bleibt erhalten. Deaktivieren, um die Position aus dem Bearbeitungsmodus zu verwenden.",
        chatLeft = "Chatabstand zum linken Bildschirmrand", chatBottom = "Chatabstand zum unteren Bildschirmrand",
        chatPositionTip = "0 setzt den Chat mit Eingabefeld und Gamepad-Hinweisen an den Bildschirmrand. Für den unteren Rand auch über der Aktionsleiste das automatische Anheben deaktivieren. Änderungen im Kampf werden danach angewendet.",
        raiseChat = "Chat über die Aktionsleiste verschieben", raiseChatTip = "Chat nur bei Überlappung mit der Aktionsleiste anheben, einschließlich Eingabe und Gamepad-Hinweisen. Deaktivieren, um die genaue Bildschirmposition oder die Position aus dem Bearbeitungsmodus zu verwenden.",
        chatGap = "Chatabstand zur Aktionsleiste", chatGapTip = "Mindestabstand zwischen Aktionsleiste und unterem Rand von Chat und Hinweisen.",
        panelRoute = "Im Gamepad-Modus die Einstellungen über das Spielmenü öffnen: Optionen > AddOns > ClassicConsoleGamepadUI. Per Befehl geöffnete Blizzard-Fenster blockieren später die Controllersteuerung.",
        keybindingsRoute = "Links in der Einstellungsliste „%s“ wählen.",
        gamepadRoute = "Links in der Einstellungsliste „%s“ wählen.",
        bindPending = "Einstellungen schließen, um mit dem Zuweisen zu beginnen.",
        editRouteKey = "Den nativen Aktionseditor öffnest du mit: %s",
        editRouteCommand = "Im Chat /click GamepadActionBarEditFrameEnterEditMode eingeben, um den nativen Aktionseditor zu öffnen.",
        keyboard = "Bildschirmtastatur", autoKeyboard = "Bildschirmtastatur beim Chatten",
        autoKeyboardTip = "Öffnet im Gamepad-Modus die Bildschirmtastatur, sobald du im Chat schreibst. Auch mit /cgp keyboard oder über die Schaltfläche bei den Tastenbelegungen.",
        keyboardTip = "Bildschirmtastatur zum Schreiben im Chat ein- oder ausblenden. Tasten mit der Maus anklicken; zum Verschieben ziehen.",
        keyboardLanguage = "Sprache der Bildschirmtastatur",
        keyboardLanguageTip = "Layout der Bildschirmtastatur und Buchstaben unter den T9-Tasten: EN (QWERTY), DE (QWERTZ mit ä ö ü ß), PL (QWERTY mit polnischen Buchstaben). Die Wahl wird gemerkt.",
        keyboardInput = "T9-Modus der Bildschirmtastatur",
        keyboardInputTip = "Tap: Taste mehrmals drücken, um den Buchstaben zu wählen. Smart: jede Taste einmal drücken und das Wort aus den Vorschlägen wählen. Hybrid: Buchstaben wie bei Tap tippen, Vorschläge ergänzen das Wort (LB/RB wählen, Y übernimmt).",
        inputTap = "Tap (mehrfach drücken)", inputSmart = "Smart (Vorschläge)", inputHybrid = "Hybrid (Tap + Vorschläge)",
        tabGeneral = "Allgemein", tabHints = "Hinweise", tabKeyboard = "Tastatur", tabTools = "Werkzeuge",
        padHint = "%s/%s: wählen  ·  %s/%s: ändern  ·  %s: benutzen  ·  %s: schließen  ·  %s/%s: Tabs",
        forgetWords = "Gelernte Wörter vergessen",
        forgetWordsTip = "Löscht die Wortliste, die die Vorschläge der Tastatur aus Chat und Questtexten lernen.",
        wordsForgotten = "Gelernte Wörter vergessen.",
        confirmAgain = "Zum Bestätigen erneut klicken",
        openTip = "Das Einstellungsfenster öffnen. Du kannst auch /cgp eingeben.",
        items = "Gegenstände", easyDelete = "Einfaches Zerstören: X, X, A, A",
        easyDeleteTip = "Im Zerstörungsdialog mit Tastenkombination X, X, A, A drücken. Die vierte Taste bestätigt das Zerstören. B bricht weiterhin ab; eine falsche Taste setzt die Folge zurück. Nur außerhalb des Kampfes im Gamepad-Modus.",
    },
})[GetLocale()] or {
    open = "Open", layout = "Bar layout", menu = "Micro menu", hints = "Hints and highlighting",
    legend = "Gamepad legend", chat = "Chat",
    contextGap = "Indicator gap above the upper row", contextGapTip = "Gap for L1/R1 indicators and class actions. The left indicator stays on the left and the right stays on the right.",
    menuRight = "Menu distance from the right edge", menuBottom = "Menu distance from the bottom edge",
    menuTip = "0 places the menu against the screen edge. Bags keep their position.",
    promptScale = "Controller button glyph size", promptScaleTip = "Change X/Y/A/B and directional glyph size. LT/RT hints have their own slider.",
    modifierScale = "LT/RT hint size", modifierScaleTip = "Scale modifier glyphs (LT/RT, L2/R2) independently of other controller button glyphs.",
    showKeyboardHints = "Show keyboard bindings", showKeyboardHintsTip = "Hiding labels keeps their keyboard bindings active.",
    showMenuHints = "Controller hints in the micro menu", showMenuHintsTip = "Show the direct controller binding or radial-menu route in tooltips.",
    highlightActive = "Highlight the active gamepad layer", highlightActiveTip = "Highlight the bar used by L2, R2 and contextual buttons.",
    moveLegend = "Move the legend below the player frame (experimental)", moveLegendTip = "Experimental: the legend can end up over chat or other frames. Off = the native gamepad legend position.",
    legendX = "Legend distance from the left edge", legendGap = "Legend gap below the player frame",
    legendPositionTip = "Position the gamepad legend in interface points.",
    anchorChat = "Position chat from screen edges", anchorChatTip = "Set the chat position with the sliders below while keeping its size. Disable to use its Edit Mode position.",
    chatLeft = "Chat distance from the left edge", chatBottom = "Chat distance from the bottom edge",
    chatPositionTip = "0 aligns chat with the screen edge, including its input box and controller hints. To reach the very bottom even over the action bar, disable Move chat above the action bar. Changes during combat apply when combat ends.",
    raiseChat = "Move chat above the action bar", raiseChatTip = "Raise chat only where it overlaps the bar, including its input box and controller hints. Disable to use the exact screen-edge position or the Edit Mode position.",
    chatGap = "Chat gap above the action bar", chatGapTip = "Minimum gap between the bar and the bottom of chat and its hints.",
    panelRoute = "In Gamepad Mode, open these settings from the game menu: Options > AddOns > ClassicConsoleGamepadUI. Blizzard windows opened by a command block controller actions later.",
    keybindingsRoute = "Choose %s in the settings list on the left.",
    gamepadRoute = "Choose %s in the settings list on the left.",
    bindPending = "Close the settings to start assigning keys.",
    editRouteKey = "Open the native action editor with: %s",
    editRouteCommand = "Type /click GamepadActionBarEditFrameEnterEditMode in chat to open the native action editor.",
    keyboard = "On-screen keyboard", autoKeyboard = "On-screen keyboard when typing in chat",
    autoKeyboardTip = "In Gamepad Mode, open the on-screen keyboard when you start typing in chat. You can also open it with /cgp keyboard or the button under key bindings.",
    keyboardTip = "Show or hide an on-screen keyboard for typing in chat. Click the keys with the mouse; drag it to move it.",
    keyboardLanguage = "On-screen keyboard language",
    keyboardLanguageTip = "Layout of the on-screen keyboard and the letters under the T9 keys: EN (QWERTY), DE (QWERTZ with ä ö ü ß), PL (QWERTY with Polish letters). The choice is remembered.",
    keyboardInput = "On-screen keyboard T9 mode",
    keyboardInputTip = "Tap: press a key repeatedly to pick the letter. Smart: press each key once and pick the word from the suggestions. Hybrid: tap the letters as in Tap and let the suggestions complete the word (LB/RB choose, Y accepts).",
    inputTap = "Tap (repeated presses)", inputSmart = "Smart (suggestions)", inputHybrid = "Hybrid (Tap + suggestions)",
    tabGeneral = "General", tabHints = "Hints", tabKeyboard = "Keyboard", tabTools = "Tools",
    padHint = "%s/%s: select  ·  %s/%s: adjust  ·  %s: activate  ·  %s: close  ·  %s/%s: tabs",
    forgetWords = "Forget learned words",
    forgetWordsTip = "Clears the word list the keyboard's suggestions learn from chat and quest texts.",
    wordsForgotten = "Learned words forgotten.",
    confirmAgain = "Click again to confirm",
    openTip = "Open the settings window. You can also type /cgp.",
    items = "Items", easyDelete = "Easy deletion: X, X, A, A",
    easyDeleteTip = "Use X, X, A, A in item deletion dialogs that require a button sequence. The fourth press confirms deletion. B still cancels; a wrong button resets the sequence. Available outside combat in Gamepad Mode.",
}
for key, value in pairs(extraText) do text[key] = value end

local controls = {
    { key = "enabled", default = true, section = "layout" },
    { key = "compact", default = true },
    { key = "moveUnitFrames", default = true },
    { key = "contextGap", default = 12, min = 0, max = 100, step = 2 },
    { key = "menuRight", default = 12, min = 0, max = 128, step = 1, section = "menu", tip = "menuTip" },
    { key = "menuBottom", default = 0, min = 0, max = 240, step = 1, tip = "menuTip" },
    { key = "promptScale", default = 1, min = 0.6, max = 1.6, step = 0.05, section = "hints" },
    { key = "modifierScale", default = 1.5, min = 0.6, max = 2.5, step = 0.05 },
    { key = "showKeyboardHints", default = true },
    { key = "showMenuHints", default = true },
    { key = "highlightActive", default = true },
    { key = "moveLegend", default = false, section = "legend" },
    { key = "legendX", default = 16, min = 0, max = 600, step = 2, parent = "moveLegend", tip = "legendPositionTip" },
    { key = "legendGap", default = 12, min = 0, max = 240, step = 2, parent = "moveLegend", tip = "legendPositionTip" },
    { key = "anchorChat", default = false, section = "chat" },
    { key = "chatLeft", default = 0, min = 0, max = 1200, step = 1, parent = "anchorChat", tip = "chatPositionTip" },
    { key = "chatBottom", default = 0, min = 0, max = 800, step = 1, parent = "anchorChat", tip = "chatPositionTip" },
    { key = "raiseChat", default = true },
    { key = "chatGap", default = 12, min = 0, max = 100, step = 2, parent = "raiseChat" },
    { key = "autoKeyboard", default = false },
    { key = "easyDelete", default = false, section = "items" },
}

local geometrySettings = { compact = true, contextGap = true,
    menuRight = true, menuBottom = true, promptScale = true, modifierScale = true }

-- Shared with the settings window (SettingsWindow.lua).
Options.text, Options.controls = text, controls
Options.choices = {
    keyboardLanguage = { { "EN", "English (QWERTY)" }, { "DE", "Deutsch (QWERTZ)" }, { "PL", "Polski (QWERTY)" } },
    keyboardPhone = { { "t9", text.inputTap }, { "t9p", text.inputSmart }, { "t9h", text.inputHybrid } },
}

-- A setting was changed in the settings window (its value is already in the database).
function Options:Changed(key)
    Addon:Trace("setting " .. key)
    Addon:CheckNativeTaint("setting changed: " .. key)
    if key == "keyboardLanguage" then
        Addon.Keyboard:SetLanguage(Addon.db[key])
    elseif key == "keyboardPhone" then
        if (Addon.Keyboard.mode or Addon.db.keyboardMode) ~= "abc" then Addon.Keyboard:SetMode(Addon.db[key]) end
    else
        if geometrySettings[key] then Addon.Layout.dirty = true end
        Addon:QueueRefresh(true)
    end
end

local KEYBOARD_LANGUAGES = { "EN", "DE", "PL" }
local KEYBOARD_INPUTS = { "t9", "t9p", "t9h" }

local function Contains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
end

function Options:InitializeDefaults()
    if not Contains(KEYBOARD_LANGUAGES, Addon.db.keyboardLanguage) then Addon.db.keyboardLanguage = "EN" end
    -- Hybrid is the default T9 mode; whatever was saved while it did not exist yet is replaced once.
    if not Addon.db.hybridDefault then
        Addon.db.hybridDefault = true
        Addon.db.keyboardPhone = "t9h"
        if Addon.db.keyboardMode ~= "abc" then Addon.db.keyboardMode = "t9h" end
    end
    if not Contains(KEYBOARD_INPUTS, Addon.db.keyboardPhone) then Addon.db.keyboardPhone = "t9h" end
    for _, info in ipairs(controls) do
        local value = Addon.db[info.key]
        if type(value) ~= type(info.default) or (info.min and (value ~= value or value < info.min or value > info.max)) then
            Addon.db[info.key] = info.default
        end
    end
end

local function OutsideCombat()
    if not InCombatLockdown() then return true end
    Addon:Print(text.combat)
    return false
end

-- Opening, switching or closing Blizzard panels from addon code runs the
-- gamepad focus, SmartNavigation and binding-stack setup in tainted
-- execution. Those tainted tables later block SetPreferredGamepadInteractTarget
-- whenever any panel closes, so in Gamepad Mode only the player opens them.
local function CanDrivePanels()
    return not Addon:IsGamepadMode()
end

function Options:OpenBindings()
    if not OutsideCombat() then return end
    if not CanDrivePanels() then
        Addon:Print(SettingsPanel:IsShown() and text.keybindingsRoute:format(SETTINGS_KEYBINDINGS_LABEL) or text.panelRoute)
        return
    end
    Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
end

function Options:OpenGamepad()
    if not OutsideCombat() then return end
    if not CanDrivePanels() then
        Addon:Print(SettingsPanel:IsShown() and text.gamepadRoute:format(GAMEPAD_LABEL) or text.panelRoute)
        return
    end
    for _, category in ipairs(SettingsPanel:GetAllCategories()) do
        if category:GetName() == GAMEPAD_LABEL then
            Settings.OpenToCategory(category:GetID())
            return
        end
    end
end

-- The native editor opens through Blizzard's own click button. Calling
-- EnterEditMode directly restyles the native bars in tainted execution.
function Options:EditActions()
    if not OutsideCombat() then return end
    if not Addon:IsGamepadMode() then Addon:Print(text.gamepad); return end
    if GamepadActionBarEditFrame:IsShown() then return end
    local command = "CLICK GamepadActionBarEditFrameEnterEditMode:LeftButton"
    local keys = {}
    for _, key in ipairs({ GetBindingKey(command) }) do
        keys[#keys + 1] = IsBindingForGamePad(key) and Addon.MenuHints:KeyText(key) or GetBindingText(key, 1)
    end
    if #keys > 0 then
        Addon:Print(text.editRouteKey:format(table.concat(keys, " / ")))
    else
        Addon:Print(text.editRouteCommand)
    end
end

local function BindingContext(action)
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        return C_KeyBindings.GetBindingContextForAction(action)
    end
end

local function CurrentKeys(action, context)
    if not GetBindingKey then return end
    return GetBindingKey(action, nil, context)
end

function Options:EnsureBindCatcher()
    if self.catcher then return end
    local catcher = CreateFrame("Frame", "ClassicConsoleGamepadUIBindCatcher", UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:EnableKeyboard(true)
    catcher:EnableMouse(false)
    catcher:SetScript("OnKeyDown", function(frame, key)
        local handled = self:HandleBindInput(key)
        if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(not handled) end
    end)
    catcher:SetScript("OnGamePadButtonDown", function(_, key)
        self:HandleBindInput(key)
    end)
    catcher:SetScript("OnEvent", function() self:StopBarBind() end)
    catcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    if catcher.EnableGamePadButton then pcall(catcher.EnableGamePadButton, catcher, true) end
    local notice = CreateFrame("Frame", nil, catcher)
    notice:SetSize(720, 64)
    notice:EnableMouse(false)
    notice:SetPoint("TOP", UIParent, "TOP", 0, -80)
    notice.text = notice:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    notice.text:SetPoint("TOP")
    notice.text:SetWidth(700)
    notice.text:SetJustifyH("CENTER")
    self.catcher, self.notice = catcher, notice
    self.watchedButtons = {}
    catcher:Hide()
end

function Options:WatchBindButton(button, resolve)
    if not button or self.watchedButtons[button] then return end
    local ok = pcall(function()
        button:HookScript("OnEnter", function()
            if not self.binding then return end
            local action, slot = resolve(button)
            if action then self:SetBindTarget(button, action, slot) end
        end)
        button:HookScript("OnLeave", function()
            if self.binding and self.binding.button == button then self:SetBindTarget(nil, nil, nil) end
        end)
    end)
    if ok then self.watchedButtons[button] = true end
end

function Options:WatchBindTargets()
    self:EnsureBindCatcher()
    if Addon.Input and Addon.Input.buttons then
        for index, button in pairs(Addon.Input.buttons) do
            self:WatchBindButton(button, function()
                local slot = Addon.Display.slots[index]
                local action = slot and slot.bindingAction
                return action, slot
            end)
        end
    end
    for _, bar in ipairs({ StanceBar, PetActionBar }) do
        if bar and bar.actionButtons then
            for _, button in ipairs(bar.actionButtons) do
                self:WatchBindButton(button, function(target)
                    return target.commandName, nil
                end)
            end
        end
    end
end

function Options:SetBindTarget(button, action, slot)
    local binding = self.binding
    if not binding then return end
    if binding.slot then binding.slot.bindingHighlight = nil end
    if binding.native and binding.native.DisableDrawLayer then
        pcall(binding.native.DisableDrawLayer, binding.native, "HIGHLIGHT")
    end
    binding.button, binding.action, binding.slot = button, action, slot
    binding.native = slot and nil or button
    if slot then slot.bindingHighlight = true end
    if binding.native and binding.native.EnableDrawLayer then
        pcall(binding.native.EnableDrawLayer, binding.native, "HIGHLIGHT")
    end
    self:UpdateBindNotice()
end

function Options:UpdateBindNotice(result)
    if not self.notice then return end
    local binding = self.binding
    local line = text.bindActive
    if result then
        line = result
    elseif binding and binding.action then
        local name = GetBindingName and GetBindingName(binding.action) or binding.action
        local context = BindingContext(binding.action)
        local key = CurrentKeys(binding.action, context)
        local keyText = key and GetBindingText and GetBindingText(key, 1) or ""
        line = text.bindActive .. "\n" .. name .. (keyText ~= "" and ("  " .. keyText) or "")
    else
        line = text.bindActive .. "\n" .. text.bindNeed
    end
    self.notice.text:SetText(line)
end

function Options:WriteBinding(action, key, clear)
    local context = BindingContext(action)
    if not context or not SetBinding then return false end
    local key1, key2 = CurrentKeys(action, context)
    if clear then
        if key1 then SetBinding(key1, nil, context) end
        if key2 then SetBinding(key2, action, context) end
    else
        if key1 then SetBinding(key1, nil, context) end
        if key2 and key2 ~= key then SetBinding(key2, nil, context) end
        SetBinding(key, nil, context)
        if not SetBinding(key, action, context) then
            if key1 then SetBinding(key1, action, context) end
            if key2 then SetBinding(key2, action, context) end
            return false
        end
        if key2 and key2 ~= key then SetBinding(key2, action, context) end
    end
    SaveBindings(GetCurrentBindingSet())
    Addon.Input.dirty = true
    local slot = self.binding and self.binding.slot
    if slot and slot.Key then
        local shown = clear and key2 or nil
        if not clear then shown = key end
        slot.Key:SetText(shown and GetBindingText(shown, 1) or "")
    end
    local native = self.binding and self.binding.native
    if native and native.UpdateHotkeys and native.commandName then
        local prefix = native.commandName:match("^(.-)%d+$")
        if prefix then pcall(native.UpdateHotkeys, native, prefix) end
    end
    return true
end

function Options:HandleBindInput(key)
    if not self.binding then return false end
    if InCombatLockdown() then self:StopBarBind(); return true end
    if key == "ESCAPE" then self:StopBarBind(); return true end
    local action = self.binding.action
    if not action then
        self:UpdateBindNotice(text.bindNeed)
        return true
    end
    if key == "BACKSPACE" or key == "DELETE" then
        local ok, assigned = pcall(self.WriteBinding, self, action, nil, true)
        self:UpdateBindNotice((ok and assigned) and text.bindCleared or text.bindFail)
        return true
    end
    if type(IsKeyPressIgnoredForBinding) == "function" and IsKeyPressIgnoredForBinding(key) then
        return true
    end
    local chord = key
    if type(GetConvertedKeyOrButton) == "function" then chord = GetConvertedKeyOrButton(key) or key end
    if type(CreateKeyChordStringUsingMetaKeyState) == "function" then
        chord = CreateKeyChordStringUsingMetaKeyState(chord) or chord
    end
    local ok, assigned = pcall(self.WriteBinding, self, action, chord, false)
    self:UpdateBindNotice((ok and assigned) and text.bindOk or text.bindFail)
    return true
end

function Options:StartBarBind()
    if self.binding then return end
    Addon:Trace("Options:StartBarBind")
    self:WatchBindTargets()
    self.binding = {}
    Addon.Input:SetBindingMode(true)
    Addon:QueueRefresh(true)
    self.catcher:Show()
    self:UpdateBindNotice()
end

function Options:StopBarBind()
    if not self.binding then return end
    Addon:Trace("Options:StopBarBind")
    self:SetBindTarget(nil, nil, nil)
    self.binding = nil
    if self.catcher then self.catcher:Hide() end
    Addon.Input:SetBindingMode(false)
    Addon:QueueRefresh(true)
end

function Options:BindFromBars()
    if not OutsideCombat() then return end
    Addon.SettingsWindow:Hide()
    if SettingsPanel:IsShown() then
        -- Let the player close Settings; closing it from here taints its teardown.
        self.pendingBind = true
        Addon:Print(text.bindPending)
        return
    end
    self:StartBarBind()
end

function Options:ObserveSettingsPanel()
    SettingsPanel:HookScript("OnHide", function()
        if not self.pendingBind then return end
        self.pendingBind = nil
        -- Start after the native close has finished.
        C_Timer.After(0, function()
            if OutsideCombat() then self:StartBarBind() end
        end)
    end)
end

-- Options > AddOns has one button that opens the settings window.
function Options:Register()
    local category, layout = Settings.RegisterVerticalLayoutCategory("ClassicConsoleGamepadUI")
    self.category = category
    layout:AddInitializer(CreateSettingsButtonInitializer("ClassicConsoleGamepadUI", text.open, function()
        Addon.SettingsWindow:Open()
    end, text.openTip, true))
    Settings.RegisterAddOnCategory(category)
    self:ObserveSettingsPanel()
end

function Options:Open()
    Addon.SettingsWindow:Toggle()
end
