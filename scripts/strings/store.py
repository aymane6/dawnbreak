"""The App Store listing, in the twelve languages the app ships in.

This is the text a reader sees before they have the app: the name under the icon, the subtitle
next to it, the search terms that decide whether they ever see it, and the description. It is
not part of the bundle, which is why it lives in its own table and is written out to
`metadata/<store>/` by `scripts/make_metadata.py` rather than compiled into a catalog.

Keyed by locale rather than positional like the rest of `scripts/strings`. The other tables hold
one short line per locale on one source line, where a fixed order is easier to scan than twelve
repeated keys; a description is forty lines long, and twelve of them in a list would be a table
nobody can read or review. `make_metadata.py` checks every table has exactly the twelve locales,
which is the guarantee the positional order was giving.

Every value is under an App Store Connect limit that the generator enforces:

    name 30, subtitle 30, keywords 100, promotional text 170, description 4000, notes 4000

The limits are counted in characters, not bytes, and App Store Connect rejects the whole
submission on one overrun. Which is worth knowing before writing German.

The free and Pro limits quoted in the descriptions are the real ones from `Entitlement`: free is
1 alarm, 1 round, 3 missions and difficulty up to medium; Pro is 25 alarms, 10 rounds, all 12
missions, all 4 difficulties and 90 days of history. Apple rejects a listing that promises more
than the binary delivers, and `scripts/asc-preflight.py` checks these numbers against the source.
"""

# The listing's own URLs. GitHub Pages off the repo's `docs/` folder, which is why `docs/` holds
# HTML: a privacy policy has to be reachable by a reviewer who is not logged in to anything, and
# a policy in a private repo is a rejection.
SUPPORT_URL = "https://aymane6.github.io/dawnbreak/support.html"
PRIVACY_URL = "https://aymane6.github.io/dawnbreak/privacy.html"
MARKETING_URL = "https://aymane6.github.io/dawnbreak/"
# The rights holder as the account that publishes the app spells it: the distribution certificate
# reads "Apple Distribution: Aymane BAMHAMED". This line is printed on the store page and at the
# foot of all twelve HTML pages, so it names the person Apple pays and not an approximation.
COPYRIGHT = "2026 Aymane Bamhamed"

# Under the icon in search results and on the home screen. "Dawnbreak" stays in every language:
# it is the name the app is reviewed and searched under, and a translated app name splits its own
# reputation across twelve strings. What is translated is the descriptor after it, which is what a
# reader scanning a search result actually reads.
NAME = {
    "en-US": "Dawnbreak: Mission Alarm",
    "ar-SA": "Dawnbreak: منبه المهام",
    "de-DE": "Dawnbreak: Mission-Wecker",
    "es-ES": "Dawnbreak: Alarma Misión",
    "fr-FR": "Dawnbreak : Réveil Mission",
    "hi": "Dawnbreak: मिशन अलार्म",
    "it": "Dawnbreak: Sveglia Missione",
    "ja": "Dawnbreak ミッション目覚まし",
    "ko": "Dawnbreak: 미션 알람",
    "pt-BR": "Dawnbreak: Alarme Missão",
    "ru": "Dawnbreak: будильник-миссия",
    "zh-Hans": "Dawnbreak 任务闹钟",
}

# The line under the name, in the same 30 characters. It answers "and?", so it says what the app
# makes you do rather than repeating that it is an alarm.
SUBTITLE = {
    "en-US": "Missions that get you up",
    "ar-SA": "مهام تُخرجك من السرير",
    "de-DE": "Missionen, die dich wecken",
    "es-ES": "Misiones que te levantan",
    "fr-FR": "Des missions qui vous lèvent",
    "hi": "मिशन जो आपको उठा दें",
    "it": "Missioni che ti fanno alzare",
    "ja": "止めるには行動が必要",
    "ko": "미션을 끝내야 꺼집니다",
    "pt-BR": "Missões que fazem levantar",
    "ru": "Задания, чтобы встать",
    "zh-Hans": "做完任务才能关掉",
}

# What people type into App Store search. Comma separated, no space after the comma: the space
# counts against the hundred characters and Apple ignores it.
#
# The app's own name and subtitle are already indexed, so nothing here repeats them. Two-word
# phrases are not spelled out either, because Apple builds combinations from single terms: "wake"
# and "up" already match "wake up". What is here is the vocabulary a half-awake person uses for
# this problem in their own language, including the words for oversleeping, which is the thing
# they are actually searching for a solution to.
KEYWORDS = {
    "en-US": "wake,heavy,sleeper,oversleep,late,snooze,loud,ringtone,squat,barcode,photo,math,shake,habit",
    "ar-SA": "استيقاظ,نوم,ثقيل,تأخير,تحدي,صوت,عالي,رنة,قرفصاء,باركود,صورة,حساب,رج,عادة,صباح",
    "de-DE": "aufwachen,verschlafen,schlummern,laut,klingelton,kniebeuge,barcode,foto,rechnen,serie,früh",
    "es-ES": "despertar,dormilón,dormido,tarde,repetir,fuerte,tono,sentadilla,código,foto,agitar,racha",
    "fr-FR": "réveiller,dormeur,oreiller,retard,rappel,fort,sonnerie,squat,code,barres,photo,calcul",
    "hi": "जगाना,नींद,देर,स्नूज़,तेज़,रिंगटोन,स्क्वैट,बारकोड,फ़ोटो,गणित,आदत,सुबह",
    "it": "svegliare,tardi,ritardo,snooze,forte,suoneria,squat,codice,barre,foto,calcolo,abitudine",
    "ja": "起きる,寝坊,遅刻,二度寝,スヌーズ,大音量,着信音,スクワット,バーコード,写真,計算,振る,習慣,連続,朝活",
    "ko": "기상,늦잠,지각,다시,알림,큰소리,벨소리,스쿼트,바코드,사진,계산,흔들기,습관,연속,아침",
    "pt-BR": "acordar,atrasar,soneca,alto,toque,agachamento,código,barras,foto,cálculo,sacudir,hábito",
    "ru": "разбудить,просыпать,опоздать,отсрочка,громкий,рингтон,приседания,штрихкод,фото,счёт,утро",
    "zh-Hans": "起床,睡过头,迟到,贪睡,响铃,铃声,深蹲,条码,拍照,算术,摇晃,习惯,连续,早起,叫醒",
}

# Above the description, and changeable without submitting a build. Used here for the one thing a
# reader wants confirmed before installing an alarm clock: that it works with the phone locked and
# does not need an account.
PROMOTIONAL_TEXT = {
    "en-US": "Rings on the lock screen with the app closed. No account, no adverts, nothing leaves your phone. Twelve missions, twelve languages.",
    "ar-SA": "يرن على شاشة القفل والتطبيق مغلق. بلا حساب، بلا إعلانات، ولا شيء يخرج من هاتفك. اثنتا عشرة مهمة، واثنتا عشرة لغة.",
    "de-DE": "Klingelt auf dem Sperrbildschirm, auch wenn die App zu ist. Kein Konto, keine Werbung, nichts verlässt dein Telefon. Zwölf Missionen, zwölf Sprachen.",
    "es-ES": "Suena en la pantalla bloqueada con la app cerrada. Sin cuenta, sin anuncios, nada sale de tu teléfono. Doce misiones, doce idiomas.",
    "fr-FR": "Sonne sur l’écran verrouillé, app fermée. Sans compte, sans publicité, rien ne quitte votre téléphone. Douze missions, douze langues.",
    "hi": "ऐप बंद होने पर भी लॉक स्क्रीन पर बजता है। कोई अकाउंट नहीं, कोई विज्ञापन नहीं, कुछ भी फ़ोन से बाहर नहीं जाता। बारह मिशन, बारह भाषाएँ।",
    "it": "Suona sulla schermata di blocco con l’app chiusa. Nessun account, nessuna pubblicità, niente lascia il telefono. Dodici missioni, dodici lingue.",
    "ja": "アプリを閉じていてもロック画面で鳴ります。アカウント不要、広告なし、データは端末の外に出ません。ミッション 12 種類、12 言語対応。",
    "ko": "앱을 닫아도 잠금 화면에서 울립니다. 계정도 광고도 없고, 데이터는 기기를 떠나지 않습니다. 미션 12가지, 12개 언어.",
    "pt-BR": "Toca na tela bloqueada com o app fechado. Sem conta, sem anúncios, nada sai do seu telefone. Doze missões, doze idiomas.",
    "ru": "Звонит на заблокированном экране, даже когда приложение закрыто. Без аккаунта, без рекламы, ничего не покидает телефон. Двенадцать заданий, двенадцать языков.",
    "zh-Hans": "应用关闭时也会在锁定屏幕响铃。无需账号，没有广告，数据不离开手机。十二种任务，十二种语言。",
}

