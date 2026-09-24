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

Nothing in the app is for sale, so nothing here quotes a price, a plan or a limit that a purchase
would lift. What the descriptions do quote are the numbers the binary really enforces: 12 missions,
4 difficulties, up to 10 rounds and 90 days of history. Apple rejects a listing that promises more
than the binary delivers, and `scripts/asc-preflight.py` checks these numbers against the source.
"""

# The listing's own URLs, on the app's own domain. The same generated `docs/` folder is served from
# S3 behind CloudFront by `infra/` rather than by GitHub Pages: a privacy policy has to be reachable
# by a reviewer who is not logged in to anything, and the terms page is linked from Settings and
# from the description even though nothing is sold, because it is where the safety wording lives.
#
# `.app` is in the HSTS preload list, so these are https or they are nothing, which is exactly the
# property a legal URL wants. The `.html` is kept even though the distribution rewrites extensionless
# paths: the literal filename works on any host, and a fallback that needs a CloudFront function to
# be correct is not a fallback.
SITE_URL = "https://dawnbreak.app/"
SUPPORT_URL = "https://dawnbreak.app/support.html"
PRIVACY_URL = "https://dawnbreak.app/privacy.html"
TERMS_URL = "https://dawnbreak.app/terms.html"
MARKETING_URL = SITE_URL
# The rights holder as the account that publishes the app spells it: the distribution certificate
# reads "Apple Distribution: Aymane BAMHAMED". This line is printed on the store page and at the
# foot of all twelve HTML pages, so it names the person Apple pays and not an approximation.
COPYRIGHT = "2026 Aymane Bamhamed"

# Under the icon in search results and on the home screen. "Dawnbreak" stays in every language:
# it is the name the app is reviewed and searched under, and a translated app name splits its own
# reputation across twelve strings. What is translated is the descriptor after it, which is what a
# reader scanning a search result actually reads.
NAME = {
    "en-US": "Dawnbreak: Mission Alarm Clock",
    "ar-SA": "Dawnbreak: منبه المهام",
    "de-DE": "Dawnbreak: Wecker mit Aufgaben",
    "es-ES": "Dawnbreak: Alarma Despertador",
    "fr-FR": "Dawnbreak : Réveil Mission",
    "hi": "Dawnbreak: मिशन अलार्म घड़ी",
    "it": "Dawnbreak: Sveglia con sfide",
    "ja": "Dawnbreak 目覚まし時計・ミッションアラーム",
    "ko": "Dawnbreak: 미션 알람 시계",
    "pt-BR": "Dawnbreak: Alarme Despertador",
    "ru": "Dawnbreak Будильник с заданием",
    "zh-Hans": "Dawnbreak 起床任务闹钟",
}

# The line under the name, in the same 30 characters. The name already says it is an alarm clock
# with missions, so this line is for the reader: someone who sleeps through ordinary alarms. Where a
# language has the word people search for that (Tiefschläfer, gros dormeurs, dormiglione, 寝坊), it
# is here, because the subtitle is indexed like the keywords; where it has none, the line says what
# waking up with the app means instead.
SUBTITLE = {
    "en-US": "Heavy sleeper? Time to wake up",
    "ar-SA": "إيقاظ قوي لأصحاب النوم الثقيل",
    "de-DE": "Tiefschläfer? Jetzt aufwachen",
    "es-ES": "Misión: despertar de verdad",
    "fr-FR": "Pensé pour les gros dormeurs",
    "hi": "उठिए, भले नींद गहरी हो",
    "it": "Dormiglione? È ora di alzarsi",
    "ja": "寝坊・二度寝防止。起きれる朝へ",
    "ko": "잠 많은 사람을 위한 기상 루틴",
    "pt-BR": "Desafios para acordar de vez",
    "ru": "Проснуться и встать с кровати",
    "zh-Hans": "叫醒爱赖床的你，做完才停",
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
    "en-US": "loud,math,puzzle,task,challenge,game,barcode,qr,scan,squat,snooze,oversleep,deep,morning,photo,shake",
    "ar-SA": "استيقاظ,صباح,الفجر,ساعة,تحدي,حساب,رياضيات,صورة,باركود,تأجيل,غفوة,رنات,لعبة,خطوات,تأخر,صوت,عالي,رج,qr",
    "de-DE": "aufstehen,alarm,laut,extrem,mission,foto,barcode,rechnen,snooze,früh,pünktlich,töne,spiel,schlummern",
    "es-ES": "fuerte,retos,matemáticas,foto,código,barras,escanear,posponer,tonos,dormilones,sueño,pesado,juego,qr",
    "fr-FR": "alarme,matin,défi,calcul,photo,lever,snooze,fort,scan,squat,sonnerie,jeu,retard,code,barre,lit,maths",
    "hi": "जागना,सुबह,तेज़,आवाज़,स्नूज़,स्क्वैट,बारकोड,फ़ोटो,गणित,गेम,चुनौती,आदत,देर,जल्दी,रिंगटोन,कदम,पहेली",
    "it": "missioni,forte,foto,matematica,ritardo,snooze,allarme,barcode,gioco,suoneria,presto,mattina,sonno,qr",
    "ja": "計算,大音量,爆音,早起き,起床,朝活,写真,スクワット,バーコード,スヌーズ,起きる,遅刻,習慣,ゲーム,脳トレ,パズル,振る,歩数,寝起き,連続,記憶,呼吸,お絵かき,QR,起こす,タイピング",
    "ko": "늦잠,소리,큰,계산,수학,사진,스쿼트,바코드,흔들기,퍼즐,게임,챌린지,도전,아침,모닝콜,깨우기,지각,습관,위젯,일어나기,걸음,호흡,기억력,그리기,타이핑,연속,QR,시끄러운,방지",
    "pt-BR": "missão,sono,pesado,alto,matemática,foto,soneca,cedo,jogo,toque,manhã,código,barras,levantar,cama,qr",
    "ru": "громкий,примерами,задачами,математика,фото,подъём,сирена,игра,штрихкод,мелодии,утро,соня,рано,qr,сон",
    "zh-Hans": "铃声,大声,早起,强制,打卡,贪睡,小睡,算术,数学,深蹲,条码,扫码,二维码,拍照,摇一摇,步数,游戏,挑战,迟到,睡过头,习惯,困难户,醒来,早上,响铃,记忆,呼吸,涂鸦,打字,小组件,连续,闹铃",
}

# Above the description, and changeable without submitting a build. It leads with the one thing no
# ordinary alarm clock does, the ring that comes back a minute after a stop without the mission, and
# then answers what a free app is asked before anyone installs it: what the catch is, whether there
# is an account, and where the data goes.
PROMOTIONAL_TEXT = {
    "en-US": "Stop the alarm without the mission and it rings again a minute later. Twelve missions, twelve languages, nothing to buy. No account, no ads, nothing leaves your phone.",
    "ar-SA": "أوقف المنبه دون إنجاز المهمة، وسيرن مجدداً بعد دقيقة. اثنتا عشرة مهمة، واثنتا عشرة لغة، ولا شيء للشراء. بلا حساب، بلا إعلانات، ولا شيء يخرج من هاتفك.",
    "de-DE": "Ohne Mission gestoppt? Eine Minute später klingelt er wieder. Zwölf Missionen, zwölf Sprachen, nichts zu kaufen. Kein Konto, keine Werbung, nichts verlässt dein Telefon.",
    "es-ES": "Si la apagas sin hacer la misión, vuelve a sonar un minuto después. Doce misiones, doce idiomas, nada que comprar. Sin cuenta, sin anuncios, nada sale de tu teléfono.",
    "fr-FR": "Arrêtez l’alarme sans la mission : elle revient une minute plus tard. Douze missions, douze langues, rien à acheter. Sans compte ni publicité, rien ne sort du téléphone.",
    "hi": "मिशन किए बिना अलार्म बंद करेंगे, तो एक मिनट बाद यह फिर बजेगा। बारह मिशन, बारह भाषाएँ, ख़रीदने को कुछ नहीं। न अकाउंट, न विज्ञापन, कुछ भी फ़ोन से बाहर नहीं जाता।",
    "it": "Spenta senza la missione, suona di nuovo un minuto dopo. Dodici missioni, dodici lingue, niente da comprare. Nessun account né pubblicità, niente lascia il telefono.",
    "ja": "ミッションを終えずに止めると、1分後にまた鳴ります。ミッション12種類、12言語対応、購入するものはありません。アカウント不要、広告なし、データは端末の外に出ません。",
    "ko": "미션을 끝내지 않고 끄면 1분 뒤에 다시 울립니다. 미션 12가지, 12개 언어, 살 것은 없습니다. 계정도 광고도 없고, 데이터는 기기를 떠나지 않습니다.",
    "pt-BR": "Desligou o alarme sem fazer a missão? Ele toca de novo um minuto depois. Doze missões, doze idiomas, nada para comprar. Sem conta, sem anúncios, nada sai do seu telefone.",
    "ru": "Выключите его без задания, и через минуту он зазвонит снова. Двенадцать заданий, двенадцать языков, покупать нечего. Без аккаунта и рекламы, ничего не покидает телефон.",
    "zh-Hans": "没做完任务就关掉闹钟，一分钟后它会再响。十二种任务，十二种语言，没有任何东西要买。无需账号，没有广告，数据不离开手机。",
}

# The first version. Apple shows this on the update page, so it is written for someone who does
# not have the app yet, not for someone comparing build numbers.
RELEASE_NOTES = {
    "en-US": "First release.\n\nDawnbreak is an alarm clock you stop by completing a mission: twelve of them, four difficulties, up to ten rounds. Stop it without the mission and it rings again a minute later. Twelve languages. Free: nothing to buy, no account, no ads, and nothing leaves your phone.\n\nIf something is wrong, Settings has a “Contact support” link that opens an email, and the support page is linked on this page. Messages get read.",
    "ar-SA": "الإصدار الأول.\n\nمنبه Dawnbreak يتوقف حين تُنجز مهمة: اثنتا عشرة مهمة، وأربع درجات صعوبة، وحتى عشر جولات. أوقفه دون المهمة وسيرن من جديد بعد دقيقة. اثنتا عشرة لغة. مجاني: لا شيء للشراء، بلا حساب، بلا إعلانات، ولا شيء يخرج من هاتفك.\n\nإن وجدت خطأً، ففي الإعدادات رابط «التواصل مع الدعم» يفتح رسالة بريد إلكتروني، ورابط صفحة الدعم موجود في هذه الصفحة. ونحن نقرأ ما يُرسَل.",
    "de-DE": "Erste Version.\n\nDawnbreak ist ein Wecker, den du abstellst, indem du eine Mission erledigst: zwölf zur Auswahl, vier Schwierigkeitsgrade, bis zu zehn Runden. Stellst du ihn ohne Mission ab, klingelt er eine Minute später wieder. Zwölf Sprachen. Gratis: nichts zu kaufen, kein Konto, keine Werbung, und nichts verlässt dein Telefon.\n\nWenn etwas nicht stimmt: In den Einstellungen öffnet der Link „Support kontaktieren“ eine E-Mail, und die Support-Seite ist auf dieser Seite verlinkt. Nachrichten werden gelesen.",
    "es-ES": "Primera versión.\n\nDawnbreak es una alarma que se apaga completando una misión: doce para elegir, cuatro dificultades y hasta diez rondas. Si la apagas sin hacer la misión, vuelve a sonar un minuto después. Doce idiomas. Gratis: nada que comprar, sin cuenta, sin anuncios y nada sale de tu teléfono.\n\nSi algo va mal, en Ajustes hay un enlace «Contactar con soporte» que abre un correo, y la página de soporte está enlazada en esta misma página. Los mensajes se leen.",
    "fr-FR": "Première version.\n\nDawnbreak est un réveil que vous arrêtez en accomplissant une mission : douze au choix, quatre difficultés, jusqu’à dix manches. Arrêtée sans la mission, l’alarme sonne de nouveau une minute plus tard. Douze langues. Gratuit : rien à acheter, pas de compte, pas de publicité, et rien ne quitte votre téléphone.\n\nSi quelque chose ne va pas, dans les Réglages, le lien « Contacter le support » ouvre un e-mail, et un lien vers la page d’assistance figure sur cette page. Les messages sont lus.",
    "hi": "पहला रिलीज़।\n\nDawnbreak एक ऐसा अलार्म है जिसे आप एक मिशन पूरा करके बंद करते हैं: चुनने को बारह मिशन, चार कठिनाइयाँ, 10 राउंड तक। मिशन के बिना बंद करेंगे, तो एक मिनट बाद यह फिर बजेगा। बारह भाषाएँ। मुफ़्त: ख़रीदने को कुछ नहीं, न अकाउंट, न विज्ञापन, और कुछ भी फ़ोन से बाहर नहीं जाता।\n\nकुछ गड़बड़ हो, तो सेटिंग में “सहायता से संपर्क करें” लिंक है जो ईमेल खोलता है, और सहायता पेज का लिंक इसी पेज पर है। वहाँ भेजा संदेश पढ़ा जाता है।",
    "it": "Prima versione.\n\nDawnbreak è una sveglia che si spegne completando una missione: dodici tra cui scegliere, quattro difficoltà, fino a dieci turni. Se la spegni senza la missione, suona di nuovo un minuto dopo. Dodici lingue. Gratis: niente da comprare, nessun account, nessuna pubblicità, e niente lascia il telefono.\n\nSe qualcosa non va, in Impostazioni c’è il link «Contatta l’assistenza» che apre un’email, e la pagina di assistenza è collegata in questa stessa pagina. I messaggi vengono letti.",
    "ja": "最初のリリースです。\n\nDawnbreak は、ミッションをクリアして止める目覚まし時計です。ミッションは12種類、難易度は4段階、最大10ラウンド。ミッションをせずに止めると、1分後にまた鳴ります。12言語対応。無料です。購入するものはなく、アカウント不要、広告なし。データは端末の外に出ません。\n\nうまく動かないときは、設定の「サポートに連絡」からメールを送れます。サポートページへのリンクもこのページにあります。届いたものは読んでいます。",
    "ko": "첫 번째 버전입니다.\n\nDawnbreak는 미션을 완료해야 꺼지는 알람 시계입니다. 미션 12가지, 난이도 4단계, 최대 10라운드. 미션을 끝내지 않고 끄면 1분 뒤에 다시 울립니다. 12개 언어. 무료입니다. 살 것도, 계정도, 광고도 없고, 데이터는 기기를 떠나지 않습니다.\n\n문제가 있다면 설정의 ‘지원팀에 문의’ 링크로 이메일을 보낼 수 있고, 지원 페이지 링크는 이 페이지에 있습니다. 보내주신 내용은 읽습니다.",
    "pt-BR": "Primeira versão.\n\nO Dawnbreak é um alarme que você desliga cumprindo uma missão: doze para escolher, quatro dificuldades, até dez rodadas. Desligou sem fazer a missão? Ele toca de novo um minuto depois. Doze idiomas. Grátis: nada para comprar, sem conta, sem anúncios, e nada sai do seu telefone.\n\nSe algo estiver errado, em Ajustes há o link “Falar com o suporte”, que abre um e-mail, e a página de suporte tem link nesta página. As mensagens são lidas.",
    "ru": "Первая версия.\n\nВ Dawnbreak будильник выключается выполнением задания: двенадцать на выбор, четыре уровня сложности, до десяти раундов. Выключите его без задания, и через минуту он зазвонит снова. Двенадцать языков. Бесплатно: покупать нечего, без аккаунта, без рекламы, и ничего не покидает телефон.\n\nЕсли что-то не так, в Настройках есть ссылка «Связаться с поддержкой», которая открывает письмо, а ссылка на страницу поддержки есть на этой странице. Письма читают.",
    "zh-Hans": "首个版本。\n\nDawnbreak 是一个要完成任务才能关掉的闹钟：十二种任务、四档难度、最多十轮。没做完任务就关掉，一分钟后它会再响。支持十二种语言。免费：没有任何东西要买，无需账号，没有广告，数据不离开手机。\n\n如果有问题，设置里的“联系支持”链接会打开一封邮件，支持页面的链接就在本页。发过来的内容会有人看。",
}

# What a TestFlight tester reads before they install, in the TestFlight app itself. Two resources
# take it: the app's beta description, which is about the app, and the build's "what to test", which
# is about this build. The same text serves both, because a tester who has just tapped Install wants
# the same few things checked either way.
#
# Written for a tester and not for a customer: what changed in this build, then steps a tester can do
# in a minute with no account and no seeded data. Rewritten for every build that goes out, because
# notes about an older build send testers looking for a change that is not there.
TESTFLIGHT_NOTES = {
    "en-US": """Build 12 is the one going back to App Review, so most of it is about the first minute and the mission screens.

