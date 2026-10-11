# Button

Tlačidlo spúšťa akciu; na obrazovke je najviac jedno primárne.

- **Primárne** (`brand`, text `on-brand`): hlavná akcia obrazovky – „Odoslať ponuku“, „Uložiť“, „Cockpit PDF“.
- **Sekundárne** (biele s okrajom `border`): ostatné akcie v hlavičke – „Day View →“, „Excel“, „Sync teraz“.
- **Tiché** (bez pozadia, text `brand-text`): odkazy na iné časti – „Detailný pohľad na dáta →“.
- Rozmery: výška 38 px, vodorovne `space-4`, rohy `radius-md`, text 14/20 váhy 500. Ikona 16 px vľavo od textu.
- Text je sloveso v rozkazovacom spôsobe. Nie „OK“, ale „Uložiť zmeny“.
- Nefunkčná akcia je `disabled` s vysvetlením v popise, nie skrytá.
