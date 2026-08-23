// Localization.swift
// Multilingual support (English / Español) for CineSched UI, menus, and Call Sheet exports.

import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Codable {
    case english = "en"
    case spanish = "es"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    /// Multi-language support has been disabled at the user's request — the app is
    /// English-only now. This stays a single change point (rather than removing every
    /// L()/isSpanish call site across the ten files that reference it) specifically so
    /// re-enabling it later, if ever wanted, is just as small a change as disabling it was.
    @Published var currentLanguage: AppLanguage = .english

    func setLanguage(_ lang: AppLanguage) {
        // No-op — language switching is disabled.
    }
}

// Global helper function for translations
func L(_ key: String, lang: AppLanguage = LocalizationManager.shared.currentLanguage) -> String {
    let dict: [String: [AppLanguage: String]] = [
        // Top Menus
        "File": [.english: "File", .spanish: "Archivo"],
        "Edit": [.english: "Edit", .spanish: "Edición"],
        "Production": [.english: "Production", .spanish: "Producción"],
        "View": [.english: "View", .spanish: "Ver"],
        "Theme": [.english: "Theme", .spanish: "Tema de Color"],
        "System Normal": [.english: "System (Normal)", .spanish: "Normal (Sistema)"],
        "Ocean Blue": [.english: "Ocean Blue", .spanish: "Azul Océano"],
        "Emerald Green": [.english: "Emerald Green", .spanish: "Verde Esmeralda"],
        "Amber Yellow": [.english: "Sunny Yellow", .spanish: "Amarillo Sol"],
        "Sunny Yellow": [.english: "Sunny Yellow", .spanish: "Amarillo Sol"],
        "New Project": [.english: "New Project", .spanish: "Nuevo Proyecto"],
        "Open…": [.english: "Open…", .spanish: "Abrir…"],
        "Open Recent": [.english: "Open Recent", .spanish: "Abrir Recientes"],
        "No Recent Projects": [.english: "No Recent Projects", .spanish: "Sin Proyectos Recientes"],
        "Clear Menu": [.english: "Clear Menu", .spanish: "Limpiar Menú"],
        "Import Script…": [.english: "Import Script…", .spanish: "Importar Guión…"],
        "Undo": [.english: "Undo", .spanish: "Deshacer"],
        "Redo": [.english: "Redo", .spanish: "Rehacer"],
        "Save As…": [.english: "Save As…", .spanish: "Guardar Como…"],
        "Export Schedule to PDF…": [.english: "Export Schedule to PDF…", .spanish: "Exportar Plan de Rodaje a PDF…"],
        "Export Plan de Rodaje (PDF)": [.english: "Export Shooting Schedule (PDF)", .spanish: "Exportar Plan de Rodaje (PDF)"],
        "Add Notice / Banner Strip": [.english: "Add Notice / Banner Strip", .spanish: "Añadir Tira de Aviso / Banner"],
        "Insert custom move, notice, or note into the stripboard schedule": [.english: "Insert custom move, notice, or note into the stripboard schedule", .spanish: "Inserta un traslado, aviso o nota dentro del stripboard"],
        "Banner Type": [.english: "Banner Type", .spanish: "Tipo de Tira"],
        "Title / Message": [.english: "Title / Message", .spanish: "Título / Mensaje"],
        "Additional Notes": [.english: "Additional Notes", .spanish: "Notas Adicionales"],
        "Estimated Time (h:mm)": [.english: "Estimated Time (h:mm)", .spanish: "Tiempo Estimado (h:mm)"],
        "Banner Color": [.english: "Banner Color", .spanish: "Color de la Tira"],
        "Add Banner": [.english: "Add Banner", .spanish: "Añadir Tira"],
        "Company Move": [.english: "Company Move", .spanish: "Traslado"],
        "Meal Break": [.english: "Meal Break", .spanish: "Comida"],
        "Notice / Note": [.english: "Notice", .spanish: "Nota"],
        "Notice": [.english: "Notice", .spanish: "Aviso"],
        "Note": [.english: "Note", .spanish: "Nota"],
        "Custom Banner": [.english: "Custom Banner", .spanish: "Banner Personalizado"],
        "GENERAL CALL": [.english: "GENERAL CALL", .spanish: "LLAMADO GENERAL"],
        "READY TO SHOOT / EN SET": [.english: "READY TO SHOOT", .spanish: "EN SET"],
        "READY TO SHOOT": [.english: "READY TO SHOOT", .spanish: "EN SET"],
        "ALMUERZO / LUNCH": [.english: "LUNCH", .spanish: "ALMUERZO"],
        "MERIENDA / SNACK": [.english: "SNACK", .spanish: "MERIENDA"],
        "CENA / DINNER": [.english: "DINNER", .spanish: "CENA"],
        "FIN DE RODAJE / WRAP": [.english: "WRAP", .spanish: "FIN DE RODAJE"],
        "Dinner:": [.english: "Dinner:", .spanish: "Cena:"],
        "Wrap / Fin de Rodaje:": [.english: "Wrap:", .spanish: "Fin de Rodaje:"],
        "Remove Banner Strip": [.english: "Remove Banner Strip", .spanish: "Remover Tira de Aviso"],
        "Export Strip Schedule to PDF…": [.english: "Export Strip Schedule to PDF…", .spanish: "Exportar Tiras a PDF…"],
        "Export Days Out of Days…": [.english: "Export Days Out of Days…", .spanish: "Exportar Days Out of Days (DooD)…"],
        "Export Scene Breakdowns…": [.english: "Export Scene Breakdowns…", .spanish: "Exportar Desgloses de Escena…"],
        "Production Setup…": [.english: "Production Setup…", .spanish: "Configuración de Producción…"],
        "Scan for Conflicts…": [.english: "Scan for Conflicts…", .spanish: "Escanear Conflictos…"],
        "Breakdown Browser…": [.english: "Breakdown Browser…", .spanish: "Explorador de Desgloses…"],
        "Include Hold Days in DOoD Report": [.english: "Include Hold Days in DOoD Report", .spanish: "Incluir días en Hold en el reporte DOoD"],
        "Show Cast in Calendar": [.english: "Show Cast in Calendar", .spanish: "Mostrar Reparto en el Calendario"],
        "Show Estimated Time Instead of Page Count": [.english: "Show Estimated Time Instead of Page Count", .spanish: "Mostrar Tiempo Estimado en Vez de Páginas"],
        "Lock Schedule": [.english: "Lock Schedule", .spanish: "Bloquear Calendario"],
        "Unlock Schedule": [.english: "Unlock Schedule", .spanish: "Desbloquear Calendario"],
        "Schedule Lock Report…": [.english: "Schedule Lock Report…", .spanish: "Reporte de Bloqueo del Calendario…"],
        "Dark Mode": [.english: "Dark Mode", .spanish: "Modo Oscuro"],
        "Color Legend…": [.english: "Color Legend…", .spanish: "Leyenda de Colores…"],
        "Customize Scene Colors…": [.english: "Customize Scene Colors…", .spanish: "Personalizar Colores de Escenas…"],
        "Language / Idioma": [.english: "Language / Idioma", .spanish: "Idioma / Language"],

        // Production Setup Sheet
        "Production Setup": [.english: "Production Setup", .spanish: "Configuración de Producción"],
        "These details appear on every call sheet": [.english: "These details appear on every call sheet", .spanish: "Estos datos aparecen en todas las órdenes de rodaje"],
        "Production Details": [.english: "Production Details", .spanish: "Detalles de Producción"],
        "Production Company": [.english: "Production Company", .spanish: "Compañía Productora"],
        "Director": [.english: "Director", .spanish: "Director/a"],
        "Director name": [.english: "Director name", .spanish: "Nombre del Director/a"],
        "Producer": [.english: "Producer", .spanish: "Productor/a"],
        "Producer name": [.english: "Producer name", .spanish: "Nombre del Productor/a"],
        "1st AD (Assistant Director)": [.english: "1st AD (Assistant Director)", .spanish: "1º Ayudante de Dirección (1st AD)"],
        "1st AD name": [.english: "1st AD name", .spanish: "Nombre del 1º Ayudante de Dirección"],
        "Default Lunch Time": [.english: "Default Lunch Time", .spanish: "Hora por Defecto de Almuerzo"],
        "Phone": [.english: "Phone", .spanish: "Teléfono"],
        "Cast Roster": [.english: "Cast Roster", .spanish: "Elenco de Actores y Personajes"],
        "Actor Name": [.english: "Actor Name", .spanish: "Nombre del Actor / Actriz"],
        "Character": [.english: "Character", .spanish: "Personaje"],
        "Unavailable Dates": [.english: "Unavailable Dates", .spanish: "Indisponibilidad / Fechas No Disponibles"],
        "Add Cast Member": [.english: "Add Cast Member", .spanish: "Añadir Actor / Personaje"],
        "Crew Roster": [.english: "Crew Roster", .spanish: "Listado del Equipo Técnico"],
        "Crew Member Name": [.english: "Crew Member Name", .spanish: "Nombre del Técnico"],
        "Role / Department": [.english: "Role / Department", .spanish: "Rol / Departamento"],
        "Daily Default Call Time": [.english: "Daily Default Call Time", .spanish: "Citación Estándar Diaria"],
        "Add Crew Member": [.english: "Add Crew Member", .spanish: "Añadir Técnico al Equipo"],
        "Location Roster": [.english: "Location Roster", .spanish: "Catálogo de Locaciones"],
        "Pull from Breakdown": [.english: "Pull from Breakdown", .spanish: "Extraer del Desglose"],
        "Location Name": [.english: "Location Name", .spanish: "Nombre de la Locación"],
        "Address": [.english: "Address", .spanish: "Dirección"],
        "Add Location": [.english: "Add Location", .spanish: "Añadir Locación"],

        // Navigation / Views
        "Calendar": [.english: "Calendar", .spanish: "Calendario"],
        "Stripboard": [.english: "Stripboard", .spanish: "Stripboard"],
        "Boneyard": [.english: "Boneyard", .spanish: "Escenas no asignadas"],
        "Unscheduled Scenes": [.english: "Unscheduled Scenes", .spanish: "Sin asignar"],
        "Import Script": [.english: "Import Script", .spanish: "Importar Guión"],
        "Export PDF": [.english: "Export PDF", .spanish: "Exportar PDF"],
        "Export Stripboard": [.english: "Export Stripboard", .spanish: "Exportar Stripboard"],
        "Days Out of Days": [.english: "Days Out of Days", .spanish: "Days Out of Days (DooD)"],
        "Scan Conflicts": [.english: "Scan Conflicts", .spanish: "Escanear Conflictos"],
        "Search scenes, cast, locations…": [.english: "Search scenes, cast, locations…", .spanish: "Buscar escenas, actores, locaciones…"],
        "days": [.english: "days", .spanish: "días"],
        "scenes": [.english: "scenes", .spanish: "escenas"],
        "unscheduled": [.english: "unscheduled", .spanish: "sin asignar"],
        "selected": [.english: "selected", .spanish: "seleccionadas"],
        "Clear": [.english: "Clear", .spanish: "Limpiar"],

        // Scene Operations
        "Add Scene": [.english: "Add Scene", .spanish: "Añadir Escena"],
        "Edit Scene": [.english: "Edit Scene", .spanish: "Editar Escena"],
        "Duplicate Scene": [.english: "Duplicate Scene", .spanish: "Duplicar Escena"],
        "Delete Scene": [.english: "Delete Scene", .spanish: "Eliminar Escena"],
        "Remove from Day": [.english: "Remove from Day", .spanish: "Quitar del Día"],
        "Remove": [.english: "Remove", .spanish: "Quitar"],
        "Send to Day…": [.english: "Send to Day…", .spanish: "Enviar al Día…"],
        "New Scene": [.english: "New Scene", .spanish: "Nueva Escena"],
        "Scene Details": [.english: "Scene Details", .spanish: "Detalles de Escena"],
        "Scene #": [.english: "Scene #", .spanish: "Escena #"],
        "Scene Title": [.english: "Scene Title", .spanish: "Título de Escena"],
        "Duration (pages)": [.english: "Duration (pages)", .spanish: "Duración (páginas)"],
        "Estimated Time": [.english: "Estimated Time", .spanish: "Tiempo Estimado"],
        "Type": [.english: "Type", .spanish: "Tipo"],
        "DAY": [.english: "DAY", .spanish: "DÍA"],
        "NIGHT": [.english: "NIGHT", .spanish: "NOCHE"],
        "DAWN": [.english: "DAWN", .spanish: "AMANECER"],
        "DUSK": [.english: "DUSK", .spanish: "ATARDECER"],
        "AFTERNOON": [.english: "AFTERNOON", .spanish: "TARDE"],
        "Custom": [.english: "Custom", .spanish: "Personalizado"],
        "CUSTOM": [.english: "CUSTOM", .spanish: "PERSONALIZADO"],

        // Call Sheet Form Fields & Headers
        "General Call & Schedule": [.english: "General Call & Schedule", .spanish: "General y Horarios"],
        "Weather": [.english: "Weather", .spanish: "Clima"],
        "Locations": [.english: "Locations", .spanish: "Locaciones"],
        "Cast": [.english: "Cast", .spanish: "Personajes"],
        "Crew": [.english: "Crew", .spanish: "Equipo Técnico"],
        "General Notes": [.english: "General Notes", .spanish: "Observaciones Generales"],
        "General Call (12h)": [.english: "General Call (12h)", .spanish: "Citación General (12h)"],
        "Estimated Schedule": [.english: "Estimated Schedule", .spanish: "Horario Estimado de Rodaje"],
        "Quote of the day": [.english: "Quote of the day", .spanish: "Frase del día"],
        "Milestones & Meal Times (12h format)": [.english: "Milestones & Meal Times (12h format)", .spanish: "Hitos y Horarios de Comida"],
        "Ready to Shoot (On Set):": [.english: "Ready to Shoot (On Set):", .spanish: "Listos en Set:"],
        "Lunch:": [.english: "Lunch:", .spanish: "Almuerzo:"],
        "Snack:": [.english: "Snack:", .spanish: "Merienda:"],
        "Wrap:": [.english: "Wrap:", .spanish: "Fin / Cena:"],
        "Nearest Hospital": [.english: "Nearest Hospital", .spanish: "Hospital Más Cercano"],
        "Weather Forecast & Sun Times": [.english: "Weather Forecast & Sun Times", .spanish: "Pronóstico del Tiempo y Sol"],
        "Temperature:": [.english: "Temperature:", .spanish: "Temperatura:"],
        "Sky Condition:": [.english: "Sky Condition:", .spanish: "Estado del Cielo:"],
        "Precipitation & Wind:": [.english: "Precipitation & Wind:", .spanish: "Lluvia y Viento:"],
        "Sunrise / Sunset:": [.english: "Sunrise / Sunset:", .spanish: "Salida / Puesta del Sol:"],
        "Basecamp Location / Address": [.english: "Basecamp Location / Address", .spanish: "Ubicación / Dirección del Basecamp"],
        "Today's Shooting Locations": [.english: "Today's Shooting Locations", .spanish: "Locaciones de Rodaje de Hoy"],
        "+ Add from Roster": [.english: "+ Add from Roster", .spanish: "+ Añadir del Listado"],
        "CHARACTER": [.english: "CHARACTER", .spanish: "PERSONAJE"],
        "ACTOR": [.english: "ACTOR", .spanish: "ACTOR / ACTRIZ"],
        "STATUS": [.english: "STATUS", .spanish: "ESTADO"],
        "PICK UP": [.english: "PICK UP", .spanish: "RECOGIDA"],
        "H/MU": [.english: "H/MU & WARDROBE", .spanish: "MAQ. Y VEST."],
        "ON SET": [.english: "ON SET", .spanish: "EN SET"],
        "DEPARTMENT / ROLE": [.english: "DEPARTMENT / ROLE", .spanish: "DEPARTAMENTO / ROL"],
        "NAME": [.english: "NAME", .spanish: "NOMBRE"],
        "CALL TIME": [.english: "CALL TIME", .spanish: "HORA CITACIÓN"],
        "PHONE": [.english: "PHONE", .spanish: "TELÉFONO"],

        // Sort Options
        "Show Order": [.english: "Show Order", .spanish: "Orden del Guión"],
        "Default": [.english: "Default", .spanish: "Por Defecto"],
        "Location": [.english: "Location", .spanish: "Locación"],
        "INT/EXT": [.english: "INT/EXT", .spanish: "INT/EXT"],

        // Actions & Sidebar
        "Save": [.english: "Save", .spanish: "Guardar"],
        "Cancel": [.english: "Cancel", .spanish: "Cancelar"],
        "Done": [.english: "Done", .spanish: "Listo"],
        "Close": [.english: "Close", .spanish: "Cerrar"],
        "Clear All": [.english: "Clear All", .spanish: "Limpiar Todo"],
        "Apply": [.english: "Apply", .spanish: "Aplicar"],
        "Select Date Range": [.english: "Select Date Range", .spanish: "Seleccionar Rango de Fechas"],
        "Start Date": [.english: "Start Date", .spanish: "Fecha de Inicio"],
        "End Date": [.english: "End Date", .spanish: "Fecha de Fin"],
        "Shift Schedule": [.english: "Shift Schedule", .spanish: "Desplazar Calendario"],
        "Update Calendar": [.english: "Update Calendar", .spanish: "Actualizar Calendario"],
        "Go to Shoot": [.english: "Go to Shoot", .spanish: "Ir al Rodaje"],
        "Today": [.english: "Today", .spanish: "Hoy"],
        "Previous Month": [.english: "Previous Month", .spanish: "Mes Anterior"],
        "Next Month": [.english: "Next Month", .spanish: "Mes Siguiente"],
        "Export Month (PDF)": [.english: "Export Month (PDF)", .spanish: "Exportar Mes (PDF)"],
        "Mark as Shoot Day": [.english: "Mark as Shoot Day", .spanish: "Marcar como Día de Rodaje"],
        "Unavailable": [.english: "Unavailable", .spanish: "No Disponible"],

        // Calendar & Stripboard totals
        "Total:": [.english: "Total:", .spanish: "Total:"],
        "Est:": [.english: "Est:", .spanish: "Est:"],
        "pgs": [.english: "pgs", .spanish: "págs"],
        "pgs.": [.english: "pgs.", .spanish: "págs."],
        "scn": [.english: "scn", .spanish: "esc"],
        "END OF DAY #": [.english: "END OF DAY #", .spanish: "FIN DE DÍA #"],
        "Total Pages:": [.english: "Total Pages:", .spanish: "Páginas Totales:"],
        "Est. Time:": [.english: "Est. Time:", .spanish: "Tiempo Est.:"],
        "Day": [.english: "Day", .spanish: "Día"],
        "of": [.english: "of", .spanish: "de"],
        "Shoot Days:": [.english: "Shoot Days:", .spanish: "Días de Rodaje:"],

        // Legend
        "Color Legend": [.english: "Color Legend", .spanish: "Leyenda de Colores"],

        // PDF and Shooting Schedule Localization
        "SHOOTING SCHEDULE": [.english: "SHOOTING SCHEDULE", .spanish: "PLAN DE RODAJE"],
        "PLAN DE RODAJE": [.english: "SHOOTING SCHEDULE", .spanish: "PLAN DE RODAJE"],
        "PAGE": [.english: "PAGE", .spanish: "PÁGINA"],
        "EMISSION:": [.english: "DATE:", .spanish: "EMISIÓN:"],
        "SHOOT DAY #": [.english: "SHOOT DAY #", .spanish: "DÍA DE RODAJE #"],
        "CREW CALL:": [.english: "CREW CALL:", .spanish: "LLEGADA:"],
        "SET:": [.english: "SET:", .spanish: "SET:"],
        "CREW CALL": [.english: "CREW CALL", .spanish: "LLEGADA DEL EQUIPO"],
        "SET CALL": [.english: "SET CALL", .spanish: "INICIO DE RODAJE"],
        "LUNCH": [.english: "LUNCH", .spanish: "ALMUERZO"],
        "SNACK": [.english: "SNACK", .spanish: "MERIENDA"],
        "DINNER": [.english: "DINNER", .spanish: "CENA"],
        "NOTICE": [.english: "NOTICE", .spanish: "AVISO"],
        "WRAP:": [.english: "WRAP:", .spanish: "FIN DE JORNADA:"],
        "TOTAL PAGES:": [.english: "TOTAL PAGES:", .spanish: "TOTAL PÁGINAS:"],
        "TOTAL TIME:": [.english: "EST. TIME:", .spanish: "TIEMPO EST.:"],
        "Pg.": [.english: "Pg.", .spanish: "Pág."],
        "pág": [.english: "pgs", .spanish: "pág"],

        // Quick Time Edit Sheet Localization
        "Set Shooting Time": [.english: "Set Shooting Time", .spanish: "Ajustar Horario de Rodaje"],
        "Ajustar Horario de Rodaje": [.english: "Set Shooting Time", .spanish: "Ajustar Horario de Rodaje"],
        "STRIP / SCENE:": [.english: "STRIP / SCENE:", .spanish: "TIRA / ESCENA:"],
        "TIME MODE:": [.english: "TIME MODE:", .spanish: "MODO DE HORARIO:"],
        "Automatic Cascade (by order)": [.english: "Automatic Cascade (by order)", .spanish: "Automático en Cascada (según orden)"],
        "Fixed Time (e.g. 11:00 AM)": [.english: "Fixed Time (e.g. 11:00 AM)", .spanish: "Hora Fija Anclada (ej. 11:00 AM)"],
        "Start Time:": [.english: "Start Time:", .spanish: "Hora Inicio:"],
        "ESTIMATED DURATION:": [.english: "ESTIMATED DURATION:", .spanish: "DURACIÓN ESTIMADA:"],
        "SCHEDULE PREVIEW:": [.english: "SCHEDULE PREVIEW:", .spanish: "VISTA PREVIA DEL HORARIO:"],
        "Save Schedule": [.english: "Save Schedule", .spanish: "Guardar Horario"],
        "Delete Banner": [.english: "Delete Banner", .spanish: "Eliminar Tira"],
        "Set Time...": [.english: "Set Time...", .spanish: "Ajustar Horario..."]
    ]

    return dict[key]?[lang] ?? key
}
