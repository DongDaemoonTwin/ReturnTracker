package com.returntracker.android.domain

import java.time.LocalDate
import java.time.temporal.ChronoUnit

object ReturnDeadline {
    fun daysRemaining(
        deadline: LocalDate,
        now: LocalDate = LocalDate.now(),
    ): Int = ChronoUnit.DAYS.between(now, deadline).toInt()

    fun label(
        deadline: LocalDate,
        now: LocalDate = LocalDate.now(),
    ): String = when (val days = daysRemaining(deadline, now)) {
        in 1..Int.MAX_VALUE -> "D-$days"
        0 -> "오늘 마감"
        else -> "기간 지남"
    }

    fun needsAttention(
        deadline: LocalDate,
        status: ReturnStatus,
        now: LocalDate = LocalDate.now(),
    ): Boolean = status != ReturnStatus.REFUNDED && daysRemaining(deadline, now) <= 3
}
