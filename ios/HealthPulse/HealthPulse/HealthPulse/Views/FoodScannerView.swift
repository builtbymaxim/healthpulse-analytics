//
//  FoodScannerView.swift
//  HealthPulse
//
//  AI-powered food scanning: camera capture → CoreML classification → USDA/cloud macro lookup → review & log.
//

import SwiftUI
import UIKit
import AVFoundation

// MARK: - Food Scanner View

struct FoodScannerView: View {
    @Environment(\.dismiss) private var dismiss

    enum ScanPhase: Equatable {
        case camera
        case analyzing
        case review
        case error(String)

        static func == (lhs: ScanPhase, rhs: ScanPhase) -> Bool {
            switch (lhs, rhs) {
            case (.camera, .camera), (.analyzing, .analyzing), (.review, .review):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    @State private var phase: ScanPhase = .camera
    @State private var capturedImage: UIImage?
    @State private var classificationHints: [FoodClassification] = []
    @State private var scannedItems: [ScannedFoodItem] = []
    @State private var portionMultipliers: [UUID: Double] = [:]
    @State private var selectedMealType: MealType = .lunch
    @State private var isLogging = false
    @State private var showSuccess = false
    @State private var shouldCapture = false

    var onFoodAdded: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .camera:
                    cameraPhaseView
                case .analyzing:
                    analyzingPhaseView
                case .review:
                    reviewPhaseView
                case .error(let message):
                    errorPhaseView(message)
                }
            }
            .navigationTitle("Scan Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Camera Phase

    private var cameraPhaseView: some View {
        VStack(spacing: 0) {
            Spacer()

            FoodCameraPreview(onPhotoCaptured: { image in
                capturedImage = image
                analyzePhoto(image)
            }, shouldCapture: $shouldCapture)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .frame(maxHeight: .infinity)

            VStack(spacing: 16) {
                Button {
                    shouldCapture = true
                    HapticsManager.shared.medium()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.green, lineWidth: 4)
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)
                    }
                }

                Text("Take a photo of your food")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Analyzing Phase

    private var analyzingPhaseView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            ProgressView("Analyzing your food...")
                .font(.headline)

            if !classificationHints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Detected:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(classificationHints) { hint in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text(hint.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(hint.confidence * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(AppTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Review Phase

    private var reviewPhaseView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Thumbnail
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Items list
                ForEach(scannedItems) { item in
                    scannedFoodItemCard(item)
                }

                if scannedItems.isEmpty {
                    Text("No food items detected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                // Total macros summary
                if !scannedItems.isEmpty {
                    totalsSummary
                }

                // Meal type selector
                mealTypeSelector

                // Log button
                Button {
                    confirmAndLog()
                } label: {
                    HStack {
                        if isLogging {
                            ProgressView().tint(.white)
                        } else if showSuccess {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Logged!")
                        } else {
                            Image(systemName: "plus.circle.fill")
                            Text("Log All Items")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(scannedItems.isEmpty ? Color.gray : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(scannedItems.isEmpty || isLogging || showSuccess)

                // Retake
                Button {
                    resetToCamera()
                } label: {
                    Text("Retake Photo")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                // Detailed scan option
                Button {
                    requestDetailedScan()
                } label: {
                    Label("Detailed AI Scan", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            .padding()
        }
    }

    // MARK: - Error Phase

    private func errorPhaseView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    resetToCamera()
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Log Manually")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: - Components

    private func scannedFoodItemCard(_ item: ScannedFoodItem) -> some View {
        let multiplier = portionMultipliers[item.id] ?? 1.0
        let scaled = item.scaled(by: multiplier)

        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.portionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    scannedItems.removeAll { $0.id == item.id }
                    portionMultipliers.removeValue(forKey: item.id)
                    HapticsManager.shared.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 0) {
                macroItem(value: scaled.calories, label: "Cal", color: .orange)
                macroItem(value: scaled.proteinG, label: "Protein", unit: "g", color: .blue)
                macroItem(value: scaled.carbsG, label: "Carbs", unit: "g", color: .yellow)
                macroItem(value: scaled.fatG, label: "Fat", unit: "g", color: .purple)
            }

            // Portion slider
            HStack {
                Text("Portion:")
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { portionMultipliers[item.id] ?? 1.0 },
                        set: { portionMultipliers[item.id] = $0 }
                    ),
                    in: 0.25...3.0,
                    step: 0.25
                )
                Text("\(Int(multiplier * 100))%")
                    .font(.caption.bold())
                    .frame(width: 44)
            }
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var totalsSummary: some View {
        let totals = scannedItems.reduce((cal: 0.0, p: 0.0, c: 0.0, f: 0.0)) { acc, item in
            let m = portionMultipliers[item.id] ?? 1.0
            return (
                acc.cal + item.calories * m,
                acc.p + item.proteinG * m,
                acc.c + item.carbsG * m,
                acc.f + item.fatG * m
            )
        }

        return VStack(spacing: 8) {
            Text("Total")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                macroItem(value: totals.cal, label: "Cal", color: .orange)
                macroItem(value: totals.p, label: "Protein", unit: "g", color: .blue)
                macroItem(value: totals.c, label: "Carbs", unit: "g", color: .yellow)
                macroItem(value: totals.f, label: "Fat", unit: "g", color: .purple)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var mealTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(MealType.allCases, id: \.self) { meal in
                    Button {
                        selectedMealType = meal
                        HapticsManager.shared.selection()
                    } label: {
                        Text(meal.displayName)
                            .font(.subheadline.bold())
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(selectedMealType == meal ? Color.green : AppTheme.surface2)
                            .foregroundStyle(selectedMealType == meal ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func macroItem(value: Double, label: String, unit: String = "", color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(value))\(unit)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func analyzePhoto(_ image: UIImage) {
        withAnimation { phase = .analyzing }

        Task {
            // Step 1: On-device CoreML classification (instant)
            let hints = await FoodClassificationService.shared.classify(image: image)
            withAnimation { classificationHints = hints }

            // Step 2: Decide path based on confidence
            if let topHint = hints.first, topHint.confidence >= 0.7 {
                // High confidence → USDA lookup (free, fast)
                await lookupUSDAForHints(hints)
            } else if !hints.isEmpty {
                // Low confidence → try cloud API with hints
                await cloudScan(image: image, hints: hints)
            } else {
                // No CoreML results → try cloud API without hints
                await cloudScan(image: image, hints: [])
            }
        }
    }

    private func lookupUSDAForHints(_ hints: [FoodClassification]) async {
        var items: [ScannedFoodItem] = []

        for hint in hints.prefix(5) {
            do {
                let foods = try await APIService.shared.lookupUSDAFood(query: hint.label.replacingOccurrences(of: "_", with: " "))
                if let food = foods.first {
                    var item = food.toScannedFoodItem()
                    // Use the CoreML display name for a friendlier label
                    item.name = hint.displayName
                    item.confidence = hint.confidence
                    items.append(item)
                }
            } catch {
                // If USDA lookup fails for an item, create a placeholder
                items.append(ScannedFoodItem(
                    id: UUID(),
                    name: hint.displayName,
                    portionDescription: "Estimated portion",
                    portionGrams: 100,
                    calories: 0,
                    proteinG: 0,
                    carbsG: 0,
                    fatG: 0,
                    fiberG: 0,
                    confidence: hint.confidence
                ))
            }
        }

        await MainActor.run {
            scannedItems = items
            for item in items {
                portionMultipliers[item.id] = 1.0
            }
            HapticsManager.shared.success()
            withAnimation { phase = .review }
        }
    }

    private func cloudScan(image: UIImage, hints: [FoodClassification]) async {
        // Compress and encode image
        guard let resized = resizeImage(image, maxDimension: 1024),
              let jpegData = resized.jpegData(compressionQuality: 0.7) else {
            await MainActor.run {
                if !hints.isEmpty {
                    // Fallback: use CoreML hints with placeholder macros
                    scannedItems = hints.map { hint in
                        ScannedFoodItem(
                            id: UUID(),
                            name: hint.displayName,
                            portionDescription: "Estimated portion",
                            portionGrams: 100,
                            calories: 0, proteinG: 0, carbsG: 0,
                            fatG: 0, fiberG: 0, confidence: hint.confidence
                        )
                    }
                    for item in scannedItems { portionMultipliers[item.id] = 1.0 }
                    withAnimation { phase = .review }
                } else {
                    withAnimation { phase = .error("Failed to process image") }
                }
            }
            return
        }

        let base64 = jpegData.base64EncodedString()

        do {
            let response = try await APIService.shared.scanFood(
                imageBase64: base64,
                classificationHints: hints.map(\.label)
            )
            await MainActor.run {
                scannedItems = response.items
                for item in response.items { portionMultipliers[item.id] = 1.0 }
                HapticsManager.shared.success()
                withAnimation { phase = .review }
            }
        } catch {
            await MainActor.run {
                HapticsManager.shared.error()
                if !hints.isEmpty {
                    // Fallback: use hints with USDA lookup
                    Task { await lookupUSDAForHints(hints) }
                } else {
                    withAnimation { phase = .error("Could not analyze food.\nPlease try again or log manually.") }
                }
            }
        }
    }

    private func requestDetailedScan() {
        guard let image = capturedImage else { return }
        withAnimation { phase = .analyzing }
        Task {
            await cloudScan(image: image, hints: classificationHints)
        }
    }

    private func confirmAndLog() {
        isLogging = true
        Task {
            do {
                for item in scannedItems {
                    let multiplier = portionMultipliers[item.id] ?? 1.0
                    let scaled = item.scaled(by: multiplier)
                    let entry = FoodEntryCreate(
                        name: scaled.name,
                        mealType: selectedMealType,
                        calories: scaled.calories,
                        proteinG: scaled.proteinG,
                        carbsG: scaled.carbsG,
                        fatG: scaled.fatG,
                        fiberG: scaled.fiberG,
                        servingSize: scaled.portionGrams,
                        servingUnit: "g",
                        notes: "AI food scan",
                        source: "ai_scan"
                    )
                    _ = try await APIService.shared.logFood(entry)
                }
                HapticsManager.shared.success()
                showSuccess = true
                onFoodAdded?()
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } catch {
                HapticsManager.shared.error()
                isLogging = false
            }
        }
    }

    private func resetToCamera() {
        capturedImage = nil
        classificationHints = []
        scannedItems = []
        portionMultipliers = [:]
        showSuccess = false
        isLogging = false
        withAnimation { phase = .camera }
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
}

// MARK: - Camera Preview (Photo Capture)

struct FoodCameraPreview: UIViewRepresentable {
    let onPhotoCaptured: (UIImage) -> Void
    @Binding var shouldCapture: Bool

    func makeUIView(context: Context) -> FoodCameraUIView {
        let view = FoodCameraUIView()
        view.onPhotoCaptured = onPhotoCaptured
        return view
    }

    func updateUIView(_ uiView: FoodCameraUIView, context: Context) {
        if shouldCapture {
            uiView.capturePhoto()
            DispatchQueue.main.async { shouldCapture = false }
        }
    }
}

class FoodCameraUIView: UIView, AVCapturePhotoCaptureDelegate {
    var onPhotoCaptured: ((UIImage) -> Void)?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showPlaceholder()
            return
        }

        session.addInput(input)

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func showPlaceholder() {
        backgroundColor = UIColor.secondarySystemBackground
        let label = UILabel()
        label.text = "Camera not available"
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        captureSession?.stopRunning()
        DispatchQueue.main.async { [weak self] in
            self?.onPhotoCaptured?(image)
        }
    }

    deinit {
        captureSession?.stopRunning()
    }
}
