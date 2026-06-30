#!/usr/bin/env python3
import argparse
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "App_Data" / "site-content.json"


def h(value):
    return html.escape(str(value or ""), quote=True)


def para_class(text, suppress_small=False):
    text = str(text or "")
    upper = text.upper()
    if "Уважаемые" in text or "Внимание" in text or (len(text) > 80 and text == upper):
        return "content-paragraph content-paragraph--warning"
    if len(text) > 8 and text == upper:
        return "content-paragraph content-paragraph--strong"
    if not suppress_small and len(text) < 70:
        return "content-paragraph content-paragraph--small"
    return "content-paragraph"


def p(text, suppress_small=False):
    return f"<p class=\"{para_class(text, suppress_small)}\">{h(text)}</p>"


def render_specialty_list(blocks):
    rows = []
    for block in blocks:
        match = re.match(r"^(\d+\.\d+\.\d+\.?)\s*(.*)$", str(block))
        if match:
            rows.append(f'<li class="specialty-row"><span>{h(match.group(1))}</span> <strong>{h(match.group(2))}</strong></li>')
        else:
            rows.append(f'<li class="specialty-row"><strong>{h(block)}</strong></li>')
    return f'<ul class="specialty-list">{"".join(rows)}</ul>'


def render_template_rows(blocks):
    rows = []
    for block in blocks:
        text = str(block)
        if ":" in text and len(text) < 180:
            label, value = text.split(":", 1)
            rows.append(f'<div class="template-row"><span>{h(label + ":")}</span><strong>{h(value.strip() or " ")}</strong></div>')
        else:
            rows.append(f'<div class="template-row template-row--wide"><strong>{h(text)}</strong></div>')
    return f'<div class="template-table">{"".join(rows)}</div>'


def render_template_layout(blocks):
    ru = blocks[:13]
    en = blocks[13:]
    return (
        '<div class="article-template">'
        f'<p class="article-template__intro">{h(ru[0])}</p>'
        '<article class="article-template__card">'
        '<div class="article-template__journal">'
        f'<strong>{h(ru[1])}</strong>'
        f'<span>{h(ru[2])}</span>'
        '</div>'
        '<div class="article-template__chips">'
        f'<span>{h(ru[3])}</span><span>{h(ru[4])}</span><span>{h(ru[5])}</span>'
        '</div>'
        f'<h3>{h(ru[6])}</h3>'
        '<div class="article-template__meta">'
        f'<p><span>Авторы</span>{h(ru[7])}</p>'
        f'<p><span>Организация</span>{h(ru[8])}</p>'
        f'<p><span>E-mail</span>{h(ru[9])}</p>'
        '</div>'
        '<div class="article-template__abstract">'
        f'<p><span>{h(ru[10])}</span></p>'
        f'<p><span>{h(ru[11])}</span></p>'
        f'<p><span>{h(ru[12].split(":", 1)[0] + ":")}</span>{h(ru[12].split(":", 1)[1].strip() if ":" in ru[12] else ru[12])}</p>'
        '</div>'
        '</article>'
        '<article class="article-template__card article-template__card--english">'
        '<div class="article-template__chips">'
        f'<span>{h(en[0])}</span><span>{h(en[1])}</span>'
        '</div>'
        f'<p class="article-template__label">{h(en[2])}</p>'
        f'<h3>{h(en[3])}</h3>'
        '<div class="article-template__meta">'
        f'<p><span>Authors</span>{h(en[4])}</p>'
        f'<p><span>Organization</span>{h(en[5])}</p>'
        f'<p><span>E-mail</span>{h(en[6])}</p>'
        '</div>'
        '<div class="article-template__abstract">'
        f'<p><span>{h(en[7])}</span></p>'
        f'<p><span>{h(en[8])}</span></p>'
        f'<p><span>{h(en[9].split(":", 1)[0] + ":")}</span>{h(en[9].split(":", 1)[1].strip() if ":" in en[9] else en[9])}</p>'
        '</div>'
        '</article>'
        '</div>'
    )


def render_rule_group(title, blocks, kind="plain"):
    if not blocks:
        return ""
    if kind == "specialties":
        content = render_specialty_list(blocks)
    elif kind == "template":
        content = render_template_rows(blocks)
    elif kind == "alerts":
        content = '<div class="alert-stack">' + "".join(p(block, suppress_small=True) for block in blocks) + "</div>"
    else:
        content = "".join(p(block, suppress_small=True) for block in blocks)
    return f'<div class="rule-group rule-group--{kind}"><h3>{h(title)}</h3>{content}</div>'


