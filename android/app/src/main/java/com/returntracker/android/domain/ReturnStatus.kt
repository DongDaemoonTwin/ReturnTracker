package com.returntracker.android.domain

enum class ReturnStatus(
    val title: String,
) {
    KEEPING("보유 중"),
    RETURN_PLANNED("반품 예정"),
    RETURN_REQUESTED("반품 신청"),
    SHIPPED("반품 발송"),
    REFUND_PENDING("환불 대기"),
    REFUNDED("환불 완료"),
}
