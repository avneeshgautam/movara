# ---- build stage ----
# Pinned to JDK 21: Spring Boot 3.3.x targets it, and pinning here means the
# build no longer depends on whatever JDK happens to be on the host.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# Copy the POM alone first so dependency resolution is cached as its own
# layer -- source edits then rebuild without re-downloading the world.
# `|| true`: this layer is a cache warm-up only. go-offline trips over some
# Spring Boot plugin goals, and the package step below re-resolves anything
# it missed -- so a partial cache must not fail the build.
COPY pom.xml .
RUN mvn -B dependency:go-offline || true

COPY src ./src
RUN mvn -B clean package -DskipTests \
    && mv target/backend-*.jar target/app.jar

# ---- runtime stage ----
# JRE only: no compiler or Maven cache in the shipped image.
FROM eclipse-temurin:21-jre
WORKDIR /app

# Run as a non-root user.
RUN useradd --system --create-home --shell /usr/sbin/nologin movara
USER movara

COPY --from=build /build/target/app.jar app.jar

# Render's free plan caps at 512MB. The JVM otherwise sizes its heap against
# the host's total memory and gets OOM-killed, so cap it against the
# container limit instead.
ENV JAVA_OPTS="-XX:MaxRAMPercentage=70 -XX:+UseSerialGC"

# The app reads $PORT (see application.yml); Render injects it at runtime.
EXPOSE 8080

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
