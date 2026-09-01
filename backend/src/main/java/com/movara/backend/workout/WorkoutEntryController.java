package com.movara.backend.workout;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class WorkoutEntryController {

    private final WorkoutEntryService workoutEntryService;

    public WorkoutEntryController(WorkoutEntryService workoutEntryService) {
        this.workoutEntryService = workoutEntryService;
    }

    /** Optionally filter with ?date=2026-08-30, otherwise returns everything, newest first. */
    @GetMapping("/api/workout-entries")
    public List<WorkoutEntryResponse> listEntries(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return Optional.ofNullable(date)
                .map(workoutEntryService::listForDate)
                .orElseGet(workoutEntryService::listAll);
    }

    @PostMapping("/api/workout-entries")
    @ResponseStatus(HttpStatus.CREATED)
    public WorkoutEntryResponse createEntry(@Valid @RequestBody WorkoutEntryRequest request) {
        return workoutEntryService.create(request);
    }

    @DeleteMapping("/api/workout-entries/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteEntry(@PathVariable String id) {
        workoutEntryService.delete(id);
    }
}
