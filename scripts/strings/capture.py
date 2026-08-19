"""The alarm labels and the captions in the App Store screenshots.

Four strings that exist for one reason: `CaptureMode` seeds them into the demo alarm list, and a
screenshot is taken in each of the twelve languages. A French listing whose screenshot still says
"Morning run" tells the reader the app was run through a translator and not much else, so these
are translated with the same care as the rest — and they are ordinary alarm labels, which is what
a reader is looking for evidence of.

They ship in the app bundle. That is the cost of the screenshots being taken from the same binary
that gets submitted rather than from a Debug build with a different layout.

Order of values in every row: en ar de es fr hi it ja ko pt-BR ru zh-Hans
"""

LABELS = {
    "capture.label.run": ["Morning run", "جري الصباح", "Morgenlauf", "Salir a correr", "Course du matin", "सुबह की दौड़", "Corsa mattutina", "朝ラン", "아침 러닝", "Corrida matinal", "Утренний бег", "晨跑"],
    "capture.label.work": ["Off to work", "إلى العمل", "Zur Arbeit", "A la oficina", "Départ au bureau", "काम पर निकलना", "Al lavoro", "仕事へ", "출근", "Sair para o trabalho", "На работу", "去上班"],
    "capture.label.walk": ["Weekend walk", "مشية نهاية الأسبوع", "Wochenendspaziergang", "Paseo del finde", "Balade du week-end", "वीकेंड की सैर", "Passeggiata del weekend", "週末の散歩", "주말 산책", "Caminhada de fim de semana", "Прогулка на выходных", "周末散步"],
    "capture.label.flight": ["Flight to Lisbon", "الرحلة إلى لشبونة", "Flug nach Lissabon", "Vuelo a Lisboa", "Vol pour Lisbonne", "लिस्बन की फ़्लाइट", "Volo per Lisbona", "リスボン行きの便", "리스본행 비행기", "Voo para Lisboa", "Рейс в Лиссабон", "飞往里斯本"],
}

