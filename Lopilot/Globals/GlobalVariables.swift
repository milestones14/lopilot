import Foundation

class GlobalVariables {
    static let models: [String: String] = [
        "Google Gemma3": "gemma3",
        "Meta Llama 3.1": "llama3.1",
        "Mistral": "mistral",
        "DeepSeek R1": "deepseek-r1",
        "Meta Code Llama": "codellama"
    ]
    
    static let modelsUser: [String: String] = [
        "gemma3": "Google Gemma3",
        "llama3.1": "Meta Llama 3.1",
        "mistral": "Mistral",
        "deepseek-r1": "DeepSeek R1",
        "codellama": "Meta Code Llama"
    ]

    static let modelsToParams: [String: [String]] = [
        "gemma3": ["1b", "4b", "12b", "27b"],
        "llama3.1": ["8b", "70b", "405b"],
        "mistral": ["7b"],
        "deepseek-r1": ["1.5b", "7b", "8b", "14b", "32b", "70b", "671b"],
        "codellama": ["7b", "13b", "34b", "70b"]
    ]
    
    // --- General, Creative & Lifestyle (30 items) ---
    static var promptSuggestions: [PromptSuggestion] {
        [
            PromptSuggestion(content: "Suggest 5 healthy breakfast ideas with eggs"),
            PromptSuggestion(content: "How do I make a sourdough starter from scratch?"),
            PromptSuggestion(content: "Summarize the plot of the Great Gatsby in three sentences"),
            PromptSuggestion(content: "Explain the theory of relativity using a sports analogy"),
            PromptSuggestion(content: "Give me a 15-minute bodyweight workout routine"),
            PromptSuggestion(content: "How does a blockchain actually work?"),
            PromptSuggestion(content: "Write a formal cover letter for a Software Engineer role"),
            PromptSuggestion(content: "Translate 'Where is the nearest train station?' into Japanese"),
            PromptSuggestion(content: "Create a list of 10 travel essentials for a hiking trip"),
            PromptSuggestion(content: "Write a funny script for a 30-second coffee commercial"),
            PromptSuggestion(content: "What are the pros and cons of remote work?"),
            PromptSuggestion(content: "Explain how photosynthesis works to a middle schooler"),
            PromptSuggestion(content: "How can I improve my focus while working from home?"),
            PromptSuggestion(content: "What is the best way to learn a new language quickly?"),
            PromptSuggestion(content: "Describe the architectural style of the Renaissance"),
            PromptSuggestion(content: "Suggest 5 classic sci-fi books for a beginner"),
            PromptSuggestion(content: "What are the main causes of the French Revolution?"),
            PromptSuggestion(content: "How do electric vehicle batteries differ from phone batteries?"),
            PromptSuggestion(content: "What are some effective networking tips for introverts?"),
            PromptSuggestion(content: "Write a short ghost story set in a library"),
            PromptSuggestion(content: "How does the stock market work for beginners?"),
            PromptSuggestion(content: "Explain the difference between a latte and a cappuccino"),
            PromptSuggestion(content: "Provide a recipe for a classic Margherita pizza"),
            PromptSuggestion(content: "Write a polite rejection letter for a job applicant"),
            PromptSuggestion(content: "What are the environmental benefits of vertical farming?"),
            PromptSuggestion(content: "Draft a beginner-friendly 10-step guide to meditation"),
            PromptSuggestion(content: "Write a thank-you note to a mentor who helped with a career move"),
            PromptSuggestion(content: "What are 5 essential tips for first-time home buyers?"),
            PromptSuggestion(content: "How do noise-canceling headphones work physically?"),
            PromptSuggestion(content: "Explain the concept of 'opportunity cost' with an everyday example"),
            PromptSuggestion(content: "What is the history behind the Olympic Games?"),
            PromptSuggestion(content: "Create a step-by-step checklist for launching a startup"),
            PromptSuggestion(content: "Explain how the immune system remembers viruses"),
            PromptSuggestion(content: "What are the best plants for a low-light apartment?")
        ]
    }
    
    // --- Coding & Tech (17 items) ---
    static var promptSuggestionsCode: [PromptSuggestion] {
        [
            PromptSuggestion(content: "Write a Hello World application in React"),
            PromptSuggestion(content: "What are the primary differences between Swift and Kotlin?"),
            PromptSuggestion(content: "Write a Python script to scrape news headlines"),
            PromptSuggestion(content: "What are the best practices for accessibility in web design?"),
            PromptSuggestion(content: "Explain the difference between SQL and NoSQL databases"),
            PromptSuggestion(content: "Write a CSS snippet for a glassmorphism card effect"),
            PromptSuggestion(content: "How do I center a div using Flexbox?"),
            PromptSuggestion(content: "Write a bash script to automate folder backups"),
            PromptSuggestion(content: "Explain the concept of 'technical debt' to a non-coder"),
            PromptSuggestion(content: "What are the most common design patterns in Swift?"),
            PromptSuggestion(content: "How do I fix a 'merge conflict' in Git?"),
            PromptSuggestion(content: "Explain the difference between deep learning and machine learning"),
            PromptSuggestion(content: "How do I optimize a website for Core Web Vitals?"),
            PromptSuggestion(content: "How do I implement 'Dark Mode' in a SwiftUI app?"),
            PromptSuggestion(content: "What are the best practices for securing a REST API?"),
            PromptSuggestion(content: "Explain how an API works using a restaurant analogy"),
            PromptSuggestion(content: "What is the difference between a compiler and an interpreter?"),
        ]
    }
    
    static var modelsToSizes: [String: String] = [
        "deepseek-r1:1.5b": "1.1GB",
        "deepseek-r1:7b": "4.7GB",
        "deepseek-r1:8b": "5.2GB",
        "deepseek-r1:14b": "9GB",
        "deepseek-r1:32b": "20GB",
        "deepseek-r1:70b": "43GB",
        "deepseek-r1:671b": "404GB",
        "gemma3:1b": "815MB",
        "gemma3:4b": "3.3GB",
        "gemma3:12b": "8.1GB",
        "gemma3:27b": "17GB",
        "codellama:7b": "3.8GB",
        "codellama:13b": "7.4GB",
        "codellama:34b": "19GB",
        "codellama:70b": "39GB",
        "llama3.1:8b": "4.9GB",
        "llama3.1:70b": "43GB",
        "llama3.1:405b": "243GB",
        "mistral:7b": "4.4GB"
    ]
}
