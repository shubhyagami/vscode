# ⚡ Original VS Code (Code-Server) + Java JDK + Database Sync for Render

This is the **authentic, full-featured Visual Studio Code** running in the cloud via official **`code-server`** (by Coder). It includes a complete **Java 17 JDK & Maven environment**, integrated Linux bash shell, and **automatic database persistence** to your public link.

---

## 🌟 Features

- 🖥️ **Original VS Code Experience**: Real VS Code interface, full settings, keybindings, and extension marketplace.
- ☕ **Complete Java Development Environment**: Pre-installed `default-jdk` (OpenJDK) and `maven`. Compile and run Java code directly in the integrated terminal with `javac` and `java`.
- 💾 **Automatic Database Persistence**: An integrated background daemon (`sync-daemon.js`) watches your workspace and automatically synchronizes all saves, creations, and deletions to your database public link.
- 🛠️ **CLI Sync Tool**: Built-in terminal command `sync-db` (`sync-db status`, `sync-db pull`, `sync-db push`).
- ☁️ **Render-Ready Dockerfile**: Automatically binds to Render's dynamic `$PORT`, disables telemetry, and tunes JVM memory flags (`-XX:MaxRAMPercentage=70.0`) to avoid OOM crashes on Render.
- 🔒 **Optional Password Protection**: Secure your cloud IDE with a password via the `PASSWORD` environment variable.

---

## 🚀 How to Deploy to Render (Step-by-Step)

### Step 1: Push this directory to a new GitHub repository
Open PowerShell or bash in this directory:
```powershell
cd d:\portfolio\coder\code-server
git init
git add .
git commit -m "Deploy Code-Server with Java and Database Sync"
git branch -M main
git remote add origin thisRepo
git push -u origin main
```

### Step 2: Create a Web Service on Render
1. Go to [dashboard.render.com](https://dashboard.render.com).
2. Click **New +** -> **Web Service**.
3. Connect your GitHub repository.
4. Render will automatically detect the **Dockerfile**!
5. Settings:
   - **Environment**: `Docker`
   - **Plan**: `Starter` ($7/mo with 512MB–1GB RAM recommended for Java + Code-Server, or Free)

### Step 3: Configure Environment Variables
Under **Environment Variables**, add:
- `DATABASE_PUBLIC_URL`: Paste your public database link (e.g. `https://my-backend.example.com/api` or database endpoint).
- `DATABASE_API_KEY`: (Optional) Your API key or bearer token.
- `PASSWORD`: (Optional) A secret password to log in. Leave empty for direct access.

Click **Create Web Service**. Render will build the Docker container and provide your live link (e.g. `https://your-service.onrender.com`).

---

## ☕ Working with Java in VS Code

Inside the integrated VS Code terminal (`Ctrl + \``):

1. Check Java and Maven versions:
   ```bash
   java -version
   javac -version
   mvn -version
   ```

2. Compile and run the included starter program:
   ```bash
   javac src/Main.java
   java -cp src Main
   ```

---

## 💾 Database Persistence & CLI Commands

Every time you edit or save a file in VS Code (`Ctrl + S`), the background sync daemon automatically pushes the changes to your `DATABASE_PUBLIC_URL`.

You also have a dedicated CLI tool in the VS Code terminal:

- **Check sync status and database latency**:
  ```bash
  sync-db status
  ```

- **Force pull all files from database**:
  ```bash
  sync-db pull
  ```

- **Force push all current workspace files to database**:
  ```bash
  sync-db push
  ```

---

## 🐳 Testing Locally with Docker (Optional)

If you have Docker running locally:
```bash
docker build -t my-code-server .
docker run -p 8080:8080 -e PASSWORD=mysecret my-code-server
```
Then visit `http://localhost:8080`.