# The first version. Apple shows this on the update page, so it is written for someone who does
# not have the app yet, not for someone comparing build numbers.
RELEASE_NOTES = {
    "en-US": "First release.\n\nTwelve missions, twenty-five alarms, four difficulties, and a lock screen alarm that comes back if you stop it without doing the mission. Twelve languages. No account, no adverts, nothing leaves your phone.\n\nIf something is wrong, the support page is one tap away in Settings. It gets read.",
    "ar-SA": "الإصدار الأول.\n\nاثنتا عشرة مهمة، خمسة وعشرون منبهاً، أربع درجات صعوبة، ومنبه على شاشة القفل يعود إن أوقفته دون إنجاز المهمة. اثنتا عشرة لغة. بلا حساب، بلا إعلانات، ولا شيء يخرج من هاتفك.\n\nإن وجدت خطأً، صفحة الدعم على بُعد لمسة من الإعدادات. ونحن نقرأ ما يُرسَل.",
    "de-DE": "Erste Version.\n\nZwölf Missionen, 25 Alarme, vier Schwierigkeitsgrade und ein Alarm auf dem Sperrbildschirm, der zurückkommt, wenn du ihn ohne Mission abstellst. Zwölf Sprachen. Kein Konto, keine Werbung, nichts verlässt dein Telefon.\n\nWenn etwas nicht stimmt: Die Support-Seite ist in den Einstellungen einen Tipp entfernt. Sie wird gelesen.",
    "es-ES": "Primera versión.\n\nDoce misiones, veinticinco alarmas, cuatro dificultades y una alarma en la pantalla bloqueada que vuelve si la paras sin hacer la misión. Doce idiomas. Sin cuenta, sin anuncios, nada sale de tu teléfono.\n\nSi algo va mal, la página de soporte está a un toque en Ajustes. Se lee.",
    "fr-FR": "Première version.\n\nDouze missions, vingt-cinq alarmes, quatre difficultés, et une alarme sur l’écran verrouillé qui revient si vous l’arrêtez sans faire la mission. Douze langues. Sans compte, sans publicité, rien ne quitte votre téléphone.\n\nSi quelque chose ne va pas, la page d’assistance est à un geste dans les réglages. Elle est lue.",
    "hi": "पहला रिलीज़।\n\nबारह मिशन, पच्चीस अलार्म, चार कठिनाइयाँ, और लॉक स्क्रीन पर एक ऐसा अलार्म जो मिशन किए बिना रोकने पर लौट आता है। बारह भाषाएँ। कोई अकाउंट नहीं, कोई विज्ञापन नहीं, कुछ भी फ़ोन से बाहर नहीं जाता।\n\nकुछ गड़बड़ हो तो सेटिंग्स से सपोर्ट पेज एक टैप दूर है। वहाँ भेजा संदेश पढ़ा जाता है।",
    "it": "Prima versione.\n\nDodici missioni, venticinque sveglie, quattro difficoltà e una sveglia sulla schermata di blocco che torna se la fermi senza fare la missione. Dodici lingue. Nessun account, nessuna pubblicità, niente lascia il telefono.\n\nSe qualcosa non va, la pagina di assistenza è a un tocco nelle impostazioni. Viene letta.",
    "ja": "最初のリリースです。\n\nミッション 12 種類、アラーム 25 個、難易度 4 段階。ミッションをせずに止めると、ロック画面にもう一度戻ってきます。12 言語対応。アカウント不要、広告なし、データは端末の外に出ません。\n\nうまく動かないときは、設定からサポートページへ 1 タップで行けます。届いたものは読んでいます。",
    "ko": "첫 번째 버전입니다.\n\n미션 12가지, 알람 25개, 난이도 4단계. 미션을 하지 않고 끄면 잠금 화면에 다시 돌아옵니다. 12개 언어. 계정도 광고도 없고, 데이터는 기기를 떠나지 않습니다.\n\n문제가 있다면 설정에서 한 번만 눌러 지원 페이지로 갈 수 있습니다. 보내주신 내용은 읽습니다.",
    "pt-BR": "Primeira versão.\n\nDoze missões, vinte e cinco alarmes, quatro dificuldades e um alarme na tela bloqueada que volta se você parar sem fazer a missão. Doze idiomas. Sem conta, sem anúncios, nada sai do seu telefone.\n\nSe algo estiver errado, a página de suporte está a um toque nos ajustes. Ela é lida.",
    "ru": "Первая версия.\n\nДвенадцать заданий, двадцать пять будильников, четыре уровня сложности и будильник на заблокированном экране, который возвращается, если выключить его без задания. Двенадцать языков. Без аккаунта, без рекламы, ничего не покидает телефон.\n\nЕсли что-то не так, страница поддержки в одном касании из настроек. Её читают.",
    "zh-Hans": "首个版本。\n\n十二种任务、二十五个闹钟、四档难度，以及一个在你不做任务就关掉后会重新出现在锁定屏幕上的闹钟。支持十二种语言。无需账号，没有广告，数据不离开手机。\n\n如果有问题，在设置里一下就能打开支持页面。发过来的内容会有人看。",
}

