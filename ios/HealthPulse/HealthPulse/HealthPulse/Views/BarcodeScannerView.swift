//
//  BarcodeScannerView.swift
//  HealthPulse
//
//  Camera barcode scanning with Open Food Facts product lookup
//

import SwiftUI
import AVFoundation

// MARK: - Barcode Scanner View

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedBarcode: String?
    @State private var product: BarcodeProduct?
    @State private var isLookingUp = false
    @State private var notFound = false
    @State private var manualBarcode = ""
    @State private var showManualEntry = false

    // Food log fields (shown after product found)
    @State private var amount: Double = 100
    @State private var selectedMealType = "snack"
    @State private var isAdding = false
    @State private var showSuccess = false

    var onFoodAdded: (() -> Void)?

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    private let amountOptions: [Double] = [50, 100, 150, 200, 250]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let product, product.found {
                    // Product found — show details + log form
                    productDetailView(product)
                } else {
                    // Scanner / manual entry
                    scannerSection
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Scanner Section

    private var scannerSection: some View {
        VStack(spacing: 20) {
            // Camera viewfinder
            ZStack {
                CameraPreview(onBarcodeDetected: { barcode in
                    guard scannedBarcode == nil, !isLookingUp else { return }
                    scannedBarcode = barcode
                    HapticsManager.shared.medium()
                    lookupBarcode(barcode)
                })
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Scan overlay
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 250, height: 120)

                if isLookingUp {
                    Color.black.opacity(0.5)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Looking up product...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 300)
            .padding(.horizontal)

            if notFound {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Product not found")
                        .font(.headline)
                    Text("Try scanning again or enter manually")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Scan Again") {
                        scannedBarcode = nil
                        notFound = false
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                }
                .padding()
            }

            // Manual barcode entry
            VStack(spacing: 8) {
                Button {
                    showManualEntry.toggle()
                } label: {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Enter barcode manually")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.green)
                }

                if showManualEntry {
                    HStack {
                        TextField("Barcode number", text: $manualBarcode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)

                        Button("Lookup") {
                            guard !manualBarcode.isEmpty else { return }
                            lookupBarcode(manualBarcode)
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .clipShape(Capsule())
                        .disabled(manualBarcode.isEmpty || isLookingUp)
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()
        }
        .padding(.top, 16)
    }

    // MARK: - Product Detail View

    private func productDetailView(_ product: BarcodeProduct) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Product info card
                VStack(spacing: 12) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    Text(product.name ?? "Unknown Product")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)

                    // Macros per 100g
                    Text("Per 100g")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 0) {
                        macroItem(value: product.caloriesPer100g, label: "Calories", color: .orange)
                        macroItem(value: product.proteinGPer100g, label: "Protein", unit: "g", color: .blue)
                        macroItem(value: product.carbsGPer100g, label: "Carbs", unit: "g", color: .yellow)
                        macroItem(value: product.fatGPer100g, label: "Fat", unit: "g", color: .purple)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Amount selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount (grams)")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack(spacing: 8) {
                        ForEach(amountOptions, id: \.self) { opt in
                            Button {
                                amount = opt
                                HapticsManager.shared.selection()
                            } label: {
                                Text("\(Int(opt))g")
                                    .font(.subheadline.bold())
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(amount == opt ? Color.green : Color(.secondarySystemBackground))
                                    .foregroundStyle(amount == opt ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Computed totals
                VStack(spacing: 8) {
                    Text("Your portion (\(Int(amount))g)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    let multiplier = amount / 100.0
                    HStack(spacing: 0) {
                        macroItem(value: product.caloriesPer100g * multiplier, label: "Cal", color: .orange)
                        macroItem(value: product.proteinGPer100g * multiplier, label: "Protein", unit: "g", color: .blue)
                        macroItem(value: product.carbsGPer100g * multiplier, label: "Carbs", unit: "g", color: .yellow)
                        macroItem(value: product.fatGPer100g * multiplier, label: "Fat", unit: "g", color: .purple)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Meal type selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meal")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack(spacing: 8) {
                        ForEach(mealTypes, id: \.self) { type in
                            Button {
                                selectedMealType = type
                                HapticsManager.shared.selection()
                            } label: {
                                Text(type.capitalized)
                                    .font(.subheadline.bold())
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedMealType == type ? Color.green : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedMealType == type ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Add button
                Button {
                    addToFoodLog(product)
                } label: {
                    HStack {
                        if isAdding {
                            ProgressView().tint(.white)
                        } else if showSuccess {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Added!")
                        } else {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Food Log")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isAdding || showSuccess)
                .padding(.horizontal)

                // Scan another
                Button {
                    self.product = nil
                    scannedBarcode = nil
                    notFound = false
                } label: {
                    Text("Scan Another Product")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical)
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

    private func lookupBarcode(_ barcode: String) {
        isLookingUp = true
        notFound = false
        Task {
            do {
                let result = try await APIService.shared.lookupBarcode(barcode)
                if result.found {
                    product = result
                } else {
                    notFound = true
                }
            } catch {
                notFound = true
            }
            isLookingUp = false
        }
    }

    private func addToFoodLog(_ product: BarcodeProduct) {
        isAdding = true
        let multiplier = amount / 100.0
        Task {
            do {
                let entry = FoodEntryCreate(
                    name: product.displayName,
                    mealType: selectedMealType,
                    calories: product.caloriesPer100g * multiplier,
                    proteinG: product.proteinGPer100g * multiplier,
                    carbsG: product.carbsGPer100g * multiplier,
                    fatG: product.fatGPer100g * multiplier,
                    fiberG: product.fiberGPer100g * multiplier,
                    servingSize: amount,
                    servingUnit: "g",
                    loggedAt: nil,
                    notes: "Scanned barcode: \(product.barcode)"
                )
                _ = try await APIService.shared.logFood(entry)
                HapticsManager.shared.success()
                showSuccess = true
                onFoodAdded?()
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } catch {
                HapticsManager.shared.error()
                isAdding = false
            }
        }
    }
}

// MARK: - Camera Preview (AVFoundation)

struct CameraPreview: UIViewRepresentable {
    let onBarcodeDetected: (String) -> Void

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.onBarcodeDetected = onBarcodeDetected
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeDetected: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDetected = false

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
        if captureSession == nil {
            setupCamera()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showPlaceholder()
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.addSublayer(preview)
        previewLayer = preview
        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func showPlaceholder() {
        backgroundColor = UIColor.secondarySystemBackground
        let label = UILabel()
        label.text = "Camera not available\nUse manual entry below"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasDetected,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else { return }
        hasDetected = true
        captureSession?.stopRunning()
        onBarcodeDetected?(barcode)
    }

    deinit {
        captureSession?.stopRunning()
    }
}
