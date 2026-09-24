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
    "shot.caption.alarms": ["It will not let go", "لن يتركك", "Er lässt nicht locker", "No te suelta", "Elle ne lâche rien", "यह पीछा नहीं छोड़ता", "Non ti molla", "逃がしません", "봐주지 않습니다", "Ele não te larga", "Он не отпустит", "它不会放过你"],
    "shot.sub.alarms": ["Mission not done? It rings again.", "لم تكتمل المهمة؟ سيرن مجدداً.", "Mission offen? Er klingelt wieder.", "¿Misión sin terminar? Vuelve a sonar.", "Mission non terminée ? Elle revient.", "मिशन अधूरा? यह फिर बजेगा।", "Missione non completata? Risuona.", "ミッション未完了なら、また鳴ります。", "미션 미완료면 다시 울립니다.", "Missão não concluída? Toca de novo.", "Задание не выполнено? Зазвонит снова.", "任务未完成？它会再响。"],
    "shot.caption.editor": ["Choose what it takes", "اختر ما يلزم لإيقافه", "Du wählst die Aufgabe", "Tú eliges el reto", "À vous de fixer l’épreuve", "चुनौती आप चुनिए", "Scegli tu la sfida", "止め方は自分で決める", "끄는 방법은 직접 고르세요", "Você escolhe o desafio", "Выберите испытание", "怎么关，你来定"],
    "shot.sub.editor": ["Four difficulties, up to ten rounds.", "أربع درجات صعوبة، وحتى عشر جولات.", "Vier Stufen, bis zu zehn Runden.", "Cuatro dificultades, hasta diez rondas.", "Quatre difficultés, jusqu’à dix manches.", "चार कठिनाइयाँ, 10 राउंड तक।", "Quattro difficoltà, fino a dieci turni.", "難易度は4段階、最大10ラウンド。", "난이도 4단계, 최대 10라운드.", "Quatro dificuldades, até dez rodadas.", "Четыре уровня, до десяти раундов.", "四档难度，最多十轮。"],
    "shot.caption.mission": ["Earn the silence", "اكسب الصمت", "Ruhe muss man sich verdienen", "Gánate el silencio", "Méritez le silence", "शांति कमाकर पाइए", "Guadagnati il silenzio", "静けさは自分で勝ち取る", "고요는 스스로 얻는 것", "Conquiste o silêncio", "Тишину нужно заслужить", "安静要自己赢来"],
    "shot.sub.mission": ["Twelve missions to switch it off.", "اثنتا عشرة مهمة لإيقافه.", "Zwölf Missionen, um ihn abzustellen.", "Doce misiones para apagarla.", "Douze missions pour l’éteindre.", "बंद करने के लिए बारह मिशन।", "Dodici missioni per spegnerla.", "止めるためのミッションは12種類。", "끄기 위한 미션 12가지.", "Doze missões para desligar.", "Двенадцать заданий, чтобы выключить.", "关掉它，要靠十二种任务。"],
    "shot.caption.stats": ["Every morning, on record", "كل صباح موثّق", "Jeder Morgen, notiert", "Cada mañana, anotada", "Chaque matin, noté", "हर सुबह का हिसाब", "Ogni mattina, annotata", "毎朝が記録に残る", "모든 아침이 기록됩니다", "Cada manhã, anotada", "Каждое утро записано", "每个清晨都有记录"],
    "shot.sub.stats": ["Wake times, streaks and every dodge.", "أوقات الاستيقاظ، والسلاسل، وكل تهرّب.", "Aufwachzeiten, Serien und jedes Kneifen.", "Horas, rachas y cada escaqueo.", "Heures de réveil, séries, chaque esquive.", "जागने का समय, सिलसिले, हर बहाना।", "Orari, serie e ogni scappatoia.", "起床時刻、連続記録、さぼった朝も。", "기상 시각, 연속 기록, 빠져나간 아침까지.", "Horários, sequências e cada escapada.", "Время подъёма, серии и все отговорки.", "起床时间、连续记录，还有每次偷懒。"],
    "shot.caption.settings": ["Nothing leaves your phone", "لا شيء يخرج من هاتفك", "Nichts verlässt dein Telefon", "Nada sale de tu teléfono", "Rien ne quitte votre téléphone", "कुछ भी फ़ोन से बाहर नहीं जाता", "Niente lascia il telefono", "データは端末の外に出ません", "데이터는 기기를 떠나지 않습니다", "Nada sai do seu telefone", "Ничего не покидает телефон", "数据不离开手机"],
    "shot.sub.settings": ["No account, no ads, no server.", "بلا حساب، بلا إعلانات، بلا خادم.", "Kein Konto, keine Werbung, kein Server.", "Sin cuenta, sin anuncios, sin servidor.", "Pas de compte, pas de pub, pas de serveur.", "न अकाउंट, न विज्ञापन, न सर्वर।", "Niente account, pubblicità o server.", "アカウントも広告もサーバーもなし。", "계정도, 광고도, 서버도 없습니다.", "Sem conta, sem anúncios, sem servidor.", "Без аккаунта, рекламы и сервера.", "无需账号，没有广告，没有服务器。"],
    "shot.caption.onboarding": ["Rings in silent mode", "يرن في الوضع الصامت", "Klingelt im Stummmodus", "Suena en modo silencio", "Sonne en mode silencieux", "साइलेंट मोड में भी बजता है", "Suona anche in silenzioso", "サイレントモードでも鳴る", "무음 모드에서도 울림", "Toca no modo silencioso", "Звонит в беззвучном режиме", "静音模式下也会响"],
    "shot.sub.onboarding": ["And through Focus, with the app closed.", "ومع أوضاع التركيز، والتطبيق مغلق.", "Auch bei Fokus und geschlossener App.", "Y en modo de concentración, con la app cerrada.", "Même en mode concentration, app fermée.", "फ़ोकस में भी, ऐप बंद होने पर भी।", "Anche con Full Immersion e l’app chiusa.", "集中モード中も、アプリを閉じていても。", "집중 모드에서도, 앱을 닫아도.", "E com Foco, mesmo com o app fechado.", "И при фокусировании, и с закрытым приложением.", "专注模式下、应用关闭时也一样。"],
}
