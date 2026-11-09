import Foundation

public final class LLMRegistry: @unchecked Sendable {
    public static let shared = LLMRegistry()

    private let jsonDecoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    public init() {}

    /// Pre-curated, verified high-speed GGUF models ready for direct download & local execution
    public func getCuratedModels() -> [LLMModelItem] {
        return [
            // 1. SmolLM2 360M Instruct (~229 MB) - Ultra-Lightweight
            LLMModelItem(
                id: "HuggingFaceTB/SmolLM2-360M-Instruct-GGUF",
                name: "SmolLM2 360M Instruct",
                creator: "Hugging Face",
                category: .ultraLight,
                parameterSize: "360M",
                quantization: .q4_k_m,
                fileSizeBytes: 229_163_008,
                downloadURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q4_k_m.gguf")!,
                fileName: "smollm2-360m-instruct-q4_k_m.gguf",
                description: "Extremely lightweight and fast model designed for high-efficiency on-device AI tasks, minimal RAM footprint (<350MB).",
                tags: ["ultra-light", "fast", "low-ram", "instruction"]
            ),

            // 2. Qwen 2.5 0.5B Instruct (~398 MB) - Ultra-Lightweight
            LLMModelItem(
                id: "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
                name: "Qwen 2.5 0.5B Instruct",
                creator: "Qwen / Alibaba",
                category: .ultraLight,
                parameterSize: "0.5B",
                quantization: .q4_k_m,
                fileSizeBytes: 397_934_592,
                downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf")!,
                fileName: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
                description: "Remarkably strong 500M parameter model offering exceptional instruction-following with near-zero latency.",
                tags: ["fast", "alibaba", "qwen", "multilingual"]
            ),

            // 3. Llama 3.2 1B Instruct (~750 MB) - Meta
            LLMModelItem(
                id: "bartowski/Llama-3.2-1B-Instruct-GGUF",
                name: "Llama 3.2 1B Instruct",
                creator: "Meta AI",
                category: .balanced,
                parameterSize: "1B",
                quantization: .q4_k_m,
                fileSizeBytes: 786_432_000,
                downloadURL: URL(string: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf")!,
                fileName: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
                description: "Meta's flagship compact architecture with state-of-the-art conversational quality and reasoning in under 1GB.",
                tags: ["meta", "llama3", "high-quality", "compact"]
            ),

            // 4. Qwen 2.5 1.5B Instruct (~986 MB) - High Quality Balanced
            LLMModelItem(
                id: "Qwen/Qwen2.5-1.5B-Instruct-GGUF",
                name: "Qwen 2.5 1.5B Instruct",
                creator: "Qwen / Alibaba",
                category: .balanced,
                parameterSize: "1.5B",
                quantization: .q4_k_m,
                fileSizeBytes: 986_120_192,
                downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf")!,
                fileName: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
                description: "Premier 1.5B parameter model with remarkable comprehension, coding, and multilingual knowledge.",
                tags: ["coding", "multilingual", "balanced"]
            ),

            // 5. SmolLM2 1.7B Instruct (~1.06 GB) - High Efficiency
            LLMModelItem(
                id: "HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF",
                name: "SmolLM2 1.7B Instruct",
                creator: "Hugging Face",
                category: .balanced,
                parameterSize: "1.7B",
                quantization: .q4_k_m,
                fileSizeBytes: 1_060_000_000,
                downloadURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf")!,
                fileName: "smollm2-1.7b-instruct-q4_k_m.gguf",
                description: "SmolLM2 1.7B outperforms many 3B models in common sense reasoning, creative writing, and concise summarization.",
                tags: ["huggingface", "fast", "efficient"]
            ),

            // 6. DeepSeek-R1 Distill Qwen 1.5B (~1.1 GB) - Breakthrough Reasoning
            LLMModelItem(
                id: "bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF",
                name: "DeepSeek-R1 Distill 1.5B",
                creator: "DeepSeek AI",
                category: .reasoning,
                parameterSize: "1.5B",
                quantization: .q4_k_m,
                fileSizeBytes: 1_120_000_000,
                downloadURL: URL(string: "https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf")!,
                fileName: "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf",
                description: "DeepSeek-R1 distilled reasoning engine capable of step-by-step thinking, complex logic, and math deduction.",
                tags: ["reasoning", "math", "deepseek", "thinking"]
            ),

            // 7. Llama 3.2 3B Instruct (~2.0 GB) - Comprehensive Multipurpose
            LLMModelItem(
                id: "bartowski/Llama-3.2-3B-Instruct-GGUF",
                name: "Llama 3.2 3B Instruct",
                creator: "Meta AI",
                category: .balanced,
                parameterSize: "3B",
                quantization: .q4_k_m,
                fileSizeBytes: 2_020_000_000,
                downloadURL: URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf")!,
                fileName: "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
                description: "Meta's highly capable 3B instruction-tuned model. Exceptional writing, brainstorming, and technical explanations.",
                tags: ["meta", "llama3", "popular"]
            ),

            // 8. Qwen 2.5 3B Instruct (~1.9 GB) - Coding & Logic
            LLMModelItem(
                id: "Qwen/Qwen2.5-3B-Instruct-GGUF",
                name: "Qwen 2.5 3B Instruct",
                creator: "Qwen / Alibaba",
                category: .coding,
                parameterSize: "3B",
                quantization: .q4_k_m,
                fileSizeBytes: 1_930_000_000,
                downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf")!,
                fileName: "qwen2.5-3b-instruct-q4_k_m.gguf",
                description: "Benchmark-topping 3B model with superior Python, Swift, web code generation, and debugging accuracy.",
                tags: ["coding", "logic", "alibaba"]
            ),

            // 9. Phi-3.5 Mini 3.8B Instruct (~2.2 GB) - Reasoning & Math
            LLMModelItem(
                id: "bartowski/Phi-3.5-mini-instruct-GGUF",
                name: "Phi-3.5 Mini 3.8B Instruct",
                creator: "Microsoft",
                category: .reasoning,
                parameterSize: "3.8B",
                quantization: .q4_k_m,
                fileSizeBytes: 2_200_000_000,
                downloadURL: URL(string: "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf")!,
                fileName: "Phi-3.5-mini-instruct-Q4_K_M.gguf",
                description: "Microsoft's state-of-the-art small language model with high proficiency in STEM reasoning and structured extraction.",
                tags: ["microsoft", "phi", "math"]
            )
        ]
    }

    /// Fetches newly created/uploaded GGUF models from Hugging Face in real-time.
    /// Whenever a new model is released, this function dynamically surfaces it in the app!
    public func fetchNewModelsFromHuggingFace(limit: Int = 15) async throws -> [LLMModelItem] {
        let endpoint = "https://huggingface.co/api/models?search=gguf&sort=lastModified&direction=-1&limit=\(limit)"
        guard let url = URL(string: endpoint) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue("Aegis-Platform/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        struct HFModelSummary: Decodable {
            let id: String
            let lastModified: String?
            let downloads: Int?
            let tags: [String]?
            let pipeline_tag: String?
        }

        let summaries = try JSONDecoder().decode([HFModelSummary].self, from: data)
        var newModels: [LLMModelItem] = []

        for summary in summaries {
            // Find model name and creator
            let parts = summary.id.components(separatedBy: "/")
            let creator = parts.count > 1 ? parts[0] : "Community"
            let rawName = parts.count > 1 ? parts[1] : summary.id

            // Clean up name
            let cleanName = rawName
                .replacingOccurrences(of: "-GGUF", with: "")
                .replacingOccurrences(of: "-gguf", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")

            // Determine parameter size heuristic
            var param = "N/A"
            for tag in summary.tags ?? [] {
                if tag.hasSuffix("b") || tag.hasSuffix("m") {
                    param = tag.uppercased()
                    break
                }
            }
            if param == "N/A" {
                if cleanName.lowercased().contains("70b") { param = "70B" }
                else if cleanName.lowercased().contains("32b") { param = "32B" }
                else if cleanName.lowercased().contains("14b") { param = "14B" }
                else if cleanName.lowercased().contains("8b") { param = "8B" }
                else if cleanName.lowercased().contains("7b") { param = "7B" }
                else if cleanName.lowercased().contains("4b") { param = "4B" }
                else if cleanName.lowercased().contains("3b") { param = "3B" }
                else if cleanName.lowercased().contains("1.5b") { param = "1.5B" }
                else if cleanName.lowercased().contains("1b") { param = "1B" }
                else if cleanName.lowercased().contains("0.5b") { param = "0.5B" }
                else if cleanName.lowercased().contains("360m") { param = "360M" }
            }

            // Construct standard GGUF download URL
            // Many repos follow the pattern: {modelName}.Q4_K_M.gguf or Q4_0.gguf
            let targetFile = "\(rawName).Q4_K_M.gguf"
            guard let downloadUrl = URL(string: "https://huggingface.co/\(summary.id)/resolve/main/\(targetFile)") else {
                continue
            }

            // Parse last modified date
            var modDate: Date? = nil
            if let dateStr = summary.lastModified {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                modDate = isoFormatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr)
            }

            let item = LLMModelItem(
                id: summary.id,
                name: cleanName,
                creator: creator,
                category: .newReleases,
                parameterSize: param,
                quantization: .q4_k_m,
                fileSizeBytes: 1_200_000_000, // Estimated default for 1B-3B
                downloadURL: downloadUrl,
                fileName: "\(rawName.lowercased()).gguf",
                isNewRelease: true,
                description: "Newly released open-weights model discovered on Hugging Face hub with GGUF quantization.",
                tags: summary.tags ?? [],
                lastModified: modDate
            )
            newModels.append(item)
        }

        return newModels
    }
}
