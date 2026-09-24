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
    "en-US": "First release.\n\nTwelve missions, as many alarms as your week needs, four difficulties, and a lock screen alarm that comes back if you stop it without doing the mission. Twelve languages. No account, no adverts, nothing leaves your phone.\n\nIf something is wrong, the support page is one tap away in Settings. It gets read.",
    "ar-SA": "الإصدار الأول.\n\nاثنتا عشرة مهمة، ومنبهات بعدد ما يحتاجه أسبوعك، وأربع درجات صعوبة، ومنبه على شاشة القفل يعود إن أوقفته دون إنجاز المهمة. اثنتا عشرة لغة. بلا حساب، بلا إعلانات، ولا شيء يخرج من هاتفك.\n\nإن وجدت خطأً، صفحة الدعم على بُعد لمسة من الإعدادات. ونحن نقرأ ما يُرسَل.",
    "de-DE": "Erste Version.\n\nZwölf Missionen, so viele Alarme wie deine Woche braucht, vier Schwierigkeitsgrade und ein Alarm auf dem Sperrbildschirm, der zurückkommt, wenn du ihn ohne Mission abstellst. Zwölf Sprachen. Kein Konto, keine Werbung, nichts verlässt dein Telefon.\n\nWenn etwas nicht stimmt: Die Support-Seite ist in den Einstellungen einen Tipp entfernt. Sie wird gelesen.",
    "es-ES": "Primera versión.\n\nDoce misiones, tantas alarmas como necesite tu semana, cuatro dificultades y una alarma en la pantalla bloqueada que vuelve si la paras sin hacer la misión. Doce idiomas. Sin cuenta, sin anuncios, nada sale de tu teléfono.\n\nSi algo va mal, la página de soporte está a un toque en Ajustes. Se lee.",
    "fr-FR": "Première version.\n\nDouze missions, autant d’alarmes que votre semaine en demande, quatre difficultés, et une alarme sur l’écran verrouillé qui revient si vous l’arrêtez sans faire la mission. Douze langues. Sans compte, sans publicité, rien ne quitte votre téléphone.\n\nSi quelque chose ne va pas, la page d’assistance est à un geste dans les réglages. Elle est lue.",
    "hi": "पहला रिलीज़।\n\nबारह मिशन, जितने अलार्म आपके हफ़्ते को चाहिए उतने, चार कठिनाइयाँ, और लॉक स्क्रीन पर एक ऐसा अलार्म जो मिशन किए बिना रोकने पर लौट आता है। बारह भाषाएँ। कोई अकाउंट नहीं, कोई विज्ञापन नहीं, कुछ भी फ़ोन से बाहर नहीं जाता।\n\nकुछ गड़बड़ हो तो सेटिंग्स से सपोर्ट पेज एक टैप दूर है। वहाँ भेजा संदेश पढ़ा जाता है।",
    "it": "Prima versione.\n\nDodici missioni, tutte le sveglie che la tua settimana richiede, quattro difficoltà e una sveglia sulla schermata di blocco che torna se la fermi senza fare la missione. Dodici lingue. Nessun account, nessuna pubblicità, niente lascia il telefono.\n\nSe qualcosa non va, la pagina di assistenza è a un tocco nelle impostazioni. Viene letta.",
    "ja": "最初のリリースです。\n\nミッション 12 種類、一週間に必要なだけのアラーム、難易度 4 段階。ミッションをせずに止めると、ロック画面にもう一度戻ってきます。12 言語対応。アカウント不要、広告なし、データは端末の外に出ません。\n\nうまく動かないときは、設定からサポートページへ 1 タップで行けます。届いたものは読んでいます。",
    "ko": "첫 번째 버전입니다.\n\n미션 12가지, 한 주에 필요한 만큼의 알람, 난이도 4단계. 미션을 하지 않고 끄면 잠금 화면에 다시 돌아옵니다. 12개 언어. 계정도 광고도 없고, 데이터는 기기를 떠나지 않습니다.\n\n문제가 있다면 설정에서 한 번만 눌러 지원 페이지로 갈 수 있습니다. 보내주신 내용은 읽습니다.",
    "pt-BR": "Primeira versão.\n\nDoze missões, quantos alarmes a sua semana precisar, quatro dificuldades e um alarme na tela bloqueada que volta se você parar sem fazer a missão. Doze idiomas. Sem conta, sem anúncios, nada sai do seu telefone.\n\nSe algo estiver errado, a página de suporte está a um toque nos ajustes. Ela é lida.",
    "ru": "Первая версия.\n\nДвенадцать заданий, столько будильников, сколько нужно вашей неделе, четыре уровня сложности и будильник на заблокированном экране, который возвращается, если выключить его без задания. Двенадцать языков. Без аккаунта, без рекламы, ничего не покидает телефон.\n\nЕсли что-то не так, страница поддержки в одном касании из настроек. Её читают.",
    "zh-Hans": "首个版本。\n\n十二种任务、你这一周需要的任意数量的闹钟、四档难度，以及一个在你不做任务就关掉后会重新出现在锁定屏幕上的闹钟。支持十二种语言。无需账号，没有广告，数据不离开手机。\n\n如果有问题，在设置里一下就能打开支持页面。发过来的内容会有人看。",
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
    "en-US": """Build 10 fixes something you found and I had not: you said the app had four alarm tones. It has fourteen, and it has had since build 8. Only four were on screen.

WHY YOU SAW FOUR
The tones were a horizontal strip of small tiles inside the sound card. Four fit on a 6.9-inch screen, three on a 6.1-inch one, the scroll indicator was hidden, and nothing said there was more. You read the screen correctly; the screen was lying.

WHAT IT IS NOW
The sound card has one row: the name of the current tone, its loudness icon, and the number 14. Tapping it opens a screen with all fourteen tiles laid out three to a row, gentlest first, worst last, every one visible at once with no scrolling on any iPhone. Tapping a tile selects it and plays a preview. The icon and its colour say which class it is: waveform for gentle, two waves for standard, three for harsh, a red triangle for savage.

WHAT NOW STOPS IT COMING BACK
A test opens that screen and checks all fourteen tiles are inside the window and tappable after zero swipes, in English and in Arabic. I put the old strip back to be sure it fails: it does. A second test checks a chosen tone survives saving and reopening the alarm.

ON ADDING RECORDED SOUNDS
You asked for open-source sources. I checked the licences at the source rather than trusting a summary, and the answer is that all fourteen stay synthesised. The short reason: only CC0 audio can go into a paid App Store binary without asking each author for permission, because Creative Commons' own FAQ says that publishing a CC BY file through a platform that applies copy protection needs the licensor's express permission, and the App Store does apply it. The full list of what is usable and what looks free but is not is in the message that came with this build.

WORTH CHECKING
1. Editor, the sound row: it should say the current tone and 14. Tap it and count the tiles.
2. Listen to Hornet, Buzzer and Cicada from that screen, and Siren.
3. Pick one, save, reopen the alarm: it must still be selected.
4. In Arabic, the same screen: the tiles are mirrored and the names are longer; nothing should be cut off.""",
    "ar-SA": """الإصدار 10 يصلح شيئاً وجدته أنت ولم أجده أنا: قلت إن التطبيق فيه أربع نغمات. فيه أربع عشرة، ومنذ الإصدار 8. أربع فقط كانت على الشاشة.

لماذا رأيت أربعاً
كانت النغمات شريطاً أفقياً من مربعات صغيرة داخل بطاقة الصوت. أربعة تظهر على شاشة 6.9 بوصة، وثلاثة على 6.1، ومؤشر التمرير مخفي، ولا شيء يقول إن هناك المزيد. قراءتك للشاشة كانت صحيحة؛ الشاشة هي التي كذبت.

ما هو الآن
في بطاقة الصوت صف واحد: اسم النغمة الحالية، وأيقونة شدّتها، والرقم ١٤. الضغط عليه يفتح شاشة فيها المربعات الأربعة عشر كلها، ثلاثة في كل صف، الألطف أولاً والأقسى آخراً، وكلها مرئية دفعة واحدة بلا تمرير على أي iPhone. والضغط على مربع يختاره ويشغّل معاينة. الأيقونة ولونها يقولان الفئة: موجة للطيف، وموجتان للعادي، وثلاث للقاسي، ومثلث أحمر للأقسى.

ما يمنع رجوع هذا
اختبار يفتح تلك الشاشة ويتحقق أن المربعات الأربعة عشر داخل النافذة وقابلة للضغط بعد صفر تمريرة، بالإنجليزية وبالعربية. أعدت الشريط القديم للتأكد أنه يفشل: يفشل فعلاً. واختبار ثانٍ يتحقق أن النغمة المختارة تبقى بعد الحفظ وإعادة الفتح.

عن إضافة أصوات مسجّلة
طلبت مصادر مفتوحة. راجعت الرخص من مصادرها الأصلية لا من ملخصات، والنتيجة أن الأربع عشرة كلها تبقى مُصنّعة. السبب المختصر: وحدها أصوات CC0 يمكن أن تدخل في تطبيق مدفوع على App Store دون استئذان كل مؤلف، لأن أسئلة Creative Commons نفسها تقول إن نشر ملف CC BY عبر منصة تطبّق حماية النسخ يحتاج إذناً صريحاً من المرخِّص، وApp Store تطبّقها. والقائمة الكاملة لما يصلح وما يبدو مجانياً وليس كذلك في الرسالة المرافقة لهذا الإصدار.

يستحق التحقق
١. المحرر، صف الصوت: يجب أن يذكر النغمة الحالية والرقم ١٤. اضغطه وعُدّ المربعات.
٢. اسمع «زنبور» و«جرس إنذار» و«زيز» من تلك الشاشة، و«صفارة».
٣. اختر واحدة، احفظ، أعد فتح المنبه: يجب أن تبقى مختارة.
٤. بالعربية، الشاشة نفسها: المربعات معكوسة والأسماء أطول؛ يجب ألّا يُقطع شيء.""",
    "de-DE": """Build 10 behebt etwas, das du gefunden hast und ich nicht: du sagtest, die App habe vier Wecktöne. Sie hat vierzehn, seit Build 8. Nur vier waren zu sehen.

WARUM DU VIER GESEHEN HAST
Die Töne waren ein waagrechter Streifen kleiner Kacheln in der Klangkarte. Vier passen auf einen 6,9-Zoll-Bildschirm, drei auf einen 6,1-Zoll-, der Scrollbalken war ausgeblendet, und nichts sagte, dass es mehr gibt. Du hast den Bildschirm richtig gelesen; der Bildschirm hat gelogen.

WIE ES JETZT IST
Die Klangkarte hat eine Zeile: der Name des aktuellen Tons, sein Lautstärke-Symbol und die Zahl 14. Ein Tipp öffnet einen Bildschirm mit allen vierzehn Kacheln, drei pro Reihe, sanft zuerst, schlimm zuletzt, alle gleichzeitig sichtbar, ohne Scrollen auf jedem iPhone. Ein Tipp auf eine Kachel wählt sie und spielt eine Vorschau. Symbol und Farbe nennen die Klasse.

WAS DAS KÜNFTIG VERHINDERT
Ein Test öffnet diesen Bildschirm und prüft, dass alle vierzehn Kacheln im Fenster liegen und antippbar sind, nach null Wischern, auf Englisch und auf Arabisch. Ich habe den alten Streifen zurückgesetzt, um sicher zu sein, dass er scheitert: er scheitert. Ein zweiter Test prüft, dass ein gewählter Ton Speichern und Wiederöffnen übersteht.

ZU AUFGENOMMENEN KLÄNGEN
Du hast nach Open-Source-Quellen gefragt. Ich habe die Lizenzen an der Quelle geprüft, nicht in Zusammenfassungen, und das Ergebnis ist: alle vierzehn bleiben synthetisiert. Kurz gesagt: nur CC0-Audio darf ohne Einzelgenehmigung in eine bezahlte App-Store-Binärdatei, denn die FAQ von Creative Commons sagt selbst, dass die Veröffentlichung einer CC-BY-Datei über eine Plattform mit Kopierschutz die ausdrückliche Erlaubnis des Lizenzgebers braucht, und der App Store wendet ihn an. Die vollständige Liste steht in der Nachricht zu diesem Build.

WORAUF ES ANKOMMT
1. Editor, Klangzeile: sie soll den aktuellen Ton und 14 nennen. Antippen und Kacheln zählen.
2. Hornisse, Summer und Zikade von dort anhören, dazu Sirene.
3. Einen wählen, speichern, Wecker wieder öffnen: er muss gewählt bleiben.
4. Auf Arabisch derselbe Bildschirm: gespiegelt, längere Namen, nichts darf abgeschnitten sein.""",
    "es-ES": """La versión 10 corrige algo que encontraste tú y yo no: dijiste que la app tenía cuatro tonos. Tiene catorce, desde la versión 8. Solo cuatro estaban en pantalla.

POR QUÉ VEÍAS CUATRO
Los tonos eran una tira horizontal de fichas pequeñas dentro de la tarjeta de sonido. Cuatro caben en una pantalla de 6,9 pulgadas, tres en una de 6,1, el indicador de scroll estaba oculto y nada decía que hubiera más. Leíste bien la pantalla; la pantalla mentía.

CÓMO ES AHORA
La tarjeta de sonido tiene una fila: el nombre del tono actual, su icono de intensidad y el número 14. Al tocarla se abre una pantalla con las catorce fichas, tres por fila, de la más suave a la peor, todas visibles a la vez y sin scroll en cualquier iPhone. Tocar una la selecciona y suena una vista previa. El icono y su color dicen la clase.

QUÉ IMPIDE QUE VUELVA
Una prueba abre esa pantalla y comprueba que las catorce fichas están dentro de la ventana y se pueden tocar tras cero deslizamientos, en inglés y en árabe. Volví a poner la tira antigua para asegurarme de que falla: falla. Otra prueba comprueba que el tono elegido sobrevive al guardar y reabrir.

SOBRE AÑADIR SONIDOS GRABADOS
Pediste fuentes open source. Comprobé las licencias en su fuente, no en resúmenes, y la conclusión es que los catorce siguen sintetizados. En corto: solo el audio CC0 puede entrar en un binario de pago de la App Store sin pedir permiso a cada autor, porque las propias FAQ de Creative Commons dicen que publicar un archivo CC BY a través de una plataforma que aplica protección de copia requiere permiso expreso del licenciante, y la App Store la aplica. La lista completa va en el mensaje que acompaña a esta versión.

VALE LA PENA COMPROBAR
1. Editor, fila de sonido: debe decir el tono actual y 14. Tócala y cuenta las fichas.
2. Escucha Avispón, Zumbador y Cigarra desde ahí, y Sirena.
3. Elige uno, guarda, reabre la alarma: debe seguir seleccionado.
4. En árabe, la misma pantalla: fichas espejadas y nombres más largos; nada debe cortarse.""",
    "fr-FR": """La version 10 corrige quelque chose que tu as trouvé et moi pas : tu as dit que l'app avait quatre sonneries. Elle en a quatorze, depuis le build 8. Quatre seulement étaient à l'écran.

POURQUOI TU EN VOYAIS QUATRE
Les sonneries étaient une bande horizontale de petites tuiles dans la carte du son. Quatre tiennent sur un écran de 6,9 pouces, trois sur un 6,1, l'indicateur de défilement était masqué, et rien ne disait qu'il y en avait plus. Tu as lu l'écran correctement ; c'est l'écran qui mentait.

CE QUE C'EST MAINTENANT
La carte du son a une seule ligne : le nom de la sonnerie actuelle, son icône d'intensité, et le nombre 14. En la touchant, un écran s'ouvre avec les quatorze tuiles, trois par ligne, de la plus douce à la pire, toutes visibles d'un coup et sans défilement sur n'importe quel iPhone. Toucher une tuile la choisit et joue un extrait. L'icône et sa couleur disent la classe : une onde pour douce, deux pour standard, trois pour dure, un triangle rouge pour brutale.

CE QUI EMPÊCHE QUE ÇA REVIENNE
Un test ouvre cet écran et vérifie que les quatorze tuiles sont dans la fenêtre et touchables après zéro balayage, en anglais et en arabe. J'ai remis l'ancienne bande pour être sûr qu'il échoue : il échoue. Un second test vérifie qu'une sonnerie choisie survit à l'enregistrement et à la réouverture de l'alarme.

SUR L'AJOUT DE SONS ENREGISTRÉS
Tu as demandé des sources open source. J'ai vérifié les licences à la source, pas dans des résumés, et la conclusion est que les quatorze restent synthétisées. En bref : seul un son en CC0 peut entrer dans un binaire payant de l'App Store sans demander l'accord de chaque auteur, parce que la FAQ de Creative Commons dit elle-même que publier un fichier CC BY via une plateforme qui applique une protection anticopie exige la permission expresse du titulaire, et l'App Store en applique une. La liste complète de ce qui est utilisable et de ce qui a l'air libre sans l'être est dans le message qui accompagne ce build.

À VÉRIFIER
1. Éditeur, la ligne du son : elle doit afficher la sonnerie actuelle et 14. Touche-la et compte les tuiles.
2. Écoute Frelon, Buzzer et Cigale depuis cet écran, et Sirène.
3. Choisis-en une, enregistre, réouvre l'alarme : elle doit rester sélectionnée.
4. En arabe, le même écran : tuiles en miroir et noms plus longs ; rien ne doit être coupé.""",
    "hi": """बिल्ड 10 उस चीज़ को ठीक करता है जो आपने पकड़ी और मैंने नहीं: आपने कहा ऐप में चार अलार्म टोन हैं। इसमें चौदह हैं, बिल्ड 8 से। स्क्रीन पर सिर्फ़ चार थे।

आपको चार क्यों दिखे
टोन साउंड कार्ड के भीतर छोटी टाइलों की एक क्षैतिज पट्टी थे। 6.9 इंच पर चार आते हैं, 6.1 इंच पर तीन, स्क्रॉल संकेतक छिपा था, और कुछ नहीं बताता था कि और भी हैं। आपने स्क्रीन ठीक पढ़ी; स्क्रीन झूठ बोल रही थी।

अब यह कैसा है
साउंड कार्ड में एक पंक्ति है: वर्तमान टोन का नाम, उसका तीव्रता आइकन, और संख्या 14। उसे दबाने पर एक स्क्रीन खुलती है जिसमें सभी चौदह टाइलें, प्रति पंक्ति तीन, सबसे कोमल पहले और सबसे बुरी अंत में, सब एक साथ दिखती हैं, किसी भी iPhone पर बिना स्क्रॉल। टाइल दबाने से वह चुनी जाती है और झलक बजती है।

इसे लौटने से क्या रोकेगा
एक टेस्ट वह स्क्रीन खोलता है और जाँचता है कि चौदहों टाइलें विंडो के भीतर हैं और शून्य स्वाइप के बाद दबाई जा सकती हैं, अंग्रेज़ी और अरबी में। मैंने पुरानी पट्टी वापस लगाकर पक्का किया कि वह विफल हो: होती है। दूसरा टेस्ट जाँचता है कि चुनी टोन सेव और फिर खोलने पर बनी रहे।

रिकॉर्ड की गई आवाज़ें जोड़ने पर
आपने ओपन सोर्स स्रोत माँगे। मैंने लाइसेंस मूल स्रोत पर जाँचे, सारांश पर नहीं, और नतीजा यह है कि सभी चौदह संश्लेषित ही रहेंगी। संक्षेप में: केवल CC0 ऑडियो ही हर लेखक से अनुमति लिए बिना App Store के भुगतान वाले बाइनरी में जा सकता है, क्योंकि Creative Commons की अपनी FAQ कहती है कि प्रतिलिपि-सुरक्षा लगाने वाले प्लैटफ़ॉर्म से CC BY फ़ाइल प्रकाशित करने के लिए लाइसेंसकर्ता की स्पष्ट अनुमति चाहिए, और App Store वह लगाता है। पूरी सूची इस बिल्ड के साथ आए संदेश में है।

जाँचने योग्य
1. एडिटर, साउंड पंक्ति: वर्तमान टोन और 14 दिखे। दबाकर टाइलें गिनें।
2. वहीं से भिड़, बज़र और झींगुर सुनें, और सायरन।
3. एक चुनें, सेव करें, अलार्म फिर खोलें: वही चुनी रहनी चाहिए।
4. अरबी में वही स्क्रीन: टाइलें उलटी और नाम लंबे; कुछ कटना नहीं चाहिए।""",
    "it": """La build 10 risolve una cosa che hai trovato tu e io no: hai detto che l'app aveva quattro suonerie. Ne ha quattordici, dalla build 8. Solo quattro erano sullo schermo.

PERCHÉ NE VEDEVI QUATTRO
Le suonerie erano una striscia orizzontale di piccole caselle dentro la scheda del suono. Quattro stanno su uno schermo da 6,9 pollici, tre su uno da 6,1, l'indicatore di scorrimento era nascosto e niente diceva che ce ne fossero altre. Hai letto bene lo schermo; era lo schermo a mentire.

COM'È ADESSO
La scheda del suono ha una riga: il nome della suoneria attuale, la sua icona di intensità e il numero 14. Toccandola si apre una schermata con tutte e quattordici le caselle, tre per riga, dalla più gentile alla peggiore, tutte visibili insieme e senza scorrimento su qualsiasi iPhone. Toccarne una la seleziona e ne suona un'anteprima.

COSA IMPEDISCE CHE TORNI
Un test apre quella schermata e verifica che tutte e quattordici le caselle siano dentro la finestra e toccabili dopo zero passate di dito, in inglese e in arabo. Ho rimesso la vecchia striscia per essere sicuro che fallisca: fallisce. Un secondo test verifica che la suoneria scelta sopravviva al salvataggio e alla riapertura.

SULL'AGGIUNTA DI SUONI REGISTRATI
Hai chiesto fonti open source. Ho verificato le licenze alla fonte, non nei riassunti, e la conclusione è che tutte e quattordici restano sintetizzate. In breve: solo l'audio CC0 può entrare in un binario a pagamento dell'App Store senza chiedere permesso a ogni autore, perché le FAQ di Creative Commons dicono che pubblicare un file CC BY tramite una piattaforma che applica protezione anticopia richiede il permesso espresso del licenziante, e l'App Store la applica. L'elenco completo è nel messaggio che accompagna questa build.

VALE LA PENA CONTROLLARE
1. Editor, riga del suono: deve dire la suoneria attuale e 14. Toccala e conta le caselle.
2. Ascolta Vespone, Cicalino e Cicala da lì, e Sirena.
3. Scegline una, salva, riapri la sveglia: deve restare selezionata.
4. In arabo, la stessa schermata: caselle specchiate e nomi più lunghi; niente deve essere tagliato.""",
    "ja": """ビルド 10 は、あなたが見つけて私が見落としていた問題を直します。「アラーム音は 4 つしかない」と言われましたが、ビルド 8 から 14 あります。画面に出ていたのが 4 つでした。

なぜ 4 つに見えたか
音の一覧は、サウンドカードの中の小さなタイルの横並びでした。6.9 インチで 4 つ、6.1 インチで 3 つしか入らず、スクロールバーは隠してあり、続きがあることをどこにも書いていませんでした。画面の読み方は正しく、画面が嘘をついていました。

いまの形
サウンドカードは 1 行になりました。現在の音の名前、強さのアイコン、そして 14 という数。触れると、14 個のタイルが 3 列で並ぶ画面が開きます。やさしい順から最悪の順まで、どの iPhone でもスクロールなしで全部見えます。タイルを触ると選択され、試聴が鳴ります。

再発を防ぐもの
テストがその画面を開き、14 個すべてがウインドウ内にあり、スワイプ 0 回で押せることを英語とアラビア語で確認します。念のため古い横並びに戻して失敗することも確かめました。もう 1 つのテストは、選んだ音が保存と再オープンを越えて残ることを見ます。

録音素材の追加について
オープンソースの入手先を求められました。要約ではなく一次情報でライセンスを確認した結果、14 音はすべて合成のままにします。理由を一言で言えば、有料の App Store バイナリに作者ごとの許諾なしで入れられるのは CC0 の音だけだからです。Creative Commons 自身の FAQ が、コピー保護を施すプラットフォーム経由で CC BY ファイルを公開するには権利者の明示的な許可が必要だと述べており、App Store はそれを施します。使えるものと、無料に見えて使えないものの一覧は、この配信に添えたメッセージにあります。

確認してほしいこと
1. 編集画面のサウンド行：現在の音と 14 が出ること。触ってタイルを数える。
2. その画面からスズメバチ、ブザー、セミ、そしてサイレンを試聴。
3. 1 つ選んで保存し、アラームを開き直す：選択が残っていること。
4. アラビア語で同じ画面：左右が反転し名前も長い。切れがないこと。""",
    "ko": """빌드 10은 당신이 찾고 제가 놓친 문제를 고칩니다. 앱에 알람음이 네 개라고 하셨죠. 빌드 8부터 열네 개입니다. 화면에 네 개만 보였던 겁니다.

왜 네 개로 보였나
소리 카드 안의 작은 타일들이 가로로 늘어선 띠였습니다. 6.9인치에서 네 개, 6.1인치에서 세 개만 들어가고, 스크롤 표시는 숨겨 두었고, 더 있다는 표시가 어디에도 없었습니다. 화면을 정확히 읽으신 겁니다. 화면이 거짓말을 했습니다.

지금은
소리 카드에 한 줄이 있습니다. 현재 음의 이름, 세기 아이콘, 그리고 숫자 14. 누르면 열네 개 타일이 한 줄에 세 개씩 놓인 화면이 열립니다. 부드러운 것부터 최악까지, 어느 iPhone에서도 스크롤 없이 전부 보입니다. 타일을 누르면 선택되고 미리듣기가 재생됩니다.

재발을 막는 것
테스트가 그 화면을 열어 열네 타일이 모두 창 안에 있고 스와이프 0회로 누를 수 있는지 영어와 아랍어로 확인합니다. 확실히 하려고 옛 띠를 되돌려 실패하는 것도 확인했습니다. 두 번째 테스트는 고른 음이 저장과 재열기를 넘어 남는지 봅니다.

녹음 소리를 넣는 문제
오픈 소스 출처를 요청하셨습니다. 요약이 아니라 원본에서 라이선스를 확인한 결과, 열네 개 모두 합성으로 유지합니다. 요약하면, 유료 App Store 바이너리에 저자별 허락 없이 넣을 수 있는 것은 CC0 오디오뿐입니다. Creative Commons의 FAQ 자체가 복사 보호를 적용하는 플랫폼을 통해 CC BY 파일을 공개하려면 권리자의 명시적 허락이 필요하다고 말하고, App Store는 그것을 적용합니다. 사용 가능한 것과 무료처럼 보이지만 아닌 것의 전체 목록은 이 빌드와 함께 보낸 메시지에 있습니다.

확인해 주세요
1. 편집기의 소리 줄: 현재 음과 14가 보일 것. 눌러서 타일을 세어 보기.
2. 그 화면에서 말벌, 부저, 매미, 그리고 사이렌 미리듣기.
3. 하나 고르고 저장한 뒤 알람을 다시 열기: 선택이 남아야 합니다.
4. 아랍어로 같은 화면: 좌우가 뒤집히고 이름도 깁니다. 잘리는 것이 없어야 합니다.""",
    "pt-BR": """A build 10 corrige algo que você achou e eu não: você disse que o app tinha quatro toques. Tem quatorze, desde a build 8. Só quatro apareciam.

POR QUE VOCÊ VIA QUATRO
Os toques eram uma faixa horizontal de blocos pequenos dentro do cartão de som. Quatro cabem numa tela de 6,9 polegadas, três numa de 6,1, o indicador de rolagem estava escondido e nada dizia que havia mais. Você leu a tela certo; a tela mentia.

COMO ESTÁ AGORA
O cartão de som tem uma linha: o nome do toque atual, o ícone de intensidade e o número 14. Ao tocar, abre uma tela com os quatorze blocos, três por linha, do mais suave ao pior, todos visíveis de uma vez e sem rolagem em qualquer iPhone. Tocar um bloco seleciona e toca uma prévia.

O QUE IMPEDE QUE VOLTE
Um teste abre essa tela e verifica que os quatorze blocos estão dentro da janela e podem ser tocados após zero deslizes, em inglês e em árabe. Recoloquei a faixa antiga para garantir que falha: falha. Um segundo teste verifica que o toque escolhido sobrevive a salvar e reabrir.

SOBRE ADICIONAR SONS GRAVADOS
Você pediu fontes open source. Conferi as licenças na fonte, não em resumos, e a conclusão é que os quatorze seguem sintetizados. Em resumo: só áudio CC0 pode entrar num binário pago da App Store sem pedir permissão a cada autor, porque o próprio FAQ da Creative Commons diz que publicar um arquivo CC BY por uma plataforma que aplica proteção de cópia exige permissão expressa do licenciante, e a App Store aplica. A lista completa está na mensagem que acompanha esta build.

VALE CONFERIR
1. Editor, linha do som: deve dizer o toque atual e 14. Toque e conte os blocos.
2. Ouça Vespão, Cigarra e Cigarra elétrica de lá, e Sirene.
3. Escolha um, salve, reabra o alarme: precisa continuar selecionado.
4. Em árabe, a mesma tela: blocos espelhados e nomes mais longos; nada pode ficar cortado.""",
    "ru": """Сборка 10 исправляет то, что нашли вы, а я нет: вы сказали, что в приложении четыре сигнала. Их четырнадцать, начиная со сборки 8. На экране было четыре.

ПОЧЕМУ ВЫ ВИДЕЛИ ЧЕТЫРЕ
Сигналы были горизонтальной полосой маленьких плиток внутри карточки звука. Четыре влезают на экран 6,9 дюйма, три на 6,1, индикатор прокрутки был скрыт, и ничто не говорило, что есть ещё. Вы прочитали экран правильно; лгал экран.

КАК ЭТО ТЕПЕРЬ
В карточке звука одна строка: название текущего сигнала, значок громкости и число 14. По нажатию открывается экран со всеми четырнадцатью плитками, по три в ряд, от самого мягкого до самого злого, все видны сразу и без прокрутки на любом iPhone. Нажатие выбирает плитку и проигрывает отрывок.

ЧТО МЕШАЕТ ЭТОМУ ВЕРНУТЬСЯ
Тест открывает этот экран и проверяет, что все четырнадцать плиток внутри окна и нажимаемы после нуля свайпов, по-английски и по-арабски. Я вернул старую полосу, чтобы убедиться, что он падает: падает. Второй тест проверяет, что выбранный сигнал переживает сохранение и повторное открытие.

О ДОБАВЛЕНИИ ЗАПИСАННЫХ ЗВУКОВ
Вы просили список открытых источников. Я проверил лицензии по первоисточникам, а не по пересказам, и вывод такой: все четырнадцать остаются синтезированными. Коротко: в платный бинарник App Store без разрешения каждого автора можно взять только звук под CC0, потому что собственный FAQ Creative Commons говорит, что публикация файла CC BY через платформу, применяющую защиту от копирования, требует явного разрешения правообладателя, а App Store её применяет. Полный список того, что годится и что только кажется свободным, в сообщении к этой сборке.

СТОИТ ПРОВЕРИТЬ
1. Редактор, строка звука: должна показать текущий сигнал и 14. Нажмите и посчитайте плитки.
2. Послушайте оттуда Шершня, Зуммер и Цикаду, а также Сирену.
3. Выберите один, сохраните, откройте будильник снова: выбор должен остаться.
4. По-арабски тот же экран: плитки зеркальны, названия длиннее; ничего не должно обрезаться.""",
    "zh-Hans": """版本 10 修好了一件你发现、我没发现的事：你说应用只有四个铃声。它有十四个，从版本 8 开始就有。只是屏幕上只出现四个。

为什么你看到四个
铃声原本是声音卡片里一排小方块的横向条。6.9 英寸屏放得下四个，6.1 英寸三个，滚动条被隐藏了，也没有任何提示说还有更多。你把屏幕读对了，是屏幕在骗人。

现在是什么样
声音卡片只有一行：当前铃声的名字、它的强度图标，以及数字 14。点它会打开一个页面，十四个方块每行三个全部排开，从最温和到最凶，在任何 iPhone 上都无需滚动就能全部看到。点一个即选中并试听。

什么能防止它再发生
一个测试会打开该页面，检查十四个方块都在窗口内、且在零次滑动后可点，英文和阿拉伯文各跑一遍。我把旧的横条放回去确认它会失败：确实失败。第二个测试检查选中的铃声能在保存并重新打开后保持。

关于加入录音素材
你要的是开源来源。我按一手来源核对了许可，而不是看摘要，结论是十四个铃声全部继续用合成。简短理由：只有 CC0 音频可以在不逐一征得作者同意的情况下进入付费的 App Store 二进制包，因为 Creative Commons 自己的 FAQ 就说，通过施加复制保护的平台发布 CC BY 文件需要权利人的明确许可，而 App Store 会施加保护。可用的与看着免费其实不可用的完整清单，在随这个版本发出的消息里。

值得验证
1. 编辑器里的声音那一行：应显示当前铃声和 14。点开并数方块。
2. 在那个页面试听马蜂、蜂鸣器、蝉鸣，以及警报。
3. 选一个、保存、重新打开闹钟：应仍然是选中状态。
4. 用阿拉伯文看同一页面：方块镜像、名字更长；不应有被截断的地方。""",
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

