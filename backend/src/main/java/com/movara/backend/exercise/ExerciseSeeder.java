package com.movara.backend.exercise;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

/** Seeds a few common exercises so the app isn't empty on first run. */
@Component
public class ExerciseSeeder implements CommandLineRunner {

    private final ExerciseRepository exerciseRepository;

    public ExerciseSeeder(ExerciseRepository exerciseRepository) {
        this.exerciseRepository = exerciseRepository;
    }

    @Override
    public void run(String... args) {
        if (exerciseRepository.count() > 0) {
            return;
        }

        exerciseRepository.saveAll(java.util.List.of(
                new Exercise("Push-ups", "Chest"),
                new Exercise("Squats", "Legs"),
                new Exercise("Bench Press", "Chest"),
                new Exercise("Deadlift", "Back"),
                new Exercise("Pull-ups", "Back"),
                new Exercise("Plank", "Core")
        ));
    }
}
