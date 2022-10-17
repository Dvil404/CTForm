SELECT
	gr.workflow_id AS '问题单号',
	gr.name AS '标题',
	gr.applicant AS '申请人',
	pt1.assignee_name AS '处理人',
	CASE
		gr.state 
		WHEN 'FINISHED' THEN
		"已完成" 
		WHEN 'CANCELED' THEN
		"已取消" 
		WHEN 'STARTED' THEN
		"已开始"
		WHEN 'TIMEOUT_CLOSED' THEN
		"已超时"
	END '工单状态',
  
	JSON_UNQUOTE(JSON_EXTRACT(gr.process_form,'$.trouble_source')) as '问题来源',
			 
CASE JSON_UNQUOTE(JSON_EXTRACT( gr.process_form, '$.trouble_classification' )) 
	WHEN 'basic' THEN
	"基础软硬件问题" 
	WHEN 'nobasic' THEN
	"非基础软硬件问题" 
	WHEN 'physical' THEN
	"物理安全隐患" 
	WHEN 'info' THEN
	"信息安全隐患" 
END '一级分类',
IF(JSON_EXTRACT(gr.process_form,'$.trouble_classification')='basic',JSON_EXTRACT(gr.process_form,'$.basic_trouble'),IF(JSON_EXTRACT(gr.process_form,'$.trouble_classification')='nobasic',JSON_EXTRACT(gr.process_form,'$.nobasic_trouble'),IF(JSON_EXTRACT(gr.process_form,'$.trouble_classification')='physical',JSON_EXTRACT(gr.process_form,'$.physical_trouble'),JSON_EXTRACT(gr.process_form,'$.info_trouble')))) as '二级分类',
       gr.created_at as '申请时间',
       FROM_UNIXTIME(JSON_EXTRACT(gr.process_form,'$.want_start_time')  / 1000) as '预期开始时间',
	   FROM_UNIXTIME(JSON_EXTRACT(gr.process_form,'$.want_end_time')  / 1000) as '预期完成时间',
	   FROM_UNIXTIME(JSON_EXTRACT(pt1.form,'$.diaoyan_start_time')  / 1000) as '调研开始时间',
	   FROM_UNIXTIME(JSON_EXTRACT(pt1.form,'$.diaoyan_end_time')  / 1000) as '调研结束时间',
	   TIMESTAMPDIFF(HOUR, FROM_UNIXTIME(JSON_EXTRACT(gr.process_form,'$.want_start_time')  / 1000),FROM_UNIXTIME(JSON_EXTRACT(gr.process_form,'$.want_end_time')  / 1000)) as '预期时间(小时)',
	   TIMESTAMPDIFF(HOUR, FROM_UNIXTIME(JSON_EXTRACT(pt1.form,'$.diaoyan_start_time')  / 1000), FROM_UNIXTIME(JSON_EXTRACT(pt1.form,'$.diaoyan_end_time')  / 1000)) as '调研时间(小时)',
      
       JSON_EXTRACT(pt1.form, '$.ola') as '是否满足SLA要求',
       gr.description as '备注'
from generic_request gr
         left join (select a.request_id, a.form, a.assign_time, a.process_task_name, a.complete_at,a.assignee_name
                    from process_task as a
                             left join (select max(created_at) as create_at, request_id, process_task_name
                                        from process_task
                                        group by request_id, process_task_name) as b
                                       on a.request_id = b.request_id
                    where a.created_at = b.create_at) as pt1
                   on gr.id = pt1.request_id and pt1.process_task_name = '服务处理'
where type ='PROBLEM_SERVICE' 
#if(${created_at} != '') 
    AND gr.created_at >= STR_TO_DATE(CONCAT('${created_at}', '-01'),'%Y-%m-%d')
		and gr.created_at <= STR_TO_DATE(CONCAT('${created_at}', '-31'),'%Y-%m-%d')
 #end
AND gr.applicant NOT LIKE 'System administrator' AND gr.applicant NOT LIKE 'lxp' AND gr.applicant NOT LIKE 'litong' ;