FREE, ALL OF IT

Every mission, every difficulty, up to ten rounds, as many alarms as your week needs, and ninety days of history. There is nothing to buy: no subscription, no adverts, no account.

Privacy policy: https://dawnbreak.app/privacy.html
Terms of use: https://dawnbreak.app/terms.html
Support: https://dawnbreak.app/support.html""",
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

مجاني بالكامل

كل المهام، كل درجات الصعوبة، حتى عشر جولات، وعدد المنبهات الذي يحتاجه أسبوعك، وتسعون يوماً من السجل. لا شيء للبيع: بلا اشتراك، بلا إعلانات، بلا حساب.

سياسة الخصوصية: https://dawnbreak.app/privacy.html
شروط الاستخدام: https://dawnbreak.app/terms.html
الدعم: https://dawnbreak.app/support.html""",
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

GRATIS, ALLES DAVON

Jede Mission, jeder Schwierigkeitsgrad, bis zu zehn Runden, so viele Alarme wie deine Woche braucht, neunzig Tage Verlauf. Es gibt nichts zu kaufen: kein Abo, keine Werbung, kein Konto.

Datenschutz: https://dawnbreak.app/privacy.html
Nutzungsbedingungen: https://dawnbreak.app/terms.html
Support: https://dawnbreak.app/support.html""",
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

