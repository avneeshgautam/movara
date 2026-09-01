package com.movara.backend.workout;

import java.time.LocalDate;

public record WorkoutEntryResponse(
        String id,
        String exerciseName,
        int sets,
        int reps,
        Double weightKg,
        LocalDate performedAt,
        String notes
) {
    public static WorkoutEntryResponse from(WorkoutEntry entry) {
        return new WorkoutEntryResponse(
                entry.getId(),
                entry.getExerciseName(),
                entry.getSets(),
                entry.getReps(),
                entry.getWeightKg(),
                entry.getPerformedAt(),
                entry.getNotes()
        );
    }
}
