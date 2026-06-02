// Models/MealRecord.swift — NurseryConnectVision

import Foundation
import SwiftData

@Model
final class MealRecord {
    var id: UUID
    var timestamp: Date
    var keyworkerName: String
    var mealType: MealType
    var foodOffered: String
    var foodConsumed: ConsumptionLevel
    var foodNotes: String
    var fluidMl: Int
    var fluidType: String
    var allergenChecked: Bool
    var allergenNotes: String
    /// Child's mood observed during the meal — surfaced in the immersive
    /// stats panel and the dashboard chart.
    var mood: MoodLevel
    var child: Child?

    var fluidDescription: String { "\(fluidMl)ml \(fluidType)" }

    init(
        keyworkerName: String,
        mealType: MealType = .lunch,
        foodOffered: String = "",
        foodConsumed: ConsumptionLevel = .all,
        foodNotes: String = "",
        fluidMl: Int = 0,
        fluidType: String = "Water",
        allergenChecked: Bool = false,
        allergenNotes: String = "",
        mood: MoodLevel = .neutral
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.keyworkerName = keyworkerName
        self.mealType = mealType
        self.foodOffered = foodOffered
        self.foodConsumed = foodConsumed
        self.foodNotes = foodNotes
        self.fluidMl = fluidMl
        self.fluidType = fluidType
        self.allergenChecked = allergenChecked
        self.allergenNotes = allergenNotes
        self.mood = mood
    }
}