WHAT CHANGED
- The screen before the alarm permission has a single button, Continue. The choice is made in the iOS alert, and the app works with either answer.
- “Set my first alarm”, the last onboarding button, now opens the alarm editor.
- Settings keeps only what does something. The app is always dark.
- Typing: no Check button. The round clears on the keystroke that completes the sentence.
- Draw: after two misses it says what it saw instead, and offers something else to draw.
- In Arabic, sums are no longer shown back to front.
- Deleting an alarm asks first.

WORTH CHECKING
1. Delete the app and install this build. Two screens with Next, then one with Continue and nothing else. Answer the alert either way, then tap “Set my first alarm”: the editor opens, and closing it, saved or not, must leave you on the alarm list.
2. Set an alarm two minutes ahead, lock the phone, and when it rings press the button with the mission's name.
3. Next time, press Stop instead: the alarm must come back a minute later.
4. When an alarm rings, the X in the corner asks before it lets you go; from “Try this mission” it closes at once.
5. Anything cut off, overlapping or in the wrong language: a screenshot is the best report.""",
    "ar-SA": """الإصدار 12 هو الذي يعود إلى مراجعة Apple، لذا يتعلق معظمه بالدقيقة الأولى وبشاشات المهام.

ما الذي تغيّر
- الشاشة التي تسبق إذن المنبهات فيها زر واحد: «متابعة». الاختيار يتم في تنبيه iOS، والتطبيق يعمل مهما كان الجواب.
- زر «اضبط أول منبه»، آخر أزرار التعريف بالتطبيق، يفتح الآن محرر المنبه.
- الإعدادات لا تحتفظ إلا بما له أثر. التطبيق داكن دائماً.
- الكتابة: لا زر «تحقق» بعد الآن. تُنجز الجولة مع الضغطة التي تُكمل الجملة.
- الرسم: بعد محاولتين فاشلتين يقول ما رآه بدلاً من ذلك، ويقترح رسماً آخر.
- بالعربية، لم تعد العمليات الحسابية تظهر معكوسة.
- حذف منبه يطلب التأكيد أولاً.

يستحق التحقق
١. احذف التطبيق وثبّت هذا الإصدار. شاشتان فيهما «التالي»، ثم شاشة ليس فيها سوى «متابعة». أجب على التنبيه كما تشاء، ثم اضغط «اضبط أول منبه»: يُفتح المحرر، وعند إغلاقه، بالحفظ أو بدونه، يجب أن تصل إلى قائمة المنبهات.
٢. اضبط منبهاً بعد دقيقتين، واقفل الهاتف، وعندما يرن اضغط الزر الذي يحمل اسم المهمة.
٣. في المرة التالية اضغط «إيقاف» بدلاً من ذلك: يجب أن يعود المنبه بعد دقيقة.
٤. عندما يرن منبه، تطلب علامة X في الزاوية التأكيد قبل أن تتركك؛ ومن «جرّب هذه المهمة» تُغلق فوراً.
٥. أي نص مقطوع أو متداخل أو بلغة خاطئة: لقطة شاشة هي أفضل بلاغ.""",
    "de-DE": """Build 12 geht zurück in die App-Prüfung, deshalb geht es vor allem um die erste Minute und um die Missionsbildschirme.

WAS SICH GEÄNDERT HAT
- Der Bildschirm vor der Alarm-Berechtigung hat nur noch eine Taste: Weiter. Die Entscheidung fällt in der iOS-Abfrage, und die App funktioniert mit beiden Antworten.
- „Ersten Alarm stellen“, die letzte Taste der Einführung, öffnet jetzt den Alarm-Editor.
- In den Einstellungen bleibt nur, was etwas bewirkt. Die App ist immer dunkel.
- Tippen: keine Prüfen-Taste mehr. Die Runde gilt mit dem Anschlag, der den Satz vollendet.
- Zeichnen: Nach zwei Fehlversuchen sagt die App, was sie stattdessen gesehen hat, und bietet etwas anderes zum Zeichnen an.
- Auf Arabisch stehen Rechenaufgaben nicht mehr verkehrt herum.
- Das Löschen eines Alarms fragt vorher nach.

WAS DU PRÜFEN SOLLTEST
1. Lösche die App und installiere diesen Build. Zwei Bildschirme mit Weiter, dann der Bildschirm zur Berechtigung, der nur Weiter anbietet. Beantworte die Abfrage, wie du willst, und tippe dann auf „Ersten Alarm stellen“: Der Editor öffnet sich, und wenn du ihn schließt, gespeichert oder nicht, musst du bei der Alarmliste landen.
2. Stell einen Alarm auf zwei Minuten später, sperr das Telefon und drück beim Klingeln die Taste mit dem Namen der Mission.
3. Beim nächsten Mal drück stattdessen Stopp: Der Alarm muss eine Minute später zurückkommen.
4. Wenn ein Alarm klingelt, fragt das X in der Ecke nach, bevor es dich gehen lässt; bei „Diese Mission ausprobieren“ schließt es sofort.
5. Abgeschnittener, überlappender oder anderssprachiger Text: Ein Screenshot ist die beste Meldung.""",
    "es-ES": """La build 12 es la que vuelve a la revisión de Apple, así que casi todo tiene que ver con el primer minuto y con las pantallas de misión.

QUÉ HA CAMBIADO
- La pantalla previa al permiso de alarmas tiene un solo botón, Continuar. La decisión se toma en el aviso de iOS, y la app funciona con cualquiera de las dos respuestas.
- «Crear mi primera alarma», el último botón de la presentación, ahora abre el editor de alarmas.
- Ajustes solo conserva lo que hace algo. La app es siempre oscura.
- Escritura: ya no hay botón Comprobar. La ronda se supera con la pulsación que completa la frase.
- Dibujo: tras dos fallos dice qué ha visto en su lugar y propone otra cosa que dibujar.
- En árabe, las operaciones ya no se muestran al revés.
- Borrar una alarma pide confirmación.