# What a TestFlight tester reads before they install, in the TestFlight app itself. Two resources
# take it: the app's beta description, which is about the app, and the build's "what to test", which
# is about this build. The same text serves both, because a tester who has just tapped Install wants
# the same four things checked either way.
#
# Written for a tester and not for a customer, which is why it names the bug it fixes and quotes the
# error message word for word: the two reports that produced build 3 both arrived as a screenshot of
# a sentence, and the fastest way to be told the sentence is back is to have shown it here first.
# Every step is one a tester can do in a minute with no account and no seeded data.
TESTFLIGHT_NOTES = {
    "en-US": """Build 3 fixes what the first two got wrong: editing a saved alarm failed with "iOS refused to schedule this alarm", and the Stop button on a ringing alarm ended the morning with no mission at all.

WHAT TO TEST FIRST

1. Edit an alarm. Set one, save it, open it again, change the time and the mission, save again. No error, and it still rings.
2. Press Stop while it rings. The mission opens anyway, and if it is not answered the alarm comes back sixty seconds later.
3. Leave the mission screen, or force quit the app with a mission still owed. The alarm comes straight back.
4. Answer the mission. Only then is the morning over, and nothing rings again.

ALSO WORTH A LOOK

- The twelve missions, at each difficulty, with several rounds.
- A locked phone, silent mode, and a Focus mode. The alarm has to ring through all three.
- Another language: change the iPhone language, then read the alarm and the mission text again.
- The emergency exit in Settings, on by default, and meant to be the only way out without a mission.

If something is wrong, a screenshot of it says more than a sentence about it. Send it back through TestFlight, or through the support page in Settings.""",
    "ar-SA": """يعالج الإصدار 3 ما أخطأ فيه الإصداران الأولان: تعديل منبه محفوظ كان يفشل برسالة «رفض iOS جدولة هذا المنبه»، وزرّ الإيقاف على منبه يرن كان ينهي الصباح دون أي مهمة.

ما يُختبر أولاً

١. عدّل منبهاً. اضبط واحداً واحفظه، ثم افتحه وغيّر الوقت والمهمة واحفظه مرة أخرى. بلا رسالة خطأ، ويظل يرن.
٢. اضغط «إيقاف» أثناء الرنين. تُفتح المهمة على أي حال، وإن لم تُنجَز يعود المنبه بعد ستين ثانية.
٣. اخرج من شاشة المهمة، أو أغلق التطبيق قسراً ومهمة معلّقة. يعود المنبه فوراً.
٤. أنجز المهمة. عندها فقط ينتهي الصباح ولا يرن شيء بعدها.

يستحق النظر أيضاً

- المهام الاثنتا عشرة، بكل درجات الصعوبة، وبعدة جولات.
- هاتف مقفل، والوضع الصامت، ونمط تركيز. على المنبه أن يرن في الحالات الثلاث.
- لغة أخرى: غيّر لغة الآيفون ثم اقرأ شاشة المنبه ونص المهمة من جديد.
- مخرج الطوارئ في الإعدادات، مُفعَّل افتراضياً، والمقصود أن يكون الطريق الوحيد للخروج دون مهمة.

إن وجدت خطأً، فلقطة شاشة له أبلغ من جملة عنه. أرسلها عبر TestFlight أو من صفحة الدعم في الإعدادات.""",
    "de-DE": """Build 3 behebt, was die ersten beiden falsch gemacht haben: Das Bearbeiten eines gespeicherten Alarms scheiterte mit „iOS hat diesen Alarm nicht angenommen“, und der Stopp-Knopf am klingelnden Alarm beendete den Morgen ganz ohne Mission.

WAS ZUERST ZU TESTEN IST

1. Einen Alarm bearbeiten. Stellen, speichern, wieder öffnen, Zeit und Mission ändern, erneut speichern. Kein Fehler, und er klingelt weiterhin.
2. Beim Klingeln auf Stopp drücken. Die Mission öffnet sich trotzdem, und wird sie nicht gelöst, kommt der Alarm sechzig Sekunden später zurück.
3. Den Missionsbildschirm verlassen oder die App beenden, während eine Mission offen ist. Der Alarm kommt sofort zurück.
4. Die Mission lösen. Erst dann ist der Morgen vorbei und es klingelt nichts mehr.

AUCH EINEN BLICK WERT

- Die zwölf Missionen, in jedem Schwierigkeitsgrad, mit mehreren Runden.
- Gesperrtes Telefon, Stummmodus und ein Fokus. Der Alarm muss durch alle drei klingeln.
- Eine andere Sprache: die iPhone-Sprache umstellen und Alarm- und Missionstexte noch einmal lesen.
- Der Notausgang in den Einstellungen, standardmäßig an und als einziger Weg ohne Mission gedacht.

Wenn etwas nicht stimmt, sagt ein Screenshot davon mehr als ein Satz darüber. Schick ihn über TestFlight zurück oder über die Support-Seite in den Einstellungen.""",
    "es-ES": """La versión 3 corrige lo que fallaba en las dos primeras: editar una alarma guardada terminaba en «iOS ha rechazado programar esta alarma», y el botón Detener de una alarma sonando acababa la mañana sin ninguna misión.

QUÉ PROBAR PRIMERO

1. Edita una alarma. Créala, guárdala, vuelve a abrirla, cambia la hora y la misión, guarda otra vez. Sin error, y sigue sonando.
2. Pulsa Detener mientras suena. La misión se abre igualmente, y si no la resuelves la alarma vuelve sesenta segundos después.
3. Sal de la pantalla de la misión, o fuerza el cierre de la app con una misión pendiente. La alarma vuelve al instante.
4. Resuelve la misión. Solo entonces acaba la mañana y no vuelve a sonar nada.

TAMBIÉN MERECE UNA MIRADA

- Las doce misiones, en cada dificultad, con varias rondas.
- Teléfono bloqueado, modo silencio y un modo de concentración. La alarma tiene que sonar en los tres.
- Otro idioma: cambia el idioma del iPhone y vuelve a leer la alarma y el texto de la misión.
- La salida de emergencia en Ajustes, activada por defecto, pensada como la única forma de salir sin misión.

Si algo va mal, una captura dice más que una frase. Envíala por TestFlight o desde la página de soporte en Ajustes.""",
    "fr-FR": """La version 3 corrige ce que les deux premières faisaient mal : modifier une alarme enregistrée échouait avec « iOS a refusé de programmer cette alarme », et le bouton Arrêter d’une alarme qui sonne mettait fin à la matinée sans aucune mission.

À TESTER EN PREMIER

1. Modifier une alarme. En créer une, l’enregistrer, la réouvrir, changer l’heure et la mission, enregistrer à nouveau. Aucune erreur, et elle sonne toujours.
2. Appuyer sur Arrêter pendant qu’elle sonne. La mission s’ouvre quand même, et si elle n’est pas résolue l’alarme revient soixante secondes plus tard.
3. Quitter l’écran de mission, ou forcer la fermeture de l’app avec une mission en cours. L’alarme revient tout de suite.
4. Résoudre la mission. C’est seulement là que la matinée est finie, et plus rien ne sonne.

À REGARDER AUSSI

- Les douze missions, à chaque difficulté, avec plusieurs manches.
- Téléphone verrouillé, mode silencieux, et un mode de concentration. L’alarme doit sonner dans les trois cas.
- Une autre langue : changer la langue de l’iPhone, puis relire l’écran d’alarme et le texte de la mission.
- La sortie d’urgence dans les réglages, activée par défaut, prévue comme le seul moyen de sortir sans mission.

Si quelque chose ne va pas, une capture d’écran en dit plus qu’une phrase. Renvoyez-la par TestFlight, ou par la page d’assistance dans les réglages.""",
    "hi": """बिल्ड 3 उन दो गड़बड़ियों को ठीक करता है जो पहले दो बिल्ड में थीं: सेव किया हुआ अलार्म बदलने पर «iOS ने इस अलार्म को शेड्यूल करने से इनकार कर दिया» आता था, और बजते अलार्म का रोकें बटन बिना कोई मिशन दिए सुबह खत्म कर देता था।

पहले क्या जाँचें

1. अलार्म बदलें। एक बनाएँ, सेव करें, फिर खोलें, समय और मिशन बदलें, दोबारा सेव करें। कोई एरर नहीं, और वह बजता भी है।
2. बजते समय रोकें दबाएँ। मिशन फिर भी खुलता है, और पूरा न करें तो अलार्म साठ सेकंड बाद लौट आता है।
3. मिशन स्क्रीन छोड़ दें, या मिशन बाकी रहते ऐप को बंद कर दें। अलार्म तुरंत लौट आता है।
4. मिशन पूरा करें। तभी सुबह खत्म होती है और फिर कुछ नहीं बजता।

इन पर भी नज़र डालें

- बारह मिशन, हर कठिनाई पर, कई राउंड के साथ।
- लॉक फ़ोन, साइलेंट मोड, और कोई फ़ोकस मोड। अलार्म तीनों में बजना चाहिए।
- दूसरी भाषा: iPhone की भाषा बदलें, फिर अलार्म और मिशन का टेक्स्ट दोबारा पढ़ें।
- सेटिंग्स में इमरजेंसी एक्ज़िट, जो डिफ़ॉल्ट रूप से चालू है और मिशन के बिना निकलने का एकमात्र रास्ता है।

कुछ गलत लगे तो उसका स्क्रीनशॉट एक वाक्य से ज़्यादा बताता है। उसे TestFlight से भेजें, या सेटिंग्स में सपोर्ट पेज से।""",
    "it": """La build 3 corregge quello che sbagliavano le prime due: modificare una sveglia salvata finiva con «iOS ha rifiutato di programmare questa sveglia», e il pulsante Stop su una sveglia che suona chiudeva la mattina senza nessuna missione.

COSA PROVARE PER PRIMO

1. Modifica una sveglia. Creala, salvala, riaprila, cambia ora e missione, salva di nuovo. Nessun errore, e suona ancora.
2. Premi Stop mentre suona. La missione si apre comunque, e se non la risolvi la sveglia torna sessanta secondi dopo.
3. Esci dalla schermata della missione, o chiudi forzatamente l'app con una missione in sospeso. La sveglia torna subito.
4. Risolvi la missione. Solo allora la mattina è finita e non suona più niente.

VALE LA PENA GUARDARE ANCHE

- Le dodici missioni, a ogni difficoltà, con più turni.
- Telefono bloccato, modalità silenziosa e una modalità di concentrazione. La sveglia deve suonare in tutti e tre i casi.
- Un'altra lingua: cambia la lingua dell'iPhone e rileggi la sveglia e il testo della missione.
- L'uscita di emergenza nelle impostazioni, attiva per impostazione predefinita, pensata come l'unico modo di uscire senza missione.

Se qualcosa non va, uno screenshot dice più di una frase. Rimandalo con TestFlight o dalla pagina di assistenza nelle impostazioni.""",
    "ja": """ビルド 3 では、最初の 2 つのビルドの不具合を 2 件直しました。保存済みのアラームを編集すると「iOS がこのアラームの登録を拒否しました」で失敗する問題と、鳴っているアラームの停止ボタンでミッションなしに朝が終わってしまう問題です。

【まず確認してほしいこと】

1. アラームを編集する。作って保存し、開き直して時刻とミッションを変え、もう一度保存する。エラーは出ず、そのまま鳴ること。
2. 鳴っている間に停止を押す。それでもミッションが開き、解かなければ 60 秒後にもう一度鳴ること。
3. ミッション画面から出る、またはミッションが残った状態でアプリを強制終了する。アラームはすぐに戻ってくること。
4. ミッションを解く。そこで初めて朝が終わり、二度と鳴らないこと。

【あわせて見てほしいところ】

- 12 種類のミッション、各難易度、複数ラウンド。
- 画面ロック中、消音モード、集中モード。この 3 つとも鳴る必要があります。
- 別の言語: iPhone の言語を変えて、アラーム画面とミッションの文章をもう一度読む。
- 設定にある緊急脱出。既定でオンで、ミッションなしに抜ける唯一の道として用意しています。

おかしいところがあれば、文章より画面のスクリーンショットのほうが伝わります。TestFlight から、または設定のサポートページから送ってください。""",
    "ko": """빌드 3은 앞선 두 빌드의 문제 두 가지를 고쳤습니다. 저장한 알람을 수정하면 「iOS가 이 알람 등록을 거부했습니다」로 실패하던 문제, 그리고 울리는 알람의 정지 버튼이 미션 없이 아침을 끝내던 문제입니다.

【먼저 확인해 주세요】

1. 알람을 수정합니다. 만들고 저장한 뒤 다시 열어 시간과 미션을 바꾸고 또 저장합니다. 오류가 없고, 여전히 울려야 합니다.
2. 울리는 중에 정지를 누릅니다. 미션은 그래도 열리고, 풀지 않으면 60초 뒤에 알람이 다시 울려야 합니다.
3. 미션 화면에서 나가거나, 미션이 남은 상태로 앱을 강제 종료합니다. 알람은 곧바로 돌아옵니다.
4. 미션을 풉니다. 그때서야 아침이 끝나고 다시 울리지 않습니다.

【함께 봐 주세요】

- 미션 12가지, 각 난이도, 여러 라운드.
- 화면 잠금, 무음 모드, 집중 모드. 세 경우 모두 울려야 합니다.
- 다른 언어: iPhone 언어를 바꾼 뒤 알람 화면과 미션 문장을 다시 읽어 보세요.
- 설정의 비상 탈출. 기본으로 켜져 있고, 미션 없이 빠져나가는 유일한 길로 두었습니다.

이상한 점이 있으면 문장보다 화면 스크린샷이 더 잘 전달됩니다. TestFlight로, 또는 설정의 지원 페이지로 보내 주세요.""",
    "pt-BR": """A build 3 corrige o que as duas primeiras erravam: editar um alarme salvo falhava com «O iOS recusou agendar este alarme», e o botão Parar de um alarme tocando encerrava a manhã sem missão nenhuma.

O QUE TESTAR PRIMEIRO

1. Edite um alarme. Crie, salve, abra de novo, mude a hora e a missão, salve outra vez. Sem erro, e ele continua tocando.
2. Toque em Parar enquanto ele toca. A missão abre de qualquer forma, e se não for resolvida o alarme volta sessenta segundos depois.
3. Saia da tela da missão, ou force o fechamento do app com uma missão pendente. O alarme volta na hora.
4. Resolva a missão. Só então a manhã acaba e nada mais toca.

TAMBÉM VALE OLHAR

- As doze missões, em cada dificuldade, com várias rodadas.
- Telefone bloqueado, modo silencioso e um modo de foco. O alarme tem que tocar nos três.
- Outro idioma: troque o idioma do iPhone e leia de novo o alarme e o texto da missão.
- A saída de emergência nos ajustes, ligada por padrão, feita para ser a única forma de sair sem missão.

Se algo estiver errado, uma captura de tela diz mais que uma frase. Mande de volta pelo TestFlight ou pela página de suporte nos ajustes.""",
    "ru": """Сборка 3 исправляет то, что было не так в первых двух: изменение сохранённого будильника заканчивалось сообщением «iOS отказался запланировать этот будильник», а кнопка «Стоп» на звонящем будильнике заканчивала утро вообще без задания.

ЧТО ПРОВЕРИТЬ В ПЕРВУЮ ОЧЕРЕДЬ

1. Измените будильник. Создайте, сохраните, откройте снова, поменяйте время и задание, сохраните ещё раз. Без ошибки, и он по-прежнему звонит.
2. Нажмите «Стоп» во время звонка. Задание всё равно откроется, и если его не выполнить, будильник вернётся через шестьдесят секунд.
3. Уйдите с экрана задания или закройте приложение принудительно, пока задание не выполнено. Будильник возвращается сразу.
4. Выполните задание. Только тогда утро закончено, и больше ничего не звонит.

НА ЧТО ЕЩЁ СТОИТ ВЗГЛЯНУТЬ

- Двенадцать заданий, на каждом уровне сложности, в несколько раундов.
- Заблокированный телефон, беззвучный режим и режим концентрации. Будильник должен звонить во всех трёх.
- Другой язык: смените язык iPhone и перечитайте экран будильника и текст задания.
- Аварийный выход в настройках: включён по умолчанию и задуман как единственный способ выйти без задания.

Если что-то не так, снимок экрана скажет больше, чем фраза о нём. Пришлите его через TestFlight или через страницу поддержки в настройках.""",
    "zh-Hans": """版本 3 修好了前两个版本的两处问题：编辑已保存的闹钟会失败并提示「iOS 拒绝了该闹钟的排程」；正在响的闹钟按下停止后，早晨就结束了，任务根本没出现。

【请先测试这些】

1. 编辑闹钟。新建、保存，再打开，改时间和任务，再保存一次。不应报错，而且照样会响。
2. 响的时候按停止。任务照样会打开；没做完的话，闹钟应在六十秒后再响。
3. 离开任务界面，或在任务未完成时强制退出应用。闹钟会立刻回来。
4. 把任务做完。只有这时早晨才算结束，之后不会再响。

【也值得看看】

- 十二种任务，每一档难度，多个轮次。
- 锁屏、静音模式，以及专注模式。这三种情况下闹钟都必须响。
- 换一种语言：改掉 iPhone 的语言，再读一遍闹钟界面和任务文字。
- 设置里的紧急退出，默认开启，是不做任务离开的唯一出口。

如果哪里不对，一张截图比一句描述更有用。请通过 TestFlight 或设置里的支持页面发回来。""",
}

