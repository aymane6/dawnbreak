"""App chrome: buttons, errors, time formatting, and the enum-derived families.

Order of values in every row: en ar de es fr hi it ja ko pt-BR ru zh-Hans
"""

from . import family

CHROME = {
    "app.name": ["Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak"],
    "tab.alarms": ["Alarms", "المنبهات", "Alarme", "Alarmas", "Alarmes", "अलार्म", "Sveglie", "アラーム", "알람", "Alarmes", "Будильники", "闹钟"],
    "tab.stats": ["Stats", "الإحصاءات", "Statistik", "Datos", "Stats", "आँकड़े", "Statistiche", "統計", "통계", "Dados", "Статистика", "统计"],
    "tab.settings": ["Settings", "الإعدادات", "Einstellungen", "Ajustes", "Réglages", "सेटिंग", "Impostazioni", "設定", "설정", "Ajustes", "Настройки", "设置"],

    "action.save": ["Save", "حفظ", "Speichern", "Guardar", "Enregistrer", "सेव करें", "Salva", "保存", "저장", "Salvar", "Сохранить", "保存"],
    "action.cancel": ["Cancel", "إلغاء", "Abbrechen", "Cancelar", "Annuler", "रद्द करें", "Annulla", "キャンセル", "취소", "Cancelar", "Отмена", "取消"],
    "action.delete": ["Delete", "حذف", "Löschen", "Eliminar", "Supprimer", "हटाएँ", "Elimina", "削除", "삭제", "Excluir", "Удалить", "删除"],
    "action.deleteAlarm": ["Delete alarm", "حذف المنبه", "Alarm löschen", "Eliminar alarma", "Supprimer l’alarme", "अलार्म हटाएँ", "Elimina sveglia", "アラームを削除", "알람 삭제", "Excluir alarme", "Удалить будильник", "删除闹钟"],
    "action.close": ["Close", "إغلاق", "Schließen", "Cerrar", "Fermer", "बंद करें", "Chiudi", "閉じる", "닫기", "Fechar", "Закрыть", "关闭"],
    "action.ok": ["OK", "حسناً", "OK", "OK", "OK", "ठीक है", "OK", "OK", "확인", "OK", "ОК", "好"],
    "action.openSettings": ["Open Settings", "فتح الإعدادات", "Einstellungen öffnen", "Abrir Ajustes", "Ouvrir Réglages", "सेटिंग खोलें", "Apri Impostazioni", "設定を開く", "설정 열기", "Abrir Ajustes", "Открыть настройки", "打开设置"],

    "legal.privacy": ["Privacy Policy", "سياسة الخصوصية", "Datenschutz", "Privacidad", "Confidentialité", "गोपनीयता नीति", "Privacy", "プライバシーポリシー", "개인정보 처리방침", "Privacidade", "Политика конфиденциальности", "隐私政策"],
    "legal.terms": ["Terms of Use", "شروط الاستخدام", "Nutzungsbedingungen", "Términos de uso", "Conditions d’utilisation", "उपयोग की शर्तें", "Termini d’uso", "利用規約", "이용약관", "Termos de uso", "Условия использования", "使用条款"],

    # A middot with hairline spaces, identical in every locale including Arabic: it separates
    # two already-localized fragments and must not pick up direction of its own.
    "list.separator": [" · ", " · ", " · ", " · ", " · ", " · ", " · ", " · ", " · ", " · ", " · ", " · "],
}

