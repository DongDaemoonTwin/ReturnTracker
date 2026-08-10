package com.returntracker.android.domain

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReturnDeadlineTest {
    private val today = LocalDate.of(2026, 8, 9)

    @Test
    fun todayIsZeroDaysRemaining() {
        assertEquals(0, ReturnDeadline.daysRemaining(today, today))
        assertEquals("오늘 마감", ReturnDeadline.label(today, today))
    }

    @Test
    fun tomorrowIsOneDayRemaining() {
        val tomorrow = LocalDate.of(2026, 8, 10)

        assertEquals(1, ReturnDeadline.daysRemaining(tomorrow, today))
        assertEquals("D-1", ReturnDeadline.label(tomorrow, today))
    }

    @Test
    fun threeDaysAwayNeedsAttention() {
        assertTrue(
            ReturnDeadline.needsAttention(
                deadline = LocalDate.of(2026, 8, 12),
                status = ReturnStatus.KEEPING,
                now = today,
            ),
        )
    }

    @Test
    fun expiredDeadline() {
        val yesterday = LocalDate.of(2026, 8, 8)

        assertEquals(-1, ReturnDeadline.daysRemaining(yesterday, today))
        assertEquals("기간 지남", ReturnDeadline.label(yesterday, today))
    }

    @Test
    fun refundedItemDoesNotNeedAttention() {
        assertFalse(
            ReturnDeadline.needsAttention(
                deadline = today,
                status = ReturnStatus.REFUNDED,
                now = today,
            ),
        )
    }
}
