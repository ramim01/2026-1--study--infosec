// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [Лабораторная работа №1],
  subtitle: [Установка и конфигурация операционной системы на виртуальную машину],
  authors: (
    ( name: [Альманасра Рами],
      affiliation: [Российский университет дружбы народов],
      email: [1032235862\@rudn.ru] ),
    ),
  lang: "ru",
  sectionnumbering: "1.1.a",
  toc: true,
  toc_title: [Содержание],
  toc_depth: 2,
  doc,
)

= Цель работы
<цель-работы>
Целью данной работы является приобретение практических навыков установки операционной системы на виртуальную машину, настройки минимально необходимых для дальнейшей работы сервисов.

= Задание
<задание>
- Установить Linux (Rocky) на виртуальную машину VirtualBox.
- Выполнить базовую конфигурацию системы и сетевых параметров.
- Подготовить систему для выполнения последующих лабораторных работ.

= Теоретическое введение
<теоретическое-введение>
Виртуализация позволяет запускать гостевые операционные системы в изолированной среде на одном физическом компьютере. Для учебных задач удобно использовать VirtualBox, который поддерживает создание виртуальных дисков, настройку ресурсов и подключение ISO-образов для установки ОС. После установки важно выполнить базовую настройку системы: задать имя хоста, создать пользователя, настроить сеть и убедиться в корректной работе окружения

