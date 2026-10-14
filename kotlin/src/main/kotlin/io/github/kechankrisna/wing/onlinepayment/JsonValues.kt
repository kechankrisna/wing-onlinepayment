package io.github.kechankrisna.wing.onlinepayment

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Lenient readers for Wing JSON: strings and numbers are read whatever type
 * Wing actually sends.
 */
internal fun JsonObject.string(vararg keys: String): String = optionalString(*keys) ?: ""

/** First present key wins; numbers and booleans are read as their text. */
internal fun JsonObject.optionalString(vararg keys: String): String? {
    for (key in keys) {
        val value = this[key]
        if (value is JsonPrimitive && value !is JsonNull) return value.content
    }
    return null
}

internal fun JsonObject.double(key: String): Double = optionalDouble(key) ?: 0.0

internal fun JsonObject.optionalDouble(key: String): Double? =
    (this[key] as? JsonPrimitive)
        ?.takeIf {
            it !is JsonNull
        }?.content
        ?.trim()
        ?.toDoubleOrNull()

internal fun JsonObject.obj(key: String): JsonObject? = this[key] as? JsonObject

/** JSON without escaping `/` or non-ASCII, like PHP's `JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE`. */
internal fun JsonElement.encode(): String = Json.encodeToString(JsonElement.serializer(), this)

internal fun decodeObject(body: String): JsonObject? =
    try {
        Json.parseToJsonElement(body) as? JsonObject
    } catch (_: IllegalArgumentException) {
        null
    }
