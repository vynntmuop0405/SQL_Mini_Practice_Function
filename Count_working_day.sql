CREATE FUNCTION dbo.fn_LateFeeAccrual
(
    @Outstanding  DECIMAL(18,4),
    @PenaltyRate  DECIMAL(18,8),   -- ví dụ 0.24 = 24%/năm
    @FromDate     DATE,
    @ToDate       DATE,
    @UseBusinessDays BIT = 1
)
RETURNS DECIMAL(18,4)
AS
BEGIN
    IF @Outstanding IS NULL 
       OR @PenaltyRate IS NULL 
       OR @FromDate IS NULL 
       OR @ToDate IS NULL 
        RETURN NULL;

    IF @ToDate <= @FromDate 
       OR @Outstanding <= 0 
       OR @PenaltyRate <= 0 
        RETURN 0;

    DECLARE @days INT;

    -- Nếu dùng ngày làm việc
    IF @UseBusinessDays = 1
    BEGIN
        ;WITH DateRange AS
        (
            SELECT @FromDate AS WorkDate
            UNION ALL
            SELECT DATEADD(DAY, 1, WorkDate)
            FROM DateRange
            WHERE DATEADD(DAY, 1, WorkDate) <= @ToDate
        )
        SELECT @days = COUNT(*)
        FROM DateRange
        WHERE DATENAME(WEEKDAY, WorkDate) NOT IN ('Saturday', 'Sunday')
        OPTION (MAXRECURSION 0); -- tránh giới hạn 100 cấp đệ quy mặc định
    END
    ELSE
    BEGIN
        SET @days = DATEDIFF(DAY, @FromDate, @ToDate);
    END

    IF @days < 0 SET @days = -@days;

    RETURN ROUND(@Outstanding * @PenaltyRate * (@days / 365.0), 4);
END
GO

----
---- KIỂM TRA
SELECT dbo.fn_LateFeeAccrual
(
    @Outstanding     = 1000000,        -- số dư nợ (1 triệu)
    @PenaltyRate     = 0.24,           -- 24%/năm
    @FromDate        = '2025-08-01',   -- ngày bắt đầu tính phí
    @ToDate          = '2025-08-13',   -- ngày kết thúc tính phí
    @UseBusinessDays = 1               -- 1 = chỉ tính ngày làm việc, 0 = tính cả ngày thường
) AS LateFee;