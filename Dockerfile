# ==============================================================================
# Production Dockerfile for Code-Server + Java (JDK) on Render
# Based on official codercom/code-server with OpenJDK, Full Permissions & Settings
# ==============================================================================

FROM codercom/code-server:latest

USER root

# Avoid interactive apt prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Java JDK, Maven, Git, Node.js, dumb-init, and essential build utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jdk \
    maven \
    curl \
    git \
    jq \
    nodejs \
    ca-certificates \
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Configure Java Environment
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Prevent Java from crashing Render containers due to memory limits
ENV _JAVA_OPTIONS="-XX:MaxRAMPercentage=70.0 -XX:+UseSerialGC"

# Copy Database Sync Daemon and CLI scripts
COPY sync-daemon.js /home/coder/sync-daemon.js
COPY bin/sync-db /usr/local/bin/sync-db
COPY entrypoint.sh /home/coder/entrypoint.sh
COPY settings.json /home/coder/settings.json

# Pre-create all workspace, user-data, and configuration directories
RUN mkdir -p /home/coder/project/src \
             /home/coder/project/.vscode \
             /home/coder/.local/share/code-server/User \
             /home/coder/.local/share/code-server/extensions \
             /home/coder/.config/code-server

# Install default User & Workspace settings
RUN cp /home/coder/settings.json /home/coder/.local/share/code-server/User/settings.json && \
    cp /home/coder/settings.json /home/coder/project/.vscode/settings.json

# Add starter Java Hello World program
RUN echo 'public class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello from VS Code + Java on Render!");\n        System.out.println("Java version: " + System.getProperty("java.version"));\n    }\n}' > /home/coder/project/src/Main.java && \
    echo '# Welcome to your Cloud VS Code\n\nRun the starter Java code in the terminal:\n```bash\njavac src/Main.java\njava -cp src Main\n```\n\nDatabase persistence is active via `sync-db status`.\n' > /home/coder/project/README.md

# Ensure complete ownership and full read/write/execute permissions for the coder user
RUN chmod +x /home/coder/entrypoint.sh /usr/local/bin/sync-db && \
    chown -R coder:coder /home/coder && \
    chmod -R 775 /home/coder

# Switch to coder user
USER coder
WORKDIR /home/coder/project

# Configure standard XDG environment paths
ENV HOME=/home/coder
ENV XDG_DATA_HOME=/home/coder/.local/share
ENV XDG_CONFIG_HOME=/home/coder/.config
ENV PORT=8080
ENV WORKSPACE_DIR=/home/coder/project

EXPOSE 8080

ENTRYPOINT ["/home/coder/entrypoint.sh"]
