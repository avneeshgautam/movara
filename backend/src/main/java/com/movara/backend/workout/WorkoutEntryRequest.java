package com.movara.backend.workout;

import java.time.LocalDate;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Payload the Flutter app sends when logging a set. The exercise is
 * identified by name so the client doesn't need to manage exercise IDs;
 * an unknown name is created on the fly.
 */
public record WorkoutEntryRequest(
        @NotBlank String exerciseName,
        @Min(1) int sets,
        @Min(1) int reps,
        Double weightKg,
        @NotNull LocalDate performedAt,
        String notes
) {
}