# The description. Read on a phone, so the first two lines carry it: the App Store collapses
# everything after about three lines behind "more", and most readers never tap it.
#
# Plain text with blank lines and no markup, because the App Store renders none: a bullet is a
# literal "-" and a heading is a short line in the same size as everything else. The section
# labels are in caps in the languages where caps mean emphasis and left alone in the ones where
# they do not, which is why the Japanese, Korean and Chinese versions use 【】 instead.
DESCRIPTION = {
    "en-US": """You do not oversleep because your alarm is too quiet. You oversleep because stopping it takes one thumb, half a second, and no thought at all.

Dawnbreak takes the thumb out of it. To silence the alarm you have to do something a sleeping person cannot: walk to the kitchen and photograph the kettle, do ten squats in front of the camera, solve arithmetic you would find easy at noon, scan the barcode on a box in another room.

By the time it goes quiet, you are up.

TWELVE MISSIONS

- Math: sums with a time limit, sized to the difficulty you chose
- Squats: counted by the camera, not by you
- Photo: go and photograph a specific object, in a specific place
- Barcode: scan the box you left in the bathroom last night
- Shake: keep shaking until the bar fills
- Steps: walk a set number of steps, counted by the phone
- Pattern: repeat a sequence that gets longer each round
- Typing: type a sentence out, exactly, punctuation and all
- Drawing: draw what it asks for, and it checks
- Memory: find the pairs
- Breathe: sixty seconds of paced breathing before you are let go
- Hold: hold still, phone upright, for longer than you want to

IT DOES NOT LET GO

Stop the alarm without finishing the mission and it comes back a minute later, on the lock screen, under a title that says why. Set as many rounds as you need: one for a weekday, ten for the morning of a flight.

It rings on the lock screen through Apple's own alarm system, so it works with the app closed, the phone locked, and Do Not Disturb on. There is an emergency exit, in Settings, on by default, because an alarm that cannot be stopped is a hazard and not a feature.

EVERY MORNING, WRITTEN DOWN

Ninety days of what actually happened: when you woke, how long the mission took, your streak, and every morning you stopped the alarm without doing the mission. The numbers are unflattering on purpose. That is what makes them useful.

BUILT PROPERLY

- Twelve languages, including right-to-left Arabic, translated rather than machine-processed
- Dark by default, because you read this screen at 6am
- A lock screen widget with the next alarm
- Full VoiceOver support and Dynamic Type
- No account. No sign-in. No adverts. No analytics
- Nothing leaves the phone. There is no server to leave it to

FREE AND PRO

Free: one alarm, one round, three missions, difficulty up to medium.

Pro: twenty-five alarms, up to ten rounds, all twelve missions, all four difficulties, ninety days of history. Monthly, yearly, or a one-time purchase that never renews.

Privacy policy: https://aymane6.github.io/dawnbreak/privacy.html
Support: https://aymane6.github.io/dawnbreak/support.html""",
    "ar-SA": """أنت لا تتأخر في النوم لأن منبهك هادئ. تتأخر لأن إيقافه يحتاج إصبعاً واحداً، ونصف ثانية، وبلا تفكير.

يُخرج Dawnbreak الإصبع من المعادلة. لإسكات المنبه عليك أن تفعل ما لا يقدر عليه نائم: أن تمشي إلى المطبخ وتصوّر الغلاية، أن تؤدي عشر حركات قرفصاء أمام الكاميرا، أن تحل عملية حسابية تراها سهلة في الظهيرة، أن تمسح باركود علبة في غرفة أخرى.

وحين يسكت، تكون قد نهضت.

اثنتا عشرة مهمة

- حساب: عمليات بمهلة زمنية، بحجم يناسب الصعوبة التي اخترتها
- قرفصاء: تعدّها الكاميرا، لا أنت
- صورة: اذهب وصوّر شيئاً محدداً في مكان محدد
- باركود: امسح العلبة التي تركتها في الحمّام ليلة أمس
- رجّ: واصل الرجّ حتى يمتلئ الشريط
- خطوات: امشِ عدداً محدداً من الخطوات، يعدّها الهاتف
- نمط: أعد تسلسلاً يطول في كل جولة
- كتابة: اكتب جملة كما هي، بعلامات ترقيمها
- رسم: ارسم ما يُطلب منك، وهو يتحقق
- ذاكرة: اعثر على الأزواج
- تنفّس: ستون ثانية من التنفّس المنتظم قبل أن يتركك
- ثبات: ابقِ الهاتف قائماً وثابتاً، أطول مما تحب

لا يتركك

أوقف المنبه دون إتمام المهمة، وسيعود بعد دقيقة واحدة على شاشة القفل، بعنوان يقول لك السبب. اضبط عدد الجولات كما تحتاج: واحدة ليوم عمل، وعشر لصباح رحلة طيران.

يرن على شاشة القفل عبر نظام المنبهات في Apple نفسه، فيعمل والتطبيق مغلق، والهاتف مقفل، ووضع عدم الإزعاج مفعّل. وهناك مخرج للطوارئ في الإعدادات، مفعّل افتراضياً، لأن منبهاً لا يمكن إيقافه خطرٌ لا ميزة.

كل صباح، مكتوباً

تسعون يوماً من الذي حدث فعلاً: وقت استيقاظك، والمدة التي استغرقتها المهمة، وسلسلتك، وكل صباح أوقفت فيه المنبه دون إنجاز المهمة. الأرقام غير مُجمِّلة بقصد. وهذا ما يجعلها مفيدة.

مبنيّ كما ينبغي

- اثنتا عشرة لغة، ومنها العربية من اليمين إلى اليسار، مترجمة لا مُمرَّرة على آلة
- داكن افتراضياً، لأنك تقرأ هذه الشاشة في السادسة صباحاً
- أداة على شاشة القفل تُظهر المنبه القادم
- دعم كامل لـ VoiceOver وللنص المتغيّر الحجم
- بلا حساب. بلا تسجيل دخول. بلا إعلانات. بلا تحليلات
- لا شيء يخرج من الهاتف. ولا يوجد أصلاً خادم يخرج إليه

المجاني و Pro

المجاني: منبه واحد، جولة واحدة، ثلاث مهام، وصعوبة حتى المتوسط.

Pro: خمسة وعشرون منبهاً، حتى عشر جولات، كل المهام الاثنتَي عشرة، كل درجات الصعوبة الأربع، وتسعون يوماً من السجل. شهري، أو سنوي، أو شراء لمرة واحدة لا يُجدَّد أبداً.

سياسة الخصوصية: https://aymane6.github.io/dawnbreak/privacy.html
الدعم: https://aymane6.github.io/dawnbreak/support.html""",
    "de-DE": """Du verschläfst nicht, weil dein Wecker zu leise ist. Du verschläfst, weil ihn abzustellen einen Daumen kostet, eine halbe Sekunde und keinen einzigen Gedanken.

Dawnbreak nimmt den Daumen aus der Rechnung. Um den Alarm still zu bekommen, musst du etwas tun, was ein schlafender Mensch nicht kann: in die Küche gehen und den Wasserkocher fotografieren, zehn Kniebeugen vor der Kamera machen, Kopfrechnen lösen, das dir mittags leichtfällt, den Barcode einer Packung im anderen Zimmer scannen.

Wenn es still wird, bist du auf.

ZWÖLF MISSIONEN

- Rechnen: Aufgaben mit Zeitlimit, passend zur gewählten Schwierigkeit
- Kniebeugen: von der Kamera gezählt, nicht von dir
- Foto: einen bestimmten Gegenstand an einem bestimmten Ort fotografieren
- Barcode: die Packung scannen, die du abends im Bad gelassen hast
- Schütteln: weiterschütteln, bis der Balken voll ist
- Schritte: eine festgelegte Zahl von Schritten gehen, vom Telefon gezählt
- Muster: eine Folge wiederholen, die mit jeder Runde länger wird
- Tippen: einen Satz abschreiben, genau, mit Satzzeichen
- Zeichnen: zeichnen, was verlangt wird, und es wird geprüft
- Gedächtnis: die Paare finden
- Atmen: sechzig Sekunden ruhiges Atmen, bevor du freikommst
- Halten: das Telefon aufrecht stillhalten, länger als dir lieb ist

ER LÄSST NICHT LOCKER

Stell den Alarm ohne fertige Mission ab, und er kommt eine Minute später zurück, auf den Sperrbildschirm, mit einem Titel, der sagt warum. Stelle so viele Runden ein, wie du brauchst: eine für einen Werktag, zehn für den Morgen eines Flugs.

Er klingelt über Apples eigenes Alarmsystem auf dem Sperrbildschirm, also bei geschlossener App, gesperrtem Telefon und aktivem Nicht-Störmodus. Es gibt einen Notausgang in den Einstellungen, standardmäßig an, denn ein Alarm, der sich nicht abstellen lässt, ist eine Gefahr und kein Feature.

JEDER MORGEN, AUFGESCHRIEBEN

Neunzig Tage von dem, was wirklich passiert ist: wann du aufgestanden bist, wie lange die Mission gedauert hat, deine Serie, und jeder Morgen, an dem du den Alarm ohne Mission gestoppt hast. Die Zahlen schmeicheln absichtlich nicht. Genau das macht sie brauchbar.

ORDENTLICH GEBAUT

- Zwölf Sprachen, inklusive Arabisch von rechts nach links, übersetzt und nicht durchgeschickt
- Dunkel von Haus aus, weil du diesen Bildschirm um sechs Uhr morgens liest
- Ein Sperrbildschirm-Widget mit dem nächsten Alarm
- Vollständige VoiceOver-Unterstützung und Dynamic Type
- Kein Konto. Kein Login. Keine Werbung. Keine Analytics
- Nichts verlässt das Telefon. Es gibt keinen Server, zu dem es könnte

GRATIS UND PRO

Gratis: ein Alarm, eine Runde, drei Missionen, Schwierigkeit bis mittel.

Pro: 25 Alarme, bis zu zehn Runden, alle zwölf Missionen, alle vier Schwierigkeitsgrade, neunzig Tage Verlauf. Monatlich, jährlich, oder ein Einmalkauf, der sich nie verlängert.

Datenschutz: https://aymane6.github.io/dawnbreak/privacy.html
Support: https://aymane6.github.io/dawnbreak/support.html""",
    "es-ES": """No te quedas dormido porque tu alarma suene poco. Te quedas dormido porque apagarla cuesta un pulgar, medio segundo y ningún pensamiento.

Dawnbreak quita el pulgar de la ecuación. Para silenciar la alarma tienes que hacer algo que una persona dormida no puede: ir a la cocina y fotografiar la tetera, hacer diez sentadillas ante la cámara, resolver cuentas que a mediodía te parecerían fáciles, escanear el código de barras de una caja que está en otra habitación.

Cuando se calla, ya estás de pie.

DOCE MISIONES

- Cálculo: cuentas con tiempo límite, del tamaño de la dificultad que elijas
- Sentadillas: las cuenta la cámara, no tú
- Foto: ve y fotografía un objeto concreto, en un sitio concreto
- Código de barras: escanea la caja que dejaste anoche en el baño
- Agitar: sigue agitando hasta llenar la barra
- Pasos: camina un número fijo de pasos, contados por el teléfono
- Patrón: repite una secuencia que se alarga en cada ronda
- Escribir: copia una frase, exacta, con su puntuación
- Dibujar: dibuja lo que te pide, y lo comprueba
- Memoria: encuentra las parejas
- Respirar: sesenta segundos de respiración pausada antes de soltarte
- Sostener: mantén el teléfono quieto y vertical, más tiempo del que querrías

NO SE RINDE

Para la alarma sin acabar la misión y vuelve un minuto después, en la pantalla bloqueada, con un título que dice por qué. Pon las rondas que necesites: una para un día de semana, diez para la mañana de un vuelo.

Suena en la pantalla bloqueada a través del propio sistema de alarmas de Apple, así que funciona con la app cerrada, el teléfono bloqueado y el modo No molestar activado. Hay una salida de emergencia en Ajustes, activada por defecto, porque una alarma que no se puede parar es un peligro y no una función.

CADA MAÑANA, POR ESCRITO

Noventa días de lo que pasó de verdad: a qué hora despertaste, cuánto tardó la misión, tu racha, y cada mañana en la que paraste la alarma sin hacer la misión. Los números no halagan, y es a propósito. Por eso sirven.

HECHA EN SERIO

- Doce idiomas, incluido el árabe de derecha a izquierda, traducidos y no pasados por una máquina
- Oscuro por defecto, porque esta pantalla la lees a las seis de la mañana
- Un widget en la pantalla bloqueada con la próxima alarma
- Compatibilidad completa con VoiceOver y texto dinámico
- Sin cuenta. Sin iniciar sesión. Sin anuncios. Sin analítica
- Nada sale del teléfono. No hay servidor al que pudiera salir

GRATIS Y PRO

Gratis: una alarma, una ronda, tres misiones, dificultad hasta media.

Pro: veinticinco alarmas, hasta diez rondas, las doce misiones, las cuatro dificultades, noventa días de historial. Mensual, anual, o una compra única que no se renueva nunca.

Privacidad: https://aymane6.github.io/dawnbreak/privacy.html
Soporte: https://aymane6.github.io/dawnbreak/support.html""",
    "fr-FR": """Vous ne dormez pas trop parce que votre réveil est trop discret. Vous dormez trop parce que l’arrêter demande un pouce, une demi-seconde, et aucune réflexion.

Dawnbreak retire le pouce de l’équation. Pour faire taire l’alarme, il faut faire quelque chose qu’une personne endormie ne peut pas faire : aller dans la cuisine et photographier la bouilloire, enchaîner dix squats face caméra, résoudre un calcul qui vous paraîtrait facile à midi, scanner le code-barres d’une boîte laissée dans une autre pièce.

Quand le silence revient, vous êtes debout.

DOUZE MISSIONS

- Calcul : des opérations chronométrées, calibrées sur la difficulté choisie
- Squats : comptés par la caméra, pas par vous
- Photo : allez photographier un objet précis, à un endroit précis
- Code-barres : scannez la boîte laissée dans la salle de bain hier soir
- Secouer : continuez jusqu’à remplir la barre
- Pas : marchez un nombre de pas défini, comptés par le téléphone
- Séquence : répétez une suite qui s’allonge à chaque manche
- Saisie : recopiez une phrase, à l’identique, ponctuation comprise
- Dessin : dessinez ce qui est demandé, et c’est vérifié
- Mémoire : retrouvez les paires
- Respiration : soixante secondes de souffle posé avant d’être libéré
- Immobilité : gardez le téléphone droit et immobile, plus longtemps que vous ne voudriez

ELLE N’ABANDONNE PAS

Arrêtez l’alarme sans finir la mission et elle revient une minute plus tard, sur l’écran verrouillé, avec un titre qui dit pourquoi. Réglez autant de manches qu’il faut : une pour un jour de semaine, dix pour le matin d’un avion.

Elle sonne sur l’écran verrouillé via le système d’alarmes d’Apple, donc app fermée, téléphone verrouillé, mode Ne pas déranger actif. Il existe une sortie d’urgence, dans les réglages, activée par défaut, parce qu’une alarme impossible à arrêter est un danger et non une fonctionnalité.

CHAQUE MATIN, NOTÉ

Quatre-vingt-dix jours de ce qui s’est réellement passé : l’heure du lever, la durée de la mission, votre série, et chaque matin où vous avez arrêté l’alarme sans faire la mission. Les chiffres ne flattent pas, volontairement. C’est ce qui les rend utiles.

FAIT SÉRIEUSEMENT

- Douze langues, dont l’arabe de droite à gauche, traduites et non passées à la machine
- Sombre par défaut, parce que cet écran se lit à six heures du matin
- Un widget d’écran verrouillé avec la prochaine alarme
- Prise en charge complète de VoiceOver et du texte dynamique
- Sans compte. Sans connexion. Sans publicité. Sans analytique
- Rien ne quitte le téléphone. Il n’y a aucun serveur où aller

GRATUIT ET PRO

Gratuit : une alarme, une manche, trois missions, difficulté jusqu’à moyenne.

Pro : vingt-cinq alarmes, jusqu’à dix manches, les douze missions, les quatre difficultés, quatre-vingt-dix jours d’historique. Mensuel, annuel, ou un achat unique qui ne se renouvelle jamais.

Confidentialité : https://aymane6.github.io/dawnbreak/privacy.html
Assistance : https://aymane6.github.io/dawnbreak/support.html""",
    "hi": """आप देर तक इसलिए नहीं सोते कि आपका अलार्म धीमा है। आप इसलिए सोते हैं कि उसे बंद करने में एक अंगूठा, आधा सेकंड और ज़रा भी सोच नहीं लगती।

Dawnbreak उस अंगूठे को हिसाब से हटा देता है। अलार्म चुप कराने के लिए आपको वह करना पड़ता है जो सोया हुआ इंसान नहीं कर सकता: रसोई तक जाकर केतली की फ़ोटो लेना, कैमरे के सामने दस स्क्वैट करना, वह गणित हल करना जो दोपहर में आसान लगता, दूसरे कमरे में रखे डिब्बे का बारकोड स्कैन करना।

जब तक वह चुप होता है, आप उठ चुके होते हैं।

बारह मिशन

- गणित: समय सीमा वाले सवाल, चुनी गई कठिनाई के अनुसार
- स्क्वैट: कैमरा गिनता है, आप नहीं
- फ़ोटो: जाकर किसी निर्दिष्ट जगह पर निर्दिष्ट चीज़ की फ़ोटो लें
- बारकोड: वह डिब्बा स्कैन करें जो आपने रात बाथरूम में छोड़ा था
- हिलाना: बार भरने तक हिलाते रहें
- कदम: तय संख्या में कदम चलें, फ़ोन गिनता है
- पैटर्न: हर राउंड में लंबा होता क्रम दोहराएँ
- टाइपिंग: एक वाक्य ठीक वैसा ही टाइप करें, विराम-चिह्नों सहित
- ड्रॉइंग: जो कहा जाए वह बनाएँ, और यह जाँचता है
- स्मृति: जोड़े खोजें
- सांस: छोड़ने से पहले साठ सेकंड की संतुलित सांस
- स्थिरता: फ़ोन सीधा और स्थिर रखें, अपनी इच्छा से ज़्यादा देर

यह छोड़ता नहीं

मिशन पूरा किए बिना अलार्म रोकें और वह एक मिनट में लौट आता है, लॉक स्क्रीन पर, ऐसे शीर्षक के साथ जो कारण बताता है। जितने राउंड चाहिए रखें: कार्यदिवस के लिए एक, फ़्लाइट वाली सुबह के लिए दस।

यह Apple की अपनी अलार्म प्रणाली से लॉक स्क्रीन पर बजता है, यानी ऐप बंद हो, फ़ोन लॉक हो, डू नॉट डिस्टर्ब चालू हो, तब भी। सेटिंग्स में एक आपातकालीन निकास है, डिफ़ॉल्ट रूप से चालू, क्योंकि जो अलार्म रोका न जा सके वह ख़तरा है, सुविधा नहीं।

हर सुबह, दर्ज

नब्बे दिन का वही जो असल में हुआ: आप कब उठे, मिशन में कितना समय लगा, आपका सिलसिला, और हर वह सुबह जब आपने मिशन किए बिना अलार्म रोक दिया। आँकड़े जानबूझकर चापलूसी नहीं करते। इसी से वे काम के हैं।

ठीक से बनाया गया

- बारह भाषाएँ, दाएँ-से-बाएँ अरबी सहित, अनुवादित, मशीन से निकाली नहीं
- डिफ़ॉल्ट डार्क, क्योंकि यह स्क्रीन आप सुबह छह बजे पढ़ते हैं
- अगले अलार्म वाला लॉक स्क्रीन विजेट
- पूरा VoiceOver समर्थन और डायनेमिक टाइप
- कोई अकाउंट नहीं। कोई साइन-इन नहीं। कोई विज्ञापन नहीं। कोई एनालिटिक्स नहीं
- कुछ भी फ़ोन से बाहर नहीं जाता। जाने के लिए कोई सर्वर ही नहीं है

मुफ़्त और Pro

मुफ़्त: एक अलार्म, एक राउंड, तीन मिशन, कठिनाई मध्यम तक।

Pro: पच्चीस अलार्म, दस राउंड तक, सभी बारह मिशन, सभी चार कठिनाइयाँ, नब्बे दिन का इतिहास। मासिक, वार्षिक, या एक बार की खरीद जो कभी रिन्यू नहीं होती।

गोपनीयता: https://aymane6.github.io/dawnbreak/privacy.html
सहायता: https://aymane6.github.io/dawnbreak/support.html""",
    "it": """Non dormi troppo perché la sveglia suona piano. Dormi troppo perché spegnerla costa un pollice, mezzo secondo e nessun pensiero.

Dawnbreak toglie il pollice dall’equazione. Per far tacere la sveglia devi fare qualcosa che una persona addormentata non può fare: andare in cucina e fotografare il bollitore, fare dieci squat davanti alla fotocamera, risolvere calcoli che a mezzogiorno ti sembrerebbero facili, scansionare il codice a barre di una scatola in un’altra stanza.

Quando torna il silenzio, sei in piedi.

DODICI MISSIONI

- Calcolo: operazioni a tempo, tarate sulla difficoltà scelta
- Squat: li conta la fotocamera, non tu
- Foto: vai a fotografare un oggetto preciso, in un posto preciso
- Codice a barre: scansiona la scatola che hai lasciato in bagno ieri sera
- Scuotere: continua a scuotere finché la barra non si riempie
- Passi: cammina un numero di passi stabilito, contati dal telefono
- Sequenza: ripeti una serie che si allunga a ogni turno
- Digitazione: ricopia una frase, identica, punteggiatura compresa
- Disegno: disegna quello che ti chiede, e viene verificato
- Memoria: trova le coppie
- Respiro: sessanta secondi di respirazione lenta prima di essere lasciato andare
- Fermo: tieni il telefono dritto e immobile, più a lungo di quanto vorresti

NON MOLLA

Ferma la sveglia senza finire la missione e torna dopo un minuto, sulla schermata di blocco, con un titolo che dice perché. Imposta i turni che ti servono: uno per un giorno feriale, dieci per la mattina di un volo.

Suona sulla schermata di blocco tramite il sistema di allarmi di Apple, quindi funziona con l’app chiusa, il telefono bloccato e Non disturbare attivo. C’è un’uscita di emergenza nelle impostazioni, attiva per impostazione predefinita, perché una sveglia che non si può fermare è un pericolo e non una funzione.

OGNI MATTINA, SCRITTA

Novanta giorni di quello che è successo davvero: a che ora ti sei svegliato, quanto è durata la missione, la tua serie, e ogni mattina in cui hai fermato la sveglia senza fare la missione. I numeri non ti lusingano, di proposito. È questo che li rende utili.

FATTA COME SI DEVE

- Dodici lingue, incluso l’arabo da destra a sinistra, tradotte e non passate a una macchina
- Scura per impostazione predefinita, perché questa schermata la leggi alle sei del mattino
- Un widget nella schermata di blocco con la prossima sveglia
- Supporto completo per VoiceOver e testo dinamico
- Nessun account. Nessun accesso. Nessuna pubblicità. Nessuna analisi
- Niente lascia il telefono. Non c’è nemmeno un server dove andare

GRATIS E PRO

Gratis: una sveglia, un turno, tre missioni, difficoltà fino a media.

Pro: venticinque sveglie, fino a dieci turni, tutte le dodici missioni, tutte e quattro le difficoltà, novanta giorni di cronologia. Mensile, annuale, o un acquisto unico che non si rinnova mai.

Privacy: https://aymane6.github.io/dawnbreak/privacy.html
Assistenza: https://aymane6.github.io/dawnbreak/support.html""",
    "ja": """寝坊するのは、アラームの音が小さいからではありません。止めるのに親指ひとつ、半秒、そして何の判断も要らないからです。

Dawnbreak は、その親指を計算から外します。アラームを黙らせるには、眠っている人間にはできないことをする必要があります。台所まで歩いてケトルを撮る。カメラの前でスクワットを 10 回する。昼間なら簡単な計算を解く。別の部屋に置いた箱のバーコードを読み取る。

静かになったときには、もう起きています。

【ミッションは 12 種類】

- 計算：制限時間つきの問題。選んだ難易度に合わせた大きさで
- スクワット：数えるのはカメラで、あなたではありません
- 写真：決められた場所へ行き、決められたものを撮る
- バーコード：昨夜バスルームに置いた箱を読み取る
- シェイク：バーが満たされるまで振り続ける
- 歩数：決められた歩数を歩く。数えるのは端末です
- パターン：ラウンドごとに長くなる並びを再現する
- 入力：文を一字一句、句読点まで写す
- 描く：指示されたものを描く。判定されます
- 記憶：ペアを見つける
- 呼吸：解放される前に、60 秒の落ち着いた呼吸
- 静止：端末を立てたまま、望むより長く静止させる

【逃がしません】

ミッションを終えずに止めると、1 分後にロック画面へ戻ってきます。理由を書いたタイトルつきで。ラウンド数は必要なだけ設定できます。平日なら 1 回、飛行機の朝なら 10 回。

Apple 純正のアラーム機構でロック画面に鳴るので、アプリを閉じていても、端末をロックしていても、集中モード中でも動きます。設定には非常口があり、標準で有効です。止められないアラームは機能ではなく危険だからです。

【毎朝が、記録として残る】

実際に起きたことの 90 日分。起床時刻、ミッションにかかった時間、連続記録、そしてミッションをせずにアラームを止めた朝のすべて。数字はわざと甘くしていません。だから使えます。

【きちんと作ってあります】

- 12 言語対応。右から左に書くアラビア語を含め、機械にかけたのではなく翻訳しています
- 標準でダーク。この画面を読むのは朝 6 時だからです
- 次のアラームを表示するロック画面ウィジェット
- VoiceOver とダイナミックタイプに完全対応
- アカウントなし。ログインなし。広告なし。解析なし
- データは端末の外に出ません。出す先のサーバーがそもそもありません

【無料版と Pro】

無料版：アラーム 1 個、1 ラウンド、ミッション 3 種類、難易度は「ふつう」まで。

Pro：アラーム 25 個、最大 10 ラウンド、ミッション 12 種類すべて、難易度 4 段階すべて、履歴 90 日分。月額、年額、または更新のない買い切り。

プライバシーポリシー：https://aymane6.github.io/dawnbreak/privacy.html
サポート：https://aymane6.github.io/dawnbreak/support.html""",
    "ko": """늦잠을 자는 이유는 알람 소리가 작아서가 아닙니다. 끄는 데 엄지 하나, 반 초, 그리고 아무 판단도 필요하지 않기 때문입니다.

Dawnbreak는 그 엄지를 계산에서 빼버립니다. 알람을 멈추려면 잠든 사람이 할 수 없는 일을 해야 합니다. 부엌까지 걸어가 주전자를 찍고, 카메라 앞에서 스쿼트를 열 번 하고, 낮이라면 쉬웠을 계산을 풀고, 다른 방에 둔 상자의 바코드를 스캔합니다.

조용해질 때쯤이면, 이미 일어나 있습니다.

【미션 12가지】

- 계산: 제한 시간이 있는 문제, 선택한 난이도에 맞춘 크기로
- 스쿼트: 세는 건 카메라이고, 당신이 아닙니다
- 사진: 정해진 장소에 가서 정해진 물건을 찍습니다
- 바코드: 어젯밤 욕실에 둔 상자를 스캔합니다
- 흔들기: 막대가 찰 때까지 계속 흔듭니다
- 걸음: 정해진 걸음 수를 걷습니다. 세는 건 기기입니다
- 패턴: 라운드마다 길어지는 순서를 따라 합니다
- 입력: 문장을 문장부호까지 그대로 옮겨 씁니다
- 그리기: 요구한 것을 그리고, 확인을 받습니다
- 기억: 짝을 찾습니다
- 호흡: 놓아주기 전에 60초의 고른 호흡
- 정지: 기기를 세운 채로, 원하는 시간보다 더 오래 가만히

【봐주지 않습니다】

미션을 끝내지 않고 끄면 1분 뒤 잠금 화면으로 돌아옵니다. 이유를 밝힌 제목과 함께. 라운드는 필요한 만큼 정하세요. 평일에는 한 번, 비행기 타는 아침에는 열 번.

Apple의 알람 시스템으로 잠금 화면에서 울리기 때문에, 앱을 닫아도, 기기를 잠가도, 방해 금지 모드에서도 작동합니다. 설정에는 비상 탈출구가 있고 기본으로 켜져 있습니다. 끌 수 없는 알람은 기능이 아니라 위험이니까요.

【모든 아침이 기록으로 남습니다】

실제로 있었던 90일: 기상 시각, 미션에 걸린 시간, 연속 기록, 그리고 미션을 하지 않고 알람을 끈 모든 아침. 숫자는 일부러 후하게 매기지 않습니다. 그래서 쓸모가 있습니다.

【제대로 만들었습니다】

- 12개 언어. 오른쪽에서 왼쪽으로 쓰는 아랍어까지, 기계에 돌린 것이 아니라 번역했습니다
- 기본은 다크. 이 화면을 읽는 시각이 아침 6시니까요
- 다음 알람을 보여주는 잠금 화면 위젯
- VoiceOver와 동적 텍스트 완전 지원
- 계정 없음. 로그인 없음. 광고 없음. 분석 없음
- 데이터는 기기를 떠나지 않습니다. 떠나 보낼 서버 자체가 없습니다

【무료와 Pro】

무료: 알람 1개, 1라운드, 미션 3가지, 난이도는 보통까지.

Pro: 알람 25개, 최대 10라운드, 미션 12가지 전부, 난이도 4단계 전부, 기록 90일. 월간, 연간, 또는 갱신되지 않는 1회 구매.

개인정보 처리방침: https://aymane6.github.io/dawnbreak/privacy.html
지원: https://aymane6.github.io/dawnbreak/support.html""",
    "pt-BR": """Você não dorme demais porque o alarme é baixo. Você dorme demais porque desligá-lo custa um polegar, meio segundo e nenhum pensamento.

O Dawnbreak tira o polegar da conta. Para silenciar o alarme você tem que fazer algo que uma pessoa dormindo não consegue: ir até a cozinha e fotografar a chaleira, fazer dez agachamentos na frente da câmera, resolver contas que ao meio-dia pareceriam fáceis, escanear o código de barras de uma caixa em outro quarto.

Quando o silêncio chega, você já está de pé.

DOZE MISSÕES

- Cálculo: contas com tempo limite, no tamanho da dificuldade escolhida
- Agachamentos: quem conta é a câmera, não você
- Foto: vá fotografar um objeto específico, em um lugar específico
- Código de barras: escaneie a caixa que você deixou no banheiro ontem à noite
- Sacudir: continue sacudindo até a barra encher
- Passos: caminhe um número definido de passos, contados pelo telefone
- Sequência: repita uma série que fica mais longa a cada rodada
- Digitação: copie uma frase, igual, com pontuação e tudo
- Desenho: desenhe o que for pedido, e ele verifica
- Memória: encontre os pares
- Respiração: sessenta segundos de respiração calma antes de ser liberado
- Firmeza: mantenha o telefone em pé e imóvel, mais tempo do que você gostaria

ELE NÃO DESISTE

Pare o alarme sem terminar a missão e ele volta um minuto depois, na tela bloqueada, com um título que diz por quê. Coloque quantas rodadas precisar: uma para um dia de semana, dez para a manhã de um voo.

Ele toca na tela bloqueada pelo próprio sistema de alarmes da Apple, então funciona com o app fechado, o telefone bloqueado e o Não Perturbe ligado. Existe uma saída de emergência nos ajustes, ligada por padrão, porque um alarme que não pode ser parado é um risco e não um recurso.

CADA MANHÃ, ANOTADA

Noventa dias do que realmente aconteceu: a que hora você acordou, quanto durou a missão, sua sequência, e cada manhã em que você parou o alarme sem fazer a missão. Os números não são gentis, de propósito. É isso que os torna úteis.

FEITO DIREITO

- Doze idiomas, incluindo o árabe da direita para a esquerda, traduzidos e não passados numa máquina
- Escuro por padrão, porque esta tela você lê às seis da manhã
- Um widget na tela bloqueada com o próximo alarme
- Suporte completo a VoiceOver e texto dinâmico
- Sem conta. Sem login. Sem anúncios. Sem analytics
- Nada sai do telefone. Não existe servidor para onde ir

GRÁTIS E PRO

Grátis: um alarme, uma rodada, três missões, dificuldade até média.

Pro: vinte e cinco alarmes, até dez rodadas, todas as doze missões, todas as quatro dificuldades, noventa dias de histórico. Mensal, anual, ou uma compra única que nunca renova.

Privacidade: https://aymane6.github.io/dawnbreak/privacy.html
Suporte: https://aymane6.github.io/dawnbreak/support.html""",
    "ru": """Вы просыпаете не потому, что будильник тихий. Вы просыпаете потому, что выключить его стоит одного большого пальца, полсекунды и ни одной мысли.

Dawnbreak убирает палец из этого уравнения. Чтобы будильник замолчал, нужно сделать то, чего спящий человек не может: дойти до кухни и сфотографировать чайник, сделать десять приседаний перед камерой, решить пример, который в полдень показался бы простым, отсканировать штрих-код коробки в другой комнате.

К тому моменту, как станет тихо, вы уже на ногах.

ДВЕНАДЦАТЬ ЗАДАНИЙ

- Счёт: примеры на время, по размеру выбранной сложности
- Приседания: считает камера, а не вы
- Фото: пойти и сфотографировать определённый предмет в определённом месте
- Штрих-код: отсканировать коробку, оставленную вечером в ванной
- Тряска: трясти, пока не заполнится полоса
- Шаги: пройти заданное число шагов, их считает телефон
- Последовательность: повторить ряд, который удлиняется каждый раунд
- Набор: перепечатать фразу в точности, со знаками препинания
- Рисунок: нарисовать то, что просят, и это проверяется
- Память: найти пары
- Дыхание: шестьдесят секунд ровного дыхания, прежде чем вас отпустят
- Удержание: держать телефон вертикально и неподвижно дольше, чем хочется

ОН НЕ ОТПУСКАЕТ

Выключите будильник, не закончив задание, и он вернётся через минуту, на заблокированный экран, с заголовком, который объясняет почему. Раундов можно поставить сколько нужно: один на будний день, десять на утро перед самолётом.

Он звонит на заблокированном экране через собственную систему будильников Apple, поэтому работает при закрытом приложении, заблокированном телефоне и включённом режиме «Не беспокоить». В настройках есть аварийный выход, включённый по умолчанию: будильник, который нельзя выключить, это опасность, а не функция.

КАЖДОЕ УТРО, ЗАПИСАННОЕ

Девяносто дней того, что было на самом деле: во сколько вы встали, сколько заняло задание, ваша серия и каждое утро, когда вы выключили будильник без задания. Цифры намеренно не льстят. Именно поэтому они полезны.

СДЕЛАНО КАК СЛЕДУЕТ

- Двенадцать языков, включая арабский справа налево, переведённые, а не прогнанные через машину
- Тёмная тема по умолчанию, потому что этот экран читают в шесть утра
- Виджет на заблокированном экране со следующим будильником
- Полная поддержка VoiceOver и динамического текста
- Без аккаунта. Без входа. Без рекламы. Без аналитики
- Ничего не покидает телефон. Просто нет сервера, куда бы это отправлялось

БЕСПЛАТНО И PRO

Бесплатно: один будильник, один раунд, три задания, сложность до средней.

Pro: двадцать пять будильников, до десяти раундов, все двенадцать заданий, все четыре уровня сложности, девяносто дней истории. Ежемесячно, ежегодно или разовая покупка, которая никогда не продлевается.

Конфиденциальность: https://aymane6.github.io/dawnbreak/privacy.html
Поддержка: https://aymane6.github.io/dawnbreak/support.html""",
    "zh-Hans": """你睡过头，不是因为闹钟太轻。是因为关掉它只需要一个拇指、半秒钟，以及完全不用思考。

Dawnbreak 把那个拇指从等式里拿掉。要让闹钟安静下来，你得做一件睡着的人做不到的事：走到厨房拍下水壶，在镜头前做十个深蹲，解一道白天觉得很容易的算式，扫描放在另一个房间里那个盒子上的条码。

等它安静下来的时候，你已经起来了。

【十二种任务】

- 算术：限时题目，大小随你选的难度而变
- 深蹲：由摄像头来数，不是由你来数
- 拍照：走过去，在指定的地方拍下指定的东西
- 条码：扫描你昨晚放在浴室里的那个盒子
- 摇晃：一直摇到进度条填满
- 步数：走完设定的步数，由手机来数
- 序列：重复一段每一轮都变长的顺序
- 打字：把一句话一字不差地抄下来，标点也算
- 画画：按要求画出来，它会判定
- 记忆：找出成对的图案
- 呼吸：放你走之前，先做六十秒平稳呼吸
- 静止：手机竖着不动，比你想坚持的时间更久

【它不会放过你】

没做完任务就关掉，它会在一分钟后回到锁定屏幕，标题会说明原因。轮数由你决定：工作日一轮，赶飞机的早晨十轮。

它通过 Apple 自己的闹钟机制在锁定屏幕响铃，所以应用关闭、手机锁定、开启专注模式时都照样工作。设置里有一个紧急出口，默认开启，因为一个关不掉的闹钟是危险，不是功能。

【每个清晨都留下记录】

九十天里真实发生的事：你几点起床、任务花了多久、连续记录，以及每一个你没做任务就关掉闹钟的早晨。数字故意不讨好你，这才是它有用的地方。

【认真做出来的】

- 十二种语言，包括从右向左书写的阿拉伯语，是翻译的，不是机器过一遍的
- 默认深色，因为你是在早上六点看这个界面
- 锁定屏幕小组件，显示下一个闹钟
- 完整支持旁白与动态字体
- 无需账号。无需登录。没有广告。没有埋点
- 数据不离开手机。压根就没有可以发去的服务器

【免费版与 Pro】

免费版：一个闹钟、一轮、三种任务、难度最高到中等。

Pro：二十五个闹钟、最多十轮、全部十二种任务、全部四档难度、九十天历史。按月、按年，或一次性买断，永不续费。

隐私政策：https://aymane6.github.io/dawnbreak/privacy.html
支持：https://aymane6.github.io/dawnbreak/support.html""",
}

