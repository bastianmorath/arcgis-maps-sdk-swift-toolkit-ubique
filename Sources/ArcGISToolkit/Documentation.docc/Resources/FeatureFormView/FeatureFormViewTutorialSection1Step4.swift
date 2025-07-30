struct FeatureFormExampleView: View {
    /// Tables with local edits that need to be applied.
    @State private var editedTables = [ServiceFeatureTable]()
    /// A Boolean value indicating whether edits are being applied.
    @State private var editsAreBeingApplied = false
    /// The presented feature form.
    @State private var featureForm: FeatureForm?
    /// A Boolean value indicating whether the form is presented.
    @State private var featureFormViewIsPresented = false
    /// The point on the screen the user tapped on to identify a feature.
    @State private var identifyScreenPoint: CGPoint?
    /// The `Map` displayed in the `MapView`.
    @State private var map = Map(url: .sampleData)!
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, _ in
                    identifyScreenPoint = screenPoint
                }
                .sheet(isPresented: $featureFormViewIsPresented) {
                    featureForm = nil
                } content: {
                    featureFormView
                }
                .task(id: identifyScreenPoint) {
                    guard !editsAreBeingApplied,
                          let identifyScreenPoint else { return }
                    await makeFeatureForm(point: identifyScreenPoint, mapView: mapView)
                }
        }
    }
}

extension FeatureFormExampleView {
    /// An error encountered while submitting edits.
    enum SubmissionError: LocalizedError {
        case anyError(any Error)
        case other(String)
        
        var errorDescription: String? {
            switch self {
            case .anyError(let error):
                error.localizedDescription
            case .other(let message):
                message
            }
        }
    }
    
    // MARK: Methods
    
    /// Applies edits to the service feature table or geodatabase.
    private func applyEdits() async throws(SubmissionError) {
        editsAreBeingApplied = true
        defer { editsAreBeingApplied = false }
        
        for table in editedTables {
            guard editedTables.contains(where: { $0 === table }) else {
                // Edits to this table were already batch-applied to the
                // geodatabase in a previous iteration.
                break
            }
            guard let database = table.serviceGeodatabase else {
                throw .other("No geodatabase found.")
            }
            guard database.hasLocalEdits else {
                throw .other("No database edits found.")
            }
            do {
                let makeSubmissionError: (_ errors: [Error]) -> SubmissionError = { errors in
                    .other("Apply edits returned ^[\(errors.count) error](inflect: true).")
                }
                if database.serviceInfo?.canUseServiceGeodatabaseApplyEdits ?? false {
                    let featureTableEditResults = try await database.applyEdits()
                    let resultErrors = featureTableEditResults.flatMap(\.editResults.errors)
                    guard resultErrors.isEmpty else {
                        throw makeSubmissionError(resultErrors)
                    }
                    editedTables.removeAll { $0.serviceGeodatabase === database }
                } else {
                    let featureEditResults = try await table.applyEdits()
                    let resultErrors = featureEditResults.errors
                    guard resultErrors.isEmpty else {
                        throw makeSubmissionError(resultErrors)
                    }
                    editedTables.removeAll { $0 === table }
                }
            } catch {
                throw .anyError(error)
            }
        }
    }
    
    /// Opens a form for the first feature found at the point on the map.
    /// - Parameters:
    ///   - point: The point to run identify at on the map view.
    ///   - mapView: The map view to identify on.
    private func makeFeatureForm(point: CGPoint, mapView: MapViewProxy) async {
        let identifyLayerResults = try? await mapView.identifyLayers(
            screenPoint: point,
            tolerance: 10
        )
        if let geoElements = identifyLayerResults?.first?.geoElements,
           let feature = geoElements.first as? ArcGISFeature {
            featureForm = FeatureForm(feature: feature)
            featureFormViewIsPresented = true
        }
    }
    
    // MARK: Properties
    
    /// The feature form view shown in the sheet over the map.
    private var featureFormView: some View {
        let featureForm = featureForm!
        return FeatureFormView(root: featureForm, isPresented: $featureFormViewIsPresented)
            .onFormEditingEvent { editingEvent in
                if case .savedEdits = editingEvent,
                   let table = featureForm.feature.table as? ServiceFeatureTable,
                   !editedTables.contains(where: { $0 === table }) {
                    editedTables.append(table)
                }
            }
    }
}

private extension Array where Element == FeatureEditResult {
    ///  Any errors from the edit results and their inner attachment results.
    var errors: [Error] {
        compactMap(\.error) + flatMap { $0.attachmentResults.compactMap(\.error) }
    }
}

private extension URL {
    static var sampleData: Self {
        .init(string: "https://www.arcgis.com/apps/mapviewer/index.html?webmap=f72207ac170a40d8992b7a3507b44fad")!
    }
}
