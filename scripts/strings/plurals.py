"""The two keys whose text depends on a number, in every locale's own plural rules.

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
