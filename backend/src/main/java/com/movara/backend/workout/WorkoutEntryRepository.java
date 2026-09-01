package com.movara.backend.workout;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;

public interface WorkoutEntryRepository extends MongoRepository<WorkoutEntry, String> {
    List<WorkoutEntry> findByPerformedAtOrderByIdDesc(LocalDate performedAt);

    List<WorkoutEntry> findAllByOrderByPerformedAtDescIdDesc();
}
