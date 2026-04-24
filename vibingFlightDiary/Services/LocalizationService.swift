import Foundation
import Observation
import SwiftUI

// MARK: - Distance Unit

enum DistanceUnit: String, CaseIterable, Identifiable {
    case km    = "km"
    case miles = "miles"
    var id: String { rawValue }
}

// MARK: - Currency

enum AppCurrency: String, CaseIterable, Identifiable {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case pln = "PLN"
    case chf = "CHF"
    case jpy = "JPY"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .eur: "€"
        case .usd: "$"
        case .gbp: "£"
        case .pln: "zł"
        case .chf: "CHF"
        case .jpy: "¥"
        }
    }

    var displayName: String {
        switch self {
        case .eur: "Euro (€)"
        case .usd: "US Dollar ($)"
        case .gbp: "British Pound (£)"
        case .pln: "Polish Złoty (zł)"
        case .chf: "Swiss Franc (CHF)"
        case .jpy: "Japanese Yen (¥)"
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case dark   = "dark"
    case light  = "light"
    case system = "system"
    var id: String { rawValue }
}

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case english  = "en"
    case polish   = "pl"
    case spanish  = "es"
    case french   = "fr"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:  "English"
        case .polish:   "Polski"
        case .spanish:  "Español"
        case .french:   "Français"
        case .japanese: "日本語"
        }
    }

    var flag: String {
        switch self {
        case .english:  "🇬🇧"
        case .polish:   "🇵🇱"
        case .spanish:  "🇪🇸"
        case .french:   "🇫🇷"
        case .japanese: "🇯🇵"
        }
    }
}

// MARK: - Localization Service

