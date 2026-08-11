package com.returntracker.android.email

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PurchaseEmailParserTest {
    private val utc = ZoneId.of("UTC")

    @Test
    fun parsesLabelledPurchaseAndExplicitDeadline() {
        val candidate = PurchaseEmailParser.parse(
            EmailMessageSnapshot(
                id = "gmail-1",
                subject = "[무신사] 주문이 완료되었습니다",
                from = "무신사 <no-reply@musinsa.com>",
                receivedAt = Instant.parse("2026-08-10T03:00:00Z"),
                body = """
                    상품명: 오버사이즈 셔츠
                    주문번호: M-12345678
                    총 결제 금액: 39,900원
                    반품 마감일: 2026.08.20
                """.trimIndent(),
            ),
            zoneId = utc,
        )

        requireNotNull(candidate)
        assertEquals("오버사이즈 셔츠", candidate.productName)
        assertEquals("무신사", candidate.storeName)
        assertEquals(39_900L, candidate.priceWon)
        assertEquals("M-12345678", candidate.orderNumber)
        assertEquals(LocalDate.of(2026, 8, 20), candidate.returnDeadline)
        assertFalse(candidate.needsReview)
    }

    @Test
    fun fallsBackToFourteenDaysAndFlagsReview() {
        val candidate = PurchaseEmailParser.parse(
            EmailMessageSnapshot(
                id = "gmail-2",
                subject = "[쿠팡] 블루투스 키보드 주문 완료",
                from = "no-reply@coupang.com",
                receivedAt = Instant.parse("2026-08-10T03:00:00Z"),
                body = "결제 금액 25,000원",
            ),
            zoneId = utc,
        )

        requireNotNull(candidate)
        assertEquals(LocalDate.of(2026, 8, 24), candidate.returnDeadline)
        assertTrue(candidate.needsReview)
        assertTrue(candidate.note.contains("14일"))
    }

    @Test
    fun ignoresCancelledOrderMessage() {
        val candidate = PurchaseEmailParser.parse(
            EmailMessageSnapshot(
                id = "gmail-3",
                subject = "주문 취소 처리 완료",
                from = "shop@example.com",
                receivedAt = Instant.parse("2026-08-10T03:00:00Z"),
                body = "주문번호: CANCEL-123 결제 금액: 10,000원",
            ),
            zoneId = utc,
        )

        assertNull(candidate)
    }
}