GRATIS, SIN EXCEPCIONES

Todas las misiones, todas las dificultades, hasta diez rondas, tantas alarmas como necesite tu semana y noventa días de historial. No hay nada que comprar: ni suscripción, ni anuncios, ni cuenta.

Privacidad: https://dawnbreak.app/privacy.html
Términos de uso: https://dawnbreak.app/terms.html
Soporte: https://dawnbreak.app/support.html""",
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

GRATUIT, EN ENTIER

Toutes les missions, toutes les difficultés, jusqu’à dix manches, autant d’alarmes que votre semaine en demande, quatre-vingt-dix jours d’historique. Il n’y a rien à acheter : aucun abonnement, aucune publicité, aucun compte.

Confidentialité : https://dawnbreak.app/privacy.html
Conditions d’utilisation : https://dawnbreak.app/terms.html
Assistance : https://dawnbreak.app/support.html""",
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

पूरा मुफ़्त

सभी मिशन, सभी कठिनाइयाँ, दस राउंड तक, जितने अलार्म आपके हफ़्ते को चाहिए उतने, और नब्बे दिन का इतिहास। ख़रीदने के लिए कुछ नहीं है: कोई सदस्यता नहीं, कोई विज्ञापन नहीं, कोई अकाउंट नहीं।

गोपनीयता: https://dawnbreak.app/privacy.html
उपयोग की शर्तें: https://dawnbreak.app/terms.html
सहायता: https://dawnbreak.app/support.html""",
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

