"""The four keys whose text depends on a number, in every locale's own plural rules.

Emitted with the String Catalog's *substitution* shape rather than a bare
`variations.plural`, because a substitution declares `formatSpecifier` explicitly. That is what
lets a variant leave the numeral out entirely: Arabic's dual is the word `يومان`, not "2 يوم",
and `stats.streak.unit` prints only the noun because the number is already drawn large inside
the progress ring.

`rows` holds one dict per locale, in the same order as `LOCALES`, and its keys must be exactly
that locale's CLDR plural categories — `make_strings.py` refuses anything else, because a
missing `few` in Russian is a bug you only ever see on a Russian device.
"""

PLURALS = {
    # Under the plan title on the paywall, in green.
    "paywall.trial": {
        "name": "days",
        "arg": 1,
        "spec": "lld",
        "rows": [
            {"one": "%lld day free", "other": "%lld days free"},
            {
                "zero": "%lld يوم مجاناً",
                "one": "يوم واحد مجاناً",
                "two": "يومان مجاناً",
                "few": "%lld أيام مجاناً",
                "many": "%lld يوماً مجاناً",
                "other": "%lld يوم مجاناً",
            },
            {"one": "%lld Tag gratis", "other": "%lld Tage gratis"},
            {"one": "%lld día gratis", "many": "%lld días gratis", "other": "%lld días gratis"},
            {"one": "%lld jour offert", "many": "%lld jours offerts", "other": "%lld jours offerts"},
            {"one": "%lld दिन मुफ़्त", "other": "%lld दिन मुफ़्त"},
            {"one": "%lld giorno gratis", "many": "%lld giorni gratis", "other": "%lld giorni gratis"},
            {"other": "%lld 日間無料"},
            {"other": "%lld일 무료"},
            {"one": "%lld dia grátis", "many": "%lld dias grátis", "other": "%lld dias grátis"},
            {
                "one": "%lld день бесплатно",
                "few": "%lld дня бесплатно",
                "many": "%lld дней бесплатно",
                "other": "%lld дня бесплатно",
            },
            {"other": "免费 %lld 天"},
        ],
    },
    # The purchase button when the selected plan has an introductory offer. English is the same
    # in both categories on purpose: "Start 7-day free trial" does not inflect.
    "paywall.cta.trial": {
        "name": "days",
        "arg": 1,
        "spec": "lld",
        "rows": [
            {"one": "Start %lld-day free trial", "other": "Start %lld-day free trial"},
            {
                "zero": "ابدأ تجربة %lld يوم مجاناً",
                "one": "ابدأ تجربة يوم واحد مجاناً",
                "two": "ابدأ تجربة يومين مجاناً",
                "few": "ابدأ تجربة %lld أيام مجاناً",
                "many": "ابدأ تجربة %lld يوماً مجاناً",
                "other": "ابدأ تجربة %lld يوم مجاناً",
            },
            {"one": "%lld Tag gratis testen", "other": "%lld Tage gratis testen"},
            {"one": "Probar %lld día gratis", "many": "Probar %lld días gratis", "other": "Probar %lld días gratis"},
            {
                "one": "Essayer %lld jour gratuitement",
                "many": "Essayer %lld jours gratuitement",
                "other": "Essayer %lld jours gratuitement",
            },
            {"one": "%lld दिन मुफ़्त आज़माएँ", "other": "%lld दिन मुफ़्त आज़माएँ"},
            {"one": "Prova %lld giorno gratis", "many": "Prova %lld giorni gratis", "other": "Prova %lld giorni gratis"},
            {"other": "%lld 日間無料で試す"},
            {"other": "%lld일 무료로 시작"},
            {
                "one": "Testar %lld dia grátis",
                "many": "Testar %lld dias grátis",
                "other": "Testar %lld dias grátis",
            },
            {
                "one": "Попробовать %lld день бесплатно",
                "few": "Попробовать %lld дня бесплатно",
                "many": "Попробовать %lld дней бесплатно",
                "other": "Попробовать %lld дня бесплатно",
            },
            {"other": "免费试用 %lld 天"},
        ],
    },
    # Shown next to the snooze button while the alarm is ringing.
    "mission.snoozesLeft": {
        "name": "snoozes",
        "arg": 1,
        "spec": "lld",
        "rows": [
            {"one": "%lld snooze left", "other": "%lld snoozes left"},
            {
                "zero": "لم يتبقَّ تأجيل",
                "one": "تأجيل واحد متبقٍ",
                "two": "تأجيلان متبقيان",
                "few": "%lld تأجيلات متبقية",
                "many": "%lld تأجيلاً متبقياً",
                "other": "%lld تأجيل متبقٍ",
            },
            {"one": "Noch %lld Mal schlummern", "other": "Noch %lld Mal schlummern"},
            {"one": "Queda %lld posposición", "many": "Quedan %lld posposiciones", "other": "Quedan %lld posposiciones"},
            {"one": "%lld rappel restant", "many": "%lld rappels restants", "other": "%lld rappels restants"},
            {"one": "%lld स्नूज़ बाकी", "other": "%lld स्नूज़ बाकी"},
            {"one": "%lld posticipo rimasto", "many": "%lld posticipi rimasti", "other": "%lld posticipi rimasti"},
            {"other": "残りスヌーズ %lld 回"},
            {"other": "다시 알림 %lld회 남음"},
            {"one": "Resta %lld soneca", "many": "Restam %lld sonecas", "other": "Restam %lld sonecas"},
            {
                "one": "Осталось %lld откладывание",
                "few": "Осталось %lld откладывания",
                "many": "Осталось %lld откладываний",
                "other": "Осталось %lld откладывания",
            },
            {"other": "还能小睡 %lld 次"},
        ],
    },
    # The word under the streak ring. No numeral: the count is the 26-point number above it.
    "stats.streak.unit": {
        "name": "days",
        "arg": 1,
        "spec": "lld",
        "rows": [
            {"one": "day", "other": "days"},
            {"zero": "يوم", "one": "يوم", "two": "يومان", "few": "أيام", "many": "يوماً", "other": "يوم"},
            {"one": "Tag", "other": "Tage"},
            {"one": "día", "many": "días", "other": "días"},
            {"one": "jour", "many": "jours", "other": "jours"},
            {"one": "दिन", "other": "दिन"},
            {"one": "giorno", "many": "giorni", "other": "giorni"},
            {"other": "日"},
            {"other": "일"},
            {"one": "dia", "many": "dias", "other": "dias"},
            {"one": "день", "few": "дня", "many": "дней", "other": "дня"},
            {"other": "天"},
        ],
    },
}
