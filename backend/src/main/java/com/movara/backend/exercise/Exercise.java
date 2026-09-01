package com.movara.backend.exercise;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "exercises")
public class Exercise {

    @Id
    private String id;

    @Indexed(unique = true)
    private String name;

    /** Loose grouping, e.g. "Chest", "Legs", "Cardio". Optional. */
    private String category;

    public Exercise() {
    }

    public Exercise(String name, String category) {
        this.name = name;
        this.category = category;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }
}