GRATIS, TUTTO

Tutte le missioni, tutte le difficoltà, fino a dieci turni, tutte le sveglie che la tua settimana richiede, novanta giorni di cronologia. Non c’è nulla da comprare: nessun abbonamento, nessuna pubblicità, nessun account.

Privacy: https://dawnbreak.app/privacy.html
Termini d’uso: https://dawnbreak.app/terms.html
Assistenza: https://dawnbreak.app/support.html""",
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

【すべて無料】

ミッション 12 種類すべて、難易度 4 段階すべて、最大 10 ラウンド、一週間に必要なだけのアラーム、履歴 90 日分。購入するものはありません。サブスクリプションも広告もアカウントもなし。

プライバシーポリシー：https://dawnbreak.app/privacy.html
利用規約：https://dawnbreak.app/terms.html
サポート：https://dawnbreak.app/support.html""",
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

【전부 무료】

미션 12가지 전부, 난이도 4단계 전부, 최대 10라운드, 한 주에 필요한 만큼의 알람, 기록 90일. 살 것이 없습니다. 구독도 광고도 계정도 없습니다.

개인정보 처리방침: https://dawnbreak.app/privacy.html
이용약관: https://dawnbreak.app/terms.html
지원: https://dawnbreak.app/support.html""",
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

GRÁTIS, TUDO

Todas as missões, todas as dificuldades, até dez rodadas, quantos alarmes a sua semana precisar e noventa dias de histórico. Não há nada para comprar: nenhuma assinatura, nenhum anúncio, nenhuma conta.

Privacidade: https://dawnbreak.app/privacy.html
Termos de uso: https://dawnbreak.app/terms.html
Suporte: https://dawnbreak.app/support.html""",
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

БЕСПЛАТНО, ЦЕЛИКОМ

Все задания, все уровни сложности, до десяти раундов, столько будильников, сколько нужно вашей неделе, девяносто дней истории. Покупать нечего: ни подписки, ни рекламы, ни аккаунта.

Конфиденциальность: https://dawnbreak.app/privacy.html
Условия использования: https://dawnbreak.app/terms.html
Поддержка: https://dawnbreak.app/support.html""",
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

【全部免费】

全部十二种任务、全部四档难度、最多十轮、你这一周需要的任意数量的闹钟，以及九十天历史记录。没有任何东西可买：没有订阅，没有广告，也没有账号。

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
