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
            "Start hidden": "Запускаться свёрнутым",
            "Otherwise Cornice comes up the way you left it.":
                "Иначе Cornice откроется так, как вы его оставили.",
            "Hide again automatically": "Сворачивать автоматически",
            "After": "Через",
            "Counted from the moment the pointer leaves the menu bar.":
                "Отсчёт с момента, когда курсор покидает строку меню.",
            "Open at login": "Запускать при входе",
            "Divider": "Разделитель",
            "Thickness": "Толщина",
            "Height": "Высота",
            "Preview": "Образец",
            "Toggle": "Переключатель",
            "Symbol": "Символ",
            "Chevron": "Шеврон",
            "Chevron, compact": "Шеврон, узкий",
            "Arrow": "Стрелка",
            "Triangle": "Треугольник",
            "Sidebar": "Боковая панель",
            "Language": "Язык",
            "Hidden, left of the divider": "Скрытые, левее разделителя",
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
        ],
        .uk: [
            "Behaviour": "Поведінка",
            "Appearance": "Оформлення",
            "Menu Bar": "Рядок меню",
            "Start hidden": "Запускатися згорнутим",
            "Otherwise Cornice comes up the way you left it.":
                "Інакше Cornice відкриється так, як ви його залишили.",
            "Hide again automatically": "Згортати автоматично",
            "After": "Через",
            "Counted from the moment the pointer leaves the menu bar.":
                "Відлік від моменту, коли курсор залишає рядок меню.",
            "Open at login": "Запускати під час входу",
            "Divider": "Роздільник",
            "Thickness": "Товщина",
            "Height": "Висота",
            "Preview": "Зразок",
            "Toggle": "Перемикач",
            "Symbol": "Символ",
            "Chevron": "Шеврон",
            "Chevron, compact": "Шеврон, вузький",
            "Arrow": "Стрілка",
            "Triangle": "Трикутник",
            "Sidebar": "Бічна панель",
            "Language": "Мова",
            "Hidden, left of the divider": "Приховані, ліворуч від роздільника",
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
        ],
        .de: [
            "Behaviour": "Verhalten",
            "Appearance": "Erscheinungsbild",
            "Menu Bar": "Menüleiste",
            "Start hidden": "Ausgeblendet starten",
            "Otherwise Cornice comes up the way you left it.":
                "Andernfalls startet Cornice so, wie Sie es verlassen haben.",
            "Hide again automatically": "Automatisch wieder ausblenden",
            "After": "Nach",
            "Counted from the moment the pointer leaves the menu bar.":
                "Gezählt ab dem Moment, in dem der Zeiger die Menüleiste verlässt.",
            "Open at login": "Bei der Anmeldung öffnen",
            "Divider": "Trenner",
            "Thickness": "Stärke",
            "Height": "Höhe",
            "Preview": "Vorschau",
            "Toggle": "Schalter",
            "Symbol": "Symbol",
            "Chevron": "Pfeilspitze",
            "Chevron, compact": "Pfeilspitze, schmal",
            "Arrow": "Pfeil",
            "Triangle": "Dreieck",
            "Sidebar": "Seitenleiste",
            "Language": "Sprache",
            "Hidden, left of the divider": "Ausgeblendet, links vom Trenner",
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
        ],
        .fr: [
            "Behaviour": "Comportement",
            "Appearance": "Apparence",
            "Menu Bar": "Barre des menus",
            "Start hidden": "Démarrer masqué",
            "Otherwise Cornice comes up the way you left it.":
                "Sinon Cornice reprend l'état dans lequel vous l'avez laissé.",
            "Hide again automatically": "Masquer à nouveau automatiquement",
            "After": "Après",
            "Counted from the moment the pointer leaves the menu bar.":
                "Compté à partir du moment où le pointeur quitte la barre des menus.",
            "Open at login": "Ouvrir à l'ouverture de session",
            "Divider": "Séparateur",
            "Thickness": "Épaisseur",
            "Height": "Hauteur",
            "Preview": "Aperçu",
            "Toggle": "Bouton",
            "Symbol": "Symbole",
            "Chevron": "Chevron",
            "Chevron, compact": "Chevron, compact",
            "Arrow": "Flèche",
            "Triangle": "Triangle",
            "Sidebar": "Barre latérale",
            "Language": "Langue",
            "Hidden, left of the divider": "Masqués: à gauche du séparateur",
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
        ],
        .es: [
            "Behaviour": "Comportamiento",
            "Appearance": "Apariencia",
            "Menu Bar": "Barra de menús",
            "Start hidden": "Iniciar oculto",
            "Otherwise Cornice comes up the way you left it.":
                "De lo contrario, Cornice se abrirá tal como lo dejó.",
            "Hide again automatically": "Ocultar de nuevo automáticamente",
            "After": "Después de",
            "Counted from the moment the pointer leaves the menu bar.":
                "Contado desde que el puntero sale de la barra de menús.",
            "Open at login": "Abrir al iniciar sesión",
            "Divider": "Separador",
            "Thickness": "Grosor",
            "Height": "Altura",
            "Preview": "Vista previa",
            "Toggle": "Interruptor",
            "Symbol": "Símbolo",
            "Chevron": "Chevrón",
            "Chevron, compact": "Chevrón, compacto",
            "Arrow": "Flecha",
            "Triangle": "Triángulo",
            "Sidebar": "Barra lateral",
            "Language": "Idioma",
            "Hidden, left of the divider": "Ocultos, a la izquierda del separador",
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
        ],
        .pt: [
            "Behaviour": "Comportamento",
            "Appearance": "Aparência",
            "Menu Bar": "Barra de menus",
            "Start hidden": "Iniciar oculto",
            "Otherwise Cornice comes up the way you left it.":
                "Caso contrário, o Cornice abre como você o deixou.",
            "Hide again automatically": "Ocultar novamente de forma automática",
            "After": "Após",
            "Counted from the moment the pointer leaves the menu bar.":
                "Contado a partir do momento em que o ponteiro sai da barra de menus.",
            "Open at login": "Abrir ao iniciar sessão",
            "Divider": "Divisor",
            "Thickness": "Espessura",
            "Height": "Altura",
            "Preview": "Pré-visualização",
            "Toggle": "Botão",
            "Symbol": "Símbolo",
            "Chevron": "Divisa",
            "Chevron, compact": "Divisa, compacta",
            "Arrow": "Seta",
            "Triangle": "Triângulo",
            "Sidebar": "Barra lateral",
            "Language": "Idioma",
            "Hidden, left of the divider": "Ocultos: à esquerda do divisor",
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
        ],
        .it: [
            "Behaviour": "Comportamento",
            "Appearance": "Aspetto",
            "Menu Bar": "Barra dei menu",
            "Start hidden": "Avvia nascosto",
            "Otherwise Cornice comes up the way you left it.":
                "Altrimenti Cornice si apre come l'hai lasciato.",
            "Hide again automatically": "Nascondi di nuovo automaticamente",
            "After": "Dopo",
            "Counted from the moment the pointer leaves the menu bar.":
                "Conteggiato da quando il puntatore lascia la barra dei menu.",
            "Open at login": "Apri all'accesso",
            "Divider": "Divisore",
            "Thickness": "Spessore",
            "Height": "Altezza",
            "Preview": "Anteprima",
            "Toggle": "Interruttore",
            "Symbol": "Simbolo",
            "Chevron": "Chevron",
            "Chevron, compact": "Chevron, compatto",
            "Arrow": "Freccia",
            "Triangle": "Triangolo",
            "Sidebar": "Barra laterale",
            "Language": "Lingua",
            "Hidden, left of the divider": "Nascosti, a sinistra del divisore",
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
        ],
        .nl: [
            "Behaviour": "Gedrag",
            "Appearance": "Weergave",
            "Menu Bar": "Menubalk",
            "Start hidden": "Verborgen starten",
            "Otherwise Cornice comes up the way you left it.":
                "Anders start Cornice zoals u het hebt achtergelaten.",
            "Hide again automatically": "Automatisch weer verbergen",
            "After": "Na",
            "Counted from the moment the pointer leaves the menu bar.":
                "Geteld vanaf het moment dat de aanwijzer de menubalk verlaat.",
            "Open at login": "Openen bij inloggen",
            "Divider": "Scheiding",
            "Thickness": "Dikte",
            "Height": "Hoogte",
            "Preview": "Voorbeeld",
            "Toggle": "Schakelaar",
            "Symbol": "Symbool",
            "Chevron": "Pijlpunt",
            "Chevron, compact": "Pijlpunt, smal",
            "Arrow": "Pijl",
            "Triangle": "Driehoek",
            "Sidebar": "Navigatiekolom",
            "Language": "Taal",
            "Hidden, left of the divider": "Verborgen, links van de scheiding",
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
        ],
        .pl: [
            "Behaviour": "Zachowanie",
            "Appearance": "Wygląd",
            "Menu Bar": "Pasek menu",
            "Start hidden": "Uruchamiaj ukryty",
            "Otherwise Cornice comes up the way you left it.":
                "W przeciwnym razie Cornice uruchomi się tak, jak go zostawiono.",
            "Hide again automatically": "Ukrywaj ponownie automatycznie",
            "After": "Po",
            "Counted from the moment the pointer leaves the menu bar.":
                "Liczone od chwili, gdy wskaźnik opuszcza pasek menu.",
            "Open at login": "Otwieraj przy logowaniu",
            "Divider": "Separator",
            "Thickness": "Grubość",
            "Height": "Wysokość",
            "Preview": "Podgląd",
            "Toggle": "Przełącznik",
            "Symbol": "Symbol",
            "Chevron": "Strzałka kątowa",
            "Chevron, compact": "Strzałka kątowa, wąska",
            "Arrow": "Strzałka",
            "Triangle": "Trójkąt",
            "Sidebar": "Panel boczny",
            "Language": "Język",
            "Hidden, left of the divider": "Ukryte, na lewo od separatora",
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
        ],
        .cs: [
            "Behaviour": "Chování",
            "Appearance": "Vzhled",
            "Menu Bar": "Řádek nabídek",
            "Start hidden": "Spouštět skrytý",
            "Otherwise Cornice comes up the way you left it.":
                "Jinak se Cornice spustí tak, jak jste jej zanechali.",
            "Hide again automatically": "Skrývat znovu automaticky",
            "After": "Po",
            "Counted from the moment the pointer leaves the menu bar.":
                "Počítáno od okamžiku, kdy ukazatel opustí řádek nabídek.",
            "Open at login": "Otevírat při přihlášení",
            "Divider": "Oddělovač",
            "Thickness": "Tloušťka",
            "Height": "Výška",
            "Preview": "Náhled",
            "Toggle": "Přepínač",
            "Symbol": "Symbol",
            "Chevron": "Šipka",
            "Chevron, compact": "Šipka, úzká",
            "Arrow": "Šipka",
            "Triangle": "Trojúhelník",
            "Sidebar": "Postranní panel",
            "Language": "Jazyk",
            "Hidden, left of the divider": "Skryté, vlevo od oddělovače",
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
        ],
        .sv: [
            "Behaviour": "Beteende",
            "Appearance": "Utseende",
            "Menu Bar": "Menyrad",
            "Start hidden": "Starta dolt",
            "Otherwise Cornice comes up the way you left it.":
                "Annars startar Cornice som du lämnade det.",
            "Hide again automatically": "Dölj igen automatiskt",
            "After": "Efter",
            "Counted from the moment the pointer leaves the menu bar.":
                "Räknat från när pekaren lämnar menyraden.",
            "Open at login": "Öppna vid inloggning",
            "Divider": "Avdelare",
            "Thickness": "Tjocklek",
            "Height": "Höjd",
            "Preview": "Förhandsvisning",
            "Toggle": "Reglage",
            "Symbol": "Symbol",
            "Chevron": "Vinkelpil",
            "Chevron, compact": "Vinkelpil, smal",
            "Arrow": "Pil",
            "Triangle": "Triangel",
            "Sidebar": "Sidofält",
            "Language": "Språk",
            "Hidden, left of the divider": "Dolda, till vänster om avdelaren",
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
        ],
        .tr: [
            "Behaviour": "Davranış",
            "Appearance": "Görünüm",
            "Menu Bar": "Menü çubuğu",
            "Start hidden": "Gizli başlat",
            "Otherwise Cornice comes up the way you left it.":
                "Aksi hâlde Cornice bıraktığınız durumda açılır.",
            "Hide again automatically": "Otomatik olarak yeniden gizle",
            "After": "Şu süreden sonra",
            "Counted from the moment the pointer leaves the menu bar.":
                "İmleç menü çubuğundan ayrıldığı andan itibaren sayılır.",
            "Open at login": "Oturum açıldığında aç",
            "Divider": "Ayırıcı",
            "Thickness": "Kalınlık",
            "Height": "Yükseklik",
            "Preview": "Önizleme",
            "Toggle": "Düğme",
            "Symbol": "Simge",
            "Chevron": "Ok ucu",
            "Chevron, compact": "Ok ucu, dar",
            "Arrow": "Ok",
            "Triangle": "Üçgen",
            "Sidebar": "Yan çubuk",
            "Language": "Dil",
            "Hidden, left of the divider": "Gizli, ayırıcının solunda",
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
        ],
        .ja: [
            "Behaviour": "動作",
            "Appearance": "外観",
            "Menu Bar": "メニューバー",
            "Start hidden": "非表示の状態で起動",
            "Otherwise Cornice comes up the way you left it.":
                "オフの場合、前回終了したときの状態で起動します。",
            "Hide again automatically": "自動的に隠し直す",
            "After": "待機時間",
            "Counted from the moment the pointer leaves the menu bar.":
                "ポインタがメニューバーから離れた時点から数えます。",
            "Open at login": "ログイン時に開く",
            "Divider": "区切り",
            "Thickness": "太さ",
            "Height": "高さ",
            "Preview": "プレビュー",
            "Toggle": "切り替え",
            "Symbol": "記号",
            "Chevron": "山形",
            "Chevron, compact": "山形（細）",
            "Arrow": "矢印",
            "Triangle": "三角形",
            "Sidebar": "サイドバー",
            "Language": "言語",
            "Hidden, left of the divider": "非表示: 区切りの左側",
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
        ],
        .ko: [
            "Behaviour": "동작",
            "Appearance": "모양",
            "Menu Bar": "메뉴 막대",
            "Start hidden": "가려진 상태로 시작",
            "Otherwise Cornice comes up the way you left it.":
                "끄면 마지막으로 종료했을 때의 상태로 시작합니다.",
            "Hide again automatically": "자동으로 다시 가리기",
            "After": "지연 시간",
            "Counted from the moment the pointer leaves the menu bar.":
                "포인터가 메뉴 막대를 벗어난 순간부터 셉니다.",
            "Open at login": "로그인 시 열기",
            "Divider": "구분선",
            "Thickness": "굵기",
            "Height": "높이",
            "Preview": "미리보기",
            "Toggle": "전환 버튼",
            "Symbol": "기호",
            "Chevron": "갈매기표",
            "Chevron, compact": "갈매기표, 좁게",
            "Arrow": "화살표",
            "Triangle": "삼각형",
            "Sidebar": "사이드바",
            "Language": "언어",
            "Hidden, left of the divider": "가려짐: 구분선 왼쪽",
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
        ],
        .zh: [
            "Behaviour": "行为",
            "Appearance": "外观",
            "Menu Bar": "菜单栏",
            "Start hidden": "启动时隐藏",
            "Otherwise Cornice comes up the way you left it.":
                "关闭时，Cornice 会按上次退出的状态启动。",
            "Hide again automatically": "自动重新隐藏",
            "After": "延迟",
            "Counted from the moment the pointer leaves the menu bar.":
                "从指针离开菜单栏的那一刻开始计时。",
            "Open at login": "登录时打开",
            "Divider": "分隔线",
            "Thickness": "粗细",
            "Height": "高度",
            "Preview": "预览",
            "Toggle": "开关",
            "Symbol": "符号",
            "Chevron": "尖角",
            "Chevron, compact": "尖角（窄）",
            "Arrow": "箭头",
            "Triangle": "三角形",
            "Sidebar": "边栏",
            "Language": "语言",
            "Hidden, left of the divider": "已隐藏: 分隔线左侧",
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
        ],
    ]
}