= Выполнение лабораторной работы
<выполнение-лабораторной-работы>
== Создание виртуальной машины
<создание-виртуальной-машины>
Открываем VirtualBox и создаём новую виртуальную машину Указываем имя виртуальной машины, определяем тип операционной системы и указываем путь к iso-образу (#ref(<fig-001>, supplement: [рис.]))

#figure([
#box(image("image/1.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Создание виртуальной машины
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-001>


Далее указываем размер оперативной памяти виртуальной машины - 2048 МБ, число процессоров - 2 и задаём размер виртуального жёсткого диска - 40 ГБ (#ref(<fig-002>, supplement: [рис.]))

#figure([
#box(image("image/2.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Создание виртуалтной машины (2)
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-002>


== Установка операционной системы
<установка-операционной-системы>
После запуска устанавливаем английский язык интерфейса (#ref(<fig-004>, supplement: [рис.]))

#figure([
#box(image("image/4.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Язык интерфейса - английский
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-004>


Добавляем русскую раскладку клавиатуры (#ref(<fig-005>, supplement: [рис.]))

#figure([
#box(image("image/5.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Настройка раскладки клавиатуры
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-005>


В разделе выбора программ указываем в качестве базового окружения Server with GUI, а в качестве дополнения --- Development Tools (#ref(<fig-007>, supplement: [рис.]))

#figure([
#box(image("image/7.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Раздел выбора программ
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-007>


Далее отключаем KDUMP, а место установки ОС оставляем без изменения (#ref(<fig-008>, supplement: [рис.])), (#ref(<fig-009>, supplement: [рис.]))

#figure([
#box(image("image/8.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Место установки ОС
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-008>


#figure([
#box(image("image/9.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Отключение KDUMP
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-009>


Устанавливаем пароль для root, разрешение на ввод пароля для root при использовании SSH (#ref(<fig-011>, supplement: [рис.]))

#figure([
#box(image("image/11.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Пароль для root
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-011>


Затем задаём локального пользователя с правами администратора и пароль для него (#ref(<fig-012>, supplement: [рис.]))

#figure([
#box(image("image/12.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Создание пользователя
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-012>


#figure([
#box(image("image/14.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Установка ОС
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-014>


== После установки
<после-установки>
Далее через терминал подключаем образ диска дополнений гостевой ОС: (#ref(<fig-015>, supplement: [рис.]))

#figure([
#box(image("image/15.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Подключение образ диска дополнений гостевой ОС
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-015>


= Домашнее задание
<домашнее-задание>
+ Версия ядра Linux (Linux version) (#ref(<fig-018>, supplement: [рис.]))
+ Частота процессора (Detected Mhz processor) (#ref(<fig-019>, supplement: [рис.]))
+ Модель процессора (CPU0) (#ref(<fig-020>, supplement: [рис.]))
+ Объем доступной оперативной памяти (Memory available) (#ref(<fig-021>, supplement: [рис.]))
+ Тип обнаруженного гипервизора (Hypervisor detected) (#ref(<fig-022>, supplement: [рис.]))
+ Тип файловой системы корневого раздела (#ref(<fig-023>, supplement: [рис.]))

#figure([
#box(image("image/18.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Версия ядра Linux
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-018>


#figure([
#box(image("image/19.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Частота процессора
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-019>


#figure([
#box(image("image/20.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Модель процессора
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-020>


#figure([
#box(image("image/21.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Объем доступной оперативной памяти
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-021>


#figure([
#box(image("image/22.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Тип обнаруженного гипервизора
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-022>


#figure([
#box(image("image/23.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Тип файловой системы корневого раздела
]), 
kind: "quarto-float-fig", 
supplement: "Рисунок", 
)
<fig-023>


= Контрольные вопросы + ответы
<контрольные-вопросы-ответы>
+ Какую информацию содержит учётная запись пользователя?

Учётная запись, как правило, содержит сведения, необходимые для опознания пользователя при подключении к системе, сведения для авторизации и учёта. Это идентификатор пользователя (login) и его пароль.

#block[
#set enum(numbering: "1.", start: 2)
+ Укажите команды терминала и приведите примеры:
]

- для получения справки по команде используют #emph[help]

- для перемещения по файловой системе используют #emph[cd]

- для просмотра содержимого каталога используют #emph[ls]

- для определения объёма каталога используют #emph[du]

- для создания/удаления каталогов используют #emph[mkdir/rmdir], а для файлов #emph[touch/rm]

- для задания определённых прав на файл/каталог используют #emph[chmod]

- для просмотра истории команд используют #emph[history]

#block[
#set enum(numbering: "1.", start: 3)
+ Что такое файловая система? Приведите примеры с краткой характеристикой.
]

Файловая система (англ. file system) --- порядок, определяющий способ организации, хранения и именования данных во внешней памяти, и обеспечивающий пользователю удобный интерфейс при работе с такими данными. Простыми словами файловая система - это система хранения файлов и организации каталогов. От файловой системы зависит, как файлы будут кодироваться, храниться на диске и читаться компьютером.

Примеры:

- FAT (англ. File Allocation Table «таблица размещения файлов») --- классическая архитектура файловой системы, которая из-за своей простоты всё ещё широко применяется для флеш-накопителей. Используется в дискетах, картах памяти и некоторых других носителях информации. Ранее находила применение и на жёстких дисках.

- NTFS (англ. new technology file system --- «файловая система новой технологии») --- стандартная файловая система для семейства операционных систем Windows NT фирмы Microsoft.

- Ext4 (англ. fourth extended file system, ext4fs) --- журналируемая файловая система, используемая преимущественно в операционных системах с ядром Linux, созданная на базе ext3 в 2006 году.

#block[
#set enum(numbering: "1.", start: 4)
+ Как посмотреть, какие файловые системы подмонтированы в ОС?
]

Следует ввести команду df.

#block[
#set enum(numbering: "1.", start: 5)
+ Как удалить зависший процесс?
]

Чтобы удалить зависшй процесс, надо сначала узнать его PID с помощью команды #emph[ps]. А после этого ввести #emph[kill ]. И всё готово!

= Выводы
<выводы>
В ходе выполнения лабораторной работы мы приобрели практические навыки установки операционной системы на виртуальную машину, настройки минимально необходимых для дальнейшей работы сервисов.

#heading(level: 1, numbering: none)[Список литературы]
<список-литературы>
Лаборатораня работа №1 \[Электронный ресурс\] URL:https:{/\/esystem.rudn.ru/pluginfile.php/3096704/mod\_folder/content/0/001-lab\_virtualbox.pdf}

#set bibliography(style: "/\_resources/csl/gost-r-7-0-5-2008-numeric.csl")

#bibliography(("bib/cite.bib"))

