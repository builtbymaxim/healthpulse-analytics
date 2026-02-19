//
//  FoodClassificationService.swift
//  HealthPulse
//
//  On-device food classification using CoreML Food-101 model.
//  Provides instant (<100ms) food identification without cloud API calls.
//

import Foundation
import CoreML
import Vision
import UIKit

class FoodClassificationService {
    static let shared = FoodClassificationService()

    private var model: VNCoreMLModel?

    private init() {
        loadModel()
    }

    private func loadModel() {
        guard let modelURL = Bundle.main.url(forResource: "Food101", withExtension: "mlmodelc") else {
            print("Food101 CoreML model not found in bundle — AI scan will use cloud fallback")
            return
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
            model = try VNCoreMLModel(for: mlModel)
        } catch {
            print("Failed to load Food101 CoreML model: \(error)")
        }
    }

    /// Whether the CoreML model is available for classification.
    var isAvailable: Bool { model != nil }

    /// Classify foods in a UIImage. Returns top N classifications above threshold.
    /// - Parameters:
    ///   - image: The food photo to classify
    ///   - maxResults: Maximum number of results to return (default 5)
    ///   - threshold: Minimum confidence threshold (default 0.1)
    /// - Returns: Array of food classifications sorted by confidence
    func classify(image: UIImage, maxResults: Int = 5, threshold: Float = 0.1) async -> [FoodClassification] {
        guard let model = model, let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                guard let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let classifications = results
                    .filter { $0.confidence >= threshold }
                    .prefix(maxResults)
                    .map { obs in
                        FoodClassification(
                            label: obs.identifier,
                            confidence: Double(obs.confidence),
                            displayName: obs.identifier
                                .replacingOccurrences(of: "_", with: " ")
                                .capitalized
                        )
                    }

                continuation.resume(returning: Array(classifications))
            }

            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("CoreML classification failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
}