ERRORS = {
    "error.title": ["Something went wrong", "حدث خطأ ما", "Etwas ist schiefgelaufen", "Se ha producido un error", "Une erreur est survenue", "कुछ गलत हो गया", "Qualcosa è andato storto", "問題が発生しました", "문제가 발생했습니다", "Algo deu errado", "Что-то пошло не так", "出错了"],
    "error.saveFailed": ["This alarm could not be saved, so it will not survive closing the app. Free up some storage and try again.", "لم يتم حفظ هذا المنبه، لذا لن يبقى بعد إغلاق التطبيق. حرّر بعض المساحة وحاول مرة أخرى.", "Dieser Alarm konnte nicht gespeichert werden und übersteht das Schließen der App nicht. Schaffe Speicherplatz und versuche es erneut.", "No se ha podido guardar esta alarma, así que no sobrevivirá al cierre de la app. Libera espacio e inténtalo de nuevo.", "Cette alarme n’a pas pu être enregistrée : elle ne survivra pas à la fermeture de l’app. Libérez de l’espace et réessayez.", "यह अलार्म सेव नहीं हो सका, इसलिए ऐप बंद करने पर यह चला जाएगा। कुछ जगह खाली करें और फिर कोशिश करें।", "Non è stato possibile salvare questa sveglia: non sopravvivrà alla chiusura dell’app. Libera spazio e riprova.", "このアラームを保存できませんでした。アプリを閉じると失われます。空き容量を作ってからやり直してください。", "이 알람을 저장할 수 없어 앱을 닫으면 사라집니다. 저장 공간을 확보한 뒤 다시 시도하세요.", "Não foi possível salvar este alarme, então ele não vai sobreviver ao fechamento do app. Libere espaço e tente de novo.", "Не удалось сохранить будильник — он не сохранится после закрытия приложения. Освободите место и попробуйте снова.", "无法保存该闹钟，关闭应用后它会消失。请清理一些存储空间后重试。"],
    "error.scheduleFailed": ["iOS refused to schedule this alarm. It is saved, but it will not ring until you fix this.", "رفض iOS جدولة هذا المنبه. تم حفظه، لكنه لن يرن حتى تعالج المشكلة.", "iOS hat diesen Alarm nicht angenommen. Er ist gespeichert, klingelt aber nicht, bis das behoben ist.", "iOS ha rechazado programar esta alarma. Está guardada, pero no sonará hasta que lo soluciones.", "iOS a refusé de programmer cette alarme. Elle est enregistrée, mais elle ne sonnera pas tant que ce n’est pas réglé.", "iOS ने इस अलार्म को शेड्यूल करने से इनकार कर दिया। यह सेव है, लेकिन ठीक होने तक बजेगा नहीं।", "iOS ha rifiutato di programmare questa sveglia. È salvata, ma non suonerà finché non risolvi.", "iOS がこのアラームの登録を拒否しました。保存はされていますが、解決するまで鳴りません。", "iOS가 이 알람 등록을 거부했습니다. 저장은 되었지만 해결하기 전까지는 울리지 않습니다.", "O iOS recusou agendar este alarme. Ele está salvo, mas não vai tocar até você resolver isso.", "iOS отказался запланировать этот будильник. Он сохранён, но не прозвонит, пока проблема не решена.", "iOS 拒绝了该闹钟的排程。闹钟已保存，但在问题解决前不会响。"],
    "error.authorizationFailed": ["Dawnbreak could not ask for alarm permission. Grant it in Settings instead.", "لم يتمكن Dawnbreak من طلب إذن المنبه. امنحه من الإعدادات بدلاً من ذلك.", "Dawnbreak konnte die Alarm-Berechtigung nicht anfragen. Erteile sie stattdessen in den Einstellungen.", "Dawnbreak no ha podido pedir el permiso de alarmas. Concédelo desde Ajustes.", "Dawnbreak n’a pas pu demander l’autorisation d’alarme. Accordez-la dans Réglages.", "Dawnbreak अलार्म की अनुमति नहीं माँग सका। इसे सेटिंग से दें।", "Dawnbreak non ha potuto chiedere il permesso per le sveglie. Concedilo da Impostazioni.", "Dawnbreak はアラームの許可を要求できませんでした。設定から許可してください。", "Dawnbreak가 알람 권한을 요청할 수 없었습니다. 설정에서 직접 허용하세요.", "O Dawnbreak não conseguiu pedir permissão de alarmes. Conceda em Ajustes.", "Dawnbreak не смог запросить разрешение на будильники. Выдайте его в настройках.", "Dawnbreak 无法请求闹钟权限。请改在“设置”中授予。"],
    "error.alarmPermissionDenied": ["Alarm permission is off, so nothing you set here will ring.", "إذن المنبه معطّل، لذا لن يرن أي شيء تضبطه هنا.", "Die Alarm-Berechtigung ist aus — nichts, was du hier einstellst, klingelt.", "El permiso de alarmas está desactivado: nada de lo que configures aquí sonará.", "L’autorisation d’alarme est désactivée : rien de ce que vous réglez ici ne sonnera.", "अलार्म की अनुमति बंद है, इसलिए यहाँ सेट किया कुछ भी नहीं बजेगा।", "Il permesso per le sveglie è disattivato: niente di ciò che imposti qui suonerà.", "アラームの許可がオフです。ここで設定しても鳴りません。", "알람 권한이 꺼져 있어 여기서 설정한 것은 울리지 않습니다.", "A permissão de alarmes está desativada, então nada configurado aqui vai tocar.", "Разрешение на будильники отключено — ничто из настроенного здесь не прозвонит.", "闹钟权限已关闭，你在这里设置的任何内容都不会响。"],
    "error.tooManyAlarms": ["iOS allows a limited number of alarms at once. Turn one off to add this one.", "يسمح iOS بعدد محدود من المنبهات في الوقت نفسه. أوقف أحدها لإضافة هذا.", "iOS erlaubt nur eine begrenzte Zahl gleichzeitiger Alarme. Schalte einen aus, um diesen hinzuzufügen.", "iOS permite un número limitado de alarmas a la vez. Desactiva una para añadir esta.", "iOS limite le nombre d’alarmes simultanées. Désactivez-en une pour ajouter celle-ci.", "iOS एक समय में सीमित अलार्म की अनुमति देता है। इसे जोड़ने के लिए एक बंद करें।", "iOS consente un numero limitato di sveglie attive. Disattivane una per aggiungere questa.", "iOS が同時に登録できるアラーム数には上限があります。追加するには 1 つオフにしてください。", "iOS는 동시에 등록할 수 있는 알람 수에 제한이 있습니다. 하나를 끄고 추가하세요.", "O iOS permite um número limitado de alarmes ao mesmo tempo. Desative um para adicionar este.", "iOS допускает ограниченное число одновременных будильников. Отключите один, чтобы добавить этот.", "iOS 同时允许的闹钟数量有限。请先关闭一个再添加。"],
    "error.missionNeedsSetup": ["This mission needs something registered first. Open the alarm and finish setting it up.", "تحتاج هذه المهمة إلى تسجيل شيء أولاً. افتح المنبه وأكمل إعداده.", "Für diese Mission muss zuerst etwas registriert werden. Öffne den Alarm und richte sie fertig ein.", "Esta misión necesita registrar algo antes. Abre la alarma y termina de configurarla.", "Cette mission exige d’abord d’enregistrer quelque chose. Ouvrez l’alarme et terminez la configuration.", "इस मिशन के लिए पहले कुछ रजिस्टर करना ज़रूरी है। अलार्म खोलें और सेटअप पूरा करें।", "Questa missione richiede prima di registrare qualcosa. Apri la sveglia e completa la configurazione.", "このミッションには先に登録が必要です。アラームを開いて設定を完了してください。", "이 미션은 먼저 등록이 필요합니다. 알람을 열어 설정을 마치세요.", "Esta missão precisa que algo seja registrado antes. Abra o alarme e conclua a configuração.", "Для этого задания сначала нужно кое-что зарегистрировать. Откройте будильник и завершите настройку.", "该任务需要先注册一样东西。请打开闹钟并完成设置。"],

    "permission.alarm.deniedTitle": ["Alarms are blocked", "المنبهات محجوبة", "Alarme sind blockiert", "Las alarmas están bloqueadas", "Les alarmes sont bloquées", "अलार्म ब्लॉक हैं", "Le sveglie sono bloccate", "アラームがブロックされています", "알람이 차단되어 있습니다", "Os alarmes estão bloqueados", "Будильники заблокированы", "闹钟被阻止"],
    "permission.alarm.deniedBody": ["Dawnbreak cannot ring until you allow alarms. Nothing on this screen will wake you up.", "لا يمكن لـ Dawnbreak أن يرن حتى تسمح بالمنبهات. لن يوقظك أي شيء في هذه الشاشة.", "Dawnbreak kann nicht klingeln, solange du Alarme nicht erlaubst. Nichts auf diesem Bildschirm weckt dich.", "Dawnbreak no puede sonar hasta que permitas las alarmas. Nada de esta pantalla te despertará.", "Dawnbreak ne peut pas sonner tant que vous n’autorisez pas les alarmes. Rien sur cet écran ne vous réveillera.", "जब तक आप अलार्म की अनुमति नहीं देते, Dawnbreak बज नहीं सकता। इस स्क्रीन पर कुछ भी आपको नहीं जगाएगा।", "Dawnbreak non può suonare finché non consenti le sveglie. Niente in questa schermata ti sveglierà.", "アラームを許可するまで Dawnbreak は鳴りません。この画面にあるものではあなたは起きられません。", "알람을 허용하기 전까지 Dawnbreak는 울릴 수 없습니다. 이 화면의 어떤 것도 당신을 깨우지 못합니다.", "O Dawnbreak não pode tocar até você permitir alarmes. Nada nesta tela vai te acordar.", "Dawnbreak не сможет прозвонить, пока вы не разрешите будильники. Ничто на этом экране вас не разбудит.", "在你允许闹钟之前，Dawnbreak 无法响铃。此页面上的任何内容都不会叫醒你。"],
}

