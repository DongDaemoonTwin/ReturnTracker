package com.returntracker.android.email

import android.util.Base64
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

class GmailApiClient {
    suspend fun fetchRecentPurchaseEmails(accessToken: String): List<EmailMessageSnapshot> =
        withContext(Dispatchers.IO) {
            val query = "newer_than:90d {subject:주문 subject:결제 subject:구매 subject:order subject:receipt} -subject:취소"
            val encodedQuery = URLEncoder.encode(query, StandardCharsets.UTF_8.name())
            val listJson = getJson(
                url = "$BASE_URL/users/me/messages?maxResults=$MAX_RESULTS&q=$encodedQuery",
                accessToken = accessToken,
            )
            val messages = listJson.optJSONArray("messages") ?: return@withContext emptyList()

            buildList {
                for (index in 0 until messages.length()) {
                    val id = messages.optJSONObject(index)?.optString("id").orEmpty()
                    if (id.isBlank()) continue
                    val json = getJson(
                        url = "$BASE_URL/users/me/messages/$id?format=full",
                        accessToken = accessToken,
                    )
                    parseMessage(json)?.let(::add)
                }
            }
        }

    private fun parseMessage(json: JSONObject): EmailMessageSnapshot? {
        val id = json.optString("id")
        if (id.isBlank()) return null

        val payload = json.optJSONObject("payload") ?: return null
        val headers = buildMap {
            val array = payload.optJSONArray("headers") ?: return@buildMap
            for (index in 0 until array.length()) {
                val header = array.optJSONObject(index) ?: continue
                put(header.optString("name").lowercase(), header.optString("value"))
            }
        }
        val plainBodies = mutableListOf<String>()
        val htmlBodies = mutableListOf<String>()
        collectBodies(payload, plainBodies, htmlBodies)
        val body = plainBodies.joinToString("\n").ifBlank {
            htmlBodies.joinToString("\n").stripHtml()
        }

        return EmailMessageSnapshot(
            id = id,
            subject = headers["subject"].orEmpty(),
            from = headers["from"].orEmpty(),
            receivedAt = json.optString("internalDate").toLongOrNull()?.let(Instant::ofEpochMilli)
                ?: Instant.now(),
            body = body,
        )
    }

    private fun collectBodies(
        part: JSONObject,
        plainBodies: MutableList<String>,
        htmlBodies: MutableList<String>,
    ) {
        val mimeType = part.optString("mimeType")
        val encoded = part.optJSONObject("body")?.optString("data").orEmpty()
        if (encoded.isNotBlank()) {
            val decoded = runCatching {
                val bytes = Base64.decode(encoded, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
                String(bytes, Charsets.UTF_8)
            }.getOrNull()
            if (!decoded.isNullOrBlank()) {
                when {
                    mimeType.startsWith("text/plain") -> plainBodies += decoded
                    mimeType.startsWith("text/html") -> htmlBodies += decoded
                }
            }
        }

        val parts = part.optJSONArray("parts") ?: return
        for (index in 0 until parts.length()) {
            parts.optJSONObject(index)?.let { collectBodies(it, plainBodies, htmlBodies) }
        }
    }

    private fun getJson(url: String, accessToken: String): JSONObject {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 15_000
            readTimeout = 20_000
            setRequestProperty("Authorization", "Bearer $accessToken")
            setRequestProperty("Accept", "application/json")
        }

        return try {
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val response = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                throw IOException("Gmail API 요청 실패 ($status): ${response.take(160)}")
            }
            JSONObject(response)
        } finally {
            connection.disconnect()
        }
    }

    private fun String.stripHtml(): String =
        replace(Regex("<style[^>]*>.*?</style>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)), " ")
            .replace(Regex("<script[^>]*>.*?</script>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)), " ")
            .replace(Regex("<br\\s*/?>|</p>|</div>|</tr>", RegexOption.IGNORE_CASE), "\n")
            .replace(Regex("<[^>]+>"), " ")
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace(Regex("[ \\t]+"), " ")
            .replace(Regex("\\n{3,}"), "\n\n")
            .trim()

    private companion object {
        const val BASE_URL = "https://gmail.googleapis.com/gmail/v1"
        const val MAX_RESULTS = 30
    }
}