@Observable class LocalizationService {
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
            applyWindowStyle()
        }
    }

    var distanceUnit: DistanceUnit {
        didSet { UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit") }
    }

    var currency: AppCurrency {
        didSet { UserDefaults.standard.set(currency.rawValue, forKey: "appCurrency") }
    }

    /// Format a km value for display using the user's chosen unit.
    func formatDistance(_ km: Double) -> String {
        switch distanceUnit {
        case .km:    return "\(Int(km).formatted()) km"
        case .miles: return "\(Int(km * 0.621371).formatted()) mi"
        }
    }

    /// Format a price for display using the user's chosen currency.
    func formatPrice(_ value: Double) -> String {
        "\(currency.symbol)\(String(format: "%.2f", value))"
    }

    /// Compact format (e.g. "59k") without unit label — use distanceFlownLabel separately.
    func formatDistanceShort(_ km: Double) -> String {
        let value = distanceUnit == .miles ? km * 0.621371 : km
        let i = Int(value)
        return i >= 1000 ? "\(i / 1000)k" : "\(i)"
    }

    func applyWindowStyle() {
        let style: UIUserInterfaceStyle = switch theme {
        case .dark:   .dark
        case .light:  .light
        case .system: .unspecified
        }
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { $0.overrideUserInterfaceStyle = style }
        }
    }

    /// Returns the SwiftUI ColorScheme to apply, or nil to follow system.
    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return nil
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        self.language = AppLanguage(rawValue: saved) ?? .english
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? "dark"
        self.theme = AppTheme(rawValue: savedTheme) ?? .dark
        let savedUnit = UserDefaults.standard.string(forKey: "distanceUnit") ?? "km"
        self.distanceUnit = DistanceUnit(rawValue: savedUnit) ?? .km
        let savedCurrency = UserDefaults.standard.string(forKey: "appCurrency") ?? "EUR"
        self.currency = AppCurrency(rawValue: savedCurrency) ?? .eur
    }

    // Shorthand helper
    private func t(_ en: String, _ pl: String, _ es: String, _ fr: String, _ ja: String) -> String {
        switch language {
        case .english:  en
        case .polish:   pl
        case .spanish:  es
        case .french:   fr
        case .japanese: ja
        }
    }

    // MARK: - Tab Bar
    var tabDiary:   String { t("Diary",   "Dziennik",    "Diario",     "Journal",      "日記") }
    var tabMap:     String { t("Map",     "Mapa",        "Mapa",       "Carte",        "地図") }
    var tabAdd:     String { t("Add",     "Dodaj",       "Añadir",     "Ajouter",      "追加") }
    var tabFlights: String { t("Flights", "Loty",        "Vuelos",     "Vols",         "フライト") }
    var tabStats:   String { t("Stats",   "Statystyki",  "Estadísticas","Statistiques","統計") }

    // MARK: - Home / Diary
    var heroTitle:        String { t("Your\nFlight Diary",  "Twój\nDziennik Lotów",    "Tu\nDiario de Vuelos",    "Votre\nJournal de Vols",     "あなたの\n飛行日誌") }
    var thisYear:         String { t("THIS YEAR",           "W TYM ROKU",              "ESTE AÑO",                "CETTE ANNÉE",                "今年") }
    var flightsStatLabel: String { t("Flights",             "Loty",                    "Vuelos",                  "Vols",                       "フライト") }
    var kmFlownLabel:     String { distanceUnit == .km
                                    ? t("Km Flown",  "Km Przelatane", "Km Volados", "Km Parcourus", "飛行 km")
                                    : t("Mi Flown",  "Mi Przebyte",   "Mi Voladas", "Mi Parcourues","飛行 mi") }
    var countriesLabel:   String { t("Countries",           "Kraje",                   "Países",                  "Pays",                       "訪問国") }
    var statsArrow:       String { t("Stats →",             "Statystyki →",            "Estadísticas →",          "Statistiques →",             "統計 →") }
    var upcomingFlights:  String { t("UPCOMING FLIGHTS",    "NADCHODZĄCE LOTY",        "PRÓXIMOS VUELOS",         "VOLS À VENIR",               "予定フライト") }
    var recentFlights:    String { t("RECENT FLIGHTS",      "OSTATNIE LOTY",           "VUELOS RECIENTES",        "VOLS RÉCENTS",               "最近のフライト") }
    var historyArrow:     String { t("History →",           "Historia →",              "Historial →",             "Historique →",               "履歴 →") }
    var noFlightsTitle:   String { t("No flights yet",      "Brak lotów",              "Sin vuelos",              "Pas encore de vols",         "フライトなし") }
    var noFlightsSub:     String { t("Tap Add below to log your first flight.",
                                     "Dotknij Dodaj, aby zalogować pierwszy lot.",
                                     "Toca Añadir para registrar tu primer vuelo.",
                                     "Appuyez sur Ajouter pour enregistrer votre premier vol.",
                                     "「追加」をタップして初フライトを記録しましょう。") }
    var pastFlightsHint:  String { t("Your past flights will appear here.",
                                     "Twoje poprzednie loty pojawią się tutaj.",
                                     "Tus vuelos pasados aparecerán aquí.",
                                     "Vos vols passés apparaîtront ici.",
                                     "過去のフライトはここに表示されます。") }

    func allFlightsCount(_ n: Int) -> String {
        switch language {
        case .english:  "All \(n) flights"
        case .polish:   "Wszystkie \(n) lotów"
        case .spanish:  "Los \(n) vuelos"
        case .french:   "Les \(n) vols"
        case .japanese: "全\(n)フライト"
        }
    }

    // MARK: - Map
    var flightMapOverline: String { t("FLIGHT MAP",    "MAPA LOTÓW",        "MAPA DE VUELOS",   "CARTE DES VOLS",   "フライトマップ") }
    var flightMapTitle:    String { t("Flight Map",    "Mapa Lotów",        "Mapa de Vuelos",   "Carte des Vols",   "フライトマップ") }
    var beenChip:          String { t("✓ Been",        "✓ Byłem",           "✓ Estuve",         "✓ Visité",         "✓ 訪問済み") }
    var allChip:           String { t("All",           "Wszystkie",         "Todos",            "Tous",             "すべて") }
    var flightsStat:       String { t("FLIGHTS",       "LOTY",              "VUELOS",           "VOLS",             "フライト") }
    var distanceStat:      String { t("DISTANCE",      "DYSTANS",           "DISTANCIA",        "DISTANCE",         "距離") }
    var countriesStat:     String { t("COUNTRIES",     "KRAJE",             "PAÍSES",           "PAYS",             "訪問国") }
    var mapEmptyHint:      String { t("Add your first flight to see it on the map",
                                      "Dodaj pierwszy lot, aby zobaczyć go na mapie",
                                      "Añade tu primer vuelo para verlo en el mapa",
                                      "Ajoutez votre premier vol pour le voir sur la carte",
                                      "地図に表示するには最初のフライトを追加してください") }

    // MARK: - Flights List
    var logbookOverline:  String { t("LOGBOOK",          "DZIENNIK",           "CUADERNO",          "CARNET",             "ログブック") }
    var allFlightsTitle:  String { t("All Flights",       "Wszystkie Loty",     "Todos los Vuelos",  "Tous les Vols",      "全フライト") }
    var noFlightsLogged:  String { t("No flights logged", "Brak zapisanych lotów","Sin vuelos registrados","Aucun vol enregistré","フライト未記録") }
    var tapAddHint:       String { t("Tap Add to log your first flight.",
                                     "Dotknij Dodaj, aby zalogować pierwszy lot.",
                                     "Toca Añadir para registrar tu primer vuelo.",
                                     "Appuyez sur Ajouter pour enregistrer votre premier vol.",
                                     "「追加」をタップして最初のフライトを記録しましょう。") }
    var deleteAction:     String { t("Delete",  "Usuń",   "Eliminar", "Supprimer", "削除") }
    var editAction:       String { t("Edit",    "Edytuj", "Editar",   "Modifier",  "編集") }

    func entriesCount(_ n: Int) -> String {
        switch language {
        case .english:  "\(n) entr\(n == 1 ? "y" : "ies")"
        case .polish:   "\(n) wpisów"
        case .spanish:  "\(n) entradas"
        case .french:   "\(n) entrées"
        case .japanese: "\(n)件"
        }
    }

    // MARK: - Add / Edit Flight
    var addFlightTitle:     String { t("Add Flight",     "Dodaj Lot",       "Añadir Vuelo",    "Ajouter un Vol",     "フライト追加") }
    var editFlightTitle:    String { t("Edit Flight",    "Edytuj Lot",      "Editar Vuelo",    "Modifier le Vol",    "フライト編集") }
    var saveFlightButton:   String { t("Save Flight",    "Zapisz Lot",      "Guardar Vuelo",   "Enregistrer le Vol", "フライトを保存") }
    var fromPlaceholder:    String { t("From",           "Skąd",            "Desde",           "Départ",             "出発地") }
    var toPlaceholder:      String { t("To",             "Dokąd",           "Hasta",           "Arrivée",            "目的地") }
    var airlinePlaceholder: String { t("Airline (optional)", "Linia lotnicza (opcjonalne)", "Aerolínea (opcional)", "Compagnie (optionnel)", "航空会社（任意）") }
    var priceLabel:         String { t("PRICE",              "CENA",                        "PRECIO",               "PRIX",                  "価格") }
    var pricePlaceholder:   String { t("e.g. 199.99",        "np. 199.99",                  "p.ej. 199.99",         "ex. 199.99",            "例：199.99") }

    // MARK: - Settings
    var settingsTitle:      String { t("Settings",        "Ustawienia",      "Configuración",   "Paramètres",         "設定") }
    var accountSection:     String { t("ACCOUNT",         "KONTO",           "CUENTA",          "COMPTE",             "アカウント") }
    var profileRow:         String { t("Profile",         "Profil",          "Perfil",          "Profil",             "プロフィール") }
    var syncRow:            String { t("Sync & Backup",   "Sync i Kopia",    "Sync y Copia",    "Sync et Sauvegarde", "同期とバックアップ") }
    var appearanceSection:  String { t("APPEARANCE",      "WYGLĄD",          "APARIENCIA",      "APPARENCE",          "外観") }
    var themeRow:           String { t("Theme",           "Motyw",           "Tema",            "Thème",              "テーマ") }
    var themeDark:          String { t("Dark",            "Ciemny",          "Oscuro",          "Sombre",             "ダーク") }
    var themeLight:         String { t("Light",           "Jasny",           "Claro",           "Clair",              "ライト") }
    var themeSystem:        String { t("System",          "Systemowy",       "Sistema",         "Système",            "システム") }
    var unitsRow:           String { t("Units",           "Jednostki",       "Unidades",        "Unités",             "単位") }
    var languageSection:    String { t("LANGUAGE",        "JĘZYK",           "IDIOMA",          "LANGUE",             "言語") }
    var languageRow:        String { t("Language",        "Język",           "Idioma",          "Langue",             "言語") }
    var aboutSection:       String { t("ABOUT",           "O APLIKACJI",     "ACERCA DE",       "À PROPOS",           "アプリについて") }
    var versionRow:         String { t("Version",         "Wersja",          "Versión",         "Version",            "バージョン") }
    var madeWithPassion:    String { t("Made with passion","Zrobione z pasją","Hecho con pasión","Fait avec passion",  "情熱を込めて制作") }
    var doneButton:         String { t("Done",            "Gotowe",          "Listo",           "Terminé",            "完了") }
    var comingSoon:         String { t("Soon",            "Wkrótce",         "Pronto",          "Bientôt",            "近日公開") }
    var currencyRow:        String { t("Currency",        "Waluta",          "Moneda",          "Devise",             "通貨") }

    // MARK: - Stats
    var statsAddMoreFlights:   String { t("Add more flights to unlock this stat",
                                          "Dodaj więcej lotów, aby odblokować tę statystykę",
                                          "Añade más vuelos para desbloquear esta estadística",
                                          "Ajoutez plus de vols pour débloquer cette statistique",
                                          "この統計を表示するにはフライトを追加してください") }
    var statsComingSoon:       String { t("Coming soon",          "Wkrótce",               "Próximamente",         "Bientôt",               "近日公開") }
    var statsYourJourney:      String { t("YOUR JOURNEY",         "TWOJA PODRÓŻ",          "TU VIAJE",             "VOTRE VOYAGE",          "あなたの旅") }
    var shareYourJourney:      String { t("Share your journey",    "Udostępnij swoją podróż","Comparte tu viaje",   "Partagez votre voyage", "旅をシェア") }
    var statsAroundEarth:      String { t("around the Earth",     "dookoła Ziemi",         "alrededor de la Tierra","autour de la Terre",   "地球一周") }
    var statsFlightsLabel:     String { t("FLIGHTS",              "LOTY",                  "VUELOS",               "VOLS",                  "フライト") }
    var statsCountriesLabel:   String { t("COUNTRIES",            "KRAJE",                 "PAÍSES",               "PAYS",                  "カ国") }
    var statsAirportsLabel:    String { t("AIRPORTS",             "LOTNISKA",              "AEROPUERTOS",          "AÉROPORTS",             "空港") }
    var statsInTheAir:         String { t("IN THE AIR",           "W POWIETRZU",           "EN EL AIRE",           "EN VOL",                "飛行時間") }
    var statsRecords:          String { t("PERSONAL RECORDS",     "REKORDY",               "RÉCORDS",              "RECORDS",               "記録") }
    var statsLongestFlight:    String { t("LONGEST FLIGHT",       "NAJDŁUŻSZY LOT",        "VUELO MÁS LARGO",      "VOL LE PLUS LONG",      "最長フライト") }
    var statsShortestFlight:   String { t("SHORTEST FLIGHT",      "NAJKRÓTSZY LOT",        "VUELO MÁS CORTO",      "VOL LE PLUS COURT",     "最短フライト") }
    var statsFavorites:        String { t("YOUR FAVORITES",       "TWOJE ULUBIONE",        "TUS FAVORITOS",        "VOS FAVORIS",           "お気に入り") }
    var statsTopAirline:       String { t("TOP AIRLINE",          "ULUBIONA LINIA",        "AEROLÍNEA TOP",        "COMPAGNIE PRÉFÉRÉE",    "よく使う航空会社") }
    var statsTopAircraft:      String { t("TOP AIRCRAFT",         "ULUBIONY SAMOLOT",      "AERONAVE TOP",         "APPAREIL PRÉFÉRÉ",      "よく乗る機体") }
    var statsFlyingStyle:      String { t("FLYING STYLE",         "STYL LATANIA",          "ESTILO DE VUELO",      "STYLE DE VOL",          "フライトスタイル") }
    var statsClassBreakdown:   String { t("BY CLASS",             "KLASY",                 "POR CLASE",            "PAR CLASSE",            "クラス別") }
    var statsSeatPreference:   String { t("SEAT PREFERENCE",      "PREFERENCJA MIEJSCA",   "PREFERENCIA ASIENTO",  "PRÉFÉRENCE SIÈGE",      "座席の好み") }
    var statsDomesticVsIntl:   String { t("DOMESTIC VS INTERNATIONAL","KRAJOWE VS MIĘDZYNARODOWE","DOMÉSTICO VS INTERNACIONAL","DOMESTIQUE VS INTERNATIONAL","国内 VS 国際") }
    var statsDomestic:         String { t("Domestic",             "Krajowe",               "Doméstico",            "Domestique",            "国内") }
    var statsInternational:    String { t("International",        "Międzynarodowe",        "Internacional",        "International",         "国際") }
    var statsWorldCoverage:    String { t("WORLD COVERAGE",       "ZASIĘG",                "COBERTURA MUNDIAL",    "COUVERTURE MONDIALE",   "世界カバレッジ") }
    var statsContinents:       String { t("continents",           "kontynenty",            "continentes",          "continents",            "大陸") }
    var statsFlightsCount:     String { t("flights",              "lotów",                 "vuelos",               "vols",                  "フライト") }
    var statsHoursShort:       String { t("h",                    "g",                     "h",                    "h",                     "時間") }

    // MARK: - Money Stats
    var statsMoneySection:     String { t("SPENDING",              "WYDATKI",               "GASTOS",               "DÉPENSES",              "支出") }
    var statsTotalSpent:       String { t("total spent",           "łącznie wydano",        "total gastado",        "total dépensé",         "合計支出") }
    var statsSpendPerYear:     String { t("SPENDING PER YEAR",     "WYDATKI W ROKU",        "GASTOS POR AÑO",       "DÉPENSES PAR AN",       "年別支出") }
    var statsAvgPerFlightCost: String { t("AVG PER FLIGHT",        "ŚR. NA LOT",            "PROM. POR VUELO",      "MOY. PAR VOL",          "便あたり平均") }
    var statsCostPerKm:        String { t("COST PER KM",           "KOSZT ZA KM",           "COSTO POR KM",         "COÛT PAR KM",           "km単価") }
    var statsCostPerMi:        String { t("COST PER MI",           "KOSZT ZA MI",           "COSTO POR MI",         "COÛT PAR MI",           "mi単価") }
    var statsMostExpensive:    String { t("MOST EXPENSIVE",        "NAJDROŻSZY",            "MÁS CARO",             "LE PLUS CHER",          "最高額") }
    var statsCheapest:         String { t("CHEAPEST",              "NAJTAŃSZY",             "MÁS BARATO",           "LE MOINS CHER",         "最安値") }
    var statsSpendByClass:     String { t("AVG PRICE BY CLASS",    "ŚR. CENA WG KLASY",    "PRECIO PROM. POR CLASE","PRIX MOY. PAR CLASSE",  "クラス別平均価格") }
    var statsTopAirlineSpend:  String { t("TOP AIRLINES BY SPEND", "LINIE WG WYDATKÓW",    "AEROLÍNEAS POR GASTO", "COMPAGNIES PAR DÉPENSE","航空会社別支出") }
    var statsFlightsTracked:   String { t("flights with price",    "lotów z ceną",          "vuelos con precio",    "vols avec prix",        "価格記録済み") }
    var statsBestDeal:         String { t("BEST DEAL",             "NAJLEPSZA OFERTA",      "MEJOR OFERTA",         "MEILLEURE AFFAIRE",     "お得なフライト") }
    var statsPriciest:         String { t("PRICIEST",              "NAJDROŻSZY",            "MÁS COSTOSO",          "PLUS CHER",             "最高額") }
    var statsPerKm:            String { t("per km",                "za km",                 "por km",               "par km",                "/km") }
    var statsPerMi:            String { t("per mi",                "za mi",                 "por mi",               "par mi",                "/mi") }

    // MARK: - Achievements
    var statsAchievements:     String { t("ACHIEVEMENTS",          "OSIĄGNIĘCIA",           "LOGROS",               "SUCCÈS",                "実績") }
    var achieveFirstFlight:    String { t("First Flight",          "Pierwszy Lot",          "Primer Vuelo",         "Premier Vol",           "初フライト") }
    var achieveFirstFlightSub: String { t("Log your first flight", "Zarejestruj pierwszy lot","Registra tu primer vuelo","Enregistrez votre premier vol","最初のフライトを記録") }
    var achieveFreqFlyer:      String { t("Frequent Flyer",        "Częsty Pasażer",        "Viajero Frecuente",    "Grand Voyageur",        "常連旅客") }
    var achieveFreqFlyerSub:   String { t("Log 10 flights",        "Zarejestruj 10 lotów",  "Registra 10 vuelos",   "Enregistrez 10 vols",   "10フライト記録") }
    var achieveJetSetter:      String { t("Jet Setter",            "Globtroter",            "Trotamundos",          "Jet-Setteur",           "ジェットセッター") }
    var achieveJetSetterSub:   String { t("Log 50 flights",        "Zarejestruj 50 lotów",  "Registra 50 vuelos",   "Enregistrez 50 vols",   "50フライト記録") }
    var achieveExplorer:       String { t("Explorer",              "Odkrywca",              "Explorador",           "Explorateur",           "探検家") }
    var achieveExplorerSub:    String { t("Visit 5 countries",     "Odwiedź 5 krajów",      "Visita 5 países",      "Visitez 5 pays",        "5カ国訪問") }
    var achieveGlobeTrotter:   String { t("Globe Trotter",         "Obieżyświat",           "Trotamundos",          "Globe-Trotteur",        "世界旅行者") }
    var achieveGlobeTrotterSub:String { t("Visit 15 countries",    "Odwiedź 15 krajów",     "Visita 15 países",     "Visitez 15 pays",       "15カ国訪問") }
    var achieveWorldCitizen:   String { t("World Citizen",         "Obywatel Świata",       "Ciudadano del Mundo",  "Citoyen du Monde",      "世界市民") }
    var achieveWorldCitizenSub:String { t("Visit 30 countries",    "Odwiedź 30 krajów",     "Visita 30 países",     "Visitez 30 pays",       "30カ国訪問") }
    var achieveAroundWorld:    String { t("Around the World",      "Dookoła Świata",        "Vuelta al Mundo",      "Tour du Monde",         "世界一周") }
    var achieveAroundWorldSub: String { t("Fly 40,075 km total",   "Przeleć łącznie 40 075 km","Vuela 40.075 km en total","Parcourez 40 075 km au total","合計40,075km飛行") }
    var achieveToTheMoon:      String { t("To the Moon",           "Na Księżyc",            "A la Luna",            "Vers la Lune",          "月まで") }
    var achieveToTheMoonSub:   String { t("Fly 384,400 km total",  "Przeleć łącznie 384 400 km","Vuela 384.400 km en total","Parcourez 384 400 km au total","合計384,400km飛行") }
    var achieveSkyTimer:       String { t("Sky Timer",             "Czas w Chmurach",       "Reloj Aéreo",          "Chrono du Ciel",        "スカイタイマー") }
    var achieveSkyTimerSub:    String { t("Spend 100h in the air", "Spędź 100h w powietrzu","Pasa 100h en el aire", "Passez 100h en vol",    "飛行時間100時間") }
    var achieveCollector:      String { t("Airport Collector",     "Kolekcjoner Lotnisk",   "Coleccionista",        "Collectionneur",        "空港コレクター") }
    var achieveCollectorSub:   String { t("Visit 10 airports",     "Odwiedź 10 lotnisk",    "Visita 10 aeropuertos","Visitez 10 aéroports",  "10空港訪問") }

    // MARK: - Monthly Heatmap
    var statsActivityMap:      String { t("ACTIVITY MAP",           "MAPA AKTYWNOŚCI",       "MAPA DE ACTIVIDAD",    "CARTE D'ACTIVITÉ",      "アクティビティマップ") }

    // MARK: - Year Comparison
    var statsYearVsYear:       String { t("YEAR VS YEAR",          "ROK DO ROKU",           "AÑO VS AÑO",          "ANNÉE VS ANNÉE",        "年度比較") }
    var statsVs:               String { t("vs",                    "vs",                    "vs",                   "vs",                    "vs") }
    var statsNoDataLastYear:   String { t("No data for last year", "Brak danych z ubiegłego roku","Sin datos del año pasado","Pas de données l'an dernier","昨年のデータなし") }

    // MARK: - Top Routes
    var statsTopRoutes:        String { t("TOP ROUTES",            "NAJCZĘSTSZE TRASY",     "RUTAS TOP",            "ROUTES PRINCIPALES",    "よく使うルート") }

    // MARK: - Fun Facts
    var statsFunFacts:         String { t("DID YOU KNOW?",          "CZY WIESZ, ŻE?",       "¿SABÍAS QUE?",         "LE SAVIEZ-VOUS ?",      "知ってた？") }

    // MARK: - Flights Detail Sheet
    var flightsLogged:         String { t("flights logged",        "lotów zarejestrowanych", "vuelos registrados",    "vols enregistrés",      "フライト記録") }
    var statsFlightsPerYear:   String { t("FLIGHTS PER YEAR",      "LOTY W ROKU",            "VUELOS POR AÑO",        "VOLS PAR AN",           "年別フライト") }
    var statsYourPace:         String { t("YOUR PACE",             "TWOJE TEMPO",            "TU RITMO",              "VOTRE CADENCE",         "ペース") }
    var statsAvgMonth:         String { t("avg / month",           "śr. / mies.",            "prom. / mes",           "moy. / mois",           "平均 / 月") }
    var statsAvgYear:          String { t("avg / year",            "śr. / rok",              "prom. / año",           "moy. / an",             "平均 / 年") }
    var statsBusiestMonth:     String { t("BUSIEST MONTH",         "NAJRUCHLIWSZY MIESIĄC",  "MES MÁS ACTIVO",        "MOIS LE PLUS ACTIF",    "最多フライト月") }
    var statsMonthStreak:      String { t("MONTH STREAK",          "SERIA MIESIĘCY",         "RACHA MENSUAL",         "SÉRIE MENSUELLE",       "月間連続記録") }
    var statsConsecutive:      String { t("consecutive",           "kolejnych",              "consecutivos",          "consécutifs",           "連続") }
    var statsMonthShort:       String { t("mo",                    "mies.",                  "mes",                   "mois",                  "ヶ月") }

    func upcomingBadge(_ n: Int) -> String {
        switch language {
        case .english:  return "+ \(n) upcoming"
        case .polish:   return "+ \(n) nadchodzące"
        case .spanish:  return "+ \(n) próximos"
        case .french:   return "+ \(n) à venir"
        case .japanese: return "+ \(n) 予定"
        }
    }

    // MARK: - Countries Detail Sheet
    var countriesVisited:   String { t("countries visited",  "odwiedzone kraje",     "países visitados",    "pays visités",         "訪問国") }
    var statsAllFlags:      String { t("ALL FLAGS",          "WSZYSTKIE FLAGI",      "TODAS LAS BANDERAS",  "TOUS LES DRAPEAUX",    "すべての国旗") }
    var statsByContinent:   String { t("BY CONTINENT",       "WG KONTYNENTU",        "POR CONTINENTE",      "PAR CONTINENT",        "大陸別") }
    var statsMostVisited:   String { t("MOST VISITED",       "NAJCZĘŚCIEJ ODWIEDZANE","MÁS VISITADOS",      "PLUS VISITÉS",         "最多訪問") }

    // Airports Detail Sheet
    var airportsVisited:     String { t("airports visited",    "odwiedzone lotniska",    "aeropuertos visitados",    "aéroports visités",       "訪問空港") }
    var statsTopAirports:    String { t("TOP AIRPORTS",        "GŁÓWNE LOTNISKA",        "PRINCIPALES AEROPUERTOS",  "PRINCIPAUX AÉROPORTS",    "主要空港") }

    // Hours Detail Sheet
    var hoursInTheAir:       String { t("hours in the air",    "godzin w powietrzu",     "horas en el aire",         "heures en vol",            "飛行時間") }
    var statsHoursPerYear:   String { t("HOURS PER YEAR",      "GODZINY W ROKU",         "HORAS POR AÑO",            "HEURES PAR AN",            "年別時間") }
    var statsAvgPerFlight:   String { t("AVG PER FLIGHT",      "ŚR. NA LOT",             "PROM. POR VUELO",          "MOY. PAR VOL",             "便あたり平均") }
    var statsDistanceFacts:  String { t("DISTANCE FACTS",      "CIEKAWOSTKI",            "DATOS DE DISTANCIA",       "DONNÉES DISTANCE",         "距離データ") }
    var statsMoonTrip:       String { t("to the Moon",         "do Księżyca",            "a la Luna",                "vers la Lune",             "月への距離") }

    func ofCountries(_ n: Int) -> String {
        switch language {
        case .english:  return "of \(n) countries"
        case .polish:   return "z \(n) krajów"
        case .spanish:  return "de \(n) países"
        case .french:   return "sur \(n) pays"
        case .japanese: return "\(n)カ国中"
        }
    }

    // MARK: - Hero subtitle
    func heroSubtitle(flights: Int, countries: Int) -> String {
        switch language {
        case .english:  return "\(flights) flight\(flights == 1 ? "" : "s") across \(countries) \(countries == 1 ? "country" : "countries")"
        case .polish:   return "\(flights) lot\(flights == 1 ? "" : "ów") w \(countries) kraju/krajach"
        case .spanish:  return "\(flights) vuelo\(flights == 1 ? "" : "s") en \(countries) país\(countries == 1 ? "" : "es")"
        case .french:   return "\(flights) vol\(flights == 1 ? "" : "s") dans \(countries) pays"
        case .japanese: return "\(flights)フライト・\(countries)カ国"
        }
    }

    // MARK: - Countdown
    var countdownToday:    String { t("Today",    "Dziś",  "Hoy",    "Aujourd'hui", "今日") }
    var countdownTomorrow: String { t("Tomorrow", "Jutro", "Mañana", "Demain",      "明日") }
    func countdownDays(_ n: Int) -> String {
        switch language {
        case .english:  return "In \(n)d"
        case .polish:   return "Za \(n)d"
        case .spanish:  return "En \(n)d"
        case .french:   return "Dans \(n)j"
        case .japanese: return "\(n)日後"
        }
    }

    // MARK: - Flight Detail labels
    var estDurationLabel: String { t("EST. DURATION", "CZAS LOTU",   "DURACIÓN EST.", "DURÉE EST.",  "推定時間") }
    var originLabel:      String { t("ORIGIN",        "SKĄD",        "ORIGEN",        "DÉPART",      "出発地") }
    var destinationLabel: String { t("DESTINATION",   "DOKĄD",       "DESTINO",       "DESTINATION", "目的地") }

    // MARK: - SeatType / FlightClass localized labels
    func seatTypeLabel(_ type: SeatType) -> String {
        switch type {
        case .window: return t("Window",  "Okno",       "Ventana",  "Hublot",   "窓側")
        case .middle: return t("Middle",  "Środek",     "Centro",   "Milieu",   "中央")
        case .aisle:  return t("Aisle",   "Przejście",  "Pasillo",  "Couloir",  "通路")
        }
    }

    func flightClassLabel(_ cls: FlightClass) -> String {
        switch cls {
        case .economy:        return t("Economy",     "Ekonomiczna",  "Económica",   "Économique",  "エコノミー")
        case .premiumEconomy: return t("Premium Eco", "Premium Eko",  "Premium Eco", "Premium Éco", "プレミアムエコ")
        case .business:       return t("Business",    "Biznes",       "Negocios",    "Affaires",    "ビジネス")
        case .first:          return t("First",       "Pierwsza",     "Primera",     "Première",    "ファースト")
        }
    }

    // MARK: - Add / Edit Flight (extended)
    var cancelButton:         String { t("Cancel",              "Anuluj",           "Cancelar",          "Annuler",           "キャンセル") }
    var backButton:           String { t("Back",                "Powrót",           "Atrás",             "Retour",            "戻る") }
    var addNewFlight:         String { t("Add a New Flight",    "Dodaj nowy lot",   "Añadir un vuelo",   "Ajouter un vol",    "フライト追加") }
    var editFlightNav:        String { t("Edit Flight",         "Edytuj lot",       "Editar vuelo",      "Modifier le vol",   "フライト編集") }
    var departureAirport:     String { t("Departure Airport",   "Lotnisko odlotu",  "Aeropuerto salida", "Départ",            "出発空港") }
    var arrivalAirport:       String { t("Arrival Airport",     "Lotnisko przylotu","Aeropuerto llegada","Arrivée",           "到着空港") }
    var fromLabel:            String { t("FROM",                "SKĄD",             "DESDE",             "DÉPART",            "出発") }
    var toLabel:              String { t("TO",                  "DOKĄD",            "HASTA",             "ARRIVÉE",           "到着") }
    var originPlaceholder:    String { t("Origin",              "Skąd",             "Origen",            "Origine",           "出発地") }
    var destinationPlaceholder: String { t("Destination",       "Dokąd",            "Destino",           "Destination",       "目的地") }
    var tapToSearch:          String { t("Tap to search",       "Dotknij, aby szukać","Toca para buscar","Appuyez pour chercher","タップして検索") }
    var dateLabel:            String { t("Date",                "Data",             "Fecha",             "Date",              "日付") }
    var distanceLabel:        String { t("Distance",            "Dystans",          "Distancia",         "Distance",          "距離") }
    var airlineLabel:         String { t("AIRLINE",             "LINIA LOTNICZA",   "AEROLÍNEA",         "COMPAGNIE",         "航空会社") }
    var airlineFieldPlaceholder: String { t("e.g. Lufthansa, Ryanair…","np. Lufthansa, Ryanair…","p.ej. Iberia, Vueling…","ex. Air France…","例：ANA、JAL…") }
    var seatLabel:            String { t("SEAT",                "MIEJSCE",          "ASIENTO",           "SIÈGE",             "座席") }
    var classLabel:           String { t("CLASS",               "KLASA",            "CLASE",             "CLASSE",            "クラス") }
    var searchFieldPlaceholder: String { t("City, airport or IATA code…","Miasto, lotnisko lub kod IATA…","Ciudad, aeropuerto o código IATA…","Ville, aéroport ou code IATA…","都市、空港またはIATAコード…") }
    var searchPromptTitle:    String { t("Search for an airport","Szukaj lotniska",  "Buscar aeropuerto", "Rechercher aéroport","空港を検索") }
    var searchPromptSub:      String { t("Type a city, country or IATA code.","Wpisz miasto, kraj lub kod IATA.","Escribe ciudad, país o código IATA.","Tapez ville, pays ou code IATA.","都市・国・IATAコードを入力") }
    var noAirportsFound:      String { t("No airports found",   "Nie znaleziono lotnisk","No se encontraron aeropuertos","Aucun aéroport trouvé","空港が見つかりません") }
    var saveChangesButton:         String { t("Save Changes",       "Zapisz zmiany",    "Guardar cambios",    "Enregistrer les modifications", "変更を保存") }
    var autoFilledBadge:           String { t("auto-filled",         "auto-uzupełnione", "autocompletado",     "auto-rempli",                   "自動入力") }
    var flightNumberLabel:         String { t("FLIGHT NO.",          "NR LOTU",          "N.° VUELO",          "N° DE VOL",                     "便名") }
    var flightNumberPlaceholder:   String { t("e.g. LO273, FR1234…", "np. LO273, FR1234…","p.ej. IB3141…",      "ex. AF447…",                    "例：NH006…") }
    var aircraftLabel:             String { t("AIRCRAFT",            "SAMOLOT",          "AERONAVE",           "APPAREIL",                      "機体") }
    var aircraftPlaceholder:       String { t("Select aircraft…",    "Wybierz samolot…", "Seleccionar avión…", "Choisir l'appareil…",           "機体を選択…") }
    var aircraftSearchPlaceholder: String { t("Search aircraft…",    "Szukaj samolotu…", "Buscar aeronave…",   "Rechercher appareil…",          "機体を検索…") }
    var clearAircraft:             String { t("Clear selection",     "Wyczyść wybór",    "Borrar selección",   "Effacer la sélection",          "選択をクリア") }
}