def render_journal_identity(blocks):
    return (
        '<div class="journal-identity">'
        f'<p class="journal-identity__name">{h(blocks[0])}</p>'
        f'<p class="journal-identity__rules">{h(blocks[1])}</p>'
        f'<p class="journal-identity__status">{h(blocks[2])}</p>'
        f'<p class="journal-identity__notice">{h(blocks[3])}</p>'
        "</div>"
    )


def render_fact_cards(items):
    cards = []
    for label, value in items:
        cards.append(f'<article class="fact-card"><span>{h(label)}</span><strong>{h(value)}</strong></article>')
    return f'<div class="fact-grid">{"".join(cards)}</div>'


def render_forbidden_panel(text):
    labels = ["Табуляция", "Разрыв страниц", "Обтекание рисунков и таблиц", "Таблицы как рисунки"]
    chips = "".join(f"<span>{h(label)}</span>" for label in labels)
    return (
        '<div class="forbidden-panel">'
        '<div><h3>В рукописи не допускаются</h3>'
        f'<div class="forbidden-panel__chips">{chips}</div></div>'
        f'<p>{h(text)}</p>'
        "</div>"
    )


def render_manuscript_specs(volume_text, format_text):
    return (
        '<div class="spec-panel">'
        f'<p class="spec-panel__lead">{h(volume_text)}</p>'
        '<dl class="spec-grid">'
        '<div><dt>Редактор</dt><dd>Word Windows</dd></div>'
        '<div><dt>Шрифт</dt><dd>Times New Roman, 14</dd></div>'
        '<div><dt>Интервал</dt><dd>1</dd></div>'
        '<div><dt>Формат</dt><dd>А4</dd></div>'
        '<div><dt>Поля</dt><dd>2 см со всех сторон</dd></div>'
        '<div><dt>Красная строка</dt><dd>1,27 см</dd></div>'
        '</dl>'
        f'<p>{h(format_text)}</p>'
        '</div>'
    )


def render_figure_table_examples(blocks):
    examples = "".join(f'<div class="example-frame__line">{h(block)}</div>' for block in blocks)
    return (
        '<div class="example-frame">'
        '<p class="example-frame__label">Пример подписей</p>'
        f'{examples}'
        '</div>'
    )


def render_reference_examples(blocks):
    return (
        '<div class="reference-examples">'
        f'<article><span>{h(blocks[0])}</span><h4>{h(blocks[1])}</h4><p>{h(blocks[2])}</p></article>'
        f'<article><span>{h(blocks[3])}</span><p>{h(blocks[4])}</p><em>{h(blocks[5])}</em></article>'
        '</div>'
    )


def render_submission_pack(text):
    items = ["Заявка на публикацию", "Текст статьи", "Иллюстрации и таблицы", "Сканированная рецензия доктора наук", "Самостоятельная проверка на антиплагиат"]
    checklist = "".join(f"<li>{h(item)}</li>" for item in items)
    return f'<div class="submission-pack"><ul>{checklist}</ul><p>{h(text)}</p></div>'


def render_review_layout(blocks):
    intro = "".join(p(block, suppress_small=True) for block in blocks[:3])
    formal_ru = "".join(p(block, suppress_small=True) for block in blocks[6:9])
    signature = (
        '<div class="signature-card">'
        f'<span>{h(blocks[9])}</span>'
        f'<strong>{h(blocks[10])}</strong>'
        '</div>'
    )
    formal_en = "".join(p(block, suppress_small=True) for block in blocks[13:17])
    signature_en = (
        '<div class="signature-card signature-card--english">'
        f'<span>{h(blocks[17])}</span>'
        f'<strong>{h(blocks[18])}</strong>'
        f'<p>{h(blocks[19])}</p><p>{h(blocks[20])}</p>'
        '</div>'
    )
    return (
        '<div class="review-layout">'
        f'<div class="rule-group"><h3>Решение по статье</h3>{intro}</div>'
        '<div class="review-card review-card--ru">'
        f'<h3>{h(blocks[3])}</h3>'
        '<div class="review-facts">'
        f'<article><span>Индекс</span><strong>{h(blocks[4])}</strong></article>'
        f'<article><span>История</span><strong>{h(blocks[5])}</strong></article>'
        '</div>'
        f'{formal_ru}{signature}</div>'
        '<div class="review-card review-card--en">'
        f'<p class="review-card__kicker">{h(blocks[11])}</p>'
        f'<h3>{h(blocks[12])}</h3>'
        f'{formal_en}{signature_en}</div>'
        '</div>'
    )


