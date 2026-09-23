// title.typ — Титульный лист

#let parse-date(date-raw) = {

  let get-month-name(month-number) = {
    let months = (
      "января", "февраля", "марта", "апреля",
      "мая", "июня", "июля", "августа",
      "сентября", "октября", "ноября", "декабря"
    )

    // Возвращаем строку по индексу (минус 1, так как массивы начинаются с 0)
    months.at(month-number - 1)
  }

  let parts = date-raw.split("-")

  text()[
    «#int(parts.at(0))»
    #get-month-name(int(parts.at(1)))
    #parts.at(2) г.
  ]
}

#let title-page(
  institute: "Институт",
  department: "Кафедра",
  discipline: "Дисциплина",
  assignment: "Практическая работа",
  group: "АААА-01-01",
  date: "01-01-1970",
  professor: "Иванов Иван Иванович",
  professor-position: "Преподаватель",
  student: "Иванов Иван Иванович",
) = {
  // Убираем нумерацию и колонтитулы на титульном листе
  set page(
    numbering: none,
    header: none,
    footer: none,
    margin: (top: 2cm, left: 3cm, right: 1.5cm, bottom: 2cm)
  )
  set text(
    font: "Times New Roman",
    size: 14pt,
    lang: "ru",
    region: "ru",
  )

  // === ГЕРБ ===
  align(center)[#image("assets/gerb.png", width: 3cm)]

  // === МИНОБРНАУКИ ===
  align(center)[
    #text(size: 12pt)[МИНОБРНАУКИ РОССИИ]
  ]

  // === Полное название ===
  align(center)[
    #text(size: 12pt)[Федеральное государственное бюджетное образовательное учреждение \
    высшего образования]
  ]

  // === Краткое название ===
  align(center)[
    #text(size: 12pt, weight: "bold")[«МИРЭА – Российский технологический университет»]
  ]

  // === РТУ МИРЭА ===
  align(center)[
    #text(size: 16pt, weight: "bold")[РТУ МИРЭА]
  ]

  // === Двойная горизонтальная линия ===
  block(
    width: 100%,
    stroke: (top: 0.5pt, bottom: 0.5pt),
    inset: 2pt,
  )

  // === Институт и кафедра ===
  align(center)[
    #text(weight: "bold")[
      #institute \ #department
    ]
  ]
  v(1.5cm)

  // === ОТЧЕТ ПО ПРАКТИЧЕСКОЙ РАБОТЕ ===
  align(center)[
    #text(size: 16pt, weight: "bold")[
      ОТЧЁТ ПО ПРАКТИЧЕСКОЙ РАБОТЕ
    ]
  ]

  // === Дисциплина ===
  align(center)[
    по дисциплине «#discipline»
  ]
  v(0.8cm)

  // === Название работы ===
  align(center)[
    #text(size: 16pt, weight: "bold")[
      #assignment
    ]
  ]
  v(2cm)

  // === Таблица с подписями ===
  grid(
    columns: (4.5cm, 8.5cm, 0cm, 3.5cm),
    row-gutter: 0.5cm,
    align: (left, left, center, center),

    // Студент
    [Студент группы],
    [#text(style: "italic")[#group #student]],
    [],
    [`__________` \ #text(size: 9pt)[(подпись)]],

    // Преподаватель
    [#professor-position],
    [#text(style: "italic")[#professor]],
    [],
    [`__________` \ #text(size: 9pt)[(подпись)]],
  )
  v(1em)

  // === Дата ===
  grid(
    columns: (4.5cm, 9cm),

    [Отчёт представлен],

    [#parse-date(date)],
  )

  // === Город и год ===
  v(1fr)
  align(center)[
    Москва 2026 г.
  ]

  // Разрыв страницы после титульника
  pagebreak()
}