QUÉ COMPROBAR
1. Borra la app e instala esta build. Dos pantallas con Siguiente y luego una que solo ofrece Continuar. Responde al aviso como quieras y pulsa «Crear mi primera alarma»: se abre el editor y, al cerrarlo, guardes o no, tienes que acabar en la lista de alarmas.
2. Pon una alarma dos minutos más tarde, bloquea el teléfono y, cuando suene, pulsa el botón con el nombre de la misión.
3. La siguiente vez pulsa Parar: la alarma debe volver un minuto después.
4. Cuando suena una alarma, la X de la esquina pide confirmación antes de dejarte ir; desde «Probar esta misión» cierra al instante.
5. Texto cortado, superpuesto o en otro idioma: una captura de pantalla es el mejor aviso.""",
    "fr-FR": """Le build 12 est celui qui repart en revue chez Apple : l’essentiel touche la première minute et les écrans de mission.

CE QUI CHANGE
- L’écran qui précède l’autorisation des alarmes n’a plus qu’un bouton, Continuer. Le choix se fait dans l’alerte d’iOS, et l’app fonctionne quelle que soit la réponse.
- « Créer ma première alarme », le dernier bouton de la présentation, ouvre maintenant l’éditeur d’alarme.
- Les réglages ne gardent que ce qui sert. L’app est toujours en mode sombre.
- Frappe : plus de bouton Vérifier. La manche est validée à la frappe qui termine la phrase.
- Dessin : après deux échecs, l’app dit ce qu’elle a vu à la place et propose autre chose à dessiner.
- En arabe, les calculs ne s’affichent plus à l’envers.
- Supprimer une alarme demande confirmation.

À VÉRIFIER
1. Supprimez l’app et installez ce build. Deux écrans avec Suivant, puis un écran qui ne propose que Continuer. Répondez à l’alerte comme vous voulez, puis touchez « Créer ma première alarme » : l’éditeur s’ouvre, et en le fermant, avec ou sans enregistrer, vous devez arriver sur la liste des alarmes.
2. Réglez une alarme deux minutes plus tard, verrouillez le téléphone et, quand elle sonne, touchez le bouton qui porte le nom de la mission.
3. La fois suivante, touchez plutôt Arrêter : l’alarme doit revenir une minute plus tard.
4. Quand une alarme sonne, la croix dans le coin demande confirmation avant de vous laisser partir ; depuis « Essayer cette mission », elle ferme tout de suite.
5. Un texte coupé, superposé ou dans la mauvaise langue : une capture d’écran est le meilleur signalement.""",
    "hi": """बिल्ड 12 वही है जो ऐप रिव्यू में वापस जा रहा है, इसलिए ज़्यादातर बदलाव पहले मिनट और मिशन स्क्रीन से जुड़े हैं।

क्या बदला
- अलार्म की अनुमति से पहले वाली स्क्रीन पर अब सिर्फ़ एक बटन है: जारी रखें। फ़ैसला iOS के अलर्ट में होता है, और ऐप दोनों जवाबों के साथ काम करता है।
- ऑनबोर्डिंग का आख़िरी बटन, “मेरा पहला अलार्म सेट करें”, अब अलार्म एडिटर खोलता है।
- सेटिंग्स में सिर्फ़ वही बचा है जो सचमुच कुछ करता है। ऐप हमेशा डार्क रहता है।
- टाइपिंग: अब जाँचें बटन नहीं है। वाक्य पूरा करने वाली कुंजी दबते ही राउंड पूरा हो जाता है।
- चित्र: दो बार चूकने के बाद ऐप बताता है कि उसे इसकी जगह क्या दिखा, और कुछ और बनाने का विकल्प देता है।
- अरबी में सवाल अब उल्टे नहीं दिखते।
- अलार्म हटाने से पहले पुष्टि माँगी जाती है।

क्या जाँचें
1. ऐप हटाएँ और यह बिल्ड इंस्टॉल करें। दो स्क्रीन पर आगे है, फिर एक स्क्रीन पर सिर्फ़ जारी रखें। अलर्ट का जवाब जैसे चाहें दें, फिर “मेरा पहला अलार्म सेट करें” दबाएँ: एडिटर खुलता है, और उसे बंद करने पर, सेव करें या नहीं, आपको अलार्म सूची पर पहुँचना चाहिए।
2. दो मिनट बाद का अलार्म लगाएँ, फ़ोन लॉक करें, और बजने पर मिशन के नाम वाला बटन दबाएँ।
3. अगली बार इसके बजाय रोकें दबाएँ: अलार्म एक मिनट बाद लौटना चाहिए।
4. अलार्म बजने पर, कोने का X जाने देने से पहले पुष्टि माँगता है; “यह मिशन आज़माएँ” में यह तुरंत बंद हो जाता है।
5. कटा हुआ, एक-दूसरे पर चढ़ा या गलत भाषा में कोई टेक्स्ट: स्क्रीनशॉट सबसे अच्छी रिपोर्ट है।""",
    "it": """La build 12 è quella che torna alla revisione di Apple, quindi riguarda soprattutto il primo minuto e le schermate delle missioni.

COSA CAMBIA
- La schermata prima del permesso per le sveglie ha un solo pulsante, Continua. La scelta si fa nell’avviso di iOS, e l’app funziona con entrambe le risposte.
- «Crea la mia prima sveglia», l’ultimo pulsante della presentazione, ora apre l’editor della sveglia.
- Le impostazioni tengono solo ciò che serve. L’app è sempre scura.
- Digitazione: niente più pulsante Verifica. Il round si supera con il tasto che completa la frase.
- Disegno: dopo due errori dice cosa ha visto al posto del disegno e propone un’altra cosa da disegnare.
- In arabo i calcoli non appaiono più al contrario.
- Eliminare una sveglia chiede conferma.

DA VERIFICARE
1. Elimina l’app e installa questa build. Due schermate con Avanti, poi una che offre solo Continua. Rispondi all’avviso come vuoi, poi tocca «Crea la mia prima sveglia»: si apre l’editor e, chiudendolo, che tu salvi o no, devi arrivare all’elenco delle sveglie.
2. Imposta una sveglia tra due minuti, blocca il telefono e, quando suona, premi il pulsante con il nome della missione.
3. La volta dopo premi invece Ferma: la sveglia deve tornare un minuto dopo.
4. Quando suona una sveglia, la X nell’angolo chiede conferma prima di lasciarti andare; da «Prova questa missione» chiude subito.
5. Testo tagliato, sovrapposto o nella lingua sbagliata: uno screenshot è la segnalazione migliore.""",
    "ja": """ビルド12はApp Reviewに再提出するビルドです。変更の中心は、最初の1分とミッション画面です。

【変更点】
- アラームの許可の前に出る画面のボタンは「続ける」だけになりました。選ぶのはiOSのダイアログで、どちらを選んでもアプリは動きます。
- 最初の案内の最後のボタン「最初のアラームを設定」で、アラームの編集画面が開くようになりました。
- 設定には効果のある項目だけを残しました。アプリは常にダーク表示です。
- タイピング：「確認」ボタンはなくなりました。文を打ち終えた瞬間にラウンドクリアです。
- お絵かき：2回外れると、代わりに何に見えたかを表示し、別のお題に変えられます。
- アラビア語で、計算式が逆向きに表示されなくなりました。
- アラームを削除する前に確認が出ます。

【確認してほしいこと】
1. アプリを削除してこのビルドを入れてください。「次へ」の画面が2つ続き、その次の画面には「続ける」しかないはずです。ダイアログにはどちらで答えてもかまいません。続けて「最初のアラームを設定」を押すと編集画面が開き、保存してもしなくても、閉じるとアラーム一覧に着くはずです。
2. 2分後にアラームを設定して端末をロックし、鳴ったらミッション名のボタンを押してください。
3. 次は代わりに「停止」を押してください。1分後にアラームが戻ってくるはずです。
4. アラームが鳴っているときは、隅の×は確認してから終了します。「このミッションを試す」からならすぐに閉じます。
5. 文字の切れ、重なり、違う言語の表示があれば、スクリーンショットが一番の報告です。""",
    "ko": """빌드 12는 App Review에 다시 보내는 빌드라서, 대부분 처음 1분과 미션 화면에 관한 변경입니다.

바뀐 점
- 알람 권한 전에 나오는 화면에는 이제 '계속' 버튼 하나만 있습니다. 선택은 iOS 알림창에서 하고, 어느 쪽을 골라도 앱은 작동합니다.
- 온보딩의 마지막 버튼 '첫 알람 만들기'를 누르면 이제 알람 편집 화면이 열립니다.
- 설정에는 실제로 무언가를 하는 항목만 남겼습니다. 앱은 항상 다크 모드입니다.
- 타이핑: '확인' 버튼이 없어졌습니다. 문장을 완성하는 키를 누르는 순간 라운드가 끝납니다.
- 그리기: 두 번 틀리면 대신 무엇처럼 보였는지 알려 주고, 다른 그림으로 바꿀 수 있게 합니다.
- 아랍어에서 계산식이 더 이상 거꾸로 표시되지 않습니다.
- 알람을 삭제하기 전에 확인을 묻습니다.

확인해 주세요
1. 앱을 삭제하고 이 빌드를 설치하세요. '다음' 화면이 두 번 나온 뒤, '계속'만 있는 화면이 나와야 합니다. 알림창에는 원하는 대로 답하고 '첫 알람 만들기'를 누르세요. 편집 화면이 열리고, 저장하든 안 하든 닫으면 알람 목록에 도착해야 합니다.
2. 2분 뒤로 알람을 맞추고 휴대폰을 잠근 뒤, 울리면 미션 이름이 적힌 버튼을 누르세요.
3. 다음에는 대신 '정지'를 누르세요. 1분 뒤 알람이 다시 울려야 합니다.
4. 알람이 울릴 때는 모서리의 X가 확인을 받은 뒤에야 나가게 해 줍니다. '이 미션 미리 해보기'에서는 바로 닫힙니다.
5. 잘리거나 겹치거나 다른 언어로 나온 글자가 있으면 스크린샷이 가장 좋은 제보입니다.""",
    "pt-BR": """O build 12 é o que volta para a revisão da Apple, então quase tudo tem a ver com o primeiro minuto e com as telas de missão.

O QUE MUDOU
- A tela antes da permissão de alarmes tem um único botão, Continuar. A escolha é feita no alerta do iOS, e o app funciona com qualquer resposta.
- “Criar meu primeiro alarme”, o último botão da apresentação, agora abre o editor de alarme.
- Os ajustes guardam só o que faz alguma coisa. O app é sempre escuro.
- Digitação: não há mais botão Verificar. A rodada termina na tecla que completa a frase.
- Desenho: depois de dois erros, o app diz o que viu no lugar e oferece outra coisa para desenhar.
- Em árabe, as contas não aparecem mais de trás para frente.
- Apagar um alarme pede confirmação.

O QUE VERIFICAR
1. Apague o app e instale este build. Duas telas com Avançar e depois uma que oferece só Continuar. Responda ao alerta como quiser e toque em “Criar meu primeiro alarme”: o editor abre e, ao fechá-lo, salvando ou não, você tem que chegar à lista de alarmes.
2. Crie um alarme para daqui a dois minutos, bloqueie o telefone e, quando tocar, toque no botão com o nome da missão.
3. Na próxima vez, toque em Parar: o alarme deve voltar um minuto depois.
4. Quando um alarme toca, o X no canto pede confirmação antes de deixar você sair; em “Testar esta missão” ele fecha na hora.
5. Texto cortado, sobreposto ou no idioma errado: uma captura de tela é o melhor relato.""",
    "ru": """Сборка 12 снова уходит на проверку в Apple, поэтому почти всё в ней касается первой минуты и экранов заданий.

