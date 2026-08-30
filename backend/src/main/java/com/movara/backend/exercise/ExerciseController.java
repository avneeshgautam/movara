package com.movara.backend.exercise;

import java.util.List;

import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ExerciseController {

    private final ExerciseRepository exerciseRepository;

    public ExerciseController(ExerciseRepository exerciseRepository) {
        this.exerciseRepository = exerciseRepository;
    }

    @GetMapping("/api/exercises")
    public List<Exercise> listExercises() {
        return exerciseRepository.findAll();
    }

    @PostMapping("/api/exercises")
    @ResponseStatus(HttpStatus.CREATED)
    public Exercise createExercise(@RequestBody NewExerciseRequest request) {
        return exerciseRepository.findByNameIgnoreCase(request.name())
                .orElseGet(() -> exerciseRepository.save(new Exercise(request.name(), request.category())));
    }

    public record NewExerciseRequest(@NotBlank String name, String category) {
    }
}
