package com.taiyebnirjhar.herald

/**
 * The AI providers the first version supports (WBS 5.2). The ids and key names are the ones
 * Hermes uses (hermes_cli/auth.py in the pinned version).
 */
enum class Provider(val hermesId: String, val keyName: String) {
    OPENROUTER("openrouter", "OPENROUTER_API_KEY"),
    GEMINI("gemini", "GEMINI_API_KEY"),
    XAI("xai", "XAI_API_KEY"),
    ;

    companion object {
        fun byId(id: String): Provider? = entries.firstOrNull { it.hermesId == id }
    }
}

/**
 * Checks a provider key and model, and builds the commands that save them inside the
 * Linux base. The key is written by Hermes's own `config set`, into Hermes's `.env` file.
 * No message ever contains the key.
 */
object ProviderSetup {
    private const val CLEAN_PATH = "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

    /** A plain message for the player when the input is not usable; null when it is fine. */
    fun problem(provider: Provider?, key: String, model: String): String? = when {
        provider == null -> "Pick a provider first."
        key.length < MIN_KEY_LENGTH || key.any { it.isWhitespace() } -> "That key doesn't look right. Paste it again."
        model.isBlank() || model.any { it.isWhitespace() } -> "Type the model name, with no spaces."
        else -> null
    }

    /** The three commands that save the key, the provider and the model, in that order. */
    fun commands(provider: Provider, key: String, model: String): List<List<String>> = listOf(
        hermes("config", "set", provider.keyName, key),
        hermes("config", "set", "model.provider", provider.hermesId),
        hermes("config", "set", "model.default", model),
    )

    private fun hermes(vararg args: String): List<String> = buildList {
        add("/usr/bin/env")
        add("-i")
        add("HOME=/root")
        add(CLEAN_PATH)
        add("LANG=C.UTF-8")
        add("/usr/local/bin/hermes")
        addAll(args)
    }

    const val MIN_KEY_LENGTH = 8
}
