package com.movara.backend.exercise;

import java.util.Optional;

import org.springframework.data.mongodb.repository.MongoRepository;

public interface ExerciseRepository extends MongoRepository<Exercise, String> {
    Optional<Exercise> findByNameIgnoreCase(String name);
}
