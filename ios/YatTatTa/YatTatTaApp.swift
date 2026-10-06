import SwiftData
import SwiftUI

@main struct YatTatTaApp: App {
    private let container: ModelContainer
    @State private var model: AppModel

    init() {
        do {
            container = try ModelContainer(for: SquatRecord.self)
        } catch {
            fatalError("SwiftData: \(error)")
        }
        let model = AppModel(context: container.mainContext)
        model.feel.start()
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
        }
        .modelContainer(container)
    }
}
