//
//  Localization.swift
//  Cornice
//

import Foundation

/// Cornice's interface language.
///
/// Held in the app's own preferences rather than left to `AppleLanguages`, which macOS
/// only applies at launch. Cornice has a few dozen strings and one window; a dictionary
/// switches them the instant the picker moves, and correcting a translation is a
/// one-line edit rather than a trip through a string catalogue.
enum Language: String, CaseIterable, Identifiable, Sendable {
    case en, ru, uk, de, fr, es, pt, it, nl, pl, cs, sv, tr, ja, ko, zh

    var id: String { rawValue }

    /// Written in the language itself: someone looking for their own language is not
    /// helped by seeing it named in a language they do not read.
    var endonym: String {
        switch self {
        case .en: "English"
        case .ru: "Русский"
        case .uk: "Українська"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        case .pt: "Português"
        case .it: "Italiano"
        case .nl: "Nederlands"
        case .pl: "Polski"
        case .cs: "Čeština"
        case .sv: "Svenska"
        case .tr: "Türkçe"
        case .ja: "日本語"
        case .ko: "한국어"
        case .zh: "简体中文"
        }
    }

    /// For formatting numbers in the language the user picked here.
    ///
    /// Without it a decimal point follows the *system* locale while every word on the
    /// screen follows this one, so a Russian machine showing the English interface put
    /// "1,5" next to "Thickness". The window has its own language; its numbers should
    /// speak it too.
    var locale: Locale { Locale(identifier: rawValue) }

    /// The closest match to the system's preferred languages, falling back to English.
    static var systemDefault: Language {
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.prefix(2)).lowercased()
            if let match = Language(rawValue: code) { return match }
        }
        return .en
    }
}

/// Keys are the English text, so an untranslated string still reads correctly rather
/// than showing a placeholder.
enum L {
    static func t(_ key: String) -> String {
        let language = Preferences.shared.language
        if language == .en { return key }
        return table[language]?[key] ?? key
    }