def render_fee_layout(blocks):
    return (
        '<div class="fee-layout">'
        '<div class="fee-grid">'
        f'<article><span>Стоимость страницы</span><strong>1300 руб.</strong><p>{h(blocks[1])}</p></article>'
        f'<article><span>DOI</span><strong>600 руб.</strong><p>{h(blocks[0])}</p><p>{h(blocks[2])}</p></article>'
        '</div>'
        f'<div class="rule-group rule-group--alerts"><h3>Льготы и порядок оплаты</h3><div class="alert-stack">{p(blocks[3], suppress_small=True)}{p(blocks[4], suppress_small=True)}</div></div>'
        '</div>'
    )


def render_contacts(text):
    return (
        '<div class="contact-cards">'
        '<article><span>Адрес редакции</span><strong>414018, Астрахань, ул. Архитектурная, д. 14</strong><p>Чуйкову Ю.С.</p></article>'
        '<article><span>Электронная почта</span><strong><a href="mailto:us.chuikov@mail.ru">us.chuikov@mail.ru</a></strong></article>'
        '<article><span>Телефон</span><strong><a href="tel:+79086111581">8-908-611-15-81</a></strong></article>'
        '</div>'
    )


def render_author_section(section):
    sid = section.get("id")
    blocks = section.get("blocks", [])
    if sid == "status":
        return (
            render_journal_identity(blocks[:4])
            + render_rule_group("Специальности ВАК", blocks[4:12], "specialties")
            + render_fact_cards([("Индекс", blocks[12]), ("История", blocks[13]), ("Профиль", "РИНЦ / eLibrary.ru")])
            + render_rule_group("Тематика и типы материалов", blocks[14:])
        )
    if sid == "originality":
        return render_rule_group("Обязательные проверки и ограничения", blocks, "alerts")
    if sid == "format":
        return (
            render_forbidden_panel(blocks[0])
            + render_manuscript_specs(blocks[1], blocks[2])
            + render_rule_group("Таблицы, рисунки, фотографии и карты", blocks[3:7])
            + render_figure_table_examples(blocks[7:11])
            + render_rule_group("Цветные материалы и формат таблиц", blocks[11:], "alerts")
        )
    if sid == "references":
        return (
            render_rule_group("Правило оформления списка", blocks[:2])
            + render_reference_examples(blocks[2:])
        )
    if sid == "template":
        return render_template_layout(blocks)
    if sid == "submission":
        return render_submission_pack(blocks[0])
    if sid == "review":
        return render_review_layout(blocks)
    if sid == "fees":
        return render_fee_layout(blocks)
    if sid == "contacts":
        return render_contacts(blocks[0])
    return "".join(p(block) for block in blocks)


def header(home, current, prefix):
    elib = home.get("elibraryUrl", "")
    return f"""<header class="topbar">
  <div class="topbar__inner">
    <a class="brand" href="{prefix}index.html">
      <img src="{prefix}img/logo.png" alt="" class="brand__logo">
      <span><strong>{h(home.get("title"))}</strong><small>научно-практический журнал</small></span>
    </a>
    <nav class="nav" aria-label="Основная навигация">
      <a href="{prefix}index.html"{" aria-current=\"page\"" if current == "home" else ""}>Главная</a>
      <a href="{prefix}authors.html"{" aria-current=\"page\"" if current == "authors" else ""}>Для авторов</a>
      <a href="{prefix}issues.html"{" aria-current=\"page\"" if current == "issues" else ""}>Издания</a>
      <a href="{prefix}index.html#contacts">Контакты</a>
      <a href="{h(elib)}" target="_blank" rel="noopener">eLibrary</a>
    </nav>
  </div>
</header>"""


