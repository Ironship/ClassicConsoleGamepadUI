local _, Addon = ...
-- What the on-screen keyboard knows about each language it can type in: the rows of the full keyboard, the letters under the
-- phone keys, a few hundred common words (where the suggestions start, see Words.lua) and where WordHunterWoW keeps a
-- word list for it. The letter tables the keyboard and the word list share are here too.
local Languages = {}
Addon.Languages = Languages

-- One UTF-8 character.
Languages.CHARACTER = "[%z\1-\127\194-\244][\128-\191]*"

-- The phone keys: the digit and its plain letters.
local KEYS = { ["2"] = "abc", ["3"] = "def", ["4"] = "ghi", ["5"] = "jkl", ["6"] = "mno", ["7"] = "pqrs", ["8"] = "tuv",
    ["9"] = "wxyz" }
Languages.KEYS = KEYS

-- Letters beyond ASCII that the languages use: lowercase, uppercase, and the plain letter whose phone key they share.
local ACCENTED = {
    { "à", "À", "a" }, { "á", "Á", "a" }, { "â", "Â", "a" }, { "ã", "Ã", "a" }, { "ä", "Ä", "a" }, { "ą", "Ą", "a" },
    { "ç", "Ç", "c" }, { "ć", "Ć", "c" },
    { "è", "È", "e" }, { "é", "É", "e" }, { "ê", "Ê", "e" }, { "ë", "Ë", "e" }, { "ę", "Ę", "e" },
    { "ì", "Ì", "i" }, { "í", "Í", "i" }, { "î", "Î", "i" }, { "ï", "Ï", "i" },
    { "ł", "Ł", "l" },
    { "ñ", "Ñ", "n" }, { "ń", "Ń", "n" },
    { "ò", "Ò", "o" }, { "ó", "Ó", "o" }, { "ô", "Ô", "o" }, { "õ", "Õ", "o" }, { "ö", "Ö", "o" }, { "œ", "Œ", "o" },
    { "ś", "Ś", "s" },
    { "ù", "Ù", "u" }, { "ú", "Ú", "u" }, { "û", "Û", "u" }, { "ü", "Ü", "u" },
    { "ź", "Ź", "z" }, { "ż", "Ż", "z" },
    { "ÿ", "Ÿ", "y" },
}

-- UPPER[lowercase letter] = uppercase letter, LOWER the other way round; DIGIT[letter] = its phone key.
local UPPER, LOWER, DIGIT = {}, {}, {}
for digit, letters in pairs(KEYS) do
    for letter in letters:gmatch(".") do DIGIT[letter] = digit end
end
for _, letter in ipairs(ACCENTED) do
    UPPER[letter[1]], LOWER[letter[2]] = letter[2], letter[1]
    DIGIT[letter[1]] = DIGIT[letter[3]]
end
-- The German sharp s has no capital letter here, and sits on the key of s.
DIGIT["ß"] = DIGIT["s"]
Languages.UPPER, Languages.LOWER, Languages.DIGIT = UPPER, LOWER, DIGIT

-- The letters of ASCII are changed by byte range and the others by table, so what comes out never depends on the
-- locale the client runs in.
function Languages.Upper(text)
    return (text:gsub("[a-z]+", string.upper):gsub("[\195-\197][\128-\191]", UPPER))
end

function Languages.Lower(text)
    return (text:gsub("[A-Z]+", string.lower):gsub("[\195-\197][\128-\191]", LOWER))
end