    private static let table: [Language: [String: String]] = [
        .ru: [
            "Behaviour": "Поведение",
            "Appearance": "Оформление",
            "Menu Bar": "Строка меню",
            "Start with the icons hidden": "Запускаться со скрытыми значками",
            "Otherwise Cornice comes up the way you left it.":
                "Иначе Cornice откроется так, как вы его оставили.",
            "Hide again when the pointer leaves the menu bar":
                "Сворачивать, когда курсор уходит из строки меню",
            "After": "Через",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Небольшая пауза, чтобы случайное движение вдоль верха экрана ничего не прятало.",
            "Open at login": "Запускать при входе",
            "Divider": "Разделитель",
            "Thickness": "Толщина",
            "Height": "Высота",
            "Preview": "Образец",
            "Toggle button": "Кнопка-переключатель",
            "Symbol": "Символ",
            "Chevron": "Шеврон",
            "Chevron, compact": "Шеврон, узкий",
            "Arrow": "Стрелка",
            "Triangle": "Треугольник",
            "Sidebar": "Боковая панель",
            "Language": "Язык",
            "Hidden, left of the divider": "Скрытые, левее разделителя",
            "Keep a second divider, for icons you never want to see":
                "Второй разделитель, для значков, которые видеть не нужно",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Занимает ещё одно место в строке меню. ⌘-перетащите его левее первого разделителя: всё, что окажется за ним, останется скрытым, даже когда остальное показано.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-клик по кнопке-переключателю открывает зону, или назначьте сочетание ниже.",
            "Open or close the always hidden zone": "Открыть или закрыть всегда скрытую зону",
            "Always hidden, left of the second divider":
                "Всегда скрытые, левее второго разделителя",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Пусто. Перетащите второй разделитель левее значков, которые видеть не нужно.",
            "Visible, right of the divider": "Видимые, правее разделителя",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Пусто. Перетащите разделитель левее значков, которые хотите убрать.",
            "⌘-drag the divider to change what is hidden.":
                "⌘-перетаскиванием разделителя меняется состав скрытого.",
            "Refresh": "Обновить",
            "Settings…": "Настройки…",
            "Quit Cornice": "Завершить Cornice",
            "Version": "Версия",
            "Check for Updates": "Проверить обновления",
            "Check at launch": "Проверять при запуске",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Один запрос к GitHub, без каких-либо сведений о вас. Cornice ничего не устанавливает поверх себя.",
            "You have the latest version.": "Установлена последняя версия.",
            "is available": "доступна",
            "Could not check:": "Не удалось проверить:",
            "off-screen": "за экраном",
            "Gestures": "Жесты",
            "Move windows with trackpad gestures": "Двигать окна жестами тачпада",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "По умолчанию выключено. Доступ к Универсальному доступу запрашивается только при включении.",
            "Accessibility has not been granted, so gestures are not running.":
                "Универсальный доступ не выдан, жесты не работают.",
            "Open Accessibility settings": "Открыть настройки Универсального доступа",
            "Two fingers, pointer on a window's title bar":
                "Два пальца, курсор на заголовке окна",
            "Left half": "Левая половина",
            "Right half": "Правая половина",
            "Fill the screen": "На весь экран",
            "Put it back where it was": "Вернуть как было",
            "Keyboard shortcuts": "Горячие клавиши",
            "Hide or reveal the icons": "Скрыть или показать значки",
            "Turn automatic hiding on or off": "Включить или выключить автоскрытие",
            "Nothing is bound until you bind it. They work from any application.":
                "Пока вы ничего не назначили, ничего и не работает. Действуют из любого приложения.",
            "Click, then press the combination you want.":
                "Нажмите, потом нажмите нужное сочетание.",
            "Remove this shortcut": "Убрать это сочетание",
            "Press keys…": "Нажмите клавиши…",
            "Not set": "Не задано",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Нужно минимум два модификатора, один из них ⌘, ⌥ или ⌃.",
            "Something else already uses that.": "Это сочетание уже занято.",
            "Swipe again straight after, and it refines instead of starting over":
                "Свайпните ещё раз сразу следом, и это уточнит, а не начнёт заново",
            "Narrower: a third, then two thirds": "Уже: треть, потом две трети",
            "Top quarter of that side": "Верхняя четверть этой стороны",
            "Bottom quarter of that side": "Нижняя четверть этой стороны",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "Вправо работает так же. Выждите мгновение, и следующий свайп начнёт заново.",
            "Send the window to the Dock": "Убрать окно в Dock",
            "Pinch in, on the title bar. It never closes anything.":
                "Щипок внутрь, на заголовке. Ничего никогда не закрывает.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Список значков по именам требует Универсального доступа. Скрытие нет.",
            "Cornice already uses that for something else.":
                "Cornice уже использует это для другого действия.",
        ],
        .uk: [
            "Behaviour": "Поведінка",
            "Appearance": "Оформлення",
            "Menu Bar": "Рядок меню",
            "Start with the icons hidden": "Запускатися зі схованими значками",
            "Otherwise Cornice comes up the way you left it.":
                "Інакше Cornice відкриється так, як ви його залишили.",
            "Hide again when the pointer leaves the menu bar":
                "Згортати, коли курсор залишає рядок меню",
            "After": "Через",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Невелика пауза, щоб випадковий рух уздовж верху екрана нічого не ховав.",
            "Open at login": "Запускати під час входу",
            "Divider": "Роздільник",
            "Thickness": "Товщина",
            "Height": "Висота",
            "Preview": "Зразок",
            "Toggle button": "Кнопка-перемикач",
            "Symbol": "Символ",
            "Chevron": "Шеврон",
            "Chevron, compact": "Шеврон, вузький",
            "Arrow": "Стрілка",
            "Triangle": "Трикутник",
            "Sidebar": "Бічна панель",
            "Language": "Мова",
            "Hidden, left of the divider": "Приховані, ліворуч від роздільника",
            "Keep a second divider, for icons you never want to see":
                "Другий роздільник, для значків, які бачити не потрібно",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Займає ще одне місце в рядку меню. ⌘-перетягніть його ліворуч від першого роздільника: усе, що опиниться за ним, лишиться прихованим, навіть коли решта показана.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-клік по кнопці-перемикачі відкриває зону, або призначте сполучення нижче.",
            "Open or close the always hidden zone":
                "Відкрити або закрити завжди приховану зону",
            "Always hidden, left of the second divider":
                "Завжди приховані, ліворуч від другого роздільника",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Порожньо. Перетягніть другий роздільник ліворуч від значків, які бачити не потрібно.",
            "Visible, right of the divider": "Видимі, праворуч від роздільника",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Порожньо. Перетягніть роздільник ліворуч від значків, які хочете прибрати.",
            "⌘-drag the divider to change what is hidden.":
                "⌘-перетягуванням роздільника змінюється склад прихованого.",
            "Refresh": "Оновити",
            "Settings…": "Налаштування…",
            "Quit Cornice": "Завершити Cornice",
            "Version": "Версія",
            "Check for Updates": "Перевірити оновлення",
            "Check at launch": "Перевіряти під час запуску",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Один запит до GitHub, без жодних відомостей про вас. Cornice нічого не встановлює поверх себе.",
            "You have the latest version.": "Встановлено найновішу версію.",
            "is available": "доступна",
            "Could not check:": "Не вдалося перевірити:",
            "off-screen": "за екраном",
            "Gestures": "Жести",
            "Move windows with trackpad gestures": "Рухати вікна жестами трекпада",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Типово вимкнено. Доступ до Універсального доступу запитується лише при увімкненні.",
            "Accessibility has not been granted, so gestures are not running.":
                "Універсальний доступ не надано, жести не працюють.",
            "Open Accessibility settings": "Відкрити налаштування Універсального доступу",
            "Two fingers, pointer on a window's title bar":
                "Два пальці, курсор на заголовку вікна",
            "Left half": "Ліва половина",
            "Right half": "Права половина",
            "Fill the screen": "На весь екран",
            "Put it back where it was": "Повернути як було",
            "Keyboard shortcuts": "Гарячі клавіші",
            "Hide or reveal the icons": "Сховати або показати значки",
            "Turn automatic hiding on or off": "Увімкнути або вимкнути автоприховування",
            "Nothing is bound until you bind it. They work from any application.":
                "Поки ви нічого не призначили, нічого й не працює. Діють з будь-якої програми.",
            "Click, then press the combination you want.":
                "Натисніть, потім натисніть потрібне поєднання.",
            "Remove this shortcut": "Прибрати це поєднання",
            "Press keys…": "Натисніть клавіші…",
            "Not set": "Не задано",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Потрібно щонайменше два модифікатори, один з них ⌘, ⌥ або ⌃.",
            "Something else already uses that.": "Це поєднання вже зайняте.",
            "Swipe again straight after, and it refines instead of starting over":
                "Проведіть ще раз одразу після, і це уточнить, а не почне заново",
            "Narrower: a third, then two thirds": "Вужче: третина, потім дві третини",
            "Top quarter of that side": "Верхня чверть цього боку",
            "Bottom quarter of that side": "Нижня чверть цього боку",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "Праворуч працює так само. Зачекайте мить, і наступний свайп почне заново.",
            "Send the window to the Dock": "Прибрати вікно в Dock",
            "Pinch in, on the title bar. It never closes anything.":
                "Щипок усередину, на заголовку. Нічого ніколи не закриває.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Список значків за іменами потребує Універсального доступу. Приховування ні.",
            "Cornice already uses that for something else.":
                "Cornice уже використовує це для іншої дії.",
        ],
        .de: [
            "Behaviour": "Verhalten",
            "Appearance": "Erscheinungsbild",
            "Menu Bar": "Menüleiste",
            "Start with the icons hidden": "Mit ausgeblendeten Symbolen starten",
            "Otherwise Cornice comes up the way you left it.":
                "Andernfalls startet Cornice so, wie Sie es verlassen haben.",
            "Hide again when the pointer leaves the menu bar":
                "Wieder ausblenden, wenn der Zeiger die Menüleiste verlässt",
            "After": "Nach",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Eine kurze Pause, damit ein Streifen über den oberen Bildschirmrand nichts wegräumt.",
            "Open at login": "Bei der Anmeldung öffnen",
            "Divider": "Trenner",
            "Thickness": "Stärke",
            "Height": "Höhe",
            "Preview": "Vorschau",
            "Toggle button": "Schaltfläche",
            "Symbol": "Symbol",
            "Chevron": "Pfeilspitze",
            "Chevron, compact": "Pfeilspitze, schmal",
            "Arrow": "Pfeil",
            "Triangle": "Dreieck",
            "Sidebar": "Seitenleiste",
            "Language": "Sprache",
            "Hidden, left of the divider": "Ausgeblendet, links vom Trenner",
            "Keep a second divider, for icons you never want to see":
                "Ein zweiter Trenner, für Symbole, die nie zu sehen sein sollen",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Kostet einen weiteren Platz in der Menüleiste. Mit ⌘ links neben den ersten Trenner ziehen: Was dahinter landet, bleibt verborgen, auch wenn der Rest sichtbar ist.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-Klick auf die Schaltfläche öffnet ihn, oder unten einen Kurzbefehl festlegen.",
            "Open or close the always hidden zone":
                "Den immer verborgenen Bereich öffnen oder schließen",
            "Always hidden, left of the second divider":
                "Immer verborgen, links vom zweiten Trenner",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Nichts. Den zweiten Trenner links neben die Symbole ziehen, die nie zu sehen sein sollen.",
            "Visible, right of the divider": "Sichtbar, rechts vom Trenner",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Nichts. Ziehen Sie den Trenner links neben die Symbole, die verschwinden sollen.",
            "⌘-drag the divider to change what is hidden.":
                "Mit ⌘ den Trenner ziehen, um zu ändern, was ausgeblendet wird.",
            "Refresh": "Aktualisieren",
            "Settings…": "Einstellungen…",
            "Quit Cornice": "Cornice beenden",
            "Version": "Version",
            "Check for Updates": "Nach Updates suchen",
            "Check at launch": "Beim Start nachsehen",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Eine Anfrage an GitHub, ohne Angaben zu Ihnen. Cornice installiert nichts über sich selbst.",
            "You have the latest version.": "Sie haben die neueste Version.",
            "is available": "ist verfügbar",
            "Could not check:": "Prüfung fehlgeschlagen:",
            "off-screen": "außerhalb des Bildschirms",
            "Gestures": "Gesten",
            "Move windows with trackpad gestures": "Fenster mit Trackpad-Gesten bewegen",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Standardmäßig aus. Bedienungshilfen werden erst beim Einschalten angefragt.",
            "Accessibility has not been granted, so gestures are not running.":
                "Bedienungshilfen wurden nicht erteilt, Gesten laufen nicht.",
            "Open Accessibility settings": "Bedienungshilfen öffnen",
            "Two fingers, pointer on a window's title bar":
                "Zwei Finger, Zeiger auf der Titelleiste eines Fensters",
            "Left half": "Linke Hälfte",
            "Right half": "Rechte Hälfte",
            "Fill the screen": "Bildschirm füllen",
            "Put it back where it was": "Zurück an den alten Platz",
            "Keyboard shortcuts": "Tastaturkurzbefehle",
            "Hide or reveal the icons": "Symbole aus- oder einblenden",
            "Turn automatic hiding on or off": "Automatisches Ausblenden ein- oder ausschalten",
            "Nothing is bound until you bind it. They work from any application.":
                "Solange nichts belegt ist, passiert nichts. Sie wirken aus jedem Programm.",
            "Click, then press the combination you want.":
                "Klicken, dann die gewünschte Kombination drücken.",
            "Remove this shortcut": "Kurzbefehl entfernen",
            "Press keys…": "Tasten drücken…",
            "Not set": "Nicht belegt",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Mindestens zwei Sondertasten, davon eine ⌘, ⌥ oder ⌃.",
            "Something else already uses that.": "Etwas anderes belegt das schon.",
            "Swipe again straight after, and it refines instead of starting over":
                "Gleich noch einmal wischen verfeinert es, statt neu anzufangen",
            "Narrower: a third, then two thirds": "Schmaler: ein Drittel, dann zwei Drittel",
            "Top quarter of that side": "Oberes Viertel dieser Seite",
            "Bottom quarter of that side": "Unteres Viertel dieser Seite",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "Nach rechts geht es genauso. Kurz warten, und der nächste Wisch fängt neu an.",
            "Send the window to the Dock": "Das Fenster ins Dock legen",
            "Pinch in, on the title bar. It never closes anything.":
                "Zusammenziehen, auf der Titelleiste. Schließt nie etwas.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Die Symbole namentlich aufzulisten braucht Bedienungshilfen. Ausblenden nicht.",
            "Cornice already uses that for something else.":
                "Cornice benutzt das schon für etwas anderes.",
        ],
        .fr: [
            "Behaviour": "Comportement",
            "Appearance": "Apparence",
            "Menu Bar": "Barre des menus",
            "Start with the icons hidden": "Démarrer avec les icônes masquées",
            "Otherwise Cornice comes up the way you left it.":
                "Sinon Cornice reprend l'état dans lequel vous l'avez laissé.",
            "Hide again when the pointer leaves the menu bar":
                "Masquer à nouveau quand le pointeur quitte la barre des menus",
            "After": "Après",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Une courte pause, pour qu'un passage près du haut de l'écran ne range rien.",
            "Open at login": "Ouvrir à l'ouverture de session",
            "Divider": "Séparateur",
            "Thickness": "Épaisseur",
            "Height": "Hauteur",
            "Preview": "Aperçu",
            "Toggle button": "Bouton",
            "Symbol": "Symbole",
            "Chevron": "Chevron",
            "Chevron, compact": "Chevron, compact",
            "Arrow": "Flèche",
            "Triangle": "Triangle",
            "Sidebar": "Barre latérale",
            "Language": "Langue",
            "Hidden, left of the divider": "Masqués: à gauche du séparateur",
            "Keep a second divider, for icons you never want to see":
                "Un second séparateur, pour les icônes que vous ne voulez jamais voir",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Cela prend une place de plus dans la barre des menus. Faites-le glisser avec ⌘ à gauche du premier séparateur: ce qui se retrouve derrière reste masqué, même quand le reste est affiché.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-cliquez sur le bouton pour l'ouvrir, ou associez un raccourci ci-dessous.",
            "Open or close the always hidden zone": "Ouvrir ou fermer la zone toujours masquée",
            "Always hidden, left of the second divider":
                "Toujours masqués: à gauche du second séparateur",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Rien. Faites glisser le second séparateur à gauche des icônes que vous ne voulez jamais voir.",
            "Visible, right of the divider": "Visibles: à droite du séparateur",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Rien. Faites glisser le séparateur à gauche des icônes à écarter.",
            "⌘-drag the divider to change what is hidden.":
                "Faites glisser le séparateur avec ⌘ pour changer ce qui est masqué.",
            "Refresh": "Actualiser",
            "Settings…": "Réglages…",
            "Quit Cornice": "Quitter Cornice",
            "Version": "Version",
            "Check for Updates": "Rechercher les mises à jour",
            "Check at launch": "Vérifier au démarrage",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Une requête vers GitHub, qui ne transporte rien. Cornice n'installe jamais rien par-dessus lui-même.",
            "You have the latest version.": "Vous avez la dernière version.",
            "is available": "est disponible",
            "Could not check:": "Vérification impossible :",
            "off-screen": "hors écran",
            "Gestures": "Gestes",
            "Move windows with trackpad gestures":
                "Déplacer les fenêtres avec des gestes du trackpad",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Désactivé par défaut. L'accessibilité n'est demandée qu'à l'activation.",
            "Accessibility has not been granted, so gestures are not running.":
                "L'accessibilité n'a pas été accordée, les gestes ne fonctionnent pas.",
            "Open Accessibility settings": "Ouvrir les réglages d'accessibilité",
            "Two fingers, pointer on a window's title bar":
                "Deux doigts, pointeur sur la barre de titre d'une fenêtre",
            "Left half": "Moitié gauche",
            "Right half": "Moitié droite",
            "Fill the screen": "Remplir l'écran",
            "Put it back where it was": "Remettre où c'était",
            "Keyboard shortcuts": "Raccourcis clavier",
            "Hide or reveal the icons": "Masquer ou afficher les icônes",
            "Turn automatic hiding on or off": "Activer ou désactiver le masquage automatique",
            "Nothing is bound until you bind it. They work from any application.":
                "Tant que rien n'est défini, rien ne se passe. Ils marchent depuis n'importe quelle app.",
            "Click, then press the combination you want.":
                "Cliquez, puis appuyez sur la combinaison voulue.",
            "Remove this shortcut": "Retirer ce raccourci",
            "Press keys…": "Appuyez sur les touches…",
            "Not set": "Non défini",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Au moins deux modificateurs, dont ⌘, ⌥ ou ⌃.",
            "Something else already uses that.": "Autre chose l'utilise déjà.",
            "Swipe again straight after, and it refines instead of starting over":
                "Balayez encore juste après, et cela affine au lieu de recommencer",
            "Narrower: a third, then two thirds": "Plus étroit : un tiers, puis deux tiers",
            "Top quarter of that side": "Quart supérieur de ce côté",
            "Bottom quarter of that side": "Quart inférieur de ce côté",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "À droite, c'est pareil. Attendez un instant et le balayage suivant repart de zéro.",
            "Send the window to the Dock": "Envoyer la fenêtre dans le Dock",
            "Pinch in, on the title bar. It never closes anything.":
                "Pincez vers l'intérieur, sur la barre de titre. Ne ferme jamais rien.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Lister les icônes par nom demande l'accessibilité. Les masquer, non.",
            "Cornice already uses that for something else.":
                "Cornice s'en sert déjà pour autre chose.",
        ],
        .es: [
            "Behaviour": "Comportamiento",
            "Appearance": "Apariencia",
            "Menu Bar": "Barra de menús",
            "Start with the icons hidden": "Empezar con los iconos ocultos",
            "Otherwise Cornice comes up the way you left it.":
                "De lo contrario, Cornice se abrirá tal como lo dejó.",
            "Hide again when the pointer leaves the menu bar":
                "Ocultar de nuevo cuando el puntero sale de la barra de menús",
            "After": "Después de",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Una breve pausa, para que rozar el borde superior no lo oculte todo.",
            "Open at login": "Abrir al iniciar sesión",
            "Divider": "Separador",
            "Thickness": "Grosor",
            "Height": "Altura",
            "Preview": "Vista previa",
            "Toggle button": "Botón",
            "Symbol": "Símbolo",
            "Chevron": "Chevrón",
            "Chevron, compact": "Chevrón, compacto",
            "Arrow": "Flecha",
            "Triangle": "Triángulo",
            "Sidebar": "Barra lateral",
            "Language": "Idioma",
            "Hidden, left of the divider": "Ocultos, a la izquierda del separador",
            "Keep a second divider, for icons you never want to see":
                "Un segundo separador, para los iconos que nunca quiere ver",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Ocupa un sitio más en la barra de menús. Arrástrelo con ⌘ a la izquierda del primer separador: lo que quede detrás sigue oculto incluso cuando lo demás está visible.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-clic en el botón para abrirla, o asigne un atajo abajo.",
            "Open or close the always hidden zone": "Abrir o cerrar la zona siempre oculta",
            "Always hidden, left of the second divider":
                "Siempre ocultos, a la izquierda del segundo separador",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Nada. Arrastre el segundo separador a la izquierda de los iconos que nunca quiere ver.",
            "Visible, right of the divider": "Visibles, a la derecha del separador",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Nada. Arrastre el separador a la izquierda de los iconos que quiera apartar.",
            "⌘-drag the divider to change what is hidden.":
                "Arrastre el separador con ⌘ para cambiar lo que se oculta.",
            "Refresh": "Actualizar",
            "Settings…": "Ajustes…",
            "Quit Cornice": "Salir de Cornice",
            "Version": "Versión",
            "Check for Updates": "Buscar actualizaciones",
            "Check at launch": "Comprobar al iniciar",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Una petición a GitHub, sin datos suyos. Cornice nunca instala nada sobre sí mismo.",
            "You have the latest version.": "Tiene la última versión.",
            "is available": "está disponible",
            "Could not check:": "No se pudo comprobar:",
            "off-screen": "fuera de pantalla",
            "Gestures": "Gestos",
            "Move windows with trackpad gestures": "Mover ventanas con gestos del trackpad",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Desactivado por omisión. La accesibilidad se pide solo al activarlo.",
            "Accessibility has not been granted, so gestures are not running.":
                "No se ha concedido la accesibilidad, los gestos no funcionan.",
            "Open Accessibility settings": "Abrir ajustes de accesibilidad",
            "Two fingers, pointer on a window's title bar":
                "Dos dedos, puntero sobre la barra de título de una ventana",
            "Left half": "Mitad izquierda",
            "Right half": "Mitad derecha",
            "Fill the screen": "Llenar la pantalla",
            "Put it back where it was": "Devolver donde estaba",
            "Keyboard shortcuts": "Atajos de teclado",
            "Hide or reveal the icons": "Ocultar o mostrar los iconos",
            "Turn automatic hiding on or off": "Activar o desactivar la ocultación automática",
            "Nothing is bound until you bind it. They work from any application.":
                "Mientras no asignes nada, no pasa nada. Funcionan desde cualquier app.",
            "Click, then press the combination you want.":
                "Haz clic y pulsa la combinación que quieras.",
            "Remove this shortcut": "Quitar este atajo",
            "Press keys…": "Pulsa las teclas…",
            "Not set": "Sin asignar",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Al menos dos modificadores, uno de ellos ⌘, ⌥ o ⌃.",
            "Something else already uses that.": "Ya lo usa otra cosa.",
            "Swipe again straight after, and it refines instead of starting over":
                "Desliza otra vez justo después y afina en vez de empezar de nuevo",
            "Narrower: a third, then two thirds": "Más estrecho: un tercio, luego dos tercios",
            "Top quarter of that side": "Cuarto superior de ese lado",
            "Bottom quarter of that side": "Cuarto inferior de ese lado",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "A la derecha funciona igual. Espera un momento y el siguiente deslizamiento empieza de cero.",
            "Send the window to the Dock": "Mandar la ventana al Dock",
            "Pinch in, on the title bar. It never closes anything.":
                "Pellizca hacia dentro, en la barra de título. Nunca cierra nada.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Listar los iconos por nombre necesita accesibilidad. Ocultarlos no.",
            "Cornice already uses that for something else.":
                "Cornice ya lo usa para otra cosa.",
        ],
        .pt: [
            "Behaviour": "Comportamento",
            "Appearance": "Aparência",
            "Menu Bar": "Barra de menus",
            "Start with the icons hidden": "Começar com os ícones ocultos",
            "Otherwise Cornice comes up the way you left it.":
                "Caso contrário, o Cornice abre como você o deixou.",
            "Hide again when the pointer leaves the menu bar":
                "Ocultar de novo quando o ponteiro sai da barra de menus",
            "After": "Após",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Uma pausa curta, para que roçar o topo do ecrã não arrume nada.",
            "Open at login": "Abrir ao iniciar sessão",
            "Divider": "Divisor",
            "Thickness": "Espessura",
            "Height": "Altura",
            "Preview": "Pré-visualização",
            "Toggle button": "Botão",
            "Symbol": "Símbolo",
            "Chevron": "Divisa",
            "Chevron, compact": "Divisa, compacta",
            "Arrow": "Seta",
            "Triangle": "Triângulo",
            "Sidebar": "Barra lateral",
            "Language": "Idioma",
            "Hidden, left of the divider": "Ocultos: à esquerda do divisor",
            "Keep a second divider, for icons you never want to see":
                "Um segundo divisor, para os ícones que nunca quer ver",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Ocupa mais um lugar na barra de menus. Arraste-o com ⌘ para a esquerda do primeiro divisor: o que ficar atrás continua oculto mesmo quando o resto está visível.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-clique no botão para a abrir, ou defina um atalho abaixo.",
            "Open or close the always hidden zone": "Abrir ou fechar a zona sempre oculta",
            "Always hidden, left of the second divider":
                "Sempre ocultos: à esquerda do segundo divisor",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Nada. Arraste o segundo divisor para a esquerda dos ícones que nunca quer ver.",
            "Visible, right of the divider": "Visíveis: à direita do divisor",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Nada. Arraste o divisor para a esquerda dos ícones que quer afastar.",
            "⌘-drag the divider to change what is hidden.":
                "Arraste o divisor com ⌘ para mudar o que fica oculto.",
            "Refresh": "Atualizar",
            "Settings…": "Ajustes…",
            "Quit Cornice": "Encerrar o Cornice",
            "Version": "Versão",
            "Check for Updates": "Procurar atualizações",
            "Check at launch": "Verificar ao iniciar",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Um pedido ao GitHub, sem dados seus. O Cornice nunca instala nada por cima de si próprio.",
            "You have the latest version.": "Você tem a versão mais recente.",
            "is available": "está disponível",
            "Could not check:": "Não foi possível verificar:",
            "off-screen": "fora da tela",
            "Gestures": "Gestos",
            "Move windows with trackpad gestures": "Mover janelas com gestos do trackpad",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Desligado por omissão. A acessibilidade só é pedida ao ligar isto.",
            "Accessibility has not been granted, so gestures are not running.":
                "A acessibilidade não foi concedida, os gestos não funcionam.",
            "Open Accessibility settings": "Abrir definições de acessibilidade",
            "Two fingers, pointer on a window's title bar":
                "Dois dedos, ponteiro sobre a barra de título de uma janela",
            "Left half": "Metade esquerda",
            "Right half": "Metade direita",
            "Fill the screen": "Preencher o ecrã",
            "Put it back where it was": "Repor onde estava",
            "Keyboard shortcuts": "Atalhos de teclado",
            "Hide or reveal the icons": "Ocultar ou mostrar os ícones",
            "Turn automatic hiding on or off": "Ligar ou desligar a ocultação automática",
            "Nothing is bound until you bind it. They work from any application.":
                "Enquanto nada estiver definido, nada acontece. Funcionam a partir de qualquer app.",
            "Click, then press the combination you want.":
                "Clique e depois prima a combinação que quiser.",
            "Remove this shortcut": "Remover este atalho",
            "Press keys…": "Prima as teclas…",
            "Not set": "Por definir",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Pelo menos dois modificadores, um deles ⌘, ⌥ ou ⌃.",
            "Something else already uses that.": "Outra coisa já usa isso.",
            "Swipe again straight after, and it refines instead of starting over":
                "Deslize outra vez logo a seguir e afina em vez de recomeçar",
            "Narrower: a third, then two thirds": "Mais estreito: um terço, depois dois terços",
            "Top quarter of that side": "Quarto superior desse lado",
            "Bottom quarter of that side": "Quarto inferior desse lado",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "Para a direita funciona igual. Espere um momento e o próximo deslize recomeça.",
            "Send the window to the Dock": "Mandar a janela para a Dock",
            "Pinch in, on the title bar. It never closes anything.":
                "Aperte para dentro, na barra de título. Nunca fecha nada.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Listar os ícones pelo nome precisa de acessibilidade. Ocultá-los não.",
            "Cornice already uses that for something else.":
                "O Cornice já usa isso para outra coisa.",
        ],
        .it: [
            "Behaviour": "Comportamento",
            "Appearance": "Aspetto",
            "Menu Bar": "Barra dei menu",
            "Start with the icons hidden": "Avvia con le icone nascoste",
            "Otherwise Cornice comes up the way you left it.":
                "Altrimenti Cornice si apre come l'hai lasciato.",
            "Hide again when the pointer leaves the menu bar":
                "Nascondi di nuovo quando il puntatore lascia la barra dei menu",
            "After": "Dopo",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Una breve pausa, così sfiorare il bordo alto dello schermo non nasconde nulla.",
            "Open at login": "Apri all'accesso",
            "Divider": "Divisore",
            "Thickness": "Spessore",
            "Height": "Altezza",
            "Preview": "Anteprima",
            "Toggle button": "Pulsante",
            "Symbol": "Simbolo",
            "Chevron": "Chevron",
            "Chevron, compact": "Chevron, compatto",
            "Arrow": "Freccia",
            "Triangle": "Triangolo",
            "Sidebar": "Barra laterale",
            "Language": "Lingua",
            "Hidden, left of the divider": "Nascosti, a sinistra del divisore",
            "Keep a second divider, for icons you never want to see":
                "Un secondo divisore, per le icone che non vuoi mai vedere",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Occupa un posto in più nella barra dei menu. Trascinalo con ⌘ a sinistra del primo divisore: quello che resta dietro rimane nascosto anche quando il resto è visibile.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-clic sul pulsante per aprirla, oppure assegna una scorciatoia qui sotto.",
            "Open or close the always hidden zone": "Aprire o chiudere la zona sempre nascosta",
            "Always hidden, left of the second divider":
                "Sempre nascosti, a sinistra del secondo divisore",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Niente. Trascina il secondo divisore a sinistra delle icone che non vuoi mai vedere.",
            "Visible, right of the divider": "Visibili, a destra del divisore",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Niente. Trascina il divisore a sinistra delle icone da togliere di mezzo.",
            "⌘-drag the divider to change what is hidden.":
                "Trascina il divisore con ⌘ per cambiare ciò che viene nascosto.",
            "Refresh": "Aggiorna",
            "Settings…": "Impostazioni…",
            "Quit Cornice": "Esci da Cornice",
            "Version": "Versione",
            "Check for Updates": "Cerca aggiornamenti",
            "Check at launch": "Controlla all'avvio",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Una richiesta a GitHub, che non porta nulla con sé. Cornice non installa mai niente sopra se stesso.",
            "You have the latest version.": "Hai la versione più recente.",
            "is available": "è disponibile",
            "Could not check:": "Impossibile verificare:",
            "off-screen": "fuori schermo",
            "Gestures": "Gesti",
            "Move windows with trackpad gestures":
                "Spostare le finestre con i gesti del trackpad",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Disattivato di serie. L'accessibilità viene chiesta solo all'attivazione.",
            "Accessibility has not been granted, so gestures are not running.":
                "L'accessibilità non è stata concessa, i gesti non funzionano.",
            "Open Accessibility settings": "Apri impostazioni di accessibilità",
            "Two fingers, pointer on a window's title bar":
                "Due dita, puntatore sulla barra del titolo di una finestra",
            "Left half": "Metà sinistra",
            "Right half": "Metà destra",
            "Fill the screen": "Riempi lo schermo",
            "Put it back where it was": "Rimetti dov'era",
            "Keyboard shortcuts": "Scorciatoie da tastiera",
            "Hide or reveal the icons": "Nascondi o mostra le icone",
            "Turn automatic hiding on or off": "Attiva o disattiva la chiusura automatica",
            "Nothing is bound until you bind it. They work from any application.":
                "Finché non assegni nulla, non succede nulla. Funzionano da qualsiasi app.",
            "Click, then press the combination you want.":
                "Fai clic, poi premi la combinazione che vuoi.",
            "Remove this shortcut": "Togli questa scorciatoia",
            "Press keys…": "Premi i tasti…",
            "Not set": "Non assegnata",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Almeno due modificatori, uno dei quali ⌘, ⌥ o ⌃.",
            "Something else already uses that.": "Qualcos'altro la usa già.",
            "Swipe again straight after, and it refines instead of starting over":
                "Scorri di nuovo subito dopo e affina invece di ricominciare",
            "Narrower: a third, then two thirds": "Più stretto: un terzo, poi due terzi",
            "Top quarter of that side": "Quarto in alto di quel lato",
            "Bottom quarter of that side": "Quarto in basso di quel lato",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "A destra funziona uguale. Aspetta un attimo e il prossimo gesto ricomincia.",
            "Send the window to the Dock": "Manda la finestra nel Dock",
            "Pinch in, on the title bar. It never closes anything.":
                "Pizzica verso l'interno, sulla barra del titolo. Non chiude mai nulla.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Elencare le icone per nome richiede l'accessibilità. Nasconderle no.",
            "Cornice already uses that for something else.":
                "Cornice lo usa già per qualcos'altro.",
        ],
        .nl: [
            "Behaviour": "Gedrag",
            "Appearance": "Weergave",
            "Menu Bar": "Menubalk",
            "Start with the icons hidden": "Starten met verborgen symbolen",
            "Otherwise Cornice comes up the way you left it.":
                "Anders start Cornice zoals u het hebt achtergelaten.",
            "Hide again when the pointer leaves the menu bar":
                "Weer verbergen als de aanwijzer de menubalk verlaat",
            "After": "Na",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Een korte pauze, zodat langs de bovenrand strijken niets opbergt.",
            "Open at login": "Openen bij inloggen",
            "Divider": "Scheiding",
            "Thickness": "Dikte",
            "Height": "Hoogte",
            "Preview": "Voorbeeld",
            "Toggle button": "Knop",
            "Symbol": "Symbool",
            "Chevron": "Pijlpunt",
            "Chevron, compact": "Pijlpunt, smal",
            "Arrow": "Pijl",
            "Triangle": "Driehoek",
            "Sidebar": "Navigatiekolom",
            "Language": "Taal",
            "Hidden, left of the divider": "Verborgen, links van de scheiding",
            "Keep a second divider, for icons you never want to see":
                "Een tweede scheiding, voor pictogrammen die je nooit wilt zien",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Kost een plek extra in de menubalk. Sleep hem met ⌘ links van de eerste scheiding: wat erachter belandt blijft verborgen, ook als de rest zichtbaar is.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-klik op de knop om hem te openen, of stel hieronder een sneltoets in.",
            "Open or close the always hidden zone":
                "De altijd verborgen zone openen of sluiten",
            "Always hidden, left of the second divider":
                "Altijd verborgen, links van de tweede scheiding",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Niets. Sleep de tweede scheiding links van de pictogrammen die je nooit wilt zien.",
            "Visible, right of the divider": "Zichtbaar, rechts van de scheiding",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Niets. Sleep de scheiding links van de symbolen die u weg wilt hebben.",
            "⌘-drag the divider to change what is hidden.":
                "Sleep de scheiding met ⌘ om te wijzigen wat verborgen wordt.",
            "Refresh": "Ververs",
            "Settings…": "Instellingen…",
            "Quit Cornice": "Cornice stoppen",
            "Version": "Versie",
            "Check for Updates": "Zoek naar updates",
            "Check at launch": "Controleren bij starten",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Eén verzoek aan GitHub, zonder gegevens over jou. Cornice installeert nooit iets over zichzelf heen.",
            "You have the latest version.": "U hebt de nieuwste versie.",
            "is available": "is beschikbaar",
            "Could not check:": "Controleren mislukt:",
            "off-screen": "buiten beeld",
            "Gestures": "Bewegingen",
            "Move windows with trackpad gestures":
                "Vensters verplaatsen met trackpadbewegingen",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Standaard uit. Toegankelijkheid wordt pas gevraagd als je dit aanzet.",
            "Accessibility has not been granted, so gestures are not running.":
                "Toegankelijkheid is niet verleend, bewegingen werken niet.",
            "Open Accessibility settings": "Open toegankelijkheidsinstellingen",
            "Two fingers, pointer on a window's title bar":
                "Twee vingers, aanwijzer op de titelbalk van een venster",
            "Left half": "Linkerhelft",
            "Right half": "Rechterhelft",
            "Fill the screen": "Scherm vullen",
            "Put it back where it was": "Terug waar het stond",
            "Keyboard shortcuts": "Toetscombinaties",
            "Hide or reveal the icons": "Symbolen verbergen of tonen",
            "Turn automatic hiding on or off": "Automatisch verbergen aan- of uitzetten",
            "Nothing is bound until you bind it. They work from any application.":
                "Zolang je niets instelt, gebeurt er niets. Ze werken vanuit elk programma.",
            "Click, then press the combination you want.":
                "Klik en druk daarna op de gewenste combinatie.",
            "Remove this shortcut": "Deze combinatie verwijderen",
            "Press keys…": "Druk op toetsen…",
            "Not set": "Niet ingesteld",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Minstens twee modificatietoetsen, waarvan één ⌘, ⌥ of ⌃.",
            "Something else already uses that.": "Iets anders gebruikt dat al.",
            "Swipe again straight after, and it refines instead of starting over":
                "Veeg meteen daarna nog eens, dan verfijnt het in plaats van opnieuw te beginnen",
            "Narrower: a third, then two thirds": "Smaller: een derde, dan twee derde",
            "Top quarter of that side": "Bovenste kwart van die kant",
            "Bottom quarter of that side": "Onderste kwart van die kant",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "Naar rechts werkt hetzelfde. Wacht even en de volgende veeg begint opnieuw.",
            "Send the window to the Dock": "Het venster naar het Dock sturen",
            "Pinch in, on the title bar. It never closes anything.":
                "Knijp naar binnen, op de titelbalk. Sluit nooit iets.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Symbolen op naam tonen vraagt toegankelijkheid. Verbergen niet.",
            "Cornice already uses that for something else.":
                "Cornice gebruikt dat al voor iets anders.",
        ],
        .pl: [
            "Behaviour": "Zachowanie",
            "Appearance": "Wygląd",
            "Menu Bar": "Pasek menu",
            "Start with the icons hidden": "Uruchamiaj z ukrytymi ikonami",
            "Otherwise Cornice comes up the way you left it.":
                "W przeciwnym razie Cornice uruchomi się tak, jak go zostawiono.",
            "Hide again when the pointer leaves the menu bar":
                "Ukryj ponownie, gdy wskaźnik opuści pasek menu",
            "After": "Po",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Krótka pauza, żeby muśnięcie górnej krawędzi ekranu niczego nie chowało.",
            "Open at login": "Otwieraj przy logowaniu",
            "Divider": "Separator",
            "Thickness": "Grubość",
            "Height": "Wysokość",
            "Preview": "Podgląd",
            "Toggle button": "Przycisk",
            "Symbol": "Symbol",
            "Chevron": "Strzałka kątowa",
            "Chevron, compact": "Strzałka kątowa, wąska",
            "Arrow": "Strzałka",
            "Triangle": "Trójkąt",
            "Sidebar": "Panel boczny",
            "Language": "Język",
            "Hidden, left of the divider": "Ukryte, na lewo od separatora",
            "Keep a second divider, for icons you never want to see":
                "Drugi separator, dla ikon, których nigdy nie chcesz widzieć",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Zajmuje jeszcze jedno miejsce na pasku menu. Przeciągnij go z ⌘ na lewo od pierwszego separatora: to, co znajdzie się za nim, pozostaje ukryte nawet wtedy, gdy reszta jest widoczna.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-kliknięcie przycisku otwiera strefę, albo przypisz skrót poniżej.",
            "Open or close the always hidden zone": "Otwórz lub zamknij zawsze ukrytą strefę",
            "Always hidden, left of the second divider":
                "Zawsze ukryte, na lewo od drugiego separatora",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Nic. Przeciągnij drugi separator na lewo od ikon, których nigdy nie chcesz widzieć.",
            "Visible, right of the divider": "Widoczne, na prawo od separatora",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Pusto. Przeciągnij separator na lewo od ikon, które chcesz schować.",
            "⌘-drag the divider to change what is hidden.":
                "Przeciągnij separator z ⌘, aby zmienić, co jest ukrywane.",
            "Refresh": "Odśwież",
            "Settings…": "Ustawienia…",
            "Quit Cornice": "Zakończ Cornice",
            "Version": "Wersja",
            "Check for Updates": "Sprawdź aktualizacje",
            "Check at launch": "Sprawdzaj przy starcie",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Jedno zapytanie do GitHuba, bez żadnych danych o tobie. Cornice nigdy nie instaluje niczego na sobie.",
            "You have the latest version.": "Masz najnowszą wersję.",
            "is available": "jest dostępna",
            "Could not check:": "Nie udało się sprawdzić:",
            "off-screen": "poza ekranem",
            "Gestures": "Gesty",
            "Move windows with trackpad gestures": "Przesuwaj okna gestami gładzika",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Domyślnie wyłączone. Dostępność jest proszona dopiero przy włączeniu.",
            "Accessibility has not been granted, so gestures are not running.":
                "Dostępność nie została przyznana, gesty nie działają.",
            "Open Accessibility settings": "Otwórz ustawienia dostępności",
            "Two fingers, pointer on a window's title bar":
                "Dwa palce, wskaźnik na pasku tytułu okna",
            "Left half": "Lewa połowa",
            "Right half": "Prawa połowa",
            "Fill the screen": "Wypełnij ekran",
            "Put it back where it was": "Przywróć na miejsce",
            "Keyboard shortcuts": "Skróty klawiszowe",
            "Hide or reveal the icons": "Ukryj lub pokaż ikony",
            "Turn automatic hiding on or off": "Włącz lub wyłącz automatyczne ukrywanie",
            "Nothing is bound until you bind it. They work from any application.":
                "Dopóki nic nie przypiszesz, nic się nie dzieje. Działają z każdego programu.",
            "Click, then press the combination you want.":
                "Kliknij, potem naciśnij wybraną kombinację.",
            "Remove this shortcut": "Usuń ten skrót",
            "Press keys…": "Naciśnij klawisze…",
            "Not set": "Nieprzypisane",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Co najmniej dwa modyfikatory, jeden z nich ⌘, ⌥ lub ⌃.",
            "Something else already uses that.": "Coś innego już tego używa.",
            "Swipe again straight after, and it refines instead of starting over":
                "Przesuń jeszcze raz zaraz potem, a doprecyzuje zamiast zaczynać od nowa",
            "Narrower: a third, then two thirds": "Węziej: jedna trzecia, potem dwie trzecie",
            "Top quarter of that side": "Górna ćwiartka tej strony",
            "Bottom quarter of that side": "Dolna ćwiartka tej strony",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "W prawo działa tak samo. Odczekaj chwilę, a następny gest zacznie od nowa.",
            "Send the window to the Dock": "Schowaj okno do Docka",
            "Pinch in, on the title bar. It never closes anything.":
                "Uszczypnij do środka, na pasku tytułu. Nigdy nic nie zamyka.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Wypisanie ikon po nazwie wymaga dostępności. Ukrywanie nie.",
            "Cornice already uses that for something else.":
                "Cornice już tego używa do czegoś innego.",
        ],
        .cs: [
            "Behaviour": "Chování",
            "Appearance": "Vzhled",
            "Menu Bar": "Řádek nabídek",
            "Start with the icons hidden": "Spouštět se skrytými ikonami",
            "Otherwise Cornice comes up the way you left it.":
                "Jinak se Cornice spustí tak, jak jste jej zanechali.",
            "Hide again when the pointer leaves the menu bar":
                "Znovu skrýt, když ukazatel opustí řádek nabídek",
            "After": "Po",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Krátká pauza, aby zavadění o horní okraj obrazovky nic neuklidilo.",
            "Open at login": "Otevírat při přihlášení",
            "Divider": "Oddělovač",
            "Thickness": "Tloušťka",
            "Height": "Výška",
            "Preview": "Náhled",
            "Toggle button": "Tlačítko",
            "Symbol": "Symbol",
            "Chevron": "Šipka",
            "Chevron, compact": "Šipka, úzká",
            "Arrow": "Šipka",
            "Triangle": "Trojúhelník",
            "Sidebar": "Postranní panel",
            "Language": "Jazyk",
            "Hidden, left of the divider": "Skryté, vlevo od oddělovače",
            "Keep a second divider, for icons you never want to see":
                "Druhý oddělovač, pro ikony, které nikdy nechcete vidět",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Zabere na liště menu ještě jedno místo. Přetáhněte ho s ⌘ nalevo od prvního oddělovače: co skončí za ním, zůstane skryté i když je ostatní vidět.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-klik na tlačítko ji otevře, nebo si níže přiřaďte zkratku.",
            "Open or close the always hidden zone": "Otevřít nebo zavřít vždy skrytou zónu",
            "Always hidden, left of the second divider":
                "Vždy skryté, vlevo od druhého oddělovače",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Nic. Přetáhněte druhý oddělovač nalevo od ikon, které nikdy nechcete vidět.",
            "Visible, right of the divider": "Viditelné, vpravo od oddělovače",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Nic. Přetáhněte oddělovač vlevo od ikon, které chcete uklidit.",
            "⌘-drag the divider to change what is hidden.":
                "Přetažením oddělovače s ⌘ změníte, co se skrývá.",
            "Refresh": "Obnovit",
            "Settings…": "Nastavení…",
            "Quit Cornice": "Ukončit Cornice",
            "Version": "Verze",
            "Check for Updates": "Zkontrolovat aktualizace",
            "Check at launch": "Zkontrolovat při spuštění",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "Jeden dotaz na GitHub, bez jakýchkoli údajů o vás. Cornice na sebe nikdy nic neinstaluje.",
            "You have the latest version.": "Máte nejnovější verzi.",
            "is available": "je k dispozici",
            "Could not check:": "Kontrola se nezdařila:",
            "off-screen": "mimo obrazovku",
            "Gestures": "Gesta",
            "Move windows with trackpad gestures": "Posouvat okna gesty trackpadu",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Ve výchozím stavu vypnuto. Zpřístupnění se vyžádá až při zapnutí.",
            "Accessibility has not been granted, so gestures are not running.":
                "Zpřístupnění nebylo uděleno, gesta nefungují.",
            "Open Accessibility settings": "Otevřít nastavení zpřístupnění",
            "Two fingers, pointer on a window's title bar":
                "Dva prsty, ukazatel na titulku okna",
            "Left half": "Levá polovina",
            "Right half": "Pravá polovina",
            "Fill the screen": "Vyplnit obrazovku",
            "Put it back where it was": "Vrátit tam, kde bylo",
            "Keyboard shortcuts": "Klávesové zkratky",
            "Hide or reveal the icons": "Skrýt nebo zobrazit ikony",
            "Turn automatic hiding on or off": "Zapnout nebo vypnout automatické skrývání",
            "Nothing is bound until you bind it. They work from any application.":
                "Dokud nic nepřiřadíte, nic se neděje. Fungují z jakékoli aplikace.",
            "Click, then press the combination you want.":
                "Klepněte a pak stiskněte požadovanou kombinaci.",
            "Remove this shortcut": "Odebrat tuto zkratku",
            "Press keys…": "Stiskněte klávesy…",
            "Not set": "Nepřiřazeno",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Nejméně dva modifikátory, jeden z nich ⌘, ⌥ nebo ⌃.",
            "Something else already uses that.": "Používá to už něco jiného.",
            "Swipe again straight after, and it refines instead of starting over":
                "Přejeďte hned znovu a upřesní to místo toho, aby začalo znovu",
            "Narrower: a third, then two thirds": "Užší: třetina, potom dvě třetiny",
            "Top quarter of that side": "Horní čtvrtina té strany",
            "Bottom quarter of that side": "Dolní čtvrtina té strany",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "Doprava to funguje stejně. Chvíli počkejte a další přejetí začne od začátku.",
            "Send the window to the Dock": "Poslat okno do Docku",
            "Pinch in, on the title bar. It never closes anything.":
                "Stáhněte prsty k sobě, na titulku okna. Nikdy nic nezavře.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Výpis ikon podle jména vyžaduje zpřístupnění. Skrývání ne.",
            "Cornice already uses that for something else.":
                "Cornice to už používá pro něco jiného.",
        ],
        .sv: [
            "Behaviour": "Beteende",
            "Appearance": "Utseende",
            "Menu Bar": "Menyrad",
            "Start with the icons hidden": "Starta med symbolerna dolda",
            "Otherwise Cornice comes up the way you left it.":
                "Annars startar Cornice som du lämnade det.",
            "Hide again when the pointer leaves the menu bar":
                "Dölj igen när pekaren lämnar menyraden",
            "After": "Efter",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "En kort paus, så att en sväng förbi skärmens överkant inte lägger undan något.",
            "Open at login": "Öppna vid inloggning",
            "Divider": "Avdelare",
            "Thickness": "Tjocklek",
            "Height": "Höjd",
            "Preview": "Förhandsvisning",
            "Toggle button": "Knapp",
            "Symbol": "Symbol",
            "Chevron": "Vinkelpil",
            "Chevron, compact": "Vinkelpil, smal",
            "Arrow": "Pil",
            "Triangle": "Triangel",
            "Sidebar": "Sidofält",
            "Language": "Språk",
            "Hidden, left of the divider": "Dolda, till vänster om avdelaren",
            "Keep a second divider, for icons you never want to see":
                "En andra avdelare, för ikoner du aldrig vill se",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Tar en plats till i menyraden. Dra den med ⌘ till vänster om den första avdelaren: det som hamnar bakom förblir dolt även när resten visas.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-klicka på knappen för att öppna den, eller ange ett kortkommando nedan.",
            "Open or close the always hidden zone": "Öppna eller stäng den alltid dolda zonen",
            "Always hidden, left of the second divider":
                "Alltid dolda, till vänster om den andra avdelaren",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Inget. Dra den andra avdelaren till vänster om ikonerna du aldrig vill se.",
            "Visible, right of the divider": "Synliga, till höger om avdelaren",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Inget. Dra avdelaren till vänster om symbolerna du vill få undan.",
            "⌘-drag the divider to change what is hidden.":
                "Dra avdelaren med ⌘ för att ändra vad som döljs.",
            "Refresh": "Uppdatera",
            "Settings…": "Inställningar…",
            "Quit Cornice": "Avsluta Cornice",
            "Version": "Version",
            "Check for Updates": "Sök efter uppdateringar",
            "Check at launch": "Kontrollera vid start",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "En förfrågan till GitHub, utan några uppgifter om dig. Cornice installerar aldrig något över sig själv.",
            "You have the latest version.": "Du har den senaste versionen.",
            "is available": "är tillgänglig",
            "Could not check:": "Kunde inte söka:",
            "off-screen": "utanför skärmen",
            "Gestures": "Gester",
            "Move windows with trackpad gestures": "Flytta fönster med styrplattegester",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Av som standard. Hjälpmedel efterfrågas först när du slår på det här.",
            "Accessibility has not been granted, so gestures are not running.":
                "Hjälpmedel har inte beviljats, gesterna körs inte.",
            "Open Accessibility settings": "Öppna hjälpmedelsinställningar",
            "Two fingers, pointer on a window's title bar":
                "Två fingrar, pekaren på ett fönsters namnlist",
            "Left half": "Vänster halva",
            "Right half": "Höger halva",
            "Fill the screen": "Fyll skärmen",
            "Put it back where it was": "Lägg tillbaka där det var",
            "Keyboard shortcuts": "Kortkommandon",
            "Hide or reveal the icons": "Dölj eller visa symbolerna",
            "Turn automatic hiding on or off": "Slå på eller av automatisk döljning",
            "Nothing is bound until you bind it. They work from any application.":
                "Så länge inget är angivet händer inget. De fungerar från vilket program som helst.",
            "Click, then press the combination you want.":
                "Klicka och tryck sedan på kombinationen du vill ha.",
            "Remove this shortcut": "Ta bort det här kortkommandot",
            "Press keys…": "Tryck på tangenter…",
            "Not set": "Inte angivet",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "Minst två modifierare, varav en ⌘, ⌥ eller ⌃.",
            "Something else already uses that.": "Något annat använder redan det.",
            "Swipe again straight after, and it refines instead of starting over":
                "Svep igen direkt efter, så förfinar det i stället för att börja om",
            "Narrower: a third, then two thirds":
                "Smalare: en tredjedel, sedan två tredjedelar",
            "Top quarter of that side": "Övre fjärdedelen på den sidan",
            "Bottom quarter of that side": "Nedre fjärdedelen på den sidan",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "Åt höger fungerar likadant. Vänta ett ögonblick, så börjar nästa svep om.",
            "Send the window to the Dock": "Lägg fönstret i Dock",
            "Pinch in, on the title bar. It never closes anything.":
                "Nyp ihop, på namnlisten. Stänger aldrig något.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Att lista symbolerna vid namn kräver hjälpmedel. Att dölja dem gör det inte.",
            "Cornice already uses that for something else.":
                "Cornice använder redan det till något annat.",
        ],
        .tr: [
            "Behaviour": "Davranış",
            "Appearance": "Görünüm",
            "Menu Bar": "Menü çubuğu",
            "Start with the icons hidden": "Simgeler gizli olarak başla",
            "Otherwise Cornice comes up the way you left it.":
                "Aksi hâlde Cornice bıraktığınız durumda açılır.",
            "Hide again when the pointer leaves the menu bar":
                "İmleç menü çubuğundan ayrılınca yeniden gizle",
            "After": "Şu süreden sonra",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "Kısa bir bekleme, ekranın üstünden geçmek hiçbir şeyi kaldırmasın diye.",
            "Open at login": "Oturum açıldığında aç",
            "Divider": "Ayırıcı",
            "Thickness": "Kalınlık",
            "Height": "Yükseklik",
            "Preview": "Önizleme",
            "Toggle button": "Düğme",
            "Symbol": "Simge",
            "Chevron": "Ok ucu",
            "Chevron, compact": "Ok ucu, dar",
            "Arrow": "Ok",
            "Triangle": "Üçgen",
            "Sidebar": "Yan çubuk",
            "Language": "Dil",
            "Hidden, left of the divider": "Gizli, ayırıcının solunda",
            "Keep a second divider, for icons you never want to see":
                "İkinci bir ayırıcı, hiç görmek istemediğiniz simgeler için",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "Menü çubuğunda bir yer daha kaplar. ⌘ ile birinci ayırıcının soluna sürükleyin: arkasında kalan her şey, geri kalanı görünürken bile gizli kalır.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "Açmak için düğmeye ⌥-tıklayın veya aşağıdan bir kısayol atayın.",
            "Open or close the always hidden zone": "Her zaman gizli bölgeyi aç veya kapat",
            "Always hidden, left of the second divider":
                "Her zaman gizli, ikinci ayırıcının solunda",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "Yok. İkinci ayırıcıyı hiç görmek istemediğiniz simgelerin soluna sürükleyin.",
            "Visible, right of the divider": "Görünür, ayırıcının sağında",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "Boş. Ayırıcıyı, kaldırmak istediğiniz simgelerin soluna sürükleyin.",
            "⌘-drag the divider to change what is hidden.":
                "Nelerin gizleneceğini değiştirmek için ayırıcıyı ⌘ ile sürükleyin.",
            "Refresh": "Yenile",
            "Settings…": "Ayarlar…",
            "Quit Cornice": "Cornice'ten çık",
            "Version": "Sürüm",
            "Check for Updates": "Güncellemeleri denetle",
            "Check at launch": "Açılışta denetle",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "GitHub'a tek bir istek, hakkınızda hiçbir bilgi taşımadan. Cornice kendi üzerine hiçbir şey kurmaz.",
            "You have the latest version.": "En son sürümü kullanıyorsunuz.",
            "is available": "kullanılabilir",
            "Could not check:": "Denetlenemedi:",
            "off-screen": "ekran dışında",
            "Gestures": "Hareketler",
            "Move windows with trackpad gestures":
                "Pencereleri izleme dörtgeni hareketleriyle taşı",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "Öntanımlı olarak kapalı. Erişilebilirlik yalnızca bunu açtığınızda istenir.",
            "Accessibility has not been granted, so gestures are not running.":
                "Erişilebilirlik verilmedi, hareketler çalışmıyor.",
            "Open Accessibility settings": "Erişilebilirlik ayarlarını aç",
            "Two fingers, pointer on a window's title bar":
                "İki parmak, imleç bir pencerenin başlık çubuğunda",
            "Left half": "Sol yarı",
            "Right half": "Sağ yarı",
            "Fill the screen": "Ekranı doldur",
            "Put it back where it was": "Eski yerine koy",
            "Keyboard shortcuts": "Klavye kısayolları",
            "Hide or reveal the icons": "Simgeleri gizle veya göster",
            "Turn automatic hiding on or off": "Otomatik gizlemeyi aç veya kapat",
            "Nothing is bound until you bind it. They work from any application.":
                "Siz atama yapmadıkça hiçbir şey olmaz. Her uygulamadan çalışırlar.",
            "Click, then press the combination you want.":
                "Tıklayın, sonra istediğiniz birleşime basın.",
            "Remove this shortcut": "Bu kısayolu kaldır",
            "Press keys…": "Tuşlara basın…",
            "Not set": "Atanmadı",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "En az iki değiştirici, biri ⌘, ⌥ veya ⌃ olmalı.",
            "Something else already uses that.": "Bunu başka bir şey kullanıyor.",
            "Swipe again straight after, and it refines instead of starting over":
                "Hemen ardından yine kaydırın, baştan başlamak yerine daraltır",
            "Narrower: a third, then two thirds": "Daha dar: üçte bir, sonra üçte iki",
            "Top quarter of that side": "O tarafın üst çeyreği",
            "Bottom quarter of that side": "O tarafın alt çeyreği",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "Sağa da aynı şekilde çalışır. Bir an bekleyin, sonraki kaydırma baştan başlar.",
            "Send the window to the Dock": "Pencereyi Dock'a gönder",
            "Pinch in, on the title bar. It never closes anything.":
                "Başlık çubuğunda içe doğru kıstırın. Hiçbir şeyi kapatmaz.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "Simgeleri adlarıyla listelemek erişilebilirlik ister. Gizlemek istemez.",
            "Cornice already uses that for something else.":
                "Cornice bunu zaten başka bir şey için kullanıyor.",
        ],
        .ja: [
            "Behaviour": "動作",
            "Appearance": "外観",
            "Menu Bar": "メニューバー",
            "Start with the icons hidden": "アイコンを隠した状態で起動する",
            "Otherwise Cornice comes up the way you left it.":
                "オフの場合、前回終了したときの状態で起動します。",
            "Hide again when the pointer leaves the menu bar": "ポインタがメニューバーから離れたら、また隠す",
            "After": "待機時間",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "画面の上端をかすめただけで隠れないよう、少し待ちます。",
            "Open at login": "ログイン時に開く",
            "Divider": "区切り",
            "Thickness": "太さ",
            "Height": "高さ",
            "Preview": "プレビュー",
            "Toggle button": "ボタン",
            "Symbol": "記号",
            "Chevron": "山形",
            "Chevron, compact": "山形（細）",
            "Arrow": "矢印",
            "Triangle": "三角形",
            "Sidebar": "サイドバー",
            "Language": "言語",
            "Hidden, left of the divider": "非表示: 区切りの左側",
            "Keep a second divider, for icons you never want to see": "2つ目の区切り。ずっと隠しておきたいアイコン用",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "メニューバーの場所をもう1つ使います。⌘を押しながら1つ目の区切りの左へドラッグしてください。その左側にあるものは、ほかを表示しているときも隠れたままです。",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "ボタンを⌥クリックで開きます。下でショートカットを割り当てることもできます。",
            "Open or close the always hidden zone": "ずっと隠す領域を開く/閉じる",
            "Always hidden, left of the second divider": "ずっと非表示: 2つ目の区切りの左側",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "ありません。ずっと隠しておきたいアイコンの左へ2つ目の区切りをドラッグしてください。",
            "Visible, right of the divider": "表示中: 区切りの右側",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "なし。隠したいアイコンの左へ区切りをドラッグしてください。",
            "⌘-drag the divider to change what is hidden.":
                "⌘を押しながら区切りをドラッグすると、隠す範囲が変わります。",
            "Refresh": "更新",
            "Settings…": "設定…",
            "Quit Cornice": "Corniceを終了",
            "Version": "バージョン",
            "Check for Updates": "アップデートを確認",
            "Check at launch": "起動時に確認",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "GitHub へのリクエストが1回だけ、送る情報はありません。Cornice が自分自身を上書きインストールすることはありません。",
            "You have the latest version.": "最新バージョンです。",
            "is available": "が利用できます",
            "Could not check:": "確認できませんでした:",
            "off-screen": "画面外",
            "Gestures": "ジェスチャ",
            "Move windows with trackpad gestures": "トラックパッドのジェスチャでウインドウを動かす",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "初期状態ではオフ。アクセシビリティはオンにしたときだけ求めます。",
            "Accessibility has not been granted, so gestures are not running.":
                "アクセシビリティが許可されていないため、ジェスチャは動作しません。",
            "Open Accessibility settings": "アクセシビリティ設定を開く",
            "Two fingers, pointer on a window's title bar": "2本指、ポインタはウインドウのタイトルバーの上",
            "Left half": "左半分",
            "Right half": "右半分",
            "Fill the screen": "画面いっぱい",
            "Put it back where it was": "元の位置に戻す",
            "Keyboard shortcuts": "キーボードショートカット",
            "Hide or reveal the icons": "アイコンを隠す、または表示する",
            "Turn automatic hiding on or off": "自動的に隠す機能をオン、オフする",
            "Nothing is bound until you bind it. They work from any application.":
                "割り当てるまで何も起きません。どのアプリからでも使えます。",
            "Click, then press the combination you want.": "クリックしてから、使いたい組み合わせを押してください。",
            "Remove this shortcut": "このショートカットを削除",
            "Press keys…": "キーを押してください…",
            "Not set": "未設定",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "修飾キーは2つ以上、うち1つは ⌘、⌥、⌃ のどれか。",
            "Something else already uses that.": "ほかのものがすでに使っています。",
            "Swipe again straight after, and it refines instead of starting over":
                "続けてもう一度スワイプすると、やり直しではなく細かく決まります",
            "Narrower: a third, then two thirds": "狭く: 3分の1、次に3分の2",
            "Top quarter of that side": "その側の上の4分の1",
            "Bottom quarter of that side": "その側の下の4分の1",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "右も同じです。少し待つと、次のスワイプは最初からになります。",
            "Send the window to the Dock": "ウインドウをDockにしまう",
            "Pinch in, on the title bar. It never closes anything.":
                "タイトルバーの上でピンチイン。何かを閉じることはありません。",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "アイコンを名前で並べるにはアクセシビリティが要ります。隠すのには要りません。",
            "Cornice already uses that for something else.":
                "Cornice がすでに別の動作で使っています。",
        ],
        .ko: [
            "Behaviour": "동작",
            "Appearance": "모양",
            "Menu Bar": "메뉴 막대",
            "Start with the icons hidden": "아이콘을 숨긴 채로 시작",
            "Otherwise Cornice comes up the way you left it.":
                "끄면 마지막으로 종료했을 때의 상태로 시작합니다.",
            "Hide again when the pointer leaves the menu bar": "포인터가 메뉴 막대를 벗어나면 다시 숨기기",
            "After": "지연 시간",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "화면 위쪽을 스쳐 지나갔다고 숨지 않도록 잠시 기다립니다.",
            "Open at login": "로그인 시 열기",
            "Divider": "구분선",
            "Thickness": "굵기",
            "Height": "높이",
            "Preview": "미리보기",
            "Toggle button": "버튼",
            "Symbol": "기호",
            "Chevron": "갈매기표",
            "Chevron, compact": "갈매기표, 좁게",
            "Arrow": "화살표",
            "Triangle": "삼각형",
            "Sidebar": "사이드바",
            "Language": "언어",
            "Hidden, left of the divider": "가려짐: 구분선 왼쪽",
            "Keep a second divider, for icons you never want to see": "두 번째 구분선. 계속 숨겨둘 아이콘용",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "메뉴 막대 자리를 하나 더 씁니다. ⌘을 누른 채 첫 번째 구분선 왼쪽으로 끌어 놓으세요. 그 왼쪽에 있는 것은 나머지가 보일 때도 계속 가려집니다.",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "버튼을 ⌥-클릭하면 열립니다. 아래에서 단축키를 지정할 수도 있습니다.",
            "Open or close the always hidden zone": "항상 가려두는 영역 열기 또는 닫기",
            "Always hidden, left of the second divider": "항상 가려짐: 두 번째 구분선 왼쪽",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "없음. 계속 숨겨둘 아이콘 왼쪽으로 두 번째 구분선을 끌어 놓으세요.",
            "Visible, right of the divider": "표시됨: 구분선 오른쪽",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "없음. 치우고 싶은 아이콘의 왼쪽으로 구분선을 드래그하십시오.",
            "⌘-drag the divider to change what is hidden.":
                "⌘를 누른 채 구분선을 드래그하면 가려지는 항목이 바뀝니다.",
            "Refresh": "새로고침",
            "Settings…": "설정…",
            "Quit Cornice": "Cornice 종료",
            "Version": "버전",
            "Check for Updates": "업데이트 확인",
            "Check at launch": "실행할 때 확인",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "GitHub에 요청 한 번, 보내는 정보는 없습니다. Cornice가 자기 자신을 덮어써 설치하는 일은 없습니다.",
            "You have the latest version.": "최신 버전입니다.",
            "is available": "사용 가능",
            "Could not check:": "확인할 수 없음:",
            "off-screen": "화면 밖",
            "Gestures": "제스처",
            "Move windows with trackpad gestures": "트랙패드 제스처로 윈도우 옮기기",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "기본값은 꺼짐. 손쉬운 사용 권한은 켤 때만 요청합니다.",
            "Accessibility has not been granted, so gestures are not running.":
                "손쉬운 사용 권한이 없어 제스처가 동작하지 않습니다.",
            "Open Accessibility settings": "손쉬운 사용 설정 열기",
            "Two fingers, pointer on a window's title bar": "두 손가락, 포인터는 윈도우 제목 막대 위에",
            "Left half": "왼쪽 절반",
            "Right half": "오른쪽 절반",
            "Fill the screen": "화면 가득",
            "Put it back where it was": "원래 자리로 되돌리기",
            "Keyboard shortcuts": "키보드 단축키",
            "Hide or reveal the icons": "아이콘 숨기기 또는 보이기",
            "Turn automatic hiding on or off": "자동 숨김 켜기 또는 끄기",
            "Nothing is bound until you bind it. They work from any application.":
                "지정하기 전까지는 아무 일도 없습니다. 어느 앱에서나 동작합니다.",
            "Click, then press the combination you want.": "누른 다음, 원하는 조합을 누르세요.",
            "Remove this shortcut": "이 단축키 지우기",
            "Press keys…": "키를 누르세요…",
            "Not set": "지정 안 됨",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "조합키는 두 개 이상, 그중 하나는 ⌘, ⌥ 또는 ⌃.",
            "Something else already uses that.": "다른 것이 이미 쓰고 있습니다.",
            "Swipe again straight after, and it refines instead of starting over":
                "바로 이어서 한 번 더 쓸면 처음부터가 아니라 더 세밀해집니다",
            "Narrower: a third, then two thirds": "더 좁게: 3분의 1, 다음은 3분의 2",
            "Top quarter of that side": "그쪽의 위 4분의 1",
            "Bottom quarter of that side": "그쪽의 아래 4분의 1",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "오른쪽도 같습니다. 잠깐 쉬면 다음 쓸기는 처음부터 시작합니다.",
            "Send the window to the Dock": "윈도우를 Dock으로 보내기",
            "Pinch in, on the title bar. It never closes anything.":
                "제목 막대 위에서 오므리기. 무엇도 닫지 않습니다.",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "아이콘을 이름으로 나열하려면 손쉬운 사용 권한이 필요합니다. 숨기는 데는 필요 없습니다.",
            "Cornice already uses that for something else.":
                "Cornice가 이미 다른 동작에 쓰고 있습니다.",
        ],
        .zh: [
            "Behaviour": "行为",
            "Appearance": "外观",
            "Menu Bar": "菜单栏",
            "Start with the icons hidden": "启动时隐藏图标",
            "Otherwise Cornice comes up the way you left it.":
                "关闭时，Cornice 会按上次退出的状态启动。",
            "Hide again when the pointer leaves the menu bar": "指针离开菜单栏后重新隐藏",
            "After": "延迟",
            "A short wait, so brushing past the top of the screen does not put them away.":
                "稍作等待，免得只是从屏幕顶部划过就把图标收起来。",
            "Open at login": "登录时打开",
            "Divider": "分隔线",
            "Thickness": "粗细",
            "Height": "高度",
            "Preview": "预览",
            "Toggle button": "按钮",
            "Symbol": "符号",
            "Chevron": "尖角",
            "Chevron, compact": "尖角（窄）",
            "Arrow": "箭头",
            "Triangle": "三角形",
            "Sidebar": "边栏",
            "Language": "语言",
            "Hidden, left of the divider": "已隐藏: 分隔线左侧",
            "Keep a second divider, for icons you never want to see": "第二条分隔线，用于永远不想看到的图标",
            "It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed.":
                "会多占菜单栏一个位置。按住 ⌘ 把它拖到第一条分隔线左边：落在它左边的东西，即使其余图标显示出来也仍然隐藏。",
            "⌥-click the toggle button to open it, or bind a shortcut below.":
                "⌥-点按按钮即可打开，也可以在下面设置快捷键。",
            "Open or close the always hidden zone": "打开或关闭常隐区域",
            "Always hidden, left of the second divider": "常隐: 第二条分隔线左侧",
            "Nothing. Drag the second divider left of the icons you never want to see.":
                "没有。把第二条分隔线拖到你永远不想看到的图标左边。",
            "Visible, right of the divider": "显示中: 分隔线右侧",
            "Nothing. Drag the divider left of the icons you want out of the way.":
                "无。把分隔线拖到想收起的图标左侧。",
            "⌘-drag the divider to change what is hidden.":
                "按住 ⌘ 拖动分隔线，即可更改隐藏范围。",
            "Refresh": "刷新",
            "Settings…": "设置…",
            "Quit Cornice": "退出 Cornice",
            "Version": "版本",
            "Check for Updates": "检查更新",
            "Check at launch": "启动时检查",
            "One request to GitHub, carrying nothing. Cornice never installs anything over itself.":
                "向 GitHub 发一次请求，不带任何信息。Cornice 从不覆盖安装自己。",
            "You have the latest version.": "已是最新版本。",
            "is available": "可用",
            "Could not check:": "无法检查：",
            "off-screen": "屏幕外",
            "Gestures": "手势",
            "Move windows with trackpad gestures": "用触控板手势移动窗口",
            "Off by default. Accessibility is asked for only when you turn this on.":
                "默认关闭。仅在开启此项时才申请辅助功能权限。",
            "Accessibility has not been granted, so gestures are not running.":
                "未获得辅助功能权限，手势未运行。",
            "Open Accessibility settings": "打开辅助功能设置",
            "Two fingers, pointer on a window's title bar": "双指，指针位于窗口标题栏上",
            "Left half": "左半屏",
            "Right half": "右半屏",
            "Fill the screen": "占满屏幕",
            "Put it back where it was": "放回原处",
            "Keyboard shortcuts": "键盘快捷键",
            "Hide or reveal the icons": "隐藏或显示图标",
            "Turn automatic hiding on or off": "打开或关闭自动隐藏",
            "Nothing is bound until you bind it. They work from any application.":
                "没有指定之前不会发生任何事。在任何应用中都有效。",
            "Click, then press the combination you want.": "点一下，然后按下想要的组合键。",
            "Remove this shortcut": "移除此快捷键",
            "Press keys…": "请按键…",
            "Not set": "未指定",
            "Use at least two modifiers, one of them ⌘, ⌥ or ⌃.": "至少两个修饰键，其中一个是 ⌘、⌥ 或 ⌃。",
            "Something else already uses that.": "已经被别的东西占用了。",
            "Swipe again straight after, and it refines instead of starting over":
                "紧接着再滑一次，会细分而不是重新开始",
            "Narrower: a third, then two thirds": "更窄：三分之一，然后三分之二",
            "Top quarter of that side": "该侧的上四分之一",
            "Bottom quarter of that side": "该侧的下四分之一",
            "Right works the same. Pause for a moment and the next swipe starts fresh.":
                "向右同理。稍等片刻，下一次滑动就重新开始。",
            "Send the window to the Dock": "把窗口收进程序坞",
            "Pinch in, on the title bar. It never closes anything.": "在标题栏上向内捏合。从不关闭任何东西。",
            "Listing the icons by name needs Accessibility. Hiding them does not.":
                "按名称列出图标需要辅助功能权限。隐藏则不需要。",
            "Cornice already uses that for something else.":
                "Cornice 已经把它用在别的动作上了。",
        ],
    ]
}