def footer(home, prefix):
    elib = home.get("elibraryUrl", "")
    email = home.get("contactEmail", "")
    return f"""<footer class="site-footer">
  <div class="footer-card">
    <p class="footer-title">{h(home.get("title"))}</p>
    <nav class="footer-nav" aria-label="Навигация в подвале">
      <a href="{prefix}index.html">Главная</a><span></span><a href="{prefix}authors.html">Для авторов</a><span></span><a href="{prefix}issues.html">Издания</a><span></span><a href="{prefix}index.html#contacts">Контакты</a><span></span><a href="{h(elib)}" target="_blank" rel="noopener">eLibrary</a>
    </nav>
    <p class="footer-contact"><a href="mailto:{h(email)}">{h(email)}</a></p>
  </div>
</footer>"""


def page(title, desc, current, home, body, depth=0):
    prefix = "../" * depth
    return f"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{h(title)}</title>
  <meta name="description" content="{h(desc)}">
  <link rel="stylesheet" href="{prefix}css/site.css">
</head>
<body>
{header(home, current, prefix)}
<main>
{body}
</main>
{footer(home, prefix)}
</body>
</html>
"""


def write(rel, content):
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(path)


AUTHOR_RE = re.compile(r"\b[А-ЯЁ][а-яё]+(?:\s+[А-ЯЁ][а-яё]+){1,3}\b")
PATRONYMIC_RE = re.compile(r"(?:вич|вна|ич|ична|овна|евна|инична)\b", re.I)
ORG_PREFIXES = (
    "ФГБОУ",
    "ФГАОУ",
    "Федеральное",
    "Астраханский государственный",
    "Каспийский",
    "Институт",
    "Башкирский",
    "Калмыцкий",
)
SUBJECTS = {"Науки о Земле", "Биологические науки", "Педагогические науки"}
ARTICLE_TYPES = {"Научная статья", "Обзор"}


def looks_like_author_or_org(text):
    text = str(text or "").strip()
    if "@" in text or PATRONYMIC_RE.search(text):
        return True
    if len(text) < 90 and re.fullmatch(r"[А-ЯЁ][а-яё]+(?:\s+[А-ЯЁ][а-яё]+){1,3},?", text):
        return True
    if text.startswith(ORG_PREFIXES):
        return True
    if "," in text and AUTHOR_RE.search(text):
        return True
    return False


def title_from_blocks(blocks, fallback):
    start = None
    for i, block in enumerate(blocks):
        if str(block).strip().startswith("DOI"):
            start = i + 1
            break
    if start is None:
        return fallback
    chunks = []
    for block in blocks[start:]:
        text = str(block).strip()
        if not text or text in SUBJECTS or text in ARTICLE_TYPES or text.startswith("УДК"):
            continue
        if text.startswith(("Аннотация", "Abstract", "Ключевые слова", "Key words", "Для цитирования", "For citation")):
            break
        if chunks and looks_like_author_or_org(text):
            break
        chunks.append(text)
        if len(chunks) >= 3:
            break
    return " ".join(chunks).strip() or fallback


def fix_titles(data):
    changed = 0
    for issue in data.get("issues", []):
        for article in issue.get("articles", []):
            title = title_from_blocks(article.get("blocks", []), article.get("title", ""))
            if title and title != article.get("title"):
                article["title"] = title
                changed += 1
    return changed


def build_home(data):
    home = data["home"]
    latest = home.get("latestIssue", "")
    body = f"""<section class="hero hero--home">
  <div class="hero__inner">
    <div>
      <p class="eyebrow">Научно-практический журнал</p>
      <h1>{h(home.get("title"))}</h1>
      <p class="lead">{h(home.get("lead"))}</p>
      <div class="tagline"><span>РИНЦ</span><span>eLibrary.ru</span><span>до 6 выпусков в год</span></div>
    </div>
    <aside class="hero-card"><h2>Полные тексты</h2><p>Полные тексты статей размещаются на сайте eLibrary.ru. На сайте журнала доступны правила для авторов и аннотации последних выпусков.</p></aside>
  </div>
