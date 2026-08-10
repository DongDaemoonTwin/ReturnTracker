package com.returntracker.android.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CurrencyFormatterTest {
    @Test
    fun parserAcceptsZeroAndFormattedLargePrice() {
        assertEquals(0L, CurrencyFormatter.parseWon("0"))
        assertEquals(1_250_000L, CurrencyFormatter.parseWon("₩1,250,000원"))
        assertNull(CurrencyFormatter.parseWon(""))
    }
}
