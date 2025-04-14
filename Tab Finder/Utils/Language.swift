import InputMethodKit

func getInputSourcesWithIDs() -> [(TISInputSource, String, Int)] {
    let selectableIsProperties = [
        kTISPropertyInputSourceType: kTISTypeKeyboardLayout as CFString,
    ] as CFDictionary
    
    let inputSourceArray = TISCreateInputSourceList(selectableIsProperties, false).takeRetainedValue() as! [TISInputSource]
    
    return inputSourceArray.map { source in
        let nameProperty = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
        let name = nameProperty != nil ? Unmanaged<CFString>.fromOpaque(nameProperty!).takeUnretainedValue() as String : "Unknown"
        
        let description = String(describing: source)
        var layoutID = -9999
        
        if let idRange = description.range(of: "id=") {
            let afterIDRange = description[idRange.upperBound...]
            if let endParenRange = afterIDRange.range(of: ")") {
                let idString = description[idRange.upperBound..<endParenRange.lowerBound]
                if let extractedID = Int(idString) {
                    layoutID = extractedID
                }
            }
        }
        
        return (source, name, layoutID)
    }
}

func getInputSourcesSortedByHistory() -> [TISInputSource] {
    guard let userDefaults = UserDefaults(suiteName: "com.apple.HIToolbox"),
          let inputSourceHistory = userDefaults.array(forKey: "AppleInputSourceHistory") as? [[String: Any]] else {
        return []
    }
    
    let inputSourceArray = getInputSourcesWithIDs()
    
    var inputSourcesSortedByHistory: [TISInputSource] = []
    
    for item in inputSourceHistory {
        guard let layoutID = item["KeyboardLayout ID"] else { return []}

        for inputSource in inputSourceArray {
            if inputSource.2 == layoutID as! Int {
                inputSourcesSortedByHistory.append(inputSource.0)
            }
        }
    }

    return inputSourcesSortedByHistory
}

func changeInputSource(inputSource: TISInputSource) {
    TISSelectInputSource(inputSource)
}

func selectPreviousInputSource() {
    let inputSources = getInputSourcesSortedByHistory()
    guard inputSources.count > 1 else { return }
    let prevInputSource = inputSources[1]
    changeInputSource(inputSource: prevInputSource)
    appState.currentInputSourceName = getCurrentInputSourceName()
}

func getCurrentInputSourceName() -> String {
    let currentInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    let nameProperty = TISGetInputSourceProperty(currentInputSource, kTISPropertyLocalizedName)
    let name = nameProperty != nil ? Unmanaged<CFString>.fromOpaque(nameProperty!).takeUnretainedValue() as String : "Unknown"
    return name
}

