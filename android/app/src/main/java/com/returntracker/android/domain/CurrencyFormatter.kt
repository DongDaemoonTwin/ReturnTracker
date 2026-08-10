package com.returntracker.android.domain

import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

object CurrencyFormatter {
    private val koreanWon = NumberFormat.getCurrencyInstance(Locale.KOREA).apply {
        currency = Currency.getInstance("KRW")
        maximumFractionDigits = 0
    }

    fun won(amount: Long): String = koreanWon.format(amount)

    fun parseWon(input: String): Long? {
        val digits = input.filter(Char::isDigit)
        return digits.takeIf(String::isNotEmpty)?.toLongOrNull()
    }
}