-- The characters of a text as a list (UTF-8 aware).
function Languages.Characters(text)
    local list = {}
    for character in text:gmatch(Languages.CHARACTER) do list[#list + 1] = character end
    return list
end

-- ---------------------------------------------------------------------------------------------
-- The languages. rows: the three letter rows of the full keyboard under the digits (Keyboard.lua adds the keys that are
-- not letters to each and makes every row as wide as the digit row); extra: one more row of accented letters. phone:
-- letters under the phone keys where they differ from the plain ones. locales: the game locales of the WordHunterWoW
-- dictionaries for it.
-- ---------------------------------------------------------------------------------------------

local function Row(letters)
    return Languages.Characters(letters)
end

Languages.order = { "EN", "DE", "PL", "FR", "ES", "IT", "PT", "KO" }

Languages.EN = {
    name = "English", layout = "QWERTY",
    rows = { Row("qwertyuiop[]\\"), Row("asdfghjkl;'"), Row("zxcvbnm,./") },
    phone = {},
    seeds = "a i the and you for that with this have are not but what all can your was will just they get out how now here "
        .. "there who when good thanks please help need group guild join run dungeon quest level going want anyone yes no "
        .. "ok hello hi bye sorry wait ready tank heal dps loot come let see one two to of in it is on at be as do we he "
        .. "she me my so if or by up an go from about would could should like know think time people back again over "
        .. "then them were been has had did more some any very much well still after before only also too into down off "
        .. "take make give look find kill use try work play game raid boss pull aggro mana health rest buff thank thx "
        .. "lol brb afk invite party trade sell buy price gold silver copper item gear weapon armor bag bank mail auction "
        .. "vendor repair flight portal summon mount talent rogue mage priest paladin warrior hunter shaman druid warlock "
        .. "human dwarf gnome elf orc troll tauren undead stormwind orgrimmar ironforge darnassus undercity lfg lfm lf "
        .. "wts wtb wtt inv",
}

Languages.DE = {
    name = "Deutsch", layout = "QWERTZ", locales = { "deDE" },
    rows = { Row("qwertzuiop[]\\"), Row("asdfghjkl;'äö"), Row("yxcvbnm,./üß") },
    phone = { ["2"] = "abcä", ["6"] = "mnoö", ["7"] = "pqrsß", ["8"] = "tuvü" },
    seeds = "und der die das ist nicht ich du wir ihr ein eine mit für auf ja nein danke bitte hallo hilfe suche gilde "
        .. "gruppe jemand noch auch aber wie was wer wo wann kann kannst will bin bist hab habe gut schon mal komm komme "
        .. "los warte bereit tschüss es sie er zu in von den dem des im am an bei nach aus um über unter vor durch ohne "
        .. "gegen wenn dann dass weil oder doch nur sehr mehr viel hier dort jetzt heute morgen gestern immer nie oft "
        .. "schnell langsam groß klein neu alt gern gerne leider vielleicht natürlich genau wirklich richtig falsch alles "
        .. "nichts etwas niemand wieder weiter zurück spiel spieler heiler schaden tank dungeon raid boss quest stufe "
        .. "level gold silber kupfer tasche bank post auktion händler reparieren flug portal beschwören reittier talent "
        .. "klasse schurke magier priester paladin krieger jäger schamane druide hexenmeister mensch zwerg gnom elf ork "
        .. "troll taure untoter sturmwind orgrimmar eisenschmiede darnassus donnerfels unterstadt sind wurde werden haben "
        .. "hat hatte war waren sein euch uns mich dich mir dir ihm ihn kein keine einen meine deine unser ob warum wieso "
        .. "welche welcher was schön sehr gute nacht tag abend",
}

Languages.PL = {
    name = "Polski", layout = "QWERTY",
    rows = { Row("qwertyuiop[]\\"), Row("asdfghjkl;'"), Row("zxcvbnm,./") },
    extra = Row("ąćęłńóśźż"),
    phone = { ["2"] = "aąbcć", ["3"] = "deęf", ["5"] = "jklł", ["6"] = "mnńoó", ["7"] = "pqrsś", ["9"] = "wxyzźż" },
    seeds = "i w nie na to jest się z do że co ale jak tak czy ja ty on my wy cześć dzięki proszę pomoc gildia grupa ktoś "
        .. "szukam mogę chcę dobra dobrze hej czekaj gotowy pa już tu tam kto gdzie kiedy ona ono oni one mnie ciebie jego "
        .. "jej nas was ich mi ci mu go ją je po za od przez dla bez pod nad przed między o u przy ze we ku bo żeby gdy "
        .. "jeśli albo lub oraz więc wtedy teraz potem zaraz dzisiaj jutro wczoraj zawsze nigdy często szybko wolno duży "
        .. "mały nowy stary może można trzeba muszę musisz musi chcesz chce będzie będę byłem był była było były są "
        .. "jestem jesteś mamy masz mam miał miała bardzo więcej mniej wszystko nic coś nikt tutaj stąd dlaczego jaki "
        .. "jaka jakie który która które ile dziękuję przepraszam sorry spoko ok okej super fajnie gra gracz grać "
        .. "leczenie uzdrowiciel obrażenia tank loch rajd boss zadanie poziom złoto srebro miedź torba bank poczta "
        .. "aukcja handlarz naprawa lot portal przywołanie wierzchowiec talent klasa łotrzyk mag kapłan paladyn "
        .. "wojownik łowca szaman druid czarnoksiężnik człowiek krasnolud gnom elf ork troll tauren nieumarły",
}

Languages.FR = {
    name = "Français", layout = "AZERTY", locales = { "frFR" },
    rows = { Row("azertyuiop[]\\"), Row("qsdfghjklm;'"), Row("wxcvbn,./") },
    extra = Row("éèêëàâùûçîïôœ"),
    phone = { ["2"] = "abcàâç", ["3"] = "deféèêë", ["4"] = "ghiîï", ["6"] = "mnoôœ", ["8"] = "tuvùûü" },
    seeds = "le la les un une des de du et est pas je tu il elle nous vous ils elles ce cette ces mon ma mes ton ta tes "
        .. "son sa ses notre votre leur que qui quoi où quand comment pourquoi oui non merci svp salut bonjour bonsoir "
        .. "bonne nuit aide besoin cherche groupe guilde avec pour dans sur sous par sans mais ou donc car si alors puis "
        .. "aussi encore déjà toujours jamais très trop peu bien mal mieux plus moins tout tous toute toutes rien "
        .. "quelque chose personne ici là maintenant demain hier soir matin suis es sommes êtes sont ai as avons avez "
        .. "ont était sera fait faire aller vais vas va allons allez vont veux veut voulez peux peut pouvez dois doit "
        .. "venir viens vient attends prêt prête désolé beaucoup tank soigneur dégâts donjon raid boss quête niveau or "
        .. "argent cuivre sac banque courrier vente marchand réparer vol portail invocation monture talent classe "
        .. "voleur mage prêtre paladin guerrier chasseur chaman druide démoniste humain nain gnome elfe orc troll "
        .. "tauren jeu joueur groupe attaque vie mana repos",
}

Languages.ES = {
    name = "Español", layout = "QWERTY", locales = { "esES", "esMX" },
    rows = { Row("qwertyuiop[]\\"), Row("asdfghjklñ;'"), Row("zxcvbnm,./") },
    extra = Row("áéíóúü¿¡"),
    phone = { ["2"] = "abcá", ["3"] = "defé", ["4"] = "ghií", ["6"] = "mnoñó", ["8"] = "tuvúü" },
    seeds = "el la los las un una unos unas de del y es no yo tú él ella nosotros ellos ellas este esta esto estos mi mis "
        .. "tu tus su sus que quien qué dónde cuándo cómo por sí gracias favor hola adiós ayuda necesito busco grupo "
        .. "hermandad alguien con para en sobre sin pero o si como también muy más menos bien mal ya aún siempre nunca "
        .. "todo todos toda todas nada algo nadie aquí allí ahora mañana ayer hoy noche día soy eres es somos sois son "
        .. "estoy estás está estamos están tengo tienes tiene tenemos tienen quiero quieres quiere puedo puedes puede "
        .. "voy vas va vamos vais van hay fue ser estar hacer ir venir espera listo lista perdón disculpa vale ok "
        .. "tanque sanador daño mazmorra banda jefe misión nivel oro plata cobre bolsa banco correo subasta vendedor "
        .. "reparar vuelo portal invocar montura talento clase pícaro mago sacerdote paladín guerrero cazador chamán "
        .. "druida brujo humano enano gnomo elfo orco trol tauren muerto juego jugador",
}

Languages.IT = {
    name = "Italiano", layout = "QWERTY", locales = { "itIT" },
    rows = { Row("qwertyuiop[]\\"), Row("asdfghjkl;'"), Row("zxcvbnm,./") },
    extra = Row("àèéìòù"),
    phone = { ["2"] = "abcà", ["3"] = "defèé", ["4"] = "ghiì", ["6"] = "mnoò", ["8"] = "tuvù" },
    seeds = "il lo la i gli le un una di del e è non io tu lui lei noi voi loro questo questa che chi cosa dove quando "
        .. "come perché sì no grazie prego ciao arrivederci aiuto serve cerco gruppo gilda qualcuno con per in su senza "
        .. "ma o se anche molto più meno bene male già ancora sempre mai tutto tutti tutta tutte niente qualcosa nessuno "
        .. "qui là adesso ora domani ieri oggi sera notte giorno sono sei siamo siete ho hai ha abbiamo avete hanno "
        .. "voglio vuoi vuole posso puoi può vado vai va andiamo vanno fatto essere avere fare andare venire "
        .. "aspetta pronto pronta scusa scusate ok bene tank guaritore danni spedizione incursione boss missione "
        .. "livello oro argento rame borsa banca posta asta venditore riparare volo portale evocare cavalcatura talento "
        .. "classe ladro mago sacerdote paladino guerriero cacciatore sciamano druido stregone umano nano gnomo elfo orco "
        .. "troll tauren morto gioco giocatore",
}

Languages.PT = {
    name = "Português", layout = "QWERTY", locales = { "ptBR" },
    rows = { Row("qwertyuiop[]\\"), Row("asdfghjklç;'"), Row("zxcvbnm,./") },
    extra = Row("áàâãéêíóôõú"),
    phone = { ["2"] = "abcáàâãç", ["3"] = "deféê", ["4"] = "ghií", ["6"] = "mnoóôõ", ["8"] = "tuvú" },
    seeds = "o a os as um uma de do da e é não eu tu ele ela nós vocês eles elas este esta isto que quem onde quando como "
        .. "porquê sim obrigado obrigada favor olá adeus ajuda preciso procuro grupo guilda alguém com para em sobre sem "
        .. "mas ou se também muito mais menos bem mal já ainda sempre nunca tudo todos toda todas nada algo ninguém aqui "
        .. "ali agora amanhã ontem hoje noite dia sou és somos são estou está estamos estão tenho tem temos têm quero "
        .. "quer posso pode vou vai vamos vão foi ser estar fazer ir vir espera pronto pronta desculpa ok tanque "
        .. "curandeiro dano masmorra raide chefe missão nível ouro prata cobre bolsa banco correio leilão vendedor "
        .. "reparar voo portal invocar montaria talento classe ladino mago sacerdote paladino guerreiro caçador xamã "
        .. "druida bruxo humano anão gnomo elfo orc troll tauren morto jogo jogador você então até só",
}

-- Korean: the standard two-set layout (두벌식), where each key carries one jamo and Shift gives the doubled consonants and the
-- two vowels with a ㅣ. The jamo are put together into syllables as they are typed (Hangul.lua). `latin` is what the same keys
-- type with the 한/영 key switched to Latin letters (for commands such as /invite). The phone layouts have no Korean keypad,
-- so Korean has the full keyboard only (`fullOnly`).
Languages.KO = {
    name = "한국어 (Korean)", layout = "두벌식", hangul = true, fullOnly = true,
    rows = { Row("ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ[]\\"), Row("ㅁㄴㅇㄹㅎㅗㅓㅏㅣ;'"), Row("ㅋㅌㅊㅍㅠㅜㅡ,./") },
    phone = {},
    shift = { ["ㅂ"] = "ㅃ", ["ㅈ"] = "ㅉ", ["ㄷ"] = "ㄸ", ["ㄱ"] = "ㄲ", ["ㅅ"] = "ㅆ", ["ㅐ"] = "ㅒ", ["ㅔ"] = "ㅖ" },
    latin = { ["ㅂ"] = "q", ["ㅈ"] = "w", ["ㄷ"] = "e", ["ㄱ"] = "r", ["ㅅ"] = "t", ["ㅛ"] = "y", ["ㅕ"] = "u", ["ㅑ"] = "i",
        ["ㅐ"] = "o", ["ㅔ"] = "p", ["ㅁ"] = "a", ["ㄴ"] = "s", ["ㅇ"] = "d", ["ㄹ"] = "f", ["ㅎ"] = "g", ["ㅗ"] = "h",
        ["ㅓ"] = "j", ["ㅏ"] = "k", ["ㅣ"] = "l", ["ㅋ"] = "z", ["ㅌ"] = "x", ["ㅊ"] = "c", ["ㅍ"] = "v", ["ㅠ"] = "b",
        ["ㅜ"] = "n", ["ㅡ"] = "m" },
    seeds = "안녕 안녕하세요 안녕히 감사합니다 고맙습니다 고마워요 고마워 감사 네 예 응 아니요 아니 좋아요 좋아 괜찮아요 괜찮아 "
        .. "미안해요 미안합니다 죄송합니다 죄송해요 잠시만요 잠깐만 기다려요 기다려 준비 준비됐어요 준비됐나요 가요 갑시다 "
        .. "가자 파티 길드 던전 레이드 퀘스트 같이 함께 도와주세요 도움 구해요 구합니다 찾아요 찾습니다 초대 초대해주세요 "
        .. "가입 힐러 탱커 딜러 사냥 보스 레벨 골드 은화 동화 가방 은행 우편 경매 상인 수리 비행 포탈 소환 탈것 특성 직업 "
        .. "도적 마법사 사제 성기사 전사 사냥꾼 주술사 드루이드 흑마법사 인간 드워프 노움 나이트엘프 오크 트롤 타우렌 언데드 "
        .. "오늘 내일 어제 지금 나중에 빨리 천천히 여기 거기 저기 우리 너 나 저 그 이 것 뭐 누구 어디 언제 어떻게 왜 "
        .. "있어요 없어요 해요 하세요 합니다 입니다 이에요 예요 맞아요 알겠어요 알겠습니다 모르겠어요 수고하셨습니다 "
        .. "수고했어요 고생했어요 축하해요 축하합니다 대박 ㅋㅋ ㅋㅋㅋ ㅎㅎ ㅠㅠ 화이팅 파이팅 잘했어요 잘가요 또 봐요 다음에 "
        .. "먼저 갈게요 잠수 자리비움 곧 돌아올게요 최고 정말 진짜 너무 많이 조금 아주 그리고 그런데 하지만 그래서 근데 이거 "
        .. "그거 저거 사요 팔아요 얼마예요 가격 템 아이템 장비 무기 방어구 물약 음식 물 마나 체력 쉬어요 버프 풀링 어그로 "
        .. "죽었어요 부활 사망 시작 끝 가능 불가능 필요 원해요 팔아 모집 파티원 공격대 공대 점수 막타 주사위 "
        .. "입찰 돌아가요 출발 도착 잠수중 접속 종료 렉 버그 점검 서버 대기열",
}

-- A language code the keyboard knows, else English.
function Languages.Valid(code)
    for _, known in ipairs(Languages.order) do
        if known == code then return code end
    end
    return "EN"
end

-- The letters a language can type, apart from ASCII: those under its phone keys and in its rows.
for _, code in ipairs(Languages.order) do
    local language = Languages[code]
    language.letters = {}
    local function Take(letters)
        for _, letter in ipairs(letters) do
            if #letter > 1 and letter:byte(1) >= 195 then language.letters[letter] = true end
        end
    end
    for _, letters in pairs(language.phone) do Take(Languages.Characters(letters)) end
    for _, row in ipairs(language.rows) do Take(row) end
    if language.extra then Take(language.extra) end
    -- A shifted letter belongs to the language as well.
    for letter in pairs(language.letters) do
        if UPPER[letter] then language.letters[UPPER[letter]] = true end
    end
end

-- True when a (lowercase) word only uses letters this language types: a word with an accent the language has no key for
-- belongs to another language, and is left out of its suggestions.
function Languages.Fits(code, word)
    if Languages[code].hangul then return Addon.Hangul.Fits(word) end
    if not word:find("[\128-\255]") then return true end
    local letters = Languages[code].letters
    for character in word:gmatch("[\194-\244][\128-\191]*") do
        if not letters[character] then return false end
    end
    return true
end

-- The characters a phone key cycles through for a language: its letters, then the digit.
function Languages.PhoneKey(code, digit)
    local letters = Languages[code].phone[digit] or KEYS[digit]
    local chars = Languages.Characters(letters)
    chars[#chars + 1] = digit
    return chars
end