TIME = {
    "clock.am": ["AM", "ص", "AM", "a. m.", "AM", "am", "AM", "午前", "오전", "AM", "AM", "上午"],
    "clock.pm": ["PM", "م", "PM", "p. m.", "PM", "pm", "PM", "午後", "오후", "PM", "PM", "下午"],
    # %1$@ is the time, %2$@ the AM/PM label. East Asian locales put the label first, which is
    # exactly the reason this is a key and not a hardcoded `"\(time) \(meridiem)"`.
    "clock.order": ["%1$@ %2$@", "%1$@ %2$@", "%1$@ %2$@", "%1$@ %2$@", "%1$@ %2$@", "%1$@ %2$@", "%1$@ %2$@", "%2$@%1$@", "%2$@ %1$@", "%1$@ %2$@", "%1$@ %2$@", "%2$@%1$@"],

    "countdown.days": ["in %1$lld d %2$lld h", "بعد %1$lld ي %2$lld س", "in %1$lld T %2$lld Std.", "en %1$lld d %2$lld h", "dans %1$lld j %2$lld h", "%1$lld दिन %2$lld घं में", "tra %1$lld g %2$lld h", "%1$lld日%2$lld時間後", "%1$lld일 %2$lld시간 후", "em %1$lld d %2$lld h", "через %1$lld д %2$lld ч", "%1$lld 天 %2$lld 小时后"],
    "countdown.hoursMinutes": ["in %1$lld h %2$lld min", "بعد %1$lld س %2$lld د", "in %1$lld Std. %2$lld Min.", "en %1$lld h %2$lld min", "dans %1$lld h %2$lld min", "%1$lld घं %2$lld मि में", "tra %1$lld h %2$lld min", "%1$lld時間%2$lld分後", "%1$lld시간 %2$lld분 후", "em %1$lld h %2$lld min", "через %1$lld ч %2$lld мин", "%1$lld 小时 %2$lld 分后"],
    "countdown.minutes": ["in %lld min", "بعد %lld د", "in %lld Min.", "en %lld min", "dans %lld min", "%lld मि में", "tra %lld min", "%lld分後", "%lld분 후", "em %lld min", "через %lld мин", "%lld 分钟后"],
    "countdown.imminent": ["any second now", "في أي لحظة", "jede Sekunde", "en cualquier momento", "d’une seconde à l’autre", "किसी भी पल", "da un momento all’altro", "まもなく", "곧 울립니다", "a qualquer momento", "вот-вот", "马上就响"],

    "duration.seconds": ["%lld s", "%lld ث", "%lld s", "%lld s", "%lld s", "%lld से", "%lld s", "%lld秒", "%lld초", "%lld s", "%lld с", "%lld 秒"],
    "duration.minutes": ["%lld min", "%lld د", "%lld Min.", "%lld min", "%lld min", "%lld मि", "%lld min", "%lld分", "%lld분", "%lld min", "%lld мин", "%lld 分钟"],
    "duration.minutesSeconds": ["%1$lld min %2$lld s", "%1$lld د %2$lld ث", "%1$lld Min. %2$lld s", "%1$lld min %2$lld s", "%1$lld min %2$lld s", "%1$lld मि %2$lld से", "%1$lld min %2$lld s", "%1$lld分%2$lld秒", "%1$lld분 %2$lld초", "%1$lld min %2$lld s", "%1$lld мин %2$lld с", "%1$lld 分 %2$lld 秒"],
}

