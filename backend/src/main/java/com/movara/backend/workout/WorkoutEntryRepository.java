package com.movara.backend.workout;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkoutEntryRepository extends JpaRepository<WorkoutEntry, Long> {
    List<WorkoutEntry> findByPerformedAtOrderByIdDesc(LocalDate performedAt);

    List<WorkoutEntry> findAllByOrderByPerformedAtDescIdDesc();
}