#: Every per-locale table, with the limit App Store Connect enforces and the filename `deliver`
#: expects. The filenames are fastlane's, because that is the layout every upload tool and every
#: reviewer already recognises, and inventing a private one buys nothing.
# How each description writes the number of missions.
#
# Spelled out rather than "12" because that is how the copy reads in eleven of the twelve languages,
# and CJK writes the digit anyway. Kept as a table so `make_metadata.py` can check the claim against
# `MissionKind.allCases` in the Swift: a thirteenth mission then fails the metadata build with a
# list of twelve descriptions to rewrite, instead of shipping twelve listings that undersell it.
MISSION_COUNT = 12

MISSION_COUNT_WORD = {
    "en-US": "TWELVE",
    "ar-SA": "اثنتا عشرة",
    "de-DE": "ZWÖLF",
    "es-ES": "DOCE",
    "fr-FR": "DOUZE",
    "hi": "बारह",
    "it": "DODICI",
    "ja": "12",
    "ko": "12",
    "pt-BR": "DOZE",
    "ru": "ДВЕНАДЦАТЬ",
    "zh-Hans": "十二",
}

# ---------------------------------------------------------------------------
# What the three products are called in the App Store
# ---------------------------------------------------------------------------
#
# Not part of the listing, which is why these are not in FIELDS and get written to no file:
# `scripts/iap.py` sends them straight to App Store Connect, because in-app purchases are their own
# resources there and fastlane's metadata folder has nowhere to put them.
#
# Tighter limits than anything above: 30 characters for a display name and 45 for a description,
# and Apple rejects the product rather than truncating. `iap.py` checks both before its first call.