# MARK: - Enum-derived families

WEEKDAYS = family("weekday.", "", {
    "monday": ["Monday", "الاثنين", "Montag", "lunes", "lundi", "सोमवार", "lunedì", "月曜日", "월요일", "segunda-feira", "понедельник", "星期一"],
    "tuesday": ["Tuesday", "الثلاثاء", "Dienstag", "martes", "mardi", "मंगलवार", "martedì", "火曜日", "화요일", "terça-feira", "вторник", "星期二"],
    "wednesday": ["Wednesday", "الأربعاء", "Mittwoch", "miércoles", "mercredi", "बुधवार", "mercoledì", "水曜日", "수요일", "quarta-feira", "среда", "星期三"],
    "thursday": ["Thursday", "الخميس", "Donnerstag", "jueves", "jeudi", "गुरुवार", "giovedì", "木曜日", "목요일", "quinta-feira", "четверг", "星期四"],
    "friday": ["Friday", "الجمعة", "Freitag", "viernes", "vendredi", "शुक्रवार", "venerdì", "金曜日", "금요일", "sexta-feira", "пятница", "星期五"],
    "saturday": ["Saturday", "السبت", "Samstag", "sábado", "samedi", "शनिवार", "sabato", "土曜日", "토요일", "sábado", "суббота", "星期六"],
    "sunday": ["Sunday", "الأحد", "Sonntag", "domingo", "dimanche", "रविवार", "domenica", "日曜日", "일요일", "domingo", "воскресенье", "星期日"],
})

