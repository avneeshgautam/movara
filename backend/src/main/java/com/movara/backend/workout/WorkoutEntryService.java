package com.movara.backend.workout;

import java.time.LocalDate;
import java.util.List;

import com.movara.backend.exercise.Exercise;
import com.movara.backend.exercise.ExerciseRepository;
import org.springframework.stereotype.Service;

@Service
public class WorkoutEntryService {

    private final WorkoutEntryRepository workoutEntryRepository;
    private final ExerciseRepository exerciseRepository;

    public WorkoutEntryService(WorkoutEntryRepository workoutEntryRepository, ExerciseRepository exerciseRepository) {
        this.workoutEntryRepository = workoutEntryRepository;
        this.exerciseRepository = exerciseRepository;
    }

    public List<WorkoutEntryResponse> listAll() {
        return workoutEntryRepository.findAllByOrderByPerformedAtDescIdDesc().stream()
                .map(WorkoutEntryResponse::from)
                .toList();
    }

    public List<WorkoutEntryResponse> listForDate(LocalDate date) {
        return workoutEntryRepository.findByPerformedAtOrderByIdDesc(date).stream()
                .map(WorkoutEntryResponse::from)
                .toList();
    }

    public WorkoutEntryResponse create(WorkoutEntryRequest request) {
        // Keep the exercises collection populated for the autocomplete list,
        // but store the name directly on the entry (denormalized).
        Exercise exercise = exerciseRepository.findByNameIgnoreCase(request.exerciseName())
                .orElseGet(() -> exerciseRepository.save(new Exercise(request.exerciseName(), null)));

        WorkoutEntry entry = new WorkoutEntry(
                exercise.getName(),
                request.sets(),
                request.reps(),
                request.weightKg(),
                request.performedAt(),
                request.notes()
        );

        return WorkoutEntryResponse.from(workoutEntryRepository.save(entry));
    }

    public void delete(String id) {
        workoutEntryRepository.deleteById(id);
    }
}
