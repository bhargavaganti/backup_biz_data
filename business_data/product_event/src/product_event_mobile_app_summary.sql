select cast (mst_datetime as date) as mst_date
,visitor_id
,visit_id
,experience_type
,device_type 
,property_status_detail
,page_type
,page_type_detail
,page_type_group
,property_status
,sub_property_status
,apps_type
, to_char(current_timestamp, 'yyyy-mm-dd hh24:mi:ss')   as etl_created_datetime , 'glue_etl' as etl_created_by
,SUM(CASE WHEN lower(trim(event_type_id)) = '70' THEN 1 ELSE 0 END) as pageview_count
from product_event.mapi_biz_data  a
WHERE  1=1
AND event_date = concat('{year}', '{month}', '{day}')
group by
cast (mst_datetime as date)
,visitor_id
,visit_id
,experience_type
,device_type 
,property_status_detail
,page_type
,page_type_detail
,page_type_group
,property_status
,sub_property_status
,apps_type