# The seven-column day picker. Arabic uses CLDR's narrow forms because its abbreviated forms
# are the full words and would blow the column apart.
WEEKDAYS_SHORT = family("weekday.", ".short", {
    "monday": ["Mon", "ن", "Mo", "lun", "lun.", "सोम", "lun", "月", "월", "seg", "пн", "一"],
    "tuesday": ["Tue", "ث", "Di", "mar", "mar.", "मंगल", "mar", "火", "화", "ter", "вт", "二"],
    "wednesday": ["Wed", "ر", "Mi", "mié", "mer.", "बुध", "mer", "水", "수", "qua", "ср", "三"],
    "thursday": ["Thu", "خ", "Do", "jue", "jeu.", "गुरु", "gio", "木", "목", "qui", "чт", "四"],
    "friday": ["Fri", "ج", "Fr", "vie", "ven.", "शुक्र", "ven", "金", "금", "sex", "пт", "五"],
    "saturday": ["Sat", "س", "Sa", "sáb", "sam.", "शनि", "sab", "土", "토", "sáb", "сб", "六"],
    "sunday": ["Sun", "ح", "So", "dom", "dim.", "रवि", "dom", "日", "일", "dom", "вс", "日"],
})

REPEAT = {
    "repeat.never": ["Once", "مرة واحدة", "Einmal", "Una vez", "Une fois", "एक बार", "Una volta", "1 回のみ", "한 번", "Uma vez", "Один раз", "仅一次"],
    "repeat.everyDay": ["Every day", "كل يوم", "Täglich", "Todos los días", "Tous les jours", "हर दिन", "Ogni giorno", "毎日", "매일", "Todos os dias", "Каждый день", "每天"],
    "repeat.weekdays": ["Weekdays", "أيام الأسبوع", "Wochentags", "De lunes a viernes", "En semaine", "सप्ताह के दिन", "Nei giorni feriali", "平日", "주중", "Dias de semana", "По будням", "工作日"],
    "repeat.weekends": ["Weekends", "نهاية الأسبوع", "Am Wochenende", "Fines de semana", "Le week-end", "सप्ताहांत", "Nel weekend", "週末", "주말", "Fins de semana", "По выходным", "周末"],
}

