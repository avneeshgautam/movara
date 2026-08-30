package com.movara.backend.exercise;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ExerciseRepository extends JpaRepository<Exercise, Long> {
    Optional<Exercise> findByNameIgnoreCase(String name);
}