func getSearchFieldPlaceholderText(by inputSourceName: String, tabsCount: Int) -> String {
    let searchFieldPlaceholderTranslations: [String: String] = [
        "Russian – PC": "Поиск вкладок Всего открыто: \(tabsCount)",
        "Ukrainian": "Пошук вкладок. Усього відкрито: \(tabsCount)",
        "ABC – AZERTY": "Tab search. Total open: \(tabsCount)",
        "ABC – QWERTZ": "Tab search. Total open: \(tabsCount)",
        "U.S.": "Tab search. Total open: \(tabsCount)",
        "ABC": "Tab search. Total open: \(tabsCount)",
        "Czech – QWERTY": "Vyhledávání karet. Celkem otevřeno: \(tabsCount)",
        "Czech": "Vyhledávání karet. Celkem otevřeno: \(tabsCount)",
        "Estonian": "Kaardiotsing. Kokku avatud: \(tabsCount)",
        "Hungarian – QWERTY": "Lapkeresés. Összesen nyitva: \(tabsCount)",
        "Hungarian": "Lapkeresés. Összesen nyitva: \(tabsCount)",
        "Latvian": "Cilnes meklēšana. Kopā atvērts: \(tabsCount)",
        "Lithuanian": "Kortelių paieška. Iš viso atidaryta: \(tabsCount)",
        "Polish": "Wyszukiwanie kart. Łącznie otwartych: \(tabsCount)",
        "Polish – QWERTZ": "Wyszukiwanie kart. Łącznie otwartych: \(tabsCount)",
        "Slovak": "Vyhľadávanie kariet. Celkovo otvorené: \(tabsCount)",
        "Slovak – QWERTY": "Vyhľadávanie kariet. Celkovo otvorené: \(tabsCount)",
        "Bulgarian – QWERTY": "Търсене на раздели. Общо отворени: \(tabsCount)",
        "Bulgarian – Standard": "Търсене на раздели. Общо отворени: \(tabsCount)",
        "Belarusian": "Пошук укладак. Усяго адкрыта: \(tabsCount)",
        "Macedonian": "Пребарување јазичиња. Вкупно отворени: \(tabsCount)",
        "Russian – QWERTY": "Поиск вкладок. Всего открыто: \(tabsCount)",
        "Russian": "Поиск вкладок. Всего открыто: \(tabsCount)",
        "Serbian": "Претрага картица. Укупно отворено: \(tabsCount)",
        "Ukrainian – Legacy": "Пошук вкладок. Усього відкрито: \(tabsCount)",
        "Colemak": "Tab search. Total open: \(tabsCount)",
        "Dvorak – Left-Handed": "Tab search. Total open: \(tabsCount)",
        "Dvorak – Right-Handed": "Tab search. Total open: \(tabsCount)",
        "Dvorak": "Tab search. Total open: \(tabsCount)",
        "Dvorak – QWERTY ⌘": "Tab search. Total open: \(tabsCount)",
        "Kana": "タブ検索。合計開いている: \(tabsCount)",
        "Australian": "Tab search. Total open: \(tabsCount)",
        "Austrian": "Tab-Suche. Insgesamt geöffnet: \(tabsCount)",
        "Belgian": "Recherche d’onglets. Total ouvert: \(tabsCount)",
        "Brazilian – ABNT2": "Pesquisa de abas. Total aberto: \(tabsCount)",
        "Brazilian": "Pesquisa de abas. Total aberto: \(tabsCount)",
        "Brazilian – Legacy": "Pesquisa de abas. Total aberto: \(tabsCount)",
        "British – PC": "Tab search. Total open: \(tabsCount)",
        "British": "Tab search. Total open: \(tabsCount)",
        "Canadian – CSA": "Recherche d’onglets. Total ouvert: \(tabsCount)",
        "Canadian": "Recherche d’onglets. Total ouvert: \(tabsCount)",
        "Canadian – PC": "Recherche d’onglets. Total ouvert: \(tabsCount)",
        "Danish": "Fanebladssøgning. Samlet åbnet: \(tabsCount)",
        "Dutch": "Tabblad zoeken. Totaal geopend: \(tabsCount)",
        "Finnish": "Välilehtihaku. Avoinna yhteensä: \(tabsCount)",
        "French – PC": "Recherche d’onglets. Total ouvert: \(tabsCount)",
        "French – Numerical": "Recherche d’onglets. Total ouvert: \(tabsCount)",
        "French": "Recherche d’onglets. Total ouvert: \(tabsCount)",
        "German": "Tab-Suche. Insgesamt geöffnet: \(tabsCount)",
        "Irish": "Cuardach cluaisíní. Iomlán oscailte: \(tabsCount)",
        "Italian": "Ricerca schede. Totale aperto: \(tabsCount)",
        "Italian – QZERTY": "Ricerca schede. Totale aperto: \(tabsCount)",
        "Norwegian": "Fanebladssøk. Totalt åpnet: \(tabsCount)",
        "Portuguese": "Pesquisa de abas. Total aberto: \(tabsCount)",
        "Spanish": "Búsqueda de pestañas. Total abierto: \(tabsCount)",
        "Spanish – Legacy": "Búsqueda de pestañas. Total abierto: \(tabsCount)",
        "Swedish": "Fliksökning. Totalt öppet: \(tabsCount)",
        "Swedish – Legacy": "Fliksökning. Totalt öppet: \(tabsCount)",
        "Swiss French": "Recherche d’onglets. Total ouvert: \(tabsCount)",
        "Swiss German": "Tab-Suche. Insgesamt geöffnet: \(tabsCount)",
        "Tongan": "Tab search. Total open: \(tabsCount)",
        "U.S. International – PC": "Tab search. Total open: \(tabsCount)",
        "2-Set Korean": "탭 검색. 총 개수: \(tabsCount)",
        "ABC – India": "Tab search. Total open: \(tabsCount)",
        "Adlam": "𞤀𞤅𞥅𞤀𞥄 𞤃𞤵𞥅𞤯𞤢𞥄𞤤. 𞤄𞤢𞤪𞤢𞥄𞤲 𞤸𞤢𞤤𞤭: \(tabsCount)",
        "Afghan Dari": "جستجوی برگه‌ها. تعداد کل باز: \(tabsCount)",
        "Afghan Pashto": "د ټبونو لټون. ټول پرانیستل شوي: \(tabsCount)",
        "Afghan Uzbek": "Varaqlash qidiruvi. Jami ochiq: \(tabsCount)",
        "Akan": "Hwehwɛ tab. Nyinara abue: \(tabsCount)",
        "Albanian": "Kërkimi i skedave. Total i hapur: \(tabsCount)",
        "Anjal": "Tab search. Total open: \(tabsCount)",
        "Apache": "Tab search. Total open: \(tabsCount)",
        "Arabic – AZERTY": "بحث عن علامات التبويب. إجمالي المفتوحة: \(tabsCount)",
        "Arabic – 123": "بحث عن علامات التبويب. إجمالي المفتوحة: \(tabsCount)",
        "Arabic – QWERTY": "بحث عن علامات التبويب. إجمالي المفتوحة: \(tabsCount)",
        "Arabic": "بحث عن علامات التبويب. إجمالي المفتوحة: \(tabsCount)",
        "Arabic – PC": "بحث عن علامات التبويب. إجمالي المفتوحة: \(tabsCount)",
        "Armenian – HM QWERTY": "Քարտեզների որոնում. Ընդհանուր բաց է: \(tabsCount)",
        "Armenian – Western QWERTY": "Քարտեզների որոնում. Ընդհանուր բաց է: \(tabsCount)",
        "Assamese – InScript": "ট্যাব সন্ধান। মুঠ খোলা: \(tabsCount)",
        "Azeri": "Vərəq axtarışı. Ümumi açıq: \(tabsCount)",
        "Bangla – QWERTY": "ট্যাব অনুসন্ধান। মোট খোলা: \(tabsCount)",
        "Bangla – InScript": "ট্যাব অনুসন্ধান। মোট খোলা: \(tabsCount)",
        "Bodo – InScript": "ट्याब खोज। कुल खुला: \(tabsCount)",
        "Cangjie": "標籤搜尋。總共打開：\(tabsCount)",
        "Cherokee – Nation": "ᎦᏗᏗᏍᏗ ᎧᏁᎢᎢ. ᏗᎦᏁᎢᎢ ᎢᏳᏍᏗ: \(tabsCount)",
        "Cherokee – QWERTY": "ᎦᏗᏗᏍᏗ ᎧᏁᎢᎢ. ᏗᎦᏁᎢᎢ ᎢᏳᏍᏗ: \(tabsCount)",
        "Chickasaw": "Tab search. Total open: \(tabsCount)",
        "Choctaw": "Tab search. Total open: \(tabsCount)",
        "Chuvash": "Валлашӑ шкулӑ. Хула ачасем: \(tabsCount)",
        "Croatian – QWERTY": "Pretraga kartica. Ukupno otvoreno: \(tabsCount)",
        "Croatian – QWERTZ": "Pretraga kartica. Ukupno otvoreno: \(tabsCount)",
        "Devanagari – QWERTY": "टैब खोज। कुल खुला: \(tabsCount)",
        "Hindi – InScript": "टैब खोज। कुल खुला: \(tabsCount)",
        "Dhivehi": "ޓެބް ހޯދާ. މައްޗަށް ހައްގަތަކު: \(tabsCount)",
        "Dogri – InScript": "टैब खोज। कुल खुला: \(tabsCount)",
        "Dzongkha": "ཐེབས་འཚོལ། ཡང་སྤུན་ཁང་།: \(tabsCount)",
        "Faroese": "Flipa leiting. Tilsamans opið: \(tabsCount)",
        "Finnish – Extended": "Välilehtihaku. Yhteensä avoinna: \(tabsCount)",
        "Finnish Sámi – PC": "Lásságahpirgávppaš. Ovdas uvdnugohtta: \(tabsCount)",
        "Geʽez": "የትዕዛዝ ፍለጋ። ጠቅላላ በክፍት ውስጥ፡ \(tabsCount)",
        "Georgian – QWERTY": "ჩანართების ძებნა. სულ გახსნილი: \(tabsCount)",
        "German – Standard": "Tab-Suche. Insgesamt geöffnet: \(tabsCount)",
        "Greek": "Αναζήτηση καρτελών. Σύνολο ανοιχτό: \(tabsCount)",
        "Greek – Polytonic": "Αναζήτηση καρτελών. Σύνολο ανοιχτό: \(tabsCount)",
        "Gujarati – QWERTY": "ટેબ શોધ. કુલ ખુલ્લું: \(tabsCount)",
        "Gujarati – InScript": "ટેબ શોધ. કુલ ખુલ્લું: \(tabsCount)",
        "Gurmukhi – QWERTY": "ਟੈਬ ਖੋਜ. ਕੁੱਲ ਖੁੱਲੇ: \(tabsCount)",
        "Gurmukhi – InScript": "ਟੈਬ ਖੋਜ. ਕੁੱਲ ਖੁੱਲੇ: \(tabsCount)",
        "Hanifi Rohingya": "𐴕𐵰𐵋𐵒𐵁𐵒 𐵃𐵉𐵙𐵁𐵓𐵖. 𐵁𐵏𐵋𐵁𐵖𐵏 𐵉𐵋𐵂: \(tabsCount)",
        "Hausa": "Binciken shafin. Jimlar buɗewa: \(tabsCount)",
        "Hawaiian": "Huli ʻaoʻao. Huina wehe: \(tabsCount)",
        "Hebrew – QWERTY": "חיפוש כרטיסיות. סך הכל פתוחות: \(tabsCount)",
        "Hebrew": "חיפוש כרטיסיות. סך הכל פתוחות: \(tabsCount)",
        "Hebrew – PC": "חיפוש כרטיסיות. סך הכל פתוחות: \(tabsCount)",
        "Icelandic": "Flipa leit. Alls opið: \(tabsCount)",
        "Igbo": "Chọta taabụ. Ngụkọta meghee: \(tabsCount)",
        "Ingush": "Таба хилар. Дошламаш хилар: \(tabsCount)",
        "Inuktitut – Nattilik": "ᑕᑖᖅᑕᐅᓯᖅ ᖃᓄᖅ. ᓄᑖᖅ ᓄᓇᕗᑦ: \(tabsCount)",
        "Inuktitut – Nunavut": "ᑕᑖᖅᑕᐅᓯᖅ ᖃᓄᖅ. ᓄᑖᖅ ᓄᓇᕗᑦ: \(tabsCount)",
        "Inuktitut – Nutaaq": "ᑕᑖᖅᑕᐅᓯᖅ ᖃᓄᖅ. ᓄᑖᖅ ᓄᓇᕗᑦ: \(tabsCount)",
        "Inuktitut – QWERTY": "ᑕᑖᖅᑕᐅᓯᖅ ᖃᓄᖅ. ᓄᑖᖅ ᓄᓇᕗᑦ: \(tabsCount)",
        "Inuktitut – Nunavik": "ᑕᑖᖅᑕᐅᓯᖅ ᖃᓄᖅ. ᓄᑖᖅ ᓄᓇᕗᑦ: \(tabsCount)",
        "Irish – Extended": "Cuardach cluaisíní. Iomlán oscailte: \(tabsCount)",
        "Jawi": "Carian tab. Jumlah dibuka: \(tabsCount)",
        "Kabyle – AZERTY": "Anadi n yiccer. Meṛṛa yettweldi: \(tabsCount)",
        "Kabyle – QWERTY": "Anadi n yiccer. Meṛṛa yettweldi: \(tabsCount)",
        "Kannada – QWERTY": "ಟ್ಯಾಬ್ ಹುಡುಕು. ಒಟ್ಟು ತೆರೆದಿವೆ: \(tabsCount)",
        "Kannada – InScript": "ಟ್ಯಾಬ್ ಹುಡುಕು. ಒಟ್ಟು ತೆರೆದಿವೆ: \(tabsCount)",
        "Kashmiri (Devanagari) – InScript": "टैब खोज. कुल खुले: \(tabsCount)",
        "Kazakh": "Қойындыларды іздеу. Барлығы ашық: \(tabsCount)",
        "Khmer": "ស្វែងរកផ្ទាំង. សរុបបើក: \(tabsCount)",
        "Konkani – InScript": "टॅब शोधा. एकूण उघडे: \(tabsCount)",
        "Kurmanji Kurdish": "Lêgerîna taban. Giştî vekirî: \(tabsCount)",
        "Sorani Kurdish": "گەڕانی تابیەکان. کۆی گشتی کراوە: \(tabsCount)",
        "Kyrgyz": "Табды издөө. Жалпы ачылган: \(tabsCount)",
        "Lao": "ຄົ້ນຫາແທບ. ລວມເປີດ: \(tabsCount)",
        "Latin American": "Búsqueda de pestañas. Total abierto: \(tabsCount)",
        "Lushootseed": "Tab qʷiqʷid. ƛ̕ubʔučəd: \(tabsCount)",
        "Maithili – InScript": "टैब खोज. कुल खुले: \(tabsCount)",
        "Malayalam – QWERTY": "ടാബ് തിരയൽ. മൊത്തം തുറന്നത്: \(tabsCount)",
        "Malayalam – InScript": "ടാബ് തിരയൽ. മൊത്തം തുറന്നത്: \(tabsCount)",
        "Maltese": "Fittex tabs. Totali miftuħ: \(tabsCount)",
        "Mandaic – Arabic": "بحث عن التبويبات. إجمالي مفتوح: \(tabsCount)",
        "Mandaic – QWERTY": "بحث عن التبويبات. إجمالي مفتوح: \(tabsCount)",
        "Manipuri (Bengali) – InScript": "ট্যাব সন্ধান. মোট খোলা: \(tabsCount)",
        "Manipuri (Meetei Mayek)": "ꯇꯦꯕ ꯁꯤꯡꯂꯤꯡ. ꯃꯊꯥꯡ ꯀꯣꯅꯕ: \(tabsCount)",
        "Māori": "Rapu ripa. Katoa tuwhera: \(tabsCount)",
        "Marathi – InScript": "टॅब शोधा. एकूण उघडे: \(tabsCount)",
        "Mi’kmaq": "Tabl aqqamij. Kepmite'taq: \(tabsCount)",
        "Mongolian": "Хавтас хайх. Нийт нээлттэй: \(tabsCount)",
        "Mvskoke": "Tvlvtv esketv. Nak okvhv: \(tabsCount)",
        "Myanmar – QWERTY": "တပ်ရှာဖွေမှု။ စုစုပေါင်းဖွင့်ထားသည်: \(tabsCount)",
        "Myanmar": "တပ်ရှာဖွေမှု။ စုစုပေါင်းဖွင့်ထားသည်: \(tabsCount)",
        "N’Ko – QWERTY": "ߕߍߓߊ߲ ߞߎߘߊ߫. ߝߟߍ߲ ߞߎߘߊ: \(tabsCount)",
        "N’Ko": "ߕߍߓߊ߲ ߞߎߘߊ߫. ߝߟߍ߲ ߞߎߘߊ: \(tabsCount)",
        "Navajo": "Tába naaltsoos. Át’éego náhást’éíts’áadah: \(tabsCount)",
        "Nepali – InScript": "ट्याब खोज. कुल खुले: \(tabsCount)",
        "Nepali – Remington": "ट्याब खोज. कुल खुले: \(tabsCount)",
        "Norwegian – Extended": "Faneblad søk. Totalt åpent: \(tabsCount)",
        "Norwegian Sámi – PC": "Faneblad søk. Totalt åpent: \(tabsCount)",
        "Odia – QWERTY": "ଟ୍ୟାବ୍ ଖୋଜ। ମୋଟ ଖୋଲା: \(tabsCount)",
        "Odia – InScript": "ଟ୍ୟାବ୍ ଖୋଜ। ମୋଟ ଖୋଲା: \(tabsCount)",
        "Osage – QWERTY": "Tab šgówe. Shka: \(tabsCount)",
        "Hmong (Pahawh)": "Nrhiav tab. Tag nrho qhib: \(tabsCount)",
        "Persian – QWERTY": "جستجوی تب‌ها. مجموع باز: \(tabsCount)",
        "Persian – Legacy": "جستجوی تب‌ها. مجموع باز: \(tabsCount)",
        "Persian – Standard": "جستجوی تب‌ها. مجموع باز: \(tabsCount)",
        "Rejang – QWERTY": "Tab peṭi. Jumlā kebuka: \(tabsCount)",
        "Romanian – Standard": "Căutare file. Total deschise: \(tabsCount)",
        "Romanian": "Căutare file. Total deschise: \(tabsCount)",
        "Sámi – PC": "Fánagis girjjálašvuohta. Oktiivlu rabas: \(tabsCount)",
        "Inari Sámi": "Távvalávvut uáihtim. Koččun rabas: \(tabsCount)",
        "Lule Sámi (Norway)": "Táhpádus hállam. Álgos rabas: \(tabsCount)",
        "Lule Sámi (Sweden)": "Táhpádus hállam. Álgos rabas: \(tabsCount)",
        "Kildin Sámi": "Таба пӱцт. Кылла тӱнӱ: \(tabsCount)",
        "North Sámi": "Fánagis gáldu. Oktiivlu rabas: \(tabsCount)",
        "Pite Sámi": "Táhpádus hál’lám. Oktiivlu rabas: \(tabsCount)",
        "Skolt Sámi": "Tääbba peʹrttem. Kävkkum rabas: \(tabsCount)",
        "South Sámi": "Faanahkh sijjehtæm. Ådtjese rabas: \(tabsCount)",
        "Ume Sámi": "Táhpádus hál’lám. Oktiivlu rabas: \(tabsCount)",
        "Samoan": "Saili tab. Aofai tatala: \(tabsCount)",
        "Sanskrit – InScript": "टैब खोज. कुल खुले: \(tabsCount)",
        "Santali (Devanagari) – InScript": "टैब खोज. कुल खुले: \(tabsCount)",
        "Santali (Ol Chiki)": "ᱴᱟᱵᱽ ᱠᱷᱚᱡᱽ. ᱛᱮᱦᱟᱹᱞ ᱠᱚ ᱵᱷᱟᱨᱟᱹ: \(tabsCount)",
        "Serbian (Latin)": "Pretraga tabova. Ukupno otvoreno: \(tabsCount)",
        "Sindhi (Devanagari) – InScript": "टैब ڳولا. ڪل کليل: \(tabsCount)",
        "Sindhi": "ٽيب ڳولهڻ. ڪل کليل: \(tabsCount)",
        "Sinhala – QWERTY": "ටැබ් සෙවීම. මුලු ආවරණය: \(tabsCount)",
        "Sinhala": "ටැබ් සෙවීම. මුලු ආවරණය: \(tabsCount)",
        "Slovenian": "Iskanje zavihkov. Skupaj odprtih: \(tabsCount)",
        "Swedish Sámi – PC": "Fánagis gáldu. Oktiivlu rabas: \(tabsCount)",
        "Syriac – Arabic": "ܒܨܝܐ ܕܛܒܐ. ܓܡܝܪ ܦܬܝܚ: \(tabsCount)",
        "Syriac – QWERTY": "ܒܨܝܐ ܕܛܒܐ. ܓܡܝܪ ܦܬܝܚ: \(tabsCount)",
        "Tajik (Cyrillic)": "Ҷустуҷӯи варақҳо. Ҳамагӣ кушода: \(tabsCount)",
        "Tamil99": "தாவலை தேடு. மொத்தம் திறந்தது: \(tabsCount)",
        "Telugu – QWERTY": "టాబ్ శోధన. మొత్తం తెరిచినవి: \(tabsCount)",
        "Telugu – InScript": "టాబ్ శోధన. మొత్తం తెరిచినవి: \(tabsCount)",
        "Thai – Pattachote": "ค้นหาแท็บ. รวมเปิด: \(tabsCount)",
        "Thai": "ค้นหาแท็บ. รวมเปิด: \(tabsCount)",
        "Tibetan – Otani": "ཏབ་འཚོལ་ཞིབ། སྣང་བརྙན་ཡོངས་སུ་ཕྱིར་འབུད: \(tabsCount)",
        "Tibetan – QWERTY": "ཏབ་འཚོལ་ཞིབ། སྣང་བརྙན་ཡོངས་སུ་ཕྱིར་འབུད: \(tabsCount)",
        "Tibetan – Wylie": "Tab tshol zhib. Snang brnyan yongs su phyir ‘bud: \(tabsCount)",
        "Tifinagh": "ⵜⴰⴳⴷⴰⵙ ⵏ ⵜⴰⴱⴰⵍⴰⵏⵜ. ⵓⵙⵙⴰⴹ ⵜⴰⴷⵉⵎⵣⵉⵔⵉ: \(tabsCount)",
        "Bangla – Transliteration": "ট্যাব অনুসন্ধান। মোট খোলা: \(tabsCount)",
        "Gujarati – Transliteration": "ટૅબ શોધ. કુલ ખૂલે: \(tabsCount)",
        "Hindi – Transliteration": "टैब खोज. कुल खुले: \(tabsCount)",
        "Kannada – Transliteration": "ಟ್ಯಾಬ್ ಹುಡುಕು. ಒಟ್ಟು ತೆರೆದಿವೆ: \(tabsCount)",
        "Malayalam – Transliteration": "ടാബ് തിരയൽ. മൊത്തം തുറന്നത്: \(tabsCount)",
        "Marathi – Transliteration": "टॅब शोधा. एकूण उघडे: \(tabsCount)",
        "Punjabi – Transliteration": "ਟੈਬ ਖੋਜ. ਕੁੱਲ ਖੁੱਲੇ: \(tabsCount)",
        "Tamil – Transliteration": "தாவலை தேடு. மொத்தம் திறந்தது: \(tabsCount)",
        "Telugu – Transliteration": "టాబ్ శోధన. మొత్తం తెరిచినవి: \(tabsCount)",
        "Urdu – Transliteration": "ٹیب تلاش. کل کھلا: \(tabsCount)",
        "Turkish Q": "Sekme arama. Toplam açık: \(tabsCount)",
        "Turkish Q – Legacy": "Sekme arama. Toplam açık: \(tabsCount)",
        "Turkish F": "Sekme arama. Toplam açık: \(tabsCount)",
        "Turkish F – Legacy": "Sekme arama. Toplam açık: \(tabsCount)",
        "Turkmen": "Tab gözle. Jemi açyk: \(tabsCount)",
        "ABC – Extended": "Tab search. Total open: \(tabsCount)",
        "Ukrainian – QWERTY": "Пошук вкладок. Всього відкрито: \(tabsCount)",
        "Unicode Hex Input": "Tab search. Total open: \(tabsCount)",
        "Urdu": "ٹیب تلاش. کل کھلا: \(tabsCount)",
        "Uyghur": "بەتكۈچ ئىزدەش. جەمئىي ئاچقىن: \(tabsCount)",
        "Uzbek (Cyrillic)": "Varaqlarni qidirish. Jami ochiq: \(tabsCount)",
        "Vietnamese": "Tìm kiếm tab. Tổng số mở: \(tabsCount)",
        "Wancho – QWERTY": "ⴓⴔⴆ ⴄⴞⴎⴌⴈ. ⴄⴡⴉⴘⴎⴌ ⴉⴕⴎⴌⴎ: \(tabsCount)",
        "Welsh": "Chwilio tabiau. Cyfanswm yn agored: \(tabsCount)",
        "Wolastoqey": "Tabic tanipsiq. Walon kisuk: \(tabsCount)",
        "Yiddish – QWERTY": "טאַב זוכן. גאַנץ אָפֿן: \(tabsCount)",
        "Yoruba": "Ṣàwárí ọ̀nà. Apapọ ṣí: \(tabsCount)",
        "Zhuyin": "注音搜尋。總計開啟: \(tabsCount)",
        "GongjinCheong Romaja": "탭 검색. 총 열린: \(tabsCount)",
        "3-Set Korean (390)": "탭 검색. 총 열린: \(tabsCount)",
        "HNC Romaja": "탭 검색. 총 열린: \(tabsCount)",
        "3-Set Korean": "탭 검색. 총 열린: \(tabsCount)",
        "Pinyin - Simplified": "拼音搜索。总计开启: \(tabsCount)",
        "Stroke - Simplified": "笔画搜索。总计开启: \(tabsCount)",
        "Stroke - Cantonese": "筆劃搜尋。總計開啟: \(tabsCount)",
        "Stroke - Traditional": "筆劃搜尋。總計開啟: \(tabsCount)",
        "Zhuyin Eten - Traditional": "注音倚天搜尋。總計開啟: \(tabsCount)",
        "Pinyin - Traditional": "拼音搜尋。總計開啟: \(tabsCount)",
        "WubihuaKeyboard": "五筆劃搜索。總計開啟: \(tabsCount)"
    ]
    return searchFieldPlaceholderTranslations[inputSourceName] ?? "Search tabs. Total open: \(tabsCount)"
}