DIFFICULTY = family("difficulty.", "", {
    "easy": ["Easy", "سهل", "Leicht", "Fácil", "Facile", "आसान", "Facile", "かんたん", "쉬움", "Fácil", "Легко", "简单"],
    "medium": ["Medium", "متوسط", "Mittel", "Medio", "Moyen", "मध्यम", "Medio", "ふつう", "보통", "Médio", "Средне", "中等"],
    "hard": ["Hard", "صعب", "Schwer", "Difícil", "Difficile", "कठिन", "Difficile", "むずかしい", "어려움", "Difícil", "Сложно", "困难"],
    "brutal": ["Brutal", "قاسٍ", "Brutal", "Brutal", "Brutal", "क्रूर", "Brutale", "鬼", "극악", "Brutal", "Жёстко", "残酷"],
})

SOUNDS = family("sound.", "", {
    "sunrise": ["Sunrise", "شروق", "Sonnenaufgang", "Amanecer", "Lever du soleil", "सूर्योदय", "Alba", "日の出", "일출", "Amanhecer", "Рассвет", "日出"],
    "birdsong": ["Birdsong", "تغريد", "Vogelgesang", "Canto de aves", "Chant d’oiseaux", "पक्षी कलरव", "Canto d’uccelli", "鳥のさえずり", "새소리", "Canto de pássaros", "Пение птиц", "鸟鸣"],
    "marimba": ["Marimba", "ماريمبا", "Marimba", "Marimba", "Marimba", "मारिम्बा", "Marimba", "マリンバ", "마림바", "Marimba", "Маримба", "马林巴"],
    "cascade": ["Cascade", "شلال", "Kaskade", "Cascada", "Cascade", "झरना", "Cascata", "カスケード", "폭포", "Cascata", "Каскад", "流水"],
    "bellhop": ["Bellhop", "جرس", "Glocke", "Campanilla", "Sonnette", "घंटी", "Campanello", "ベル", "벨", "Campainha", "Звонок", "铃声"],
    "radar": ["Radar", "رادار", "Radar", "Radar", "Radar", "रडार", "Radar", "レーダー", "레이더", "Radar", "Радар", "雷达"],
    "klaxon": ["Klaxon", "بوق", "Hupe", "Claxon", "Klaxon", "हॉर्न", "Clacson", "クラクション", "경적", "Buzina", "Клаксон", "汽笛"],
    "siren": ["Siren", "صفارة", "Sirene", "Sirena", "Sirène", "सायरन", "Sirena", "サイレン", "사이렌", "Sirene", "Сирена", "警报"],
})