# The subscription group, which the App Store shows above the two plans. One string, not twelve:
# "Dawnbreak Pro" is a product name, and NAME above already explains why those are not translated.
IAP_GROUP_NAME = "Dawnbreak Pro"

# The name of each plan, under its price. "Pro" and then the period, because the group name is
# already on screen above it: repeating "Dawnbreak" here would spend a third of the thirty
# characters on a word the reader has just read. The period words are the ones the app's own paywall
# uses, so a reader who saw the paywall sees the same word in the confirmation sheet.
IAP_NAME = {
    "monthly": {
        "en-US": "Pro Monthly",
        "ar-SA": "Pro شهري",
        "de-DE": "Pro monatlich",
        "es-ES": "Pro mensual",
        "fr-FR": "Pro mensuel",
        "hi": "Pro मासिक",
        "it": "Pro mensile",
        "ja": "Pro 月額",
        "ko": "Pro 월간",
        "pt-BR": "Pro mensal",
        "ru": "Pro на месяц",
        "zh-Hans": "Pro 按月",
    },
    "yearly": {
        "en-US": "Pro Yearly",
        "ar-SA": "Pro سنوي",
        "de-DE": "Pro jährlich",
        "es-ES": "Pro anual",
        "fr-FR": "Pro annuel",
        "hi": "Pro वार्षिक",
        "it": "Pro annuale",
        "ja": "Pro 年額",
        "ko": "Pro 연간",
        "pt-BR": "Pro anual",
        "ru": "Pro на год",
        "zh-Hans": "Pro 按年",
    },
    "lifetime": {
        "en-US": "Pro Lifetime",
        "ar-SA": "Pro للأبد",
        "de-DE": "Pro für immer",
        "es-ES": "Pro para siempre",
        "fr-FR": "Pro à vie",
        "hi": "Pro हमेशा के लिए",
        "it": "Pro per sempre",
        "ja": "Pro 買い切り",
        "ko": "Pro 평생",
        "pt-BR": "Pro para sempre",
        "ru": "Pro навсегда",
        "zh-Hans": "Pro 永久",
    },
}

