# Lopilot
<img width="1200" height="809" alt="Screenshot 2026-01-31 at 6 45 39 PM" src="https://github.com/user-attachments/assets/4c1857c8-6920-4d4a-a46c-e7fcfe900824" />

**Lopilot** is a native macOS application built with SwiftUI that serves as a powerful, local client for Large Language Models (LLMs). Powered by **Ollama**, Lopilot allows you to chat with state-of-the-art AI models entirely offline, ensuring your data remains private and secure.

## Key Features

* **♾️ Fully Limitless & Free:** Since the heavy lifting happens locally, you can skip the monthly subscriptions and usage caps found in services like Meta AI+ or Mistral Le Chat Pro.
* **🧠 Global Community-Powered Learning:** Experience an assistant that actually evolves with you; when you correct the AI, it integrates those insights to sharpen its logic and accuracy for the entire community. To ensure your security, only anonymous, non-personal instructions are used for this global improvement.
* **📦 Built-in Model Manager:** Easily browse, install, and manage your local model library directly through the app interface.
* **📂 File Context:** Drag and drop or import up to 10 files per message (Swift, Python, txt, etc.) to give the AI the specific context it needs.
* **🕓 Chat History:** Your sessions are auto-saved to your local storage, allowing you to pick up exactly where you left off.
* **🔒 Local & Private Processing:** All core message processing happens 100% on your machine. Your private conversations and files never leave your device.

## Supported Models

Lopilot currently supports these models (via Ollama):

* **Meta Llama 3.1** (8b to 405b)
* **DeepSeek R1** (1.5b to 671b)
* **Google Gemma 3** (1b to 27b)
* **Mistral** (7b)
* **Meta Code Llama** (7b to 70b)

## Prerequisites

To run Lopilot, you must have the following installed on your Mac:

1. **macOS 14.0+** (Sonoma or later).
2. **Ollama**: This app acts as a GUI client for Ollama. Download from [ollama.com](https://ollama.com).

## Usage Guide

### Managing Models

Navigate to the "Models" tab. Here you can see which models are installed.

* **To Install:** Click the `Install` button next to the model size you want.
* **To Uninstall:** Click `Uninstall` to free up disk space.

### Using Attachments

You can analyze code or text files by clicking the **(+)** button near the text input.

* **Supported formats:** Text files, Source Code (Swift, Python, JS, etc.).
* **Limit:** Up to 10 files per message.

## Technical Details

* **Persistence:** Chat history and user preferences are stored locally using `UserDefaults`.
* **Sandbox Security:** The app uses security-scoped resources to read user-selected files safely.
* **Networking:** Communicates with the local Ollama instance via `http://localhost:11434/api/generate`.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=milestones14/lopilot&type=date&legend=top-left)](https://www.star-history.com/#milestones14/lopilot&type=date&legend=top-left)

## License

This project is licensed under the **Creative Commons Attribution-NoDerivatives 4.0 International (CC BY-ND 4.0)** license.

**What this means:**
* **Sharing:** You are free to copy and redistribute the material in any medium or format.
* **No Derivatives:** If you remix, transform, or build upon the material, you may **not** distribute the modified material.
* **Contributions:** If you would like to suggest changes or improvements, please submit a Pull Request to this repository. By submitting a PR, you agree to allow your contribution to be integrated into the main project under these same terms.
