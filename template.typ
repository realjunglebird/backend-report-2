// template.typ

// Функция-шаблон для всего документа
#let project(doc) = {
  // 1. СТРАНИЦА
  set page(
    paper: "a4",
    margin: (
      top: 2cm,
      bottom: 2cm,
      left: 3cm,
      right: 1.5cm,
    ),
    numbering: "1",
    header: none,
    footer: align(center)[#context[#counter(page).display("1")]],
  )

  // 2. ТЕКСТ
  set text(
    font: "Times New Roman",
    size: 14pt,
    lang: "ru",
    region: "ru",
  )

  // 3. АБЗАЦЫ
  set par(
    first-line-indent: (amount: 1.25cm, all: true),
    leading: 0.65em,
    justify: true,
  )

  // 4. ЗАГОЛОВКИ
  set heading(
    numbering: "1.",
    outlined: true,
  )

  show outline: set heading(numbering: none, outlined: false)

  // В Typst для отображения номера и текста заголовка используется it
  show heading.where(level: 1): it => block(width: 100%)[
    #align(left)[
      #text(weight: "bold", size: 16pt)[
        #if it.numbering != none [
          #counter(heading).display()
        ]
        #it.body
      ]
    ]
    #v(1em)
  ]

  show heading.where(level: 2): it => block(width: 100%)[
    #text(weight: "bold", size: 14pt)[#counter(heading).display() #it.body]
    #v(0.5em)
  ]

  show heading.where(level: 3): it => block(width: 100%)[
    #text(weight: "bold", size: 14pt)[#counter(heading).display() #it.body]
    #v(0.3em)
  ]

  show heading.where(level: 4): it => block(width: 100%)[
    #text(weight: "bold", size: 14pt)[#counter(heading).display() #it.body]
    #v(0.3em)
  ]

  // 5. РИСУНКИ И ТАБЛИЦЫ
  show figure.where(kind: image): it => block(width: 100%)[
    #align(center)[
      #it.body
      #text(weight: "bold", size: 12pt)[Рисунок #it.counter.display() — #it.caption.body]
    ]
  ]

  show figure.where(kind: table): it => block(width: 100%)[
    #set par(first-line-indent: 0pt)

    #align(left)[
      #text(size: 12pt)[Таблица #it.counter.display() — #it.caption.body]
    ]
    #set text(size: 12pt)
    #it.body
  ]

  // 6. ЛИСТИНГИ С КОДОМ
  show figure.where(kind: raw): it => block(width: 100%, breakable: true)[
    #set par(first-line-indent: 0pt)
    #set align(left)
    #text(size: 12pt)[Листинг #it.counter.display()#if it.has("caption") [ — #it.caption.body ]]
    #it.body
  ]

  // 7. СПИСКИ
  set list(
    indent:1.25cm,
    spacing: 1em,
    marker: [--],
  )

  set enum(
    indent: 1.25cm,
    spacing: 1em,
    numbering: "1.",
  )

  // Переопределяем отступы для вложенных списков (2-й уровень и глубже)
  show list: it => {
    set list(indent: 0.5cm) // Уменьшенный отступ для маркированных вложенных
    set enum(indent: 0.5cm) // Уменьшенный отступ для нумерованных вложенных
    it
  }

  show enum: it => {
    set list(indent: 0.5cm)
    set enum(indent: 0.5cm)
    it
  }

  // 8. БИБЛИОГРАФИЯ
  set bibliography(
    title: "Список использованных источников",
  )

  // Возвращаем сам документ со всеми применёнными стилями
  doc
}

// Хелперы остаются снаружи функции
#let code-block(body, lang: "python", caption: "") = {
  show figure: set block(breakable: true)

  figure(
    block(
      fill: rgb("#f7f7f7"),
      stroke: 1pt + luma(150),
      inset: 8pt,
      width: 100%,
      breakable: true,
      [
        #set align(left)
        #set text(font: ("Courier New", "Consolas"), size: 10pt)
        #body
      ]
    ),
    caption: caption,
    kind: raw,
    supplement: [Листинг]
  )
}

#let new-page() = pagebreak()
