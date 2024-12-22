-- head data
select
  CustomerKey,
  Order_Date,
  Order_Number,
  Unit_Price_USD,
from
  `dqlab-yudha-sample1.GlobalElectronicsRetailer.Order`
    inner join
      `dqlab-yudha-sample1.GlobalElectronicsRetailer.Product`
        using(ProductKey)
limit
  5
;

-- check null value
select
  sum(case when CustomerKey is null then 1 else 0 end) as CustomerKey,
  sum(case when Order_Number is null then 1 else 0 end) as Order_Number,
  sum(case when Quantity is null then 1 else 0 end) as Quantity,
  sum(case when Unit_Price_USD is null then 1 else 0 end) as Unit_Price_USD,
  sum(case when Order_Date is null then 1 else 0 end) as Order_Date
from
  `dqlab-yudha-sample1.GlobalElectronicsRetailer.Order`
    inner join
      `dqlab-yudha-sample1.GlobalElectronicsRetailer.Product`
        using(ProductKey)

;

-- Data good and now we start to calculate FRM
select
  o.CustomerKey,
  case when date_diff(max(o.Order_Date), min(o.Order_Date), Day) = 0 then 1 else date_diff(max(o.Order_Date), min(o.Order_Date), Day) end as recency,-- use case when to define if one puchase it mean 1 not zero
  count(o.Order_Number) as frequency,
  sum(safe_cast(replace(p.Unit_Price_USD, '$','') as float64)) as monetary
from
  `dqlab-yudha-sample1.GlobalElectronicsRetailer.Order` as o
    inner join
      `dqlab-yudha-sample1.GlobalElectronicsRetailer.Product` as p
        using(ProductKey)
where
  p.Unit_Price_USD is not null
group by
  1

;

-- and now we give score
with rfm as (
select
  o.CustomerKey as CustomerKey,
  case when date_diff(max(o.Order_Date), min(o.Order_Date), Day) = 0 then 1 else date_diff(max(o.Order_Date), min(o.Order_Date), Day) end as recency,
  count(o.Order_Number) as frequency,
  sum(safe_cast(replace(p.Unit_Price_USD, '$','') as float64)) as monetary
from
  `dqlab-yudha-sample1.GlobalElectronicsRetailer.Order` as o
    inner join
      `dqlab-yudha-sample1.GlobalElectronicsRetailer.Product` as p
        using(ProductKey)
where
  p.Unit_Price_USD is not null
group by
  1
)

select
  CustomerKey,
  recency,
  frequency,
  monetary,
  ntile(3) over (order by recency) as rfm_recency,
  ntile(3) over (order by frequency) as rfm_frequency,
  ntile(3) over (order by monetary) as rfm_monetary
from
  rfm

;


-- and now  we calculate merge RFM score
with rfm as (
select
  o.CustomerKey as CustomerKey,
  case when date_diff(max(o.Order_Date), min(o.Order_Date), Day) = 0 then 1 else date_diff(max(o.Order_Date), min(o.Order_Date), Day) end as recency,
  count(o.Order_Number) as frequency,
  sum(safe_cast(replace(p.Unit_Price_USD, '$','') as float64)) as monetary
from
  `dqlab-yudha-sample1.GlobalElectronicsRetailer.Order` as o
    inner join
      `dqlab-yudha-sample1.GlobalElectronicsRetailer.Product` as p
        using(ProductKey)
where
  p.Unit_Price_USD is not null
group by
  1
),

rfm_cal as (
select
  CustomerKey,
  recency,
  frequency,
  monetary,
  ntile(3) over (order by recency) as rfm_recency,
  ntile(3) over (order by frequency) as rfm_frequency,
  ntile(3) over (order by monetary) as rfm_monetary
from
  rfm
)

select
  CustomerKey,
  recency,
  frequency,
  monetary,
  rfm_recency,
  rfm_frequency,
  rfm_monetary,
  (rfm_recency + rfm_frequency + rfm_monetary) as rfm_score,
  (rfm_recency || rfm_frequency || rfm_monetary) as rf_segment
from
  rfm_cal
;

/*
 and now we give detail of segment based on frm score such

New customer, Lost customer, Regular customer, Loyal customers, and Champion customers


*/

with rfm as (
select
  o.CustomerKey as CustomerKey,
  case when date_diff(max(o.Order_Date), min(o.Order_Date), Day) = 0 then 1 else date_diff(max(o.Order_Date), min(o.Order_Date), Day) end as recency,
  count(o.Order_Number) as frequency,
  sum(safe_cast(replace(p.Unit_Price_USD, '$','') as float64)) as monetary
from
  `dqlab-yudha-sample1.GlobalElectronicsRetailer.Order` as o
    inner join
      `dqlab-yudha-sample1.GlobalElectronicsRetailer.Product` as p
        using(ProductKey)
where
  p.Unit_Price_USD is not null
group by
  1
),

rfm_cal as (
select
  CustomerKey,
  recency,
  frequency,
  monetary,
  ntile(3) over (order by recency) as rfm_recency,
  ntile(3) over (order by frequency) as rfm_frequency,
  ntile(3) over (order by monetary) as rfm_monetary
from
  rfm
),

rfm_next as (
  select
    CustomerKey,
    recency,
    frequency,
    monetary,
    rfm_recency,
    rfm_frequency,
    rfm_monetary,
    (rfm_recency + rfm_frequency + rfm_monetary) as rfm_score,
    (rfm_recency || rfm_frequency || rfm_monetary) as rf_segment
  from
    rfm_cal
),

rfm_sg as (
  select
    CustomerKey,
    recency,
    frequency,
    monetary,
    rfm_recency,
    rfm_frequency,
    rfm_monetary,
    rfm_score,
    rf_segment,
    case
      when rf_segment = '333' then 'Champion Customer'
      when rf_segment in ('323', '332') then 'Potential Champion Customer'
      when rf_segment in ('233', '331', '232', '223') then 'Loyal Customer'
      when rf_segment in ('321', '322', '213') then 'Potential Loyal Customer'
      when rf_segment = '222' then 'Regular Customer'
      when rf_segment in ('212', '231') then 'Potential Regular Customer'
      when rf_segment in ('313', '311', '312') then 'New Customer'
      when rf_segment in ('123', '132', '133', '221', '211') then 'At-Risk Customer'
      when rf_segment in ('122', '111', '121', '131', '113', '112') then 'Lost Customer'
    else '0' end as Category
  from
    rfm_next    
)

select
  CustomerKey,
  recency,
  frequency,
  monetary,
  rfm_recency,
  rfm_frequency,
  rfm_monetary,
  rfm_score,
  rf_segment,
  Category,
from
  rfm_sg
;
