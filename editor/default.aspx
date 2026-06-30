<%@ Page Language="C#" ValidateRequest="false" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<script runat="server">
string DataPath { get { return Server.MapPath("~/App_Data/site-content.json"); } }
string AuthPath { get { return Server.MapPath("~/App_Data/editor-auth.json"); } }
JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
protected void Page_Load(object sender, EventArgs e) {
  Directory.CreateDirectory(Server.MapPath("~/App_Data/backups"));
  if (!File.Exists(AuthPath)) { HandleSetup(); return; }
  if (Session["editor"] == null) { HandleLogin(); return; }
  if (Request.HttpMethod == "POST" && Request.Form["action"] == "logout") { Session.Abandon(); Response.Redirect("default.aspx"); return; }
  if (Request.HttpMethod == "POST" && Request.Form["action"] == "save") { SaveContent(); return; }
  RenderEditor(null);
}
void HandleSetup() {
  if (Request.HttpMethod == "POST" && Request.Form["action"] == "setup") {
    string pass = Request.Form["password"] ?? "";
    if (pass.Length < 10) { RenderSetup("Пароль должен быть не короче 10 символов."); return; }
    File.WriteAllText(AuthPath, Json.Serialize(HashPassword(pass)), Encoding.UTF8);
    Session["editor"] = true;
    Response.Redirect("default.aspx"); return;
  }
  RenderSetup(null);
}
void HandleLogin() {
  if (Request.HttpMethod == "POST" && Request.Form["action"] == "login") {
    string pass = Request.Form["password"] ?? "";
    dynamic auth = Json.DeserializeObject(File.ReadAllText(AuthPath, Encoding.UTF8));
    if (VerifyPassword(pass, auth)) { Session["editor"] = true; Response.Redirect("default.aspx"); return; }
    RenderLogin("Неверный пароль."); return;
  }
  RenderLogin(null);
}
void SaveContent() {
  string raw = Request.Form["contentJson"] ?? "";
  Dictionary<string, object> root = null;
  try {
    root = Json.Deserialize<Dictionary<string, object>>(raw);
    ValidateContent(root);
  }
  catch (Exception ex) { RenderEditor("JSON не сохранен: " + H(ex.Message)); return; }
  if (File.Exists(DataPath)) {
    string stamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss");
    File.Copy(DataPath, Server.MapPath("~/App_Data/backups/site-content-" + stamp + ".json"), false);
  }
  File.WriteAllText(DataPath + ".tmp", raw, Encoding.UTF8);
  if (File.Exists(DataPath)) File.Delete(DataPath);
  File.Move(DataPath + ".tmp", DataPath);
  GeneratePublicPages(root);
  RenderEditor("Сохранено. Резервная копия создана. Статические страницы сайта обновлены.");
}
object HashPassword(string pass) {
  byte[] salt = new byte[16]; using (var rng = new RNGCryptoServiceProvider()) rng.GetBytes(salt);
  using (var pbkdf = new Rfc2898DeriveBytes(pass, salt, 120000)) {
    return new { salt = Convert.ToBase64String(salt), hash = Convert.ToBase64String(pbkdf.GetBytes(32)), iterations = 120000 };
  }
}
bool VerifyPassword(string pass, dynamic auth) {
  byte[] salt = Convert.FromBase64String((string)auth["salt"]);
  int iter = Convert.ToInt32(auth["iterations"]);
  byte[] expected = Convert.FromBase64String((string)auth["hash"]);
  using (var pbkdf = new Rfc2898DeriveBytes(pass, salt, iter)) {
    byte[] actual = pbkdf.GetBytes(32); if (actual.Length != expected.Length) return false;
    int diff = 0; for (int i=0;i<actual.Length;i++) diff |= actual[i] ^ expected[i]; return diff == 0;
  }
}
string H(string s) { return HttpUtility.HtmlEncode(s ?? ""); }
Dictionary<string, object> Dict(object value) { return value as Dictionary<string, object> ?? new Dictionary<string, object>(); }
object[] Arr(object value) { return value as object[] ?? new object[0]; }
string Val(Dictionary<string, object> d, string key) { object v; return d != null && d.TryGetValue(key, out v) && v != null ? Convert.ToString(v) : ""; }
void ValidateContent(Dictionary<string, object> root) {
  if (root == null) throw new Exception("Нет корневого объекта данных.");
  if (!root.ContainsKey("home")) throw new Exception("Нет раздела home.");
  if (Arr(root.ContainsKey("issues") ? root["issues"] : null).Length == 0) throw new Exception("Нет выпусков.");
}
string C(string value) {
  if (String.IsNullOrEmpty(value)) return "content-paragraph";
  if (value.IndexOf("Уважаемые", StringComparison.OrdinalIgnoreCase) >= 0 || value.IndexOf("Внимание", StringComparison.OrdinalIgnoreCase) >= 0 || value.ToUpperInvariant() == value && value.Length > 80) return "content-paragraph content-paragraph--warning";
  if (value.ToUpperInvariant() == value && value.Length > 8) return "content-paragraph content-paragraph--strong";
  return "content-paragraph";
}
string P(string value) { return "<p class='" + C(value) + "'>" + H(value) + "</p>"; }
string SafeSlug(string value) {
  string s = value ?? "";
  StringBuilder b = new StringBuilder();
  foreach (char ch in s) if ((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '-') b.Append(ch);
  return b.Length > 0 ? b.ToString() : "issue";
}
string Header(string current, Dictionary<string, object> home) {
  string elib = Val(home, "elibraryUrl");
  string title = Val(home, "title");
  return "<header class='topbar'><div class='topbar__inner'><a class='brand' href='/'><img src='/img/logo.png' alt='' class='brand__logo'><span><strong>" + H(title) + "</strong><small>научно-практический журнал</small></span></a><nav class='nav' aria-label='Основная навигация'>" +
    "<a href='/'" + (current == "home" ? " aria-current='page'" : "") + ">Главная</a><a href='/authors.html'" + (current == "authors" ? " aria-current='page'" : "") + ">Для авторов</a><a href='/issues.html'" + (current == "issues" ? " aria-current='page'" : "") + ">Издания</a><a href='/#contacts'>Контакты</a><a href='" + H(elib) + "' target='_blank' rel='noopener'>eLibrary</a></nav></div></header>";
}
string Footer(Dictionary<string, object> home) {
  string elib = Val(home, "elibraryUrl");
  string email = Val(home, "contactEmail");
  string title = Val(home, "title");
  return "<footer class='site-footer'><div class='footer-card'><p class='footer-title'>" + H(title) + "</p><nav class='footer-nav' aria-label='Навигация в подвале'><a href='/'>Главная</a><span></span><a href='/authors.html'>Для авторов</a><span></span><a href='/issues.html'>Издания</a><span></span><a href='/#contacts'>Контакты</a><span></span><a href='" + H(elib) + "' target='_blank' rel='noopener'>eLibrary</a></nav><p class='footer-contact'><a href='mailto:" + H(email) + "'>" + H(email) + "</a></p></div></footer>";
}
string Page(string title, string description, string current, Dictionary<string, object> home, string body) {
  return "<!doctype html><html lang='ru'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>" + H(title) + "</title><meta name='description' content='" + H(description) + "'><link rel='stylesheet' href='/css/site.css'></head><body>" + Header(current, home) + "<main>" + body + "</main>" + Footer(home) + "</body></html>";
}
void AtomicWrite(string rel, string html) {
  string path = Server.MapPath("~/" + rel.TrimStart('/'));
  Directory.CreateDirectory(Path.GetDirectoryName(path));
  string tmp = path + ".tmp";
  File.WriteAllText(tmp, html, Encoding.UTF8);
  if (File.Exists(path)) File.Delete(path);
  File.Move(tmp, path);
}
void GeneratePublicPages(Dictionary<string, object> root) {
  Dictionary<string, object> home = Dict(root["home"]);
  object[] issues = Arr(root["issues"]);
  object[] authors = Arr(root["authorSections"]);
  string title = Val(home, "title");
  string email = Val(home, "contactEmail");
  string elib = Val(home, "elibraryUrl");
  string latest = Val(home, "latestIssue");
  StringBuilder b = new StringBuilder();
  b.Append("<section class='hero hero--home'><div class='hero__inner'><div><p class='eyebrow'>Научно-практический журнал</p><h1>").Append(H(title)).Append("</h1><p class='lead'>").Append(H(Val(home, "lead"))).Append("</p><div class='tagline'><span>РИНЦ</span><span>eLibrary.ru</span><span>до 6 выпусков в год</span></div></div><aside class='hero-card'><h2>Полные тексты</h2><p>Полные тексты статей размещаются на сайте eLibrary.ru. На сайте журнала доступны правила для авторов и аннотации последних выпусков.</p></aside></div></section>");
  b.Append("<section class='section home-panel'><div class='stat-strip'><div class='stat'><strong>2025</strong><span>актуальные выпуски</span></div><div class='stat'><strong>").Append(H(latest)).Append("</strong><span>последний выпуск</span></div><div class='stat'><strong>").Append(H(Val(home, "foundedYear"))).Append("</strong><span>год начала издания журнала</span></div></div></section>");
  b.Append("<section class='section section--tight'><div class='section__head'><h2>О журнале</h2><p>«Астраханский вестник экологического образования» входит в перечень цитируемых в РИНЦ и размещается в полнотекстовом формате на eLibrary.ru.</p></div><div class='grid grid--three'><article class='card'><h3>Тематика</h3><p>Науки о Земле, биологические науки, экологическое образование, природопользование и охрана окружающей среды.</p></article><article class='card'><h3>Материалы</h3><p>Теоретические и обзорные статьи, научные сообщения, краткие сообщения, рецензии, библиография, информация о конференциях и юбилейных датах.</p></article><article class='card'><h3>Периодичность</h3><p>Периодичность издания - до 6 раз в год. Язык издания - русский.</p></article></div></section>");
  b.Append("<section class='section section--tight'><div class='section__head'><h2>Основные разделы</h2><p>Для авторов подготовлены требования к рукописям, пример оформления статьи, порядок рецензирования и условия публикации. В разделе «Издания» собраны аннотации выпусков и данные для цитирования.</p></div><div class='grid'><article class='card feature-link'><h3>Правила для авторов</h3><p>Требования к структуре рукописи, оформлению литературы, таблиц, рисунков, DOI, рецензированию и порядку публикации.</p><a class='button button--primary' href='/authors.html'>Открыть правила</a></article><article class='card feature-link'><h3>Издания</h3><p>Последний опубликованный на сайте выпуск: ").Append(H(latest)).Append(". Полные тексты статей размещены на eLibrary.ru.</p><a class='button button--primary' href='/issues.html'>Смотреть издания</a></article></div></section>");
  b.Append("<section class='section' id='contacts'><div class='contact-panel'><div><p class='eyebrow'>Контакты</p><h2>Связаться с редакцией</h2><p>Материалы и вопросы по публикации можно направлять в редакцию журнала.</p><p class='contact-email'><a href='mailto:").Append(H(email)).Append("'>").Append(H(email)).Append("</a></p></div><form class='contact-form' action='/newsujet/feedback' method='post'><label>Имя<input name='name' type='text' required></label><label>E-mail для связи<input name='email' type='email' required></label><label>Текст сообщения<textarea name='text' rows='6' required></textarea></label><input type='hidden' value='/succed'><button type='submit'>Отправить сообщение</button></form></div></section>");
  string homePage = Page(title, Val(home, "lead"), "home", home, b.ToString());
  AtomicWrite("index.html", homePage); AtomicWrite("preview.html", homePage);

  b.Length = 0;
  b.Append("<section class='hero'><div class='hero__inner'><div><p class='eyebrow'>Правила для авторов</p><h1>Как подготовить и отправить статью</h1><p class='lead'>Требования к рукописям, пример оформления статьи, условия публикации, рецензирование и англоязычные сведения для авторов.</p></div><aside class='hero-card'><h2>Разделы правил</h2><p>Откройте нужный раздел, чтобы посмотреть требования к подготовке и отправке материалов в журнал.</p></aside></div></section><section class='section'><div class='section__head'><h2>Правила для авторов</h2><p>Требования сгруппированы по смыслу и сохранены из исходной страницы.</p></div><div class='content-layout'><aside class='side-nav'>");
  foreach (object ao in authors) { Dictionary<string, object> a = Dict(ao); b.Append("<a href='#").Append(H(Val(a, "id"))).Append("'>").Append(H(Val(a, "title"))).Append("</a>"); }
  b.Append("</aside><div class='content-flow'>");
  foreach (object ao in authors) {
    Dictionary<string, object> a = Dict(ao); b.Append("<section class='content-section' id='").Append(H(Val(a, "id"))).Append("'><div class='content-section__head'><h2>").Append(H(Val(a, "title"))).Append("</h2></div><div class='content-section__body'>");
    foreach (object block in Arr(a["blocks"])) b.Append(P(Convert.ToString(block)));
    b.Append("</div></section>");
  }
  b.Append("</div></div></section>");
  AtomicWrite("authors.html", Page("Правила для авторов | " + title, "Требования к рукописям и условия публикации", "authors", home, b.ToString()));

  b.Length = 0;
  b.Append("<section class='hero'><div class='hero__inner'><div><p class='eyebrow'>Издания</p><h1>Последние выпуски</h1><p class='lead'>Аннотации статей, ключевые слова и данные для цитирования. Полные тексты размещены на eLibrary.ru.</p></div><aside class='hero-card'><h2>").Append(issues.Length).Append(" выпусков</h2><p><a href='").Append(H(elib)).Append("' target='_blank' rel='noopener'>Страница журнала на eLibrary.ru</a></p></aside></div></section><section class='section'><div class='issue-grid'>");
  foreach (object io in issues) {
    Dictionary<string, object> issue = Dict(io); string slug = SafeSlug(Val(issue, "slug")); int count = Arr(issue["articles"]).Length;
    b.Append("<article class='issue-card'><p class='eyebrow'>Выпуск</p><h2>").Append(H(Val(issue, "label"))).Append("</h2><p>").Append(count).Append(" статей</p><a class='button button--primary' href='/issues/").Append(H(slug)).Append(".html'>Открыть выпуск</a></article>");
  }
  b.Append("</div></section>");
  AtomicWrite("issues.html", Page("Издания | " + title, "Аннотации выпусков журнала", "issues", home, b.ToString()));

  foreach (object io in issues) {
    Dictionary<string, object> issue = Dict(io); string slug = SafeSlug(Val(issue, "slug")); object[] articles = Arr(issue["articles"]);
    b.Length = 0;
    b.Append("<section class='hero'><div class='hero__inner'><div><p class='eyebrow'>Выпуск</p><h1>").Append(H(Val(issue, "label"))).Append("</h1><p class='lead'>Аннотации статей, ключевые слова и данные для цитирования.</p></div><aside class='hero-card'><h2>").Append(articles.Length).Append(" статей</h2><p><a href='/issues.html'>Вернуться к списку выпусков</a></p></aside></div></section><section class='section'><div class='issue-toolbar'><a class='button' href='/issues.html'>Все выпуски</a><nav aria-label='Статьи выпуска'>");
    for (int i = 0; i < articles.Length; i++) b.Append("<a href='#article-").Append(i + 1).Append("'>").Append(i + 1).Append("</a>");
    b.Append("</nav></div><div class='article-list'>");
    for (int i = 0; i < articles.Length; i++) {
      Dictionary<string, object> article = Dict(articles[i]);
      b.Append("<article class='article-card' id='article-").Append(i + 1).Append("'><div class='article-card__head'><span>").Append(i + 1).Append("</span><h2>").Append(H(Val(article, "title"))).Append("</h2></div><div class='article-card__body'>");
      foreach (object block in Arr(article["blocks"])) b.Append(P(Convert.ToString(block)));
      b.Append("</div></article>");
    }
    b.Append("</div></section>");
    AtomicWrite("issues/" + slug + ".html", Page(Val(issue, "label") + " | " + title, "Аннотации выпуска " + Val(issue, "label"), "issues", home, b.ToString()));
  }
}
void PageTop(string title) { Response.Write("<!doctype html><html lang='ru'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>"+H(title)+"</title><style>body{font-family:system-ui,-apple-system,Segoe UI,Arial,sans-serif;background:#f6f7f4;color:#17211d;margin:0}.wrap{max-width:1100px;margin:0 auto;padding:32px}header{display:flex;justify-content:space-between;gap:16px;align-items:center;margin-bottom:24px}.panel{background:#fff;border:1px solid #dfe5dd;border-radius:8px;box-shadow:0 18px 50px rgba(23,33,29,.09);padding:24px;margin-bottom:18px}input,textarea{width:100%;box-sizing:border-box;padding:10px;border:1px solid #dfe5dd;border-radius:6px;font:inherit}textarea{min-height:130px}button{border:0;border-radius:8px;background:#176b4d;color:#fff;padding:10px 14px;font-weight:800;cursor:pointer}.secondary{background:#eef4ef;color:#0f4736}.danger{background:#b84a3a}.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}.item{border:1px solid #dfe5dd;border-radius:8px;padding:14px;margin:10px 0;background:#fbfcfb}.muted{color:#5d6a63}.msg{background:#fffaf0;border-left:4px solid #c8861f;padding:12px;margin-bottom:16px}@media(max-width:760px){.grid{grid-template-columns:1fr}}</style></head><body><div class='wrap'>"); }
void PageEnd() { Response.Write("</div></body></html>"); }
void RenderSetup(string msg) { PageTop("Настройка редактора"); if(msg!=null) Response.Write("<div class='msg'>"+msg+"</div>"); Response.Write("<div class='panel'><h1>Настройка редактора</h1><p>Создайте пароль администратора. Хранится только PBKDF2-хэш.</p><form method='post'><input type='hidden' name='action' value='setup'><label>Пароль<input type='password' name='password' required minlength='10'></label><p><button>Создать пароль</button></p></form></div>"); PageEnd(); }
void RenderLogin(string msg) { PageTop("Вход в редактор"); if(msg!=null) Response.Write("<div class='msg'>"+msg+"</div>"); Response.Write("<div class='panel'><h1>Вход в редактор</h1><form method='post'><input type='hidden' name='action' value='login'><label>Пароль<input type='password' name='password' required></label><p><button>Войти</button></p></form></div>"); PageEnd(); }
void RenderEditor(string msg) {
  string raw = File.Exists(DataPath) ? File.ReadAllText(DataPath, Encoding.UTF8) : "{}";
  PageTop("Редактор сайта");
  Response.Write("<header><div><h1>Редактор сайта</h1><p class='muted'>Изменения сохраняются в App_Data/site-content.json; перед сохранением создается резервная копия.</p></div><form method='post'><input type='hidden' name='action' value='logout'><button class='secondary'>Выйти</button></form></header>");
  if(msg!=null) Response.Write("<div class='msg'>"+msg+"</div>");
  Response.Write("<form method='post' id='editorForm'><input type='hidden' name='action' value='save'><input type='hidden' name='contentJson' id='contentJson'><div id='app'></div><p><button type='submit'>Сохранить</button></p></form>");
  Response.Write("<script id='initial' type='application/json'>"+H(raw)+"</script>");
  Response.Write(@"<script>
const data=JSON.parse(document.getElementById('initial').textContent||'{}');
const app=document.getElementById('app');
function esc(s){return String(s||'').replace(/[&<>'\x22]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\'':'&#39;','\x22':'&quot;'}[c]));}
function ta(v){return esc((v||[]).join('\n\n'));}
function split(v){return String(v||'').split(/\n\s*\n/g).map(x=>x.trim()).filter(Boolean);}
function collect(){
 data.home=data.home||{}; data.home.title=document.getElementById('home_title').value; data.home.contactEmail=document.getElementById('home_email').value; data.home.elibraryUrl=document.getElementById('home_elib').value; data.home.latestIssue=document.getElementById('home_latest').value; data.home.lead=document.getElementById('home_lead').value;
 document.querySelectorAll('.author-title').forEach(el=>data.authorSections[+el.dataset.i].title=el.value);
 document.querySelectorAll('.author-blocks').forEach(el=>data.authorSections[+el.dataset.i].blocks=split(el.value));
 document.querySelectorAll('.issue-label').forEach(el=>data.issues[+el.dataset.ii].label=el.value);
 document.querySelectorAll('.issue-slug').forEach(el=>data.issues[+el.dataset.ii].slug=el.value);
 document.querySelectorAll('.article-title').forEach(el=>data.issues[+el.dataset.ii].articles[+el.dataset.ai].title=el.value);
 document.querySelectorAll('.article-blocks').forEach(el=>data.issues[+el.dataset.ii].articles[+el.dataset.ai].blocks=split(el.value));
}
function render(){
 app.innerHTML=`<div class='panel'><h2>Главная</h2><div class='grid'><label>Название<input id='home_title' value='${esc(data.home?.title)}'></label><label>Email<input id='home_email' value='${esc(data.home?.contactEmail)}'></label><label>eLibrary URL<input id='home_elib' value='${esc(data.home?.elibraryUrl)}'></label><label>Последний выпуск<input id='home_latest' value='${esc(data.home?.latestIssue)}'></label></div><label>Вступительный текст<textarea id='home_lead'>${esc(data.home?.lead)}</textarea></label></div>`;
 app.innerHTML+=`<div class='panel'><h2>Правила для авторов</h2>${(data.authorSections||[]).map((s,i)=>`<div class='item'><label>Заголовок<input class='author-title' data-i='${i}' value='${esc(s.title)}'></label><label>Текст раздела<textarea class='author-blocks' data-i='${i}'>${ta(s.blocks)}</textarea></label></div>`).join('')}</div>`;
 app.innerHTML+=`<div class='panel'><h2>Издания</h2><p class='muted'>Каждая статья хранится блоками текста, разделенными пустой строкой.</p><p><button type='button' class='secondary' data-action='issue-add'>Добавить выпуск</button></p>${(data.issues||[]).map((issue,ii)=>`<div class='item'><h3>${esc(issue.label||'Новый выпуск')}</h3><p><button type='button' class='secondary' data-action='issue-up' data-ii='${ii}'>Выше</button> <button type='button' class='secondary' data-action='issue-down' data-ii='${ii}'>Ниже</button> <button type='button' class='danger' data-action='issue-delete' data-ii='${ii}'>Удалить выпуск</button></p><div class='grid'><label>Номер выпуска<input class='issue-label' data-ii='${ii}' value='${esc(issue.label)}'></label><label>Slug<input class='issue-slug' data-ii='${ii}' value='${esc(issue.slug)}'></label></div><p><button type='button' class='secondary' data-action='article-add' data-ii='${ii}'>Добавить статью</button></p>${(issue.articles||[]).map((a,ai)=>`<div class='item'><p><button type='button' class='secondary' data-action='article-up' data-ii='${ii}' data-ai='${ai}'>Выше</button> <button type='button' class='secondary' data-action='article-down' data-ii='${ii}' data-ai='${ai}'>Ниже</button> <button type='button' class='danger' data-action='article-delete' data-ii='${ii}' data-ai='${ai}'>Удалить статью</button></p><label>Заголовок статьи<input class='article-title' data-ii='${ii}' data-ai='${ai}' value='${esc(a.title)}'></label><label>Блоки статьи<textarea class='article-blocks' data-ii='${ii}' data-ai='${ai}'>${ta(a.blocks)}</textarea></label></div>`).join('')}</div>`).join('')}</div>`;
}
render();
app.addEventListener('click',e=>{
 const btn=e.target.closest('button[data-action]'); if(!btn) return; collect();
 const a=btn.dataset.action, ii=+btn.dataset.ii, ai=+btn.dataset.ai;
 if(a==='issue-add') data.issues.push({label:'Новый выпуск',slug:'new-issue',articles:[]});
 if(a==='issue-delete' && confirm('Удалить выпуск?')) data.issues.splice(ii,1);
 if(a==='issue-up' && ii>0) [data.issues[ii-1],data.issues[ii]]=[data.issues[ii],data.issues[ii-1]];
 if(a==='issue-down' && ii<data.issues.length-1) [data.issues[ii+1],data.issues[ii]]=[data.issues[ii],data.issues[ii+1]];
 if(a==='article-add') data.issues[ii].articles.push({title:'Новая статья',blocks:['Новая статья']});
 if(a==='article-delete' && confirm('Удалить статью?')) data.issues[ii].articles.splice(ai,1);
 if(a==='article-up' && ai>0) [data.issues[ii].articles[ai-1],data.issues[ii].articles[ai]]=[data.issues[ii].articles[ai],data.issues[ii].articles[ai-1]];
 if(a==='article-down' && ai<data.issues[ii].articles.length-1) [data.issues[ii].articles[ai+1],data.issues[ii].articles[ai]]=[data.issues[ii].articles[ai],data.issues[ii].articles[ai+1]];
 render();
});
document.getElementById('editorForm').addEventListener('submit',()=>{
 collect();
 document.getElementById('contentJson').value=JSON.stringify(data,null,2);
});
</script>");
  PageEnd();
}
</script>