APPEARANCE = family("appearance.", "", {
    "dark": ["Dark", "داكن", "Dunkel", "Oscuro", "Sombre", "गहरा", "Scuro", "ダーク", "다크", "Escuro", "Тёмное", "深色"],
    "light": ["Light", "فاتح", "Hell", "Claro", "Clair", "हल्का", "Chiaro", "ライト", "라이트", "Claro", "Светлое", "浅色"],
    "system": ["Match system", "مثل النظام", "Wie System", "Según el sistema", "Comme le système", "सिस्टम जैसा", "Come il sistema", "システムに合わせる", "시스템 설정", "Igual ao sistema", "Как в системе", "跟随系统"],
})

OUTCOMES = family("outcome.", "", {
    "completed": ["Got up", "استيقظت", "Aufgestanden", "Te levantaste", "Levé", "उठ गए", "Alzato", "起きた", "일어남", "Levantou", "Встал", "起床成功"],
    "completedAfterSnoozes": ["Got up late", "استيقظت متأخراً", "Spät aufgestanden", "Te levantaste tarde", "Levé en retard", "देर से उठे", "Alzato in ritardo", "遅れて起きた", "늦게 일어남", "Levantou tarde", "Встал позже", "起床偏晚"],
    "bailedOut": ["Bailed out", "انسحبت", "Abgebrochen", "Abandonaste", "Abandonné", "छोड़ दिया", "Abbandonato", "途中でやめた", "포기함", "Desistiu", "Сдался", "中途放弃"],
    "interrupted": ["Interrupted", "انقطع", "Unterbrochen", "Interrumpida", "Interrompu", "बाधित", "Interrotto", "中断", "중단됨", "Interrompido", "Прервано", "被打断"],
})

# MARK: - Ringing alarm and Live Activity

ALARM = {
    "alarm.defaultTitle": ["Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak", "Dawnbreak"],
    "alarm.stop": ["Stop", "إيقاف", "Stopp", "Parar", "Arrêter", "रोकें", "Ferma", "停止", "정지", "Parar", "Стоп", "停止"],
    "alarm.followUpTitle": ["Mission not done", "لم تكتمل المهمة", "Mission offen", "Misión sin terminar", "Mission non terminée", "मिशन अधूरा", "Missione non completata", "ミッション未完了", "미션 미완료", "Missão não concluída", "Задание не выполнено", "任务未完成"],
    "alarm.relentless.short": ["Relentless", "عنيد", "Unerbittlich", "Implacable", "Implacable", "अडिग", "Implacabile", "執念", "끈질김", "Implacável", "Неумолимый", "不放弃"],
    "alarm.needsSetup": ["Finish setup", "أكمل الإعداد", "Setup beenden", "Termina la config.", "Terminer la config.", "सेटअप पूरा करें", "Completa il setup", "設定を完了", "설정 완료 필요", "Concluir config.", "Завершите настройку", "完成设置"],
    # On the row, when the app has an alarm the system has not accepted. Says what is wrong,
    # not why, because the reason is already in the dialog the failure raised.
    "alarm.notArmed": ["Will not ring", "لن يرن", "Klingelt nicht", "No sonará", "Ne sonnera pas", "नहीं बजेगा", "Non suonerà", "鳴りません", "울리지 않음", "Não vai tocar", "Не прозвонит", "不会响铃"],
    "alarm.delete.title": ["Delete this alarm?", "حذف هذا المنبه؟", "Diesen Alarm löschen?", "¿Eliminar esta alarma?", "Supprimer cette alarme ?", "यह अलार्म हटाएँ?", "Eliminare questa sveglia?", "このアラームを削除しますか？", "이 알람을 삭제할까요?", "Excluir este alarme?", "Удалить этот будильник?", "删除该闹钟？"],
    "alarm.delete.body": ["Its mission setup goes with it. This cannot be undone.", "سيُحذف معه إعداد مهمته. لا يمكن التراجع.", "Die Missionskonfiguration verschwindet mit. Das lässt sich nicht widerrufen.", "Su configuración de misión se irá con ella. No se puede deshacer.", "Sa configuration de mission part avec. C’est irréversible.", "इसका मिशन सेटअप भी चला जाएगा। इसे पलटा नहीं जा सकता।", "Anche la configurazione della missione andrà perduta. L’azione è irreversibile.", "ミッションの設定も一緒に消えます。取り消せません。", "미션 설정도 함께 사라집니다. 되돌릴 수 없습니다.", "A configuração da missão vai com ele. Não é possível desfazer.", "Настройка задания удалится вместе с ним. Отменить нельзя.", "任务设置会一并删除，且无法撤销。"],
}