</section>
<section class="section home-panel"><div class="stat-strip"><div class="stat"><strong>2025</strong><span>актуальные выпуски</span></div><div class="stat"><strong>{h(latest)}</strong><span>последний выпуск</span></div><div class="stat"><strong>{h(home.get("foundedYear"))}</strong><span>год начала издания журнала</span></div></div></section>
<section class="section section--tight"><div class="section__head"><h2>О журнале</h2><p>«Астраханский вестник экологического образования» входит в перечень цитируемых в РИНЦ и размещается в полнотекстовом формате на eLibrary.ru.</p></div><div class="grid grid--three"><article class="card"><h3>Тематика</h3><p>Науки о Земле, биологические науки, экологическое образование, экология, природопользование и охрана окружающей среды.</p></article><article class="card"><h3>Материалы</h3><p>Теоретические и обзорные статьи, научные сообщения, краткие сообщения, рецензии, библиография, информация о конференциях и юбилейных датах.</p></article><article class="card"><h3>Периодичность</h3><p>Периодичность издания - до 6 раз в год. Язык издания - русский. Публикуются материалы, ранее не публиковавшиеся в других изданиях.</p></article></div></section>
<section class="section section--tight"><div class="section__head"><h2>Основные разделы</h2><p>Для авторов подготовлены требования к рукописям, пример оформления статьи, порядок рецензирования и условия публикации. В разделе «Издания» собраны аннотации выпусков и данные для цитирования.</p></div><div class="grid"><article class="card feature-link"><h3>Правила для авторов</h3><p>Требования к структуре рукописи, оформлению литературы, таблиц, рисунков, DOI, рецензированию и порядку публикации.</p><a class="button button--primary" href="authors.html">Открыть правила</a></article><article class="card feature-link"><h3>Издания</h3><p>Последний опубликованный на сайте выпуск: {h(latest)}. Полные тексты статей размещены на eLibrary.ru.</p><a class="button button--primary" href="issues.html">Смотреть издания</a></article></div></section>
<section class="section section--tight"><div class="process"><div class="process__intro"><h2>Публикация статьи</h2><p>Редакция принимает оригинальные материалы, ранее не публиковавшиеся в других изданиях. Перед отправкой статьи автору необходимо проверить оформление рукописи и комплект сопроводительных материалов.</p></div><ol class="process-list"><li><span>1</span><div><strong>Подготовить рукопись.</strong><br>Проверить структуру статьи, аннотацию, ключевые слова, список литературы, таблицы и рисунки.</div></li><li><span>2</span><div><strong>Отправить материалы.</strong><br>Направить статью и сведения об авторах в редакцию журнала.</div></li><li><span>3</span><div><strong>Пройти рассмотрение.</strong><br>Редакция рассматривает материал, направляет замечания или согласует публикацию.</div></li><li><span>4</span><div><strong>Смотреть выпуск.</strong><br>Аннотации публикуются на сайте, полные тексты размещаются на eLibrary.ru.</div></li></ol></div></section>
<section class="section" id="contacts">
  <div class="contact-panel">
    <div>
      <p class="eyebrow">Контакты</p>
      <h2>Связаться с редакцией</h2>
      <p>Материалы и вопросы по публикации можно направлять в редакцию журнала.</p>
      <p class="contact-email"><a href="mailto:{h(home.get("contactEmail"))}">{h(home.get("contactEmail"))}</a></p>
    </div>
    <form class="contact-form" action="/newsujet/feedback" method="post">
      <label>Имя<input name="name" type="text" required></label>
      <label>E-mail для связи<input name="email" type="email" required></label>
      <label>Текст сообщения<textarea name="text" rows="6" required></textarea></label>
      <input type="hidden" value="/succed">
      <button type="submit">Отправить сообщение</button>
    </form>
  </div>
</section>
"""
    html_page = page(home.get("title"), home.get("lead"), "home", home, body)
    write("index.html", html_page)
    write("preview.html", html_page)


def build_authors(data):
    home = data["home"]
    sections = data.get("authorSections", [])
    side = "".join(f'<a href="#{h(section.get("id"))}">{h(section.get("title"))}</a>' for section in sections)
    body_sections = []
    for section in sections:
        blocks = render_author_section(section)
        body_sections.append(f'<section class="content-section" id="{h(section.get("id"))}"><div class="content-section__head"><h2>{h(section.get("title"))}</h2></div><div class="content-section__body">{blocks}</div></section>')
    body = f"""<section class="hero"><div class="hero__inner"><div><p class="eyebrow">Правила для авторов</p><h1>Как подготовить и отправить статью</h1><p class="lead">Требования к рукописям, пример оформления статьи, условия публикации, рецензирование и англоязычные сведения для авторов.</p></div><aside class="hero-card"><h2>Разделы правил</h2><p>Откройте нужный раздел, чтобы посмотреть требования к подготовке и отправке материалов в журнал.</p></aside></div></section>