ЧТО ИЗМЕНИЛОСЬ
- На экране перед разрешением на будильники осталась одна кнопка: «Продолжить». Выбор делается в запросе iOS, и приложение работает при любом ответе.
- Последняя кнопка знакомства, «Создать первый будильник», теперь открывает редактор будильника.
- В настройках осталось только то, что действительно работает. Приложение всегда тёмное.
- Набор текста: кнопки «Проверить» больше нет. Раунд засчитывается на нажатии, которое завершает фразу.
- Рисование: после двух промахов приложение говорит, что увидело вместо рисунка, и предлагает нарисовать другое.
- На арабском примеры больше не показываются задом наперёд.
- Удаление будильника теперь требует подтверждения.

ЧТО ПРОВЕРИТЬ
1. Удалите приложение и установите эту сборку. Два экрана с кнопкой «Далее», затем экран, где есть только «Продолжить». Ответьте на запрос как угодно и нажмите «Создать первый будильник»: откроется редактор, и после его закрытия, с сохранением или без, вы должны попасть в список будильников.
2. Поставьте будильник на две минуты вперёд, заблокируйте телефон и, когда он зазвонит, нажмите кнопку с названием задания.
3. В следующий раз нажмите «Стоп»: будильник должен вернуться через минуту.
4. Когда звонит будильник, крестик в углу спрашивает подтверждение, прежде чем отпустить; в «Попробовать это задание» он закрывает сразу.
5. Обрезанный, наложенный или не на том языке текст: скриншот будет лучшим сообщением.""",
    "zh-Hans": """构建版本 12 将重新提交 App 审核，所以改动大多集中在第一分钟和任务界面。

【改动】
- 闹钟权限之前的那一屏只剩一个按钮：“继续”。选择在 iOS 弹窗里做，无论怎么选，App 都能用。
- 引导的最后一个按钮“设置我的第一个闹钟”现在会打开闹钟编辑器。
- 设置里只保留真正起作用的项目。App 始终是深色的。
- 打字：不再有“检查”按钮。打出完成句子的那一个字，这一轮就过了。
- 涂鸦：连续两次没认出来后，会告诉你它看到的是什么，并让你换一个题目。
- 阿拉伯语下，算式不再倒着显示。
- 删除闹钟前会先确认。

【请检查】
1. 删除 App 后安装这个版本。先是两屏“下一步”，然后一屏只有“继续”。弹窗随便怎么回答，再点“设置我的第一个闹钟”：编辑器会打开，无论保存与否，关掉后都应该进入闹钟列表。
2. 设一个两分钟后的闹钟，锁屏，响铃时按写着任务名称的按钮。
3. 下一次改按“停止”：闹钟应该在一分钟后再次响起。
4. 闹钟响起时，角落的 X 会先确认再放你走；从“试玩这个任务”进入则会立即关闭。
5. 文字被截断、重叠或语言不对：截图就是最好的反馈。""",
}

# The description. Read on a phone, so the first two lines carry it: the App Store collapses
# everything after about three lines behind "more", and most readers never tap it.
#
# Plain text with blank lines and no markup, because the App Store renders none: a bullet is a
# literal "-" and a heading is a short line in the same size as everything else. The section
# labels are in caps in the languages where caps mean emphasis and left alone in the ones where
# they do not, which is why the Japanese, Korean and Chinese versions use 【】 instead.
DESCRIPTION = {
    "en-US": """You do not oversleep because your alarm is too quiet. You oversleep because stopping it takes one thumb, half a second and no thought at all.

Dawnbreak takes the thumb out of it. To stop the alarm you complete a mission: walk to the kitchen and point the camera at the kettle, do eight squats in front of the camera, solve arithmetic you would find easy at noon, scan the barcode on a box in another room.

Stop it without the mission and, one minute later, it rings again.

TWELVE MISSIONS

- Math: mental arithmetic sized to the difficulty. Only Hard and Brutal are timed, and a wrong answer brings a new problem
- Memory: watch which tiles light up, then tap the same ones
- Sequence: repeat a run of colored pads that grows by one each time you get it right
- Typing: retype a sentence word for word, from a short line at Easy to a long one at Brutal. Capitals and punctuation do not count
- Shake: 15 to 100 shakes
- Steps: 20 to 200 steps, counted by the phone
- Squats: 3, 8, 15 or 25, counted by the front camera, on the device
- Photo: register an object once, the kettle for instance. In the morning, point the camera at one like it. Recognition runs on the device and checks what the object is, not where it is
- Barcode: register a barcode or QR code, say on a box in another room, then scan it
- Draw: draw what it asks for, and on-device recognition checks it
- Flap: a one-thumb flying game. Get through 2 to 15 gaps
- Breathe: guided breathing, 3 to 10 cycles, from about 30 seconds to over three minutes

AS HARD AS YOU NEED IT

- Four difficulties: Easy, Medium, Hard and Brutal
- Up to ten rounds of the same mission
- Up to three more missions later in the morning, each one ringing 1 to 60 minutes after you clear the one before
- Snooze from 1 to 30 minutes, as often as you allow, or not at all
- Fourteen alarm tones, from gentle to savage
- Try a mission first from the alarm editor, silently and with nothing armed. Two in the afternoon is a good time to find out what Brutal means

IT DOES NOT LET GO

- Relentless is on for every new alarm: stop the alarm without finishing the mission and it rings again a minute later on the lock screen, titled “Mission not done”
- Closing the app is no way out: until the mission is done, the next ring is already set
- It rings as a system alarm, through AlarmKit: with the app closed, the phone locked, silent mode on, and through every Focus, Do Not Disturb included. Requires iOS 26
- There is always a way out. The X in the corner of every mission screen asks you to confirm, then stops the alarm and logs the morning as a give-up, because an alarm that cannot be stopped is a hazard and not a feature

EVERY MORNING, WRITTEN DOWN

Up to 90 days of wake times, how long the missions took, streaks, snoozes, and the mornings you stopped it without the mission. The numbers are unflattering on purpose. That is what makes them useful.

BUILT PROPERLY

- Twelve languages, including Arabic, laid out right to left
- Dark throughout, because you read this screen at 6am
- A widget with the next alarm, for the lock screen and the home screen
- No account. No sign-in. No ads. No analytics
- Nothing leaves the phone. There is no server to leave it to

FREE, ALL OF IT

Every mission, every difficulty and every tone, from the first launch. There is nothing to buy: no subscription, no ads, no account.