WIDGET = {
    "widget.next.name": ["Next alarm", "المنبه القادم", "Nächster Alarm", "Próxima alarma", "Prochaine alarme", "अगला अलार्म", "Prossima sveglia", "次のアラーム", "다음 알람", "Próximo alarme", "Следующий будильник", "下一个闹钟"],
    "widget.next.description": ["The time you are getting up and what it will take to stop the alarm.", "الوقت الذي ستستيقظ فيه وما يتطلبه إيقاف المنبه.", "Wann du aufstehst und was nötig ist, um den Alarm zu stoppen.", "A qué hora te levantas y qué hará falta para parar la alarma.", "L’heure de votre réveil et ce qu’il faudra faire pour arrêter l’alarme.", "आप कब उठेंगे और अलार्म रोकने के लिए क्या करना होगा।", "A che ora ti alzi e cosa serve per fermare la sveglia.", "起きる時刻と、アラームを止めるために必要なこと。", "일어날 시각과 알람을 멈추기 위해 해야 할 일.", "A que horas você vai levantar e o que será preciso para parar o alarme.", "Во сколько вы встаёте и что потребуется, чтобы выключить будильник.", "你的起床时间，以及关掉闹钟需要做什么。"],
    "widget.next.title": ["NEXT ALARM", "المنبه القادم", "NÄCHSTER ALARM", "PRÓXIMA ALARMA", "PROCHAINE ALARME", "अगला अलार्म", "PROSSIMA SVEGLIA", "次のアラーム", "다음 알람", "PRÓXIMO ALARME", "СЛЕДУЮЩИЙ", "下一个闹钟"],
    "widget.next.none": ["No alarm armed", "لا منبه مضبوط", "Kein Alarm aktiv", "Sin alarmas activas", "Aucune alarme armée", "कोई अलार्म चालू नहीं", "Nessuna sveglia attiva", "アラームなし", "설정된 알람 없음", "Nenhum alarme ativo", "Нет будильников", "没有已启用的闹钟"],
    "widget.next.inline": ["Alarm %@", "منبه %@", "Alarm %@", "Alarma %@", "Alarme %@", "अलार्म %@", "Sveglia %@", "アラーム %@", "알람 %@", "Alarme %@", "Будильник %@", "闹钟 %@"],
    "widget.rounds": ["%lld×", "%lld×", "%lld×", "%lld×", "%lld×", "%lld×", "%lld×", "%lld×", "%lld×", "%lld×", "%lld×", "%lld×"],
    "widget.subhead.default": ["Stop it, then finish the mission", "أوقفه ثم أكمل المهمة", "Stoppen, dann Mission erledigen", "Párala y termina la misión", "Arrêtez, puis terminez la mission", "रोकें, फिर मिशन पूरा करें", "Fermala, poi completa la missione", "止めてからミッションを完了", "정지 후 미션을 완료하세요", "Pare e conclua a missão", "Выключите и выполните задание", "先停止，再完成任务"],
    "widget.subhead.relentless": ["Relentless: it comes back in a minute", "عنيد: سيعود بعد دقيقة", "Unerbittlich: kommt in einer Minute zurück", "Implacable: vuelve en un minuto", "Implacable : elle revient dans une minute", "अडिग: यह एक मिनट में फिर बजेगा", "Implacabile: torna tra un minuto", "執念モード：1 分後にまた鳴ります", "끈질김: 1분 뒤 다시 울립니다", "Implacável: volta em um minuto", "Неумолимый: вернётся через минуту", "不放弃模式：一分钟后再响"],
}