# The line under the name, in 45 characters. The three numbers are the real ones from `Entitlement`,
# the same ones the description and the review notes quote, because a purchase sheet that promises
# more than the binary gives is where a 2.3.1 rejection starts. Nothing here mentions the free week
# on the yearly plan: eligibility for an introductory offer depends on the account, so the App Store
# draws it from the offer itself and copy that states it would be wrong for anyone who has had it.
IAP_DESCRIPTION = {
    "en-US": "12 missions, 25 alarms, every difficulty.",
    "ar-SA": "١٢ مهمة، ٢٥ منبهاً، كل الصعوبات.",
    "de-DE": "12 Missionen, 25 Alarme, alle Stufen.",
    "es-ES": "12 misiones, 25 alarmas, 4 dificultades.",
    "fr-FR": "12 missions, 25 alarmes, 4 difficultés.",
    "hi": "12 मिशन, 25 अलार्म, हर कठिनाई।",
    "it": "12 missioni, 25 sveglie, 4 difficoltà.",
    "ja": "ミッション12種、アラーム25個、全難易度。",
    "ko": "미션 12가지, 알람 25개, 모든 난이도.",
    "pt-BR": "12 missões, 25 alarmes, 4 dificuldades.",
    "ru": "12 заданий, 25 будильников, 4 сложности.",
    "zh-Hans": "12种任务、25个闹钟、全部难度。",
}

