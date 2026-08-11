package com.returntracker.android.email

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class EmailMessageSnapshot(
    val id: String,
    val subject: String,
    val from: String,
    val receivedAt: Instant,
    val body: String,
)

data class EmailPurchaseCandidate(
    val sourceMessageId: String,
    val productName: String,
    val storeName: String,
    val priceWon: Long,
    val purchaseDate: LocalDate,
    val returnDeadline: LocalDate,
    val orderNumber: String?,
    val note: String,
    val needsReview: Boolean,
)

object PurchaseEmailParser {
    private val purchaseKeyword = Regex(
        pattern = "(주문|결제|구매|영수증|order|receipt|payment)",
        option = RegexOption.IGNORE_CASE,
    )
    private val cancelledKeyword = Regex(
        pattern = "(주문|결제).{0,12}(취소|환불).{0,12}(완료|처리)",
        option = RegexOption.IGNORE_CASE,
    )
    private val productPattern = Regex(
        pattern = "(?:상품명|주문\u0020?상품|product(?:\u0020name)?)\\s*[:：]\\s*([^\\r\\n|]{2,100})",
        option = RegexOption.IGNORE_CASE,
    )
    private val orderNumberPattern = Regex(
        pattern = "(?:주문\u0020?번호|order\u0020?(?:number|no\\.?|#))\\s*[:：#]?\\s*([A-Z0-9-]{5,40})",
        option = RegexOption.IGNORE_CASE,
    )
    private val labelledPricePattern = Regex(
        pattern = "(?:총\\s*(?:결제|주문)\\s*금액|결제\\s*금액|합계|total)[^0-9]{0,20}([0-9][0-9,]*)\\s*(?:원|KRW|₩)",
        option = RegexOption.IGNORE_CASE,
    )
    private val generalPricePattern = Regex(
        pattern = "(?:₩\\s*)?([0-9][0-9,]{2,})\\s*(?:원|KRW)",
        option = RegexOption.IGNORE_CASE,
    )
    private val fullDatePattern = Regex("(20\\d{2})[./-]\\s*(\\d{1,2})[./-]\\s*(\\d{1,2})")
    private val koreanDatePattern = Regex("(20\\d{2})년\\s*(\\d{1,2})월\\s*(\\d{1,2})일")
    private val returnDaysPattern = Regex(
        pattern = "(?:반품|return).{0,40}(?:수령|배송(?:\\s*완료)?|purchase)?.{0,20}(\\d{1,2})일\\s*(?:이내|동안|까지)",
        option = RegexOption.IGNORE_CASE,
    )

    fun parse(
        message: EmailMessageSnapshot,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): EmailPurchaseCandidate? {
        val text = "${message.subject}\n${message.body}"
        if (!purchaseKeyword.containsMatchIn(text) || cancelledKeyword.containsMatchIn(message.subject)) {
            return null
        }

        val purchaseDate = message.receivedAt.atZone(zoneId).toLocalDate()
        val explicitDeadline = findDeadline(text)
        val policyDays = returnDaysPattern.find(text)?.groupValues?.getOrNull(1)?.toLongOrNull()
        val deadline = explicitDeadline ?: purchaseDate.plusDays(policyDays ?: DEFAULT_RETURN_DAYS)
        val deadlineWasEstimated = explicitDeadline == null

        val extractedProductName = productPattern.find(text)?.groupValues?.getOrNull(1)?.cleanValue()
        val subjectProductName = cleanSubject(message.subject)
        val productName = extractedProductName
            ?: subjectProductName.takeIf { it.length >= 2 }
            ?: "상품명 확인 필요"
        val priceWon = findPrice(text)
        val needsReview = deadlineWasEstimated || productName == "상품명 확인 필요" || priceWon == 0L

        val notes = buildList {
            add("Gmail 자동 등록")
            if (deadlineWasEstimated) {
                add(
                    if (policyDays != null) {
                        "메일의 ${policyDays}일 정책으로 마감일 추정"
                    } else {
                        "반품 마감일을 구매일 기준 ${DEFAULT_RETURN_DAYS}일로 추정"
                    },
                )
            }
            if (needsReview) add("상품 정보 확인 필요")
        }

        return EmailPurchaseCandidate(
            sourceMessageId = message.id,
            productName = productName,
            storeName = storeName(message.from),
            priceWon = priceWon,
            purchaseDate = purchaseDate,
            returnDeadline = deadline,
            orderNumber = orderNumberPattern.find(text)?.groupValues?.getOrNull(1)?.cleanValue(),
            note = notes.joinToString(" · "),
            needsReview = needsReview,
        )
    }

    private fun findDeadline(text: String): LocalDate? {
        val candidates = sequence {
            yieldAll(fullDatePattern.findAll(text))
            yieldAll(koreanDatePattern.findAll(text))
        }

        return candidates.firstNotNullOfOrNull { match ->
            val start = (match.range.first - 60).coerceAtLeast(0)
            val end = (match.range.last + 60).coerceAtMost(text.lastIndex)
            val context = text.substring(start, end + 1)
            if (!Regex("반품|교환|return", RegexOption.IGNORE_CASE).containsMatchIn(context)) {
                return@firstNotNullOfOrNull null
            }
            runCatching {
                LocalDate.of(
                    match.groupValues[1].toInt(),
                    match.groupValues[2].toInt(),
                    match.groupValues[3].toInt(),
                )
            }.getOrNull()
        }
    }

    private fun findPrice(text: String): Long {
        val raw = labelledPricePattern.find(text)?.groupValues?.getOrNull(1)
            ?: generalPricePattern.find(text)?.groupValues?.getOrNull(1)
            ?: return 0L
        return raw.replace(",", "").toLongOrNull() ?: 0L
    }

    private fun cleanSubject(subject: String): String = subject
        .replace(Regex("^\\s*\\[[^]]+]\\s*"), "")
        .replace(
            Regex(
                "(?:주문|결제|구매|영수증|order|receipt|payment).{0,20}(?:완료|확인|내역|되었습니다|received)?",
                RegexOption.IGNORE_CASE,
            ),
            "",
        )
        .replace(Regex("[-:：|]+"), " ")
        .cleanValue()

    private fun storeName(from: String): String {
        val displayName = Regex("^\\s*\\\"?([^\\\"<]+)\\\"?\\s*<")
            .find(from)
            ?.groupValues
            ?.getOrNull(1)
            ?.cleanValue()
        if (!displayName.isNullOrBlank()) return displayName

        val domain = from.substringAfter('@', "").substringBefore('>').lowercase()
        return when {
            "coupang" in domain -> "쿠팡"
            "musinsa" in domain -> "무신사"
            "naver" in domain -> "네이버"
            "amazon" in domain -> "Amazon"
            domain.isNotBlank() -> domain.substringBefore('.').replaceFirstChar(Char::uppercase)
            else -> "구매처 확인 필요"
        }
    }

    private fun String.cleanValue(): String = trim().trim('"', '\'', '-', ':', '：').trim()

    private const val DEFAULT_RETURN_DAYS = 14L
}