# The headline and the line under it, drawn above each framed screenshot by
# `scripts/frame-shots.swift`. Keyed by `CaptureLaunch.Screen.captionKey` / `.subcaptionKey`.
#
# Read at thumbnail size on a phone, which is what decides the length: the headline is one short
# line, the subcaption one clause. They are in this catalog rather than in the metadata folders
# because a caption in the wrong language on a translated screenshot is the single most obvious
# way a localized listing can look automated, and here the same tests that cover the rest of the
# app cover them.
CAPTIONS = {
    "shot.caption.alarms": ["Wake up for real", "استيقظ فعلاً", "Wirklich aufwachen", "Despierta de verdad", "Réveil pour de vrai", "अब सच में उठिए", "Sveglia sul serio", "本当に起きる朝へ", "진짜로 일어나는 아침", "Acorde de verdade", "Просыпайтесь по-настоящему", "真正地起床"],
    "shot.sub.alarms": ["Set it once. It will not let go.", "اضبطه مرة، ولن يتركك.", "Einmal stellen. Er lässt nicht locker.", "Configúrala una vez. No se rinde.", "Réglez-la une fois. Elle n'abandonne pas.", "एक बार सेट करें, फिर छूट नहीं मिलेगी।", "Impostala una volta. Non molla.", "一度設定すれば、逃げられません。", "한 번 설정하면 봐주지 않습니다.", "Configure uma vez. Ele não desiste.", "Настройте один раз. Он не отпустит.", "设置一次，它不会放过你。"],
    "shot.caption.editor": ["Set up your morning", "اختر صباحك", "Deinen Morgen einstellen", "Diseña tu mañana", "Composez votre matin", "अपनी सुबह चुनें", "Scegli la tua mattina", "自分好みの朝に", "아침을 직접 설정", "Monte sua manhã", "Настройте своё утро", "定制你的早晨"],
    "shot.sub.editor": ["Tone, snooze, mission, difficulty.", "النغمة، التأجيل، المهمة، الصعوبة.", "Ton, Schlummern, Mission, Schwierigkeit.", "Tono, repetición, misión, dificultad.", "Sonnerie, rappel, mission, difficulté.", "टोन, स्नूज़, मिशन, कठिनाई।", "Suono, snooze, missione, difficoltà.", "音、スヌーズ、ミッション、難易度。", "알림음, 다시 알림, 미션, 난이도.", "Som, soneca, missão, dificuldade.", "Звук, отсрочка, миссия, сложность.", "铃声、小睡、任务、难度。"],
    "shot.caption.mission": ["Earn the silence", "اكسب الصمت", "Ruhe muss man sich verdienen", "Gánate el silencio", "Méritez le silence", "शांति कमाकर पाइए", "Guadagnati il silenzio", "静けさは自分で勝ち取る", "고요는 스스로 얻는 것", "Conquiste o silêncio", "Тишину нужно заслужить", "安静要自己赢来"],
    "shot.sub.mission": ["Twelve missions to switch it off.", "اثنتا عشرة مهمة لإيقافه.", "Zwölf Missionen, ihn abzustellen.", "Doce misiones para apagarla.", "Douze missions pour l'éteindre.", "बंद करने के लिए बारह मिशन।", "Dodici missioni per spegnerla.", "止めるためのミッションは12種類。", "끄기 위한 미션 12가지.", "Doze missões para desligar.", "Двенадцать миссий, чтобы выключить.", "十二种任务才能关掉它。"],
    "shot.caption.stats": ["See every morning", "كل صباح موثّق", "Jeder Morgen im Blick", "Cada mañana, a la vista", "Chaque matin, en clair", "हर सुबह का हिसाब", "Ogni mattina, nero su bianco", "毎朝の記録が残る", "모든 아침이 기록됩니다", "Cada manhã registrada", "Каждое утро на виду", "每个清晨都有记录"],
    "shot.sub.stats": ["Streaks, snoozes, honest numbers.", "سلاسل، تأجيلات، أرقام صادقة.", "Serien, Schlummer, ehrliche Zahlen.", "Rachas, repeticiones, datos honestos.", "Séries, rappels, chiffres honnêtes.", "स्ट्रीक, स्नूज़, सच्चे आँकड़े।", "Serie, snooze, numeri onesti.", "連続記録、スヌーズ、正直な数字。", "연속 기록, 다시 알림, 솔직한 숫자.", "Sequências, sonecas, números honestos.", "Серии, отсрочки, честные цифры.", "连胜、小睡、真实数字。"],
    "shot.caption.settings": ["Made to fit you", "مصمم على مقاسك", "Passt sich dir an", "Hecha a tu medida", "Réglé à votre mesure", "आपके हिसाब से", "Su misura per te", "あなたに合わせて", "당신에게 맞춰서", "Do seu jeito", "Настроено под вас", "为你而调"],
    "shot.sub.settings": ["Dark by default. Twelve languages.", "داكن افتراضياً. اثنتا عشرة لغة.", "Dunkel von Haus aus. Zwölf Sprachen.", "Oscuro por defecto. Doce idiomas.", "Sombre par défaut. Douze langues.", "डिफ़ॉल्ट डार्क। बारह भाषाएँ।", "Scuro per impostazione. Dodici lingue.", "標準でダーク。12言語対応。", "기본은 다크. 12개 언어.", "Escuro por padrão. Doze idiomas.", "Тёмная тема по умолчанию. Двенадцать языков.", "默认深色。支持十二种语言。"],
    "shot.caption.onboarding": ["Set up in a minute", "الإعداد في دقيقة", "In einer Minute bereit", "Listo en un minuto", "Prêt en une minute", "एक मिनट में तैयार", "Pronto in un minuto", "設定は1分で完了", "1분이면 준비 완료", "Pronto em um minuto", "Готово за минуту", "一分钟完成设置"],
    "shot.sub.onboarding": ["Then it does the hard part.", "ثم يتولى هو الجزء الصعب.", "Den harten Teil übernimmt er.", "Lo difícil lo hace la app.", "Ensuite, elle fait le plus dur.", "मुश्किल काम यह खुद करेगा।", "Il resto lo fa l'app.", "あとの難しい役はアプリが。", "어려운 일은 앱이 맡습니다.", "O resto difícil é com o app.", "Дальше самое трудное берёт на себя приложение.", "剩下的难事交给它。"],
}