<section class="section section--tight"><div class="author-overview"><article><span>1</span><h3>Проверить соответствие</h3><p>Специальность ВАК, оригинальность, запрет на ИИ-тексты и повторные публикации.</p></article><article><span>2</span><h3>Подготовить файл</h3><p>Формат Word, поля, шрифт, таблицы, рисунки, подписи и список литературы.</p></article><article><span>3</span><h3>Оформить шапку</h3><p>Русские и английские сведения, аннотация, ключевые слова и данные для цитирования.</p></article><article><span>4</span><h3>Отправить и пройти рецензирование</h3><p>Комплект материалов, внешнее рецензирование, оплата, индекс статьи и контакты редакции.</p></article></div></section>
<section class="section"><div class="section__head"><h2>Подробные правила</h2><p>Правила сгруппированы по реальным задачам автора: от проверки соответствия до отправки материалов и публикации.</p></div><div class="content-layout"><aside class="side-nav">{side}</aside><div class="content-flow">{''.join(body_sections)}</div></div></section>"""
    write("authors.html", page(f'Правила для авторов | {home.get("title")}', "Требования к рукописям и условия публикации", "authors", home, body))


def build_issues(data):
    home = data["home"]
    issues = data.get("issues", [])
    cards = []
    for issue in issues:
        cards.append(f'<article class="issue-card"><p class="eyebrow">Выпуск</p><h2>{h(issue.get("label"))}</h2><p>{len(issue.get("articles", []))} статей</p><a class="button button--primary" href="issues/{h(issue.get("slug"))}.html">Открыть выпуск</a></article>')
    body = f"""<section class="hero"><div class="hero__inner"><div><p class="eyebrow">Издания</p><h1>Последние выпуски</h1><p class="lead">Аннотации статей, ключевые слова и данные для цитирования. Полные тексты размещены на eLibrary.ru.</p></div><aside class="hero-card"><h2>{len(issues)} выпусков</h2><p><a href="{h(home.get("elibraryUrl"))}" target="_blank" rel="noopener">Страница журнала на eLibrary.ru</a></p></aside></div></section>
<section class="section"><div class="issue-grid">{''.join(cards)}</div></section>"""
    write("issues.html", page(f'Издания | {home.get("title")}', "Аннотации выпусков журнала", "issues", home, body))
    for issue in issues:
        articles = issue.get("articles", [])
        nav = "".join(f'<a href="#article-{i}">{i}</a>' for i in range(1, len(articles) + 1))
        article_html = []
        for i, article in enumerate(articles, 1):
            blocks = "".join(p(block) for block in article.get("blocks", []))
            article_html.append(f'<article class="article-card" id="article-{i}"><div class="article-card__head"><span>{i}</span><h2>{h(article.get("title"))}</h2></div><div class="article-card__body">{blocks}</div></article>')
        body = f"""<section class="hero"><div class="hero__inner"><div><p class="eyebrow">Выпуск</p><h1>{h(issue.get("label"))}</h1><p class="lead">Аннотации статей, ключевые слова и данные для цитирования.</p></div><aside class="hero-card"><h2>{len(articles)} статей</h2><p><a href="../issues.html">Вернуться к списку выпусков</a></p></aside></div></section>
<section class="section"><div class="issue-toolbar"><a class="button" href="../issues.html">Все выпуски</a><nav aria-label="Статьи выпуска">{nav}</nav></div><div class="article-list">{''.join(article_html)}</div></section>"""
        write(f'issues/{issue.get("slug")}.html', page(f'{issue.get("label")} | {home.get("title")}', f'Аннотации выпуска {issue.get("label")}', "issues", home, body, depth=1))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fix-titles", action="store_true")
    args = parser.parse_args()
    data = json.loads(DATA.read_text(encoding="utf-8"))
    changed = fix_titles(data) if args.fix_titles else 0
    if changed:
        DATA.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    build_home(data)
    build_authors(data)
    build_issues(data)
    print(f"generated: {len(data.get('issues', []))} issues; title fixes: {changed}")


if __name__ == "__main__":
    main()
