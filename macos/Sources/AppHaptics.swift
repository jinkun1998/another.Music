import Foundation
import AppKit

/// Centralized macOS trackpad haptic feedback engine using NSHapticFeedbackManager.
/// Automatically provides Force Touch trackpad tactile clicks, detents, and pulses.
public enum AppHaptics {
    /// Standard subtle notch/detent tick (e.g. for timeline steps, volume increments)
    public static func tick() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .now
        )
    }

    /// Snap / boundary alignment click (e.g. hitting 0% / 100%, 0:00, track end, like button latch, seek commit)
    public static func alignment() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
    }

    /// Distinct level change step / click (e.g. dice slot ticks, volume 5% notches, skip buttons, mode toggles)
    public static func levelChange() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
    }

    /// Celebratory double pulse (e.g. winning the dice roll / landing on target track)
    public static func win() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .levelChange,
                performanceTime: .now
            )
        }
    }
}