# The lifetime purchase says what it is instead of how hard it is, because the one question a
# non-consumable has to answer next to two subscriptions is whether it renews.
IAP_DESCRIPTION_LIFETIME = {
    "en-US": "12 missions, 25 alarms. One payment.",
    "ar-SA": "١٢ مهمة، ٢٥ منبهاً. دفعة واحدة.",
    "de-DE": "12 Missionen, 25 Alarme. Einmalig zahlen.",
    "es-ES": "12 misiones, 25 alarmas. Un solo pago.",
    "fr-FR": "12 missions, 25 alarmes. Un seul paiement.",
    "hi": "12 मिशन, 25 अलार्म। एक बार भुगतान।",
    "it": "12 missioni, 25 sveglie. Pagamento unico.",
    "ja": "ミッション12種、アラーム25個。買い切り。",
    "ko": "미션 12가지, 알람 25개. 한 번만 결제.",
    "pt-BR": "12 missões, 25 alarmes. Pagamento único.",
    "ru": "12 заданий, 25 будильников. Один платёж.",
    "zh-Hans": "12种任务、25个闹钟。一次买断。",
}

FIELDS = (
    ("name", NAME, 30),
    ("subtitle", SUBTITLE, 30),
    ("keywords", KEYWORDS, 100),
    ("promotional_text", PROMOTIONAL_TEXT, 170),
    ("description", DESCRIPTION, 4000),
    ("release_notes", RELEASE_NOTES, 4000),
    # TestFlight rather than the store, and in this table anyway: it is per-locale prose with a
    # character limit, which is exactly what the checks in `make_metadata.py` exist for, and
    # `metadata/fr-FR/testflight_notes.txt` is then a file a diff can show like any other.
    ("testflight_notes", TESTFLIGHT_NOTES, 4000),
)

#: Written into every locale folder, identical in all of them: they are URLs, not prose.
SHARED = (
    ("support_url", SUPPORT_URL),
    ("privacy_url", PRIVACY_URL),
    ("marketing_url", MARKETING_URL),
)

#: The product tables, in the same (name, table, limit) shape as FIELDS. These are written to no
#: file, so without this nothing but App Store Connect would ever check them: `scripts/iap.py`
#: reads it before its first call and `scripts/asc-preflight.py` reads it without a network.
PRODUCT_FIELDS = (
    ("iap_name/monthly", IAP_NAME["monthly"], 30),
    ("iap_name/yearly", IAP_NAME["yearly"], 30),
    ("iap_name/lifetime", IAP_NAME["lifetime"], 30),
    ("iap_description", IAP_DESCRIPTION, 45),
    ("iap_description/lifetime", IAP_DESCRIPTION_LIFETIME, 45),
)
