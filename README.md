# Lopilot: Local LLM GUI for Mac (Ollama Client)
<img width="1200" height="809" alt="Screenshot 2026-01-31 at 6 45 39 PM" src="https://github.com/user-attachments/assets/4c1857c8-6920-4d4a-a46c-e7fcfe900824" />

**Lopilot** is an open-source, native macOS **Ollama GUI** built with SwiftUI. It serves as a powerful **Local LLM Client**, allowing you to run Large Language Models like **Llama 3.1**, **DeepSeek R1**, and **Gemma 3** entirely offline for maximum privacy.

> **Note:** This is a native alternative to web-based interfaces, optimized specifically for **Apple Silicon (M1/M2/M3/M4)** performance.

---

## 🚀 Key Features

* **🌐 Native Ollama GUI:** A lightweight, high-performance interface for managing and chatting with local AI models.
* **🧠 Community-Driven Logic:** Optional, anonymous logic sharing to improve model accuracy across the Lopilot ecosystem.
* **📦 Integrated Model Manager:** One-click install/uninstall for **DeepSeek R1**, **Llama 3.1**, and **Mistral**.
* **📂 Local RAG / File Context:** Attach up to 10 source code files (Swift, Python, JS) per message for context-aware coding assistance.
* **🕓 Persistent Chat History:** Local storage of all AI sessions for seamless workflow continuity.

## 🤖 Supported Models

Lopilot connects via **Ollama** to run the industry's best open-weight models:

* **Meta Llama 3.1** (8b to 405b) — *General purpose*
* **DeepSeek R1** (1.5b to 671b) — *High-reasoning model*
* **Google Gemma 3** (1b to 27b) — *Fast & efficient*
* **Mistral & CodeLlama** — *Optimized for developers*

---

## 🛠 Prerequisites & Installation

To use this **Local LLM Mac application**, you need:

1. **macOS 14.0+**
2. **Ollama**: Download the backend engine at [ollama.com](https://ollama.com).

### Quick Start

1. Ensure Ollama is running in your menu bar.
2. Launch Lopilot.
3. Download a model in the **Models** tab (e.g., `llama3.1`).
4. Start chatting!

---

## 💻 Technical Architecture

* **Framework:** SwiftUI (Native Mac Performance).
* **Local API:** Connects to `localhost:11434` (Ollama standard port).
* **Storage:** Local persistence via `UserDefaults` and security-scoped file bookmarks.

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=milestones14/lopilot&type=date&legend=top-left)](https://www.star-history.com/#milestones14/lopilot&type=date&legend=top-left)

## License

This project is licensed under the **Creative Commons Attribution-NoDerivatives 4.0 International (CC BY-ND 4.0)** license.

**What this means:**
* **Sharing:** You are free to copy and redistribute the material in any medium or format.
* **No Derivatives:** If you remix, transform, or build upon the material, you may **not** distribute the modified material.
* **Contributions:** If you would like to suggest changes or improvements, please submit a Pull Request to this repository. By submitting a PR, you agree to allow your contribution to be integrated into the main project under these same terms.
