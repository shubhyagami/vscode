# ==============================================================================
# Production Dockerfile for Code-Server + Java (JDK) on Render
# Based on official codercom/code-server with OpenJDK 17 & Database Sync
# ==============================================================================

FROM codercom/code-server:latest

USER root

# Avoid interactive apt prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Java 17 JDK, Maven, Git, Node.js, and essential build utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk \
    maven \
    curl \
    git \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Configure Java Environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Prevent Java from crashing Render containers due to memory limits
ENV _JAVA_OPTIONS="-XX:MaxRAMPercentage=70.0 -XX:+UseSerialGC"

# Copy Database Sync Daemon and CLI scripts
COPY sync-daemon.js /home/coder/sync-daemon.js
COPY bin/sync-db /usr/local/bin/sync-db
COPY entrypoint.sh /home/coder/entrypoint.sh

# Fix permissions
RUN chmod +x /home/coder/entrypoint.sh /usr/local/bin/sync-db && \
    chown coder:coder /home/coder/sync-daemon.js /home/coder/entrypoint.sh

# Create starter workspace
USER coder
WORKDIR /home/coder/project

# Add starter Java Hello World program
RUN mkdir -p /home/coder/project/src && \
    echo 'public class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello from VS Code + Java on Render!");\n        System.out.println("Java version: " + System.getProperty("java.version"));\n    }\n}' > /home/coder/project/src/Main.java && \
    echo '# Welcome to your Cloud VS Code\n\nRun the starter Java code in the terminal:\n```bash\njavac src/Main.java\njava -cp src Main\n```\n\nDatabase persistence is active via `sync-db status`.\n' > /home/coder/project/README.md

# Render injects PORT dynamically at runtime (defaults to 8080)
ENV PORT=8080
ENV WORKSPACE_DIR=/home/coder/project

EXPOSE 8080

ENTRYPOINT ["/home/coder/entrypoint.sh"]
