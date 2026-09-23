#import "template.typ": *
#import "title.typ": *

#show: project

// Титульник
#title-page(
  institute: "Институт информационных технологий (ИИТ)",
  department: "Кафедра инструментального и прикладного программного обеспечения (ИиППО)",
  discipline: "Проектирование и разработка серверных частей интернет-ресурсов",
  assignment: "Практическая работа №2",
  student: "Сазонов Егор Сергеевич",
  group: "ИКБО-23-24",
  professor: "Благирев Михаил Михайлович",
  professor-position: "Ассистент",
  date: "23-09-2026"
)

// Оглавление
#outline(title: "Оглавление")
#pagebreak()

#include "content/objective.typ"
#include "content/work.typ"
#include "content/conclusion.typ"
#include "content/questions.typ"
