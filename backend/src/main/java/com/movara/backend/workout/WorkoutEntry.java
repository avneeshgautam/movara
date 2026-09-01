package com.movara.backend.workout;

import java.time.LocalDate;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * One logged unit of work: "N sets of M reps" of a given exercise,
 * optionally with a weight, on a given day.
 *
 * The exercise is stored denormalized as a plain name rather than a
 * reference: MongoDB has no SQL-style joins, and the API already identifies
 * exercises by name. The `exercises` collection is kept separately just to
 * back the autocomplete list.
 */
@Document(collection = "workout_entries")
public class WorkoutEntry {

    @Id
    private String id;

    private String exerciseName;

    private int sets;

    private int reps;

    /** Weight per rep, in kg. Optional (e.g. bodyweight exercises). */
    private Double weightKg;

    private LocalDate performedAt;

    private String notes;

    public WorkoutEntry() {
    }

    public WorkoutEntry(String exerciseName, int sets, int reps, Double weightKg, LocalDate performedAt, String notes) {
        this.exerciseName = exerciseName;
        this.sets = sets;
        this.reps = reps;
        this.weightKg = weightKg;
        this.performedAt = performedAt;
        this.notes = notes;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getExerciseName() {
        return exerciseName;
    }

    public void setExerciseName(String exerciseName) {
        this.exerciseName = exerciseName;
    }

    public int getSets() {
        return sets;
    }

    public void setSets(int sets) {
        this.sets = sets;
    }

    public int getReps() {
        return reps;
    }

    public void setReps(int reps) {
        this.reps = reps;
    }

    public Double getWeightKg() {
        return weightKg;
    }

    public void setWeightKg(Double weightKg) {
        this.weightKg = weightKg;
    }

    public LocalDate getPerformedAt() {
        return performedAt;
    }

    public void setPerformedAt(LocalDate performedAt) {
        this.performedAt = performedAt;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }
}
