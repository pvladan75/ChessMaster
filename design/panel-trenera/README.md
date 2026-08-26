# Panel trenera — kanvas sa varijantama

Radni fajlovi za kanvas koji poredi tri varijante panela trenera. Objavljen je
kao Artifact: https://claude.ai/code/artifact/dca9d784-3e96-4c50-84ed-9b69e117a07c

| Fajl | Šta je |
|---|---|
| `Main.dc.html` | tabla sa odlukom — šta koja varijanta rešava i po koju cenu |
| `VarijantaA.dc.html` | **Danas** — šta mi je sad posao |
| `VarijantaB.dc.html` | **Po učeniku** — kako stoji svako |
| `VarijantaC.dc.html` | **Čeka tebe** — gde sam ja usko grlo |
| `canvas.json` | raspored tabli na kanvasu |

Boje i razmaci su preuzeti iz `chess_app/lib/theme/app_colors.dart`, tamna tema.
Polja su stvarna (Rejting, Tačnost, Rešeno, Aktivnih dana, period 7/30/90);
**imena učenika i brojevi su izmišljeni**, jer je repozitorijum javan.

Makete su statične i služe izboru varijante. Ne hvataju prelivanje na uskom
telefonu — to ostaje provera na uređaju, iz razloga opisanog u `CLAUDE.md`.

Sastavljeni `panel-trenera.html` je gitignorisan: 2,2 MB, i pravi se iz ovih
fajlova.