Privacy policy: https://dawnbreak.app/privacy.html
Terms of use: https://dawnbreak.app/terms.html
Support: https://dawnbreak.app/support.html""",
    "ar-SA": """أنت لا تتأخر في النوم لأن منبهك هادئ. تتأخر لأن إيقافه يحتاج إصبعاً واحداً، ونصف ثانية، وبلا تفكير.

يُخرج Dawnbreak الإصبع من المعادلة. لإيقاف المنبه تُنجز مهمة: أن تمشي إلى المطبخ وتوجّه الكاميرا نحو الغلاية، أن تؤدي ثماني حركات قرفصاء أمام الكاميرا، أن تحل عمليات حسابية تراها سهلة في الظهيرة، أن تمسح باركود علبة في غرفة أخرى.

أوقفه دون إنجاز المهمة، وبعد دقيقة واحدة سيرن من جديد.

اثنتا عشرة مهمة

- حساب: حساب ذهني يناسب درجة الصعوبة. الوقت محدد في مستويي «صعب» و«قاسٍ» فقط، والإجابة الخاطئة تأتي بمسألة جديدة
- ذاكرة: راقب المربعات التي تضيء، ثم المس المربعات نفسها
- تسلسل: أعد سلسلة من الأزرار الملونة تطول بزر واحد في كل مرة تصيب فيها
- كتابة: أعد كتابة جملة كلمة بكلمة، من سطر قصير في «سهل» إلى جملة طويلة في «قاسٍ». علامات الترقيم لا تُحتسب
- رجّ: من 15 إلى 100 رجّة
- خطوات: من 20 إلى 200 خطوة، يعدّها الهاتف
- قرفصاء: 3 أو 8 أو 15 أو 25، تعدّها الكاميرا الأمامية على الجهاز نفسه
- صورة: سجّل شيئاً مرة واحدة، الغلاية مثلاً. وفي الصباح وجّه الكاميرا نحو شيء من النوع نفسه. يجري التعرّف على الجهاز، ويتحقق مما هو الشيء، لا من مكانه
- باركود: سجّل باركود أو رمز QR، على علبة في غرفة أخرى مثلاً، ثم امسحه
- رسم: ارسم ما يُطلب منك، والتعرّف على الجهاز يتحقق منه
- تحليق: لعبة طيران تُلعب بإصبع واحد. اعبر من فتحتين إلى 15 فتحة
- تنفّس: تنفّس موجَّه، من 3 إلى 10 دورات، من نحو 30 ثانية إلى أكثر من ثلاث دقائق

بالصعوبة التي تحتاجها

- أربع درجات صعوبة: سهل، ومتوسط، وصعب، وقاسٍ
- حتى عشر جولات من المهمة نفسها
- حتى ثلاث مهام إضافية لاحقاً في الصباح، كل واحدة منها ترن بعد مدة من دقيقة إلى 60 دقيقة من إنجاز التي قبلها
- تأجيل من دقيقة إلى 30 دقيقة، بعدد المرات الذي تسمح به، أو بلا تأجيل أصلاً
- أربع عشرة نغمة منبه، من الهادئة إلى الشرسة
- جرّب مهمة أولاً من محرر المنبه، بلا صوت ودون ضبط أي منبه. الثانية بعد الظهر وقت مناسب لتكتشف ماذا يعني «قاسٍ»

لا يتركك

- وضع «عنيد» مفعّل في كل منبه جديد: أوقف المنبه دون إتمام المهمة، وسيرن من جديد بعد دقيقة على شاشة القفل، بعنوان «لم تكتمل المهمة»
- إغلاق التطبيق لا يُخرجك: ما دامت المهمة لم تكتمل، فالرنين التالي مضبوط مسبقاً
- يرن كمنبه نظام عبر AlarmKit، حتى والتطبيق مغلق، والهاتف مقفل، والوضع الصامت مفعّل، ومع أي وضع تركيز، ومنه عدم الإزعاج. يتطلب iOS 26
- هناك دائماً مخرج. علامة X في زاوية كل شاشة مهمة تطلب التأكيد، ثم توقف المنبه وتسجّل الصباح كانسحاب، لأن منبهاً لا يمكن إيقافه خطرٌ لا ميزة

كل صباح، مكتوباً

حتى 90 يوماً من أوقات الاستيقاظ، ومدة المهام، والسلاسل، والتأجيلات، والصباحات التي أوقفته فيها دون المهمة. الأرقام غير مُجمَّلة عن قصد. وهذا ما يجعلها مفيدة.

مبنيّ كما ينبغي

- اثنتا عشرة لغة، ومنها العربية من اليمين إلى اليسار
- داكن بالكامل، لأنك تقرأ هذه الشاشة في السادسة صباحاً
- أداة تعرض المنبه القادم، لشاشة القفل وللشاشة الرئيسية
- بلا حساب. بلا تسجيل دخول. بلا إعلانات. بلا تحليلات
- لا شيء يخرج من الهاتف. ولا يوجد أصلاً خادم يخرج إليه

مجاني بالكامل

كل المهام، وكل درجات الصعوبة، وكل النغمات، من أول تشغيل. لا شيء للشراء: بلا اشتراك، بلا إعلانات، بلا حساب.

سياسة الخصوصية: https://dawnbreak.app/privacy.html
شروط الاستخدام: https://dawnbreak.app/terms.html
الدعم: https://dawnbreak.app/support.html""",
    "de-DE": """Du verschläfst nicht, weil dein Wecker zu leise ist. Du verschläfst, weil ihn abzustellen einen Daumen kostet, eine halbe Sekunde und keinen einzigen Gedanken.

Dawnbreak nimmt den Daumen aus der Rechnung. Um den Alarm abzustellen, erledigst du eine Mission: in die Küche gehen und die Kamera auf den Wasserkocher richten, acht Kniebeugen vor der Kamera machen, Rechenaufgaben lösen, die dir mittags leichtfallen würden, den Barcode einer Packung im anderen Zimmer scannen.

Stellst du ihn ohne Mission ab, klingelt er eine Minute später wieder.

ZWÖLF MISSIONEN

- Rechnen: Kopfrechnen passend zur Schwierigkeit. Nur Schwer und Brutal laufen auf Zeit, und nach einer falschen Antwort kommt eine neue Aufgabe
- Gedächtnis: Merk dir, welche Felder aufleuchten, und tipp genau diese an
- Sequenz: Wiederhole eine Folge farbiger Felder, die mit jedem richtigen Durchgang um eins länger wird
- Tippen: Schreib einen Satz Wort für Wort ab, von einer kurzen Zeile bei Leicht bis zu einem langen Satz bei Brutal. Groß- und Kleinschreibung, Akzente und Satzzeichen zählen nicht
- Schütteln: 15 bis 100 Mal
- Schritte: 20 bis 200 Schritte, vom Telefon gezählt
- Kniebeugen: 3, 8, 15 oder 25, von der Frontkamera auf dem Gerät gezählt
- Foto: Registriere einmal einen Gegenstand, etwa den Wasserkocher. Morgens richtest du die Kamera auf einen gleichartigen. Die Erkennung läuft auf dem Gerät und prüft, was der Gegenstand ist, nicht wo er steht
- Barcode: Registriere einen Barcode oder QR-Code, etwa auf einer Packung im anderen Zimmer, und scanne ihn dann
- Zeichnen: Zeichne, was verlangt wird. Die Erkennung auf dem Gerät prüft es
- Flattern: ein Flugspiel für einen Daumen. Flieg durch 2 bis 15 Lücken
- Atmen: geführtes Atmen, 3 bis 10 Zyklen, von etwa 30 Sekunden bis über drei Minuten

SO HART, WIE DU ES BRAUCHST

- Vier Schwierigkeitsgrade: Leicht, Mittel, Schwer und Brutal
- Bis zu zehn Runden derselben Mission
- Bis zu drei weitere Missionen später am Morgen, jede klingelt 1 bis 60 Minuten, nachdem du die vorige geschafft hast
- Schlummern von 1 bis 30 Minuten, so oft du es erlaubst, oder gar nicht
- Vierzehn Wecktöne, von sanft bis gnadenlos
- Probier eine Mission vorher im Alarm-Editor aus, lautlos und ohne dass ein Alarm gestellt wird. Was Brutal heißt, findest du besser um 14 Uhr heraus

ER LÄSST NICHT LOCKER

- „Unerbittlich“ ist bei jedem neuen Alarm eingeschaltet: Stellst du ihn ab, ohne die Mission zu beenden, klingelt er eine Minute später wieder auf dem Sperrbildschirm, mit dem Titel „Mission offen“
- App schließen hilft nicht: Bis die Mission erledigt ist, ist das nächste Klingeln schon gestellt
- Er klingelt als Systemalarm, über AlarmKit: bei geschlossener App, bei gesperrtem Telefon, trotz Stummschaltung und in jedem Fokus, auch bei Nicht stören. Erfordert iOS 26
- Einen Ausweg gibt es immer. Das X in der Ecke jedes Missionsbildschirms fragt nach, stoppt dann den Alarm und trägt den Morgen als Abbruch ein, denn ein Alarm, der sich nicht abstellen lässt, ist eine Gefahr und kein Feature

JEDER MORGEN, AUFGESCHRIEBEN

Bis zu 90 Tage: Aufwachzeiten, Dauer der Missionen, Serien, Schlummern und jeder Morgen, an dem du ihn ohne Mission abgestellt hast. Die Zahlen schmeicheln absichtlich nicht. Genau das macht sie brauchbar.

ORDENTLICH GEBAUT

- Zwölf Sprachen, auch Arabisch, von rechts nach links gesetzt
- Durchgehend dunkel, weil du diesen Bildschirm um 6 Uhr liest
- Ein Widget mit dem nächsten Alarm, für Sperrbildschirm und Home-Bildschirm
- Kein Konto. Kein Login. Keine Werbung. Keine Analysedaten
- Nichts verlässt das Telefon. Es gibt keinen Server, zu dem es gehen könnte

GRATIS, ALLES DAVON

Jede Mission, jeder Schwierigkeitsgrad und jeder Ton, vom ersten Start an. Es gibt nichts zu kaufen: kein Abo, keine Werbung, kein Konto.

Datenschutz: https://dawnbreak.app/privacy.html
Nutzungsbedingungen: https://dawnbreak.app/terms.html
Support: https://dawnbreak.app/support.html""",
    "es-ES": """No te quedas dormido porque tu alarma suene poco. Te quedas dormido porque apagarla cuesta un pulgar, medio segundo y ningún pensamiento.

Dawnbreak quita el pulgar de la ecuación. Para apagar la alarma completas una misión: ir a la cocina y apuntar la cámara a la tetera, hacer ocho sentadillas delante de la cámara, resolver cuentas que a mediodía te parecerían fáciles, escanear el código de barras de una caja que está en otra habitación.

Si la apagas sin hacer la misión, un minuto después vuelve a sonar.

DOCE MISIONES

- Cálculo: cálculo mental a la medida de la dificultad. Solo Difícil y Brutal van contra reloj, y una respuesta incorrecta trae una cuenta nueva
- Memoria: fíjate en qué casillas se iluminan y toca esas mismas
- Secuencia: repite una serie de botones de colores que crece en uno cada vez que aciertas
- Escritura: copia una frase palabra por palabra, desde una línea corta en Fácil hasta una larga en Brutal. Mayúsculas, tildes y puntuación no cuentan
- Agitar: de 15 a 100 sacudidas
- Pasos: de 20 a 200 pasos, contados por el teléfono
- Sentadillas: 3, 8, 15 o 25, contadas por la cámara frontal, en el propio dispositivo
- Foto: registra un objeto una vez, la tetera por ejemplo. Por la mañana, apunta la cámara a uno parecido. El reconocimiento se hace en el dispositivo y comprueba qué objeto es, no dónde está
- Código de barras: registra un código de barras o un código QR, por ejemplo el de una caja en otra habitación, y luego escanéalo
- Dibujo: dibuja lo que te pide, y el reconocimiento en el dispositivo lo comprueba
- Aleteo: un juego de vuelo que se juega con un pulgar. Supera de 2 a 15 huecos
- Respirar: respiración guiada, de 3 a 10 ciclos, desde unos 30 segundos hasta más de tres minutos

TAN DURA COMO LA NECESITES

- Cuatro dificultades: Fácil, Medio, Difícil y Brutal
- Hasta diez rondas de la misma misión
- Hasta tres misiones más a lo largo de la mañana, cada una suena entre 1 y 60 minutos después de superar la anterior
- Posponer de 1 a 30 minutos, tantas veces como permitas, o ninguna
- Catorce tonos de alarma, de suaves a despiadados
- Prueba una misión antes desde el editor de la alarma, en silencio y sin programar nada. Las dos de la tarde son un buen momento para descubrir qué significa Brutal

NO SE RINDE

- El modo Implacable viene activado en cada alarma nueva: si la apagas sin terminar la misión, vuelve a sonar un minuto después en la pantalla bloqueada, con el título «Misión sin terminar»
- Cerrar la app no te libra: hasta que termines la misión, el siguiente aviso ya está programado
- Suena como alarma del sistema, a través de AlarmKit: con la app cerrada, el teléfono bloqueado, en modo silencio y con cualquier modo de concentración, No molestar incluido. Requiere iOS 26
- Siempre hay una salida. La X de la esquina de cada pantalla de misión pide confirmación, luego para la alarma y registra la mañana como abandono, porque una alarma que no se puede parar es un peligro y no una función

CADA MAÑANA, POR ESCRITO

Hasta 90 días de horas de despertar, lo que tardaron las misiones, rachas, posposiciones y las mañanas en que la apagaste sin hacer la misión. Los números no halagan, y es a propósito. Por eso sirven.

HECHA EN SERIO

- Doce idiomas, incluido el árabe, de derecha a izquierda
- Oscura de principio a fin, porque esta pantalla la lees a las 6 de la mañana
- Un widget con la próxima alarma, para la pantalla bloqueada y la de inicio
- Sin cuenta. Sin iniciar sesión. Sin anuncios. Sin analítica
- Nada sale del teléfono. No hay ningún servidor al que pudiera salir

GRATIS, SIN EXCEPCIONES

Todas las misiones, todas las dificultades y todos los tonos, desde el primer momento. No hay nada que comprar: ni suscripción, ni anuncios, ni cuenta.

Privacidad: https://dawnbreak.app/privacy.html
Términos de uso: https://dawnbreak.app/terms.html
Soporte: https://dawnbreak.app/support.html""",
    "fr-FR": """Vous ne dormez pas trop parce que votre réveil est trop discret. Vous dormez trop parce que l’arrêter demande un pouce, une demi-seconde et aucune réflexion.

Dawnbreak retire le pouce de l’équation. Pour arrêter l’alarme, vous accomplissez une mission : aller dans la cuisine et pointer l’appareil photo vers la bouilloire, enchaîner huit squats face à la caméra, résoudre un calcul qui vous paraîtrait facile à midi, scanner le code-barres d’une boîte dans une autre pièce.

Arrêtée sans la mission, elle sonne de nouveau une minute plus tard.

DOUZE MISSIONS

- Calcul : du calcul mental à la mesure de la difficulté. Seuls Difficile et Brutal sont chronométrés, et une mauvaise réponse amène un nouveau calcul
- Mémoire : repérez les cases qui s’allument, puis touchez les mêmes
- Séquence : reproduisez une suite de touches colorées qui s’allonge d’une touche par réussite
- Frappe : recopiez une phrase mot pour mot, d’une ligne courte en Facile à une longue phrase en Brutal. Majuscules, accents et ponctuation ne comptent pas
- Secouer : de 15 à 100 secousses
- Pas : de 20 à 200 pas, comptés par le téléphone
- Squats : 3, 8, 15 ou 25, comptés par la caméra avant, sur l’appareil
- Photo : enregistrez un objet une fois, la bouilloire par exemple. Le matin, cadrez un objet du même genre. La reconnaissance, faite sur l’appareil, vérifie ce qu’est l’objet, pas où il se trouve
- Code-barres : enregistrez un code-barres ou un QR code, sur une boîte dans une autre pièce par exemple, puis scannez-le
- Dessin : dessinez ce qui vous est demandé, la reconnaissance sur l’appareil vérifie
- Battement : un jeu de vol à un pouce. Franchissez de 2 à 15 passages
- Respiration : respiration guidée, de 3 à 10 cycles, d’environ 30 secondes à plus de trois minutes

AUSSI DUR QUE NÉCESSAIRE

- Quatre difficultés : Facile, Moyen, Difficile et Brutal
- Jusqu’à dix manches de la même mission
- Jusqu’à trois missions de plus dans la matinée : chacune sonne de 1 à 60 minutes après la réussite de la précédente
- Rappel de 1 à 30 minutes, autant de fois que vous l’autorisez, ou pas du tout
- Quatorze sonneries, de la plus douce à la plus féroce
- Essayez d’abord une mission depuis l’éditeur d’alarme, en silence et sans rien programmer. Mieux vaut découvrir à 14 h ce que veut dire Brutal

ELLE N’ABANDONNE PAS

- Le mode Implacable est activé pour chaque nouvelle alarme : arrêtée sans finir la mission, elle sonne de nouveau une minute plus tard sur l’écran verrouillé, sous le titre « Mission non terminée »
- Fermer l’app ne sert à rien : tant que la mission n’est pas faite, la prochaine sonnerie est déjà programmée
- Elle sonne comme une alarme système, via AlarmKit : app fermée, téléphone verrouillé, en mode silencieux et dans tous les modes de concentration, Ne pas déranger compris. iOS 26 requis
- Il y a toujours une issue. La croix dans le coin de chaque écran de mission demande confirmation, puis arrête l’alarme et note la matinée comme un abandon, parce qu’une alarme impossible à arrêter est un danger, pas une fonctionnalité

CHAQUE MATIN, NOTÉ

Jusqu’à 90 jours d’heures de réveil, de durées de mission, de séries et de rappels, avec les matins où vous l’avez arrêtée sans la mission. Les chiffres ne flattent pas, exprès. C’est ce qui les rend utiles.

FAIT SÉRIEUSEMENT

- Douze langues, dont l’arabe, affiché de droite à gauche
- Sombre de bout en bout, parce que vous lisez cet écran à 6 h
- Un widget avec la prochaine alarme, pour l’écran verrouillé et l’écran d’accueil
- Ni compte, ni connexion, ni publicité, ni analytique
- Rien ne quitte le téléphone. Il n’y a aucun serveur où l’envoyer

GRATUIT, EN ENTIER

Toutes les missions, difficultés et sonneries, dès le premier lancement. Rien à acheter : ni abonnement, ni publicité, ni compte.

Confidentialité : https://dawnbreak.app/privacy.html
Conditions d’utilisation : https://dawnbreak.app/terms.html
Assistance : https://dawnbreak.app/support.html""",
    "hi": """आप देर तक इसलिए नहीं सोते कि आपका अलार्म धीमा है। आप इसलिए सोते हैं कि उसे बंद करने में एक अंगूठा, आधा सेकंड और ज़रा भी सोच नहीं लगती।

Dawnbreak उस अंगूठे को हिसाब से हटा देता है। अलार्म बंद करने के लिए आपको एक मिशन पूरा करना होता है: रसोई तक जाकर कैमरा केतली की ओर करना, कैमरे के सामने आठ स्क्वैट करना, ऐसा गणित हल करना जो दोपहर में आसान लगता, दूसरे कमरे में रखे डिब्बे का बारकोड स्कैन करना।

मिशन के बिना अलार्म बंद करेंगे, तो एक मिनट बाद यह फिर बजेगा।

बारह मिशन

- गणित: कठिनाई के अनुसार मानसिक गणित। समय सीमा सिर्फ़ “कठिन” और “क्रूर” में है, और गलत जवाब पर नया सवाल आता है
- स्मृति: देखिए कौन-से खाने चमकते हैं, फिर उन्हीं को छूइए
- क्रम: रंगीन बटनों का एक क्रम दोहराइए, जो हर सही बार के साथ एक बटन लंबा हो जाता है
- टाइपिंग: एक वाक्य शब्दशः दोबारा टाइप कीजिए, “आसान” में छोटी पंक्ति से लेकर “क्रूर” में लंबे वाक्य तक। विराम-चिह्न नहीं गिने जाते
- हिलाना: 15 से 100 बार हिलाइए
- कदम: 20 से 200 कदम, फ़ोन गिनता है
- स्क्वैट: 3, 8, 15 या 25, जिन्हें सामने का कैमरा डिवाइस पर ही गिनता है
- फ़ोटो: कोई चीज़ एक बार दर्ज कीजिए, जैसे केतली। सुबह कैमरा वैसी ही किसी चीज़ की ओर कीजिए। पहचान डिवाइस पर होती है और देखती है कि चीज़ क्या है, यह नहीं कि वह कहाँ रखी है
- बारकोड: कोई बारकोड या QR कोड दर्ज कीजिए, जैसे दूसरे कमरे में रखे डिब्बे पर, फिर उसे स्कैन कीजिए
- चित्र: जो कहा जाए वह बनाइए, डिवाइस पर होने वाली पहचान उसे जाँचती है
- उड़ान: एक अंगूठे से खेला जाने वाला उड़ने का खेल। 2 से 15 गैप पार कीजिए
- श्वास: निर्देशित श्वास, 3 से 10 चक्र, लगभग 30 सेकंड से लेकर तीन मिनट से ज़्यादा तक

जितना कठिन आपको चाहिए

- चार कठिनाइयाँ: आसान, मध्यम, कठिन और क्रूर
- एक ही मिशन के 10 राउंड तक
- सुबह आगे चलकर तीन और मिशन तक, हर एक पिछला मिशन पूरा होने के 1 से 60 मिनट बाद बजता है
- 1 से 30 मिनट का स्नूज़, जितनी बार आप अनुमति दें, या बिल्कुल नहीं
- चौदह अलार्म टोन, हल्के से लेकर बेरहम तक
- अलार्म एडिटर में पहले कोई मिशन आज़माइए, बिना आवाज़ के और बिना कोई अलार्म सेट किए। “क्रूर” का मतलब जानने के लिए दोपहर दो बजे का समय अच्छा है

यह छोड़ता नहीं

- अडिग मोड हर नए अलार्म में चालू रहता है: मिशन पूरा किए बिना अलार्म बंद करें, तो एक मिनट बाद यह लॉक स्क्रीन पर “मिशन अधूरा” शीर्षक के साथ फिर बजता है
- ऐप बंद करने से भी छुटकारा नहीं: जब तक मिशन पूरा नहीं होता, अगली घंटी पहले से तय रहती है
- यह AlarmKit के ज़रिए सिस्टम अलार्म की तरह बजता है: ऐप बंद हो, फ़ोन लॉक हो, साइलेंट मोड चालू हो, या कोई भी फ़ोकस चालू हो, परेशान न करें समेत, तब भी। iOS 26 ज़रूरी है
- बाहर निकलने का रास्ता हमेशा है। हर मिशन स्क्रीन के कोने में बना X पुष्टि माँगता है, फिर अलार्म बंद करता है और उस सुबह को छोड़ने के रूप में दर्ज करता है, क्योंकि जो अलार्म रोका न जा सके वह ख़तरा है, सुविधा नहीं

हर सुबह, दर्ज

90 दिनों तक का ब्योरा: आप कब उठे, मिशन में कितना समय लगा, सिलसिले, स्नूज़, और वे सुबहें जब आपने मिशन के बिना अलार्म बंद किया। आँकड़े जानबूझकर चापलूसी नहीं करते। इसी से वे काम के हैं।

ठीक से बनाया गया

- बारह भाषाएँ, दाएँ से बाएँ लिखी जाने वाली अरबी समेत
- पूरी तरह डार्क, क्योंकि यह स्क्रीन आप सुबह 6 बजे पढ़ते हैं
- अगले अलार्म वाला विजेट, लॉक स्क्रीन और होम स्क्रीन दोनों के लिए
- कोई अकाउंट नहीं। कोई साइन-इन नहीं। कोई विज्ञापन नहीं। कोई एनालिटिक्स नहीं
- कुछ भी फ़ोन से बाहर नहीं जाता। जाने के लिए कोई सर्वर ही नहीं है

पूरा मुफ़्त

हर मिशन, हर कठिनाई और हर टोन, पहली बार खोलते ही। ख़रीदने के लिए कुछ नहीं है: कोई सदस्यता नहीं, कोई विज्ञापन नहीं, कोई अकाउंट नहीं।

गोपनीयता: https://dawnbreak.app/privacy.html
उपयोग की शर्तें: https://dawnbreak.app/terms.html
सहायता: https://dawnbreak.app/support.html""",
    "it": """Non dormi troppo perché la sveglia suona piano. Dormi troppo perché spegnerla costa un pollice, mezzo secondo e nessun pensiero.

Dawnbreak toglie il pollice dall’equazione. Per spegnere la sveglia completi una missione: andare in cucina e inquadrare il bollitore, fare otto squat davanti alla fotocamera, risolvere calcoli che a mezzogiorno ti sembrerebbero facili, scansionare il codice a barre di una scatola in un’altra stanza.

Se la spegni senza la missione, un minuto dopo suona di nuovo.

DODICI MISSIONI

- Calcoli: calcolo mentale tarato sulla difficoltà. Solo Difficile e Brutale sono a tempo, e una risposta sbagliata porta un nuovo calcolo
- Memoria: guarda quali caselle si accendono, poi tocca le stesse
- Sequenza: ripeti una serie di tasti colorati che si allunga di uno ogni volta che la indovini
- Digitazione: ricopia una frase parola per parola, da una riga breve in Facile a una frase lunga in Brutale. Maiuscole, accenti e punteggiatura non contano
- Scuoti: da 15 a 100 scosse
- Passi: da 20 a 200 passi, contati dal telefono
- Squat: 3, 8, 15 o 25, contati dalla fotocamera anteriore, sul dispositivo
- Foto: registra un oggetto una volta, per esempio il bollitore. Al mattino inquadra un oggetto dello stesso tipo. Il riconoscimento avviene sul dispositivo e verifica che cosa è l’oggetto, non dove si trova
- Codice a barre: registra un codice a barre o un codice QR, per esempio su una scatola in un’altra stanza, poi scansionalo
- Disegno: disegna quello che ti chiede, il riconoscimento sul dispositivo lo verifica
- Volo: un gioco di volo con un pollice solo. Supera da 2 a 15 varchi
- Respiro: respirazione guidata, da 3 a 10 cicli, da circa 30 secondi a oltre tre minuti

DURA QUANTO SERVE

- Quattro difficoltà: Facile, Medio, Difficile e Brutale
- Fino a dieci turni della stessa missione
- Fino a tre missioni in più nel corso della mattina: ognuna suona da 1 a 60 minuti dopo che hai superato la precedente
- Posticipo da 1 a 30 minuti, quante volte lo concedi, oppure mai
- Quattordici suonerie, dalle più dolci alle più feroci
- Prova prima una missione dall’editor della sveglia, in silenzio e senza impostare nulla. Le due del pomeriggio sono il momento giusto per scoprire cosa vuol dire Brutale

NON MOLLA

- La modalità Implacabile è attiva su ogni nuova sveglia: spenta senza finire la missione, suona di nuovo un minuto dopo sulla schermata di blocco, con il titolo «Missione non completata»
- Chiudere l’app non basta: finché la missione non è fatta, il prossimo squillo è già impostato
- Suona come sveglia di sistema, tramite AlarmKit: con l’app chiusa, il telefono bloccato, in modalità silenziosa e con qualsiasi modalità Full Immersion, Non disturbare compreso. Richiede iOS 26
- C’è sempre una via d’uscita. La X nell’angolo di ogni schermata di missione chiede conferma, poi ferma la sveglia e registra la mattina come resa, perché una sveglia che non si può fermare è un pericolo e non una funzione

OGNI MATTINA, SCRITTA

Fino a 90 giorni di orari di risveglio, durata delle missioni, serie, posticipi e le mattine in cui l’hai spenta senza missione. I numeri non ti lusingano, di proposito. È questo che li rende utili.

FATTA COME SI DEVE

- Dodici lingue, arabo compreso, da destra a sinistra
- Scura dall’inizio alla fine, perché questa schermata la leggi alle 6
- Un widget con la prossima sveglia, per la schermata di blocco e la schermata Home
- Nessun account. Nessun login. Nessuna pubblicità. Nessuna analisi
- Niente lascia il telefono. Non c’è nemmeno un server dove mandarlo

GRATIS, TUTTO

Tutte le missioni, tutte le difficoltà e tutte le suonerie, dal primo avvio. Non c’è nulla da comprare: nessun abbonamento, nessuna pubblicità, nessun account.

Privacy: https://dawnbreak.app/privacy.html
Termini d’uso: https://dawnbreak.app/terms.html
Assistenza: https://dawnbreak.app/support.html""",
    "ja": """寝坊するのは、アラームの音が小さいからではありません。止めるのに親指ひとつ、半秒、そして何の判断も要らないからです。

Dawnbreak は、その親指を計算から外します。アラームを止めるには、ミッションをクリアします。台所まで歩いてケトルにカメラを向ける。カメラの前でスクワットを8回する。昼間なら簡単な計算を解く。別の部屋に置いた箱のバーコードを読み取る。

ミッションを終えずに止めると、1分後にまた鳴ります。

【ミッションは12種類】

- 計算：難易度に合わせた暗算。制限時間があるのは「むずかしい」と「鬼」だけで、間違えると新しい問題に変わります
- 記憶：光ったマスを覚えて、同じマスをタップします
- 順番：色つきのボタンが光った順番を再現します。正解するたびに1つずつ長くなります
- タイピング：文を一語一語そのとおりに打ち直します。「かんたん」は短い一文、「鬼」は長い一文です。句読点は問いません
- シェイク：15回から100回振ります
- 歩数：20歩から200歩。数えるのは端末です
- スクワット：3回、8回、15回、25回のいずれか。前面カメラが端末上で数えます
- 写真：ケトルなど、ものを一度登録しておきます。朝は同じ種類のものにカメラを向けます。認識は端末上で行われ、それが何かを確かめます。どこにあるかは問いません
- バーコード：別の部屋の箱などにあるバーコードやQRコードを登録し、朝にそれを読み取ります
- お絵かき：お題どおりに描くと、端末上の認識が判定します
- フラップ：親指ひとつで遊ぶ飛行ゲーム。すき間を2個から15個くぐり抜けます
- 呼吸：ガイドに合わせた呼吸を3サイクルから10サイクル。約30秒から3分以上まで

【必要なだけ厳しく】

- 難易度は4段階：かんたん、ふつう、むずかしい、鬼
- 同じミッションを最大10ラウンド
- 朝のうちに、追加のミッションを最大3つ。それぞれ、前のミッションをクリアしてから1分から60分後に鳴ります
- スヌーズは1分から30分。回数は許可した分だけ、またはスヌーズなし
- アラーム音は14種類。やさしい音から容赦ない音まで
- アラームの編集画面で、先にミッションを試せます。音は鳴らず、アラームも設定されません。「鬼」がどういう意味か知るには、午後2時がちょうどいい時間です

【逃がしません】

- 執念モードは、新しいアラームすべてでオンになっています。ミッションを終えずに止めると、1分後にロック画面で「ミッション未完了」として、また鳴ります
- アプリを閉じても逃げられません。ミッションを終えるまで、次に鳴る時刻はもう設定されています
- AlarmKit によるシステムのアラームなので、アプリを閉じていても、端末がロック中でも、サイレントモードでも、どの集中モードでも、おやすみモードでも鳴ります。iOS 26以降が必要です
- 出口は必ずあります。どのミッション画面にも隅に×があり、確認のあとでアラームを止め、その朝を「途中でやめた」と記録します。止められないアラームは、機能ではなく危険だからです

【毎朝が、記録として残る】

最大90日分の起床時刻、ミッションにかかった時間、連続記録、スヌーズ、そしてミッションなしで止めた朝。数字はわざと甘くしていません。だから使えます。

【きちんと作ってあります】

- 12言語対応。アラビア語は右から左に表示します
- 画面は最初から最後までダーク。この画面を読むのは朝6時だからです
- 次のアラームを表示するウィジェット。ロック画面にもホーム画面にも置けます
- アカウントなし。ログインなし。広告なし。解析なし
- データは端末の外に出ません。出す先のサーバーがそもそもありません

【すべて無料】

すべてのミッション、すべての難易度、すべてのアラーム音を、最初の起動から使えます。購入するものはありません。サブスクリプションも広告もアカウントもありません。

プライバシーポリシー：https://dawnbreak.app/privacy.html
利用規約：https://dawnbreak.app/terms.html
サポート：https://dawnbreak.app/support.html""",
    "ko": """늦잠을 자는 이유는 알람 소리가 작아서가 아닙니다. 끄는 데 엄지 하나, 반 초, 그리고 아무 판단도 필요하지 않기 때문입니다.

Dawnbreak는 그 엄지를 계산에서 빼버립니다. 알람을 끄려면 미션을 완료해야 합니다. 부엌까지 걸어가 주전자에 카메라를 비추고, 카메라 앞에서 스쿼트를 여덟 번 하고, 낮이라면 쉬웠을 계산을 풀고, 다른 방에 둔 상자의 바코드를 스캔하는 식입니다.

미션을 끝내지 않고 끄면, 1분 뒤에 다시 울립니다.

【미션 12가지】

- 계산: 난이도에 맞춘 암산. 어려움과 극악에만 제한 시간이 있고, 틀리면 새 문제가 나옵니다
- 기억력: 불이 들어온 칸을 기억했다가 같은 칸을 누르세요
- 순서: 색깔 버튼이 켜지는 순서를 따라 누르세요. 맞힐 때마다 하나씩 길어집니다
- 타이핑: 문장을 한 단어도 빠짐없이 다시 입력하세요. 쉬움에서는 짧은 문장, 극악에서는 긴 문장입니다. 문장부호는 따지지 않습니다
- 흔들기: 15번에서 100번까지 흔드세요
- 걸음: 20걸음에서 200걸음까지, 기기가 셉니다
- 스쿼트: 3회, 8회, 15회 또는 25회. 전면 카메라가 기기 안에서 셉니다
- 사진: 주전자 같은 물건을 한 번 등록해 두세요. 아침에는 같은 종류의 물건에 카메라를 비추면 됩니다. 인식은 기기 안에서 이루어지며, 물건이 무엇인지만 확인하고 어디에 있는지는 보지 않습니다
- 바코드: 다른 방에 둔 상자의 바코드나 QR 코드 등을 등록한 뒤, 아침에 스캔하세요
- 그리기: 제시된 것을 그리면 기기 안의 인식이 확인합니다
- 플랩: 엄지 하나로 하는 비행 게임. 틈 2개에서 15개를 통과하세요
- 호흡: 안내에 따라 3회에서 10회 호흡 주기를 반복합니다. 약 30초에서 3분 넘게 걸립니다

【필요한 만큼 혹독하게】

- 난이도 4단계: 쉬움, 보통, 어려움, 극악
- 같은 미션을 최대 10라운드까지
- 아침 중에 추가 미션 최대 3개. 앞의 미션을 끝내고 1분에서 60분 뒤에 각각 울립니다
- 다시 알림은 1분에서 30분까지, 허용한 횟수만큼, 또는 아예 없이
- 알람음 14가지, 부드러운 소리부터 사정없는 소리까지
- 알람 편집 화면에서 미션을 먼저 해볼 수 있습니다. 소리도 나지 않고, 알람도 맞춰지지 않습니다. 극악이 무슨 뜻인지 알아보기엔 오후 2시가 딱 좋습니다

【봐주지 않습니다】

- ‘끈질기게’ 모드는 새 알람마다 켜져 있습니다. 미션을 끝내지 않고 끄면 1분 뒤 잠금 화면에서 ‘미션 미완료’라는 제목으로 다시 울립니다
- 앱을 닫아도 빠져나갈 수 없습니다. 미션을 끝낼 때까지 다음 알람이 이미 맞춰져 있습니다
- AlarmKit을 통해 시스템 알람으로 울립니다. 앱을 닫아도, 기기를 잠가도, 무음 모드여도, 어떤 집중 모드나 방해 금지 모드에서도 울립니다. iOS 26 이상이 필요합니다
- 출구는 언제나 있습니다. 모든 미션 화면 모서리의 X는 확인을 받은 뒤 알람을 끄고, 그날 아침을 포기로 기록합니다. 끌 수 없는 알람은 기능이 아니라 위험이니까요

【모든 아침이 기록으로 남습니다】

최대 90일 동안의 기상 시각, 미션에 걸린 시간, 연속 기록, 다시 알림, 그리고 미션 없이 끈 아침까지. 숫자는 일부러 후하게 매기지 않습니다. 그래서 쓸모가 있습니다.

【제대로 만들었습니다】

- 12개 언어 지원. 아랍어는 오른쪽에서 왼쪽으로 표시합니다
- 처음부터 끝까지 다크 화면. 이 화면을 읽는 시각이 아침 6시니까요
- 다음 알람을 보여주는 위젯. 잠금 화면과 홈 화면 모두에 둘 수 있습니다
- 계정 없음. 로그인 없음. 광고 없음. 분석 없음
- 데이터는 기기를 떠나지 않습니다. 떠나 보낼 서버 자체가 없습니다

【전부 무료】

모든 미션, 모든 난이도, 모든 알람음을 처음 실행할 때부터 쓸 수 있습니다. 살 것이 없습니다. 구독도 광고도 계정도 없습니다.

개인정보 처리방침: https://dawnbreak.app/privacy.html
이용약관: https://dawnbreak.app/terms.html
지원: https://dawnbreak.app/support.html""",
    "pt-BR": """Você não dorme demais porque o alarme é baixo. Você dorme demais porque desligá-lo custa um polegar, meio segundo e nenhum pensamento.

O Dawnbreak tira o polegar da conta. Para desligar o alarme, você cumpre uma missão: ir até a cozinha e apontar a câmera para a chaleira, fazer oito agachamentos na frente da câmera, resolver contas que ao meio-dia pareceriam fáceis, escanear o código de barras de uma caixa em outro cômodo.

Desligou sem fazer a missão? Um minuto depois ele toca de novo.

DOZE MISSÕES

- Cálculo: contas de cabeça no tamanho da dificuldade. Só Difícil e Brutal têm limite de tempo, e uma resposta errada traz uma conta nova
- Memória: veja quais quadrados acendem e toque nos mesmos
- Sequência: repita uma série de botões coloridos que cresce um a cada acerto
- Digitação: redigite uma frase palavra por palavra, de uma linha curta no Fácil a uma frase longa no Brutal. Maiúsculas, acentos e pontuação não contam
- Agitar: de 15 a 100 sacudidas
- Passos: de 20 a 200 passos, contados pelo telefone
- Agachamentos: 3, 8, 15 ou 25, contados pela câmera frontal, no próprio aparelho
- Foto: cadastre um objeto uma vez, a chaleira, por exemplo. De manhã, aponte a câmera para um parecido. O reconhecimento roda no aparelho e confere o que o objeto é, não onde ele está
- Código de barras: cadastre um código de barras ou QR code, numa caixa em outro cômodo, por exemplo, e depois escaneie
- Desenho: desenhe o que for pedido, e o reconhecimento no aparelho confere
- Voo: um jogo de voar com um polegar só. Passe por 2 a 15 vãos
- Respirar: respiração guiada, de 3 a 10 ciclos, de uns 30 segundos a mais de três minutos

TÃO DIFÍCIL QUANTO VOCÊ PRECISAR

- Quatro dificuldades: Fácil, Médio, Difícil e Brutal
- Até dez rodadas da mesma missão
- Até mais três missões ao longo da manhã, cada uma tocando de 1 a 60 minutos depois que você concluir a anterior
- Soneca de 1 a 30 minutos, quantas vezes você permitir, ou nenhuma
- Catorze toques de alarme, dos suaves aos impiedosos
- Teste uma missão antes, no editor do alarme, em silêncio e sem nada agendado. Duas da tarde é uma boa hora para descobrir o que Brutal quer dizer

ELE NÃO DESISTE

- O modo Implacável vem ligado em todo alarme novo: desligou sem terminar a missão, ele toca de novo um minuto depois na tela bloqueada, com o título “Missão não concluída”
- Fechar o app não adianta: enquanto a missão não termina, o próximo toque já está marcado
- Ele toca como alarme do sistema, pelo AlarmKit: com o app fechado, o telefone bloqueado, no modo silencioso e com qualquer Foco, Não Perturbe incluído. Requer iOS 26
- Sempre existe uma saída. O X no canto de cada tela de missão pede confirmação, depois para o alarme e registra a manhã como desistência, porque um alarme que não pode ser parado é um risco e não um recurso

CADA MANHÃ, ANOTADA

Até 90 dias de horários de despertar, tempo das missões, sequências, sonecas e as manhãs em que você desligou sem fazer a missão. Os números não são gentis, de propósito. É isso que os torna úteis.

FEITO DIREITO

- Doze idiomas, inclusive árabe, da direita para a esquerda
- Escuro do início ao fim, porque você lê esta tela às 6 da manhã
- Um widget com o próximo alarme, para a tela bloqueada e a Tela de Início
- Sem conta. Sem login. Sem anúncios. Sem analytics
- Nada sai do telefone. Não existe servidor para onde ir

GRÁTIS, TUDO

Todas as missões, todas as dificuldades e todos os toques, desde a primeira abertura. Não há nada para comprar: nenhuma assinatura, nenhum anúncio, nenhuma conta.

Privacidade: https://dawnbreak.app/privacy.html
Termos de uso: https://dawnbreak.app/terms.html
Suporte: https://dawnbreak.app/support.html""",
    "ru": """Вы просыпаете не потому, что будильник тихий. Вы просыпаете потому, что выключить его стоит одного большого пальца, полсекунды и ни одной мысли.

Dawnbreak убирает палец из этого уравнения. Чтобы выключить будильник, нужно выполнить задание: дойти до кухни и навести камеру на чайник, сделать восемь приседаний перед камерой, решить примеры, которые в полдень показались бы простыми, отсканировать штрих-код коробки в другой комнате.

Выключите его без задания, и через минуту он зазвонит снова.

ДВЕНАДЦАТЬ ЗАДАНИЙ

- Математика: устный счёт под выбранную сложность. На время решаются только уровни «Сложно» и «Жёстко», а неверный ответ даёт новый пример
- Память: запомните, какие клетки загорелись, и нажмите те же самые
- Цепочка: повторите последовательность цветных кнопок, которая становится на одну длиннее после каждого верного повтора
- Набор текста: перепечатайте фразу слово в слово, от короткой строки на уровне «Легко» до длинной фразы на «Жёстко». Регистр и знаки препинания не важны
- Встряхивание: от 15 до 100 встряхиваний
- Шаги: от 20 до 200 шагов, их считает телефон
- Приседания: 3, 8, 15 или 25, их считает фронтальная камера прямо на устройстве
- Фото: один раз зарегистрируйте предмет, например чайник. Утром наведите камеру на такой же. Распознавание работает на устройстве и проверяет, что это за предмет, а не где он стоит
- Штрих-код: зарегистрируйте штрих-код или QR-код, например на коробке в другой комнате, а потом отсканируйте его
- Рисование: нарисуйте то, что просят, и распознавание на устройстве это проверит
- Полёт: маленькая аркада для одного пальца. Пролетите от 2 до 15 просветов
- Дыхание: дыхание по подсказкам, от 3 до 10 циклов, примерно от 30 секунд до трёх с лишним минут

НАСТОЛЬКО ЖЁСТКО, НАСКОЛЬКО НУЖНО

- Четыре уровня сложности: «Легко», «Средне», «Сложно» и «Жёстко»
- До десяти раундов одного и того же задания
- До трёх дополнительных заданий позже утром, каждое звонит через срок от 1 до 60 минут после того, как вы выполните предыдущее
- Откладывание от 1 до 30 минут, столько раз, сколько вы разрешите, или ни разу
- Четырнадцать мелодий будильника, от мягких до беспощадных
- Сначала попробуйте задание прямо в редакторе будильника, без звука и ничего не заводя. Два часа дня отлично подходят, чтобы узнать, что значит «Жёстко»

ОН НЕ ОТПУСКАЕТ

- Режим «Неумолимый» включён для каждого нового будильника: выключите будильник, не закончив задание, и через минуту он зазвонит снова на заблокированном экране, с заголовком «Задание не выполнено»
- Закрыть приложение не поможет: пока задание не выполнено, следующий звонок уже назначен
- Он звонит как системный будильник, через AlarmKit: при закрытом приложении, на заблокированном телефоне, в беззвучном режиме, при любом фокусировании и в режиме «Не беспокоить». Требуется iOS 26
- Выход есть всегда. Крестик в углу каждого экрана задания просит подтверждения, затем выключает будильник и записывает утро как отказ, потому что будильник, который нельзя остановить, это опасность, а не функция

КАЖДОЕ УТРО, ЗАПИСАННОЕ

До 90 дней: во сколько вы проснулись, сколько длились задания, серии, откладывания и те утра, когда вы выключили будильник без задания. Цифры намеренно не льстят. Именно поэтому они полезны.

СДЕЛАНО КАК СЛЕДУЕТ

- Двенадцать языков, включая арабский с письмом справа налево
- Тёмное оформление целиком, потому что этот экран вы читаете в 6 утра
- Виджет со следующим будильником, для заблокированного экрана и экрана «Домой»
- Без аккаунта. Без входа. Без рекламы. Без аналитики
- Ничего не покидает телефон. Сервера, куда бы это уходило, просто нет

БЕСПЛАТНО, ЦЕЛИКОМ

Все задания, все уровни сложности и все мелодии, с первого запуска. Покупать нечего: ни подписки, ни рекламы, ни аккаунта.

Конфиденциальность: https://dawnbreak.app/privacy.html
Условия использования: https://dawnbreak.app/terms.html
Поддержка: https://dawnbreak.app/support.html""",
    "zh-Hans": """你睡过头，不是因为闹钟太轻。是因为关掉它只需要一个拇指、半秒钟，以及完全不用思考。

Dawnbreak 把那个拇指从等式里拿掉。要关掉闹钟，你得完成一个任务：走到厨房，把镜头对准水壶；在镜头前做八个深蹲；解几道白天觉得很容易的算术题；扫描另一个房间里那个盒子上的条码。

没做完任务就关掉，一分钟后它会再响。

【十二种任务】

- 算术：按难度出心算题。只有“困难”和“残酷”限时，答错就换一道新题
- 记忆：记住哪些方格亮了，再点出同样的方格
- 序列：重复一串彩色按键的顺序，每答对一次就多一个
- 打字：把一句话逐字重打一遍，“简单”是短短一句，“残酷”是一长句。标点不算
- 摇一摇：摇十五到一百下
- 步数：走二十到两百步，由手机来数
- 深蹲：三个、八个、十五个或二十五个，由前置摄像头在设备上计数
- 拍照：先登记一样东西，比如水壶。早上把镜头对准同一类东西即可。识别在设备上完成，只看它是什么，不看它放在哪里
- 条码：登记一个条码或二维码，比如另一个房间里某个盒子上的，然后去扫它
- 涂鸦：按题目画出来，由设备上的识别来判定
- 飞行：一个用一根拇指玩的飞行小游戏。穿过二到十五个缝隙
- 呼吸：跟着引导呼吸三到十个循环，从大约三十秒到三分多钟

【想要多难就多难】

- 四档难度：简单、中等、困难、残酷
- 同一个任务最多十轮
- 早上稍后最多再加三个任务，每个都在你完成上一个之后一到六十分钟响起
- 小睡一到三十分钟，次数由你定，也可以完全不允许小睡
- 十四种闹钟铃声，从温柔到凶狠
- 可以先在闹钟编辑页试玩任务，全程静音，也不会设定任何闹钟。下午两点正适合搞清楚“残酷”是什么意思

【它不会放过你】

- 每个新闹钟都开启了“不放弃模式”：没做完任务就关掉闹钟，一分钟后它会在锁定屏幕上以“任务未完成”为标题再次响起
- 关掉应用也没用：任务没做完之前，下一次响铃早就定好了
- 它作为系统闹钟，通过 AlarmKit 响铃：应用关闭、手机锁定、开着静音模式，或处于任何专注模式时都会响，勿扰模式也不例外。需要 iOS 26
- 出口永远都在。每个任务界面角落的 X 会先请你确认，然后停止闹钟，并把这个早晨记为放弃，因为关不掉的闹钟是危险，不是功能

【每个清晨都留下记录】

最多九十天的起床时间、任务用时、连续记录、小睡次数，以及没做任务就关掉闹钟的那些早晨。数字故意不讨好你，这才是它有用的地方。

【认真做出来的】

- 十二种语言，阿拉伯语按从右到左排版
- 从头到尾都是深色，因为你是在早上六点看这个界面
- 显示下一个闹钟的小组件，锁定屏幕和主屏幕都能放
- 无需账号。无需登录。没有广告。没有数据分析
- 数据不离开手机。压根就没有可以发去的服务器

【全部免费】

所有任务、所有难度、所有铃声，第一次打开就能用。没有任何东西要买：没有订阅，没有广告，也没有账号。

隐私政策：https://dawnbreak.app/privacy.html
使用条款：https://dawnbreak.app/terms.html
支持：https://dawnbreak.app/support.html""",
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
